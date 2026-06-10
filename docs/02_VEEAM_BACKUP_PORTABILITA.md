# 02 — Veeam su NAS: backup ripristinabile su un altro PC, in qualsiasi momento

Obiettivo: **«il backup Veeam deve essere installabile su un altro PC in qualsiasi momento.»**
Si fa, ma servono **tre cose insieme** — manca una sola e il ripristino su hardware nuovo fallisce.

---

## La regola in una frase

1. Backup immagine dell'**INTERO computer** (non solo cartelle).
2. **Supporto di ripristino Veeam** (chiavetta USB avviabile) **con i driver di rete**, perché il
   backup è sul **NAS** e il PC nuovo deve poter raggiungere la rete in fase di ripristino.
3. **Password di cifratura** del backup + **credenziali del NAS** + (se i dischi sono cifrati)
   **chiave di ripristino BitLocker**.

Manca 1 → hai i file ma non il sistema. Manca 2 → non avvii il PC nuovo o non vedi il NAS.
Manca 3 → il backup è illeggibile / il disco non si sblocca. **Backup inutile.**

---

## Perché "Intero computer"

Veeam Agent fa **bare metal recovery**: ripristina l'immagine completa (OS + programmi + impostazioni
+ dati) e la adatta a **hardware diverso**. È ciò che rende il backup "installabile altrove". Un backup
di sole cartelle ti dà solo i file, non ricostruisce Windows e i programmi → il job dev'essere
**Entire computer**.

---

## Configurazione del job (poi annotala nella mappa, sez. 11)

| Impostazione | Scelta consigliata |
|--------------|--------------------|
| Modalità | **Entire computer** |
| Destinazione | **Shared folder (NAS)**: `\\NAS\backup\...` con credenziali dedicate |
| Pianificazione | Almeno giornaliera + backup manuale prima di ogni grande modifica |
| Retention | Abbastanza punti da coprire un problema scoperto in ritardo (es. 7–14) |
| Cifratura | **Attiva**, password forte salvata nel password manager |

### Il NAS è una sola copia: completala
Un backup solo sul NAS è esposto a guasti del NAS e a ransomware (le share SMB sono raggiungibili).
Applica la **3-2-1**: oltre al NAS, tieni una **seconda copia** su disco USB esterno e/o una copia
**offsite/immutabile** (snapshot immutabili del NAS, o cloud). Annota dove sono le copie.

---

## Supporto di ripristino (il pezzo che quasi tutti dimenticano)

1. In Veeam Agent crea il **Recovery Media** su chiavetta USB.
2. **Includi i driver** (rete e storage soprattutto): senza driver di rete non raggiungi il NAS in
   ripristino; senza driver storage non vedi il disco di destinazione.
3. Etichetta la chiavetta (data + PC) e conservala con le credenziali del NAS (nel password manager).
4. **Rigeneralo** dopo aggiornamenti importanti di Windows o cambi hardware. Annota la data nella mappa.

---

## Ripristino su un PC nuovo/diverso (dal NAS)

> Da provare **almeno una volta** prima di averne bisogno (vedi "Test").

1. Avvia il PC di destinazione dal **supporto di ripristino Veeam** (boot da USB).
2. Configura la **rete** nel menu di ripristino (se serve, carica i driver dalla chiavetta) così da
   raggiungere il NAS.
3. Scegli **Bare Metal Recovery** → sorgente **Shared folder**: inserisci `\\NAS\share` e le
   **credenziali del NAS**.
4. Inserisci la **password di cifratura** del backup.
5. Seleziona il **punto di ripristino** (la data).
6. Scegli il **disco di destinazione**; Veeam adatta l'immagine all'hardware diverso (fornisci driver
   storage/rete dalla chiavetta se richiesti).
7. Avvia, attendi, riavvia rimuovendo la chiavetta.

### Dopo il primo avvio — **specifico per Entra ID joined**
- Verifica i driver mancanti in **Gestione dispositivi**.
- Riattiva **Windows** e **Office/M365** se richiesto (hardware diverso può richiederlo).
- **L'identità del dispositivo in Entra ID è legata all'hardware/TPM:** dopo un ripristino su un PC
  diverso il join può non corrispondere più. Probabile **ri-registrazione/ri-join** del dispositivo
  in Entra ID (e nuova conformità Intune). Pianificalo: non è un errore, è normale su hardware nuovo.
- Se i dischi usano **BitLocker**, la **chiave di ripristino** dei dispositivi Entra ID è di norma
  **archiviata in Entra ID**: la recuperi da `entra.microsoft.com` (admin) o dall'account utente.
  Verifica *prima* di averne bisogno che sia effettivamente lì.

---

## Test di ripristino (obbligatorio)

Un backup non testato è solo una speranza. Almeno una volta, e dopo ogni cambiamento importante:
- **Completo:** ripristina su un **disco di scorta** o in una **macchina virtuale** dal NAS, verifica
  avvio e programmi chiave. Annota la data in `01_…` sez. 11.
- **Minimo:** ripristina **singoli file** dal backup, per confermare leggibilità + password di cifratura.

---

## Da annotare nella mappa (sez. 11)

Versione Veeam, tipo job (Intero computer), percorso NAS, dove sono le credenziali NAS, retention,
cifratura sì/no e *dove* è la password, copie aggiuntive (USB/offsite), data del supporto di ripristino
e **dove** è, e la **data dell'ultimo test riuscito**.

> Nota prodotto: questa guida assume **Veeam Agent for Microsoft Windows**. Funzioni e nomi delle voci
> possono variare tra le versioni: fai sempre riferimento alla documentazione ufficiale Veeam corrente.
