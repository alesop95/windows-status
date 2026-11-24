# 11 — Orchestrazione di piu' agenti da terminale su Windows 11


## 16/11/2026 - Unita recuperate e sessione NAS corroborata, verifica senza ricollegamenti

Il recupero di unità persistenti e il collaudo dei diritti sono passaggi separati. Dopo un recupero riuscito, verificare sulle connessioni correnti senza scollegarle nuovamente: il modo di verifica deve rifiutare unità non attive e non deve mai chiamare cancellazione o recupero. Corroborare dal servizio remoto identità e ora della sessione quando disponibile. Una prova di accesso alla radice non equivale a lettura/scrittura/rimozione o al rifiuto delle altre risorse. Tutti i valori e riscontri restano nel progetto proprietario; nessuna credenziale nella ricetta di macchina.


## 16/11/2026 - Recupero delle unita salvate ma Unavailable, senza disconnessioni

Una voce SMB persistente può esistere con stato Unavailable: non equivale a una connessione ripristinata. Provare la funzione di recupero con questo stato reale e verificare connessione, radice e profilo. Un ripristino fallito non va ripetuto automaticamente nel finally: registrare il codice Windows e preservare le altre unità. Separare il recupero senza disconnessioni dal collaudo positivo/negativo. Distinguere anche account del processo padre, elevazione del figlio e privilegi dell’apparato remoto: il nome utente da solo non decide quale token stia eseguendo la prova. Nessuna credenziale viene acquisita o copiata nella ricetta di macchina.


## 16/11/2026 - Enumerazione connessioni nel logon standard dopo Accesso negato

Una query di gestione SMB può essere negata nel token standard mentre la mappatura resta disponibile. Verificare realmente ogni capacità nel contesto in cui sarà usata. WNetOpenEnum con RESOURCE_CONNECTED enumera soltanto le connessioni del logon corrente: non sostituirlo con RESOURCE_GLOBALNET o con una query amministrativa. Errori o omissioni rispetto alle unità attive bloccano il collaudo; non vanno trattati come assenza di connessioni. Le prove sulle cartelle restano nel token della persona, senza elevazione; dati e policy degli apparati restano nel progetto proprietario.


## 16/11/2026 - Corretto il preflight UNC dopo il rifiuto sulla postazione

Un controllo UNC è fallito in esercizio benché la suite fosse verde: le prove usavano un elenco vuoto di mappature e saltavano il riconoscimento del server. Le prove devono includere percorsi della destinazione e di altri apparati, casi con sottocartelle e nomi simili, e verificare il motivo del rifiuto. Il parser PowerShell non verifica le regex compilate a runtime. Per il confronto degli host UNC è sufficiente separare i componenti e confrontare il nome esatto. Il rifiuto precedente alle disconnessioni va distinto da una verifica degli accessi riuscita; dopo la correzione serve ancora il rapporto della postazione.


## 16/11/2026 - Collaudo SMB nel token standard preparato per il pilota

Il collaudo SMB dalla console RMM deve usare il token standard del desktop. Prima di ricollegare si confermano file chiusi, identità, unità vive e salvate; si esclude ogni connessione di servizio o di altri apparati. WNetCancelConnection2 con flag zero mantiene il profilo e Force false rifiuta file o lavori aperti. Verificare lettura/scrittura/rimozione con file temporanei univoci e distinguere accesso negato da errori di rete. Una sequenza fallita non viene ripetuta automaticamente; mappature previste e diagnosi devono rimanere recuperabili. Il progetto proprietario conserva strumenti, policy e riscontri; qui resta soltanto la procedura astratta.


## 16/11/2026 - Declassamento pilota e otto divieti verificati sul NAS

Il primo collaudo reale del percorso nativo conferma due operazioni dipendenti con diari separati e logout: diritto personale e rimozione di una sola appartenenza. Una rilettura indipendente delle API conferma lo stato finale e la conservazione degli altri principali. Questo non chiude da solo il collaudo SMB sulla postazione: una sessione già autenticata può conservare il contesto precedente. Prima di ricollegare si coordina la chiusura dei file, si opera nel token standard della persona e si conservano connessioni degli altri apparati e identità di servizio. Nessun dato organizzativo o credenziale viene trasferito nella ricetta di macchina.


