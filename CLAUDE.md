# CLAUDE.md — contesto e regole per Claude Code

Progetto: **windows-status** — fotografia completa e ripristinabile di un PC Windows 11
aziendale (Entra ID joined, tenant Microsoft 365), con backup Veeam Agent verso NAS.
Gli script sono proprietari e versionati su GitHub: devono restare puliti, generici e riusabili.

## Obiettivo del progetto
Permettere di (1) fotografare lo stato completo del PC e di ogni account, (2) mantenere una mappa
sempre aggiornata, (3) pulire/ottimizzare in sicurezza, (4) ristabilire la stessa configurazione
altrove (immagine Veeam + reinstallazione software + dotfiles/git/Claude).

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
4. Macchina **Entra ID joined / gestita**: NON toccare senza ordine esplicito Windows Update,
   Microsoft Defender, attivazione Office, Microsoft Edge/WebView2, OneDrive, agenti Intune/MDM,
   ne azzerare la telemetria (Intune la usa per la conformita).
5. **Mai segreti nel repo.** Token, API key, password Veeam, chiavi private SSH, chiave BitLocker,
   `.credentials.json` di Claude: esclusi dagli snapshot (oscurati) e dal git (`.gitignore`).
   Nella mappa va solo *dove* sono custoditi.
6. Ogni modifica effettiva → riga nel changelog (data, cosa, perche, come si annulla).
7. Prima di un push, specie su repo pubblico, verifica che nessun output contenga dati sensibili.
8. **Versionamento multi-account** (vedi `docs/04_GIT_VERSIONAMENTO_MULTIACCOUNT.md`): per i repo
   personali NON usare mai l'identità globale di lavoro. Imposta sempre in `--local` `user.name`,
   `user.email` e `core.sshCommand` (OpenSSH di Windows), remote con l'alias `github-personal`, e dopo
   il primo commit verifica `git log -1 --format="%an <%ae>"`. Mai repo dentro cartelle di sync cloud.

## Convenzioni
- Lingua: italiano. Sistema operativo italiano (attenzione ai nomi localizzati di gruppi/servizi).
- Le sezioni 🔄 della mappa derivano dagli snapshot; le ✍️ sono decisioni umane: non inventarle.
- Aggiornando la mappa, aggiorna anche "Ultimo aggiornamento" in cima.
- Criterio operativo: **prima la mappatura, poi la pulizia.**

## Struttura
- `docs/`    guide e mappa (la IP da versionare)
- `scripts/` Snapshot-Stato.ps1, Compare-Snapshot.ps1, Reinstall-Software.ps1
- `snapshots/` output datato (ignorato da git)
