<#
.SYNOPSIS
  Punto d'ingresso di QUESTA MACCHINA alla catena degli agenti da terminale.

.DESCRIPTION
  La catena vive nel TEMPLATE, nel pacchetto `agenti-terminale`: installatori,
  launcher, pulizia, misura del consumo e file di riferimento. E' generica e non
  contiene nulla di questa macchina.

  Questo script e' l'unica parte specifica: conosce **dove sta il template** e
  **quali sono i valori di questa macchina**, cioe' i prefissi degli slug da
  preservare nel wipe e il numero di radici. Non duplica logica: la chiama.

  La divisione e' la stessa applicata a tutto il progetto. Cio' che e' generico e
  riusabile da chiunque sta nel template; cio' che vale solo qui sta qui. Un
  percorso di disco o un prefisso cablato dentro il template lo renderebbe
  inservibile su un'altra macchina, che e' esattamente cio' che un template non
  deve essere.

.PARAMETER Azione
  installa   installa o riallinea entrambi gli agenti
  verifica   sola lettura, mostra il quadro
  consumo    consumo di token di tutte le radici
  comandi    riscrive i comandi brevi nel profilo PowerShell

.PARAMETER Resto
  Argomenti passati allo script del template cosi' come sono.

.EXAMPLE
  .\scripts\Agenti.ps1 verifica
.EXAMPLE
  .\scripts\Agenti.ps1 installa
.EXAMPLE
  .\scripts\Agenti.ps1 consumo -Resto '-Giorni','7'

.NOTES
  Scheda: docs\10_CODEX_CLI_E_WORKSPACE_OPENAI.md
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('installa', 'verifica', 'consumo', 'comandi')]
  [string]$Azione = 'verifica',

  [string]$Template = 'E:\template-claude-developing',

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Resto
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# =============================================================================
#  VALORI DI QUESTA MACCHINA
#  Stanno qui perche' non appartengono al template.
#
#  DECISIONE DEL 2026-09-22: NESSUNA trascrizione si preserva.
#  Le cartelle sotto 'projects' hanno il nome di un progetto e NON contengono il
#  progetto: contengono solo i verbali delle conversazioni avvenute li'. La
#  memoria di un progetto vive DENTRO il progetto, versionata: .claude/memory/,
#  work-log, diario, resume-prompt. Elencare qui i dischi di sviluppo faceva
#  quindi il contrario di cio' che sembrava: non proteggeva la memoria, teneva
#  i doppioni proprio dei progetti che la memoria ce l'hanno gia'.
#  Cio' che si perde: solo il --resume delle conversazioni passate.
#
#  $prefissiImpostazioni e' un'ALTRA cosa e resta popolato: governa le voci
#  'projects' di .claude.json, che sono permessi e dialogo di fiducia, cioe'
#  configurazione e non conversazioni. Svuotarlo farebbe ricomparire il dialogo
#  di fiducia a ogni progetto a ogni sessione.
# =============================================================================
$prefissiImpostazioni = @('D:', 'E:')

$pacchetto = Join-Path $Template '.claude\templates\agenti-terminale\tools'
if (-not (Test-Path -LiteralPath $pacchetto)) {
  Write-Host "MANCA il pacchetto del template: $pacchetto" -ForegroundColor Red
  Write-Host 'Clona il template, oppure indicane il percorso con -Template.' -ForegroundColor Yellow
  exit 1
}

$argomenti = @()
if ($Resto) { $argomenti += $Resto }

switch ($Azione) {
  'installa' {
    & (Join-Path $pacchetto 'Installa-Agenti.ps1') -Template $Template -NienteDaPreservare -PrefissiImpostazioni $prefissiImpostazioni @argomenti
  }
  'verifica' {
    & (Join-Path $pacchetto 'Installa-Agenti.ps1') -Template $Template -NienteDaPreservare -PrefissiImpostazioni $prefissiImpostazioni -Verifica @argomenti
  }
  'consumo' {
    & (Join-Path $pacchetto 'Consumo-Agenti.ps1') @argomenti
  }
  'comandi' {
    & (Join-Path $pacchetto 'Installa-Comandi.ps1') @argomenti
  }
}
