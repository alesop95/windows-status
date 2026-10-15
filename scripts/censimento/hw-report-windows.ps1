# Caratterizzazione hardware completa - macchine Windows
# Output confrontabile con hw-report.sh (Linux)
#
# USO: aprire PowerShell COME AMMINISTRATORE sulla macchina da analizzare, poi:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\hw-report-windows.ps1 > hw-NOMEMACCHINA.txt
#
# Non installa nulla, non modifica nulla: solo lettura.

function Sep($t) { "`n============================================================"; "== $t"; "============================================================" }

Sep "IDENTITA"
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
"hostname   : $($cs.Name)"
"dominio    : $($cs.Domain)"
"data       : $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
"OS         : $($os.Caption) build $($os.BuildNumber)"
"versione   : $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion)"
"arch       : $($os.OSArchitecture)"
"installato : $($os.InstallDate)"
"ultimo boot: $($os.LastBootUpTime)"
$fw = if ($env:firmware_type) { $env:firmware_type } else { (Get-CimInstance Win32_ComputerSystem).BootupState }
"boot       : $(if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State') {'UEFI'} else {'BIOS/Legacy o non determinabile'})"
try { "SecureBoot : $(Confirm-SecureBootUEFI)" } catch { "SecureBoot : non applicabile (BIOS legacy)" }

Sep "SISTEMA / MOTHERBOARD / BIOS"
$cs | Select-Object Manufacturer,Model,SystemFamily,SystemSKUNumber | Format-List | Out-String
Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer,Product,Version,SerialNumber | Format-List | Out-String
Get-CimInstance Win32_BIOS | Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate,SerialNumber | Format-List | Out-String
"--- chassis ---"
Get-CimInstance Win32_SystemEnclosure | Select-Object ChassisTypes,SerialNumber | Format-List | Out-String

Sep "CPU"
Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,
  MaxClockSpeed,CurrentClockSpeed,L2CacheSize,L3CacheSize,SocketDesignation,ProcessorId,VirtualizationFirmwareEnabled,
  SecondLevelAddressTranslationExtensions,VMMonitorModeExtensions | Format-List | Out-String
"--- virtualizzazione abilitata nel BIOS ---"
"VT-x/AMD-V : $((Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled)"
"Hyper-V presente: $((Get-CimInstance Win32_ComputerSystem).HypervisorPresent)"

Sep "MEMORIA"
$tot = [math]::Round($cs.TotalPhysicalMemory/1GB,2)
"totale installata : $tot GB"
"--- banchi ---"
Get-CimInstance Win32_PhysicalMemory | Select-Object DeviceLocator,BankLabel,
  @{N='GB';E={[math]::Round($_.Capacity/1GB,0)}},
  @{N='Tipo';E={switch($_.SMBIOSMemoryType){20{'DDR'}21{'DDR2'}24{'DDR3'}26{'DDR4'}34{'DDR5'}default{"code $($_.SMBIOSMemoryType)"}}}},
  Speed,ConfiguredClockSpeed,Manufacturer,PartNumber,SerialNumber | Format-Table -AutoSize | Out-String
"--- slot totali / occupati ---"
$pma = Get-CimInstance Win32_PhysicalMemoryArray
"slot totali    : $($pma.MemoryDevices)"
"slot occupati  : $((Get-CimInstance Win32_PhysicalMemory | Measure-Object).Count)"
"massimo supportato : $([math]::Round($pma.MaxCapacity/1MB,0)) GB"

Sep "DISCHI"
Get-PhysicalDisk | Select-Object DeviceId,FriendlyName,MediaType,BusType,
  @{N='GB';E={[math]::Round($_.Size/1GB,1)}},SerialNumber,FirmwareVersion,HealthStatus | Format-Table -AutoSize | Out-String
"--- partizioni e volumi ---"
Get-Partition -ErrorAction SilentlyContinue | Select-Object DiskNumber,PartitionNumber,DriveLetter,Type,
  @{N='GB';E={[math]::Round($_.Size/1GB,1)}},IsBoot,IsSystem | Format-Table -AutoSize | Out-String
Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } | Select-Object DriveLetter,FileSystemLabel,FileSystem,
  @{N='TotGB';E={[math]::Round($_.Size/1GB,1)}},@{N='LiberiGB';E={[math]::Round($_.SizeRemaining/1GB,1)}},HealthStatus |
  Format-Table -AutoSize | Out-String
"--- stile partizionamento (GPT/MBR) ---"
Get-Disk -ErrorAction SilentlyContinue | Select-Object Number,FriendlyName,PartitionStyle,
  @{N='GB';E={[math]::Round($_.Size/1GB,1)}},BusType | Format-Table -AutoSize | Out-String
