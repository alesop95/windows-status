# 17 - Monitoraggio aperto del parco

> Guardare le macchine nel tempo senza account, senza token, senza limiti di nodi e senza che un byte esca dalla rete. Tre pezzi che nascono per stare insieme: `windows_exporter` sui PC, Prometheus e Grafana OSS su una macchina sola.

## La forma, prima dei pezzi

La tentazione, installando il monitoraggio su un PC nuovo, e' mettere tutto li': l'agente, l'archivio, il cruscotto. Funziona, e si guarda da `localhost`. Ma sono seicento megabyte, due servizi e un database su una postazione di lavoro, per guardare **una** macchina; e quando le macchine diventano quindici, ci sono quindici cruscotti e nessuna vista d'insieme.

La forma giusta separa chi espone da chi guarda:

```
PC nuovo 1 ─ windows_exporter  (11 MB, un servizio, :9182)  ┐
PC nuovo 2 ─ windows_exporter                               ├─→  UNA macchina centrale
PC nuovo 3 ─ windows_exporter                               │    Prometheus + Grafana OSS
server Linux ─ node_exporter oppure Netdata                 ┘    (:9090 e :3000)
```

Sul PC resta pochissimo: un servizio che espone le metriche su `http://localhost:9182/metrics` e si ferma li'. Non ha interfaccia, non ha account, non parla con nessuno se non viene interrogato. A interrogarlo, archiviare e disegnare ci pensa la macchina centrale, che puo' essere un PC fisso dell'ufficio, una macchina virtuale o il server Linux che si sta gia' censendo.

E' la stessa direzione del censimento: molte macchine, uno sguardo.

## I pezzi, e quanto costano

