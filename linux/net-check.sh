#!/usr/bin/env bash
# Diagnóstico de rede em etapas (gateway, internet, DNS, portas, IP público). OK/FALHA por etapa.
# Uso: ./net-check.sh [host_para_portas=github.com] [portas="443 80"]
set -uo pipefail

TARGET="${1:-github.com}"
PORTS="${2:-443 80}"
FAILS=0
ok()   { printf '\033[32m[ OK  ]\033[0m %-26s %s\n' "$1" "${2:-}"; }
fail() { printf '\033[31m[FALHA]\033[0m %-26s %s\n' "$1" "${2:-}"; FAILS=$((FAILS + 1)); }

gw=$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')
if [[ -n "$gw" ]] && ping -c 2 -W 2 "$gw" >/dev/null 2>&1; then ok "Gateway" "$gw"; else fail "Gateway" "${gw:-sem rota padrão}"; fi

if ping -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then ok "Internet (1.1.1.1)"; else fail "Internet (1.1.1.1)"; fi

for h in google.com github.com; do
  ipaddr=$(getent ahostsv4 "$h" | awk '{print $1; exit}')
  if [[ -n "$ipaddr" ]]; then ok "DNS $h" "$ipaddr"; else fail "DNS $h"; fi
done

for p in $PORTS; do
  if timeout 4 bash -c "</dev/tcp/$TARGET/$p" 2>/dev/null; then ok "Porta $p em $TARGET"; else fail "Porta $p em $TARGET"; fi
done

pub=$(curl -s --max-time 5 https://api.ipify.org || true)
if [[ -n "$pub" ]]; then ok "IP público" "$pub"; else fail "IP público" "sem resposta"; fi

echo
if (( FAILS == 0 )); then echo "Rede OK."; else echo "$FAILS etapa(s) com falha."; fi
exit $(( FAILS > 0 ))
