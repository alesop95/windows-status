# 18 - Un supporto USB che non risponde blocca le interrogazioni sui dischi di tutta la macchina

Un dispositivo USB guasto non si limita a smettere di funzionare: può prendere in ostaggio il provider Storage di Windows e con esso ogni programma che chieda lo stato dei dischi, compresi quelli che con quel dispositivo non c'entrano niente. Su questa macchina è successo per tre giorni. Il documento spiega il meccanismo, la firma con cui lo si riconosce nel registro eventi, come verificarlo senza restare appesi a propria volta, come uscirne, e le impostazioni di Windows che hanno contribuito e che conviene cambiare prima che si ripeta.

> Stato al 2026-10-26: causa accertata e risolta. Il supporto è stato scollegato fisicamente il 26/10 fra le 09:21:00 e le 09:21:20; lo stack di archiviazione è tornato vivo subito dopo, dimostrato dal fatto che il disco di backup, che per sette minuti non era riuscito nemmeno a enumerarsi, si è agganciato alle 09:21:33,871. I rimedi di configurazione del paragrafo 6 sono stati applicati lo stesso giorno: sospensione selettiva USB disattivata su rete e batteria (`powercfg` riporta `0x00000000` su entrambe) e permesso di spegnimento tolto a tutti e quattro gli hub, verificato su `MSPower_DeviceEnable`, che li riporta a `Enable = False`. Restano aperte la causa a monte del paragrafo 8 e la corrispondenza fra porte fisiche e hub.

---

## 1. Il fatto

Il 23/10 alle 10:01:50 una chiavetta USB senza marca, montata come `G:`, smette di rispondere nel mezzo di un'operazione di paging. Ventun secondi dopo Windows comincia a ritentare la lettura del suo blocco zero, e continua a ritentarla ogni venti secondi per tre giorni, 419 volte.

```
23/10 10:01:50  disk ID 51   Errore nel dispositivo \Device\Harddisk4\DR21
                             durante un'operazione di paging
23/10 10:02:11  disk ID 153  primo nuovo tentativo su LBA 0x0, ri-enumerato come DR24
      ...                    un tentativo ogni ~20 s, ininterrottamente
26/10 09:13:33  disk ID 11   Il driver ha rilevato un errore del controller su DR24
26/10 ~09:21                 scollegamento fisico: tutto si sblocca
```

Nelle stesse ore, e senza che il legame fosse evidente a nessuno:

| Quando | Che cosa si è rotto |
|---|---|
| 23/10 10:11 | `WSearch` smette di rispondere; il gestore servizi registra 7011 ogni 30 s, poi 7046 |
| 23/10 17:07 | un banale `Get-PSDrive -PSProvider FileSystem` va in timeout a 120 s |
| 23/10 16:50 | il backup pianificato resta fermo 42 minuti in una guardia, con zero CPU e zero I/O |
| 23/10-26/10 | Google Drive non si apre e non ottiene la lettera che chiede |
| 26/10 09:14 | il disco di backup, ricollegato, non riesce a enumerarsi per sette minuti |

Nessuno di questi cinque sintomi nomina la chiavetta. È questo che rende il guasto difficile: il dispositivo rotto non è quello che si lamenta.

## 2. Il meccanismo: un solo sportello per tutti i dischi

`Get-Volume`, `Get-Partition`, `Get-Disk` e `Win32_DiskDrive` non leggono il disco che gli si indica: passano dal provider Storage di Windows, che per rispondere a una qualunque di quelle domande enumera **tutti** i dischi della macchina. Se uno solo non risponde, il provider resta appeso sui suoi tentativi e la domanda non torna mai, qualunque disco riguardasse.

Lo stesso vale per il percorso di aggancio dei dispositivi di archiviazione nuovi, `USBSTOR → disk.sys → partmgr → mountmgr`. Un disco collegato mentre quel percorso è bloccato non entra: è esattamente ciò che ha impedito al disco di backup di presentarsi per sette minuti.

Due conseguenze pratiche, entrambe controintuitive:

