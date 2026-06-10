<#
================================================================================
 Snapshot-Stato.ps1  —  Fotografia di SOLA LETTURA di un PC Windows 11
================================================================================
 SCOPO
   Crea una fotografia completa e ripetibile dello stato della macchina e di
   OGNI account: identita, utenti, sessioni, software, servizi, avvio, rete,
   sicurezza, superficie d'attacco e persistenza (porte, autoruns, WMI, task,
   driver), Veeam, e (per ogni profilo) configurazioni di Claude, git, SSH e
   ambiente di sviluppo. Output in ..\snapshots\snapshot_<data>.

 GARANZIE
   - NON modifica nulla: legge ed esporta soltanto.
   - I SEGRETI NON vengono salvati: token, API key, password, chiavi private SSH
     e il file .credentials.json di Claude sono esclusi o oscurati (***REDACTED***).
   - Verifica comunque l'output prima di versionarlo: la cartella snapshots\ e'
     ignorata da git per default (vedi .gitignore).

 USO
   Apri PowerShell COME AMMINISTRATORE (per i dati di tutti gli account/BitLocker):
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
     .\Snapshot-Stato.ps1                 # tutto (consigliato)
     .\Snapshot-Stato.ps1 -Scope Machine  # solo dati di macchina
     .\Snapshot-Stato.ps1 -Scope User     # solo dati dell'account corrente

 MULTI-ACCOUNT
   I dati "file-based" (Claude/git/SSH) di TUTTI i profili in C:\Users vengono letti
   dal disco (serve admin), inclusi i profili Claude multi-account (.claude-account*
   selezionati via CLAUDE_CONFIG_DIR). I dati "live" (versioni di node/python,
   estensioni VS Code, git config attivo) riflettono SOLO l'account che esegue lo
   script: per averli completi, esegui anche -Scope User loggato in ciascun account.
================================================================================
#>

param(
    [ValidateSet('All','Machine','User')]
    [string]$Scope = 'All'
)

$ErrorActionPreference = 'Continue'
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj    = Split-Path -Parent $base
$outRoot = Join-Path $proj 'snapshots'
$outDir  = Join-Path $outRoot "snapshot_$stamp"
$usersDir= Join-Path $outDir 'utenti'
New-Item -ItemType Directory -Force -Path $outDir   | Out-Null
New-Item -ItemType Directory -Force -Path $usersDir | Out-Null

$summary = New-Object System.Collections.Generic.List[string]
function Add-Sum([string]$line){ $summary.Add($line) }
function Save([string]$name,$content){ $content | Out-File -FilePath (Join-Path $outDir $name) -Encoding UTF8 }
function SaveUser([string]$name,$content){ $content | Out-File -FilePath (Join-Path $usersDir $name) -Encoding UTF8 }
function Section([string]$t){ Add-Sum ''; Add-Sum ('=' * 72); Add-Sum $t; Add-Sum ('=' * 72) }

