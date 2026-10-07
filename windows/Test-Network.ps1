<#
.SYNOPSIS
    Diagnóstico rápido de rede para atendimento de suporte: adaptador e IP, gateway, DNS,
    acesso à internet, resolução de nomes, portas TCP e IP público. Mostra um resultado OK/FALHA por etapa.

.EXAMPLE
    .\Test-Network.ps1
    .\Test-Network.ps1 -Hosts github.com, outlook.office365.com -Ports 443, 3389
#>
[CmdletBinding()]
param(
    [string[]]$Hosts = @('google.com', 'microsoft.com', 'github.com'),
    [int[]]$Ports = @(443, 80),
    [string]$PortTarget = 'github.com',
    [string]$InternetProbe = '1.1.1.1'
)

$results = [System.Collections.Generic.List[object]]::new()
function Add-Result([string]$etapa, [bool]$ok, [string]$detalhe) {
    $results.Add([pscustomobject]@{ Etapa = $etapa; Resultado = if ($ok) { 'OK' } else { 'FALHA' }; Detalhe = $detalhe })
}

$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
if ($cfg) {
    Add-Result 'Adaptador' $true "$($cfg.InterfaceAlias) — $($cfg.IPv4Address.IPAddress)"
    $gw = $cfg.IPv4DefaultGateway.NextHop
    $gwOk = Test-Connection -ComputerName $gw -Count 2 -Quiet -ErrorAction SilentlyContinue
    Add-Result 'Gateway' $gwOk $gw
    $dnsServers = ($cfg.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses
    Add-Result 'Servidores DNS' ([bool]$dnsServers) ($dnsServers -join ', ')
} else {
    Add-Result 'Adaptador' $false 'Nenhum adaptador conectado com gateway'
}

$inetOk = Test-Connection -ComputerName $InternetProbe -Count 2 -Quiet -ErrorAction SilentlyContinue
Add-Result "Internet ($InternetProbe)" $inetOk 'ping'

foreach ($h in $Hosts) {
    try {
        $ip = (Resolve-DnsName -Name $h -Type A -ErrorAction Stop | Where-Object Type -eq 'A' | Select-Object -First 1).IPAddress
        Add-Result "DNS $h" $true $ip
    } catch {
        Add-Result "DNS $h" $false $_.Exception.Message
    }
}

foreach ($p in $Ports) {
    $t = Test-NetConnection -ComputerName $PortTarget -Port $p -WarningAction SilentlyContinue
    Add-Result "Porta $p em $PortTarget" $t.TcpTestSucceeded $t.RemoteAddress
}

try {
    $pub = (Invoke-RestMethod -Uri 'https://api.ipify.org?format=json' -TimeoutSec 5).ip
    Add-Result 'IP público' $true $pub
} catch {
    Add-Result 'IP público' $false 'sem resposta'
}

foreach ($r in $results) {
    $color = if ($r.Resultado -eq 'OK') { 'Green' } else { 'Red' }
    Write-Host ("[{0,-5}] {1,-28} {2}" -f $r.Resultado, $r.Etapa, $r.Detalhe) -ForegroundColor $color
}
$fail = @($results | Where-Object Resultado -eq 'FALHA').Count
Write-Host ''
if ($fail -eq 0) { Write-Host 'Rede OK.' -ForegroundColor Green } else { Write-Host "$fail etapa(s) com falha." -ForegroundColor Yellow }
