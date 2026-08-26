<#
.SYNOPSIS
    Monitor freschezza backup Veeam Agent for Microsoft Windows.

.DESCRIPTION
    Misura l'ETA' DELL'ULTIMO RESTORE POINT CREATO (event ID 10010) e allerta
    oltre soglia. La metrica primaria e' l'ASSENZA DI UN SUCCESSO RECENTE, non
    la presenza di un errore: questo copre anche i guasti silenziosi (servizio
    fermo, job disabilitato, macchina spenta nella finestra di backup) che un
    monitor event-driven non intercetterebbe.

    Controlli secondari (contesto, contribuiscono all'exit code):
      - esito dell'ultima sessione conclusa      (ID 190, livello = esito)
      - retry falliti nelle ultime 24 h          (ID 191)
      - stato del servizio VeeamEndpointBackupSvc
      - freschezza del Job_*.log (cross-check indipendente dall'event log)

    Se Veeam Agent NON e' installato lo script esce con 0 e messaggio
    informativo: e' sicuro distribuirlo su tutta la flotta.

.NOTES
    Event ID verificati su Veeam Agent for Microsoft Windows (build 2026-08):
      110   - job avviato
      190   - job TERMINATO. L'esito e' nel LIVELLO dell'evento, non nell'ID.
      191   - terminato con errore, sara' ritentato
      10010 - restore point creato
      10050 - restore point rimosso per retention
      23050 - job modificato
      23120 - sorgenti del job aggiornate

    ATTENZIONE: 190 non e' un ID di successo. Filtrare su 190 senza guardare il
    livello classifica come "riuscito" anche un fallimento. Per questo la
    metrica primaria e' 10010.

    Il livello e' letto come VALORE NUMERICO ($_.Level) e non come
    LevelDisplayName, perche' quest'ultimo e' localizzato (it-IT: "Errore",
    "Avviso", "Informazioni") e romperebbe lo script su macchine con locale
    diverso.

    Contesto di esecuzione: LOCAL SYSTEM. Nessuna dipendenza da SMB o da
    credenziali di rete - deliberato, vedi README.

    Exit code:  0 = OK   1 = Warning   2 = Critical
#>

#Requires -Version 5.1

# ============================ PARAMETRI ============================
$VeeamLogName     = 'Veeam Agent'               # verificato
$VeeamServiceName = 'VeeamEndpointBackupSvc'    # verificato
$JobLogPath       = 'C:\ProgramData\Veeam\Endpoint'

$EvtRestorePoint  = 10010    # restore point creato  -> METRICA PRIMARIA
$EvtJobFinished   = 190      # job terminato (livello = esito)
$EvtJobRetry      = 191      # errore, sara' ritentato

$WarnHours        = 30       # job giornaliero + margine per PC spento / run lungo
$CritHours        = 72
$RetryWarnCount   = 5        # retry in 24 h oltre cui segnalare loop

$WriteNinjaFields = $false   # $true solo dopo aver creato i custom field
# ===================================================================

# Livelli evento (numerici, indipendenti dal locale)
$LVL_CRITICAL = 1
$LVL_ERROR    = 2
$LVL_WARNING  = 3
$LVL_INFO     = 4

function Get-LevelName {
    param([int]$Level)
    switch ($Level) {
        1 { 'Critical' } 2 { 'Error' } 3 { 'Warning' } 4 { 'Information' }
        default { "Level$Level" }
    }
}

$exitCode = 0
$out      = New-Object System.Collections.Generic.List[string]
$ageHours = -1

function Set-Exit {
    param([int]$Code)
    if ($Code -gt $script:exitCode) { $script:exitCode = $Code }
}

# ---------- 0. Veeam Agent installato? ----------
$svc     = Get-Service -Name $VeeamServiceName -ErrorAction SilentlyContinue
$logHere = $null
try { $logHere = Get-WinEvent -ListLog $VeeamLogName -ErrorAction Stop } catch { }

if (-not $svc -and -not $logHere) {
    Write-Output "N/A: Veeam Agent for Microsoft Windows non risulta installato su questo endpoint."
    Write-Output "Nessun controllo eseguito. Escludere la macchina dalla policy o installare l'agent."
    exit 0
}

$out.Add("=== Veeam Agent - freschezza backup ===")
$out.Add("Host: $env:COMPUTERNAME   Controllo: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")

# ---------- 1. METRICA PRIMARIA: eta' ultimo restore point ----------
$lastRp = $null
try {
    $lastRp = Get-WinEvent -FilterHashtable @{ LogName = $VeeamLogName; Id = $EvtRestorePoint } `
                           -MaxEvents 1 -ErrorAction Stop
} catch { }

if (-not $lastRp) {
    $out.Add("CRITICAL: nessun restore point (ID $EvtRestorePoint) presente nel log '$VeeamLogName'.")
    $out.Add("  Possibili cause: nessun backup mai riuscito, oppure log ruotato (verificare maxSize).")
    Set-Exit 2
} else {
    $ageHours = [math]::Round(((Get-Date) - $lastRp.TimeCreated).TotalHours, 1)
    $out.Add("Ultimo restore point: $($lastRp.TimeCreated.ToString('dd/MM/yyyy HH:mm')) - $ageHours h fa")
    if     ($ageHours -gt $CritHours) { $out.Add("CRITICAL: oltre la soglia di $CritHours h."); Set-Exit 2 }
    elseif ($ageHours -gt $WarnHours) { $out.Add("WARNING: oltre la soglia di $WarnHours h.");  Set-Exit 1 }
    else                              { $out.Add("OK: entro la soglia di $WarnHours h.") }
}

# ---------- 2. Esito ultima sessione conclusa ----------
try {
    $fin = Get-WinEvent -FilterHashtable @{ LogName = $VeeamLogName; Id = $EvtJobFinished } `
                        -MaxEvents 1 -ErrorAction Stop
    $lvlName = Get-LevelName $fin.Level
    $msg     = ($fin.Message -replace "`r`n", ' ' -replace '\s+', ' ').Trim()
    $msgCut  = $msg.Substring(0, [Math]::Min(240, $msg.Length))

    $out.Add("Ultima sessione conclusa: $($fin.TimeCreated.ToString('dd/MM HH:mm')) [$lvlName]")
    $out.Add("  $msgCut")

    if ($fin.Level -in @($LVL_ERROR, $LVL_CRITICAL)) {
        $out.Add("WARNING: l'ultima sessione e' terminata in errore.")
        Set-Exit 1
    }
} catch {
    $out.Add("Nessun evento ID $EvtJobFinished nel log.")
}

# ---------- 3. Loop di retry ----------
try {
    $retries = @(Get-WinEvent -FilterHashtable @{
                     LogName   = $VeeamLogName
                     Id        = $EvtJobRetry
                     StartTime = (Get-Date).AddHours(-24)
                 } -ErrorAction Stop)
    $out.Add("Retry falliti nelle ultime 24 h: $($retries.Count)")
    if ($retries.Count -ge $RetryWarnCount) {
        $out.Add("WARNING: il job e' in loop di retry (soglia $RetryWarnCount). Errore persistente non risolto dai tentativi automatici.")
        Set-Exit 1
    }
} catch {
    $out.Add("Retry falliti nelle ultime 24 h: 0")
}

# ---------- 4. Servizio ----------
if (-not $svc) {
    $out.Add("CRITICAL: servizio '$VeeamServiceName' non trovato (log presente ma agent rimosso?).")
    Set-Exit 2
} else {
    $out.Add("Servizio $($svc.Name): $($svc.Status) / avvio $($svc.StartType)")
    if ($svc.Status -ne 'Running') {
        $out.Add("CRITICAL: servizio non in esecuzione. Nessun backup possibile.")
        Set-Exit 2
    }
    if ($svc.StartType -ne 'Automatic') {
        $out.Add("WARNING: tipo di avvio non Automatic.")
        Set-Exit 1
    }
}

# ---------- 5. Cross-check indipendente: attivita' del job log ----------
# Due disposizioni possibili, verificate su questa macchina il 26/08/2026. Veeam
# Agent 13 tiene i log in una SOTTOCARTELLA per job, 'Job_<nome>\Job.Job_<nome>.
# Backup*.log'; build precedenti li tengono piatti in 'Job_*.log'. Il pattern
# piatto da solo non trova nulla su Agent 13, perche' 'Job_<nome>' e' una
# directory e non un file: produceva un WARNING permanente con backup sano,
# cioe' il falso positivo che questo monitor esiste per non generare.
$jl = @(
    Get-ChildItem -Path $JobLogPath -Directory -Filter 'Job_*' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ChildItem -Path $_.FullName -Filter '*.log' -File -ErrorAction SilentlyContinue }
    Get-ChildItem -Path (Join-Path $JobLogPath 'Job_*.log') -File -ErrorAction SilentlyContinue
) | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($jl) {
    $la = [math]::Round(((Get-Date) - $jl.LastWriteTime).TotalHours, 1)
    $out.Add("Job log piu' recente: $($jl.Name) - $la h fa")
    if ($la -gt $CritHours) {
        $out.Add("WARNING: nessuna scrittura di log da oltre $CritHours h. Il job potrebbe non essere piu' schedulato.")
        Set-Exit 1
    }
} else {
    $out.Add("WARNING: nessun log di job trovato sotto $JobLogPath (ne' 'Job_*\*.log' ne' 'Job_*.log').")
    Set-Exit 1
}

# ---------- 6. Verdetto ----------
$verdict = switch ($exitCode) { 0 { 'OK' } 1 { 'WARNING' } 2 { 'CRITICAL' } }
$out.Add("--- Verdetto: $verdict ---")
$out | ForEach-Object { Write-Output $_ }

# ---------- 7. Custom field NinjaOne ----------
if ($WriteNinjaFields) {
    try {
        Ninja-Property-Set veeamLastBackupHours $ageHours
        Ninja-Property-Set veeamStatus          $verdict
    } catch {
        Write-Output "Nota: scrittura custom field non riuscita ($($_.Exception.Message))."
    }
}

exit $exitCode
