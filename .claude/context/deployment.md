---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
  - docs/02_VEEAM_BACKUP_PORTABILITA.md
last-verified-commit: 9407b27
---

# Deployment e uso operativo

Non esiste un hosting: il "deploy" è l'esecuzione degli script sulla macchina da fotografare e, in caso di ripristino, sul PC di destinazione.

## Esecuzione ordinaria

Da PowerShell come amministratore, nella radice del progetto:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Snapshot-Stato.ps1                 # fotografia completa (consigliato)
.\scripts\Snapshot-Stato.ps1 -Scope Machine  # solo dati di macchina
.\scripts\Snapshot-Stato.ps1 -Scope User     # solo account corrente (da ripetere per account)
.\scripts\Compare-Snapshot.ps1               # diff tra i due snapshot più recenti
```

L'output va in `snapshots/snapshot_<timestamp>/`, ignorato da git. I dati live per-utente (versioni runtime, estensioni VS Code, git config attivo) riflettono solo l'account che esegue: per la copertura completa si riesegue `-Scope User` in ogni account.

## Ripristino su un'altra macchina

La strategia è a due gambe (ADR-002). La gamba immagine è Veeam Agent verso NAS con bare metal recovery, documentata in `docs/02_VEEAM_BACKUP_PORTABILITA.md` e da annotare a mano nella mappa perché Veeam non esporta il job in modo affidabile via script. La gamba riproducibile è questo repository: `scripts/Reinstall-Software.ps1` reimporta il software dal `software_winget.json` dello snapshot, la mappa e i file per-account guidano la ricostruzione di git, SSH, Claude e dell'ambiente di sviluppo. Su hardware diverso, dopo il ripristino immagine, vanno previsti ri-join Entra ID e recupero della chiave BitLocker da Entra ID.
