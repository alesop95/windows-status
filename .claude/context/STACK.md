---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: 9407b27
---

# Stack applicativo

> Documento di recupero più importante: tracciato, perché un collega che clona deve vederlo.

## Stack e runtime

Il progetto è interamente in Windows PowerShell 5.1, senza dipendenze esterne: quattro script
sotto `scripts/` più il launcher `Avvia.ps1` in radice, pensati per Windows 11 in lingua
italiana. `Avvia.ps1` è il punto d'ingresso standardizzato (menu) che orchestra gli script e
funziona identico clonando la repo su qualsiasi macchina; non ha logica propria. Lo snapshot
completo richiede una shell elevata (amministratore) per leggere i profili altrui, BitLocker e
Defender; l'inventario software usa `winget` quando presente e ripiega sul registro quando
manca. Non c'è build, non c'è gestore di pacchetti: si clona e si esegue.

## Alternative deliberatamente escluse

Non risultano alternative valutate e scartate documentate nella storia; la sezione si popola
quando una scelta del genere emerge.

## Flussi di codice e ruolo architetturale dei file

`scripts/Snapshot-Stato.ps1` è il cuore: produce in `snapshots/snapshot_<timestamp>/` una
fotografia di sola lettura, organizzata in tre parti governate dal parametro `-Scope`
(`All`, `Machine`, `User`). La parte macchina copre identità, join Entra ID e inventario
hardware (sezione 1: scheda madre, BIOS/UEFI, GPU, banchi RAM, dischi fisici con tipo/bus/salute
SMART, volumi, controller e dispositivi USB con i dischi di massa, adattatori di rete con
velocità di link, monitor — tutto in `hardware_*.csv` diffabili),
account, sessioni e membri di Administrators (2), configurazioni macchina (3) inclusa la licenza /
attivazione Windows (edizione, canale Retail/OEM/Volume, stato, tipo licenza — `licenza_windows.txt/.csv`
— senza mai salvare la chiave intera né quella OEM di firmware) e la readiness operativa
(`readiness.txt`: riavvio in sospeso, uptime/ultimo avvio, ultimo update installato, modalità
Defender e ultime scansioni/firme AV — con alert READINESS nel Compare al comparire di un riavvio in sospeso), configurazioni di macchina (3), software da
winget (con export riproducibile all'ultima versione, lista aggiornabili), registro e Appx (4), servizi (5), avvio e attività pianificate (6), rete e firewall (7),
sicurezza (8: Defender e AV registrati, BitLocker, postura hardware/OS, esclusioni e ASR,
auditpol, logging PowerShell, secedit, regole firewall inbound, catena di fiducia con root CA,
Trusted Publishers, hosts, proxy e DoH), rilevamento Veeam (9), superficie d'attacco e
persistenza (10): porte TCP/UDP in ascolto con processo proprietario, autoruns profondi
(Run/RunOnce per hive, Winlogon, IFEO con Debugger, SilentProcessExit), sottoscrizioni WMI in
`root\subscription`, azioni e trigger delle attività pianificate non Microsoft, firme dei
driver con estrazione dei non firmati, servizi con percorso non quotato, e l'audit ACL delle
cartelle sensibili e delle directory nel PATH (segnala dove gruppi ampi — Users/Authenticated
Users/Everyone — hanno scrittura; marca GRAVE Modify/FullControl o qualsiasi scrittura nel PATH,
vettore di privilege escalation); e gli export
ripristinabili (11): profili Wi-Fi senza chiavi, associazioni file, piano energetico,
impostazioni internazionali, XML delle task non Microsoft, e la lista dei driver di terze parti
(`driver_terze_parti.csv`) necessari a far rifunzionare l'hardware su un nuovo PC (con la nota su
`Export-WindowsDriver`/`pnputil` per portarsi e re-iniettare i file `.inf`). La parte per-account (12) legge da
disco, per ogni profilo in `C:\Users` (esclusi i profili di servizio TEMP*/UMFD-*), le
configurazioni di Claude — tutti i profili `.claude*`, inclusi i multi-account selezionati via
`CLAUDE_CONFIG_DIR`, con inventario limitato alle prime 200 voci e `settings.json`/`CLAUDE.md`/
`.claude.json` oscurati — più git e SSH, sempre tramite redazione dei segreti. La parte utente
live (13) fotografa l'ambiente di sviluppo dell'account che esegue, più Windows Terminal,
profili PowerShell, destinazioni `cmdkey` ed estensioni browser Edge/Chrome. Ogni sezione
scrive file CSV o TXT dedicati e righe di sintesi in `SUMMARY.txt`. I contenuti potenzialmente
sensibili passano da `Protect-Secrets` (api key, token GitHub/AWS/Slack, JWT, blocchi di chiave
privata PEM); in coda lo script riesegue una scansione anti-segreti su tutto l'output e produce
`MANIFEST.sha256` con l'hash di ogni file (integrità tamper-evident).

