---
generated-from-commit: 7db4de7
generated-from-branch: main
generated-date: 2026-06-10
covers-paths:
  - scripts/*.ps1
  - docs/02_VEEAM_BACKUP_PORTABILITA.md
last-verified-commit: 9407b27
---

## 17/11/2026 - Ricetta generica Graph ed Exchange registrata

Aggiornata docs/09_TOOLCHAIN_DA_ALTRI_PROGETTI.md con i moduli PowerShell già rilevati nel profilo corrente e la separazione fra identità Windows, account agente, client amministrativo e app del servizio. Consenso organizzativo persistente distinto dalla cache di processo; chiave privata sul runtime, permessi di posta limitati e prova dentro/fuori prima della ricezione. Nessun dato aziendale, certificato operativo, ID, casella o credenziale acquisiti qui; nessuna installazione, login aggiuntivo o modifica al sistema. Il bootstrap di un nuovo account agente non deve creare app cloud o propagare privilegi.

Il controllo di ripresa segnala riferimenti Git preesistenti non più validi in sei schede: non sono stati riscritti o dichiarati riconciliati. La nuova voce deriva da lettura diretta dei moduli e dalla procedura generica; il resto delle modifiche già presenti è stato conservato.

## 13/11/2026 - QuLog e HBS interrogabili e nuovi account predisposti

Gli installatori del pacchetto agenti-terminale consultano ora il registro privato opzionale `%LOCALAPPDATA%/agenti-terminale/progetti.json`. Il registro contiene percorsi di progetti già autorizzati e nomi dei server attesi, senza token o identità aziendali. Vale sia per la catena del template sia per scripts/Agenti.ps1 di questa macchina. Codex riceve la fiducia per i soli progetti registrati; Claude verifica le definizioni e le abilitazioni condivise del progetto. Un conflitto di fiducia blocca l’aggiunta. Login per account e dialogo iniziale del client restano distinti. Nessuna credenziale viene copiata fra radici.

Il punto d’ingresso della macchina accetta ora -Claude e -Codex come liste tipizzate indipendenti. Per esempio, scripts/Agenti.ps1 verifica -Claude 4 -Codex 4 prepara il riscontro per due nuove radici; installa con gli stessi parametri esegue la creazione e il provisioning. Questi sono esempi, non account aggiunti alla macchina durante il collaudo. Se il registro esiste serve Python 3.11 o successivo. Il registro reale è stato configurato privatamente e ne è conservata una copia di consegna in _notes/configurazione-agenti/. Le radici esistenti non sono state reinstallate con Forza.

La capacità NAS di progetto comprende ora QuLog e HBS: configurazione dei log, eventi, accessi, sessioni, destinazioni, elenco dei job e dettaglio/storico tramite getter revisionati. Credenziali di lettura e manutenzione rimangono separate. Elenco completo dei job, storico completo e backup ripristinabile sono tre verifiche diverse; nomi, destinazioni, risultati e prove restano nel progetto proprietario. Nessun valore aziendale viene conservato qui.

Sessantasette prove offline e 23 sottoprove passano con Ruff verde. Una prova esegue l’installatore Codex reale su profilo temporaneo senza creare auth.json; un’altra verifica la selezione degli account dal punto d’ingresso della macchina. Le mutazioni rilevano la mancata eredità del progetto e due regressioni del lettore NAS. Le definizioni MCP di progetto sono documentate da [Claude](https://code.claude.com/docs/en/mcp) e [Codex](https://developers.openai.com/codex/mcp); il registro e la sua applicazione sono capacità interne del template. Resta necessario il ripristino separato dei progetti e dei relativi segreti dopo una formattazione.


# Deployment e uso operativo

Non esiste un hosting: il "deploy" è l'esecuzione degli script sulla macchina da fotografare e, in caso di ripristino, sul PC di destinazione.

## Esecuzione ordinaria

Da PowerShell come amministratore, nella radice del progetto:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Snapshot-Stato.ps1                 # fotografia completa (consigliato)
.\scripts\Snapshot-Stato.ps1 -Scope Machine  # solo dati di macchina
.\scripts\Snapshot-Stato.ps1 -Scope User     # solo account corrente (da ripetere per account)
.\scripts\Compare-Snapshot.ps1               # diff tra i due snapshot più recenti
```

L'output va in `snapshots/snapshot_<timestamp>/`, ignorato da git. I dati live per-utente (versioni runtime, estensioni VS Code, git config attivo) riflettono solo l'account che esegue: per la copertura completa si riesegue `-Scope User` in ogni account.

## Ripristino su un'altra macchina

La strategia è a due gambe (ADR-002). La gamba immagine è Veeam Agent verso NAS con bare metal recovery, documentata in `docs/02_VEEAM_BACKUP_PORTABILITA.md` e da annotare a mano nella mappa perché Veeam non esporta il job in modo affidabile via script. La gamba riproducibile è questo repository: `scripts/Reinstall-Software.ps1` reimporta il software dal `software_winget.json` dello snapshot, la mappa e i file per-account guidano la ricostruzione di git, SSH, Claude e dell'ambiente di sviluppo. Su hardware diverso, dopo il ripristino immagine, vanno previsti ri-join Entra ID e recupero della chiave BitLocker da Entra ID.

## 13/11/2026 - Connessioni QNAP di progetto per tutti gli account degli agenti

Su richiesta dell’operatore documentata in docs/10_CODEX_CLI_E_WORKSPACE_OPENAI.md la ricetta astratta: definizioni MCP di progetto condivise, identità degli agenti separate dai token NAS, deposito privato nel progetto di rete e ricostruzione senza trasferire segreti via Git. Il progetto proprietario mantiene codice, valori e prove. Verificata la scoperta della definizione nei tre account Claude e nei tre Codex, oltre alla radice Codex predefinita; aggiunta dove mancava la fiducia per il solo progetto rete. Handshake locale offline e 39 prove verdi, nessun catalogo NAS ancora acquisito. Per il pilota il certificato autofirmato è accettato per impronta nel solo progetto, con fiducia al primo uso dichiarata. Nessuna modifica a trust store, servizi, registro, firewall o login Windows; la capacità resta distinta da un inventario completo. Per annullare, rimuovere il solo server QNAP e le sole voci di fiducia aggiunte. Configurazioni precedenti conservate privatamente nel progetto che ha eseguito la consegna.

## 13/11/2026 - NAS multiaccount: lettura e manutenzione da script

La stessa macchina può offrire l’integrazione NAS a tre radici Claude Code e tre radici Codex CLI dello stesso utente Windows, usando le definizioni del progetto proprietario. La ricetta resta generica: endpoint, nomi degli apparati, utenti, token e prove dell’infrastruttura vivono soltanto nel livello privato di quel progetto. Questa condivisione fra radici degli agenti non concede accesso ad altri utenti Windows.

Per ogni NAS compatibile si preparano due credenziali: censimento in sola lettura e manutenzione con categorie limitate. I token non entrano nei file globali di ciascun account; restano in depositi privati distinti. Claude e Codex caricano lo stesso lettore di progetto. Lo script di manutenzione richiede un piano completo, la sua impronta approvata, destinazione e certificato coincidenti, lettura dello stato prima e dopo e diario scritto prima della modifica. Un timeout richiede riconciliazione e non un nuovo tentativo automatico. Il catalogo di manutenzione è stato acquisito sul pilota della nuova funzione; una modifica reale rimane da collaudare. I cataloghi non attestano da soli privilegi effettivi, copertura completa o continuità operativa.

Per ricostruire la capacità si ripristinano i launcher e le radici previste dal template, si recupera il progetto proprietario, si rigenerano le configurazioni private di progetto e si acquisiscono credenziali nuove per ogni NAS. Si verificano separatamente scoperta della definizione in ogni account, handshake locale, collegamento HTTPS, catalogo e letture autorizzate. Un apparato legacy può restare nell’inventario e nel controllo degli accessi anche se non supporta MCP. Nessun riferimento all’organizzazione o a utenti e host reali appartiene a questa ricetta. Non è necessario replicare segreti in ciascuna radice account.
