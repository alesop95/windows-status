<#
================================================================================
 Compare-Snapshot.ps1 — Confronta due snapshot e mostra COSA E' CAMBIATO
================================================================================
 USO
   .\Compare-Snapshot.ps1                     # confronta i due snapshot piu recenti
   .\Compare-Snapshot.ps1 -Old <cartella> -New <cartella>

 Confronta gli elenchi chiave (software, servizi, avvio, app, account) e segnala
 le voci aggiunte (+) e rimosse (-). In coda produce gli ALERT DI SICUREZZA:
 variazioni critiche (nuovi amministratori, account abilitati, autorun, azioni di
 task pianificate, porte in ascolto, cambi di StartMode/account dei servizi,
 driver non firmati, postura hardware/OS, esclusioni Defender e regole ASR,
 nuove regole firewall inbound) evidenziate per la revisione. Di sola lettura.

 Gli alert usano anche i CSV della sezione "superficie d'attacco" dello snapshot:
 se un CSV manca in uno dei due snapshot (es. snapshot vecchio), la relativa
 categoria viene saltata senza errori.
================================================================================
#>
param([string]$Old,[string]$New)

$base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$snapRoot= Join-Path (Split-Path -Parent $base) 'snapshots'

if(-not $Old -or -not $New){
    $snaps = Get-ChildItem $snapRoot -Directory | Where-Object Name -like 'snapshot_*' | Sort-Object Name
    if($snaps.Count -lt 2){ Write-Host 'Servono almeno due snapshot per il confronto.' -ForegroundColor Yellow; return }
    $Old = $snaps[-2].FullName; $New = $snaps[-1].FullName
}
Write-Host "PRIMA: $Old"
Write-Host "DOPO : $New`n"

# Avvisa se i due snapshot sono stati presi con privilegi diversi: da admin si vede di piu'
# (Appx -AllUsers, tutte le task, hive di servizio), quindi il diff sarebbe rumore di visibilita'
function Get-Elev([string]$dir){
    $p = Join-Path $dir 'SUMMARY.txt'
    if(Test-Path $p){ $s = Get-Content $p | Select-String '^Amministratore'; if($s){ return ($s.Line -split ':')[-1].Trim() } }
    $null
}
$eo = Get-Elev $Old; $en = Get-Elev $New
if($eo -and $en -and $eo -ne $en){
    Write-Host "ATTENZIONE: snapshot presi con privilegi diversi (PRIMA admin=$eo, DOPO admin=$en):" -ForegroundColor Yellow
    Write-Host "molte differenze saranno di VISIBILITA', non cambiamenti reali. Confronta snapshot omogenei.`n" -ForegroundColor Yellow
}

function Load-Csv([string]$dir,[string]$file){
    $p = Join-Path $dir $file
    if(Test-Path $p){ ,@(Import-Csv $p) } else { $null }
}

# ---------------------------------------------------------------------------
#  Diff generale per chiave: voci aggiunte (+) e rimosse (-)
# ---------------------------------------------------------------------------
$files = @{
    'Software (registro)'   = @{ file='software_registro.csv';      key='DisplayName' }
    'Servizi (StartMode)'   = @{ file='servizi.csv';                 key='Name' }
    'Avvio automatico'      = @{ file='avvio.csv';                   key='Name' }
    'App Windows (Appx)'    = @{ file='app_appx_allusers.csv';       key='Name' }
    'Account locali'        = @{ file='account_locali.csv';          key='Name' }
    'Attivita pianificate'  = @{ file='attivita_pianificate.csv';    key='TaskName' }
    'Dischi fisici (HW)'    = @{ file='hardware_dischi.csv';          key='Modello' }
    'Dispositivi USB (HW)'  = @{ file='hardware_usb_dispositivi.csv'; key='FriendlyName' }
    'Banchi RAM (HW)'       = @{ file='hardware_ram.csv';             key='Slot' }
}

