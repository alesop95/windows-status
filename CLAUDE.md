# CLAUDE.md — contesto e regole per Claude Code

Progetto: **windows-status** — fotografia completa e ripristinabile di un PC Windows 11
aziendale, registrato al tenant Microsoft 365 in modalità workplace join (NON Entra ID joined
né gestito da Intune: verificato dallo snapshot), con backup Veeam Agent verso NAS.
Gli script sono proprietari e versionati su GitHub (repo **pubblico**): devono restare puliti,
generici, riusabili e **anonimi** — i valori reali della macchina vivono solo in
`CLAUDE.local.md`, ignorato da git.

## Obiettivo del progetto
Permettere di (1) fotografare lo stato completo del PC e di ogni account, (2) mantenere una mappa
sempre aggiornata, (3) pulire/ottimizzare in sicurezza, (4) ristabilire la stessa configurazione
altrove (immagine Veeam + reinstallazione software + dotfiles/git/Claude).

## Procedura di ripresa in una sessione nuova
Lo stato del progetto è interamente recuperabile su disco. Si legge per primo
`.claude/memory/index.md` (branch, commit di riferimento, stato delle schede, punto di ripresa);
poi `.claude/context/current-work.md` se c'è una feature attiva. Si invoca la skill
`sync-context` per verificare il drift tra schede e codice e si leggono solo le schede
pertinenti al task. `memory/progress.md` e `memory/decisions.md` danno storia e decisioni quando
servono. Il materiale sotto `_notes/` si apre solo per verificare un requisito originale.

## Cosa puoi fare
- Eseguire `scripts\Snapshot-Stato.ps1` (sola lettura) e `scripts\Compare-Snapshot.ps1`.
- Aggiornare le sezioni 🔄 di `docs\01_MAPPA_CONFIGURAZIONE.md` dai dati dello snapshot.
- Tenere il changelog aggiornato a ogni intervento.
- Migliorare gli script restando coerente con i paletti qui sotto.

## Paletti di sicurezza (NON negoziabili)
1. Di default SOLA LETTURA sul sistema. Ogni comando che MODIFICA (servizi, registro,
   disinstallazioni, rete, firewall, attivita pianificate, debloating) va PRIMA proposto e
   poi eseguito SOLO dopo conferma esplicita.
2. Prima di qualsiasi modifica: ricorda backup immagine Veeam recente + punto di ripristino.
3. Una categoria di modifiche alla volta, con riavvio e verifica (Outlook/Teams/OneDrive/VPN/SSO)
   prima di procedere.
4. Macchina **aziendale, registrata al tenant** (workplace join, senza Intune): NON toccare
   comunque senza ordine esplicito Windows Update, Microsoft Defender, attivazione Office,
   Microsoft Edge/WebView2, OneDrive, ne azzerare la telemetria. Sono cautele prudenziali, non
   imposte: se la macchina venisse in futuro aggiunta a Entra ID o a Intune, tornerebbero
   vincoli obbligatori. Nota correlata: NON essendo Entra-joined, la chiave BitLocker NON e
   archiviata in Entra ID di default — va custodita e annotata nella mappa.
5. **Mai segreti nel repo.** Token, API key, password Veeam, chiavi private SSH, chiave BitLocker,
   `.credentials.json` di Claude: esclusi dagli snapshot (oscurati) e dal git (`.gitignore`).
   Nella mappa va solo *dove* sono custoditi.
6. Ogni modifica effettiva → riga nel changelog (data, cosa, perche, come si annulla).
7. Prima di un push (il repo e PUBBLICO), verifica che nessun file tracciato contenga segreti,
   email, hostname o altri identificativi reali: nei file tracciati si usano segnaposto tra
   parentesi angolari, la mappatura reale sta in `CLAUDE.local.md`.
8. **Versionamento multi-account** (vedi `docs/04_GIT_VERSIONAMENTO_MULTIACCOUNT.md` e
   `.claude/rules/git-identity-and-repo.md`): per i repo personali NON usare mai l'identità
   globale di lavoro. Imposta sempre in `--local` `user.name`, `user.email` e `core.sshCommand`
   (OpenSSH di Windows), remote con l'alias `github-personal`, e dopo il primo commit verifica
   `git log -1 --format="%an <%ae>"`. Mai repo dentro cartelle di sync cloud.
9. Le operazioni di `git add`, commit e push restano sempre manuali dell'utente: l'agente
   prepara i file, non committa.

## Convenzioni
- Lingua: italiano. Sistema operativo italiano (attenzione ai nomi localizzati di gruppi/servizi).
- Le sezioni 🔄 della mappa derivano dagli snapshot; le ✍️ sono decisioni umane: non inventarle.
- Aggiornando la mappa, aggiorna anche "Ultimo aggiornamento" in cima.
- Criterio operativo: **prima la mappatura, poi la pulizia.**
- Claude non scrive nei file di memoria e contesto di propria iniziativa: li aggiorna su
  richiesta o a passo concluso, e il versionamento resta sotto controllo umano.

## Struttura
- `docs/`     guide e mappa (tracciate; le copie compilate `*.compilata.md` restano locali)
- `scripts/`  Snapshot-Stato.ps1, Compare-Snapshot.ps1, Reinstall-Software.ps1
              (devono stare qui: ricavano la radice del progetto dalla cartella genitore)
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
Regole modulari sotto `.claude/rules/`, skill sotto `.claude/skills/` (`init-project-system`,
`sync-context`, `git-sync`, `repo-status`). Lo standard completo è in
`.claude/PROJECT-SYSTEM.md`.
