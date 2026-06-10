---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: 74fb6c7
---

# Test di sviluppo

Non esiste un test runner automatico: la verifica è manuale e segue il carattere di sola lettura
degli script. Il ciclo minimo dopo ogni modifica a uno script è eseguirlo con i tre valori di
`-Scope`, controllare che `SUMMARY.txt` e i file attesi vengano prodotti senza errori nelle
sezioni, e soprattutto verificare la redazione: nessun output sotto `snapshots/` deve contenere
token, password o chiavi in chiaro. Prima di ogni push, essendo il repository pubblico, si
ricontrolla che i file tracciati non contengano identificativi reali (la checklist operativa
locale vive in `_notes/TEST-CHECKLIST.md`, ignorata).

Una suite Pester per `Protect-Secrets` e per la struttura dell'output è un'estensione possibile
ma non ancora decisa; se adottata andrà registrata come ADR e questa scheda aggiornata.
