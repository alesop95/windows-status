# 15 - Censimento hardware multipiattaforma

> Due strumenti di sola lettura che fotografano l'hardware e la configurazione di base di una macchina e producono un testo confrontabile fra macchine diverse e fra sistemi operativi diversi. Servono a censire un parco, non a tenere la storia di una macchina sola: quella e' il mestiere di `Snapshot-Stato.ps1`. Nessun dato reale di nessuna macchina entra in questo repository: gli output restano fuori da git.

## A cosa serve, e perche' non basta lo snapshot

`Snapshot-Stato.ps1` fotografa **questa** macchina in profondita', ricava la radice del progetto dalla cartella genitore, scrive in `snapshots\` e si confronta con se stesso nel tempo. E' lo strumento giusto quando la domanda e' "cos'e' cambiato qui dentro".

La domanda del censimento e' un'altra: "che cosa c'e' in quelle quindici macchine", comprese quelle su cui questo repository non c'e' e non ci sara'. Per rispondere serve uno strumento che si copi su una chiavetta o si incolli in un terminale, che non presupponga nulla di installato, che non scriva da nessuna parte e che produca un testo leggibile con gli occhi e confrontabile con `diff`. Da qui due file soli, autonomi, uno per famiglia di sistema operativo, con le **stesse sezioni nello stesso ordine**: identita', scheda madre e BIOS, CPU, memoria, dischi, rete, GPU, periferiche, software rilevante, utenti. Affiancando due output di piattaforme diverse le sezioni si corrispondono, ed e' questo che li rende confrontabili.

## Gli strumenti

`scripts\censimento\hw-report-windows.ps1` - macchine Windows. Da PowerShell **amministratore** sulla macchina da censire:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\hw-report-windows.ps1 > hw-<nome-macchina>.txt
```

Senza privilegi di amministratore mancano, in silenzio o con una riga di avviso, BitLocker, Secure Boot, i contatori di affidabilita' dei dischi e i numeri di serie dei banchi di memoria. Il file resta valido, ma e' un censimento parziale: vale la pena annotarlo accanto all'output.

`scripts\censimento\hw-report.sh` - macchine Linux. Da shell con `sudo`:

```bash
sudo bash hw-report.sh > hw-$(hostname).txt 2>&1
```

Lo script non installa nulla e sopravvive all'assenza dei comandi che usa: `dmidecode`, `smartctl`, `ethtool`, `lspci`, `lsusb`, `docker` e `psql` sono tutti invocati con l'errore silenziato, e la sezione corrispondente resta vuota invece di interrompere il giro. Un output con le sezioni di memoria e SMART vuote dice quindi due cose indistinguibili - strumento assente oppure privilegi insufficienti - e la differenza si risolve solo guardando la macchina.

Entrambi sono di **sola lettura**: nessuna scrittura su disco al di fuori della redirezione che si chiede esplicitamente, nessuna modifica al registro, ai servizi o alla rete. Rispettano il paletto 1 senza bisogno di conferme perche' non c'e' niente da confermare.

## Cosa esce, e come si confronta

L'output e' testo semplice, diviso da righe di separazione con il nome della sezione in chiaro. Due macchine della stessa famiglia si confrontano direttamente:

```bash
diff hw-macchina-a.txt hw-macchina-b.txt
```

Il confronto e' rumoroso per costruzione - numeri di serie, indirizzi MAC, tempi di accensione cambiano sempre - e questo e' voluto: lo strumento non decide cosa conti, lo decide chi legge. Per un confronto pulito conviene filtrare le righe volatili prima del `diff`, oppure leggere una sezione alla volta.

Fra Windows e Linux il `diff` non ha senso: li' si confrontano le sezioni a occhio, che e' il motivo per cui portano lo stesso nome.

## Dove vivono gli output, e perche' non qui

Gli output contengono numeri di serie di macchina, scheda madre, dischi e banchi di memoria, indirizzi MAC e IP, nomi degli account locali ed elenco dei programmi installati. Sono dati identificativi di macchine reali, e questo repository e' **pubblico**: non devono entrarci mai. `.gitignore` esclude per questo il modello `hw-*.txt` ovunque nell'albero, cosi' che un file prodotto per sbaglio dentro la cartella del progetto non finisca in un commit per distrazione.

Il posto degli output e' la cartella di censimento fuori dal repository, accanto agli altri documenti del parco macchine. Qui dentro vivono gli strumenti, non i risultati: e' la stessa regola che tiene `snapshots\` fuori da git.

## Rapporto con gli altri pezzi

Questi due script **non** fanno parte della catena locale dello snapshot, esattamente come quelli di `scripts\rmm\`: non ricavano la radice del progetto, non scrivono in `snapshots\`, non vengono chiamati da `Avvia.ps1`. Si differenziano da `rmm\` perche' non sono pensati per la distribuzione automatica come LOCAL SYSTEM, ma per l'esecuzione a mano su una macchina alla volta, spesso una macchina che non si rivedra'.

Il confine pratico e' questo: se la macchina e' questa, si usa `Snapshot-Stato.ps1`; se la macchina e' una qualunque delle altre e la si guarda una volta sola, si usa il censimento.
