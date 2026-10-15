# =============================================================================
#  hw-report-windows.ps1  -  censimento hardware di UNA macchina Windows
#  Parte di windows-status, cartella scripts\censimento. Vedi docs\15.
# =============================================================================
#  COSA FA. Legge l'hardware e la configurazione di base della macchina su cui
#  gira e scrive un testo con le stesse sezioni, con gli stessi nomi e nello
#  stesso ordine, del gemello hw-report.sh per Linux: due macchine di famiglie
#  diverse si affiancano sezione per sezione.
#
#  COSA NON FA, E PERCHE'. Niente postura di sicurezza, licenze, BitLocker,
#  Secure Boot, software installato, account, avvio, persistenza, backup.
#  Su una macchina dentro il perimetro del progetto quelle cose le copre, molto
#  piu' a fondo e con lo storico, scripts\Snapshot-Stato.ps1 insieme a
#  Compare-Snapshot.ps1: duplicarle qui produrrebbe due verita' che divergono.
#  Il censimento serve alle macchine che quella catena non raggiunge.
#
#  ANONIMO PER DEFAULT. Seriali, UUID, hostname, dominio e nomi utente escono
#  come pseudonimi stabili; i MAC conservano le prime tre coppie, cioe' il
#  produttore, e perdono le altre; gli IPv4 conservano la rete e perdono
#  l'ultimo numero. Lo stesso valore sulla stessa macchina da' sempre lo stesso
#  pseudonimo, quindi due censimenti restano confrontabili. Con -Identificativi
#  esce tutto in chiaro: quell'output contiene dati identificativi reali e non
#  va mai dentro un repository.
#
#  SOLA LETTURA. Non installa, non modifica, non tocca registro ne' servizi.
#  Da amministratore si vedono in piu' i seriali dei banchi di memoria e i
#  contatori di affidabilita' dei dischi; senza, l'intestazione lo dichiara.
#
#  USO
#    powershell -NoProfile -ExecutionPolicy Bypass -File .\hw-report-windows.ps1
#    .\hw-report-windows.ps1 -Etichetta PDL-07 -Destinazione D:\censimento
#    .\hw-report-windows.ps1 -Identificativi -Destinazione .\hw-reale.txt
#    .\hw-report-windows.ps1 -Sezioni CPU,MEMORIA,DISCHI -StdOut
#    .\hw-report-windows.ps1 -ContestoSoftware -Pattern 'veeam|sql'
#    .\hw-report-windows.ps1 -Elenco
# =============================================================================

[CmdletBinding()]
param(
    # File o cartella di destinazione. Cartella o omesso: il nome lo decide lo
    # script, e in modo anonimo non contiene mai l'hostname.
    [string]   $Destinazione,

    # Scrive a schermo invece che su file (per incollare o per una pipe).
    [switch]   $StdOut,

    # Nome con cui chiamare la macchina nel censimento (numero di inventario,
    # postazione, ruolo). Sostituisce l'hostname nell'intestazione e nel nome
    # del file. E' l'unico identificativo che decidi tu.
    [string]   $Etichetta,

    # Disattiva l'anonimizzazione: seriali, MAC e IP escono in chiaro.
    [switch]   $Identificativi,

    # Sale degli pseudonimi. Lo stesso sale su piu' macchine rende gli
    # pseudonimi confrontabili tra loro; sali diversi li rendono scollegati.
    [string]   $Sale = 'censimento',

    # Sottoinsieme di sezioni, nell'ordine fisso. -Elenco le mostra.
    [string[]] $Sezioni,

    # Aggiunge la sezione CONTESTO SOFTWARE (servizi, porte, conteggi, utenti).
    # Su una macchina del perimetro del progetto NON serve: la copre lo snapshot.
    [switch]   $ContestoSoftware,

    # Filtro per la sezione CONTESTO SOFTWARE (espressione regolare).
    [string]   $Pattern,

    # Stampa le sezioni disponibili ed esce.
    [switch]   $Elenco
)

