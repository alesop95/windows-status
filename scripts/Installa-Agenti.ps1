<#
.SYNOPSIS
  Punto d'ingresso unico: da una macchina Windows nuda al multi-account completo
  di entrambi gli agenti da terminale.

.DESCRIPTION
  Orchestratore. Non duplica nulla: chiama Installa-Claude.ps1 e
  Installa-Codex.ps1, e si occupa dell'unica dipendenza esterna, cioe' il
  repository template da cui provengono le copie di riferimento di Claude.

  PERCHE' DUE REPOSITORY E NON UNO. Hanno lavori diversi, e confonderli li rompe
  entrambi. Il template e' lo STANDARD: generico, portabile fra macchine e fra
  persone, senza alcun valore di questa macchina. Questo repository e' QUESTA
  MACCHINA: contiene i valori che solo qui hanno senso, cioe' i prefissi dei
  dischi di sviluppo e il numero di account. Copiare i riferimenti del template
  qui dentro creerebbe due versioni che divergono in silenzio; mettere i valori
  di questa macchina nel template lo renderebbe inservibile altrove.

  Quello che si puo' fare, ed e' quello che fa questo script, e' togliere
  all'utente l'onere di sapere tutto cio': un comando solo, e la dipendenza si
  risolve da se'.

  ASIMMETRIA FRA I DUE AGENTI, che spiega perche' l'installazione non e' la
  stessa. Claude Code ha un hook SessionEnd, cioe' un comando registrato nel
  settings.json dell'account che punta a un file: lo script di wipe deve quindi
  esistere come copia dentro ogni radice. Codex non ha un hook di ciclo di vita,
  si avvia da un wrapper, e i suoi script restano nel repository. Da qui due
  installatori diversi sotto un unico comando.

.PARAMETER Account
  Numeri delle radici da installare per entrambi gli agenti. Default: 1, 2, 3.

.PARAMETER Prefissi
  Prefissi degli slug da preservare nel wipe di Claude, es. 'D--','E--'.
  Su una macchina nuova vanno passati: non si indovinano, e un insieme sbagliato
  non produce un errore ma un magazzino vuoto. Su una macchina gia' installata
  vengono letti da una radice esistente.

.PARAMETER Template
  Radice del repository template.

.PARAMETER ClonaTemplate
  Se il template non c'e', lo clona dal remoto invece di fermarsi.

.PARAMETER SoloClaude / SoloCodex
  Limita l'esecuzione a un solo agente.

.PARAMETER Verifica
  Sola lettura: non scrive nulla, stampa il quadro di entrambi gli agenti.

.PARAMETER Forza
  Riallinea le installazioni esistenti dalle copie di riferimento.

.EXAMPLE
  .\scripts\Installa-Agenti.ps1 -Verifica
.EXAMPLE
  .\scripts\Installa-Agenti.ps1 -Prefissi 'D--','E--' -ClonaTemplate
.EXAMPLE
  .\scripts\Installa-Agenti.ps1 -Forza

.NOTES
  Scheda: docs\10_CODEX_CLI_E_WORKSPACE_OPENAI.md
