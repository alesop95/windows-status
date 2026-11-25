# =============================================================================
#  Espelli-Supporto.ps1  -  chi tiene occupato un disco USB, e poi l'espulsione
#  windows-status. Vedi docs\18, paragrafo sull'espulsione negata.
# =============================================================================
#  IL PROBLEMA. "Rimozione sicura" risponde "Dispositivo attualmente in uso" e
#  non dice da chi. Chi stacca lo stesso lascia un volume exFAT o FAT32 segnato
#  come da riparare, e su un disco di backup questo ferma i backup successivi.
#
#  COSA FA, senza parametri (sola lettura):
#    1  risale dalla lettera al dispositivo USB che Windows espelle davvero;
#    2  elenca i processi con file o cartelle aperti sulla lettera. Da utente
#       vede solo i propri processi; da amministratore anche i servizi, tranne
#       quelli protetti dal sistema (antivirus, kernel);
#    3  cerca i colpevoli ricorrenti che l'elenco non puo' vedere: finestre di
#       Esplora aperte sulla lettera, job di Veeam Agent in corso, client di
#       sincronizzazione accesi;
#    4  rilegge dal registro eventi gli ultimi rifiuti per quel dispositivo, con
#       il processo che Windows ha nominato (evento Kernel-PnP 225) o il motivo
#       (evento Kernel-PnP/Device Management 1000).
#
#  CON -Espelli chiede a Windows l'espulsione con la stessa chiamata della
#  "Rimozione sicura" (CM_Request_Device_Eject), che a differenza della finestra
#  restituisce il motivo del rifiuto. Non stacca nulla con la forza.
#
#  CON -Espelli -ChiudiInnocui, prima di espellere chiude, dopo conferma SI,
#  solo cio' che si puo' chiudere senza perdere lavoro: le finestre di Esplora
#  aperte sulla lettera e i COM Surrogate (dllhost.exe, le anteprime di Esplora)
#  che hanno un handle sulla lettera. Nient'altro: un editor, un terminale o un
#  servizio li chiude chi li usa (paletto 1).
#
#  USO
#    .\Espelli-Supporto.ps1                       # diagnosi su J:
#    .\Espelli-Supporto.ps1 -Lettera K            # un'altra lettera
#    .\Espelli-Supporto.ps1 -Espelli              # diagnosi poi espulsione
#    .\Espelli-Supporto.ps1 -Espelli -ChiudiInnocui
# =============================================================================

[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z]$')]
    [string] $Lettera = 'J',
    [switch] $Espelli,
    [switch] $ChiudiInnocui,
    # Ore di registro eventi in cui cercare i rifiuti precedenti.
    [int]    $Ore = 24
)

$ErrorActionPreference = 'Stop'
$Lettera = $Lettera.ToUpper()
$radice  = "${Lettera}:\"

function Titolo { param([string]$T) Write-Host ''; Write-Host "  $T" -ForegroundColor Cyan }
function Ok     { param([string]$T) Write-Host "  [ok]      $T" -ForegroundColor Green }
function Info   { param([string]$T) Write-Host "  [info]    $T" }
function Avviso { param([string]$T) Write-Host "  [attenzione] $T" -ForegroundColor Yellow }
function Stop_  { param([string]$T) Write-Host "  [fermo]   $T" -ForegroundColor Red }

function Conferma {
    param([string]$Domanda)
    Write-Host ''
    Write-Host "  $Domanda" -ForegroundColor Yellow
    return ((Read-Host '  Digita SI per procedere, qualunque altra cosa per saltare') -eq 'SI')
}

