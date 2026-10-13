# 13 - Memoria vincolata che cresce: una perdita di handle di sezione

Questo documento chiude l'indagine aperta nella sezione 2d di `07_SALUTE_E_STABILITA.md`: su questa macchina la memoria vincolata cresce di circa sette gigabyte al giorno senza che nessun processo la dichiari, finché dopo tre o quattro settimane senza riavvio il sistema arriva al limite e si blocca. Il detentore è stato identificato dalla serie di campioni e poi misurato direttamente: è `ArmourySocketServer.exe`, un componente del software ASUS per la scheda madre, che apre di continuo sezioni di memoria da circa 256 KB e non le chiude mai. Il documento spiega il meccanismo, il metodo con cui lo si è trovato, lo strumento che lo rifà da sé, `scripts\Diagnostica-Vincolata.ps1`, l'esperimento che lo conferma e le opzioni di rimedio, la cui scelta resta al proprietario.

> Stato al 2026-10-13: causa accertata. Detentore identificato per correlazione su tre avvii, confermato dalla misura diretta delle sezioni che tiene aperte e poi dall'esperimento di rilascio: terminato il processo, la vincolata è scesa di 5,7 GB, il 98% di quanto le sezioni valevano. Rimedio, passo 1, applicato il 13/10 alle 13:34: attività pianificata disattivata e processo terminato (paragrafo 8). Il passo 2, sul firewall, attende la verifica del proprietario.

---

## 1. Perché la vincolata può non appartenere a nessun processo

La memoria vincolata[^1] è la somma degli impegni che il sistema ha preso a garantire spazio, in RAM o nel file di paging, per memoria che qualcuno ha chiesto. Il gestore delle attività la mostra come «Vincolata», nella forma usato su limite: 56/244 GB nella schermata del 13/10, con il limite pari alla RAM più il file di paging. Quando l'impegno totale raggiunge il limite, ogni nuova allocazione fallisce, le applicazioni terminano per memoria insufficiente e il sistema registra l'evento 2004 del Resource-Exhaustion-Detector; se a fallire è un componente di sistema, la macchina si blocca.

La maggior parte della vincolata ha un proprietario visibile: la memoria privata dei processi, che il gestore delle attività mostra per processo, e i due pool del kernel. C'è però una categoria che non compare in nessuno dei due: le sezioni appoggiate al file di paging. Una sezione è l'oggetto del kernel dietro la memoria condivisa; un programma la crea, per esempio con `CreateFileMapping` senza un file sottostante, e il sistema carica sulla vincolata l'intera dimensione della sezione al momento della creazione. Quell'impegno non è memoria privata di nessun processo: compare nel processo solo se e finché la sezione è mappata in una sua vista. Se il programma crea la sezione, la usa, ne smappa la vista e non chiude l'handle, l'oggetto resta vivo, l'impegno resta sulla vincolata, e nessun contatore di processo lo mostra più. L'unica traccia è l'handle aperto.

Questo spiega i tre tratti che la sezione 2d aveva misurato senza poterli attribuire. La quota mancante non è nei processi, perché è commit di sezioni non mappate. Non è nei pool, perché le sezioni appoggiate al file di paging non stanno nel pool. Ed è prenotata ma non residente, perché una sezione impegna la vincolata alla creazione ma occupa RAM solo nelle pagine che qualcuno ha davvero scritto: la RAM in uso resta fra 38 e 82 GB su 128 mentre la vincolata tocca il limite.

## 2. La serie misurata

La serie è quella raccolta da `scripts\Campiona-Vincolata.ps1`, installato il 05/10 come attività pianificata che gira come SYSTEM ogni 15 minuti, nei file `snapshots\vincolata\totali.csv` e `processi.csv`, ignorati da git. Ogni campione registra la vincolata, il limite, il privato dei processi, i due pool e la quota non attribuita, cioè vincolata meno privato meno pool; e per i 25 processi con più memoria mappata e i 25 con più handle registra handle, privato e mappato. Al 13/10 la serie conta 771 campioni su tre avvii.

