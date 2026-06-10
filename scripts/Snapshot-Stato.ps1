<#
================================================================================
 Snapshot-Stato.ps1  —  Fotografia di SOLA LETTURA di un PC Windows 11
================================================================================
 SCOPO
   Crea una fotografia completa e ripetibile dello stato della macchina e di
   OGNI account: identita, utenti, sessioni, software, servizi, avvio, rete,
   sicurezza, Veeam, e (per ogni profilo) configurazioni di Claude, git, SSH e
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
   dal disco (serve admin). I dati "live" (versioni di node/python, estensioni VS Code,
   git config attivo) riflettono SOLO l'account che esegue lo script: per averli
   completi, esegui anche -Scope User loggato in ciascun account.
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
      Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop |
          ForEach-Object { Add-Sum "  $($_.Name)  [$($_.ObjectClass)/$($_.PrincipalSource)]" }
  } catch { Add-Sum "Impossibile leggere gli amministratori locali: $_" }
  try {
      Add-Sum ''; Add-Sum 'Profili presenti in C:\Users:'
      Get-ChildItem 'C:\Users' -Directory -ErrorAction Stop |
          Where-Object { $_.Name -notin @('Public','Default','Default User','All Users') } |
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
}

# ============================================================================
#  PARTE PER-UTENTE (file-based, da disco) — Claude / git / SSH per OGNI account
# ============================================================================
if($doMachine){
  Section '10. CONFIGURAZIONI PER ACCOUNT (Claude / git / SSH)  [da disco]'
  try {
      $profiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction Stop |
          Where-Object { $_.Name -notin @('Public','Default','Default User','All Users') }
  } catch { $profiles=@(); Add-Sum "Impossibile elencare i profili: $_" }

  foreach($p in $profiles){
      $u = $p.Name; $home = $p.FullName
      Add-Sum ''; Add-Sum "--- Account: $u ---"

      # --- Claude (mai i segreti) ---
      $claudeDir = Join-Path $home '.claude'
      $claudeJson= Join-Path $home '.claude.json'
      $lines = @("# Configurazione Claude per $u","")
      if(Test-Path $claudeDir){
          $lines += "Cartella .claude presente. Inventario (esclusi i segreti):"
          Get-ChildItem $claudeDir -Recurse -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -ne '.credentials.json' } |
              ForEach-Object { $lines += ("  {0}  ({1} byte)" -f $_.FullName.Replace($home,'~'), $_.Length) }
          if(Test-Path (Join-Path $claudeDir '.credentials.json')){ $lines += "  ~\.claude\.credentials.json  (PRESENTE — NON letto: contiene credenziali)" }
          foreach($f in @('settings.json','CLAUDE.md')){
              $fp = Join-Path $claudeDir $f
              if(Test-Path $fp){ $lines += ""; $lines += "### .claude\$f (oscurato):"; $lines += (Protect-Secrets (Get-Content $fp -Raw)) }
          }
          Add-Sum "  Claude: cartella .claude presente (dettaglio in utenti\${u}_claude.txt)"
      } else { $lines += "Nessuna cartella .claude."; Add-Sum "  Claude: non configurato" }
      if(Test-Path $claudeJson){
          $lines += ""; $lines += "### .claude.json (oscurato, utile per progetti e server MCP):"
          $lines += (Protect-Secrets (Get-Content $claudeJson -Raw))
      }
      SaveUser "${u}_claude.txt" ($lines -join "`r`n")

      # --- git (mai i token) ---
      $gitcfg = Join-Path $home '.gitconfig'
      if(Test-Path $gitcfg){
          SaveUser "${u}_gitconfig.txt" (Protect-Secrets (Get-Content $gitcfg -Raw))
          Add-Sum "  git: .gitconfig presente (utenti\${u}_gitconfig.txt)"
      } else { Add-Sum "  git: nessun .gitconfig globale" }

      # --- SSH (solo chiavi PUBBLICHE e inventario; mai chiavi private) ---
      $sshDir = Join-Path $home '.ssh'
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
  Section "11. AMBIENTE DI SVILUPPO (account corrente: $env:USERNAME)"
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
