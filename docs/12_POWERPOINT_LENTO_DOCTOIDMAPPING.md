# 12 - PowerPoint lento: la cache DocToIdMapping

Questo documento descrive un guasto di Office che si presenta come lentezza di PowerPoint e che nessuno degli interventi abituali risolve: riparazioni, aggiornamenti, reinstallazioni, driver e antivirus lo lasciano dov'è, perché la causa sta in una cache del profilo utente che nessuno di quegli interventi tocca. Spiega che cos'è quella cache, perché a una certa dimensione blocca PowerPoint a ogni click, come si riconosce in pochi secondi e come si bonifica, con lo strumento locale `scripts\Diagnostica-PowerPoint.ps1` e con lo script di flotta `scripts\rmm\Fix-OfficeDocToIdMapping.ps1`.

> Origine: intervento dell'ottobre 2026 su una postazione della flotta, qui `<pdl-colpita>`, con Microsoft 365 Apps in Current Channel su Windows 11 Pro 25H2. Primi blocchi registrati il 01/10/2026, risoluzione il 07/10/2026, verifica a una settimana il 13/10/2026. Il rapporto d'intervento originale, con nomi, SID e identificativi reali, resta nella documentazione interna dell'IT e non entra in questo repository; la mappatura dei segnaposto sta in `CLAUDE.local.md`.

---

## 1. Il sintomo, e perché inganna

PowerPoint si blocca per cinque-dieci secondi dopo ogni click, mostrando «Non risponde» nella barra del titolo, con qualunque presentazione, anche vuota, e anche avviato in modalità provvisoria con `powerpnt /safe`. Word ed Excel sulla stessa postazione funzionano normalmente, e gli stessi file aperti sui PC dei colleghi non danno problemi. Il registro Applicazioni contiene eventi *AppHangB1*, ID 1002, per `POWERPNT.EXE`, senza indicazione del modulo responsabile.

Ognuno di questi indizi spinge verso una pista sbagliata. Il fatto che il problema segua la postazione e non il file fa pensare a driver, antivirus o aggiornamenti di Windows. Il fatto che resista alla modalità provvisoria esclude gli add-in, il che è vero, ma fa pensare anche che le personalizzazioni dell'utente siano fuori causa, il che è falso: la modalità provvisoria disattiva add-in e personalizzazioni caricate all'avvio, non i dati che Office tiene nel registro del profilo. E il fatto che riguardi solo PowerPoint fa cercare nella chiave di registro di PowerPoint, mentre la causa sta in una chiave comune a tutte le applicazioni Office, che solo PowerPoint consulta con la frequenza che la rende un problema.

## 2. Che cos'è DocToIdMapping

La chiave sta nel profilo dell'utente:

```
HKCU\Software\Microsoft\Office\16.0\Common\Identity\DocToIdMapping\<id>_ADAL
```

`Common\Identity` è l'area in cui Office 16.0[^1] conserva le informazioni sugli account Microsoft 365 collegati e le relative cache, condivisa da tutte le applicazioni della suite. `DocToIdMapping` è la cache che associa i documenti agli account: per ogni documento o posizione aperti registra quale identità va usata per accedervi, così che la volta successiva Office sappia con quali credenziali aprirlo senza chiederle all'utente. Ogni sottochiave corrisponde a un'identità, nominata con il suo identificativo e il suffisso del protocollo di autenticazione, `_ADAL`[^2]; ogni valore dentro la sottochiave è un URL o un percorso di documento.

Tre proprietà della chiave spiegano tutto il resto del caso. La prima è che sta sotto `Common` e non sotto `PowerPoint`: il reset della chiave di PowerPoint non la tocca. La seconda è che è un dato del profilo utente, non dell'installazione: Quick Repair, aggiornamenti di Office e, con ogni probabilità, anche una disinstallazione completa la lasciano intatta, perché nessuna di queste operazioni pulisce `HKCU`. La terza è che Office non le pone un limite visibile: su un PC sano la sottochiave contiene due o tre valori, sulla postazione colpita ne conteneva 186.322, e in nessuno dei due casi Office ha segnalato qualcosa.