- **Il dispositivo guasto continua a dichiararsi sano.** Al livello PnP la chiavetta rispondeva `Status: OK`, `CM_PROB_NONE`, "This device is working properly", per tutti e tre i giorni. L'interfaccia USB era viva; era il controller flash dietro a essere bloccato. Chi guarda Gestione dispositivi non vede niente.
- **Il file system continua a funzionare.** Mentre `Get-Volume` non tornava, `dir` sul disco di backup elencava 53 voci in 32 millisecondi e `Get-PSDrive` leggeva lo spazio libero. Le operazioni che non passano dal provider restano istantanee, il che fa sembrare il problema intermittente o immaginario.

## 3. La firma nel registro eventi

Tre identificatori del provider `disk`, nel registro di sistema, nell'ordine in cui compaiono:

| ID | Significato | Peso |
|---|---|---|
| 51 | errore sul dispositivo, spesso durante un'operazione di paging | è l'istante della rottura |
| 153 | nuovo tentativo di I/O su un indirizzo di blocco logico | a raffica e sempre su LBA `0x0`: il dispositivo non risponde più a niente |
| 11 | il driver ha rilevato un errore del controller | peggioramento, comparso solo al terzo giorno |

Il numero del disco va letto da `Properties[2]` dell'evento e non dal testo, che è tradotto nella lingua di Windows; `Properties[0]` dà la forma `\Device\HarddiskN\DRnn`. Attenzione al fatto che **`N` è il numero del disco e viene riusato**: un dispositivo staccato libera il suo numero per il successivo, quindi non si identifica un supporto dal numero di disco attraverso un cambio di dispositivo. Su questa macchina quell'errore è stato commesso e corretto: errori attribuiti alla chiavetta si sono rivelati di un'altra, staccata poco prima.

Il contatore `DRnn` invece è un progressivo globale: cambia a ogni ri-enumerazione, e un salto di quel numero sullo stesso disco significa che Windows ha buttato giù l'oggetto e l'ha ricostruito.

Dato che vale la pena conoscere: in trenta giorni, a fronte di 419 errori dal livello **disco**, il livello **USB** non ha prodotto un solo errore o avviso. Chi cerca un guasto USB nel registro cercando i provider `USB`, `UCX`, `usbhub` non trova niente. Si cercano i provider `disk` e `partmgr`.

## 4. Come verificare senza restare appesi

Il rischio, indagando, è piantare anche lo strumento diagnostico. Ogni interrogazione al provider va messa in un processo o in un runspace separato con un tetto di tempo.

```powershell
# Il provider risponde?
$j = Start-Job { Get-Disk }
if (Wait-Job $j -Timeout 30) { Receive-Job $j } else { 'PROVIDER IMPIANTATO'; Stop-Job $j }

# Quale lettera non risponde: si prova una per una, con un tetto basso
foreach ($l in 'C','D','E','G','J') {
    $j = Start-Job -ArgumentList $l { param($l) fsutil fsinfo volumeinfo "${l}:" }
    if (Wait-Job $j -Timeout 8) { "$l ok" } else { "$l NON RISPONDE"; Stop-Job $j }
    Remove-Job $j -Force
}

# Chi sta ritentando, letto dai dati dell'evento e non dal testo tradotto
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='disk'; Id=@(11,51,153);
                                StartTime=(Get-Date).AddHours(-24)} |
  Group-Object { [string]$_.Properties[2].Value } |
  Select-Object @{n='Disco';e={$_.Name}}, Count
```

Queste strade restano percorribili a provider bloccato, perché non lo attraversano: il registro eventi, `fsutil fsinfo drives`, `Get-PSDrive`, `Get-PnpDevice`, e la chiave `HKLM\SYSTEM\MountedDevices`. Non lo sono `Get-Volume`, `Get-Partition`, `Get-Disk`, `Win32_DiskDrive`, `Get-StorageReliabilityCounter`.

## 5. Come uscirne

**Si stacca il dispositivo fisicamente.** Non si usa la rimozione sicura di Windows: l'espulsione passa dallo stesso stack bloccato e si pianta a sua volta. Non c'è rischio di perdere scritture in sospeso, perché su un dispositivo che non risponde nessuna scrittura può riuscire.

L'ordine conta:

1. prima si stacca il dispositivo guasto e si lascia **vuota** la porta che occupava, finché non si sa se il guasto è il supporto o la porta;
2. poi si staccano e si ricollegano gli altri dispositivi di archiviazione che nel frattempo non erano riusciti a entrare: un aggancio fallito non si ritenta da solo;
3. i dispositivi importanti si rimettono su porte sul retro, direttamente in scheda madre, non dietro un hub;
4. se dopo lo scollegamento il provider resta bloccato, serve un riavvio: la coda di I/O sospesa sta nel kernel e non sempre si libera.

