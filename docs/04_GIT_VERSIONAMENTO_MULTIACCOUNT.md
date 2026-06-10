# 04 — Versionamento git multi-account (identità personale su PC aziendale)

> Convenzione di versionamento per repo **personali** su un PC aziendale dove il git **globale** ha
> l'identità di lavoro. Il principio: l'identità di lavoro resta il default globale; ogni repo personale
> **sovrascrive in locale** identità e chiave SSH, così non si mischiano mai i due account.

---

## Verdetto sul setup

Il flusso che usi è **corretto**. In sintesi del perché:

- `git config --local core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"` forza l'OpenSSH di Windows
  (quello che legge `C:\Users\<utente>\.ssh\config`) invece dell'ssh interno di Git for Windows, che
  potrebbe non trovare lo stesso `config`/le stesse chiavi. Le `/` nel percorso sono giuste per git.
- `user.name`/`user.email` in `--local` sovrascrivono il globale **solo per questo repo**: è il modo
  corretto di gestire il multi-account.
- `git remote add origin git@github-personal:<utente-github>/<repo>.git` usa l'alias SSH `github-personal`,
  che in `~/.ssh/config` punta a `github.com` con la chiave `id_ed25519_personal` → autentica come
  account personale.
- `ssh -T git@github-personal` che risponde `Hi <utente-github>!` conferma alias+chiave→account giusto.
  (Il codice di uscita 1 è normale: GitHub non dà shell.)
- Lo scenario README/licenza già sul remote con `git pull origin main --rebase` poi `git push` è
  corretto: il rebase **riapplica i tuoi commit sopra** il commit iniziale del remote → storia
  lineare, nessun commit di merge. (Con `--rebase` non serve `--allow-unrelated-histories`.)

---

## Il file `~/.ssh/config` (verifica che ci sia `IdentitiesOnly yes`)

```sshconfig
# C:\Users\<utente>\.ssh\config
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

⚠️ **`IdentitiesOnly yes` è il dettaglio che conta nel multi-account.** Senza, SSH può offrire per
prima la chiave *di lavoro* (o quella caricata nell'agent): se GitHub autentica con quella, ti ritrovi
loggato con l'account sbagliato e vedi errori tipo "repository not found". Con `IdentitiesOnly yes`
viene usata **solo** la chiave indicata. (La chiave pubblica `id_ed25519_personal.pub` dev'essere
caricata sull'account **personale** GitHub: una chiave può stare su un solo account alla volta.)

---

## Sequenza comandi (riusabile per qualsiasi repo personale)

```powershell
cd "<percorso del repo>"

git init
git branch -M main

# Identità personale + SSH di Windows, SOLO per questo repo
git config --local core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
git config --local user.name  "<utente-github>"
git config --local user.email "<email-personale>"

# Remote tramite alias personale
git remote add origin git@github-personal:<utente-github>/<nome-repo>.git

# Verifica config + che l'identità sia davvero quella personale
git config --local --list | Select-String "user\.|remote\.|core\.ssh"
ssh -T git@github-personal

git add .
git commit -m "Initial commit: <note>"

# Conferma che il commit NON sia partito con l'email di lavoro:
git log -1 --format="%an <%ae>"

git push -u origin main
```

Se il repo remoto è stato creato con README/licenza:
```powershell
git pull origin main --rebase
git push -u origin main
```
Le volte successive: `git push`.

---

## ⚠️ Caveat importante: repo dentro una cartella di sync cloud

Esempio tipico: un repo dentro la cartella locale di Google Drive. **Tenere un repo git attivo dentro una cartella
sincronizzata (Google Drive / OneDrive / Dropbox) è rischioso:** il client di sync e git scrivono sugli
stessi file di `.git\` (in particolare `index`, `packed-refs`, `objects`) e possono entrare in
conflitto, **corrompendo il repository**. Opzioni, dalla più sicura:

1. **Consigliata:** tieni il repo *fuori* dalla cartella sincronizzata (es. su `E:\`) e usa **GitHub
   come backup/sync**, non Google Drive. È esattamente ciò che fa `windows-status` su `E:\windows-status`.
2. Se proprio deve stare nel Drive: **metti in pausa la sincronizzazione** durante le operazioni git,
   oppure escludi la cartella dalla sync. Non è una soluzione robusta come la 1.

> Per i tuoi script proprietari (valore reale, storia da preservare) la 1 è la scelta giusta.

---

## Igiene multi-account (per non sbagliare mai identità)

- **Default globale "rifiuta di indovinare":** così git non committa con un'identità a caso se dimentichi
  il `--local`.
  ```powershell
  git config --global user.useConfigOnly true
  ```
  Da quel momento, in un repo senza identità locale, `git commit` si ferma e ti chiede di impostarla.

- **(Opzionale) Identità automatica per cartella**, via include condizionale nel `~/.gitconfig` globale:
  ```gitconfig
  [includeIf "gitdir/i:E:/repos-personali/"]
      path = ~/.gitconfig-personal
  ```
  con `~/.gitconfig-personal`:
  ```gitconfig
  [user]
      name = <utente-github>
      email = <email-personale>
  [core]
      sshCommand = C:/Windows/System32/OpenSSH/ssh.exe
  ```
  Tutti i repo sotto quel percorso prendono l'identità personale da soli. (`gitdir/i` = match
  case-insensitive su Windows; usa `/` e la `/` finale. Il **remote** con l'alias resta comunque
  da impostare per repo.)

---

## Contesto per Claude Code

Quando crei o versioni un repo **personale** su questa macchina, segui questa convenzione:

1. **Non usare mai l'identità globale (di lavoro)** per un repo personale. Imposta sempre in `--local`
   `user.name`, `user.email` e `core.sshCommand` (OpenSSH di Windows).
2. **Remote sempre con l'alias** `git@github-personal:<utente-github>/<repo>.git` (mai HTTPS con credenziali
   di lavoro, mai l'alias aziendale).
3. **Dopo il primo commit, verifica** `git log -1 --format="%an <%ae>"`: dev'essere l'email personale.
   Se è quella di lavoro, correggi prima di pushare (`git commit --amend --reset-author` dopo aver
   sistemato la config locale).
4. **Non inizializzare/usare repo dentro cartelle di sync cloud** (Google Drive/OneDrive/Dropbox):
   proponi un percorso fuori dalla sync e usa GitHub come backup.
5. Repo che descrivono l'infrastruttura → **privati** finché contengono riferimenti sensibili; prima
   di ogni push verifica che non ci siano segreti (vale il `.gitignore` del progetto).
