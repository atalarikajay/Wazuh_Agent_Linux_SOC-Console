#!/bin/bash
# Blok atau buka blokir IP di firewall host. data.ip, data.mode = block | unblock.
# Memakai iptables bila ada, kalau tidak nft. Rantai sendiri bernama SOC-BLOCK.
. "$(dirname "$0")/soc-common.sh"

IP="$(soc_data ip)"
MODE="$(soc_data mode)"; MODE="${MODE:-block}"

[ -n "$IP" ] || { soc_log "ip kosong"; exit 0; }
if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]] && ! [[ "$IP" =~ ^[0-9a-fA-F:]+(/[0-9]{1,3})?$ ]]; then
    soc_log "ip $IP tidak sah"; exit 0
fi
case "$IP" in
    127.*|0.0.0.0*|::1*) soc_log "ip $IP tidak boleh diblok"; exit 0 ;;
esac

if [[ "$IP" == *:* ]]; then IPT="ip6tables"; NFAM="ip6"; else IPT="iptables"; NFAM="ip"; fi

if command -v "$IPT" >/dev/null 2>&1; then
    "$IPT" -N SOC-BLOCK 2>/dev/null || true
    "$IPT" -C INPUT  -j SOC-BLOCK 2>/dev/null || "$IPT" -I INPUT  1 -j SOC-BLOCK
    "$IPT" -C OUTPUT -j SOC-BLOCK 2>/dev/null || "$IPT" -I OUTPUT 1 -j SOC-BLOCK
    if [ "$MODE" = "unblock" ]; then
        while "$IPT" -D SOC-BLOCK -s "$IP" -j DROP 2>/dev/null; do :; done
        while "$IPT" -D SOC-BLOCK -d "$IP" -j DROP 2>/dev/null; do :; done
        soc_log "buka blokir $IP ($IPT)"
    else
        "$IPT" -C SOC-BLOCK -s "$IP" -j DROP 2>/dev/null || "$IPT" -A SOC-BLOCK -s "$IP" -j DROP
        "$IPT" -C SOC-BLOCK -d "$IP" -j DROP 2>/dev/null || "$IPT" -A SOC-BLOCK -d "$IP" -j DROP
        soc_log "blok $IP masuk dan keluar ($IPT)"
    fi
elif command -v nft >/dev/null 2>&1; then
    nft list table "$NFAM" soc >/dev/null 2>&1 || nft add table "$NFAM" soc
    nft list chain "$NFAM" soc in  >/dev/null 2>&1 || nft add chain "$NFAM" soc in  '{ type filter hook input priority -10; }'
    nft list chain "$NFAM" soc out >/dev/null 2>&1 || nft add chain "$NFAM" soc out '{ type filter hook output priority -10; }'
    ADDR_KW="ip"; [ "$NFAM" = "ip6" ] && ADDR_KW="ip6"
    if [ "$MODE" = "unblock" ]; then
        for ch in in out; do
            dir="saddr"; [ "$ch" = "out" ] && dir="daddr"
            nft -a list chain "$NFAM" soc "$ch" 2>/dev/null | grep -F "$ADDR_KW $dir $IP " | grep -o 'handle [0-9]*' | awk '{print $2}' | \
                while read -r h; do nft delete rule "$NFAM" soc "$ch" handle "$h"; done
        done
        soc_log "buka blokir $IP (nft)"
    else
        nft add rule "$NFAM" soc in  "$ADDR_KW" saddr "$IP" drop
        nft add rule "$NFAM" soc out "$ADDR_KW" daddr "$IP" drop
        soc_log "blok $IP masuk dan keluar (nft)"
    fi
else
    soc_log "iptables dan nft tidak ada, $IP tidak bisa diblok"
fi
exit 0
