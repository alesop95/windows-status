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

## Prossimi blocchi candidati (decisi il 2026-06-10, in ordine di valore)

Catena di fiducia: inventario root CA macchina, Trusted Publishers, file hosts, proxy
WinHTTP/utente, DoH, inventario `cmdkey` (solo nomi).

Export ripristinabili: XML delle attività pianificate non Microsoft, profili Wi-Fi senza
chiavi, associazioni file, piano energetico, impostazioni internazionali.

Ambiente utente esteso: Windows Terminal e profili PowerShell, estensioni browser Edge/Chrome,
font utente.

Integrità dello snapshot: manifest SHA256 dell'output, passata anti-segreti finale su tutti i
file prodotti, pattern `Protect-Secrets` estesi (PEM, token Azure/AWS/Slack), output JSON
strutturato accanto ai CSV.

## Promemoria espliciti

Server MCP locale che esponga gli snapshot (ultimo stato, diff, ricerca) come tool: rimandato,
`.mcp.json` segnaposto già in radice, implementazione da progettare in `mcp/`.

Compilazione della mappa `docs/01_MAPPA_CONFIGURAZIONE.md` con il primo snapshot reale (le
sezioni 🔄), e documentazione manuale del job Veeam (sezione 10 della mappa).

Fasi successive del progetto originario: pulizia/debloating guidato da `docs/00`, re-mappatura,
backup immagine pulito e test di ripristino.
