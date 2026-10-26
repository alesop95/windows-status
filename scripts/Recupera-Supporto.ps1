<#
================================================================================
 Recupera-Supporto.ps1  -  Copia via un supporto rimovibile che sta cedendo
================================================================================

 Un supporto che cede non si comporta come uno morto: si monta regolarmente e
 poi fa cadere la sessione interattiva. Il blocco non lo produce il dispositivo,
 lo producono i quattro componenti che gli vanno addosso da soli appena compare
 una lettera di unita' - AutoPlay, la shell con le anteprime, l'indicizzatore e
 l'antivirus - che su un supporto che non risponde restano tutti in attesa.

 Lo script si lancia PRIMA di collegare il supporto e resta in attesa. Rileva la
 comparsa della lettera con fsutil, che non passa dal provider Storage e quindi
 non si appende, e copia all'istante senza un solo tentativo di ripetizione.

 Non scrive mai sul supporto di origine. Si interrompe con Ctrl+C.

 Prima di lanciarlo, da PowerShell amministratore:
     Set-Service WSearch -StartupType Manual
     Stop-Service WSearch
 e AutoPlay disattivato. Il contesto completo sta in
 docs/18_USB_SOSPENSIONE_E_SUPPORTI_RIMOVIBILI.md, paragrafo 9.
================================================================================
#>

[CmdletBinding()]
param(
    # Dove finiscono i dati recuperati. Dentro ci nasce una cartella datata.
    # Obbligatorio e senza valore predefinito: un percorso cablato nel sorgente
    # finisce nel repository, e il contenuto di un supporto riservato non si
    # annuncia nel nome di una cartella versionata.
    [Parameter(Mandatory = $true)]
    [string]$Destinazione,

    # Per quanto restare in attesa del supporto, in secondi.
    [int]$AttesaMax = 300
)

$ErrorActionPreference = 'Stop'

function Get-Lettere {
    # fsutil e' l'unico modo affidabile di elencare le lettere quando c'e' di
    # mezzo un supporto che non risponde: non passa dal provider Storage, che
    # invece si appende. Get-Volume, Get-Disk e Get-PSDrive qui non si usano.
    $out = & fsutil.exe fsinfo drives 2>$null
    if (-not $out) { return @() }
    return @([regex]::Matches(($out -join ' '), '([A-Za-z]):\\') | ForEach-Object { $_.Groups[1].Value.ToUpper() })
}

Write-Host ''
Write-Host '=== Recupero da supporto che risponde male ===' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path -LiteralPath $Destinazione)) {
    throw "Destinazione inesistente: $Destinazione"
}

$iniziali = @(Get-Lettere)
Write-Host ("Lettere gia' presenti: " + ($iniziali -join ' '))
Write-Host ''
Write-Host 'ADESSO collega il supporto. Non aprire Esplora risorse, non cliccare niente.' -ForegroundColor Yellow
Write-Host ("In attesa fino a $AttesaMax secondi...")
Write-Host ''

$t0 = Get-Date
$nuova = $null
while (((Get-Date) - $t0).TotalSeconds -lt $AttesaMax) {
    Start-Sleep -Milliseconds 1500
    $adesso = @(Get-Lettere)
    $diff = @($adesso | Where-Object { $iniziali -notcontains $_ })
    if ($diff.Count -gt 0) { $nuova = $diff[0]; break }
    Write-Host '.' -NoNewline
}
Write-Host ''

if (-not $nuova) {
    Write-Host ''
    Write-Host 'Nessuna lettera nuova: il supporto non si e'' montato.' -ForegroundColor Red
    Write-Host 'Scollegalo fisicamente. Non usare la rimozione sicura: passa dallo stesso'
    Write-Host 'meccanismo che si blocca, quindi si pianta anche lei.'
    exit 1
}

$origine = "${nuova}:\"
$secondi = [int]((Get-Date) - $t0).TotalSeconds
Write-Host ''
Write-Host ("MONTATO su ${nuova}: dopo $secondi secondi. Copio subito.") -ForegroundColor Green

$cartella = Join-Path $Destinazione ('recupero-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $cartella -Force | Out-Null
$log = Join-Path $cartella '_copia.log'

Write-Host ("Destinazione: $cartella")
Write-Host ''

# /R:0 /W:0 e' il cuore della cosa: zero tentativi, zero attesa fra un tentativo
# e l'altro. Su un supporto sano non cambia niente; su uno che sta cedendo
# evita che robocopy resti appeso per minuti su ogni settore illeggibile.
# Niente /MT: le letture parallele su un controller in difficolta' peggiorano
# le cose. /XJ per non seguire collegamenti.
$argomenti = @(
    $origine, $cartella,
    '/E', '/XJ',
    '/R:0', '/W:0',
    '/NP', '/NDL',
    '/COPY:DAT',
    ('/LOG:' + $log), '/TEE'
)

$inizio = Get-Date
& robocopy.exe @argomenti
$codice = $LASTEXITCODE
$durata = (Get-Date) - $inizio

Write-Host ''
Write-Host '=== Esito ===' -ForegroundColor Cyan

$file = @(Get-ChildItem -LiteralPath $cartella -Recurse -File -Force -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -ne $log })
$byte = ($file | Measure-Object -Property Length -Sum).Sum
if (-not $byte) { $byte = 0 }

Write-Host ("File copiati:  {0}" -f $file.Count)
Write-Host ("Totale:        {0:N1} MB" -f ($byte / 1MB))
Write-Host ("Durata:        {0:mm\:ss}" -f $durata)
Write-Host ("Codice:        {0}" -f $codice)
Write-Host ("Cartella:      {0}" -f $cartella)
Write-Host ("Log:           {0}" -f $log)
Write-Host ''

if ($codice -ge 8) {
    Write-Host 'ATTENZIONE: alcuni file NON sono stati copiati. Leggi il log.' -ForegroundColor Red
    Write-Host 'Quello che e'' arrivato e'' comunque buono e sta nella cartella.'
    Write-Host 'I fallimenti su System Volume Information sono normali e irrilevanti.'
} else {
    Write-Host 'Copia completata senza errori.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Adesso scollega il supporto fisicamente. Non usare la rimozione sicura.' -ForegroundColor Yellow
