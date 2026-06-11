<#
================================================================================
 Allinea-BestPractice.ps1  —  Allinea un PC Windows 11 al baseline di sicurezza
================================================================================
 SCOPO
   Porta una macchina (vergine o gia in uso) alle best practice di sicurezza
   emerse dall'analisi del progetto windows-status. Lavora a passi: legge lo
   stato attuale, mostra il DIVARIO rispetto al baseline, e applica le modifiche
   SOLO su richiesta esplicita, una alla volta, con possibilita di annullare.

 FILOSOFIA (coerente con i paletti del progetto)
   - DI DEFAULT NON MODIFICA NULLA: senza -Apply produce solo un report del divario.
   - Con -Apply, per OGNI controllo non conforme chiede conferma (s/N) prima di agire.
   - Ogni modifica e REVERSIBILE: il rollback e indicato e annotato nel log.
   - I controlli che richiedono admin vengono saltati se non sei elevato (lo dice).
   - NON tocca Windows Update, Defender, Office, Edge/WebView2, OneDrive, Intune.
   - Cio che non e automatizzabile in sicurezza (Secure Boot, BitLocker) e SOLO
     segnalato come avviso, mai forzato.

 USO
   # 1) REPORT del divario (sola lettura, sicuro ovunque):
   .\Allinea-BestPractice.ps1
   # 2) APPLICAZIONE guidata (da PowerShell AMMINISTRATORE, dopo backup Veeam + punto di ripristino):
   .\Allinea-BestPractice.ps1 -Apply
   # 3) Solo alcune categorie:
   .\Allinea-BestPractice.ps1 -Apply -Solo RDP-CACHE,PS-LOG

 PARACADUTE
   Prima di -Apply: assicurati di avere un'immagine Veeam recente e un punto di
   ripristino. Dopo ogni categoria applicata: riavvia se richiesto e verifica
   Outlook/Teams/OneDrive/VPN/SSO prima di proseguire. Per il debloating delle app
   consumer vedi il piano in docs/00 e context/current-work.md (operazione a parte).
================================================================================
#>
param(
    [switch]$Apply,
    [string[]]$Solo,
    [switch]$SenzaConferma
)

