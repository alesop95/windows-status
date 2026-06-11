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
ACCOUNT-DORMANTI generici (#2, applicazione rifiutata = rischio accettato per Administrator/dev);
audit ACL delle cartelle sensibili e directory nel PATH (#8: `acl_cartelle_sensibili.csv`, alert
ACL nel Compare, marca GRAVE Modify/FullControl o scrittura nel PATH; collaudo: 0 gravi).

## Prossimi blocchi candidati (in ordine di valore)

Meccanismo di "eccezioni / rischio accettato" in `Allinea-BestPractice.ps1`: un file di eccezioni
(es. `.claude` o radice, ignorato se contiene dati macchina) in cui marcare i controlli
deliberatamente non allineati con motivazione e data, così il report li mostra come "ACCETTATO"
invece di "DA ALLINEARE". Si aggancia alla logica risk-accepted della checklist VA (docs/06).
Caso reale: ADMIN-BUILTIN (Administrator e `dev` tenuti abilitati per scelta) resta "da allineare"
finché non esiste questo meccanismo.

Audit ACL delle cartelle sensibili (read-only): controllare i permessi NTFS di un elenco curato
di percorsi (`C:\`, `C:\Windows`, `System32`, `Windows\Temp`, `Program Files`, `ProgramData`,
cartelle StartUp, radici profili) e segnalare dove `Users`/`Authenticated Users`/`Everyone` hanno
Write/Modify/FullControl (violazione del minimo privilegio = vettore di privilege escalation).
Includere i due casi ad alto impatto: directory scrivibili presenti nel PATH di sistema, e
cartelle dei binari dei servizi scrivibili da utenti (si aggancia ai "percorsi non quotati" già
rilevati). Output `acl_cartelle_sensibili.csv` diffabile + alert ACL nel Compare su nuova ACL
debole. Principio: cartelle di sistema/programmi scrivibili solo da SYSTEM/Administrators/
TrustedInstaller, utenti in sola lettura+esecuzione.

Debloating a livello macchina (-AllUsers / provisioned MIRATO) come passo opzionale distinto dal
per-utente, con le cautele del paletto 4 (mai de-provisioning massivo su macchina gestita).

Catena di fiducia, export ripristinabili, ambiente utente esteso, integrità: GIA' IMPLEMENTATI
il 2026-06-10 (vedi sezione Completati e work-log); restano eventuali estensioni (font utente,
Module logging/Transcription PowerShell).

## Promemoria espliciti

Server MCP locale che esponga gli snapshot (ultimo stato, diff, ricerca) come tool: rimandato,
`.mcp.json` segnaposto già in radice, implementazione da progettare in `mcp/`.

Compilazione della mappa `docs/01_MAPPA_CONFIGURAZIONE.md` con il primo snapshot reale (le
sezioni 🔄), e documentazione manuale del job Veeam (sezione 10 della mappa).

Fasi successive del progetto originario: pulizia/debloating guidato da `docs/00`, re-mappatura,
backup immagine pulito e test di ripristino.
