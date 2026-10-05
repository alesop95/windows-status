<#
================================================================================
 Reinstall-Software.ps1 — Reinstalla i programmi su un PC nuovo dal winget export
================================================================================
 Serve a "ristabilire ovunque" la parte software della fotografia: prende il file
 software_winget.json prodotto da uno snapshot e lo reimporta su una macchina nuova.

 USO (sul PC di destinazione, come amministratore):
   .\Reinstall-Software.ps1                 # usa il software_winget.json piu recente
   .\Reinstall-Software.ps1 -Json <percorso\software_winget.json>

 Suggerimento: rivedi il JSON e togli cio che non vuoi reinstallare prima di lanciarlo.
================================================================================
#>
param([string]$Json)

$base=Split-Path -Parent $MyInvocation.MyCommand.Path
$snapRoot=Join-Path (Split-Path -Parent $base) 'snapshots'

if(-not $Json){
    $Json = Get-ChildItem $snapRoot -Recurse -Filter 'software_winget.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime | Select-Object -Last 1 -ExpandProperty FullName
}
if(-not $Json -or -not (Test-Path -LiteralPath $Json)){ throw 'Nessun software_winget.json trovato: crea uno snapshot -Scope User da un account interattivo con WinGet.' }

try {
    $inventory = Get-Content -LiteralPath $Json -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $packages = @($inventory.Sources | ForEach-Object { $_.Packages } | Where-Object { $_.PackageIdentifier })
    if($packages.Count -eq 0){ throw 'il manifesto non contiene pacchetti' }
} catch { throw "Manifesto WinGet non utilizzabile ($Json): $($_.Exception.Message)" }

Write-Host "Manifesto: $Json ($($packages.Count) pacchetti)"
Write-Host 'Rivedi prima il contenuto se non vuoi reinstallare tutto. Continuo? (Ctrl+C per annullare)'
Pause
winget import -i $Json --accept-package-agreements --accept-source-agreements --ignore-unavailable
if($LASTEXITCODE -ne 0){ throw "winget import non riuscito (codice $LASTEXITCODE)" }
