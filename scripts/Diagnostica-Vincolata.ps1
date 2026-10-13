<#
================================================================================
 Diagnostica-Vincolata.ps1  -  Chi trattiene la memoria vincolata che cresce
================================================================================
 SCOPO
   Interpreta la serie raccolta da Campiona-Vincolata.ps1 e risponde a tre
   domande: a che ritmo cresce la vincolata che non appartiene a nessun
   processo, quale processo la trattiene, e fra quanti giorni il sistema
   arriva al limite. Il detentore si cerca fra i processi i cui handle
   crescono insieme alla quota non attribuita, e si conferma misurando
   direttamente le sezioni di memoria che quei handle tengono vive.
   Vedi docs\13_MEMORIA_VINCOLATA_HANDLE_LEAK.md.

 COME DECIDE
   - Avvii separati dove l'uptime si azzera; per ognuno: regressione della
     quota non attribuita sul tempo (GB/giorno).
   - Per ogni processo presente in almeno l'80% dei campioni dell'avvio, con
     almeno 1.000 handle di crescita: correlazione di Pearson fra i suoi
     handle e la quota non attribuita, e pendenza in KB per handle.
   - Qualunque grandezza che cresce col tempo correla con una quota che cresce
     col tempo: per questo il sospetto deve superare la soglia in OGNI avvio
     valido, e la sua pendenza deve restare stabile fra un avvio e l'altro.
   - Conferma indipendente (admin): duplica gli handle di tipo Section del
     sospetto, ne legge la dimensione con NtQuerySection e somma quelle non
     appoggiate a file. Quella somma e' commit trattenuto, misurato e non dedotto.

 GARANZIE
   - Senza -VerificaRilascio legge soltanto; scrive in snapshots\vincolata\.
   - Duplicare un handle per interrogarlo non cambia l'oggetto: la copia si
     chiude subito.
   - -VerificaRilascio TERMINA il processo sospetto, a conferma digitando SI,
     e misura quanta vincolata si libera: e' l'unica parte che modifica.

 USO
   .\Diagnostica-Vincolata.ps1                      # diagnosi (meglio da admin)
   .\Diagnostica-Vincolata.ps1 -Processo Nome       # forza il processo da esaminare
   .\Diagnostica-Vincolata.ps1 -VerificaRilascio    # esperimento decisivo (admin)

 CODICI DI USCITA
   0 = nessuna crescita significativa   1 = crescita senza detentore identificato
   2 = detentore identificato           3 = dati insufficienti
================================================================================
#>
param(
    [string]$Cartella = '',
    [double]$SogliaR = 0.98,
    [int]$MinCampioni = 24,
    [double]$RitmoMinimo = 1.0,
    [int]$UltimeOre = 6,
    # Misura il ritmo solo sui campioni successivi a questo istante (es. l'ora di un rimedio), formato 2026-10-13T13:35
    [string]$Dal = '',
    [string]$Processo = '',
    [int]$Giorni = 60,
    [switch]$VerificaRilascio,
    [int]$Attesa = 30
)

$ErrorActionPreference = 'Continue'
$script:attivita = @()
$script:ritmoDubbio = $false
$base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj    = Split-Path -Parent $base
if(-not $Cartella){ $Cartella = Join-Path $proj 'snapshots\vincolata' }
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$inv     = [Globalization.CultureInfo]::InvariantCulture