| Pezzo | Licenza | Versione appuntata | Peso | Dove sta |
|---|---|---|---|---|
| [windows_exporter](https://github.com/prometheus-community/windows_exporter) | MIT | v0.31.9 | MSI 11 MB | su ogni PC Windows |
| [Prometheus](https://github.com/prometheus/prometheus) | Apache-2.0 | v3.15.0 | zip 109 MB | macchina centrale |
| [Grafana OSS](https://github.com/grafana/grafana) | AGPL-3.0 | 13.2.4 | MSI 473 MB | macchina centrale |

**Costano zero, e non c'e' un asterisco.** Nessun account da creare, nessun token da incollare, nessuna chiave che scade, nessun limite al numero di macchine, nessuna funzione che si sblocca pagando. Gli allarmi sono dentro Grafana OSS. Tutti e tre pubblicano il digest dei propri artefatti, quindi entrano nel manifesto di `scripts\prima-installazione\strumenti.json` come gli altri e vengono verificati prima di essere eseguiti.

Una precisazione che vale la pena fare, perche' il nome confonde: **Grafana OSS non e' Grafana Cloud**. Il primo e' il programma che si installa e che qui si usa; il secondo e' il servizio ospitato da Grafana Labs, con un piano gratuito limitato e piani a pagamento. Qui non serve e non si usa.

## Perche' Netdata e' uscito dalla catena Windows

Netdata era il candidato naturale: si installa in due minuti, vede tutto da solo, ha risoluzione al secondo e gli allarmi gia' scritti. Il suo codice e' GPL-3.0.

Il problema non e' la licenza, e' la build per Windows. La pagina di installazione Windows di Netdata dichiara:

> *On the free Community tier, standalone Agents collect metrics but the local dashboard is locked — view your data in Netdata Cloud instead.*

Cioe': su Windows, con il piano gratuito, `http://localhost:19999` e' **bloccato**. L'agente raccoglie e i dati si guardano sul loro cloud. Senza token di aggancio si installa un servizio che non mostra niente; con il token, le metriche della macchina escono verso un servizio di terzi. Licenza aperta, funzione chiusa nella build: una "versione locale e basta", su Windows, non esiste.

Siccome la regola di questo progetto e' che il monitoraggio resti aperto e locale, su Windows Netdata non passa, ed e' stato sostituito da `windows_exporter`, che fa meno cose ma le fa senza chiedere niente a nessuno.

**Su Linux il discorso e' opposto.** Li' il cruscotto locale e' aperto, la configurazione e' zero e la risoluzione e' al secondo: sulle macchine Linux del parco Netdata resta la scelta migliore, e puo' convivere con Prometheus, che sa interrogarlo nel proprio formato (`/api/v1/allmetrics?format=prometheus`). In alternativa, per restare omogenei, `node_exporter` sta a Linux come `windows_exporter` sta a Windows.

Il manifesto conserva quindi la voce Netdata, marcata `piattaforma: linux`, con il motivo scritto accanto: una decisione che non lascia traccia e' una decisione che fra sei mesi qualcuno rifara' al contrario.

## Sul PC: l'agente

Fa parte della catena della prima installazione, passo `MONITORAGGIO` (vedi `docs/16`). Nel profilo:

```json
"monitoraggio": {
  "installa": true,
  "porta": 9182,
  "centrale": "192.0.2.10",
  "collettori": "cpu,cs,logical_disk,memory,net,os,service,system,process"
}
```

Il campo `centrale` e' quello che conta per la sicurezza. L'MSI di `windows_exporter` offre `ADDLOCAL=FirewallException`, che apre la porta **a tutta la rete**: la catena non lo usa e crea invece una regola ristretta al solo indirizzo della macchina centrale. Lasciando `centrale` vuoto, la porta resta chiusa dall'esterno e l'agente serve solo a chi sta davanti alla macchina.

Dopo l'installazione la catena verifica da se' che l'agente risponda e conta le metriche esposte: se non risponde, lo dice subito invece di lasciarlo scoprire a Prometheus fra una settimana.

## Sulla macchina centrale

```powershell
.\scripts\Monitoraggio-Centrale.ps1                              # piano
.\scripts\Monitoraggio-Centrale.ps1 -Scarica                     # scarica e verifica
.\scripts\Monitoraggio-Centrale.ps1 -Config -Macchine pc01,pc02  # genera i file
.\scripts\Monitoraggio-Centrale.ps1 -Installa -Macchine pc01,pc02
```

`-Config` scrive due file: `prometheus.yml` con l'elenco delle macchine, l'intervallo (`-Intervallo`, 15 secondi per default) e la ritenzione (`-Ritenzione`, 90 giorni); e `regole.yml` con tre allarmi di partenza - macchina non raggiungibile, disco sotto il 10%, memoria sotto il 10% - scritti per essere ampliati.

**Una cosa onesta su Windows.** Grafana si installa come servizio dal suo MSI. Prometheus no: il suo binario non e' un servizio di Windows, e per farlo partire da solo servono o un involucro di terze parti (NSSM, WinSW) o un'attivita' pianificata all'avvio. Lo script usa la seconda, perche' non aggiunge dipendenze da verificare. Se la macchina centrale e' un **Linux**, niente di tutto questo serve: li' Prometheus e Grafana sono pacchetti con il loro servizio, e la configurazione generata qui si copia tale e quale.

Finita l'installazione restano quattro cose da fare a mano, che lo script elenca invece di fingere di aver fatto: cambiare la password di Grafana al primo accesso su `http://localhost:3000`; aggiungere Prometheus come fonte dati (`http://localhost:9090`); importare il cruscotto della comunita' per `windows_exporter`, che e' l'ID **14694** su grafana.com; e controllare che su `http://localhost:9090/targets` le macchine risultino `UP`.

## Sicurezza delle porte

Tre porte nuove, e nessuna deve stare aperta piu' del necessario.

| Porta | Chi | Deve essere raggiungibile da |
|---|---|---|
| 9182 | `windows_exporter` sui PC | **solo** la macchina centrale |
| 9090 | Prometheus | solo la macchina centrale stessa |
| 3000 | Grafana | chi deve guardare i cruscotti, e nessun altro |

Le metriche non sono innocue: dicono quali processi girano, quando la macchina e' accesa, quanto e' pieno ogni disco. Compaiono nella sezione superficie d'attacco dello snapshot, ed e' giusto che ci compaiano. Grafana ha utenti e password propri: la prima cosa da fare e' cambiare `admin`.

## Rapporto con quello che il progetto gia' fa

`Controlla-Salute.ps1` e gli script di flotta sotto `scripts\rmm\` guardano **un istante**: il registro eventi fino a oggi, la freschezza dell'ultimo backup, il drift dei GUID di volume. Rispondono a "come sta adesso" e si lanciano quando serve.

Il monitoraggio risponde a un'altra domanda: "come stava martedi' alle tre di notte, e da quando sta peggiorando". Serve una serie storica, e una serie storica va raccolta prima che la domanda si ponga. I due non si sostituiscono: la diagnosi della memoria vincolata di `docs/13` e' nata proprio da campioni presi a mano per giorni, ed e' esattamente il lavoro che un Prometheus acceso avrebbe gia' fatto da solo.

## Aggiornare le versioni appuntate

Come per gli altri strumenti (procedura in `docs/16`): si guarda cosa e' cambiato a monte, si prende il digest **dal file che l'autore pubblica** - `sha256sums.txt` per windows_exporter e Prometheus, il file `.sha256` accanto al pacchetto per Grafana - si aggiornano versione e digest in `strumenti.json`, si prova, si annota nel changelog.

Il digest si copia da quel file e non si calcola sulla copia scaricata: un digest calcolato su cio' che si e' scaricato certifica soltanto che il file non e' cambiato *dopo*.
