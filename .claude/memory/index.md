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

Dopo il commit manuale: (1) DEBLOATING — eseguibile solo dopo che l'utente conferma il
paracadute (immagine Veeam recente + punto di ripristino); piano a micro-step pronto in
`current-work.md`, si parte dal Gruppo A (app consumer); nulla è ancora eseguito; (2) decisioni
✍️ dalla mappa compilata — BitLocker OFF, Secure Boot disattivo con TPM pronto, logging
PowerShell non configurato, residuo Lenovo, estensione VPN/proxy nel browser; (3) un nuovo
snapshot ELEVATO come baseline pulita post-modifiche (RDP, task) che completa anche auditpol,
secedit, associazioni file; (4) roadmap residua: server MCP locale, job Veeam in mappa (sez. 11).
