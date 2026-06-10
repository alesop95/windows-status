# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: 74fb6c7
Data snapshot:        2026-06-10
```

Working tree non pulito: blocchi catena di fiducia (TRUST), export ripristinabili (sezione 11),
ambiente utente esteso (BROWSER) e integrità (scansione finale + MANIFEST.sha256) implementati
e collaudati; il commit è manuale dell'utente. La mappa compilata è locale (ignorata da git).
Al commit successivo portare i `last-verified-commit` al nuovo HEAD.

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

Dopo il commit manuale: (1) conferma utente per rimuovere `RiavvioSingoloNotturno` (verdetto:
one-shot scaduta del 2025-11-30, innocua) — la rimozione va a changelog; (2) decisioni ✍️ dalla
mappa compilata — BitLocker OFF, Secure Boot disattivo con TPM pronto, logging PowerShell non
configurato, residuo Lenovo, estensione VPN/proxy nel browser; (3) un nuovo snapshot ELEVATO
completerebbe auditpol, secedit e associazioni file; (4) roadmap residua: output JSON
strutturato, server MCP locale, fasi di pulizia guidate da docs/00.
