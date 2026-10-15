# CLAUDE.md — contesto e regole per Claude Code

Progetto: **windows-status** — fotografia completa e ripristinabile di un PC Windows 11 aziendale, registrato al tenant Microsoft 365 in modalità workplace join (NON Entra ID joined né gestito da Intune: verificato dallo snapshot), con backup Veeam Agent verso NAS. Gli script sono proprietari e versionati su GitHub (repo **pubblico**): devono restare puliti, generici, riusabili e **anonimi** — i valori reali della macchina vivono solo in `CLAUDE.local.md`, ignorato da git.

## Obiettivo del progetto
Permettere di (1) fotografare lo stato completo del PC e di ogni account, (2) mantenere una mappa sempre aggiornata, (3) pulire/ottimizzare in sicurezza, (4) ristabilire la stessa configurazione altrove (immagine Veeam + reinstallazione software + dotfiles/git/Claude).

## Procedura di ripresa in una sessione nuova
Lo stato del progetto è interamente recuperabile su disco. Si legge per primo `.claude/memory/index.md` (branch, commit di riferimento, stato delle schede, punto di ripresa); poi `.claude/context/current-work.md` se c'è una feature attiva. Si invoca la skill `sync-context` per verificare il drift tra schede e codice e si leggono solo le schede pertinenti al task. `memory/progress.md` e `memory/decisions.md` danno storia e decisioni quando servono. Il materiale sotto `_notes/` si apre solo per verificare un requisito originale.

## Cosa puoi fare
- Eseguire `scripts\Snapshot-Stato.ps1` (sola lettura) e `scripts\Compare-Snapshot.ps1`.
- Eseguire `scripts\Allinea-BestPractice.ps1` SENZA `-Apply` (sola lettura: report del divario rispetto al baseline). Con `-Apply` MODIFICA il sistema: vale il paletto 1 (proporre, conferma per passo, paracadute, reversibilità, changelog).
- Eseguire `scripts\Diagnostica-PowerPoint.ps1` e `scripts\Diagnostica-Vincolata.ps1` senza parametri (sola lettura). `-Bonifica` del primo modifica il registro del profilo e `-VerificaRilascio` del secondo termina un processo: vale il paletto 1, ed entrambi chiedono conferma digitando SI.
- Eseguire `scripts\Prima-Installazione.ps1` senza parametri (piano, sola lettura), con `-Scarica` (prende e verifica i digest, non esegue) e con `-Controlla` (residui AI, sola lettura); e `scripts\Prepara-Chiavetta.ps1` (prepara la cartella per un PC nuovo, scrive solo nella destinazione). Con `-Applica` esegue strumenti di terze parti che MODIFICANO il sistema, e RemoveWindowsAI e' reversibile **solo in parte** (il registro torna con -revertMode, i pacchetti rimossi no): vale il paletto 1 piu' il 2, la catena si ferma da sola su macchina aziendale e chiede conferma digitando SI a ogni passo. Vedi docs/16.
- Aggiornare le sezioni 🔄 di `docs\01_MAPPA_CONFIGURAZIONE.md` dai dati dello snapshot.
- Tenere il changelog aggiornato a ogni intervento.
- Migliorare gli script restando coerente con i paletti qui sotto.

