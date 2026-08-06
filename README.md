# windows-status

Fotografia **completa e ripristinabile** di un PC Windows 11, e progetto vivo per tenerla aggiornata nel tempo. Pensato per la mia macchina aziendale (registrata al tenant Microsoft 365 in modalità workplace join — non Entra ID joined né gestita da Intune — con backup Veeam Agent verso NAS) ma scritto in modo generico e riusabile **ovunque**.

> Gli script sono **proprietari**: la cartella `snapshots/` (dati specifici della macchina) è ignorata da git; si versionano gli script e i documenti.

---

## Idea di fondo

Lo "stato del PC" non lo scrivo a mano: lo faccio **rigenerare dalla macchina** con uno script di **sola lettura**. Lo stesso script fotografa anche **ogni account** (multi-account): utenti, programmi, e le configurazioni di **Claude**, **git**, **SSH** e dell'**ambiente di sviluppo**. I segreti non vengono mai salvati. Confrontando due fotografie vedo *esattamente* cosa è cambiato.

Il "ripristino ovunque" poggia su due gambe:
1. **Immagine Veeam** dell'intero computer - *bare metal recovery* anche su hardware diverso (il ripristino letterale del PC).
2. **Questo progetto** - la configurazione documentata e riproducibile (reinstallazione software, git/Claude/dotfiles, mappa) per ricostruire l'ambiente anche senza l'immagine.

---

## Regole

1. **Prima la mappatura, poi la pulizia.** Fotografia e documenti *prima* di toccare qualunque cosa.
2. **Prima del debloating, il paracadute:** immagine Veeam recente + punto di ripristino.
3. **Solo modifiche reversibili**, una categoria alla volta, con riavvio e verifica (Outlook/Teams/OneDrive/VPN/SSO) prima di procedere.
4. **Macchina aziendale registrata al tenant** (workplace join, senza Intune): non toccare senza motivo Windows Update, Defender, attivazione Office, Edge/WebView2, OneDrive; non azzerare la telemetria. Se la macchina diventasse Entra ID joined / gestita, questi vincoli tornerebbero imposti.
5. **Tutto a changelog** (sezione finale della mappa): data, cosa, perché, come si annulla.
6. **I segreti non entrano nei file né nel repo.** Si annota solo *dove* sono custoditi.

---

## Uso

**Snapshot completo** (consigliato: da PowerShell **amministratore**, altrimenti mancano BitLocker, Secure Boot, TPM, Defender e i dati degli altri account — il riepilogo segnala con cosa è stato eseguito):

```powershell
cd <cartella del progetto>
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Snapshot-Stato.ps1                 # tutto
.\scripts\Snapshot-Stato.ps1 -Scope Machine  # solo macchina
.\scripts\Snapshot-Stato.ps1 -Scope User     # solo account corrente (ripetere per ogni account)
```

**Confronto tra i due snapshot più recenti** (diff + sezione ALERT DI SICUREZZA in coda; confrontare snapshot presi con gli stessi privilegi, altrimenti il diff è rumore di visibilità):

```powershell
.\scripts\Compare-Snapshot.ps1
.\scripts\Compare-Snapshot.ps1 -Old <cartella> -New <cartella>
```

**Allineamento al baseline di sicurezza** (porta un PC vergine o difforme alle best practice; il report è sola lettura e sicuro ovunque, l'applicazione modifica il sistema e va fatta dopo aver verificato il paracadute — immagine recente + punto di ripristino):

```powershell
.\scripts\Allinea-BestPractice.ps1           # REPORT del divario (non modifica nulla)
.\scripts\Allinea-BestPractice.ps1 -Apply    # applicazione guidata, conferma per ogni passo (admin)
```

**Reinstallazione su un PC nuovo** (da amministratore, dopo aver rivisto il JSON):

```powershell
.\scripts\Reinstall-Software.ps1
```

L'output va in `snapshots\snapshot_<data>\` (ignorato da git): `SUMMARY.txt` per la sintesi, CSV/TXT per i dettagli, `utenti\` per le configurazioni per-account.

---