$ErrorActionPreference = 'Continue'
$VERSIONE = '2.0'
$TUTTE = @('IDENTITA','SISTEMA','CPU','MEMORIA','DISCHI','RETE','GPU','PERIFERICHE','ALIMENTAZIONE')

if ($Elenco) {
    'Sezioni del censimento, ordine fisso e comune a hw-report.sh:'
    $TUTTE | ForEach-Object { "  $_" }
    '  SOFTWARE        solo con -ContestoSoftware'
    return
}

if (-not $Sezioni -or $Sezioni.Count -eq 0) { $Sezioni = $TUTTE }
# Con -File PowerShell non costruisce array: -Sezioni CPU,RETE arriva come una
# stringa sola. Si spezza qui, cosi' la stessa forma vale da -File e da -Command.
$Sezioni = @($Sezioni | ForEach-Object { $_ -split '[,;\s]+' } |
             Where-Object { $_ } | ForEach-Object { $_.ToUpper().Trim() })
$ignote = @($Sezioni | Where-Object { $TUTTE -notcontains $_ -and $_ -ne 'SOFTWARE' })
if ($ignote.Count -gt 0) { throw "Sezioni non riconosciute: $($ignote -join ', '). Usa -Elenco." }
if ($ContestoSoftware -and $Sezioni -notcontains 'SOFTWARE') { $Sezioni = @($Sezioni) + 'SOFTWARE' }

$Anonimo = -not $Identificativi

# Macchine vecchie o edizioni ridotte: se manca Get-CimInstance si ripiega su WMI.
if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
    function Get-CimInstance {
        param([string]$ClassName, [string]$Namespace = 'root\cimv2', $ErrorAction)
        Get-WmiObject -Class $ClassName -Namespace $Namespace -ErrorAction SilentlyContinue
    }
}

# --- anonimizzazione ---------------------------------------------------------

# Valori che non identificano nessuno e che non vanno sostituiti: li scrivono
# i produttori quando il campo e' rimasto vuoto in fabbrica.
$INUTILI = @('to be filled by o.e.m.','default string','none','n/a','not specified',
             'not available','system serial number','base board serial number',
             'chassis serial number','0123456789','unknown','workgroup','standard',
             '00000000-0000-0000-0000-000000000000',
             # Nomi di account generici: non identificano nessuno, e sostituirli
             # sfigurerebbe le etichette italiane di questo stesso censimento
             # (un account chiamato Utente colpirebbe la parola "utente").
             'utente','utenti','user','users','admin','administrator','amministratore',
             'guest','ospite','public','default','defaultuser0','sistema','system')

$script:Sost = New-Object System.Collections.ArrayList

function Pseudonimo {
    param([string]$Valore, [string]$Tipo)
    $sha  = [System.Security.Cryptography.SHA256]::Create()
    $byte = [System.Text.Encoding]::UTF8.GetBytes(('{0}|{1}|{2}' -f $Sale, $Tipo, $Valore))
    $dig  = $sha.ComputeHash($byte)
    $sha.Dispose()
    $hex = ($dig[0..3] | ForEach-Object { $_.ToString('x2') }) -join ''
    return ('<{0}-{1}>' -f $Tipo, $hex)
}

function Registra {
    param([string]$Valore, [string]$Tipo)
    if (-not $Anonimo) { return }
    if ([string]::IsNullOrWhiteSpace($Valore)) { return }
    $v = $Valore.Trim()
    # Sotto i quattro caratteri la sostituzione globale colpirebbe parole comuni.
    if ($v.Length -lt 4) { return }
    if ($INUTILI -contains $v.ToLower()) { return }
    if ($script:Sost | Where-Object { $_.Da -eq $v }) { return }
    [void]$script:Sost.Add([pscustomobject]@{ Da = $v; A = (Pseudonimo $v $Tipo) })
}