| Avvio | Campioni | Ore | Non attribuita all'inizio | Alla fine | Ritmo |
|---|---|---|---|---|---|
| 05/10 11:06 | 100 | 24,6 | 5,2 GB | 12,9 GB | 7,0 GB al giorno |
| 06/10 11:58 | 595 | 148,5 | 4,7 GB | 51,6 GB | 7,4 GB al giorno |
| 12/10 16:43 | 76 | 18,8 | 5,1 GB | 11,6 GB | 7,2 GB al giorno |

Il ritmo è stato calcolato per regressione lineare della quota non attribuita sul tempo di attività, avvio per avvio, ed è lo stesso nei tre avvii entro il sei per cento: sette gigabyte al giorno, cioè circa 300 MB l'ora, anche di notte e a macchina inattiva, come la sezione 2d aveva già osservato. Nello stesso intervallo i due pool, dopo le prime ore, restano fra 4 e 6,5 GB ciascuno senza tendenza, e la memoria mappata visibile nei processi resta fra 45 e 55 GB. Crescono invece gli handle totali del sistema, di circa 25.000 ogni dodici ore, ed è da qui che parte l'identificazione.

## 3. Identificare il detentore: correlazione e stabilità della pendenza

Per ogni avvio e per ogni processo presente in almeno l'80% dei suoi campioni, con una crescita di almeno 1.000 handle, si calcolano due numeri: la correlazione di Pearson fra il numero di handle del processo e la quota non attribuita, e la pendenza della quota rispetto agli handle, espressa in KB per handle. Misura del 13/10 sui due CSV, con `Diagnostica-Vincolata.ps1`; il primo e il secondo processo per correlazione in ciascun avvio:

| Avvio | Processo | r | KB per handle | Crescita degli handle |
|---|---|---|---|---|
| 05/10 | `ArmourySocketServer` | 0,9980 | 259 | +28.585 |
| 05/10 | `Telegram` | 0,7491 | 1.431 | +4.414 |
| 06/10 | `ArmourySocketServer` | 0,9999 | 274 | +173.740 |
| 06/10 | `Veeam.EndPoint.Service` | 0,9340 | 27.327 | +1.536 |
| 12/10 | `ArmourySocketServer` | 0,9992 | 260 | +20.963 |
| 12/10 | `explorer` | 0,5063 | 2.882 | +1.729 |

La correlazione da sola non basterebbe, e vale dirlo perché è l'errore più facile da commettere con questo metodo: qualunque grandezza che cresce col tempo correla con una quota che cresce col tempo, e infatti nel lungo avvio del 06/10 anche il servizio di backup e Telegram superano 0,9. Due proprietà distinguono il detentore dalle coincidenze. La prima è la costanza: `ArmourySocketServer` supera 0,998 in tutti e tre gli avvii, gli altri cambiano da un avvio all'altro. La seconda, più forte, è la pendenza. Se un processo trattiene vincolata attraverso i suoi handle, ogni handle costa la dimensione dell'oggetto che tiene vivo, e quel costo non dipende dal giorno: la pendenza di `ArmourySocketServer` sta fra 259 e 274 KB per handle in tre avvii diversi, mentre quelle degli altri vanno da 1.400 a 27.000 KB e non si ripetono. Una pendenza stabile vicina a 256 KB descrive un oggetto di dimensione fissa, cioè esattamente ciò che una sezione è.

Un terzo controllo è stato fatto e scartato, e lo si riporta perché sembra la mossa ovvia. Togliendo a entrambe le serie la tendenza lineare nel tempo e correlando i residui, `ArmourySocketServer` dà valori negativi, fra -0,55 e -0,75. Non è una smentita: i suoi handle crescono in modo così regolare che, tolta la retta, resta solo rumore, mentre le oscillazioni della quota non attribuita attorno alla sua retta le producono gli altri programmi. Il controllo sui residui misura chi fa oscillare la vincolata, non chi la fa crescere.

