# Lezioni per il template

> Le lezioni nate in questo progetto che valgono oltre il progetto, cioè che passano le due domande della sezione 16 di `.claude/PROJECT-SYSTEM.md`: restano vere tolti i nomi propri, e non sono già nella testa di chi lavora bene. Una voce per lezione, creata con `python .claude/templates/tools/lezioni-template.py nuova` nel giro di lavoro in cui la lezione nasce. Lo stato non si scrive qui: una lezione è recepita quando il template la elenca in `.claude/templates/lezioni-recepite.json`, che arriva con l'allineamento.

Adottato il: 2026-10-26

## L-001 - 2026-10-26 - Una chiamata di sistema senza timeout proprio va messa dietro un tetto di tempo

Get-Volume, Get-Partition e Get-Disk non hanno un timeout: passano da un provider che per rispondere enumera tutti i dischi, quindi un solo dispositivo guasto le blocca per sempre, anche se con la domanda non c'entra niente. Uno script che le usa in una guardia non fallisce, si ferma: 42 minuti con zero CPU, zero I/O, nessun log e nessun codice di uscita, e l'unico modo di accorgersene e' guardare l'elenco dei processi. La chiamata si esegue in un runspace o in un processo separato con un tetto di tempo, e la scadenza si tratta come esito a se' stante: non lo so non e' assente e non e' pieno, e confonderli manda a cercare il guasto nel posto sbagliato. Vale per ogni operazione di inventario che dovrebbe essere istantanea: se si appende, il guasto sta in cio' che sta enumerando, non nel soggetto dell'indagine.

## L-002 - 2026-10-26 - Uno stub sul confine che si vuole provare rende i test ciechi proprio li'

Per isolare una chiamata lenta si introduce un punto di aggancio che i test sostituiscono. Se quel punto coincide con il confine tecnico da verificare, per esempio fra due runspace o fra due processi, gli stub restituiscono valori gia' pronti e il confine non viene mai percorso: i test restano verdi ed esattamente ciechi dove serviva vedere. Il punto di aggancio va messo a monte del confine, e almeno una verifica deve attraversarlo per davvero contro il sistema reale, anche solo in sola lettura.

## L-003 - 2026-10-26 - Una prova dal vivo fatta a sistema guasto non esercita il caso in cui funziona

Una correzione e' stata verificata contro il sistema reale mentre il guasto era ancora presente: il codice usciva per timeout e la prova e' passata. Il percorso in cui la chiamata riesce non era mai stato eseguito, e conteneva un difetto che ha bloccato la prima esecuzione vera. Una verifica fatta nella condizione anomala copre solo quel ramo. Prima di dichiarare chiuso un intervento si esercita anche il ramo normale, e se la condizione anomala non si riproduce a comando e' il ramo normale ad avere la precedenza.

## L-004 - 2026-10-26 - Un oggetto che attraversa un confine perde le proprieta' calcolate da un adattatore

Le parole Healthy, OK ed exFAT non stanno nell'oggetto restituito da Get-Volume: le produce l'adattatore di tipi del modulo Storage, che vive nel runspace in cui il modulo e' caricato. Spostando la chiamata in un runspace separato, l'oggetto torna a un chiamante che quel modulo non lo ha importato e restano i codici grezzi 0, 2 e 16, cosi' un confronto con le stringhe boccia un volume sano. Quando un valore attraversa un confine di runspace, di processo o di serializzazione, si proietta in un tipo semplice dalla parte in cui l'adattatore esiste, invece di passare l'oggetto vivo e sperare che le proprieta' calcolate sopravvivano.

## L-005 - 2026-10-26 - Un log tace anche su cio' che non si impegna a registrare

setupapi.dev.log registra installazioni e rimozioni di dispositivo, ma non lo scollegamento fisico di un dispositivo gia' installato, che e' una surprise removal gestita dal PnP e non lascia righe. Chi lo interroga per datare una rimozione trova silenzio e lo legge come assenza del fatto. Prima di concludere qualcosa da un'assenza in un log si stabilisce a che cosa quel log si impegna: un log e' una promessa su cosa registra, e la promessa va letta prima dei dati.

## L-006 - 2026-10-26 - Un identificativo che sembra unico puo' essere un segnaposto di fabbrica

Il numero di serie di una chiavetta puo' non identificare nulla: molti controller flash anonimi espongono di fabbrica un segnaposto, una sequenza ordinata di caratteri uguale su tutti gli esemplari, e il sistema operativo non distingue quel supporto da qualunque altro dello stesso lotto. Ogni regola che lega configurazione a identita' di dispositivo, cioe' riservazioni di lettera, liste di consenso, criteri e licenze, appoggiata a un identificativo del genere non e' sbagliata: e' mal definita, perche' un altro dispositivo eredita il posto. L'unicita' si verifica prima di costruirci sopra, non dopo il primo comportamento strano.

