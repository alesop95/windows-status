<#
================================================================================
 Diagnostica-PowerPoint.ps1  -  Diagnosi di PowerPoint lento (cache identità Office)
================================================================================
 SCOPO
   Riconosce in pochi secondi la causa accertata dei blocchi di PowerPoint di
   5-10 secondi dopo ogni click: la cache Office DocToIdMapping sovradimensionata,
   che PowerPoint scorre a ogni aggiornamento del ribbon per decidere se il
   pulsante Copilot/Suggerimenti va abilitato. Mette accanto alla misura della
   cache gli hang registrati, la build di Office e i fattori che nel caso
   originale sono stati esclusi, e opzionalmente misura i blocchi dal vivo.
   Vedi docs\12_POWERPOINT_LENTO_DOCTOIDMAPPING.md.

 GARANZIE
   - Senza -Bonifica legge soltanto e scrive in snapshots\office\ (ignorata da git).
   - Della cache conta i valori e non li stampa mai: i valori sono URL di
     documenti. L'identità compare troncata ai primi 8 caratteri.
   - -Bonifica agisce solo sul profilo corrente (HKCU), si rifiuta con Office
     aperto, esporta prima un backup .reg e chiede conferma digitando SI.
     Office ricrea la chiave da solo; il backup si reimporta con reg import.

 USO
   .\Diagnostica-PowerPoint.ps1                 # diagnosi (sola lettura)
   .\Diagnostica-PowerPoint.ps1 -Monitora 60    # + misura dei blocchi per 60 s
   .\Diagnostica-PowerPoint.ps1 -TuttiIProfili  # anche gli altri utenti collegati (admin)
   .\Diagnostica-PowerPoint.ps1 -Bonifica       # backup + eliminazione a conferma

 CODICI DI USCITA
   0 = OK   1 = ATTENZIONE   2 = ALERT (cache oltre soglia)
   Con -Bonifica: 0 = bonificato o niente da fare, 3 = backup o eliminazione falliti
================================================================================
#>
param(
    [int]$Giorni = 14,
    [int]$Soglia = 10000,
    [int]$SogliaAttenzione = 1000,
    [switch]$TuttiIProfili,
    [int]$Monitora = 0,
    [switch]$Bonifica,
    # Solo per la prova su una chiave di test: il percorso della chiave DocToIdMapping.
    [string]$PercorsoChiave = 'HKCU:\Software\Microsoft\Office\16.0\Common\Identity\DocToIdMapping'
)

$ErrorActionPreference = 'Continue'
$base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj    = Split-Path -Parent $base
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir  = Join-Path $proj 'snapshots\office'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$since   = (Get-Date).AddDays(-[math]::Abs($Giorni))

$RelKey    = 'Software\Microsoft\Office\16.0\Common\Identity\DocToIdMapping'
$OfficeExe = 'WINWORD','EXCEL','POWERPNT','OUTLOOK','ONENOTE','MSACCESS','MSPUB','VISIO','WINPROJ','lync'

$summary = New-Object System.Collections.Generic.List[string]
$alerts  = New-Object System.Collections.Generic.List[string]
function Add-Sum([string]$line){ $summary.Add($line) }
function Section([string]$t){ Add-Sum ''; Add-Sum ('=' * 72); Add-Sum $t; Add-Sum ('=' * 72) }
function Add-Alert([string]$liv,[string]$cat,[string]$txt){ $alerts.Add("[$liv][$cat] $txt") }
function Get-Ev($filter){ try { @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop) } catch { @() } }
function Get-Livello([int]$n){ if($n -ge $Soglia){ 'ALERT' } elseif($n -ge $SogliaAttenzione){ 'ATTENZIONE' } else { 'OK' } }
# 'HKCU:\X' o 'Registry::HKEY_USERS\X' -> forma nativa per reg.exe
function ConvertTo-RegNative([string]$p){
    $p = $p -replace '^Registry::',''
    $p = $p -replace '^HKCU:\\','HKCU\' -replace '^HKLM:\\','HKLM\'
    $p -replace '^HKEY_CURRENT_USER\\','HKCU\' -replace '^HKEY_USERS\\','HKU\'
}