## Paletti di sicurezza (NON negoziabili)
1. Di default SOLA LETTURA sul sistema. Ogni comando che MODIFICA (servizi, registro, disinstallazioni, rete, firewall, attivita pianificate, debloating) va PRIMA proposto e poi eseguito SOLO dopo conferma esplicita.
2. Prima di qualsiasi modifica: ricorda backup immagine Veeam recente + punto di ripristino.
3. Una categoria di modifiche alla volta, con riavvio e verifica (Outlook/Teams/OneDrive/VPN/SSO) prima di procedere.
4. Macchina **aziendale, registrata al tenant** (workplace join, senza Intune): NON toccare comunque senza ordine esplicito Windows Update, Microsoft Defender, attivazione Office, Microsoft Edge/WebView2, OneDrive, ne azzerare la telemetria. Sono cautele prudenziali, non imposte: se la macchina venisse in futuro aggiunta a Entra ID o a Intune, tornerebbero vincoli obbligatori. Nota correlata: NON essendo Entra-joined, la chiave BitLocker NON e archiviata in Entra ID di default — va custodita e annotata nella mappa.
5. **Mai segreti nel repo.** Token, API key, password Veeam, chiavi private SSH, chiave BitLocker, `.credentials.json` di Claude: esclusi dagli snapshot (oscurati) e dal git (`.gitignore`). Nella mappa va solo *dove* sono custoditi.
6. Ogni modifica effettiva → riga nel changelog (data, cosa, perche, come si annulla).
7. Prima di un push (il repo e PUBBLICO), verifica che nessun file tracciato contenga segreti, email, hostname o altri identificativi reali: nei file tracciati si usano segnaposto tra parentesi angolari, la mappatura reale sta in `CLAUDE.local.md`.
8. **Versionamento multi-account** (vedi `docs/04_GIT_VERSIONAMENTO_MULTIACCOUNT.md` e `.claude/rules/git-identity-and-repo.md`): per i repo personali NON usare mai l'identità globale di lavoro. Imposta sempre in `--local` `user.name`, `user.email` e `core.sshCommand` (OpenSSH di Windows), remote con l'alias `github-personal`, e dopo il primo commit verifica `git log -1 --format="%an <%ae>"`. Mai repo dentro cartelle di sync cloud.
9. Le operazioni di `git add`, commit e push restano sempre manuali dell'utente: l'agente prepara i file, non committa.

## Convenzioni
- Lingua: italiano. Sistema operativo italiano (attenzione ai nomi localizzati di gruppi/servizi).
- Le sezioni 🔄 della mappa derivano dagli snapshot; le ✍️ sono decisioni umane: non inventarle.
- Aggiornando la mappa, aggiorna anche "Ultimo aggiornamento" in cima.
- Criterio operativo: **prima la mappatura, poi la pulizia.**
- Claude non scrive nei file di memoria e contesto di propria iniziativa: li aggiorna su richiesta o a passo concluso, e il versionamento resta sotto controllo umano.

