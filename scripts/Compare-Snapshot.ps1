<#
================================================================================
 Compare-Snapshot.ps1 — Confronta due snapshot e mostra COSA E' CAMBIATO
================================================================================
 USO
   .\Compare-Snapshot.ps1                     # confronta i due snapshot piu recenti
   .\Compare-Snapshot.ps1 -Old <cartella> -New <cartella>

 Confronta gli elenchi chiave (software, servizi, avvio, app, account) e segnala
 le voci aggiunte (+) e rimosse (-). Di sola lettura.
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

$files = @{
    'Software (registro)'   = @{ file='software_registro.csv';      key='DisplayName' }
    'Servizi (StartMode)'   = @{ file='servizi.csv';                 key='Name' }
    'Avvio automatico'      = @{ file='avvio.csv';                   key='Name' }
    'App Windows (Appx)'    = @{ file='app_appx_allusers.csv';       key='Name' }
    'Account locali'        = @{ file='account_locali.csv';          key='Name' }
    'Attivita pianificate'  = @{ file='attivita_pianificate.csv';    key='TaskName' }
}

foreach($label in $files.Keys){
    $f=$files[$label].file; $k=$files[$label].key
    $po=Join-Path $Old $f; $pn=Join-Path $New $f
    if(-not (Test-Path $po) -or -not (Test-Path $pn)){ continue }
    $o=(Import-Csv $po).$k; $n=(Import-Csv $pn).$k
    $diff=Compare-Object $o $n
    Write-Host "== $label ==" -ForegroundColor Cyan
    if(-not $diff){ Write-Host '   nessuna differenza'; continue }
    $diff | ForEach-Object {
        if($_.SideIndicator -eq '=>'){ Write-Host "   + AGGIUNTO : $($_.InputObject)" -ForegroundColor Green }
        else                         { Write-Host "   - RIMOSSO  : $($_.InputObject)" -ForegroundColor Red }
    }
}
Write-Host "`nNota: per i servizi e mostrato solo il nome; i cambi di StartMode si vedono aprendo i due servizi.csv."
