# =============================================================================
#  Prima-Installazione.ps1  -  prima installazione di un PC Windows nuovo
#  windows-status. Vedi docs\16.
# =============================================================================
#  COSA E'. Non un nuovo strumento di pulizia: una CATENA DI CUSTODIA attorno a
#  due strumenti di terze parti che la pulizia la fanno gia' bene, e che da soli
#  non lasciano traccia di cosa hanno cambiato.
#
#      zoicware/RemoveWindowsAI   rimuove Copilot, Recall, Click to Do e i
#                                 pacchetti AI anche non rimovibili  (MIT)
#      Raphire/Win11Debloat       app preinstallate, telemetria, interfaccia,
#                                 reversibile per dichiarazione dell'autore (MIT)
#
#  Quello che aggiunge questo script e' cio' che al progetto serve e che a loro
#  non compete: versioni appuntate e verificate per digest invece di codice
#  remoto eseguito al volo, paracadute prima di toccare, conferma esplicita a
#  ogni passo, e soprattutto una fotografia PRIMA e una DOPO, confrontate, cosi'
#  che "cosa ha cambiato" sia una domanda con una risposta scritta.
#
#  PALETTI DEL PROGETTO CHE QUESTO SCRIPT FA RISPETTARE
#    1  sola lettura per default: senza -Applica non tocca niente
#    2  paracadute prima di modificare: punto di ripristino e immagine
#    3  una categoria alla volta, con verifica in mezzo
#    4  macchina aziendale: si ferma, perche' i due strumenti toccano Windows
#       Update, telemetria e BitLocker, cioe' cio' che il paletto 4 vieta
#    5  prima la mappatura, poi la pulizia: snapshot prima, sempre
#    6  changelog: a fine corsa stampa la riga da incollare nella mappa
#
#  NON RIAVVIA MAI DA SE'. Dove serve un riavvio lo dice e si ferma.
#
#  USO
#    .\Prima-Installazione.ps1                  # piano e prerequisiti (sola lettura)
#    .\Prima-Installazione.ps1 -Scarica         # scarica e verifica i digest
#    .\Prima-Installazione.ps1 -Applica         # catena completa, conferma per passo
#    .\Prima-Installazione.ps1 -Applica -Passi AI
#    .\Prima-Installazione.ps1 -Applica -Passi DEBLOAT -OpzioniDebloat '-RemoveApps','-DisableTelemetry'
#    .\Prima-Installazione.ps1 -Controlla       # cosa e' rimasto, dopo
# =============================================================================

[CmdletBinding()]
param(
    # Scarica gli strumenti alle versioni appuntate e ne verifica il digest.
    # Non esegue niente: si puo' fare prima, anche su un'altra macchina.
    [switch]   $Scarica,

    # Esegue la catena. Ogni passo che modifica chiede conferma digitando SI.
    [switch]   $Applica,

    # Controllo dopo l'intervento: cosa resta dell'AI, sola lettura.
    [switch]   $Controlla,

    # Sottoinsieme di passi: SNAPSHOT, PARACADUTE, AI, DEBLOAT, CONTROLLO.
    [string[]] $Passi,

    # Argomenti passati tali e quali a Win11Debloat.ps1. Senza, parte il suo menu.
    [string[]] $OpzioniDebloat,

    # Argomenti passati tali e quali a RemoveWindowsAi.ps1. Senza, parte la sua UI.
    [string[]] $OpzioniAI,

    # Cartella di lavoro per il codice di terze parti. Fuori dal repository:
    # codice scaricato non sta accanto agli script del progetto.
    [string]   $Cartella = (Join-Path $env:TEMP 'windows-status-prima-installazione'),

    # Procede anche su macchina unita a dominio o registrata a un tenant.
    # Serve una decisione umana, non un parametro dimenticato: vedi paletto 4.
    [switch]   $ForzaAziendale,

    # Salta la fotografia iniziale. Si usa solo se e' gia' stata fatta a mano.
    [switch]   $SenzaSnapshot
)

