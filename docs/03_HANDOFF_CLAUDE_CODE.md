# 03 — Handoff a Claude Code su `E:\windows-status`

Quando vuoi che l'assistente lavori **sulla macchina** (legge lo stato reale, aggiorna la mappa, genera comandi sui dati veri), passi a **Claude Code** dentro il progetto. Il file `CLAUDE.md` (già nella cartella) gli dà contesto e paletti di sicurezza: non serve riscriverlo.

> Da fare **dopo** Fasi 1–5 (mappatura, paracadute, pulizia, re-mappatura, backup+test).

---

## A. Prerequisiti
- Piano Claude a pagamento (**Pro** o **Max**) **oppure** una API key da console Anthropic (Claude Code non è nel piano gratuito).
- **Git for Windows** (git-scm.com, default, "Add Git to PATH" attivo). Claude Code usa Git Bash internamente anche se lo lanci da PowerShell.

## B. Installazione (Windows 11 nativo, consigliata)
In **PowerShell**:
```powershell
irm https://claude.ai/install.ps1 | iex
```
Chiudi e riapri il terminale (per il PATH), poi verifica:
```powershell
claude --version
```
Alternativa con WinGet (stesso binario nativo, aggiornamento manuale):
```powershell
winget install --id Anthropic.ClaudeCode
```
Al primo avvio `claude` chiede l'autenticazione. `claude doctor` diagnostica l'installazione. (L'installazione nativa si aggiorna da sola in background.)

## C. Aprire il progetto
```powershell
cd E:\windows-status
claude
```
Claude Code legge automaticamente `CLAUDE.md` come contesto e regole.

## D. Versionamento (git + GitHub, identità personale)
> Convenzione completa in `04_GIT_VERSIONAMENTO_MULTIACCOUNT.md`. In breve, per questo repo personale:
```powershell
cd E:\windows-status
git init
git branch -M main

# identità personale + SSH di Windows, solo per questo repo
git config --local core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
git config --local user.name  "<utente-github>"
git config --local user.email "<email-personale>"
git remote add origin git@github-personal:<utente-github>/windows-status.git

git add .
git commit -m "Initial commit: windows-status"
git log -1 --format="%an <%ae>"     # deve mostrare l'email personale
ssh -T git@github-personal          # deve rispondere: Hi <utente-github>!

git push -u origin main
# se il repo remoto ha gia README/licenza:
#   git pull origin main --rebase
#   git push -u origin main
```
- `snapshots/` è ignorata da git (`.gitignore`): i dati della macchina restano locali.
- **Prima di ogni push**, specie su repo pubblico, verifica che nessun file contenga segreti o dati sensibili. Gli snapshot oscurano i segreti, ma una copia *compilata* della mappa potrebbe averne.

## E. Primi compiti utili da chiedere a Claude Code
- *"Esegui lo snapshot di sola lettura e dimmi cosa è cambiato rispetto al precedente"* (usa `Compare-Snapshot.ps1`).
- *"Aggiorna le sezioni 🔄 della mappa con l'ultimo snapshot, senza toccare le ✍️."*
- *"Dall'export WinGet genera i comandi per reinstallare tutto su un PC nuovo."*
- *"Elenca gli account che possono accedere e segnala quelli non presenti nella mappa."*
- *"Per ogni account riepiloga la config di Claude e git trovata negli snapshot."*
- *"Prepara la checklist di verifica post-ripristino Veeam per macchina Entra ID joined."*

## F. Igiene
- Tieni il repo **privato** finché contiene riferimenti alla tua infrastruttura.
- Conferma sempre i comandi che modificano il sistema prima di lasciarli eseguire (vedi `CLAUDE.md`).
- Commit dopo ogni sessione importante: avrai lo storico esatto della mappa nel tempo.

> Per dettagli ufficiali e aggiornati su installazione/uso di Claude Code, fai riferimento alla documentazione ufficiale Anthropic.

## G. Server MCP a livello di account

Claude Code supporta server MCP a due livelli distinti: *progetto* e *account*.

Il livello *progetto* usa `.mcp.json` nella root del repo (versionato, attivo solo nelle sessioni aperte in quel progetto). Il livello *account* usa un file globale attivo in tutte le sessioni, indipendentemente dal progetto aperto.

### Claude Code CLI

Il file di configurazione account-level è `%USERPROFILE%\.claude-<nome-profilo>\mcp.json`. Su questa macchina sono presenti più profili Claude Code (uno per identità/account); ogni profilo ha il proprio `mcp.json` indipendente.

Formato consigliato per un server MCP distribuito come pacchetto npm: il pacchetto si installa una volta, a livello globale e con la versione fissata, e il config lancia `node.exe` sul file d'ingresso con il percorso assoluto.

```powershell
npm install -g <pacchetto-npm>@<versione>
```

```json
{
  "mcpServers": {
    "<nome-server>": {
      "command": "C:\\Program Files\\nodejs\\node.exe",
      "args": [
        "<%APPDATA%>\\npm\\node_modules\\<pacchetto-npm>\\dist\\index.js",
        "<percorso-1>", "<percorso-2>"
      ]
    }
  }
}
```

Nota: il file usa `mcpServers` come chiave radice (non `servers`). I percorsi nei `args` sono assoluti, e nel JSON `%APPDATA%` non viene espanso: va scritto per esteso. Il file d'ingresso è quello indicato dal campo `bin` del `package.json` del pacchetto.

Perché non `cmd /c npx -y <pacchetto>`, che era la forma documentata qui fino al 2026-10-12. Senza versione, npx a ogni avvio chiede al registro l'ultima release e, se ne trova una nuova, reinstalla nella sua cache `%LOCALAPPDATA%\npm-cache\_npx\<hash>`. L'hash dipende solo dal nome del pacchetto, quindi la cartella è una sola per tutti i client che lanciano lo stesso server: l'app desktop, che a ogni avvio ne fa partire più istanze, e ogni profilo di Claude Code. Il 2026-10-12, all'uscita della 1.0.0 di `@modelcontextprotocol/server-filesystem`, tre npx partiti nello stesso secondo hanno reinstallato in parallelo nella stessa cartella. Windows tiene bloccati i file in uso, e sono usciti EBUSY, ENOTEMPTY, EPERM ed ENOENT: il server non è ripartito né per l'app né per le sessioni di Claude Code. La forma `npx -y <pacchetto>@<versione>` riduce il rischio ma non lo toglie, perché la prima installazione resta comunque una corsa fra client. L'installazione globale non ha corse: si fa una volta, da terminale, e i client leggono soltanto.

Il prezzo è che gli aggiornamenti diventano manuali: si ripete `npm install -g <pacchetto-npm>@<nuova-versione>` con l'app chiusa, e si verifica che il file d'ingresso non abbia cambiato percorso.

### App claude.ai desktop (Windows Store, MSIX)

Il file di configurazione è separato da quello del CLI e si trova in:
```
%LOCALAPPDATA%\Packages\Claude_<id-pacchetto>\LocalCache\Roaming\Claude\claude_desktop_config.json
```
Il pacchetto MSIX ha un identificatore variabile (`Claude_pzs8sxrjxfjjc` su questa macchina). Il path esatto si trova cercando `claude_desktop_config.json` sotto `%LOCALAPPDATA%\Packages\`.

L'app legge il file all'avvio. Modifiche al file diventano effettive solo dopo un riavvio completo, inclusa la chiusura dell'icona nel system tray. Il pulsante "Modifica configurazione" in Settings → Sviluppatore → Server MCP locali apre lo stesso file per la modifica; non esiste una UI con campi editabili separati.

### Ripristino su macchina nuova

Per ripristinare i server MCP account-level su una macchina diversa:
1. Installare i pacchetti dei server a livello globale, con la versione fissata (oggi `npm install -g @modelcontextprotocol/server-filesystem@1.0.0`).
2. Creare i file `mcp.json` nei profili Claude Code presenti in `%USERPROFILE%\.claude-<profilo>\`.
3. Aggiornare `claude_desktop_config.json` prima di avviare la app claude.ai desktop.
4. Verificare che i percorsi nei `args`, compreso il file d'ingresso del pacchetto, esistano sulla nuova macchina prima del primo avvio.

I server MCP account-level non vengono catturati dallo snapshot di questo progetto perché i file contengono percorsi specifici della macchina; vanno ricreati manualmente al ripristino.

## H. Instradamento dei modelli a livello di account

Dal 2026-10-12 i profili Claude Code di questa macchina instradano il lavoro meccanico dei subagent su modelli più economici. L'impianto è lo stesso del livello *account* descritto nella sezione G: la logica vive in un posto solo, fuori dai profili, e ciò che cambia da un profilo all'altro è un file di configurazione.

La logica è una mod di Claude Code che sta nel progetto `template-claude-developing`, sotto `.claude\templates\instradamento-modelli\mod`, e non viene copiata nei profili: ogni profilo la carica da quel percorso tramite `env.CLAUDE_CODE_PLUGIN_DIRS` nel proprio `settings.json`. Due copie divergerebbero in silenzio; una registrazione punta sempre alla versione corrente.

La configurazione è il file `%USERPROFILE%\.claude-<profilo>\instradamento-modelli.json`. I tre profili hanno oggi lo stesso contenuto: modo `instrada`, e una tabella che manda su Haiku con ragionamento basso i tipi di agente il cui lavoro è meccanico (`Explore`, `statusline-setup`, `lettore-documentazione`) e su Sonnet con ragionamento basso o medio quelli intermedi (`claude-code-guide`, `general-purpose`). I tipi che richiedono giudizio, fra cui `code-reviewer` e `security-auditor`, restano fuori dalla tabella di proposito: non vengono instradati.

Perché l'instradamento abbia qualcosa da instradare serve una seconda impostazione, ed è la metà che si dimentica. L'agente non apre subagent di propria iniziativa se un file di istruzioni non glielo consente, quindi il `CLAUDE.md` di ciascun profilo porta una sezione che lo autorizza a delegare il lavoro meccanico e gli vieta di delegare quello che richiede giudizio. Senza quella sezione la tabella resta scritta e non passa di lì nessuno.

Verifica in sola lettura, dal progetto del template, che dice profilo per profilo se la mod è registrata e in che modo si trova:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".claude/templates/instradamento-modelli/tools/installa-instradamento.ps1" -Verifica -IncludiDefault
```

Dentro una sessione, `/instradamento` scrive il modo corrente, la tabella, quanti subagent sono stati instradati e i token consumati per modello; `/instradamento osserva` e `/instradamento spento` cambiano il modo per quella sessione sola, senza toccare il file. I conteggi cumulati stanno nello store del plugin, condiviso fra le sessioni della macchina, e sono un libro mastro: per il consumo fatturato resta `ccusage`.

### Ripristino su macchina nuova

Come per i server MCP, questi file non entrano nello snapshot perché contengono percorsi specifici della macchina. Al ripristino: clonare `template-claude-developing`, poi lanciare `installa-instradamento.ps1` una volta per profilo, che scrive la configurazione di partenza (modo `osserva`) e registra il percorso della mod nel `settings.json` di quel profilo; poi portare il modo a `instrada` e riscrivere la tabella; infine ricopiare nel `CLAUDE.md` di ogni profilo la sezione che autorizza la delega. Per tornare indietro basta rimettere `"modo": "osserva"`, che misura senza instradare, oppure `"spento"`.

## I. Riserva dei subagent e plugin, per tutte le radici dei due agenti

Dal 2026-11-16 due scelte valgono per tutte le radici di account della macchina, tre di Claude Code e tre di Codex, e sono scritte in un file solo di questo repository, `scripts/agenti-macchina.json`: la riserva dei subagent e i plugin da avere installati.

La riserva è la percentuale del limite del piano oltre la quale i subagent non partono più, così che il resto della finestra resti al lavoro in prima persona. Su questa macchina è l'ottanta per cento della finestra settimanale, e, dal pomeriggio del 2026-11-16, l'ottanta per cento anche della finestra delle cinque ore, con azione `nega`. La seconda soglia è entrata dopo che sette subagent avviati insieme hanno esaurito proprio quella finestra, che la riserva non guardava. In Claude Code la attua la mod di instradamento della sezione H, che legge la percentuale dal motore dentro la sessione e nega lo spawn con il motivo: il valore sta nel campo `riservaAgenti` di `instradamento-modelli.json` di ogni profilo. In Codex la attua il wrapper `Avvia-Codex.ps1`: all'uscita registra l'ultima lettura dei limiti dalle sessioni, prima che la pulizia le cancelli, e all'avvio successivo, se la soglia è passata e la finestra non si è ancora azzerata, parte con `--disable multi_agent`. Il valore sta in `riserva-agenti.json` di ogni radice Codex e la lettura in `riserva-ultima-lettura.json`. Una sessione Codex avviata senza il wrapper non ha riserva.

Il plugin è `superpowers`, installato il 2026-11-16 nelle sei radici: versione 7.0.2 dal marketplace ufficiale in Claude Code, 7.0.1 dal catalogo curato in Codex. La mappa fra le sue skill e il sistema di progetto, con i tre punti in cui prevale la regola del progetto, sta nel template, in `.claude/templates/superpowers/README.md`.

Lo stato si legge e si riapplica con i comandi della catena degli agenti, lanciati dalla radice di questo repository perché è da qui che il file dei valori viene trovato:

```powershell
.\scripts\Agenti.ps1 verifica
.\scripts\Agenti.ps1 installa
```

Il primo non scrive niente e mostra, in fondo, soglie, ultima lettura per radice Codex e plugin presenti o mancanti. Il secondo riscrive la soglia dove manca e installa i plugin dove mancano; rieseguirlo non cambia niente. Per cambiare la soglia si cambia il file dei valori e si rilancia.

Durante l'installazione è emerso un difetto del profilo `claude-account3`: il suo `known_marketplaces.json` puntava alla cartella dei marketplace del profilo 2, e il gestore dei plugin rifiutava di aggiornare il catalogo. È stato sanato come il gestore stesso indica, togliendo e riaggiungendo il marketplace ufficiale in quel profilo e reinstallando il plugin; la copia del file precedente è accanto, con il suffisso `.prima-del-16-11`.

### Che cosa non è stato osservato

La riserva di Claude Code è provata contro il motore simulato dalle prove della mod, non in una sessione oltre soglia. Quella di Codex è stata provata sulle letture reali delle tre radici, e il 2026-11-16 dichiarava i subagent spenti per `codex-account1`, la cui ultima lettura portava la finestra settimanale al cento per cento; non è stato osservato dall'interno di una sessione che con `--disable multi_agent` Codex non apra altri agenti, oltre a ciò che dice `codex features list`.
