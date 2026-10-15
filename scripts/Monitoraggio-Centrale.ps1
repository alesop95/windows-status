# =============================================================================
#  Monitoraggio-Centrale.ps1  -  la macchina che guarda le altre
#  windows-status. Vedi docs\17.
# =============================================================================
#  LA FORMA. Sui PC sta solo windows_exporter: undici megabyte, un servizio,
#  nessuna interfaccia. Qui sta il resto, UNA volta sola per tutto il parco:
#
#      Prometheus   Apache-2.0   interroga gli exporter, archivia, allarmi
#      Loki         AGPL-3.0     riceve i log che gli agenti Alloy spingono
#      Grafana OSS  AGPL-3.0     i cruscotti, che leggono da Prometheus e Loki
#
#  Nessun account, nessun token, nessuna chiave, nessun limite di nodi. Tutto
#  sulle proprie macchine. Grafana OSS non e' Grafana Cloud: qui non si usa.
#
#  ONESTA' SU WINDOWS. Grafana si installa come servizio dal suo MSI.
#  Prometheus no: il suo binario non e' un servizio di Windows, e per farlo
#  partire da solo servono o un involucro di terze parti (NSSM, WinSW) o
#  un'attivita' pianificata all'avvio. Questo script usa la seconda, che non
#  aggiunge dipendenze. Se la macchina centrale e' un Linux, li' Prometheus e'
#  un pacchetto con il suo servizio e tutto questo non serve: vedi docs\17.
#
#  SOLA LETTURA per default.
#
#  USO
#    .\Monitoraggio-Centrale.ps1                          # piano
#    .\Monitoraggio-Centrale.ps1 -Scarica                 # scarica e verifica
#    .\Monitoraggio-Centrale.ps1 -Config -Macchine pc01,pc02,pc03
#    .\Monitoraggio-Centrale.ps1 -Installa -Macchine pc01,pc02
# =============================================================================

[CmdletBinding()]
param(
    # Scarica Prometheus e Grafana OSS alle versioni appuntate e ne verifica il
    # digest. Circa 600 MB in tutto: si fa una volta sola, qui.
    [switch]   $Scarica,

    # Genera prometheus.yml dall'elenco delle macchine, senza installare niente.
    [switch]   $Config,

    # Installa: estrae Prometheus, lo avvia con un'attivita' pianificata, e
    # installa Grafana OSS. Chiede conferma a ogni passo.
    [switch]   $Installa,

    # Le macchine da interrogare: nomi o indirizzi, separati da virgola.
    [string[]] $Macchine,

    # La porta su cui risponde windows_exporter sui PC.
    [int]      $Porta = 9182,

    # Ogni quanto interrogare. Prometheus usa 15s di default; 1s non si fa.
    [string]   $Intervallo = '15s',

    # Per quanto tenere la serie storica.
    [string]   $Ritenzione = '90d',

    # Dove installare. Per default sotto ProgramData, che non e' sincronizzata
    # da niente e sopravvive ai profili utente.
    [string]   $Cartella = (Join-Path $env:ProgramData 'windows-status-monitoraggio')
)

$ErrorActionPreference = 'Stop'
$Manifesto = Join-Path $PSScriptRoot 'prima-installazione\strumenti.json'

function Titolo { param([string]$T)
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor DarkGray
    Write-Host "  $T" -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor DarkGray
}
function Ok     { param([string]$T) Write-Host "  [ok]      $T" -ForegroundColor Green }
function Info   { param([string]$T) Write-Host "  [info]    $T" }
function Avviso { param([string]$T) Write-Host "  [attenzione] $T" -ForegroundColor Yellow }

function Conferma {
    param([string]$Domanda)
    Write-Host ''
    Write-Host "  $Domanda" -ForegroundColor Yellow
    return ((Read-Host '  Digita SI per procedere') -eq 'SI')
}

function Strumenti-Centrali {
    $j = Get-Content $Manifesto -Raw -Encoding UTF8 | ConvertFrom-Json
    return @($j.strumenti | Where-Object { $_.ruolo -eq 'centrale' })
}

