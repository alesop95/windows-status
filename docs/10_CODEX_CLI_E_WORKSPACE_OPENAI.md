# 10 — Codex CLI e workspace OpenAI

Questa macchina usa piu' agenti da terminale, e finora solo uno di essi era censito. Questa scheda copre il secondo: **Codex CLI**, il client ufficiale che porta un abbonamento ChatGPT dentro il terminale, e la **configurazione del workspace** che lo governa dalla console di amministrazione.

Il documento e' scritto per essere **riapplicabile su qualunque macchina Windows 11**, quindi non contiene nessun valore reale: identificativi, nomi e caselle di posta compaiono come segnaposto fra parentesi angolari e vivono nella copia locale `10_CODEX_CLI_E_WORKSPACE_OPENAI.compilata.md`, ignorata da git come le altre compilate.

Rilievo della configurazione del workspace: **2026-09-21**, letto dalla console e non dedotto. Lo stato della macchina a quella data era: Node.js 22.23.1 e npm 10.9.8 presenti, `codex` **non installato**, nessuna cartella `.codex` nel profilo utente. Si parte quindi da zero e senza residui, il che rende questa scheda anche il verbale di una installazione pulita.

> Regola 1 del progetto rispettata: prima la mappatura, poi la pulizia. La tabella del baseline registra lo stato **rilevato** accanto al target, e i due sono colonne distinte proprio perche' non coincidono ancora.

---

## 1. Che cosa si sta configurando, e un equivoco da togliere di mezzo

L'equivoco da cui parte quasi ogni setup di questo tipo e' credere di avere N abbonamenti individuali. Non e' cosi': un piano **Business** e' **un workspace con N postazioni**, e la differenza cambia le conseguenze operative.

| Fatto | Conseguenza |
|---|---|
| Le postazioni Standard hanno un'allowance Codex pari a quella di un piano Plus, non Pro | Piu' postazioni danno piu' capienza, non modelli migliori |
| L'allowance e' per membro ed e' condivisa fra Codex web, IDE e CLI | Aprire il terminale non apre un budget separato |
| **Le conversazioni di chat NON rientrano in quel serbatoio** | Chi usa solo ChatGPT in chat non consuma la quota di Codex, e viceversa |

> **Correzione registrata, perche' l'errore opposto e' intuitivo e ha gia' influenzato una decisione in questo progetto.** La schermata `Utilizzo e fatturazione` dichiara sotto `Plan limits`: *"Shared across Codex, Work, Workspace Agents, and ChatGPT for Excel. Chat conversations are not included."* Il serbatoio copre quindi l'uso **agentico e strumentale**, non la chat. Ne segue che mettere una radice Codex su un'identita' usata da altri **per la sola chat** non sottrae loro capacita'. Il conflitto esiste solo se quelle persone usano a loro volta Codex, Work o gli agenti.
>
> **Seconda trappola di lettura, nella stessa schermata:** le percentuali sono di **disponibilita' residua**, non di consumo. "84% di disponibilita' residua" significa che ne e' stato usato il 16 per cento. Si legge al contrario con naturalezza, e porta a credere di essere quasi al limite quando si e' appena partiti.
| Le postazioni Premium portano il moltiplicatore d'uso, a prezzo per postazione piu' alto | E' la leva giusta se il problema e' la potenza |
| Il workspace puo' acquistare crediti per sforare i limiti inclusi | E' la leva giusta se un singolo membro satura, invece di comprare una postazione in piu' |
| Le postazioni Codex-only pay-as-you-go non sono piu' vendibili su Business dal 24 giugno 2026 | Le sole leve restano Standard, Premium e crediti |

Quindi "collegare piu' account sulla stessa macchina" significa fare login con **piu' membri dello stesso workspace**, e la ragione per farlo e' separare i perimetri di lavoro e i budget, non moltiplicare le capacita'.

Identificativi del workspace, che servono per i ticket all'assistenza e per le integrazioni: ID organizzazione `<ORG_ID>` e ID area di lavoro `<WORKSPACE_ID>`, entrambi leggibili nella pagina Generali della console. **Sono dati identificanti e non vanno in un file tracciato**: stanno nella compilata.

---

## 2. Parte A — La configurazione del workspace

### 2.1 Perche' questa meta' non e' tracciabile automaticamente

La Compliance API e i log di audit che registrano le modifiche alle impostazioni di un workspace sono funzioni di **Enterprise ed Edu**. Su **Business** non esiste un canale programmatico per rileggere questi interruttori, quindi non esiste un confronto automatico possibile su questa meta'.

Questa e' una limitazione da dichiarare, non da aggirare con uno strumento che finge. Un controllo che stampa verde perche' non sta guardando nulla e' peggio dell'assenza del controllo, e in questo repository la regola vale gia' per il baseline di sicurezza. Il tracciamento della Parte A e' quindi **un rilievo manuale datato piu' un changelog motivato**, e la sezione 2.4 lo rende abbastanza economico da sopravvivere.

La Parte B, cioe' la configurazione locale, e' invece pienamente automatizzabile e finisce nello snapshot: vedi sezione 5.

### 2.2 Baseline consigliato

Colonna **Rilevato** = stato al 2026-09-21. Colonna **Classe**: `C` critico, `R` raccomandato, `N` neutro o gia' corretto.

| Impostazione | Rilevato | Target | Classe | Perche' |
|---|---|---|---|---|
| **Conservazione e memoria** | | | | |
| Criteri di conservazione dei dati delle chat | Per sempre | 90 giorni | **C** | Rende inutile ogni pulizia locale: le conversazioni restano lato server a tempo indefinito |
| Abilita memoria | ON | OFF | **C** | Magazzino nascosto per utente, non ispezionabile, e con la riga sopra permanente |
| Utilizza la memoria migliorata | OFF | OFF | N | Gia' corretto |
| Riferimento a note e trascrizioni precedenti | ON | OFF | R | Richiamo cross-sessione di trascrizioni di riunione |
| **Credenziali e accesso** | | | | |
| Token di accesso personali | OFF | OFF | N | Minimo privilegio |
| Scadenza massima del token di accesso | Nessun limite | 90 giorni | **C** | Una credenziale senza scadenza e' permanente; il vincolo va messo prima che serva |
| Codice dispositivo per Codex CLI | OFF | OFF | **C** | Serve solo al login headless; la descrizione ufficiale avverte del rischio phishing |
| Individuare e controllare i dispositivi da remoto | OFF | OFF | R | Pilotare l'ambiente Codex locale dal telefono e' superficie enorme su una macchina con repository di clienti |
| Amministrare Codex | OFF | OFF | N | Minimo privilegio |
| Amministrare Codex Security | OFF | OFF | N | Minimo privilegio |
| **Superficie Codex** | | | | |
| Codex e Work in locale | ON | ON | N | E' il presupposto di tutto il setup da terminale |
| Codex Cloud | ON | OFF | R | Scelta di perimetro: qui si usa solo la CLI locale |
| Accesso a internet dell'agente Codex | ON | OFF | R | Vale solo per gli ambienti cloud, che non si usano |
| Codex Security | ON | ON | N | Utile, nessun costo di esposizione |
| App Codex Slack, risposte complete | OFF | OFF | N | Pubblica solo il link, corretto |
| Invio di referral Codex | ON | OFF | N | Invito verso l'esterno, rumore |
| **Canali verso l'esterno** | | | | |
| Pubblicare con Siti | ON | OFF | R | Canale di pubblicazione sul web senza passo di revisione |
| Abilita agenti | ON | ON | N | Superficie produttiva voluta |
| Abilita skill | ON | ON | N | Superficie produttiva voluta |
| Autorizzazioni dei plugin | Consenti basso rischio | Chiedi sempre | R | Conferma prima dell'azione, coerente con la disciplina degli agenti |
| Condivisione di chat, canvas o progetti | Solo membri | Solo membri | N | Gia' la scelta restrittiva |
| Esecuzione del codice | ON | ON | N | Contenuto, in Canvas |
| Accesso del codice alla rete | ON | OFF | R | Uscita di rete da Canvas, non necessaria |
| Ricerca sul web | ON | ON | N | Utile; le query non sono associate agli account |
| ChatGPT Record | ON | da decidere | **C** | Massima densita' di materiale di terzi non anonimizzato, e con la ritenzione attuale e' permanente |
| Condivisione di schermo o video in Voice | ON | OFF | R | Nessun uso dichiarato |
| **Telemetria** | | | | |
| Approfondimenti su attivita' | OFF | OFF | N | Classificazione dei messaggi, corretto |
| Sondaggi d'impatto OpenAI | OFF | OFF | N | Corretto |
| Identificativi utente nelle esportazioni dei sondaggi | ON | OFF | **C** | Nome e casella di posta di ogni rispondente in chiaro |
| Feedback sulle risposte | ON | OFF | R | Il pollice invia la conversazione in revisione |
| **Non pertinenti a una macchina Windows** | | | | |
| Modifiche al codice su macOS | ON | OFF | N | Nessun Mac nel perimetro |
| Collegamento ad Apple Intelligence | ON | OFF | N | Idem |