Il supporto guasto **non va ricollegato a una macchina che serve**, nemmeno per analizzarlo: rifà esattamente la stessa cosa. Si analizza su una macchina sacrificabile. Una possibilità concreta di recupero esiste, perché un controller bloccato spesso si sblocca dopo un ciclo completo senza corrente, ma va tentata dove un provider impiantato non costa niente.

## 6. Le impostazioni di Windows che ci hanno messo del loro

È la parte che riguarda la configurazione della macchina, ed è l'unica su cui si può agire **prima** che il guasto si ripresenti.

**Sospensione selettiva USB.** Su questa macchina risultava attiva su rete e su batteria, perfino sul piano «Prestazioni elevate»:

```
Impostazione sospensione selettiva USB (48e6b7a6-50f5-4782-a5d4-53bb8f07e226)
  Alimentazione CA: 0x00000001  (Abilitata)
  Alimentazione CC: 0x00000001  (Abilitata)
```

Permette a Windows di togliere corrente ai dispositivi USB giudicati inattivi. I controller economici sono proprio quelli che poi non si risvegliano, e un dispositivo che non si risveglia è indistinguibile da un dispositivo guasto. Si disattiva da PowerShell con privilegi di amministratore:

```powershell
powercfg -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg -setactive SCHEME_CURRENT
```

**Spegnimento degli hub per risparmio energia.** In Gestione dispositivi, ogni *Hub radice USB* e ogni *Hub USB generico* ha una scheda **Risparmio energia** con la casella «Consenti al computer di spegnere il dispositivo per risparmiare energia». Su questa macchina le chiavi `EnhancedPowerManagementEnabled` e `AllowIdleIrpInD3` sotto `HKLM\SYSTEM\CurrentControlSet\Enum\<istanza>\Device Parameters` non sono impostate, cioè valgono il predefinito e il permesso c'è. Va tolta su tutti gli hub.

**La catena degli hub.** Vale sapere che cosa c'è fra la scheda madre e il dispositivo:

```powershell
Get-PnpDevice -Class USB -Status OK | Where-Object FriendlyName -match 'hub|controller'
```

Su questa macchina, oltre al controller Intel USB 3.20 e all'hub radice, ci sono tre hub aggiuntivi: un Genesys Logic `VID_05E3&PID_0608` e due ASMedia `VID_174C&PID_2074` e `VID_174C&PID_3074`. I Genesys sono i chip degli hub economici non alimentati, ed è dietro un hub del genere che un dispositivo paga per primo qualunque cedimento di tensione.

**Gruppo di continuità.** La macchina è un desktop senza UPS. Il proprietario riferisce un calo di tensione lampo in coincidenza con la rottura, e il registro lo rende credibile: nessun evento `Kernel-Power`, nessun riavvio, nessun altro disco coinvolto. L'alimentatore del PC ha assorbito il calo grazie alla propria capacità di tenuta; una chiavetta USB non ne ha praticamente nessuna. Questa volta è morto un supporto da pochi euro. Un calo più lungo spegne il PC, e se succede durante una copia su exFAT il danno è di un altro ordine.

## 7. Due effetti collaterali che si manifestano altrove

**Lettere di unità e riservazioni.** Finché il dispositivo guasto resta collegato, `HKLM\SYSTEM\MountedDevices` continua a riservargli la sua lettera, e chi la vuole se la vede negare. Su questa macchina Google Drive chiedeva `G:`, se la vedeva rifiutare e ripiegava su `H:` a ogni avvio, con il sintomo visibile «Google Drive non si apre». Il nesso con la chiavetta non è affatto evidente.

Una trappola dentro la trappola: il seriale di quella chiavetta era `SERIALE-RIMOSSO`, cioè il segnaposto che montano molti controller flash anonimi, non un numero univoco. Windows non sa distinguere un supporto così da qualunque altro dello stesso lotto, e riservargli una lettera «per identità» non è nemmeno un'operazione ben definita: una chiavetta diversa erediterebbe il posto. Per i dispositivi che contano si verifica che il seriale sia vero prima di fondarci sopra qualunque automatismo.

