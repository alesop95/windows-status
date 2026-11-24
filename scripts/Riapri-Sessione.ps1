<#
================================================================================
 Riapri-Sessione.ps1  -  Rimette una trascrizione recuperata e riapre la sessione
================================================================================

 Seconda meta' del recupero dopo un crash dei terminali. Legge la cartella
 prodotta da Recupera-DaShadow.ps1, che ha la stessa forma delle radici degli
 agenti (.claude-accountN\projects\<cartella>\<id>.jsonl per Claude Code,
 .codex-accountN\sessions\...\rollout-...-<id>.jsonl per Codex).

 Senza -Id elenca le sessioni recuperate: agente, radice, id, ora dell'ultimo
 messaggio, dimensione e cartella di progetto, letta dal campo cwd della
 trascrizione. Niente tabella cablata.

 Con -Id rimette quella sola trascrizione nella stessa posizione della sua
 radice, senza sovrascrivere un file che c'e' gia', e per Claude Code riapre
 subito la sessione con il lanciatore del template (Avvia-Claude.ps1 --resume).
 Una sessione per volta: l'hook di fine sessione conserva solo le sessioni
 aperte, quindi una trascrizione rimessa e non riaperta sparisce alla prossima
 chiusura. Per Codex stampa il comando di ripresa invece di lanciarlo.

 USO (da un PowerShell normale, una finestra per sessione)
   .\Riapri-Sessione.ps1 -Recupero 'D:\recupero\recupero-sessioni-2026-11-24_1410'
   .\Riapri-Sessione.ps1 -Recupero '<cartella>' -Id <id>
   .\Riapri-Sessione.ps1 -Recupero '<cartella>' -Id <id> -SoloComando

 -SoloComando rimette il file ma stampa il comando invece di aprire la sessione.
 Procedura completa in docs/19_RECUPERO_DOPO_CRASH_DEI_TERMINALI.md.
================================================================================
#>

[CmdletBinding()]
param(
    # Cartella prodotta da Recupera-DaShadow.ps1.
    [Parameter(Mandatory = $true)]
    [string]$Recupero,

    # Id della sessione da riaprire; senza, elenco.
    [string]$Id,

    # Dove sta il template con il lanciatore degli agenti, come in Agenti.ps1.
    [string]$Template = 'E:\template-claude-developing',

    # Profilo che contiene le radici degli agenti; diverso solo nelle prove.
    [string]$Profilo = $env:USERPROFILE,

    [switch]$SoloComando
)

$ErrorActionPreference = 'Stop'