$summary = New-Object System.Collections.Generic.List[string]
function Add-Sum([string]$line){ $summary.Add($line) }
function Section([string]$t){ Add-Sum ''; Add-Sum ('=' * 72); Add-Sum $t; Add-Sum ('=' * 72) }
function Get-Ev($filter){ try { @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop) } catch { @() } }
# I CSV di Campiona-Vincolata sono esportati con la virgola decimale del sistema.
function ToD($s){ if($null -eq $s -or "$s" -eq ''){ return $null }; [double]::Parse(("$s" -replace ',','.'), $inv) }
function F1($d){ if($null -eq $d){ '-' } else { ([double]$d).ToString('0.0', $inv) } }
function Get-Pearson([double[]]$x,[double[]]$y){
    $n = $x.Count; if($n -lt 3){ return $null }
    $mx = ($x | Measure-Object -Average).Average; $my = ($y | Measure-Object -Average).Average
    $sxy = 0.0; $sxx = 0.0; $syy = 0.0
    for($i=0; $i -lt $n; $i++){ $dx = $x[$i]-$mx; $dy = $y[$i]-$my; $sxy += $dx*$dy; $sxx += $dx*$dx; $syy += $dy*$dy }
    if($sxx -eq 0 -or $syy -eq 0){ return $null }
    $sxy / [math]::Sqrt($sxx*$syy)
}
function Get-Pendenza([double[]]$x,[double[]]$y){
    $n = $x.Count; if($n -lt 2){ return $null }
    $mx = ($x | Measure-Object -Average).Average; $my = ($y | Measure-Object -Average).Average
    $sxy = 0.0; $sxx = 0.0
    for($i=0; $i -lt $n; $i++){ $dx = $x[$i]-$mx; $sxy += $dx*($y[$i]-$my); $sxx += $dx*$dx }
    if($sxx -eq 0){ return $null }; $sxy / $sxx
}
# Stessa formula di Campiona-Vincolata.ps1: vincolata - privato dei processi - pool.
function Get-StatoVincolata {
    $m = Get-CimInstance Win32_PerfRawData_PerfOS_Memory
    $os = Get-CimInstance Win32_OperatingSystem
    $priv = (Get-Process | Measure-Object PagedMemorySize64 -Sum).Sum
    [pscustomobject]@{
        VincolataGB     = $m.CommittedBytes/1GB
        LimiteGB        = $m.CommitLimit/1GB
        PrivatoGB       = $priv/1GB
        PoolPGB         = $m.PoolPagedBytes/1GB
        PoolNPGB        = $m.PoolNonpagedBytes/1GB
        NonAttribuitaGB = ($m.CommittedBytes - $priv - $m.PoolPagedBytes - $m.PoolNonpagedBytes)/1GB
        UptimeOre       = ((Get-Date) - $os.LastBootUpTime).TotalHours
    }
}

