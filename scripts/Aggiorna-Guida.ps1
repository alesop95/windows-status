# =============================================================================
#  Aggiorna-Guida.ps1  -  tiene GUIDA.md allineata al progetto
# =============================================================================
#  IL PROBLEMA. Una guida scritta a mano invecchia in silenzio: si aggiunge uno
#  script, si aggiunge una voce di menu, e la guida continua a descrivere il
#  progetto di tre mesi fa senza che niente segnali la differenza. Il modo in
#  cui se ne accorge qualcuno e' sempre lo stesso: seguendola e sbattendoci.
#
#  COME SI RISOLVE QUI. GUIDA.md e' per meta' scritta a mano e per meta'
#  GENERATA dal progetto stesso. Le parti generate stanno fra marcatori e
#  nascono da quattro fonti che sono gia' la verita':
#
#      Avvia.ps1                       le voci di menu, cioe' cosa si puo' fare
#      scripts\*.ps1 e sottocartelle   gli strumenti e la loro riga di sintesi
#      docs\*.md                       i documenti e il loro titolo
#      prima-installazione\strumenti.json   i progetti di terze parti appuntati
#
#  Fra i marcatori non si scrive a mano: si rigenera. Fuori dai marcatori si
#  scrive a mano, e il generatore non tocca niente.
#
#  USO
#    .\Aggiorna-Guida.ps1              # mostra se la guida e' allineata
#    .\Aggiorna-Guida.ps1 -Applica     # rigenera le parti generate
#    .\Aggiorna-Guida.ps1 -Verifica    # come sopra ma esce 1 se e' da rigenerare
#                                      # (per un controllo prima del commit)
# =============================================================================

[CmdletBinding()]
param(
    # Riscrive le parti generate di GUIDA.md.
    [switch] $Applica,

    # Non scrive: esce con codice 1 se la guida non e' allineata. Serve a un
    # controllo automatico prima di un commit.
    [switch] $Verifica
)

$ErrorActionPreference = 'Stop'

$Radice = Split-Path $PSScriptRoot -Parent
$Guida  = Join-Path $Radice 'GUIDA.md'
$Avvia  = Join-Path $Radice 'Avvia.ps1'
$Manif  = Join-Path $PSScriptRoot 'prima-installazione\strumenti.json'

function Ok     { param([string]$T) Write-Host "  [ok]      $T" -ForegroundColor Green }
function Info   { param([string]$T) Write-Host "  [info]    $T" }
function Avviso { param([string]$T) Write-Host "  [attenzione] $T" -ForegroundColor Yellow }

# --- lettura delle fonti -----------------------------------------------------

function Leggi-Voci {
    # Le voci del menu stanno in un array PowerShell: invece di interpretarlo,
    # lo si legge con un'espressione regolare riga per riga. Se un giorno il
    # formato cambia, questa funzione smette di trovare voci e il controllo
    # lo dice, che e' meglio di una guida che mente.
    $voci = @()
    foreach ($riga in (Get-Content $Avvia -Encoding UTF8)) {
        if ($riga -notmatch '^\s*@\{\s*N=') { continue }
        $n = if ($riga -match "N\s*=\s*'([^']+)'") { $matches[1] } else { continue }
        $t = if ($riga -match "Titolo\s*=\s*'((?:[^']|'')*)'") { $matches[1] -replace "''", "'" } else { '' }
        $p = if ($riga -match "Tipo\s*=\s*'([^']+)'") { $matches[1] } else { '' }
        $s = if ($riga -match "Join-Path \`$scripts '([^']+)'") { $matches[1] } else { '' }
        $voci += [pscustomobject]@{ N = $n; Titolo = $t; Tipo = $p; Script = $s }
    }
    return $voci
}

function Sintesi-Script {
    # Due convenzioni convivono nel progetto e si leggono entrambe:
    #   1. la riga d'intestazione "<nome> - descrizione" dei file piu' recenti
    #   2. il blocco .SYNOPSIS di PowerShell, usato dai piu' vecchi
    # Il trattino della prima dev'essere circondato da spazi, altrimenti una
    # riga d'esempio come ".\Script.ps1 -Installa" verrebbe scambiata per una
    # descrizione. Dove non c'e' ne' l'una ne' l'altra, lo si dice.
    param([string]$Percorso)
    $nome  = Split-Path $Percorso -Leaf
    $testa = Get-Content $Percorso -TotalCount 40 -Encoding UTF8 -ErrorAction SilentlyContinue

    foreach ($r in $testa) {
        if ($r -match [regex]::Escape($nome) + '\s+[-\u2014]+\s+(.+?)\s*$') {
            return ($matches[1].Trim())
        }
    }

    for ($i = 0; $i -lt $testa.Count; $i++) {
        if ($testa[$i] -match '^\s*\.SYNOPSIS\s*$') {
            for ($j = $i + 1; $j -lt $testa.Count; $j++) {
                $r = $testa[$j].Trim()
                if ($r) { return ($r -replace '\s+$', '') }
            }
        }
    }

    return '(senza riga di sintesi nell''intestazione)'
}

