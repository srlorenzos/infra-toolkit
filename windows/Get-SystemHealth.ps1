<#
.SYNOPSIS
    Relatório de saúde do Windows em HTML: sistema, uptime, CPU, memória, discos, serviços parados,
    reinicialização pendente, últimas atualizações e processos que mais consomem.

.EXAMPLE
    .\Get-SystemHealth.ps1
    .\Get-SystemHealth.ps1 -OutFile C:\Temp\saude.html -DiskWarnPercent 15
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $env:TEMP ("saude-{0}-{1:yyyyMMdd-HHmm}.html" -f $env:COMPUTERNAME, (Get-Date))),
    [int]$DiskWarnPercent = 10,
    [switch]$NoOpen
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-Badge([bool]$ok, [string]$okText = 'OK', [string]$badText = 'ATENÇÃO') {
    if ($ok) { "<span class='ok'>$okText</span>" } else { "<span class='bad'>$badText</span>" }
}

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$uptime = (Get-Date) - $os.LastBootUpTime
$cpuLoad = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 0)
$memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
$memFree = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
$memUsedPct = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 0)

$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freePct = if ($_.Size) { [math]::Round($_.FreeSpace / $_.Size * 100, 0) } else { 0 }
    [pscustomobject]@{
        Unidade = $_.DeviceID
        Total   = "{0:N1} GB" -f ($_.Size / 1GB)
        Livre   = "{0:N1} GB" -f ($_.FreeSpace / 1GB)
        PctLivre = $freePct
        Status  = Get-Badge ($freePct -ge $DiskWarnPercent)
    }
}

$pendingReboot = (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
    (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')

$stoppedAuto = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" |
    Where-Object { $_.Name -notmatch 'sppsvc|gupdate|edgeupdate|RemoteRegistry|MapsBroker|TrustedInstaller' } |
    Select-Object @{n = 'Serviço'; e = { $_.DisplayName } }, @{n = 'Nome'; e = { $_.Name } }, @{n = 'Estado'; e = { $_.State } }

$hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 |
    Select-Object @{n = 'Atualização'; e = { $_.HotFixID } }, @{n = 'Tipo'; e = { $_.Description } }, @{n = 'Instalada em'; e = { $_.InstalledOn } }

$topProc = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 |
    Select-Object @{n = 'Processo'; e = { $_.ProcessName } }, @{n = 'Memória'; e = { "{0:N0} MB" -f ($_.WorkingSet64 / 1MB) } }, @{n = 'CPU (s)'; e = { [math]::Round($_.CPU, 1) } }

$style = @'
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#0f1117;color:#e6e6e6;margin:0;padding:24px}
h1{margin:0 0 4px;font-size:24px} h2{font-size:16px;margin:24px 0 8px;color:#9fb3ff}
.muted{color:#8a8fa3;font-size:13px} table{border-collapse:collapse;width:100%;max-width:900px}
th,td{text-align:left;padding:6px 10px;border-bottom:1px solid #262a36;font-size:13px}
th{color:#8a8fa3;font-weight:600} .ok{color:#3ecf7a;font-weight:700} .bad{color:#ff6b6b;font-weight:700}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;max-width:900px}
.card{background:#171a23;border-radius:10px;padding:12px} .big{font-size:22px;font-weight:700}
</style>
'@

$cards = @"
<div class='grid'>
<div class='card'><div class='muted'>Uptime</div><div class='big'>$($uptime.Days)d $($uptime.Hours)h</div></div>
<div class='card'><div class='muted'>CPU agora</div><div class='big'>$cpuLoad%</div></div>
<div class='card'><div class='muted'>Memória usada</div><div class='big'>$memUsedPct%</div><div class='muted'>$memFree GB livres de $memTotal GB</div></div>
<div class='card'><div class='muted'>Reinício pendente</div><div class='big'>$(Get-Badge (-not $pendingReboot) 'Não' 'Sim')</div></div>
</div>
"@

$html = @"
<!doctype html><html lang='pt-BR'><head><meta charset='utf-8'><title>Saúde — $env:COMPUTERNAME</title>$style</head><body>
<h1>$env:COMPUTERNAME</h1>
<div class='muted'>$($os.Caption) $($os.Version) · $($cs.Manufacturer) $($cs.Model) · $($cpu.Name) · gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm')</div>
<h2>Resumo</h2>$cards
<h2>Discos</h2>$(($disks | Select-Object Unidade, Total, Livre, @{n='% livre';e={$_.PctLivre}}, Status | ConvertTo-Html -Fragment) -replace '&lt;','<' -replace '&gt;','>' -replace '&#39;',"'")
<h2>Serviços automáticos parados</h2>$(if ($stoppedAuto) { $stoppedAuto | ConvertTo-Html -Fragment } else { "<span class='ok'>Nenhum</span>" })
<h2>Últimas atualizações</h2>$($hotfixes | ConvertTo-Html -Fragment)
<h2>Processos que mais usam memória</h2>$($topProc | ConvertTo-Html -Fragment)
</body></html>
"@

$html | Out-File -FilePath $OutFile -Encoding utf8
Write-Host "Relatório salvo em $OutFile"
if (-not $NoOpen) { Start-Process $OutFile }
