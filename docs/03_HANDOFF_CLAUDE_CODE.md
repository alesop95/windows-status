# 03 — Handoff a Claude Code su `E:\windows-status`

Quando vuoi che l'assistente lavori **sulla macchina** (legge lo stato reale, aggiorna la mappa, genera
comandi sui dati veri), passi a **Claude Code** dentro il progetto. Il file `CLAUDE.md` (già nella
cartella) gli dà contesto e paletti di sicurezza: non serve riscriverlo.

> Da fare **dopo** Fasi 1–5 (mappatura, paracadute, pulizia, re-mappatura, backup+test).

---

## A. Prerequisiti
- Piano Claude a pagamento (**Pro** o **Max**) **oppure** una API key da console Anthropic
  (Claude Code non è nel piano gratuito).
- **Git for Windows** (git-scm.com, default, "Add Git to PATH" attivo). Claude Code usa Git Bash
  internamente anche se lo lanci da PowerShell.

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
Al primo avvio `claude` chiede l'autenticazione. `claude doctor` diagnostica l'installazione.
(L'installazione nativa si aggiorna da sola in background.)

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
- **Prima di ogni push**, specie su repo pubblico, verifica che nessun file contenga segreti o dati
  sensibili. Gli snapshot oscurano i segreti, ma una copia *compilata* della mappa potrebbe averne.

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

> Per dettagli ufficiali e aggiornati su installazione/uso di Claude Code, fai riferimento alla
> documentazione ufficiale Anthropic.

## G. Server MCP a livello di account

Claude Code supporta server MCP a due livelli distinti: *progetto* e *account*.

Il livello *progetto* usa `.mcp.json` nella root del repo (versionato, attivo solo nelle
sessioni aperte in quel progetto). Il livello *account* usa un file globale attivo in tutte le
sessioni, indipendentemente dal progetto aperto.

### Claude Code CLI

Il file di configurazione account-level è `%USERPROFILE%\.claude-<nome-profilo>\mcp.json`.
Su questa macchina sono presenti più profili Claude Code (uno per identità/account); ogni
profilo ha il proprio `mcp.json` indipendente.

Formato:
```json
{
  "mcpServers": {
    "<nome-server>": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "<pacchetto-npm>", "<percorso-1>", "<percorso-2>"]
    }
  }
}
```

Nota: il file usa `mcpServers` come chiave radice (non `servers`). I percorsi nei `args` sono
assoluti. Usare `cmd /c npx` su Windows anziché `npx` diretto, per evitare problemi di PATH.

### App claude.ai desktop (Windows Store, MSIX)

Il file di configurazione è separato da quello del CLI e si trova in:
```
%LOCALAPPDATA%\Packages\Claude_<id-pacchetto>\LocalCache\Roaming\Claude\claude_desktop_config.json
```
Il pacchetto MSIX ha un identificatore variabile (`Claude_pzs8sxrjxfjjc` su questa macchina).
Il path esatto si trova cercando `claude_desktop_config.json` sotto `%LOCALAPPDATA%\Packages\`.

L'app legge il file all'avvio. Modifiche al file diventano effettive solo dopo un riavvio
completo, inclusa la chiusura dell'icona nel system tray. Il pulsante "Modifica configurazione"
in Settings → Sviluppatore → Server MCP locali apre lo stesso file per la modifica; non esiste
una UI con campi editabili separati.

### Ripristino su macchina nuova

Per ripristinare i server MCP account-level su una macchina diversa:
1. Creare i file `mcp.json` nei profili Claude Code presenti in `%USERPROFILE%\.claude-<profilo>\`.
2. Aggiornare `claude_desktop_config.json` prima di avviare la app claude.ai desktop.
3. Verificare che i percorsi nei `args` esistano sulla nuova macchina prima del primo avvio.

I server MCP account-level non vengono catturati dallo snapshot di questo progetto perché i
file contengono percorsi specifici della macchina; vanno ricreati manualmente al ripristino.
