<#
================================================================================
 Genera-Report.ps1  —  Report HTML autoconsistente da uno snapshot
================================================================================
 SCOPO
   Trasforma uno snapshot (SUMMARY.txt) in un singolo file HTML navigabile e
   autoconsistente (CSS inline, nessuna dipendenza), comodo da leggere o
   condividere. Di sola lettura sul sistema: scrive solo report.html DENTRO la
   cartella dello snapshot (ignorata da git).

 USO
   .\Genera-Report.ps1                 # usa lo snapshot piu recente
   .\Genera-Report.ps1 -Snapshot <cartella snapshot_...>

 NOTA
   Il report contiene i dati reali della macchina: resta nella cartella snapshots\
   (ignorata da git). Non condividerlo senza prima verificarne il contenuto.
================================================================================
#>
param([string]$Snapshot)

$base     = Split-Path -Parent $MyInvocation.MyCommand.Path
$snapRoot = Join-Path (Split-Path -Parent $base) 'snapshots'
if(-not $Snapshot){
    $Snapshot = (Get-ChildItem $snapRoot -Directory -ErrorAction SilentlyContinue | Where-Object Name -like 'snapshot_*' | Sort-Object Name | Select-Object -Last 1).FullName
}
if(-not $Snapshot -or -not (Test-Path $Snapshot)){ Write-Host 'Nessuno snapshot trovato.' -ForegroundColor Yellow; return }
$summaryPath = Join-Path $Snapshot 'SUMMARY.txt'
if(-not (Test-Path $summaryPath)){ Write-Host "SUMMARY.txt assente in $Snapshot" -ForegroundColor Yellow; return }

function Esc([string]$t){ if($null -eq $t){return ''}; $t.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }

$summary = Get-Content $summaryPath -Raw
# Le sezioni sono delimitate da righe di '='; lo split alterna: [preambolo],[titolo],[contenuto],...
$parts = [regex]::Split($summary, '(?m)^={5,}\s*$')
$nome  = Split-Path $Snapshot -Leaf

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append(@"
<!DOCTYPE html><html lang="it"><head><meta charset="utf-8">
<title>windows-status - report $nome</title>
<style>
 :root{--ink:#1A1F26;--mut:#5b6470;--line:#e3e6ea;--bg:#fbfaf6;--card:#fff;--accent:#2563eb;--warn:#b5651d;--err:#9a1c2b;--ok:#1f7a4d;}
 *{box-sizing:border-box} body{font-family:Segoe UI,system-ui,sans-serif;background:var(--bg);color:var(--ink);margin:0;padding:24px;line-height:1.5;font-size:14px}
 h1{font-size:22px;margin:0 0 2px} .sub{color:var(--mut);font-size:12px;margin-bottom:18px}
 details{background:var(--card);border:1px solid var(--line);border-radius:8px;margin-bottom:10px;overflow:hidden}
 summary{cursor:pointer;padding:10px 14px;font-weight:600;font-size:14px;background:#f1f3f5;list-style:none}
 summary::-webkit-details-marker{display:none} summary::before{content:'\25B8 ';color:var(--mut)} details[open] summary::before{content:'\25BE '}
 pre{margin:0;padding:12px 16px;white-space:pre-wrap;word-break:break-word;font-family:ui-monospace,Consolas,monospace;font-size:12.5px}
 .hl{background:#fff7ed;border-left:3px solid var(--warn)} .hl pre{color:#7a3e0a}
 .bar{height:4px;background:linear-gradient(90deg,#3C2487,#019BEE,#09A596,#E3B23C);margin:-24px -24px 16px}
 mark{background:#fde68a}
</style></head><body><div class="bar"></div>
<h1>windows-status - report di stato</h1>
<div class="sub">Snapshot: $nome - generato il $(Get-Date -Format 'yyyy-MM-dd HH:mm'). Dati reali della macchina: file locale, non condividere senza verifica.</div>
"@)

# Preambolo (intestazione dello snapshot)
$pre = $parts[0].Trim()
if($pre){ [void]$sb.Append("<details open><summary>Intestazione</summary><pre>$(Esc $pre)</pre></details>") }

# Sezioni: titolo a indice dispari, contenuto al successivo
for($i=1; $i -lt $parts.Count; $i+=2){
    $titolo = $parts[$i].Trim()
    $cont   = if($i+1 -lt $parts.Count){ $parts[$i+1].Trim() } else { '' }
    if(-not $titolo){ continue }
    # evidenzia le sezioni con segnali d'attenzione
    $cls = if($cont -match '(?im)^\s*!|ATTENZIONE|NON firmati: [1-9]|SI \(|DISATTIVATA|non quotato e spazi: [1-9]'){ ' class="hl"' } else { '' }
    [void]$sb.Append("<details open><summary>$(Esc $titolo)</summary><pre$cls>$(Esc $cont)</pre></details>")
}

[void]$sb.Append('</body></html>')
$outFile = Join-Path $Snapshot 'report.html'
$sb.ToString() | Out-File $outFile -Encoding UTF8
Write-Host "Report generato: $outFile" -ForegroundColor Green
Write-Host 'Aprilo nel browser (doppio clic). Resta nella cartella snapshots\ (ignorata da git).'