## 4. La conferma: le sezioni misurate una per una

La correlazione indica il sospetto; la conferma viene da una misura che non dipende dalla serie. Con i diritti di amministratore lo strumento legge la tabella degli handle del sistema con `NtQuerySystemInformation`, ne ricava il tipo di oggetto di ciascuno con i nomi forniti da `NtQueryObject`, duplica in sé ogni handle di tipo Section del processo con il solo diritto di interrogazione, ne legge dimensione e attributi con `NtQuerySection` e chiude subito la copia. Somma poi le dimensioni delle sezioni non appoggiate a un file, che sono quelle caricate sulla vincolata. Duplicare un handle per interrogarlo non modifica l'oggetto né il processo che lo possiede.

Misura del 13/10 alle 11:42, a 19 ore dall'avvio, sul processo in esecuzione dal 12/10 alle 16:33:

```
ArmourySocketServer: 22.854 handle in tutto
  Section            22.611
  EtwRegistration        92
  Event                  52
  Key                    19
  Thread                 12
  File                   10
Sezioni lette: 22.609, tutte non appoggiate a file, 5,6 GB in tutto, in media 261 KB l'una
Oggetti distinti: 22.610 (nessun doppio conteggio)
Quota non attribuita: 11,7 GB, di cui 5,1 GB già presenti al primo campione dell'avvio
Crescita dall'avvio: 6,6 GB; sezioni / crescita: 86%
```

Il 99% degli handle del processo è di sezione, la dimensione media coincide con la pendenza della serie, e le sezioni misurate spiegano l'86% della crescita della quota dall'avvio. Il resto è compatibile con le sezioni create fra l'accensione e il primo campione, e con la crescita propria di altri programmi, come Telegram, il cui privato e i cui handle crescono anch'essi ma senza la regolarità del detentore. I numeri sono di un'unica misura; la conferma causale è l'esperimento del paragrafo 7, che li ha ritrovati.

Il processo è `C:\Program Files (x86)\ASUS\ArmouryDevice\dll\ArmourySocketServer\ArmourySocketServer.exe`, versione del file 0.1.20.13, avviato dall'attività pianificata `\ASUS\ArmourySocketServer` con innesco all'accesso dell'utente, privilegi elevati e nessun riavvio automatico in caso di arresto. Sulla macchina sono installati i componenti AURA e i driver di astrazione per illuminazione e ventole della scheda madre ASUS, ma non l'applicazione Armoury Crate dello Store: chi usi il servizio di socket che questo processo offre è da verificare.

### Che cosa fa il processo mentre perde memoria

Osservazione del 13/10 sul processo appena riavviato. `ArmourySocketServer` resta in ascolto sulle porte TCP 9012 e 9013 di tutte le interfacce, e ogni tre secondi circa tenta una connessione a `127.0.0.1:1042`, dove non ascolta nessun processo: in 45 secondi i tentativi distinti, riconosciuti dalla porta locale sempre nuova, sono stati 15 e gli handle sono cresciuti di 14. Al ritmo di un tentativo ogni tre secondi si ottengono circa 1.200 tentativi l'ora, cioè il ritmo di crescita degli handle misurato nella serie. Ne inferisco, senza averlo verificato nel codice, che ogni tentativo fallito crei una sezione e non la chiuda: la perdita sarebbe un ciclo di riconnessione verso un interlocutore assente. Nessun processo è connesso alle due porte in ascolto.

L'interlocutore mancante è plausibilmente l'applicazione Armoury Crate, che sulla macchina non c'è più: manca anche la cartella del suo servizio, mentre i componenti di `ArmouryDevice`, con eseguibile datato 13/08/2024, sono rimasti con le loro attività pianificate. L'illuminazione è gestita da un servizio distinto, `LightingService`, che non dipende da questo processo.