`scripts/Compare-Snapshot.ps1` confronta due snapshot (di default i due più recenti) in due
passate: il diff generale per chiave sui CSV principali (voci aggiunte e rimosse), e la sezione
finale di ALERT DI SICUREZZA che incrocia i CSV della superficie d'attacco e gli attributi:
nuovi membri di Administrators, account creati o riabilitati, autorun nuovi (cartelle e
registro), task nuove o con azione cambiata, porte in ascolto nuove (escluse le UDP effimere),
servizi nuovi o con StartMode/account di esecuzione cambiati, driver non firmati comparsi,
postura hardware/OS cambiata, esclusioni Defender nuove e ASR indebolite, regole firewall
inbound nuove, root CA e Trusted Publishers nuovi, hosts modificato, estensioni browser nuove,
servizi con percorso non quotato comparsi, e variazioni hardware (nuovo disco — con allerta
specifica se è un disco USB di massa, salute SMART non ottimale, cambio di RAM totale, dischi e
dispositivi USB aggiunti/rimossi), e cambi di licenza/attivazione Windows (categoria LICENZA:
stato attivazione o canale cambiati), e nuove ACL deboli gravi su cartelle sensibili o nel PATH
(categoria ACL). Avvisa se i due snapshot hanno privilegi diversi.
Se un CSV manca in uno dei due snapshot la categoria viene saltata senza errori. Vincolo di codifica: gli script vanno salvati in UTF-8 con BOM, perché Windows
PowerShell 5.1 interpreta l'UTF-8 senza BOM come ANSI e i caratteri tipografici nelle stringhe
spezzano il parsing.

`scripts/Allinea-BestPractice.ps1` è l'unico script che MODIFICA il sistema, ed è la terza gamba
accanto a fotografa/confronta: porta una macchina (vergine o difforme) al baseline di sicurezza
emerso dall'analisi. È dichiarativo: una lista di controlli, ciascuno con `Test` (stato attuale +
conformità), `Apply` e rollback. Di default gira in sola lettura e stampa solo il DIVARIO; con
`-Apply` chiede conferma per ogni controllo non conforme, salta quelli che richiedono admin se
non elevato, registra un log in `snapshots/allineamento_<stamp>.log`, e non tocca mai Windows
Update, Defender, Office, Edge, OneDrive, Intune. I controlli non automatizzabili in sicurezza
(Secure Boot, BitLocker) sono solo segnalati. Baseline attuale: cache bitmap RDP, firma SMB
client/server, SMBv1 off, ScriptBlock logging, LSA RunAsPPL, igiene account (Administrator
integrato disabilitato — con rifiuto se è l'unico admin — e segnalazione account abilitati
anomali, mai usati o senza profilo), più gli avvisi Secure Boot/BitLocker. Prima di ogni `-Apply`
crea automaticamente un punto di ripristino del sistema (se la Protezione sistema è attiva e si è
elevati), come rete di sicurezza locale oltre a Veeam. Supporta un meccanismo di eccezioni /
rischio accettato: i controlli elencati in `baseline-eccezioni.json` (radice, locale/ignorato da
git; template tracciato `baseline-eccezioni.esempio.json`) appaiono come ACCETTATO nel report con
motivo e data, e non vengono proposti in `-Apply` — stessa logica risk-accepted della checklist VA.
Il report calcola anche un PUNTEGGIO DI CONFORMITA (conformi sui controlli auto-valutabili,
esclusi avvisi e accettati) e stampa per ogni controllo i RIFERIMENTI NORMATIVI (ISO/IEC
27001:2022 Annex A + CIS), per alimentare governance e checklist VA.

`scripts/Genera-Report.ps1` trasforma uno snapshot (SUMMARY.txt) in un singolo `report.html`
autoconsistente (CSS inline, sezioni navigabili, righe d'attenzione evidenziate); read-only,
scrive solo dentro la cartella snapshot (ignorata da git). Avvertenza di codifica/PS: NON
chiamare una funzione `H` (collide con l'alias `h`=Get-History); qui si usa `Esc` per l'HTML-encode.

`scripts/Reinstall-Software.ps1` chiude il cerchio della portabilità: reimporta su una macchina
nuova il `software_winget.json` prodotto dallo snapshot, previa revisione manuale del JSON.

Vincolo strutturale: tutti gli script ricavano la radice del progetto come cartella genitore
della propria (`Split-Path -Parent $base`), quindi devono vivere in `scripts/`, mai nella radice,
altrimenti `snapshots/` finirebbe fuori dal repository.

## Riferimenti a snippet

`scripts/Snapshot-Stato.ps1:56` `Protect-Secrets` — redazione di api key, token, password, JWT.
`scripts/Snapshot-Stato.ps1:51` `Save`/`SaveUser` — convenzione di output verso lo snapshot.
`scripts/Compare-Snapshot.ps1:41` `$files` — mappa CSV→chiave primaria su cui si basa il diff.
`scripts/Compare-Snapshot.ps1:72` `Add-Alert` — accumulo degli alert di sicurezza per categoria.
Avvertenza variabili: `$home` è read-only in PowerShell (la sezione per-account usa `$homeDir`).