Add-Sum "DIAGNOSI POWERPOINT LENTO  -  $(Get-Date)"
Add-Sum "Eseguito da : $env:USERDOMAIN\$env:USERNAME   (amministratore: $isAdmin)"
Add-Sum "Soglie      : ATTENZIONE da $SogliaAttenzione valori, ALERT da $Soglia (il caso originale: 186.322; un PC sano: 2-3)"

# --- 1. OFFICE ---------------------------------------------------------------
Section '1. OFFICE (build e canale)'
$canali = @{
    '492350f6-3a01-4f97-b9c0-c7c6ddf67d60' = 'Current Channel'
    '64256afe-f5d9-4f86-8936-8840a6a4f5be' = 'Current Channel (Preview)'
    '55336b82-a18d-4dd6-b5f6-9e5095c314a6' = 'Monthly Enterprise Channel'
    '7ffbc6bf-bc32-4f92-8982-f9dd17fd3114' = 'Semi-Annual Enterprise Channel'
    'b8f9b850-328d-4355-9145-c59439a0c4cf' = 'Semi-Annual Enterprise Channel (Preview)'
    '5440fd1f-7ecb-4221-8110-145efaa6372f' = 'Beta Channel'
}
$c2r = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue
if($c2r){
    $url = [string]$(if($c2r.UpdateChannel){ $c2r.UpdateChannel } else { $c2r.CDNBaseUrl })
    $guid = ([regex]::Match($url,'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')).Value
    $canale = if($guid -and $canali[$guid]){ $canali[$guid] } elseif($guid){ "sconosciuto ($guid)" } else { 'non rilevato' }
    Add-Sum "Build Office (ClickToRun) : $($c2r.VersionToReport)"
    Add-Sum "Canale                    : $canale"
    Add-Sum "Piattaforma               : $($c2r.Platform)"
} else { Add-Sum 'Office a consegna rapida (ClickToRun) non rilevato: la cache esiste anche con Office MSI 2016+, si controlla comunque.' }
$ppt = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\powerpnt.exe' -ErrorAction SilentlyContinue).'(default)'
Add-Sum ("POWERPNT.EXE              : {0}" -f $(if($ppt){ $ppt } else { 'non trovato in App Paths' }))

# --- 2. CACHE DocToIdMapping ---------------------------------------------------
Section '2. CACHE DocToIdMapping (causa accertata del caso)'
Add-Sum 'Un valore per ogni documento o posizione aperti, letto da PowerPoint a ogni aggiornamento del ribbon.'
# Elenco degli hive da controllare: HKCU di default, gli hive caricati in HKU con -TuttiIProfili.
$hive = New-Object System.Collections.Generic.List[object]
if($TuttiIProfili){
    if(-not $isAdmin){ Add-Sum 'ATTENZIONE: -TuttiIProfili senza admin legge solo il profilo corrente.' }
    else {
        foreach($k in Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^S-1-(5-21|12-1)-[\d-]+$' }){
            $sid = $k.PSChildName
            $lab = try { (New-Object Security.Principal.SecurityIdentifier($sid)).Translate([Security.Principal.NTAccount]).Value } catch { $sid }
            $hive.Add([pscustomobject]@{ Utente=$lab; Percorso="Registry::HKEY_USERS\$sid\$RelKey"; Corrente=$false })
        }
        Add-Sum 'Profili non collegati: non letti (nessun reg load qui). Per la flotta: scripts\rmm\Fix-OfficeDocToIdMapping.ps1.'
    }
}
if($hive.Count -eq 0){ $hive.Add([pscustomobject]@{ Utente="$env:USERDOMAIN\$env:USERNAME"; Percorso=$PercorsoChiave; Corrente=$true }) }