# ----------------------------------------------------------------------------
#  Lettura degli handle: tipi di oggetto e dimensione delle sezioni (admin)
# ----------------------------------------------------------------------------
if (-not ('HV.Handles' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace HV {
  [StructLayout(LayoutKind.Sequential)]
  public struct SBI { public IntPtr BaseAddress; public uint AllocationAttributes; public long MaximumSize; }
  public class Sezioni { public int Totali; public int Lette; public int Anonime; public long ByteAnonimi; public long ByteFile; public int OggettiDistinti; public bool Deduplicate; }
  public static class Handles {
    [DllImport("ntdll.dll")] static extern int NtQuerySystemInformation(int c, IntPtr b, int l, out int r);
    [DllImport("ntdll.dll")] static extern int NtQueryObject(IntPtr h, int c, IntPtr b, int l, out int r);
    [DllImport("ntdll.dll")] static extern int NtQuerySection(IntPtr h, int c, out SBI b, IntPtr l, IntPtr r);
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint a, bool i, int pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool DuplicateHandle(IntPtr sp, IntPtr sh, IntPtr tp, out IntPtr th, uint acc, bool inh, uint opt);

    // Nomi dei tipi di oggetto, per indice (ObjectTypesInformation = 3).
    public static Dictionary<int,string> Tipi() {
      var d = new Dictionary<int,string>(); int len = 0x10000; IntPtr b = IntPtr.Zero;
      try {
        while (true) {
          b = Marshal.AllocHGlobal(len); int r;
          int st = NtQueryObject(IntPtr.Zero, 3, b, len, out r);
          if (st == unchecked((int)0xC0000004)) { Marshal.FreeHGlobal(b); b = IntPtr.Zero; len = Math.Max(len*2, r); continue; }
          if (st != 0) return d;
          break;
        }
        int n = Marshal.ReadInt32(b); long p = b.ToInt64() + IntPtr.Size;
        for (int i = 0; i < n; i++) {
          IntPtr e = new IntPtr(p);
          ushort ln = (ushort)Marshal.ReadInt16(e, 0); ushort mx = (ushort)Marshal.ReadInt16(e, 2);
          IntPtr nb = Marshal.ReadIntPtr(e, IntPtr.Size);
          int idx = Marshal.ReadByte(e, 0x5A);           // OBJECT_TYPE_INFORMATION.TypeIndex (Windows 8.1+)
          d[idx] = Marshal.PtrToStringUni(nb, ln/2);
          long sz = 0x68 + mx; sz = (sz + IntPtr.Size - 1) & ~((long)IntPtr.Size - 1);
          p += sz;
        }
      } finally { if (b != IntPtr.Zero) Marshal.FreeHGlobal(b); }
      return d;
    }

    // Tabella degli handle di sistema (SystemExtendedHandleInformation = 0x40): righe [pid, handle, tipo, oggetto].
    static List<long[]> Tabella(int pid) {
      var res = new List<long[]>(); int len = 1 << 24; IntPtr b = IntPtr.Zero;
      try {
        while (true) {
          b = Marshal.AllocHGlobal(len); int r;
          int st = NtQuerySystemInformation(0x40, b, len, out r);
          if (st == unchecked((int)0xC0000004)) { Marshal.FreeHGlobal(b); b = IntPtr.Zero; len = Math.Max(len*2, r + (1<<20)); continue; }
          if (st != 0) throw new Exception("NtQuerySystemInformation: 0x" + st.ToString("X8"));
          break;
        }
        long n = Marshal.ReadIntPtr(b).ToInt64(); int es = 3*IntPtr.Size + 16; long p = b.ToInt64() + 2*IntPtr.Size;
        for (long i = 0; i < n; i++, p += es) {
          IntPtr e = new IntPtr(p);
          long upid = Marshal.ReadIntPtr(e, IntPtr.Size).ToInt64();
          if (upid != pid) continue;
          long obj = Marshal.ReadIntPtr(e, 0).ToInt64();
          long hv  = Marshal.ReadIntPtr(e, 2*IntPtr.Size).ToInt64();
          int tipo = (ushort)Marshal.ReadInt16(e, 3*IntPtr.Size + 6);
          res.Add(new long[] { upid, hv, tipo, obj });
        }
      } finally { if (b != IntPtr.Zero) Marshal.FreeHGlobal(b); }
      return res;
    }

    public static Dictionary<int,int> ConteggioPerTipo(int pid) {
      var d = new Dictionary<int,int>();
      foreach (var h in Tabella(pid)) { int t = (int)h[2]; int c; d.TryGetValue(t, out c); d[t] = c + 1; }
      return d;
    }

    // Somma delle dimensioni delle sezioni tenute aperte da pid. Anonime = non appoggiate a file (SEC_FILE/SEC_IMAGE assenti).
    public static Sezioni MisuraSezioni(int pid, int tipoSection) {
      var s = new Sezioni(); var visti = new HashSet<long>(); bool ded = true;
      IntPtr hp = OpenProcess(0x0040, false, pid);   // PROCESS_DUP_HANDLE
      if (hp == IntPtr.Zero) return s;
      try {
        foreach (var h in Tabella(pid)) {
          if ((int)h[2] != tipoSection) continue;
          s.Totali++;
          if (h[3] == 0) ded = false;
          else if (!visti.Add(h[3])) continue;       // stesso oggetto da due handle: si conta una volta
          IntPtr dup;
          if (!DuplicateHandle(hp, new IntPtr(h[1]), GetCurrentProcess(), out dup, 0x0001, false, 0)) continue;  // SECTION_QUERY
          try {
            SBI bi;
            if (NtQuerySection(dup, 0, out bi, new IntPtr(Marshal.SizeOf(typeof(SBI))), IntPtr.Zero) == 0) {
              s.Lette++;
              if ((bi.AllocationAttributes & (0x800000 | 0x1000000)) == 0) { s.Anonime++; s.ByteAnonimi += bi.MaximumSize; }
              else s.ByteFile += bi.MaximumSize;
            }
          } finally { CloseHandle(dup); }
        }
      } finally { CloseHandle(hp); }
      s.Deduplicate = ded; s.OggettiDistinti = ded ? visti.Count : -1;
      return s;
    }
  }
}
'@
}

# ----------------------------------------------------------------------------
#  Diagnosi
# ----------------------------------------------------------------------------
Add-Sum "DIAGNOSI MEMORIA VINCOLATA  -  $(Get-Date)"
Add-Sum "Eseguito da : $env:USERDOMAIN\$env:USERNAME   (amministratore: $isAdmin)"
Add-Sum "Serie       : $Cartella"
if(-not $isAdmin){ Add-Sum 'ATTENZIONE: senza admin la conferma sulle sezioni (sezione 4) non si esegue.' }

# --- 1. STATO ATTUALE --------------------------------------------------------
Section '1. STATO ATTUALE'
$ora = Get-StatoVincolata
Add-Sum ("Vincolata         : {0} / {1} GB ({2}%)" -f (F1 $ora.VincolataGB),(F1 $ora.LimiteGB),[int]($ora.VincolataGB/$ora.LimiteGB*100))
Add-Sum ("Privato processi  : {0} GB    Pool di paging {1} GB    Pool non di paging {2} GB" -f (F1 $ora.PrivatoGB),(F1 $ora.PoolPGB),(F1 $ora.PoolNPGB))
Add-Sum ("Non attribuita    : {0} GB    (vincolata - privato dei processi - pool)" -f (F1 $ora.NonAttribuitaGB))
Add-Sum ("Uptime            : {0} ore" -f (F1 $ora.UptimeOre))

# --- 2. SERIE STORICA ----------------------------------------------------------
Section '2. SERIE STORICA PER AVVIO (da Campiona-Vincolata.ps1)'
$fTot = Join-Path $Cartella 'totali.csv'; $fPro = Join-Path $Cartella 'processi.csv'
if(-not (Test-Path $fTot) -or -not (Test-Path $fPro)){
    Add-Sum 'Serie assente. Raccoglierla con: .\scripts\Campiona-Vincolata.ps1 -Installa (admin, un campione ogni 15 minuti).'
    $summary -join "`r`n" | Write-Host; exit 3
}
$tot = @(Import-Csv $fTot | ForEach-Object { [pscustomobject]@{ Ora=$_.Ora; Up=(ToD $_.UptimeOre); Vinc=(ToD $_.VincolataGB); Lim=(ToD $_.LimiteGB); NA=(ToD $_.NonAttribuitaGB); H=(ToD $_.HandleTotali) } })
$avvii = New-Object System.Collections.Generic.List[object]; $cur = New-Object System.Collections.Generic.List[object]
foreach($t in $tot){ if($cur.Count -and $t.Up -lt $cur[$cur.Count-1].Up){ $avvii.Add($cur.ToArray()); $cur = New-Object System.Collections.Generic.List[object] }; $cur.Add($t) }
if($cur.Count){ $avvii.Add($cur.ToArray()) }
Add-Sum ("{0} campioni, {1} avvii. Un avvio e' valido da {2} campioni in su (circa {3} ore)." -f $tot.Count,$avvii.Count,$MinCampioni,[int]($MinCampioni/4))
Add-Sum ''
Add-Sum ("  {0,-20} {1,8} {2,8} {3,10} {4,10} {5,12}" -f 'inizio','campioni','ore','NA ini GB','NA fin GB','GB/giorno')
$info = for($i=0; $i -lt $avvii.Count; $i++){
    $a = $avvii[$i]
    $rate = Get-Pendenza ([double[]]($a | ForEach-Object Up)) ([double[]]($a | ForEach-Object NA))
    $o = [pscustomobject]@{ Indice=$i; Inizio=$a[0].Ora; N=$a.Count; Ore=($a[-1].Up - $a[0].Up); NAi=$a[0].NA; NAf=$a[-1].NA; GBGiorno=$(if($null -ne $rate){ $rate*24 } else { $null }); Valido=($a.Count -ge $MinCampioni); Campioni=$a }
    Add-Sum ("  {0,-20} {1,8} {2,8} {3,10} {4,10} {5,12}{6}" -f $o.Inizio,$o.N,(F1 $o.Ore),(F1 $o.NAi),(F1 $o.NAf),(F1 $o.GBGiorno),$(if($o.Valido){ '' } else { '   (troppo breve)' }))
    $o
}
$validi = @($info | Where-Object Valido)
if($validi.Count -eq 0){
    Section 'VERDETTO'
    Add-Sum "Dati insufficienti: nessun avvio con almeno $MinCampioni campioni. Lasciare girare il campionamento e rieseguire."
    $f = Join-Path $Cartella "diagnosi_$stamp.txt"; ($summary -join "`r`n") | Out-File $f -Encoding UTF8; Write-Host ($summary -join "`r`n"); exit 3
}
$ritmo = ($validi[-1]).GBGiorno
$etichetta = "dell'ultimo avvio valido"
# Ritmo recente: dopo un rimedio applicato a macchina accesa la regressione sull'intero avvio mescola il prima e il dopo.
$ult = $avvii[$avvii.Count-1]
if($Dal){ $rec = @($ult | Where-Object { $_.Ora -ge $Dal }); $finestra = "dal $Dal" }
else    { $rec = @($ult | Where-Object { $_.Up -ge ($ult[-1].Up - $UltimeOre) }); $finestra = "delle ultime $UltimeOre ore" }
if($Dal -and $rec.Count -lt 8){ Add-Sum ''; Add-Sum ("Dal {0} ci sono {1} campioni: ne servono almeno 8 (due ore) per misurare il ritmo." -f $Dal,$rec.Count) }
if($rec.Count -ge 8){
    $rr = Get-Pendenza ([double[]]($rec | ForEach-Object Up)) ([double[]]($rec | ForEach-Object NA))
    if($null -ne $rr){
        $ritmoAvvio = $ritmo; $ritmo = $rr*24; $etichetta = $finestra
        Add-Sum ''
        Add-Sum ("Ritmo {0} ({1} campioni, ultimo del {2}): {3} GB al giorno; sull'intero avvio valido: {4}." -f $finestra,$rec.Count,$ult[-1].Ora,(F1 $ritmo),(F1 $ritmoAvvio))
        # Un calo brusco fra due campioni e' un rilascio (processo terminato, rimedio): la retta che lo attraversa non misura la crescita.
        $salti = 0; for($i=1; $i -lt $rec.Count; $i++){ if($rec[$i-1].NA - $rec[$i].NA -ge 1){ $salti++ } }
        if($salti -gt 0){
            Add-Sum ("  ATTENZIONE: cali di almeno 1 GB fra campioni consecutivi nella finestra: {0}. Il ritmo recente non e' rappresentativo: si usa quello dell'intero avvio. Rimisurare con -Dal <ora successiva al calo>." -f $salti)
            $script:ritmoDubbio = $true; $ritmo = $ritmoAvvio; $etichetta = "dell'ultimo avvio valido"
        }
    }
}
$crescita = ($null -ne $ritmo -and $ritmo -ge $RitmoMinimo)

# --- 3. DETENTORE --------------------------------------------------------------
Section '3. DETENTORE: handle che crescono insieme alla quota non attribuita'
$naPerOra = @{}; foreach($a in $validi){ foreach($c in $a.Campioni){ $naPerOra[$c.Ora] = @($a.Indice, $c.NA) } }
$serie = @{}   # "avvio|nome|pid" -> lista (handle, NA); un processo puo' comparire due volte per campione nei CSV
$visti = @{}
foreach($r in Import-Csv $fPro){
    $x = $naPerOra[$r.Ora]; if(-not $x){ continue }
    $k = "$($x[0])|$($r.Nome)|$($r.PID)"; $kk = "$k|$($r.Ora)"
    if($visti.ContainsKey($kk)){ continue }; $visti[$kk] = 1
    if(-not $serie.ContainsKey($k)){ $serie[$k] = New-Object System.Collections.Generic.List[double[]] }
    $serie[$k].Add([double[]]@([double]$r.Handle, [double]$x[1]))
}
$visti = $null
$cand = foreach($k in $serie.Keys){
    $p = $k.Split('|'); $ai = [int]$p[0]; $a = $info[$ai]; $v = $serie[$k]
    if($v.Count -lt 0.8*$a.N){ continue }
    $hs = [double[]]($v | ForEach-Object { $_[0] }); $ns = [double[]]($v | ForEach-Object { $_[1] })
    $dH = ($hs | Measure-Object -Maximum).Maximum - ($hs | Measure-Object -Minimum).Minimum
    if($dH -lt 1000){ continue }
    $r = Get-Pearson $hs $ns; if($null -eq $r){ continue }
    [pscustomobject]@{ Avvio=$ai; Nome=$p[1]; PID=$p[2]; R=$r; KBperHandle=((Get-Pendenza $hs $ns)*1MB); CrescitaHandle=$dH; Handle=$hs[-1] }
}
$cand = @($cand)
foreach($a in $validi){
    Add-Sum ''
    Add-Sum ("Avvio del {0}: i tre processi piu' correlati" -f $a.Inizio)
    $cand | Where-Object Avvio -eq $a.Indice | Sort-Object R -Descending | Select-Object -First 3 | ForEach-Object {
        Add-Sum ("  {0,-26} PID {1,-6} r = {2}   {3,7} KB per handle   +{4} handle" -f $_.Nome,$_.PID,$_.R.ToString('0.0000',$inv),[int]$_.KBperHandle,[int]$_.CrescitaHandle)
    }
}
# Sospetto: sopra soglia in ogni avvio valido; il nome che ci riesce, con la pendenza piu' stabile.
$sospetto = $null; $sopra = @{}
foreach($c in $cand | Where-Object { $_.R -ge $SogliaR }){ if(-not $sopra.ContainsKey($c.Nome)){ $sopra[$c.Nome] = @{} }; $sopra[$c.Nome][$c.Avvio] = $c }
$ok = @($sopra.Keys | Where-Object { $sopra[$_].Count -eq $validi.Count })
if($Processo){ $sospetto = $Processo; Add-Sum ''; Add-Sum "Processo forzato con -Processo: $Processo" }
elseif($ok.Count -ge 1){
    $sospetto = $ok | Sort-Object { $kb = @($sopra[$_].Values | ForEach-Object KBperHandle); (($kb | Measure-Object -Maximum).Maximum - ($kb | Measure-Object -Minimum).Minimum) } | Select-Object -First 1
    $kb = @($sopra[$sospetto].Values | ForEach-Object KBperHandle)
    Add-Sum ''
    Add-Sum ("SOSPETTO: {0}, con r >= {1} in {2} avvii su {2}; pendenza fra {3} e {4} KB per handle." -f $sospetto,$SogliaR.ToString($inv),$validi.Count,[int]($kb | Measure-Object -Minimum).Minimum,[int]($kb | Measure-Object -Maximum).Maximum)
    Add-Sum '  Una pendenza stabile fra avvii diversi indica un costo fisso per handle: un oggetto di dimensione costante.'
    if($ok.Count -gt 1){ Add-Sum ("  Altri processi sopra soglia in tutti gli avvii: {0}" -f (($ok | Where-Object { $_ -ne $sospetto }) -join ', ')) }
} else {
    Add-Sum ''
    Add-Sum "Nessun processo supera r >= $SogliaR in tutti gli avvii validi."
    Add-Sum '  Se la quota cresce comunque, il detentore e'' probabilmente un driver: serve poolmon o una traccia WPR con il profilo VirtualAllocation.'
}

# --- 4. CONFERMA SULLE SEZIONI ---------------------------------------------------
Section '4. CONFERMA: sezioni di memoria tenute aperte dal sospetto'
$misura = $null; $proc = @()
if(-not $sospetto){ Add-Sum 'Nessun sospetto da esaminare.' }
else {
    $proc = @(Get-Process -Name $sospetto -ErrorAction SilentlyContinue)
    if($proc.Count -eq 0){ Add-Sum "$sospetto non e' in esecuzione adesso." }
    elseif(-not $isAdmin){ Add-Sum 'Serve PowerShell amministratore per leggere gli handle di un altro processo.' }
    else {
        try {
            $tipi = [HV.Handles]::Tipi()
            $idxSec = ($tipi.GetEnumerator() | Where-Object Value -eq 'Section' | Select-Object -First 1).Key
            foreach($p in $proc){
                Add-Sum ("{0} PID {1}: {2} handle in tutto" -f $p.ProcessName,$p.Id,$p.HandleCount)
                $cnt = [HV.Handles]::ConteggioPerTipo($p.Id)
                $cnt.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 6 | ForEach-Object {
                    $nome = if($tipi.ContainsKey($_.Key)){ $tipi[$_.Key] } else { "tipo $($_.Key)" }
                    Add-Sum ("  {0,-20} {1,8}" -f $nome,$_.Value)
                }
                if($null -ne $idxSec){
                    $s = [HV.Handles]::MisuraSezioni($p.Id, [int]$idxSec)
                    $misura = [pscustomobject]@{ PID=$p.Id; GB=$s.ByteAnonimi/1GB; Sezioni=$s }
                    $medio = if($s.Anonime){ $s.ByteAnonimi/$s.Anonime/1KB } else { 0 }
                    Add-Sum ("  Sezioni: {0} handle, {1} lette; {2} non appoggiate a file per {3} GB (in media {4} KB l'una); {5} GB appoggiate a file." -f $s.Totali,$s.Lette,$s.Anonime,(F1 ($s.ByteAnonimi/1GB)),[int]$medio,(F1 ($s.ByteFile/1GB)))
                    if($s.Deduplicate){ Add-Sum ("  Oggetti distinti: {0} (handle duplicati sullo stesso oggetto contati una volta)." -f $s.OggettiDistinti) }
                    else { Add-Sum '  Indirizzi degli oggetti non esposti: possibili doppi conteggi se piu'' handle puntano alla stessa sezione.' }
                    $quota = if($ora.NonAttribuitaGB -gt 0){ $s.ByteAnonimi/1GB/$ora.NonAttribuitaGB*100 } else { 0 }
                    Add-Sum ("  Sezioni / quota non attribuita attuale ({1} GB): {0}%." -f [int]$quota,(F1 $ora.NonAttribuitaGB))
                    # Una parte della quota esiste gia' all'accensione: il confronto giusto e' con la crescita dall'avvio.
                    $avvioCorr = $info[-1]
                    if([math]::Abs($avvioCorr.Campioni[-1].Up - ($ora.UptimeOre - (((Get-Date) - [datetime]::Parse($avvioCorr.Campioni[-1].Ora, $inv)).TotalHours))) -lt 1){
                        $cresc = $ora.NonAttribuitaGB - $avvioCorr.NAi
                        if($cresc -gt 0){ Add-Sum ("  Crescita della quota dall'avvio: {0} GB (da {1} GB); sezioni / crescita: {2}%." -f (F1 $cresc),(F1 $avvioCorr.NAi),[int]($s.ByteAnonimi/1GB/$cresc*100)) }
                    }
                }
            }
        } catch { Add-Sum "Lettura degli handle fallita: $_" }
    }
    foreach($p in $proc){
        $w = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue
        $exe = $w.ExecutablePath
        $ver = if($exe -and (Test-Path $exe)){ (Get-Item $exe).VersionInfo.FileVersion } else { '-' }
        $par = if($w){ Get-CimInstance Win32_Process -Filter "ProcessId=$($w.ParentProcessId)" -ErrorAction SilentlyContinue } else { $null }
        $svc = Get-CimInstance Win32_Service -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue
        Add-Sum ''
        Add-Sum "  Eseguibile : $exe"
        Add-Sum "  Versione   : $ver"
        Add-Sum ("  Avviato da : {0}{1}" -f $(if($par){ "$($par.Name) (PID $($par.ProcessId))" } else { 'processo padre non piu'' attivo' }),$(if($svc){ "; e' il servizio $($svc.Name)" } else { '' }))
        Add-Sum "  In esecuzione dal: $($p.StartTime)"
        $script:attivita = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { @($_.Actions | ForEach-Object { $_.Execute -replace '"','' }) -contains $exe })
        foreach($a in $script:attivita){
            $trg = (@($a.Triggers | ForEach-Object { $_.CimClass.CimClassName -replace '^MSFT_Task','' -replace 'Trigger$','' }) -join ', ')
            Add-Sum ("  Attivita' pianificata: {0}{1} (stato {2}, avvio: {3}, riavvii automatici: {4})" -f $a.TaskPath,$a.TaskName,$a.State,$trg,[int]$a.Settings.RestartCount)
        }
    }
}

