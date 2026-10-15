# Leggimi — PC nuovo

> Questo file sta in radice perche' e' il primo che deve vedere chi apre la cartella su una macchina appena accesa. La sequenza completa, con il perche' di ogni passo, sta in `docs/16`. Qui c'e' solo l'ordine delle cose e cosa serve avere sottomano.

## Prima di cominciare: tre cose da portare

Il progetto da solo non basta su un PC vergine, e due dei pezzi mancanti non possono stare nel repository.

1. **Il progetto.** `git clone https://github.com/alesop95/windows-status.git`, oppure una copia su chiavetta.
2. **Gli strumenti di terze parti.** Si scaricano al volo (serve rete) oppure si portano gia' verificati sulla chiavetta.
3. **`software_winget.json`**, se vuoi reinstallare i programmi della macchina vecchia. Nasce da uno snapshot di *quella* macchina e `snapshots/` e' ignorata da git: va copiato a mano.

Dalla macchina vecchia, `scripts\Prepara-Chiavetta.ps1` mette tutti e tre in una cartella sola:

```powershell
.\scripts\Prepara-Chiavetta.ps1 -Destinazione E:\
```

Sul PC nuovo quella cartella basta a se stessa: niente rete, niente git.

## La sequenza

```powershell
# sul PC nuovo, PowerShell COME AMMINISTRATORE, nella cartella del progetto
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Avvia.ps1          # voce P: percorso guidato
```

| # | Passo | Dove | Automatico? |
|---|---|---|---|
| 1 | Copiare il progetto sul PC | a mano | no |
| 2 | **Immagine di sistema della macchina vergine** | Veeam, `docs/02` | no, e non si salta |
| 3 | Piano e prerequisiti | `Avvia.ps1` voce 9 | si, sola lettura |
| 4 | Strumenti: scarica e verifica i digest | voce 9s | si, sola lettura |
| 5 | Catena: fotografia, paracadute, AI | voce 9a | guidato, conferma per passo |
| 6 | **Riavvio** | a mano | no, mai automatico |
| 7 | Catena: debloat, monitoraggio | voce 9a | guidato, conferma per passo |
| 8 | **Riavvio** | a mano | no |
| 9 | Controllo residui e confronto delle due fotografie | voce 9c | si, sola lettura |
| 10 | Reinstallazione programmi da WinGet | voce 5 | serve `software_winget.json` |
| 11 | Baseline di sicurezza: prima il report, poi l'applicazione | voci 3 e 4 | guidato |
| 12 | Identita' git, chiavi SSH, Claude e Codex, dotfiles | `docs/03`, `04`, `10` | no, per scelta |

Il passo 12 non e' automatizzabile **per costruzione**: il paletto 5 del progetto vieta i segreti nel repository, quindi non c'e' niente da ripristinare da solo. I documenti dicono dove sono custoditi e in che ordine rimetterli.

## Il profilo: togliere i menu, non le conferme

Senza profilo i tre strumenti aprono ciascuno la propria interfaccia, e su ogni PC nuovo si rifanno le stesse scelte a mano. Con un profilo le scelte sono gia' scritte:

```powershell
copy .\scripts\prima-installazione\profilo.esempio.json .\scripts\prima-installazione\profilo.json
# si adatta, poi la catena lo trova da sola
```

Il profilo toglie le interfacce di terze parti. **Non toglie le conferme**: ogni passo che modifica chiede `SI`, perche' quello e' il paletto 1 del progetto. `profilo.json` e' ignorato da git perche' puo' contenere il token di Netdata.

## Le tre cose da sapere prima di premere invio

**RemoveWindowsAI e' reversibile solo in parte.** La catena gli passa sempre `-backupMode`, che esporta le chiavi dei servizi cancellati e crea un punto di ripristino, e il suo `-revertMode` le rimette. Ma i pacchetti rimossi — appx, CBS, file — non li salva nessuno. Per quelli il ritorno indietro e' l'immagine del passo 2.

**Netdata non si installa da solo, e c'e' un motivo.** Su Windows, con il piano gratuito Community, il cruscotto locale su `localhost:19999` e' bloccato: l'agente raccoglie ma i dati si guardano su Netdata Cloud. Senza token non vedi niente; con il token le metriche della macchina escono verso un servizio di terzi. E' una decisione da prendere, quindi sta nel profilo a `false` e non parte se non lo si scrive.

**Su macchina aziendale la catena si ferma.** Dominio, tenant o MDM: serve `-ForzaAziendale`, perche' le opzioni dei due strumenti toccano Windows Update, telemetria e cifratura automatica, cioe' cio' che il paletto 4 vieta senza un ordine esplicito.

## Se qualcosa non torna

Il digest di uno strumento non corrisponde: la catena si ferma e **va bene cosi'**. Vuol dire che il progetto a monte e' cambiato o che il file e' stato alterato. La risposta non e' aggiornare il manifesto: e' guardare perche'. La procedura per aggiornare una versione di proposito sta in `docs/16`.