## 16/11/2026 - Lettura nativa collaudata e sette restrizioni personali verificate

Un successo puntuale dell’API non dimostra che gli altri permessi siano rimasti invariati: rileggere e confrontare l’intera lista dei principali e l’accesso guest. Un marcatore di conversione ACL in corso richiede una nuova lettura dopo il completamento, senza ripetere la scrittura. Se una modifica parziale MCP fallisce su una voce preesistente non risolvibile, non eliminarla per sbloccare il comando: conservare prima/dopo e verificare un metodo nativo che operi sul solo principale richiesto. Operazioni dipendenti hanno piani, digest e diari distinti e la seconda parte soltanto se la prima è verificata. Password effimera in console e sessioni proprie da chiudere; nessuna copia di credenziali nelle diverse radici agente. Questa è una procedura astratta: i valori e i rapporti degli apparati restano nel progetto proprietario.


## 16/11/2026 - Lettura nativa QTS predisposta, login operativo da collaudare

Per integrare API native di un apparato quando un server MCP non espone una funzione, verificare la copertura del catalogo prima di dedurla dai privilegi della credenziale. Un client diverso non aggiunge funzioni al server. Il primo collaudo autenticato deve essere una lettura: URL HTTPS esplicito e certificato verificato prima delle credenziali, nessun redirect, password chiesta in console con input nascosto e sessione propria da chiudere. Password e SID non entrano in file, argomenti o rapporti. Il progetto tecnico conserva strumenti e prove; il progetto di macchina documenta soltanto il metodo generale. Le radici multiple degli agenti non richiedono di copiare password tra account. Nessuna configurazione di un nuovo apparato o di account viene dichiarata eseguita da questa nota.


## 16/11/2026 - Mappatura dalla console RMM nel token standard, senza desktop remoto

Per creare un’unità visibile all’utente da una console RMM elevata si usa un’attività a richiesta con LogonType Interactive e RunLevel Limited. Computer, SID e sessione del processo devono corrispondere al desktop attivo; non basta eseguire il comando come SYSTEM o come amministratore dello stesso account. Nessuna password memorizzata nell’attività. Verificare lettera, mappature vive e salvate prima di cambiare rete.

Il caso è stato collaudato con diciassette prove offline, tre mutazioni e una ispezione locale reale nel token standard, senza creare unità. I rapporti contengono campi primitivi selezionati, senza serializzare interi oggetti dei provider. Questa nota descrive il metodo generale e non installa strumenti o mappature su questa macchina. Nessun endpoint, account o percorso aziendale è riportato.

