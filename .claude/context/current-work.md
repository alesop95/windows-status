---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: 9407b27
status: caratterizzazione completa; debloating in analisi a secco
---

## 19/11/2026 - Visualizzazione del promemoria locale confermata

L’attività singola con utente interattivo e privilegi limitati ha richiesto una notifica Windows all’ora prevista; l’utente conferma di averla vista. Il diario tecnico prova la richiesta, la risposta dell’utente ne conferma la visualizzazione: sono evidenze distinte. La scomparsa del pop-up non annulla il lavoro remoto e non richiede di ricreare l’attività. Il promemoria resta separato dall’esecuzione e dalle notifiche del servizio ricordato. Nessun dettaglio di progetto, account remoto o credenziale trasferito qui. **Template:** nessuna.

## 18/11/2026 - Promemoria temporanei legati all’utente Windows

Per un promemoria esplicitamente richiesto è stata usata un’attività Windows singola, Interactive e Limited, senza password, con StartWhenAvailable e senza WakeToRun. L’azione mostra una notifica locale; dipende dalla disponibilità del PC e della sessione dell’utente, distinta da un promemoria cloud. Non esegue connessioni o controlli sul servizio remoto.

Il codice e i dettagli della singola attività appartengono al progetto che la richiede; qui resta soltanto la ricetta. La creazione di un nuovo account Claude/Codex non duplica queste attività: le radici agente dello stesso utente Windows condividono la sessione, mentre un altro utente Windows richiede una propria configurazione autorizzata. Nel ripristino non ricreare scadenze già passate. Annullamento: eliminare soltanto l’attività nominata nel registro privato del progetto proprietario, mai usare cancellazioni per prefisso. Nessun pacchetto, credenziale cloud o profilo agente installati.

Riferimento: [impostazioni delle attività pianificate Microsoft](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset?view=windowsserver2025-ps). La registrazione è stata riletta; l’avviso è futuro e la visualizzazione non è ancora confermata.

## 17/11/2026 - Ricetta generica Graph ed Exchange registrata

Aggiornata docs/09_TOOLCHAIN_DA_ALTRI_PROGETTI.md con i moduli PowerShell già rilevati nel profilo corrente e la separazione fra identità Windows, account agente, client amministrativo e app del servizio. Consenso organizzativo persistente distinto dalla cache di processo; chiave privata sul runtime, permessi di posta limitati e prova dentro/fuori prima della ricezione. Nessun dato aziendale, certificato operativo, ID, casella o credenziale acquisiti qui; nessuna installazione, login aggiuntivo o modifica al sistema. Il bootstrap di un nuovo account agente non deve creare app cloud o propagare privilegi.

Il controllo di ripresa segnala riferimenti Git preesistenti non più validi in sei schede: non sono stati riscritti o dichiarati riconciliati. La nuova voce deriva da lettura diretta dei moduli e dalla procedura generica; il resto delle modifiche già presenti è stato conservato.

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


## 13/11/2026 - Roadmap canonica con collegamento Desktop ed export ISO mantenuto

Quando una pagina HTML locale è generata da un progetto, il Desktop può conservarne soltanto un Internet Shortcut verso il file canonico. Il generatore deve aggiornare il file del progetto e verificare il target del collegamento; una copia Desktop precedente va conservata prima della rimozione. Un collegamento omonimo verso un altro target non viene sovrascritto. Eventuali export di archivio restano una scelta distinta e dichiarata. La procedura è stata provata con sette casi isolati e tre mutazioni; percorsi e contenuti reali rimangono nel progetto proprietario.

Per una nuova unità di rete richiesta all’utente, il preflight RMM ha confermato una console elevata nella stessa sessione dell’Explorer dell’utente. La creazione e la verifica devono avvenire nel contesto standard reale; l’assenza della lettera nelle liste del token elevato non autorizza a sostituire connessioni esistenti. La mappatura richiesta rimane da eseguire e collaudare. Questo progetto non conserva nomi, share o credenziali dell’organizzazione.


## 13/11/2026 - Archivio storico confermato e richiesta una nuova unità visibile

