# =============================================================================
#  Prepara-Chiavetta.ps1  -  prepara la cartella da portare sul PC nuovo
#  windows-status. Vedi docs\16 e LEGGIMI-PC-NUOVO.md
# =============================================================================
#  IL PROBLEMA. La catena della prima installazione presuppone tre cose che su
#  un PC appena acceso spesso non ci sono: il progetto, la rete per scaricare
#  gli strumenti, e il manifesto WinGet della macchina VECCHIA, che nasce da uno
#  snapshot e non sta nel repository perche' snapshots\ e' ignorata da git.
#
#  COSA FA. Dalla macchina che ha gia' tutto, mette in una cartella sola:
#    - il progetto, senza la cronologia git, senza snapshots\ e senza _notes\
#    - gli strumenti di terze parti alle versioni appuntate, GIA' VERIFICATI
#    - il software_winget.json piu' recente, se c'e' e se lo si vuole
#    - il profilo, se esiste, con un avviso se contiene un token
#    - un LEGGIMI con la sequenza e lo stato di cio' che c'e' dentro
#
#  Quella cartella si copia su una chiavetta e basta a se' stessa: sul PC nuovo
#  non serve ne' rete ne' git.
#
#  SOLA LETTURA sul sistema: scrive soltanto dentro la cartella di destinazione.
#
#  USO
#    .\Prepara-Chiavetta.ps1 -Destinazione E:\
#    .\Prepara-Chiavetta.ps1 -Destinazione D:\consegna -SenzaWinget
#    .\Prepara-Chiavetta.ps1 -Destinazione D:\consegna -ConProfilo
# =============================================================================

[CmdletBinding()]
param(
    # Dove preparare la cartella. Dentro viene creata windows-status-PC-NUOVO.
    [Parameter(Mandatory = $true)]
    [string] $Destinazione,

    # Non copiare il manifesto WinGet (elenco dei programmi della macchina vecchia).
    [switch] $SenzaWinget,

    # Copia anche prima-installazione\profilo.json, che PUO' contenere il token
    # di Netdata. Senza questo interruttore viene copiato solo l'esempio.
    [switch] $ConProfilo,

    # Non scaricare gli strumenti: utile se la cartella e' gia' stata preparata
    # una volta e si vuole solo aggiornare il progetto.
    [switch] $SenzaStrumenti
)

$ErrorActionPreference = 'Stop'

$Radice = Split-Path $PSScriptRoot -Parent
$Nome   = 'windows-status-PC-NUOVO'
$Dest   = Join-Path $Destinazione $Nome

function Ok     { param([string]$T) Write-Host "  [ok]      $T" -ForegroundColor Green }
function Info   { param([string]$T) Write-Host "  [info]    $T" }
function Avviso { param([string]$T) Write-Host "  [attenzione] $T" -ForegroundColor Yellow }

Write-Host ''
Write-Host '========================================================================' -ForegroundColor DarkGray
Write-Host '  PREPARAZIONE DELLA CARTELLA PER IL PC NUOVO' -ForegroundColor Cyan
Write-Host '========================================================================' -ForegroundColor DarkGray