function Prendi {
    param($T)
    if (-not (Test-Path $Cartella)) { New-Item -ItemType Directory -Path $Cartella -Force | Out-Null }
    $file = Join-Path $Cartella $T.ingresso
    if (-not (Test-Path $file)) {
        Info "$($T.nome) $($T.versione): scarico ($([math]::Round($T.byte/1MB)) MB)"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $v = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
        try { Invoke-WebRequest -Uri $T.url -OutFile $file -UseBasicParsing } finally { $ProgressPreference = $v }
    } else { Info "$($T.nome): gia' presente" }

    $h = (Get-FileHash $file -Algorithm SHA256).Hash.ToLower()
    if ($h -ne $T.sha256.ToLower()) {
        Avviso "$($T.nome): DIGEST DIVERSO da quello pubblicato dall'autore"
        Info   "  atteso  : $($T.sha256)"
        Info   "  trovato : $h"
        throw "Digest non corrispondente per $($T.nome)."
    }
    Ok "$($T.nome): digest verificato"
    return $file
}

function Scrivi-Config {
    param([string[]]$Host_, [string]$Percorso)
    $bersagli = ($Host_ | ForEach-Object { "          - '{0}:{1}'" -f $_, $Porta }) -join "`n"
    $yml = @"
# prometheus.yml - generato da windows-status\scripts\Monitoraggio-Centrale.ps1
# $(Get-Date -Format 'yyyy-MM-dd HH:mm')
#
# Ogni macchina qui sotto deve avere windows_exporter in ascolto sulla porta
# $Porta, e la sua regola firewall deve lasciar passare SOLO questa macchina.

global:
  scrape_interval: $Intervallo
  evaluation_interval: $Intervallo

rule_files:
  - 'regole.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'windows'
    static_configs:
      - targets:
$bersagli
"@
    $regole = @"
# regole.yml - allarmi di base, da ampliare.
# Prometheus li valuta; a notificarli ci pensa Grafana oppure Alertmanager.
groups:
  - name: macchine
    rules:
      - alert: MacchinaNonRaggiungibile
        expr: up{job="windows"} == 0
        for: 5m
        labels:
          gravita: critico
        annotations:
          descrizione: '{{ `$labels.instance }} non risponde da 5 minuti'

      - alert: DiscoQuasiPieno
        expr: windows_logical_disk_free_bytes / windows_logical_disk_size_bytes < 0.10
        for: 15m
        labels:
          gravita: avviso
        annotations:
          descrizione: '{{ `$labels.instance }} volume {{ `$labels.volume }} sotto il 10% libero'

      - alert: MemoriaQuasiEsaurita
        expr: windows_os_physical_memory_free_bytes / windows_cs_physical_memory_bytes < 0.10
        for: 15m
        labels:
          gravita: avviso
        annotations:
          descrizione: '{{ `$labels.instance }} meno del 10% di memoria libera'
"@
    # Loki vuole la barra in avanti anche su Windows. Si usa il metodo Replace
    # e non l'operatore -replace, che interpreterebbe il modello come regex.
    $datiLoki = (Join-Path $Percorso 'dati-loki').Replace([char]92, '/')
    $loki = @"
# loki-config.yaml - generato da windows-status
# Configurazione a binario singolo, archivio su disco locale: per un parco di
# ufficio basta e avanza, e non tira dentro nessun servizio esterno.

auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: warn

common:
  instance_addr: 127.0.0.1
  path_prefix: $datiLoki
  storage:
    filesystem:
      chunks_directory: $datiLoki/chunks
      rules_directory: $datiLoki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: $Ritenzione
  reject_old_samples: false

compactor:
  working_directory: $datiLoki/compactor
  retention_enabled: true
  delete_request_store: filesystem
"@
    $loki | Set-Content (Join-Path $Percorso 'loki-config.yaml') -Encoding UTF8
    Ok "loki-config.yaml scritto (ritenzione $Ritenzione)"

    $yml    | Set-Content (Join-Path $Percorso 'prometheus.yml') -Encoding UTF8
    $regole | Set-Content (Join-Path $Percorso 'regole.yml') -Encoding UTF8
    Ok "prometheus.yml e regole.yml scritti in $Percorso"
}