Eliminare la sottochiave è sicuro. È una cache: Office la ricrea da solo e la ripopola man mano che si aprono documenti, e al massimo la prima apertura di un documento dal cloud dopo la bonifica richiede un istante in più. Account, credenziali, impostazioni e documenti non vengono toccati.

## 3. Il meccanismo del blocco

La catena di chiamate seguente è stata ricostruita da una traccia della CPU registrata con WPR[^3] durante i blocchi e analizzata con WPA[^4] con i simboli pubblici Microsoft. Il ramo riportato pesa circa 20,7 dei 21,8 secondi di CPU usati da PowerPoint nella traccia.

```
PPCORE!PPT::TaskMgr::IdleTask                         attività eseguita dopo ogni interazione
 PPCORE!ThrottledToolBarUpdateWorker::DoWork          aggiornamento del ribbon
  Mso98!OfficeSpace::DataSourceUtils::UpdateList      ricostruzione degli elenchi di comandi
   Mso98!OfficeSpace::FSList::UpdateList              87% della CPU di PowerPoint
    Mso98!OfficeSpace::BaseControl::FEnabled          il comando va mostrato attivo o no?
     PPCORE!ActionManager::GetActionState
      PPCORE!SuggestionPaneAction::GetState           pulsante Suggerimenti / Copilot
       PPCORE!PPT::Copilot::GetDisabledReasons        perché Copilot non è disponibile qui?
        PPCORE!PPT::Identity::ResolveOfficeIdentity   con quale account è aperto il documento?
         Mso98!Authentication::Doc2IdCache::GetIdentity
          Mso30!Authentication::DocToIdentityMapping::TryIdentity
           Mso20!CMsoUrlSimple::Crack / IdnToAscii    analisi di un URL, una per ogni voce
            ntdll!RtlAllocateHeap                     allocazioni di memoria per ogni analisi
```

Letta dal basso verso l'alto, la catena racconta questo. Dopo ogni azione dell'utente PowerPoint esegue un'attività di riposo che aggiorna il ribbon. Per ogni comando del ribbon deve decidere se mostrarlo attivo o disattivato, e uno di quei comandi è il pulsante dei suggerimenti, legato a Copilot. Per sapere se Copilot è disponibile per il documento aperto, PowerPoint deve stabilire con quale account Office il documento è associato, e per farlo interroga la cache DocToIdMapping. L'interrogazione non è una ricerca per chiave: scorre le voci e per ciascuna analizza l'URL, con le relative conversioni del nome di dominio e allocazioni di memoria. Il costo dell'interrogazione è quindi proporzionale al numero di voci, ed è un'inferenza dalla forma della catena, non una misura su cache di dimensioni diverse.

Il controllo non avviene una volta per apertura ma a ogni aggiornamento del ribbon, cioè dopo ogni click: nella traccia la funzione `GetActionState` compare 1.355 volte. Con tre voci il costo è invisibile; con 186.322 voci ogni aggiornamento tiene occupato un core per diversi secondi, e l'interfaccia, che gira sullo stesso thread, smette di rispondere.

Il controllo vive nel codice del ribbon di PowerPoint, `PPCORE.DLL`. Word ed Excel leggono la stessa cache, ma non con questa frequenza nel percorso dell'interfaccia, ed è per questo che la stessa chiave sovradimensionata blocca solo PowerPoint.

La distribuzione della CPU per modulo, nella stessa traccia, conferma che il lavoro è tutto interno a Office e alle funzioni di memoria di Windows:

| Modulo | CPU (ms) | Ruolo |
|---|---|---|
| `ntdll.dll` | circa 8.760 | allocazione della memoria (heap) |
| `Mso20win32client.dll` | circa 6.740 | libreria condivisa di Office |
| `ucrtbase.dll` | circa 3.440 | runtime C: stringhe e copie di memoria |
| `Mso30win32client.dll` | circa 1.980 | libreria condivisa di Office |
| antivirus, driver grafico, DirectWrite | trascurabile | esclusi come causa |

## 4. Il caso: diciassette verifiche, quindici a vuoto

La tabella riassume le verifiche nell'ordine in cui sono state fatte, tutte da remoto tramite RMM[^5], in parte nel contesto SYSTEM e in parte in quello dell'utente collegato. Si riporta perché è il catalogo di ciò che non serve fare, e perché ogni riga esclusa ha un motivo che il paragrafo 2 spiega.