Il volume del disco di backup, riservato invece per firma del volume e non per identità del dispositivo, ha ripreso la sua lettera da solo al ricollegamento, senza che si dovesse toccare niente.

**exFAT sui supporti rimovibili.** Nella radice del disco di backup, formattato exFAT, sono comparse tre cartelle di recupero di `chkdsk` in un mese:

```
FOUND.000   05/10 18:55   6 elementi
FOUND.001   09/10 17:58   1 elemento
FOUND.002   15/10 13:30   1 elemento
```

Sono catene di file orfane recuperate dopo una riparazione del file system, e cadono vicino agli eventi di errore registrati sullo stesso disco. exFAT non ha journaling: un'interruzione di corrente o di contatto nel mezzo di una scrittura lascia strutture incoerenti, e questo è il risultato. Non è un difetto del disco, è il prezzo di exFAT su un supporto che perde contatto. Su un disco che deve custodire backup, vale la pena sapere che il file system scelto per la portabilità non protegge le scritture interrotte.

## 8. Che cosa resta aperto

La causa a monte non è accertata. Il 13/10 alle 17:26:32 e 17:26:33, a un secondo di distanza, hanno registrato errori **due dispositivi diversi**: il disco di backup e una chiavetta. L'attribuzione di quella chiavetta è stata corretta il 26/10 con il metodo del paragrafo 9: non è il supporto anonimo che poi prese `G:` e morì il 23/10, è quello che porta il materiale della CA aziendale, rimasto poi staccato fino a quel giorno. Non c'è quindi stata nessuna «sostituzione» a sei secondi: erano due supporti distinti, entrambi collegati quel pomeriggio, ed entrambi hanno poi ceduto, a tredici giorni di distanza l'uno dall'altro. Due dispositivi che inciampano a un secondo l'uno dall'altro, e due chiavette guaste nella stessa zona in due settimane, indicano qualcosa di condiviso a monte: hub, cablaggio del pannello frontale, o alimentazione del bus. Il fatto che il livello USB non abbia mai segnalato nulla rende meno probabile un hub che stacca i dispositivi e più probabile un problema di alimentazione o di risveglio.

Non è stato verificato quale porta fisica corrisponda a quale hub, e finché non lo si fa il sospetto resta su una zona, non su un connettore. La porta che ospitava il supporto guasto è stata lasciata vuota in attesa.

## 9. Leggere un supporto che sta cedendo senza congelare la macchina

Un supporto che cede non si comporta come uno morto, e va trattato diversamente. Quello del paragrafo 1 non rispondeva nemmeno alla domanda «ci sei»: non si montava più e produceva la raffica di tentativi. Il supporto con il materiale della CA, ricollegato il 26/10 alle 16:53, si è invece **montato regolarmente** — eventi Kernel-PnP 400 «configurato» e 410 «avviato» — e poi ha congelato il sistema operativo entro un paio di minuti, **senza produrre un solo evento `disk`**. È lo stadio precedente dello stesso cedimento: il controller risponde ancora all'enumerazione, ma su certe zone non restituisce i dati e nemmeno un errore.

Il punto che conta è che **il blocco non lo produce il dispositivo, lo producono i componenti di Windows che gli si buttano addosso da soli** nell'istante in cui compare una lettera di unità. Sono quattro, e nessuno di essi richiede un clic dell'utente: AutoPlay, che apre il volume per decidere che cosa proporre; la shell, che genera le anteprime delle cartelle; l'indicizzatore, che comincia a indicizzare il contenuto; e l'antivirus, che scansiona il supporto nuovo. Su un supporto sano finiscono in millisecondi e nessuno se ne accorge. Su uno che non risponde restano tutti in attesa, e poiché sono componenti di sistema si porta via la sessione interattiva.