## L-007 - 2026-10-26 - Chi e' escluso da una risorsa non sa niente, chi la tiene sa tutto

Per mezza giornata l'indagine ha chiesto perche' un programma non ottenesse la lettera che chiedeva, e la risposta stava in chi la teneva e non la rilasciava. Davanti a una contesa la domanda produttiva non e' perche' il richiedente fallisce, ma chi detiene la risorsa e perche' non la molla. Vale per lettere di unita', porte, lock, mutex e nomi di file: il richiedente vede solo il proprio fallimento, il detentore ha tutto il contesto.

## L-008 - 2026-10-26 - Due cause che competono per lo stesso effetto si ordinano con un testimone, non con un argomento

Due sessioni hanno agito sullo stesso guasto nello stesso minuto, un distacco fisico di un dispositivo e una modifica al registro, ed entrambe si attribuivano lo sblocco. A ordinarle non e' stato un ragionamento di plausibilita' ma un terzo evento indipendente datato al millisecondo, che cadeva fra le due e ne escludeva una. Quando due interventi ravvicinati rivendicano lo stesso effetto si cerca un evento che non sia nessuno dei due e lo si data alla risoluzione piu' fine disponibile.

## L-009 - 2026-10-26 - Un dato ambiguo letto dentro l'ipotesi corrente e' l'errore piu' frequente di un'indagine

Su nove errori dichiarati da due sessioni indipendenti, la maggioranza ha la stessa forma: un dato ambiguo interpretato dentro l'ipotesi gia' in testa, invece che confrontato con le altre ipotesi che lo spiegherebbero altrettanto bene. Un volume a zero byte letto come mount fantasma del programma sotto indagine era il supporto guasto; un errore attribuito a un dispositivo per il suo numero di disco era di un altro, perche' quel numero si riusa quando un supporto viene staccato. Non si corregge con piu' prudenza: davanti a ogni dato ambiguo si chiede che cos'altro produrrebbe esattamente questa osservazione.

## L-010 - 2026-10-26 - Il blocco non lo produce il dispositivo guasto, lo producono i componenti che gli si buttano addosso

Un supporto di archiviazione che non risponde non congela da solo il sistema operativo. Nell'istante in cui compare una lettera di unita', quattro componenti gli vanno addosso senza che nessuno clicchi niente: AutoPlay che apre il volume per decidere cosa proporre, la shell che genera le anteprime, l'indicizzatore e l'antivirus. Su un supporto sano finiscono in millisecondi; su uno che non risponde restano tutti in attesa, e poiche' sono componenti di sistema si portano via la sessione interattiva. Togliendoli di mezzo, lo stesso supporto che mezz'ora prima aveva congelato la macchina si e' montato in 6 secondi e ha consegnato tutti i suoi file. Davanti a un dispositivo che fa cadere il sistema, la domanda non e' solo cosa ha il dispositivo ma chi lo sta interrogando a nostra insaputa.

## L-011 - 2026-10-26 - Su un supporto che cede, zero tentativi di ripetizione e' la differenza fra saltare e appendersi

Gli strumenti di copia ripetono per default le letture fallite, con attese fra un tentativo e l'altro: e' giusto su un supporto sano, dove un errore e' transitorio. Su un supporto che sta cedendo e' la rovina, perche' ogni settore illeggibile costa minuti di attesa invece di essere saltato, e il recupero non arriva mai in fondo nella finestra in cui il dispositivo regge ancora. Si copia con zero tentativi e zero attesa, in robocopy /R:0 /W:0, e senza letture parallele, perche' su un controller in difficolta' peggiorano le cose. Si prende tutto cio' che il supporto riesce a dare e si lascia che il log elenchi il resto.

## L-012 - 2026-10-26 - Una premessa riferita a voce e mai verificata puo' reggere un'indagine intera

Un'indagine di tre giorni, condotta da due agenti che si correggevano a vicenda, e' stata costruita sopra una frase dell'utente mai messa in discussione, cioe' che un certo materiale stesse su un certo supporto. Era sbagliata, e il sistema operativo aveva registrato il dato giusto fin dall'inizio: l'etichetta di ogni supporto mai montato sta in HKLM\SOFTWARE\Microsoft\Windows Portable Devices\Devices, leggibile in sola lettura anche a dispositivo scollegato. La verifica costava una query. Una premessa ricevuta e non verificata non diventa piu' solida perche' tutto il resto le si e' appoggiato sopra: le premesse di partenza si verificano per prime, soprattutto quando esiste una fonte autoritativa a costo quasi nullo.

## L-013 - 2026-10-26 - Il messaggio che spiega una bonifica e' il punto in cui la bonifica si annulla

