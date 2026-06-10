# 01 -  Mappa configurazione (documento vivo)

> Questo è il documento che **tieni sempre aggiornato**. Le sezioni 🔄 si popolano dai file prodotti da `scripts\Snapshot-Stato.ps1` (cartella `snapshots\snapshot_*`): a fianco di ogni sezione trovi il file sorgente. Le sezioni ✍️ sono decisioni umane da compilare autonomamente.
> 
> **Segreti = mai qui.** Si indica solo *dove* sono custoditi (password manager, Entra ID, ecc.).
> Se si versione una copia *compilata* con dati reali, chiamala `01_MAPPA_CONFIGURAZIONE.compilata.md` (è già in `.gitignore`) e valuta bene prima di un push pubblico.

Ultimo aggiornamento: `____-__-__`  •  Aggiornato da: `__________`

---

## 1. 🔄 Identità macchina -  *da `SUMMARY.txt` / `join_dsregcmd.txt`*

| Campo                    | Valore                                 |
| ------------------------ | -------------------------------------- |
| Hostname                 | `__________`                           |
| Marca / Modello / Serial | `__________`                           |
| CPU / RAM                | `__________`                           |
| Edizione / Build Windows | `__________`                           |
| Stato join               | `Entra ID joined` (AzureAdJoined: YES) |
| Tenant (nome / ID)       | `__________`                           |
| Gestita da Intune/MDM    | `Sì / No` (riga MDMUrl in dsregcmd)    |

---

## 2. 🔄 Account e sessioni -  *da `account_locali.csv`, `sessioni_quser.txt`*

### Amministratori locali

| Account      | Tipo (locale / Entra / Microsoft) | Note         |
| ------------ | --------------------------------- | ------------ |
| `__________` | `__________`                      | `__________` |

### Tutti gli account / profili (multi-account)

| Account (profilo C:\Users) | Uso          | Può accedere? |
| -------------------------- | ------------ | ------------- |
| `__________`               | `__________` | `Sì / No`     |

### Sessioni all'ultimo snapshot

| Utente       | Stato         | Ora accesso  |
| ------------ | ------------- | ------------ |
| `__________` | `Active/Disc` | `__________` |

> ✍️ Account non riconosciuti → indagare. Questo è lo "stato sempre monitorabile" che volevi.

---

## 3. 🔄 Software installato -  *da `software_winget.*`, `software_registro.csv`, `app_appx_*`*

| Software critico                  | Versione     | Origine (WinGet id / Store / installer) |
| --------------------------------- | ------------ | --------------------------------------- |
| Veeam Agent for Microsoft Windows | `__________` | installer Veeam                         |
| Microsoft 365 / Office            | `__________` | `__________`                            |
| `__________`                      | `__________` | `__________`                            |

> Reinstallazione su PC nuovo: `scripts\Reinstall-Software.ps1` (usa `software_winget.json`).

---

## 4. 🔄 Configurazioni di Claude -  per ogni account- — *da `utenti\<acct>_claude.txt`*

> Multi-account: una riga per profilo. Lo snapshot salva inventario + `.claude.json`/`settings.json`/
> `CLAUDE.md` **oscurati** (mai `.credentials.json`).

| Account      | Claude configurato? | Server MCP impostati | CLAUDE.md utente | Note (modello, alias, ecc.) |
| ------------ | ------------------- | -------------------- | ---------------- | --------------------------- |
| `__________` | `Sì/No`             | `__________`         | `Sì/No`          | `__________`                |

> ✍️ Login Claude (account/API key): **dove** è custodito → `__________` (non la credenziale).

---

## 5. 🔄 Configurazioni di sviluppo -  per account- — *da `utenti\<acct>_gitconfig.txt`, `utenti\<acct>_ssh.txt`, `utenti\_dev_<acct>.txt`*

### git

| Account      | user.name / user.email | Credential helper | Default branch | Note         |
| ------------ | ---------------------- | ----------------- | -------------- | ------------ |
| `__________` | `__________`           | `__________`      | `__________`   | `__________` |

### Chiavi SSH (solo riferimento; chiavi private MAI qui)

| Account      | Chiavi presenti (nomi) | Chiave pubblica registrata su | Note         |
| ------------ | ---------------------- | ----------------------------- | ------------ |
| `__________` | `__________`           | `GitHub / NAS / ___`          | `__________` |

### Toolchain (Node/Python/.NET/VS Code/WSL…)

| Account      | Strumenti principali e versioni | Estensioni VS Code chiave | WSL distro   |
| ------------ | ------------------------------- | ------------------------- | ------------ |
| `__________` | `__________`                    | `__________`              | `__________` |

> ✍️ Per avere i dati *live* di sviluppo di ogni account, esegui `Snapshot-Stato.ps1 -Scope User`
> loggato con quell'account (i file su disco si leggono comunque tutti con lo snapshot admin).

---

## 6. 🔄 Servizi modificati rispetto al default -  *confronto via `Compare-Snapshot.ps1`*

| Servizio     | Default      | Impostato    | Data         | Motivo       | Come annullare |
| ------------ | ------------ | ------------ | ------------ | ------------ | -------------- |
| `__________` | `__________` | `__________` | `____-__-__` | `__________` | `__________`   |

