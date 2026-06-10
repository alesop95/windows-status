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

Working tree non pulito: AV registrati nello snapshot, avviso elevazione nel compare, sezione
"Uso" nel README e mappa compilata aggiornata con i dati elevati; il commit è manuale
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

Dopo il commit manuale: (1) decisioni ✍️ dell'utente dalla mappa compilata — BitLocker OFF su
tutti i volumi, Secure Boot disattivo con TPM pronto, task `RiavvioSingoloNotturno` e residuo
Lenovo; (2) prossimo blocco dalla roadmap: Defender e policy in profondità (esclusioni AV, ASR,
auditpol, logging PowerShell), da eseguire con snapshot elevato.