Fonti: [contesto di sicurezza delle attività](https://learn.microsoft.com/en-us/windows/win32/taskschd/security-contexts-for-running-tasks), [principal Interactive/Limited](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtaskprincipal), [mappatura SMB persistente](https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbmapping), [contesto elevato della CLI RMM](https://www.ninjaone.com/docs/endpoint-management/scripting-and-automation/command-line-interface-cli/using-command-line-interface-cli/). Il collaudo locale dimostra il passaggio al token; non sostituisce la prova della mappatura sul pilota.

Questa macchina ospita due flotte di agenti da terminale, censite nella scheda 10: tre radici Claude Code e tre radici Codex, isolate e ripristinabili. Questa scheda copre il livello sopra: **quali strumenti permettono di far lavorare piu' agenti in parallelo**, quali sono compatibili con questa macchina e quali no, e come si installano.

Il criterio di *quando* convenga farlo non sta qui: e' materia di disciplina di progetto e vive nel template. Qui sta solo cio' che impatta il setup di Windows.

Rilievo del 2026-09-21, aggiornato il 2026-10-16 per Nimbalyst (sezione 2, installazione e uso).

---

## 1. Il vincolo che esclude meta' del panorama

Quasi tutti gli orchestratori di agenti nascono su Unix e si appoggiano a **`tmux`**, il multiplexer di terminale, per tenere vive piu' sessioni. Il loro installer manda gli utenti Windows su **WSL**, e per questa macchina WSL e' gia' stato valutato e scartato, per una ragione documentata nella scheda 10: i progetti vivono su `D:\` ed `E:\`, e dentro WSL quei percorsi diventano `/mnt/d` e `/mnt/e`. Le regole di sandbox, i percorsi nei file di configurazione e i prefissi del wipe divergerebbero dai percorsi reali.

> **Correzione registrata.** La prima stesura di questa scheda affermava che `tmux` non ha alcun port nativo Windows, e su quella base escludeva d'ufficio ogni strumento che lo richiede. **E' falso.** Esiste **`psmux`**, tmux nativo per Windows senza WSL e senza Cygwin, che legge un `.tmux.conf` esistente e dichiara supporto di prima classe per le agent team di Claude Code in pannelli separati. Era **gia' censito nel catalogo dei pacchetti del template**, e non era stato guardato prima di scrivere: e' un'istanza esatta del principio della sezione 20 del sistema di progetto, cioe' guardare che cosa esiste gia' prima di concludere.
>
> La conseguenza e' che la regola di selezione **non e' "niente tmux"**, ma quella qui sotto.

**La regola corretta: su questa macchina si adottano solo strumenti che girano nativi, senza WSL.** Uno strumento che richiede `tmux` non e' escluso in partenza: e' condizionato all'adozione di `psmux`, che aggiunge una dipendenza da valutare per conto proprio.

Il perimetro della regola va detto per intero, perche' dal 2026-10-20 il censimento registra un componente che dentro WSL ci vive davvero: colibri, il motore di inferenza su CPU descritto nella sezione 7 di `docs/09`. Non e' una contraddizione, perche' questa regola nasce dai percorsi dei progetti su `D:\` ed `E:\` e riguarda gli strumenti che quei progetti li aprono davvero, mentre colibri riceve lotti di lavoro e risponde su HTTP senza vedere nessun percorso di progetto. La formulazione esatta e' quindi che non si adotta WSL per gli strumenti che lavorano sui progetti; un servizio che gira per conto proprio dentro la distribuzione e' un'altra cosa, e si censisce in `docs/09`.

### Strumenti esaminati

| Strumento | Esito |
|---|---|
| **Nimbalyst** | **adottabile.** Nativo Windows, nessuna dipendenza Unix. Vedi sezione 2 |
| **Claude Squad** | **condizionato.** Richiede `tmux`, quindi presuppone `psmux`. Da valutare solo se Nimbalyst si rivela insufficiente: due dipendenze invece di una, per un beneficio che si sovrappone |
| **Conductor** | escluso, solo macOS |
| **Crystal** | escluso, deprecato a febbraio 2026 con redirezione al successore |

Vengono elencati non per completezza ma perche' sono i primi risultati di qualunque ricerca sull'argomento: senza questa tabella, ogni volta che qualcuno riapre il tema li rivaluta da capo.

---

## 2. Nimbalyst, l'unico candidato compatibile

E' il successore di Crystal. Applicazione desktop, **nativa Windows**, e fa girare in parallelo **Claude Code, Codex, OpenCode e Copilot**, ciascuno in un **worktree git isolato**.

| Voce | Valore rilevato |
|---|---|
| Licenza | MIT, gratuita per uso individuale |
| Piattaforme | Windows 10+, macOS, Linux |
| Agenti | Claude Code, Codex, OpenCode (alpha), Copilot (alpha) |
| Isolamento | worktree git per sessione |
| Maturita' | circa 1.800 stelle e 575 issue aperte al 2026-09-21; circa 1.900 stelle al 2026-10-16 |
| Versione | 0.79.1 disponibile al 2026-10-16, rilascio del 30 settembre 2026; su questa macchina installata la 0.77.5 |
| Pacchetto winget | `Nimbalyst.Nimbalyst`, editore Nimbalyst Inc. |

Il numero di issue aperte va letto per quello che e': **e' un progetto giovane**, non uno strumento assestato. Va adottato sapendo che puo' rompersi, e mai come unico modo di arrivare al proprio lavoro.

### Il caveat che conta piu' della licenza

Il client e' MIT, ma **il server di sincronizzazione della collaborazione e' un progetto separato, con licenza diversa**, e punta a un endpoint di terze parti (`wss://sync.nimbalyst.com`). Esiste inoltre un'app mobile companion.

Su una macchina che ospita repository di clienti, attivare la sincronizzazione significa **mandare materiale di terzi a un servizio esterno non governato da alcun accordo**. Vale la stessa disciplina applicata altrove in questo progetto: si usa in **modalita' locale**, senza collaborazione ne' companion mobile, e la scelta va verificata nelle impostazioni dopo l'installazione, non assunta.

### Installazione e aggiornamento

La via preferita e' winget, che verifica da se' l'impronta SHA-256 dell'installer contro quella del manifest prima di eseguirlo: e' la stessa catena di custodia che la prima stesura di questa scheda chiedeva di fare a mano, e la rende automatica. Il rilievo del 2026-10-16 ha trovato l'applicazione gia' installata in `%LOCALAPPDATA%\Programs\Nimbalyst`, versione 0.77.5, con la 0.79.1 disponibile.

```powershell
winget list --id Nimbalyst.Nimbalyst
winget upgrade --id Nimbalyst.Nimbalyst
```

Su una macchina dove non c'e', il primo comando non trova niente e l'installazione e' `winget install --id Nimbalyst.Nimbalyst`. Resta valida la via manuale dalla pagina delle release del repository `nimbalyst/nimbalyst`, con il confronto del digest prima dell'esecuzione: se non coincide, o se la release non pubblica digest, non si esegue.

Dopo l'installazione, prima di aprire un progetto reale, si verificano quattro cose: che i dati d'uso anonimi siano spenti in *Settings > Application > Advanced > Analytics*; che non ci sia un account Nimbalyst, ne' un team, ne' l'app mobile collegata, perche' la sincronizzazione passa dal servizio del produttore; che l'estensione *Crew*, agenti autonomi a turni entro un budget di token introdotti con la 0.79.1, resti spenta; e che i provider in *Settings > Application > AI Providers* usino l'account Claude e l'account Codex attesi, perche' il login dell'applicazione e' un asse distinto dalle radici della scheda 10.

### Come si usa

Il recap d'uso completo vive nel template di sistema, nel pacchetto `nimbalyst` (`.claude/templates/nimbalyst/README.md`), che e' la copia da aggiornare: qui ne resta l'essenziale. Un progetto e' una cartella aperta dal *Project Manager* (`Ctrl+P`). *Files* (`Ctrl+E`) lavora su un file con l'agente accanto e mostra le sue modifiche come differenze da accettare una per una; *Agent* (`Ctrl+K`) avvia e riprende le sessioni; `Ctrl+Shift+K` apre la bacheca delle sessioni. Una sessione isolata su un ramo nuovo si apre con *New Worktree* (`Ctrl+Alt+W`), che richiede la *Developer Mode* e un repository git, e si fonde nel ramo principale dal pannello della sessione. Il commit fatto dall'applicazione segue comunque l'identita' git locale del repository, come da paletto 8.

---

## 3. Che cosa Nimbalyst risolve e che cosa no

Risolve l'**isolamento del filesystem**: piu' agenti sullo stesso repository si pestano i piedi con rami e modifiche non salvate, e i worktree danno a ciascuno la propria cartella condividendo una sola storia git. Risolve anche la **navigazione**, cioe' il problema pratico di non perdere di vista cinque sessioni aperte.

**Non risolve il problema che conta**, che e' *quando* convenga avviare piu' agenti e *quanto* costi. Nessuno degli strumenti esaminati lo fa: sono tutti lanciatori, danno la leva e non il criterio. Quel criterio e' disciplina di progetto e vive nel template, non qui.

**Non e' un prerequisito.** Due agenti collaborano benissimo senza alcun orchestratore, scambiandosi lavoro attraverso file nel repository. Nimbalyst e' comodita', non infrastruttura, e va adottato in quest'ordine: prima il metodo, poi eventualmente lo strumento che lo rende piu' comodo.

---

## 4. Impatto sul ripristino della macchina

Nimbalyst e' un'applicazione desktop installata, quindi rientra fra i componenti da reinstallare dopo una formattazione, non fra quelli ricostruibili da `Installa-Agenti.ps1`. Va censita fra il software riproducibile allo stesso titolo degli altri eseguibili presi da GitHub.

Le due flotte di agenti restano invece ricostruibili da script, come da scheda 10: Nimbalyst le **usa**, non le fornisce, e la sua assenza non impedisce di lavorare.