foreach($label in $files.Keys){
    $f=$files[$label].file; $k=$files[$label].key
    $po=Join-Path $Old $f; $pn=Join-Path $New $f
    if(-not (Test-Path $po) -or -not (Test-Path $pn)){ continue }
    # filtro su null perche' un CSV vuoto rende null e Compare-Object non accetta null/vuoto
    $o=@((Import-Csv $po).$k | Where-Object { $null -ne $_ })
    $n=@((Import-Csv $pn).$k | Where-Object { $null -ne $_ })
    $diff = if($o.Count -eq 0 -and $n.Count -eq 0){ $null }
            elseif($o.Count -eq 0){ $n | ForEach-Object { [pscustomobject]@{ InputObject=$_; SideIndicator='=>' } } }
            elseif($n.Count -eq 0){ $o | ForEach-Object { [pscustomobject]@{ InputObject=$_; SideIndicator='<=' } } }
            else { Compare-Object $o $n }
    Write-Host "== $label ==" -ForegroundColor Cyan
    if(-not $diff){ Write-Host '   nessuna differenza'; continue }
    $diff | ForEach-Object {
        if($_.SideIndicator -eq '=>'){ Write-Host "   + AGGIUNTO : $($_.InputObject)" -ForegroundColor Green }
        else                         { Write-Host "   - RIMOSSO  : $($_.InputObject)" -ForegroundColor Red }
    }
}

# ---------------------------------------------------------------------------
#  ALERT DI SICUREZZA: variazioni critiche da verificare una per una
# ---------------------------------------------------------------------------
$alerts = New-Object System.Collections.Generic.List[string]
function Add-Alert([string]$categoria,[string]$dettaglio){ $alerts.Add("[$categoria] $dettaglio") }

# 1. Nuovi membri del gruppo Administrators
$ao = Load-Csv $Old 'amministratori_locali.csv'; $an = Load-Csv $New 'amministratori_locali.csv'
if($null -ne $ao -and $null -ne $an){
    foreach($m in $an){ if($m.Name -notin @($ao.Name)){ Add-Alert 'ADMIN' "nuovo membro di Administrators: $($m.Name) [$($m.ObjectClass)/$($m.PrincipalSource)]" } }
}

# 2. Account locali nuovi o riabilitati
$lo = Load-Csv $Old 'account_locali.csv'; $ln = Load-Csv $New 'account_locali.csv'
if($null -ne $lo -and $null -ne $ln){
    $oldBy=@{}; $lo | ForEach-Object { $oldBy[$_.Name]=$_ }
    foreach($a in $ln){
        if(-not $oldBy.ContainsKey($a.Name)){
            if($a.Enabled -eq 'True'){ Add-Alert 'ACCOUNT' "nuovo account locale ABILITATO: $($a.Name)" }
            else                     { Add-Alert 'ACCOUNT' "nuovo account locale (disabilitato): $($a.Name)" }
        } elseif($oldBy[$a.Name].Enabled -eq 'False' -and $a.Enabled -eq 'True'){
            Add-Alert 'ACCOUNT' "account riabilitato: $($a.Name)"
        }
    }
}

# 3. Nuovi autorun: cartelle/chiavi di avvio classiche e autoruns profondi
$vo = Load-Csv $Old 'avvio.csv'; $vn = Load-Csv $New 'avvio.csv'
if($null -ne $vo -and $null -ne $vn){
    foreach($r in $vn){ if($r.Name -notin @($vo.Name)){ Add-Alert 'AUTORUN' "nuova voce di avvio: $($r.Name) -> $($r.Command) [$($r.Location)]" } }
}
$ro = Load-Csv $Old 'autoruns_registro.csv'; $rn = Load-Csv $New 'autoruns_registro.csv'
if($null -ne $ro -and $null -ne $rn){
    $keyO = @($ro | ForEach-Object { "$($_.Origine)|$($_.Nome)|$($_.Comando)" })
    foreach($r in $rn){
        if("$($r.Origine)|$($r.Nome)|$($r.Comando)" -notin $keyO){
            Add-Alert 'AUTORUN' "registro: $($r.Origine) \ $($r.Nome) = $($r.Comando)"
        }
    }
}

