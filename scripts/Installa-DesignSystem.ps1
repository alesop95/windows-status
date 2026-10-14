<#
.SYNOPSIS
    Propaga UN design system, confezionato come pacchetto skill, a tutte le radici
    di account degli agenti da terminale presenti su questa macchina.

.DESCRIPTION
    Un design system e' una cartella che contiene un file SKILL.md con il suo
    frontmatter (name, description) e, accanto, i token, i font, gli asset e le
    regole del marchio. Questo script non conosce nessun marchio: riceve il
    percorso del pacchetto, ne legge il nome e la descrizione dal SKILL.md, lo
    deposita una volta sola in un magazzino di macchina e lo rende visibile a
    ogni radice di account creando un collegamento di cartella (junction), non
    una copia. Una sola copia reale significa un solo aggiornamento: rifare il
    pacchetto nel magazzino aggiorna tutte le radici insieme.

    In ogni radice scrive anche un blocco di istruzioni delimitato da marcatori
    dentro il file che l'agente legge a inizio sessione (CLAUDE.md per Claude
    Code, AGENTS.md per Codex), cosi' che la skill non sia soltanto presente ma
    anche ricordata. Il testo del blocco si genera dal frontmatter del pacchetto:
    nessun dato del marchio vive in questo repository.

    Di default lo script e' in sola lettura e mostra che cosa farebbe.

.PARAMETER Sorgente
    Cartella del pacchetto da propagare. Deve contenere SKILL.md. Obbligatoria
    con -Applica, salvo che il pacchetto sia gia' nel magazzino.

.PARAMETER Deposito
    Magazzino di macchina che ospita la copia reale. Default: .design-systems
    nel profilo utente. Il pacchetto finisce in <Deposito>\<Nome>.

.PARAMETER Nome
    Nome breve con cui la skill compare nelle radici. Default: il campo name del
    frontmatter, altrimenti il nome della cartella sorgente.

.PARAMETER Radici
    Radici di account da servire. Default: tutte le cartelle .claude-account* e
    .codex-account* del profilo utente.

.PARAMETER IncludiPredefinite
    Serve anche le radici predefinite .claude e .codex, che normalmente restano
    fuori perche' non appartengono a nessun account configurato.

.PARAMETER Applica
    Esegue davvero: deposito, collegamenti e blocchi di istruzioni.

.PARAMETER Rimuovi
    Toglie i collegamenti e i blocchi di istruzioni. Non tocca il magazzino e
    non cancella mai una cartella reale.

.EXAMPLE
    .\Installa-DesignSystem.ps1 -Verifica
    Mostra, per ogni radice, se il design system e' collegato e ricordato.

.EXAMPLE
    .\Installa-DesignSystem.ps1 -Sorgente '<percorso del pacchetto>' -Applica
    Deposita il pacchetto e lo propaga a tutte le radici di account.

.NOTES
    Le radici di Codex vengono riscritte da Installa-Codex.ps1 quando si
    ridistribuisce la configurazione di riferimento: dopo un -Forza va rilanciato
    questo script, altrimenti il blocco di istruzioni sparisce mentre il
    collegamento resta. La verifica lo segnala.
#>
[CmdletBinding()]
param(
    [string]$Sorgente,
    [string]$Deposito = (Join-Path $env:USERPROFILE '.design-systems'),
    [string]$Nome,
    [string[]]$Radici,
    [switch]$IncludiPredefinite,
    [switch]$Applica,
    [switch]$Rimuovi,
    [switch]$Verifica
)

$ErrorActionPreference = 'Stop'

$MARCATORE_INIZIO = '<!-- DESIGN-SYSTEM-DI-ACCOUNT:INIZIO -->'
$MARCATORE_FINE   = '<!-- DESIGN-SYSTEM-DI-ACCOUNT:FINE -->'

function Write-Titolo([string]$testo) {
    Write-Host ''
    Write-Host ('=' * 70) -ForegroundColor Cyan
    Write-Host (' ' + $testo) -ForegroundColor Cyan
    Write-Host ('=' * 70) -ForegroundColor Cyan
}

