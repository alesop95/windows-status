# 07 — Salute e stabilità (registro eventi, memoria, crash)

Lo snapshot fotografa la **configurazione**; il Compare ne segnala le **variazioni di sicurezza**. Nessuno dei due guarda però *come si sta comportando* la macchina: crash, schermate blu, esaurimento di memoria, errori hardware. Questo documento copre quella dimensione — la **stabilità** — con un check ripetibile (`scripts\Controlla-Salute.ps1`) e un setup per tenerla sotto controllo nel tempo.

> Origine: incidente del **2026-06-30**. Tre app (Telegram, VS Code, Chrome) terminate quasi in contemporanea; dal registro eventi è emerso un **esaurimento di memoria/commit**, non un guasto hardware. Da lì è nato questo check. Il dettaglio dell'incidente sta in `_notes\` (locale, non versionato).

---

## 1. Il check (`Controlla-Salute.ps1`) — sola lettura

```powershell
.\scripts\Controlla-Salute.ps1                 # ultimi 14 giorni
.\scripts\Controlla-Salute.ps1 -Giorni 30      # finestra più ampia
.\scripts\Controlla-Salute.ps1 -Retention 14   # tiene solo gli ultimi 14 report
```

Interroga in sola lettura il registro eventi e lo stato live e produce `snapshots\salute_<data>\SUMMARY.txt` (+ CSV/TXT di dettaglio). Cosa controlla:

| # | Cosa | Fonte (registro eventi / WMI) |
|---|---|---|
| 1 | Memoria live: RAM libera, % commit, paging, top processi | `Win32_OperatingSystem`, `Get-Process` |
| 2 | **Esaurimento memoria virtuale** | System / `Resource-Exhaustion-Detector` **ID 2004** |
| 3 | **Crash applicativi** + riconoscimento codici OOM | Application **ID 1000** |
| 4 | Applicazioni bloccate (hang) | Application **ID 1002** |
| 5 | **BSOD** e arresti imprevisti | System `WER-SystemErrorReporting` **1001**, **Kernel-Power 41**, **6008** |
| 6 | **Errori hardware** (CPU/RAM/PCIe) | System `WHEA-Logger` |
| 7 | Corruzione file system / disco | System `Ntfs` 55/137, `disk` 7/11/51/52/153 |

Chiude con un **VERDETTO** che classifica i segnali in `ALERT` / `WARN`. Per i dati di sistema e i BSOD conviene eseguirlo da **PowerShell amministratore** (il riepilogo segnala con quali privilegi è girato).

### Codici di esaurimento memoria (la chiave di lettura)
Lo stesso problema — "memoria finita" — si presenta con facce diverse. Mappa di riferimento:

| Codice | Significato | Dove si vede |
|---|---|---|
| `0xc000012d` | `STATUS_COMMITMENT_LIMIT` — commit esaurito: il processo **non parte** | dialogo "Impossibile avviare correttamente l'applicazione" |
| `0xe0000008` | OOM di **Chromium/Electron** | Chrome, VS Code, Edge, app Electron (anche reason `oom`, code `-536870904`) |
| `0xc0000017` | `STATUS_NO_MEMORY` — allocazione fallita | crash generici |
| `0x8007000e` | `E_OUTOFMEMORY` | runtime COM/.NET |
| `0xc0000005` | Access Violation (puntatore nullo) | *spesso conseguenza*: un'allocazione fallita restituisce `NULL`, poi dereferenziato |

---

## 2. Setup per tenere Windows sotto controllo

### 2a. Check periodico automatico (opt-in, reversibile)
Come per lo snapshot, il check può girare da solo come attività pianificata (SYSTEM):

```powershell
.\scripts\Controlla-Salute.ps1 -Installa       # giornaliero, ore 13:15 (admin)
.\scripts\Controlla-Salute.ps1 -Disinstalla    # rimuove l'attività (admin)
```