# 4. Task pianificate nuove o con azione cambiata (solo non Microsoft)
$to = Load-Csv $Old 'attivita_pianificate_azioni.csv'; $tn = Load-Csv $New 'attivita_pianificate_azioni.csv'
if($null -ne $to -and $null -ne $tn){
    $keyO = @($to | ForEach-Object { "$($_.TaskPath)$($_.TaskName)|$($_.Esegui)|$($_.Argomenti)" })
    foreach($t in $tn){
        if("$($t.TaskPath)$($t.TaskName)|$($t.Esegui)|$($t.Argomenti)" -notin $keyO){
            Add-Alert 'TASK' "task nuova o con azione cambiata: $($t.TaskPath)$($t.TaskName) -> $($t.Esegui) $($t.Argomenti)"
        }
    }
}

# 5. Nuove porte in ascolto (chiave: protocollo + porta + processo)
#    Le UDP effimere (>=49152, tipicamente browser) cambiano a ogni avvio: escluse per il rumore
$po2 = Load-Csv $Old 'porte_in_ascolto.csv'; $pn2 = Load-Csv $New 'porte_in_ascolto.csv'
if($null -ne $po2 -and $null -ne $pn2){
    $stabile = { -not ($_.Protocollo -eq 'UDP' -and [int]$_.Porta -ge 49152) }
    $keyO = @($po2 | Where-Object $stabile | ForEach-Object { "$($_.Protocollo):$($_.Porta):$($_.Processo)" } | Sort-Object -Unique)
    $keyN = @($pn2 | Where-Object $stabile | ForEach-Object { "$($_.Protocollo):$($_.Porta):$($_.Processo)" } | Sort-Object -Unique)
    foreach($k in $keyN){ if($k -notin $keyO){ Add-Alert 'PORTE' "nuova porta in ascolto: $k" } }
}

# 6. Servizi: nuovi, o con StartMode/account di esecuzione cambiati
$so = Load-Csv $Old 'servizi.csv'; $sn = Load-Csv $New 'servizi.csv'
if($null -ne $so -and $null -ne $sn){
    $oldBy=@{}; $so | ForEach-Object { $oldBy[$_.Name]=$_ }
    foreach($s in $sn){
        if(-not $oldBy.ContainsKey($s.Name)){
            Add-Alert 'SERVIZI' "nuovo servizio: $($s.Name) ($($s.DisplayName)) StartMode=$($s.StartMode) Account=$($s.StartName)"
        } else {
            $prev=$oldBy[$s.Name]
            if($prev.StartMode -ne $s.StartMode){ Add-Alert 'SERVIZI' "$($s.Name): StartMode $($prev.StartMode) -> $($s.StartMode)" }
            if($prev.StartName -ne $s.StartName){ Add-Alert 'SERVIZI' "$($s.Name): account di esecuzione $($prev.StartName) -> $($s.StartName)" }
        }
    }
}

# 7. Nuovi driver non firmati (prima colonna = nome dispositivo, nomi localizzati)
$do2 = Load-Csv $Old 'driver_non_firmati.csv'; $dn2 = Load-Csv $New 'driver_non_firmati.csv'
if($null -ne $do2 -and $null -ne $dn2 -and @($dn2).Count -gt 0){
    $col = @(@($dn2)[0].PSObject.Properties.Name)[0]
    $namesO = @($do2 | ForEach-Object { $_.$col })
    foreach($d in $dn2){ if($d.$col -notin $namesO){ Add-Alert 'DRIVER' "nuovo driver NON firmato: $($d.$col)" } }
}

# 8. Postura hardware/OS: ogni valore cambiato e' un alert (esclusi i conteggi hotfix)
function Load-Post([string]$dir){
    $p = Join-Path $dir 'sicurezza_postura.txt'
    if(-not (Test-Path $p)){ return $null }
    $h=@{}
    Get-Content $p | ForEach-Object { if($_ -match '^(.+?)\s*:\s*(.*)$'){ $h[$matches[1].Trim()]=$matches[2].Trim() } }
    $h
}
$ppo = Load-Post $Old; $ppn = Load-Post $New
if($null -ne $ppo -and $null -ne $ppn){
    foreach($k in $ppn.Keys){
        if($k -like 'Hotfix*'){ continue }
        if($ppo.ContainsKey($k) -and $ppo[$k] -ne $ppn[$k]){ Add-Alert 'POSTURA' "$($k): '$($ppo[$k])' -> '$($ppn[$k])'" }
    }
}