$ErrorActionPreference = 'Stop'
$VERSIONE = '1.0'

$Radice     = Split-Path $PSScriptRoot -Parent
$Manifesto  = Join-Path $PSScriptRoot 'prima-installazione\strumenti.json'
$PS51       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$TUTTI      = @('SNAPSHOT','PARACADUTE','AI','DEBLOAT','CONTROLLO')

if (-not $Passi -or $Passi.Count -eq 0) { $Passi = $TUTTI }
$Passi = @($Passi | ForEach-Object { $_ -split '[,;\s]+' } |
           Where-Object { $_ } | ForEach-Object { $_.ToUpper().Trim() })
$ignoti = @($Passi | Where-Object { $TUTTI -notcontains $_ })
if ($ignoti.Count -gt 0) { throw "Passi non riconosciuti: $($ignoti -join ', '). Ammessi: $($TUTTI -join ', ')." }

function Titolo { param([string]$T)
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host "  $T" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkGray
}
function Ok    { param([string]$T) Write-Host "  [ok]      $T" -ForegroundColor Green }
function Info  { param([string]$T) Write-Host "  [info]    $T" }
function Avviso{ param([string]$T) Write-Host "  [attenzione] $T" -ForegroundColor Yellow }
function Stop_ { param([string]$T) Write-Host "  [fermo]   $T" -ForegroundColor Red }

function Test-Amministratore {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { $false }
}

function Conferma {
    param([string]$Domanda)
    Write-Host ''
    Write-Host "  $Domanda" -ForegroundColor Yellow
    $r = Read-Host '  Digita SI per procedere, qualunque altra cosa per saltare'
    return ($r -eq 'SI')
}

function Leggi-Manifesto {
    if (-not (Test-Path $Manifesto)) { throw "Manifesto non trovato: $Manifesto" }
    $j = Get-Content $Manifesto -Raw -Encoding UTF8 | ConvertFrom-Json
    return $j.strumenti
}

# --- prerequisiti ------------------------------------------------------------

function Stato-Macchina {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

    $tenant = $false
    try {
        $dsreg = & dsregcmd.exe /status 2>$null
        if ($dsreg -match 'AzureAdJoined\s*:\s*YES' -or $dsreg -match 'WorkplaceJoined\s*:\s*YES' -or
            $dsreg -match 'DomainJoined\s*:\s*YES') { $tenant = $true }
    } catch { }
    if ($cs -and $cs.PartOfDomain) { $tenant = $true }

    $mdm = $false
    try {
        $mdm = [bool](Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue |
               Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).EnrollmentState -eq 1 })
    } catch { }

    $sr = $null
    try { $sr = @(Get-ComputerRestorePoint -ErrorAction Stop) } catch { }

    [pscustomobject]@{
        Nome            = if ($cs) { $cs.Name } else { $env:COMPUTERNAME }
        OS              = if ($os) { "$($os.Caption) build $($os.BuildNumber)" } else { 'sconosciuto' }
        Edizione        = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).EditionID
        Versione        = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
        Amministratore  = Test-Amministratore
        PowerShell      = $PSVersionTable.PSVersion.ToString()
        Aziendale       = $tenant
        Mdm             = $mdm
        PuntiRipristino = if ($sr) { $sr.Count } else { 0 }
        UltimoPunto     = if ($sr -and $sr.Count -gt 0) { ($sr | Select-Object -Last 1).CreationTime } else { $null }
        LiberiGB        = [math]::Round((Get-PSDrive C -ErrorAction SilentlyContinue).Free / 1GB, 1)
        Git             = [bool](Get-Command git -ErrorAction SilentlyContinue)
    }
}

