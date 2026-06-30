<#
================================================================================
 Controlla-Salute.ps1  —  Check di SOLA LETTURA di salute e stabilita' del PC
================================================================================
 SCOPO
   Interroga il REGISTRO EVENTI e lo stato live delle risorse per far emergere i
   problemi che lo snapshot di configurazione NON vede: esaurimento di memoria
   (OOM / commit limit), crash e hang delle applicazioni, schermate blu (BSOD),
   spegnimenti anomali, errori hardware (WHEA) e corruzione del file system.
   Nasce dall'incidente del 2026-06-30 (Chrome/VS Code/Telegram terminati per
   esaurimento memoria): vedi docs\07_SALUTE_E_STABILITA.md.

 GARANZIE
   - NON modifica nulla quando lo esegui senza parametri: legge soltanto.
   - L'UNICA cosa che modifica il sistema e' la CREAZIONE/RIMOZIONE dell'attivita
     pianificata con -Installa / -Disinstalla (serve admin, reversibile).
   - Niente segreti, niente identificativi reali: l'output (nomi processo, conteggi)
     finisce in snapshots\ (ignorata da git). Verificalo comunque prima di versionare.

 USO
   .\Controlla-Salute.ps1                 # check sugli ultimi 14 giorni (sola lettura)
   .\Controlla-Salute.ps1 -Giorni 30      # finestra piu' ampia
   .\Controlla-Salute.ps1 -Retention 14   # tiene solo gli ultimi 14 report salute_*
   .\Controlla-Salute.ps1 -Installa       # attivita pianificata giornaliera (admin)
   .\Controlla-Salute.ps1 -Disinstalla    # rimuove l'attivita (admin)

 NOTA
   Alcuni log (BSOD, alcuni eventi di sistema) sono piu' completi da PowerShell
   AMMINISTRATORE; il riepilogo segnala con quali privilegi e' stato eseguito.
================================================================================
#>
param(
    [int]$Giorni = 14,
    # Retention: quanti report salute piu' recenti tenere (0 = tieni tutto).
    [int]$Retention = 0,
    [switch]$Installa,
    [switch]$Disinstalla,
    [ValidateSet('Settimanale','Giornaliera')][string]$Frequenza = 'Giornaliera',
    [string]$Ora = '13:15'
)

$ErrorActionPreference = 'Continue'
$base     = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj     = Split-Path -Parent $base
$me       = $MyInvocation.MyCommand.Path
$taskName = 'windows-status Controllo salute'
$isAdmin  = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ----------------------------------------------------------------------------
#  Installazione / rimozione dell'attivita pianificata (unica parte che MODIFICA)
# ----------------------------------------------------------------------------
if($Disinstalla){
    if(-not $isAdmin){ Write-Host 'Serve PowerShell amministratore per rimuovere l''attivita.' -ForegroundColor Red; return }
    if(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue){
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Attivita '$taskName' RIMOSSA." -ForegroundColor Green
    } else { Write-Host 'Attivita non presente: niente da rimuovere.' }
    return
}
if($Installa){
    if(-not $isAdmin){ Write-Host 'Serve PowerShell amministratore per creare l''attivita pianificata.' -ForegroundColor Red; return }
    try {
        $arg     = "-NoProfile -ExecutionPolicy Bypass -File `"$me`" -Giorni $Giorni -Retention 30"
        $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trigger = if($Frequenza -eq 'Giornaliera'){ New-ScheduledTaskTrigger -Daily -At $Ora } else { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $Ora }
        $princ   = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
        $set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $princ -Settings $set `
            -Description 'Check periodico di salute/stabilita di windows-status (sola lettura). Reversibile: Controlla-Salute.ps1 -Disinstalla.' -Force | Out-Null
        Write-Host "Attivita '$taskName' INSTALLATA ($Frequenza, ore $Ora, come SYSTEM, finestra $Giorni giorni)." -ForegroundColor Green
        Write-Host 'Reversibile con: .\Controlla-Salute.ps1 -Disinstalla'
        Write-Host 'I report salute vanno in snapshots\ (ignorata da git).'
    } catch { Write-Host "Errore nella creazione dell'attivita: $_" -ForegroundColor Red }
    return
}

