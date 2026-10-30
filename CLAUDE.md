# CLAUDE.md — contesto e regole per Claude Code

Progetto: **windows-status** — fotografia completa e ripristinabile di un PC Windows 11 aziendale, registrato al tenant Microsoft 365 in modalità workplace join (NON Entra ID joined né gestito da Intune: verificato dallo snapshot), con backup Veeam Agent verso NAS. Gli script sono proprietari e versionati su GitHub (repo **pubblico**): devono restare puliti, generici, riusabili e **anonimi** — i valori reali della macchina vivono solo in `CLAUDE.local.md`, ignorato da git.

## Obiettivo del progetto
Permettere di (1) fotografare lo stato completo del PC e di ogni account, (2) mantenere una mappa sempre aggiornata, (3) pulire/ottimizzare in sicurezza, (4) ristabilire la stessa configurazione altrove (immagine Veeam + reinstallazione software + dotfiles/git/Claude).

## Procedura di ripresa in una sessione nuova
Lo stato del progetto è interamente recuperabile su disco. Si legge per primo `.claude/memory/index.md` (branch, commit di riferimento, stato delle schede, punto di ripresa); poi `.claude/context/current-work.md` se c'è una feature attiva. Si invoca la skill `sync-context` per verificare il drift tra schede e codice e si leggono solo le schede pertinenti al task. `memory/progress.md` e `memory/decisions.md` danno storia e decisioni quando servono. Il materiale sotto `_notes/` si apre solo per verificare un requisito originale.

## Cosa puoi fare

Per il dettaglio operativo leggere `.claude/context/guida-e-struttura.md`; prima di qualsiasi modifica restano obbligatori tutti i paletti di sicurezza di questo indice.

## Paletti di sicurezza (NON negoziabili)
1. Di default SOLA LETTURA sul sistema. Ogni comando che MODIFICA (servizi, registro, disinstallazioni, rete, firewall, attivita pianificate, debloating) va PRIMA proposto e poi eseguito SOLO dopo conferma esplicita.
2. Prima di qualsiasi modifica: ricorda backup immagine Veeam recente + punto di ripristino.
3. Una categoria di modifiche alla volta, con riavvio e verifica (Outlook/Teams/OneDrive/VPN/SSO) prima di procedere.
4. Macchina **aziendale, registrata al tenant** (workplace join, senza Intune): NON toccare comunque senza ordine esplicito Windows Update, Microsoft Defender, attivazione Office, Microsoft Edge/WebView2, OneDrive, ne azzerare la telemetria. Sono cautele prudenziali, non imposte: se la macchina venisse in futuro aggiunta a Entra ID o a Intune, tornerebbero vincoli obbligatori. Nota correlata: NON essendo Entra-joined, la chiave BitLocker NON e archiviata in Entra ID di default — va custodita e annotata nella mappa.
5. **Mai segreti nel repo.** Token, API key, password Veeam, chiavi private SSH, chiave BitLocker, `.credentials.json` di Claude: esclusi dagli snapshot (oscurati) e dal git (`.gitignore`). Nella mappa va solo *dove* sono custoditi.
6. Ogni modifica effettiva → riga nel changelog (data, cosa, perche, come si annulla).
7. Prima di un push (il repo e PUBBLICO), verifica che nessun file tracciato contenga segreti, email, hostname o altri identificativi reali: nei file tracciati si usano segnaposto tra parentesi angolari, la mappatura reale sta in `CLAUDE.local.md`. La verifica si fa con `python tools/Test-Anonymization.py`, che esce 1 su un riscontro bloccante e 2 se manca il file dei pattern `_notes/.anonymization-patterns.json`; criterio e perimetro nella regola sempre attiva `.claude/rules/anonymization.md`.
8. **Versionamento multi-account** (vedi `docs/04_GIT_VERSIONAMENTO_MULTIACCOUNT.md` e `.claude/rules/git-identity-and-repo.md`): per i repo personali NON usare mai l'identità globale di lavoro. Imposta sempre in `--local` `user.name`, `user.email` e `core.sshCommand` (OpenSSH di Windows), remote con l'alias `github-personal`, e dopo il primo commit verifica `git log -1 --format="%an <%ae>"`. Mai repo dentro cartelle di sync cloud.
9. Le operazioni di `git add`, commit e push restano sempre manuali dell'utente: l'agente prepara i file, non committa.

## Convenzioni
- Lingua: italiano. Sistema operativo italiano (attenzione ai nomi localizzati di gruppi/servizi).
- Le sezioni 🔄 della mappa derivano dagli snapshot; le ✍️ sono decisioni umane: non inventarle.
- Aggiornando la mappa, aggiorna anche "Ultimo aggiornamento" in cima.
- Criterio operativo: **prima la mappatura, poi la pulizia.**
- Claude non scrive nei file di memoria e contesto di propria iniziativa: li aggiorna su richiesta o a passo concluso, e il versionamento resta sotto controllo umano.

## Documenti (in `docs/`, tracciati; le copie compilate `*.compilata.md` restano locali)

Per il dettaglio operativo leggere `.claude/context/guida-e-struttura.md`; prima di qualsiasi modifica restano obbligatori tutti i paletti di sicurezza di questo indice.

## Struttura

Per il dettaglio operativo leggere `.claude/context/guida-e-struttura.md`; prima di qualsiasi modifica restano obbligatori tutti i paletti di sicurezza di questo indice.

## Indice dei file satellite tracciati

Alla ripresa leggere `.claude/memory/index.md` e `.claude/context/current-work.md`. Storia e decisioni sono in `.claude/memory/progress.md` e `decisions.md`; l’indice dettagliato dei satelliti e degli strumenti e in `.claude/context/guida-e-struttura.md`.

Norme caricate su richiesta, una riga per situazione con le parole con cui si presenta, così che il caricamento non dipenda dal ricordare che la norma esista.

- `git worktree list` mostra più di un albero, se ne crea o se ne rimuove uno, si deve decidere da dove leggere la memoria versionata: skill `alberi-di-lavoro`.
- Un recupero web fallisce con 403 o con una pagina di verifica anti-bot, la fonte sta su Reddit o su Discord, serve la trascrizione di un video, si sta per annotare una fonte non letta: skill `fonti-non-recuperabili`.
- Si scrive o si valuta una prova automatica, si chiude un difetto, una verifica manuale smentisce una suite verde, si sta per dichiarare completo un intervento il cui scopo era un effetto misurabile: skill `prove-che-misurano`.
- Si inizializza o si allinea il progetto, oppure cambia il modo in cui si prova e si rilascia, e va deciso come separare test e produzione: skill `separazione-ambienti`.
- Si imposta o si verifica user.name e user.email, si collega o si cambia il remoto o l'alias SSH, si inizializza un repository, un push fallisce per permessi, `/status` mostra un account Claude diverso da quello atteso, si autentica o si usa `gh`: skill `identita-git`.
- Va prodotto, modificato o convertito un artefatto visivo o documentale, cioè un documento, una presentazione, un PDF, un'immagine, un'animazione, un audio o un impaginato, oppure si sta per scrivere uno script o installare una libreria per farlo: skill `craft-apps`, che prima verifica in locale le applicazioni Craft installate e le usa senza rete né token.
