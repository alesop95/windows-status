# 11 — Orchestrazione di piu' agenti da terminale su Windows 11

Questa macchina ospita due flotte di agenti da terminale, censite nella scheda 10: tre radici Claude Code e tre radici Codex, isolate e ripristinabili. Questa scheda copre il livello sopra: **quali strumenti permettono di far lavorare piu' agenti in parallelo**, quali sono compatibili con questa macchina e quali no, e come si installano.

Il criterio di *quando* convenga farlo non sta qui: e' materia di disciplina di progetto e vive nel template. Qui sta solo cio' che impatta il setup di Windows.

Rilievo del 2026-09-21.

---

## 1. Il vincolo che esclude meta' del panorama

Quasi tutti gli orchestratori di agenti nascono su Unix e si appoggiano a **`tmux`**, il multiplexer di terminale, per tenere vive piu' sessioni. Il loro installer manda gli utenti Windows su **WSL**, e per questa macchina WSL e' gia' stato valutato e scartato, per una ragione documentata nella scheda 10: i progetti vivono su `D:\` ed `E:\`, e dentro WSL quei percorsi diventano `/mnt/d` e `/mnt/e`. Le regole di sandbox, i percorsi nei file di configurazione e i prefissi del wipe divergerebbero dai percorsi reali.

> **Correzione registrata.** La prima stesura di questa scheda affermava che `tmux` non ha alcun port nativo Windows, e su quella base escludeva d'ufficio ogni strumento che lo richiede. **E' falso.** Esiste **`psmux`**, tmux nativo per Windows senza WSL e senza Cygwin, che legge un `.tmux.conf` esistente e dichiara supporto di prima classe per le agent team di Claude Code in pannelli separati. Era **gia' censito nel catalogo dei pacchetti del template**, e non era stato guardato prima di scrivere: e' un'istanza esatta del principio della sezione 20 del sistema di progetto, cioe' guardare che cosa esiste gia' prima di concludere.
>
> La conseguenza e' che la regola di selezione **non e' "niente tmux"**, ma quella qui sotto.

**La regola corretta: su questa macchina si adottano solo strumenti che girano nativi, senza WSL.** Uno strumento che richiede `tmux` non e' escluso in partenza: e' condizionato all'adozione di `psmux`, che aggiunge una dipendenza da valutare per conto proprio.

### Strumenti esaminati

| Strumento | Esito |
|---|---|
| **Nimbalyst** | **adottabile.** Nativo Windows, nessuna dipendenza Unix. Vedi sezione 2 |
| **Claude Squad** | **condizionato.** Richiede `tmux`, quindi presuppone `psmux`. Da valutare solo se Nimbalyst si rivela insufficiente: due dipendenze invece di una, per un beneficio che si sovrappone |
| **Conductor** | escluso, solo macOS |
| **Crystal** | escluso, deprecato a febbraio 2026 con redirezione al successore |

Vengono elencati non per completezza ma perche' sono i primi risultati di qualunque ricerca sull'argomento: senza questa tabella, ogni volta che qualcuno riapre il tema li rivaluta da capo.

---

## 2. Nimbalyst, l'unico candidato compatibile

E' il successore di Crystal. Applicazione desktop, **nativa Windows**, e fa girare in parallelo **Claude Code, Codex, OpenCode e Copilot**, ciascuno in un **worktree git isolato**.

| Voce | Valore rilevato |
|---|---|
| Licenza | MIT, gratuita per uso individuale |
| Piattaforme | Windows 10+, macOS, Linux |
| Agenti | Claude Code, Codex, OpenCode (alpha), Copilot (alpha) |
| Isolamento | worktree git per sessione |
| Maturita' | circa 1.800 stelle, 575 issue aperte |

Il numero di issue aperte va letto per quello che e': **e' un progetto giovane**, non uno strumento assestato. Va adottato sapendo che puo' rompersi, e mai come unico modo di arrivare al proprio lavoro.

### Il caveat che conta piu' della licenza

Il client e' MIT, ma **il server di sincronizzazione della collaborazione e' un progetto separato, con licenza diversa**, e punta a un endpoint di terze parti (`wss://sync.nimbalyst.com`). Esiste inoltre un'app mobile companion.

Su una macchina che ospita repository di clienti, attivare la sincronizzazione significa **mandare materiale di terzi a un servizio esterno non governato da alcun accordo**. Vale la stessa disciplina applicata altrove in questo progetto: si usa in **modalita' locale**, senza collaborazione ne' companion mobile, e la scelta va verificata nelle impostazioni dopo l'installazione, non assunta.

### Installazione

L'eseguibile si scarica dalla pagina delle release ufficiali del repository `nimbalyst/nimbalyst`. Secondo la disciplina gia' applicata su questa macchina ad altri eseguibili presi da GitHub, **il digest va verificato prima dell'esecuzione** contro quello pubblicato dal repository, non dopo.

```powershell
$dir = "$env:USERPROFILE\Downloads"
Start-Process 'https://github.com/nimbalyst/nimbalyst/releases/latest'
```

Scaricato l'installer, prima di eseguirlo:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\Nimbalyst-Windows.exe" -Algorithm SHA256
```

Si confronta il risultato con il digest pubblicato nella release. Se non coincide, o se la release non pubblica digest, **non si esegue**: si apre invece la questione, perche' un eseguibile desktop che orchestra agenti con accesso ai repository e' esattamente il tipo di componente su cui una sostituzione silenziosa avrebbe l'effetto peggiore.

Dopo l'installazione, **prima di aprire un progetto reale**, si verificano tre cose: che la sincronizzazione della collaborazione sia disattivata, che i percorsi dei worktree cadano dove ci si aspetta, e che veda entrambe le flotte di agenti.

---

## 3. Che cosa Nimbalyst risolve e che cosa no

Risolve l'**isolamento del filesystem**: piu' agenti sullo stesso repository si pestano i piedi con rami e modifiche non salvate, e i worktree danno a ciascuno la propria cartella condividendo una sola storia git. Risolve anche la **navigazione**, cioe' il problema pratico di non perdere di vista cinque sessioni aperte.

**Non risolve il problema che conta**, che e' *quando* convenga avviare piu' agenti e *quanto* costi. Nessuno degli strumenti esaminati lo fa: sono tutti lanciatori, danno la leva e non il criterio. Quel criterio e' disciplina di progetto e vive nel template, non qui.

**Non e' un prerequisito.** Due agenti collaborano benissimo senza alcun orchestratore, scambiandosi lavoro attraverso file nel repository. Nimbalyst e' comodita', non infrastruttura, e va adottato in quest'ordine: prima il metodo, poi eventualmente lo strumento che lo rende piu' comodo.

---

## 4. Impatto sul ripristino della macchina

Nimbalyst e' un'applicazione desktop installata, quindi rientra fra i componenti da reinstallare dopo una formattazione, non fra quelli ricostruibili da `Installa-Agenti.ps1`. Va censita fra il software riproducibile allo stesso titolo degli altri eseguibili presi da GitHub.

Le due flotte di agenti restano invece ricostruibili da script, come da scheda 10: Nimbalyst le **usa**, non le fornisce, e la sua assenza non impedisce di lavorare.
