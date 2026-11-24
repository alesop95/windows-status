# 19 - Recupero delle sessioni degli agenti dopo un crash dei terminali

Ultimo aggiornamento: 2026-11-24.

Questo documento descrive che cosa fare quando le sessioni degli agenti da terminale si chiudono tutte insieme per un guasto e non per una chiusura voluta: come si recuperano le trascrizioni che il wipe di fine sessione ha cancellato, in che ordine si riavvia la macchina e come si riprende ciascuna sessione dal punto in cui si era fermata. Gli strumenti sono `scripts/Recupera-DaShadow.ps1` e `scripts/Riapri-Sessione.ps1`. La procedura nasce dall'incidente del 24/11/2026 ed è stata scritta prima di averne di nuovo bisogno, perché in quell'occasione è stata costruita a mano, sotto pressione, e il recupero è riuscito soltanto per una coincidenza di orari.

## 1. Il fatto del 24/11/2026

Una scorciatoia di tastiera appena installata, che apre un terminale amministratore senza conferma del Controllo dell'account utente[^1] (`scripts/Scorciatoia-TerminaleAdmin.ps1`), è stata premuta sette volte fra le 13:35 e le 13:55. Alle 13:56:03 i processi ospitati in Windows Terminal sono usciti tutti con il codice 0xC000013A, che indica la chiusura della console: due servizi in background e cinque sessioni di agenti, quattro di Claude Code e una di Codex, chiuse entro le 13:59. Sono sopravvissuti soltanto VS Code e un terminale elevato aperto giorni prima.

Ciò che è misurato viene dai registri dell'Utilità di pianificazione e del runtime delle app e dai diari del wipe dei tre account. Ciò che non è misurato è il meccanismo: Windows Terminal non registra la propria chiusura, quindi che il crash venga dalle istanze elevate aperte dalla scorciatoia è un'inferenza dalla sequenza temporale. Dopo il riavvio la scorciatoia è stata riprovata con una sola pressione e una scheda fittizia aperta accanto, e la scheda è sopravvissuta: è sana nell'uso singolo, ma la pressione ripetuta con molte sessioni aperte non è stata riprodotta.

## 2. Perché un crash dei terminali diventa una perdita

Un crash dei terminali da solo non perde lavoro: i file dei progetti sono su disco e le modifiche non committate restano dove sono. Il danno lo fa il passo successivo. Alla chiusura di ogni sessione di Claude Code scatta l'hook `SessionEnd`, che su questa macchina esegue il wipe dell'account: cancella con una rimozione definitiva, senza cestino, le trascrizioni di tutte le sessioni chiuse e conserva soltanto quelle ancora aperte. L'hook non distingue una chiusura voluta da un crash, quindi quando le sessioni muoiono tutte insieme cancella proprio le conversazioni che servivano per riprenderle. Il 24/11 le trascrizioni di Claude Code dei tre account erano sparite in tre minuti.

Le trascrizioni di Codex non le tocca nessun hook, perché la pulizia di Codex la fa il lanciatore quando il processo esce in modo ordinario oppure `Pulisci-Codex.ps1`, e un crash non passa da nessuno dei due. Il 24/11 sono sopravvissute integre.

Ciò che una trascrizione recuperata non contiene lo coprono soltanto i file di ripresa che ogni sessione scrive su disco a ogni giro di lavoro. Il 24/11 i progetti che li avevano aggiornati da pochi minuti hanno avuto un danno nullo, quelli fermi alla mattina no.

## 3. I primi minuti: che cosa non fare

Finché il recupero non è finito non si chiude nessuna altra sessione di Claude Code e non si lancia il wipe a mano, perché ogni `SessionEnd` cancella di nuovo ciò che appartiene a sessioni chiuse. Non si lancia `Pulisci-Codex.ps1 -Tutto`, che toglierebbe le sessioni Codex sopravvissute. Non si interrompe un backup Veeam in corso, perché la sua copia shadow è con buona probabilità l'unico posto dove le trascrizioni esistono ancora. E non si usa ciò che si sospetta abbia causato il crash, nemmeno per aprire il terminale amministratore che serve al recupero: lo si apre dal menu Start con «Esegui come amministratore».

## 4. Il recupero delle trascrizioni dalla copia shadow