# ----------------------------------------------------------------------------
#  Check (sola lettura)
# ----------------------------------------------------------------------------
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$outRoot = Join-Path $proj 'snapshots'
$outDir  = Join-Path $outRoot "salute_$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$since   = (Get-Date).AddDays(-[math]::Abs($Giorni))

$summary = New-Object System.Collections.Generic.List[string]
$alerts  = New-Object System.Collections.Generic.List[string]
function Add-Sum([string]$line){ $summary.Add($line) }
function Section([string]$t){ Add-Sum ''; Add-Sum ('=' * 72); Add-Sum $t; Add-Sum ('=' * 72) }
function Add-Alert([string]$liv,[string]$cat,[string]$txt){ $alerts.Add("[$liv][$cat] $txt") }
function Save([string]$name,$content){ $content | Out-File -FilePath (Join-Path $outDir $name) -Encoding UTF8 }
# Lettura eventi tollerante: nessun match => lista vuota, non eccezione
function Get-Ev($filter){ try { @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop) } catch { @() } }

# Codici eccezione tipici di ESAURIMENTO MEMORIA (il cuore dell'incidente 2026-06-30).
# I dialoghi/loader e i runtime li espongono in forme diverse: qui la mappa unica.
$oomCodes = @{
    'c000012d' = 'STATUS_COMMITMENT_LIMIT (memoria/commit esaurita: il processo non parte)'
    'c0000017' = 'STATUS_NO_MEMORY (allocazione fallita)'
    'e0000008' = 'OOM di Chromium/Electron (Chrome, VS Code, Edge, app Electron)'
    '8007000e' = 'E_OUTOFMEMORY'
}

Add-Sum "CHECK SALUTE E STABILITA  -  $(Get-Date)"
Add-Sum "Finestra analizzata : ultimi $Giorni giorni (dal $($since.ToString('yyyy-MM-dd HH:mm')))"
Add-Sum "Eseguito da         : $env:USERDOMAIN\$env:USERNAME   (amministratore: $isAdmin)"
if(-not $isAdmin){ Add-Sum 'ATTENZIONE: senza admin alcuni eventi di sistema/BSOD possono mancare.' }

# --- 1. STATO MEMORIA LIVE -------------------------------------------------
Section '1. STATO MEMORIA LIVE (in questo momento)'
try {
    $os   = Get-CimInstance Win32_OperatingSystem
    $perf = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction SilentlyContinue
    $totGB  = [math]::Round($os.TotalVisibleMemorySize/1MB,1)
    $freeGB = [math]::Round($os.FreePhysicalMemory/1MB,1)
    $freePct = if($totGB){ [math]::Round($freeGB/$totGB*100,0) } else { 0 }
    $commitLimGB = [math]::Round($os.TotalVirtualMemorySize/1MB,1)
    $commitUseGB = [math]::Round(($os.TotalVirtualMemorySize-$os.FreeVirtualMemory)/1MB,1)
    $commitPct   = if($perf){ [int]$perf.PercentCommittedBytesInUse } elseif($commitLimGB){ [math]::Round($commitUseGB/$commitLimGB*100,0) } else { 0 }
    Add-Sum ("RAM fisica         : {0} GB totali, {1} GB liberi ({2}%)" -f $totGB,$freeGB,$freePct)
    Add-Sum ("Commit             : {0} GB usati / {1} GB limite  ({2}% committed)" -f $commitUseGB,$commitLimGB,$commitPct)
    if($perf){ Add-Sum ("Paging (Pages/sec) : {0}" -f [int]$perf.PagesPerSec) }
    if($freePct -lt 10){ Add-Alert 'ALERT' 'MEMORIA' "RAM libera molto bassa: $freePct%" }
    elseif($freePct -lt 20){ Add-Alert 'WARN' 'MEMORIA' "RAM libera bassa: $freePct%" }
    if($commitPct -ge 90){ Add-Alert 'ALERT' 'MEMORIA' "commit charge al $commitPct% del limite (rischio OOM imminente)" }
    elseif($commitPct -ge 80){ Add-Alert 'WARN' 'MEMORIA' "commit charge al $commitPct% del limite" }
} catch { Add-Sum "Stato memoria non leggibile: $_" }