### 2.3 Le voci critiche, e perche' lo sono

**La ritenzione a tempo indefinito e' il vincolo che domina tutti gli altri.** Si puo' azzerare ogni store locale a ogni chiusura di sessione e ottenere comunque una conservazione permanente lato server. Su Business il default e' indefinito e l'amministratore puo' ottenere finestre personalizzate **a scatti di 30 giorni con un pavimento di 90**, ma non da un menu: la console rimanda all'assistenza, quindi e' l'unica voce di questa scheda che richiede un ticket. E' anche quella con il rendimento piu' alto, perche' nessun'altra azione qui dentro la compensa.

**La memoria lato server e' l'omologo esatto del magazzino nascosto locale.** Il sistema di progetto portabile stabilisce che l'unica memoria legittima e' quella versionata dentro la cartella di progetto; una memoria per utente, non ispezionabile e conservata a tempo indefinito e' la negazione di quel principio, non una sua variante.

**Due interruttori sono inerti oggi e pericolosi domani, ed e' precisamente per questo che vanno sistemati adesso.** Gli identificativi utente nelle esportazioni sono attivi mentre i sondaggi che li produrrebbero sono spenti; la scadenza dei token e' illimitata mentre la creazione dei token personali e' disabilitata. In entrambi i casi la protezione dipende da un interruttore a monte che qualcun altro potra' accendere senza rivedere quello a valle. Un guard-rail messo quando serve e' un guard-rail messo tardi.

**Il codice dispositivo per Codex CLI va lasciato spento anche durante l'installazione.** Serve al login non interattivo in ambienti headless; un'installazione su desktop fa login interattivo. Se durante il setup qualcosa suggerisce di accenderlo, e' il segnale che si sta sbagliando procedura, non che manca un permesso.

### 2.4 Procedura di rilievo

Poiche' il rilievo e' manuale, l'innesco non e' il calendario, che nessuno rispetta, ma un evento che accade comunque: **ogni cambio di postazioni o di piano**, piu' una passata trimestrale. La procedura e' di tre passi e costa pochi minuti.

