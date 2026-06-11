# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: 9407b27
Data snapshot:        2026-06-11
```

Working tree non pulito: tracciamento cache bitmap RDP nello snapshot, `docs/05_QUICKSTART.md` e
`docs/06_RACCORDO_CHECKLIST_VA.md` nuovi, indice docs nel CLAUDE.md, piano debloating a secco in
current-work; più due modifiche EFFETTIVE al sistema già applicate (rimozione task one-shot,
disattivazione cache RDP). Il commit è manuale dell'utente. La mappa compilata è locale. Al
commit successivo portare i `last-verified-commit` al nuovo HEAD. Aggiunto inoltre il terzo
script `scripts/Allinea-BestPractice.ps1` (applicatore del baseline, dry-run di default).

## Stato di verifica delle schede

| Scheda | last-verified | Stato |
|---|---|---|
| STACK.md | 9407b27 | aggiornata (descrive il working tree, commit in attesa) |
| design-and-security.md | 9407b27 | aggiornata |
| deployment.md | 9407b27 | aggiornata |
| dev-testing.md | 9407b27 | aggiornata |
| current-work.md | 9407b27 | caratterizzazione completa; piano debloating a secco |
| roadmap.md | 9407b27 | aggiornata |

## Punto di ripresa

Hardening live in corso (paracadute Veeam confermato il 2026-06-11), una azione alla volta con
spiegazione + approvazione + changelog. FATTO: ScriptBlock logging ON; debloating Gruppo A
(5 componenti Xbox + DevHome rimossi, Media Player e Phone Link mantenuti); debloating Gruppo B
(rimosso Spotify, mantenuto WhatsApp); AI/slop (rimosso Copilot; BingSearch non installata).
RIMANDATI: firma SMB (due NAS legacy/EOL + backup Veeam su uno di essi) e Secure Boot (UEFI).
BitLocker = PER ULTIMO (decisione utente). Snapshot ELEVATO di certificazione FATTO
(`snapshot_20260611_111205`): hardening confermato; scoperto che Copilot/DevHome/Xbox sono via
solo per l'utente corrente, persistono a livello -AllUsers. FATTI il 2026-06-11: inventario hardware
nello snapshot (`hardware_*.csv`, sezione 1, con alert HARDWARE nel Compare); avvio standardizzato
`Avvia.ps1` (menu unico, `-Help` non interattivo); controllo licenza/attivazione Windows (sezione
3, `licenza_windows.txt/.csv`, alert LICENZA nel Compare, mai la chiave intera) — evidenza: Win 11
Pro RETAIL attivato via licenza DIGITALE (chiave dal fornitore; migrazione HW in docs/02);
software riproducibile all'ultima versione (winget export + winget upgrade) e lista driver di
terze parti `driver_terze_parti.csv` (+ Export-WindowsDriver/pnputil) per il ripristino su nuovo
hardware. Prossimi possibili, a scelta
utente e sempre spiegati prima: (1) debloating a livello macchina (-AllUsers/provisioned MIRATO)
per togliere Copilot/Xbox/DevHome anche dagli altri profili; (2) BitLocker (PER ULTIMO, vedi
memoria bitlocker-implementazione-safe); (3) opz. policy TurnOffWindowsCopilot; (4) rimandati
Secure Boot e firma SMB (NAS legacy); (5) un nuovo snapshot ELEVATO sarà la prima baseline
completa CON l'inventario hardware (i campi hardware nella mappa si compilano da lì). Roadmap residua: server MCP locale, job Veeam in mappa.