Una copia shadow[^2] è un'istantanea in sola lettura di un volume a un certo istante. Veeam Agent ne crea una all'avvio di ogni backup a livello di volume e la tiene finché il backup gira; Windows ne tiene altre per i punti di ripristino. Se esiste una copia del volume del profilo creata prima del crash, le trascrizioni come erano in quel momento stanno lì dentro. Il 24/11 il backup era partito alle 13:45 ed era ancora in corso, e la sua copia delle 13:46 ha restituito tutte le sessioni. Un'ora e mezza dopo, a backup finito, quella copia non esisteva più: la finestra utile dura quanto il backup.

Da un PowerShell amministratore, prima senza scrivere niente per vedere quale copia verrebbe usata:

```powershell
cd "E:/windows-status"
.\scripts\Recupera-DaShadow.ps1 -Prima "2026-11-24 13:56"
.\scripts\Recupera-DaShadow.ps1 -Prima "2026-11-24 13:56" -Destinazione "D:/recupero" -Applica
```

`-Prima` è l'ora del crash: lo script sceglie la copia più recente creata prima di quell'ora. Con `-Applica` monta quella copia attraverso un collegamento simbolico temporaneo nella radice del disco di sistema, copia le cartelle delle sessioni di ogni radice degli agenti che trova nel profilo (`.claude`, `.claude-accountN`, `.codex`, `.codex-accountN`) in una cartella datata dentro `-Destinazione`, toglie il collegamento e stampa l'elenco delle sessioni recuperate con radice, id, ora dell'ultimo messaggio e cartella di progetto. Non scrive nelle radici degli agenti e non tocca né la copia shadow né il backup. Rifiuta una destinazione dentro una radice degli agenti o nella cartella temporanea, che il wipe ripulisce, e una destinazione che contiene una cartella con il nome di una radice, che la corsa successiva scambierebbe per una radice vera; consiglia un disco diverso da quello del profilo.

Se lo script esce con codice 2 non c'è una copia anteriore al crash. La via che resta è il ripristino a livello di file di Veeam Agent dal punto di backup più recente anteriore al crash, con gli stessi percorsi e una destinazione fuori dal profilo; dipende dalla velocità di lettura dal NAS, che quel giorno era bassa.

In ogni caso mancano i minuti fra l'istante della copia e il crash. Il 24/11 erano dieci-tredici minuti per sessione.

## 5. Lo stato di ogni progetto prima di riavviare

Prima di riavviare conviene fissare in una tabella, progetto per progetto, quattro cose: quale agente e quale account ci lavorava, se la trascrizione è integra o recuperata e fino a che ora arriva, l'ora dell'ultimo file di ripresa e del work-log, e quanti file non committati ci sono. È la tabella da cui si scrive poi il messaggio di ripresa di ciascuna sessione, e permette di vedere subito dove il buco è nullo e dove no.

| Progetto | Agente e account | Trascrizione fino alle | Ripresa e work-log su disco | Non committati |
|---|---|---|---|---|
| `<progetto>` | `<agente>`, account N | integra / recuperata, `hh:mm` | ripresa `hh:mm`, work-log `hh:mm` | N |

## 6. Prima del riavvio

Ogni sessione ancora viva chiude il proprio lavoro in modo ordinario: aggiorna il file di ripresa, propone il commit e il proprietario lo esegue. Poi le sessioni Claude Code si chiudono con `/exit` e si lancia il wipe a mano, che a quel punto cancella soltanto ciò che è già stato messo al sicuro. Il backup in corso si lascia finire se si può: se il riavvio lo interrompe, lo rifà il giro successivo. Poi gli aggiornamenti in sospeso e il riavvio, che su questa macchina decide ed esegue soltanto il proprietario.

## 7. Dopo il riavvio, in quest'ordine

Prima si prova la modifica sospettata del crash, con nessuna sessione di lavoro aperta. Si apre un terminale normale con una scheda fittizia, per esempio `ping -t 127.0.0.1`, si esegue una volta l'azione sospetta, si aspetta un minuto e si guarda se la scheda fittizia è ancora viva. Se è morta la modifica si toglie subito, dal suo comando di annullamento lanciato da un terminale aperto per un'altra via. La stessa regola vale per qualunque modifica futura che tocchi il terminale o la shell condivisa da tutte le sessioni: si prova con una scheda fittizia accanto e senza sessioni di lavoro attive, mai mentre ci sono.

