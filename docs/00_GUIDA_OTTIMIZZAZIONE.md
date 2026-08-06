# 00 -  Ottimizzazione e debloating reale (PC Entra ID joined)

> Criterio del progetto: **prima la mappatura, poi la pulizia.** Arrivi qui dopo aver fatto la fotografia (Fase 1) e dopo aver verificato il paracadute Veeam (Fase 2). Se manca uno dei due, fermati.

---

## 1. Cosa significa "vero debloating" (i livelli)

Il debloating non è "premere un bottone": è agire, in modo reversibile, su **livelli diversi** di Windows. Capirli serve a sapere *cosa* tocca un tool e *perché* qualcosa può rompersi.

| Livello                                 | Cos'è                                               | Come si vede nello snapshot       |
| --------------------------------------- | --------------------------------------------------- | --------------------------------- |
| **App utente (Appx installate)**        | App moderne installate per un utente                | `app_appx_allusers.csv`           |
| **App provisioned**                     | App che Windows reinstalla per ogni *nuovo* profilo | `app_appx_provisioned.csv`        |
| **Funzionalità / componenti opzionali** | Features on demand, capabilities                    | (DISM / Funzionalità facoltative) |
| **Servizi**                             | Servizi di Windows e di terze parti                 | `servizi.csv`                     |
| **Attività pianificate**                | Task che girano in background                       | `attivita_pianificate.csv`        |
| **Telemetria / privacy**                | Diagnostica, pubblicità, suggerimenti               | impostazioni + registro           |
| **Componenti AI**                       | Copilot, Recall, suggerimenti AI                    | Winslop li mappa                  |

Regola pratica del "vero debloating":

- **Disinstalla** ciò che è chiaramente inutile *per te* (app consumer, giochi).
- **Disattiva** (non cancellare) quando il componente potrebbe servire o tornare con un update.
- **Non de-provisionare in modo permanente** su una macchina gestita: rischia di confliggere con Intune e con il servicing di Windows (lo store CBS).
- Ogni passo: **uno alla volta > riavvio > verifica > changelog.**

---

## 2. Vincoli specifici perché la macchina è Entra ID joined / M365

Lo snapshot conferma lo stato (`join_dsregcmd.txt`, riga `AzureAdJoined : YES`). Su questa macchina:

- **Non azzerare la telemetria.** Intune/Entra usano i dati diagnostici per la **conformità**.  Si può *ridurre* il superfluo, non spegnere tutto.
- **Non rimuovere gli agenti di gestione** (MDM/Intune), né disattivare i servizi che li reggono.
- **Tieni Microsoft Edge / WebView2.** Flussi di **SSO, Conditional Access** e diverse app (Teams, componenti M365) ci appoggiano. Rimuoverlo può rompere l'accesso.
- **Tieni OneDrive** se usi lo *Spostamento cartelle note* (Desktop/Documenti sincronizzati).
- **Windows Update e Defender** restano. La sicurezza del tenant dipende anche da questi.
- Se compaiono **policy bloccate** (voci in grigio nelle impostazioni), sono imposte da Intune: non forzarle, eventualmente si gestiscono dal portale.

> In pratica: su questa macchina il debloating "vero" è soprattutto **AI/slop, app consumer, suggerimenti e avvio**, non lo smontaggio dei servizi di sistema.

---

## 3. Gli strumenti open-source (come usarli, in concreto)

### Winhance -  https://winhance.net (GitHub: memstechtips/Winhance)

Debloat + ottimizzazione + personalizzazione con interfaccia chiara; **crea un punto di ripristino** e molte azioni sono reversibili via toggle. Versione installabile o portable.

Uso consigliato qui:

1. Avviarlo (portable va benissimo).
2. **App:** rimuovere solo app consumer che si riconoscono (deselezionando tutto il resto).
3. **Optimize/Privacy:** ridurre suggerimenti, notifiche e telemetria *senza azzerarla* (vedi §2).
4. **Software (WinGet):** utile per reinstallare strumenti su un PC nuovo, non necessario ora.
5. Applica > **riavvia** > verifica > annota nel changelog.

### Winslop -  pagina MajorGeeks (open-source, fork di CrapFixer, ~170 KB)

Mirato alle **componenti AI/"slop"** di Windows 11 (Copilot, Recall, suggerimenti, promozioni). Tende a **disattivare invece di cancellare** e ha modalità di backup/ripristino. L'uso consigliato è:

1. *Inspect System*: leggi cosa trova.
2. Seleziona **Recall, Copilot, suggerimenti** e ciò che non usi; lascia stare ciò che non conosci.
3. Applica (preferisci "disattiva" dove c'è la scelta) > **riavvia** > verifica > changelog.

> Scarica **solo** dalle fonti ufficiali (sito/GitHub). Evita mirror e "PC cleaner" commerciali.

### Strumenti dalla tua lista

- `cleanmgr` (Pulizia disco), `sfc /scannow`, `DISM /Online /Cleanup-Image /RestoreHealth`.
- *Wise Registry Cleaner*: se lo usi, accetta il **backup del registro** che propone prima di pulire.

---

## 4. Debloating manuale (complementare ai tool, tutto reversibile)

Da usare quando vuoi precisione o per documentare *esattamente* cosa fai. Esempi (PowerShell admin).

**Vedere le app installate per tutti gli utenti**

```powershell
Get-AppxPackage -AllUsers | Select-Object Name | Sort-Object Name
```

**Rimuovere una singola app per l'utente corrente** (reversibile: reinstallabile da Store/WinGet)

```powershell
Get-AppxPackage *NomeApp* | Remove-AppxPackage
```

**Disattivare un servizio inutile (uno alla volta!)** -  annota lo stato PRIMA dallo snapshot

```powershell
Get-Service NomeServizio                 # leggi stato attuale
Set-Service NomeServizio -StartupType Manual   # piu prudente di "Disabled"
```

**Disattivare un'attività pianificata superflua**

```powershell
Disable-ScheduledTask -TaskPath "\Microsoft\Windows\..." -TaskName "Nome"
```

⛔ **Da NON fare su questa macchina (gestita):** `Remove-AppxProvisionedPackage` massivo, blocco di Windows Update, disinstallazione di Edge, disattivazione di servizi di sicurezza/gestione. Sono le operazioni che rompono il servicing o la conformità Intune.

---

## 5. Procedura passo-passo (Fase 3)

1. Conferma paracadute (immagine Veeam recente + restore point).
2. **App consumer** (Winhance) > applica > riavvia > verifica > changelog.
3. **AI/slop** (Winslop) > applica > riavvia > verifica > changelog.
4. **Privacy/suggerimenti/notifiche** (Winhance, senza azzerare la telemetria) > riavvia > verifica.
5. **Avvio automatico** (Task Manager) e servizi superflui (uno alla volta) > riavvia > verifica.
6. **Pulizia disco**: `cleanmgr`, temporanei, vecchi update; eventuale Wise (con backup registro).
7. **Re-mappatura** (Fase 4): `Snapshot-Stato.ps1` poi `Compare-Snapshot.ps1` > vedi cosa è cambiato.
8. Aggiorna `01_MAPPA_CONFIGURAZIONE.md` (sezioni 🔄) e il changelog.
9. Nuovo backup immagine "pulito" (Fase 5).

---

## 6. Se qualcosa si rompe

- Subito dopo una modifica > **Ripristino configurazione di sistema** all'ultimo punto.
- Problema profondo (boot, attivazione, instabilità) > **ripristino immagine Veeam** (doc 02).
- App rimossa per errore > reinstalla da Store o `winget install <id>` (id dallo snapshot WinGet).

> Il file `r/ItalyHardware – Risorse/Guide` è un buon hub generale, ma su una macchina **di lavoro e gestita** valgono prima i vincoli del §2.

---

## 7. Due modi di intervenire: PowerShell mirato vs strumenti esterni (separazione dei ruoli)

Sul *come* applicare le modifiche esistono due strade, complementari, da scegliere caso per caso.

**PowerShell mirato (nativo).** È la via predefinita del progetto. Si vede esattamente ogni comando e il suo rollback, è versionabile, e `Allinea-BestPractice.ps1` lo incapsula in controlli con `Test`/`Apply`/`Rollback`. Le rimozioni di app si fanno con `Remove-AppxPackage` (reversibile da Store), le impostazioni con chiavi di registro puntuali. È trasparente e chirurgico: agisce solo su ciò che dichiari. È la scelta giusta su una macchina di lavoro e per tutto ciò che deve restare riproducibile da un clone del repository.

**Strumenti esterni (Winhance, Winslop).** Agiscono "a colpi più larghi": toccano in un passo molti servizi, attività, chiavi e App. Sono comodi per un debloating ampio su un PC personale, ma su una macchina gestita vanno trattati con cautela, perché un'azione massiva può confliggere con Intune/servicing o disattivare qualcosa che serve. Non sono versionabili: l'unico modo per sapere *cosa* hanno toccato è confrontare lo stato prima e dopo.

**La regola di separazione.** I tool esterni *fanno* l'azione; `windows-status` fa da **rete di sicurezza e revisore**: fotografa, confronta, segnala. Quindi vanno sempre usati *tra due snapshot*. Procedura sicura, da seguire senza scorciatoie:

1. Scaricarli SOLO da fonte ufficiale (sito/GitHub di Winhance, MajorGeeks per Winslop). Mai mirror, mai "PC cleaner" commerciali.
2. Snapshot "prima" con `Snapshot-Stato.ps1` (idealmente elevato).
3. Usarli in modalità *inspect*, preferendo "disattiva" a "cancella", con il LORO punto di ripristino/backup attivo, oltre al paracadute Veeam.
4. Snapshot "dopo" + `Compare-Snapshot.ps1`: certifica esattamente cosa hanno toccato (servizi, task, registro, AppX) e gli ALERT dicono se hanno cambiato qualcosa di critico.
5. Tutto a changelog nella mappa (sezione 12), con il *come si annulla*.

**Scelta all'avvio.** Quando si lancia il flusso di ottimizzazione su una macchina, la decisione "PowerShell mirato e/o strumenti esterni, e con quale ampiezza" va posta esplicitamente all'operatore, non assunta. Il debloating delle app consumer di base resta più trasparente e reversibile con `Remove-AppxPackage` nativo; i tool esterni si riservano ai casi in cui serve un'azione più ampia, sempre dentro la procedura a due snapshot qui sopra.