## Documenti (in `docs/`, tracciati; le copie compilate `*.compilata.md` restano locali)
- `00_GUIDA_OTTIMIZZAZIONE.md` debloating e ottimizzazione (Winhance/Winslop, manuale)
- `01_MAPPA_CONFIGURAZIONE.md` mappa viva (sezioni 🔄 da snapshot, ✍️ decisioni umane)
- `02_VEEAM_BACKUP_PORTABILITA.md` strategia di backup e ripristino bare metal
- `03_HANDOFF_CLAUDE_CODE.md` setup di Claude Code sul progetto
- `04_GIT_VERSIONAMENTO_MULTIACCOUNT.md` identità git multi-account
- `05_QUICKSTART.md` guida rapida d'uso del tool
- `06_RACCORDO_CHECKLIST_VA.md` come gli alert alimentano una checklist di remediation VA
- `07_SALUTE_E_STABILITA.md` check di salute/stabilità (registro eventi: OOM, crash, BSOD, WHEA) e setup di monitoraggio
- `08_MONITORAGGIO_BACKUP_VEEAM.md` rilevare il guasto silenzioso del backup (freschezza dei restore point, drift dei GUID di volume) e i due script RMM di flotta
- `09_TOOLCHAIN_DA_ALTRI_PROGETTI.md` censimento anonimo dei componenti che gli altri progetti della macchina hanno aggiunto, e divergenze verificate fra le loro schede e lo stato reale
- `11_ORCHESTRAZIONE_AGENTI_SU_WINDOWS.md` strumenti per far lavorare più agenti in parallelo: perché `tmux` esclude metà del panorama su questa macchina, Nimbalyst come unico candidato nativo, installazione con verifica del digest, e il caveat sul server di sincronizzazione di terze parti
- `10_CODEX_CLI_E_WORKSPACE_OPENAI.md` secondo agente da terminale: setup multi-account via `CODEX_HOME`, ripristino 1:1 dopo formattazione, i cinque store da ripulire, baseline della console di amministrazione, i due canali di spesa OpenAI (chiave API contro login ChatGPT) e le trappole diagnostiche incontrate
- `12_POWERPOINT_LENTO_DOCTOIDMAPPING.md` PowerPoint che si blocca a ogni click: che cos'è la cache `Common\Identity\DocToIdMapping`, la catena di chiamate del ribbon e del controllo Copilot che la scorre, il caso con le diciassette verifiche, lo strumento locale, lo script di flotta e il metodo WPR/WPA
- `13_MEMORIA_VINCOLATA_HANDLE_LEAK.md` vincolata che cresce senza appartenere a nessun processo: sezioni appoggiate al file di paging tenute vive da handle mai chiusi, il detentore di questa macchina trovato per correlazione e misurato sezione per sezione, la proiezione al limite, l'esperimento di rilascio e i rimedi
- `14_DESIGN_SYSTEM_DI_ACCOUNT.md` come una macchina fa ereditare a ogni radice di account degli agenti da terminale lo stesso design system: pacchetto skill, una sola copia reale nel magazzino di macchina, collegamenti di cartella verso le radici e blocco di istruzioni generato dal pacchetto, cosi' che il marchio non viva in questo repository
- `15_CENSIMENTO_HARDWARE_MULTIPIATTAFORMA.md` censimento di un parco macchine con due strumenti autonomi di sola lettura, uno per Windows e uno per Linux, con le stesse sezioni nello stesso ordine: perche' censire (molte macchine una volta) e' un mestiere diverso dal fotografare (una macchina molte volte), anonimizzazione predefinita con pseudonimi stabili, parametri gemelli sulle due piattaforme, e perche' gli output non entrano mai nel repository
- `16_PRIMA_INSTALLAZIONE_PC_NUOVO.md` cosa si fa a un PC Windows appena acceso: i tre progetti di terze parti (RemoveWindowsAI, Win11Debloat, Netdata), perche' la loro forma `irm | iex` non e' accettabile qui, la catena di custodia che il progetto ci mette attorno (versioni appuntate, digest, paracadute, conferma, fotografia prima e dopo), quanto esattamente e' reversibile ciascuno, il profilo che toglie i menu ma non le conferme, perche' Netdata non si installa da solo (su Windows il cruscotto locale e' bloccato nel piano gratuito e i dati vanno al Cloud), la chiavetta per il PC senza rete e come si aggiornano le versioni appuntate
- `17_MONITORAGGIO_APERTO_DEL_PARCO.md` guardare le macchine nel tempo senza account, senza token, senza limiti di nodi e senza che un byte esca dalla rete: windows_exporter (MIT) sui PC, Prometheus (Apache-2.0) e Grafana OSS (AGPL-3.0) su UNA macchina centrale; perche' Netdata e' uscito dalla catena Windows (licenza aperta ma cruscotto locale bloccato nel piano gratuito) e resta invece la scelta giusta su Linux; le tre porte e fin dove aprirle; il rapporto con Controlla-Salute, che guarda un istante mentre il monitoraggio guarda il tempo

## Struttura
- `docs/`     guide e mappa (tracciate; le copie compilate `*.compilata.md` restano locali)
- `Avvia.ps1`  punto d'ingresso unico (menu) in radice: orchestra gli script di `scripts/`. Una capacità che non compare qui è una capacità che non esiste per chi apre il progetto su una macchina che non conosce: ogni script nuovo va aggiunto al menu. Voce `P` = percorso guidato del PC nuovo, che distingue fatto, da fare e **non verificabile da qui** (l'immagine Veeam resta `[?]`: nessuno script può saperlo)
- `LEGGIMI-PC-NUOVO.md` in radice: la sequenza del PC nuovo e le tre cose da portarsi (progetto, strumenti, `software_winget.json`), perché è il primo file che si apre su una macchina appena accesa. Vedi docs/16
- `scripts/`  Snapshot-Stato.ps1, Compare-Snapshot.ps1, Allinea-BestPractice.ps1, Genera-Report.ps1, Pianifica-Snapshot.ps1, Reinstall-Software.ps1, Controlla-Salute.ps1 (salute/stabilità da registro eventi, vedi docs/07), Campiona-Vincolata.ps1 (serie temporale della memoria vincolata per processo, vedi docs/07 sezione 2d), Diagnostica-Vincolata.ps1 (chi trattiene la vincolata e fra quanti giorni si arriva al limite, vedi docs/13), Diagnostica-PowerPoint.ps1 (PowerPoint lento per la cache DocToIdMapping, con bonifica a conferma, vedi docs/12) (devono stare qui: ricavano la radice dalla cartella genitore)
- `scripts/rmm/` script di flotta da distribuire via RMM, NON parte della catena locale dello snapshot: girano come LOCAL SYSTEM sull'endpoint, non ricavano la radice del repo e non scrivono in `snapshots/`. Oggi Veeam-BackupFreshness.ps1 (freschezza dei restore point) e Disk-LayoutDrift.ps1 (drift dei GUID di volume), vedi docs/08; Fix-OfficeDocToIdMapping.ps1 (cache DocToIdMapping su tutti i profili, vedi docs/12)
- `scripts/Agenti.ps1` **punto d'ingresso di questa macchina** alla catena dei due agenti da terminale, che vive nel TEMPLATE (pacchetto `agenti-terminale`) e non qui: questo script conosce soltanto dove sta il template e i due valori specifici della macchina, cioè i prefissi degli slug da preservare nel wipe e il numero di radici. Azioni: `verifica`, `installa`, `consumo`, `comandi`. Non duplica logica, la chiama: due copie divergerebbero in silenzio. Vedi docs/10
- `scripts/Installa-DesignSystem.ps1` propaga UN design system, confezionato come pacchetto skill, a tutte le radici di account di Claude Code e di Codex: deposita una copia sola nel magazzino di macchina, collega le radici e scrive in ciascuna il blocco di istruzioni generato dal pacchetto. Sola lettura per default, `-Applica` per agire, `-Rimuovi` per tornare indietro. Nessun dato del marchio vive qui: nome, descrizione e percorso arrivano dal pacchetto al momento dell'uso. Vedi docs/14
- `scripts/censimento/` strumenti di censimento di un parco macchine, autonomi e di sola lettura, da copiare sulla macchina da guardare: hw-report-windows.ps1 e hw-report.sh producono lo stesso elenco di sezioni nello stesso ordine su Windows e su Linux, con parametri gemelli (destinazione, etichetta, sezioni, sale, pattern). **Anonimi per default**: hostname, seriali e UUID diventano pseudonimi stabili, del MAC resta il produttore e dell'IPv4 resta la rete; `-Identificativi` / `--identificativi` spegne l'anonimizzazione e quell'output va trattato come dato reale. Nessuna distribuzione e nessuna versione di Windows e' data per scontata: ogni comando assente degrada in una riga che lo dichiara. Come `rmm/` non fanno parte della catena locale dello snapshot: non ricavano la radice del repo, non scrivono in `snapshots/`, non passano da `Avvia.ps1`. Gli output restano fuori da git (`hw-*.txt` in .gitignore). Vedi docs/15
- `scripts/Prima-Installazione.ps1` prima installazione di un PC nuovo: non un nuovo strumento di pulizia, ma la **catena di custodia** attorno a tre progetti di terze parti (zoicware/RemoveWindowsAI per Copilot, Recall e i pacchetti AI non rimovibili; Raphire/Win11Debloat per app preinstallate, telemetria e interfaccia; netdata/netdata per il monitoraggio). Aggiunge cio' che a loro non compete: versioni appuntate e verificate per digest SHA-256 invece del loro `irm <url> | iex`, paracadute, conferma digitando SI a ogni passo, snapshot prima e dopo con confronto, riga di changelog pronta. Non riavvia mai da se'. Passa sempre `-backupMode` a RemoveWindowsAI, che e' reversibile **solo in parte**: il registro torna, i pacchetti rimossi no. Netdata non parte se il profilo non lo dice, perche' su Windows il piano gratuito blocca il cruscotto locale e i dati si guardano sul Cloud: e' una decisione, non un passo. Si ferma su macchina a dominio/tenant/MDM salvo `-ForzaAziendale`, per il paletto 4. Vedi docs/16
- `scripts/Prepara-Chiavetta.ps1` da lanciare sulla macchina VECCHIA: mette in una cartella sola il progetto (senza `.git`, `snapshots/`, `_notes/`), gli strumenti gia' scaricati e verificati, e `software_winget.json`, che nasce da uno snapshot e per questo non puo' stare nel repo. Cosi' il PC nuovo non ha bisogno ne' di rete ne' di git. Copia il profilo solo con `-ConProfilo`, e avvisa se contiene un token
- `scripts/Monitoraggio-Centrale.ps1` la macchina che guarda le altre: scarica e verifica Prometheus e Grafana OSS ai digest pubblicati dai loro autori, genera `prometheus.yml` e `regole.yml` dall'elenco delle macchine, e installa. Sui PC sta solo `windows_exporter` (11 MB, passo MONITORAGGIO della catena). Dice in chiaro che su Windows Prometheus non e' un servizio e usa un'attivita' pianificata invece di aggiungere dipendenze, e che su Linux niente di tutto cio' serve. Vedi docs/17
- `scripts/prima-installazione/strumenti.json` manifesto delle versioni appuntate: repo, licenza, commit o versione immutabile, file di ingresso, digest SHA-256 e quanto lo strumento sia reversibile (`true`, `false` o `"parziale"` — attenzione a non leggere `"parziale"` come un sì). Aggiornarlo e' un atto deliberato (procedura in docs/16), non una conseguenza di un digest che non torna
- `scripts/prima-installazione/profilo.esempio.json` le scelte dei tre strumenti gia' prese, con i nomi dei parametri letti dal loro codice alla versione appuntata. Si copia in `profilo.json`, che e' **ignorato da git** perche' puo' contenere il token di Netdata (paletto 5). Toglie i menu di terze parti, NON le conferme
- `snapshots/` output datato (ignorato da git)
- `_notes/`   livello privato e verboso (ignorato da git)
- `.claude/`  centro di controllo versionato (vedi indice sotto)
- `.mcp.json` segnaposto per un futuro server MCP locale (vedi roadmap)

