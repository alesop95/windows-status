# windows-status

Fotografia **completa e ripristinabile** di un PC Windows 11, e progetto vivo per tenerla aggiornata nel tempo. Pensato per la mia macchina aziendale (registrata al tenant Microsoft 365 in
modalità workplace join — non Entra ID joined né gestita da Intune — con backup Veeam Agent verso NAS) ma scritto in modo generico e riusabile **ovunque**.

> Gli script sono **proprietari**: la cartella `snapshots/` (dati specifici della macchina) è ignorata da git; si versionano gli script e i documenti.

---

## Idea di fondo

Lo "stato del PC" non lo scrivo a mano: lo faccio **rigenerare dalla macchina** con uno script di **sola lettura**. Lo stesso script fotografa anche **ogni account** (multi-account): utenti, programmi,
e le configurazioni di **Claude**, **git**, **SSH** e dell'**ambiente di sviluppo**. I segreti non vengono mai salvati. Confrontando due fotografie vedo *esattamente* cosa è cambiato.

Il "ripristino ovunque" poggia su due gambe:
1. **Immagine Veeam** dell'intero computer - *bare metal recovery* anche su hardware diverso (il ripristino letterale del PC).
2. **Questo progetto** - la configurazione documentata e riproducibile (reinstallazione software, git/Claude/dotfiles, mappa) per ricostruire l'ambiente anche senza l'immagine.

---

## Regole

1. **Prima la mappatura, poi la pulizia.** Fotografia e documenti *prima* di toccare qualunque cosa.
2. **Prima del debloating, il paracadute:** immagine Veeam recente + punto di ripristino.
3. **Solo modifiche reversibili**, una categoria alla volta, con riavvio e verifica (Outlook/Teams/OneDrive/VPN/SSO) prima di procedere.
4. **Macchina aziendale registrata al tenant** (workplace join, senza Intune): non toccare senza motivo Windows Update, Defender, attivazione Office, Edge/WebView2, OneDrive; non azzerare la telemetria. Se la macchina diventasse Entra ID joined / gestita, questi vincoli tornerebbero imposti.
5. **Tutto a changelog** (sezione finale della mappa): data, cosa, perché, come si annulla.
6. **I segreti non entrano nei file né nel repo.** Si annota solo *dove* sono custoditi.

---