# --- 5. EVENTI ------------------------------------------------------------------
Section "5. EVENTI (ultimi $Giorni giorni)"
$since = (Get-Date).AddDays(-$Giorni)
$re = Get-Ev @{ LogName='System'; ProviderName='Microsoft-Windows-Resource-Exhaustion-Detector'; Id=2004; StartTime=$since }
$kp = Get-Ev @{ LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=41; StartTime=$since }
Add-Sum "Memoria virtuale insufficiente (Resource-Exhaustion-Detector 2004): $($re.Count)   Riavvii non puliti (Kernel-Power 41): $($kp.Count)"
foreach($e in $re | Select-Object -First 5){
    try {
        $s = ([xml]$e.ToXml()).Event.UserData.MemoryExhaustionInfo.SystemInfo
        $na = ([double]$s.SystemCommitCharge - [double]$s.ProcessCommitCharge - [double]$s.PagedPoolUsage - [double]$s.NonPagedPoolUsage)/1GB
        Add-Sum ("  {0}  vincolata {1} GB, processi {2} GB, non attribuita {3} GB" -f $e.TimeCreated,(F1 ([double]$s.SystemCommitCharge/1GB)),(F1 ([double]$s.ProcessCommitCharge/1GB)),(F1 $na))
    } catch { Add-Sum "  $($e.TimeCreated)  (dettaglio XML non leggibile)" }
}
foreach($e in $kp | Select-Object -First 5){ Add-Sum ("  Kernel-Power 41: {0}  (BugcheckCode {1})" -f $e.TimeCreated,$e.Properties[0].Value) }

