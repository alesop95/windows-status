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

## Prossimi blocchi candidati (decisi il 2026-06-11, in ordine di valore)

Inventario hardware intelligente (sezione nuova dello snapshot, sola lettura): specifiche
hardware (CPU/RAM/scheda madre/GPU), dischi connessi (modello, tipo SSD/HDD/NVMe, salute SMART,
spazio), mappatura porte USB con velocità negoziata (USB 2.0/3.x, controller, dispositivi
collegati), schede di rete e velocità link, monitor collegati. Con relativo alert nel Compare
(es. nuovo dispositivo USB di massa = possibile esfiltrazione/ingresso).

Avvio standardizzato / portabilità: un punto d'ingresso unico (es. `Avvia.ps1` o sezione
quickstart) che, clonata la repo su una QUALSIASI macchina Windows 11, guidi l'operatore tra
snapshot, confronto, allineamento al baseline e debloating in modo uniforme — chiedendo
all'avvio se usare PowerShell mirato e/o gli strumenti esterni (Winhance/Winslop) e con quale
ampiezza (vedi `docs/00` §7).

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