$ErrorActionPreference = 'Continue'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj    = Split-Path -Parent $base
$logDir  = Join-Path $proj 'snapshots'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$logFile = Join-Path $logDir ("allineamento_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".log")
$log = New-Object System.Collections.Generic.List[string]
function Write-Log([string]$m){ $log.Add("$(Get-Date -Format s)  $m") }

# Helper per leggere lo stato della cache bitmap RDP (utente)
function Get-RdpCacheState {
    $reg = (Get-ItemProperty 'HKCU:\Software\Microsoft\Terminal Server Client' -Name 'DisablePersistentCache' -ErrorAction SilentlyContinue).DisablePersistentCache
    $def = "$env:USERPROFILE\Documents\Default.rdp"
    $rdpOff = $false; $rdpPresent = $false
    if(Test-Path $def){ $c = Get-Content $def -Raw; $rdpPresent = $c -match 'bitmapcachepersistenable'; $rdpOff = $c -match 'bitmapcachepersistenable:i:0' }
    [pscustomobject]@{ RegOff = ($reg -eq 1); RdpOff = $rdpOff; RdpPresent = $rdpPresent }
}

# ============================================================================
#  BASELINE — elenco dichiarativo dei controlli
#  Ogni controllo: Id, Categoria, Titolo, Admin (serve elevazione), Rischio,
#  Test = { ritorna @{Conforme=[bool]; Stato=[string]} }, Apply = { applica },
#  Rollback = come si annulla, Avviso = $true se non automatizzabile (solo report)
# ============================================================================
$baseline = @(
  @{
    Id='RDP-CACHE'; Categoria='RDP'; Admin=$false; Rischio='Basso'
    Titolo='Disattivare la cache bitmap persistente del client RDP'
    Test={ $s=Get-RdpCacheState; @{ Conforme = ($s.RegOff -and ($s.RdpOff -or -not $s.RdpPresent)); Stato = "registro DisablePersistentCache off=$($s.RegOff), Default.rdp off=$($s.RdpOff)" } }
    Apply={
        New-ItemProperty -Path 'HKCU:\Software\Microsoft\Terminal Server Client' -Name 'DisablePersistentCache' -Value 1 -PropertyType DWord -Force | Out-Null
        $def="$env:USERPROFILE\Documents\Default.rdp"
        if(Test-Path $def){ (Get-Content $def -Raw).Replace('bitmapcachepersistenable:i:1','bitmapcachepersistenable:i:0') | Set-Content $def -Encoding Unicode }
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Terminal Server Client\Cache" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    Rollback='Rimettere DisablePersistentCache a 0 (o eliminarlo) e Default.rdp a bitmapcachepersistenable:i:1'
  },
  @{
    Id='SMB-SIGN'; Categoria='SMB'; Admin=$true; Rischio='Medio'
    Titolo='Richiedere la firma SMB (client e server)'
    Test={ $sv=(Get-SmbServerConfiguration -ErrorAction SilentlyContinue).RequireSecuritySignature; $cl=(Get-SmbClientConfiguration -ErrorAction SilentlyContinue).RequireSecuritySignature; @{ Conforme = ($sv -eq $true -and $cl -eq $true); Stato = "server=$sv client=$cl" } }
    Apply={ Set-SmbServerConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop; Set-SmbClientConfiguration -RequireSecuritySignature $true -Force -ErrorAction Stop }
    Rollback='Set-SmbServerConfiguration -RequireSecuritySignature $false -Force ; Set-SmbClientConfiguration -RequireSecuritySignature $false -Force'
    Note='Medio: dispositivi SMB legacy che non supportano la firma potrebbero non connettersi. Verifica i NAS/condivisioni dopo.'
  },
  @{
    Id='SMB1-OFF'; Categoria='SMB'; Admin=$true; Rischio='Basso'
    Titolo='Disattivare il protocollo SMBv1 (lato server)'
    Test={ $v=(Get-SmbServerConfiguration -ErrorAction SilentlyContinue).EnableSMB1Protocol; @{ Conforme = ($v -eq $false); Stato = "EnableSMB1Protocol=$v" } }
    Apply={ Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop }
    Rollback='Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force (sconsigliato)'
  },
  @{
    Id='PS-LOG'; Categoria='Logging'; Admin=$true; Rischio='Basso'
    Titolo='Abilitare il PowerShell Script Block Logging'
    Test={ $v=(Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name 'EnableScriptBlockLogging' -ErrorAction SilentlyContinue).EnableScriptBlockLogging; @{ Conforme = ($v -eq 1); Stato = $(if($null -ne $v){"EnableScriptBlockLogging=$v"}else{'non configurato'}) } }
    Apply={ New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Force | Out-Null; New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Name 'EnableScriptBlockLogging' -Value 1 -PropertyType DWord -Force | Out-Null }
    Rollback='Impostare EnableScriptBlockLogging a 0 o eliminare la chiave ScriptBlockLogging'
  },
  @{
    Id='LSA-PPL'; Categoria='Credenziali'; Admin=$true; Rischio='Medio'
    Titolo='Proteggere LSA come processo protetto (RunAsPPL)'
    Test={ $v=(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL' -ErrorAction SilentlyContinue).RunAsPPL; @{ Conforme = ($v -ge 1); Stato = $(if($null -ne $v){"RunAsPPL=$v"}else{'non impostato'}) } }
    Apply={ New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL' -Value 1 -PropertyType DWord -Force | Out-Null }
    Rollback='Eliminare il valore RunAsPPL (o impostarlo a 0); effettivo dopo riavvio'
    Note='Medio: effettivo dopo il riavvio; in rari casi blocca SSP/driver non firmati. Protegge contro il furto di credenziali (es. mimikatz).'
  },
  @{
    Id='SECUREBOOT'; Categoria='Avvio'; Admin=$false; Rischio='-'; Avviso=$true
    Titolo='Secure Boot attivo (UEFI)'
    Test={ $on=$null; try { $on=Confirm-SecureBootUEFI } catch {}; @{ Conforme = ($on -eq $true); Stato = $(if($null -ne $on){"SecureBoot=$on"}else{'non leggibile'}) } }
    Rollback='-'
    Note='Non automatizzabile: si attiva da firmware UEFI (richiede modalita UEFI, non Legacy/CSM).'
  },
  @{
    Id='BITLOCKER'; Categoria='Cifratura'; Admin=$true; Rischio='-'; Avviso=$true
    Titolo='BitLocker attivo sul volume di sistema'
    Test={ $st=$null; try { $st=(Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop).ProtectionStatus } catch {}; @{ Conforme = ("$st" -eq 'On'); Stato = $(if($null -ne $st){"ProtectionStatus=$st"}else{'non leggibile (serve admin)'}) } }
    Rollback='-'
    Note='Non auto-applicato: attivarlo e una decisione (richiede TPM pronto e custodia della chiave di ripristino). Vedi mappa.'
  }
)

# ============================================================================
#  ESECUZIONE
# ============================================================================
Write-Host ''
Write-Host '==================================================================' -ForegroundColor Cyan
Write-Host ' Allinea-BestPractice  —  ' -NoNewline -ForegroundColor Cyan
if($Apply){ Write-Host 'MODALITA APPLICAZIONE' -ForegroundColor Yellow } else { Write-Host 'MODALITA REPORT (sola lettura)' -ForegroundColor Green }
Write-Host '==================================================================' -ForegroundColor Cyan
Write-Host "Elevato (admin): $isAdmin"
if($Solo){ Write-Host "Filtro categorie/id: $($Solo -join ', ')" }
Write-Host ''

if($Apply -and -not $SenzaConferma){
    Write-Host 'ATTENZIONE: stai per MODIFICARE il sistema.' -ForegroundColor Yellow
    Write-Host 'Prerequisiti: immagine Veeam recente + punto di ripristino. Ogni modifica e reversibile e verra registrata in:'
    Write-Host "  $logFile"
    $go = Read-Host 'Procedo con la sessione guidata? (s/N)'
    if($go -notmatch '^[sS]'){ Write-Host 'Annullato. Nessuna modifica.' -ForegroundColor Green; return }
}

$items = $baseline | Where-Object { -not $Solo -or $_.Id -in $Solo -or $_.Categoria -in $Solo }
$report = New-Object System.Collections.Generic.List[object]

foreach($c in $items){
    $res = & $c.Test
    $stato = if($res.Conforme){ 'CONFORME' } elseif($c.Avviso){ 'DA VALUTARE (avviso)' } else { 'DA ALLINEARE' }
    $report.Add([pscustomobject]@{ Id=$c.Id; Categoria=$c.Categoria; Stato=$stato; Dettaglio=$res.Stato; Admin=$c.Admin; Rischio=$c.Rischio })

    if($Apply -and -not $res.Conforme -and -not $c.Avviso){
        Write-Host ''
        Write-Host "--- [$($c.Id)] $($c.Titolo)" -ForegroundColor White
        Write-Host "    Stato attuale : $($res.Stato)"
        Write-Host "    Rischio       : $($c.Rischio)"
        if($c.Note){ Write-Host "    Nota          : $($c.Note)" -ForegroundColor Yellow }
        Write-Host "    Rollback      : $($c.Rollback)"
        if($c.Admin -and -not $isAdmin){ Write-Host '    SALTATO: richiede PowerShell amministratore.' -ForegroundColor Red; Write-Log "SKIP $($c.Id): serve admin"; continue }
        $do = if($SenzaConferma){ 's' } else { Read-Host '    Applicare questa modifica? (s/N)' }
        if($do -match '^[sS]'){
            try {
                & $c.Apply
                $after = & $c.Test
                if($after.Conforme){ Write-Host "    OK applicato. Nuovo stato: $($after.Stato)" -ForegroundColor Green; Write-Log "APPLICATO $($c.Id): $($after.Stato)" }
                else { Write-Host "    Applicato ma ancora non conforme: $($after.Stato) (forse serve riavvio)" -ForegroundColor Yellow; Write-Log "APPLICATO-PARZIALE $($c.Id): $($after.Stato)" }
            } catch { Write-Host "    ERRORE durante l'applicazione: $_" -ForegroundColor Red; Write-Log "ERRORE $($c.Id): $_" }
        } else { Write-Host '    Saltato.'; Write-Log "SALTATO-UTENTE $($c.Id)" }
    }
}

Write-Host ''
Write-Host '=== DIVARIO RISPETTO AL BASELINE ===' -ForegroundColor Cyan
$report | Format-Table Id,Categoria,Stato,Dettaglio,Admin,Rischio -AutoSize | Out-String | Write-Host
$daAllineare = @($report | Where-Object Stato -eq 'DA ALLINEARE').Count
$daValutare  = @($report | Where-Object Stato -eq 'DA VALUTARE (avviso)').Count
Write-Host "Conformi: $(@($report | Where-Object Stato -eq 'CONFORME').Count)  |  Da allineare: $daAllineare  |  Da valutare (manuale): $daValutare"

if(-not $Apply){
    Write-Host ''
    Write-Host 'Questo e solo un REPORT. Per applicare (dopo backup Veeam + punto di ripristino):' -ForegroundColor Green
    Write-Host '  .\Allinea-BestPractice.ps1 -Apply        (da PowerShell amministratore)'
} else {
    ($log -join "`r`n") | Out-File $logFile -Encoding UTF8
    Write-Host ''
    Write-Host "Log della sessione: $logFile"
    Write-Host 'Riavvia se richiesto e verifica Outlook/Teams/OneDrive/VPN/SSO. Poi rilancia lo snapshot per certificare lo stato.'
}