# 9. Defender: nuove esclusioni (vettore classico di accecamento dell'AV) e ASR indebolite
$exo = Load-Csv $Old 'defender_esclusioni.csv'; $exn = Load-Csv $New 'defender_esclusioni.csv'
if($null -ne $exo -and $null -ne $exn){
    $keyO = @($exo | ForEach-Object { "$($_.Tipo)|$($_.Valore)" })
    foreach($e in $exn){ if("$($e.Tipo)|$($e.Valore)" -notin $keyO){ Add-Alert 'DEFENDER' "NUOVA esclusione $($e.Tipo): $($e.Valore)" } }
}
$asro = Load-Csv $Old 'defender_asr.csv'; $asrn = Load-Csv $New 'defender_asr.csv'
if($null -ne $asro -and $null -ne $asrn){
    $oldBy=@{}; $asro | ForEach-Object { $oldBy[$_.Regola]=$_.Azione }
    foreach($r in $asrn){
        if($oldBy.ContainsKey($r.Regola) -and $oldBy[$r.Regola] -eq '1' -and $r.Azione -ne '1'){
            Add-Alert 'DEFENDER' "regola ASR indebolita: $($r.Regola) da Blocca(1) ad Azione=$($r.Azione)"
        }
    }
    foreach($k in $oldBy.Keys){
        if($oldBy[$k] -eq '1' -and $k -notin @($asrn.Regola)){ Add-Alert 'DEFENDER' "regola ASR rimossa (era Blocca): $k" }
    }
}

# 10. Firewall: nuove regole inbound consentite e attive
$fwo = Load-Csv $Old 'firewall_regole_inbound_allow.csv'; $fwn = Load-Csv $New 'firewall_regole_inbound_allow.csv'
if($null -ne $fwo -and $null -ne $fwn){
    foreach($r in $fwn){
        if($r.Nome -notin @($fwo.Nome)){
            Add-Alert 'FIREWALL' "nuova regola inbound consentita: $($r.NomeVisualizzato) [$($r.Programma) $($r.Porta) profilo=$($r.Profilo)]"
        }
    }
}

# 11. Catena di fiducia: nuove root CA (criticita' alta), nuovi Trusted Publishers, hosts modificato
$rco = Load-Csv $Old 'cert_root_ca.csv'; $rcn = Load-Csv $New 'cert_root_ca.csv'
if($null -ne $rco -and $null -ne $rcn){
    foreach($c in $rcn){ if($c.Thumbprint -notin @($rco.Thumbprint)){ Add-Alert 'TRUST' "NUOVA root CA di macchina: $($c.Subject) [$($c.Thumbprint)]" } }
}
$tpo = Load-Csv $Old 'cert_trusted_publishers.csv'; $tpn = Load-Csv $New 'cert_trusted_publishers.csv'
if($null -ne $tpo -and $null -ne $tpn){
    foreach($c in $tpn){ if($c.Thumbprint -notin @($tpo.Thumbprint)){ Add-Alert 'TRUST' "nuovo Trusted Publisher: $($c.Subject)" } }
}
$ho = Join-Path $Old 'hosts.txt'; $hn = Join-Path $New 'hosts.txt'
if((Test-Path $ho) -and (Test-Path $hn)){
    if((Get-FileHash $ho).Hash -ne (Get-FileHash $hn).Hash){
        Add-Alert 'TRUST' 'file hosts MODIFICATO (possibile dirottamento DNS locale): confronta i due hosts.txt'
    }
}

