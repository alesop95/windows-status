# 14 - Design system ereditato da un account

> Come si fa in modo che ogni account degli agenti da terminale, su questa macchina, disegni con lo stesso design system invece che con la palette che si ricorda. Il documento descrive la capacita' in astratto: quale sia il design system di questa macchina non e' scritto qui, perche' questo repository e' pubblico e resta anonimo. Il valore reale vive in `CLAUDE.local.md`, ignorato da git.

## Il problema

Un agente che genera una pagina, un export o un mock sceglie i colori e la tipografia da qualcosa. Se quel qualcosa e' un file prodotto in una sessione precedente, il marchio si degrada per copie successive: la seconda pagina eredita gli errori della prima, la terza quelli della seconda, e nessuno se ne accorge finche' qualcuno mette due artefatti accanto. Se invece e' un pacchetto con i token, i font e le regole, l'agente ha una fonte, e la fonte si aggiorna in un posto solo.

Il secondo problema e' la moltiplicazione delle radici. Su questa macchina convivono piu' account di Claude Code e piu' account di Codex, ciascuno con la propria radice di configurazione nel profilo utente e con un proprio file di istruzioni letto a inizio sessione. Una skill installata a mano in una radice vale per quella radice soltanto, e la divergenza non emette nessun errore: semplicemente, due account dello stesso utente disegnano in modo diverso.

## La forma della soluzione

Il design system si confeziona come un pacchetto skill, cioe' una cartella con un `SKILL.md` in testa, il cui frontmatter dichiara `name` e `description`, e accanto tutto il resto: token di colore, tipografia e spaziatura, font, loghi, icone, componenti, regole scritte. Che cosa contenga oltre al `SKILL.md` non riguarda questa capacita': conta che sia una cartella autonoma e che il suo nome e la sua descrizione si leggano dal pacchetto stesso.

Di quel pacchetto esiste una sola copia reale, nel magazzino di macchina, che per default e' `.design-systems` nel profilo utente. Ogni radice di account riceve un collegamento di cartella, cioe' una junction, dentro la propria sottocartella `skills`. Il collegamento non duplica i byte: aggiornare il pacchetto nel magazzino aggiorna tutte le radici nello stesso istante, che e' esattamente il comportamento che si vuole da un design system. La copia, al contrario, avrebbe prodotto tante versioni quante sono le radici, e la prima divergenza sarebbe passata inosservata.

Essere presente non basta: una skill che nessuno nomina non viene invocata. Per questo lo strumento scrive anche, nel file di istruzioni di ogni radice, un blocco delimitato da marcatori che dichiara il design system, dove sta e che cosa copre. Il testo del blocco si genera dal frontmatter del pacchetto, quindi il nome del marchio non entra mai in questo repository: entra nelle radici, che sono fuori da git.

## Lo strumento

`scripts\Installa-DesignSystem.ps1`. Di default e' in sola lettura e mostra, radice per radice, se il design system e' collegato e se e' ricordato nel file di istruzioni.

```powershell
cd "E:\windows-status"
.\scripts\Installa-DesignSystem.ps1 -Verifica
```

La propagazione vera chiede il percorso del pacchetto e il permesso esplicito, secondo il paletto 1 del progetto.

```powershell
cd "E:\windows-status"
.\scripts\Installa-DesignSystem.ps1 -Sorgente "<percorso del pacchetto>" -Applica
```

Le radici servite per default sono tutte le `.claude-account*` e `.codex-account*` del profilo utente. Le radici predefinite `.claude` e `.codex`, che non appartengono a un account configurato, restano fuori salvo `-IncludiPredefinite`. Con `-Radici` si indica un elenco esplicito, con `-Nome` si forza il nome breve della skill quando non si vuole quello del frontmatter, con `-Deposito` si sposta il magazzino. Con `-Rimuovi -Applica` si tolgono i collegamenti e i blocchi, mentre il magazzino resta: lo strumento non cancella mai una cartella reale, e se ne trova una al posto del collegamento la mette da parte rinominandola invece di sovrascriverla.

## Tre cose che e' meglio sapere prima

Una sessione gia' aperta non vede una skill installata dopo il suo avvio. Dopo la propagazione, le sessioni in corso vanno riaperte, e questo vale per entrambi gli agenti.

Le radici di Codex vengono riscritte quando si ridistribuisce la configurazione di riferimento con la catena del template, cioe' con un `-Forza`. In quel momento il collegamento sopravvive, perche' sta in `skills`, ma il blocco di istruzioni in `AGENTS.md` sparisce, perche' quel file viene rimpiazzato per intero. Lo strumento va quindi rilanciato dopo ogni ridistribuzione, e la verifica in sola lettura lo segnala mostrando una radice collegata ma non ricordata.

Il collegamento e' un punto unico di guasto, ed e' il prezzo del vantaggio: se il magazzino viene spostato o cancellato, tutte le radici perdono il pacchetto insieme. Il magazzino sta quindi nel profilo utente e non in una cartella temporanea o di scaricamento, che sono precisamente i posti da cui un riferimento sparisce senza preavviso. Lo stesso vale per la sorgente da cui si e' depositato: dopo l'installazione non serve piu', e non deve diventare il percorso che qualcuno annota.

## Rapporto con gli altri pezzi della macchina

La catena dei due agenti da terminale, cioe' installazione delle radici, avvio isolato e pulizia, vive nel template e si richiama da `scripts\Agenti.ps1`: questa capacita' non la tocca e non la duplica. Agisce dopo, su radici gia' esistenti, e si limita a due gesti idempotenti, il collegamento e il blocco di istruzioni. Puo' essere rilanciata quante volte si vuole senza effetti cumulativi.