$cache = New-Object System.Collections.Generic.List[object]
foreach($h in $hive){
    Add-Sum ''
    Add-Sum "Profilo: $($h.Utente)"
    if(-not (Test-Path $h.Percorso)){ Add-Sum '  chiave DocToIdMapping assente: OK'; continue }
    $root = Get-Item $h.Percorso
    if($root.ValueCount -gt 0){ Add-Sum ("  (valori diretti sulla chiave: {0})" -f $root.ValueCount) }
    $sub = @(Get-ChildItem $h.Percorso -ErrorAction SilentlyContinue)
    if($sub.Count -eq 0){ Add-Sum '  nessuna sottochiave: OK' }
    foreach($s in $sub){
        $n   = [int]$s.ValueCount
        $liv = Get-Livello $n
        $id  = $s.PSChildName
        $suf = if($id -match '(_[A-Za-z]+)$'){ $matches[1] } else { '' }
        $idCorto = if($id.Length -gt 8){ $id.Substring(0,8) + '...' + $suf } else { $id }
        Add-Sum ("  {0,-22} {1,9} valori   {2}" -f $idCorto,$n,$liv)
        $cache.Add([pscustomobject]@{ Utente=$h.Utente; Corrente=$h.Corrente; Percorso=$h.Percorso; Nome=$id; Valori=$n; Livello=$liv })
        if($liv -eq 'ALERT'){ Add-Alert 'ALERT' 'CACHE' "$($h.Utente): $idCorto ha $n valori (soglia $Soglia): e' la firma del caso, vedi -Bonifica" }
        elseif($liv -eq 'ATTENZIONE'){ Add-Alert 'ATTENZIONE' 'CACHE' "$($h.Utente): $idCorto ha $n valori: crescita da sorvegliare (rieseguire fra una settimana)" }
    }
    # Totale dei valori sotto Common\Identity: nel caso 2.606 KB esportati contro 33 KB del PC sano.
    $idRoot = Split-Path $h.Percorso -Parent
    if(Test-Path $idRoot){
        $tot = [int](Get-Item $idRoot).ValueCount
        foreach($k in Get-ChildItem $idRoot -Recurse -ErrorAction SilentlyContinue){ $tot += [int]$k.ValueCount }
        Add-Sum ("  Totale valori sotto Common\Identity: {0}" -f $tot)
    }
}

# --- 3. HANG DAL REGISTRO EVENTI -----------------------------------------------
Section "3. HANG REGISTRATI (Application Hang, ID 1002, ultimi $Giorni giorni)"
$hg = Get-Ev @{ LogName='Application'; Id=1002; StartTime=$since }
$hPpt = @($hg | Where-Object { [string]$_.Properties[0].Value -ieq 'POWERPNT.EXE' })
$hWrd = @($hg | Where-Object { [string]$_.Properties[0].Value -ieq 'WINWORD.EXE' }).Count
$hXls = @($hg | Where-Object { [string]$_.Properties[0].Value -ieq 'EXCEL.EXE' }).Count
Add-Sum ("POWERPNT.EXE: {0}   WINWORD.EXE: {1}   EXCEL.EXE: {2}" -f $hPpt.Count,$hWrd,$hXls)
if($hPpt.Count -gt 0){
    Add-Sum "  Ultimo hang di PowerPoint: $($hPpt[0].TimeCreated)"
    $ver = ($hPpt | ForEach-Object { [string]$_.Properties[1].Value } | Sort-Object -Unique) -join ', '
    Add-Sum "  Versioni coinvolte: $ver"
    if($hWrd + $hXls -eq 0){ Add-Sum '  Solo PowerPoint si blocca, Word ed Excel no: e'' la stessa firma del caso.' }
    Add-Alert 'ATTENZIONE' 'HANG' "$($hPpt.Count) hang di PowerPoint registrati nella finestra"
}

