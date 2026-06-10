# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: 9407b27
Data snapshot:        2026-06-10
```

Working tree non pulito: `snapshot.json` (riepilogo strutturato) implementato e collaudato; il
commit è manuale dell'utente. La mappa compilata è locale (ignorata da git). Al commit
successivo portare i `last-verified-commit` al nuovo HEAD. La roadmap di caratterizzazione di
sicurezza è COMPLETA: il lavoro futuro è in "Punto di ripresa".

## Stato di verifica delle schede

| Scheda | last-verified | Stato |
|---|---|---|
| STACK.md | e32d96b | aggiornata (descrive il working tree, commit in attesa) |
| design-and-security.md | e32d96b | aggiornata |
| deployment.md | e32d96b | aggiornata |
| dev-testing.md | e32d96b | aggiornata |
| current-work.md | e32d96b | tre feature implementate e collaudate, in attesa di commit |
| roadmap.md | e32d96b | aggiornata |

## Punto di ripresa

Dopo il commit manuale: (1) decisioni ✍️ dalla mappa compilata — BitLocker OFF, Secure Boot
disattivo con TPM pronto, logging PowerShell non configurato, residuo Lenovo, estensione
VPN/proxy nel browser — da affrontare una alla volta col paracadute Veeam; (2) un nuovo
snapshot ELEVATO come baseline pulita post-rimozione task (completa anche auditpol, secedit,
associazioni file); (3) roadmap residua: server MCP locale, fasi di pulizia guidate da docs/00,
documentazione manuale del job Veeam in mappa (sezione 11).