# Oscura i segreti nel testo prima di salvarlo
function Protect-Secrets([string]$t){
    if([string]::IsNullOrEmpty($t)){ return $t }
    $t = [regex]::Replace($t,'(?i)("?(?:api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|secret|password|pwd|authorization|token|pat|bearer)"?\s*[:=]\s*"?)([^"\r\n,}]+)','$1***REDACTED***')
    $t = [regex]::Replace($t,'sk-ant-[A-Za-z0-9\-_]+','***REDACTED***')
    $t = [regex]::Replace($t,'gh[pousr]_[A-Za-z0-9]{20,}','***REDACTED***')
    $t = [regex]::Replace($t,'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}','***REDACTED.JWT***')
    return $t
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$doMachine = $Scope -in @('All','Machine')
$doUser    = $Scope -in @('All','User')

Add-Sum "SNAPSHOT STATO PC  -  $(Get-Date)"
Add-Sum "Scope             : $Scope"
Add-Sum "Eseguito da       : $env:USERDOMAIN\$env:USERNAME"
Add-Sum "Amministratore    : $isAdmin"
if($doMachine -and -not $isAdmin){ Add-Sum "ATTENZIONE: senza admin mancheranno dati di altri account, BitLocker e Defender." }

# ============================================================================
#  PARTE MACCHINA
# ============================================================================
if($doMachine){

  Section '1. IDENTITA MACCHINA'
  try {
      $cs=Get-CimInstance Win32_ComputerSystem; $os=Get-CimInstance Win32_OperatingSystem
      $bios=Get-CimInstance Win32_BIOS; $cpu=(Get-CimInstance Win32_Processor|Select-Object -First 1).Name
      Add-Sum "Hostname        : $($cs.Name)"
      Add-Sum "Marca/Modello   : $($cs.Manufacturer) $($cs.Model)"
      Add-Sum "Serial/Service  : $($bios.SerialNumber)"
      Add-Sum "CPU             : $cpu"
      Add-Sum ("RAM (GB)        : {0:N1}" -f ($cs.TotalPhysicalMemory/1GB))
      Add-Sum "OS              : $($os.Caption)"
      Add-Sum "Build/Versione  : $($os.Version) (build $($os.BuildNumber))"
  } catch { Add-Sum "Errore identita: $_" }
  try {
      $dsreg = dsregcmd /status 2>$null
      Save 'join_dsregcmd.txt' ($dsreg -join "`r`n")
      Add-Sum 'Stato join (Entra ID / dominio):'
      ($dsreg | Select-String 'AzureAdJoined|DomainJoined|EnterpriseJoined|TenantName|MDMUrl|DeviceId|TenantId') |
          ForEach-Object { Add-Sum "  $($_.Line.Trim())" }
      Add-Sum '(dettaglio completo in join_dsregcmd.txt)'
  } catch { Add-Sum "dsregcmd non disponibile: $_" }

  Section '2. ACCOUNT E SESSIONI'
  try {
      Get-LocalUser | Select-Object Name,Enabled,LastLogon,Description |
          Export-Csv (Join-Path $outDir 'account_locali.csv') -NoTypeInformation -Encoding UTF8
      Add-Sum 'Utenti locali (account_locali.csv):'
      Get-LocalUser | ForEach-Object { Add-Sum "  $($_.Name)  (Enabled=$($_.Enabled))" }
  } catch { Add-Sum "Get-LocalUser non disponibile: $_" }
  try {
      Add-Sum ''; Add-Sum 'Amministratori locali:'
      $admins = Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop
      $admins | Select-Object Name,ObjectClass,PrincipalSource |
          Export-Csv (Join-Path $outDir 'amministratori_locali.csv') -NoTypeInformation -Encoding UTF8
      $admins | ForEach-Object { Add-Sum "  $($_.Name)  [$($_.ObjectClass)/$($_.PrincipalSource)]" }
  } catch { Add-Sum "Impossibile leggere gli amministratori locali: $_" }
  try {
      Add-Sum ''; Add-Sum 'Profili presenti in C:\Users:'
      Get-ChildItem 'C:\Users' -Directory -ErrorAction Stop |
          Where-Object { $_.Name -notin @('Public','Default','Default User','All Users') -and
                         $_.Name -notmatch '^(TEMP|UMFD-\d+)(\.|$)' } |
          ForEach-Object { Add-Sum "  $($_.Name)" }
  } catch {}
  try {
      Add-Sum ''; Add-Sum 'Sessioni in questo momento (quser):'
      $q = quser 2>$null
      if($q){ $q | ForEach-Object { Add-Sum "  $_" }; Save 'sessioni_quser.txt' ($q -join "`r`n") }
      else  { Add-Sum '  (nessuna sessione interattiva o quser non disponibile)' }
  } catch { Add-Sum "quser non disponibile: $_" }

  Section '3. CONFIGURAZIONI MACCHINA'
  try { Add-Sum ('Piano energetico: ' + ((powercfg /getactivescheme) -join '')) } catch {}
  try { Add-Sum ('Fuso orario: ' + (Get-TimeZone).Id) } catch {}
  try {
      Get-Printer | Select-Object Name,DriverName,PortName,Shared |
          Export-Csv (Join-Path $outDir 'stampanti.csv') -NoTypeInformation -Encoding UTF8
  } catch {}

  Section '4. SOFTWARE INSTALLATO'
  try {
      Get-Command winget -ErrorAction Stop | Out-Null
      winget list 2>$null | Out-File (Join-Path $outDir 'software_winget.txt') -Encoding UTF8
      winget export -o (Join-Path $outDir 'software_winget.json') --accept-source-agreements 2>$null | Out-Null
      Add-Sum 'WinGet: software_winget.txt + software_winget.json (riutilizzabile con: winget import).'
  } catch { Add-Sum 'WinGet non disponibile (uso il registro).' }
  try {
      Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
          Where-Object DisplayName | Select-Object DisplayName,DisplayVersion,Publisher,InstallDate | Sort-Object DisplayName |
          Export-Csv (Join-Path $outDir 'software_registro.csv') -NoTypeInformation -Encoding UTF8
      Add-Sum 'Programmi (registro): software_registro.csv'
  } catch {}
  try {
      Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object Name,PackageFullName | Sort-Object Name |
          Export-Csv (Join-Path $outDir 'app_appx_allusers.csv') -NoTypeInformation -Encoding UTF8
      Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Select-Object DisplayName,PackageName |
          Export-Csv (Join-Path $outDir 'app_appx_provisioned.csv') -NoTypeInformation -Encoding UTF8
      Add-Sum 'App Windows (Appx): app_appx_allusers.csv + app_appx_provisioned.csv (utili per il debloating).'
  } catch {}

  Section '5. SERVIZI'
  try {
      Get-CimInstance Win32_Service | Select-Object Name,DisplayName,State,StartMode,StartName | Sort-Object DisplayName |
          Export-Csv (Join-Path $outDir 'servizi.csv') -NoTypeInformation -Encoding UTF8
      Add-Sum 'Servizi: servizi.csv (confronta due snapshot per i cambi di StartMode).'
  } catch {}

  Section '6. AVVIO E ATTIVITA PIANIFICATE'
  try {
      Get-CimInstance Win32_StartupCommand | Select-Object Name,Command,Location,User |
          Export-Csv (Join-Path $outDir 'avvio.csv') -NoTypeInformation -Encoding UTF8
  } catch {}
  try {
      Get-ScheduledTask | Where-Object State -ne 'Disabled' | Select-Object TaskName,TaskPath,State | Sort-Object TaskPath,TaskName |
          Export-Csv (Join-Path $outDir 'attivita_pianificate.csv') -NoTypeInformation -Encoding UTF8
      Add-Sum 'Avvio: avvio.csv  |  Attivita pianificate attive: attivita_pianificate.csv'
  } catch {}

  Section '7. RETE'
  try { ipconfig /all | Out-File (Join-Path $outDir 'rete_ipconfig.txt') -Encoding UTF8 } catch {}
  try {
      Get-DnsClientServerAddress | Select-Object InterfaceAlias,AddressFamily,ServerAddresses |
          Export-Csv (Join-Path $outDir 'rete_dns.csv') -NoTypeInformation -Encoding UTF8
      Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction |
          Export-Csv (Join-Path $outDir 'firewall_profili.csv') -NoTypeInformation -Encoding UTF8
      Get-SmbShare | Select-Object Name,Path,Description |
          Export-Csv (Join-Path $outDir 'condivisioni.csv') -NoTypeInformation -Encoding UTF8
      Get-SmbMapping -ErrorAction SilentlyContinue | Select-Object LocalPath,RemotePath,Status |
          Export-Csv (Join-Path $outDir 'unita_di_rete.csv') -NoTypeInformation -Encoding UTF8
      Add-Sum 'Rete: rete_ipconfig.txt, rete_dns.csv, firewall_profili.csv, condivisioni.csv, unita_di_rete.csv'
  } catch {}

  Section '8. SICUREZZA'
  try {
      $mp=Get-MpComputerStatus -ErrorAction Stop
      Add-Sum "Defender AV attivo: $($mp.AntivirusEnabled) | Realtime: $($mp.RealTimeProtectionEnabled) | Firme: $($mp.AntivirusSignatureLastUpdated)"
  } catch { Add-Sum "Stato Defender non leggibile: $_" }
  try {
      Add-Sum 'BitLocker:'
      Get-BitLockerVolume -ErrorAction Stop | ForEach-Object {
          Add-Sum "  $($_.MountPoint)  Protezione=$($_.ProtectionStatus)  $($_.EncryptionPercentage)%  $($_.KeyProtector.KeyProtectorType -join ',')"
      }
      Add-Sum '  >> Su PC Entra ID joined la chiave di ripristino e di norma in Entra ID (entra.microsoft.com / account utente).'
      Add-Sum '  >> La chiave NON viene salvata qui: nella mappa annota solo DOVE recuperarla.'
  } catch { Add-Sum "Stato BitLocker non leggibile (serve admin): $_" }

  # --- Postura hardware/OS: Secure Boot, TPM, VBS, LSA, UAC, SMB, RDP, WinRM, patch ---
  try {
      $post = New-Object System.Collections.Generic.List[string]
      function Add-Post([string]$k,[string]$v){ $post.Add(("{0,-30}: {1}" -f $k,$v)) }
      try { Add-Post 'SecureBoot' ([string](Confirm-SecureBootUEFI -ErrorAction Stop)) }
      catch { Add-Post 'SecureBoot' 'non leggibile (serve admin, o firmware legacy BIOS)' }
      try {
          $tpm = Get-Tpm -ErrorAction Stop
          if($null -ne $tpm.TpmPresent -and "$($tpm.TpmPresent)" -ne ''){ Add-Post 'TPM presente / pronto' "$($tpm.TpmPresent) / $($tpm.TpmReady)" }
          else { Add-Post 'TPM' 'non leggibile (serve admin)' }
      } catch { Add-Post 'TPM' 'non leggibile (serve admin)' }
      try {
          $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction Stop
          Add-Post 'VBS (0=off 1=on 2=running)' ([string]$dg.VirtualizationBasedSecurityStatus)
          Add-Post 'Servizi VBS attivi' (($dg.SecurityServicesRunning -join ',') + '  (1=CredentialGuard, 2=HVCI)')
      } catch { Add-Post 'VBS/CredentialGuard' 'non leggibile' }
      $lsa = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -ErrorAction SilentlyContinue
      Add-Post 'LSA RunAsPPL' ($(if($null -ne $lsa.RunAsPPL){ [string]$lsa.RunAsPPL } else { 'non impostato (=0)' }))
      $uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
      Add-Post 'UAC EnableLUA' ([string]$uac.EnableLUA)
      Add-Post 'UAC prompt admin' "$($uac.ConsentPromptBehaviorAdmin)  (5=default, 2=consenso su desktop sicuro, 0=MAI: pericoloso)"
      try { $smb = Get-SmbServerConfiguration -ErrorAction Stop
            Add-Post 'SMBv1 server' ([string]$smb.EnableSMB1Protocol)
            Add-Post 'SMB firma richiesta' ([string]$smb.RequireSecuritySignature) }
      catch { Add-Post 'SMBv1' 'non leggibile (serve admin)' }
      $rdp = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -ErrorAction SilentlyContinue
      $nla = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -ErrorAction SilentlyContinue
      Add-Post 'RDP abilitato' ($(if($rdp.fDenyTSConnections -eq 0){ 'SI' } else { 'no' }))
      Add-Post 'RDP NLA richiesta' ([string]$nla.UserAuthentication)
      $winrm = Get-Service WinRM -ErrorAction SilentlyContinue
      Add-Post 'WinRM servizio' "$($winrm.Status) (avvio: $($winrm.StartType))"
      $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
      Add-Post 'Versione / build completa' "$($cv.DisplayVersion)  $($cv.CurrentBuildNumber).$($cv.UBR)"
      $hfRaw = Get-HotFix -ErrorAction SilentlyContinue
      if($hfRaw){
          # InstalledOn e' una proprieta' calcolata che su locale italiano puo' non parsare: accesso protetto
          $hf = foreach($h in $hfRaw){
              $dInst = $null; try { $dInst = $h.InstalledOn } catch {}
              [pscustomobject]@{ HotFixID=$h.HotFixID; Description=$h.Description; InstalledOn=$dInst }
          }
          $hf | Export-Csv (Join-Path $outDir 'hotfix.csv') -NoTypeInformation -Encoding UTF8
          $last = $hf | Where-Object InstalledOn | Sort-Object InstalledOn | Select-Object -Last 1
          Add-Post 'Hotfix installati' "$(@($hf).Count) (ultimo: $($last.HotFixID) del $($last.InstalledOn.ToString('yyyy-MM-dd'))) -> hotfix.csv"
      } else { Add-Post 'Hotfix' 'elenco non disponibile' }
      Save 'sicurezza_postura.txt' ($post -join "`r`n")
      Add-Sum ''
      Add-Sum 'Postura hardware/OS (sicurezza_postura.txt + hotfix.csv):'
      $post | ForEach-Object { Add-Sum "  $_" }
  } catch { Add-Sum "Postura di sicurezza non leggibile: $_" }

  Section '9. VEEAM (rilevamento)'
  try {
      $vs = Get-Service | Where-Object { $_.Name -like 'Veeam*' -or $_.DisplayName -like 'Veeam*' }
      if($vs){ Add-Sum 'Servizi Veeam:'; $vs | ForEach-Object { Add-Sum "  $($_.DisplayName) [$($_.Status)]" } }
      else  { Add-Sum 'Nessun servizio Veeam rilevato.' }
      Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
          Where-Object { $_.DisplayName -like 'Veeam*' } | ForEach-Object { Add-Sum "  Installato: $($_.DisplayName) $($_.DisplayVersion)" }
  } catch { Add-Sum "Rilevamento Veeam fallito: $_" }
  Add-Sum ''
  Add-Sum 'NOTA: il JOB Veeam (sorgente=Intero computer, destinazione=NAS \\server\share, retention,'
  Add-Sum 'cifratura, pianificazione, data supporto di ripristino, data ultimo test) va documentato a mano'
  Add-Sum 'nella sezione Veeam della mappa: Veeam Agent non lo esporta in modo affidabile via script.'

  Section "10. SUPERFICIE D'ATTACCO E PERSISTENZA"

  # --- Porte in ascolto con processo proprietario ---
  try {
      $procInfo = @{}
      Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
          ForEach-Object { $procInfo[[string]$_.ProcessId] = $_ }
      $porte = @()
      $porte += Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
          $p = $procInfo[[string]$_.OwningProcess]
          [pscustomobject]@{ Protocollo='TCP'; IndirizzoLocale=$_.LocalAddress; Porta=$_.LocalPort
                             PID=$_.OwningProcess; Processo=$p.Name; Percorso=$p.ExecutablePath }
      }
      $porte += Get-NetUDPEndpoint -ErrorAction SilentlyContinue | ForEach-Object {
          $p = $procInfo[[string]$_.OwningProcess]
          [pscustomobject]@{ Protocollo='UDP'; IndirizzoLocale=$_.LocalAddress; Porta=$_.LocalPort
                             PID=$_.OwningProcess; Processo=$p.Name; Percorso=$p.ExecutablePath }
      }
      $porte | Sort-Object Protocollo,{ [int]$_.Porta } |
          Export-Csv (Join-Path $outDir 'porte_in_ascolto.csv') -NoTypeInformation -Encoding UTF8
      $tcpN = @($porte | Where-Object Protocollo -eq 'TCP').Count
      $udpN = @($porte | Where-Object Protocollo -eq 'UDP').Count
      Add-Sum "Porte in ascolto: $tcpN TCP, $udpN UDP, con processo proprietario (porte_in_ascolto.csv)"
  } catch { Add-Sum "Porte in ascolto non leggibili: $_" }

  # --- Autoruns profondi: Run/RunOnce per hive, Winlogon, IFEO, SilentProcessExit ---
  try {
      $auto = New-Object System.Collections.Generic.List[object]
      $runKeys = @(
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
          'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
      )
      # Hive utente caricati in HKEY_USERS: coprono gli account con sessione attiva e .DEFAULT
      Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue |
          Where-Object { $_.PSChildName -notmatch '_Classes$' } | ForEach-Object {
              $runKeys += "Registry::HKEY_USERS\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Run"
              $runKeys += "Registry::HKEY_USERS\$($_.PSChildName)\Software\Microsoft\Windows\CurrentVersion\RunOnce"
          }
      foreach($k in $runKeys){
          if(-not (Test-Path $k)){ continue }
          $vals = Get-ItemProperty $k -ErrorAction SilentlyContinue
          foreach($p in $vals.PSObject.Properties){
              if($p.Name -in 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider'){ continue }
              $auto.Add([pscustomobject]@{ Origine=$k; Nome=$p.Name; Comando=[string]$p.Value })
          }
      }
      $wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
      foreach($n in 'Shell','Userinit','Taskman'){
          if($wl.$n){ $auto.Add([pscustomobject]@{ Origine='Winlogon'; Nome=$n; Comando=[string]$wl.$n }) }
      }
      Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' -ErrorAction SilentlyContinue |
          ForEach-Object {
              $d = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).Debugger
              if($d){ $auto.Add([pscustomobject]@{ Origine='IFEO'; Nome=$_.PSChildName; Comando=[string]$d }) }
          }
      Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit' -ErrorAction SilentlyContinue |
          ForEach-Object {
              $m = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).MonitorProcess
              if($m){ $auto.Add([pscustomobject]@{ Origine='SilentProcessExit'; Nome=$_.PSChildName; Comando=[string]$m }) }
          }
      # I comandi possono contenere credenziali negli argomenti: si salva tramite redazione
      $csv = ($auto | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
      Save 'autoruns_registro.csv' (Protect-Secrets $csv)
      $ifeoN = @($auto | Where-Object Origine -eq 'IFEO').Count
      Add-Sum "Autoruns registro: $($auto.Count) voci (autoruns_registro.csv) | IFEO con Debugger: $ifeoN"
  } catch { Add-Sum "Autoruns non leggibili: $_" }

  # --- Sottoscrizioni WMI (persistenza classica: di norma vuote o tutte note) ---
  try {
      $flt  = Get-CimInstance -Namespace root\subscription -ClassName __EventFilter -ErrorAction SilentlyContinue
      $cons = Get-CimInstance -Namespace root\subscription -ClassName __EventConsumer -ErrorAction SilentlyContinue
      $bind = Get-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding -ErrorAction SilentlyContinue
      $w = @("# Sottoscrizioni WMI (root\subscription) — $(Get-Date)","")
      $w += "## EventFilter ($(@($flt).Count)):";  $flt  | ForEach-Object { $w += "  $($_.Name): $($_.Query)" }
      $w += ""; $w += "## EventConsumer ($(@($cons).Count)):"
      $cons | ForEach-Object { $w += "  [$($_.CimClass.CimClassName)] $($_.Name)" }
      $w += ""; $w += "## FilterToConsumerBinding ($(@($bind).Count)):"
      $bind | ForEach-Object { $w += "  $($_.Filter) -> $($_.Consumer)" }
      Save 'wmi_sottoscrizioni.txt' (Protect-Secrets ($w -join "`r`n"))
      Add-Sum "Sottoscrizioni WMI: $(@($bind).Count) binding, $(@($cons).Count) consumer (wmi_sottoscrizioni.txt)"
  } catch { Add-Sum "Sottoscrizioni WMI non leggibili: $_" }

  # --- Azioni complete delle attivita pianificate non Microsoft ---
  try {
      $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -notlike '\Microsoft\*' }
      $rows = foreach($t in $tasks){
          foreach($a in $t.Actions){
              [pscustomobject]@{
                  TaskPath=$t.TaskPath; TaskName=$t.TaskName; Stato=[string]$t.State; Autore=$t.Author
                  Esegui=$a.Execute; Argomenti=$a.Arguments; CartellaLavoro=$a.WorkingDirectory
              }
          }
      }
      $csv = ($rows | ConvertTo-Csv -NoTypeInformation) -join "`r`n"
      Save 'attivita_pianificate_azioni.csv' (Protect-Secrets $csv)
      Add-Sum "Attivita pianificate non Microsoft, con azioni: $(@($tasks).Count) task (attivita_pianificate_azioni.csv)"
  } catch { Add-Sum "Azioni delle attivita pianificate non leggibili: $_" }

  # --- Driver: inventario firme e non firmati ---
  try {
      $dq = driverquery /si /fo csv 2>$null | ConvertFrom-Csv
      if($dq){
          # I nomi colonna sono localizzati ma l'ordine e' fisso: 1=dispositivo, 3=firmato
          $cols = @(@($dq)[0].PSObject.Properties.Name)
          $dq | Export-Csv (Join-Path $outDir 'driver_firme.csv') -NoTypeInformation -Encoding UTF8
          $unsigned = @($dq | Where-Object { $_.($cols[2]) -match '^(FALSE|FALSO|NO)$' })
          $unsigned | Export-Csv (Join-Path $outDir 'driver_non_firmati.csv') -NoTypeInformation -Encoding UTF8
          Add-Sum "Driver: $(@($dq).Count) totali, NON firmati: $($unsigned.Count) (driver_firme.csv, driver_non_firmati.csv)"
      } else { Add-Sum 'driverquery non ha prodotto output.' }
  } catch { Add-Sum "Firme driver non leggibili: $_" }

  # --- Servizi con percorso non quotato contenente spazi (escalation classica) ---
  try {
      $svcBad = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
          $_.PathName -and $_.PathName.Trim() -notmatch '^"' -and
          ($_.PathName -split '\.exe')[0] -match '\s'
      } | Select-Object Name,DisplayName,StartMode,StartName,PathName
      $svcBad | Export-Csv (Join-Path $outDir 'servizi_percorsi_non_quotati.csv') -NoTypeInformation -Encoding UTF8
      Add-Sum "Servizi con percorso non quotato e spazi: $(@($svcBad).Count) (servizi_percorsi_non_quotati.csv)"
  } catch { Add-Sum "Controllo percorsi servizi fallito: $_" }
}