Il processo ha anche un'esposizione di rete. Due regole del firewall in ingresso, `ArmourySocketServer` e `ArmouryHtmlDebugServer`, consentono qualunque protocollo, porta e indirizzo remoto ai due eseguibili della cartella, su tutti i profili: le porte 9012 e 9013 sono quindi raggiungibili dalla rete locale, da un componente che nessuno usa.

## 5. La proiezione, e un riavvio che non c'entra

Al 13/10 la vincolata è 58,8 GB su 244 e cresce di 7,2 GB al giorno: senza riavvio il limite si raggiunge in circa 26 giorni, intorno all'8 novembre. La stima è lineare e ottimistica, perché il lavoro quotidiano aggiunge vincolata propria sopra la perdita: gli eventi 2004 del 02/10 e del 05/10 sono arrivati con la quota non attribuita fra 165 e 183 GB e il privato dei processi fra 50 e 66 GB.

Degli ultimi due arresti non puliti, Kernel-Power 41 con codice di bugcheck zero, solo uno è riconducibile a questa perdita. Quello del 05/10 alle 10:29 è arrivato sette minuti dopo l'ultimo evento 2004, con la vincolata al limite. Quello del 06/10 alle 11:52 no: alle 10:58 dello stesso giorno la vincolata era a 67 GB su 244. La sua causa è un'altra e resta da capire, oppure si tratta di uno spegnimento forzato a mano; in ogni caso non va attribuito a questo difetto.

Ricostruzione del 13/10, in sola lettura su tutti i registri eventi della macchina e sulla serie del campionatore. L'ora delle 11:52 è quella della riaccensione, non del blocco: l'ultimo evento registrato, in un registro qualunque, è delle 11:46:14, e l'avvio comincia alle 11:52:11, quindi la macchina è rimasta ferma o bloccata circa sei minuti. L'evento 6008 scritto all'avvio dà come ora dell'arresto le 11:09:14, ma non è attendibile: è il valore che il sistema aggiorna periodicamente quando è vivo, e la macchina era viva dopo, perché il campionatore ha scritto campioni regolari fino alle 11:43:56 e altri registri hanno scritto fino alle 11:46. Si escludono tre cause. La memoria, perché alle 11:43 la vincolata era 64,7 GB su 244. Un aggiornamento in corso, perché il cumulativo e quello di .NET erano stati installati il 05/10 alle 14:39 in attesa di riavvio, e dopo la riaccensione sono stati completati con due riavvii pianificati, che sono gli eventi 1074 delle 11:53 e delle 11:54 e non hanno a che fare con il blocco. Un guasto di archiviazione visibile, perché nella finestra non ci sono errori del disco o del file system, solo i riepiloghi periodici di Storport. Il Kernel-Power 41 non porta informazione: codice di bugcheck zero con parametri nulli, nessuna pressione del pulsante rilevata, nessun dump né rapporto del kernel. Questa firma è quella di un'interruzione di alimentazione o di un reset forzato dopo un blocco, e i registri non permettono di distinguere le due cose. Gli ultimi eventi sono ordinari: un accesso di servizio di SYSTEM e l'avvio del servizio Criteri di gruppo alle 11:45:08, e una serie di enumerazioni WMI dei dischi fisici alle 11:46. Il giorno prima Windows Update aveva installato un driver USB di terze parti, e lo annoto senza indizi che lo colleghino. Restano due vie: chiedere al proprietario se quel giorno ha trovato la macchina bloccata e l'ha spenta a mano, oppure se è mancata la corrente, e preparare la cattura del caso successivo. Un dump su richiesta da tastiera (`CrashOnCtrlScroll`) servirebbe per un blocco, ma è una modifica del registro che entra in vigore solo al riavvio successivo, e quindi va proposta e lasciata al proprietario.

## 6. Lo strumento: `scripts\Diagnostica-Vincolata.ps1`

Lo strumento rifà da sé l'intera analisi dei paragrafi 2-5 a partire dalla serie, e la ripete su qualunque macchina abbia il campionamento attivo. Senza parametri legge soltanto e scrive il report in `snapshots\vincolata\diagnosi_<data>.txt`.

