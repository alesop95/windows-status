---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
  - .gitignore
last-verified-commit: d98a77d
---

# Design e sicurezza applicativa

## Paradigmi di design

Il principio fondante è che lo stato non si scrive a mano: lo produce la macchina tramite uno script di sola lettura, e il cambiamento si misura per differenza tra due fotografie (ADR-001). Ogni sezione dello snapshot è avvolta in un `try/catch` non bloccante con `$ErrorActionPreference = 'Continue'`: una sorgente non leggibile degrada con una nota nel riepilogo, non interrompe la fotografia. L'output è testuale e diffabile (CSV e TXT), mai binario.

## Sicurezza applicativa

Tre livelli di difesa, in ordine. Primo, la redazione alla fonte: `Protect-Secrets` oscura nel testo api key, token, password, PAT GitHub, chiavi Anthropic e JWT prima che qualsiasi contenuto tocchi il disco; le chiavi SSH private e `.credentials.json` di Claude non vengono proprio letti, se ne inventaria solo la presenza. Secondo, il `.gitignore`: `snapshots/` (dati di macchina), pattern di segreti (`*.key`, `*.pem`, `*.env`, `*token*`, eccetera), il livello privato (`_notes/`, `CLAUDE.local.md`, `.claude/settings.local.json`) e le copie compilate dei documenti (`docs/*.compilata.md`). Terzo, la verifica umana prima di ogni push, perché il repository è pubblico (ADR-006): i file tracciati restano anonimi, i valori reali vivono in `CLAUDE.local.md`.

Vincolo di piattaforma: la macchina è registrata al tenant in modalità *workplace join*, non Entra ID joined né gestita da Intune (verificato dallo snapshot, vedi `CLAUDE.md`). Gli script leggono lo stato di Defender e BitLocker ma il progetto non li modifica mai senza ordine esplicito; la telemetria non si azzera per prudenza, in previsione di un eventuale futuro ingresso in Entra ID/Intune (paletti in `CLAUDE.md`). Conseguenza diretta per BitLocker: non essendoci Entra ID, la chiave di ripristino non ha un escrow automatico di piattaforma, quindi va custodita altrove (console RMM/MSP, copia offline) e annotata solo come *dove* nella mappa, mai come valore.

Quarto livello, specifico per BitLocker (ADR-007): lo snapshot non tratta mai la chiave di ripristino come dato da fotografare, nemmeno oscurata. Cattura invece il `KeyProtectorId` del protettore `RecoveryPassword`, un GUID che identifica il protettore senza permettere di sbloccare nulla, e lo confronta tra due fotografie: un GUID diverso è il segnale di una rigenerazione (disattivazione/riattivazione, cambio TPM, aggiornamento Windows che rompe la protezione) da far seguire da una verifica dell'escrow. La stessa fotografia estende la copertura hardware alla tabella delle partizioni intera (`Get-Partition`/`Get-Disk`, incluse le partizioni senza lettera come EFI/Recovery/MSR), altrimenti un intervento con `diskpart` che non cambia le lettere assegnate passerebbe inosservato.

Avvertenza operativa per gli strumenti di ricerca: ripgrep e gli strumenti che rispettano il `.gitignore` saltano i file ignorati, quindi una scansione di sicurezza su cartelle ignorate va fatta leggendo i file direttamente o disattivando il rispetto del `.gitignore`.