function Read-Frontmatter([string]$percorsoSkill) {
    # Legge i campi name e description dal frontmatter YAML minimale di SKILL.md.
    $meta = @{ name = ''; description = '' }
    $righe = Get-Content -LiteralPath $percorsoSkill -Encoding UTF8
    if ($righe.Count -eq 0 -or $righe[0].Trim() -ne '---') { return $meta }
    for ($i = 1; $i -lt $righe.Count; $i++) {
        if ($righe[$i].Trim() -eq '---') { break }
        if ($righe[$i] -match '^\s*(name|description)\s*:\s*(.+?)\s*$') {
            $meta[$Matches[1]] = $Matches[2].Trim('"').Trim("'")
        }
    }
    return $meta
}

function Test-Junction([string]$percorso) {
    if (-not (Test-Path -LiteralPath $percorso)) { return $false }
    $voce = Get-Item -LiteralPath $percorso -Force
    return [bool]($voce.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
}

function Remove-SoloJunction([string]$percorso) {
    # Elimina il punto di reparse senza seguirlo: il bersaglio resta intatto.
    [System.IO.Directory]::Delete($percorso)
}

function New-Junction([string]$collegamento, [string]$bersaglio) {
    New-Item -ItemType Junction -Path $collegamento -Target $bersaglio -ErrorAction Stop | Out-Null
}

function Get-RadiciAgenti([string[]]$esplicite, [switch]$conPredefinite) {
    $elenco = New-Object System.Collections.Generic.List[object]
    if ($esplicite) {
        foreach ($r in $esplicite) {
            $foglia = Split-Path -Leaf $r
            $agente = if ($foglia -like '.codex*') { 'Codex' } else { 'Claude' }
            $elenco.Add([pscustomobject]@{
                Percorso    = $r
                Agente      = $agente
                Istruzioni  = Join-Path $r $(if ($agente -eq 'Codex') { 'AGENTS.md' } else { 'CLAUDE.md' })
            })
        }
        return $elenco
    }
    $schemi = @(
        @{ Filtro = '.claude-account*'; Agente = 'Claude'; File = 'CLAUDE.md' },
        @{ Filtro = '.codex-account*';  Agente = 'Codex';  File = 'AGENTS.md' }
    )
    if ($conPredefinite) {
        $schemi += @{ Filtro = '.claude'; Agente = 'Claude'; File = 'CLAUDE.md' }
        $schemi += @{ Filtro = '.codex';  Agente = 'Codex';  File = 'AGENTS.md' }
    }
    foreach ($schema in $schemi) {
        Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Filter $schema.Filtro -Force |
            Sort-Object Name | ForEach-Object {
                $elenco.Add([pscustomobject]@{
                    Percorso   = $_.FullName
                    Agente     = $schema.Agente
                    Istruzioni = Join-Path $_.FullName $schema.File
                })
            }
    }
    return $elenco
}

function New-BloccoIstruzioni([hashtable]$meta, [string]$nome, [string]$percorsoSkill) {
    # Il testo si genera dal pacchetto: qui dentro non vive nessun dato di marchio.
    $descrizione = if ($meta.description) { $meta.description } else { 'design system di questa organizzazione' }
    $righe = @(
        $MARCATORE_INIZIO,
        '# Design system di account',
        '',
        ('Gli artefatti visivi destinati a questa organizzazione, cioe'' le pagine HTML di documentazione e di stato, gli export, le fotografie di progetto e i mock, si disegnano con il design system installato a livello di account e non con palette inventate o ereditate da un file precedente. Il pacchetto e'' la skill `{0}`, che vive in `{1}`: {2}' -f $nome, ($percorsoSkill -replace '\\', '/'), $descrizione),
        '',
        ('Si invoca con lo strumento Skill su `{0}` quando serve disegnare, e si leggono le sue regole prima di scrivere la prima riga di stile. Le sue fondamenta, cioe'' colori, tipografia, spaziature, geometria e asset, prevalgono su qualunque scelta estetica improvvisata in sessione. Il pacchetto e'' un collegamento al magazzino di macchina: aggiornarlo la'' aggiorna tutte le radici di account insieme.' -f $nome),
        '',
        ('Propagazione e verifica: `scripts\Installa-DesignSystem.ps1` del progetto di stato della macchina. Questo blocco e'' generato: si modifica rigenerandolo, non a mano.'),
        $MARCATORE_FINE
    )
    return ($righe -join "`n")
}

function Set-BloccoIstruzioni([string]$file, [string]$blocco, [switch]$togli) {
    $nuovo = ''
    $esisteva = $false
    if (Test-Path -LiteralPath $file) {
        $testo = [System.IO.File]::ReadAllText($file)
        $i = $testo.IndexOf($MARCATORE_INIZIO)
        $f = $testo.IndexOf($MARCATORE_FINE)
        if ($i -ge 0 -and $f -gt $i) {
            $esisteva = $true
            $fine = $f + $MARCATORE_FINE.Length
            $coda = $testo.Substring($fine).TrimStart("`r", "`n")
            $nuovo = if ($togli) {
                $testo.Substring(0, $i).TrimEnd("`r", "`n") + "`n`n" + $coda
            } else {
                $testo.Substring(0, $i) + $blocco + "`n`n" + $coda
            }
        } elseif (-not $togli) {
            $nuovo = $blocco + "`n`n" + $testo.TrimStart("`r", "`n")
        } else {
            return [pscustomobject]@{ Scritto = $false; Esisteva = $false }
        }
    } elseif (-not $togli) {
        $nuovo = $blocco + "`n"
    } else {
        return [pscustomobject]@{ Scritto = $false; Esisteva = $false }
    }
    $codifica = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($file, ($nuovo -replace "`r`n", "`n"), $codifica)
    return [pscustomobject]@{ Scritto = $true; Esisteva = $esisteva }
}

function Test-BloccoPresente([string]$file) {
    if (-not (Test-Path -LiteralPath $file)) { return $false }
    return ([System.IO.File]::ReadAllText($file)).Contains($MARCATORE_INIZIO)
}

# --- risoluzione del pacchetto ------------------------------------------------

if ($Sorgente) {
    if (-not (Test-Path -LiteralPath $Sorgente -PathType Container)) {
        throw "Sorgente non trovata: $Sorgente"
    }
    $Sorgente = (Resolve-Path -LiteralPath $Sorgente).Path
    $skillMd = Join-Path $Sorgente 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillMd)) {
        throw "La sorgente non e' un pacchetto skill: manca SKILL.md in $Sorgente"
    }
    $meta = Read-Frontmatter $skillMd
    if (-not $Nome) { $Nome = if ($meta.name) { $meta.name } else { Split-Path -Leaf $Sorgente } }
} else {
    $meta = @{ name = ''; description = '' }
}