function Mostra-Piano {
    param($S, $Strumenti)
    Titolo "PIANO - prima installazione, windows-status v$VERSIONE"
    Info "macchina        : $($S.Nome)"
    Info "sistema         : $($S.OS)  $($S.Versione)  edizione $($S.Edizione)"
    Info "PowerShell      : $($S.PowerShell)"
    Info "spazio libero C : $($S.LiberiGB) GB"
    Info "cartella lavoro : $Cartella"
    Write-Host ''

    if ($S.Amministratore) { Ok 'eseguito da amministratore' }
    else { Stop_ 'NON amministratore: nessuno dei due strumenti puo'' funzionare' }

    if ($S.Edizione -match 'Home') {
        Avviso 'edizione Home: RemoveWindowsAI non garantisce la rimozione completa'
    } else { Ok "edizione $($S.Edizione): adatta alla rimozione completa" }

    if ($S.Aziendale -or $S.Mdm) {
        Stop_ 'macchina unita a dominio, registrata a un tenant o gestita via MDM'
        Info  '  Il paletto 4 del progetto vieta di toccare Windows Update, Defender,'
        Info  '  attivazione Office, Edge/WebView2, OneDrive e telemetria senza ordine'
        Info  '  esplicito, e i due strumenti toccano esattamente quelle cose.'
        Info  '  Serve -ForzaAziendale, cioe'' una decisione presa e non dimenticata.'
    } else { Ok 'macchina non aziendale: nessun vincolo di tenant' }

    if ($S.PuntiRipristino -gt 0) { Ok "punti di ripristino presenti: $($S.PuntiRipristino), ultimo $($S.UltimoPunto)" }
    else { Avviso 'nessun punto di ripristino: il ripristino configurazione e'' probabilmente spento' }

    if ($S.Git) { Ok 'git presente: gli strumenti si prendono al commit appuntato' }
    else { Avviso 'git assente: si ripiega sullo zip del commit, verificato per digest' }

    Write-Host ''
    Write-Host '  Strumenti appuntati nel manifesto:' -ForegroundColor Cyan
    foreach ($t in $Strumenti) {
        $rev = if ($t.reversibile) { 'reversibile' } else { 'NON REVERSIBILE' }
        Write-Host ("    {0,-18} {1}  commit {2}  [{3}]" -f $t.nome, $t.licenza, $t.commit.Substring(0,10), $rev)
    }

    Write-Host ''
    Write-Host '  Ordine della catena:' -ForegroundColor Cyan
    Write-Host '    1 SNAPSHOT    fotografia della macchina vergine (Snapshot-Stato.ps1)'
    Write-Host '    2 PARACADUTE  punto di ripristino, e conferma che esista un''immagine'
    Write-Host '    3 AI          RemoveWindowsAI, il passo senza ritorno. Poi RIAVVIO manuale'
    Write-Host '    4 DEBLOAT     Win11Debloat, reversibile. Poi RIAVVIO manuale'
    Write-Host '    5 CONTROLLO   seconda fotografia e confronto: cosa e'' cambiato davvero'
    Write-Host ''
    Write-Host "  Passi scelti: $($Passi -join ', ')"
    Write-Host ''
    Write-Host '  Nessuna modifica e'' stata fatta. Per agire: -Applica' -ForegroundColor Green
}

# --- approvvigionamento ------------------------------------------------------

