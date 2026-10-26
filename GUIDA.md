# Guida all'uso di windows-status

> Come si usa il progetto, tutto, in un posto solo. **Meta' di questo file e' generata dal progetto stesso**: le tabelle fra i marcatori `<!-- GENERATO -->` nascono da `Avvia.ps1`, dalla cartella `scripts\`, da `docs\` e dal manifesto degli strumenti di terze parti. Si rigenerano con `.\scripts\Aggiorna-Guida.ps1 -Applica` e non si scrivono a mano, cosi' che una capacita' nuova non possa restare fuori dalla guida in silenzio.
>
> Per il percorso completo su una macchina appena accesa c'e' un file a parte: `LEGGIMI-PC-NUOVO.md`.

## Da dove si parte, sempre

```powershell
cd <cartella del progetto>
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Avvia.ps1
```

`Avvia.ps1` e' il punto d'ingresso unico: non fa niente da se', chiama gli script di `scripts\`. Le voci marcate `sola lettura` sono sicure ovunque e in qualunque momento; quelle marcate `MODIFICA` chiedono conferma e presuppongono il paracadute (immagine recente piu' punto di ripristino).

Molte voci danno molto di piu' da **amministratore**: senza, allo snapshot mancano BitLocker, Secure Boot, TPM, Defender e i dati degli altri account, e il riepilogo lo dichiara.

## Voglio fare una cosa precisa

| Se vuoi... | Fai |
|---|---|
| sapere com'e' messa questa macchina, adesso | voce `1`, poi `2b` per il report leggibile |
| sapere **cosa e' cambiato** da ieri | voce `1` e poi `2` (confronto fra gli ultimi due snapshot) |
| capire perche' la macchina e' lenta o instabile | voci `2c`, `2f`, e `2d` se il sospetto e' PowerPoint |
| portare la macchina alle best practice di sicurezza | voce `3` (solo report), poi `4` (applicazione guidata) |
| **preparare un PC nuovo** | `LEGGIMI-PC-NUOVO.md`, poi voce `P` |
| preparare la chiavetta per un PC senza rete | voce `11`, dalla macchina **vecchia** |
| censire una macchina che non ha questo progetto | voce `10` qui, oppure `scripts\censimento\` copiato la' |
| accendere il monitoraggio continuo del parco | voce `12` sull'hub, e il passo `MONITORAGGIO` sui PC |
| ritrovare i log di tutte le macchine insieme | Loki sull'hub e il passo `LOG` sui PC, vedi `docs/17` |
| reinstallare i programmi su una macchina nuova | voce `5`, con il `software_winget.json` della vecchia |
| fotografare da solo, ogni giorno | voce `6i` (attivita' pianificata, opt-in) |

## Il menu, voce per voce

Questa tabella e' generata da `Avvia.ps1`: se una voce c'e' li', e' qui.

<!-- GENERATO: menu -->
| Voce | Cosa fa | Tipo | Script |
|---|---|---|---|
| `1` | Fotografa lo stato (snapshot completo) | sola lettura | `Snapshot-Stato.ps1` |
| `2` | Confronta i due snapshot piu recenti | sola lettura | `Compare-Snapshot.ps1` |
| `2b` | Genera report HTML dell'ultimo snapshot | sola lettura | `Genera-Report.ps1` |
| `2c` | Controlla salute e stabilita (registro eventi) | sola lettura | `Controlla-Salute.ps1` |
| `2d` | Diagnostica PowerPoint lento (cache identita Office) | sola lettura | `Diagnostica-PowerPoint.ps1` |
| `2e` | Bonifica cache PowerPoint (profilo corrente) | **MODIFICA** | `Diagnostica-PowerPoint.ps1` |
| `2f` | Diagnostica memoria vincolata (detentore e proiezione) | sola lettura | `Diagnostica-Vincolata.ps1` |
| `2g` | Verifica rilascio vincolata (termina il sospetto) | **MODIFICA** | `Diagnostica-Vincolata.ps1` |
| `2h` | Recupera un supporto rimovibile che sta cedendo | sola lettura | `Recupera-Supporto.ps1` |
| `3` | Report baseline di sicurezza (divario) | sola lettura | `Allinea-BestPractice.ps1` |
| `4` | Applica baseline di sicurezza (guidato) | **MODIFICA** | `Allinea-BestPractice.ps1` |
| `5` | Reinstalla software da winget export | **MODIFICA** | `Reinstall-Software.ps1` |
| `6` | Snapshot periodico: stato | sola lettura | `Pianifica-Snapshot.ps1` |
| `6i` | Snapshot periodico: INSTALLA (attivita pianif.) | **MODIFICA** | `Pianifica-Snapshot.ps1` |
| `7` | Check salute periodico: INSTALLA (attivita pianif.) | **MODIFICA** | `Controlla-Salute.ps1` |
| `8` | Design system di account: verifica la propagazione | sola lettura | `Installa-DesignSystem.ps1` |
| `9` | PC NUOVO: piano della prima installazione | sola lettura | `Prima-Installazione.ps1` |
| `9s` | PC NUOVO: scarica e verifica gli strumenti | sola lettura | `Prima-Installazione.ps1` |
| `9a` | PC NUOVO: esegui la catena (AI + debloat) | **MODIFICA** | `Prima-Installazione.ps1` |
| `9c` | PC NUOVO: controlla i residui AI, dopo | sola lettura | `Prima-Installazione.ps1` |
| `10` | Censimento hardware di questa macchina (anonimo) | sola lettura | `censimento\hw-report-windows.ps1` |
| `11` | Prepara la cartella per un PC nuovo (chiavetta) | sola lettura | `Prepara-Chiavetta.ps1` |
| `P` | PC NUOVO: percorso guidato (dove sono arrivato) | sola lettura | (interno al menu) |
| `12` | Monitoraggio: piano della macchina centrale | sola lettura | `Monitoraggio-Centrale.ps1` |
| `12s` | Monitoraggio: scarica e verifica Prometheus e Grafana | sola lettura | `Monitoraggio-Centrale.ps1` |
| `G` | Guida: e' allineata al progetto? | sola lettura | `Aggiorna-Guida.ps1` |
| `Ga` | Guida: riallinea GUIDA.md al progetto | sola lettura | `Aggiorna-Guida.ps1` |

Voci totali: 27, di cui 7 che modificano il sistema.
<!-- FINE GENERATO: menu -->

## Gli strumenti

Tutti gli script del progetto, con la loro riga di sintesi presa dalla loro stessa intestazione. Quelli direttamente in `scripts/` ricavano la radice del progetto dalla cartella genitore e devono restare li'; quelli in `scripts/rmm/` e `scripts/censimento/` no, e infatti funzionano anche da soli, copiati altrove.

<!-- GENERATO: strumenti -->
| Script | A cosa serve |
|---|---|
| `scripts/Agenti.ps1` | Punto d'ingresso di QUESTA MACCHINA alla catena degli agenti da terminale. |
| `scripts/Aggiorna-Guida.ps1` | tiene GUIDA.md allineata al progetto |
| `scripts/Allinea-BestPractice.ps1` | Allinea un PC Windows 11 al baseline di sicurezza |
| `scripts/Campiona-Vincolata.ps1` | Campionatore di SOLA LETTURA della memoria vincolata |
| `scripts/Compare-Snapshot.ps1` | Confronta due snapshot e mostra COSA E' CAMBIATO |
| `scripts/Controlla-Salute.ps1` | Check di SOLA LETTURA di salute e stabilita' del PC |
| `scripts/Diagnostica-PowerPoint.ps1` | Diagnosi di PowerPoint lento (cache identità Office) |
| `scripts/Diagnostica-Vincolata.ps1` | Chi trattiene la memoria vincolata che cresce |
| `scripts/Genera-Report.ps1` | Report HTML autoconsistente da uno snapshot |
| `scripts/Installa-DesignSystem.ps1` | Propaga UN design system, confezionato come pacchetto skill, a tutte le radici |
| `scripts/Monitoraggio-Centrale.ps1` | la macchina che guarda le altre |
| `scripts/Pianifica-Snapshot.ps1` | Snapshot periodico (opt-in) per il rilevamento drift |
| `scripts/Prepara-Chiavetta.ps1` | prepara la cartella da portare sul PC nuovo |
| `scripts/Prima-Installazione.ps1` | prima installazione di un PC Windows nuovo |
| `scripts/Recupera-Supporto.ps1` | Copia via un supporto rimovibile che sta cedendo |
| `scripts/Reinstall-Software.ps1` | Reinstalla i programmi su un PC nuovo dal winget export |
| `scripts/Snapshot-Stato.ps1` | Fotografia di SOLA LETTURA di un PC Windows 11 |
| `scripts/censimento/hw-report.sh` | censimento hardware di UNA macchina Linux |
| `scripts/censimento/hw-report-windows.ps1` | censimento hardware di UNA macchina Windows |
| `scripts/rmm/Disk-LayoutDrift.ps1` | Rileva variazioni nel layout dei volumi (GUID) dei dischi fissi. |
| `scripts/rmm/Fix-OfficeDocToIdMapping.ps1` | Rileva e bonifica la cache Office "DocToIdMapping" sovradimensionata |
| `scripts/rmm/Veeam-BackupFreshness.ps1` | Monitor freschezza backup Veeam Agent for Microsoft Windows. |
<!-- FINE GENERATO: strumenti -->

## I documenti

<!-- GENERATO: documenti -->
| Documento | Titolo |
|---|---|
| `docs/00_GUIDA_OTTIMIZZAZIONE.md` | 00 -  Ottimizzazione e debloating reale (PC Entra ID joined) |
| `docs/01_MAPPA_CONFIGURAZIONE.md` | 01 -  Mappa configurazione (documento vivo) |
| `docs/02_VEEAM_BACKUP_PORTABILITA.md` | 02 — Veeam su NAS: backup ripristinabile su un altro PC, in qualsiasi momento |
| `docs/03_HANDOFF_CLAUDE_CODE.md` | 03 — Handoff a Claude Code su `E:\windows-status` |
| `docs/04_GIT_VERSIONAMENTO_MULTIACCOUNT.md` | 04 — Versionamento git multi-account (identità personale su PC aziendale) |
| `docs/05_QUICKSTART.md` | 05 - Quickstart: come si usa `windows-status` |
| `docs/06_RACCORDO_CHECKLIST_VA.md` | 06 - Raccordo con la checklist di remediation (Vulnerability Assessment) |
| `docs/07_SALUTE_E_STABILITA.md` | 07 — Salute e stabilità (registro eventi, memoria, crash) |
| `docs/08_MONITORAGGIO_BACKUP_VEEAM.md` | 08 — Monitoraggio del backup Veeam: rilevare il guasto silenzioso |
| `docs/09_TOOLCHAIN_DA_ALTRI_PROGETTI.md` | 09 — Toolchain aggiunta dagli altri progetti della macchina |
| `docs/10_CODEX_CLI_E_WORKSPACE_OPENAI.md` | 10 — Codex CLI e workspace OpenAI |
| `docs/11_ORCHESTRAZIONE_AGENTI_SU_WINDOWS.md` | 11 — Orchestrazione di piu' agenti da terminale su Windows 11 |
| `docs/12_POWERPOINT_LENTO_DOCTOIDMAPPING.md` | 12 - PowerPoint lento: la cache DocToIdMapping |
| `docs/13_MEMORIA_VINCOLATA_HANDLE_LEAK.md` | 13 - Memoria vincolata che cresce: una perdita di handle di sezione |
| `docs/14_DESIGN_SYSTEM_DI_ACCOUNT.md` | 14 - Design system ereditato da un account |
| `docs/15_CENSIMENTO_HARDWARE_MULTIPIATTAFORMA.md` | 15 - Censimento hardware multipiattaforma |
| `docs/16_PRIMA_INSTALLAZIONE_PC_NUOVO.md` | 16 - Prima installazione di un PC nuovo |
| `docs/17_MONITORAGGIO_APERTO_DEL_PARCO.md` | 17 - Monitoraggio aperto del parco |
| `docs/18_USB_SOSPENSIONE_E_SUPPORTI_RIMOVIBILI.md` | 18 - Un supporto USB che non risponde blocca le interrogazioni sui dischi di tutta la macchina |
<!-- FINE GENERATO: documenti -->

## I progetti di terze parti che il progetto usa

Nessuno di questi vive nel repository: il manifesto `scripts\prima-installazione\strumenti.json` ne appunta la versione e il digest, e gli script li scaricano e li **verificano** prima di eseguirli. Non si usa mai la forma `irm <url> | iex` che alcuni di loro consigliano: esegue codice che nessuno ha guardato e non e' ripetibile.

<!-- GENERATO: terze-parti -->
| Progetto | Licenza | Versione appuntata | Ruolo | Piattaforma |
|---|---|---|---|---|
| RemoveWindowsAI | MIT | commit `793e458f13` | pulizia | windows |
| Win11Debloat | MIT | commit `f431c56159` | pulizia | windows |
| windows_exporter | MIT | `v0.31.9` | agente | windows |
| Grafana Alloy | Apache-2.0 | `v1.20.1` | agente | windows |
| Netdata | GPL-3.0 | `v2.12.1` | agente | linux |
| Prometheus | Apache-2.0 | `v3.15.0` | centrale | windows |
| Grafana OSS | AGPL-3.0 | `13.2.4` | centrale | windows |
| Loki | AGPL-3.0 | `v3.7.8` | centrale | windows |

Tutti appuntati a una versione immutabile e verificati per digest SHA-256 prima dell'esecuzione.
<!-- FINE GENERATO: terze-parti -->

Se un digest non corrisponde, la catena si ferma e va bene cosi': vuol dire che il progetto a monte e' cambiato o che il file e' stato alterato. La risposta non e' aggiornare il manifesto, e' guardare perche'. La procedura per aggiornare una versione di proposito sta in `docs/16`.

## Le regole che valgono sempre

1. **Sola lettura per default.** Qualunque cosa modifichi va prima proposta e poi confermata.
2. **Prima il paracadute.** Immagine recente piu' punto di ripristino, prima di toccare.
3. **Una categoria alla volta**, con verifica in mezzo.
4. **Macchina aziendale**: non si toccano Windows Update, Defender, attivazione Office, Edge, OneDrive e telemetria senza un ordine esplicito. Gli script che potrebbero farlo si fermano da soli e chiedono `-ForzaAziendale`.
5. **Mai segreti nel repository.** Il repo e' pubblico: nei file tracciati si usano segnaposto, i valori reali vivono in `CLAUDE.local.md` e in `profilo.json`, entrambi ignorati da git.
6. **Tutto a changelog**, nella mappa: data, cosa, perche', come si annulla.
7. **`git add`, commit e push restano scelte umane.**

## Come si tiene aggiornata questa guida

Le parti fra i marcatori si rigenerano:

```powershell
.\scripts\Aggiorna-Guida.ps1              # dice se e' allineata
.\scripts\Aggiorna-Guida.ps1 -Applica     # la riallinea
.\scripts\Aggiorna-Guida.ps1 -Verifica    # esce 1 se non lo e', per un controllo pre-commit
```

Una capacita' nuova e' finita quando: lo script c'e', ha la sua riga di sintesi nell'intestazione, ha una voce in `Avvia.ps1`, ha un documento in `docs\`, e questa guida e' stata rigenerata. Finche' uno di questi manca, la capacita' esiste per chi l'ha scritta e non per chi aprira' il progetto fra sei mesi.

Le parti **fuori** dai marcatori - la tabella "voglio fare una cosa precisa" qui sopra, soprattutto - restano scritte a mano, perche' nessun generatore sa dire a cosa serve davvero una cosa. Quelle si aggiornano con le dita.
