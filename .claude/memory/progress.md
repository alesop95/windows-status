# Work-log

> Append-only, in ordine cronologico inverso (la voce più recente in alto). Ogni passo
> significativo di codice e ogni intervento manuale rilevante lascia una voce con data, file
> toccati, motivo e commit di riferimento. Qui confluisce anche il log di riconciliazione dei
> documenti `.docx`, con il nome del documento sorgente e l'esito, così la data di allineamento
> sopravvive a un clone.

## 2026-06-12 — #4 Readiness operativa nello snapshot

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Sequenza suggerimenti minori
#4->#3->#5->#6->#7. #4 FATTO: blocco readiness in sezione 3 dello snapshot (`readiness.txt`):
riavvio in sospeso (CBS, WindowsUpdate RebootRequired, PendingFileRenameOperations, rinomina PC),
uptime/ultimo avvio, ultimo update installato (registro WU Results\Install LastSuccessTime),
modalità Defender + ultime quick/full scan + data firme. Compare: alert READINESS quando il
riavvio in sospeso passa da no a SI. Read-only, nessuna modifica al sistema. Collaudo: trovato
**riavvio in sospeso = SI** (CBS/WindowsUpdate/PendingFileRename) con uptime 9g → consigliato
all'utente di riavviare (rende effettivo anche LSA RunAsPPL); Defender "Not running" (AV di terze
parti attivo, scansioni nella sua console). Doc: STACK, mappa (sez. 1/9). Prossimo: #3 punteggio
conformità + mappatura ISO/CIS.

## 2026-06-12 — Verifica share di sviluppo D (accesso intatto) + nota password esposta

