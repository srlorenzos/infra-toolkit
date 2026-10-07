#!/usr/bin/env bash
# Saúde rápida de um servidor Linux: uptime, carga, memória, discos, serviços com falha,
# reinício pendente e processos que mais consomem. Sai com código 1 se algo pedir atenção.
# Uso: ./health-check.sh [limite_disco_%_usado=90]
set -uo pipefail

LIMIT="${1:-90}"
WARN=0
ok()   { printf '\033[32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[ATEN]\033[0m %s\n' "$*"; WARN=1; }

# shellcheck source=/dev/null
echo "== $(hostname) — $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") — $(date '+%d/%m/%Y %H:%M')"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"

cores=$(nproc)
load1=$(cut -d' ' -f1 /proc/loadavg)
if awk -v l="$load1" -v c="$cores" 'BEGIN{exit !(l > c)}'; then warn "Carga $load1 acima de $cores núcleos"; else ok "Carga $load1 ($cores núcleos)"; fi

read -r total avail < <(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t, a}' /proc/meminfo)
used_pct=$(( (total - avail) * 100 / total ))
if (( used_pct >= 90 )); then warn "Memória ${used_pct}% usada"; else ok "Memória ${used_pct}% usada"; fi

while read -r fs pct mnt; do
  p=${pct%\%}
  if (( p >= LIMIT )); then warn "Disco $mnt ($fs) ${pct} usado"; else ok "Disco $mnt ${pct} usado"; fi
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1{print $1, $5, $6}')

if command -v systemctl >/dev/null; then
  failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
  if [[ -n "$failed" ]]; then warn "Serviços com falha: $(echo "$failed" | tr '\n' ' ')"; else ok "Nenhum serviço com falha"; fi
fi

if [[ -f /var/run/reboot-required ]]; then warn "Reinício pendente"; else ok "Sem reinício pendente"; fi

echo
echo "Processos que mais usam memória:"
ps -eo pid,comm,%mem,%cpu --sort=-%mem | head -n 6

exit "$WARN"