Ne discende la ricetta, verificata lo stesso giorno. Si spegne AutoPlay (`DisableAutoplay = 1` sotto `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers`, che è la chiave dietro l'interruttore delle Impostazioni). Si ferma l'indicizzatore e gli si mette l'avvio su `Manual`, altrimenti torna su da solo mentre si lavora. Non si apre Esplora risorse, per nessun motivo. E si lancia **prima** di collegare il supporto uno strumento che attende la comparsa della lettera e copia all'istante: l'attesa si fa con `fsutil fsinfo drives`, che non passa dal provider Storage e quindi non si appende, mai con `Get-Volume` o `Get-PSDrive`.

La copia si fa con `robocopy /E /XJ /R:0 /W:0`, senza `/MT`. Zero tentativi di ripetizione è il cuore della cosa: su un supporto sano non cambia nulla, su uno che cede è la differenza fra saltare subito un settore illeggibile e restare appesi minuti su ciascuno. Niente multithread perché le letture parallele su un controller in difficoltà peggiorano le cose.

Risultato misurato: lo stesso supporto che mezz'ora prima aveva congelato il sistema operativo si è montato in 6 secondi e ha consegnato tutti e dieci i suoi file in meno di un secondo. Gli unici due fallimenti erano `IndexerVolumeGuid` e `WPSettings.dat` dentro `System Volume Information`, accesso negato, irrilevanti. L'implementazione di riferimento è `Recupera-CA.ps1` del progetto `sync-dev`.

### Quale supporto è, quando ce ne sono due simili

Quando si indaga su chiavette anonime che si somigliano, l'identificativo del dispositivo non dice che cosa contengono. L'etichetta sì, e Windows la conserva: `HKLM\SOFTWARE\Microsoft\Windows Portable Devices\Devices` tiene una voce per ogni supporto mai montato, con il valore `FriendlyName` pari all'etichetta del volume e il nome della chiave che contiene fabbricante, prodotto, revisione e numero di serie.

```powershell
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows Portable Devices\Devices' | ForEach-Object {
    '{0,-24} {1}' -f (Get-ItemProperty $_.PSPath).FriendlyName, $_.PSChildName
}
```

È in sola lettura, non tocca nessun dispositivo e funziona anche a supporto scollegato. Su questa macchina ha risolto in dieci secondi un'attribuzione sbagliata che aveva retto per tre giorni di indagine: il supporto con la CA è quello etichettato `ETICHETTA-RIMOSSA`, revisione 8.01, mentre quello che aveva preso `G:` ed era morto è un altro, senza etichetta propria. L'intera catena era partita da una frase detta a voce e mai verificata, mentre la verifica costava una query.

## 10. Per chi scrive strumenti che interrogano i dischi

La lezione trasversale è una sola: **una chiamata al provider Storage non ha un timeout proprio e può non tornare mai.** Uno script di manutenzione che la usa in una verifica preliminare non fallisce quando il provider si blocca, si ferma e basta, senza log, senza codice di uscita e senza niente da leggere. Su questa macchina un backup pianificato è rimasto così per 42 minuti, e il modo in cui lo si è scoperto è stato guardare l'elenco dei processi.

Ogni interrogazione va eseguita in un runspace o in un processo separato con un tetto di tempo, e la scadenza va distinta dagli altri esiti: «non lo so» non è «disco assente» né «disco pieno», e confonderli manda a cercare il guasto nel posto sbagliato. Il thread rimasto appeso dentro il provider non si può interrompere, perché fermarlo significherebbe aspettare proprio la chiamata che non torna; si abbandona, ed essendo di background non trattiene l'uscita del processo.

Una trappola ulteriore, pagata sul campo: spostando la chiamata in un runspace separato, l'oggetto restituito da `Get-Volume` attraversa un confine. Le parole `Healthy`, `OK`, `exFAT` non stanno nell'oggetto, le produce l'adattatore di tipi del modulo Storage, che vive nel runspace dove il modulo è caricato. Se il chiamante non lo ha importato — e un processo che chiama il provider solo dentro il runspace figlio non lo importa — tornano i codici grezzi `0`, `2`, `16`, e un confronto con le stringhe boccia un volume perfettamente sano. I valori vanno proiettati in un oggetto semplice **dentro** il runspace, dove l'adattatore c'è.

L'implementazione di riferimento di entrambe le cose è `Invoke-StorageQuery` e `Get-VolumeInfoFromProvider` nel progetto `sync-dev`, con le verifiche di regressione che le accompagnano.

[^1]: Gli orari e i conteggi di questo documento vengono dal registro eventi di sistema di questa macchina, dal `setupapi.dev.log` e dai log del progetto `sync-dev`, raccolti fra il 23/10 e il 26/10 del 2026.