| # | Verifica | Esito |
|---|---|---|
| 1 | reset della chiave `HKCU\...\Office\16.0\PowerPoint` (rinominata, con backup) e pulizia dei `PPT*.tmp` | nessun effetto; il primo tentativo era finito per errore nel profilo SYSTEM ed è stato ripetuto tramite `HKU\<SID>` |
| 2 | disattivazione dell'add-in di un OCR di terze parti (LoadBehavior da 3 a 2, chiavi HKLM a 64 e 32 bit) | nessun effetto |
| 3 | disattivazione dell'accelerazione grafica di Office | nessun effetto, poi riattivata |
| 4 | avvio in modalità provvisoria (`powerpnt /safe`) | blocchi presenti: esclusi add-in e personalizzazioni caricate all'avvio |
| 5 | stampante predefinita | già Microsoft Print to PDF: esclusa |
| 6 | build di Office confrontata con un PC funzionante | identica: esclusa |
| 7 | Quick Repair di Office | nessun effetto |
| 8 | driver grafico Intel aggiornato di quattro anni | nessun effetto; il driver nuovo è stato mantenuto |
| 9 | rimozione dell'aggiornamento cumulativo di anteprima del mese | nessun effetto |
| 10 | aggiornamento di Office alla build successiva | nessun effetto |
| 11 | controllo dei font (687 di sistema, nessuno installato a mano) | esclusi |
| 12 | elenco dei moduli caricati in `POWERPNT.EXE` | unici moduli di terze parti: l'antivirus |
| 13 | monitor PowerShell dello stato di PowerPoint, un campione al secondo | blocchi di 5-10 s con un core al 100%, CPU a zero a riposo, rete regolare: la causa è un calcolo interno |
| 14 | antivirus: eccezioni per `POWERPNT.EXE`, policy di test, anti-exploit avanzato disattivato | nessun effetto, con i moduli dell'antivirus rimossi dal processo: escluso |
| 15 | spostamento degli elenchi recenti (21.430 collegamenti in Recent di Windows, 240 in Recent di Office, jump list fino a 6 MB) | nessun effetto |
| 16 | traccia WPR e analisi WPA | causa individuata (paragrafo 3) |
| 17 | eliminazione della sottochiave DocToIdMapping sovradimensionata | risolto |

Il confronto che ha reso evidente l'anomalia, fra la postazione colpita e quella di un collega:

| Elemento | Postazione colpita | PC sano |
|---|---|---|
| valori in `Identity\DocToIdMapping\<id>_ADAL` | 186.322 | 2 |
| dimensione di `Common\Identity` esportata | 2.606 KB | 33 KB |

Le verifiche 1-15 hanno un tratto in comune: cambiano l'installazione, l'ambiente o la configurazione dell'applicazione, e nessuna tocca i dati che Office tiene sotto `Common` nel profilo. La 13 è quella che ha cambiato la direzione dell'indagine, perché ha trasformato «PowerPoint è lento» in una misura: un core saturo durante il blocco e nessuna attività di rete dicono che il tempo si spende in un calcolo, e un calcolo si trova con un profilatore, non per esclusione.

## 5. La bonifica e la sua reversibilità

La bonifica consiste in tre passi, nell'ordine: chiudere le applicazioni Office dell'utente, esportare un backup della chiave, eliminare la sola sottochiave sovradimensionata. Eseguiti a mano, nel contesto dell'utente:

```powershell
reg export "HKCU\Software\Microsoft\Office\16.0\Common\Identity\DocToIdMapping" "<cartella-amministratori>\DocToIdMapping.reg" /y
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Identity\DocToIdMapping\<id>_ADAL" /f
```

Eseguiti da un RMM come SYSTEM, `HKCU` punta al profilo di SYSTEM e non a quello dell'utente: si usa `HKU\<SID-utente>` al posto di `HKCU`. È l'errore in cui è caduto il primo tentativo del caso, e vale per ogni intervento remoto sul profilo, non solo per questo.

Il backup si reimporta con `reg import <file.reg>`, ma un ripristino reintroduce il problema, quindi serve solo in caso di effetti collaterali imprevisti, che nel caso non ci sono stati. Il backup contiene gli URL dei documenti aperti dall'utente: va tenuto in una cartella leggibile solo dagli amministratori, mai in `C:\Users\Public`, ed eliminato a fine osservazione. Lo stesso vale per una traccia WPR, che pesa alcuni gigabyte e contiene dati del profilo.

