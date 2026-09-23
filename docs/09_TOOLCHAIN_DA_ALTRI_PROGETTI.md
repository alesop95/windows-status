# 09 — Toolchain aggiunta dagli altri progetti della macchina

Questa macchina ospita molti progetti su `D:\` ed `E:\`, e ciascuno installa ciò che gli serve. Il rischio, per un progetto che esiste per **ristabilire la stessa configurazione altrove**, è che quelle aggiunte non siano registrate da nessuna parte: al momento del ripristino mancherebbero componenti che nessun manifesto di pacchetti conosce, e che si riscoprono rompendosi.

Questo documento è il censimento anonimo di quelle aggiunte, ricavato il **2026-08-26** dai progetti citati e **verificato sulla macchina**, non dedotto dalle loro schede. La distinzione conta: in tre casi la scheda del progetto e lo stato reale della macchina non coincidono, e la sezione 3 li elenca.

> Regola di perimetro rispettata: i progetti censiti **non sono stati modificati in alcun modo**, nemmeno nei file di memoria. Sono stati aperti in sola lettura. L'unico progetto aggiornato è questo.

---

## 1. Cosa è stato censito

Sono stati esaminati `D:\network-design` in profondità, gli altri progetti di `D:\` con una passata mirata alle modifiche di sistema, e su `E:\` i tre progetti indicati: `retrogame-mod-pok-dev`, `home-lab-cybersec-networking`, `my-wedding-day`.

---

## 2. Componenti presenti sulla macchina (verificati)

Tutti i valori sotto sono stati letti dalla macchina il 2026-08-26, non dalle schede dei progetti.

| Componente | Versione | Canale / posizione | Progetto che lo richiede |
|---|---|---|---|
| Node.js | 22.23.1 | installer, `Node.js` nel registro | `my-wedding-day` (vincolato da `.node-version`) |
| npm | 10.9.8 | con Node | `my-wedding-day` |
| yarn | 1.22.22 | globale | `my-wedding-day` (script `prebuild`, `prestart`) |
| firebase-tools | 15.25.0 | npm globale, `%APPDATA%\npm` | `my-wedding-day` (emulatori, `test:rules`) |
| Eclipse Temurin **JRE** | 21.0.11+10 (x64) | `C:\Program Files\Eclipse Adoptium\jre-21.0.11.10-hotspot` | `my-wedding-day`: **gli emulatori Firebase non partono senza una JVM** |
| Browser Playwright | chromium 1223 e 1228, headless shell, ffmpeg, winldd | cache in `%LOCALAPPDATA%\ms-playwright` | `my-wedding-day` (suite `e2e`) |
| Python | 3.13.14 e 3.12.10 | installer, **due interpreti** | trasversale |
| Python (gestito da uv) | CPython 3.12.13 | `Astral/CPython3.12.13`, visibile solo con `py -0` | trasversale |
| `yt-dlp` | 2026.8.19 | `pip install --user`, `%APPDATA%\Python\Python313\Scripts` | `retrogame-mod-pok-dev` (sottotitoli come fonti citabili) |
| Deno | 2.9.5 | **WinGet**, shim in `%LOCALAPPDATA%\Microsoft\WinGet\Links` | `retrogame-mod-pok-dev` (runtime JS per yt-dlp) |
| ffmpeg | 9.0.1 full build (gyan.dev), compilato con `--enable-whisper` | **WinGet**, shim in `%LOCALAPPDATA%\Microsoft\WinGet\Links` | pipeline di trascrizione |
| .NET runtime | Desktop 8.0.31 e 10.0.12, NETCore 6.0.36 / 8.0.31 / 10.0.12, ASP.NET Core 8.0.29 / 8.0.31 / 10.0.12 (riletti il 2026-09-23 con `dotnet --list-runtimes`) | installer | `retrogame-mod-pok-dev` (applicazioni .NET Windows Forms) |
| .NET SDK | 10.0.401, dal 2026-09-23 | **WinGet**, pacchetto `Microsoft.DotNet.SDK.10`, in `C:\Program Files\dotnet\sdk` accanto ai runtime; verificato con `dotnet --list-sdks` | `retrogame-mod-pok-dev`: compila la libreria del verificatore di salvataggi dal clone del suo sorgente, che richiede `net10.0` e C# 14, per generare esemplari con la stessa libreria che ne giudica la legalità. Prima di questa data la macchina non aveva alcun SDK |
| git | 2.55.0.windows.3 | installer | trasversale |
| Veeam Agent for Microsoft Windows | 13.0.3.1220 | installer | vedi `08_MONITORAGGIO_BACKUP_VEEAM.md` |
| Driver CH340/CH341 (wch.cn - Ports) | 3.9.2024.9 | consegnato da Windows Update come driver di dispositivo, non da installer manuale; servizio kernel `CH341SER_A64` (`CH341S64.SYS`) | `retrogame-mod-pok-dev` (GBxCart RW v1.4 Pro, lettore di cartucce Game Boy/GBA) |
| FlashGBX | 5.1 | installer ufficiale (`FlashGBX-5.1_Windows-x64_Setup.exe`, da `github.com/Lesserkuma/FlashGBX`, digest SHA-256 verificato contro l'API di GitHub prima dell'esecuzione), in `C:\Users\Utente\AppData\Local\Programs\FlashGBX`; componente driver del setup deliberatamente escluso perché ridondante col driver già fornito da Windows Update | `retrogame-mod-pok-dev` (lettura/scrittura cartucce e salvataggi tramite il GBxCart RW) |
| PKHeX | 26.8.26.0 | eseguibile portable in `E:\tools\pkhex\PKHeX.exe` (56,5 MB), da `github.com/kwsch/PKHeX`; pubblicazione self-contained, nessun `PKHeX.exe.config` o `runtimeconfig.json` a fianco: porta il proprio runtime .NET incorporato nel file singolo e non dipende dalle versioni di `Microsoft.WindowsDesktop.App` installate sulla macchina | `retrogame-mod-pok-dev` (editing e verifica di legalità dei salvataggi Pokemon, in uso da circa un mese) |

Due osservazioni che contano per il ripristino. La prima è che **WinGet è diventato un canale di installazione attivo** su questa macchina, con shim in `%LOCALAPPDATA%`: lo snapshot lo esportava già in `software_winget.json`, quindi Deno e ffmpeg sono riproducibili con `winget import`. La seconda è che i pacchetti installati con `pip install --user` e la cache dei browser di Playwright **non appartengono a nessun manifesto**: la prima non compare né nel registro di Windows né in WinGet, la seconda è pesante e va riscaricata a comando esplicito. Entrambe erano invisibili allo snapshot prima di questa tornata.

---

## 3. Divergenze fra le schede dei progetti e lo stato reale

Registrate qui perché sono verificate, e **non** propagate ai progetti di origine, che per vincolo non sono stati toccati. Chi lavora su quei progetti le può recepire quando vuole.

**Il runtime .NET è la versione 8, non la 9 — CHIUSA il 2026-09-15, non era un blocco.** La scheda di `retrogame-mod-pok-dev` dichiarava ".NET 9 Desktop" fra i componenti sul PC per l'editor di salvataggi, e questo censimento aveva segnalato il rischio che PKHeX non partisse senza quella versione esatta. Verificato ora che PKHeX è installato e in uso da circa un mese (versione 26.8.26.0): è una pubblicazione self-contained, che porta il proprio runtime .NET incorporato nell'eseguibile da 56,5 MB, quindi non dipende in alcun modo dalle versioni di `Microsoft.WindowsDesktop.App` presenti sulla macchina, oggi 8.0.31 e 10.0.12. Il presunto blocco non esisteva: la scheda del progetto dichiarava una dipendenza che l'eseguibile reale non ha.

**Deno è già installato.** La stessa scheda lo presenta come una decisione ancora da prendere, perché "aggiunge un componente alla macchina". Il componente c'è: Deno 2.9.5, installato via WinGet. La decisione risulta quindi già presa, o presa altrove senza aggiornare la scheda.

**La catena del lettore di cartucce non è sulla macchina — CHIUSA il 2026-09-15.** Al censimento del 2026-08-26 non risultavano installati i driver seriali CH340 e CH341, né gli eseguibili del software di lettura o dell'editor di salvataggi: coerente con lo stato del sottoprogetto, allora non ancora operativo. Il 2026-09-15 il lettore GBxCart RW è stato collegato: Windows Update ha fornito da sé il driver CH340/CH341 (pacchetto del produttore "wch.cn - Ports" 3.9.2024.9) senza alcun installer manuale, e FlashGBX 5.1 è stato installato con il suo setup ufficiale. La catena è ora sulla macchina per intero, con le versioni esatte in tabella nella sezione 2.

---

## 4. Dipendenze non locali, da non confondere con software installato

Due dipendenze dei progetti censiti **non sono componenti di questa macchina** e non vanno nel piano di reinstallazione, ma vanno sapute perché il progetto che le usa si rompe senza di esse.

La prima è un **secondo computer con GPU** raggiungibile in rete locale, che espone un servizio di inferenza su HTTP e serve a condensare fonti lunghe prima che entrino in conversazione. È una dipendenza di rete: sopravvive a una re-immagine di questa macchina, ma non a un cambio di rete o di indirizzo. Indirizzo reale in `CLAUDE.local.md`.

La seconda è la **gestione degli endpoint via RMM**, già nota a questo progetto. Da `D:\network-design` arriva la conferma che l'RMM applica policy e automazioni e **ruota la password locale ogni trenta giorni**. La conseguenza rilevante qui è che qualunque credenziale di questa postazione memorizzata in un apparato di rete o in un job dura al massimo trenta giorni, il che è anche il motivo per cui gli script del documento 08 non si appoggiano a credenziali di rete.

---

## 5. Esito della passata su `D:\`

`D:\network-design` è un progetto di documentazione e progettazione di rete: agisce su apparati, non sulla configurazione di Windows di questa macchina. Non introduce componenti locali oltre a Python, già presente. Ne emergono però tre fatti pertinenti a questo progetto, tutti già coerenti con quanto la mappa registra.

Il primo è la conferma della gestione via RMM con rotazione della password locale, trattata nella sezione 4. Il secondo è che la pratica aziendale consolidata prevede la **modifica del file `hosts` per endpoint**, che è una modifica di sistema locale e come tale merita di stare nella mappa: il file locale ha precedenza sul DNS, quindi una voce dimenticata sopravvive a qualunque correzione lato server ed è esattamente il tipo di residuo che uno snapshot deve fotografare. Il terzo riguarda l'identità di dispositivo: un intervento del 20/07/2026 su una postazione ha risolto un fallimento di autenticazione delle applicazioni Microsoft causato da una **registrazione workplace join orfana** con keyset software corrotto, rimossa e ricreata. Tocca direttamente il tema di `CLAUDE.md`, dove la registrazione al tenant in modalità workplace join è un fatto centrale, e conferma che quello stato va fotografato e non dato per stabile.

Gli altri progetti di `D:\` sono stati passati in cerca di modifiche al registro di sistema, alla configurazione di rete, al firewall, alle attività pianificate, alle funzionalità opzionali di Windows e alle variabili d'ambiente. **Nessuno ne introduce.** Sono progetti applicativi e di automazione che girano dentro il proprio perimetro.

---

## 6. Raccordo

Le voci di questo documento vanno riportate nella sezione software di `01_MAPPA_CONFIGURAZIONE.md` e considerate in `02_VEEAM_BACKUP_PORTABILITA.md` al momento di ricostruire la macchina, dove la sezione sul software per il nuovo hardware è il posto in cui la toolchain qui sopra diventa una lista di reinstallazione. La cattura automatica di queste informazioni è stata aggiunta alla sezione 13 di `scripts\Snapshot-Stato.ps1`, quindi da qui in avanti il censimento si aggiorna da sé a ogni snapshot.
