# Leggimi — Windows da zero

> Dalla macchina appena accesa a una macchina pulita, con il software che serve, monitorata e fotografata. Questo file sta in radice perche' e' il primo che deve vedere chi apre la cartella su un PC nuovo. Il perche' di ogni scelta sta in `docs/16` (prima installazione) e `docs/17` (monitoraggio).

## In due righe

Si fa l'immagine della macchina vergine, si lancia `Avvia.ps1`, si segue la voce `P`. La catena fotografa, installa il software, toglie AI e bloatware, accende gli agenti di monitoraggio e rifotografa, chiedendo conferma a ogni passo. I riavvii li decidi tu.

Tempo realistico: **un'ora e mezza**, di cui la meta' e' attesa.

---

## Passo 0 — Cosa ti serve prima di cominciare

Tre cose, e due non possono stare nel repository.

1. **Il progetto.** `git clone https://github.com/alesop95/windows-status.git`, oppure una copia su chiavetta.
2. **Gli strumenti di terze parti**, circa 160 MB. Si scaricano al volo (serve rete) oppure si portano gia' verificati.
3. **`software_winget.json`**, solo se vuoi reinstallare i programmi di una macchina vecchia. Nasce da uno snapshot di *quella* macchina e `snapshots/` e' ignorata da git: va copiato a mano.

Dalla macchina vecchia, un comando prepara tutto:

```powershell
.\scripts\Prepara-Chiavetta.ps1 -Destinazione E:\
```

Sul PC nuovo quella cartella basta a se stessa: niente rete, niente git.

**Se vuoi anche il monitoraggio**, serve una macchina che faccia da hub: un fisso dell'ufficio, una macchina virtuale o il server Linux. Si prepara una volta sola per tutto il parco (vedi il passo 9) e poi non si tocca piu'.

---

## La sequenza

```powershell
# PowerShell COME AMMINISTRATORE, nella cartella del progetto
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Avvia.ps1
```

| # | Passo | Voce | Dura | Automatico? |
|---|---|---|---|---|
| 1 | Copiare il progetto sul PC | — | 2 min | no |
| 2 | **Immagine di sistema della macchina vergine** | — | 20 min | no, e non si salta |
| 3 | Preparare il profilo delle scelte | — | 5 min, una volta sola | no |
| 4 | Piano e prerequisiti | `9` | 10 sec | si, sola lettura |
| 5 | Scaricare e verificare gli strumenti | `9s` | 3 min | si, sola lettura |
| 6 | Catena: fotografia, paracadute, software, AI | `9a` | 20 min | guidato, conferma per passo |
| 7 | **Riavvio** | — | 2 min | no, mai automatico |
| 8 | Catena: debloat, metriche, log | `9a` | 10 min | guidato, conferma per passo |
| 9 | **Riavvio** | — | 2 min | no |
| 10 | Controllo residui e confronto delle due fotografie | `9c` | 5 min | si, sola lettura |
| 11 | Reinstallare i programmi della macchina vecchia | `5` | variabile | serve `software_winget.json` |
| 12 | Baseline di sicurezza: prima il report, poi applicarlo | `3` poi `4` | 15 min | guidato |
| 13 | Identita' git, chiavi SSH, Claude e Codex, dotfiles | — | 15 min | no, per scelta |

La voce `P` stampa questa sequenza con lo stato di ogni passo, cosi' non si perde il conto fra i due riavvii. Distingue tre cose: `[x]` fatto, `[ ]` da fare, `[?]` **non verificabile da qui** — l'immagine Veeam resta sempre `[?]`, perche' nessuno script puo' sapere se l'hai fatta.

Il passo 13 non e' automatizzabile **per costruzione**: il paletto 5 vieta i segreti nel repository, quindi non c'e' niente da ripristinare da solo. `docs/03`, `04` e `10` dicono dove sono custoditi e in che ordine rimetterli.

---

## Passo 3 — Il profilo, cioe' le scelte prese una volta sola

Senza profilo, ogni strumento apre la propria interfaccia e su ogni PC si rifanno le stesse scelte a mano, col rischio che la decima macchina non sia come la prima.

```powershell
copy .\scripts\prima-installazione\profilo.esempio.json .\scripts\prima-installazione\profilo.json
notepad .\scripts\prima-installazione\profilo.json
```

Quattro blocchi da compilare:

```
applicativi   quali programmi installare, con winget (consigliato) o Ninite
ai            quali rimozioni AI fare
debloat       cosa togliere e cosa sistemare dell'interfaccia
monitoraggio  windows_exporter: acceso o no, e quale macchina e' l'hub
log           Grafana Alloy: acceso o no, e dove sta Loki
```

Il profilo toglie le interfacce di terze parti. **Non toglie le conferme**: ogni passo che modifica chiede `SI`, perche' quello e' il paletto 1. `profilo.json` e' ignorato da git.

---

