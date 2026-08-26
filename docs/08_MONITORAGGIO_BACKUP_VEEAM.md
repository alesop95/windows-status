# 08 — Monitoraggio del backup Veeam: rilevare il guasto silenzioso

Il documento `02_VEEAM_BACKUP_PORTABILITA.md` spiega **come si configura** il backup e come si ripristina. Questo copre la domanda successiva, che è diversa e più insidiosa: **come si scopre che il backup ha smesso di funzionare**. La risposta non è ovvia, perché il modo tipico in cui un job di backup muore non produce nessun segnale che qualcuno guardi.

> Origine: incidente su una postazione della flotta, **10/08/2026**, rimasto invisibile **15 giorni**. Il job Veeam ha accumulato 193 retry falliti senza che nessuno se ne accorgesse, mentre la retention a 7 giorni continuava a potare la catena esistente. Rilevato solo per controllo manuale il 25/08. I valori reali della macchina e dello share stanno in `CLAUDE.local.md` (locale); qui compaiono come segnaposto.

---

## 1. Il caso, e perché riguarda questo progetto

La sequenza è accertata dal canale `Microsoft-Windows-Partition/Diagnostic`, evento **ID 1006**, sul disco di sistema NVMe.

| Ora (10/08/2026) | Partizioni | GUID `{GUID-precedente}` | GUID `{GUID-nuovo}` |
|---|---|---|---|
| 09:02:21 | 4 | presente | — |
| 09:03:51 | 4 | presente | — |
| **09:03:51** | **3** | — | — |
| **09:03:51** | **4** | — | presente |
| 09:04:31 | 4 | — | presente |

Tre eventi nello stesso secondo: la partizione di ripristino è stata **eliminata e ricreata** durante il ciclo di servicing di `KB5101711` e `KB5101684` (primo evento CBS alle 09:08:24). Il job Veeam, configurato a livello di volume, memorizzava il GUID vecchio e ha iniziato a fallire in `Preparing for backup` con `Error: Cannot find volume \\?\Volume{...}`.

Il punto che lega l'incidente a questo repository è il seguente. Il numero di partizioni **non è cambiato**: era 4 prima e 4 dopo. Sono cambiate identità e GUID di una di esse, a pari numero, tipo, offset e dimensione. Un confronto che guardi solo il conteggio, la lettera o la dimensione delle partizioni vede *nessuna differenza* e tace, che è esattamente ciò che è accaduto.

C'è un precedente che rende l'evento non eccezionale ma ricorrente: il **01/07/2026 alle 16:10:53** lo stesso disco era già passato da 5 a 4 partizioni. Quella volta il job non si ruppe, perché la partizione rimossa non era in configurazione. Due modifiche di layout in sei settimane su una sola macchina significano che sulla flotta l'evento è frequente, non raro. È anche la stessa modifica di partizioni che la memoria di questo progetto registra alla data del 2026-07-02: la fonte di quel cambiamento, allora attribuita a un intervento manuale con `diskpart`, ha qui la sua spiegazione documentata.

---

## 2. Ricaduta sugli script di questo repository (applicata)

L'insegnamento dell'incidente è stato recepito nello snapshot e nel confronto, perché era una lacuna reale e verificata.

Prima di questa modifica `hardware_partizioni.csv` registrava disco, numero, lettera, tipo, dimensione, flag di boot e offset, e `Compare-Snapshot.ps1` confrontava lettera, dimensione, comparsa e scomparsa. Nessuno di quei campi cambia in un elimina-e-ricrea alla stessa posizione: **il caso peggiore era invisibile allo strumento**.

Oggi lo snapshot registra anche il **GUID di volume** (`GuidVolume`) per ogni partizione, e `hardware_volumi.csv` include pure i volumi **senza lettera**, cioè Ripristino ed EFI, che sono proprio quelli che un ciclo di servicing rigenera. Il confronto emette una categoria di alert nuova.

```
[VOLUMI] disco 0 #4 (Recovery, 1,3GB): GUID di volume CAMBIATO a partizione invariata -
         la partizione e' stata eliminata e ricreata. Un job di backup a livello di volume
         che la referenzia fallira' in 'Preparing for backup'.
```