# --- 4. FATTORI ESCLUSI NEL CASO (contesto) ------------------------------------
Section '4. FATTORI ESCLUSI NEL CASO ORIGINALE (solo contesto, fuori dal verdetto)'
Add-Sum 'Nel caso originale nessuno di questi era la causa; si riportano per non ripetere le stesse prove.'
$addin = foreach($r in 'HKLM:\SOFTWARE\Microsoft\Office\PowerPoint\Addins','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\PowerPoint\Addins','HKCU:\Software\Microsoft\Office\PowerPoint\Addins'){
    foreach($k in Get-ChildItem $r -ErrorAction SilentlyContinue){
        $lb = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).LoadBehavior
        [pscustomobject]@{ Nome=$k.PSChildName; LoadBehavior=$lb }
    }
}
$attivi = @($addin | Where-Object { $_.LoadBehavior -eq 3 })
Add-Sum ("Add-in COM di PowerPoint: {0} registrati, {1} caricati all'avvio (LoadBehavior 3){2}" -f @($addin).Count,$attivi.Count,$(if($attivi.Count){ ': ' + (($attivi.Nome) -join ', ') } else { '' }))
$hw = (Get-ItemProperty 'HKCU:\Software\Microsoft\Office\16.0\Common\Graphics' -ErrorAction SilentlyContinue).DisableHardwareAcceleration
Add-Sum ("Accelerazione grafica di Office: {0}" -f $(if($hw -eq 1){ 'DISATTIVATA (DisableHardwareAcceleration=1)' } else { 'attiva' }))
$rec  = Join-Path $env:APPDATA 'Microsoft\Windows\Recent'
$nRec = @(Get-ChildItem $rec -File -Filter '*.lnk' -ErrorAction SilentlyContinue).Count
$nOff = @(Get-ChildItem (Join-Path $env:APPDATA 'Microsoft\Office\Recent') -File -ErrorAction SilentlyContinue).Count
$jl   = Get-ChildItem (Join-Path $rec 'AutomaticDestinations') -File -ErrorAction SilentlyContinue | Measure-Object Length -Maximum
Add-Sum ("Elementi recenti: Windows {0}, Office {1}; jump list più grande {2} MB (nel caso: 21.430, 240, 6 MB)" -f $nRec,$nOff,[math]::Round(([double]$jl.Maximum)/1MB,1))
$prn = (Get-CimInstance Win32_Printer -Filter 'Default=TRUE' -ErrorAction SilentlyContinue | Select-Object -First 1).Name
Add-Sum ("Stampante predefinita: {0}" -f $(if($prn){ $prn } else { 'nessuna' }))
$fSys = @(Get-ChildItem (Join-Path $env:WINDIR 'Fonts') -File -ErrorAction SilentlyContinue).Count
$fUsr = @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts') -File -ErrorAction SilentlyContinue).Count
Add-Sum ("Font: {0} di sistema, {1} installati dall'utente" -f $fSys,$fUsr)
$pp = Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -First 1
if($pp){
    $terzi = @($pp.Modules | Where-Object { $_.FileVersionInfo.CompanyName -and $_.FileVersionInfo.CompanyName -notmatch 'Microsoft' } |
               ForEach-Object { $_.FileVersionInfo.CompanyName } | Sort-Object -Unique)
    Add-Sum ("Moduli di terze parti in POWERPNT.EXE: {0}" -f $(if($terzi.Count){ $terzi -join ', ' } else { 'nessuno' }))
} else { Add-Sum 'Moduli di terze parti: PowerPoint non è aperto, non rilevabili.' }

