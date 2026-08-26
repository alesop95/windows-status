<#
.SYNOPSIS
    Rileva variazioni nel layout dei volumi (GUID) dei dischi fissi.

.DESCRIPTION
    I job Veeam Agent in modalita' "Volume level backup" memorizzano i volumi
    sorgente per GUID (\\?\Volume{...}). Se Windows elimina e ricrea una
    partizione - tipicamente la partizione di ripristino WinRE durante un ciclo
    di servicing - il GUID cambia e il job inizia a fallire in fase
    "Preparing for backup" con:

        Error: Cannot find volume \\?\Volume{...}

    Caso documentato su <pdl-riferimento>: il 10/08/2026 alle 09:03:51 la partizione di
    ripristino del disco 0 e' stata eliminata e ricreata durante
    l'installazione di KB5101711/KB5101684. Prova nel canale
    Microsoft-Windows-Partition/Diagnostic (ID 1006): PartitionCount 4 -> 3 -> 4
    nello stesso secondo, con sostituzione del GUID
    {GUID-precedente} -> {GUID-nuovo}. Il job ha poi fallito per 15 giorni,
    accumulando 193 retry, senza che nessuno se ne accorgesse.

    Questo script rileva l'evento QUANDO ACCADE, prima che il backup fallisca.

.PARAMETER Reset
    Riscrive la baseline sullo stato attuale. Usare DOPO aver riallineato il job
    Veeam (step Volumes: deseleziona e riseleziona i volumi, verifica il
    Summary, esegui un run manuale).

.NOTES
    - Considera solo i dischi NON rimovibili: i BusType USB/SD/MMC sono esclusi,
      quindi collegare o scollegare un SSD esterno non genera falsi positivi.
    - Le partizioni prive di filesystem (MSR/Reserved) non hanno volume e sono
      naturalmente escluse.
    - Al primo avvio crea la baseline ed esce con 0.
    - L'alert PERSISTE fino a un -Reset esplicito: e' voluto. Un auto-riallineo
      silenzioso equivarrebbe a non avere il controllo.
    - Contesto di esecuzione: LOCAL SYSTEM.

    Exit code:  0 = OK / baseline creata   1 = layout modificato   2 = errore
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Reset,

    # Cartella della baseline. Default neutro: al deploy si passa il percorso
    # dell'organizzazione (il valore reale non vive in questo repository, pubblico).
    [string]$BaselineDir = 'C:\ProgramData\WindowsStatus'
)

# ============================ PARAMETRI ============================
$BaselineFile = Join-Path $BaselineDir 'VolumeBaseline.json'
$ExcludedBus  = @('USB', 'SD', 'MMC', 'File Backed Virtual', 'Virtual')
# ===================================================================

function Get-FixedVolumeSet {
    <# Restituisce i UniqueId dei volumi su dischi NON rimovibili, ordinati. #>
    $result = New-Object System.Collections.Generic.List[object]

    $disks = Get-Disk -ErrorAction Stop |
             Where-Object { $ExcludedBus -notcontains $_.BusType }

    foreach ($d in $disks) {
        $parts = Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue
        foreach ($p in $parts) {
            $v = $p | Get-Volume -ErrorAction SilentlyContinue
            if ($v -and $v.UniqueId) {
                $result.Add([pscustomobject]@{
                    UniqueId = $v.UniqueId
                    Disk     = $d.Number
                    Model    = $d.FriendlyName
                    Part     = $p.PartitionNumber
                    Letter   = $v.DriveLetter
                    Label    = $v.FileSystemLabel
                    Type     = $p.Type
                    SizeGB   = [math]::Round($p.Size / 1GB, 2)
                })
            }
        }
    }
    return ($result | Sort-Object UniqueId)
}

function Format-VolLine {
    param($v)
    $lt = if ($v.Letter) { "$($v.Letter):" } else { '   ' }
    $lb = if ($v.Label)  { $v.Label }       else { '(senza etichetta)' }
    "    disco $($v.Disk) part $($v.Part)  $lt  $($v.Type.PadRight(8))  $($v.SizeGB.ToString().PadLeft(9)) GB  $lb"
}

# ---------- Raccolta stato attuale ----------
try {
    $current = @(Get-FixedVolumeSet)
} catch {
    Write-Output "ERRORE: impossibile enumerare dischi e volumi. $($_.Exception.Message)"
    exit 2
}