Dopo sei giorni dalla bonifica la sottochiave della postazione colpita conteneva tre valori, con PowerPoint regolare: nessun processo sta generando voci in massa, e le 186.322 voci si sono accumulate in un lungo periodo d'uso o per un evento passato che oggi non è più attivo.

## 6. Lo strumento locale: `scripts\Diagnostica-PowerPoint.ps1`

Lo strumento porta nel progetto la diagnosi che nel caso è arrivata dopo diciassette verifiche, in modo che la prossima volta arrivi per prima. Senza parametri legge soltanto e scrive il report in `snapshots\office\diagnosi_<data>.txt`, ignorata da git.

```powershell
.\scripts\Diagnostica-PowerPoint.ps1                 # diagnosi, sola lettura
.\scripts\Diagnostica-PowerPoint.ps1 -Monitora 60    # più la misura dei blocchi per 60 secondi
.\scripts\Diagnostica-PowerPoint.ps1 -TuttiIProfili  # anche gli altri utenti collegati (admin)
.\scripts\Diagnostica-PowerPoint.ps1 -Bonifica       # backup ed eliminazione, a conferma
```

Il report ha sei sezioni. La prima riporta build e canale di Office, letti dalla configurazione della consegna a portata di clic[^6]. La seconda è il cuore: per ogni sottochiave di DocToIdMapping legge il solo conteggio dei valori, senza enumerarli, quindi in un istante anche con centinaia di migliaia di voci, e classifica OK sotto 1.000 valori, ATTENZIONE fino a 9.999, ALERT da 10.000; i valori non vengono mai stampati, perché sono URL di documenti, e l'identità compare troncata ai primi otto caratteri. Con `-TuttiIProfili`, da amministratore, legge anche gli hive degli altri utenti collegati; i profili scollegati li lascia allo script di flotta, che sa caricarli. La terza conta gli hang ID 1002 di PowerPoint nella finestra e li mette accanto a quelli di Word ed Excel, perché la firma del caso è che si blocchi solo PowerPoint. La quarta riporta i fattori esclusi nel caso, cioè add-in caricati all'avvio, accelerazione grafica, elementi recenti, jump list, stampante predefinita, font e moduli di terze parti, come contesto e fuori dal verdetto, così che non si ripetano le stesse prove. La quinta, con `-Monitora`, campiona PowerPoint ogni secondo e ne ricava gli episodi di «Non risponde» e il picco di CPU per core, che è la verifica 13 del caso resa ripetibile e confrontabile prima e dopo un intervento; il dettaglio va in un CSV accanto al report. La sesta dà il verdetto: con ALERT propone la bonifica, con hang ma cache sana rimanda al paragrafo 8.

I codici di uscita sono 0 per OK, 1 per ATTENZIONE e 2 per ALERT, così che lo strumento si possa usare anche da un'attività pianificata.