## Indice dei file satellite tracciati
Memoria e meta-stato, sotto `.claude/memory/`:
```
.claude/memory/index.md       snapshot e tabella di sincronizzazione, da leggere per primo
.claude/memory/progress.md    work-log append-only di passi e riconciliazioni
.claude/memory/decisions.md   registro ADR-lite delle decisioni architetturali
```
Schede tecniche, sotto `.claude/context/`, con frontmatter di riconciliazione:
```
.claude/context/STACK.md                stack, flussi e ruolo architetturale degli script
.claude/context/design-and-security.md  design e sicurezza applicativa
.claude/context/deployment.md           uso operativo e strategia di ripristino
.claude/context/dev-testing.md          verifica manuale, redazione, pre-push
.claude/context/current-work.md         feature attiva e definition of done
.claude/context/roadmap.md              direzione e priorità
```
Regole modulari sotto `.claude/rules/`, skill sotto `.claude/skills/` (`init-project-system`, `sync-context`, `git-sync`, `repo-status`). Lo standard completo è in `.claude/PROJECT-SYSTEM.md`.

Norme caricate su richiesta, una riga per situazione con le parole con cui si presenta, così che il caricamento non dipenda dal ricordare che la norma esista.

- `git worktree list` mostra più di un albero, se ne crea o se ne rimuove uno, si deve decidere da dove leggere la memoria versionata: skill `alberi-di-lavoro`.
- Un recupero web fallisce con 403 o con una pagina di verifica anti-bot, la fonte sta su Reddit o su Discord, serve la trascrizione di un video, si sta per annotare una fonte non letta: skill `fonti-non-recuperabili`.
- Si scrive o si valuta una prova automatica, si chiude un difetto, una verifica manuale smentisce una suite verde, si sta per dichiarare completo un intervento il cui scopo era un effetto misurabile: skill `prove-che-misurano`.
- Si inizializza o si allinea il progetto, oppure cambia il modo in cui si prova e si rilascia, e va deciso come separare test e produzione: skill `separazione-ambienti`.
- Si imposta o si verifica user.name e user.email, si collega o si cambia il remoto o l'alias SSH, si inizializza un repository, un push fallisce per permessi, `/status` mostra un account Claude diverso da quello atteso, si autentica o si usa `gh`: skill `identita-git`.