function Get-Cartella {
    param([string]$File, [string]$Agente)
    foreach ($Riga in (Get-Content -LiteralPath $File -TotalCount 40 -Encoding UTF8)) {
        try { $J = $Riga | ConvertFrom-Json } catch { continue }
        if ($Agente -eq 'codex') { if ($J.payload -and $J.payload.cwd) { return [string]$J.payload.cwd } }
        elseif ($J.cwd) { return [string]$J.cwd }
    }
    return ''
}
function Get-Ultimo {
    param([string]$File)
    $U = ''
    foreach ($Riga in (Get-Content -LiteralPath $File -Tail 30 -Encoding UTF8)) {
        if ($Riga -match '"timestamp":"([^"]+)"') { $U = $Matches[1] }
    }
    return $U
}
function Get-Sessioni {
    $Base = (Resolve-Path -LiteralPath $Recupero).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $Base -Recurse -Filter '*.jsonl' -File | ForEach-Object {
        $Rel = $_.FullName.Substring($Base.Length).TrimStart('\')
        $Parti = $Rel -split '\\'
        $Agente = $null; $SId = $null
        if ($Parti[0] -match '^\.claude(-account\d+)?$' -and $Parti.Count -eq 4 -and $Parti[1] -eq 'projects') {
            $Agente = 'claude'; $SId = $_.BaseName
        }
        elseif ($Parti[0] -match '^\.codex(-account\d+)?$' -and $Parti[1] -eq 'sessions' -and $_.BaseName -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$') {
            $Agente = 'codex'; $SId = $Matches[1]
        }
        if ($Agente) {
            [pscustomobject]@{
                Agente   = $Agente
                Radice   = $Parti[0]
                Id       = $SId
                Ultimo   = Get-Ultimo $_.FullName
                KB       = [int]($_.Length / 1KB)
                Progetto = Get-Cartella $_.FullName $Agente
                Rel      = $Rel
                File     = $_.FullName
            }
        }
    }
}
function Get-Numero {
    param([string]$Radice)
    if ($Radice -match '-account(\d+)$') { return [int]$Matches[1] }
    return 0
}

if (-not (Test-Path -LiteralPath $Recupero)) { throw "cartella di recupero inesistente: $Recupero" }

if (-not $Id) {
    $Tutte = @(Get-Sessioni | Sort-Object Ultimo -Descending)
    if ($Tutte.Count -eq 0) { Write-Host "  nessuna trascrizione in $Recupero"; exit 1 }
    $Tutte | Format-Table Agente, Radice, Id, Ultimo, KB, Progetto -AutoSize | Out-Host
    Write-Host "  Per riaprirne una: -Id <id>, una finestra per sessione."
    return
}

$S = @(Get-Sessioni | Where-Object { $_.Id -eq $Id })
if ($S.Count -eq 0) { throw "nessuna trascrizione con id $Id in $Recupero" }
if ($S.Count -gt 1) { throw "id $Id presente in piu' radici: $(($S | ForEach-Object Radice) -join ', ')" }
$S = $S[0]

# Rimette la trascrizione nella stessa posizione, senza sovrascrivere.
$Dst = Join-Path $Profilo $S.Rel
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Dst) | Out-Null
if (Test-Path -LiteralPath $Dst) { Write-Host "  [gia' presente] $Dst, non lo sovrascrivo" }
else { Copy-Item -LiteralPath $S.File -Destination $Dst; Write-Host "  [ok]   rimesso $Dst" }
if ($S.Agente -eq 'claude') {
    # Accanto alla trascrizione Claude Code tiene una cartella con i subagent.
    $SrcSub = Join-Path (Split-Path -Parent $S.File) $Id
    $DstSub = Join-Path (Split-Path -Parent $Dst) $Id
    if ((Test-Path -LiteralPath $SrcSub) -and -not (Test-Path -LiteralPath $DstSub)) {
        Copy-Item -LiteralPath $SrcSub -Destination $DstSub -Recurse
        Write-Host "  [ok]   rimessi i subagent della sessione"
    }
}

$Cwd = $S.Progetto
if (-not $Cwd) { throw "la trascrizione non dichiara la cartella di progetto (cwd): riaprirla a mano" }
if (-not (Test-Path -LiteralPath $Cwd)) { throw "la cartella di progetto $Cwd non esiste su questa macchina" }
$N = Get-Numero $S.Radice

if ($S.Agente -eq 'codex') {
    $Comando = if ($N -gt 0) { "codex-account$N resume $Id" } else { "codex resume $Id" }
    Write-Host "  Codex non si riapre da qui. In un PowerShell normale nuovo:"
    Write-Host "    cd `"$Cwd`""
    Write-Host "    $Comando"
    return
}

if ($N -eq 0) {
    Write-Host "  Radice predefinita di Claude Code. In un PowerShell normale nuovo:"
    Write-Host "    cd `"$Cwd`""
    Write-Host "    claude --resume $Id"
    return
}

$Avvia = Join-Path $Template '.claude\templates\agenti-terminale\tools\Avvia-Claude.ps1'
if (-not (Test-Path -LiteralPath $Avvia)) { throw "lanciatore non trovato: $Avvia (parametro -Template)" }
Write-Host "  Riapro con l'account $N in ${Cwd}: --resume $Id"
if ($SoloComando) {
    Write-Host "    & `"$Avvia`" -Account $N -Progetto `"$Cwd`" --resume $Id"
    return
}
Set-Location -LiteralPath $Cwd
& $Avvia -Account $N -Progetto $Cwd --resume $Id