"--- SMART / affidabilita ---"
foreach ($d in Get-PhysicalDisk) {
  "### $($d.FriendlyName) (DeviceId $($d.DeviceId))"
  try {
    $d | Get-StorageReliabilityCounter -ErrorAction Stop |
      Select-Object Wear,PowerOnHours,Temperature,ReadErrorsTotal,WriteErrorsTotal | Format-List | Out-String
  } catch { "  contatori non disponibili" }
}

Sep "RETE"
Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name,InterfaceDescription,Status,
  LinkSpeed,MacAddress,DriverVersion | Format-Table -AutoSize | Out-String
"--- indirizzi ---"
Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '127.*' } |
  Select-Object InterfaceAlias,IPAddress,PrefixLength | Format-Table -AutoSize | Out-String
"--- gateway ---"
Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } |
  Select-Object InterfaceAlias,NextHop | Format-Table -AutoSize | Out-String
"--- DNS ---"
Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.ServerAddresses } | Select-Object InterfaceAlias,ServerAddresses | Format-Table -AutoSize | Out-String

Sep "GPU"
Get-CimInstance Win32_VideoController | Select-Object Name,VideoProcessor,
  @{N='VRAM_GB';E={[math]::Round($_.AdapterRAM/1GB,2)}},DriverVersion,DriverDate,
  CurrentHorizontalResolution,CurrentVerticalResolution | Format-List | Out-String

Sep "SLOT PCI / DISPOSITIVI"
"--- slot di sistema ---"
Get-CimInstance Win32_SystemSlot -ErrorAction SilentlyContinue |
  Select-Object SlotDesignation,CurrentUsage,MaxDataWidth | Format-Table -AutoSize | Out-String
"--- controller storage ---"
Get-CimInstance Win32_IDEController -ErrorAction SilentlyContinue | Select-Object Name | Format-Table -AutoSize | Out-String
Get-CimInstance Win32_SCSIController -ErrorAction SilentlyContinue | Select-Object Name,DriverName | Format-Table -AutoSize | Out-String

Sep "PERIFERICHE"
Get-CimInstance Win32_CDROMDrive -ErrorAction SilentlyContinue | Select-Object Name,Drive,MediaType | Format-Table -AutoSize | Out-String
"--- monitor collegati ---"
Get-CimInstance Win32_DesktopMonitor -ErrorAction SilentlyContinue | Select-Object Name,ScreenWidth,ScreenHeight | Format-Table -AutoSize | Out-String

Sep "ALIMENTAZIONE / TERMICO"
Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object Name,EstimatedChargeRemaining | Format-Table -AutoSize | Out-String
try {
  Get-CimInstance -Namespace root/wmi MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
    Select-Object InstanceName,@{N='TempC';E={[math]::Round(($_.CurrentTemperature-2732)/10,1)}} | Format-Table -AutoSize | Out-String
} catch { "temperature ACPI non esposte" }

Sep "SOFTWARE RILEVANTE"
"--- licenza Windows ---"
try {
  Get-CimInstance SoftwareLicensingProduct -ErrorAction Stop |
    Where-Object { $_.PartialProductKey } |
    Select-Object Name,@{N='Stato';E={switch($_.LicenseStatus){0{'Non licenziato'}1{'Licenziato'}2{'Grazia OOB'}3{'Grazia OOT'}4{'Grazia non genuino'}5{'Notifica'}default{$_.LicenseStatus}}}},
      @{N='Canale';E={$_.ProductKeyChannel}} | Format-Table -AutoSize | Out-String
} catch { "stato licenza non leggibile" }
"--- BitLocker (attenzione se si formatta) ---"
try {
  Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint,VolumeStatus,ProtectionStatus,EncryptionPercentage |
    Format-Table -AutoSize | Out-String
} catch { "BitLocker non disponibile o non configurato" }
"--- servizi in ascolto ---"
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,@{N='Processo';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
  Sort-Object LocalPort -Unique | Format-Table -AutoSize | Out-String
"--- programmi installati (primi 40) ---"
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName } | Select-Object DisplayName,DisplayVersion,Publisher |
  Sort-Object DisplayName | Select-Object -First 40 | Format-Table -AutoSize | Out-String

Sep "UTENTI"
Get-LocalUser -ErrorAction SilentlyContinue | Select-Object Name,Enabled,LastLogon,Description | Format-Table -AutoSize | Out-String
"--- amministratori locali ---"
Get-LocalGroupMember -Group 'Administrators' -ErrorAction SilentlyContinue | Select-Object Name,ObjectClass | Format-Table -AutoSize | Out-String

Sep "FINE"
