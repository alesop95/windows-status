---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: e32d96b
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
account, sessioni e membri di Administrators (2), configurazioni di macchina (3), software da
winget, registro e Appx (4), servizi (5), avvio e attività pianificate (6), rete e firewall (7),
sicurezza Defender e BitLocker (8), rilevamento Veeam (9), e la superficie d'attacco e
persistenza (10): porte TCP/UDP in ascolto con processo proprietario, autoruns profondi
(Run/RunOnce per hive, Winlogon, IFEO con Debugger, SilentProcessExit), sottoscrizioni WMI in
`root\subscription`, azioni complete delle attività pianificate non Microsoft, firme dei driver
con estrazione dei non firmati, servizi con percorso non quotato. La parte per-account (11)
legge da disco, per ogni profilo in `C:\Users` (esclusi i profili di servizio TEMP*/UMFD-*), le
configurazioni di Claude — tutti i profili `.claude*`, inclusi i multi-account selezionati via
`CLAUDE_CONFIG_DIR`, con inventario limitato alle prime 200 voci e `settings.json`/`CLAUDE.md`/
`.claude.json` oscurati — più git e SSH, sempre tramite redazione dei segreti. La parte utente live (12) fotografa l'ambiente di sviluppo
dell'account che esegue. Ogni sezione scrive file CSV o TXT dedicati e righe di sintesi in
`SUMMARY.txt`. I CSV con comandi potenzialmente sensibili (autoruns, azioni delle task) passano
da `Protect-Secrets` prima del salvataggio.

`scripts/Compare-Snapshot.ps1` confronta due snapshot (di default i due più recenti) in due
passate: il diff generale per chiave sui CSV principali (voci aggiunte e rimosse), e la sezione
finale di ALERT DI SICUREZZA che incrocia i CSV della superficie d'attacco e gli attributi:
nuovi membri di Administrators, account creati o riabilitati, autorun nuovi (cartelle e
registro), task nuove o con azione cambiata, porte in ascolto nuove, servizi nuovi o con
StartMode/account di esecuzione cambiati, driver non firmati comparsi, servizi con percorso non
quotato comparsi. Se un CSV manca in uno dei due snapshot la categoria viene saltata senza
errori. Vincolo di codifica: gli script vanno salvati in UTF-8 con BOM, perché Windows
PowerShell 5.1 interpreta l'UTF-8 senza BOM come ANSI e i caratteri tipografici nelle stringhe
spezzano il parsing.

`scripts/Reinstall-Software.ps1` chiude il cerchio della portabilità: reimporta su una macchina
nuova il `software_winget.json` prodotto dallo snapshot, previa revisione manuale del JSON.

Vincolo strutturale: tutti e tre gli script ricavano la radice del progetto come cartella
genitore della propria (`Split-Path -Parent $base`), quindi devono vivere in `scripts/`, mai
nella radice, altrimenti `snapshots/` finirebbe fuori dal repository.

## Riferimenti a snippet

`scripts/Snapshot-Stato.ps1:56` `Protect-Secrets` — redazione di api key, token, password, JWT.
`scripts/Snapshot-Stato.ps1:51` `Save`/`SaveUser` — convenzione di output verso lo snapshot.
`scripts/Compare-Snapshot.ps1:41` `$files` — mappa CSV→chiave primaria su cui si basa il diff.
`scripts/Compare-Snapshot.ps1:72` `Add-Alert` — accumulo degli alert di sicurezza per categoria.
Avvertenza variabili: `$home` è read-only in PowerShell (la sezione per-account usa `$homeDir`).
