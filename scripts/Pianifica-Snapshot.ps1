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
   .\Pianifica-Snapshot.ps1 -Installa -Frequenza Giornaliera -Ora 13:00 -Retention 14
   .\Pianifica-Snapshot.ps1 -Installa -Frequenza Mensile -GiornoMese 1 -Ora 09:00
   .\Pianifica-Snapshot.ps1 -Disinstalla                     # rimuove l'attivita (admin)

 NOTA
   La task gira come SYSTEM con -Scope Machine (sezioni 1-12: la 13, ambiente live
   dell'account, da SYSTEM sarebbe falsata) e con -Retention (default 7) tiene solo gli
   ultimi N snapshot in snapshots\ (ignorata da git). Confrontare snapshot omogenei.
================================================================================
#>
param(
    [switch]$Installa,
    [switch]$Disinstalla,
    [ValidateSet('Settimanale','Giornaliera','Mensile')][string]$Frequenza='Settimanale',
    [string]$Ora='12:30',
    # Giorno del mese per -Frequenza Mensile (1-28, per restare valido su tutti i mesi)
    [ValidateRange(1,28)][int]$GiornoMese=1,
    # Quanti snapshot piu recenti conservare ad ogni esecuzione (0 = tieni tutto).
    [int]$Retention=7
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
        # -Scope Machine: la task gira come SYSTEM, quindi la sezione 13 (ambiente di
        # sviluppo dell'account corrente) sarebbe quella di SYSTEM e falserebbe i diff.
        # Machine copre 1-12, incluso l'inventario multi-account letto dal disco, e tiene
        # le fotografie automatiche omogenee. -Retention applica la pulizia ad ogni run.
        $argSnap = "-NoProfile -ExecutionPolicy Bypass -File `"$snap`" -Scope Machine -Retention $Retention"
        $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argSnap
        $trigger = switch($Frequenza){
            'Giornaliera' { New-ScheduledTaskTrigger -Daily -At $Ora }
            'Mensile'     { New-ScheduledTaskTrigger -Monthly -DaysOfMonth $GiornoMese -At $Ora -Months @(1..12) }
            default       { New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $Ora }
        }
        $princ   = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
        $set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $princ -Settings $set `
            -Description 'Snapshot periodico di windows-status (sola lettura) per il rilevamento del drift. Reversibile: Pianifica-Snapshot.ps1 -Disinstalla.' -Force | Out-Null
        $freqLabel = if($Frequenza -eq 'Mensile'){ "$Frequenza, giorno $GiornoMese, ore $Ora" } else { "$Frequenza, ore $Ora" }
        Write-Host "Attivita '$taskName' INSTALLATA ($freqLabel, come SYSTEM, -Scope Machine, retention $Retention)." -ForegroundColor Green
        Write-Host 'Reversibile con: .\Pianifica-Snapshot.ps1 -Disinstalla'
        Write-Host "Gli snapshot vanno in snapshots\ (ignorata da git); la retention tiene gli ultimi $Retention."
    } catch { Write-Host "Errore nella creazione dell'attivita: $_" -ForegroundColor Red }
    return
}

# Default: solo stato (sola lettura)
Mostra-Stato