Dopo aver tolto da un repository pubblico dei dati che non dovevano starci, il commit si chiamava 'Anonimizza quanto restava di aziendale' e il corpo elencava per categoria tutto cio' che era stato rimosso. Il dato era sparito dai file, ma il messaggio era un cartello che indicava i commit precedenti e diceva dove guardare e che cosa cercare: in un caso il messaggio conteneva ancora in chiaro proprio l'etichetta appena tolta dai file. Un messaggio di commit e' contenuto pubblico quanto il codice. Si descrive che cosa fa la modifica, non che cosa si stava nascondendo: 'aggiunge lo strumento e allinea la documentazione' dice il vero senza indicare dove scavare.

## L-014 - 2026-10-26 - Una ricerca nel contenuto non e' una ricerca nei messaggi

La verifica che una stringa fosse sparita dalla storia e' stata fatta con git log --all -S, che cerca nelle differenze dei FILE e non nei messaggi di commit. Diciassette stringhe hanno dato zero occorrenze e la bonifica e' stata dichiarata riuscita, mentre una di quelle stringhe stava ancora in chiaro nel messaggio di un commit. Una verifica copre solo la superficie che interroga: per i messaggi serve git log --all --format=%B passato al filtro, per i nomi dei file git log --all --name-only, per i tag git tag -l -n99. Dichiarare pulito un repository sulla base di una sola di queste tre e' un errore di metodo, non una svista.

## L-015 - 2026-10-26 - La visibilita' di un repository si verifica prima di scriverci, non dopo

Un percorso aziendale completo e' finito come valore predefinito di un parametro in uno script, ed e' stato pubblicato su un repository pubblico. L'errore non e' stato scrivere il percorso, che in locale sarebbe stato comodo e innocuo: e' stato non aver mai chiesto dove sarebbe finito. Un comando, gh repo view --json visibility, risponde in un secondo, e la convenzione del progetto su cosa non deve entrare nei file tracciati sta scritta nelle sue regole. Entrambi i controlli costano dieci secondi e vanno fatti prima della prima riga, non dopo il push: dopo il push nessuna correzione e' piu' completa, perche' la storia resta e cio' che e' stato pubblico non torna privato.

## L-016 - 2026-10-27 - Una protezione che fallisce in assenza di un valore la disarma chiunque riempia quel posto

Una norma di progetto imponeva di dichiarare l'identita' di git in ogni repository e si appoggiava a user.useConfigOnly, l'impostazione che vieta a git di inventare l'identita' da sola. La norma descriveva l'effetto cosi': senza identita' locale il commit viene rifiutato. Non e' vero, e sulla macchina in questione non lo era: useConfigOnly impedisce a git di DEDURRE un'identita' da utente e nome host, non di leggerne una configurata, quindi un blocco [user] rimasto nel file globale la soddisfa e il commit passa, firmato con quell'identita'. Verificato in una sandbox: con il blocco globale presente il commit riesce con l'indirizzo di lavoro, con il blocco svuotato git risponde "Author identity unknown" e rifiuta.

La forma generale e' che una protezione il cui meccanismo e' fallire in assenza di un valore viene disarmata da chiunque riempia quel posto altrove, spesso per una ragione legittima e in un file diverso da quello dove la protezione e' scritta. Il disarmo e' silenzioso e va nella direzione comoda, perche' i commit continuano a funzionare: nessun sintomo lo annuncia. Una protezione del genere non si dichiara attiva perche' l'impostazione e' presente, si prova nella condizione che dovrebbe bloccare, e la prova va rifatta sulla macchina, perche' cio' che la disarma e' configurazione locale e non codice.

## L-017 - 2026-10-27 - Si riscrive una storia per un dato pubblicato dove non doveva stare, non per uniformare un'attribuzione

Due progetti della stessa macchina erano arrivati a due regole opposte sulla riscrittura della storia. Uno aveva riscritto undici repository aziendali per togliere dai commit l'indirizzo personale di chi li aveva firmati; l'altro stava per riscriverne quaranta personali per uniformare lo stesso indirizzo, e si e' fermato davanti al costo, cioe' una richiesta di assistenza per repository e nessuna presa sui fork e sui cloni gia' esistenti. Il criterio che li concilia non e' la distinzione fra segreto e attribuzione, che li lascerebbe in contraddizione, ma il luogo: si riscrive quando un dato e' finito dove il suo proprietario non ha scelto di pubblicarlo, e un indirizzo personale dentro i repository di un'organizzazione e' esattamente quel caso. Non si riscrive per rendere uniforme a posteriori un'attribuzione legittima la' dove sta.

La lezione sotto la lezione e' che un criterio implicito produce una risposta diversa a ogni sessione e a ogni progetto, e la divergenza si scopre solo quando qualcuno confronta i due. Finche' la regola resta nella testa di chi decide, la coerenza e' un caso fortunato: una decisione che si ripresentera' su altri repository si scrive dove la rileggera' chi non era presente, e si scrive includendo il caso in cui la risposta e' no.