# --- 6. PROIEZIONE E VERDETTO -------------------------------------------------------
Section '6. PROIEZIONE E VERDETTO'
if($crescita){
    $giorni = ($ora.LimiteGB - $ora.VincolataGB) / $ritmo
    Add-Sum ("Ritmo {2}: {0} GB al giorno. Margine al limite: {1} GB." -f (F1 $ritmo),(F1 ($ora.LimiteGB - $ora.VincolataGB)),$etichetta)
    Add-Sum ("Senza riavvio il limite si raggiunge fra circa {0} giorni, intorno al {1}." -f (F1 $giorni),((Get-Date).AddDays($giorni).ToString('yyyy-MM-dd')))
    Add-Sum '  Proiezione lineare: il carico di lavoro aggiunge vincolata propria, quindi la data vera e'' piu'' vicina.'
} else {
    Add-Sum ("Nessuna crescita significativa: ritmo {2} {0} GB al giorno, soglia {1}." -f (F1 $ritmo),$RitmoMinimo,$etichetta)
    if($sospetto -and $script:ritmoDubbio){ Add-Sum "  Il ritmo recente e' falsato da un rilascio: non se ne puo' concludere che la crescita sia cessata." }
    elseif($sospetto){ Add-Sum "  Il detentore della serie storica era ${sospetto}: se e' stato applicato un rimedio, la crescita risulta cessata." }
}
if($sospetto -and $crescita -and $proc.Count -eq 0){
    Add-Sum ''
    Add-Sum "Detentore identificato nella serie: $sospetto, che pero' adesso non e' in esecuzione."
    Add-Sum '  Il ritmo indicato comprende il periodo in cui girava: se e'' stato fermato come rimedio non dice ancora niente sull''effetto.'
    Add-Sum "  Rimisurare con -Dal <ora dell'arresto> quando dopo quell'ora ci sono almeno 8 campioni, cioe' due ore."
}
elseif($sospetto -and $crescita){
    Add-Sum ''
    Add-Sum "Detentore identificato: $sospetto."
    Add-Sum '  Conferma decisiva: .\scripts\Diagnostica-Vincolata.ps1 -VerificaRilascio (admin): termina il processo e misura il rilascio.'
    Add-Sum '  Tampone finche'' non c''e'' un rimedio: riavviare il solo processo prima della data stimata (non serve riavviare la macchina).'
    Add-Sum '  Rimedi e loro rischi: docs\13_MEMORIA_VINCOLATA_HANDLE_LEAK.md.'
}
$exit = if(-not $crescita){ 0 } elseif($sospetto){ 2 } else { 1 }