La guardia è retrocompatibile: confrontando uno snapshot anteriore alla modifica, dove la colonna non esiste, il controllo si salta invece di produrre un falso allarme. Verificato il 2026-08-26 confrontando lo snapshot del 25/08 con quello del 26/08.

Nota di lettura sul valore attuale: il GUID della partizione di ripristino del disco 0 registrato dallo snapshot **è quello nuovo**, `{GUID-nuovo}`, cioè lo stato post-incidente. È il riferimento corretto da qui in avanti, e una sua variazione futura va trattata come l'evento descritto sopra.

---

## 3. I due script per l'RMM (`scripts\rmm\`)

I due script in `scripts\rmm\` non appartengono alla catena locale dello snapshot: girano **come LOCAL SYSTEM sotto l'agent RMM** su tutta la flotta, non ricavano nulla dalla radice del repository e non scrivono in `snapshots\`. Stanno qui perché sono il seguito operativo di questo documento.

| File | Ruolo | Cosa misura |
|---|---|---|
| `Veeam-BackupFreshness.ps1` | **Rilevamento** | Ore dall'ultimo restore point creato |
| `Disk-LayoutDrift.ps1` | **Prevenzione** | Variazione dei GUID di volume dei dischi fissi |

Servono entrambi e non sono alternativi: il secondo previene la causa accertata, il primo rileva qualunque altra modalità di guasto.

### 3a. `Veeam-BackupFreshness.ps1` — misurare l'assenza di un successo

Il principio è misurare l'**assenza di un successo recente**, non la presenza di un errore. È una scelta deliberata: un monitor guidato dagli eventi è cieco ai guasti silenziosi, cioè servizio fermo, job disabilitato, attività pianificata cancellata, macchina spenta nella finestra di backup. Un monitor guidato dall'età li copre tutti.

La metrica primaria sono le ore dall'ultimo evento **`10010`**, cioè *restore point creato*.

**Perché non l'evento 190.** `190` significa "job terminato" e l'esito sta nel **livello** dell'evento, non nell'ID: filtrare su `190` senza guardare il livello classifica come riuscito anche un fallimento. C'è di più, ed è dirimente: il run risolutivo del 25/08 ha chiuso in **Warning**, per il reset del changed block tracking, pur avendo prodotto un restore point valido. Ancorare il monitor a `190` di livello Information avrebbe generato un falso allarme proprio sul run che aveva risolto il problema. `10010` misura il fatto che conta, cioè *esiste un restore point*.

| ID | Significato |
|---|---|
| `110` | job avviato |
| `190` | job terminato — **livello = esito** |
| `191` | terminato con errore, sarà ritentato |
| `10010` | restore point creato |
| `10050` | restore point rimosso per retention |
| `23050` / `23120` | job modificato / sorgenti aggiornate |

I controlli secondari sono quattro: esito dell'ultima sessione (`190`), **retry falliti nelle ultime 24 h** (`191`) con soglia 5, stato e tipo di avvio del servizio `VeeamEndpointBackupSvc`, e freschezza del log del job come riscontro indipendente dal registro eventi. Sul caso reale il controllo dei retry avrebbe allertato in **meno di un'ora** invece che dopo giorni.

Le soglie predefinite tengono conto di un job giornaliero più il margine per macchina spenta o run lungo.

```
WarnHours      = 30
CritHours      = 72
RetryWarnCount = 5
```

Due scelte di robustezza per la flotta. Il livello dell'evento è letto come **valore numerico** (`$_.Level`) e non come `LevelDisplayName`, che su un sistema in italiano restituisce "Errore", "Avviso" e "Informazioni" e romperebbe lo script su macchine con locale diverso: è una cautela che questo progetto conosce già, avendo un sistema operativo italiano. E se né il servizio né il canale eventi esistono lo script esce con `0` e un messaggio informativo, quindi è sicuro distribuirlo su tutta la flotta senza escludere le macchine prive di agent.

### 3b. `Disk-LayoutDrift.ps1` — prevenire la causa accertata

Salva una baseline dei GUID di volume dei dischi fissi e a ogni esecuzione la confronta. Se un GUID scompare o ne compare uno nuovo allerta **prima** che il job Veeam fallisca, e stampa la procedura di riallineamento.

La cartella della baseline è il parametro `-BaselineDir`, con default neutro `C:\ProgramData\WindowsStatus`: il percorso reale dell'organizzazione si passa al deploy e non vive in questo repository, che è pubblico.

Tre comportamenti da conoscere. I **dischi rimovibili sono esclusi** per `BusType` (USB, SD, MMC, Virtual), così collegare o scollegare un SSD esterno non genera falsi positivi; sulla macchina di riferimento questo esclude il disco esterno USB. Le partizioni prive di filesystem, cioè MSR e Reserved, non hanno volume e restano escluse naturalmente. Al primo avvio lo script crea la baseline ed esce `0`.

L'ultimo comportamento è il più importante e non è un difetto: **l'alert persiste fino a un `-Reset` esplicito**. Un riallineo automatico e silenzioso equivarrebbe a non avere il controllo.

```powershell
powershell -ExecutionPolicy Bypass -File Disk-LayoutDrift.ps1 -Reset
```

Il riallineamento va eseguito **dopo** aver sistemato il job, non prima: si apre Veeam Agent, si va su Edit Backup Job allo step Volumes, si spunta "Show system hidden volumes", si deselezionano e riselezionano i volumi dati per forzare la ri-enumerazione dei volumi di sistema, si verifica nello step Summary che i GUID scomparsi non compaiano più, si conclude con un run manuale e solo allora si lancia il `-Reset`. Il primo run dopo l'intervento rilegge tutto, perché il changed block tracking viene azzerato sul disco modificato.

---

## 4. Stato di collaudo (aggiornato)

Il materiale di origine dichiarava che gli script **non erano mai stati eseguiti**, essendo stati redatti in un ambiente senza PowerShell. Su questa macchina il collaudo è stato fatto, ed è il motivo per cui il caveat qui sotto è più corto dell'originale.

Entrambi gli script **passano il parse reale** di PowerShell (verificato il 2026-08-26 con `[Parser]::ParseFile`). `Veeam-BackupFreshness.ps1` è stato **eseguito** e ha girato correttamente in sola lettura.

L'esecuzione ha trovato e fatto correggere un difetto vero, che vale la pena registrare perché è del tipo che il documento originale indica come il peggiore. Il controllo secondario cercava i log del job con il pattern piatto `Job_*.log` nella cartella `C:\ProgramData\Veeam\Endpoint`, ma **Veeam Agent 13 li tiene in una sottocartella per job**, con nomi della forma `Job_<nome>\Job.Job_<nome>.Backup*.log`. Il pattern piatto non trovava mai nulla, perché `Job_<nome>` è una directory e non un file: il risultato era un verdetto **WARNING permanente su un backup perfettamente sano**, cioè il falso positivo che allena a ignorare gli alert. Corretto cercando in entrambe le disposizioni, quella a sottocartelle e quella piatta delle build precedenti; dopo la correzione il verdetto sulla macchina di riferimento è **OK con exit 0**.

`Disk-LayoutDrift.ps1` **non è stato eseguito**, per scelta e non per dimenticanza: creerebbe la baseline in `C:\ProgramData`, cioè scriverebbe fuori dal repository, e ricade nel paletto 1 di `CLAUDE.md`. È stata invece verificata in sola lettura la sua logica di enumerazione, replicandola senza scritture: rileva **7 volumi su disco fisso** con GUID ed esclude correttamente il disco esterno USB.

Restano validi i caveat che non era possibile chiudere qui. `Ninja-Property-Set` dipende da sintassi e versione dell'agent RMM ed è lasciato disattivato di proposito (`$WriteNinjaFields = $false`). La distinzione fine fra exit code 1 e 2 su livelli di severità diversi dipende dalla configurazione del tenant RMM: se non è supportata si usano due condizioni separate. E `Veeam-BackupFreshness.ps1` misura il restore point più recente **fra tutti i job** della macchina, che è corretto per un endpoint con un solo job ma va parametrizzato per nome job dove i job sono più di uno.

---

## 5. Deploy sull'RMM

Import come nuovo script PowerShell per Windows, con **Run As System**. I due script si tengono **separati** e non uniti, perché hanno cadenze e semantiche diverse.

| Script | Frequenza | Motivo |
|---|---|---|
| `Veeam-BackupFreshness` | ogni **4-6 h** | il valore misurato cambia una volta al giorno |
| `Disk-LayoutDrift` | **1 volta al giorno**, mattino | i cambi di layout avvengono al boot dopo un aggiornamento |

`Disk-LayoutDrift` va aggiunto **anche come azione post-patching**, subito dopo la finestra di aggiornamento: è il momento di massimo rischio, ed è esattamente quando l'incidente si è verificato.

Le condizioni di alert si configurano su exit code diverso da zero, dove `0` è OK, `1` è Warning e `2` è Critical. Opzionalmente si creano due custom field di dispositivo scrivibili da script, `veeamLastBackupHours` di tipo numerico e `veeamStatus` di tipo testo, e si porta `$WriteNinjaFields` a `$true`: dà una dashboard "ore dall'ultimo backup" ordinabile su tutta la flotta.

---

## 6. Cosa gli script NON fanno, e perché

**Non controllano i file `.vbk` e `.vib` sul repository di destinazione.** La ragione è precisa e vale la pena capirla, perché l'ipotesi opposta è quella che viene in mente per prima.

L'agent RMM gira come `LOCAL SYSTEM`, che non possiede le credenziali dello share di rete. Le credenziali dell'account di servizio del backup sono salvate **nella configurazione del job Veeam**, non nel credential store di Windows. Un `Get-ChildItem` verso lo share eseguito come SYSTEM da un endpoint fallirebbe per accesso negato, producendo **falsi positivi permanenti**: il peggior esito possibile, perché allena a ignorare gli alert.

Il controllo lato repository va quindi eseguito **dal NAS o da un host con accesso proprio allo share**, come attività separata. È lo stesso principio già adottato in `02_VEEAM_BACKUP_PORTABILITA.md`, dove il NAS è una sola copia e va completata.

---

## 7. Punti ancora aperti

**Verificare la catena sul NAS.** Non ancora fatto. Da un host con accesso allo share, cercando la sottocartella indicata dagli eventi `10010` e `10050`.

```powershell
Get-ChildItem "\\<ip-nas>\<share-backup>\<cartella-pdl>" -Recurse -Include *.vbk,*.vib,*.vbm | Sort-Object LastWriteTime -Descending | Select-Object Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}, LastWriteTime | Format-Table -AutoSize
```

Gli eventi citano un nome host **diverso** da quello attuale della macchina. *Inferenza da confermare guardando lo share, non un fatto accertato*: il PC è stato rinominato dopo la creazione della catena e Veeam mantiene il nome originale come identificativo del set di restore point.

**Notifiche email native di Veeam**, da attivare su failure *e* warning come secondo canale indipendente dall'RMM.

**Log eventi Veeam a 20 MB su tutta la flotta.** Il default è 1 MB: sulla macchina dell'incidente 400 eventi coprivano solo circa 36 ore, ed è il motivo per cui la storia del guasto era già stata sovrascritta quando la si è cercata. Da distribuire come script one-shot.

```powershell
wevtutil sl "Veeam Agent" /ms:20971520
```

**Verifica post-patching** dello stato dell'ambiente di ripristino sulle macchine con job a livello di volume, con `reagentc /info`.

---

## 8. Raccordo

Lo stato del backup e la sua freschezza vanno annotati nella sezione 11 di `01_MAPPA_CONFIGURAZIONE.md`, insieme al job. La strategia di backup e la portabilità stanno in `02_VEEAM_BACKUP_PORTABILITA.md`. Il monitoraggio della stabilità della macchina, che è la dimensione parallela a questa, sta in `07_SALUTE_E_STABILITA.md`. Gli alert `[VOLUMI]` e `[PARTIZIONI]` prodotti dal confronto alimentano la checklist di remediation descritta in `06_RACCORDO_CHECKLIST_VA.md`.
