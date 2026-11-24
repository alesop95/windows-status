# =============================================================================
#  Scorciatoia-TerminaleAdmin.ps1  -  Ctrl+Alt+Q apre PowerShell da amministratore
#  windows-status.
# =============================================================================
#  COSA FA. Ctrl+Alt+Q apre Windows Terminal con PowerShell da amministratore,
#  senza la conferma del Controllo dell'account utente, per ogni utente del
#  gruppo Amministratori di questo PC. Scelta del proprietario del 2026-11-24.
#
#  COME. Windows assegna tasti solo ai collegamenti del menu Start e del Desktop,
#  e solo nella forma Ctrl+Alt+tasto: Ctrl+Q da solo richiederebbe un programma
#  residente e lo toglierebbe a tutte le applicazioni. L'elevazione senza
#  conferma la da' un'attivita' pianificata con i privilegi piu' alti, una per
#  ogni utente del gruppo Amministratori (SID S-1-5-32-544), chiamata
#  TerminaleAdmin-<utente> e lanciabile solo da quell'utente. Un'attivita' unica
#  intestata al gruppo non funziona: il tasto parte dal token non elevato
#  dell'utente, e Windows gli nega di lanciarla (provato il 2026-11-24). Il
#  collegamento, nel menu Start comune a tutti gli utenti, lancia l'attivita'
#  dell'utente collegato dentro una console invisibile (conhost --headless), cosi'
#  a video compare solo il terminale. Un utente che non e' amministratore non ha
#  un'attivita': per lui il tasto non apre niente. Un amministratore aggiunto dopo
#  richiede di rilanciare -Applica.
#
#  PREZZO ACCETTATO. Qualunque programma che gira con un utente amministratore
#  puo' aprire questo terminale elevato senza conferma; Windows impedisce pero' a
#  un processo non elevato di scrivere dentro quella finestra.
#
#  USO (da un terminale amministratore, per -Applica e -Rimuovi)
#    .\Scorciatoia-TerminaleAdmin.ps1            # dice che cosa farebbe (sola lettura)
#    .\Scorciatoia-TerminaleAdmin.ps1 -Applica   # crea o aggiorna attivita' e collegamento
#    .\Scorciatoia-TerminaleAdmin.ps1 -Rimuovi   # toglie tutto
#
#  COME SI ANNULLA: -Rimuovi.
# =============================================================================
[CmdletBinding()]
param(
    [switch]$Applica,
    [switch]$Rimuovi
)
$ErrorActionPreference = 'Stop'

$LnkComune = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Terminale (Admin).lnk'
$LnkUtente = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Terminale (Admin).lnk'
$Conhost   = Join-Path $env:WINDIR 'System32\conhost.exe'
$Cmd       = Join-Path $env:WINDIR 'System32\cmd.exe'
$Schtasks  = Join-Path $env:WINDIR 'System32\schtasks.exe'
$Tasto     = 'CTRL+ALT+Q'
$Cartella  = '\windows-status\'
$Prefisso  = 'TerminaleAdmin'
# Il percorso di Windows Terminal e' per utente: l'attivita' lo scrive con la
# variabile, che Utilita' di pianificazione espande per l'utente che la lancia.
$WtVariabile = '%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe'

function Test-Amministratore {
    $Id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $Id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-Attivita {
    Get-ScheduledTask -TaskPath $Cartella -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like "$Prefisso*" }
}
# Utenti (non gruppi) del gruppo Amministratori, locali e del tenant.
function Get-Amministratori {
    Get-LocalGroupMember -SID 'S-1-5-32-544' | Where-Object { "$($_.ObjectClass)" -in @('User', 'Utente') }
}
function Get-NomeBreve { param($Nome) ($Nome -split '\\')[-1] }

if (-not $Applica -and -not $Rimuovi) {
    foreach ($U in Get-Amministratori) { Write-Host "  [info] attivita' $Cartella$Prefisso-$(Get-NomeBreve $U.Name) per $($U.Name)" }
    Write-Host "  [info] collegamento $LnkComune, tasto $Tasto"
    Get-Attivita | ForEach-Object { Write-Host "  [info] esiste gia': $($_.TaskName)" }
    return
}
if (-not (Test-Amministratore)) { throw "va lanciato da un terminale amministratore" }

if (Test-Path $LnkUtente) { Remove-Item $LnkUtente }
Get-Attivita | ForEach-Object { Unregister-ScheduledTask -TaskPath $Cartella -TaskName $_.TaskName -Confirm:$false }

if ($Rimuovi) {
    if (Test-Path $LnkComune) { Remove-Item $LnkComune }
    Write-Host "  [ok]   collegamento e attivita' tolti"
    return
}

$Servizio = New-Object -ComObject Schedule.Service
$Servizio.Connect()
$Azione = New-ScheduledTaskAction -Execute $WtVariabile -Argument 'powershell.exe -NoLogo' -WorkingDirectory '%USERPROFILE%'
$Regole = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances Parallel
foreach ($U in Get-Amministratori) {
    $Nome = "$Prefisso-$(Get-NomeBreve $U.Name)"
    $Sid  = $U.SID.Value
    $Chi  = New-ScheduledTaskPrincipal -UserId $Sid -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskPath $Cartella -TaskName $Nome -Action $Azione -Principal $Chi -Settings $Regole -Description "Ctrl+Alt+Q: PowerShell da amministratore senza conferma per $($U.Name), windows-status" -Force | Out-Null
    # Leggerla e lanciarla: quell'utente, gli amministratori elevati e il sistema.
    $Servizio.GetFolder($Cartella.TrimEnd('\')).GetTask($Nome).SetSecurityDescriptor("D:(A;;FA;;;BA)(A;;FA;;;SY)(A;;GRGX;;;$Sid)", 0)
}

$Shell = New-Object -ComObject WScript.Shell
$S = $Shell.CreateShortcut($LnkComune)
$S.TargetPath   = $Conhost
$S.Arguments    = "--headless $Cmd /c $Schtasks /run /tn `"$Cartella$Prefisso-%USERNAME%`""
$S.Hotkey       = $Tasto
$S.WindowStyle  = 7
$S.IconLocation = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe,0"
$S.Description  = 'Ctrl+Alt+Q: PowerShell da amministratore - windows-status'
$S.Save()

# Verifica su cio' che e' stato scritto.
Get-Attivita | ForEach-Object { Write-Host "  [ok]   attivita' $($_.TaskName), utente $($_.Principal.UserId), livello $($_.Principal.RunLevel)" }
Write-Host "  [ok]   collegamento $LnkComune, tasto $($Shell.CreateShortcut($LnkComune).Hotkey)"
Write-Host "  Se Ctrl+Alt+Q non risponde subito, Esplora risorse registra il tasto al prossimo accesso."
