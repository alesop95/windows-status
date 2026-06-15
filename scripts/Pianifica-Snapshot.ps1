<#
================================================================================
 Pianifica-Snapshot.ps1  —  Snapshot periodico (opt-in) per il rilevamento drift
================================================================================
 SCOPO
   Crea (su richiesta) un'attivita pianificata che esegue Snapshot-Stato.ps1 a
   intervalli regolari, come SYSTEM, cosi nel tempo il confronto tra snapshot fa
   emergere il drift della macchina. Lo snapshot e di SOLA LETTURA; l'unica cosa
   che modifica il sistema e' la CREAZIONE/RIMOZIONE dell'attivita pianificata.

 FILOSOFIA
   - Di default mostra solo lo STATO (sola lettura, sicuro).
   - -Installa crea l'attivita (serve admin): e' una modifica, reversibile con -Disinstalla.
   - L'attivita gira come SYSTEM con privilegi elevati per avere dati completi.

 USO
   .\Pianifica-Snapshot.ps1                                  # stato (sola lettura)
   .\Pianifica-Snapshot.ps1 -Installa                        # settimanale, lunedi 12:30 (admin)
   .\Pianifica-Snapshot.ps1 -Installa -Frequenza Giornaliera -Ora 13:00
   .\Pianifica-Snapshot.ps1 -Disinstalla                     # rimuove l'attivita (admin)

 NOTA
   Gli snapshot si accumulano in snapshots\ (ignorata da git): ripulire ogni tanto
   le cartelle vecchie. Confrontare snapshot omogenei (l'attivita gira sempre elevata).
================================================================================
#>
param(
    [switch]$Installa,
    [switch]$Disinstalla,
    [ValidateSet('Settimanale','Giornaliera')][string]$Frequenza='Settimanale',
    [string]$Ora='12:30'
)

$base     = Split-Path -Parent $MyInvocation.MyCommand.Path
$snap     = Join-Path $base 'Snapshot-Stato.ps1'
$taskName = 'windows-status Snapshot periodico'
$isAdmin  = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Mostra-Stato {
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if($t){
        $info = $t | Get-ScheduledTaskInfo
        Write-Host "Snapshot periodico: INSTALLATO" -ForegroundColor Green
        Write-Host "  Stato      : $($t.State)"
        Write-Host "  Prossima   : $($info.NextRunTime)"
        Write-Host "  Ultima     : $($info.LastRunTime) (risultato $($info.LastTaskResult))"
    } else {
        Write-Host "Snapshot periodico: NON installato." -ForegroundColor Yellow
        Write-Host "  Per attivarlo (admin): .\Pianifica-Snapshot.ps1 -Installa"
    }
}

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
    if(-not (Test-Path $snap)){ Write-Host "Snapshot-Stato.ps1 non trovato in $base" -ForegroundColor Red; return }
    try {
        $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$snap`""
        $trigger = if($Frequenza -eq 'Giornaliera'){ New-ScheduledTaskTrigger -Daily -At $Ora } else { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $Ora }
        $princ   = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
        $set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $princ -Settings $set `
            -Description 'Snapshot periodico di windows-status (sola lettura) per il rilevamento del drift. Reversibile: Pianifica-Snapshot.ps1 -Disinstalla.' -Force | Out-Null
        Write-Host "Attivita '$taskName' INSTALLATA ($Frequenza, ore $Ora, come SYSTEM)." -ForegroundColor Green
        Write-Host 'Reversibile con: .\Pianifica-Snapshot.ps1 -Disinstalla'
        Write-Host 'Ricorda: gli snapshot si accumulano in snapshots\ (ripulire le cartelle vecchie ogni tanto).'
    } catch { Write-Host "Errore nella creazione dell'attivita: $_" -ForegroundColor Red }
    return
}

# Default: solo stato (sola lettura)
Mostra-Stato
