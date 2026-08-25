#!/bin/bash
# FocusPanic Helper - Ejecuta operaciones privilegiadas de bloqueo
# Se instala en /usr/local/bin/focuspanic-helper con permisos de sudoers NOPASSWD

ACTION="$1"
HOSTS_FILE="/etc/hosts"

case "$ACTION" in
    apply)
        # Argumento 2: ruta al archivo temporal con el nuevo contenido de hosts
        TEMP_FILE="$2"
        if [ -f "$TEMP_FILE" ]; then
            cp -f "$TEMP_FILE" "$HOSTS_FILE"
            chmod 644 "$HOSTS_FILE"
            killall -HUP mDNSResponder 2>/dev/null || true
            dscacheutil -flushcache 2>/dev/null || true
            rm -f "$TEMP_FILE"
            echo "OK"
        else
            echo "ERROR: Archivo temporal no encontrado: $TEMP_FILE"
            exit 1
        fi
        ;;
    remove)
        # Quitar el bloque FocusPanic del archivo hosts
        if grep -q "BEGIN FOCUSPANIC BLOCK" "$HOSTS_FILE"; then
            sed -i '' '/# >>> BEGIN FOCUSPANIC BLOCK/,/# <<< END FOCUSPANIC BLOCK/d' "$HOSTS_FILE"
            chmod 644 "$HOSTS_FILE"
            killall -HUP mDNSResponder 2>/dev/null || true
            dscacheutil -flushcache 2>/dev/null || true
            echo "OK"
        else
            echo "OK_NOOP"
        fi
        ;;
    flush)
        killall -HUP mDNSResponder 2>/dev/null || true
        dscacheutil -flushcache 2>/dev/null || true
        echo "OK"
        ;;
    pfon)
        # Activar redirección de puerto 80 → 8484
        TEMP_PF="$2"
        if [ -f "$TEMP_PF" ]; then
            pfctl -ef "$TEMP_PF" 2>/dev/null
            rm -f "$TEMP_PF"
            echo "OK"
        fi
        ;;
    pfoff)
        pfctl -d 2>/dev/null || true
        echo "OK"
        ;;
    *)
        echo "Uso: focuspanic-helper {apply|remove|flush|pfon|pfoff} [archivo]"
        exit 1
        ;;
esac
