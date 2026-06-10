---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: 7db4de7
---

# Stack applicativo

> Documento di recupero più importante: tracciato, perché un collega che clona deve vederlo.

## Stack e runtime

Il progetto è interamente in Windows PowerShell 5.1, senza dipendenze esterne: tre script
autosufficienti sotto `scripts/`, pensati per Windows 11 in lingua italiana. Lo snapshot
completo richiede una shell elevata (amministratore) per leggere i profili altrui, BitLocker e
Defender; l'inventario software usa `winget` quando presente e ripiega sul registro quando
manca. Non c'è build, non c'è gestore di pacchetti: si clona e si esegue.

## Alternative deliberatamente escluse

Non risultano alternative valutate e scartate documentate nella storia; la sezione si popola
quando una scelta del genere emerge.

## Flussi di codice e ruolo architetturale dei file

`scripts/Snapshot-Stato.ps1` è il cuore: produce in `snapshots/snapshot_<timestamp>/` una
fotografia di sola lettura, organizzata in tre parti governate dal parametro `-Scope`
(`All`, `Machine`, `User`). La parte macchina copre identità e join Entra ID (sezione 1),
account e sessioni (2), configurazioni di macchina (3), software da winget, registro e Appx (4),
servizi (5), avvio e attività pianificate (6), rete e firewall (7), sicurezza Defender e
BitLocker (8), rilevamento Veeam (9). La parte per-account (10) legge da disco, per ogni profilo
in `C:\Users`, le configurazioni di Claude, git e SSH, sempre tramite redazione dei segreti. La
parte utente live (11) fotografa l'ambiente di sviluppo dell'account che esegue. Ogni sezione
scrive file CSV o TXT dedicati e righe di sintesi in `SUMMARY.txt`.

`scripts/Compare-Snapshot.ps1` confronta due snapshot (di default i due più recenti) sui CSV
chiave — software, servizi, avvio, Appx, account locali, attività pianificate — e stampa le voci
aggiunte e rimosse per chiave primaria. Non rileva i cambi di attributo (per esempio lo
`StartMode` di un servizio): è il limite che la feature degli alert di sicurezza deve colmare.

`scripts/Reinstall-Software.ps1` chiude il cerchio della portabilità: reimporta su una macchina
nuova il `software_winget.json` prodotto dallo snapshot, previa revisione manuale del JSON.

Vincolo strutturale: tutti e tre gli script ricavano la radice del progetto come cartella
genitore della propria (`Split-Path -Parent $base`), quindi devono vivere in `scripts/`, mai
nella radice, altrimenti `snapshots/` finirebbe fuori dal repository.

## Riferimenti a snippet

`scripts/Snapshot-Stato.ps1:55` `Protect-Secrets` — redazione di api key, token, password, JWT.
`scripts/Snapshot-Stato.ps1:50` `Save`/`SaveUser` — convenzione di output verso lo snapshot.
`scripts/Compare-Snapshot.ps1:26` `$files` — mappa CSV→chiave primaria su cui si basa il diff.