function Leggi-Strumenti {
    $cartelle = @($PSScriptRoot)
    $cartelle += (Get-ChildItem $PSScriptRoot -Directory | Select-Object -ExpandProperty FullName)
    $righe = @()
    foreach ($c in $cartelle) {
        foreach ($f in (Get-ChildItem $c -File | Where-Object { $_.Extension -in '.ps1', '.sh' } | Sort-Object Name)) {
            $rel = $f.FullName.Substring($Radice.Length + 1).Replace('\', '/')
            $righe += [pscustomobject]@{ Percorso = $rel; Sintesi = (Sintesi-Script $f.FullName) }
        }
    }
    return $righe
}

function Leggi-Documenti {
    $righe = @()
    foreach ($f in (Get-ChildItem (Join-Path $Radice 'docs') -Filter '*.md' | Sort-Object Name)) {
        if ($f.Name -like '*.compilata.md') { continue }   # copie locali con dati reali
        $titolo = (Get-Content $f.FullName -TotalCount 5 -Encoding UTF8 | Where-Object { $_ -match '^#\s+(.+)' } |
                   Select-Object -First 1) -replace '^#\s+', ''
        $righe += [pscustomobject]@{ File = $f.Name; Titolo = $titolo }
    }
    return $righe
}

function Leggi-Terze-Parti {
    if (-not (Test-Path $Manif)) { return @() }
    return (Get-Content $Manif -Raw -Encoding UTF8 | ConvertFrom-Json).strumenti
}

# --- generazione -------------------------------------------------------------

function Blocco-Menu {
    $v = Leggi-Voci
    $r = @()
    $r += "| Voce | Cosa fa | Tipo | Script |"
    $r += "|---|---|---|---|"
    foreach ($x in $v) {
        $s = if ($x.Script) { "``$($x.Script)``" } else { '(interno al menu)' }
        $tipo = if ($x.Tipo -eq 'MODIFICA') { '**MODIFICA**' } else { $x.Tipo }
        $r += "| ``$($x.N)`` | $($x.Titolo) | $tipo | $s |"
    }
    $r += ""
    $r += "Voci totali: $($v.Count), di cui $(@($v | Where-Object { $_.Tipo -eq 'MODIFICA' }).Count) che modificano il sistema."
    return $r
}

function Blocco-Strumenti {
    $s = Leggi-Strumenti
    $r = @()
    $r += "| Script | A cosa serve |"
    $r += "|---|---|"
    foreach ($x in $s) { $r += "| ``$($x.Percorso)`` | $($x.Sintesi) |" }
    return $r
}

function Blocco-Documenti {
    $d = Leggi-Documenti
    $r = @()
    $r += "| Documento | Titolo |"
    $r += "|---|---|"
    foreach ($x in $d) { $r += "| ``docs/$($x.File)`` | $($x.Titolo) |" }
    return $r
}

function Blocco-TerzeParti {
    $t = Leggi-Terze-Parti
    if ($t.Count -eq 0) { return @('(manifesto non trovato)') }
    $r = @()
    $r += "| Progetto | Licenza | Versione appuntata | Ruolo | Piattaforma |"
    $r += "|---|---|---|---|---|"
    foreach ($x in $t) {
        $ver = if ($x.commit) { "commit ``$($x.commit.Substring(0,10))``" } else { "``$($x.versione)``" }
        $r += "| $($x.nome) | $($x.licenza) | $ver | $($x.ruolo) | $($x.piattaforma) |"
    }
    $r += ""
    $r += "Tutti appuntati a una versione immutabile e verificati per digest SHA-256 prima dell'esecuzione."
    return $r
}

$blocchi = @{
    'menu'        = { Blocco-Menu }
    'strumenti'   = { Blocco-Strumenti }
    'documenti'   = { Blocco-Documenti }
    'terze-parti' = { Blocco-TerzeParti }
}

function Rigenera {
    param([string]$Testo)
    $cambiati = @()
    foreach ($nome in $blocchi.Keys) {
        $apre  = "<!-- GENERATO: $nome -->"
        $chiude = "<!-- FINE GENERATO: $nome -->"
        $i = $Testo.IndexOf($apre)
        $j = $Testo.IndexOf($chiude)
        if ($i -lt 0 -or $j -lt 0) { Avviso "marcatore '$nome' assente da GUIDA.md"; continue }
        $vecchio = $Testo.Substring($i + $apre.Length, $j - $i - $apre.Length)
        $nuovo = "`n" + ((& $blocchi[$nome]) -join "`n") + "`n"
        if ($vecchio.Replace("`r", '') -ne $nuovo) { $cambiati += $nome }
        $Testo = $Testo.Substring(0, $i + $apre.Length) + $nuovo + $Testo.Substring($j)
    }
    return @{ Testo = $Testo; Cambiati = $cambiati }
}

# --- esecuzione --------------------------------------------------------------

if (-not (Test-Path $Guida)) { throw "GUIDA.md non trovata in $Radice" }

$originale = Get-Content $Guida -Raw -Encoding UTF8
$esito = Rigenera $originale

Write-Host ''
Write-Host '  GUIDA.md - allineamento delle parti generate' -ForegroundColor Cyan
Write-Host ''

if ($esito.Cambiati.Count -eq 0) {
    Ok 'la guida e'' allineata al progetto'
    if ($Verifica) { exit 0 }
    return
}

Avviso "parti da rigenerare: $($esito.Cambiati -join ', ')"
Info   'Succede quando si aggiunge una voce di menu, uno script, un documento'
Info   'o uno strumento di terze parti, e la guida non lo sa ancora.'

if ($Applica) {
    [System.IO.File]::WriteAllText($Guida, $esito.Testo, (New-Object System.Text.UTF8Encoding($false)))
    Ok "GUIDA.md rigenerata ($($esito.Cambiati.Count) blocchi)"
    Info 'Rileggi le parti scritte a mano: il generatore non le tocca, ma una'
    Info 'capacita'' nuova di solito merita una riga anche li''.'
    return
}

if ($Verifica) {
    Write-Host ''
    Avviso 'GUIDA.md NON e'' allineata. Rigenerala con -Applica prima del commit.'
    exit 1
}

Info 'Per rigenerarla: .\scripts\Aggiorna-Guida.ps1 -Applica'
