# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: 2552033
Data snapshot:        2026-06-10
```

Working tree non pulito: blocco Defender/policy in profondità (snapshot+compare, categorie
DEFENDER e FIREWALL), trigger delle task nel CSV, AV registrati, avviso elevazione, sezione
"Uso" nel README e mappa aggiornata; il commit è manuale dell'utente. La mappa compilata
`docs/01_MAPPA_CONFIGURAZIONE.compilata.md` è locale (ignorata da git). Al commit successivo
portare i `last-verified-commit` al nuovo HEAD.

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

Dopo il commit manuale: (1) leggere il trigger di `RiavvioSingoloNotturno` dall'export elevato
(`snapshots\task_riavvio.xml`, comando già dato all'utente) e decidere se rimuoverla; (2)
decisioni ✍️ dalla mappa compilata — BitLocker OFF, Secure Boot disattivo con TPM pronto,
logging PowerShell non configurato, residuo Lenovo; (3) prossimo blocco dalla roadmap
(candidati: catena di fiducia, export ripristinabili, integrità snapshot); (4) un nuovo
snapshot ELEVATO completerebbe auditpol e secedit nella mappa.
