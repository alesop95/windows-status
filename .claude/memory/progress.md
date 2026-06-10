# Work-log

> Append-only, in ordine cronologico inverso (la voce più recente in alto). Ogni passo
> significativo di codice e ogni intervento manuale rilevante lascia una voce con data, file
> toccati, motivo e commit di riferimento. Qui confluisce anche il log di riconciliazione dei
> documenti `.docx`, con il nome del documento sorgente e l'esito, così la data di allineamento
> sopravvive a un clone.

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
