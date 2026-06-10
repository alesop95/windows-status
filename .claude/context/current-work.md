---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: 9407b27
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

## Feature attiva 3 — Snapshot/Compare: postura hardware/OS

Cosa fa: la sezione 8 SICUREZZA dello snapshot produce `sicurezza_postura.txt` (Secure Boot,
TPM, VBS/Credential Guard/HVCI, LSA RunAsPPL, UAC, SMBv1 e firma SMB, RDP+NLA, WinRM, build
completa) e `hotfix.csv`; il compare ha la categoria POSTURA che segnala ogni valore cambiato
(esclusi i conteggi hotfix).

Definition of done:
- [x] tutti i controlli sopra, degradanti senza admin ("non leggibile (serve admin)")
- [x] output chiave:valore diffabile + CSV hotfix robusto al locale italiano
- [x] alert POSTURA nel compare, con esclusione del rumore (hotfix; porte UDP effimere ≥49152
      escluse dalla categoria PORTE)

Collaudo del 2026-06-10 (non elevato): VBS in esecuzione ma senza CredentialGuard/HVCI,
RunAsPPL=2, SMBv1 off ma firma SMB non richiesta, RDP off, WinRM fermo, 25H2 26200.8457 con
7 hotfix. Confronto reale baseline→nuovo: 4 alert tutti legittimi (porte Veeam, mDNS Edge).

## Feature attiva 4 — Snapshot multi-profilo Claude e AV registrati

Cosa fa: la sezione per-account legge tutti i profili `.claude*` (default e multi-account via
`CLAUDE_CONFIG_DIR`) con inventario limitato a 200 voci e config oscurate; la sezione 8 elenca
gli antivirus registrati in SecurityCenter2 (con AV di terze parti, Defender in passivo è
normale); il compare avvisa quando i due snapshot hanno privilegi diversi (rumore di
visibilità).

Definition of done: tutte le voci fatte e collaudate il 2026-06-10 (3 profili rilevati,
redazione pulita; avviso elevazione verificato sul confronto non-elevato vs elevato).

## Feature attiva 5 — Snapshot/Compare: Defender e policy in profondità

Cosa fa: la sezione 8 dello snapshot esporta esclusioni Defender (`defender_esclusioni.csv`),
regole ASR (`defender_asr.csv`), Tamper Protection e modalità Defender, audit policy
(`auditpol.txt`), logging PowerShell (`powershell_logging.txt`), criteri locali
(`secedit_policy.inf`, solo admin) e regole firewall inbound consentite
(`firewall_regole_inbound_allow.csv`); la sezione 10 aggiunge la colonna Trigger alle azioni
delle task. Il compare ha le categorie DEFENDER (nuove esclusioni, ASR indebolite/rimosse) e
FIREWALL (nuove regole inbound consentite).

Definition of done: tutto implementato e collaudato il 2026-06-10 (degradazione senza admin
verificata; alert DEFENDER e FIREWALL verificati con test sintetico 3/3; 215 regole inbound in
baseline; trovato che il logging PowerShell non è configurato → ✍️ candidato hardening).
Nota: con AV di terze parti attivo, Defender è "Not running" e le sue esclusioni non sono
leggibili localmente — le esclusioni reali vivono nella console dell'AV aziendale.

## Feature attiva 6 — Catena di fiducia, export ripristinabili, ambiente esteso, integrità

Cosa fa: sezione 8 + catena di fiducia (root CA macchina, Trusted Publishers, hosts, proxy
WinHTTP/utente, DoH); nuova sezione 11 EXPORT RIPRISTINABILI (Wi-Fi senza chiavi, associazioni
file via DISM, powercfg, impostazioni internazionali, XML delle task non Microsoft, oscurati);
sezione 13 estesa (Windows Terminal, profili PowerShell, destinazioni cmdkey, estensioni
browser Edge/Chrome in CSV per account); `Protect-Secrets` esteso (AWS, Slack, blocchi PEM);
scansione anti-segreti finale su tutto l'output e `MANIFEST.sha256`. Compare: categorie TRUST
(nuova root CA, nuovo publisher, hosts modificato) e BROWSER (nuove estensioni).

Definition of done: tutto implementato e collaudato il 2026-06-10 su snapshot completo reale —
76 root CA e 1 publisher in baseline, hosts 11 righe legittime, 21 XML task, 27 estensioni
browser (notata estensione VPN/proxy NordVPN → ✍️), scansione finale PULITA, manifest prodotto.
Rinumerate le sezioni: 11=export, 12=per-account, 13=ambiente dev.

## Verdetto sulla task RiavvioSingoloNotturno (2026-06-10)

Trigger letto dall'export elevato: TimeTrigger SINGOLO del 2025-11-30 alle 04:00, senza
ripetizione, creato come SYSTEM ("riavvio alle 3:00 AM del giorno successivo"). È un residuo
one-shot già scaduto: non riavvierà mai più il PC. Rimozione proposta (comando elevato
`Unregister-ScheduledTask -TaskName RiavvioSingoloNotturno`), in attesa di conferma utente; da
registrare nel changelog della mappa quando eseguita.

## Domande aperte

Il server MCP locale è rimandato: in radice c'è un `.mcp.json` segnaposto non funzionante per
scelta, da compilare quando si deciderà l'implementazione (vedi roadmap).

Risolte il 2026-06-10: CLAUDE.md e README riallineati al join reale (workplace, non Entra);
snapshot elevato eseguito dall'utente. Esiti nella mappa compilata, con tre ✍️ aperti per
l'utente: BitLocker OFF su tutti i volumi (attivarlo?), Secure Boot disattivo con TPM pronto
(attivarlo da UEFI?), task `RiavvioSingoloNotturno` e residuo Lenovo da spiegare/pulire.