if ($current.Count -eq 0) {
    Write-Output "ERRORE: nessun volume su disco fisso rilevato. Verificare il modulo Storage."
    exit 2
}

$currentIds = @($current | Select-Object -ExpandProperty UniqueId)

$snapshot = [ordered]@{
    Host      = $env:COMPUTERNAME
    Created   = (Get-Date).ToString('o')
    Count     = $currentIds.Count
    UniqueIds = $currentIds
    Detail    = @($current | ForEach-Object {
                    "disco $($_.Disk)/$($_.Model) part $($_.Part) $($_.Letter) $($_.Label) $($_.Type) $($_.SizeGB)GB $($_.UniqueId)"
                 })
}

# ---------- Primo avvio o reset ----------
if ($Reset -or -not (Test-Path $BaselineFile)) {
    try {
        if (-not (Test-Path $BaselineDir)) {
            New-Item -Path $BaselineDir -ItemType Directory -Force | Out-Null
        }
        $snapshot | ConvertTo-Json -Depth 4 | Set-Content -Path $BaselineFile -Encoding UTF8
    } catch {
        Write-Output "ERRORE: impossibile scrivere la baseline in $BaselineFile. $($_.Exception.Message)"
        exit 2
    }

    $mode = if ($Reset) { 'BASELINE RIALLINEATA' } else { 'BASELINE CREATA (primo avvio)' }
    Write-Output "$mode - $($currentIds.Count) volumi su disco fisso registrati."
    $current | ForEach-Object { Write-Output (Format-VolLine $_) }
    Write-Output ""
    Write-Output "File: $BaselineFile"
    exit 0
}

# ---------- Confronto ----------
try {
    $baseline    = Get-Content $BaselineFile -Raw | ConvertFrom-Json
    $baselineIds = @($baseline.UniqueIds)
} catch {
    Write-Output "ERRORE: baseline illeggibile o corrotta ($BaselineFile). $($_.Exception.Message)"
    Write-Output "Rieseguire lo script con -Reset per rigenerarla."
    exit 2
}

$diff = Compare-Object -ReferenceObject $baselineIds -DifferenceObject $currentIds

if (-not $diff) {
    Write-Output "OK: layout volumi invariato ($($currentIds.Count) volumi su disco fisso)."
    Write-Output "Baseline del $([datetime]::Parse($baseline.Created).ToString('dd/MM/yyyy HH:mm'))."
    exit 0
}

# ---------- Layout modificato ----------
Write-Output "ALERT: LAYOUT VOLUMI MODIFICATO rispetto alla baseline."
Write-Output "Baseline del $([datetime]::Parse($baseline.Created).ToString('dd/MM/yyyy HH:mm')) - $($baselineIds.Count) volumi"
Write-Output "Stato attuale                        - $($currentIds.Count) volumi"
Write-Output ""

$gone = @($diff | Where-Object { $_.SideIndicator -eq '<=' })
$new  = @($diff | Where-Object { $_.SideIndicator -eq '=>' })

if ($gone.Count -gt 0) {
    Write-Output "SCOMPARSI ($($gone.Count)) - un job Veeam che li referenzia fallira' in 'Preparing for backup':"
    foreach ($g in $gone) { Write-Output "    $($g.InputObject)" }
    Write-Output ""
}

if ($new.Count -gt 0) {
    Write-Output "NUOVI ($($new.Count)):"
    foreach ($n in $new) {
        $info = $current | Where-Object { $_.UniqueId -eq $n.InputObject } | Select-Object -First 1
        if ($info) { Write-Output "    $($n.InputObject)"; Write-Output (Format-VolLine $info) }
        else       { Write-Output "    $($n.InputObject)" }
    }
    Write-Output ""
}

Write-Output "AZIONE RICHIESTA:"
Write-Output "  1. Veeam Agent -> Edit Backup Job -> step Volumes"
Write-Output "  2. Spuntare 'Show system hidden volumes'"
Write-Output "  3. Deselezionare e riselezionare i volumi dati (es. C:, D:) per forzare"
Write-Output "     la ri-enumerazione dei volumi system-required"
Write-Output "  4. Nello step Summary verificare che i GUID SCOMPARSI non compaiano piu'"
Write-Output "     e che i NUOVI siano inclusi"
Write-Output "  5. Finish + run manuale (attendersi un ciclo con rilettura completa: il"
Write-Output "     changed block tracking viene azzerato sul disco modificato)"
Write-Output "  6. Rieseguire questo script con -Reset per riallineare la baseline"

exit 1