# ============================================================================
#  PARTE PER-UTENTE (file-based, da disco) — Claude / git / SSH per OGNI account
# ============================================================================
if($doMachine){
  Section '11. CONFIGURAZIONI PER ACCOUNT (Claude / git / SSH)  [da disco]'
  try {
      # Esclusi anche i profili di servizio (TEMP*, UMFD-* dei Font Driver Host): non sono account reali
      $profiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction Stop |
          Where-Object { $_.Name -notin @('Public','Default','Default User','All Users') -and
                         $_.Name -notmatch '^(TEMP|UMFD-\d+)(\.|$)' }
  } catch { $profiles=@(); Add-Sum "Impossibile elencare i profili: $_" }

  foreach($p in $profiles){
      # NB: non usare $home come nome: HOME e' una variabile read-only di PowerShell
      $u = $p.Name; $homeDir = $p.FullName
      Add-Sum ''; Add-Sum "--- Account: $u ---"

      # --- Claude: TUTTI i profili .claude* (default e multi-account via CLAUDE_CONFIG_DIR; mai i segreti) ---
      $claudeDirs = @(Get-ChildItem $homeDir -Directory -Filter '.claude*' -Force -ErrorAction SilentlyContinue)
      $claudeJson = Join-Path $homeDir '.claude.json'
      $lines = @("# Configurazione Claude per $u","")
      if($claudeDirs.Count -gt 0){
          foreach($cd in $claudeDirs){
              $lines += "## Profilo $($cd.Name)"
              $inv = @(Get-ChildItem $cd.FullName -Recurse -File -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -ne '.credentials.json' })
              $lines += "Inventario: $($inv.Count) file (esclusi i segreti); primi 200:"
              $inv | Select-Object -First 200 |
                  ForEach-Object { $lines += ("  {0}  ({1} byte)" -f $_.FullName.Replace($homeDir,'~'), $_.Length) }
              if($inv.Count -gt 200){ $lines += "  ... (+$($inv.Count-200) altri file non elencati)" }
              if(Test-Path (Join-Path $cd.FullName '.credentials.json')){
                  $lines += "  ~\$($cd.Name)\.credentials.json  (PRESENTE — NON letto: contiene credenziali)"
              }
              # Nei profili multi-account il file di stato .claude.json vive DENTRO la cartella profilo
              foreach($f in @('settings.json','CLAUDE.md','.claude.json')){
                  $fp = Join-Path $cd.FullName $f
                  if(Test-Path $fp){ $lines += ""; $lines += "### $($cd.Name)\$f (oscurato):"; $lines += (Protect-Secrets (Get-Content $fp -Raw)) }
              }
              $lines += ""
          }
          Add-Sum "  Claude: $($claudeDirs.Count) profilo/i [$(($claudeDirs | ForEach-Object Name) -join ', ')] (dettaglio in utenti\${u}_claude.txt)"
      } else { $lines += "Nessuna cartella .claude*."; Add-Sum "  Claude: non configurato" }
      if(Test-Path $claudeJson){
          $lines += ""; $lines += "### .claude.json (radice del profilo utente — oscurato, utile per progetti e server MCP):"
          $lines += (Protect-Secrets (Get-Content $claudeJson -Raw))
      }
      SaveUser "${u}_claude.txt" ($lines -join "`r`n")

      # --- git (mai i token) ---
      $gitcfg = Join-Path $homeDir '.gitconfig'
      if(Test-Path $gitcfg){
          SaveUser "${u}_gitconfig.txt" (Protect-Secrets (Get-Content $gitcfg -Raw))
          Add-Sum "  git: .gitconfig presente (utenti\${u}_gitconfig.txt)"
      } else { Add-Sum "  git: nessun .gitconfig globale" }

      # --- SSH (solo chiavi PUBBLICHE e inventario; mai chiavi private) ---
      $sshDir = Join-Path $homeDir '.ssh'
      if(Test-Path $sshDir){
          $sl = @("# SSH per $u — solo inventario e chiavi pubbliche","")
          Get-ChildItem $sshDir -File -ErrorAction SilentlyContinue | ForEach-Object { $sl += "  $($_.Name)  ($($_.Length) byte)" }
          $sl += ""; $sl += "### Chiavi pubbliche (*.pub):"
          Get-ChildItem $sshDir -Filter '*.pub' -ErrorAction SilentlyContinue | ForEach-Object { $sl += (Get-Content $_.FullName -Raw) }
          $sl += ""; $sl += ">> Le chiavi PRIVATE non vengono lette ne salvate."
          SaveUser "${u}_ssh.txt" ($sl -join "`r`n")
          Add-Sum "  ssh: cartella .ssh presente (utenti\${u}_ssh.txt — solo pubbliche)"
      }
  }
}

