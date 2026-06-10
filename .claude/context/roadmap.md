---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/**
  - docs/**
last-verified-commit: 7db4de7
---

# Roadmap

> Direzione e priorità. Il criterio operativo del progetto resta: prima la mappatura, poi la
> pulizia.

## In corso

Caratterizzazione di sicurezza dello snapshot: blocco superficie d'attacco e persistenza in
`Snapshot-Stato.ps1` e alert di sicurezza in `Compare-Snapshot.ps1` (dettaglio e definition of
done in `current-work.md`).

## Prossimi blocchi candidati (decisi il 2026-06-10, in ordine di valore)

Postura hardware/OS: Secure Boot, TPM, VBS/Credential Guard/HVCI, LSA protection, UAC, SMBv1,
RDP/NLA, listener WinRM, livello patch (`Get-HotFix` e storia update).

Defender e policy in profondità: esclusioni Defender, regole ASR, Tamper Protection, audit
policy, logging PowerShell, export `secedit`, regole firewall personalizzate.

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
