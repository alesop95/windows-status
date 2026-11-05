# Anonimizzazione della documentazione tecnica

> Regola modulare, da caricare sempre nei progetti che la istanziano. Vale per ogni contenuto scritto d'ora in avanti nei file tracciati. Da istanziare in `.claude/rules/anonymization.md` sostituendo i segnaposto tra parentesi angolari con i valori del progetto, e da estendere man mano che emergono categorie nuove. I casi osservati che giustificano queste prescrizioni, con le misure e le date, stanno in `norme/anonymization.md` di questo pacchetto, da istanziare in `.claude/norme/anonymization.md`: quel file non si carica all'avvio e non serve per applicare la regola.

## Quando questa regola serve, e quando non serve

Serve quando il repository è pubblico, oppure condiviso più largamente della cerchia che lo scrive, e la materia che documenta appartiene a qualcun altro: un'infrastruttura aziendale, un cliente, un fornitore, delle persone fisiche. Le due condizioni valgono insieme. Un repository pubblico che documenta soltanto codice proprio non ne ha bisogno; un repository privato che documenta l'infrastruttura di un cliente ne ha bisogno comunque, perché la cerchia di chi vi accede cambia nel tempo e la storia git conserva tutto.

Prima di scrivere verificare la visibilità del repository e dichiararla in `CLAUDE.md` con data ed esito. Il guard-rail vale per la materia di terzi anche in un repository oggi privato: un cambio di visibilità espone anche la storia. `tools/check-visibilita.py` confronta dichiarato e osservato alla chiusura; dettagli e casi sono nel riferimento `.claude/norme/anonymization.md`.

La ragione per cui la regola è vincolante e non consigliata sta nella durata: ciò che entra in un file tracciato resta visibile anche dopo una correzione successiva, perché la storia git è consultabile finché non viene riscritta, e riscrivere una storia condivisa è un'operazione pianificata e non un rimedio a valle di una svista.

## Cosa si anonimizza sempre

Ogni indirizzo IP[^1] pubblico reale del soggetto documentato o dei suoi fornitori, ogni indirizzo IP privato reale di qualunque blocco, ogni indirizzo fisico[^2] di un apparato reale, e ogni nome proprio completo di una persona fisica, vanno sostituiti con un segnaposto prima di scrivere in un file tracciato.

## Dati amministrativi e commerciali: mai in un file tracciato

Vale a maggior ragione per ciò che non è tecnico, ed è la categoria che sfugge più facilmente perché arriva come dettaglio a corredo di un fatto vero. Non si scrivono mai importi contrattuali e canoni, prezzi di acquisto di hardware o licenze, percentuali di sconto negoziate, numeri di fattura, ordine o preventivo, numeri di linea telefonica o di interno, IBAN e altri dati bancari, partita IVA e codice fiscale di controparti, e termini contrattuali specifici quando rivelano condizioni economiche.

Il criterio che decide è semplice e va applicato senza eccezioni: il *fatto operativo* resta raccontabile, il *numero* no. Si scrive che è stato acquistato uno switch nuovo tramite un preventivo di un certo fornitore, non il prezzo né il numero del preventivo; si scrive che un canone è stato rinnovato, non il suo importo; si scrive che una linea è stata dismessa, non il suo numero.

## Cosa resta reale, e perché

I nomi delle organizzazioni, cioè del soggetto documentato e dei suoi fornitori: sono nomi di persona giuridica e non dati personali, e tipicamente il repository dichiara comunque nel proprio titolo di che cosa si occupa. Le caselle di posta funzionali non personali. Il nome e la casella dell'autore dei commit, che coincidono con i metadati visibili su ogni commit della storia, quindi anonimizzarli nella prosa non avrebbe alcun effetto protettivo. Gli indirizzi citati come minaccia nota, che sono dati pubblici sull'attaccante e non informazioni del soggetto documentato.

Resta reale, con un'eccezione da dichiarare esplicitamente nel testo ogni volta che si usa, il nome di un oggetto di configurazione letterale già presente su un apparato reale, per esempio una regola di firewall che contiene un nome proprio nel proprio nome tecnico. La ragione è operativa: un segnaposto renderebbe quell'oggetto introvabile a chi deve agire sull'interfaccia dell'apparato, e una procedura che non si può eseguire non protegge nessuno.

## Convenzione dei segnaposto

Gli indirizzi pubblici si sostituiscono con gli intervalli riservati alla documentazione da RFC 5737, cioè `203.0.113.0/24`, `198.51.100.0/24` e `192.0.2.0/24`, che non sono instradabili su Internet reale.

Gli indirizzi privati si spostano su un blocco privato *diverso* da quello reale, mantenendo invariati gli ottetti che portano significato, tipicamente quello che identifica il segmento e quello che identifica il ruolo dell'host, così la documentazione resta leggibile e coerente con se stessa. L'esempio che si scrive nella regola istanziata non deve mai essere la mappatura vera, altrimenti la regola pubblica proprio la corrispondenza che esiste per nascondere.

Gli indirizzi fisici diventano una serie progressiva su un prefisso convenuto. Le persone diventano `Persona-A`, `Persona-B` in ordine di prima apparizione nel documento corrente, oppure un'etichetta di ruolo quando il ruolo è più informativo del nome, per esempio `Referente-<Fornitore>-1` o `Collaboratore-Esterno-1`. I luoghi con nome proprio diventano `<Tipo>-N`.

## Dove vive la mappatura, ed è il file più sensibile del progetto

La traduzione da segnaposto a valore reale non si scrive mai in un file tracciato: vive nel layer privato del progetto, per default `_notes/.anonymization-map.md`, ignorato da git, e si estende riusando lo stesso segnaposto quando la stessa persona o lo stesso indirizzo ricompaiono altrove.