function Sanifica {
    param([string]$Testo)
    if (-not $Anonimo) { return $Testo }
    # Dal piu' lungo al piu' corto: un seriale contenuto in un altro non deve
    # essere sostituito per primo e spezzare quello che lo contiene.
    foreach ($s in ($script:Sost | Sort-Object { $_.Da.Length } -Descending)) {
        $Testo = [regex]::Replace($Testo, [regex]::Escape($s.Da), $s.A, 'IgnoreCase')
    }
    # Rete di sicurezza per i valori comparsi dentro descrizioni libere.
    # MAC: restano le prime tre coppie, cioe' il produttore; il resto sparisce.
    $Testo = [regex]::Replace($Testo,
        '\b([0-9A-Fa-f]{2})([:-])([0-9A-Fa-f]{2})\2([0-9A-Fa-f]{2})\2[0-9A-Fa-f]{2}\2[0-9A-Fa-f]{2}\2[0-9A-Fa-f]{2}\b',
        {
            param($m)
            $s = $m.Groups[2].Value
            '{0}{1}{2}{1}{3}{1}XX{1}XX{1}XX' -f $m.Groups[1].Value, $s, $m.Groups[3].Value, $m.Groups[4].Value
        })
    # IPv4: resta la rete, sparisce l'ultimo numero.
    $Testo = [regex]::Replace($Testo, '\b(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})\b', {
        param($m)
        $rete = $m.Groups[1].Value
        # Loopback, rotta di default, maschere e multicast restano leggibili:
        # non identificano una macchina e servono a capire la configurazione.
        if ($rete -match '^(127\.|0\.0\.0|255\.255\.25|22[4-9]\.|23[0-9]\.)') { return $m.Value }
        return ('{0}.x' -f $rete)
    })
    return $Testo
}

function RaccogliIdentificativi {
    if (-not $Anonimo) { return }
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs) { Registra $cs.Name 'host'; Registra $cs.Domain 'dominio' }
    Registra $env:COMPUTERNAME 'host'
    Registra $env:USERDNSDOMAIN 'dominio'
    $prod = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
    if ($prod) { Registra $prod.IdentifyingNumber 'sn'; Registra $prod.UUID 'uuid' }
    foreach ($c in @(Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue))       { Registra $c.SerialNumber 'sn' }
    foreach ($c in @(Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue))            { Registra $c.SerialNumber 'sn' }
    foreach ($c in @(Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue)) { Registra $c.SerialNumber 'sn' }
    foreach ($c in @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue))  { Registra $c.SerialNumber 'sn' }
    foreach ($c in @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue))       { Registra $c.ProcessorId 'cpuid' }
    foreach ($d in @(Get-PhysicalDisk -ErrorAction SilentlyContinue))                      { Registra $d.SerialNumber 'sn' }
    foreach ($d in @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue))       { Registra $d.SerialNumber 'sn' }
    foreach ($u in @(Get-LocalUser -ErrorAction SilentlyContinue))                         { Registra $u.Name 'utente' }
    Registra $env:USERNAME 'utente'
}

# --- impalcatura -------------------------------------------------------------

function Usa { param([string]$S) return ($Sezioni -contains $S) }
function Sep { param([string]$T) ''; '============================================================'; "== $T"; '============================================================' }
function Tab { param($Dati) if ($Dati) { $Dati | Format-Table -AutoSize | Out-String -Width 200 } else { '  nessun dato' } }
function Lis { param($Dati) if ($Dati) { $Dati | Format-List | Out-String -Width 200 } else { '  nessun dato' } }