Commit: 9407b27. L'utente ha chiesto di ripristinare, se rimosso, l'accesso del client di
sviluppo (un host della LAN) alla share di sviluppo su questo PC, e ha incollato in chat la password
dell'account `dev` IN CHIARO. AZIONE DI SICUREZZA: password NON salvata da nessuna parte
(paletto 5); consigliata rotazione (registrato in mappa compilata, gitignored). Verifica
read-only: l'accesso era INTATTO — share `D` (D:\, "Condivisione per sviluppo interno"), permessi
share `dev`=Full, NTFS `dev`=FullControl, account abilitato; nulla da ripristinare. La share
corretta è `D` (non "developing"). Restrizione attuale per CREDENZIALE (solo dev/Utente), NON per
IP: per limitare al solo client servirebbe scoping firewall SMB (vale per tutto l'SMB del PC) o
restringere l'NTFS di D:\ a solo dev — proposte 3 opzioni all'utente, in attesa di scelta.
Disegno share documentato in mappa compilata (sez. 8), senza password.
SEGUITO (stesso giorno): l'utente ha scelto l'opzione 2 (restrizione per IP) dopo aver confermato
che lo scanner/stampante condivisi NON sono usati da altri host. Applicato (elevato, UAC):
`Set-NetFirewallRule -RemoteAddress <IP-client>` sulle 3 regole SMB inbound (FPS-SMB-In-TCP da
LocalSubnet, FPS-SMB-In-TCP-V2 da Any, FPS-NB_Session-In-TCP da LocalSubnet; IP reale nella mappa
locale). Solo il client di sviluppo raggiunge l'SMB in ingresso; uscita verso NAS/stampanti
intatta. Rollback esatto registrato in changelog
mappa. Chiarito all'utente: la restrizione è solo inbound, l'outbound (client verso NAS/stampanti)
non è toccato.

## 2026-06-12 — Meccanismo eccezioni / rischio accettato in Allinea-BestPractice

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Aggiunto il meccanismo di
eccezioni: `Allinea-BestPractice.ps1` legge `baseline-eccezioni.json` (radice, locale/ignorato da
git) e marca i controlli elencati come ACCETTATO (con motivo+data), escludendoli dalle proposte
di `-Apply`. Creato il file reale (gitignored) con ADMIN-BUILTIN accettato (account tenuti per
scelta dell'utente; motivo nel file locale) e il template tracciato `baseline-eccezioni.esempio.json`; aggiunta la regola
in `.gitignore`. Collaudo report: ADMIN-BUILTIN ora ACCETTATO (Conformi 4 / Da allineare 1 /
Accettati 1 / Da valutare 3); check-ignore conferma json ignorato ed esempio tracciato. Stessa
logica risk-accepted della checklist VA (docs/06). Doc: STACK, roadmap (completati 2026-06-12).
Resta come ultimo intervento di rilievo BitLocker; suggerimenti #3-#7 ancora aperti.

## 2026-06-11 — #8 Audit ACL cartelle sensibili + directory scrivibili nel PATH

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Implementato l'audit ACL
(read-only) nella sezione 10 dello snapshot: per un elenco curato di cartelle sensibili
(C:\, Windows, System32, Temp, Tasks, drivers, Program Files (x86/64), ProgramData, StartUp
all-users) e per ogni directory del PATH di sistema, segnala dove gruppi AMPI (Everyone S-1-1-0,
Authenticated Users S-1-5-11, Users S-1-5-32-545, Guests, Anonymous) hanno diritti di scrittura.
Logica per SID (locale-independent). Marca GRAVE = Modify/FullControl, oppure QUALSIASI scrittura
se la dir è nel PATH (DLL/exe planting). Output `acl_cartelle_sensibili.csv`; Add-Sum elenca i
gravi. Compare: categoria alert ACL su nuova ACL debole grave. Collaudo: 2 voci (ProgramData
Users, Tasks Authenticated Users) = default benigni di Windows, marcate non gravi → 0 alert;
nessuna dir scrivibile nel PATH. Doc: STACK, mappa sez. 1/9, roadmap (completati). Sequenza
suggerimenti #1→#2→#8 COMPLETATA. Restano: meccanismo eccezioni risk-accepted (in coda),
BitLocker (per ultimo), rimandati Secure Boot e firma SMB.

## 2026-06-11 — Baseline esteso: restore point automatico (#1) + igiene account (#2)

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Sequenza suggerimenti #1→#2→#8.
#1 FATTO: `Allinea-BestPractice.ps1 -Apply` ora crea AUTOMATICAMENTE un punto di ripristino prima
delle modifiche (Checkpoint-Computer; aggira temporaneamente la frequenza 24h e ripristina il
valore; se Protezione sistema off o non elevato, avvisa e chiede se proseguire con Veeam). Solo
codice, nessuna modifica live ora; report invariato.
#2 FATTO (costruzione): due nuovi controlli baseline, generici/portabili (per SID ed euristiche,
nessun nome hardcoded): ADMIN-BUILTIN (Administrator integrato -500 va disabilitato; Apply rifiuta
se è l'unico admin attivo — Test-AltroAdminAttivo) e ACCOUNT-DORMANTI (avviso: account abilitati
mai loggati o senza profilo). Collaudo report su questa macchina: ADMIN-BUILTIN=DA ALLINEARE
(Administrator abilitato), ACCOUNT-DORMANTI segnala un account locale (abilitato, senza profilo:
ha un LastLogon ma nessuna cartella in C:\Users). L'APPLICAZIONE (disabilitare Administrator) è una
modifica al sistema: proposta e RIFIUTATA dall'utente — RISCHIO ACCETTATO: Administrator usato
dall'utente, `dev` serve per accesso a una cartella di rete di sviluppo (per questo è senza
profilo: fa accessi alla share, non sessioni interattive). NON disabilitarli. Registrato in mappa
(sez. 2 + changelog). Aggiunta idea in roadmap: meccanismo di eccezioni/risk-accepted in
Allinea-BestPractice così il report mostra "ACCETTATO" invece di "DA ALLINEARE". #8 (audit ACL)
ancora da fare.