---

## 7. 🔄 Avvio e attività pianificate -  *da `avvio.csv`, `attivita_pianificate.csv`*

| Voce         | Tipo           | Stato              | Note         |
| ------------ | -------------- | ------------------ | ------------ |
| `__________` | `Avvio / Task` | `Attivo/Disattivo` | `__________` |

---

## 8. 🔄 Rete -  *da `rete_ipconfig.txt`, `rete_dns.csv`, `unita_di_rete.csv`, `condivisioni.csv`, `firewall_profili.csv`*

| Campo                                 | Valore            |
| ------------------------------------- | ----------------- |
| IP / DHCP / DNS                       | `__________`      |
| VPN aziendale                         | `__________`      |
| NAS (percorso backup)                 | `\\______\______` |
| Unità di rete mappate                 | `__________`      |
| Condivisioni / regole firewall custom | `__________`      |

---

## 9. 🔄✍️ Sicurezza -  *da `SUMMARY.txt`, `sicurezza_postura.txt`, `hotfix.csv`*

| Campo                                      | Valore                                                 |
| ------------------------------------------ | ------------------------------------------------------ |
| Microsoft Defender                         | `Attivo / ___`                                         |
| Firewall                                   | `__________`                                           |
| BitLocker                                  | `Attivo/Disattivo` + tipo protezione                   |
| **Chiave di ripristino BitLocker -  dove** | `Entra ID (entra.microsoft.com) / ___` (NON la chiave) |
| Secure Boot / TPM                          | `__________` (serve snapshot da admin)                 |
| VBS / Credential Guard / HVCI              | `__________`                                           |
| LSA RunAsPPL / UAC                         | `__________`                                           |
| SMBv1 / firma SMB richiesta                | `__________`                                           |
| RDP (+NLA) / WinRM                         | `__________`                                           |
| Build completa / ultimo hotfix             | `__________`                                           |
| Esclusioni AV / regole ASR                 | `__________` (da `defender_esclusioni.csv` / `defender_asr.csv`) |
| Logging PowerShell / audit policy          | `__________` (da `powershell_logging.txt` / `auditpol.txt`) |
| Regole firewall inbound consentite         | `___` regole (da `firewall_regole_inbound_allow.csv`)  |
| Root CA macchina / Trusted Publishers      | `___ / ___` (da `cert_root_ca.csv`, `cert_trusted_publishers.csv`) |
| File hosts / proxy / DoH                   | `__________` (da `hosts.txt`, `proxy_doh.txt`)         |

---

## 10. 🔄 Superficie d'attacco e persistenza -  *da `porte_in_ascolto.csv`, `autoruns_registro.csv`, `wmi_sottoscrizioni.txt`, `attivita_pianificate_azioni.csv`, `driver_non_firmati.csv`, `servizi_percorsi_non_quotati.csv`*

| Controllo                                | Stato all'ultimo snapshot | Note (legittimo? perché)     |
| ---------------------------------------- | ------------------------- | ---------------------------- |
| Porte in ascolto (TCP/UDP)               | `___ TCP / ___ UDP`       | `__________`                 |
| Autoruns registro (Run/Winlogon/IFEO)    | `___ voci -  IFEO: ___`   | `__________`                 |
| Sottoscrizioni WMI                       | `___ binding`             | `SCM Event Log = di serie`   |
| Task non Microsoft (con azioni complete) | `___ task`                | `__________`                 |
| Driver non firmati                       | `___`                     | `__________`                 |
| Servizi con percorso non quotato         | `___`                     | `__________`                 |

> ✍️ Ogni voce che `Compare-Snapshot.ps1` segnala nella sezione **ALERT DI SICUREZZA** (nuovi admin,
> account, autorun, task, porte, cambi StartMode, driver non firmati) va spiegata qui o indagata.

---

## 11. ✍️ Veeam -  riepilogo (dettaglio in `02_VEEAM_BACKUP_PORTABILITA.md`)

| Campo                                  | Valore                                                   |
| -------------------------------------- | -------------------------------------------------------- |
| Prodotto / versione                    | `Veeam Agent for Microsoft Windows ___`                  |
| Tipo di backup                         | `Intero computer` (richiesto per ripristino su altro PC) |
| Destinazione                           | `NAS: \\______\______`                                   |
| Pianificazione / Retention             | `__________`                                             |
| Cifratura                              | `Sì/No` -  password in: `__________` (password manager)  |
| Credenziali NAS -  dove                | `__________` (non le credenziali)                        |
| **Supporto di ripristino creato il**   | `____-__-__` -  conservato in: `__________`              |
| **Ultimo test di ripristino riuscito** | `____-__-__`                                             |

---

## 12. ✍️ Registro modifiche (changelog)

> Ogni intervento qui. È ciò che rende tutto reversibile e auditabile.

| Data         | Area        | Cosa ho cambiato             | Strumento | Perché          | Come si annulla          |
| ------------ | ----------- | ---------------------------- | --------- | --------------- | ------------------------ |
| `____-__-__` | Esempio: AI | Disattivati Recall e Copilot | Winslop   | privacy/risorse | toggle inverso / restore |
|              |             |                              |           |                 |                          |
