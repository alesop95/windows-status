<#
.SYNOPSIS
    Rileva e bonifica la cache Office "DocToIdMapping" sovradimensionata
    (causa accertata di blocchi di PowerPoint, ottobre 2026: vedi
    docs/12_POWERPOINT_LENTO_DOCTOIDMAPPING.md del repository windows-status).

.DESCRIPTION
    Per ogni profilo utente del PC controlla la chiave:
        HKCU\Software\Microsoft\Office\16.0\Common\Identity\DocToIdMapping\<identita>
    e conta i valori di ciascuna sottochiave. Se una sottochiave supera la soglia
    (default 10.000 valori), lo script:
        1. esporta un backup .reg della sola chiave DocToIdMapping dell'utente;
        2. elimina la sottochiave sovradimensionata (Office la ricrea da solo);
        3. verifica l'esito e scrive un log.

    Gestisce sia i profili con utente collegato (hive gia' caricato in HKEY_USERS)
    sia i profili non collegati (carica temporaneamente NTUSER.DAT).

    Se l'utente collegato ha app Office aperte, per default NON le chiude: segnala
    lo stato "IN ATTESA" e lascia la bonifica a un'esecuzione successiva.

    Pensato per NinjaOne: eseguire come SYSTEM.
    Compatibile con Windows PowerShell 5.1.

.PARAMETER Threshold
    Numero di valori oltre il quale una sottochiave e' considerata anomala. Default 10000.

.PARAMETER ReportOnly
    Solo rilevamento: nessuna modifica, nessun backup.

.PARAMETER ForceCloseOffice
    Se l'utente collegato ha app Office aperte, le chiude forzatamente prima della bonifica.
    ATTENZIONE: il lavoro non salvato va perso.

.PARAMETER SkipOfflineProfiles
    Non analizza i profili degli utenti non collegati.

.PARAMETER BackupRetentionDays
    I backup piu' vecchi di N giorni vengono eliminati. Default 60. 0 = nessuna pulizia.

.PARAMETER BaseDir
    Cartella di lavoro per backup e log, con accesso limitato a SYSTEM e Administrators.
    Default C:\ProgramData\WindowsStatus\DocToIdMapping.

.PARAMETER CustomField
    (Opzionale) Nome di un campo personalizzato NinjaOne in cui scrivere l'esito sintetico.

.NOTES
    Variabili di script NinjaOne supportate (sovrascrivono i parametri):
        threshold, reportOnly, forceCloseOffice, skipOfflineProfiles,
        backupRetentionDays, customField, baseDir

    Codici di uscita:
        0 = nessuna anomalia rilevata
        1 = anomalia rilevata e bonificata correttamente
        2 = anomalia rilevata ma NON bonificata (ReportOnly oppure app Office aperte)
        3 = errore durante l'esecuzione
#>

[CmdletBinding()]
param(
    [int]$Threshold = 10000,
    [switch]$ReportOnly,
    [switch]$ForceCloseOffice,
    [switch]$SkipOfflineProfiles,
    [int]$BackupRetentionDays = 60,
    [string]$CustomField = '',
    [string]$BaseDir = (Join-Path $env:ProgramData 'WindowsStatus\DocToIdMapping')
)

# ---------------------------------------------------------------------------
# Override da variabili di script NinjaOne (arrivano come variabili d'ambiente)
# ---------------------------------------------------------------------------
function Test-EnvTrue([string]$Value) { return ($Value -and $Value.Trim().ToLower() -in @('true', '1', 'yes', 'si')) }

if ($env:threshold -and ($env:threshold -as [int]))                     { $Threshold = [int]$env:threshold }
if (Test-EnvTrue $env:reportOnly)                                        { $ReportOnly = $true }
if (Test-EnvTrue $env:forceCloseOffice)                                  { $ForceCloseOffice = $true }
if (Test-EnvTrue $env:skipOfflineProfiles)                               { $SkipOfflineProfiles = $true }
if ($env:backupRetentionDays -and ($env:backupRetentionDays -as [int]) -ne $null) { $BackupRetentionDays = [int]$env:backupRetentionDays }
if ($env:customField)                                                    { $CustomField = $env:customField }
if ($env:baseDir)                                                        { $BaseDir = $env:baseDir }

# ---------------------------------------------------------------------------
# Costanti
# ---------------------------------------------------------------------------
$BackupDir    = Join-Path $BaseDir 'Backup'
$LogDir       = Join-Path $BaseDir 'Logs'
$RunStamp     = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile      = Join-Path $LogDir "DocToIdMapping_$RunStamp.log"
$RelKeyPath   = 'Software\Microsoft\Office\16.0\Common\Identity\DocToIdMapping'
$OfficeExe    = @('WINWORD.EXE','EXCEL.EXE','POWERPNT.EXE','OUTLOOK.EXE','ONENOTE.EXE',
                  'MSACCESS.EXE','MSPUB.EXE','VISIO.EXE','WINPROJ.EXE','LYNC.EXE')
$SidPattern   = '^S-1-(5-21|12-1)-[\d-]+$'   # utenti locali/dominio (5-21) ed Entra ID (12-1)

$script:Results  = New-Object System.Collections.Generic.List[object]
$script:HadError = $false

# ---------------------------------------------------------------------------
# Funzioni di supporto
# ---------------------------------------------------------------------------
function Initialize-Folders {
    foreach ($d in @($BaseDir, $BackupDir, $LogDir)) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    # I backup contengono URL di documenti: accesso solo a SYSTEM e Administrators
    & icacls.exe $BaseDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' /T /C /Q | Out-Null
}

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Output $line
    try { Add-Content -Path $LogFile -Value $line -ErrorAction Stop } catch { }
}

