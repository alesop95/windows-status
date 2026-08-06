# 06 - Raccordo con la checklist di remediation (Vulnerability Assessment)

> Come lo stato fotografato da `windows-status` alimenta una checklist di remediation di un Vulnerability Assessment (lo strumento HTML interattivo: host con fingerprint, interventi con severità/CVSS, azione di remediation, stato, accettazione del rischio, riferimenti normativi). I due strumenti sono complementari e vanno tenuti distinti.

## I due ruoli, una catena sola

`windows-status` e la checklist VA rispondono a due domande diverse sullo stesso oggetto.

`windows-status` risponde a **"cosa c'è e cos'è cambiato"**: fotografa lo stato reale di una macchina (sola lettura), lo confronta nel tempo e ne fa emergere le variazioni critiche come *alert*. È la fonte di evidenza, ripetibile e datata.

La checklist VA risponde a **"cosa va sistemato, con che priorità, a che punto siamo"**: prende i *finding* (da un Nessus, da un pentest, o dagli alert di `windows-status`), assegna severità e riferimenti normativi, traccia la remediation fino alla chiusura o all'accettazione formale del rischio. È il registro di governance.

La catena è: **fotografia (windows-status) → alert → finding → intervento tracciato (checklist VA) → verifica con una nuova fotografia**. La verifica chiude il cerchio: dopo aver applicato una remediation, un nuovo snapshot e un `Compare-Snapshot` dimostrano che il finding è sparito.

## Mappatura dei concetti

I due modelli combaciano quasi uno a uno, ed è ciò che rende il raccordo naturale.

```
checklist VA                         windows-status
-----------------------------------  ------------------------------------------------
host (fingerprint: IP, MAC, OS,      sezione 1 IDENTITA + sezione 7 RETE dello snapshot
  FQDN, porte caratteristiche)         (hostname, OS, build; porte in porte_in_ascolto.csv)
intervento / finding                 una riga ALERT di Compare-Snapshot, o un campo ✍️ della mappa
severità (CVSS / crit-high-med-low)  categoria dell'alert (ADMIN, DEFENDER, TRUST, POSTURA, ...)
azione di remediation                la modifica proposta (a micro-step, come da docs/00)
stato (da fare / fatto / risk acc.)  il changelog della mappa (sezione 12) + esito del Compare
riferimenti normativi                da aggiungere a mano nella checklist (vedi sotto)
```

## Cosa fotografa `windows-status` che è direttamente un finding da tracciare

Gli alert di `Compare-Snapshot.ps1` sono già finding pronti per la checklist: nuovo amministratore locale, nuova esclusione Defender (accecamento dell'AV), regola ASR indebolita, nuova root CA non attesa, file hosts modificato, porta in ascolto nuova, servizio con percorso non quotato, driver non firmato. Anche i campi ✍️ della mappa che restano aperti sono finding di postura: BitLocker disattivo, Secure Boot disattivo, firma SMB non richiesta, logging PowerShell non configurato, cache bitmap RDP attiva. Ognuno di questi si copia nella checklist come intervento, con la severità decisa dall'operatore e l'azione di remediation presa da `docs/00`.

## Riferimenti normativi

La checklist VA mappa ogni intervento a ISO/IEC 27001:2022, NIS2, GDPR, Codice Privacy, ISO 17100 e D.Lgs. 231/2001. `windows-status` non li conosce e non deve inventarli: resta sul piano tecnico. L'associazione finding → norma si fa nella checklist, dove il contesto di governance è esplicito. Esempi ricorrenti di hardening endpoint Windows: il controllo degli accessi amministrativi e l'hardening di configurazione ricadono tipicamente sotto ISO 27001 Annex A (gestione accessi, configurazione sicura), la protezione dei dati personali sotto GDPR, e la gestione del rischio e degli incidenti sotto NIS2 quando applicabile.

## Quando NON serve la checklist

Per una singola macchina di lavoro, la mappa (`docs/01`) con il suo changelog è sufficiente a tracciare interventi e reversibilità. La checklist VA dà valore quando i finding sono molti, distribuiti su più host, e serve dimostrare formalmente lo stato di remediation a un auditor o a un cliente: è lì che la dimensione di governance (severità, norme, risk-accepted documentato) ripaga la sovrastruttura. La regola pratica: un solo endpoint → mappa; un parco macchine sotto audit → checklist alimentata dagli snapshot dei singoli endpoint.