$amministratore = $false
try {
    $identita = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principale = New-Object Security.Principal.WindowsPrincipal($identita)
    $amministratore = $principale.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { }

# --- corpo -------------------------------------------------------------------

function Corpo {

$cs = Get-CimInstance Win32_ComputerSystem  -ErrorAction SilentlyContinue
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

$nomeMacchina = if ($Etichetta)             { $Etichetta }
                elseif ($Anonimo -and $cs)  { Pseudonimo $cs.Name 'host' }
                elseif ($cs)                { $cs.Name }
                else                        { $env:COMPUTERNAME }

'============================================================'
'== CENSIMENTO HARDWARE'
'============================================================'
"strumento  : hw-report-windows.ps1 v$VERSIONE (windows-status, scripts/censimento)"
'piattaforma: Windows'
"macchina   : $nomeMacchina"
"data       : $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')"
"modo       : $(if ($Anonimo) { 'anonimo (pseudonimi stabili; -Identificativi per il chiaro)' } else { 'IDENTIFICATIVI IN CHIARO - contiene dati reali, non versionare' })"
"privilegi  : $(if ($amministratore) { 'amministratore (censimento completo)' } else { 'utente standard (PARZIALE: mancano seriali dei banchi e affidabilita dei dischi)' })"
"sezioni    : $($Sezioni -join ', ')"
'nota       : sicurezza, licenze, software e account non stanno qui: dentro il'
'             perimetro del progetto li copre scripts\Snapshot-Stato.ps1'

if (Usa 'IDENTITA') {
    Sep 'IDENTITA'
    "hostname   : $(if ($cs) { $cs.Name } else { $env:COMPUTERNAME })"
    "dominio    : $(if ($cs) { $cs.Domain } else { '-' })"
    "ruolo rete : $(if ($cs -and $cs.PartOfDomain) { 'unita a dominio' } else { 'gruppo di lavoro' })"
    "OS         : $(if ($os) { "$($os.Caption) build $($os.BuildNumber)" } else { '-' })"
    $dv = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion
    "versione   : $dv"
    "arch       : $(if ($os) { $os.OSArchitecture } else { $env:PROCESSOR_ARCHITECTURE })"
    "installato : $(if ($os) { $os.InstallDate } else { '-' })"
    "ultimo boot: $(if ($os) { $os.LastBootUpTime } else { '-' })"
    if ($os -and $os.LastBootUpTime) {
        $up = (Get-Date) - $os.LastBootUpTime
        "uptime     : $([int]$up.TotalDays)g $($up.Hours)h $($up.Minutes)m"
    }
    "firmware   : $(if ($env:firmware_type) { $env:firmware_type } elseif (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State') { 'UEFI' } else { 'BIOS/Legacy o non determinabile' })"
    "PowerShell : $($PSVersionTable.PSVersion)"
}

if (Usa 'SISTEMA') {
    Sep 'SISTEMA / SCHEDA MADRE / FIRMWARE'
    Lis ($cs | Select-Object Manufacturer, Model, SystemFamily, SystemSKUNumber)
    '--- prodotto ---'
    Lis (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue |
         Select-Object Name, Vendor, Version, IdentifyingNumber, UUID)
    '--- scheda madre ---'
    Lis (Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue |
         Select-Object Manufacturer, Product, Version, SerialNumber)
    '--- firmware ---'
    Lis (Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue |
         Select-Object Manufacturer, SMBIOSBIOSVersion, ReleaseDate, SerialNumber)
    '--- telaio ---'
    Lis (Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue |
         Select-Object ChassisTypes, SerialNumber)
}

if (Usa 'CPU') {
    Sep 'CPU'
    Lis (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object Name, Manufacturer,
         NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed, CurrentClockSpeed,
         L2CacheSize, L3CacheSize, SocketDesignation, ProcessorId, AddressWidth)
    '--- virtualizzazione ---'
    $cpu0 = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    "VT-x/AMD-V abilitata nel firmware : $(if ($cpu0) { $cpu0.VirtualizationFirmwareEnabled } else { '-' })"
    "hypervisor presente               : $(if ($cs) { $cs.HypervisorPresent } else { '-' })"
}

if (Usa 'MEMORIA') {
    Sep 'MEMORIA'
    if ($cs) { "totale installata : $([math]::Round($cs.TotalPhysicalMemory/1GB,2)) GB" }
    if ($os) { "libera ora        : $([math]::Round($os.FreePhysicalMemory/1MB,2)) GB" }
    '--- banchi ---'
    Tab (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Select-Object DeviceLocator, BankLabel,
         @{N='GB';E={[math]::Round($_.Capacity/1GB,0)}},
         @{N='Tipo';E={switch ($_.SMBIOSMemoryType) {20{'DDR'}21{'DDR2'}24{'DDR3'}26{'DDR4'}34{'DDR5'}default{"code $($_.SMBIOSMemoryType)"}}}},
         Speed, ConfiguredClockSpeed, Manufacturer, PartNumber, SerialNumber)
    '--- slot ---'
    $pma = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pma) {
        "slot totali        : $($pma.MemoryDevices)"
        "slot occupati      : $(@(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue).Count)"
        "massimo supportato : $([math]::Round($pma.MaxCapacity/1MB,0)) GB"
    } else { '  non esposto dal firmware' }
}

if (Usa 'DISCHI') {
    Sep 'DISCHI'
    $pd = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    if ($pd.Count -gt 0) {
        Tab ($pd | Select-Object DeviceId, FriendlyName, MediaType, BusType,
             @{N='GB';E={[math]::Round($_.Size/1GB,1)}}, SerialNumber, FirmwareVersion, HealthStatus)
    } else {
        '  Get-PhysicalDisk non disponibile: ripiego su Win32_DiskDrive'
        Tab (Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object Index, Model, InterfaceType,
             @{N='GB';E={[math]::Round($_.Size/1GB,1)}}, SerialNumber, FirmwareRevision)
    }
    '--- geometria ---'
    Tab (Get-Disk -ErrorAction SilentlyContinue | Select-Object Number, FriendlyName, PartitionStyle,
         @{N='GB';E={[math]::Round($_.Size/1GB,1)}}, BusType, IsBoot, IsSystem)
    '--- volumi ---'
    Tab (Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter } |
         Select-Object DriveLetter, FileSystemLabel, FileSystem,
         @{N='TotGB';E={[math]::Round($_.Size/1GB,1)}},
         @{N='LiberiGB';E={[math]::Round($_.SizeRemaining/1GB,1)}}, HealthStatus)
    '--- affidabilita (richiede amministratore) ---'
    if ($pd.Count -gt 0) {
        foreach ($d in $pd) {
            "### $($d.FriendlyName) (DeviceId $($d.DeviceId))"
            try {
                Lis ($d | Get-StorageReliabilityCounter -ErrorAction Stop |
                     Select-Object Wear, PowerOnHours, Temperature, ReadErrorsTotal, WriteErrorsTotal)
            } catch { '  contatori non disponibili (privilegi, oppure disco che non li espone)' }
        }
    }
}

