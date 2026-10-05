<#
================================================================================
 Campiona-Vincolata.ps1  —  Campionatore di SOLA LETTURA della memoria vincolata
================================================================================
 SCOPO
   Individuare chi trattiene la memoria vincolata (commit) che non risulta in
   nessun processo. Ogni esecuzione aggiunge una riga di totali e le righe dei
   processi piu' grandi a due CSV; confrontando i campioni nel tempo, il processo
   che cresce allo stesso ritmo della quota "non attribuita" e' il detentore.
   Vedi docs\07_SALUTE_E_STABILITA.md, sezione 2d.

 COSA MISURA
   Totali: vincolata, limite, commit privato dei processi, pool, quota non
   attribuita (vincolata - processi - pool), uptime, handle totali.
   Per processo: commit privato, byte committed delle regioni mappate
   (MEM_MAPPED, via VirtualQueryEx) e numero di handle.

 GARANZIE
   - Senza parametri legge soltanto e scrive in snapshots\vincolata\ (ignorata da git).
   - L'UNICA parte che modifica il sistema e' -Installa / -Disinstalla
     dell'attivita pianificata (serve admin, reversibile).
   - I processi protetti (es. antimalware) restano illeggibili anche come SYSTEM:
     di quelli si registrano solo commit privato e handle.

 USO
   .\Campiona-Vincolata.ps1               # un campione (sola lettura)
   .\Campiona-Vincolata.ps1 -Installa     # campione ogni 15 minuti come SYSTEM (admin)
   .\Campiona-Vincolata.ps1 -Disinstalla  # rimuove l'attivita (admin)
================================================================================
#>
param(
    [int]$Top = 25,
    [int]$IntervalloMinuti = 15,
    [switch]$Installa,
    [switch]$Disinstalla
)

$ErrorActionPreference = 'Stop'
$base     = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj     = Split-Path -Parent $base
$me       = $MyInvocation.MyCommand.Path
$taskName = 'windows-status Campionamento vincolata'
$isAdmin  = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ----------------------------------------------------------------------------
#  Installazione / rimozione dell'attivita pianificata (unica parte che MODIFICA)
# ----------------------------------------------------------------------------
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
    try {
        $arg     = "-NoProfile -ExecutionPolicy Bypass -File `"$me`" -Top $Top"
        $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalloMinuti)
        $princ   = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
        $set     = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $princ -Settings $set `
            -Description 'Campionamento della memoria vincolata di windows-status (sola lettura). Reversibile: Campiona-Vincolata.ps1 -Disinstalla.' -Force | Out-Null
        Write-Host "Attivita '$taskName' INSTALLATA (ogni $IntervalloMinuti minuti, come SYSTEM)." -ForegroundColor Green
        Write-Host 'Reversibile con: .\scripts\Campiona-Vincolata.ps1 -Disinstalla'
        Write-Host 'I campioni vanno in snapshots\vincolata\ (ignorata da git).'
    } catch { Write-Host "Errore nella creazione dell'attivita: $_" -ForegroundColor Red }
    return
}

# ----------------------------------------------------------------------------
#  Campione (sola lettura)
# ----------------------------------------------------------------------------
$outDir = Join-Path $proj 'snapshots\vincolata'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (-not ('VQ.Scan' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace VQ {
  [StructLayout(LayoutKind.Sequential)]
  public struct MBI { public IntPtr BaseAddress; public IntPtr AllocationBase; public uint AllocationProtect; public ushort PartitionId; public IntPtr RegionSize; public uint State; public uint Protect; public uint Type; }
  public static class Scan {
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint a, bool i, int pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] static extern IntPtr VirtualQueryEx(IntPtr h, IntPtr addr, out MBI m, IntPtr len);
    // Byte committed delle regioni MEM_MAPPED; -1 se il processo non e' leggibile.
    public static long Mapped(int pid) {
      IntPtr h = OpenProcess(0x0400 | 0x0010, false, pid);
      if (h == IntPtr.Zero) { h = OpenProcess(0x1000 | 0x0010, false, pid); }
      if (h == IntPtr.Zero) return -1;
      long mapped = 0, addr = 0; MBI m; int sz = Marshal.SizeOf(typeof(MBI));
      try {
        while (VirtualQueryEx(h, new IntPtr(addr), out m, new IntPtr(sz)) != IntPtr.Zero) {
          long rs = m.RegionSize.ToInt64();
          if (m.State == 0x1000 && m.Type == 0x40000) mapped += rs;
          long next = m.BaseAddress.ToInt64() + rs; if (next <= addr) break; addr = next;
        }
      } finally { CloseHandle(h); }
      return mapped;
    }
  }
}
'@
}

$t     = Get-Date
$m     = Get-CimInstance Win32_PerfRawData_PerfOS_Memory
$os    = Get-CimInstance Win32_OperatingSystem
$procs = Get-Process
$righe = foreach ($p in $procs) {
    $map = [VQ.Scan]::Mapped($p.Id)
    [pscustomobject]@{
        Ora       = $t.ToString('s'); Nome = $p.ProcessName; PID = $p.Id; Handle = $p.HandleCount
        PrivatoMB = [math]::Round($p.PagedMemorySize64/1MB)
        MappatoMB = if($map -ge 0){ [math]::Round($map/1MB) } else { $null }
    }
}
$priv   = ($procs | Measure-Object PagedMemorySize64 -Sum).Sum
$mapTot = ($righe | Where-Object MappatoMB -ne $null | Measure-Object MappatoMB -Sum).Sum
$tot = [pscustomobject]@{
    Ora                  = $t.ToString('s')
    UptimeOre            = [math]::Round(($t - $os.LastBootUpTime).TotalHours, 2)
    VincolataGB          = [math]::Round($m.CommittedBytes/1GB, 2)
    LimiteGB             = [math]::Round($m.CommitLimit/1GB, 2)
    PrivatoProcessiGB    = [math]::Round($priv/1GB, 2)
    PoolPGB              = [math]::Round($m.PoolPagedBytes/1GB, 2)
    PoolNPGB             = [math]::Round($m.PoolNonpagedBytes/1GB, 2)
    NonAttribuitaGB      = [math]::Round(($m.CommittedBytes - $priv - $m.PoolPagedBytes - $m.PoolNonpagedBytes)/1GB, 2)
    MappatoVisibileGB    = [math]::Round($mapTot/1KB, 2)
    ProcessiNonLeggibili = ($righe | Where-Object MappatoMB -eq $null).Count
    HandleTotali         = ($procs | Measure-Object HandleCount -Sum).Sum
    Admin                = $isAdmin
}
$tot | Export-Csv (Join-Path $outDir 'totali.csv') -Append -NoTypeInformation -Encoding UTF8
# Due classifiche per campione: per memoria mappata e per handle (un processo puo' comparire in entrambe).
$righe | Sort-Object MappatoMB -Descending | Select-Object -First $Top | Export-Csv (Join-Path $outDir 'processi.csv') -Append -NoTypeInformation -Encoding UTF8
$righe | Sort-Object Handle -Descending    | Select-Object -First $Top | Export-Csv (Join-Path $outDir 'processi.csv') -Append -NoTypeInformation -Encoding UTF8
$tot
