# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: 9407b27
Data snapshot:        2026-06-11
```

Working tree non pulito: tracciamento cache bitmap RDP nello snapshot, `docs/05_QUICKSTART.md` e
`docs/06_RACCORDO_CHECKLIST_VA.md` nuovi, indice docs nel CLAUDE.md, piano debloating a secco in
current-work; più due modifiche EFFETTIVE al sistema già applicate (rimozione task one-shot,
disattivazione cache RDP). Il commit è manuale dell'utente. La mappa compilata è locale. Al
commit successivo portare i `last-verified-commit` al nuovo HEAD. Aggiunto inoltre il terzo
script `scripts/Allinea-BestPractice.ps1` (applicatore del baseline, dry-run di default).

## Stato di verifica delle schede

| Scheda | last-verified | Stato |
|---|---|---|
| STACK.md | 9407b27 | aggiornata (descrive il working tree, commit in attesa) |
| design-and-security.md | 9407b27 | aggiornata |
| deployment.md | 9407b27 | aggiornata |
| dev-testing.md | 9407b27 | aggiornata |
| current-work.md | 9407b27 | caratterizzazione completa; piano debloating a secco |
| roadmap.md | 9407b27 | aggiornata |

## Punto di ripresa

Hardening live in corso (paracadute Veeam confermato il 2026-06-11), una azione alla volta con
spiegazione + approvazione + changelog. FATTO: ScriptBlock logging ON; debloating Gruppo A
(5 componenti Xbox + DevHome rimossi, Media Player e Phone Link mantenuti); debloating Gruppo B
(rimosso Spotify, mantenuto WhatsApp). RIMANDATI: firma SMB (due NAS legacy/EOL + backup Veeam su
uno di essi) e Secure Boot (UEFI). BitLocker = PER ULTIMO (decisione utente). Prossimi possibili,
a scelta utente e sempre spiegati prima: (1) AI-slop (Copilot/BingSearch); (2) snapshot ELEVATO
di certificazione (completa anche auditpol, secedit, associazioni file); (3) BitLocker quando si
decide; (4) firma SMB/Secure Boot quando le condizioni sono risolte. Roadmap residua: server MCP locale, job Veeam in mappa.
