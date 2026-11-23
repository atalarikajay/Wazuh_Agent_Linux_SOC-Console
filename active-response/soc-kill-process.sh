#!/bin/bash
# Matikan proses berdasarkan data.pid atau data.name. Proses sistem dan agen keamanan dilindungi.
. "$(dirname "$0")/soc-common.sh"

PID="$(soc_data pid)"
NAME="$(soc_data name)"

PROTECTED_RE='^(systemd|init|wazuh-.*|ossec-.*|auditd|sshd|dbus-daemon|rsyslogd|journald|systemd-.*|cron|crond|NetworkManager|containerd|dockerd|kubelet|WatchGuardAgent|PSANHost|AgentSvc|psufrcli|soc-.*)$'

kill_one() {
    local pid="$1" comm
    [[ "$pid" =~ ^[0-9]+$ ]] || { soc_log "pid '$pid' tidak sah"; return; }
    [ "$pid" -gt 1 ] || { soc_log "pid $pid tidak boleh dimatikan"; return; }
    [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] || { soc_log "pid $pid adalah script ini sendiri"; return; }
    comm="$(ps -o comm= -p "$pid" 2>/dev/null | tr -d ' ')"
    [ -n "$comm" ] || { soc_log "pid $pid tidak ada"; return; }
    if [[ "$comm" =~ $PROTECTED_RE ]]; then
        soc_log "pid $pid ($comm) dilindungi, tidak dimatikan"; return
    fi
    if kill -TERM "$pid" 2>/dev/null; then
        sleep 2
        kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
        soc_log "pid $pid ($comm) dimatikan"
    else
        soc_log "pid $pid ($comm) gagal dimatikan"
    fi
}

if [ -n "$PID" ]; then
    kill_one "$PID"
elif [ -n "$NAME" ]; then
    NAME="${NAME##*/}"
    if [[ "$NAME" =~ $PROTECTED_RE ]]; then
        soc_log "nama $NAME dilindungi, tidak dimatikan"; exit 0
    fi
    found=0
    for p in $(pgrep -x "$NAME" 2>/dev/null); do found=1; kill_one "$p"; done
    [ "$found" -eq 1 ] || soc_log "tidak ada proses bernama $NAME"
else
    soc_log "pid dan name kosong"
fi
exit 0