if (-not $Nome) {
    # Senza sorgente si deduce dal magazzino, se contiene un solo pacchetto.
    if (Test-Path -LiteralPath $Deposito) {
        $presenti = @(Get-ChildItem -LiteralPath $Deposito -Directory -ErrorAction SilentlyContinue)
        if ($presenti.Count -eq 1) { $Nome = $presenti[0].Name }
    }
}
if (-not $Nome) {
    throw "Indicare -Sorgente oppure -Nome: senza uno dei due non si sa quale design system servire."
}

$destinazioneDeposito = Join-Path $Deposito $Nome
if (-not $meta.description -and (Test-Path -LiteralPath (Join-Path $destinazioneDeposito 'SKILL.md'))) {
    $meta = Read-Frontmatter (Join-Path $destinazioneDeposito 'SKILL.md')
}

$radiciDaServire = Get-RadiciAgenti -esplicite $Radici -conPredefinite:$IncludiPredefinite

Write-Titolo "Design system di account: $Nome"
Write-Host ("Magazzino di macchina : {0}" -f $destinazioneDeposito)
if ($Sorgente) { Write-Host ("Pacchetto sorgente    : {0}" -f $Sorgente) }
Write-Host ("Radici di account     : {0}" -f $radiciDaServire.Count)
$modo = if ($Rimuovi) { 'RIMOZIONE' } elseif ($Applica) { 'APPLICA (modifica)' } else { 'sola lettura' }
Write-Host ("Modalita              : {0}" -f $modo) -ForegroundColor $(if ($Applica -or $Rimuovi) { 'Yellow' } else { 'Green' })

# --- deposito ------------------------------------------------------------------

