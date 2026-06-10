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
