<#
.SYNOPSIS
  Avvia Codex CLI su una radice di account isolata, e ripulisce all'uscita.

.DESCRIPTION
  Codex tiene tutto il proprio stato persistente sotto la radice indicata da
  CODEX_HOME. Se quella variabile non e' impostata, ricade SILENZIOSAMENTE sulla
  radice di default del profilo utente: il comando riesce, stampa "Successfully
  logged in", e le credenziali finiscono nel posto sbagliato.

  Questo e' il motivo per cui il comando non va digitato a mano. E' successo
  davvero durante l'installazione del 2026-09-21: l'assegnamento della variabile
  con la sintassi di un'altra shell e' fallito, l'errore stampato sembrava una
  riga scollegata, e il login e' andato a buon fine sulla radice di default.

  Lo script imposta la radice, verifica che esista e sia configurata, esegue
  Codex, e al ritorno del processo invoca la pulizia se e' installata. Non e'
  un hook: Codex non ne espone uno di fine sessione, e un wrapper e' comunque
  piu' affidabile perche' il processo e' gia' terminato quando la pulizia parte.

.PARAMETER Account
  Numero della radice, che corrisponde a <PROFILO_UTENTE>\.codex-account<N>.

.PARAMETER Stato
  Sola lettura: non avvia Codex, stampa lo stato di login e la diagnosi.

.PARAMETER NoPulizia
  Salta la pulizia all'uscita. Da usare quando si vuole conservare la sessione
  per un resume.

.PARAMETER Resto
  Argomenti passati a Codex cosi' come sono.

.EXAMPLE
  .\scripts\Avvia-Codex.ps1 -Account 1
.EXAMPLE
  .\scripts\Avvia-Codex.ps1 -Account 1 -Stato
.EXAMPLE
  .\scripts\Avvia-Codex.ps1 -Account 2 -Resto 'login'

.NOTES
  Scheda di riferimento: docs\10_CODEX_CLI_E_WORKSPACE_OPENAI.md
  Sola lettura sul sistema tranne per cio' che scrive Codex stesso.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 9)]
  [int]$Account,

  [switch]$Stato,

  [switch]$NoPulizia,

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Resto
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$radice = Join-Path $env:USERPROFILE ".codex-account$Account"

# --- Guardia 1: la radice esiste ed e' configurata -------------------------
# Senza questa, un numero di account sbagliato creerebbe una radice nuova e
# vuota, e Codex chiederebbe un login che nessuno si aspetta.
if (-not (Test-Path -LiteralPath $radice)) {
  Write-Host "La radice $radice non esiste." -ForegroundColor Red
  Write-Host "Creala e mettici il config.toml di riferimento (scheda 10, sez. 3.4), poi rilancia." -ForegroundColor Yellow
  exit 1
}
$configToml = Join-Path $radice 'config.toml'
if (-not (Test-Path -LiteralPath $configToml)) {
  Write-Host "La radice $radice esiste ma non ha config.toml." -ForegroundColor Red
  Write-Host "Senza di esso Codex gira con i default, non con il perimetro deciso. Vedi scheda 10, sez. 3.4." -ForegroundColor Yellow
  exit 1
}

# --- Guardia 2: codex e' raggiungibile -------------------------------------
$codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $codex) {
  Write-Host "codex non e' nel PATH. Installalo con: npm install -g @openai/codex" -ForegroundColor Red
  exit 1
}

$env:CODEX_HOME = $radice
Write-Host "CODEX_HOME = $radice" -ForegroundColor Cyan

# --- Modo di sola lettura ---------------------------------------------------
if ($Stato) {
  & codex login status
  & codex doctor --summary
  exit 0
}

# --- Esecuzione -------------------------------------------------------------
try {
  if ($Resto -and $Resto.Count -gt 0) {
    & codex @Resto
  }
  else {
    & codex
  }
}
finally {
  # Il finally copre anche Ctrl+C e un'uscita per errore, che sono i casi in cui
  # una pulizia messa in coda al blocco try non verrebbe mai eseguita.
  if (-not $NoPulizia) {
    $pulizia = Join-Path $PSScriptRoot 'Pulisci-Codex.ps1'
    if (Test-Path -LiteralPath $pulizia) {
      Write-Host 'Pulizia degli store di sessione...' -ForegroundColor Cyan
      & $pulizia -Account $Account
    }
    else {
      Write-Host 'Pulisci-Codex.ps1 non installato: nessuna pulizia eseguita.' -ForegroundColor DarkYellow
    }
  }
}