Accumula `salute_<data>\` in `snapshots\` (ignorata da git, retention 30 in modalità pianificata): nel tempo si vede se un problema è episodico o ricorrente. Annota in changelog quando lo installi.

### 2b. Limitare WSL2 (causa frequente di pressione memoria)
WSL2 (`vmmemWSL`) può arrivare a riservare fino al ~50% della RAM e non la rilascia bene. Crea `%UserProfile%\.wslconfig` e poi `wsl --shutdown`:

```ini
[wsl2]
memory=16GB
processors=4
swap=8GB
```

### 2c. Sorvegliare i processi che crescono (leak)
Quando il check segnala OOM ricorrente, il colpevole è di solito un processo che cresce nel tempo (spesso `node.exe` o un'app Electron). Per individuarlo al volo:

```powershell
Get-Process node,Code,chrome -ErrorAction SilentlyContinue |
  Sort-Object WS -Descending |
  Select-Object Name,Id,@{n='WS_MB';e={[math]::Round($_.WS/1MB)}},StartTime
```

Un dev server o un processo Electron lasciato attivo per giorni va riavviato; se il leak è in uno strumento, aggiornarlo.

**Caso specifico di questa macchina: Claude Code stesso è un sospetto `node.exe`.** Ogni sessione avvia processo CLI e, per ogni server MCP configurato via `npx` (es. il filesystem server `obsidian-vaults` a livello account, vedi `CLAUDE.md` utente), uno o più `node.exe` figli che restano attivi finché la sessione è aperta. Sessioni lunghe non chiuse, o più account/istanze in parallelo (`.claude-account1`/`.claude-account2`/`.claude-account3`), moltiplicano questi processi. Per distinguerli dagli altri `node.exe` (dev server, altri tool) risali al genitore:

```powershell
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
  Select-Object ProcessId, ParentProcessId,
    @{n='Genitore';e={(Get-Process -Id $_.ParentProcessId -ErrorAction SilentlyContinue).ProcessName}},
    @{n='WS_MB';e={[math]::Round((Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue).WS/1MB)}},
    CommandLine
```

Se il genitore è `claude` e la riga di comando cita un server MCP, quel `node.exe` è un'istanza dell'MCP e va tenuto d'occhio come le altre: chiuderla insieme alla sessione che non serve più, non lasciarla appesa tra un lancio e l'altro di Claude Code.

### 2d. Quando la vincolata non appartiene a nessun processo (analisi del 2026-10-05)

La sezione 2c presuppone che il commit esaurito stia in un processo. Su questa macchina il presupposto è falso, e lo dimostrano gli stessi eventi 2004, che nel ramo XML `UserData/MemoryExhaustionInfo/SystemInfo` riportano separatamente `SystemCommitCharge`, `ProcessCommitCharge`, `PagedPoolUsage`, `NonPagedPoolUsage` e `PhysicalMemoryUsage`. La differenza fra il commit di sistema e la somma di commit dei processi e dei due pool è commit che nessun processo possiede come privato: sezioni condivise appoggiate al file di paging, viste mappate, allocazioni di driver.

Misura presa su tutti gli eventi 2004 presenti nel registro System al 2026-10-05, dal 27/05 al 05/10, con lo script di lettura riportato sotto: in ogni episodio la vincolata è al limite (222 GB fino a luglio, 244 GB dopo l'ingrandimento del pagefile), il commit dei processi sta fra 29 e 81 GB, i due pool insieme fra 7 e 26 GB, e la quota non attribuita fra 115 e 185 GB. La RAM fisica effettivamente usata negli stessi istanti è fra 38 e 82 GB su 128: la vincolata che manca è prenotata ma non residente. Il processo più grande di ogni evento non supera mai 8,3 GB (un `7zG.exe` del 02/10), e di norma sta sotto i 3 GB.

La quota non attribuita cresce con l'uptime a ritmo quasi costante, circa 6,5 GB al giorno, cioè 270 MB l'ora, e cresce anche di notte a macchina inattiva: fra 00:28 e 09:09 del 27/06 è salita di 2,3 GB. Subito dopo un riavvio vale circa 5 GB (misura del 05/10 a 30 minuti di uptime). Ne segue che il sistema arriva al limite dopo tre o quattro settimane senza riavvio, indipendentemente dal carico, e che ingrandire il pagefile ha solo spostato in là la data: il 05/10 la macchina, avviata il 10/09, si è bloccata (Kernel-Power 41 con `BugcheckCode=0`, cioè nessuna schermata blu ma blocco e riavvio forzato) sette minuti dopo l'ultimo evento 2004. Un ritmo costante e indipendente dall'attività dell'utente indica un componente che alloca a intervalli regolari e non rilascia, plausibilmente un servizio o un driver; quale sia è ancora da verificare.

Lettura della ripartizione dagli eventi, in sola lettura:

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Resource-Exhaustion-Detector'; Id=2004} | ForEach-Object { $s=([xml]$_.ToXml()).Event.UserData.MemoryExhaustionInfo.SystemInfo; [pscustomobject]@{Quando=$_.TimeCreated; VincolataGB=[math]::Round($s.SystemCommitCharge/1GB,1); ProcessiGB=[math]::Round($s.ProcessCommitCharge/1GB,1); NonAttribuitaGB=[math]::Round(($s.SystemCommitCharge-$s.ProcessCommitCharge-$s.PagedPoolUsage-$s.NonPagedPoolUsage)/1GB,1); RAMusataGB=[math]::Round($s.PhysicalMemoryUsage/1GB,1)} }
```