$file = Join-Path $Cartella "diagnosi_$stamp.txt"
($summary -join "`r`n") | Out-File -FilePath $file -Encoding UTF8
Write-Host ($summary -join "`r`n")
Write-Host ''
Write-Host "Report salvato in: $file" -ForegroundColor Cyan

# ----------------------------------------------------------------------------
#  Verifica del rilascio (unica parte che MODIFICA: termina un processo)
# ----------------------------------------------------------------------------
if($VerificaRilascio){
    Write-Host ''
    Write-Host '=== VERIFICA DEL RILASCIO (termina il processo sospetto) ===' -ForegroundColor Yellow
    if(-not $isAdmin){ Write-Host 'Serve PowerShell amministratore.' -ForegroundColor Red; exit $exit }
    if(-not $sospetto -or $proc.Count -eq 0){ Write-Host 'Nessun processo sospetto in esecuzione: niente da verificare.' -ForegroundColor Yellow; exit $exit }
    Write-Host 'Paletto 2: terminare un processo e'' reversibile (si riavvia con il suo programma o con un riavvio),'
    Write-Host 'ma il lavoro aperto in quel programma si perde. Nessun file di sistema viene toccato.'
    $proc | ForEach-Object { Write-Host ("  da terminare: {0} PID {1} ({2} handle)" -f $_.ProcessName,$_.Id,$_.HandleCount) }
    if($misura){ Write-Host ("  rilascio atteso: circa {0} GB (le sezioni misurate sopra)" -f (F1 $misura.GB)) }
    $conf = Read-Host 'Digita SI per terminarlo e misurare'
    if($conf -cne 'SI'){ Write-Host 'Annullato: nessuna modifica eseguita.' -ForegroundColor Yellow; exit $exit }
    $prima = Get-StatoVincolata
    $pidVecchi = @($proc | ForEach-Object Id)
    $proc | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    Write-Host "Attesa di $Attesa secondi..."
    Start-Sleep -Seconds $Attesa
    $dopo = Get-StatoVincolata
    $ripartito = @(Get-Process -Name $sospetto -ErrorAction SilentlyContinue | Where-Object { $pidVecchi -notcontains $_.Id })
    $dNA = $prima.NonAttribuitaGB - $dopo.NonAttribuitaGB; $dV = $prima.VincolataGB - $dopo.VincolataGB
    Write-Host ("Non attribuita: {0} -> {1} GB (liberati {2} GB). Vincolata: {3} -> {4} GB (liberati {5} GB)." -f (F1 $prima.NonAttribuitaGB),(F1 $dopo.NonAttribuitaGB),(F1 $dNA),(F1 $prima.VincolataGB),(F1 $dopo.VincolataGB),(F1 $dV))
    if($misura -and $misura.GB -gt 0){ Write-Host ("Rilascio misurato / sezioni misurate: {0}%" -f [int]($dNA/$misura.GB*100)) }
    Write-Host ("Il processo si e' riavviato da solo: {0}" -f $(if($ripartito.Count){ "si (PID $(($ripartito.Id) -join ', '))" } else { 'no' }))
    foreach($a in @($script:attivita)){ if(-not $ripartito.Count){ Write-Host ("Per riavviarlo subito: Start-ScheduledTask -TaskPath '{0}' -TaskName '{1}' (altrimenti riparte al prossimo logon)" -f $a.TaskPath,$a.TaskName) } }
    Write-Host ''
    Write-Host 'Riga per il changelog (paletto 6):'
    Write-Host ("  {0} | Terminato {1} (PID {2}) per verificare il rilascio della vincolata: liberati {3} GB | diagnosi del leak, vedi docs/13 | Start-ScheduledTask dell'attivita' che lo avvia, o nuovo logon" -f (Get-Date -Format 'yyyy-MM-dd'),$sospetto,($pidVecchi -join ', '),(F1 $dNA))
    "$(Get-Date -Format s);$sospetto;$($pidVecchi -join ',');$(F1 $prima.NonAttribuitaGB);$(F1 $dopo.NonAttribuitaGB);$(F1 $dNA);$(if($misura){ F1 $misura.GB } else { '' });$($ripartito.Count -gt 0)" |
        Add-Content -Path (Join-Path $Cartella 'verifiche_rilascio.csv') -Encoding UTF8
}
exit $exit