Per rendere una nuova unità di rete visibile nella sessione della persona non basta creare la connessione come SYSTEM o nel token elevato del terminale RMM. Prima si rilevano elevazione, sessione del processo, proprietario/sessione di Explorer e lettere occupate; la mappatura persistente deve poi essere eseguita e verificata nel contesto della persona. Una lettera proposta non viene usata senza verificare che sia libera. Le unità esistenti restano la baseline da preservare.

La procedura di esecuzione non è ancora collaudata: è in corso il preflight dell’endpoint nel progetto proprietario della rete. Non sono stati creati mapping globali, attività pianificate, credenziali o nuove connessioni sulle postazioni. Questo documento conserva soltanto il metodo; nomi, percorsi, lettere e risultati aziendali rimangono nel dossier privato del progetto di rete. Riferimenti: [separazione delle mappature fra token](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/mapped-drives-not-available-from-elevated-command), [New-SmbMapping](https://learn.microsoft.com/en-us/powershell/module/smbshare/new-smbmapping) e [principal interattivi delle attività Windows](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtaskprincipal). La scelta di un’attività temporanea è soltanto un’alternativa tecnica studiata, non una modifica eseguita.


## 13/11/2026 - Pilota SMB via NinjaOne e ricaricamento delle sessioni agenti

Il ricaricamento di un nuovo strumento MCP riguarda il processo Claude Code o Codex CLI già aperto sul progetto. Quando si torna a quel progetto si apre una nuova sessione dal launcher abituale; non occorre rifare il login di un account già autenticato. Il login personale è un passaggio distinto, necessario quando si crea un account nuovo. Il riavvio dei client non è un requisito per proseguire una conversazione che non deve usare subito il nuovo strumento.

Per il censimento delle cartelle di rete via RMM si distinguono mappature persistenti, connessioni SMB attive e viste dei token. La console NinjaOne Logged-in user è elevata secondo la documentazione del prodotto e può non vedere le unità della sessione standard. Una lettura di Get-SmbConnection restituisce UserName e Credential, che possono differire: il campo Credential identifica l’account usato, senza contenere la sua password. Un risultato vuoto non certifica assenza di uso o di permessi. Nessun dato delle postazioni o dei NAS viene copiato qui; fonti e procedura operativa rimangono nel progetto proprietario.


## 13/11/2026 - QuLog e HBS interrogabili e nuovi account predisposti

Gli installatori del pacchetto agenti-terminale consultano ora il registro privato opzionale `%LOCALAPPDATA%/agenti-terminale/progetti.json`. Il registro contiene percorsi di progetti già autorizzati e nomi dei server attesi, senza token o identità aziendali. Vale sia per la catena del template sia per scripts/Agenti.ps1 di questa macchina. Codex riceve la fiducia per i soli progetti registrati; Claude verifica le definizioni e le abilitazioni condivise del progetto. Un conflitto di fiducia blocca l’aggiunta. Login per account e dialogo iniziale del client restano distinti. Nessuna credenziale viene copiata fra radici.

Il punto d’ingresso della macchina accetta ora -Claude e -Codex come liste tipizzate indipendenti. Per esempio, scripts/Agenti.ps1 verifica -Claude 4 -Codex 4 prepara il riscontro per due nuove radici; installa con gli stessi parametri esegue la creazione e il provisioning. Questi sono esempi, non account aggiunti alla macchina durante il collaudo. Se il registro esiste serve Python 3.11 o successivo. Il registro reale è stato configurato privatamente e ne è conservata una copia di consegna in _notes/configurazione-agenti/. Le radici esistenti non sono state reinstallate con Forza.

La capacità NAS di progetto comprende ora QuLog e HBS: configurazione dei log, eventi, accessi, sessioni, destinazioni, elenco dei job e dettaglio/storico tramite getter revisionati. Credenziali di lettura e manutenzione rimangono separate. Elenco completo dei job, storico completo e backup ripristinabile sono tre verifiche diverse; nomi, destinazioni, risultati e prove restano nel progetto proprietario. Nessun valore aziendale viene conservato qui.

Sessantasette prove offline e 23 sottoprove passano con Ruff verde. Una prova esegue l’installatore Codex reale su profilo temporaneo senza creare auth.json; un’altra verifica la selezione degli account dal punto d’ingresso della macchina. Le mutazioni rilevano la mancata eredità del progetto e due regressioni del lettore NAS. Le definizioni MCP di progetto sono documentate da [Claude](https://code.claude.com/docs/en/mcp) e [Codex](https://developers.openai.com/codex/mcp); il registro e la sua applicazione sono capacità interne del template. Resta necessario il ripristino separato dei progetti e dei relativi segreti dopo una formattazione.


## 13/11/2026 - Seconda credenziale NAS di manutenzione acquisita

Acquisita nel progetto proprietario una seconda credenziale NAS di manutenzione, distinta da quella di lettura, e verificato il relativo catalogo HTTPS. Le definizioni di progetto già collaudate nei tre account Claude e nei tre Codex non richiedono di copiare il token nelle radici account.

Il numero di funzioni può differire fra apparati: si confrontano le definizioni effettivamente restituite senza dedurre dalla sola quantità pacchetti installati, categorie scelte o diritti esercitabili. La modalità di manutenzione dichiarata dall’operatore resta distinta dalla verifica del catalogo; nessuna scrittura reale è stata collaudata. Il completamento delle credenziali rimane in corso nel progetto proprietario, che conserva valori, identità e prove. Nessun dato aziendale aggiunto qui.


## 13/11/2026 - Connessione Claude verificata nelle tre radici account

La verifica nativa del collegamento MCP di progetto risulta Connected nelle tre radici Claude Code. Copre avvio e handshake del server stdio locale, senza interrogare gli apparati. Rimane distinta dalla verifica dei dati reali già raccolti attraverso il server risolto dalle configurazioni dei tre account Codex.

Un errore EPERM di uv_spawn nel sandbox indica che il processo figlio non è partito: non dimostra da solo un difetto del server o delle credenziali remote. La verifica autorizzata fuori sandbox ha funzionato con la stessa definizione. Gli hook di fine sessione sono stati disabilitati soltanto nel processo diagnostico tramite impostazione temporanea, senza cambiare la configurazione salvata o eseguire la pulizia degli store. Le sessioni già aperte devono ricaricare il server di progetto. Token di lettura e di manutenzione restano separati; una modifica reale rimane da collaudare. Dati e prove degli apparati rimangono nel progetto proprietario.


# Lavoro in corso

> La fonte di verità su cosa è fatto resta `memory/index.md` e il work-log, non le spunte qui.

## Caratterizzazione di sicurezza — COMPLETATA (2026-06-10)

Tutte le feature di caratterizzazione sono implementate, collaudate e nel work-log (`memory/progress.md`): superficie d'attacco e persistenza, alert di sicurezza nel Compare, postura hardware/OS, snapshot multi-profilo Claude, AV registrati, Defender e policy in profondità, catena di fiducia, export ripristinabili, ambiente utente esteso, integrità (scansione anti-segreti finale + `MANIFEST.sha256`), `snapshot.json`, tracciamento cache bitmap RDP. Dettaglio e collaudi in `memory/progress.md`.

## Modifiche al sistema applicate (2026-06-10)

Rimossa la task one-shot scaduta `RiavvioSingoloNotturno`. Disattivata in modo robusto la cache bitmap persistente del client RDP (registro `DisablePersistentCache=1` + `Default.rdp` a 0 + cache svuotata): reversibile, a changelog nella mappa compilata.

## Hardening live applicato (2026-06-11, paracadute Veeam confermato)

Una azione alla volta, spiegata e approvata. (1) PS-LOG: ScriptBlock logging abilitato. (2) Firma SMB: RIMANDATA — due NAS legacy/EOL in rete e backup Veeam su uno di essi; rischio rottura. (3) Debloating Gruppo A "solo superflue": rimossi 5 componenti Xbox + DevHome per l'utente; mantenuti Media Player e Phone Link; XboxGameCallableUI non rimovibile (stub di sistema). (4) Debloating Gruppo B "solo Spotify": rimosso Spotify, mantenuto WhatsApp (possibile uso lavorativo). Tutto a changelog nella mappa compilata. Restano: BitLocker (per ultimo, decisione utente), Secure Boot (rimandato, UEFI), firma SMB (rimandata, NAS legacy), eventuale AI-slop (Copilot/BingSearch), snapshot elevato di certificazione.

## Applicatore del baseline — Allinea-BestPractice.ps1 (2026-06-11)

Terza gamba del tool: allinea un PC (vergine o difforme) al baseline di sicurezza. Dichiarativo, dry-run di default, `-Apply` guidato con conferma per passo e log reversibile. Baseline: RDP cache, firma SMB, SMBv1 off, ScriptBlock logging, LSA RunAsPPL; avvisi Secure Boot/BitLocker. Collaudato in report su questa macchina (3 conformi, 2 da allineare). Per estenderlo: aggiungere un elemento alla lista `$baseline` con `Test`/`Apply`/`Rollback`. Applicazione reale rinviata al via col paracadute Veeam.

## Feature attiva — Piano di debloating a micro-step (ANALISI A SECCO, nulla eseguito)

Cosa fa: pulizia app consumer della macchina Windows 11 seguendo `docs/00`, una categoria alla volta. Stato: **piano, non eseguito.** Vincolo: prima del primo passo serve il paracadute (immagine Veeam recente + punto di ripristino), poi un'app/gruppo alla volta con riavvio e verifica (Outlook/Teams/OneDrive/VPN/SSO) e riga di changelog.

Candidati dall'inventario reale (snapshot 20260610_151411, 212 Appx), divisi per confidenza. Le rimozioni sono reversibili: ogni app si reinstalla da Store o `winget`. Comando per-utente: `Get-AppxPackage *<Nome>* | Remove-AppxPackage` (per tutti gli utenti serve admin e `-AllUsers`).

Gruppo A — consumer chiaramente superflui su un PC di lavoro (rimozione a basso rischio): `Microsoft.BingNews`, `Microsoft.BingWeather`, `Microsoft.GamingApp`, `Microsoft.Xbox*` (TCUI, GameCallableUI, GameOverlay, GamingOverlay, IdentityProvider, SpeechToTextOverlay), `Microsoft.ZuneMusic`, `Microsoft.ZuneVideo`, `Microsoft.YourPhone`, `Microsoft.WindowsFeedbackHub`, `Clipchamp.Clipchamp`, `Microsoft.Windows.DevHome`.

Gruppo B — personali, da decidere caso per caso (potresti usarli): `SpotifyAB.SpotifyMusic`, `5319275A.WhatsAppDesktop`, `Microsoft.MicrosoftStickyNotes`, `Microsoft.Todos`, `Microsoft.WindowsMaps`.

Gruppo C — NON toccare (lavoro / integrazione di sistema): `MSTeams` (lavoro), `Microsoft.People` e `PeopleExperienceHost` (integrati con Outlook), `Microsoft.PowerAutomateDesktop`. `Microsoft.Copilot` e `Microsoft.BingSearch` sono AI/slop: categoria separata da affrontare dopo le app consumer.

Micro-step proposti (da eseguire SOLO dopo conferma e paracadute):
1. snapshot "prima" → 2. rimozione Gruppo A → 3. riavvio → 4. verifica app di lavoro →
5. snapshot "dopo" + `Compare-Snapshot` per certificare cosa è cambiato → 6. changelog in mappa. Poi, in una sessione successiva, eventualmente Gruppo B e la categoria AI/slop.

## Domande aperte / decisioni ✍️ dell'utente

Dalla mappa compilata, da affrontare una alla volta col paracadute Veeam: BitLocker OFF su tutti i volumi, Secure Boot disattivo (TPM pronto), logging PowerShell non configurato, residuo Lenovo tra le task, estensione VPN/proxy nel browser. Il server MCP locale resta rimandato (`.mcp.json` segnaposto in radice).

## 13/11/2026 - Connessioni QNAP di progetto per tutti gli account degli agenti

Su richiesta dell’operatore documentata in docs/10_CODEX_CLI_E_WORKSPACE_OPENAI.md la ricetta astratta: definizioni MCP di progetto condivise, identità degli agenti separate dai token NAS, deposito privato nel progetto di rete e ricostruzione senza trasferire segreti via Git. Il progetto proprietario mantiene codice, valori e prove. Verificata la scoperta della definizione nei tre account Claude e nei tre Codex, oltre alla radice Codex predefinita; aggiunta dove mancava la fiducia per il solo progetto rete. Handshake locale offline e 39 prove verdi, nessun catalogo NAS ancora acquisito. Per il pilota il certificato autofirmato è accettato per impronta nel solo progetto, con fiducia al primo uso dichiarata. Nessuna modifica a trust store, servizi, registro, firewall o login Windows; la capacità resta distinta da un inventario completo. Per annullare, rimuovere il solo server QNAP e le sole voci di fiducia aggiunte. Configurazioni precedenti conservate privatamente nel progetto che ha eseguito la consegna.

## 13/11/2026 - Ricetta QNAP esercitata sul pilota tramite HTTPS

L’acquisizione privata del token è stata esercitata e il lettore del progetto di rete ha acquisito il catalogo del pilota tramite HTTPS con controllo del certificato. Il blocco HTTP proposto dall’app è stato analizzato soltanto per estrarre la credenziale, senza eseguirlo. La stessa credenziale è consumata dal lettore condiviso degli agenti e dagli script; endpoint e prove restano nel progetto proprietario. Questa misura riguarda il catalogo e non un inventario o una modifica del NAS. La modalità di sola lettura effettiva e le annotazioni discordanti delle funzioni restano da riscontrare prima delle chiamate ai dati. Corretto nella rete il riepilogo degli apparati ancora senza token: una credenziale configurata non obbliga gli altri apparati a essere già pronti. Quaranta prove offline passano. Nessuna modifica a Windows o al trust store.

## 13/11/2026 - NAS multiaccount: lettura e manutenzione da script

La stessa macchina può offrire l’integrazione NAS a tre radici Claude Code e tre radici Codex CLI dello stesso utente Windows, usando le definizioni del progetto proprietario. La ricetta resta generica: endpoint, nomi degli apparati, utenti, token e prove dell’infrastruttura vivono soltanto nel livello privato di quel progetto. Questa condivisione fra radici degli agenti non concede accesso ad altri utenti Windows.

Per ogni NAS compatibile si preparano due credenziali: censimento in sola lettura e manutenzione con categorie limitate. I token non entrano nei file globali di ciascun account; restano in depositi privati distinti. Claude e Codex caricano lo stesso lettore di progetto. Lo script di manutenzione richiede un piano completo, la sua impronta approvata, destinazione e certificato coincidenti, lettura dello stato prima e dopo e diario scritto prima della modifica. Un timeout richiede riconciliazione e non un nuovo tentativo automatico. Il catalogo di manutenzione è stato acquisito sul pilota della nuova funzione; una modifica reale rimane da collaudare. I cataloghi non attestano da soli privilegi effettivi, copertura completa o continuità operativa.

Per ricostruire la capacità si ripristinano i launcher e le radici previste dal template, si recupera il progetto proprietario, si rigenerano le configurazioni private di progetto e si acquisiscono credenziali nuove per ogni NAS. Si verificano separatamente scoperta della definizione in ogni account, handshake locale, collegamento HTTPS, catalogo e letture autorizzate. Un apparato legacy può restare nell’inventario e nel controllo degli accessi anche se non supporta MCP. Nessun riferimento all’organizzazione o a utenti e host reali appartiene a questa ricetta. Non è necessario replicare segreti in ciascuna radice account.

## 13/11/2026 - Configurazione multiaccount riscontrata con letture reali

La definizione NAS di progetto è stata risolta nei tre account Codex e il relativo server stdio ha acquisito dati reali di sistema, utenti e gruppi da tre apparati, tramite HTTPS. La verifica riguarda configurazione e protocollo del server, senza avviare un’altra sessione agente. La stessa definizione resta condivisa con le tre radici Claude. Credenziali di manutenzione distinte e script di piani sono disponibili; il primo collaudo di una modifica reale resta aperto. Dati, conteggi, identità, endpoint e prove restano nel progetto proprietario: questa ricetta non conserva riferimenti dell’organizzazione. Un NAS legacy escluso da MCP rimane nell’inventario per gli accessi.
