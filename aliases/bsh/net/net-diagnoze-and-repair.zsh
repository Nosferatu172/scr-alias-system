#!/usr/bin/env zsh
# Script Name: net-diagnoze-and-repair.zsh
# ID: SCR-ID-20260317130553-IY33H9QLME
# Assigned with:
# Created by: Tyler Jensen
# Email: tylerjensen5@yahoo.com
# Alias Call: net-diagnoze-and-repair

set -euo pipefail

echo ""
echo "=============================="
echo "  NOVA WSL NETWORK DIAG TOOL  "
echo "=============================="
echo ""

REPORT="/tmp/nova-net-report.txt"
echo "Nova Network Report - $(date)" > $REPORT
echo "---------------------------------------" >> $REPORT

#########################################################
# 1. Detect IPv6 instability
#########################################################

echo "[1] Checking IPv6 status..."
IPV6_STATUS=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)

if [[ "$IPV6_STATUS" == "1" ]]; then
    echo "  IPv6 is disabled (good for WSL)" | tee -a $REPORT
else
    echo "  IPv6 ENABLED — may cause WSL mirror instability." | tee -a $REPORT
    echo "  Auto-disabling IPv6 for stability..." | tee -a $REPORT
    
    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
    
    echo "net.ipv6.conf.all.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf >/dev/null
    echo "net.ipv6.conf.default.disable_ipv6=1" | sudo tee -a /etc/sysctl.conf >/dev/null
fi

#########################################################
# 2. DNS check
#########################################################

echo "\n[2] Checking DNS resolver..."
DNS=$(cat /etc/resolv.conf | grep nameserver | head -n1 | awk '{print $2}')

echo "  Current DNS: $DNS" | tee -a $REPORT

if [[ "$DNS" == "127.0.0.1" || "$DNS" == "172."* ]]; then
    echo "  WSL is using Windows DNS — inconsistent for mirrors." | tee -a $REPORT
    echo "  Switching to Cloudflare DNS (1.1.1.1)..." | tee -a $REPORT

    sudo rm /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf >/dev/null
else
    echo "  DNS looks stable." | tee -a $REPORT
fi

#########################################################
# 3. Modem firewall / packet-loss check
#########################################################

echo "\n[3] Testing packet loss to Cloudflare..."
LOSS=$(ping -c 4 1.1.1.1 | grep loss | awk '{print $6}')

echo "  Packet loss: $LOSS" | tee -a $REPORT

if [[ "$LOSS" != "0%" ]]; then
    echo "  WARNING: Your modem/firewall may be dropping packets." | tee -a $REPORT
    echo "  This impacts apt and mirror downloads." | tee -a $REPORT
else
    echo "  No packet loss detected." | tee -a $REPORT
fi

#########################################################
# 4. Test Kali mirrors for corruption / redirects
#########################################################

echo "\n[4] Testing Kali mirrors..."

MIRRORS=(
  "http://http.kali.org/kali"
  "http://kali.download/kali"
  "http://mirror.math.princeton.edu/pub/kali"
)

FASTEST=""
BEST_MS=999999

for URL in $MIRRORS; do
    printf "   > Testing %s ... " "$URL"

    RAW=$(curl -o /dev/null -s -w "%{time_connect}" "$URL" || echo "")
    if [[ -z "$RAW" ]]; then
        echo "FAIL"
        echo "  Mirror unreachable: $URL" >> $REPORT
        continue
    fi

    # Convert seconds to ms without bc
    MS=$(printf "%.0f" "$(echo "$RAW * 1000" | awk '{print $1}')")
    echo "${MS}ms"

    if (( MS < BEST_MS )); then
        BEST_MS=$MS
        FASTEST=$URL
    fi
done

echo "\n  Fastest mirror: $FASTEST" | tee -a $REPORT

#########################################################
# 5. Apply fastest mirror
#########################################################

echo "\n[5] Applying fastest mirror..."
sudo tee /etc/apt/sources.list >/dev/null << EOF
deb $FASTEST kali-rolling main non-free-firmware contrib non-free
EOF

#########################################################
# 6. Force apt corruption repair
#########################################################

echo "\n[6] Forcing package repair and cleanup..."
sudo rm -rf /var/lib/apt/lists/*
sudo apt clean

sudo apt update --fix-missing || true

sudo dpkg --configure -a || true
sudo apt --fix-broken install -y || true

sudo apt update

#########################################################
# Done
#########################################################

echo ""
echo "====================================="
echo "  NOVA NETWORK REPAIR COMPLETE"
echo "====================================="
echo ""
echo "Full report saved to:"
echo "  $REPORT"
echo ""
echo "If you want a version that logs everything or auto-tunes over time, I can build it."
