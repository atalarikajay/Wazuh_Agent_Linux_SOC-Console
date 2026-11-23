#!/bin/bash
# Pasang script Active Response SOC ke agen Wazuh Linux yang sudah terpasang. Jalankan sebagai root.
# Online, satu baris:
#   curl -fsSL https://raw.githubusercontent.com/atalarikajay/Wazuh_Agent_Linux_SOC-Console/main/active-response/install_soc_ar.sh | bash
# Dari folder lokal atau share:
#   SOC_AR_SOURCE=/mnt/share/active-response bash install_soc_ar.sh
set -u
BASE="${SOC_AR_SOURCE:-https://raw.githubusercontent.com/atalarikajay/Wazuh_Agent_Linux_SOC-Console/main/active-response}"
BASE="${BASE%/}"
BIN="/var/ossec/active-response/bin"
FILES="soc-common.sh soc-kill-process.sh soc-quarantine-file.sh soc-block-ip.sh"

[ "$(id -u)" -eq 0 ] || { echo "[FAIL] Harus root"; exit 1; }
[ -d "$BIN" ] || { echo "[FAIL] $BIN tidak ada. Agen Wazuh belum terpasang."; exit 1; }
command -v python3 >/dev/null || { echo "[FAIL] python3 tidak ada, script AR membutuhkannya untuk membaca JSON"; exit 1; }

ok=0; total=0
for f in $FILES; do
    total=$((total + 1))
    dest="$BIN/$f"
    if [[ "$BASE" =~ ^https?:// ]]; then
        curl -fsSL --max-time 60 -o "$dest" "$BASE/$f" || { echo "[GAGAL] $f tidak bisa diunduh"; continue; }
    else
        cp -f "$BASE/$f" "$dest" 2>/dev/null || { echo "[GAGAL] $f tidak ada di $BASE"; continue; }
    fi
    size=$(stat -c %s "$dest" 2>/dev/null || echo 0)
    [ "$size" -ge 50 ] || { echo "[GAGAL] $f cuma $size byte, kemungkinan halaman error"; continue; }
    chown root:wazuh "$dest"; chmod 750 "$dest"
    echo "[ OK ] $f ($size byte)"
    ok=$((ok + 1))
done
if [ "$ok" -eq "$total" ]; then
    echo "Semua $ok script Active Response SOC terpasang di $BIN. Agen tidak perlu direstart."
    exit 0
fi
echo "Hanya $ok dari $total berkas terpasang."
exit 1