# --- 5. MISURA DEI BLOCCHI (opzionale) -----------------------------------------
if($Monitora -gt 0){
    Section "5. MISURA DEI BLOCCHI DAL VIVO ($Monitora s, un campione al secondo)"
    $ncpu = [Environment]::ProcessorCount
    $righe = New-Object System.Collections.Generic.List[object]
    $prev = $null; $prevT = $null
    Write-Host "Misura in corso per $Monitora secondi: usare PowerPoint normalmente (click, cambio slide)..." -ForegroundColor Cyan
    for($i = 0; $i -lt $Monitora; $i++){
        $p = Get-Process POWERPNT -ErrorAction SilentlyContinue | Select-Object -First 1
        $t = Get-Date
        if($p){
            $cpu = $p.TotalProcessorTime.TotalMilliseconds
            $core = if($null -ne $prev){ [math]::Round(($cpu - $prev) / ($t - $prevT).TotalMilliseconds * 100, 0) } else { $null }
            $righe.Add([pscustomobject]@{ Ora=$t.ToString('HH:mm:ss'); Risponde=$p.Responding; CpuCorePct=$core; CpuTotPct=$(if($null -ne $core){ [math]::Round($core/$ncpu,1) } else { $null }) })
            $prev = $cpu; $prevT = $t
        } else { $righe.Add([pscustomobject]@{ Ora=$t.ToString('HH:mm:ss'); Risponde=$null; CpuCorePct=$null; CpuTotPct=$null }) }
        Start-Sleep -Milliseconds 1000
    }
    $csv = Join-Path $outDir "monitor_$stamp.csv"
    $righe | Export-Csv $csv -NoTypeInformation -Encoding UTF8
    $vivi = @($righe | Where-Object { $_.Risponde -ne $null })
    if($vivi.Count -eq 0){ Add-Sum 'PowerPoint non era aperto durante la misura.' }
    else {
        # Episodi = sequenze consecutive di campioni "non risponde"
        $ep = New-Object System.Collections.Generic.List[int]; $run = 0
        foreach($r in $vivi){ if($r.Risponde -eq $false){ $run++ } elseif($run){ $ep.Add($run); $run = 0 } }
        if($run){ $ep.Add($run) }
        $picco = ($vivi | Where-Object CpuCorePct -ne $null | Measure-Object CpuCorePct -Maximum).Maximum
        Add-Sum ("Campioni con PowerPoint aperto: {0}; episodi 'Non risponde': {1}; durate (s): {2}" -f $vivi.Count,$ep.Count,$(if($ep.Count){ $ep -join ', ' } else { '-' }))
        Add-Sum ("Picco di CPU di PowerPoint: {0}% di un core" -f [int]$picco)
        Add-Sum "Dettaglio: $csv"
        if($ep.Count -gt 0 -and $picco -ge 80){ Add-Sum '  Blocchi con un core saturo: calcolo interno, la stessa firma del caso (non rete, non disco).' }
        if($ep.Count -gt 0){ Add-Alert 'ATTENZIONE' 'BLOCCHI' "$($ep.Count) episodi di 'Non risponde' in $Monitora s" }
    }
}

# --- VERDETTO ------------------------------------------------------------------
Section 'VERDETTO'
$nA = @($alerts | Where-Object { $_ -like '`[ALERT`]*' }).Count
$nW = @($alerts | Where-Object { $_ -like '`[ATTENZIONE`]*' }).Count
if($alerts.Count -eq 0){ Add-Sum 'OK: cache sana e nessun hang di PowerPoint nella finestra.' }
else {
    $alerts | ForEach-Object { Add-Sum "  $_" }
    Add-Sum ''
    if($nA -gt 0){
        Add-Sum 'Cache oltre soglia. Rimedio: chiudere Office e lanciare .\scripts\Diagnostica-PowerPoint.ps1 -Bonifica'
        Add-Sum '(backup .reg, conferma, eliminazione della sola sottochiave; Office la ricrea).'
    } elseif(@($cache | Where-Object Livello -eq 'ALERT').Count -eq 0 -and ($hPpt.Count -gt 0 -or $nW -gt 0)){
        Add-Sum 'La cache è sana: la causa è un''altra. Il passo che nel caso ha risolto è la profilazione:'
        Add-Sum '  wpr -start CPU -filemode'
        Add-Sum '  (riprodurre i blocchi in PowerPoint per 20-30 secondi)'
        Add-Sum '  wpr -stop <cartella-amministratori>\ppt_hang.etl'
        Add-Sum 'Analisi con Windows Performance Analyzer: docs\12_POWERPOINT_LENTO_DOCTOIDMAPPING.md, sezione 6.'
        Add-Sum 'La traccia pesa alcuni GB e contiene dati del profilo: non salvarla in una cartella leggibile da tutti.'
    }
}
$exit = if($nA -gt 0){ 2 } elseif($nW -gt 0){ 1 } else { 0 }