## 2026-06-11 — Debloating a livello macchina (mirato) + suggerimenti proposti

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Eseguito (elevato, UAC) il
debloating a livello macchina MIRATO sugli stessi target già approvati (5 Xbox + DevHome +
Copilot): `Remove-AppxPackage -AllUsers` + tentativo `Remove-AppxProvisionedPackage`. Esito
reale: account `Utente` pulito; le app NON erano provisioned (nuovi profili già puliti, obiettivo
principale raggiunto); resta 1 copia residua nel profilo **Administrator** per ciascuna
(`-AllUsers` non l'ha rimossa — si libera nel contesto di quell'account o è staged). Scelta:
lasciata così (Administrator è break-glass, valore marginale; nessun de-provisioning massivo →
paletto 4 ok). Reversibile. A changelog nella mappa. Metodo elevazione: solito script .ps1 +
Start-Process RunAs (poi rimosso).
Proposti all'utente nuovi suggerimenti (in attesa di scelta): (1) punto di ripristino automatico
prima di ogni -Apply; (2) igiene account (Administrator abilitato, account locale dormante);
(3) punteggio conformità baseline + mappatura ISO/CIS; (4) readiness nello snapshot (pending
reboot, Windows Update, ultima scansione AV); (5) report HTML autoconsistente; (6) estensione
baseline (Module logging/Transcription, ASR, LLMNR/NetBIOS, macro Office); (7) snapshot periodico
opt-in via scheduled task. Preferite: #1 e #2.

## 2026-06-11 — Software riproducibile e lista driver di terze parti per nuovo hardware

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Su richiesta utente (rimettere
in piedi Windows su hardware nuovo). Sezione 4: chiarito che `software_winget.json` reinstalla
all'ULTIMA versione (via Reinstall-Software.ps1/winget import), aggiunto `winget upgrade` ->
`software_winget_aggiornabili.txt` e conteggio pacchetti. Sezione 11 (export ripristinabili):
nuovo `driver_terze_parti.csv` = LISTA dei driver non-Microsoft (chipset/rete/GPU/audio/storage)
con dispositivo/classe/produttore/versione/inf, più nota su `Export-WindowsDriver -Online` +
`pnputil /add-driver` per portarsi e re-iniettare i file .inf sul nuovo PC. Collaudo: 59
pacchetti winget riproducibili, 34 driver terze parti (22 in classi critiche); scansione segreti
pulita. Doc: `docs/02` nuova sezione "Software e driver per il nuovo hardware"; mappa sez. 3/4
aggiornata; STACK aggiornato. Prossimo (a scelta utente): debloating a livello macchina; BitLocker
per ultimo; rimandati Secure Boot e firma SMB.