## Cosa fa davvero la catena (passi 6 e 8)

| Fase | Strumento | Licenza | Reversibile? |
|---|---|---|---|
| `SNAPSHOT` | `Snapshot-Stato.ps1` del progetto | — | sola lettura |
| `PARACADUTE` | punto di ripristino + conferma sull'immagine | — | — |
| `APPLICATIVI` | winget, oppure Ninite | winget: MIT | si |
| `AI` | RemoveWindowsAI | MIT | **solo in parte** |
| `DEBLOAT` | Win11Debloat | MIT | si |
| `MONITORAGGIO` | windows_exporter | MIT | si |
| `LOG` | Grafana Alloy | Apache-2.0 | si |
| `CONTROLLO` | seconda fotografia + `Compare-Snapshot.ps1` | — | sola lettura |

Ogni strumento e' appuntato a una versione precisa e **verificato per digest** prima di essere eseguito. Se un digest non corrisponde la catena si ferma, e va bene cosi': vuol dire che il progetto a monte e' cambiato o che il file e' stato alterato. La risposta non e' aggiornare il manifesto, e' guardare perche'.

---

## Passo 9bis — L'hub del monitoraggio, una volta per tutto il parco

Sui PC stanno solo i due agenti: `windows_exporter` (11 MB) per le metriche e Alloy (107 MB) per i log. Archivio e cruscotti stanno su **una** macchina:

```powershell
# sulla macchina hub
.\scripts\Monitoraggio-Centrale.ps1                                  # piano
.\scripts\Monitoraggio-Centrale.ps1 -Scarica                         # ~630 MB
.\scripts\Monitoraggio-Centrale.ps1 -Installa -Macchine pc01,pc02
```

Monta Prometheus (metriche), Loki (log) e Grafana OSS (la console), genera le configurazioni dall'elenco delle macchine e lascia quattro cose da fare a mano in Grafana, che elenca a fine corsa. Tutto aperto, tutto locale: **nessun account, nessun token, nessun limite di nodi, niente che esca dalla rete.**

Se l'hub e' un Linux, li' Prometheus, Loki e Grafana sono pacchetti con il loro servizio e si usa quella via: le configurazioni generate qui si copiano tali e quali.

---

## Le cinque cose da sapere prima di premere invio

**1. RemoveWindowsAI e' reversibile solo in parte.** La catena gli passa sempre `-backupMode`, che esporta le chiavi dei servizi cancellati e crea un punto di ripristino, e il suo `-revertMode` le rimette. Ma i pacchetti rimossi — appx, CBS, file — non li salva nessuno. Per quelli il ritorno indietro e' l'immagine del passo 2. **Per questo il passo 2 non si salta.**

**2. Ninite e' comodo ma non e' appuntabile, e non e' open source.** Due download della stessa selezione hanno digest diversi (misurato), e installa sempre le ultime versioni: la stessa riga oggi e fra un mese non produce lo stesso PC. Nel profilo il predefinito e' winget. Se usi Ninite lo stesso, la catena verifica la firma Authenticode e stampa il digest della copia eseguita, da annotare nel changelog.

**3. Su macchina aziendale la catena si ferma.** Dominio, tenant o MDM: serve `-ForzaAziendale`, perche' le opzioni degli strumenti toccano Windows Update, telemetria e cifratura automatica, cioe' cio' che il paletto 4 vieta senza un ordine esplicito.

**4. Netdata non e' nella catena Windows, ed e' una scelta.** Il codice e' GPL-3.0, ma la sua pagina di installazione Windows dichiara che nel piano gratuito il cruscotto locale e' bloccato e i dati si guardano sul loro cloud. Su Linux invece e' aperto davvero e resta la scelta migliore: vedi `docs/17`.

**5. Le porte nuove vanno strette.** `windows_exporter` ascolta sulla 9182 e la catena la apre **solo** verso l'hub, non verso la rete. Alloy non apre niente, perche' spinge lui. Sull'hub: Grafana 3000 a chi deve guardare, Prometheus 9090 solo locale, Loki 3100 raggiungibile dai PC.

---

## Se qualcosa non torna

| Sintomo | Cosa vuol dire |
|---|---|
| un digest non corrisponde | il progetto a monte e' cambiato, o il file e' stato alterato. Si guarda perche', non si aggiorna il manifesto |
| la catena rifiuta di partire | macchina a dominio, tenant o MDM; oppure non sei amministratore |
| l'antivirus segnala RemoveWindowsAI | falso positivo noto e dichiarato dall'autore |
| `9c` trova residui AI | normale: una parte non si tocca da script, e un aggiornamento di Windows puo' rimettere qualcosa. Rifai `9c` dopo il primo Patch Tuesday |
| in Grafana non si vede la macchina | controlla `http://hub:9090/targets`; se e' `DOWN`, la regola firewall della 9182 non lascia passare l'hub |
