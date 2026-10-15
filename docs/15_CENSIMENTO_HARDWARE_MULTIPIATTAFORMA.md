# 15 - Censimento hardware multipiattaforma

> Due strumenti autonomi di sola lettura, uno per Windows e uno per Linux, che fotografano l'hardware e la configurazione di base di **una macchina qualunque** e ne scrivono un testo anonimo e confrontabile. Servono a censire un parco. Non sostituiscono `Snapshot-Stato.ps1` e non ne sono una versione ridotta: censire e' un mestiere diverso dal fotografare.

## Censire non e' fotografare

Le due attivita' si somigliano solo da lontano, e tenerle separate e' la ragione per cui questi script stanno accanto a quelli del progetto invece che dentro la loro catena.

Lo **snapshot** guarda *una* macchina *molte* volte. Ricava la radice del progetto dalla cartella genitore, scrive in `snapshots\`, copre in profondita' sicurezza, licenze, BitLocker, avvio, persistenza, account e Veeam, e il suo valore vero sta nel confronto fra due fotografie successive: `Compare-Snapshot.ps1` dice cosa e' cambiato. Senza storico, quel valore non esiste.

Il **censimento** guarda *molte* macchine *una* volta. Non puo' presupporre un repository, una cartella, una versione di PowerShell, una distribuzione, e nemmeno il permesso di installare qualcosa; spesso guarda una macchina che non rivedra' mai. Il suo valore sta nell'ampiezza e nella confrontabilita': quindici file che si possono affiancare perche' hanno le stesse sezioni, con gli stessi nomi, nello stesso ordine.

Un solo strumento per entrambi i mestieri sarebbe o troppo pesante per girare ovunque, o troppo povero per tenere lo storico. Sono due, e si sovrappongono dove e' giusto che si sovrappongano: sul ferro, che e' l'unica cosa che entrambi devono saper leggere.

## Gli strumenti

`scripts\censimento\hw-report-windows.ps1` e `scripts\censimento\hw-report.sh`. Stesse sezioni, stesso ordine, stessa intestazione, stesse regole di anonimizzazione. Un file solo per piattaforma, da copiare su una chiavetta o incollare in un terminale.

```powershell
# Windows, da PowerShell amministratore
powershell -NoProfile -ExecutionPolicy Bypass -File .\hw-report-windows.ps1
.\hw-report-windows.ps1 -Etichetta PDL-07 -Destinazione D:\censimento
```

```bash
# Linux, con sudo
sudo bash hw-report.sh
sudo bash hw-report.sh --label SRV-03 --out /var/tmp/censimento
```

Lo script scrive il file da se', in UTF-8 senza BOM e con fine riga LF su entrambe le piattaforme. Non si usa la redirezione con `>`: su PowerShell 5.1 produrrebbe UTF-16, che fuori da Windows non si legge come testo.

Senza privilegi il censimento gira lo stesso ma e' **parziale**, e lo dichiara nella propria intestazione: su Windows mancano i seriali dei banchi di memoria e i contatori di affidabilita' dei dischi, su Linux mancano i dati SMBIOS di `dmidecode` e lo SMART. L'intestazione dice sempre con quali privilegi il file e' stato prodotto, cosi' che due censimenti non confrontabili si riconoscano a colpo d'occhio.

## Anonimo per default

Un censimento nasce per essere condiviso: si manda a un fornitore, si allega a un preventivo, si mette accanto agli altri quattordici. Per questo l'anonimizzazione e' il **comportamento predefinito** e il chiaro va chiesto.

| Dato | Come esce |
|---|---|
| hostname, dominio, nomi utente | pseudonimo stabile, p.es. `<host-4dc71e16>` |
| seriali (sistema, scheda madre, firmware, telaio, dischi, banchi), UUID, ProcessorId | pseudonimo stabile, p.es. `<sn-9f2c01ab>` |
| indirizzi MAC | restano le prime tre coppie, cioe' il **produttore**: `08-BF-B8-XX-XX-XX` |
| indirizzi IPv4 | resta la **rete**, sparisce l'ultimo numero: `172.29.176.x` |
| loopback, `0.0.0.0`, maschere, multicast | invariati: non identificano nessuna macchina |
| nomi di account generici (utente, admin, root, guest) | invariati: non identificano nessuno |

Lo pseudonimo e' un troncamento di SHA-256 calcolato su sale, tipo e valore. Due conseguenze utili: lo **stesso valore sulla stessa macchina da' sempre lo stesso pseudonimo**, quindi due censimenti a distanza di mesi restano confrontabili; e lo **stesso sale su piu' macchine** rende gli pseudonimi confrontabili fra loro, mentre sali diversi li rendono scollegati. Il sale si sceglie con `-Sale` / `--salt`.

Il MAC conserva il produttore e l'IPv4 conserva la rete perche' quelle due informazioni sono *l'oggetto* del censimento - che schede di rete ci sono, quante macchine stanno sulla stessa sottorete - mentre la parte che identifica la singola macchina non lo e'.

L'ultima riga della tabella e' una lezione presa sul campo: il primo collaudo girava su una macchina il cui account si chiama `Utente`, e la sostituzione letterale ha trasformato la parola *utente* delle etichette italiane in uno pseudonimo. I nomi di account generici sono ora esclusi, il che risolve il difetto e non perde niente, perche' un account chiamato `utente` non identifica nessuno.

Con `-Identificativi` / `--identificativi` esce tutto in chiaro. Quell'output contiene seriali reali: lo script lo avvisa a schermo quando finisce, e quel file non entra mai in un repository.

## Parametri

| Windows | Linux | A cosa serve |
|---|---|---|
| `-Destinazione <percorso>` | `--out <percorso>` | file o cartella; se e' una cartella il nome lo decide lo script |
| `-StdOut` | `--stdout` | a schermo invece che su file |
| `-Etichetta <nome>` | `--label <nome>` | come chiamare la macchina: numero di inventario, postazione, ruolo |
| `-Identificativi` | `--identificativi` | spegne l'anonimizzazione |
| `-Sale <stringa>` | `--salt <stringa>` | sale degli pseudonimi |
| `-Sezioni <elenco>` | `--sections <elenco>` | sottoinsieme di sezioni, separate da virgola |
| `-ContestoSoftware` | `--software` | aggiunge la sezione CONTESTO SOFTWARE |
| `-Pattern <regex>` | `--pattern <regex>` | filtra servizi e pacchetti della sezione opzionale |
| `-Elenco` | `--list` | mostra le sezioni |
| | `--help` | mostra l'uso |

In modo anonimo anche il **nome del file** e' anonimo: senza `-Etichetta` lo script usa lo pseudonimo dell'hostname, non l'hostname.

Le sezioni sono `IDENTITA`, `SISTEMA`, `CPU`, `MEMORIA`, `DISCHI`, `RETE`, `GPU`, `PERIFERICHE`, `ALIMENTAZIONE`, piu' `SOFTWARE` che e' opzionale. L'ordine e' fisso e non dipende da come lo si scrive sulla riga di comando: due censimenti restano allineati anche se chiesti in modi diversi.

## Qualsiasi Windows, qualsiasi Linux

Nessuna delle due famiglie e' data per scontata in una sola versione.

Su Windows: se manca `Get-CimInstance` si ripiega su WMI, se manca `Get-PhysicalDisk` si ripiega su `Win32_DiskDrive`, se manca `Get-NetAdapter` si ripiega su `Win32_NetworkAdapter`, e ogni interrogazione che il firmware non espone - slot di memoria, temperature ACPI, batteria - lascia una riga che lo dichiara invece di un errore rosso.

Su Linux non si presuppone nessuna distribuzione: il gestore di pacchetti viene riconosciuto fra `dpkg`, `rpm`, `pacman` e `apk`; il firewall fra `ufw`, `firewalld`, `nft` e `iptables`; i servizi fra systemd, OpenRC e SysV; `dmidecode`, `smartctl`, `ethtool`, `lspci`, `lsusb` e `ip` sono tutti facoltativi, e quando mancano lo script lo scrive invece di tacere. Riconosce anche di girare dentro un container o una macchina virtuale, che in un censimento e' precisamente la cosa da non confondere con il ferro.

Dalla versione 2.0 **nessun prodotto e' piu' cablato nel codice**: la versione precedente cercava per nome alcuni servizi del posto da cui proveniva. Cio' che interessa oggi si chiede con `--pattern`, e cambia da parco a parco.

## Cosa esce, e come si confronta

Testo semplice, sezioni separate da righe di uguali, intestazione che dichiara strumento, versione, piattaforma, data, modo, privilegi e sezioni incluse. Due macchine della stessa famiglia si confrontano con `diff`; fra Windows e Linux si leggono le sezioni affiancate, ed e' il motivo per cui portano lo stesso nome.

In modo anonimo il confronto e' molto piu' pulito che in chiaro: i valori volatili sono gia' ridotti a pseudonimi stabili, quindi un `diff` fra due censimenti della stessa macchina mostra i **cambiamenti veri** - un banco aggiunto, un disco sostituito, una scheda di rete nuova - invece del rumore dei numeri che cambiano a ogni avvio.

## Dove vivono gli output

Mai qui. In chiaro contengono seriali, MAC, IP, account e programmi di macchine reali, e questo repository e' pubblico: `.gitignore` esclude `hw-*.txt` ovunque nell'albero, cosi' che un file prodotto per sbaglio dentro la cartella del progetto non finisca in un commit per distrazione. Il posto degli output e' la cartella di censimento del parco macchine. Qui dentro vivono gli strumenti, non i risultati: la stessa regola che tiene `snapshots\` fuori da git.

## Rapporto con gli altri pezzi

Non fanno parte della catena locale dello snapshot, come quelli di `scripts\rmm\`: non ricavano la radice del progetto, non scrivono in `snapshots\`, non vengono chiamati da `Avvia.ps1`. Si differenziano da `rmm\` perche' non sono pensati per la distribuzione automatica come LOCAL SYSTEM, ma per l'esecuzione a mano, una macchina alla volta.

Il confine pratico: se la macchina e' questa, e la domanda e' *cosa e' cambiato*, si usa `Snapshot-Stato.ps1`. Se la macchina e' una delle altre, e la domanda e' *cosa c'e'*, si usa il censimento.
