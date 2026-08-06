---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
last-verified-commit: 9407b27
status: caratterizzazione completa; debloating in analisi a secco
---

# Lavoro in corso

> La fonte di verità su cosa è fatto resta `memory/index.md` e il work-log, non le spunte qui.

## Caratterizzazione di sicurezza — COMPLETATA (2026-06-10)

Tutte le feature di caratterizzazione sono implementate, collaudate e nel work-log (`memory/progress.md`): superficie d'attacco e persistenza, alert di sicurezza nel Compare, postura hardware/OS, snapshot multi-profilo Claude, AV registrati, Defender e policy in profondità, catena di fiducia, export ripristinabili, ambiente utente esteso, integrità (scansione anti-segreti finale + `MANIFEST.sha256`), `snapshot.json`, tracciamento cache bitmap RDP. Dettaglio e collaudi in `memory/progress.md`.

## Modifiche al sistema applicate (2026-06-10)

Rimossa la task one-shot scaduta `RiavvioSingoloNotturno`. Disattivata in modo robusto la cache bitmap persistente del client RDP (registro `DisablePersistentCache=1` + `Default.rdp` a 0 + cache svuotata): reversibile, a changelog nella mappa compilata.

## Hardening live applicato (2026-06-11, paracadute Veeam confermato)

Una azione alla volta, spiegata e approvata. (1) PS-LOG: ScriptBlock logging abilitato. (2) Firma SMB: RIMANDATA — due NAS legacy/EOL in rete e backup Veeam su uno di essi; rischio rottura. (3) Debloating Gruppo A "solo superflue": rimossi 5 componenti Xbox + DevHome per l'utente; mantenuti Media Player e Phone Link; XboxGameCallableUI non rimovibile (stub di sistema). (4) Debloating Gruppo B "solo Spotify": rimosso Spotify, mantenuto WhatsApp (possibile uso lavorativo). Tutto a changelog nella mappa compilata. Restano: BitLocker (per ultimo, decisione utente), Secure Boot (rimandato, UEFI), firma SMB (rimandata, NAS legacy), eventuale AI-slop (Copilot/BingSearch), snapshot elevato di certificazione.

## Applicatore del baseline — Allinea-BestPractice.ps1 (2026-06-11)

Terza gamba del tool: allinea un PC (vergine o difforme) al baseline di sicurezza. Dichiarativo, dry-run di default, `-Apply` guidato con conferma per passo e log reversibile. Baseline: RDP cache, firma SMB, SMBv1 off, ScriptBlock logging, LSA RunAsPPL; avvisi Secure Boot/BitLocker. Collaudato in report su questa macchina (3 conformi, 2 da allineare). Per estenderlo: aggiungere un elemento alla lista `$baseline` con `Test`/`Apply`/`Rollback`. Applicazione reale rinviata al via col paracadute Veeam.

## Feature attiva — Piano di debloating a micro-step (ANALISI A SECCO, nulla eseguito)

Cosa fa: pulizia app consumer della macchina Windows 11 seguendo `docs/00`, una categoria alla volta. Stato: **piano, non eseguito.** Vincolo: prima del primo passo serve il paracadute (immagine Veeam recente + punto di ripristino), poi un'app/gruppo alla volta con riavvio e verifica (Outlook/Teams/OneDrive/VPN/SSO) e riga di changelog.

Candidati dall'inventario reale (snapshot 20260610_151411, 212 Appx), divisi per confidenza. Le rimozioni sono reversibili: ogni app si reinstalla da Store o `winget`. Comando per-utente: `Get-AppxPackage *<Nome>* | Remove-AppxPackage` (per tutti gli utenti serve admin e `-AllUsers`).

Gruppo A — consumer chiaramente superflui su un PC di lavoro (rimozione a basso rischio): `Microsoft.BingNews`, `Microsoft.BingWeather`, `Microsoft.GamingApp`, `Microsoft.Xbox*` (TCUI, GameCallableUI, GameOverlay, GamingOverlay, IdentityProvider, SpeechToTextOverlay), `Microsoft.ZuneMusic`, `Microsoft.ZuneVideo`, `Microsoft.YourPhone`, `Microsoft.WindowsFeedbackHub`, `Clipchamp.Clipchamp`, `Microsoft.Windows.DevHome`.

Gruppo B — personali, da decidere caso per caso (potresti usarli): `SpotifyAB.SpotifyMusic`, `5319275A.WhatsAppDesktop`, `Microsoft.MicrosoftStickyNotes`, `Microsoft.Todos`, `Microsoft.WindowsMaps`.

Gruppo C — NON toccare (lavoro / integrazione di sistema): `MSTeams` (lavoro), `Microsoft.People` e `PeopleExperienceHost` (integrati con Outlook), `Microsoft.PowerAutomateDesktop`. `Microsoft.Copilot` e `Microsoft.BingSearch` sono AI/slop: categoria separata da affrontare dopo le app consumer.

Micro-step proposti (da eseguire SOLO dopo conferma e paracadute):
1. snapshot "prima" → 2. rimozione Gruppo A → 3. riavvio → 4. verifica app di lavoro →
5. snapshot "dopo" + `Compare-Snapshot` per certificare cosa è cambiato → 6. changelog in mappa. Poi, in una sessione successiva, eventualmente Gruppo B e la categoria AI/slop.

## Domande aperte / decisioni ✍️ dell'utente

Dalla mappa compilata, da affrontare una alla volta col paracadute Veeam: BitLocker OFF su tutti i volumi, Secure Boot disattivo (TPM pronto), logging PowerShell non configurato, residuo Lenovo tra le task, estensione VPN/proxy nel browser. Il server MCP locale resta rimandato (`.mcp.json` segnaposto in radice).
