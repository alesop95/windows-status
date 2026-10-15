<#
================================================================================
 Avvia.ps1  —  Punto d'ingresso unico e standardizzato di windows-status
================================================================================
 SCOPO
   Clonata la repo su una QUALSIASI macchina Windows 11, questo è il comando unico
   da cui partire: presenta un menu che guida tra fotografia, confronto, baseline
   di sicurezza, debloating e reinstallazione, in modo uniforme su ogni PC.

   Non implementa logica propria: orchestra gli script in scripts\. Le operazioni
   di sola lettura sono sempre sicure; quelle che MODIFICANO il sistema avvisano e
   restano a conferma esplicita (paletti del progetto).

 USO
   .\Avvia.ps1            # menu interattivo
   .\Avvia.ps1 -Help      # elenca le voci senza entrare nel menu (per script/CI)

 NOTA
   Per i dati completi (BitLocker, Secure Boot, TPM, Defender, altri account) lo
   snapshot va eseguito da PowerShell AMMINISTRATORE.
================================================================================
#>
param([switch]$Help)

$base    = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = Join-Path $base 'scripts'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$voci = @(
  @{ N='1'; Titolo='Fotografa lo stato (snapshot completo)';      Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Snapshot-Stato.ps1') } }
  @{ N='2'; Titolo='Confronta i due snapshot piu recenti';        Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Compare-Snapshot.ps1') } }
  @{ N='2b';Titolo='Genera report HTML dell''ultimo snapshot';     Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Genera-Report.ps1') } }
  @{ N='2c';Titolo='Controlla salute e stabilita (registro eventi)'; Tipo='sola lettura';   Azione={ & (Join-Path $scripts 'Controlla-Salute.ps1') } }
  @{ N='2d';Titolo='Diagnostica PowerPoint lento (cache identita Office)'; Tipo='sola lettura'; Azione={ & (Join-Path $scripts 'Diagnostica-PowerPoint.ps1') } }
  @{ N='2e';Titolo='Bonifica cache PowerPoint (profilo corrente)'; Tipo='MODIFICA';         Azione={ & (Join-Path $scripts 'Diagnostica-PowerPoint.ps1') -Bonifica } }
  @{ N='2f';Titolo='Diagnostica memoria vincolata (detentore e proiezione)'; Tipo='sola lettura'; Azione={ & (Join-Path $scripts 'Diagnostica-Vincolata.ps1') } }
  @{ N='2g';Titolo='Verifica rilascio vincolata (termina il sospetto)'; Tipo='MODIFICA';    Azione={ & (Join-Path $scripts 'Diagnostica-Vincolata.ps1') -VerificaRilascio } }
  @{ N='3'; Titolo='Report baseline di sicurezza (divario)';      Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Allinea-BestPractice.ps1') } }
  @{ N='4'; Titolo='Applica baseline di sicurezza (guidato)';     Tipo='MODIFICA';          Azione={ & (Join-Path $scripts 'Allinea-BestPractice.ps1') -Apply } }
  @{ N='5'; Titolo='Reinstalla software da winget export';        Tipo='MODIFICA';          Azione={ & (Join-Path $scripts 'Reinstall-Software.ps1') } }
  @{ N='6'; Titolo='Snapshot periodico: stato';                   Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Pianifica-Snapshot.ps1') } }
  @{ N='6i';Titolo='Snapshot periodico: INSTALLA (attivita pianif.)'; Tipo='MODIFICA';      Azione={ & (Join-Path $scripts 'Pianifica-Snapshot.ps1') -Installa } }
  @{ N='7'; Titolo='Check salute periodico: INSTALLA (attivita pianif.)'; Tipo='MODIFICA';  Azione={ & (Join-Path $scripts 'Controlla-Salute.ps1') -Installa } }
  @{ N='8'; Titolo='Design system di account: verifica la propagazione'; Tipo='sola lettura'; Azione={ & (Join-Path $scripts 'Installa-DesignSystem.ps1') -Verifica } }
  @{ N='9'; Titolo='PC NUOVO: piano della prima installazione';     Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Prima-Installazione.ps1') } }
  @{ N='9s';Titolo='PC NUOVO: scarica e verifica gli strumenti';    Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Prima-Installazione.ps1') -Scarica } }
  @{ N='9a';Titolo='PC NUOVO: esegui la catena (AI + debloat)';     Tipo='MODIFICA';          Azione={ & (Join-Path $scripts 'Prima-Installazione.ps1') -Applica } }
  @{ N='9c';Titolo='PC NUOVO: controlla i residui AI, dopo';        Tipo='sola lettura';      Azione={ & (Join-Path $scripts 'Prima-Installazione.ps1') -Controlla } }
  @{ N='10';Titolo='Censimento hardware di questa macchina (anonimo)'; Tipo='sola lettura';   Azione={ & (Join-Path $scripts 'censimento\hw-report-windows.ps1') } }
  @{ N='11';Titolo='Prepara la cartella per un PC nuovo (chiavetta)'; Tipo='sola lettura';   Azione={ & (Join-Path $scripts 'Prepara-Chiavetta.ps1') -Destinazione (Read-Host 'Destinazione (es. E:\)') } }
  @{ N='P'; Titolo='PC NUOVO: percorso guidato (dove sono arrivato)'; Tipo='sola lettura';   Azione={ Mostra-Percorso } }
  @{ N='12';Titolo='Monitoraggio: piano della macchina centrale';    Tipo='sola lettura';   Azione={ & (Join-Path $scripts 'Monitoraggio-Centrale.ps1') } }
  @{ N='12s';Titolo='Monitoraggio: scarica e verifica Prometheus e Grafana'; Tipo='sola lettura'; Azione={ & (Join-Path $scripts 'Monitoraggio-Centrale.ps1') -Scarica } }
)

# Percorso guidato del PC nuovo: non esegue niente da se', dice a che punto
# sei e qual e' la voce successiva. Lo stato lo deduce da cio' che e' verificabile
# sulla macchina; cio' che non e' verificabile lo dichiara tale invece di fingere.
function Mostra-Percorso {
    $snapRoot = Join-Path $base 'snapshots'
    $snapshot = @(Get-ChildItem $snapRoot -Directory -ErrorAction SilentlyContinue).Count
    $strumenti = Test-Path (Join-Path $env:TEMP 'windows-status-prima-installazione')
    $netdata  = [bool](Get-Service -Name 'netdata' -ErrorAction SilentlyContinue)
    $profilo  = Test-Path (Join-Path $scripts 'prima-installazione\profilo.json')
    $winget   = [bool](Get-ChildItem $snapRoot -Recurse -Filter 'software_winget.json' -ErrorAction SilentlyContinue)
    $punti    = 0
    try { $punti = @(Get-ComputerRestorePoint -ErrorAction Stop).Count } catch { }

    function Riga($fatto, $testo, $voce) {
        $segno = switch ($fatto) { 'si' {'[x]'} 'no' {'[ ]'} default {'[?]'} }
        $col   = switch ($fatto) { 'si' {'Green'} 'no' {'Yellow'} default {'DarkGray'} }
        Write-Host ("  {0} {1}" -f $segno, $testo) -NoNewline -ForegroundColor $col
        if ($voce) { Write-Host ("   -> voce $voce") -ForegroundColor Cyan } else { Write-Host '' }
    }

    Write-Host ''
    Write-Host '  PERCORSO DEL PC NUOVO' -ForegroundColor Cyan
    Write-Host '  [x] fatto   [ ] da fare   [?] non verificabile da qui' -ForegroundColor DarkGray
    Write-Host ''
    Riga 'si'  'progetto presente su questa macchina'                         $null
    Riga '?'   'immagine di sistema della macchina vergine (Veeam, docs\02)'  $null
    Riga $(if($profilo){'si'}else{'no'})   'profilo delle scelte (profilo.json, togli i menu di terze parti)' $null
    Riga $(if($punti -gt 0){'si'}else{'no'}) "punti di ripristino presenti: $punti"                  '9'
    Riga $(if($snapshot -gt 0){'si'}else{'no'}) "fotografie nel progetto: $snapshot"                 '1 oppure 9a'
    Riga $(if($strumenti){'si'}else{'no'}) 'strumenti di terze parti scaricati e verificati'         '9s'
    Riga '?'   'RemoveWindowsAI eseguito (lo dice il controllo dei residui)'  '9c'
    Riga '?'   'Win11Debloat eseguito'                                        '9a'
    Riga $(if($netdata){'si'}else{'no'}) 'Netdata installato (opzionale, vedi docs\16)'              '9a'
    Riga $(if($winget){'si'}else{'no'}) 'software_winget.json disponibile per la reinstallazione'    '11 sulla macchina VECCHIA'
    Riga '?'   'baseline di sicurezza applicato'                              '3 poi 4'
    Riga '?'   'identita git, SSH, Claude e Codex, dotfiles (docs\03,04,10)'  $null
    Write-Host ''
    Write-Host '  Ordine consigliato: immagine -> 9 -> 9s -> 9a -> RIAVVIO -> 9a -> RIAVVIO -> 9c -> 5 -> 3 -> 4' -ForegroundColor Cyan
    Write-Host '  Dettagli e cautele: LEGGIMI-PC-NUOVO.md in radice, e docs\16.'
    Write-Host '  I riavvii non sono mai automatici: li decidi tu.' -ForegroundColor Yellow
}

function Show-Menu {
    Write-Host ''
    Write-Host '==================================================================' -ForegroundColor Cyan
    Write-Host ' windows-status  —  avvio standardizzato' -ForegroundColor Cyan
    Write-Host '==================================================================' -ForegroundColor Cyan
    Write-Host ("Elevato (admin): {0}" -f $isAdmin) -NoNewline
    if(-not $isAdmin){ Write-Host '   (per snapshot completo e baseline servono i diritti admin)' -ForegroundColor Yellow } else { Write-Host '' }
    Write-Host ''
    foreach($v in $voci){
        $col = if($v.Tipo -eq 'MODIFICA'){ 'Yellow' } else { 'Green' }
        Write-Host ("  {0})  {1}" -f $v.N, $v.Titolo) -NoNewline
        Write-Host ("   [{0}]" -f $v.Tipo) -ForegroundColor $col
    }
    Write-Host '  0)  Esci'
    Write-Host ''
    Write-Host 'Promemoria: le voci [MODIFICA] richiedono paracadute (immagine Veeam + punto di ripristino),' -ForegroundColor Yellow
    Write-Host 'si applicano una categoria alla volta con verifica, e vanno a changelog nella mappa.' -ForegroundColor Yellow
    Write-Host 'Debloating: vedi docs\00 (PowerShell mirato vs Winhance/Winslop, §7) e il piano in context\current-work.md.'
}

if($Help){
    Write-Host 'Voci disponibili (windows-status\Avvia.ps1):'
    foreach($v in $voci){ Write-Host ("  {0})  {1}  [{2}]" -f $v.N, $v.Titolo, $v.Tipo) }
    Write-Host '  0)  Esci'
    return
}

# All'avvio: scelta esplicita dell'approccio di ottimizzazione (coerente con docs\00 §7)
Write-Host ''
Write-Host 'Approccio agli interventi di ottimizzazione/hardening su questa macchina:' -ForegroundColor Cyan
Write-Host '  - PowerShell mirato (predefinito): trasparente, reversibile, versionabile (Allinea-BestPractice, Remove-AppxPackage).'
Write-Host '  - Strumenti esterni (Winhance/Winslop): solo da fonte ufficiale, in modalita inspect, SEMPRE tra due snapshot (vedi docs\00 §7).'
Write-Host 'La scelta si fa al momento di ogni intervento; questo menu usa la via PowerShell mirato.'

do {
    Show-Menu
    $scelta = Read-Host 'Scegli una voce'
    $v = $voci | Where-Object N -eq $scelta
    if($scelta -eq '0'){ break }
    elseif($v){
        if($v.Tipo -eq 'MODIFICA'){
            Write-Host ''
            Write-Host "Stai per eseguire un'azione che MODIFICA il sistema: $($v.Titolo)" -ForegroundColor Yellow
            $ok = Read-Host 'Hai un backup immagine recente e un punto di ripristino? Procedo? (s/N)'
            if($ok -notmatch '^[sS]'){ Write-Host 'Annullato.'; continue }
        }
        & $v.Azione
        Write-Host ''
        Read-Host 'Premi Invio per tornare al menu' | Out-Null
    } else { Write-Host 'Scelta non valida.' -ForegroundColor Red }
} while($true)

Write-Host 'Uscita. Ricorda: git add/commit/push restano manuali; verifica niente segreti prima di un push.'
