---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: ff519f0
status: implementata, collaudata, in attesa di commit
---

# Lavoro in corso

> La fonte di verità su cosa è fatto resta `memory/index.md` e il work-log, non le spunte qui.

## Feature attiva 1 — Snapshot: superficie d'attacco e persistenza

Cosa fa: aggiunge a `scripts/Snapshot-Stato.ps1` una sezione di sola lettura che fotografa i
punti classici di attacco e persistenza di Windows 11, per portare la caratterizzazione a
livello di audit di cybersecurity.

File da modificare: `scripts/Snapshot-Stato.ps1` (nuova sezione macchina dopo la 8),
`docs/01_MAPPA_CONFIGURAZIONE.md` (nuova sezione 🔄 corrispondente).

Definition of done:
- [x] porte TCP/UDP in ascolto con processo proprietario (PID, nome, percorso eseguibile)
- [x] autoruns profondi: chiavi Run/RunOnce per HKLM e per ogni hive utente, Winlogon
      (Shell/Userinit), Image File Execution Options con Debugger impostato (+ SilentProcessExit)
- [x] sottoscrizioni eventi WMI (EventFilter, EventConsumer, FilterToConsumerBinding)
- [x] azioni complete delle attività pianificate non Microsoft (comando ed argomenti, non solo
      il nome)
- [x] driver non firmati e servizi con percorso non quotato contenente spazi
- [x] tutto in sola lettura, con redazione, output CSV/TXT diffabile e righe in SUMMARY.txt

Collaudo del 2026-06-10: snapshot reale eseguito senza errori; la sezione ha rilevato 69 porte
TCP e 71 UDP, 23 autoruns, il binding WMI di serie "SCM Event Log", 21 task non Microsoft, un
driver non firmato (lettore smartcard); scansione anti-segreti sull'output pulita.

## Feature attiva 2 — Compare: alert di sicurezza

Cosa fa: `scripts/Compare-Snapshot.ps1` non si limita al diff per chiave ma segnala con
evidenza le variazioni critiche per la sicurezza.

File da modificare: `scripts/Compare-Snapshot.ps1`.

Definition of done:
- [x] alert su nuovo membro del gruppo Administrators e nuovo account locale abilitato/riabilitato
- [x] alert su nuovo autorun e nuova attività pianificata con la sua azione
- [x] alert su cambio di StartMode/StartName dei servizi (diff per attributo, non solo per nome)
- [x] alert su nuova porta in ascolto e nuovo driver non firmato (richiede i CSV della feature 1)
- [x] sezione finale "ALERT DI SICUREZZA" leggibile a colpo d'occhio (con conteggio totale)

Collaudo del 2026-06-10: test con snapshot sintetico manomesso in 7 punti — tutte le 8 categorie
di alert sono scattate correttamente; con snapshot identici la sezione riporta "nessun alert".

## Domande aperte

Il server MCP locale è rimandato: in radice c'è un `.mcp.json` segnaposto non funzionante per
scelta, da compilare quando si deciderà l'implementazione (vedi roadmap).