```powershell
.\scripts\Diagnostica-Vincolata.ps1                    # diagnosi; da amministratore include la conferma sulle sezioni
.\scripts\Diagnostica-Vincolata.ps1 -Processo <nome>   # esamina un processo scelto a mano
.\scripts\Diagnostica-Vincolata.ps1 -VerificaRilascio  # esperimento di rilascio, a conferma (admin)
```

Il report ha sei sezioni: lo stato attuale con la stessa formula del campionatore; la serie per avvio, con il ritmo di ciascuno; il detentore, con i tre processi più correlati di ogni avvio e il sospetto, che deve superare la soglia di correlazione in ogni avvio valido e fra quelli che ci riescono è il più stabile nella pendenza; la conferma sulle sezioni, con la distribuzione degli handle per tipo, la somma delle sezioni non appoggiate a file, il rapporto con la crescita dall'avvio, l'eseguibile, la versione e l'attività pianificata che lo avvia; gli eventi 2004 con la loro ripartizione e i Kernel-Power 41; la proiezione e il verdetto.

| Parametro | Default | Funzione |
|---|---|---|
| `-Cartella` | `snapshots\vincolata` | dove stanno `totali.csv` e `processi.csv` |
| `-SogliaR` | 0,98 | correlazione minima in ogni avvio valido |
| `-MinCampioni` | 24 | campioni minimi perché un avvio conti, circa sei ore |
| `-RitmoMinimo` | 1 | GB al giorno sotto i quali la crescita non è significativa |
| `-UltimeOre` | 6 | finestra del ritmo recente, calcolato sugli ultimi campioni dell'avvio corrente; quando ha almeno otto campioni guida proiezione e verdetto, così l'effetto di un rimedio si vede senza riavviare; se nella finestra c'è un calo di almeno 1 GB fra due campioni lo strumento lo segnala e non trae conclusioni |
| `-Dal` | nessuno | misura il ritmo solo sui campioni successivi a un istante, nella forma `2026-10-13T13:35`, tipicamente l'ora di un rimedio |
| `-Giorni` | 60 | finestra degli eventi |
| `-Attesa` | 30 | secondi fra l'arresto del processo e la seconda misura |

| Codice di uscita | Significato |
|---|---|
| 0 | nessuna crescita significativa |
| 1 | crescita senza detentore identificato: probabile driver, servono poolmon o una traccia WPR del profilo di allocazione |
| 2 | detentore identificato |
| 3 | dati insufficienti: nessun avvio con abbastanza campioni |

Lo strumento è stato collaudato sulla serie reale, dove indica `ArmourySocketServer` con gli stessi numeri ottenuti indipendentemente durante l'analisi, e su due copie alterate della serie: una troncata a dieci campioni, su cui risponde «dati insufficienti» con codice 3 senza nominare un sospetto, e una con la quota non attribuita resa costante, su cui risponde che non c'è crescita, con codice 0, e che nessun processo supera la soglia.

## 7. L'esperimento di rilascio

La prova che chiude l'indagine è causale e non statistica: si termina il processo e si misura quanta vincolata si libera. Se le sezioni sono sue, la loro chiusura è automatica alla terminazione e la quota non attribuita deve scendere di circa quanto misurato al paragrafo 4. `-VerificaRilascio` lo fa, ed è l'unica parte dello strumento che modifica il sistema: mostra il processo, gli handle e il rilascio atteso, chiede di digitare `SI`, misura, termina il processo, attende trenta secondi, rimisura, dice se il processo si è riavviato da solo, scrive l'esito in `snapshots\vincolata\verifiche_rilascio.csv` e stampa la riga per il changelog della mappa.

