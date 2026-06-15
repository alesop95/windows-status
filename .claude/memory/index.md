# Snapshot di sincronizzazione

> Da leggere per primo a inizio sessione. Fotografa lo stato del progetto al commit di
> riferimento e mappa ogni scheda al suo stato di verifica. È la fonte di verità su cosa è fatto,
> non le spunte del diario.

## Stato

```
Branch attivo:        main
Commit di riferimento: 9407b27
Data snapshot:        2026-06-15
```

Working tree con modifiche preparate, non committate: vedi work-log (`progress.md`) per il
dettaglio dell'ultima tornata. Il commit è manuale dell'utente; al commit successivo portare i
`last-verified-commit` al nuovo HEAD (skill `sync-context`). La mappa compilata
`docs/01_MAPPA_CONFIGURAZIONE.compilata.md` e `baseline-eccezioni.json` sono locali (ignorati).

## Stato di verifica delle schede

| Scheda | last-verified | Stato |
|---|---|---|
| STACK.md | 9407b27 | aggiornata (descrive il working tree, commit in attesa) |
| design-and-security.md | 9407b27 | aggiornata |
| deployment.md | 9407b27 | aggiornata |
| dev-testing.md | 9407b27 | aggiornata |
| current-work.md | 9407b27 | aggiornata |
| roadmap.md | 9407b27 | aggiornata |

## Capacità dello strumento (sintesi)

Snapshot (`scripts/Snapshot-Stato.ps1`): identità+hardware, account, config+licenza+readiness,
software riproducibile+driver di terze parti, servizi, avvio, rete, sicurezza+postura+catena di
fiducia, Veeam, superficie d'attacco/persistenza+audit ACL, export ripristinabili, per-account
(Claude multi-profilo/git/SSH), ambiente dev. Compare con ~16 categorie di alert. Allinea-
BestPractice (baseline + restore point automatico + eccezioni risk-accepted). Avvia.ps1 (menu).

## Interventi sul sistema già applicati (changelog completo nella mappa compilata)

ScriptBlock logging ON; cache bitmap RDP disattivata; task one-shot rimossa; debloating Gruppo A
(Xbox+DevHome), B (Spotify), AI (Copilot) per utente e a livello macchina (residuo solo nel
profilo Administrator); SMB in ingresso ristretto al solo client di sviluppo via firewall.
Rischi accettati (NON modificare): Administrator e secondo account locale tenuti abilitati.

## Punto di ripresa

Suggerimenti minori in corso, ordine #4→#3→#5→#6→#7. **#4 readiness FATTO** (`readiness.txt`);
**#3 punteggio conformità + ISO/CIS FATTO** in Allinea (collaudo 80%, riferimenti normativi per
controllo); **#5 report HTML FATTO** (`scripts/Genera-Report.ps1` → `report.html`, voce 2b in
Avvia); **#6 estensione baseline FATTO** (+6 controlli: Module logging/LLMNR/macro Office
applicabili, Transcription/ASR/NetBIOS avvisi; punteggio ora 50% su 8 auto-valutabili).
**#7 snapshot periodico opt-in FATTO** (`scripts/Pianifica-Snapshot.ps1`, voci 6/6i in Avvia; non
installato = opt-in). Sequenza #4-#7 COMPLETA. Poi
estensione baseline (Module logging/Transcription, ASR, LLMNR/NetBIOS, macro Office), #7 snapshot
periodico opt-in. **BitLocker = PER ULTIMO** (vedi memoria `bitlocker-implementazione-safe`).
Rimandati: Secure Boot (UEFI) e firma SMB (NAS legacy). Roadmap residua: server MCP locale, job
Veeam in mappa, policy TurnOffWindowsCopilot opzionale.

AZIONE consigliata all'utente (dallo snapshot 2026-06-12): **riavvio in sospeso = SÌ** (uptime
~9g) → riavviare quando comodo (rende effettivo anche LSA RunAsPPL). Password `dev` esposta in
chat → consigliata rotazione.