$amministratore = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class SupportoUsb {
    [StructLayout(LayoutKind.Sequential)]
    struct VOCE { public IntPtr Oggetto; public IntPtr Pid; public IntPtr Handle; public uint Accesso;
                  public ushort Creatore; public ushort Tipo; public uint Attributi; public uint Riservato; }
    [StructLayout(LayoutKind.Sequential)]
    struct LUID { public uint Basso; public int Alto; }
    [StructLayout(LayoutKind.Sequential)]
    struct PRIVILEGIO { public uint Conteggio; public LUID Luid; public uint Attributi; }

    [DllImport("ntdll.dll")] static extern int NtQuerySystemInformation(int c, IntPtr b, int l, out int r);
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint a, bool i, int p);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool DuplicateHandle(IntPtr sp, IntPtr sh, IntPtr tp, out IntPtr th, uint a, bool i, uint o);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] static extern uint GetFileType(IntPtr h);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] static extern uint GetFinalPathNameByHandle(IntPtr h, StringBuilder s, uint n, uint f);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr p, uint a, out IntPtr t);
    [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool LookupPrivilegeValue(string s, string n, out LUID l);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr t, bool d, ref PRIVILEGIO n, int l, IntPtr p, IntPtr r);
    [DllImport("cfgmgr32.dll", CharSet=CharSet.Unicode)] static extern int CM_Locate_DevNodeW(out uint d, string id, uint f);
    [DllImport("cfgmgr32.dll", CharSet=CharSet.Unicode)] static extern int CM_Request_Device_EjectW(uint d, out int veto, StringBuilder nome, int len, uint f);

    // Da amministratore il privilegio di debug apre anche i processi dei
    // servizi. Quelli protetti dal sistema restano chiusi comunque.
    public static bool AbilitaDebug() {
        IntPtr t;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out t)) return false;
        try {
            PRIVILEGIO p = new PRIVILEGIO(); p.Conteggio = 1; p.Attributi = 2;
            if (!LookupPrivilegeValue(null, "SeDebugPrivilege", out p.Luid)) return false;
            return AdjustTokenPrivileges(t, false, ref p, 0, IntPtr.Zero, IntPtr.Zero) && Marshal.GetLastWin32Error() == 0;
        } finally { CloseHandle(t); }
    }

    // Righe "pid<TAB>percorso" degli handle di file o cartella sotto il prefisso.
    public static List<string> Handle(string prefisso) {
        var res = new List<string>();
        int len = 1 << 20, ret; IntPtr buf;
        while (true) {
            buf = Marshal.AllocHGlobal(len);
            int st = NtQuerySystemInformation(64, buf, len, out ret);
            if (st == unchecked((int)0xC0000004)) { Marshal.FreeHGlobal(buf); len = Math.Max(len * 2, ret + 65536); continue; }
            if (st != 0) { Marshal.FreeHGlobal(buf); throw new Exception("NtQuerySystemInformation 0x" + st.ToString("X")); }
            break;
        }
        try {
            long n = Marshal.ReadIntPtr(buf).ToInt64();
            int dim = Marshal.SizeOf(typeof(VOCE));
            IntPtr p = buf + IntPtr.Size * 2;
            var proc = new Dictionary<int, IntPtr>();
            IntPtr io = GetCurrentProcess();
            for (long i = 0; i < n; i++) {
                var e = (VOCE)Marshal.PtrToStructure(p + (int)(i * dim), typeof(VOCE));
                int pid = (int)e.Pid.ToInt64();
                // Maschere di accesso tipiche delle pipe sincrone: leggerne il nome
                // puo' bloccare il thread per sempre, quindi si saltano.
                if (e.Accesso == 0x0012019f || e.Accesso == 0x001a019f || e.Accesso == 0x00120189 || e.Accesso == 0x00100000) continue;
                IntPtr hp;
                if (!proc.TryGetValue(pid, out hp)) { hp = OpenProcess(0x40, false, pid); proc[pid] = hp; }
                if (hp == IntPtr.Zero) continue;
                IntPtr dup;
                if (!DuplicateHandle(hp, e.Handle, io, out dup, 0, false, 2)) continue;
                try {
                    if (GetFileType(dup) != 1) continue;
                    var sb = new StringBuilder(1024);
                    if (GetFinalPathNameByHandle(dup, sb, 1024, 0) == 0) continue;
                    string s = sb.ToString();
                    if (s.StartsWith(@"\\?\")) s = s.Substring(4);
                    if (s.StartsWith(prefisso, StringComparison.OrdinalIgnoreCase)) res.Add(pid + "\t" + s);
                } finally { CloseHandle(dup); }
            }
            foreach (var h in proc.Values) if (h != IntPtr.Zero) CloseHandle(h);
        } finally { Marshal.FreeHGlobal(buf); }
        return res;
    }

    // 0 = espulso. Altrimenti codice CONFIGRET, con tipo e nome del veto.
    public static int Espelli(string istanza, out int veto, out string nome) {
        veto = 0; nome = "";
        uint d;
        int cr = CM_Locate_DevNodeW(out d, istanza, 0);
        if (cr != 0) return cr;
        var sb = new StringBuilder(512);
        cr = CM_Request_Device_EjectW(d, out veto, sb, sb.Capacity, 0);
        nome = sb.ToString();
        return cr;
    }
}
'@

# Tipi di veto di PNP_VETO_TYPE, come li restituisce Windows.
$Veti = @{
    1 = 'motivo non indicato'; 2 = 'dispositivo legacy'; 3 = 'chiusura in sospeso'
    4 = 'un''applicazione'; 5 = 'un servizio di Windows'
    6 = 'handle ancora aperti sul volume'
    7 = 'un altro dispositivo'; 8 = 'un driver'; 9 = 'richiesta non valida'
    10 = 'alimentazione insufficiente'; 11 = 'dispositivo non disattivabile'
    12 = 'driver legacy'; 13 = 'permessi insufficienti'; 14 = 'gia'' rimosso'
}

# --- 1. dalla lettera al dispositivo USB -------------------------------------

function Get-DispositivoUsb {
    # Lettera -> partizione -> disco attraverso Win32 (CIM), non il provider
    # Storage: quello si pianta se un qualunque disco della macchina non
    # risponde (docs\18), e qui si sta proprio diagnosticando un disco.
    $logico = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${Lettera}:'" -ErrorAction SilentlyContinue
    if (-not $logico) { return $null }
    $part  = Get-CimAssociatedInstance -InputObject $logico -ResultClassName Win32_DiskPartition -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $part) { return $null }
    $disco = Get-CimAssociatedInstance -InputObject $part -ResultClassName Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $disco) { return $null }
    $padre = $null
    try { $padre = [string](Get-PnpDeviceProperty -InstanceId $disco.PNPDeviceID -KeyName DEVPKEY_Device_Parent -ErrorAction Stop).Data } catch { }
    [pscustomobject]@{
        Modello    = $disco.Model
        Interfaccia= $disco.InterfaceType
        Disco      = $disco.PNPDeviceID
        Usb        = $padre
        FileSystem = $logico.FileSystem
        Volume     = $logico.VolumeName
    }
}

