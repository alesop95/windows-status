# Anonimizzazione: i casi osservati

> Norma del pacchetto `anonymization`. Non si carica all'avvio di una sessione e non serve per applicare la regola: raccoglie i casi, con le misure e le date, che giustificano le prescrizioni di `rules/anonymization.md`. La divisione esiste perché quella regola è sempre attiva in ogni progetto che la istanzia e concorre al budget degli instruction file, mentre un caso osservato si legge una volta sola, quando si vuole capire perché una prescrizione è scritta così. Si istanzia in `.claude/norme/anonymization.md`.

## La visibilità si stabilisce prima della prima riga

Il 2026-10-27, in un progetto istanziato: un percorso aziendale completo è finito come valore predefinito di un parametro in uno script e da lì in un repository pubblico. L'errore non è stato scrivere quel percorso, comodo e innocuo in locale, ma non aver mai chiesto dove sarebbe finito.

## Il perimetro non è l'insieme dei file tracciati

Il difetto che ha fissato la definizione è controintuitivo. Definire il perimetro come l'insieme dei file tracciati sembra naturale, e lascia fuori il file nuovo, scritto e non ancora aggiunto all'indice, proprio nel momento in cui serve guardarlo. Nel progetto di origine tre file nuovi sono passati puliti per fortuna e non per verifica, e il difetto è stato scoperto per caso qualche giorno dopo.

## Perché i riscontri del layer privato non bloccano

Nel progetto di origine la misura dice 10.844 riscontri nel layer privato contro zero bloccanti nel perimetro pubblico, e fra i file più densi c'è proprio la mappa dei segnaposto, che per definizione contiene tutti i valori reali. È la ragione per cui quei riscontri si elencano a parte invece di fermare il commit.

## La convenzione esce dove qualcuno la spiega

Il 2026-10-26, in un progetto istanziato: due righe del registro di lavoro di un *secondo* repository pubblico dichiaravano la corrispondenza fra la classe di indirizzi reali di una rete e la classe di segnaposto che la sostituiva, nominando il repository dove la mappatura viveva. Quelle due righe rendevano reversibili quattrocentosessantuno occorrenze nel repository protetto, mentre il controllo restituiva zero riscontri bloccanti, correttamente, perché ciò che era uscito non era un valore ma la regola.

## Un verde misura i pattern, non il repository

Nel progetto di origine, dopo un controllo verde, una lettura integrale per categorie chiuse ha trovato circa millecento riscontri: clienti, identificativi amministrativi, nomi di battesimo, indirizzi scritti con separatori diversi dal punto e documenti interi di altri progetti, nessuno dei quali aveva un pattern. Sulle parole brevi, il 2026-10-28 una voce dell'elenco dei nomi propri ha prodotto due riscontri bloccanti dentro la parola inglese «removing» del testo di una skill, fermando un commit senza che niente fosse uscito. Il valore concreto della voce resta nel livello privato: anche il racconto di un falso positivo deve rispettare l'anonimizzazione.

## Dettaglio conservato dalla regola del progetto

## Il controllo automatico, e perché non basta la buona volontà

Lo strumento `tools/Test-Anonymization.py` di questo pacchetto passa i file del repository e riporta indirizzi reali, indirizzi fisici reali, nomi propri di persona, caselle di posta personali, importi, numeri di telefono, IBAN, partite IVA e i segreti letterali già noti. Esce con codice diverso da zero se trova qualcosa nelle categorie bloccanti, e va eseguito prima di ogni commit che tocchi documentazione.

```
python tools/Test-Anonymization.py
python tools/Test-Anonymization.py --tutti    # include il layer privato, non bloccante
```

Lo script è versionato e non contiene nessun valore reale: ciò che deve cercare vive nel file dei pattern del layer privato, la cui forma è dichiarata in `patterns.example.json`. Se quel file manca, lo script si ferma e lo dichiara invece di restituire un esito verde che non ha calcolato. Quando cresce la mappa dei segnaposto cresce anche il file dei pattern: sono due facce dello stesso dato.

La ragione per cui il controllo esiste, e va usato invece che ricordato, è un numero. Il primo audit nel progetto di origine ha trovato centoquarantotto riscontri su ottantanove file tracciati, di cui una trentina erano valori reali veri: indirizzi cablati dentro gli script, indirizzi fisici di apparati dentro gli script di scrittura, indirizzi pubblici di macchine virtuali, caselle di posta personali, importi contrattuali, e la voce di registro citata sopra. Nessuno di quei residui era stato introdotto di proposito, e nessuno apparteneva alla sessione che li ha scoperti.

Ne discende la regola operativa: il controllo si fa sull'*intero perimetro*, non sui soli file toccati dalla sessione. Un residuo non si introduce, si eredita, e restare puliti sui propri file non dice niente sul repository.

## Il perimetro del controllo, e perché non è l'insieme dei file tracciati

Il perimetro predefinito è ciò che sta per essere pubblicato, cioè i file tracciati più quelli non tracciati e non ignorati, che sono esattamente i candidati al prossimo commit. I riscontri di entrambi i gruppi sono bloccanti, perché entrambi i gruppi finiscono in pubblico, e quelli del secondo gruppo vengono marcati a video con un avviso esplicito.

Definire il perimetro come l'insieme dei file tracciati sembra la scelta naturale ed è sbagliata, perché un file nuovo e non ancora aggiunto all'indice resta invisibile al controllo proprio nel momento in cui serve guardarlo, cioè prima di pubblicarlo.

Con `--tutti` entrano anche i file *ignorati*, cioè il layer narrativo locale e gli output degli strumenti. Quei file contengono valori reali per costruzione e per decisione, ed è il motivo per cui git li ignora. I loro riscontri vengono perciò elencati a parte, aggregati per file, e *non sono bloccanti*: se lo fossero il controllo fallirebbe per il solo fatto di esistere, e un controllo che fallisce sempre smette di essere letto.

Ne discende la proprietà che rende il perimetro corretto senza manutenzione: un percorso del layer privato diventa un problema nell'istante in cui viene tracciato, e in quel momento non compare più fra i riscontri privati ma fra i bloccanti, con la marca di file non tracciato. Il controllo cambia da solo la propria valutazione quando cambia lo stato del file, e nessuno deve ricordarsi di aggiornare una lista.


## Verifica della visibilita: motivazione completa

Quale dei due casi sia si stabilisce prima della prima riga e non dopo il push, perché dopo il push nessuna correzione è più completa: la storia resta, e ciò che è stato pubblico non torna privato. Costa un comando, `gh repo view <owner>/<repo> --json visibility -q .visibility`, e la convenzione del progetto su che cosa non deve entrare nei file tracciati sta già scritta nelle sue regole. L'esito non resta nella testa di chi l'ha chiesto: il progetto dichiara nel proprio `CLAUDE.md`, che l'agente legge a ogni sessione, se il repository è pubblico, privato o condiviso, con la verifica e la data. È quella riga a rendere azionabile tutto il resto, e dove mancava la visibilità è stata scoperta solo dopo aver scritto. Il presupposto però non è la visibilità di oggi ma quella che il repository può assumere: passa a pubblico con un clic, deciso magari da qualcun altro, e in quell'istante tutto ciò che è stato scritto confidando nella privatezza diventa pubblico insieme alla storia, senza che niente lo annunci. Ne segue che il guard-rail si adotta in ogni repository che documenti materia di qualcun altro, quale che sia la visibilità corrente, e che il confronto fra dichiarato e osservato è un controllo di chiusura, `tools/check-visibilita.py`, e non una verifica da ricordare.