Per individuare il detentore serve una serie temporale da un riavvio in avanti, che metta accanto alla quota non attribuita, per ogni processo, il commit privato, i byte committed delle regioni mappate (`MEM_MAPPED`, letti con `VirtualQueryEx`) e il numero di handle: il processo che cresce allo stesso ritmo della quota non attribuita la sta trattenendo, e se nessuno cresce il detentore è un driver. Lo strumento è `scripts\Campiona-Vincolata.ps1`: senza parametri prende un campione in sola lettura e lo accoda a `snapshots\vincolata\totali.csv` e `processi.csv`; con `-Installa`, da PowerShell amministratore, registra un'attività pianificata che lo esegue come SYSTEM ogni 15 minuti, e `-Disinstalla` la rimuove. Da utente non amministratore non legge circa 160 processi su 400, fra cui i servizi, ed è per questo che la serie va presa dall'attività. Anche come SYSTEM i processi protetti, come l'antimalware, restano illeggibili per la memoria mappata: di quelli restano commit privato e handle.

```powershell
.\scripts\Campiona-Vincolata.ps1               # un campione (sola lettura)
.\scripts\Campiona-Vincolata.ps1 -Installa     # ogni 15 minuti come SYSTEM (admin)
.\scripts\Campiona-Vincolata.ps1 -Disinstalla  # rimuove l'attività (admin)
```

---

## 3. Come leggere il verdetto

- **`[ALERT][OOM]`** → memoria/commit esaurita. Prima di cercare il processo (2c) verifica con 2d se la vincolata è davvero nei processi; poi 2b (WSL). Soluzione strutturale: fermare il leak, **non** ingrandire il pagefile.
- **`[ALERT][BSOD]` / `[ALERT][HARDWARE]` (WHEA)** → è hardware: test RAM (`mdsched.exe`), driver, temperature. *Nell'incidente 2026-06-30 questi erano a zero → causa software.*
- **`[ALERT][DISCO]`** → corruzione reale: `chkdsk`, SMART, backup immediato.
- **`[WARN][STABILITA]`** (Kernel-Power 41 / 6008) → spegnimento non pulito: mancanza alimentazione, hang totale o reset forzato. Se isolato, episodico.

> Nota sul rumore: l'evento **NTFS ID 98** ("volume integro") è informativo e ricorre a centinaia: il check lo **esclude di proposito** per non confonderlo con un errore.

---

## 4. Raccordo

Gli `ALERT` di questo check alimentano la stessa logica di remediation degli alert del Compare (vedi `06_RACCORDO_CHECKLIST_VA.md`): ogni segnale è una voce da chiudere, con data, causa e azione. Il changelog vive nella mappa (`01_MAPPA_CONFIGURAZIONE.md`).