function Scarica-Strumento {
    param($T)
    $dest = Join-Path $Cartella ("{0}-{1}" -f $T.nome, $T.commit.Substring(0,10))
    $ingresso = Join-Path $dest $T.ingresso

    if (Test-Path $ingresso) {
        Info "$($T.nome): gia' presente in $dest"
    } else {
        if (-not (Test-Path $Cartella)) { New-Item -ItemType Directory -Path $Cartella -Force | Out-Null }
        if (Get-Command git -ErrorAction SilentlyContinue) {
            Info "$($T.nome): clone e checkout del commit appuntato"
            & git -c advice.detachedHead=false clone --quiet $T.repo $dest 2>&1 | Out-Null
            & git -C $dest checkout --quiet $T.commit 2>&1 | Out-Null
        } else {
            Info "$($T.nome): scarico lo zip del commit appuntato"
            $owner = ($T.repo -split '/')[-2]
            $nome  = ($T.repo -split '/')[-1]
            $zip   = Join-Path $Cartella ("{0}-{1}.zip" -f $nome, $T.commit.Substring(0,10))
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri "https://codeload.github.com/$owner/$nome/zip/$($T.commit)" -OutFile $zip -UseBasicParsing
            Expand-Archive -Path $zip -DestinationPath $Cartella -Force
            $estratta = Join-Path $Cartella "$nome-$($T.commit)"
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Move-Item $estratta $dest
            Remove-Item $zip -Force
        }
    }

    if (-not (Test-Path $ingresso)) { throw "$($T.nome): file di ingresso assente dopo lo scaricamento: $ingresso" }

    # Il digest e' il cancello: se non corrisponde, non si esegue niente.
    $h = (Get-FileHash $ingresso -Algorithm SHA256).Hash.ToLower()
    if ($h -ne $T.sha256.ToLower()) {
        Stop_ "$($T.nome): DIGEST DIVERSO da quello appuntato nel manifesto"
        Info  "  atteso  : $($T.sha256)"
        Info  "  trovato : $h"
        Info  '  Puo'' voler dire che il progetto a monte e'' cambiato, oppure che il'
        Info  '  file e'' stato alterato lungo la strada. In entrambi i casi la catena'
        Info  '  si ferma: si rivede il codice, si aggiorna il manifesto a mano, si'
        Info  '  annota nel changelog. Non si procede per inerzia.'
        throw "Digest non corrispondente per $($T.nome)."
    }
    Ok "$($T.nome): digest verificato ($($T.sha256.Substring(0,16))...)"
    return $ingresso
}

# --- passi -------------------------------------------------------------------

function Passo-Snapshot {
    param([string]$Momento)
    $s = Join-Path $PSScriptRoot 'Snapshot-Stato.ps1'
    if (-not (Test-Path $s)) { Avviso "Snapshot-Stato.ps1 non trovato: fotografia $Momento saltata"; return }
    Info "fotografia $Momento in corso (sola lettura, puo' durare qualche minuto)"
    & $PS51 -NoProfile -ExecutionPolicy Bypass -File $s -Scope Machine
    Ok "fotografia $Momento eseguita"
}

function Passo-Paracadute {
    Titolo 'PARACADUTE'
    Info 'Il ritorno indietro da RemoveWindowsAI non e'' un parametro: e'' un''immagine.'
    Info 'Il punto di ripristino copre il registro e i driver, non i pacchetti rimossi.'

    $sr = $null
    try { $sr = Get-ComputerRestorePoint -ErrorAction Stop } catch { }
    if (-not $sr) {
        Avviso 'Ripristino configurazione di sistema disattivato su C:'
        if (Conferma 'Attivo il ripristino configurazione su C: ? (modifica il sistema)') {
            Enable-ComputerRestore -Drive 'C:\'
            Ok 'ripristino configurazione attivato'
        } else { Avviso 'ripristino configurazione lasciato spento' }
    }

    if (Conferma 'Creo un punto di ripristino adesso?') {
        try {
            Checkpoint-Computer -Description 'windows-status prima installazione' -RestorePointType 'MODIFY_SETTINGS'
            Ok 'punto di ripristino creato'
        } catch {
            Avviso "punto di ripristino non creato: $($_.Exception.Message)"
            Info  '  Windows ne consente uno ogni 24 ore salvo forzature: se ne esiste'
            Info  '  gia'' uno di oggi va bene lo stesso.'
        }
    }

    Write-Host ''
    Info 'Immagine di sistema: questo script non la sa creare e non finge di saperlo.'
    Info 'Su una macchina nuova bastano pochi minuti con Veeam Agent (vedi docs/02).'
    if (-not (Conferma 'Confermi che esiste un''immagine recente, o che accetti di non averla?')) {
        throw 'Fermato: niente paracadute, niente passo senza ritorno.'
    }
    Ok 'paracadute confermato'
}

