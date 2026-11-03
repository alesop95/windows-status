<#
.SYNOPSIS
    Tiene aperto il canale verso il server di inferenza con GPU, a livello di macchina.

.DESCRIPTION
    L'inferenza locale gira su un host separato raggiunto via SSH con inoltro di porta. Finche'
    quel canale e' stato aperto a mano dentro una sessione di lavoro, e' vissuto quanto la
    sessione: chiudendo la finestra il lavoro a lotti si fermava, e nessun altro progetto della
    macchina poteva usare la GPU perche' la porta locale non esisteva. Il canale non appartiene
    a un progetto, appartiene alla macchina, esattamente come una stampante o una unita' di rete.

    Questo script lo rende tale. -Avvia lo apre se non c'e' gia', ed e' idempotente, quindi un
    progetto puo' chiamarlo a ogni apertura di sessione senza sapere se sia gia' aperto.
    -Installa registra una attivita' pianificata che lo apre al logon e lo risorveglia, cosi'
    sopravvive alla chiusura di ogni sessione e al riavvio della macchina.

    L'attivita' gira come l'utente che la installa, non come SYSTEM, e la ragione e' vincolante:
    il canale si autentica con la chiave SSH e con l'alias dichiarati nel profilo di quell'utente,
    che SYSTEM non ha. Un canale installato come SYSTEM si registra senza errore e poi non si
    apre mai.

.PARAMETER Stato
    Dice se il canale e' aperto e se il server risponde. Sola lettura, nessuna modifica.

.PARAMETER Avvia
    Apre il canale se non e' gia' aperto. Idempotente: se risponde gia', non fa nulla.

.PARAMETER Chiudi
    Chiude il canale aperto da questo script, lasciando intatta l'attivita' pianificata.

.PARAMETER Installa
    Registra l'attivita' pianificata al logon dell'utente corrente.

.PARAMETER Disinstalla
    Rimuove l'attivita' pianificata. Non chiude un canale gia' aperto.

.PARAMETER Sorveglia
    Uso interno dell'attivita' pianificata: riapre il canale ogni volta che cade.

.EXAMPLE
    .\scripts\Canale-GPU.ps1 -Stato
    .\scripts\Canale-GPU.ps1 -Avvia
    .\scripts\Canale-GPU.ps1 -Installa
#>
[CmdletBinding()]
param(
    [switch]$Stato,
    [switch]$Avvia,
    [switch]$Chiudi,
    [switch]$Installa,
    [switch]$Disinstalla,
    [switch]$Sorveglia,
    [string]$Alias        = 'gpu-ollama',
    [int]$PortaLocale     = 11502,
    [int]$PortaRemota     = 11500,
    [int]$AttesaSecondi   = 20
)

$ErrorActionPreference = 'Stop'
$me       = $MyInvocation.MyCommand.Path
$taskName = 'windows-status - Canale GPU inferenza'
$logDir   = Join-Path (Split-Path (Split-Path $me -Parent) -Parent) '_notes\canale-gpu'

function Test-Canale {
    param([int]$Porta)
    # Non basta che la porta sia in ascolto: un canale puo' restare aperto verso un servizio
    # morto, e un inoltro SSH accetta la connessione locale prima di sapere se l'altro capo
    # risponda. Si interroga percio' il servizio, non il socket.
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Porta/api/tags" -TimeoutSec 5 -UseBasicParsing
        return ($r.StatusCode -eq 200)
    } catch { return $false }
}

