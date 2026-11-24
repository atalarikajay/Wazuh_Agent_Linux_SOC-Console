#!/bin/bash
# Bagian bersama script active response SOC untuk agen Wazuh Linux.
# Di-source oleh tiap script. Membaca JSON active response dari stdin,
# bentuknya {"command":"add","parameters":{"alert":{"data":{...}}}}.
# Butuh python3 untuk membaca JSON, sama seperti installer agen.

SOC_AR_LOG="/var/ossec/logs/active-responses.log"
[ -d /var/ossec/logs ] || SOC_AR_LOG="/var/log/soc-active-responses.log"

soc_log() {
    local line
    line="$(date '+%Y/%m/%d %H:%M:%S') soc-ar: $*"
    { echo "$line" >> "$SOC_AR_LOG"; } 2>/dev/null || true
    echo "$line"
}

# Baca SATU baris stdin, simpan di SOC_AR_INPUT. Agen mengirim JSON satu baris lalu menunggu
# jawaban tanpa menutup stdin, jadi `cat` akan menggantung selamanya.
IFS= read -r SOC_AR_INPUT 2>/dev/null || true

# soc_data KEY  -> nilai parameters.alert.data.KEY, kosong bila tidak ada
soc_data() {
    [ -n "$SOC_AR_INPUT" ] || { echo ""; return; }
    printf '%s' "$SOC_AR_INPUT" | python3 -c '
import json, sys
key = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    print(""); sys.exit(0)
data = (((d.get("parameters") or {}).get("alert") or {}).get("data") or {})
v = data.get(key, "")
print("" if v is None else str(v))
' "$1" 2>/dev/null
}

soc_command() {
    [ -n "$SOC_AR_INPUT" ] || { echo "add"; return; }
    printf '%s' "$SOC_AR_INPUT" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("command", "add"))
except Exception:
    print("add")
' 2>/dev/null
}
