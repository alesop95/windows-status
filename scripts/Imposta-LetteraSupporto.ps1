# =============================================================================
#  Imposta-LetteraSupporto.ps1  -  lettera fissa per un disco esterno
#  windows-status. Vedi docs\16 (passo SUPPORTI) e docs\18.
# =============================================================================
#  A COSA SERVE. Gli script di backup riconoscono il disco esterno dalla
#  lettera, prima ancora che dal modello e dal numero di serie. Su un PC nuovo
#  Windows assegna al primo collegamento la prima lettera libera, e il backup
#  non trova il suo disco. Questo script assegna la lettera attesa una volta:
#  Windows la ricorda per quel volume in HKLM\SYSTEM\MountedDevices e la
#  riassegna da sola a ogni collegamento successivo, finche' resta libera.
#
#  Il disco si riconosce per modello (confronto -like sul nome) e, se indicato,
#  per numero di serie. Il numero di serie NON va scritto in un file tracciato
#  (paletto 7): sta in profilo.json, ignorato da git, o si passa a mano.
#
#  Senza -Applica non tocca niente: dice cosa farebbe.
#
#  USO
#    .\Imposta-LetteraSupporto.ps1 -Modello '*<modello>*' -Lettera J
#    .\Imposta-LetteraSupporto.ps1 -Modello '*<modello>*' -Seriale '<seriale>' -Lettera J -Applica
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Modello,
    [string] $Seriale = '',
    [Parameter(Mandatory = $true)] [ValidatePattern('^[D-Zd-z]$')] [string] $Lettera,
    [string] $Nome = 'disco esterno',
    [switch] $Applica
)

$ErrorActionPreference = 'Stop'
$Lettera = $Lettera.ToUpper()

function Ok     { param([string]$T) Write-Host "  [ok]      $T" -ForegroundColor Green }
function Info   { param([string]$T) Write-Host "  [info]    $T" }
function Avviso { param([string]$T) Write-Host "  [attenzione] $T" -ForegroundColor Yellow }
function Stop_  { param([string]$T) Write-Host "  [fermo]   $T" -ForegroundColor Red }

# Esito per chi chiama: 'fatto' | 'gia' | 'assente' | 'conflitto' | 'anteprima' | 'saltato'
function Esito { param([string]$E) [pscustomobject]@{ Esito = $E } }

$dischi = @(Get-Disk | Where-Object {
    ($_.FriendlyName -like $Modello) -and
    ((-not $Seriale) -or ((("$($_.SerialNumber)").Trim()) -eq $Seriale.Trim()))
})

if ($dischi.Count -eq 0) {
    Avviso "$Nome non collegato (modello '$Modello'$(if ($Seriale) { ', seriale indicato' })). Collegalo e rilancia."
    return (Esito 'assente')
}
if ($dischi.Count -gt 1) {
    Stop_ "piu' dischi corrispondono a '$Modello': indica il numero di serie per scegliere quello giusto."
    $dischi | ForEach-Object { Info "  disco $($_.Number): $($_.FriendlyName)" }
    return (Esito 'conflitto')
}
$disco = $dischi[0]

# Partizione dati: la piu' grande fra quelle non riservate.
$part = Get-Partition -DiskNumber $disco.Number -ErrorAction SilentlyContinue |
        Where-Object { $_.Type -ne 'Reserved' } |
        Sort-Object Size -Descending | Select-Object -First 1
if (-not $part) { Stop_ "nessuna partizione utilizzabile su '$($disco.FriendlyName)'."; return (Esito 'conflitto') }

if ($part.DriveLetter -eq $Lettera) {
    Ok "$Nome ($($disco.FriendlyName)) ha gia' la lettera ${Lettera}:."
    return (Esito 'gia')
}

$occupata = Get-Partition -DriveLetter $Lettera -ErrorAction SilentlyContinue
if ($occupata -and $occupata.DiskNumber -ne $disco.Number) {
    Stop_ "la lettera ${Lettera}: e' gia' del disco $($occupata.DiskNumber). Liberala prima: lo script non toglie la lettera a un altro disco."
    return (Esito 'conflitto')
}

$attuale = if ($part.DriveLetter) { "$($part.DriveLetter):" } else { 'nessuna lettera' }
Info "$Nome trovato: disco $($disco.Number) '$($disco.FriendlyName)', partizione $($part.PartitionNumber), ora $attuale"
if (-not $Applica) {
    Info "assegnerei ${Lettera}:. Nessuna modifica fatta: per farla, -Applica."
    return (Esito 'anteprima')
}

if ($part.DriveLetter) {
    Set-Partition -DiskNumber $disco.Number -PartitionNumber $part.PartitionNumber -NewDriveLetter $Lettera
} else {
    Add-PartitionAccessPath -DiskNumber $disco.Number -PartitionNumber $part.PartitionNumber -AccessPath "${Lettera}:\"
}
Ok "assegnata ${Lettera}: a $Nome. Windows la riassegna da sola ai prossimi collegamenti."
Info "si annulla da Gestione disco (diskmgmt.msc): Cambia lettera e percorso di unita'."
return (Esito 'fatto')