function Get-UserLabel {
    param([string]$Sid, [string]$ProfilePath)
    try {
        return (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate([System.Security.Principal.NTAccount]).Value
    } catch {
        if ($ProfilePath) { return (Split-Path $ProfilePath -Leaf) } else { return $Sid }
    }
}

function Get-OfficeProcessesForSid {
    param([string]$Sid)
    $filter = ($OfficeExe | ForEach-Object { "Name='$_'" }) -join ' OR '
    $procs  = Get-CimInstance Win32_Process -Filter $filter -ErrorAction SilentlyContinue
    $owned  = @()
    foreach ($p in $procs) {
        try {
            $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwnerSid -ErrorAction Stop
            if ($owner.Sid -eq $Sid) { $owned += $p }
        } catch { }
    }
    return $owned
}

function Remove-OldBackups {
    if ($BackupRetentionDays -le 0) { return }
    $limit = (Get-Date).AddDays(-$BackupRetentionDays)
    Get-ChildItem $BackupDir -Filter '*.reg' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $limit } |
        ForEach-Object {
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            Write-Log "Backup scaduto eliminato: $($_.Name)"
        }
}

function Add-Result {
    param($User, $Sid, $Identity, $Values, $Status)
    $script:Results.Add([pscustomobject]@{
        Utente   = $User
        SID      = $Sid
        Identita = $Identity
        Valori   = $Values
        Esito    = $Status
    })
}