Va detto perché quel file merita più attenzione di ogni altro: è l'unico che rende reversibile ogni altra anonimizzazione. Nel progetto in cui questa regola è nata, il riscontro più grave di tutto il primo audit non era un indirizzo né un nome, ma una voce di registro che pubblicava la corrispondenza fra un segnaposto e la persona reale. Un singolo accoppiamento pubblicato vale più di cento valori nascosti.

## Controllo prima della pubblicazione

Prima di ogni commit documentale eseguire `python tools/Test-Anonymization.py` sull'intero insieme dei file tracciati e dei nuovi non ignorati, non sui soli file della sessione. I riscontri bloccanti impediscono la chiusura. Lo script non contiene valori reali: pattern e mappa restano nel livello privato ignorato, si aggiornano insieme e il controllo deve fermarsi se i pattern mancano. Con `--tutti` si esamina anche il materiale ignorato: contiene valori reali per decisione e i suoi riscontri non bloccano. Un file privato che viene tracciato rientra nel perimetro bloccante. Comandi, motivazioni e casi sono conservati in `.claude/norme/anonymization.md`.

## Quattro cose che lo strumento non può fare, e restano umane

Non distingue un falso positivo da una fuga quando il valore è ambiguo, per esempio un numero di versione che somiglia a un indirizzo: quei riscontri finiscono nelle categorie non bloccanti e vanno guardati uno per uno.

E non conosce il contesto: un nome dentro una ragione sociale legale è ammesso, lo stesso nome in una frase narrativa no, e la lista delle eccezioni di contesto va tenuta aggiornata a mano nel file dei pattern e tenuta *corta*, perché più è lunga meno il controllo dice.

Non vede la regola, vede i valori, e questa è la terza. Le due difese abituali, cioè proteggere il file della mappatura e cercare i valori reali nei file pubblicabili, guardano entrambe il valore e nessuna guarda la convenzione che lo sostituisce, che da sola rende reversibile ogni sostituzione senza che un valore sia mai uscito. Ne discendono tre cose. La convenzione con cui un progetto pseudonimizza non si spiega fuori da quel progetto, nemmeno per giustificare perché un dato è assente, e un rimando generico basta sempre allo scopo. Nei progetti che condividono la stessa macchina o lo stesso autore il controllo va esteso a cercare la forma della relazione, cioè la compresenza di una classe reale e della sua sostituta nella stessa riga. E la frase che spiega perché si sta togliendo qualcosa si scrive senza nominare né ciò che si toglie né dove viveva.

La quarta è che un verde misura i pattern, non il repository: un controllo a elenchi dichiara pulito un perimetro che contiene tutto ciò per cui nessuno ha scritto un pattern. L'audit di un perimetro pubblico si fa quindi periodicamente leggendo per categorie chiuse e non rilanciando il controllo, e ciò che l'audit trova si aggiunge ai pattern nello stesso giro e si prova rilanciando il controllo, che deve trovare i residui sfuggiti alla correzione a mano. Il confronto per sottostringa non accetta parole brevi, che combaciano dentro parole comuni: quelle restano un controllo a lettura, dichiarato come tale.

## Cosa fare quando si trova un valore reale già pubblicato

Non si riscrive la storia git da soli. La riscrittura di una storia condivisa è un'operazione pianificata, con backup e comunicazione preventiva se esistono altri collaboratori, mai un'azione improvvisata a valle di una singola sessione.

La sequenza corretta è segnalare il valore trovato, aggiungerlo alla mappa privata, correggerlo nel file tracciato corrente, e annotare la necessità di una pulizia della storia come lavoro a parte. Conviene tenere nel layer privato anche un file di sostituzioni pronto per quella pulizia, così che quando arriverà il momento non si debba ricostruire l'elenco: si accumula mano a mano, ed è l'unico modo per non pagare due volte lo stesso lavoro.

[^1]: *IP*, Internet Protocol - il numero che identifica un'interfaccia di rete; quelli privati sono validi solo dentro una rete locale, quelli pubblici sono raggiungibili da Internet.

[^2]: *Indirizzo fisico*, o MAC, Media Access Control - identificatore assegnato in fabbrica a un'interfaccia di rete, che identifica un apparato specifico in modo più stabile di un indirizzo IP.

## In questo progetto

Istanziata il 2026-10-27, quando un rapporto d'incidente con seriali di dispositivi, identità di volume e nomi di sessione andava portato nel repository, che è pubblico. Qui la mappa dei segnaposto non sta in `_notes/.anonymization-map.md` ma in `CLAUDE.local.md`, ignorato da git, che la teneva già prima dello strumento; il file dei pattern è `_notes/.anonymization-patterns.json` e nasce da quella mappa più i nomi propri del progetto di rete collegato. Oltre alle categorie del pacchetto, il file elenca come segreti letterali i seriali dei dispositivi, le identità dei volumi, i nomi delle cartelle sul NAS e gli identificativi dell'area di lavoro OpenAI, e come prefissi reali anche i blocchi che il progetto di rete usa come *segnaposto*: scritti qui insieme a una classe reale, ricostruirebbero la corrispondenza che quel progetto esiste per nascondere.

```
python tools/Test-Anonymization.py           # perimetro pubblicabile, bloccante: prima di ogni commit e di ogni push
python tools/Test-Anonymization.py --tutti   # include _notes/, non bloccante
```

Il controllo sostituisce la verifica a occhio richiesta dal paletto 7 di `CLAUDE.md`, non la affianca: un esito verde ottenuto con un file dei pattern incompleto è verde solo su ciò che il file conosce, quindi ogni valore reale nuovo che entra in `CLAUDE.local.md` entra nello stesso giro anche nei pattern.
