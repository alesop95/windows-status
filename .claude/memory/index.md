# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: 7db4de7
Data snapshot:        2026-06-10
```

Working tree non pulito: l'allineamento al sistema portabile (anatomia `.claude`, nuovo
`.gitignore`, anonimizzazione docs, spostamento script in `scripts/`, schede `context/`) è
preparato ma il commit è manuale dell'utente. Al commit successivo eseguire `sync-context` per
portare i `last-verified-commit` al nuovo HEAD.

## Stato di verifica delle schede

| Scheda | last-verified | Stato |
|---|---|---|
| STACK.md | 7db4de7 | aggiornata (descrive il working tree, commit in attesa) |
| design-and-security.md | 7db4de7 | aggiornata (come sopra) |
| deployment.md | 7db4de7 | aggiornata (come sopra) |
| dev-testing.md | 7db4de7 | aggiornata (come sopra) |
| current-work.md | 7db4de7 | aggiornata (feature attive: superficie d'attacco, alert compare) |
| roadmap.md | 7db4de7 | aggiornata |

## Punto di ripresa

Dopo il commit manuale dell'allineamento: implementare il blocco "superficie d'attacco e
persistenza" in `scripts/Snapshot-Stato.ps1` e poi gli alert di sicurezza in
`scripts/Compare-Snapshot.ps1` (definition of done in `context/current-work.md`).
