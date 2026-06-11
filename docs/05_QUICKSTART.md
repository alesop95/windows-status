# 05 - Quickstart: come si usa `windows-status`

> Guida rapida d'uso. Per il dettaglio di ogni sezione vedi gli altri documenti in `docs/` e le
> intestazioni dei tre script in `scripts/`. Criterio del progetto: **prima la mappatura, poi la pulizia.**

## Cos'è
Una fotografia completa, ripetibile e a prova di manomissione di un PC Windows 11: stato di
sistema, sicurezza a livello di audit (postura, superficie d'attacco, persistenza, catena di
fiducia), configurazioni per ogni account (Claude multi-profilo, git, SSH, browser) e quanto
serve a **ricostruire la macchina altrove**. Ogni dato sensibile è oscurato alla fonte; ogni
snapshot si chiude con una scansione anti-segreti e un manifest SHA256.

## Il ciclo operativo

```
1. FOTOGRAFA   ->  .\scripts\Snapshot-Stato.ps1     (da PowerShell AMMINISTRATORE)
2. CONFRONTA   ->  .\scripts\Compare-Snapshot.ps1   (i due snapshot piu recenti)
3. TRIAGE      ->  ogni riga "! [CATEGORIA]" va spiegata o indagata
4. ANNOTA      ->  docs\01_MAPPA_CONFIGURAZIONE.compilata.md (locale) + changelog
5. VERSIONA    ->  git add/commit/push (operazione manuale dell'utente)
```

Fotografa prima e dopo ogni modifica importante (installazioni, pulizia, aggiornamenti grossi) e
periodicamente come controllo. `SUMMARY.txt` per la sintesi umana, `snapshot.json` per quella a
macchina, la sottocartella `utenti\` per le configurazioni per-account.

## Comandi

```powershell
cd <cartella del progetto>
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\scripts\Snapshot-Stato.ps1                 # fotografia completa (consigliato)
.\scripts\Snapshot-Stato.ps1 -Scope Machine  # solo dati di macchina
.\scripts\Snapshot-Stato.ps1 -Scope User     # solo account corrente (ripetere per ogni account)

.\scripts\Compare-Snapshot.ps1               # diff + sezione ALERT DI SICUREZZA
.\scripts\Compare-Snapshot.ps1 -Old <cartella> -New <cartella>

.\scripts\Reinstall-Software.ps1             # su un PC nuovo, dopo aver rivisto il JSON winget
```

**Allineare un PC al baseline di sicurezza** (su PC vergine o difforme; report sicuro ovunque,
applicazione solo dopo paracadute Veeam + punto di ripristino):

```powershell
.\scripts\Allinea-BestPractice.ps1           # REPORT del divario (sola lettura)
.\scripts\Allinea-BestPractice.ps1 -Apply    # applicazione guidata, conferma per ogni passo (admin)
.\scripts\Allinea-BestPractice.ps1 -Apply -Solo RDP-CACHE,PS-LOG   # solo alcuni controlli
```

## Le tre regole d'oro
1. **Sempre da amministratore** (Win+X -> Terminale Admin). Senza, mancano BitLocker, Secure
   Boot, TPM, Defender, secedit e gli altri account; il riepilogo lo segnala in testa.
2. **Confronta snapshot omogenei** (elevato con elevato): il Compare avvisa se i privilegi
   differiscono, perche da admin "si vede di piu" e il diff diventa rumore di visibilita.
3. **Se il repo e pubblico**: gli snapshot restano in `snapshots\` (ignorata da git), la mappa
   coi dati reali e la copia `*.compilata.md` (ignorata), e nei file tracciati vanno solo
   segnaposto. I valori reali vivono in `CLAUDE.local.md`.

## Le categorie di alert del Compare
`ADMIN` (nuovi amministratori) - `ACCOUNT` (creati/riabilitati) - `AUTORUN` (avvio + registro
profondo) - `TASK` (task nuove o azione cambiata) - `PORTE` (nuove porte in ascolto) - `SERVIZI`
(nuovi, StartMode/account cambiati, percorsi non quotati) - `DRIVER` (non firmati) - `POSTURA`
(Secure Boot, TPM, VBS, UAC, SMB, RDP... cambiati) - `DEFENDER` (nuove esclusioni, ASR
indebolite) - `FIREWALL` (nuove regole inbound) - `TRUST` (nuove root CA, publisher, hosts
modificato) - `BROWSER` (nuove estensioni). Regola di triage: *ogni alert e legittimo solo dopo
che sai spiegarlo*.

## Ripristino su un altro PC (le due gambe)
Immagine **Veeam** (bare metal, vedi `02_VEEAM_BACKUP_PORTABILITA.md`) + questo repo:
`Reinstall-Software.ps1` per i programmi, `task_xml\` per le attivita pianificate, `wifi\` e
`associazioni_file.xml` per le impostazioni, i file `utenti\` per ricostruire Claude/git/SSH, la
mappa per tutto il resto.

## Modifiche al sistema (debloating, hardening): regole
Tutto ciò che MODIFICA il sistema (debloating, servizi, registro, RDP, ecc.) NON è automatico:
si propone, si applica a micro-step, **una categoria alla volta**, con paracadute (immagine
Veeam recente + punto di ripristino) prima, e riavvio + verifica (Outlook/Teams/OneDrive/VPN/SSO)
dopo. Ogni modifica effettiva va a changelog nella mappa con: data, cosa, perche, come si annulla.

## Sistema di progetto (per Claude Code)
A inizio sessione Claude legge `.claude\memory\index.md` (commit di riferimento, stato schede,
**punto di ripresa**) e riparte da lì. `progress.md` è la storia, `decisions.md` le decisioni
(ADR), le schede `context\` descrivono il codice. Commit e push restano sempre manuali.
