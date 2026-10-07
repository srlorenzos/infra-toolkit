# infra-toolkit

[![qualidade](https://github.com/srlorenzos/infra-toolkit/actions/workflows/lint.yml/badge.svg)](https://github.com/srlorenzos/infra-toolkit/actions/workflows/lint.yml) ![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207-5391FE?logo=powershell&logoColor=white) ![Bash](https://img.shields.io/badge/Bash-4%2B-4EAA25?logo=gnubash&logoColor=white)

Scripts curtos e práticos para **suporte técnico e infraestrutura**, em Windows (PowerShell) e Linux (Bash). Cada um responde rápido à pergunta "o que está errado com esta máquina?".

| Script | Plataforma | O que faz |
| --- | --- | --- |
| [`windows/Get-SystemHealth.ps1`](windows/Get-SystemHealth.ps1) | Windows | Relatório HTML: uptime, CPU, memória, discos com alerta, serviços automáticos parados, reinício pendente, últimas atualizações e processos que mais consomem. |
| [`windows/Test-Network.ps1`](windows/Test-Network.ps1) | Windows | Diagnóstico de rede em etapas (adaptador, gateway, DNS, internet, resolução de nomes, portas TCP, IP público) com OK/FALHA. |
| [`linux/health-check.sh`](linux/health-check.sh) | Linux | Carga, memória, discos acima do limite, serviços systemd com falha, reinício pendente e top de processos. Sai com código 1 se algo pedir atenção (bom para cron e monitoramento). |
| [`linux/net-check.sh`](linux/net-check.sh) | Linux | Mesmo diagnóstico de rede em etapas, usando só ferramentas padrão (`ip`, `ping`, `getent`, `/dev/tcp`, `curl`). |

## Uso

```powershell
# Windows (PowerShell 5.1 ou 7)
.\windows\Get-SystemHealth.ps1                      # gera e abre o relatório HTML
.\windows\Get-SystemHealth.ps1 -DiskWarnPercent 15 -OutFile C:\Temp\saude.html
.\windows\Test-Network.ps1 -Hosts outlook.office365.com -Ports 443,3389
```

```bash
# Linux
./linux/health-check.sh 85        # alerta com disco acima de 85% de uso
./linux/net-check.sh github.com "443 22"
```

Se o PowerShell bloquear a execução: `Set-ExecutionPolicy -Scope Process Bypass`.

Os scripts só leem informações do sistema: nenhum altera configuração, apaga arquivo ou instala nada.

## Licença

MIT © Eduardo Lorenzo
