# 16 - Prima installazione di un PC nuovo

> Cosa si fa a un PC Windows appena acceso, prima che diventi la macchina di qualcuno. Due strumenti di terze parti fanno il lavoro sporco; questo progetto ci mette attorno la catena di custodia che a loro non compete: versioni appuntate e verificate, paracadute, conferma a ogni passo, e una fotografia prima e una dopo, confrontate.

## Il problema, e perche' non basta lanciare i due strumenti

Un PC nuovo arriva con Copilot, Recall, Click to Do, le app preinstallate, i contenuti suggeriti e la telemetria accesa. Esistono due progetti aperti che risolvono bene la cosa, e non ha senso riscriverli:

| Strumento | Autore | Licenza | Cosa fa |
|---|---|---|---|
| [RemoveWindowsAI](https://github.com/zoicware/RemoveWindowsAI) | zoicware | MIT | rimuove Copilot, Recall, Click to Do e i pacchetti AI anche quando Windows li marca come non rimovibili |
| [Win11Debloat](https://github.com/Raphire/Win11Debloat) | Raphire | MIT | app preinstallate, telemetria, contenuti suggeriti, barra applicazioni, menu Start, Esplora file |

Il problema non e' quello che fanno: e' come si usano. Entrambi si presentano con un comando che scarica ed esegue codice remoto in un colpo solo, `irm <url> | iex`. Quella forma e' comoda e ha tre difetti che questo progetto non puo' accettare: esegue codice che nessuno ha guardato, prende *qualunque cosa* ci sia a quell'indirizzo nel momento in cui si preme invio, e non e' ripetibile, perche' domani quell'indirizzo servira' un file diverso. Inoltre nessuno dei due lascia un verbale di cosa ha cambiato davvero sulla macchina.

Il progetto ha gia' la risposta a quest'ultimo punto - la fotografia e il confronto - e ha dei paletti che valgono anche qui. Da cui `scripts\Prima-Installazione.ps1`: non un terzo strumento di pulizia, ma la **catena di custodia** attorno ai due.

## Cosa aggiunge la catena

**Versioni appuntate.** `scripts\prima-installazione\strumenti.json` fissa per ogni strumento un commit immutabile e il digest SHA-256 del suo file di ingresso. Lo script prende il codice a quel commit - con `git checkout` se git c'e', altrimenti dallo zip di quel commit - e poi **verifica il digest**. Se non corrisponde, si ferma e non esegue niente. Un commento aggiunto a una riga basta a farlo scattare: e' stato provato di proposito.

**Paracadute prima, non dopo.** Punto di ripristino creato sul momento, e una domanda esplicita sull'immagine di sistema a cui bisogna rispondere `SI` per proseguire. Lo script non sa creare un'immagine e non finge di saperlo: su una macchina nuova sono pochi minuti con Veeam Agent, e la procedura sta in `docs/02`.

**Conferma a ogni passo.** Niente scorre da solo: ogni passo che modifica chiede di digitare `SI`, e qualunque altra risposta lo salta invece di interrompere la catena.

**Fotografia prima e dopo.** `Snapshot-Stato.ps1` gira sulla macchina vergine, poi di nuovo alla fine, e `Compare-Snapshot.ps1` dice cosa e' cambiato. E' la regola del progetto - prima la mappatura, poi la pulizia - applicata al caso in cui la pulizia la fa qualcun altro. Senza, "cosa ha tolto quello strumento" resta una domanda senza risposta.

**Niente riavvii automatici.** Dove serve un riavvio, lo script lo dice e si ferma, e spiega con quale comando riprendere. Il riavvio lo decide chi sta davanti alla macchina.

## La cosa piu' importante: i due strumenti non sono reversibili allo stesso modo

Questa asimmetria decide tutto il resto, e va capita prima di premere invio.

**Win11Debloat e' reversibile.** L'autore lo dichiara e documenta come tornare indietro; quasi tutte le app si reinstallano dallo Store. Agisce su chiavi di registro e pacchetti ordinari. Se una scelta non piace, si rifa'.

**RemoveWindowsAI non lo e'.** Per togliere pacchetti che Windows marca come non rimovibili usa mezzi profondi: esegue codice come `TrustedInstaller`, rende visibili e rimuove voci del CBS store, cancella attivita' pianificate con i loro file, e installa un pacchetto di aggiornamento fittizio perche' Windows Update non rimetta cio' che ha tolto. Nessuna di queste cose ha un parametro per tornare indietro. **Il ritorno indietro e' l'immagine di sistema**, o la reinstallazione.

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
| `-Passi <elenco>` | `SNAPSHOT`, `PARACADUTE`, `AI`, `DEBLOAT`, `CONTROLLO` |
| `-OpzioniAI <...>` | argomenti passati tali e quali a RemoveWindowsAi.ps1; senza, parte la sua interfaccia |
| `-OpzioniDebloat <...>` | argomenti passati tali e quali a Win11Debloat.ps1; senza, parte il suo menu |
| `-ForzaAziendale` | procede su macchina a dominio, tenant o MDM |
| `-Cartella <percorso>` | dove mettere il codice di terze parti; per default una cartella temporanea, **fuori dal repository** |
| `-SenzaSnapshot` | salta le fotografie, se sono gia' state fatte a mano |

L'ordine e' `SNAPSHOT`, `PARACADUTE`, `AI`, riavvio, `DEBLOAT`, riavvio, `CONTROLLO`. Prima il passo senza ritorno, su un sistema ancora intatto, perche' cerca pacchetti e voci che un debloating precedente potrebbe avere gia' spostato; poi quello reversibile, che e' anche quello che si rifa' volentieri una seconda volta quando si cambia idea su un dettaglio dell'interfaccia.

Il codice di terze parti viene scaricato in una cartella temporanea e non dentro il progetto: codice altrui non vive accanto agli script del progetto, e non finisce per sbaglio in un commit.

## Aggiornare le versioni appuntate

I due progetti sono vivi e cambiano spesso. Appuntare una versione significa che la catena resta ripetibile, non che si resta indietro per sempre: l'aggiornamento e' un atto deliberato.

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
