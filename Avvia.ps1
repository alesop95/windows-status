<#
================================================================================
 Avvia.ps1  —  Punto d'ingresso unico e standardizzato di windows-status
================================================================================
 SCOPO
   Clonata la repo su una QUALSIASI macchina Windows 11, questo è il comando unico
   da cui partire: presenta un menu che guida tra fotografia, confronto, baseline
   di sicurezza, debloating e reinstallazione, in modo uniforme su ogni PC.

   Non implementa logica propria: orchestra gli script in scripts\. Le operazioni
   di sola lettura sono sempre sicure; quelle che MODIFICANO il sistema avvisano e
   restano a conferma esplicita (paletti del progetto).

 USO
   .\Avvia.ps1            # menu interattivo
   .\Avvia.ps1 -Help      # elenca le voci senza entrare nel menu (per script/CI)

 NOTA
   Per i dati completi (BitLocker, Secure Boot, TPM, Defender, altri account) lo
   snapshot va eseguito da PowerShell AMMINISTRATORE.
================================================================================
#>
param([switch]$Help)

$base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Join-Path $base 'scripts'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$voci = @(
  @{ N='1'; Titolo='Fotografa lo stato (snapshot completo)';      Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Snapshot-Stato.ps1') } }
  @{ N='2'; Titolo='Confronta i due snapshot piu recenti';        Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Compare-Snapshot.ps1') } }
  @{ N='3'; Titolo='Report baseline di sicurezza (divario)';      Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Allinea-BestPractice.ps1') } }
  @{ N='4'; Titolo='Applica baseline di sicurezza (guidato)';     Tipo='MODIFICA';          Azione={ & (Join-Path $scripts 'Allinea-BestPractice.ps1') -Apply } }
  @{ N='5'; Titolo='Reinstalla software da winget export';        Tipo='MODIFICA';          Azione={ & (Join-Path $scripts 'Reinstall-Software.ps1') } }
)

function Show-Menu {
    Write-Host ''
    Write-Host '==================================================================' -ForegroundColor Cyan
    Write-Host ' windows-status  —  avvio standardizzato' -ForegroundColor Cyan
    Write-Host '==================================================================' -ForegroundColor Cyan
    Write-Host ("Elevato (admin): {0}" -f $isAdmin) -NoNewline
    if(-not $isAdmin){ Write-Host '   (per snapshot completo e baseline servono i diritti admin)' -ForegroundColor Yellow } else { Write-Host '' }
    Write-Host ''
    foreach($v in $voci){
        $col = if($v.Tipo -eq 'MODIFICA'){ 'Yellow' } else { 'Green' }
        Write-Host ("  {0})  {1}" -f $v.N, $v.Titolo) -NoNewline
        Write-Host ("   [{0}]" -f $v.Tipo) -ForegroundColor $col
    }
    Write-Host '  0)  Esci'
    Write-Host ''
    Write-Host 'Promemoria: le voci [MODIFICA] richiedono paracadute (immagine Veeam + punto di ripristino),' -ForegroundColor Yellow
    Write-Host 'si applicano una categoria alla volta con verifica, e vanno a changelog nella mappa.' -ForegroundColor Yellow
    Write-Host 'Debloating: vedi docs\00 (PowerShell mirato vs Winhance/Winslop, §7) e il piano in context\current-work.md.'
}

if($Help){
    Write-Host 'Voci disponibili (windows-status\Avvia.ps1):'
    foreach($v in $voci){ Write-Host ("  {0})  {1}  [{2}]" -f $v.N, $v.Titolo, $v.Tipo) }
    Write-Host '  0)  Esci'
    return
}

# All'avvio: scelta esplicita dell'approccio di ottimizzazione (coerente con docs\00 §7)
Write-Host ''
Write-Host 'Approccio agli interventi di ottimizzazione/hardening su questa macchina:' -ForegroundColor Cyan
Write-Host '  - PowerShell mirato (predefinito): trasparente, reversibile, versionabile (Allinea-BestPractice, Remove-AppxPackage).'
Write-Host '  - Strumenti esterni (Winhance/Winslop): solo da fonte ufficiale, in modalita inspect, SEMPRE tra due snapshot (vedi docs\00 §7).'
Write-Host 'La scelta si fa al momento di ogni intervento; questo menu usa la via PowerShell mirato.'

do {
    Show-Menu
    $scelta = Read-Host 'Scegli una voce'
    $v = $voci | Where-Object N -eq $scelta
    if($scelta -eq '0'){ break }
    elseif($v){
        if($v.Tipo -eq 'MODIFICA'){
            Write-Host ''
            Write-Host "Stai per eseguire un'azione che MODIFICA il sistema: $($v.Titolo)" -ForegroundColor Yellow
            $ok = Read-Host 'Hai un backup immagine recente e un punto di ripristino? Procedo? (s/N)'
            if($ok -notmatch '^[sS]'){ Write-Host 'Annullato.'; continue }
        }
        & $v.Azione
        Write-Host ''
        Read-Host 'Premi Invio per tornare al menu' | Out-Null
    } else { Write-Host 'Scelta non valida.' -ForegroundColor Red }
} while($true)

Write-Host 'Uscita. Ricorda: git add/commit/push restano manuali; verifica niente segreti prima di un push.'