# --- piano -------------------------------------------------------------------

$centrali = Strumenti-Centrali

if (-not $Scarica -and -not $Config -and -not $Installa) {
    Titolo 'MACCHINA CENTRALE DEL MONITORAGGIO - piano'
    Info 'Sui PC: windows_exporter (11 MB). Qui: Prometheus e Grafana OSS.'
    Info "cartella : $Cartella"
    Write-Host ''
    foreach ($t in $centrali) {
        Write-Host ("    {0,-14} {1,-12} {2,-10} {3} MB" -f $t.nome, $t.licenza, $t.versione, [math]::Round($t.byte/1MB))
    }
    Write-Host ''
    Write-Host '  Nessun account, nessun token, nessun limite di nodi.' -ForegroundColor Green
    Write-Host '  Grafana OSS non e'' Grafana Cloud: qui non serve e non si usa.'
    Write-Host ''
    Info 'Ordine: -Scarica, poi -Config -Macchine <elenco>, poi -Installa.'
    Info 'Se la macchina centrale e'' un Linux, su quella conviene usare i'
    Info 'pacchetti della distribuzione: vedi docs\17.'
    return
}

if ($Scarica) {
    Titolo 'SCARICAMENTO E VERIFICA'
    foreach ($t in $centrali) { Prendi $t | Out-Null }
    Ok "pronti in $Cartella"
}

if ($Config) {
    Titolo 'CONFIGURAZIONE'
    if (-not $Macchine -or $Macchine.Count -eq 0) { throw 'Serve -Macchine con l''elenco dei PC da interrogare.' }
    $Macchine = @($Macchine | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ })
    if (-not (Test-Path $Cartella)) { New-Item -ItemType Directory -Path $Cartella -Force | Out-Null }
    Info "macchine: $($Macchine -join ', ')"
    Info "intervallo $Intervallo, ritenzione $Ritenzione, porta $Porta"
    Scrivi-Config $Macchine $Cartella
}