Esperimento eseguito il 13/10 alle 12:05, a 19,5 ore dall'avvio, con il consenso del proprietario. Prima della terminazione lo strumento ha misurato 23.039 sezioni non appoggiate a file per 5,7 GB. Trenta secondi dopo la terminazione la quota non attribuita era scesa da 11,8 a 6,1 GB, cioè 5,6 GB, e la vincolata da 58,6 a 52,9 GB, cioè 5,7 GB: il rilascio misurato è il 98% delle sezioni misurate, e la quota è tornata al valore che ha subito dopo l'accensione. Il processo non si è riavviato da solo ed è stato riavviato subito dopo con la sua attività pianificata, così da ripristinare lo stato di partenza; ottanta minuti dopo aveva già 1.816 handle contro i 264 iniziali, circa 1.170 l'ora, lo stesso ritmo della serie. La perdita riparte quindi a ogni avvio del processo, e non dipende da qualcosa che il processo abbia accumulato nei giorni precedenti.

Terminare il processo è reversibile e non tocca file di sistema. L'attività che lo avvia non prevede riavvii automatici: dopo l'esperimento il processo riparte al successivo accesso, oppure subito con `Start-ScheduledTask -TaskPath '\ASUS\' -TaskName 'ArmourySocketServer'`. Nel frattempo le funzioni che dipendono da lui, presumibilmente il controllo dell'illuminazione e dei dispositivi ASUS da software, possono non rispondere; la loro natura esatta è da verificare proprio con questo esperimento.

## 8. Rimedi possibili

La scelta spetta al proprietario dopo l'esperimento, e vale il paletto 3: una categoria di modifiche alla volta, con verifica prima della successiva. Le opzioni, dalla meno alla più invasiva:

| Rimedio | Effetto | Rischio | Come si annulla |
|---|---|---|---|
| riavviare il solo processo almeno ogni due settimane (su questa macchina il riavvio del PC è escluso dal proprietario) | azzera la perdita a ogni riavvio del processo | nessuno; è un tampone che va ricordato | non serve |
| attività pianificata settimanale che termina e riavvia il processo | tampone automatico | interruzione momentanea dei servizi ASUS | rimuovere l'attività |
| aggiornare i componenti ASUS e rimisurare con il campionatore | elimina la causa, se la versione nuova la corregge | aggiornamento di software con privilegi elevati | reinstallare la versione precedente |
| disattivare l'attività `\ASUS\ArmourySocketServer` | il processo non parte più | perdita delle funzioni che lo usano, da verificare | `Enable-ScheduledTask` |
| disinstallare il software ASUS con lo strumento di rimozione del produttore | toglie processo e attività | perdita del controllo software di illuminazione e ventole; le curve delle ventole del BIOS restano | reinstallazione dal sito del produttore |

Scelta del 13/10, dopo i rilievi della sezione 4 sul ciclo di riconnessione e sull'esposizione di rete: la quarta riga, in due passi di categoria diversa. Passo 1, stabilità: disattivata l'attività `\ASUS\ArmourySocketServer` e terminato il processo, senza punto di ripristino per scelta del proprietario; da subito le porte 9012 e 9013 non sono più in ascolto, la vincolata è scesa di 0,4 GB, cioè quanto il processo aveva accumulato dal riavvio di mezzogiorno, e `LightingService` e `AcPowerNotification` hanno continuato a girare. Passo 2, firewall, applicato il 13/10 alle 14:45 dopo che i primi quattro campioni successivi al passo 1 avevano dato una quota piatta: disattivate con `Disable-NetFirewallRule` le due regole in ingresso `ArmourySocketServer` e `ArmouryHtmlDebugServer`, che restano definite e si riattivano con `Enable-NetFirewallRule` sugli stessi nomi; serve nel caso in cui un aggiornamento ASUS riattivi l'attività, perché il processo tornerebbe a girare ma non sarebbe più raggiungibile dalla rete. Dopo il passo, nessun processo in ascolto su 9012 e 9013 e `LightingService` in esecuzione. La verifica si fa a macchina accesa, perché il proprietario non può riavviare il PC. L'esperimento del paragrafo 7 informa anche la scelta fra la quarta e le altre: se con il processo fermo nulla di ciò che il proprietario usa smette di funzionare, disattivare l'attività è un rimedio a costo nullo e reversibile con un comando.

