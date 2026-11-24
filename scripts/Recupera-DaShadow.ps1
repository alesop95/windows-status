<#
================================================================================
 Recupera-DaShadow.ps1  -  Copia le trascrizioni degli agenti da una copia shadow
================================================================================

 Quando un crash chiude tutte le sessioni degli agenti insieme, l'hook di fine
 sessione di Claude Code cancella le trascrizioni delle sessioni chiuse senza
 passare dal cestino, e con loro la possibilita' di riprenderle. Se in quel
 momento esiste una copia shadow del volume del profilo, per esempio quella di
 un backup Veeam ancora in corso, le trascrizioni come erano all'ora della copia
 stanno li' dentro. Questo script le copia in una cartella fuori dalla portata
 del wipe, da cui Riapri-Sessione.ps1 le rimette una alla volta.

 Senza -Applica e' di sola lettura: elenca le copie shadow del volume del
 profilo, dice quale userebbe (la piu' recente anteriore a -Prima) e quali
 radici degli agenti copierebbe. Con -Applica monta quella copia in sola
 lettura con un collegamento temporaneo, copia e toglie il collegamento. Non
 scrive mai nelle radici degli agenti, non tocca le copie shadow e non tocca
 il backup. Le radici si scoprono nel profilo (.claude, .claude-accountN,
 .codex, .codex-accountN), non sono cablate.

 USO (da PowerShell amministratore: le copie shadow non si leggono altrimenti)
   .\Recupera-DaShadow.ps1 -Prima '2026-11-24 13:56'
   .\Recupera-DaShadow.ps1 -Prima '2026-11-24 13:56' -Destinazione 'D:\recupero' -Applica

 Uscita 2 se non c'e' una copia utile: allora si ripristinano gli stessi
 percorsi dal punto di backup con il ripristino a livello di file di Veeam.
 Procedura completa in docs/19_RECUPERO_DOPO_CRASH_DEI_TERMINALI.md.
================================================================================
#>

[CmdletBinding()]
param(
    # Ora del crash: si usa la copia shadow piu' recente creata prima di questa.
    [datetime]$Prima = (Get-Date),

    # Dove copiare. Obbligatoria con -Applica e senza valore predefinito: dentro
    # nasce una cartella datata. Non puo' stare in una radice degli agenti ne'
    # nella cartella temporanea, che il wipe ripulisce.
    [string]$Destinazione,

    [switch]$Applica
)

$ErrorActionPreference = 'Stop'

$Profilo  = $env:USERPROFILE
$Unita    = Split-Path -Qualifier $Profilo
$Relativo = $Profilo.Substring($Unita.Length).TrimStart('\')
$CopiaClaude = @{ Cartelle = @('projects', 'file-history', 'plans', 'session-env', 'sessions', 'todos'); File = @('history.jsonl', '.claude.json') }
$CopiaCodex  = @{ Cartelle = @('sessions'); File = @('history.jsonl') }

function Test-Amministratore {
    $Id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $Id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Test-Dentro {
    param([string]$Percorso, [string]$Contenitore)
    $P = [IO.Path]::GetFullPath($Percorso).TrimEnd('\') + '\'
    $C = [IO.Path]::GetFullPath($Contenitore).TrimEnd('\') + '\'
    return $P.StartsWith($C, [StringComparison]::OrdinalIgnoreCase)
}

$Radici = @(Get-ChildItem -LiteralPath $Profilo -Directory -Force | Where-Object { $_.Name -match '^\.(claude|codex)(-account\d+)?$' })
$Admin  = Test-Amministratore

# Parametri di -Applica controllati subito, prima di leggere le copie shadow.
if ($Applica) {
    if (-not $Destinazione) { throw "-Applica richiede -Destinazione" }
    foreach ($R in $Radici) {
        if (Test-Dentro $Destinazione $R.FullName) { throw "-Destinazione sta dentro $($R.FullName), che il wipe ripulisce" }
    }
    if (Test-Dentro $Destinazione $env:TEMP) { throw "-Destinazione sta nella cartella temporanea, che il wipe ripulisce" }
    # Una cartella con il nome di una radice, ovunque nel percorso, verrebbe
    # scambiata per una radice vera dalla corsa successiva (provato il 24/11).
    if (@([IO.Path]::GetFullPath($Destinazione) -split '\\' | Where-Object { $_ -match '^\.(claude|codex)' }).Count -gt 0) {
        throw "-Destinazione contiene una cartella con il nome di una radice degli agenti"
    }
    if ((Split-Path -Qualifier ([IO.Path]::GetFullPath($Destinazione))) -eq $Unita) {
        Write-Host "  [attenzione] la destinazione sta sullo stesso volume del profilo: meglio un altro disco." -ForegroundColor Yellow
    }
    if (-not $Admin) { throw "-Applica va lanciato da un PowerShell amministratore (non dalla scorciatoia sospetta del crash)" }
}

Write-Host ''
Write-Host "  Volume del profilo: $Unita   copia anteriore a: $($Prima.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "  Radici degli agenti: $(($Radici | ForEach-Object Name) -join ', ')"
if (-not $Admin) {
    Write-Host "  [attenzione] terminale non amministratore: l'elenco delle copie shadow puo' risultare vuoto senza esserlo." -ForegroundColor Yellow
}

$Volume = (Get-CimInstance Win32_Volume -Filter "DriveLetter='$Unita'").DeviceID
$Copie = @()
try { $Copie = @(Get-CimInstance Win32_ShadowCopy -ErrorAction Stop | Where-Object { $_.VolumeName -eq $Volume } | Sort-Object InstallDate) }
catch { Write-Host "  [errore] copie shadow non leggibili: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "  Copie shadow di ${Unita}: $($Copie.Count)"
foreach ($C in $Copie) { Write-Host ("    {0}  {1}" -f $C.InstallDate.ToString('yyyy-MM-dd HH:mm:ss'), $C.DeviceObject) }
$Scelta = $Copie | Where-Object { $_.InstallDate -lt $Prima } | Select-Object -Last 1

if (-not $Scelta) {
    Write-Host "  [esito] nessuna copia shadow di $Unita anteriore a -Prima." -ForegroundColor Yellow
    if (-not $Admin) { Write-Host "  Rilanciare da amministratore prima di concluderlo." }
    else { Write-Host "  Via alternativa: ripristino a livello di file dal punto di backup (docs/19)." }
    exit 2
}
Write-Host "  [scelta] copia del $($Scelta.InstallDate.ToString('yyyy-MM-dd HH:mm:ss')): $($Scelta.DeviceObject)"

if (-not $Applica) {
    Write-Host "  Sola lettura. Per copiare: -Destinazione <cartella> -Applica, da amministratore."
    return
}


$Uscita = Join-Path $Destinazione ('recupero-sessioni-' + (Get-Date -Format 'yyyy-MM-dd_HHmm'))
New-Item -ItemType Directory -Force -Path $Uscita | Out-Null
$Link = Join-Path "$env:SystemDrive\" "recupero-shadow-$PID"
if (Test-Path -LiteralPath $Link) { throw "esiste gia' ${Link}: toglierlo a mano dopo averlo guardato" }

& cmd.exe /c mklink /d "$Link" "$($Scelta.DeviceObject)\" | Out-Null
if (-not (Test-Path -LiteralPath $Link)) { throw "collegamento alla copia shadow non creato" }
$Errori = 0
try {
    foreach ($R in $Radici) {
        $Src = Join-Path $Link (Join-Path $Relativo $R.Name)
        if (-not (Test-Path -LiteralPath $Src)) { Write-Host "  [assente nella copia] $($R.Name)"; continue }
        $Regola = if ($R.Name -like '.codex*') { $CopiaCodex } else { $CopiaClaude }
        $Out = Join-Path $Uscita $R.Name
        New-Item -ItemType Directory -Force -Path $Out | Out-Null
        foreach ($Dir in $Regola.Cartelle) {
            $D = Join-Path $Src $Dir
            if (-not (Test-Path -LiteralPath $D)) { continue }
            & robocopy.exe $D (Join-Path $Out $Dir) /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -ge 8) { $Errori++; Write-Host "  [errore] robocopy $($R.Name)\$Dir uscita $LASTEXITCODE" -ForegroundColor Red }
        }
        foreach ($F in $Regola.File) {
            $D = Join-Path $Src $F
            if (Test-Path -LiteralPath $D) { Copy-Item -LiteralPath $D -Destination $Out -Force }
        }
        Write-Host "  [ok]   $($R.Name) -> $Out"
    }
}
finally {
    # Toglie solo il collegamento, mai la copia shadow: rmdir su un collegamento
    # simbolico rimuove il collegamento e non il contenuto.
    $Item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($Item -and ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { & cmd.exe /c rmdir "$Link" | Out-Null }
}

Write-Host ''
Write-Host "  Copiato in $Uscita ($Errori errori). Sessioni recuperate:"
& (Join-Path $PSScriptRoot 'Riapri-Sessione.ps1') -Recupero $Uscita
if ($Errori -gt 0) { exit 1 }