if ($Installa) {
    Titolo 'INSTALLAZIONE'
    $prom = $centrali | Where-Object { $_.nome -eq 'Prometheus' }
    $graf = $centrali | Where-Object { $_.nome -eq 'Grafana OSS' }

    $zip = Prendi $prom
    $msi = Prendi $graf

    if (-not (Test-Path (Join-Path $Cartella 'prometheus.yml'))) {
        if (-not $Macchine) { throw 'Manca prometheus.yml: ripeti con -Config -Macchine <elenco>.' }
        $Macchine = @($Macchine | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ })
        Scrivi-Config $Macchine $Cartella
    }

    $dirProm = Join-Path $Cartella 'prometheus'
    if (-not (Test-Path $dirProm)) {
        Info 'estraggo Prometheus'
        Expand-Archive -Path $zip -DestinationPath $Cartella -Force
        $estratta = Get-ChildItem $Cartella -Directory | Where-Object { $_.Name -like 'prometheus-*' } | Select-Object -First 1
        if ($estratta) { Move-Item $estratta.FullName $dirProm }
        Ok "Prometheus in $dirProm"
    } else { Info 'Prometheus gia'' estratto' }

    Copy-Item (Join-Path $Cartella 'prometheus.yml') $dirProm -Force
    Copy-Item (Join-Path $Cartella 'regole.yml')     $dirProm -Force

    Write-Host ''
    Info 'Il binario di Prometheus non e'' un servizio di Windows: lo si avvia con'
    Info 'un''attivita'' pianificata all''avvio, che non aggiunge dipendenze.'
    if (Conferma 'Creo l''attivita'' pianificata che avvia Prometheus all''avvio?') {
        $exe = Join-Path $dirProm 'prometheus.exe'
        $az  = New-ScheduledTaskAction -Execute $exe `
               -Argument "--config.file=prometheus.yml --storage.tsdb.retention.time=$Ritenzione" `
               -WorkingDirectory $dirProm
        $tr  = New-ScheduledTaskTrigger -AtStartup
        $pr  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $st  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskName 'windows-status Prometheus' -Action $az -Trigger $tr `
            -Principal $pr -Settings $st -Force | Out-Null
        Start-ScheduledTask -TaskName 'windows-status Prometheus'
        Ok 'attivita'' creata e avviata: Prometheus su http://localhost:9090'
    }

    $zipLoki = Prendi ($centrali | Where-Object { $_.nome -eq 'Loki' })
    $dirLoki = Join-Path $Cartella 'loki'
    if (-not (Test-Path $dirLoki)) { New-Item -ItemType Directory -Path $dirLoki -Force | Out-Null }
    if (-not (Test-Path (Join-Path $dirLoki 'loki-windows-amd64.exe'))) {
        Info 'estraggo Loki'
        Expand-Archive -Path $zipLoki -DestinationPath $dirLoki -Force
    }
    Copy-Item (Join-Path $Cartella 'loki-config.yaml') $dirLoki -Force
    Ok "Loki in $dirLoki"

    Write-Host ''
    Info 'Anche Loki, come Prometheus, non e'' un servizio di Windows.'
    if (Conferma 'Creo l''attivita'' pianificata che avvia Loki all''avvio?') {
        $exeLoki = Join-Path $dirLoki 'loki-windows-amd64.exe'
        $azL = New-ScheduledTaskAction -Execute $exeLoki -Argument '-config.file=loki-config.yaml' -WorkingDirectory $dirLoki
        $trL = New-ScheduledTaskTrigger -AtStartup
        $prL = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $stL = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskName 'windows-status Loki' -Action $azL -Trigger $trL -Principal $prL -Settings $stL -Force | Out-Null
        Start-ScheduledTask -TaskName 'windows-status Loki'
        Ok 'attivita'' creata e avviata: Loki su http://localhost:3100'
        Info 'I PC devono poter RAGGIUNGERE la porta 3100 di questa macchina:'
        Info 'sono loro a spingere i log, non e'' questa a chiederli.'
    }

    Write-Host ''
    if (Conferma 'Installo Grafana OSS (servizio, circa 473 MB sul disco)?') {
        $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/qn','/i',"`"$msi`"") -Wait -PassThru
        Info "msiexec terminato con codice $($p.ExitCode)"
        $svc = Get-Service -Name 'Grafana' -ErrorAction SilentlyContinue
        if ($svc) { Ok "servizio Grafana presente, stato $($svc.Status)" } else { Avviso 'servizio Grafana non trovato' }
    }

    Write-Host ''
    Titolo 'COSA FARE ADESSO, A MANO'
    Info '1. Apri Grafana: http://localhost:3000   (admin / admin al primo accesso,'
    Info '   che va cambiata subito: e'' la prima cosa che chiede)'
    Info '2. Connections > Data sources > Add > Prometheus'
    Info '   URL: http://localhost:9090   e Save & test'
    Info '2b. Connections > Data sources > Add > Loki'
    Info '   URL: http://localhost:3100   e Save & test'
    Info '3. Dashboards > New > Import > ID 14694 (Windows Exporter Dashboard,'
    Info '   della comunita'') e scegli la fonte dati appena creata'
    Info '4. Verifica i bersagli: http://localhost:9090/targets  devono essere UP'
    Write-Host ''
    Info '5. Esplora i log: Explore > fonte dati Loki > query  {sistema="windows"}'
    Write-Host ''
    Avviso 'Porte di questa macchina: Grafana 3000 (chi guarda), Prometheus 9090'
    Avviso '(solo locale), Loki 3100 (raggiungibile DAI PC che spingono i log).'
    Avviso 'Tutto il resto va chiuso verso la rete.'
}