if (Usa 'RETE') {
    Sep 'RETE'
    $na = @(Get-NetAdapter -ErrorAction SilentlyContinue)
    if ($na.Count -gt 0) {
        Tab ($na | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress, DriverVersion)
    } else {
        '  Get-NetAdapter non disponibile: ripiego su Win32_NetworkAdapter'
        Tab (Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue |
             Where-Object { $_.PhysicalAdapter } | Select-Object Name, NetConnectionID, MACAddress, Speed)
    }
    '--- indirizzi ---'
    Tab (Get-NetIPAddress -ErrorAction SilentlyContinue |
         Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -ne '::1' } |
         Select-Object InterfaceAlias, AddressFamily, IPAddress, PrefixLength)
    '--- rotta di default ---'
    Tab (Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
         Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } | Select-Object InterfaceAlias, NextHop)
    '--- DNS ---'
    Tab (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
         Where-Object { $_.ServerAddresses } |
         Select-Object InterfaceAlias, @{N='ServerAddresses';E={$_.ServerAddresses -join ', '}})
}

if (Usa 'GPU') {
    Sep 'GPU / VIDEO'
    Lis (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name, VideoProcessor,
         @{N='VRAM_GB';E={[math]::Round($_.AdapterRAM/1GB,2)}}, DriverVersion, DriverDate,
         CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate)
}

if (Usa 'PERIFERICHE') {
    Sep 'BUS E PERIFERICHE'
    '--- slot di sistema ---'
    Tab (Get-CimInstance Win32_SystemSlot -ErrorAction SilentlyContinue |
         Select-Object SlotDesignation, CurrentUsage, MaxDataWidth)
    '--- controller storage ---'
    Tab (Get-CimInstance Win32_SCSIController -ErrorAction SilentlyContinue | Select-Object Name, DriverName)
    '--- controller USB ---'
    Tab (Get-CimInstance Win32_USBController -ErrorAction SilentlyContinue | Select-Object Name, Manufacturer)
    '--- monitor collegati ---'
    Tab (Get-CimInstance Win32_DesktopMonitor -ErrorAction SilentlyContinue |
         Select-Object Name, ScreenWidth, ScreenHeight)
    '--- lettori ottici ---'
    Tab (Get-CimInstance Win32_CDROMDrive -ErrorAction SilentlyContinue | Select-Object Name, Drive, MediaType)
}