if ($Applica -and -not $Rimuovi) {
    if (-not (Test-Path -LiteralPath $destinazioneDeposito)) {
        if (-not $Sorgente) { throw ("Il magazzino non contiene {0}: serve -Sorgente." -f $Nome) }
        Write-Host ''
        Write-Host ("Deposito il pacchetto in {0}" -f $destinazioneDeposito)
        New-Item -ItemType Directory -Path $Deposito -Force | Out-Null
        Copy-Item -LiteralPath $Sorgente -Destination $destinazioneDeposito -Recurse -Force
    } else {
        Write-Host ''
        Write-Host 'Il magazzino contiene gia'' il pacchetto: non viene sovrascritto.' -ForegroundColor DarkGray
    }
}

$depositoPronto = Test-Path -LiteralPath $destinazioneDeposito
$blocco = New-BloccoIstruzioni -meta $meta -nome $Nome -percorsoSkill $destinazioneDeposito

# --- radici --------------------------------------------------------------------

$righeEsito = New-Object System.Collections.Generic.List[object]

foreach ($radice in $radiciDaServire) {
    $cartellaSkill = Join-Path $radice.Percorso 'skills'
    $collegamento  = Join-Path $cartellaSkill $Nome
    $stato = 'assente'
    $azione = ''

    if (Test-Path -LiteralPath $collegamento) {
        $stato = if (Test-Junction $collegamento) { 'collegato' } else { 'cartella reale' }
    }

    if ($Rimuovi) {
        if ($Applica) {
            if ($stato -eq 'collegato') { Remove-SoloJunction $collegamento; $azione = 'collegamento rimosso' }
            elseif ($stato -eq 'cartella reale') { $azione = 'NON toccata: e'' una cartella reale' }
            else { $azione = 'niente da rimuovere' }
            $esitoBlocco = Set-BloccoIstruzioni -file $radice.Istruzioni -blocco $blocco -togli
            if ($esitoBlocco.Scritto) { $azione += '; blocco tolto' }
        } else {
            $azione = 'da rimuovere (simulazione)'
        }
    }
    elseif ($Applica) {
        if (-not $depositoPronto) { throw "Magazzino non pronto: $destinazioneDeposito" }
        if (-not (Test-Path -LiteralPath $cartellaSkill)) {
            New-Item -ItemType Directory -Path $cartellaSkill -Force | Out-Null
        }
        if ($stato -eq 'collegato') {
            Remove-SoloJunction $collegamento
            New-Junction $collegamento $destinazioneDeposito
            $azione = 'collegamento rifatto'
        } elseif ($stato -eq 'cartella reale') {
            $archivio = "$collegamento.sostituito-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
            Rename-Item -LiteralPath $collegamento -NewName (Split-Path -Leaf $archivio)
            New-Junction $collegamento $destinazioneDeposito
            $azione = 'cartella reale messa da parte in ' + (Split-Path -Leaf $archivio) + ', collegamento creato'
        } else {
            New-Junction $collegamento $destinazioneDeposito
            $azione = 'collegamento creato'
        }
        $esitoBlocco = Set-BloccoIstruzioni -file $radice.Istruzioni -blocco $blocco
        $azione += if ($esitoBlocco.Esisteva) { '; blocco aggiornato' } else { '; blocco scritto' }
    }
    else {
        $azione = switch ($stato) {
            'collegato'      { 'gia'' a posto' }
            'cartella reale' { 'da convertire in collegamento' }
            default          { 'da collegare' }
        }
    }

    $righeEsito.Add([pscustomobject]@{
        Radice   = Split-Path -Leaf $radice.Percorso
        Agente   = $radice.Agente
        Skill    = $stato
        Ricordo  = if (Test-BloccoPresente $radice.Istruzioni) { 'si' } else { 'no' }
        Azione   = $azione
    })
}

Write-Host ''
$righeEsito | Format-Table -AutoSize

if (-not $Applica -and -not $Rimuovi) {
    Write-Host 'Sola lettura: nessuna modifica eseguita. Rilanciare con -Applica per propagare.' -ForegroundColor Green
}
if ($Applica -and -not $Rimuovi) {
    Write-Host 'Fatto. Una sessione gia'' aperta non vede la skill nuova: va riaperta.' -ForegroundColor Yellow
    Write-Host 'Dopo un Installa-Codex.ps1 -Forza, le radici Codex perdono il blocco: rilanciare questo script.' -ForegroundColor Yellow
}
