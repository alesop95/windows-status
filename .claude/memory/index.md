# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: ff519f0
Data snapshot:        2026-06-10
```

Working tree non pulito: le due feature di sicurezza (sezione superficie d'attacco nello
snapshot, alert nel compare) sono implementate e collaudate ma il commit è manuale dell'utente.
Al commit successivo eseguire `sync-context` per portare i `last-verified-commit` al nuovo HEAD.

## Stato di verifica delle schede

| Scheda | last-verified | Stato |
|---|---|---|
| STACK.md | ff519f0 | aggiornata (descrive il working tree, commit in attesa) |
| design-and-security.md | ff519f0 | aggiornata |
| deployment.md | ff519f0 | aggiornata |
| dev-testing.md | ff519f0 | aggiornata |
| current-work.md | ff519f0 | feature implementate e collaudate, in attesa di commit |
| roadmap.md | ff519f0 | aggiornata |

## Punto di ripresa

Dopo il commit manuale delle feature: compilare le sezioni 🔄 della mappa
`docs/01_MAPPA_CONFIGURAZIONE.md` con lo snapshot reale del 2026-06-10 (incluse le note di
legittimità della nuova sezione 10), poi scegliere il prossimo blocco dalla roadmap (consigliato:
postura hardware/OS).