if (Usa 'ALIMENTAZIONE') {
    Sep 'ALIMENTAZIONE / TERMICO'
    $bat = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    if ($bat.Count -gt 0) { Tab ($bat | Select-Object Name, EstimatedChargeRemaining, BatteryStatus) }
    else                  { '  nessuna batteria: macchina fissa, oppure non esposta' }
    '--- temperature ACPI ---'
    try {
        Tab (Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
             Select-Object InstanceName, @{N='TempC';E={[math]::Round(($_.CurrentTemperature-2732)/10,1)}})
    } catch { '  temperature ACPI non esposte da questo firmware' }
}

if (Usa 'SOFTWARE') {
    Sep 'CONTESTO SOFTWARE'
    'Sezione opzionale, per macchine FUORI dal perimetro del progetto.'
    'Dentro il perimetro la copre scripts\Snapshot-Stato.ps1, con lo storico.'
    if ($Pattern) { "filtro     : $Pattern" }
    '--- servizi in esecuzione ---'
    $srv = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' })
    "in esecuzione : $($srv.Count)"
    if ($Pattern) {
        Tab ($srv | Where-Object { $_.Name -match $Pattern -or $_.DisplayName -match $Pattern } |
             Select-Object Name, DisplayName)
    }
    '--- porte in ascolto ---'
    Tab (Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
         Select-Object LocalAddress, LocalPort,
         @{N='Processo';E={(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}} |
         Sort-Object LocalPort -Unique)
    '--- programmi installati ---'
    $prg = @(Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                              'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
             Where-Object { $_.DisplayName })
    "totale        : $($prg.Count)"
    if ($Pattern) {
        Tab ($prg | Where-Object { $_.DisplayName -match $Pattern } |
             Select-Object DisplayName, DisplayVersion, Publisher | Sort-Object DisplayName)
    }
    '--- account locali abilitati ---'
    Tab (Get-LocalUser -ErrorAction SilentlyContinue | Where-Object { $_.Enabled } | Select-Object Name, LastLogon)
}

Sep 'FINE'
}

# --- esecuzione --------------------------------------------------------------

RaccogliIdentificativi
$testo = Sanifica ((& { Corpo } | Out-String -Width 200))

if ($StdOut) { $testo; return }

$nome = if ($Etichetta)   { $Etichetta }
        elseif ($Anonimo) { (Pseudonimo $env:COMPUTERNAME 'host').Trim('<', '>') }
        else              { $env:COMPUTERNAME }
$nome = ($nome -replace '[^A-Za-z0-9_.-]', '-')
$predefinito = "hw-$nome-$(Get-Date -Format 'yyyyMMdd').txt"

if (-not $Destinazione) {
    $percorso = Join-Path (Get-Location).Path $predefinito
} elseif (Test-Path $Destinazione -PathType Container) {
    $percorso = Join-Path $Destinazione $predefinito
} else {
    $percorso = $Destinazione
}

$cartella = Split-Path $percorso -Parent
if ($cartella -and -not (Test-Path $cartella)) { New-Item -ItemType Directory -Path $cartella -Force | Out-Null }

# UTF-8 senza BOM e fine riga LF, lo stesso formato del gemello Linux: una
# redirezione con > avrebbe prodotto UTF-16, illeggibile come testo altrove.
[System.IO.File]::WriteAllText($percorso, ($testo -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))

"Censimento scritto in: $percorso"
if (-not $Anonimo)        { 'ATTENZIONE: output con identificativi reali. Non versionarlo e non condividerlo senza valutarlo.' }
if (-not $amministratore) { "Nota: eseguito senza privilegi di amministratore, il censimento e' parziale." }