# Top processi per memoria + aggregato per nome (i sospetti dei leak emergono qui)
try {
    $procs = Get-Process -ErrorAction SilentlyContinue
    $top = $procs | Sort-Object WS -Descending | Select-Object -First 25 @{n='Nome';e={$_.ProcessName}}, Id, @{n='WS_MB';e={[math]::Round($_.WS/1MB)}}, @{n='Privata_MB';e={[math]::Round($_.PrivateMemorySize64/1MB)}}
    $top | Export-Csv (Join-Path $outDir 'memoria_top_processi.csv') -NoTypeInformation -Encoding UTF8
    $agg = $procs | Group-Object ProcessName | Select-Object Name, Count, @{n='TotWS_MB';e={[math]::Round((($_.Group|Measure-Object WS -Sum).Sum)/1MB)}} | Sort-Object TotWS_MB -Descending | Select-Object -First 15
    $agg | Export-Csv (Join-Path $outDir 'memoria_aggregato_per_nome.csv') -NoTypeInformation -Encoding UTF8
    Add-Sum ''
    Add-Sum 'Top 5 processi per memoria (dettaglio in memoria_top_processi.csv):'
    $top | Select-Object -First 5 | ForEach-Object { Add-Sum ("  {0,-22} PID {1,-7} {2} MB" -f $_.Nome,$_.Id,$_.WS_MB) }
    Add-Sum 'Top 5 per nome aggregato (memoria_aggregato_per_nome.csv):'
    $agg | Select-Object -First 5 | ForEach-Object { Add-Sum ("  {0,-22} x{1,-4} {2} MB" -f $_.Name,$_.Count,$_.TotWS_MB) }
} catch { Add-Sum "Elenco processi non leggibile: $_" }

# --- 2. ESAURIMENTO RISORSE (Resource-Exhaustion-Detector, ID 2004) --------
Section '2. ESAURIMENTO MEMORIA VIRTUALE (Resource-Exhaustion-Detector, ID 2004)'
try {
    $re = Get-Ev @{ LogName='System'; ProviderName='Microsoft-Windows-Resource-Exhaustion-Detector'; Id=2004; StartTime=$since }
    Add-Sum "Eventi 2004 nella finestra: $($re.Count)"
    if($re.Count -gt 0){
        Add-Sum "  Primo: $($re[-1].TimeCreated)   Ultimo: $($re[0].TimeCreated)"
        # Top consumatori citati nei messaggi (estrae i nomi *.exe)
        $cons = @{}
        foreach($e in $re){ foreach($m in [regex]::Matches($e.Message,'([\w\.\-]+\.exe)')){ $n=$m.Groups[1].Value; $cons[$n]=([int]$cons[$n])+1 } }
        $topCons = $cons.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 6
        if($topCons){ Add-Sum '  Processi piu citati come consumatori:'; $topCons | ForEach-Object { Add-Sum "    $($_.Key)  (in $($_.Value) eventi)" } }
        $re | Select-Object TimeCreated, Message | Format-List | Out-String | Set-Content (Join-Path $outDir 'esaurimento_2004.txt') -Encoding UTF8
        if($re.Count -ge 20){ Add-Alert 'ALERT' 'OOM' "$($re.Count) eventi di memoria virtuale insufficiente: esaurimento ricorrente (probabile leak)" }
        else { Add-Alert 'WARN' 'OOM' "$($re.Count) eventi di memoria virtuale insufficiente" }
    }
} catch { Add-Sum "Lettura 2004 fallita: $_" }