# Il disco deve esserci (una chiavetta non inserita e' l'errore tipico), la
# cartella no: quella la si crea.
$disco = Split-Path $Destinazione -Qualifier -ErrorAction SilentlyContinue
if ($disco -and -not (Test-Path "$disco\")) { throw "Disco non raggiungibile: $disco (chiavetta inserita?)" }
if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
Info "cartella: $Dest"

# --- 1. il progetto ----------------------------------------------------------

$progetto = Join-Path $Dest 'windows-status'
Info 'copio il progetto (senza cronologia git, snapshots e note private)'
$esclusiDir  = @('.git', 'snapshots', '_notes')
$esclusiFile = @('CLAUDE.local.md', 'profilo.json')

& robocopy.exe $Radice $progetto /E /NFL /NDL /NJH /NJS /NC /NS /NP `
    /XD @esclusiDir /XF @esclusiFile | Out-Null
# robocopy usa i codici di uscita come maschera di bit: sotto 8 e' successo.
if ($LASTEXITCODE -ge 8) { throw "robocopy non riuscito (codice $LASTEXITCODE)" }
$LASTEXITCODE = 0
Ok "progetto copiato ($(@(Get-ChildItem $progetto -Recurse -File).Count) file)"

# --- 2. gli strumenti di terze parti -----------------------------------------

$strumenti = Join-Path $Dest 'strumenti'
if (-not $SenzaStrumenti) {
    Info 'scarico e verifico gli strumenti alle versioni appuntate'
    $pi = Join-Path $PSScriptRoot 'Prima-Installazione.ps1'
    # Uno script PowerShell non imposta $LASTEXITCODE: se il digest non torna
    # lancia un'eccezione, e con ErrorActionPreference a Stop arriva fin qui.
    try { & $pi -Scarica -Cartella $strumenti }
    catch { throw "scaricamento o verifica non riusciti, la cartella NON e' pronta: $($_.Exception.Message)" }
    Ok 'strumenti presenti e verificati'
} else {
    if (Test-Path $strumenti) { Info 'strumenti: lasciati come sono' }
    else { Avviso 'strumenti NON presenti: sul PC nuovo servira'' la rete' }
}

# --- 3. il manifesto WinGet della macchina vecchia ---------------------------

if (-not $SenzaWinget) {
    $snap = Join-Path $Radice 'snapshots'
    $json = Get-ChildItem $snap -Recurse -Filter 'software_winget.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1
    if ($json) {
        Copy-Item $json.FullName (Join-Path $Dest 'software_winget.json') -Force
        $n = 0
        try {
            $inv = Get-Content $json.FullName -Raw | ConvertFrom-Json
            $n = @($inv.Sources | ForEach-Object { $_.Packages }).Count
        } catch { }
        Ok "software_winget.json copiato ($n pacchetti, del $($json.LastWriteTime.ToString('yyyy-MM-dd')))"
        Avviso 'contiene l''elenco dei programmi di questa macchina: rivedilo prima di usarlo'
    } else {
        Avviso 'nessun software_winget.json negli snapshot: sul PC nuovo la voce 5 non avra'' nulla da importare'
        Info  '  si produce con:  .\Avvia.ps1  voce 1, da un account interattivo con WinGet'
    }
}

# --- 4. il profilo ------------------------------------------------------------

$profiloReale = Join-Path $PSScriptRoot 'prima-installazione\profilo.json'
if ($ConProfilo -and (Test-Path $profiloReale)) {
    Copy-Item $profiloReale (Join-Path $progetto 'scripts\prima-installazione\profilo.json') -Force
    $contenuto = Get-Content $profiloReale -Raw
    if ($contenuto -match '"token"\s*:\s*"[^"]+"') {
        Avviso 'il profilo copiato CONTIENE UN TOKEN Netdata: la chiavetta diventa un segreto'
        Avviso 'da trattare come tale, e non va lasciata in giro ne'' riusata per altro'
    } else {
        Ok 'profilo copiato (nessun token dentro)'
    }
} elseif (Test-Path $profiloReale) {
    Info 'profilo.json esiste ma NON e'' stato copiato (serve -ConProfilo: puo'' contenere un token)'
}

# --- 5. il leggimi della cartella --------------------------------------------

$righe = @(
    "CARTELLA DI PRIMA INSTALLAZIONE - windows-status"
    "preparata il $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    ""
    "COSA C'E' DENTRO"
    "  windows-status\          il progetto, senza cronologia git e senza dati di macchina"
    "  strumenti\               RemoveWindowsAI, Win11Debloat e l'MSI di Netdata, verificati"
    "  software_winget.json     programmi della macchina vecchia, da rivedere prima di importare"
    ""
    "COSA FARE SUL PC NUOVO"
    "  1. Copia la cartella windows-status\ dove vuoi, per esempio C:\windows-status"
    "  2. Fai l'immagine di sistema della macchina ancora vergine (Veeam, vedi docs\02)"
    "  3. Apri PowerShell COME AMMINISTRATORE nella cartella e lancia:"
    "       Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass"
    "       .\Avvia.ps1"
    "  4. Scegli la voce 'PC NUOVO: percorso guidato' e segui i passi."
    ""
    "  Gli strumenti sono gia' qui: alla catena si indica questa cartella con"
    "       -Cartella <percorso di strumenti\>"
    "  cosi' il PC nuovo non ha bisogno di rete."
    ""
    "LEGGI PRIMA"
    "  LEGGIMI-PC-NUOVO.md nella radice del progetto, e docs\16."
    "  RemoveWindowsAI e' reversibile solo in parte: l'immagine non e' un di piu'."
)
$righe -join "`r`n" | Set-Content (Join-Path $Dest 'LEGGIMI.txt') -Encoding UTF8
Ok 'LEGGIMI.txt scritto'

# --- riepilogo ----------------------------------------------------------------

Write-Host ''
$mb = [math]::Round((Get-ChildItem $Dest -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
Ok "cartella pronta: $Dest  ($mb MB)"
Info 'Copiala su una chiavetta. Sul PC nuovo leggi prima LEGGIMI.txt.'
