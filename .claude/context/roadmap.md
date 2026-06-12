---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/**
  - docs/**
last-verified-commit: 9407b27
---

# Roadmap

> Direzione e priorità. Il criterio operativo del progetto resta: prima la mappatura, poi la
> pulizia.

## Completati

Superficie d'attacco e persistenza nello snapshot + alert di sicurezza nel compare
(2026-06-10). Postura hardware/OS nello snapshot (Secure Boot, TPM, VBS/Credential Guard, LSA,
UAC, SMB, RDP, WinRM, patch level) con categoria di alert POSTURA nel compare (2026-06-10).
Snapshot multi-profilo Claude: tutti i `.claude*` per account, inclusi i profili
`CLAUDE_CONFIG_DIR`, con inventario limitato e config oscurate (2026-06-10).
Defender e policy in profondità: esclusioni e regole ASR (con alert DEFENDER), Tamper
Protection, auditpol, logging PowerShell, export `secedit`, regole firewall inbound consentite
(con alert FIREWALL), più i trigger delle attività pianificate nel CSV (2026-06-10).

Catena di fiducia (root CA, Trusted Publishers, hosts, proxy/DoH, con alert TRUST), export
ripristinabili (Wi-Fi senza chiavi, associazioni file, piano energetico, internazionali, XML
task), ambiente utente esteso (Terminal, profili PowerShell, cmdkey, estensioni browser con
alert BROWSER) e integrità dello snapshot (Protect-Secrets esteso, scansione anti-segreti
finale, MANIFEST.sha256) (2026-06-10). Riepilogo strutturato `snapshot.json` con i conteggi
chiave e l'indice dei file (2026-06-10). La caratterizzazione di sicurezza decisa il 2026-06-10
è con questo COMPLETA.

Applicatore del baseline `scripts/Allinea-BestPractice.ps1` (2026-06-11): terza gamba del tool,
allinea un PC vergine o difforme alle best practice emerse, dry-run di default e applicazione
guidata reversibile con conferma per passo. Raccordo con la checklist di remediation VA in
`docs/06_RACCORDO_CHECKLIST_VA.md`; quickstart in `docs/05_QUICKSTART.md`.

## Completati il 2026-06-11

Inventario hardware intelligente nello snapshot (sezione 1: scheda madre/BIOS/GPU, banchi RAM,
dischi con tipo/bus/salute SMART, volumi, controller e dispositivi USB con dischi di massa,
adattatori di rete con link, monitor — `hardware_*.csv`), con categorie di diff e alert HARDWARE
nel Compare (nuovo disco USB di massa, salute SMART, cambio RAM). Nota: la velocità USB negoziata
per-dispositivo non è esposta in modo affidabile, si deduce la classe dal controller.

Avvio standardizzato `Avvia.ps1` in radice: menu unico (fotografa / confronta / report baseline /
applica baseline / reinstalla), distingue sola-lettura da MODIFICA, chiede l'approccio
(PowerShell mirato vs strumenti esterni, docs/00 §7), `-Help` non interattivo. Funziona identico
clonando la repo su qualsiasi Windows 11.

## Completati il 2026-06-11 (seconda tornata)

Restore point automatico prima di ogni `-Apply` (#1); igiene account ADMIN-BUILTIN +
ACCOUNT-DORMANTI generici (#2, applicazione rifiutata = rischio accettato per i due account tenuti);
audit ACL delle cartelle sensibili e directory nel PATH (#8: `acl_cartelle_sensibili.csv`, alert
ACL nel Compare, marca GRAVE Modify/FullControl o scrittura nel PATH; collaudo: 0 gravi).

## Completati il 2026-06-12

#4 readiness operativa nello snapshot (`readiness.txt`: riavvio in sospeso, uptime, ultimo update,
scansioni/firme AV; alert READINESS). #3 punteggio conformità baseline + mappatura ISO/CIS in
Allinea-BestPractice (riferimenti normativi per controllo). #5 report HTML autoconsistente
(`scripts/Genera-Report.ps1` → `report.html` da SUMMARY, sezioni navigabili, voce nel menu Avvia).
#6 estensione baseline: +6 controlli in Allinea-BestPractice (PS Module logging, LLMNR off, blocco
macro Office da Internet applicabili; PS Transcription, ASR Defender, NetBIOS over TCP/IP come
avvisi report-only), tutti con Rif ISO/CIS.

Meccanismo "eccezioni / rischio accettato" in `Allinea-BestPractice.ps1`: file locale
`baseline-eccezioni.json` (ignorato da git; template `baseline-eccezioni.esempio.json` tracciato);
i controlli elencati appaiono ACCETTATO con motivo/data e non vengono proposti in `-Apply`.
ADMIN-BUILTIN ora risulta ACCETTATO (account tenuti per scelta dell'utente; dettaglio nella mappa locale).

## Prossimi blocchi candidati (in ordine di valore)

BitLocker (PER ULTIMO, su decisione utente): attivazione guidata della cifratura, un volume alla
volta, con custodia della chiave di ripristino prima del riavvio — vedi memoria
`bitlocker-implementazione-safe`. Resta solo segnalato (avviso) in Allinea-BestPractice.

Suggerimenti #3-#7 ancora aperti: (3) punteggio conformità baseline + mappatura ISO/CIS;
(4) readiness nello snapshot (pending reboot, Windows Update, ultima scansione AV); (5) report
HTML autoconsistente; (6) estensione baseline (Module logging/Transcription, ASR, LLMNR/NetBIOS,
macro Office); (7) snapshot periodico opt-in via scheduled task.

Estensioni minori: font utente nello snapshot; firma SMB e Secure Boot (RIMANDATI: NAS legacy /
UEFI); debloating a livello macchina già fatto in modo mirato (residuo solo nel profilo Administrator).

## Promemoria espliciti

Server MCP locale che esponga gli snapshot (ultimo stato, diff, ricerca) come tool: rimandato,
`.mcp.json` segnaposto già in radice, implementazione da progettare in `mcp/`.

Compilazione della mappa `docs/01_MAPPA_CONFIGURAZIONE.md` con il primo snapshot reale (le
sezioni 🔄), e documentazione manuale del job Veeam (sezione 10 della mappa).

Fasi successive del progetto originario: pulizia/debloating guidato da `docs/00`, re-mappatura,
backup immagine pulito e test di ripristino.