## 9. Che cosa resta da verificare

L'esperimento di rilascio è stato eseguito e ha confermato la causa (paragrafo 7), e il passo 1 del rimedio è applicato (paragrafo 8). Va verificato sulla serie del campionatore, a macchina accesa, che la quota non attribuita smetta di crescere da quel momento: un ritmo prossimo a zero nelle ore successive basta, senza aspettare un nuovo avvio. Prima lettura, alle 14:41: i quattro campioni dalle 13:43 alle 14:28 danno 6,05, 6,12, 6,14 e 6,08 GB, contro una crescita di circa 0,07 GB ogni quarto d'ora prima dell'arresto, e gli handle totali sono scesi di circa 8.000 e da lì non crescono; lo strumento chiede otto campioni prima di misurare un ritmo, quindi la misura formale è dalle 15:30 in poi con `-Dal 2026-10-13T13:35`. Con il processo fermo lo strumento ora lo dichiara nel verdetto, invece di proporre l'esperimento di rilascio su un processo che non c'è. Misura delle 15:33, sugli 8 campioni dalle 13:43 alle 15:28 di `snapshots/vincolata/totali.csv`: la quota non attribuita va da 6,05 a 6,30 GB, 3,2 GB al giorno per regressione, contro i 7,0-7,4 dei tre avvii con il processo attivo. La crescita residua non ha la firma della perdita: non è lineare nel tempo, perché i primi quattro campioni sono piatti (6,05-6,14) e la salita arriva con gli ultimi quattro, quando il privato dei processi passa da 35,2 a 40,1 GB per l'apertura di nuove applicazioni; nella finestra la quota correla con il privato dei processi (r = 0,91) e con il pool di paging (0,98), e nessun processo fra i primi cinquanta accumula handle: il massimo è explorer con 1.211 in quasi due ore, contro i circa 1.200 l'ora del detentore. Ne inferisco che sia carico di lavoro, cioè sezioni condivise e strutture del kernel delle applicazioni aperte, e non un secondo detentore; due ore di lavoro attivo però non bastano a separarlo da un fondo lento, e la verifica conclusiva è una finestra che comprenda una notte, sulla quale il ritmo deve scendere sotto la soglia o restare legato al privato. Lo strumento stampa ora, nella finestra di `-Dal` o di `-UltimeOre`, la correlazione fra quota non attribuita e privato dei processi, e con il detentore fermo ne fa la base del verdetto: sopra 0,8 la crescita è trattata come carico di lavoro, sotto come indizio di un secondo detentore. Restano poi due verifiche: che cosa smette di funzionare con il processo fermo, che decide il rimedio, da osservare durante un periodo con il processo fermo perché nei pochi minuti dell'esperimento nessuno ha usato le funzioni ASUS; e la causa del Kernel-Power 41 del 06/10, che non è questa. Resta infine da confermare, dopo il rimedio, che la quota non attribuita smetta di crescere: il campionatore continua a girare e la stessa diagnosi, rilanciata dopo un giorno, deve dare un ritmo vicino a zero e codice 0.

## 10. Raccordo

La lettura degli eventi 2004 e la storia dell'indagine stanno nella sezione 2d di `07_SALUTE_E_STABILITA.md`; il check di salute, quando trova eventi 2004, rimanda a questo strumento. Ogni intervento effettivo, compreso l'esperimento di rilascio, va registrato nel changelog di `01_MAPPA_CONFIGURAZIONE.md`. Il caso parallelo di questo progetto, un altro difetto che nessun intervento abituale toccava e che una misura diretta ha risolto, è `12_POWERPOINT_LENTO_DOCTOIDMAPPING.md`.

[^1]: *Memoria vincolata*, traduzione italiana di Windows per commit charge - l'impegno totale di memoria virtuale che il sistema garantisce, con il suo limite pari a RAM più file di paging; è la grandezza che, raggiunto il limite, fa fallire le allocazioni.
