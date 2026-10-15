# 16 - Prima installazione di un PC nuovo

> Cosa si fa a un PC Windows appena acceso, prima che diventi la macchina di qualcuno. Due strumenti di terze parti fanno il lavoro sporco; questo progetto ci mette attorno la catena di custodia che a loro non compete: versioni appuntate e verificate, paracadute, conferma a ogni passo, e una fotografia prima e una dopo, confrontate.

## Il problema, e perche' non basta lanciare gli strumenti

Un PC nuovo arriva con Copilot, Recall, Click to Do, le app preinstallate, i contenuti suggeriti e la telemetria accesa. E arriva anche senza nessuno che guardi come sta. Esistono progetti aperti che risolvono bene le due cose, e non ha senso riscriverli:

| Strumento | Autore | Licenza | Cosa fa |
|---|---|---|---|
| [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) | zoicware | MIT | rimuove Copilot, Recall, Click to Do e i pacchetti AI anche quando Windows li marca come non rimovibili |
| [Win11Debloat](https://github.com/Raphire/Win11Debloat) | Raphire | MIT | app preinstallate, telemetria, contenuti suggeriti, barra applicazioni, menu Start, Esplora file |
| [Netdata](https://github.com/netdata/netdata) | netdata | GPL-3.0 | agente di monitoraggio: metriche al secondo, allarmi, storico. A differenza degli altri due non toglie, **mette** |

Il problema non e' quello che fanno: e' come si usano. I primi due si presentano con un comando che scarica ed esegue codice remoto in un colpo solo, `irm <url> | iex`. Quella forma e' comoda e ha tre difetti che questo progetto non puo' accettare: esegue codice che nessuno ha guardato, prende *qualunque cosa* ci sia a quell'indirizzo nel momento in cui si preme invio, e non e' ripetibile, perche' domani quell'indirizzo servira' un file diverso. Inoltre nessuno di loro lascia un verbale di cosa ha cambiato davvero sulla macchina.

Il progetto ha gia' la risposta a quest'ultimo punto - la fotografia e il confronto - e ha dei paletti che valgono anche qui. Da cui `scripts\Prima-Installazione.ps1`: non un terzo strumento di pulizia, ma la **catena di custodia** attorno ai tre.

## Cosa aggiunge la catena

**Versioni appuntate.** `scripts\prima-installazione\strumenti.json` fissa per ogni strumento un commit immutabile e il digest SHA-256 del suo file di ingresso. Lo script prende il codice a quel commit - con `git checkout` se git c'e', altrimenti dallo zip di quel commit - e poi **verifica il digest**. Se non corrisponde, si ferma e non esegue niente. Un commento aggiunto a una riga basta a farlo scattare: e' stato provato di proposito.

**Paracadute prima, non dopo.** Punto di ripristino creato sul momento, e una domanda esplicita sull'immagine di sistema a cui bisogna rispondere `SI` per proseguire. Lo script non sa creare un'immagine e non finge di saperlo: su una macchina nuova sono pochi minuti con Veeam Agent, e la procedura sta in `docs/02`.

**Conferma a ogni passo.** Niente scorre da solo: ogni passo che modifica chiede di digitare `SI`, e qualunque altra risposta lo salta invece di interrompere la catena.

**Fotografia prima e dopo.** `Snapshot-Stato.ps1` gira sulla macchina vergine, poi di nuovo alla fine, e `Compare-Snapshot.ps1` dice cosa e' cambiato. E' la regola del progetto - prima la mappatura, poi la pulizia - applicata al caso in cui la pulizia la fa qualcun altro. Senza, "cosa ha tolto quello strumento" resta una domanda senza risposta.

**Niente riavvii automatici.** Dove serve un riavvio, lo script lo dice e si ferma, e spiega con quale comando riprendere. Il riavvio lo decide chi sta davanti alla macchina.

## La cosa piu' importante: gli strumenti non sono reversibili allo stesso modo

Questa asimmetria decide tutto il resto, e va capita prima di premere invio.

**Win11Debloat e' reversibile.** L'autore lo dichiara e documenta come tornare indietro; quasi tutte le app si reinstallano dallo Store. Agisce su chiavi di registro e pacchetti ordinari. Se una scelta non piace, si rifa'.

**RemoveWindowsAI lo e' solo in parte**, e vale la pena dire esattamente quanto, perche' leggendo il suo codice si scopre che fa piu' di quanto prometta il titolo. Ha due interruttori che contano:

- `-backupMode` esporta, nella cartella `RemoveWindowsAI\Backup` del profilo utente, le chiavi di registro dei servizi che sta per cancellare (`WSAIFabricSvc`, `AarSvc` e gli altri), e in modo non interattivo crea anche un punto di ripristino.
- `-revertMode` rilegge quei file e rimette i valori di registro sullo stato acceso.

Quindi la parte *di registro* del lavoro si disfa. Quello che **non** torna sono i pacchetti rimossi: appx, voci del CBS store e file cancellati non vengono salvati da nessuna parte, e il pacchetto di aggiornamento fittizio che impedisce la reinstallazione resta. Per quella meta' del lavoro **il ritorno indietro e' l'immagine di sistema**, o la reinstallazione.

Per questo la catena gli passa **sempre** `-backupMode`, senza chiederlo: costa pochi secondi, e senza di esso anche la parte reversibile smetterebbe di esserlo.

Da cui la regola operativa: RemoveWindowsAI si esegue **su una macchina nuova, prima che contenga dati di qualcuno**, e con un'immagine gia' fatta. Su una macchina in servizio non si esegue, e questo script fa di tutto per renderlo difficile.

Due altre cose dichiarate dal suo autore: va eseguito con **Windows PowerShell 5.1** e non con PowerShell 7 (lo script lo invoca sempre con l'eseguibile 5.1, quindi il problema non si pone), e alcuni antivirus di terze parti lo segnalano come **falso positivo**, cosa normale per gli strumenti che fanno modifiche profonde.

## Il vincolo aziendale

Su una macchina unita a un dominio, registrata a un tenant o gestita via MDM, lo script **si ferma**. Non e' prudenza generica: il paletto 4 del progetto vieta di toccare senza ordine esplicito Windows Update, Defender, attivazione Office, Edge/WebView2, OneDrive e la telemetria, e fra le opzioni di Win11Debloat ci sono proprio la telemetria, le politiche di Windows Update e la disattivazione della cifratura automatica BitLocker.

Se l'ordine c'e', si ripete con `-ForzaAziendale`, che esiste apposta per rendere la decisione una cosa presa e non una cosa dimenticata. Lo stato della macchina viene letto da `dsregcmd /status` e dalle registrazioni MDM, e il piano lo stampa prima di qualunque cosa.

## Uso

```powershell
cd <cartella del progetto>
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\scripts\Prima-Installazione.ps1              # piano e prerequisiti, SOLA LETTURA
.\scripts\Prima-Installazione.ps1 -Scarica     # scarica e verifica i digest, non esegue
.\scripts\Prima-Installazione.ps1 -Applica     # catena completa, conferma per passo
.\scripts\Prima-Installazione.ps1 -Controlla   # cosa e' rimasto, sola lettura
```

Senza parametri non tocca niente: stampa chi e' la macchina, se e' aziendale, se c'e' un punto di ripristino, quale edizione di Windows e' (su Home l'autore di RemoveWindowsAI non garantisce la rimozione completa), e l'ordine della catena.

| Parametro | A cosa serve |
|---|---|
| `-Scarica` | prende e verifica gli strumenti senza eseguirli; si puo' fare prima, anche altrove |
| `-Applica` | esegue la catena |
| `-Controlla` | verifica dopo: pacchetti AI, servizio `WSAIFabricSvc`, attivita' pianificate, funzionalita' Recall, piu' il confronto fra le due fotografie |
| `-Passi <elenco>` | `SNAPSHOT`, `PARACADUTE`, `AI`, `DEBLOAT`, `MONITORAGGIO`, `CONTROLLO` |
| `-Profilo <percorso>` | le scelte gia' prese per i tre strumenti; senza, usa `prima-installazione\profilo.json` se esiste |
| `-OpzioniAI <...>` | argomenti passati tali e quali a RemoveWindowsAi.ps1; senza, parte la sua interfaccia |
| `-OpzioniDebloat <...>` | argomenti passati tali e quali a Win11Debloat.ps1; senza, parte il suo menu |
| `-ForzaAziendale` | procede su macchina a dominio, tenant o MDM |
| `-Cartella <percorso>` | dove mettere il codice di terze parti; per default una cartella temporanea, **fuori dal repository** |
| `-SenzaSnapshot` | salta le fotografie, se sono gia' state fatte a mano |

L'ordine e' `SNAPSHOT`, `PARACADUTE`, `AI`, riavvio, `DEBLOAT`, `MONITORAGGIO`, riavvio, `CONTROLLO`. Prima il passo senza ritorno, su un sistema ancora intatto, perche' cerca pacchetti e voci che un debloating precedente potrebbe avere gia' spostato; poi quello reversibile, che e' anche quello che si rifa' volentieri una seconda volta quando si cambia idea su un dettaglio dell'interfaccia.

Il codice di terze parti viene scaricato in una cartella temporanea e non dentro il progetto: codice altrui non vive accanto agli script del progetto, e non finisce per sbaglio in un commit.

## Il profilo: togliere i menu, non le conferme

Senza profilo i tre strumenti aprono ciascuno la propria interfaccia, e su ogni PC nuovo si rifanno le stesse scelte a mano, con il rischio che la decima macchina non sia configurata come la prima. Il profilo le scrive una volta.

```powershell
copy .\scripts\prima-installazione\profilo.esempio.json .\scripts\prima-installazione\profilo.json
# si adatta, poi la catena lo trova da sola
```

Il profilo contiene tre blocchi: `ai.opzioni` e `debloat.opzioni`, cioe' gli argomenti passati tali e quali ai due script, e `monitoraggio`, che decide di Netdata. I nomi dei parametri nell'esempio sono quelli **veri**, letti dal codice degli strumenti alla versione appuntata: se si aggiorna una versione si ricontrollano.

Quello che il profilo toglie sono le interfacce. **Non toglie le conferme**: ogni passo che modifica continua a chiedere `SI`, perche' quello e' il paletto 1 e non e' una scomodita' da aggirare. Un parametro passato a mano sulla riga di comando vince sempre sul profilo.

`profilo.json` e' **ignorato da git** perche' puo' contenere il token di Netdata, che e' un segreto: si versiona solo `profilo.esempio.json`, esattamente come per `baseline-eccezioni.json`.

L'esempio e' tarato su un PC **non** aziendale e lascia fuori di proposito quattro opzioni di Win11Debloat - `-DisableTelemetry`, `-DisableUpdateASAP`, `-DisableDeliveryOptimization`, `-DisableBitlockerAutoEncryption` - e la voce `DisableDefenderAI` di RemoveWindowsAI: sono esattamente cio' che il paletto 4 vieta di toccare su una macchina del tenant.

## Gli applicativi: Ninite o winget

Il passo `APPLICATIVI` mette il software di base sulla macchina vergine, subito dopo il paracadute e prima della pulizia: e' il momento in cui non c'e' ancora niente da rompere e la fotografia iniziale e' gia' stata presa. Si sceglie nel profilo fra due vie che **non sono equivalenti**, e vale la pena sapere in cosa differiscono.

**winget** e' la via che si accorda con il resto della catena. Verifica l'hash di ogni pacchetto dal manifesto del suo repository, e' gia' dentro Windows, e il progetto lo usa gia' in `Reinstall-Software.ps1`. Gli identificativi si trovano con `winget search`.

**Ninite** e' comodo: una pagina, si spuntano i programmi, esce un installatore che li mette tutti senza chiedere niente e senza barre degli strumenti. Ma ha due proprieta' che lo mettono fuori dalle regole di questa catena, e il progetto non fa finta che le segua.

*Non e' appuntabile.* Ninite costruisce l'eseguibile a ogni richiesta. Lo abbiamo misurato: due scaricamenti della stessa identica selezione, a pochi secondi di distanza, hanno la stessa dimensione (433.816 byte) e **digest SHA-256 diversi**. Non esiste quindi un digest da mettere nel manifesto, e non e' un difetto di Ninite: e' come funziona, e per giunta installa sempre le *ultime* versioni, quindi la stessa selezione oggi e fra un mese non produce lo stesso PC. Tutta la catena esiste per rendere ripetibile una prima installazione; questo passo, con Ninite, ripetibile non e'.

*Non e' open source.* E' un servizio chiuso, gratuito per uso personale, mentre l'uso in azienda ricade sotto Ninite Pro, che si paga.

Se lo si usa lo stesso - ed e' una scelta legittima su un PC personale - la catena fa le due cose che restano possibili: verifica la **firma Authenticode** dell'eseguibile e si ferma se non e' valida, e stampa il **digest della copia effettivamente eseguita**, da annotare nel changelog. Non e' un digest atteso, e' un digest testimoniato: dice almeno *cosa* e' stato eseguito quel giorno.

Le voci di Ninite nel profilo sono i nomi che compaiono nel suo indirizzo: `ninite.com/7zip-vlc-firefox/ninite.exe` diventa `["7zip", "vlc", "firefox"]`.

## Netdata: perche' non si installa da solo

Netdata e' il terzo strumento, e ha una natura diversa dagli altri due: non toglie, installa un servizio che resta acceso e raccoglie metriche al secondo. Si disinstalla come un normale MSI, quindi e' reversibile.

Il motivo per cui nel profilo sta a `installa: false` non e' tecnico, e' una decisione da prendere consapevolmente. Dalla documentazione di Netdata: **su Windows, con il piano gratuito Community, il cruscotto locale `http://localhost:19999` e' bloccato**. L'agente raccoglie, ma i dati si guardano su Netdata Cloud. Le conseguenze sono due, e sono entrambe importanti qui:

- **senza token** di aggancio l'agente gira e non mostra niente, ne' in locale ne' altrove: si installa un servizio inutile;
- **con il token** le metriche della macchina escono verso un servizio di terze parti, cosa che su una macchina aziendale e' una decisione di chi governa i dati, non di chi installa il PC.

Per questo la catena non lo installa se il profilo non lo dice, e se il profilo non ha un token lo chiede una seconda volta prima di procedere.

Due note operative. L'agente apre la **porta 19999 in ascolto**: compare nella sezione superficie d'attacco dello snapshot, e se il cruscotto si guarda dal Cloud non serve che sia raggiungibile dalla rete - `chiudiFirewall: true` nel profilo fa creare, a conferma, una regola in ingresso che la blocca. E l'installatore pesa circa 173 MB: su una macchina senza rete va portato con la chiavetta.

Il digest di Netdata nel manifesto non e' calcolato da noi su una copia scaricata una volta: e' quello pubblicato dall'autore nel file `sha256sums.txt` della release. E' una differenza che conta, perche' un digest calcolato su cio' che si e' scaricato certifica solo che il file non e' cambiato *dopo*.

## Portare tutto su un PC senza rete

`scripts\Prepara-Chiavetta.ps1`, da lanciare **sulla macchina vecchia**, mette in una cartella sola le tre cose che al PC nuovo servono e che non si trovano la':

```powershell
.\scripts\Prepara-Chiavetta.ps1 -Destinazione E:\
```

Dentro ci finiscono il progetto senza cronologia git, senza `snapshots\` e senza `_notes\`; gli strumenti alle versioni appuntate, **gia' verificati**; e `software_winget.json`, cioe' l'elenco dei programmi della macchina vecchia, che nasce da uno snapshot e non puo' stare nel repository. Piu' un `LEGGIMI.txt` con la sequenza.

Il profilo viene copiato solo con `-ConProfilo`, e se contiene un token lo script avvisa che da quel momento la chiavetta e' essa stessa un segreto.

Sul PC nuovo si indica alla catena dove sono gli strumenti e la rete non serve:

```powershell
.\scripts\Prima-Installazione.ps1 -Applica -Cartella <percorso di strumenti\>
```

## Dove sono arrivato

Su una macchina nuova si perde facilmente il conto, soprattutto fra i due riavvii. La voce `P` di `Avvia.ps1` - *PC NUOVO: percorso guidato* - stampa la sequenza con lo stato di ogni passo e la voce di menu che lo esegue.

Distingue tre cose e non ne confonde nessuna: `[x]` fatto, `[ ]` da fare, `[?]` **non verificabile da qui**. L'immagine Veeam, per esempio, resta `[?]`: nessuno script puo' sapere se e' stata fatta, e fingere di saperlo sarebbe peggio che ammetterlo.

## Aggiornare le versioni appuntate

I tre progetti sono vivi e cambiano spesso. Appuntare una versione significa che la catena resta ripetibile, non che si resta indietro per sempre: l'aggiornamento e' un atto deliberato.

1. Si guarda cosa e' cambiato a monte, dal commit appuntato a quello nuovo.
2. Si calcola il digest del nuovo file di ingresso: `(Get-FileHash .\Win11Debloat.ps1 -Algorithm SHA256).Hash`.
3. Si aggiornano `commit`, `commit_data` e `sha256` in `scripts\prima-installazione\strumenti.json`.
4. Si prova su una macchina di prova o in una macchina virtuale.
5. Si annota nel changelog della mappa.

Per Win11Debloat il manifesto punta al **tag di rilascio** e non alla punta del ramo: un rilascio e' un artefatto che l'autore ha dichiarato stabile. RemoveWindowsAI non pubblica rilasci, quindi li' si appunta un commit.

Se un giorno il digest non corrisponde senza che nessuno abbia aggiornato il manifesto, la risposta giusta non e' aggiornare il manifesto: e' guardare perche'.

## Dopo: cosa resta

`-Controlla` cerca i residui noti - pacchetti il cui nome contiene Copilot, Recall, AIX, AppChat, WindowsWorkload, ClickToDo; il servizio `WSAIFabricSvc`; le attivita' pianificate con AI, Recall o Copilot nel nome; lo stato della funzionalita' opzionale Recall - e poi esegue il confronto fra le due fotografie.

Qualche residuo e' normale e non significa che lo strumento abbia fallito: una parte delle funzioni AI non si tocca da script, e l'autore tiene una pagina apposta, `OtherAIFeatures.md`, con quello che va spento a mano. Un aggiornamento di Windows puo' inoltre rimettere qualcosa: RemoveWindowsAI installa per questo un'attivita' pianificata che ricontrolla dopo gli aggiornamenti, ed e' il motivo per cui conviene rifare `-Controlla` dopo il primo Patch Tuesday della macchina.

## Rapporto con gli altri documenti

`docs/00_GUIDA_OTTIMIZZAZIONE.md` resta il documento del debloating **manuale e ragionato** su una macchina gia' in servizio, dove ogni categoria si valuta e si verifica. Questo documento copre il caso opposto: una macchina nuova, dove si puo' essere molto piu' decisi perche' non c'e' niente da rompere e l'immagine e' appena stata fatta.

`docs/02` ha la procedura dell'immagine Veeam, che qui e' il paracadute. `docs/05` e' la guida rapida d'uso del progetto. Il changelog degli interventi, come sempre, sta nella mappa: lo script stampa a fine corsa la riga gia' pronta da incollare.