Poi si riprendono le sessioni Codex, prima di aprirne di nuove, ciascuna in una finestra PowerShell normale sua, dalla cartella del progetto e con il comando dell'account che la ospitava:

```powershell
cd "<cartella del progetto>"
codex-accountN resume <id>
```

Se `resume` risponde che la sessione non esiste, la trascrizione recuperata va rimessa nella stessa posizione sotto la radice dell'account; `Riapri-Sessione.ps1 -Id <id>` lo fa e stampa il comando.

Poi le sessioni Claude Code, una alla volta e ciascuna in una finestra PowerShell normale nuova. Senza `-Id` lo script elenca ciò che c'è nella cartella di recupero; con `-Id` rimette quella sola trascrizione nella radice d'origine, senza sovrascrivere un file presente, insieme alla cartella dei suoi subagent, e riapre subito la sessione con il lanciatore del template, nella cartella di progetto letta dalla trascrizione stessa:

```powershell
cd "E:/windows-status"
.\scripts\Riapri-Sessione.ps1 -Recupero "D:/recupero/recupero-sessioni-<data>"
.\scripts\Riapri-Sessione.ps1 -Recupero "D:/recupero/recupero-sessioni-<data>" -Id <id>
```

Una alla volta perché il wipe conserva soltanto le sessioni aperte: una trascrizione rimessa a posto e non riaperta sparisce alla prima chiusura di un'altra sessione, di qualunque account, perché il wipe di ciascun account ripulisce tutte le sessioni chiuse. `-SoloComando` rimette il file e stampa il comando di avvio invece di eseguirlo.

A ogni sessione riaperta si dà un messaggio che le dice quattro cose: che è stata chiusa da un crash e non in modo ordinario, fino a che ora arriva la conversazione recuperata, quali file sono stati scritti dopo quell'ora con la loro ora (file di ripresa, work-log, file non committati), e che cosa le si chiede, cioè rileggerli, dire che cosa è successo fra la fine della conversazione e il crash e che cosa non risulta da nessuna parte, e poi riprendere. Per esempio:

```text
Sei stata riaperta dopo un crash dei terminali delle <hh:mm>. La conversazione recuperata si ferma alle <hh:mm>. Dopo hai scritto _notes/RESUME-PROMPT.md (<hh:mm>) e .claude/memory/progress.md (<hh:mm>), e ci sono <N> file non committati. Rileggili, dimmi che cosa è successo fra le <hh:mm> e le <hh:mm> e che cosa non risulta da nessuna parte, poi riprendi.
```

Per ultima si apre, se serve, una sessione nuova sul progetto che ha registrato l'incidente.

## 8. Il buco degli ultimi minuti

Fra l'istante della copia shadow e il crash c'è sempre un intervallo che nessuna trascrizione recuperata contiene. Lo coprono soltanto i file che la sessione ha scritto su disco in quei minuti: il file di ripresa, il work-log, le modifiche ai file del progetto. Per questo a ogni sessione riaperta si chiede di confrontare l'ultimo messaggio recuperato con quei file e di dire che cosa manca, invece di riprendere dalla conversazione come se fosse completa. Una decisione presa a voce in quei minuti e mai scritta non è ricostruibile: si chiede al proprietario se ce ne fosse una.

## 9. Quando è finito, e che cosa cambierà

Quando tutte le sessioni sono riaperte e hanno ricostruito il proprio buco, la cartella di recupero si può tenere come archivio dell'incidente oppure cancellare: contiene trascrizioni complete e configurazioni degli account, quindi non va lasciata su un disco condiviso.

La lezione generale è salita al template, che ne farà una versione stabile nel pacchetto `agenti-terminale`: un wipe che distingue la chiusura voluta dal crash e, nel secondo caso, sposta le trascrizioni in una quarantena datata invece di cancellarle, e i due strumenti di questo documento in forma generale. Quando arriveranno, `Recupera-DaShadow.ps1` e `Riapri-Sessione.ps1` diventeranno chiamate al template, come già `scripts/Agenti.ps1`, e questo documento si aggiornerà di conseguenza.

[^1]: *UAC*, User Account Control - la conferma che Windows chiede prima di avviare un programma con i privilegi di amministratore.

[^2]: *VSS*, Volume Shadow Copy Service - il servizio di Windows che crea le copie shadow, usato dai programmi di backup per leggere un volume coerente mentre è in uso.