# ============================================================================
#  PARTE UTENTE LIVE — ambiente di sviluppo dell'account corrente
# ============================================================================
if($doUser){
  Section "12. AMBIENTE DI SVILUPPO (account corrente: $env:USERNAME)"
  $dev = @("# Ambiente sviluppo — $env:USERDOMAIN\$env:USERNAME — $(Get-Date)","")
  function Try-Cmd($label,$scriptblock){
      try { $out = & $scriptblock 2>$null; if($out){ $script:dev += "## ${label}:"; $script:dev += ($out | Out-String).TrimEnd(); $script:dev += "" } }
      catch {}
  }
  Try-Cmd 'git version'        { git --version }
  Try-Cmd 'git config --list'  { Protect-Secrets ((git config --list | Out-String)) }
  Try-Cmd 'node'               { node --version }
  Try-Cmd 'npm'                { npm --version }
  Try-Cmd 'npm globali'        { npm ls -g --depth=0 }
  Try-Cmd 'python'             { python --version }
  Try-Cmd 'pip'                { pip --version }
  Try-Cmd 'dotnet'             { dotnet --list-sdks }
  Try-Cmd 'go'                 { go version }
  Try-Cmd 'rustc'              { rustc --version }
  Try-Cmd 'java'               { java -version }
  Try-Cmd 'docker'             { docker --version }
  Try-Cmd 'winget'             { winget --version }
  Try-Cmd 'scoop'              { scoop --version }
  Try-Cmd 'choco'              { choco --version }
  Try-Cmd 'VS Code estensioni' { code --list-extensions --show-versions }
  Try-Cmd 'WSL distro'         { wsl -l -v }
  Try-Cmd 'claude version'     { claude --version }
  $dev += "## PATH:"; $dev += ($env:Path -split ';' | Sort-Object)
  SaveUser "_dev_${env:USERNAME}.txt" ($dev -join "`r`n")
  Add-Sum ''
  Add-Sum "Ambiente di sviluppo dell'account $env:USERNAME salvato in utenti\_dev_${env:USERNAME}.txt"
  Add-Sum '(Per gli altri account, riesegui -Scope User loggato con quegli utenti.)'
}

# --- Riepilogo ---------------------------------------------------------------
Save 'SUMMARY.txt' ($summary -join "`r`n")
Write-Host ''
Write-Host 'Snapshot completato.' -ForegroundColor Green
Write-Host "Cartella: $outDir"
Write-Host 'Apri SUMMARY.txt per la sintesi; CSV/TXT e la sottocartella utenti\ per i dettagli.'
Write-Host 'Confronto tra due snapshot: scripts\Compare-Snapshot.ps1'