`-Bonifica` è l'unica parte che modifica, e agisce solo sul profilo di chi la lancia, quindi non richiede i diritti di amministratore. Si rifiuta se un'applicazione Office della sessione è aperta, esporta la chiave in `snapshots\office\backup\` e non procede se il backup è vuoto, elenca le sottochiavi oltre soglia e chiede di digitare `SI`, elimina solo quelle, verifica che non esistano più e stampa la riga da aggiungere al changelog della mappa, con il comando di ripristino. Il parametro `-PercorsoChiave` esiste solo per provare la bonifica su una chiave di test, ed è con quello che la bonifica è stata collaudata il 13/10, su una chiave di prova con una sottochiave da 10.050 valori e una da 9.999 che differiscono solo per la posizione rispetto alla soglia. Con Word aperto, e poi con un'istanza di Excel avviata come server di automazione, lo strumento si è rifiutato senza toccare nulla. Con Office chiuso ha prodotto un backup di 1.524 KB con tutti i 20.049 valori, ha eliminato solo la sottochiave oltre soglia, e la diagnosi successiva ha dato ATTENZIONE per quella rimasta; `reg import` del backup ha ripristinato entrambe con i loro valori. Lo script di flotta è stato collaudato lo stesso giorno in `-ReportOnly`, con `-BaseDir` in una cartella temporanea: codice 0, tre profili letti, compresi due scollegati caricati e scaricati come `WS_TMP_<n>` senza residui.

## 7. Lo script di flotta: `scripts\rmm\Fix-OfficeDocToIdMapping.ps1`

Lo script è stato scritto per l'RMM durante l'intervento ed è riportato qui in forma anonimizzata, con la logica invariata: rispetto all'originale cambiano solo la descrizione, la cartella di lavoro, che diventa il parametro `-BaseDir`, e il prefisso degli hive temporanei. Come gli altri script di `scripts\rmm\`, non fa parte della catena locale dello snapshot: gira come SYSTEM sull'endpoint e scrive in `C:\ProgramData`, non nel repository.

Per ogni profilo elencato in `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList` con SID di utente locale, di dominio o Entra ID (`S-1-5-21-*` e `S-1-12-1-*`), usa l'hive già caricato se l'utente è collegato, oppure carica temporaneamente il suo `NTUSER.DAT` con `reg load` come `HKU\WS_TMP_<n>` e lo scarica alla fine. Di ogni sottochiave legge il solo conteggio dei valori. Se una supera la soglia e non è attivo `-ReportOnly`, controlla attraverso il proprietario dei processi se l'utente ha applicazioni Office aperte, e in quel caso rimanda la bonifica o, con `-ForceCloseOffice`, le chiude; poi esporta il backup e, solo se il backup è riuscito, elimina le sottochiavi oltre soglia e verifica l'esito.

| Parametro o variabile RMM | Default | Funzione |
|---|---|---|
| `Threshold` / `threshold` | 10000 | valori oltre i quali una sottochiave è anomala |
| `ReportOnly` / `reportOnly` | disattivo | solo rilevamento, nessun backup e nessuna modifica |
| `ForceCloseOffice` / `forceCloseOffice` | disattivo | chiude le app Office dell'utente collegato; il lavoro non salvato si perde |
| `SkipOfflineProfiles` / `skipOfflineProfiles` | disattivo | salta i profili non collegati |
| `BackupRetentionDays` / `backupRetentionDays` | 60 | elimina i backup più vecchi di N giorni, 0 = mai |
| `CustomField` / `customField` | vuoto | campo personalizzato dell'RMM in cui scrivere l'esito sintetico |
| `BaseDir` / `baseDir` | `C:\ProgramData\WindowsStatus\DocToIdMapping` | cartella di backup e log, accessibile solo a SYSTEM e Administrators |

| Codice di uscita | Significato |
|---|---|
| 0 | nessuna anomalia |
| 1 | anomalia rilevata e bonificata |
| 2 | anomalia rilevata e non bonificata: `-ReportOnly`, oppure Office aperto senza `-ForceCloseOffice` |
| 3 | errore, per esempio backup o eliminazione falliti: vedere il log |

I codici diversi da zero fanno risultare l'attività come fallita nell'RMM, e questo è voluto: le postazioni da esaminare si trovano filtrando le esecuzioni fallite. L'uso consigliato è una prima corsa in `-ReportOnly` su tutta la flotta, l'esame delle postazioni con codice 2, la bonifica su quelle preferibilmente fuori orario, e poi una corsa periodica in `-ReportOnly`, per esempio mensile, con il campo personalizzato valorizzato perché lo stato resti visibile nella scheda del dispositivo.

Il ripristino da backup ha una sottigliezza. Per un utente collegato al momento della bonifica, il file `.reg` fa riferimento a `HKEY_USERS\<SID>` e si reimporta con `reg import` come SYSTEM. Per un profilo scollegato, il file fa riferimento all'hive temporaneo `HKEY_USERS\WS_TMP_<n>`: si ricarica l'hive con lo stesso nome, si importa e si scarica, oppure si sostituisce nel file `WS_TMP_<n>` con il SID dell'utente e lo si importa mentre l'utente è collegato.

## 8. Il metodo: profilare prima, ipotizzare dopo

La lezione generale del caso è di metodo. Quando un'applicazione si blocca con un core saturo, il tempo si spende in un calcolo, e un profilatore indica la funzione responsabile in pochi passaggi; l'esclusione per tentativi, invece, procede al ritmo di un'ipotesi per intervento e non converge se la causa sta in un posto che nessuna ipotesi prevede. WPR è incluso in Windows 11; WPA si installa dal Microsoft Store.

```powershell
wpr -start CPU -filemode
wpr -stop "<cartella-amministratori>\ppt_hang.etl"
```

Fra i due comandi si riproduce il blocco per venti-trenta secondi. In WPA si caricano i simboli pubblici Microsoft, si apre il grafico *CPU Usage (Sampled)*, si filtra sul processo e si raggruppa per stack: il ramo più pesante, seguito dall'alto verso il basso, porta alla funzione che consuma il tempo. Nel caso il file pesava circa 3,1 GB, e contiene dati del profilo: si salva in una cartella riservata agli amministratori e si elimina a fine analisi.

Due altre lezioni valgono oltre PowerPoint. Da un RMM che gira come SYSTEM, `HKCU` e `%TEMP%` sono quelli di SYSTEM: per agire sul profilo di un utente si passa da `HKU\<SID>`, oppure da una sessione nel contesto dell'utente collegato. E un problema legato ai dati del profilo sopravvive a riparazioni, aggiornamenti e reinstallazioni dell'applicazione, quindi la reinstallazione non è la mossa finale ma una delle meno informative.

## 9. Punti aperti

Non è noto perché la cache sia cresciuta fino a 186.322 voci. Le ipotesi sono il volume di documenti aperti da SharePoint e OneDrive, oppure strumenti che aprono file attraverso Office, come software di traduzione assistita o di traduzione automatica; la verifica a una settimana esclude che oggi un processo generi voci in massa, ma non dice che cosa le abbia generate allora. Lo strumento e lo script rimuovono il sintomo, non la causa della crescita: se una postazione torna in ATTENZIONE dopo una bonifica, il ritmo di ricrescita misurato con due diagnosi a una settimana di distanza è l'indizio da cui partire.

La soglia di 10.000 valori è empirica: deriva dal confronto di un solo caso anomalo con un PC sano, cioè 186.322 contro 2, e lascia un margine ampio in entrambe le direzioni, ma non è stata misurata la dimensione a cui il blocco diventa percepibile. La soglia di attenzione a 1.000 è una scelta prudenziale dello strumento locale, non una misura.

Gli strumenti controllano solo Office 16.0, cioè Microsoft 365 Apps e Office dal 2016 in poi.

## 10. Raccordo

Gli hang di PowerPoint compaiono anche nel check di salute, sezione 4 di `07_SALUTE_E_STABILITA.md`, che da questo caso in poi rimanda allo strumento quando fra le applicazioni bloccate c'è `POWERPNT.EXE`. Lo script di flotta si distribuisce come gli altri di `scripts\rmm\`, descritti in `08_MONITORAGGIO_BACKUP_VEEAM.md`. Una bonifica eseguita su questa macchina va registrata nel changelog di `01_MAPPA_CONFIGURAZIONE.md`.

[^1]: *Office 16.0*, numero di versione interno condiviso da Office 2016, 2019, 2021, 2024 e Microsoft 365 Apps: per questo la stessa chiave vale per tutte queste edizioni.

[^2]: *ADAL*, Active Directory Authentication Library - libreria di autenticazione Microsoft con cui Office ottiene i token per gli account aziendali; il suffisso indica con quale meccanismo è stata registrata l'identità.

[^3]: *WPR*, Windows Performance Recorder - registratore incluso in Windows che cattura eventi ETW (Event Tracing for Windows), fra cui i campioni di CPU con il relativo stack di chiamate.

[^4]: *WPA*, Windows Performance Analyzer - strumento Microsoft che apre le tracce di WPR e le mostra per processo, modulo e funzione, risolvendo i nomi con i simboli pubblici.

[^5]: *RMM*, Remote Monitoring and Management - piattaforma di gestione remota della flotta, che esegue script sugli endpoint come SYSTEM e ne raccoglie esito e output.

[^6]: *Consegna a portata di clic*, traduzione di Click-to-Run - il sistema di installazione e aggiornamento di Microsoft 365 Apps, la cui configurazione sta in `HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration`.