# ---------------------------------------------------------------------------
# Analisi e bonifica di un singolo hive
#   $HiveRoot : es. 'HKEY_USERS\S-1-5-21-...' oppure 'HKEY_USERS\WS_TMP_1'
#   $IsLive   : $true se l'utente e' collegato (hive caricato da Windows)
# ---------------------------------------------------------------------------
function Invoke-HiveCheck {
    param([string]$Sid, [string]$HiveRoot, [string]$UserLabel, [bool]$IsLive)

    $mapPsPath  = "Registry::$HiveRoot\$RelKeyPath"
    $mapRegPath = "$HiveRoot\$RelKeyPath"

    if (-not (Test-Path $mapPsPath)) {
        Write-Log "$UserLabel : chiave DocToIdMapping assente (OK)"
        Add-Result $UserLabel $Sid '-' 0 'OK'
        return
    }

    # Lettura del solo conteggio (ValueCount): non enumera i valori, e' veloce anche con 200.000 voci
    $subKeys = @(Get-ChildItem $mapPsPath -ErrorAction SilentlyContinue)
    $info = foreach ($k in $subKeys) {
        [pscustomobject]@{ Name = $k.PSChildName; Count = $k.ValueCount }
    }
    $subKeys = $null

    if (-not $info) {
        Write-Log "$UserLabel : DocToIdMapping vuota (OK)"
        Add-Result $UserLabel $Sid '-' 0 'OK'
        return
    }

    $flagged = @($info | Where-Object { $_.Count -ge $Threshold })
    foreach ($i in ($info | Where-Object { $_.Count -lt $Threshold })) {
        Write-Log "$UserLabel : $($i.Name) = $($i.Count) valori (sotto soglia $Threshold, OK)"
        Add-Result $UserLabel $Sid $i.Name $i.Count 'OK'
    }
    if ($flagged.Count -eq 0) { return }

    foreach ($f in $flagged) {
        Write-Log "$UserLabel : $($f.Name) = $($f.Count) valori -> OLTRE SOGLIA ($Threshold)" 'WARN'
    }

    # --- Solo report -------------------------------------------------------
    if ($ReportOnly) {
        foreach ($f in $flagged) { Add-Result $UserLabel $Sid $f.Name $f.Count 'RILEVATO (solo report)' }
        return
    }

    # --- App Office aperte (solo utenti collegati) ---------------------------
    if ($IsLive) {
        $procs = @(Get-OfficeProcessesForSid -Sid $Sid)
        if ($procs.Count -gt 0) {
            $names = ($procs | Select-Object -ExpandProperty Name -Unique) -join ', '
            if ($ForceCloseOffice) {
                Write-Log "$UserLabel : chiusura forzata app Office aperte ($names)" 'WARN'
                foreach ($p in $procs) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
                Start-Sleep -Seconds 3
                if (@(Get-OfficeProcessesForSid -Sid $Sid).Count -gt 0) {
                    Write-Log "$UserLabel : impossibile chiudere le app Office, bonifica rimandata" 'ERROR'
                    foreach ($f in $flagged) { Add-Result $UserLabel $Sid $f.Name $f.Count 'IN ATTESA (Office non chiudibile)' }
                    return
                }
            } else {
                Write-Log "$UserLabel : app Office aperte ($names), bonifica rimandata. Usare -ForceCloseOffice o rieseguire a Office chiuso." 'WARN'
                foreach ($f in $flagged) { Add-Result $UserLabel $Sid $f.Name $f.Count 'IN ATTESA (Office aperto)' }
                return
            }
        }
    }

    # --- Backup della chiave DocToIdMapping ----------------------------------
    $safeUser   = ($UserLabel -replace '[\\/:*?"<>| ]', '_')
    $backupFile = Join-Path $BackupDir "DocToIdMapping_${safeUser}_$RunStamp.reg"
    & reg.exe export $mapRegPath $backupFile /y 2>&1 | Out-Null
    if (-not (Test-Path $backupFile) -or (Get-Item $backupFile).Length -eq 0) {
        Write-Log "$UserLabel : backup NON riuscito, nessuna modifica eseguita" 'ERROR'
        $script:HadError = $true
        foreach ($f in $flagged) { Add-Result $UserLabel $Sid $f.Name $f.Count 'ERRORE (backup fallito)' }
        return
    }
    Write-Log ("{0} : backup creato {1} ({2} KB)" -f $UserLabel, $backupFile, [math]::Round((Get-Item $backupFile).Length / 1KB))

    # --- Eliminazione delle sottochiavi oltre soglia ------------------------
    foreach ($f in $flagged) {
        $target = "$mapRegPath\$($f.Name)"
        & reg.exe delete $target /f 2>&1 | Out-Null
        if (Test-Path "Registry::$target") {
            Write-Log "$UserLabel : eliminazione di $($f.Name) NON riuscita" 'ERROR'
            $script:HadError = $true
            Add-Result $UserLabel $Sid $f.Name $f.Count 'ERRORE (eliminazione fallita)'
        } else {
            Write-Log "$UserLabel : $($f.Name) eliminata ($($f.Count) valori rimossi)" 'OK'
            Add-Result $UserLabel $Sid $f.Name $f.Count 'BONIFICATO'
        }
    }
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
try {
    Initialize-Folders
    Write-Log "=== Avvio controllo DocToIdMapping su $env:COMPUTERNAME ==="
    Write-Log ("Parametri: Soglia={0} ReportOnly={1} ForceCloseOffice={2} SkipOfflineProfiles={3} Retention={4}gg" -f `
        $Threshold, [bool]$ReportOnly, [bool]$ForceCloseOffice, [bool]$SkipOfflineProfiles, $BackupRetentionDays)

    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($me -ne 'S-1-5-18') {
        Write-Log "Lo script non gira come SYSTEM ($me): i profili diversi dal proprio potrebbero non essere accessibili." 'WARN'
    }

    $profileList = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -ErrorAction Stop |
        Where-Object { $_.PSChildName -match $SidPattern } |
        ForEach-Object {
            [pscustomobject]@{
                Sid         = $_.PSChildName
                ProfilePath = (Get-ItemProperty $_.PSPath -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
            }
        }

    $tmpIndex = 0
    foreach ($p in $profileList) {
        $label = Get-UserLabel -Sid $p.Sid -ProfilePath $p.ProfilePath

        if (Test-Path "Registry::HKEY_USERS\$($p.Sid)") {
            # Utente collegato: hive gia' caricato
            Invoke-HiveCheck -Sid $p.Sid -HiveRoot "HKEY_USERS\$($p.Sid)" -UserLabel $label -IsLive $true
            continue
        }

        if ($SkipOfflineProfiles) { continue }

        # Utente non collegato: caricamento temporaneo di NTUSER.DAT
        $ntuser = if ($p.ProfilePath) { Join-Path $p.ProfilePath 'NTUSER.DAT' } else { $null }
        if (-not $ntuser -or -not (Test-Path $ntuser)) { continue }

        $tmpIndex++
        $tmpName = "WS_TMP_$tmpIndex"
        & reg.exe load "HKU\$tmpName" $ntuser 2>&1 | Out-Null
        if (-not (Test-Path "Registry::HKEY_USERS\$tmpName")) {
            Write-Log "$label : impossibile caricare NTUSER.DAT (profilo in uso o bloccato), saltato" 'WARN'
            Add-Result $label $p.Sid '-' '-' 'SALTATO (hive non caricabile)'
            continue
        }
        try {
            Invoke-HiveCheck -Sid $p.Sid -HiveRoot "HKEY_USERS\$tmpName" -UserLabel $label -IsLive $false
        } finally {
            [gc]::Collect(); [gc]::WaitForPendingFinalizers()
            Start-Sleep -Milliseconds 500
            & reg.exe unload "HKU\$tmpName" 2>&1 | Out-Null
            if (Test-Path "Registry::HKEY_USERS\$tmpName") {
                Write-Log "$label : ATTENZIONE, hive temporaneo $tmpName non scaricato (verra' rilasciato al riavvio)" 'WARN'
            }
        }
    }

    Remove-OldBackups
}
catch {
    Write-Log "Errore non gestito: $($_.Exception.Message)" 'ERROR'
    $script:HadError = $true
}

# ---------------------------------------------------------------------------
# Riepilogo ed esito
# ---------------------------------------------------------------------------
Write-Output ''
Write-Output '=== RIEPILOGO ==='
if ($script:Results.Count -gt 0) {
    $script:Results | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
} else {
    Write-Output 'Nessun profilo utente analizzato.'
}

$bonificati = @($script:Results | Where-Object Esito -eq 'BONIFICATO').Count
$pendenti   = @($script:Results | Where-Object { $_.Esito -like 'RILEVATO*' -or $_.Esito -like 'IN ATTESA*' }).Count

if ($script:HadError)   { $exitCode = 3; $summary = 'ERRORE - vedere log' }
elseif ($pendenti -gt 0){ $exitCode = 2; $summary = "RILEVATO NON BONIFICATO ($pendenti)" }
elseif ($bonificati -gt 0){ $exitCode = 1; $summary = "BONIFICATO ($bonificati)" }
else                    { $exitCode = 0; $summary = 'OK' }

$maxValues = ($script:Results | Where-Object { $_.Valori -is [int] } | Measure-Object Valori -Maximum).Maximum
if ($null -eq $maxValues) { $maxValues = 0 }
$summary = "$summary | max valori: $maxValues | $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

Write-Log "Esito: $summary (exit code $exitCode)"
Write-Log "Log: $LogFile"

if ($CustomField -and (Get-Command 'Ninja-Property-Set' -ErrorAction SilentlyContinue)) {
    try { Ninja-Property-Set $CustomField $summary; Write-Log "Campo NinjaOne '$CustomField' aggiornato" }
    catch { Write-Log "Impossibile aggiornare il campo NinjaOne '$CustomField': $($_.Exception.Message)" 'WARN' }
}

exit $exitCode