# 12. Nuove estensioni browser (per ogni account fotografato con -Scope User)
Get-ChildItem (Join-Path $New 'utenti') -Filter '_browser_estensioni_*.csv' -ErrorAction SilentlyContinue | ForEach-Object {
    $oldF = Join-Path (Join-Path $Old 'utenti') $_.Name
    if(Test-Path $oldF){
        $bo = @(Import-Csv $oldF); $bn = @(Import-Csv $_.FullName)
        $keyO = @($bo | ForEach-Object { "$($_.Browser)|$($_.ProfiloBrowser)|$($_.Id)" })
        foreach($e in $bn){
            if("$($e.Browser)|$($e.ProfiloBrowser)|$($e.Id)" -notin $keyO){
                Add-Alert 'BROWSER' "nuova estensione $($e.Browser): $($e.Nome) [$($e.Id)]"
            }
        }
    }
}

# 13. Hardware: salute dischi, nuovo disco USB di massa (esfiltrazione), cambi RAM
$hdo = Load-Csv $Old 'hardware_dischi.csv'; $hdn = Load-Csv $New 'hardware_dischi.csv'
if($null -ne $hdo -and $null -ne $hdn){
    foreach($d in $hdn){
        if($d.Salute -and $d.Salute -ne 'Healthy'){ Add-Alert 'HARDWARE' "disco con salute NON ottimale: $($d.Modello) -> $($d.Salute)/$($d.Stato)" }
        $key = "$($d.Modello)|$($d.Numero)"
        if($key -notin @($hdo | ForEach-Object { "$($_.Modello)|$($_.Numero)" })){
            if($d.Bus -eq 'USB'){ Add-Alert 'HARDWARE' "NUOVO disco USB di massa collegato: $($d.Modello) $($d.CapacitaGB)GB (possibile vettore di esfiltrazione/ingresso dati)" }
            else { Add-Alert 'HARDWARE' "nuovo disco: $($d.Modello) $($d.CapacitaGB)GB [$($d.Bus)]" }
        }
    }
    $totO = ($hdo | Measure-Object).Count; $totN = ($hdn | Measure-Object).Count
}
$hro = Load-Csv $Old 'hardware_ram.csv'; $hrn = Load-Csv $New 'hardware_ram.csv'
if($null -ne $hro -and $null -ne $hrn){
    $sumO = ($hro | Measure-Object CapacitaGB -Sum).Sum; $sumN = ($hrn | Measure-Object CapacitaGB -Sum).Sum
    if($sumO -ne $sumN){ Add-Alert 'HARDWARE' "RAM totale cambiata: $sumO GB -> $sumN GB" }
}

# 13b. Licenza Windows: cambio di stato attivazione (es. da Licenziato a grazia/non attivato)
$lwo = Load-Csv $Old 'licenza_windows.csv'; $lwn = Load-Csv $New 'licenza_windows.csv'
if($null -ne $lwo -and $null -ne $lwn){
    $so = ($lwo | Select-Object -First 1).Stato; $sn = ($lwn | Select-Object -First 1).Stato
    if($so -and $sn -and $so -ne $sn){ Add-Alert 'LICENZA' "stato attivazione Windows cambiato: '$so' -> '$sn'" }
    $co = ($lwo | Select-Object -First 1).Canale; $cn = ($lwn | Select-Object -First 1).Canale
    if($co -and $cn -and $co -ne $cn){ Add-Alert 'LICENZA' "canale licenza cambiato: '$co' -> '$cn'" }
}

# 14. Servizi con percorso non quotato comparsi dopo
$qo = Load-Csv $Old 'servizi_percorsi_non_quotati.csv'; $qn = Load-Csv $New 'servizi_percorsi_non_quotati.csv'
if($null -ne $qo -and $null -ne $qn){
    foreach($s in $qn){ if($s.Name -notin @($qo.Name)){ Add-Alert 'SERVIZI' "nuovo servizio con percorso non quotato: $($s.Name) -> $($s.PathName)" } }
}

Write-Host ''
Write-Host '=== ALERT DI SICUREZZA ===' -ForegroundColor Yellow
if($alerts.Count -eq 0){
    Write-Host '   nessun alert: nessuna variazione critica rilevata tra i due snapshot.' -ForegroundColor Green
} else {
    $alerts | ForEach-Object { Write-Host "   ! $_" -ForegroundColor Red }
    Write-Host ''
    Write-Host "   Totale: $($alerts.Count) alert. Verifica ogni voce prima di considerarla legittima." -ForegroundColor Yellow
}