# --- 2. handle aperti --------------------------------------------------------

function Get-HandleSuLettera {
    $righe = @([SupportoUsb]::Handle($radice))
    $righe | ForEach-Object {
        $pid_, $percorso = $_ -split "`t", 2
        $p = Get-Process -Id ([int]$pid_) -ErrorAction SilentlyContinue
        [pscustomobject]@{ PID = [int]$pid_; Processo = $p.ProcessName; Percorso = $percorso }
    } | Sort-Object Processo, PID, Percorso -Unique
}

# --- 3. colpevoli ricorrenti -------------------------------------------------

function Get-FinestreEsplora {
    $uri = "file:///${Lettera}:"
    try {
        @((New-Object -ComObject Shell.Application).Windows() | Where-Object {
            $_.LocationURL -and $_.LocationURL.StartsWith($uri, [StringComparison]::OrdinalIgnoreCase)
        })
    } catch { @() }
}

function Get-Sospetti {
    $s = @()
    if (Get-Process VeeamAgent -ErrorAction SilentlyContinue) {
        $s += 'Veeam Agent ha un job in corso (VeeamAgent.exe attivo). Se il job salva anche questo volume lo tiene aperto fino alla fine, unione degli incrementali compresa. Aspetta la fine del job, ed escludi il disco esterno dal job se non va salvato.'
    }
    if (Get-Process GoogleDriveFS -ErrorAction SilentlyContinue) {
        $s += 'Google Drive e'' acceso: se sincronizza una cartella su questa lettera la tiene aperta. Mettilo in pausa o chiudilo.'
    }
    foreach ($n in 'OneDrive', 'Dropbox', 'MEGAsync') {
        if (Get-Process $n -ErrorAction SilentlyContinue) {
            $s += "$n e' acceso: blocca l'espulsione solo se sincronizza qualcosa su questa lettera."
        }
    }
    if (Get-Service WSearch -ErrorAction SilentlyContinue | Where-Object Status -eq 'Running') {
        $s += 'Windows Search e'' attivo: se il volume e'' tra i percorsi indicizzati, lo legge dopo ogni scrittura grossa. Si toglie da Opzioni di indicizzazione.'
    }
    $s
}

# --- 4. rifiuti precedenti ---------------------------------------------------

function Get-RifiutiRecenti {
    param([string]$Usb)
    if (-not $Usb) { return @() }
    $dal = (Get-Date).AddHours(-$Ore)
    $out = @()
    try {
        $out += @(Get-WinEvent -ErrorAction Stop -FilterHashtable @{
            LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-PnP'; Id = 225; StartTime = $dal
        } | Where-Object { [string]$_.Properties[4].Value -eq $Usb } | ForEach-Object {
            # [2] e' l'eseguibile, [4] il dispositivo: dai dati dell'evento,
            # non dal testo, che e' tradotto nella lingua di Windows.
            [pscustomobject]@{ Quando = $_.TimeCreated; Chi = "processo: $([string]$_.Properties[2].Value)" }
        })
    } catch { }
    try {
        $out += @(Get-WinEvent -ErrorAction Stop -FilterHashtable @{
            LogName = 'Microsoft-Windows-Kernel-PnP/Device Management'; Id = 1000; StartTime = $dal
        } | Where-Object { [string]$_.Properties[0].Value -eq $Usb } | ForEach-Object {
            $tipo = [int]$_.Properties[1].Value
            $motivo = if ($Veti.ContainsKey($tipo)) { $Veti[$tipo] } else { "veto $tipo" }
            [pscustomobject]@{ Quando = $_.TimeCreated; Chi = "$motivo - $([string]$_.Properties[2].Value)" }
        })
    } catch { }
    $out | Sort-Object Quando
}