$file = Join-Path $outDir "diagnosi_$stamp.txt"
($summary -join "`r`n") | Out-File -FilePath $file -Encoding UTF8
Write-Host ($summary -join "`r`n")
Write-Host ''
Write-Host "Report salvato in: $file" -ForegroundColor Cyan

# --- BONIFICA (unica parte che MODIFICA) ---------------------------------------
if($Bonifica){
    Write-Host ''
    Write-Host '=== BONIFICA (modifica il registro del profilo corrente) ===' -ForegroundColor Yellow
    $target = @($cache | Where-Object { $_.Corrente -and $_.Livello -eq 'ALERT' })
    if($target.Count -eq 0){ Write-Host 'Nessuna sottochiave del profilo corrente oltre soglia: niente da bonificare.' -ForegroundColor Green; exit $exit }
    $sess   = (Get-Process -Id $PID).SessionId
    $aperti = @(Get-Process -Name $OfficeExe -ErrorAction SilentlyContinue | Where-Object { $_.SessionId -eq $sess })
    if($aperti.Count -gt 0){
        Write-Host ("App Office aperte ({0}): chiuderle e rilanciare. Nessuna modifica eseguita." -f (($aperti.ProcessName | Sort-Object -Unique) -join ', ')) -ForegroundColor Red
        exit $exit
    }
    $native = ConvertTo-RegNative $target[0].Percorso
    $bkDir  = Join-Path $outDir 'backup'
    New-Item -ItemType Directory -Force -Path $bkDir | Out-Null
    $bk = Join-Path $bkDir "DocToIdMapping_$stamp.reg"
    & reg.exe export $native $bk /y 2>&1 | Out-Null
    if(-not (Test-Path $bk) -or (Get-Item $bk).Length -eq 0){ Write-Host "Backup NON riuscito ($bk): nessuna modifica eseguita." -ForegroundColor Red; exit 3 }
    Write-Host ("Backup: {0} ({1} KB). Contiene URL di documenti: resta locale, non va condiviso." -f $bk,[math]::Round((Get-Item $bk).Length/1KB))
    $target | ForEach-Object { Write-Host ("  da eliminare: {0} ({1} valori)" -f $_.Nome,$_.Valori) }
    $ok = Read-Host "Digita SI per eliminare $($target.Count) sottochiave/i"
    if($ok -cne 'SI'){ Write-Host 'Annullato: nessuna modifica eseguita (il backup resta).' -ForegroundColor Yellow; exit $exit }
    $fatto = 0
    foreach($t in $target){
        & reg.exe delete "$native\$($t.Nome)" /f 2>&1 | Out-Null
        if(Test-Path (Join-Path $t.Percorso $t.Nome)){ Write-Host "Eliminazione di $($t.Nome) NON riuscita." -ForegroundColor Red }
        else { Write-Host "Eliminata $($t.Nome) ($($t.Valori) valori)." -ForegroundColor Green; $fatto++ }
    }
    Write-Host ''
    Write-Host 'Riga per il changelog (paletto 6):'
    Write-Host ("  {0} | Bonificata la cache DocToIdMapping del profilo corrente ({1} sottochiave/i, max {2} valori) | blocchi di PowerPoint, vedi docs/12 | reg import ""{3}"" (reintroduce il problema)" -f (Get-Date -Format 'yyyy-MM-dd'),$fatto,(($target | Measure-Object Valori -Maximum).Maximum),$bk)
    Write-Host 'Riaprire PowerPoint e verificare; rieseguire la diagnosi fra una settimana per misurare la ricrescita.'
    exit $(if($fatto -eq $target.Count){ 0 } else { 3 })
}
exit $exit