1. Aprire la console di amministrazione, pagina Generali, e catturare le schermate dell'intera Politica dell'area di lavoro. **Le schermate contengono gli identificativi del workspace**, quindi vanno in `_notes\`, mai in `docs\`.
2. Confrontare con la colonna Target della tabella 2.2 e annotare ogni scostamento.
3. Registrare le modifiche applicate nel changelog della mappa compilata, con data, cosa, perche' e come si annulla, secondo la Regola 5 del progetto.

---

## 3. Parte B — Codex CLI sulla macchina

### 3.1 Prerequisiti

Node.js 22 o superiore, gia' presente su questa macchina e censito nella scheda 09. Nessun altro prerequisito.

### 3.2 Installazione

Su Windows **WSL non e' piu' necessario**: esiste l'installazione nativa con sandbox basata su AppContainer, in variante elevata e non elevata, e WSL2 resta un'opzione per chi ha gia' il proprio flusso li' dentro. Con progetti che vivono su `D:\` ed `E:\` la scelta corretta e' quella nativa, perche' WSL2 trasformerebbe quei percorsi in mount `/mnt/d` e farebbe divergere le regole di sandbox dai percorsi reali.

```powershell
npm install -g @openai/codex
```

### 3.3 Topologia multi-account

Codex tiene **tutto** il proprio stato persistente sotto una sola radice, riposizionabile con la variabile d'ambiente `CODEX_HOME`. E' l'esatto omologo di `CLAUDE_CONFIG_DIR`, e permette di replicare la stessa topologia per account gia' in uso sulla macchina.

Inventario **verificato con `codex doctor` su questa macchina**, versione 0.155.1, e non dedotto dalla documentazione, che su due punti risultava superata.

| Contenuto di `CODEX_HOME` | Natura |
|---|---|
| `config.toml` | Configurazione. Da versionare in forma anonimizzata |
| `auth.json` | Credenziali del login. Mai in nessun file, mai nello snapshot |
| `memories_1.sqlite`, `memories_v2_1.sqlite` | **Memoria nascosta locale.** Da azzerare |
| `thread_history_1.sqlite` | Indice paginato delle sessioni. Da azzerare, ma **non a colpi di rimozione di file**: vedi 4.3 |
| `state_5.sqlite` | Stato. Da azzerare |
| rollout attivi e archiviati | Transcript delle sessioni. Da azzerare tramite il comando supportato |
| `logs_2.sqlite`, `log/` | Log di esecuzione. Da azzerare |
| `goals_1.sqlite`, `queue_1.sqlite` | Stato di lavoro. Da azzerare |
| `app-server-daemon/`, `app-server-control/` | Stato del daemon locale. Da preservare |
| `version.json`, `tmp/` | Cache. Indifferente |
| `skills/`, `plugins/` | Estensioni. Da preservare |

La riga delle memorie corregge un'assunzione iniziale sbagliata: si era dato per scontato che Codex conservasse solo transcript e nessuna memoria semantica nascosta. **Ne conserva due database**, quindi l'omologia con il magazzino nascosto dell'altro agente e' piu' stretta, non piu' larga, e la disciplina della sezione 15 del sistema di progetto si applica per intero.

Il percorso della radice si ricolloca con `CODEX_HOME`; il solo stato SQLite si ricolloca a parte con `CODEX_SQLITE_HOME`.

> **Trappola, costata due tentativi durante l'installazione del 2026-09-21.** Se l'assegnamento di `CODEX_HOME` fallisce, **Codex non si ferma: ricade in silenzio sulla radice di default** del profilo utente. Il comando riesce, stampa `Successfully logged in`, e le credenziali finiscono nel posto sbagliato; l'unico segnale e' una riga di errore della shell che sembra scollegata dal resto. E' accaduto due volte perche' la riga era scritta nella sintassi di un'altra shell. La difesa non e' ricordarsi la sintassi giusta, e' **non digitare quella riga a mano**: si usa `scripts\Avvia-Codex.ps1`, che verifica la radice prima di eseguire. Se il caso si ripresenta, il rimedio e' spostare `auth.json` nella radice corretta e verificare con `codex login status` su entrambe.

Corrispondenza con l'altro agente da terminale, utile a chi conosce gia' quel setup:

| Claude Code | Codex CLI |
|---|---|
| `CLAUDE_CONFIG_DIR` | `CODEX_HOME` |
| `settings.json` | `config.toml`, piu' `<profilo>.config.toml` con `--profile` |
| `.credentials.json` | `auth.json` |
| `projects/<slug>/*.jsonl` | `sessions/YYYY/MM/DD/rollout-*.jsonl` |
| `history.jsonl` | `history.jsonl` |
| voci `projects` di `.claude.json` | nessun equivalente |
| scratchpad in `%LOCALAPPDATA%\Temp` | nessun equivalente, tutto sta sotto la radice |

Le ultime due righe sono una semplificazione reale: su Codex non esiste il doppio perimetro, quindi non serve ne' la pulizia di un file di configurazione che custodisce il login, ne' quella di uno scratchpad fuori dalla home.

Una radice per membro, secondo lo schema `<PROFILO_UTENTE>\.codex-account<N>`, e un collegamento di avvio per ciascuna accanto a quelli gia' presenti sul desktop.

### 3.3.1 Il login di piu' membri sulla stessa macchina

Fare login su piu' radici e' l'unico punto davvero scomodo del setup, e conviene sapere perche' prima di combatterlo.

Riscontro **verificato sul binario** di codex-cli 0.155.1, non dedotto: Codex **non legge nessuna variabile `BROWSER`**, apre l'URL di autorizzazione con `ShellExecute` e `rundll32`, cioe' lo consegna a Windows che usa il **profilo predefinito**, e non espone nessun flag `--no-browser`. L'unico percorso senza browser e' `--device-auth`, che la policy del workspace tiene disabilitato e che va lasciato disabilitato.

Ne discende che **non si sceglie dove si apre la pagina**, e che aprire una finestra in incognito non serve a niente: la scheda automatica nasce comunque nel profilo normale. Cio' che si controlla e' invece **chi e' autenticato in quel profilo**, e questa e' la leva da usare.

La procedura deterministica e' quindi, per ogni radice: **logout da `chatgpt.com` nel profilo predefinito**, poi il comando di login, poi l'accesso con il membro voluto nella scheda che si apre da sola, che a quel punto mostra la schermata di accesso e non una sessione gia' valida. Alla fine dei login il browser torna irrilevante, perche' ogni radice ha il proprio `auth.json`.

L'alternativa, piu' laboriosa una volta sola e nulla dopo, e' tenere **un profilo browser per membro** e rendere predefinito quello giusto prima di ciascun login.

Il modo in cui questo sbaglia, quando sbaglia, e' sempre lo stesso di tutto il resto di questa scheda: il login **riesce**, dichiara successo, e registra il membro gia' autenticato nel browser invece di quello voluto. Nessun errore, nessun avviso. Per questo la verifica dopo ogni login non e' una formalita': si legge l'identita' dentro le credenziali e si confronta con la mappatura attesa.

### 3.3.2 La quarta radice: l'app desktop usa quella di default

Su questa macchina gli store Codex sono **quattro, non tre**, e il quarto non lo crea nessuna scelta esplicita.

L'app desktop, installata sotto `%LOCALAPPDATA%\OpenAI\Codex` e quindi **distinta dall'installazione npm**, non imposta `CODEX_HOME` e lavora percio' sulla **radice di default** del profilo utente. Fa login li', vi registra le sessioni e vi riscrive il proprio `config.toml`, sensibilmente piu' grande di quello di riferimento perche' vi versa la configurazione completa dell'applicazione. Mantiene inoltre un processo `app-server` residente.

La cronologia dei fatti osservati il 2026-09-21 non lascia margine di interpretazione: la radice di default conteneva solo `log\` e `tmp\`; alle 10:27:16, contestualmente al login nell'app desktop, vi e' comparso `auth.json`; alle 10:37 un indice con una sessione gia' registrata; alle 11:26:02 il `config.toml` e' stato riscritto dal processo dell'app.

Ne discendono tre conseguenze operative.

La prima corregge un'affermazione facile da fare e sbagliata: **l'app desktop non e' una superficie isolata**. E' vero che non tocca le radici numerate, ed e' per questo che l'affermazione regge a un controllo superficiale; ma possiede la radice di default, che e' uno store completo con credenziali, transcript e database di memorie.

La seconda e' che quella radice **non ha le chiavi di prevenzione della sezione 3.4**, perche' il `config.toml` lo scrive l'applicazione. Quella superficie accumula quindi cronologia con i default, e nessuna configurazione delle tre radici numerate la riguarda.

La terza e' che **il wipe deve coprire la radice di default**, e non come ripulitura di una cartella creata per errore ma come uno store di pari dignita' agli altri, con l'avvertenza che vi insiste un processo residente: va gestita la concorrenza, o la si pulisce a app chiusa.

Resta aperto se abbia senso imporre anche li' le chiavi di prevenzione, dato che l'applicazione riscrive il file: va provato, non assunto.

### 3.3.3 Il quinto store: i dati delle attivita' fuori progetto

Oltre alle radici `CODEX_HOME` esiste una **quinta posizione**, e sta fuori da tutte:

```text
C:\Users\Utente\Documents\Codex\<data>\<nome-attivita>\outputs
C:\Users\Utente\Documents\Codex\<data>\<nome-attivita>\work
```

E' la destinazione predefinita dei dati delle **attivita' avviate al di fuori dei progetti**, impostabile dall'app desktop. Partiziona per data e per nome dell'attivita', con una cartella per i file di lavoro e una per gli output.

Tre cose da sapere.

**Non e' isolata per account.** E' un percorso fisso nel profilo utente, quindi tutte le radici e l'app desktop vi scrivono nello stesso posto. L'isolamento ottenuto con `CODEX_HOME` **non si applica qui**: e' un punto in cui i perimetri si ricongiungono.

**E' fuori da qualunque `CODEX_HOME`**, quindi una pulizia che si limiti alle radici la lascia intatta. Va nel wipe esplicitamente.

**Va verificato se la cartella Documenti sia reindirizzata su OneDrive**, perche' in quel caso file di lavoro e output verrebbero sincronizzati in cloud senza che nessuno lo abbia deciso. Su questa macchina la verifica e' stata fatta il 2026-09-21: `Documenti` e' **locale** e OneDrive risiede altrove, quindi il rischio non sussiste. Su un'altra macchina e' la prima cosa da controllare, perche' il reindirizzamento di `Documenti` su OneDrive e' una configurazione aziendale comune.

Al momento del rilievo la cartella conteneva solo l'ossatura di una attivita', senza alcun file.

### 3.4 `config.toml` di riferimento

Lo stesso file per ogni radice, salvo i server MCP che possono differire.

```toml
# Prevenzione: e' il livello che evita di sporcare, invece di pulire dopo.
[history]
persistence = "none"

[analytics]
enabled = false

[otel]
exporter = "none"
log_user_prompt = false

# Perimetro di esecuzione. Corrisponde alla whitelist dell'altro agente:
# le operazioni sicure sono ammesse, quelle verso l'esterno restano manuali.
approval_policy = "on-request"
sandbox_mode = "workspace-write"
```

`history.persistence = "none"` toglie la cronologia dei prompt ma **non** i rollout di sessione sotto `sessions/`: quelli restano, e sono il bersaglio della pulizia descritta nella Parte C. E' una distinzione che e' facile dare per scontata e che lascerebbe indietro il grosso dei dati.

### 3.4.1 Isolamento e anonimizzazione: fin dove arrivano le radici

La domanda si pone appena si vede che tutti i membri finiscono nella stessa area di lavoro, e la risposta onesta e' che **l'isolamento delle radici e' locale, non lato server**, e che **non e' anonimizzazione**.

Le radici isolano lo stato su disco: credenziali, transcript, cronologia, database di memorie. Una sessione di una radice non e' visibile ne' recuperabile da un'altra, e il wipe agisce per radice. E' isolamento reale, ma della macchina.

Non isolano tre cose, e sono le piu' importanti. I membri appartengono alla **stessa area di lavoro**, quindi lato server tutto confluisce nello stesso tenant sotto la stessa politica di ritenzione: nessuna configurazione locale la cambia. Un'eventuale **identita' di servizio condivisa** perde l'attribuzione all'origine, e a valle non si recupera. Soprattutto, **separare gli account separa la contabilita', non il contenuto**: dati identificanti dentro un progetto escono dalla macchina identici da qualunque radice partano.

Le leve reali, in ordine di efficacia: la **ritenzione delle chat**, che domina tutto; il **perimetro di accesso sul filesystem**, cioe' questa sezione; l'**anonimizzazione del contenuto** sul perimetro del repository, che e' l'unica cosa che agisce sul contenuto; e il **wipe locale**, che e' l'ultimo anello e non il primo.

### La sandbox va installata, e la diagnosi lo dice male

`codex doctor` riporta `sandbox backend disabled` accanto a `filesystem sandbox restricted`, il che suggerisce una politica dichiarata e non imposta. La spiegazione, emersa solo alla prima sessione interattiva, e' piu' banale: **il backend non era ancora stato installato**. Alla prima sessione Codex propone di configurarlo, con tre opzioni:

| Opzione | Quando |
|---|---|
| **Sandbox predefinita, richiede privilegi di amministratore** | **la scelta giusta.** Una elevazione UAC una volta sola |
| Sandbox non-admin | ripiego; la proposta stessa la dichiara `higher risk if prompt injected` |
| Esci | nessuna sandbox |

La variante non-admin va presa solo se l'elevazione e' negata da una macchina gestita, e in quel caso va annotata come limite noto da recuperare. Dopo la configurazione la sessione dichiara `Sandbox ready`.

### La scoperta che conta: l'approvazione scavalca la sandbox

Prova eseguita il 2026-09-21 dentro una sessione reale, con `approval_policy = "on-request"`. All'agente e' stato chiesto di scrivere un file **fuori** dal progetto. Il comando e' stato **approvato dall'utente**, ed e' riuscito: file creato, codice di uscita 0, nessun errore.

Non e' un difetto della sandbox. **E' il progetto: l'approvazione e' la via d'uscita dal perimetro.** Un comando approvato viene eseguito fuori dalla sandbox, che protegge da cio' che l'agente fa di propria iniziativa, non da cio' che una persona autorizza.

La conseguenza va detta senza giri di parole, perche' e' facile costruirsi un falso senso di sicurezza:

> **Il perimetro vale quanto la persona che clicca approva.** Con `on-request`, se si approva per riflesso, `writable_roots = []` non protegge nulla.

Ne discende una leva concreta, da usare quando la materia lo merita: per una sessione su materiale sensibile si avvia con `--ask-for-approval never`, e i comandi che violerebbero il perimetro **falliscono** invece di chiedere. Piu' attrito, ma il perimetro smette di dipendere da un riflesso.

### 3.4.2 La cartella di lavoro non e' un dettaglio

Avviare Codex senza indicare una cartella di lavoro lo fa partire nella **home dell'utente**, e in quel caso `sandbox_mode = "workspace-write"` rende scrivibile **l'intera home**. Nessun avviso lo segnala: la sessione si apre normalmente e dichiara soltanto `directory: ~`.

C'e' un secondo effetto, osservato il 2026-09-21 e meno ovvio. Partendo dalla home, Codex trova `~\.codex` **dentro la cartella corrente** e la scambia per una configurazione di progetto, emettendo un avviso su chiavi non supportate in `C:\Users\Utente\.codex\config.toml`. La radice di default e la configurazione locale di progetto si sovrappongono per il solo fatto di trovarsi nello stesso posto.

Per questo `Avvia-Codex.ps1` ha un parametro `-Progetto` e **rifiuta di avviare una sessione interattiva senza**. La cartella va indicata, non ereditata:

```powershell
.\scripts\Avvia-Codex.ps1 -Account 2 -Progetto E:\un-progetto
```

Il modo `-Stato`, che non apre una sessione, non richiede il progetto.

### 3.5 `AGENTS.md` come puntatore, mai come copia

Per Codex il file di istruzioni di progetto e' `AGENTS.md`, con la stessa gerarchia dell'omologo dell'altro agente: globale nella radice della configurazione, di repository nella radice del progetto, locale nelle sottocartelle.

La regola da tenere ferma e' che **`AGENTS.md` sia un puntatore ai documenti del progetto e non una loro copia**, per due motivi di peso diverso. Il primo e' di principio: una copia e' una seconda fonte di verita', ed e' il drift che il motore di riconciliazione esiste per impedire. Il secondo e' tecnico e meno ovvio: la chiave `project_doc_max_bytes` tronca `AGENTS.md` a una soglia di default modesta, quindi un file che contenesse davvero il materiale verrebbe letto a meta' **senza dirlo**. Un puntatore non raggiunge mai la soglia.

---

## 4. Parte C — Pulizia e anonimizzazione

### 4.1 I tre livelli

Il primo livello e' la **prevenzione**, ed e' la sezione 3.4: le chiavi di `config.toml` che spengono cronologia, metriche e log dei prompt. E' preferibile alla pulizia perche' non dipende dal momento in cui qualcosa viene eseguito.

Il secondo livello e' il **wipe** degli store che restano, trattato sotto.

Il terzo livello e' l'**anonimizzazione del repository**, che e' un problema diverso e indipendente dall'agente: riguarda i valori identificanti finiti nei file versionati, si risolve con un controllo sul perimetro git e non ha nulla a che vedere con Codex. Vale qui la stessa osservazione che vale altrove: un residuo non si introduce, si eredita, quindi il controllo si fa sul perimetro intero e non sul diff.

### 4.2 Perche' un wrapper di avvio e non un hook

**Codex non ha un hook di fine sessione.** L'unico gancio di ciclo di vita e' `notify`, un programma esterno invocato al completamento di un **turno** dell'agente, che non e' il momento giusto. La pulizia va quindi fatta da un **wrapper di avvio**: uno script che imposta `CODEX_HOME`, esegue `codex` e, al ritorno del processo, esegue il wipe.

Questo e' **piu' affidabile** dell'hook di fine sessione dell'altro agente, che soffre di un caveat di timing noto: il processo puo' riscrivere file di sessione dopo che l'hook e' gia' scattato, quindi la coda dell'ultima sessione sopravvive fino alla chiusura successiva. Qui il processo e' gia' terminato quando la pulizia parte. Resta il solo limite della terminazione anomala, che si copre tenendo il wipe invocabile anche a mano.

Gli store da azzerare e da preservare sono quelli della tabella in 3.3. Il login sopravvive, come deve.

Resta una verifica aperta: la presenza dell'opzione `--dangerously-bypass-hook-trust` indica che questa versione **ha una nozione di hook**, quindi l'affermazione che Codex non ne esponga nessuno di ciclo di vita va riverificata. Se esistesse un gancio di fine sessione, il wrapper resterebbe comunque preferibile per il motivo detto sopra, ma varrebbe la pena saperlo.

### 4.3 Il wipe selettivo, e le due differenze strutturali che vanno progettate

Qui sta la parte in cui un'automazione presa da un altro agente non si limita a non funzionare: **sbaglia in un modo che non somiglia a un errore**.

**Prima differenza: la partizione.** Il wipe dell'altro agente e' selettivo per progetto perche' il suo store e' partizionato per percorso, con uno slug derivato dal path. Codex **non partiziona per progetto**: la cartella di lavoro della sessione sta *dentro* il rollout, non nel nome di una cartella. Una logica di preservazione basata sui nomi delle cartelle, portata qui, non corrisponderebbe a nulla, preserverebbe l'insieme vuoto e cancellerebbe tutto senza emettere un errore, perche' dal suo punto di vista starebbe facendo esattamente cio' che le e' stato chiesto.

**Seconda differenza: i rollout sono indicizzati da un database.** Questa versione tiene un `thread_history_1.sqlite` e uno `state_5.sqlite` che indicizzano le sessioni, e offre `migrate-rollouts` proprio per portare le sessioni in formato file dentro la storia paginata. Rimuovere i file da sotto un indice che li cita lo disallinea. Esiste pero' la via supportata, ed e' quella da usare:

```powershell
codex delete <UUID-sessione> --force
```

La strategia adottata e' quindi **enumera, filtra per cartella di lavoro, elimina con il comando supportato**, mai con una rimozione di file. Le tre guardie da implementare, prima di qualunque eliminazione, sono:

1. la radice indicata esiste e assomiglia a una radice di Codex, cioe' contiene almeno `config.toml` o `sessions/`, cosi' che un segnaposto non sostituito non si traduca in rimozioni altrove;
2. i prefissi di preservazione non sono ancora il segnaposto, perche' un insieme vuoto significherebbe non preservare niente;
3. esistono rollout e **almeno uno** corrisponde ai prefissi configurati; in caso contrario lo script si ferma dichiarando che la configurazione appartiene a un'altra macchina, e va forzato solo con una deroga esplicita.

I prefissi non vanno indovinati, si leggono: lo script ha un modo di **sola lettura** che elenca le cartelle di lavoro realmente presenti marcandole come preservate o da rimuovere, funzionante anche a segnaposto non sostituito, perche' e' proprio il comando con cui si scopre che cosa configurare. Un secondo modo a vuoto stampa ogni rimozione senza farne nessuna. La sequenza corretta e' elencare, scegliere, compilare, provare a vuoto, e solo allora installare.

A queste si aggiunge una quarta regola, che non e' una guardia ma un criterio di fallimento: **una sessione la cui cartella di lavoro non sia determinabile viene preservata, mai rimossa.** Un rollout illeggibile o con un formato inatteso non deve tradursi in una cancellazione decisa in assenza di informazioni.

### 4.4 `Pulisci-Codex.ps1`

Lo script vive in `scripts\Pulisci-Codex.ps1` ed e' invocato da `Avvia-Codex.ps1` in un blocco `finally`, quindi copre anche l'interruzione da tastiera e l'uscita per errore.

| Modo | Effetto |
|---|---|
| `-Lista` | sola lettura: elenca le sessioni con la loro cartella di lavoro, marcate KEEP o WIPE. Funziona a segnaposto non sostituito |
| `-DryRun` | stampa ogni rimozione senza farne nessuna |
| `-Tutto` | azzera anche i database di stato, ignorando la preservazione |
| `-IncludiDefault` | include la radice dell'app desktop, esclusa per default |
| `-GiorniAttivita <n>` | giorni da conservare in `Documents\Codex`. Default 0, cioe' tutto |
| `-Deroga` | forza l'esecuzione quando la terza guardia rifiuta |

Copre tutti e cinque gli store: le tre radici numerate, facoltativamente quella di default, e `Documents\Codex`. Rimuove le sessioni con `codex delete <uuid> --force` e non cancellando file, per non disallineare l'indice. Non tocca mai `auth.json`, `config.toml`, `skills\`, `plugins\`, e dopo ogni radice **verifica** che cio' che doveva sopravvivere sia sopravvissuto, perche' un wipe che porta via le credenziali e' indistinguibile da uno corretto finche' non si riapre la sessione successiva.

Collaudato il 2026-09-21 nei tre modi, con una pulizia vera al termine: entrambe le radici autenticate hanno conservato credenziali e configurazione, e `codex login status` ha continuato a rispondere. Due difetti sono emersi proprio dal collaudo a vuoto e sarebbero comparsi solo durante una pulizia vera: `TryParseExact` in PowerShell 5.1 non accetta un provider nullo, e pretende che la variabile passata per riferimento sia gia' tipizzata `[datetime]`.

---

## 5. Parte D — Che cosa si versiona e che cosa no

| Elemento | Dove | Versionato |
|---|---|---|
| Questa scheda | `docs\10_...md` | Si' |
| Identificativi, nomi, caselle di posta, stato rilevato reale | `docs\10_....compilata.md` | No, ignorato |
| Schermate della console | `_notes\` | No, ignorato |
| Script di avvio e di wipe | `scripts\` | Si' |
| `config.toml` di riferimento, anonimizzato | in questa scheda | Si' |
| `config.toml` reali, `auth.json`, `sessions/` | nelle radici degli account | Mai |
| Fotografia della configurazione locale | `snapshots\` | No, ignorato |

La fotografia dell'ultima riga e' il punto in cui la Parte B diventa tracciabile davvero. Lo snapshot gia' fotografa, per ogni account, la configurazione dell'altro agente da terminale, di git, di SSH e dell'ambiente di sviluppo: estenderlo alle radici `CODEX_HOME` presenti, esportando `config.toml` ed escludendo per costruzione `auth.json`, fa entrare Codex nel confronto fra due fotografie senza aggiungere nessuno strumento nuovo. E' la differenza fra le due meta' di questa scheda: la Parte A si rileva a mano perche' non c'e' altro modo, la Parte B no.

---

## 6. Ripristino 1:1 dopo una formattazione

Il setup multi-account e' riproducibile **per intero dal repository**, senza copiare niente dalla macchina precedente. Serve `scripts\Installa-Codex.ps1` piu' `codex-config.riferimento.toml`, entrambi versionati.

```powershell
.\scripts\Installa-Codex.ps1 -Verifica
.\scripts\Installa-Codex.ps1 -Radici 3
```

Il primo comando e' di sola lettura e stampa il quadro; il secondo installa Codex se assente, crea le radici mancanti e scrive in ciascuna il `config.toml` dalla copia di riferimento. E' **idempotente**: rieseguirlo non sovrascrive un `config.toml` gia' presente, salvo `-Forza`, che serve a riallineare le radici quando la copia di riferimento cambia.

### Dove vivono gli strumenti, e perche' non dentro le radici

La domanda si pone da sola: se ogni radice e' un perimetro isolato, perche' gli script non vivono dentro di essa, una copia per account? La risposta e' che **le radici sono stato, il repository e' strumento**, e confonderli rompe proprio la riproducibilita' che si vuole ottenere. Cinque ragioni, in ordine di gravita'.

Le radici **muoiono con la macchina**. Uno strumento di ricostruzione che vive dentro cio' che va ricostruito non esiste piu' nel momento in cui serve.

L'installatore **deve girare prima che le radici esistano**: ospitarlo in una radice e' un paradosso, perche' serve a crearla.

Il wipe **non deve vivere dentro cio' che ripulisce**. Una pulizia leggermente piu' larga del previsto rimuove il proprio strumento, e lo fa senza errori.

**Tre copie divergono in silenzio.** Uno script parametrizzato per account e' una sola fonte di verita'; tre copie accumulano correzioni disallineate e nessuno sa piu' quale sia quella giusta. E' la stessa ragione per cui `AGENTS.md` e' un puntatore e non una copia.

E' infine **lo scopo dichiarato del repository che li ospita**: si versionano gli script e i documenti, non le fotografie dello stato.

Gli script non contengono percorsi fissi, usano la posizione del proprio file e il profilo utente, quindi il repository si clona ovunque, anche su una macchina con lettere di disco diverse.

### Il puntatore nelle radici

Resta un problema reale che la collocazione nel repository crea: le radici diventano **orfane**. Chi le trovasse fra due anni non avrebbe modo di sapere dove stiano strumenti, documentazione e regole.

Si risolve con un puntatore, non con una copia: `Installa-Codex.ps1` scrive in ogni radice un **`AGENTS.md`** dalla copia versionata `codex-agents.riferimento.md`. Codex lo legge all'inizio di ogni sessione su quella radice, quindi il puntatore non e' un promemoria per un umano di passaggio ma un documento che fa un lavoro: dichiara all'agente stesso dove vivono gli strumenti, che la memoria legittima e' solo quella di progetto, che commit e push restano manuali, e che segreti e identificativi non entrano nei file tracciati.

Vale anche qui la regola gia' enunciata: **non si modifica nella radice**, si modifica il riferimento e si ridistribuisce con `-Forza`, altrimenti le radici divergono senza che nulla lo segnali.

### Cosa si ripristina e cosa no

| Elemento | Ripristino |
|---|---|
| Codex CLI | automatico, `npm install -g` dentro lo script |
| Radici degli account | automatico |
| `config.toml` di ogni radice | automatico, dalla copia di riferimento versionata |
| Launcher e installatore | vengono con il repository |
| Baseline del workspace | e' la tabella 2.2, si riapplica a mano nella console |
| **`auth.json`, cioe' le credenziali** | **mai**, si rifa' un login per radice |

L'ultima riga non e' un limite dello strumento ma la scelta corretta, e vale dirla per esteso perche' la tentazione opposta e' forte: una credenziale copiata da una macchina all'altra e' una credenziale uscita dal proprio custode, e sopravvive in un backup molto piu' a lungo di quanto sopravviva la ragione per cui era stata copiata. Il costo del ripristino e' un login per radice, che e' esattamente il punto in cui si vuole che qualcuno dimostri di avere diritto a quell'accesso.

### Le uniche due cose specifiche della macchina

Sono i **prefissi delle cartelle di lavoro** da preservare, che dipendono dalle lettere di disco su cui vivono i progetti, e il **numero di radici**. Il primo non va indovinato ma letto con il modo di sola lettura del wipe; il secondo e' un parametro. Tutto il resto, cioe' la tabella del baseline, la copia di riferimento, la disciplina del puntatore `AGENTS.md` e la struttura del wipe con le tre guardie, si trasferisce invariato.

### Collaudo eseguito

Il 2026-09-21 l'installatore e' stato eseguito con `-Forza` su tre radici gia' popolate, di cui una autenticata. Esito verificato: i tre `config.toml` risultano **byte-identici** alla copia di riferimento, e `auth.json` della radice autenticata e' rimasto intatto per dimensione e data, con il login ancora valido subito dopo. E' il collaudo che serve, perche' un installatore che riallinea la configurazione e per farlo azzera le credenziali sarebbe indistinguibile da uno corretto finche' non lo si usa sul serio.

---

## 6-bis. Simmetria fra i due agenti da terminale

Questa macchina ospita due agenti da terminale, entrambi multi-account, e per un po' solo uno dei due era riproducibile con un comando. La differenza non era una svista ma una conseguenza tecnica, e va conosciuta perche' spiega perche' l'installazione non puo' essere identica.

**Claude Code ha un hook di fine sessione.** Un hook e' un comando registrato nel `settings.json` dell'account che punta a un file, quindi lo script di wipe **deve esistere come copia dentro ogni radice**. **Codex non ha un hook di ciclo di vita**, si avvia da un wrapper, e i suoi script restano nel repository. Da qui due installatori diversi.

### La simmetria d'uso, che e' diversa da quella di sostanza

La simmetria costruita finora era **di sostanza**: due installatori, due catene, un punto d'ingresso. Restava pero' un'asimmetria **d'uso**, ed e' quella che si sente ogni giorno: Claude si avviava con `claude-account2`, Codex con il percorso intero di uno script dentro il repository.

Era sbagliato per un motivo di principio: **il repository e' la fonte degli strumenti, non il modo in cui li si lancia**. Lanciare per percorso significa che lo strumento quotidiano dipende da dove hai clonato il repo.

`scripts\Installa-Comandi.ps1` scrive nel profilo PowerShell le funzioni per tutte le radici presenti, scoprendole da sole. Dopo l'installazione i due agenti si avviano allo stesso modo:

```powershell
cd <progetto>
claude-account2
codex-account2
```

La cartella corrente diventa il progetto, come ci si aspetta da un comando di shell.

**La differenza interna resta, ed e' documentata perche' non e' arbitraria.** La funzione di Claude imposta la variabile e chiama l'eseguibile: basta, perche' la pulizia la fa l'hook nativo. La funzione di Codex passa dal launcher, perche' Codex **non ha un hook di ciclo di vita** e guardie, vincolo sulla cartella di lavoro e pulizia all'uscita vivono nel wrapper. Stessa invocazione, motori diversi.

Il blocco scritto nel profilo e' delimitato da marcatori e viene sostituito a ogni esecuzione, quindi lo script e' idempotente. Il profilo viene copiato prima di essere toccato, e alla prima installazione `-RimuoviVecchie` toglie le definizioni scritte a mano in precedenza: **in PowerShell vince l'ultima definita**, quindi una definizione vecchia lasciata in coda farebbe ombra a quella generata senza che nulla lo segnali.

### Un solo punto d'ingresso

```powershell
.\scripts\Installa-Agenti.ps1 -Verifica
.\scripts\Installa-Agenti.ps1 -Prefissi 'D--','E--' -ClonaTemplate
```

`Installa-Agenti.ps1` non duplica nulla: verifica i prerequisiti, risolve la dipendenza dal template clonandolo se manca, e chiama i due installatori. Da una macchina Windows nuda a multi-account completo su entrambi gli agenti si passa da qui.

### Perche' due repository e non uno

E' la domanda che si pone chiunque veda la dipendenza, e la risposta e' che **hanno lavori diversi**.

Il **template** e' lo *standard*: generico, portabile fra macchine e fra persone, privo di qualunque valore di questa macchina. **Questo repository** e' *questa macchina*: contiene i valori che solo qui hanno senso, i prefissi dei dischi di sviluppo e il numero di account.

Copiare i riferimenti del template dentro questo repository creerebbe due versioni che divergono in silenzio, che e' il difetto che tutto il resto del progetto esiste per evitare. Mettere i valori di questa macchina nel template lo renderebbe inservibile altrove. La dipendenza va quindi **tenuta**, resa **esplicita** e **automatizzata**, non eliminata: l'orchestratore la risolve da se', e l'utente non ha bisogno di sapere quale repository fa cosa.

### `Installa-Claude.ps1` e i suoi due difetti trovati al collaudo

Lo script sostituisce nel `session-end-wipe.ps1` del template il percorso della radice e i prefissi da preservare, copia il companion, e fonde nel `settings.json` l'hook e `autoMemoryEnabled: false` **preservando ogni altra chiave**, con una scrittura difensiva in Node per la ragione gia' nota: `ConvertFrom-Json` di PowerShell 5.1 tratta le chiavi come case-insensitive.

Ha tre guardie, e la terza ha trovato due difetti veri durante il collaudo su una radice di prova, entrambi del tipo che sarebbe emerso solo alla prima chiusura di sessione.

Il primo: la sostituzione dei segnaposto era fatta con `-replace`, e **nella stringa di sostituzione i caratteri `$` sono riferimenti a gruppi di cattura**, non testo letterale. Righe che contengono variabili uscivano mangiate. Corretto passando a una sostituzione riga per riga, senza regex.

Il secondo: **PowerShell 5.1 mangia le virgolette annidate** quando passa un argomento a un eseguibile nativo, e l'hook finiva registrato con il percorso non quotato. Su un percorso con spazi non avrebbe funzionato. Corretto passando a Node il solo percorso e facendogli comporre il comando.

La guardia stessa ha poi dovuto essere corretta per un falso positivo: contava anche i segnaposto citati **nei commenti** di intestazione del template, che restano li' legittimamente, e dava quindi un allarme a ogni installazione riuscita. Un allarme che suona sempre smette di essere letto, quindi ora guarda le sole righe di assegnamento.

---

## 7. I due canali di spesa OpenAI, e l'integrazione con Trados Studio

Il perimetro OpenAI dell'azienda non e' solo l'abbonamento: ci sono **due canali di spesa distinti**, con fatture separate, e confonderli porta a decisioni sbagliate in entrambe le direzioni. La regola per distinguerli e' meccanica e non ha eccezioni.

> **La spesa segue il meccanismo di autenticazione, non il prodotto.**

| Come si aggancia | Cosa consuma |
|---|---|
| Con una **chiave API** (`sk-...`) | L'account **Platform**, a consumo, fattura separata. **Non tocca** le postazioni |
| Con il **login ChatGPT** (OAuth) | L'allowance della **postazione** di quel membro, condivisa fra web, app desktop e Codex CLI |

### L'integrazione con Trados Studio

L'azienda usa OpenAI come *provider di automated translation* dentro Trados Studio, tramite il plugin **OpenAI provider for Trados Studio**, configurato in `Options > Language Pairs > All Language Pairs > Translation Memory and Automated Translation`. La connessione si stabilisce incollando una **chiave API** nella sezione `Connections`.

Ne discende, per la tabella sopra, che **l'uso di Trados Studio non consuma nulla dell'abbonamento Business**: e' spesa dell'account Platform, a consumo. E' la risposta a una domanda che si ripresenta ogni volta che si valuta se comprare postazioni in piu'.

Due osservazioni di governance, che non bloccano nulla oggi ma vanno registrate perche' diventano urgenti tutte insieme.

La chiave API e' **unica per il gruppo di lavoro** e distribuita dal reparto IT. Non e' quindi attribuibile a una persona ne' revocabile per persona: una revoca ferma l'intero reparto, e un consumo anomalo non e' riconducibile a chi lo ha generato. La mitigazione, quando servira', e' una chiave per persona o per progetto, che il piano Platform consente.

L'accesso a ChatGPT documentato per i PM avviene con un'**identita' di servizio condivisa**, e la documentazione stessa dichiara che su di essa "confluiranno tutte le chat di chi si collega usando tale account". Combinato con la ritenzione delle chat su `Per sempre` (tabella 2.2, voce critica), produce un archivio permanente, condiviso e non attribuibile. E' un'altra ragione, indipendente da quelle gia' date, per cui la voce sulla ritenzione va affrontata per prima.

### L'OTP dell'identita' di servizio, e dove si legge

La documentazione per i PM istruisce ad accedere con l'identita' di servizio e avverte che il portale puo' chiedere un **codice OTP inviato all'indirizzo collegato all'account**. L'identita' e' una **cassetta postale condivisa**, quindi l'OTP arriva normalmente; quello che serve per leggerlo e' la **delega** sulla cassetta, in `Lettura e gestione (accesso completo)`, assegnata dall'interfaccia di amministrazione di Exchange. Senza delega il codice arriva e nessuno lo vede, che e' il modo in cui questo passaggio si presenta come un guasto quando invece e' un permesso mancante.

Il flag di accesso bloccato sull'utente non e' in conflitto e non va rimosso: le cassette condivise sono bloccate al sign-in **per progetto**, e restano perfettamente in grado di ricevere posta.

Se l'OTP non arriva, l'ordine di controllo che paga e' questo, e la prima domanda da farsi e' **se il messaggio sia mai stato consegnato**, non dove sia finito. Si va quindi subito alla traccia messaggi di Exchange, `Flusso di posta > Traccia messaggi`, filtrando per destinatario. Cercare prima nelle cartelle, nella posta indesiderata e in quarantena e' tempo speso a esplorare ipotesi che la traccia scarta tutte in un colpo.

> **Seconda trappola diagnostica, e questa costa piu' della prima.** Nel riepilogo della traccia la colonna `Stato` puo' riportare **`Operazione non riuscita`** mentre gli **eventi del messaggio** mostrano una consegna **riuscita**. Non e' una contraddizione: il riepilogo si riferisce al recapito nella cassetta di destinazione originale, gli eventi all'esito complessivo. Accade tipicamente quando sulla cassetta insiste un **inoltro senza conservazione della copia**: il messaggio viene ricevuto, rediretto altrove, la copia originale scartata con `LED=250 2.1.5 RESOLVER.FWD.Forwarded`, e consegnato all'indirizzo di inoltro. Chi si ferma al riepilogo cerca un guasto che non esiste. **La risposta sta sempre negli eventi del messaggio, mai nella colonna di stato**, e si aprono cliccando la riga.
>
> Il caso reale in cui e' emersa: una cassetta di servizio condivisa, indicata da una procedura aziendale come indirizzo di riferimento, inoltrava da mesi tutta la posta a una singola persona senza che nulla lo documentasse. I delegati vedevano una casella ferma da mesi e nessun errore.

> **Trappola diagnostica, costata una diagnosi sbagliata durante questa sessione.** Il pannello utenti di Microsoft 365 **non e' autoritativo sull'esistenza di una cassetta**. Per l'utente collegato a una cassetta condivisa mostra `Unlicensed` e, nella scheda Posta, "L'utente non dispone di alcuna licenza di Exchange Online": entrambe le cose sono vere e nessuna delle due significa che la cassetta non esista, perche' **una cassetta condivisa e' senza licenza per definizione**, ed e' precisamente il suo pregio. Non e' affidabile nemmeno il suffisso `(Shared)` nel nome visualizzato, che in questo tenant e' applicato a intermittenza: diverse cassette condivise ne sono prive. L'unica fonte autoritativa e' l'**interfaccia di amministrazione di Exchange**, `Destinatari > Cassette postali`, colonna `Tipo di destinatario`, che dichiara `SharedMailbox` o `UserMailbox`. Si guarda quella, prima di concludere qualsiasi cosa sul recapito.

---

## 7-bis. Misurare il consumo di tutte le radici insieme

Con sei radici su due agenti, il consumo si guarda una radice alla volta e quindi non si guarda mai. La conseguenza non e' estetica: **si lavora su una flotta satura mentre un'altra e' ferma**, che e' precisamente lo spreco che il setup multi-account esiste per evitare.

```powershell
.\scripts\Consumo-Agenti.ps1
.\scripts\Consumo-Agenti.ps1 -Giorni 7
.\scripts\Consumo-Agenti.ps1 -Json
```

Sola lettura. Non chiama nessun servizio: legge i file di sessione che i due agenti tengono gia' sul disco, tramite `ccusage`, che li interpreta senza inviare nulla altrove. Scopre da sola le radici presenti, comprese le due **radici di default** senza numero, che consumano quota e sono il posto in cui e' piu' facile perdere di vista dove siano finiti i token.

Segnala inoltre lo **squilibrio fra le flotte** quando supera un fattore cinque, perche' il serbatoio fermo e' la leva che aumenta il lavoro svolto senza avvicinare alcun limite.

### Due trappole di lettura, entrambe incontrate

**La colonna in valuta e' nozionale.** E' quanto quei token costerebbero a tariffa a consumo; su un piano in abbonamento non si paga. Serve come indicatore di valore, non come spesa, e leggerla come una fattura porta a conclusioni sbagliate sull'ordine di grandezza.

**`Cache Read` domina e non e' lavoro nuovo.** E' contesto riletto, e su un rilievo reale valeva quasi il 99 per cento del totale. Le colonne che descrivono il lavoro sono `Input`, `Output` e `Cache Create`.

### Un difetto trovato al collaudo, che vale oltre questo strumento

Per misurare una radice alla volta si punta la variabile d'ambiente di quella flotta alla radice e quella dell'altra altrove. La prima versione la puntava a un **nome inventato**, e `ccusage` non restituiva zero: **falliva**, e il fallimento arrivava come "nessun dato", indistinguibile da un consumo nullo.

La seconda versione usava una cartella vuota ma esistente, e falliva ancora: non basta che esista, **deve avere la forma di una radice di agente**. La versione corretta crea le sottocartelle che le due flotte si aspettano.

La forma generale merita di essere ricordata perche' non riguarda questo strumento: **un errore di lettura che si presenta come assenza di dato produce una misura sbagliata e silenziosa**, ed e' il modo in cui una misurazione diventa peggiore di nessuna misurazione.

---

## 8. Punti aperti

1. **Ticket all'assistenza per la ritenzione delle chat.** Nessuna altra azione compensa questa voce. Target 90 giorni.
2. **Verificare quali interruttori siano davvero modificabili.** Nella console diversi appaiono di un blu attenuato rispetto ad altri, il che di norma indica un controllo attivo ma non modificabile da quel pannello. Finche' non e' verificato, alcune righe della tabella 2.2 sono constatazioni e non azioni.
3. **Decidere su ChatGPT Record.** E' la fonte di materiale di terzi con la densita' piu' alta, e la decisione dipende dall'esito del punto 1.
4. **Estendere lo script di snapshot alle radici `CODEX_HOME`**, come da sezione 5. La forma migliore e' `codex doctor --json`, che produce un report gia' redatto: e' l'omologo di un controllo di igiene dell'account, e nessuno deve scrivere un parser di `config.toml`.
5. ~~Compilare i prefissi di `Pulisci-Codex.ps1`~~ **FATTO il 2026-09-21.** La sequenza ha funzionato come progettata: sessione reale su un progetto, `-Lista` che legge la cartella di lavoro **da dentro il rollout**, compilazione, prova a vuoto. Tutte e tre le guardie sono state verificate contro dati reali, inclusa la terza, provata passando i prefissi di un'ipotetica altra macchina: rifiuta, e con `-Deroga` procede dichiarandolo.
6. **Verificare se esista un hook di ciclo di vita**, come da 4.2.
7. **Trattare la radice di default come un quarto store a pieno titolo**, non come un residuo: e' quella dell'app desktop, ha credenziali, sessioni e memorie, e non ha le chiavi di prevenzione. Vedi 3.3.2. Da decidere se imporvi la configurazione di riferimento, verificando se l'applicazione la riscrive.

8. **Integrare la documentazione per i PM** con il passaggio della delega sulla cassetta condivisa, che oggi non e' scritto da nessuna parte ed e' l'unico requisito per leggere l'OTP.
9. **Valutare una chiave API per persona o per progetto**, al posto di quella unica di reparto.

---

## 9. Stato dell'installazione

| Elemento | Stato al 2026-09-21 |
|---|---|
| `codex-cli` | 0.155.1, npm globale, in `%APPDATA%\npm` |
| Radice `account1` | creata, `config.toml` valido, **login ChatGPT attivo** |
| Validazione configurazione | `codex --strict-config doctor` accetta tutte le chiavi della sezione 3.4 |
| Diagnosi `account1` | 20 ok, 0 warn, 0 fail |
| `scripts\Avvia-Codex.ps1` | scritto e collaudato, nei due modi normale e `-Stato` |
| `scripts\Installa-Codex.ps1` | scritto e collaudato, ripristino 1:1 verificato con `-Forza` |
| `scripts\Pulisci-Codex.ps1` | scritto e collaudato nei modi `-Lista`, `-DryRun`, `-Tutto` e in pulizia vera. Prefissi da compilare |
| Radici autenticate | **tutte e tre**, identita' verificate dalle rivendicazioni dentro `auth.json` |
| `scripts\Installa-Agenti.ps1` | punto d'ingresso unico per entrambi gli agenti, collaudato |
| `scripts\Installa-Claude.ps1` | scritto e collaudato con installazione da zero su radice di prova, poi rimossa |
| Setup complessivo | **sei account attivi**, tre per agente |
| Sandbox Windows | installata alla prima sessione, variante con privilegi di amministratore |
| `scripts\Pulisci-Codex.ps1` | **operativo**: prefissi compilati, tre guardie verificate su dati reali |