#>
[CmdletBinding()]
param(
  [int[]]$Account = @(1, 2, 3),
  [string[]]$Prefissi,
  [string]$Template = 'E:\template-claude-developing',
  [string]$RemotoTemplate,
  [switch]$ClonaTemplate,
  [switch]$SoloClaude,
  [switch]$SoloCodex,
  [switch]$Verifica,
  [switch]$Forza
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Titolo($t) { Write-Host '' ; Write-Host "=== $t ===" -ForegroundColor Cyan }
function Nota($t, $c) { Write-Host $t -ForegroundColor $c }

Titolo 'Installa-Agenti'
if ($Verifica) { Nota 'Modo: SOLA LETTURA, nessuna modifica.' 'Yellow' }

# --- prerequisiti -----------------------------------------------------------
Titolo 'Prerequisiti'
$mancanti = @()
foreach ($c in @('node', 'git')) {
  $g = Get-Command $c -ErrorAction SilentlyContinue
  if ($g) { Nota ("  {0,-8} presente" -f $c) 'Green' }
  else { Nota ("  {0,-8} ASSENTE" -f $c) 'Red'; $mancanti += $c }
}
foreach ($c in @('claude', 'codex')) {
  $g = Get-Command $c -ErrorAction SilentlyContinue
  if ($g) { Nota ("  {0,-8} presente" -f $c) 'Green' }
  else { Nota ("  {0,-8} assente (verra' installato o va installato a mano)" -f $c) 'DarkYellow' }
}
if ($mancanti.Count -gt 0) {
  Nota ("Mancano prerequisiti non installabili da qui: {0}. Interrotto." -f ($mancanti -join ', ')) 'Red'
  exit 1
}

# --- la dipendenza dal template --------------------------------------------
if (-not $SoloCodex) {
  Titolo 'Template (fonte dei riferimenti di Claude)'
  if (Test-Path -LiteralPath (Join-Path $Template '.claude\templates\tools')) {
    Nota ("  presente: {0}" -f $Template) 'Green'
  }
  elseif ($Verifica) {
    Nota ("  ASSENTE: {0}" -f $Template) 'Yellow'
    Nota '  In sola lettura non lo clono. Rilancia con -ClonaTemplate.' 'Yellow'
  }
  elseif ($ClonaTemplate) {
    # Il remoto del template si DERIVA da quello di questo repository, sostituendo
    # il nome del progetto. Cosi' nessun nome utente finisce in un file tracciato
    # (il repository e' pubblico e la convenzione del progetto usa segnaposto), e
    # non c'e' un URL da tenere aggiornato a mano.
    if (-not $RemotoTemplate) {
      $mio = (& git -C (Split-Path -Parent $PSScriptRoot) remote get-url origin 2>$null)
      if ($mio) { $RemotoTemplate = ($mio -replace '[^/:]+\.git$', 'template-claude-developing.git') }
    }
    if (-not $RemotoTemplate) {
      Nota '  Impossibile derivare il remoto del template dal remoto di questo repository.' 'Red'
      Nota '  Passalo esplicitamente con -RemotoTemplate, oppure copia il template a mano.' 'Yellow'
      exit 1
    }
    Nota ("  assente, clono da {0}" -f $RemotoTemplate) 'Cyan'
    $padre = Split-Path -Parent $Template
    if ($padre -and -not (Test-Path -LiteralPath $padre)) { New-Item -ItemType Directory -Path $padre -Force | Out-Null }
    & git clone $RemotoTemplate $Template
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $Template '.claude\templates\tools'))) {
      Nota '  CLONE FALLITO. Cause tipiche su una macchina nuova: chiave SSH non' 'Red'
      Nota '  ancora installata, oppure alias host non configurato in ~\.ssh\config.' 'Red'
      Nota '  Sistema l''accesso git e rilancia, oppure copia il template a mano e' 'Yellow'
      Nota '  indicalo con -Template.' 'Yellow'
      exit 1
    }
    Nota '  clonato' 'Green'
  }
  else {
    Nota ("  ASSENTE: {0}" -f $Template) 'Red'
    Nota '  Le copie di riferimento di Claude vivono nel template, non qui: duplicarle' 'Yellow'
    Nota '  creerebbe due versioni che divergono in silenzio.' 'Yellow'
    Nota '  Rilancia con -ClonaTemplate, oppure indica dove si trova con -Template.' 'Yellow'
    exit 1
  }
}

# --- i due installatori -----------------------------------------------------
$argComuni = @{ Account = $Account }
if ($Verifica) { $argComuni['Verifica'] = $true }
if ($Forza) { $argComuni['Forza'] = $true }

if (-not $SoloCodex) {
  Titolo 'Claude Code'
  $argClaude = $argComuni.Clone()
  $argClaude['Template'] = $Template
  if ($Prefissi -and $Prefissi.Count -gt 0) { $argClaude['Prefissi'] = $Prefissi }
  & (Join-Path $PSScriptRoot 'Installa-Claude.ps1') @argClaude
}

if (-not $SoloClaude) {
  Titolo 'Codex CLI'
  $argCodex = @{ Radici = ($Account | Measure-Object -Maximum).Maximum }
  if ($Verifica) { $argCodex['Verifica'] = $true }
  if ($Forza) { $argCodex['Forza'] = $true }
  & (Join-Path $PSScriptRoot 'Installa-Codex.ps1') @argCodex
}

Titolo 'Riepilogo'
Nota 'Cio'' che NON viene ripristinato da nessuno dei due, deliberatamente:' 'White'
Nota '  - le credenziali: si rifa'' un login per radice e per agente' 'DarkGray'
Nota '  - i server MCP di account (mcp.json): vanno ricreati a mano' 'DarkGray'
Nota '  - la configurazione lato server dei workspace: vive fuori dalla macchina' 'DarkGray'
Write-Host ''
