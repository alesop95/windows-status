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

Il numero di serie SERIALE-RIMOSSO di una chiavetta non identifica nulla: e' il valore predefinito di molti controller flash anonimi, e il sistema operativo non distingue quel supporto da qualunque altro dello stesso lotto. Ogni regola che lega configurazione a identita' di dispositivo, cioe' riservazioni di lettera, liste di consenso, criteri e licenze, appoggiata a un identificativo del genere non e' sbagliata: e' mal definita, perche' un altro dispositivo eredita il posto. L'unicita' si verifica prima di costruirci sopra, non dopo il primo comportamento strano.

## L-007 - 2026-10-26 - Chi e' escluso da una risorsa non sa niente, chi la tiene sa tutto

Per mezza giornata l'indagine ha chiesto perche' un programma non ottenesse la lettera che chiedeva, e la risposta stava in chi la teneva e non la rilasciava. Davanti a una contesa la domanda produttiva non e' perche' il richiedente fallisce, ma chi detiene la risorsa e perche' non la molla. Vale per lettere di unita', porte, lock, mutex e nomi di file: il richiedente vede solo il proprio fallimento, il detentore ha tutto il contesto.

## L-008 - 2026-10-26 - Due cause che competono per lo stesso effetto si ordinano con un testimone, non con un argomento

Due sessioni hanno agito sullo stesso guasto nello stesso minuto, un distacco fisico di un dispositivo e una modifica al registro, ed entrambe si attribuivano lo sblocco. A ordinarle non e' stato un ragionamento di plausibilita' ma un terzo evento indipendente datato al millisecondo, che cadeva fra le due e ne escludeva una. Quando due interventi ravvicinati rivendicano lo stesso effetto si cerca un evento che non sia nessuno dei due e lo si data alla risoluzione piu' fine disponibile.

## L-009 - 2026-10-26 - Un dato ambiguo letto dentro l'ipotesi corrente e' l'errore piu' frequente di un'indagine

Su nove errori dichiarati da due sessioni indipendenti, la maggioranza ha la stessa forma: un dato ambiguo interpretato dentro l'ipotesi gia' in testa, invece che confrontato con le altre ipotesi che lo spiegherebbero altrettanto bene. Un volume a zero byte letto come mount fantasma del programma sotto indagine era il supporto guasto; un errore attribuito a un dispositivo per il suo numero di disco era di un altro, perche' quel numero si riusa quando un supporto viene staccato. Non si corregge con piu' prudenza: davanti a ogni dato ambiguo si chiede che cos'altro produrrebbe esattamente questa osservazione.