## 2026-06-11 — Licenza: procedura di migrazione su hardware nuovo

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Precisazione utente: la chiave
retail NON è custodita da lui, la detiene il FORNITORE. Documentata la procedura di migrazione
della licenza su hardware nuovo in `docs/02` ("Migrazione della licenza Windows su hardware
nuovo"): essendo RETAIL è trasferibile (la OEM no). Strada A (primaria nel suo caso): farsi dare
la chiave dal fornitore, liberare la vecchia con `slmgr /upk` + `/cpky`, inserirla sul nuovo PC.
Strada B (self-service): collegare la licenza digitale a un account Microsoft e riattivare con la
Risoluzione problemi di attivazione — con caveat che su PC di lavoro il collegamento di un MS
account personale può essere limitato da policy. Dopo ripristino Veeam su HW diverso: Windows si
disattiva, riattivare con A o B. Aggiornata la riga licenza-gestione nella mappa compilata (chiave
dal fornitore + le due strade). Nessuna modifica agli script in questo passo.

## 2026-06-11 — Controllo licenza/attivazione Windows nello snapshot

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Aggiunto alla sezione 3 il
controllo licenza Windows: edizione, canale (Retail/OEM/Volume via regex su Description), stato
attivazione (LicenseStatus mappato), ultimi 5 della product key, presenza chiave generica
(indizio licenza digitale), presenza chiave OEM in firmware ACPI MSDM — il tutto SENZA mai
salvare la chiave intera né la OEM (solo presenza/bool). Output `licenza_windows.txt` +
`licenza_windows.csv`. Compare: categoria alert LICENZA su cambio di stato attivazione o canale.
Collaudo + scansione: nessuna chiave intera trapelata (pattern 5x5 non trovato).
EVIDENZA macchina: Win 11 Pro, canale RETAIL, ATTIVATO, chiave generica `*****-3V66T`, nessuna
OEM in firmware → **licenza DIGITALE**. PRECISAZIONE dell'utente: la licenza digitale DERIVA da
un product key (retail). Gestione (in mappa, ✍️): (1) custodire la chiave retail originale
d'acquisto nel password manager (il sistema mostra solo la generica, non quella acquistata);
(2) collegare la licenza digitale all'account Microsoft per la riattivazione dopo
reinstall/cambio hardware. Aggiunta nota generica anche nell'output `licenza_windows.txt`. Nota in docs/02 sul
comportamento della licenza dopo ripristino Veeam su hardware diverso (digitale/retail/OEM).

## 2026-06-11 — Inventario hardware nello snapshot + avvio standardizzato Avvia.ps1

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Due build richiesti.
(1) INVENTARIO HARDWARE: nuovo blocco nella sezione 1 dello snapshot (rinominata "IDENTITA E
HARDWARE", nessuna rinumerazione delle altre). Cattura scheda madre, BIOS/UEFI, GPU, banchi RAM
(`hardware_ram.csv`), dischi fisici con tipo/bus/salute SMART (`hardware_dischi.csv`), volumi,
controller e dispositivi USB con conteggio dischi di massa (`hardware_usb_*.csv`), adattatori di
rete con LinkSpeed (`hardware_rete_adattatori.csv`), monitor EDID (`hardware_monitor.csv`), più
`hardware_inventario.txt` di sintesi. Compare esteso: dischi/USB/RAM nel diff per-chiave +
categoria alert HARDWARE (nuovo disco USB di massa = esfiltrazione, salute SMART non ottimale,
cambio RAM totale). Collaudato: 4 dischi (SATA/USB/NVMe) Healthy, 128 GB in 4 banchi, Ethernet
2.5 Gbps, 3 monitor; Compare gestisce senza errori il caso snapshot vecchio senza HW (skip
graceful). Limite noto e documentato: velocità USB per-dispositivo non esposta in modo
affidabile. NB: i valori hardware sono machine-identifying → vivono solo negli snapshot e nella
mappa compilata (entrambi gitignored), mai nei file tracciati.
(2) AVVIA.PS1 in radice: punto d'ingresso unico/menu che orchestra gli script di scripts\,
distingue sola-lettura da MODIFICA (conferma + paracadute), chiede l'approccio ottimizzazione
(docs/00 §7), ha `-Help` non interattivo per smoke test/CI. Rende l'uso standardizzato clonando
la repo su qualsiasi Windows 11. Doc aggiornata (STACK, mappa sez.1, quickstart, CLAUDE.md,
roadmap). Prossimo: debloating a livello macchina (opz.), BitLocker (per ultimo), rimandati
Secure Boot e firma SMB.

## 2026-06-11 — Snapshot elevato di CERTIFICAZIONE + separazione ruoli tool + nuove direzioni

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Eseguito snapshot ELEVATO di
certificazione (`snapshot_20260611_111205`) e Compare vs l'elevato del 2026-06-10 (`..._151411`).
Confermati: ScriptBlock logging=1, cache bitmap RDP disattivata, task `RiavvioSingoloNotturno`
rimossa, Spotify rimosso. SCOPERTA: Copilot/DevHome/Xbox sono rimossi solo per l'utente corrente
ma persistono a livello `-AllUsers`/provisioned (altri profili + nuovi profili) → ✍️ decidere se
estendere a livello macchina (rimozione mirata, mai de-provisioning massivo: paletto 4). I 3
alert del Compare sono il normale auto-update di OneDrive (26.088→26.095): legittimi.
Documentazione: aggiunta `docs/00` §7 "PowerShell mirato vs Winhance/Winslop" — separazione dei
ruoli, procedura sicura a due snapshot (fonte ufficiale, inspect/disattiva, prima/dopo, changelog),
e la regola di CHIEDERE all'avvio quale via usare. Roadmap aggiornata con: inventario hardware
intelligente (specifiche, dischi/SMART, porte USB+velocità, rete), avvio standardizzato/portabilità
(entrypoint unico per qualsiasi Win11 clonando la repo), debloating a livello macchina opzionale.
Salvata memoria [[bitlocker-implementazione-safe]] per l'ultimo intervento.

## 2026-06-11 — Hardening live (4): AI/slop, rimosso Copilot (BingSearch assente)

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Categoria AI/slop: rimossa
l'app `Microsoft.Copilot` per l'utente (per-utente, no UAC), reversibile da Store.
`Microsoft.BingSearch` non era installata per l'account, nulla da fare. Nota: Copilot può
ricomparire dopo aggiornamenti Windows; per bloccarla in modo persistente esiste la policy
`TurnOffWindowsCopilot` (HKCU, non applicata ora — eventuale follow-up). A changelog. Restano:
snapshot elevato di certificazione; rimandati Secure Boot e firma SMB; BitLocker per ultimo.

## 2026-06-11 — Hardening live (3): debloating Gruppo B (solo Spotify); Secure Boot rimandato

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Secure Boot: messo in
RIMANDATO come la firma SMB (richiede UEFI, non automatizzabile). BitLocker: confermato per
ULTIMO. Debloating Gruppo B (scelta utente "solo Spotify"): del Gruppo B erano presenti solo
Spotify e WhatsApp (StickyNotes/Todos/Maps assenti); rimosso `SpotifyAB.SpotifyMusic` per
l'utente, mantenuto WhatsApp Desktop (possibile uso lavorativo). Reversibile da Store. A
changelog. Prossimo a scelta utente: AI-slop (Copilot/BingSearch) o nuovo snapshot elevato di
certificazione; restano rimandati Secure Boot e firma SMB; BitLocker per ultimo.

## 2026-06-11 — Hardening live (2): firma SMB RIMANDATA, debloating Gruppo A applicato

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Azione 2 (firma SMB):
RIMANDATA su decisione informata — i NAS connessi sono 4, due EOL (modelli legacy) e il
backup Veeam punta a uno dei due vecchi; la firma SMB obbligatoria rischiava di tagliarli fuori. Da
riprendere quando i NAS legacy sono verificati/dismessi (sono già nella lista di remediation del
VA). Annotato in mappa.
Debloating Gruppo A (scelta utente "solo le superflue"): rimosse per l'account corrente, via
`Remove-AppxPackage` (per-utente, nessun UAC), XboxGamingOverlay, XboxGameOverlay,
XboxSpeechToTextOverlay, XboxIdentityProvider, Windows.DevHome. `XboxGameCallableUI` non
rimovibile (stub di sistema protetto, HRESULT 0x80073CFA — atteso). Mantenuti di proposito
Windows Media Player (ZuneMusic) e Phone Link (YourPhone). Reversibile da Store. A changelog.
Molte altre app del Gruppo A (BingNews/Weather, GamingApp, Clipchamp, FeedbackHub, ZuneVideo)
erano già assenti per l'utente. Prossimo: a scelta utente; restano BitLocker, Secure Boot, e la
firma SMB rimandata.

## 2026-06-11 — Hardening live (paracadute Veeam confermato): azione 1 ScriptBlock logging

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente). Avviata la fase di
applicazione del baseline su macchina reale, dopo che l'utente ha lanciato il backup immagine
Veeam sul NAS. Flusso concordato: spiegare ogni azione -> approvazione utente -> applicare ->
tracciare (changelog mappa + doc) -> snapshot -> azione successiva. UNA azione alla volta.
Azione 1 APPLICATA: PowerShell Script Block Logging abilitato (EnableScriptBlockLogging=1) via
processo elevato (UAC approvato), verificato col report Allinea-BestPractice (PS-LOG=CONFORME).
A changelog nella mappa compilata. Nota operativa: l'elevazione con one-liner e virgolette
annidate non faceva comparire l'UAC; affidabile invece scrivere uno script .ps1 temporaneo e
lanciarlo con `Start-Process -Verb RunAs -File` (poi rimosso). Prossima: azione 2 firma SMB
(rischio medio per i NAS), da spiegare e approvare prima.

## 2026-06-11 — Nuovo strumento: Allinea-BestPractice.ps1 (applicatore reversibile del baseline)

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Allinea-BestPractice.ps1` (NUOVO — terza gamba del tool: allinea un PC
vergine o difforme al baseline di sicurezza emerso dall'analisi), più documentazione (`STACK.md`,
`README.md`, `docs/05_QUICKSTART.md`, `CLAUDE.md` cosa-puoi-fare e struttura).
Design: dichiarativo (lista di controlli con Test/Apply/rollback), DRY-RUN di default (stampa
solo il divario, sola lettura), `-Apply` chiede conferma per ogni controllo non conforme, salta
quelli che richiedono admin se non elevato, logga in `snapshots/allineamento_<stamp>.log`, non
tocca Windows Update/Defender/Office/Edge/OneDrive/Intune, e segnala (senza forzare) Secure Boot
e BitLocker. Baseline: RDP-CACHE, SMB-SIGN (client+server), SMB1-OFF, PS-LOG (ScriptBlock
logging), LSA-PPL, + avvisi SECUREBOOT/BITLOCKER. Collaudato in modalità report su questa
macchina (non elevato): 3 conformi, 2 da allineare (firma SMB, ScriptBlock logging), 2 da
valutare. Nessuna applicazione eseguita: il paracadute Veeam si lancia all'avvio del lavoro.

## 2026-06-10 — Cache RDP disattivata, raccordo checklist VA, quickstart, piano debloating a secco

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (tracciamento cache bitmap persistente RDP nella
postura: legge sia il registro `DisablePersistentCache` sia `Default.rdp`
`bitmapcachepersistenable`, perché la checkbox della GUI mstsc scrive nel .rdp, non nel
registro), `docs/05_QUICKSTART.md` (NUOVO, dal recap d'uso, anonimo), `docs/06_RACCORDO_CHECKLIST_VA.md`
(NUOVO, raccordo concettuale con la checklist di remediation VA — su richiesta utente, dopo aver
letto il loro tool HTML), `CLAUDE.md` (indice satelliti), mappa template e compilata, `current-work.md`.
Modifica EFFETTIVA al sistema (approvata): disattivata la cache bitmap RDP in modo robusto
(registro=1, Default.rdp=0, cache svuotata) — la modifica che l'utente aveva fatto via GUI non
si era salvata (Default.rdp restava 1, 5 file in cache); ora snapshot conferma DISATTIVATA. A
changelog nella mappa compilata. Debloating: prodotto SOLO il piano a micro-step (analisi a
secco, nulla eseguito) su richiesta utente — paracadute non ancora confermato; candidati app
consumer divisi in gruppi A/B/C dall'inventario reale (212 Appx), MSTeams e PowerAutomate
esclusi perché di lavoro.

## 2026-06-10 — snapshot.json e rimozione della task one-shot di riavvio

Commit: 9407b27 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (riepilogo strutturato `snapshot.json`: data, scope,
elevazione, conteggi chiave, indice dei file — collaudato con -Scope User, conteggi macchina
correttamente null). Prima modifica EFFETTIVA al sistema del progetto: rimozione della task
residua `RiavvioSingoloNotturno` (one-shot del 2025-11-30 scaduta), eseguita da elevato con
consenso UAC dell'utente e registrata nel changelog della mappa compilata. La roadmap di
caratterizzazione di sicurezza decisa il 2026-06-10 è completata.

## 2026-06-10 — Quattro blocchi finali: fiducia, export, ambiente esteso, integrità; verdetto task

Commit: 74fb6c7 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (catena di fiducia in sezione 8: root CA, Trusted
Publishers, hosts, proxy, DoH; nuova sezione 11 EXPORT RIPRISTINABILI: Wi-Fi senza chiavi,
associazioni file, powercfg, internazionali, XML task oscurati; sezione 13: Windows Terminal,
profili PowerShell, cmdkey, estensioni browser; Protect-Secrets esteso ad AWS/Slack/PEM;
scansione anti-segreti finale e MANIFEST.sha256; rinumerazione 11/12→12/13),
`scripts/Compare-Snapshot.ps1` (categorie TRUST e BROWSER), mappa template e compilata.
Collaudo su snapshot completo reale: 76 root CA e 1 Trusted Publisher in baseline, hosts con 11
righe attive tutte legittime (NAS, Docker, progetti locali), 21 XML di task esportati, 27
estensioni browser (notata estensione VPN/proxy → ✍️ in mappa), scansione finale anti-segreti
PULITA, manifest prodotto; confronto tra snapshot omogenei con un solo alert benigno (mDNS).
Verdetto su `RiavvioSingoloNotturno` (XML esportato da elevato con consenso UAC dell'utente):
TimeTrigger SINGOLO del 2025-11-30 04:00 senza ripetizione, residuo già scaduto, innocuo;
rimozione proposta e in attesa di conferma.

## 2026-06-10 — Blocco Defender/policy in profondità e indagine task di riavvio notturno

Commit: 2552033 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (sezione 8: esclusioni Defender, regole ASR, Tamper
Protection e modalità, auditpol, logging PowerShell, secedit, regole firewall inbound
consentite; sezione 10: colonna Trigger nelle azioni delle task), `scripts/Compare-Snapshot.ps1`
(categorie DEFENDER e FIREWALL), mappa template e compilata (nuove righe sezione 9).
Collaudo: degradazione senza admin corretta; alert DEFENDER/FIREWALL verificati con test
sintetico (3/3); baseline di 215 regole firewall inbound; logging PowerShell risultato non
configurato (✍️ candidato hardening). Con AV di terze parti attivo, Defender è "Not running" e
le sue esclusioni non sono leggibili localmente (vivono nella console dell'AV).
Indagine `RiavvioSingoloNotturno`: la task esiste (Ready, percorso radice, autore vuoto, azione
shutdown /r /f /t 0) ma è visibile solo da sessione elevata; la sessione utente è attiva dal
03/06, quindi NON sta riavviando ogni notte — probabile one-shot residua. Trigger esatto da
leggere con export elevato (comando lasciato all'utente); decisione di rimozione rinviata a
quando si conoscerà il trigger.

## 2026-06-10 — Snapshot elevato, mappa completata, AV registrati, avviso elevazione

Commit: 2552033 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (sezione 8: antivirus registrati via
SecurityCenter2), `scripts/Compare-Snapshot.ps1` (avviso quando i due snapshot hanno privilegi
diversi), `README.md` (nuova sezione "Uso" con i comandi di snapshot/confronto/reinstallazione
e l'avvertenza sull'esecuzione elevata), mappa compilata aggiornata con i dati elevati.
Esiti dello snapshot ELEVATO (eseguito dall'utente, snapshot_20260610_151411): BitLocker OFF su
tutti i volumi; Secure Boot disattivo con TPM presente e pronto; Defender in passivo perché
l'AV attivo è un endpoint di terze parti registrato in SecurityCenter2 (normale, non
un'anomalia; il nome è nella mappa compilata locale); 72 porte TCP, 26
autoruns, 30 task non Microsoft; trovate la task custom di riavvio forzato notturno e una task
residua Lenovo su PC ASUS (✍️ da spiegare/pulire). Il confronto non-elevato vs elevato genera
rumore di visibilità: da qui l'avviso nel compare e la regola di confrontare snapshot omogenei.

## 2026-06-10 — Riallineamento documenti al join reale e snapshot multi-profilo Claude

Commit: e32d96b (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `CLAUDE.md` e `README.md` (la macchina è aziendale e registrata al tenant in
workplace join, NON Entra ID joined né Intune: vincoli del paletto 4 riformulati come cautele
prudenziali; nota che la chiave BitLocker NON è in Entra ID di default),
`scripts/Snapshot-Stato.ps1` (sezione 11: legge TUTTI i profili `.claude*` per account, inclusi
i multi-account via CLAUDE_CONFIG_DIR, inventario limitato a 200 voci, anche `.claude.json`
interno al profilo, sempre oscurato), schede `STACK.md` e `roadmap.md`.
Collaudo: 3 profili rilevati sull'account principale (.claude, .claude-account1 con 4815 file,
.claude-account2 con 788), scansione segreti sull'output pulita.

## 2026-06-10 — Mappa compilata, blocco postura hardware/OS, riduzione rumore alert

Commit: e32d96b (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (postura hardware/OS in sezione 8 →
`sicurezza_postura.txt` + `hotfix.csv`; filtro profili di servizio TEMP*/UMFD*; TPM e
InstalledOn robusti senza admin e su locale italiano), `scripts/Compare-Snapshot.ps1`
(categoria alert POSTURA; esclusione porte UDP effimere ≥49152 dal rumore),
`docs/01_MAPPA_CONFIGURAZIONE.md` (righe postura in sezione 9),
`docs/01_MAPPA_CONFIGURAZIONE.compilata.md` (NUOVA, ignorata da git: mappa con i dati reali
dello snapshot 20260610_123233), schede `roadmap.md` e `current-work.md`.
Esito del collaudo non elevato: VBS attivo senza CredentialGuard/HVCI, firma SMB non richiesta,
RDP off, 25H2 26200.8457; confronto baseline→nuovo con 4 alert tutti legittimi.
Scoperte di mappatura: la macchina NON è Entra ID joined (solo workplace-registered al tenant
di lavoro, niente Intune) contrariamente a quanto assunto in CLAUDE.md/README; account
Administrator locale abilitato e account `dev` abilitato senza profilo (da indagare ✍️);
Defender risulta False da snapshot non elevato (da riconfermare da admin); lo snapshot non
legge ancora i profili Claude multi-account `~\.claude-account*` (voce aggiunta in roadmap).

## 2026-06-10 — Feature di sicurezza: superficie d'attacco nello snapshot e alert nel compare

Commit: ff519f0 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: `scripts/Snapshot-Stato.ps1` (nuova sezione 10 superficie d'attacco, export CSV
degli amministratori in sezione 2, rinumerazione 10→11 e 11→12), `scripts/Compare-Snapshot.ps1`
(sezione ALERT DI SICUREZZA a 8 categorie, diff per attributo dei servizi),
`docs/01_MAPPA_CONFIGURAZIONE.md` (nuova sezione 🔄 10, Veeam→11, changelog→12),
`docs/02_VEEAM_BACKUP_PORTABILITA.md` (richiami sez. 10→11), schede `STACK.md` e
`current-work.md`.
Motivo: caratterizzazione di cybersecurity decisa il 2026-06-10 (vedi roadmap).
Collaudo: snapshot reale completo senza errori e con scansione anti-segreti pulita; alert
verificati con uno snapshot sintetico manomesso in 7 punti (8/8 categorie scattate), poi
eliminato. Tre bug corretti strada facendo: gli script devono essere UTF-8 con BOM (PowerShell
5.1 legge l'UTF-8 senza BOM come ANSI e i caratteri tipografici spezzano le stringhe); la
sezione per-account assegnava `$home`, variabile read-only di PowerShell (ora `$homeDir`,
avrebbe attribuito i dati di ogni profilo all'esecutore); il diff generico esplodeva con CSV
vuoti (`Compare-Object` non accetta null).

## 2026-06-10 — Allineamento al sistema di progetto portabile

Commit: 7db4de7 (modifiche preparate, commit manuale dell'utente da fare).
File toccati: import di `.claude/PROJECT-SYSTEM.md`, `rules/`, quattro skill del motore,
`templates/`; nuovo `.gitignore`; `settings.json`; `CLAUDE.local.md`; anatomia `memory/`;
`.mcp.json` segnaposto; anonimizzazione di `docs/03`, `docs/04`,
`rules/git-identity-and-repo.md` e `skills/init-project-system/SKILL.md`.
Motivo: adozione retroattiva dello standard (sezione 11 di PROJECT-SYSTEM.md). La scansione
segreti su file tracciati e storia (un solo commit) è risultata pulita. Il repository GitHub è
risultato PUBBLICO: i dati identificativi reali sono stati sostituiti con segnaposto nei file
tracciati e spostati in `CLAUDE.local.md` (ignorato). Rilevato che il vecchio `.gitignore`
escludeva `docs/**` in contraddizione con CLAUDE.md/README: ora i docs sono tracciabili e si
ignorano solo le copie compilate.
Nella stessa sessione: i tre script sono stati spostati in `scripts/` perché ricavano la radice
del progetto dalla cartella genitore (in radice avrebbero scritto gli snapshot fuori dal repo);
create e popolate dal codice attuale le sei schede di `context/` ancorate a 7db4de7; `CLAUDE.md`
integrato con procedura di ripresa e indice dei satelliti; istanziati gli stub di `_notes/` e
`.mcp.json` segnaposto. Schede tutte aggiornate rispetto a HEAD (= 7db4de7); il drift partirà
dal commit manuale di questo allineamento.

## 2026-06-08 — Commit iniziale del progetto

Commit: 7db4de7.
File: `Snapshot-Stato.ps1`, `Compare-Snapshot.ps1`, `Reinstall-Software.ps1`, `README.md`,
`CLAUDE.md`, `.gitignore` (i `docs/` esistevano ma erano esclusi da git).
Motivo: prima versione degli script di fotografia/confronto/reinstallazione e dei documenti di
progetto, come da messaggio di commit.
