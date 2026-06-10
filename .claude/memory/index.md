# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: e32d96b
Data snapshot:        2026-06-10
```

Working tree non pulito: postura hardware/OS (snapshot+compare), filtro profili di servizio,
riduzione rumore alert, riallineamento CLAUDE.md/README al join reale (workplace, non Entra) e
lettura multi-profilo Claude `.claude*` sono implementati e collaudati; il commit è manuale
dell'utente. La mappa compilata `docs/01_MAPPA_CONFIGURAZIONE.compilata.md` è locale (ignorata
da git). Al commit successivo portare i `last-verified-commit` al nuovo HEAD.

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

Dopo il commit manuale: (1) snapshot da PowerShell ELEVATO (l'utente lo esegue) e
completamento nella mappa compilata di BitLocker, Defender, Secure Boot, TPM e dei dati
per-account degli altri profili; (2) prossimo blocco dalla roadmap (consigliato: Defender e
policy in profondità, che beneficia anch'esso dell'esecuzione elevata).