function Passo-AI {
    param([string]$Ingresso)
    Titolo 'AI - RemoveWindowsAI (passo senza ritorno)'
    Info 'Rimuove Copilot, Recall, Click to Do, i pacchetti AI anche non rimovibili,'
    Info 'le voci nel CBS store e le attivita'' pianificate; installa un pacchetto'
    Info 'fittizio perche'' Windows Update non li rimetta.'
    Avviso 'Alcuni antivirus di terze parti lo segnalano: e'' un falso positivo noto.'
    Avviso 'Si esegue con Windows PowerShell 5.1: PowerShell 7 non e'' supportato.'
    if ($OpzioniAI) { Info "opzioni: $($OpzioniAI -join ' ')" } else { Info 'nessuna opzione: parte la sua interfaccia' }

    if (-not (Conferma 'Eseguo RemoveWindowsAI adesso?')) { Avviso 'passo AI saltato'; return $false }

    $arg = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Ingresso)
    if ($OpzioniAI) { $arg += $OpzioniAI }
    $p = Start-Process -FilePath $PS51 -ArgumentList $arg -Wait -PassThru -Verb RunAs
    Info "RemoveWindowsAI terminato con codice $($p.ExitCode)"
    return $true
}

function Passo-Debloat {
    param([string]$Ingresso)
    Titolo 'DEBLOAT - Win11Debloat (reversibile)'
    Info 'App preinstallate, telemetria, contenuti suggeriti, barra applicazioni,'
    Info 'menu Start, Esplora file, menu contestuale.'
    Info 'L''autore documenta come tornare indietro, e quasi tutte le app si'
    Info 'reinstallano dallo Store: vedi la pagina Reverting Changes del progetto.'
    Avviso 'Alcune sue opzioni toccano Windows Update, telemetria e cifratura'
    Avviso 'automatica BitLocker: su macchina aziendale sono vietate dal paletto 4.'
    if ($OpzioniDebloat) { Info "opzioni: $($OpzioniDebloat -join ' ')" } else { Info 'nessuna opzione: parte il suo menu' }

    if (-not (Conferma 'Eseguo Win11Debloat adesso?')) { Avviso 'passo DEBLOAT saltato'; return $false }

    $arg = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Ingresso)
    if ($OpzioniDebloat) { $arg += $OpzioniDebloat }
    $p = Start-Process -FilePath $PS51 -ArgumentList $arg -Wait -PassThru -Verb RunAs
    Info "Win11Debloat terminato con codice $($p.ExitCode)"
    return $true
}

function Passo-Controllo {
    Titolo 'CONTROLLO - cosa e'' rimasto'
    $trovati = @()

    $appx = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -match 'Copilot|Recall|AIX|AppChat|WindowsWorkload|ClickToDo' })
    if ($appx.Count -gt 0) {
        Avviso "pacchetti AI ancora presenti: $($appx.Count)"
        $appx | Select-Object -First 10 | ForEach-Object { Info "    $($_.Name)" }
        $trovati += 'appx'
    } else { Ok 'nessun pacchetto AI fra quelli cercati' }

    $svc = Get-Service -Name 'WSAIFabricSvc' -ErrorAction SilentlyContinue
    if ($svc) {
        Avviso "servizio WSAIFabricSvc presente, stato $($svc.Status), avvio $($svc.StartType)"
        $trovati += 'servizio'
    } else { Ok 'servizio WSAIFabricSvc assente' }

    $task = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
              Where-Object { $_.TaskName -match 'Recall|Copilot|AI' })
    if ($task.Count -gt 0) {
        Avviso "attivita' pianificate AI: $($task.Count)"
        $trovati += 'attivita'
    } else { Ok 'nessuna attivita'' pianificata AI fra quelle cercate' }

    $feat = Get-WindowsOptionalFeature -Online -FeatureName 'Recall' -ErrorAction SilentlyContinue
    if ($feat) { Info "funzionalita' Recall: $($feat.State)" }

    Write-Host ''
    if ($trovati.Count -eq 0) { Ok 'controllo pulito' }
    else { Avviso "resta qualcosa ($($trovati -join ', ')): vedi docs/16 sezione sui residui" }

    $c = Join-Path $PSScriptRoot 'Compare-Snapshot.ps1'
    if (Test-Path $c) {
        Info 'confronto fra le due fotografie piu'' recenti'
        & $PS51 -NoProfile -ExecutionPolicy Bypass -File $c
    } else { Avviso 'Compare-Snapshot.ps1 non trovato: confronto saltato' }
}

