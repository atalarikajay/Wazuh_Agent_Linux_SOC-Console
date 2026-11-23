#!/bin/bash
# Karantina, hapus, atau pulihkan berkas. data.path, data.mode = quarantine | delete | restore.
. "$(dirname "$0")/soc-common.sh"

QDIR="/var/lib/soc/quarantine"
P="$(soc_data path)"
MODE="$(soc_data mode)"; MODE="${MODE:-quarantine}"

[ -n "$P" ] || { soc_log "path kosong"; exit 0; }
case "$P" in
    /*) ;;
    *) soc_log "path '$P' harus absolut"; exit 0 ;;
esac

# Folder sistem dan folder agen keamanan tidak boleh disentuh.
FORBIDDEN_RE='^/(bin|sbin|lib|lib32|lib64|libx32|usr|etc|boot|proc|sys|dev|run|var/ossec|var/lib/soc|opt/WatchGuard|opt/panda|snap)(/|$)'
if [[ "$P" =~ $FORBIDDEN_RE ]] || [ "$P" = "/" ]; then
    soc_log "path $P berada di folder terlindung, ditolak"; exit 0
fi

mkdir -p "$QDIR" && chmod 700 "$QDIR"

if [ "$MODE" = "restore" ]; then
    # Cari catatan meta yang asalnya sama, pulihkan yang terbaru.
    meta="$(grep -ls "\"original\": \"$P\"" "$QDIR"/*.meta.json 2>/dev/null | sort | tail -1)"
    [ -n "$meta" ] || { soc_log "tidak ada karantina untuk $P"; exit 0; }
    qfile="${meta%.meta.json}"
    [ -f "$qfile" ] || { soc_log "berkas karantina $qfile tidak ada"; exit 0; }
    mkdir -p "$(dirname "$P")"
    if mv -f "$qfile" "$P"; then
        chmod 644 "$P"; rm -f "$meta"
        soc_log "dipulihkan $P dari $qfile"
    else
        soc_log "gagal memulihkan $P"
    fi
    exit 0
fi

[ -f "$P" ] || { soc_log "berkas $P tidak ada"; exit 0; }
sha="$(sha256sum "$P" 2>/dev/null | cut -d' ' -f1)"

if [ "$MODE" = "delete" ]; then
    if rm -f "$P"; then soc_log "dihapus $P sha256=$sha"; else soc_log "gagal menghapus $P"; fi
    exit 0
fi

stamp="$(date +%Y%m%d-%H%M%S)"
qname="${stamp}_$(basename "$P").quarantined"
qpath="$QDIR/$qname"
if mv -f "$P" "$qpath"; then
    chmod 000 "$qpath"
    printf '{"original": "%s", "quarantined": "%s", "sha256": "%s", "time": "%s", "host": "%s"}\n' \
        "$P" "$qpath" "$sha" "$(date -Iseconds)" "$(hostname)" > "$qpath.meta.json"
    soc_log "dikarantina $P -> $qpath sha256=$sha"
else
    soc_log "gagal mengkarantina $P"
fi
exit 0