function Get-ProcessiCanale {
    param([int]$Porta)
    Get-CimInstance Win32_Process -Filter "Name = 'ssh.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match "$Porta`:127\.0\.0\.1" }
}

function Show-Stato {
    param([int]$Porta)
    $vivo  = Test-Canale -Porta $Porta
    $proc  = @(Get-ProcessiCanale -Porta $Porta)
    if ($vivo) {
        Write-Host "Canale APERTO su 127.0.0.1:$Porta, il server risponde." -ForegroundColor Green
    } elseif ($proc.Count -gt 0) {
        Write-Host "Canale presente ma il server NON risponde: $($proc.Count) processo ssh in piedi." -ForegroundColor Yellow
        Write-Host '  Probabile causa: il servizio sull''altro capo e'' fermo, oppure la porta remota e'' sbagliata.'
    } else {
        Write-Host "Canale CHIUSO: niente in ascolto su 127.0.0.1:$Porta." -ForegroundColor Red
    }
    $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($t) {
        $info = $t | Get-ScheduledTaskInfo
        Write-Host "Attivita' pianificata: presente, stato $($t.State), ultimo avvio $($info.LastRunTime)."
    } else {
        Write-Host "Attivita' pianificata: assente. Si installa con: .\scripts\Canale-GPU.ps1 -Installa"
    }
    return $vivo
}

function Start-Canale {
    param([int]$Porta, [int]$Remota, [string]$Alias, [int]$Attesa)
    if (Test-Canale -Porta $Porta) {
        Write-Host "Canale gia' aperto su 127.0.0.1:$Porta." -ForegroundColor Green
        return $true
    }
    # Un processo ssh rimasto senza l'altro capo tiene la porta e impedisce al nuovo di aprirla,
    # e con -o ExitOnForwardFailure il nuovo muore in silenzio: il vecchio va chiuso prima.
    foreach ($p in @(Get-ProcessiCanale -Porta $Porta)) {
        Write-Host "Chiudo un canale precedente rimasto aperto (PID $($p.ProcessId))."
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $argomenti = @(
        '-N',
        '-L', "$Porta`:127.0.0.1:$Remota",
        '-o', 'ExitOnForwardFailure=yes',
        '-o', 'ServerAliveInterval=30',
        '-o', 'ServerAliveCountMax=3',
        '-o', 'BatchMode=yes',
        $Alias
    )
    Start-Process -FilePath 'ssh.exe' -ArgumentList $argomenti -WindowStyle Hidden `
        -RedirectStandardError (Join-Path $logDir 'ssh-errori.log') | Out-Null
    for ($i = 0; $i -lt $Attesa; $i++) {
        Start-Sleep -Seconds 1
        if (Test-Canale -Porta $Porta) {
            Write-Host "Canale APERTO su 127.0.0.1:$Porta dopo $($i + 1) secondi." -ForegroundColor Green
            return $true
        }
    }
    Write-Host "Il canale non si e'' aperto entro $Attesa secondi." -ForegroundColor Red
    Write-Host "  Errori in: $logDir\ssh-errori.log"
    Write-Host "  Da verificare a mano: ssh -o BatchMode=yes $Alias hostname"
    return $false
}

function Stop-Canale {
    param([int]$Porta)
    $proc = @(Get-ProcessiCanale -Porta $Porta)
    if ($proc.Count -eq 0) { Write-Host 'Nessun canale da chiudere.'; return }
    foreach ($p in $proc) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "Chiuso il canale con PID $($p.ProcessId)."
    }
}

# ----------------------------------------------------------------------------
#  Azioni
# ----------------------------------------------------------------------------

if ($Stato)   { $ok = Show-Stato -Porta $PortaLocale; if ($ok) { exit 0 } else { exit 1 } }
if ($Chiudi)  { Stop-Canale -Porta $PortaLocale; exit 0 }

if ($Avvia) {
    $ok = Start-Canale -Porta $PortaLocale -Remota $PortaRemota -Alias $Alias -Attesa $AttesaSecondi
    if ($ok) { exit 0 } else { exit 1 }
}

if ($Sorveglia) {
    # Ciclo dell'attivita' pianificata. Non termina da se': se il canale cade lo riapre, con
    # una attesa crescente fino a cinque minuti, perche' riprovare ogni secondo contro un host
    # spento riempie il registro e non apre niente.
    $attesa = 10
    while ($true) {
        if (-not (Test-Canale -Porta $PortaLocale)) {
            $ok = Start-Canale -Porta $PortaLocale -Remota $PortaRemota -Alias $Alias -Attesa $AttesaSecondi
            if ($ok) { $attesa = 10 } else { $attesa = [Math]::Min($attesa * 2, 300) }
        } else {
            $attesa = 10
        }
        Start-Sleep -Seconds $attesa
    }
}

if ($Installa) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$me`" -Sorveglia -Alias $Alias -PortaLocale $PortaLocale -PortaRemota $PortaRemota"
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    # Come l'utente, non come SYSTEM: la chiave SSH e l'alias vivono nel suo profilo.
    $princ   = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    $set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew `
                   -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $princ -Settings $set `
        -Description "Tiene aperto l'inoltro SSH verso il server di inferenza con GPU, sulla porta locale $PortaLocale. Reversibile: Canale-GPU.ps1 -Disinstalla." -Force | Out-Null
    Write-Host "Attivita' '$taskName' INSTALLATA, al logon di $env:USERNAME." -ForegroundColor Green
    Write-Host 'Reversibile con: .\scripts\Canale-GPU.ps1 -Disinstalla'
    Write-Host 'Il canale si apre anche subito con: .\scripts\Canale-GPU.ps1 -Avvia'
    exit 0
}

if ($Disinstalla) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Attivita' '$taskName' RIMOSSA." -ForegroundColor Green
        Write-Host 'Un canale gia'' aperto resta aperto: si chiude con -Chiudi.'
    } else {
        Write-Host "Attivita' '$taskName' non presente."
    }
    exit 0
}

Get-Help $me -Detailed