# --- esecuzione --------------------------------------------------------------

$S = Stato-Macchina
$Strumenti = Leggi-Manifesto

if ($Controlla) { Passo-Controllo; return }

if (-not $Applica -and -not $Scarica) { Mostra-Piano $S $Strumenti; return }

if ($Scarica -and -not $Applica) {
    Titolo 'SCARICAMENTO E VERIFICA'
    foreach ($t in $Strumenti) { Scarica-Strumento $t | Out-Null }
    Write-Host ''
    Ok "strumenti pronti e verificati in $Cartella"
    Info 'Nessuna modifica al sistema. Per agire: -Applica'
    return
}

# --- da qui in poi si modifica il sistema ---

Mostra-Piano $S $Strumenti

if (-not $S.Amministratore) { throw 'Servono privilegi di amministratore.' }

if (($S.Aziendale -or $S.Mdm) -and -not $ForzaAziendale) {
    throw ('Macchina aziendale (dominio, tenant o MDM). Il paletto 4 del progetto ' +
           'vieta di toccare Windows Update, Defender, telemetria e affini senza ordine ' +
           'esplicito. Se l''ordine c''e'', ripeti con -ForzaAziendale.')
}
if ($S.Aziendale -or $S.Mdm) { Avviso 'macchina aziendale, si procede per decisione esplicita (-ForzaAziendale)' }

if (-not (Conferma 'Confermi di voler iniziare la catena su QUESTA macchina?')) {
    Info 'niente fatto'
    return
}

$eseguiti = @()

if ($Passi -contains 'SNAPSHOT' -and -not $SenzaSnapshot) {
    Titolo 'SNAPSHOT - fotografia prima di toccare'
    Passo-Snapshot 'iniziale'
    $eseguiti += 'snapshot iniziale'
}

if ($Passi -contains 'PARACADUTE') { Passo-Paracadute; $eseguiti += 'paracadute' }

if ($Passi -contains 'AI') {
    $ing = Scarica-Strumento ($Strumenti | Where-Object { $_.nome -eq 'RemoveWindowsAI' })
    if (Passo-AI $ing) {
        $eseguiti += 'RemoveWindowsAI'
        Write-Host ''
        Avviso 'RIAVVIO NECESSARIO prima di proseguire.'
        Info   'Questo script non riavvia mai da se''. Riavvia quando ti e'' comodo e'
        Info   'poi riprendi con:  .\Prima-Installazione.ps1 -Applica -Passi DEBLOAT,CONTROLLO'
        if (-not (Conferma 'Hai gia'' riavviato e vuoi proseguire adesso lo stesso?')) {
            Info 'catena sospesa al punto giusto'
            return
        }
    }
}

if ($Passi -contains 'DEBLOAT') {
    $ing = Scarica-Strumento ($Strumenti | Where-Object { $_.nome -eq 'Win11Debloat' })
    if (Passo-Debloat $ing) {
        $eseguiti += 'Win11Debloat'
        Avviso 'Un riavvio rende effettive tutte le modifiche di interfaccia.'
    }
}

if ($Passi -contains 'CONTROLLO') {
    if (-not $SenzaSnapshot) { Passo-Snapshot 'finale'; $eseguiti += 'snapshot finale' }
    Passo-Controllo
}

Titolo 'FATTO'
Info "passi eseguiti: $($eseguiti -join ', ')"
Write-Host ''
Write-Host '  Riga da incollare nel changelog della mappa (paletto 6):' -ForegroundColor Cyan
Write-Host ("  | {0} | Prima installazione: {1} | PC nuovo, riduzione AI e debloating | Immagine di sistema; Win11Debloat reversibile, RemoveWindowsAI no |" -f
            (Get-Date -Format 'yyyy-MM-dd'), ($eseguiti -join ' + '))