# --- esecuzione --------------------------------------------------------------

Titolo "SUPPORTO ${Lettera}: - chi lo tiene occupato"

$dev = Get-DispositivoUsb
if (-not $dev) { Stop_ "Nessun disco con lettera ${Lettera}: collegato."; return }
Info "disco     : $($dev.Modello)  ($($dev.Interfaccia), $($dev.FileSystem), etichetta '$($dev.Volume)')"
if ($dev.Usb -like 'USB\*') { Info "dispositivo USB: $($dev.Usb)" }
else { Avviso "il disco non risulta appeso a un dispositivo USB ($($dev.Usb)): l'espulsione potrebbe non essere possibile" }

if ($amministratore) {
    if ([SupportoUsb]::AbilitaDebug()) { Ok 'amministratore: si vedono anche i servizi (non quelli protetti dal sistema)' }
    else { Avviso 'amministratore, ma il privilegio di debug non si e'' attivato: si vedono solo i processi apribili' }
} else {
    Avviso 'utente normale: si vedono solo i tuoi processi. Da amministratore si vedono anche i servizi.'
}

$handle = @(Get-HandleSuLettera)
Titolo 'Handle aperti sulla lettera'
if ($handle.Count -eq 0) { Ok 'nessuno fra i processi visibili' }
else { $handle | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Write-Host }

$finestre = @(Get-FinestreEsplora)
Titolo 'Finestre di Esplora sulla lettera'
if ($finestre.Count -eq 0) { Ok 'nessuna' }
else { $finestre | ForEach-Object { Avviso ([uri]::UnescapeDataString($_.LocationURL)) } }

Titolo 'Colpevoli ricorrenti attivi adesso'
$sospetti = @(Get-Sospetti)
if ($sospetti.Count -eq 0) { Ok 'nessuno' } else { $sospetti | ForEach-Object { Avviso $_ } }

Titolo "Rifiuti di espulsione nelle ultime $Ore ore"
$rifiuti = @(Get-RifiutiRecenti $dev.Usb)
if ($rifiuti.Count -eq 0) { Ok 'nessuno' }
else { $rifiuti | ForEach-Object { Info ("{0:dd/MM HH:mm:ss}  {1}" -f $_.Quando, $_.Chi) } }

if (-not $Espelli) {
    Write-Host ''
    Info 'Solo diagnosi, niente toccato. Per espellere: -Espelli (aggiungi -ChiudiInnocui per'
    Info 'chiudere prima le finestre di Esplora e le anteprime che tengono la lettera).'
    return
}

if ($ChiudiInnocui) {
    $surrogati = @($handle | Where-Object { $_.Processo -eq 'dllhost' } | Select-Object -ExpandProperty PID -Unique)
    if ($finestre.Count -gt 0 -or $surrogati.Count -gt 0) {
        Titolo 'Chiusura di cio'' che non contiene lavoro'
        Info "finestre di Esplora da chiudere: $($finestre.Count)"
        Info "COM Surrogate (dllhost) da terminare: $($surrogati -join ', ')"
        if (Conferma 'Chiudo queste finestre e questi processi?') {
            foreach ($f in $finestre) { try { $f.Quit() } catch { } }
            foreach ($id in $surrogati) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
            Start-Sleep -Milliseconds 800
            Ok 'fatto'
        } else { Info 'niente chiuso' }
    } else { Info 'niente di innocuo da chiudere' }
}

Titolo 'Espulsione'
if (-not ($dev.Usb -like 'USB\*')) { Stop_ 'dispositivo USB non individuato: espulsione non tentata'; return }
$veto = 0; $nome = ''
$cr = [SupportoUsb]::Espelli($dev.Usb, [ref]$veto, [ref]$nome)
if ($cr -eq 0) {
    Ok "espulso: ora puoi staccare il cavo."
    return
}
$motivo = if ($Veti.ContainsKey($veto)) { $Veti[$veto] } else { "veto $veto" }
Stop_ "Windows ha rifiutato l'espulsione (codice 0x$($cr.ToString('X'))): $motivo"
if ($nome) { Info "  da: $nome" }
Info 'NON staccare il cavo: il volume resterebbe da riparare. Togli la causa e rilancia.'
if (-not $amministratore -and $handle.Count -eq 0) {
    Info 'Nessun tuo processo tiene la lettera: rilancia da amministratore per vedere i servizi.'
}