# --- 3. CRASH APPLICATIVI (Application, ID 1000) ---------------------------
Section '3. CRASH APPLICATIVI (Application Error, ID 1000)'
try {
    $cr = Get-Ev @{ LogName='Application'; Id=1000; StartTime=$since }
    Add-Sum "Crash totali nella finestra: $($cr.Count)"
    if($cr.Count -gt 0){
        $rows = foreach($e in $cr){
            $code = ''; try { $code = [string]$e.Properties[6].Value } catch {}
            $codeNorm = ($code -replace '^0x','').ToLower()
            [pscustomobject]@{ Quando=$e.TimeCreated; App=($e.Properties[0].Value); Modulo=($e.Properties[3].Value); Codice=$code; OOM=$oomCodes[$codeNorm] }
        }
        $rows | Sort-Object Quando -Descending | Export-Csv (Join-Path $outDir 'crash_applicativi.csv') -NoTypeInformation -Encoding UTF8
        Add-Sum 'Per applicazione:'
        $rows | Group-Object App | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { Add-Sum ("  {0,-28} x{1}" -f $_.Name,$_.Count) }
        $oom = @($rows | Where-Object OOM)
        if($oom.Count -gt 0){
            Add-Sum ''
            Add-Sum "Crash riconducibili a ESAURIMENTO MEMORIA: $($oom.Count)"
            $oom | Group-Object {$_.App} | ForEach-Object { Add-Sum "  $($_.Name) x$($_.Count) -> $($_.Group[0].OOM)" }
            Add-Alert 'ALERT' 'OOM' "$($oom.Count) crash applicativi per esaurimento memoria (codici: $((($oom.Codice|Sort-Object -Unique) -join ', ')))"
        }
    }
} catch { Add-Sum "Lettura crash 1000 fallita: $_" }

# --- 4. HANG APPLICATIVI (Application, ID 1002) ----------------------------
Section '4. APPLICAZIONI BLOCCATE (Application Hang, ID 1002)'
try {
    $hg = Get-Ev @{ LogName='Application'; Id=1002; StartTime=$since }
    Add-Sum "Hang totali nella finestra: $($hg.Count)"
    if($hg.Count -gt 0){
        $hg | Group-Object {$_.Properties[0].Value} | Sort-Object Count -Descending | Select-Object -First 8 |
            ForEach-Object { Add-Sum ("  {0,-28} x{1}" -f $_.Name,$_.Count) }
    }
} catch { Add-Sum "Lettura hang 1002 fallita: $_" }

# --- 5. STABILITA' DI SISTEMA: BSOD, spegnimenti anomali -------------------
Section '5. STABILITA DI SISTEMA (BSOD e arresti imprevisti)'
try {
    $bsod = Get-Ev @{ LogName='System'; ProviderName='Microsoft-Windows-WER-SystemErrorReporting'; Id=1001; StartTime=$since }
    Add-Sum "Schermate blu / Bugcheck (BSOD): $($bsod.Count)"
    if($bsod.Count -gt 0){
        $bsod | Select-Object TimeCreated, Message | Format-List | Out-String | Set-Content (Join-Path $outDir 'bsod.txt') -Encoding UTF8
        $bsod | Select-Object -First 5 | ForEach-Object { Add-Sum "  $($_.TimeCreated)" }
        Add-Alert 'ALERT' 'BSOD' "$($bsod.Count) schermate blu nella finestra (dettaglio in bsod.txt)"
    }
    $kp = Get-Ev @{ LogName='System'; Id=41; StartTime=$since }            # Kernel-Power 41 = riavvio senza spegnimento pulito
    $ev6008 = Get-Ev @{ LogName='System'; Id=6008; StartTime=$since }      # arresto imprevisto
    Add-Sum "Riavvii anomali (Kernel-Power 41): $($kp.Count)  |  Arresti imprevisti (6008): $($ev6008.Count)"
    if($kp.Count -gt 0){ $kp | Select-Object -First 5 | ForEach-Object { Add-Sum "  Kernel-Power 41: $($_.TimeCreated)" }
                         Add-Alert 'WARN' 'STABILITA' "$($kp.Count) riavvii/spegnimenti anomali (Kernel-Power 41)" }
} catch { Add-Sum "Lettura stabilita fallita: $_" }

