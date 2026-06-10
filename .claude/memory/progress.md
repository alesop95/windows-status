# Work-log

> Append-only, in ordine cronologico inverso (la voce più recente in alto). Ogni passo
> significativo di codice e ogni intervento manuale rilevante lascia una voce con data, file
> toccati, motivo e commit di riferimento. Qui confluisce anche il log di riconciliazione dei
> documenti `.docx`, con il nome del documento sorgente e l'esito, così la data di allineamento
> sopravvive a un clone.

## 2026-06-10 — Snapshot elevato, mappa completata, AV registrati, avviso elevazione

Commit: 2552033 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (sezione 8: antivirus registrati via
SecurityCenter2), `scripts/Compare-Snapshot.ps1` (avviso quando i due snapshot hanno privilegi
diversi), `README.md` (nuova sezione "Uso" con i comandi di snapshot/confronto/reinstallazione
e l'avvertenza sull'esecuzione elevata), mappa compilata aggiornata con i dati elevati.
Esiti dello snapshot ELEVATO (eseguito dall'utente, snapshot_20260610_151411): BitLocker OFF su
tutti i volumi; Secure Boot disattivo con TPM presente e pronto; Defender in passivo perché
l'AV attivo è un endpoint di terze parti registrato in SecurityCenter2 (normale, non
un'anomalia; il nome è nella mappa compilata locale); 72 porte TCP, 26
autoruns, 30 task non Microsoft; trovate la task custom di riavvio forzato notturno e una task
residua Lenovo su PC ASUS (✍️ da spiegare/pulire). Il confronto non-elevato vs elevato genera
rumore di visibilità: da qui l'avviso nel compare e la regola di confrontare snapshot omogenei.

## 2026-06-10 — Riallineamento documenti al join reale e snapshot multi-profilo Claude

Commit: e32d96b (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `CLAUDE.md` e `README.md` (la macchina è aziendale e registrata al tenant in
workplace join, NON Entra ID joined né Intune: vincoli del paletto 4 riformulati come cautele
prudenziali; nota che la chiave BitLocker NON è in Entra ID di default),
`scripts/Snapshot-Stato.ps1` (sezione 11: legge TUTTI i profili `.claude*` per account, inclusi
i multi-account via CLAUDE_CONFIG_DIR, inventario limitato a 200 voci, anche `.claude.json`
interno al profilo, sempre oscurato), schede `STACK.md` e `roadmap.md`.
Collaudo: 3 profili rilevati sull'account principale (.claude, .claude-account1 con 4815 file,
.claude-account2 con 788), scansione segreti sull'output pulita.

## 2026-06-10 — Mappa compilata, blocco postura hardware/OS, riduzione rumore alert

Commit: e32d96b (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (postura hardware/OS in sezione 8 →
`sicurezza_postura.txt` + `hotfix.csv`; filtro profili di servizio TEMP*/UMFD*; TPM e
InstalledOn robusti senza admin e su locale italiano), `scripts/Compare-Snapshot.ps1`
(categoria alert POSTURA; esclusione porte UDP effimere ≥49152 dal rumore),
`docs/01_MAPPA_CONFIGURAZIONE.md` (righe postura in sezione 9),
`docs/01_MAPPA_CONFIGURAZIONE.compilata.md` (NUOVA, ignorata da git: mappa con i dati reali
dello snapshot 20260610_123233), schede `roadmap.md` e `current-work.md`.
Esito del collaudo non elevato: VBS attivo senza CredentialGuard/HVCI, firma SMB non richiesta,
RDP off, 25H2 26200.8457; confronto baseline→nuovo con 4 alert tutti legittimi.
Scoperte di mappatura: la macchina NON è Entra ID joined (solo workplace-registered al tenant
di lavoro, niente Intune) contrariamente a quanto assunto in CLAUDE.md/README; account
Administrator locale abilitato e account `dev` abilitato senza profilo (da indagare ✍️);
Defender risulta False da snapshot non elevato (da riconfermare da admin); lo snapshot non
legge ancora i profili Claude multi-account `~\.claude-account*` (voce aggiunta in roadmap).

## 2026-06-10 — Feature di sicurezza: superficie d'attacco nello snapshot e alert nel compare

Commit: ff519f0 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (nuova sezione 10 superficie d'attacco, export CSV
degli amministratori in sezione 2, rinumerazione 10→11 e 11→12), `scripts/Compare-Snapshot.ps1`
(sezione ALERT DI SICUREZZA a 8 categorie, diff per attributo dei servizi),
`docs/01_MAPPA_CONFIGURAZIONE.md` (nuova sezione 🔄 10, Veeam→11, changelog→12),
`docs/02_VEEAM_BACKUP_PORTABILITA.md` (richiami sez. 10→11), schede `STACK.md` e
`current-work.md`.
Motivo: caratterizzazione di cybersecurity decisa il 2026-06-10 (vedi roadmap).
Collaudo: snapshot reale completo senza errori e con scansione anti-segreti pulita; alert
verificati con uno snapshot sintetico manomesso in 7 punti (8/8 categorie scattate), poi
eliminato. Tre bug corretti strada facendo: gli script devono essere UTF-8 con BOM (PowerShell
5.1 legge l'UTF-8 senza BOM come ANSI e i caratteri tipografici spezzano le stringhe); la
sezione per-account assegnava `$home`, variabile read-only di PowerShell (ora `$homeDir`,
avrebbe attribuito i dati di ogni profilo all'esecutore); il diff generico esplodeva con CSV
vuoti (`Compare-Object` non accetta null).

## 2026-06-10 — Allineamento al sistema di progetto portabile

Commit: 7db4de7 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: import di `.claude/PROJECT-SYSTEM.md`, `rules/`, quattro skill del motore,
`templates/`; nuovo `.gitignore`; `settings.json`; `CLAUDE.local.md`; anatomia `memory/`;
`.mcp.json` segnaposto; anonimizzazione di `docs/03`, `docs/04`,
`rules/git-identity-and-repo.md` e `skills/init-project-system/SKILL.md`.
Motivo: adozione retroattiva dello standard (sezione 11 di PROJECT-SYSTEM.md). La scansione
segreti su file tracciati e storia (un solo commit) è risultata pulita. Il repository GitHub è
risultato PUBBLICO: i dati identificativi reali sono stati sostituiti con segnaposto nei file
tracciati e spostati in `CLAUDE.local.md` (ignorato). Rilevato che il vecchio `.gitignore`
escludeva `docs/**` in contraddizione con CLAUDE.md/README: ora i docs sono tracciabili e si
ignorano solo le copie compilate.
Nella stessa sessione: i tre script sono stati spostati in `scripts/` perché ricavano la radice
del progetto dalla cartella genitore (in radice avrebbero scritto gli snapshot fuori dal repo);
create e popolate dal codice attuale le sei schede di `context/` ancorate a 7db4de7; `CLAUDE.md`
integrato con procedura di ripresa e indice dei satelliti; istanziati gli stub di `_notes/` e
`.mcp.json` segnaposto. Schede tutte aggiornate rispetto a HEAD (= 7db4de7); il drift partirà
dal commit manuale di questo allineamento.

## 2026-06-08 — Commit iniziale del progetto

Commit: 7db4de7.
File: `Snapshot-Stato.ps1`, `Compare-Snapshot.ps1`, `Reinstall-Software.ps1`, `README.md`,
`CLAUDE.md`, `.gitignore` (i `docs/` esistevano ma erano esclusi da git).
Motivo: prima versione degli script di fotografia/confronto/reinstallazione e dei documenti di
progetto, come da messaggio di commit.