# --- 6. HARDWARE: errori macchina (WHEA) -----------------------------------
Section '6. ERRORI HARDWARE (WHEA-Logger: CPU/RAM/PCIe)'
try {
    $whea = Get-Ev @{ LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$since }
    $wheaErr = @($whea | Where-Object { $_.Level -le 3 })   # 1=Critical 2=Error 3=Warning
    Add-Sum "Eventi WHEA: $($whea.Count) (di cui error/critical: $($wheaErr.Count))"
    if($wheaErr.Count -gt 0){
        $whea | Group-Object Id | ForEach-Object { Add-Sum "  ID $($_.Name) x$($_.Count)" }
        Add-Alert 'ALERT' 'HARDWARE' "$($wheaErr.Count) errori hardware WHEA: possibile RAM/CPU/PCIe difettosi (NON e' solo software)"
    } else { Add-Sum '  Nessun errore hardware: i guasti di memoria sono quindi da escludere come causa.' }
} catch { Add-Sum "Lettura WHEA fallita: $_" }

# --- 7. FILE SYSTEM: corruzione reale (non i 'volume integro' informativi) --
Section '7. INTEGRITA FILE SYSTEM / DISCO'
try {
    # Solo eventi di CORRUZIONE/ERRORE: Ntfs 55/137, disk 7/11/51/52/153.
    # ESCLUSO di proposito Ntfs ID 98 ("volume integro": informativo, genera rumore).
    $fsErr = Get-Ev @{ LogName='System'; ProviderName='Microsoft-Windows-Ntfs'; Id=55,137; StartTime=$since }
    $dskErr = Get-Ev @{ LogName='System'; ProviderName='disk'; Id=7,11,51,52,153; StartTime=$since }
    $tot = $fsErr.Count + $dskErr.Count
    Add-Sum "Errori NTFS (corruzione, 55/137): $($fsErr.Count)  |  Errori disco (7/11/51/52/153): $($dskErr.Count)"
    if($tot -gt 0){
        ($fsErr + $dskErr) | Select-Object TimeCreated, Id, ProviderName, Message | Sort-Object TimeCreated -Descending |
            Format-List | Out-String | Set-Content (Join-Path $outDir 'errori_disco.txt') -Encoding UTF8
        Add-Alert 'ALERT' 'DISCO' "$tot eventi di corruzione/errore disco (dettaglio in errori_disco.txt; valutare chkdsk e SMART)"
    } else { Add-Sum '  Nessun errore reale di file system/disco (gli eventi NTFS 98 "volume integro" sono esclusi a posta).' }
} catch { Add-Sum "Lettura errori disco fallita: $_" }

# --- VERDETTO ---------------------------------------------------------------
Section 'VERDETTO'
if($alerts.Count -eq 0){
    Add-Sum 'OK: nessun problema di stabilita o memoria nella finestra analizzata.'
} else {
    $nA = @($alerts | Where-Object { $_ -like '`[ALERT`]*' }).Count
    $nW = @($alerts | Where-Object { $_ -like '`[WARN`]*' }).Count
    Add-Sum "Rilevati $($alerts.Count) segnali ($nA ALERT, $nW WARN):"
    $alerts | ForEach-Object { Add-Sum "  $_" }
    Add-Sum ''
    Add-Sum 'Cosa fare (vedi docs\07_SALUTE_E_STABILITA.md):'
    Add-Sum '  - OOM ricorrente: identificare il processo che cresce (spesso node.exe/Electron), limitare WSL2 (.wslconfig).'
    Add-Sum '  - BSOD/WHEA: e hardware -> test RAM (mdsched), driver, temperature.'
    Add-Sum '  - Errori disco: chkdsk + SMART + backup immediato.'
}

$text = ($summary -join "`r`n")
Save 'SUMMARY.txt' $text
Write-Host $text
Write-Host ''
Write-Host "Report salvato in: $outDir" -ForegroundColor Cyan

# Retention: tiene solo gli ultimi N report salute_* (0 = tutti)
if($Retention -gt 0){
    Get-ChildItem $outRoot -Directory -Filter 'salute_*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -Skip $Retention |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}
