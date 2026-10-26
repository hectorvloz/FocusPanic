import Foundation

/// Contenido de `/usr/local/bin/focuspanic-helper` (v2). Se instala como root con una regla de
/// sudoers NOPASSWD, así que cualquier proceso del usuario (incluido un agente de IA) puede
/// ejecutarlo: todo lo que debilita la protección exige el PIN del compañero, que viaja por stdin
/// para que no aparezca en `ps`, y el PIN solo existe como hash en un directorio de root.
enum GuardHelperScript {
    static let version = 2

    static let content = #"""
#!/bin/bash
# FocusPanic Helper v2 — operaciones privilegiadas de bloqueo y guardián que mantiene viva la app.
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
umask 022

HELPER_VERSION=2
HOSTS=/etc/hosts
GUARD_DIR="/Library/Application Support/FocusPanic/guard"
PIN_FILE="$GUARD_DIR/pin.hash"
ANSWER_FILE="$GUARD_DIR/answer.hash"
FAIL_FILE="$GUARD_DIR/failures"
PAUSE_FILE="$GUARD_DIR/pause-until"
EVENT_FILE="$GUARD_DIR/last-event"
APP_PATH=/Applications/FocusPanic.app
APP_BACKUP="$GUARD_DIR/FocusPanic.app"
DAEMON_LABEL=com.focuspanic.guardian
DAEMON_PLIST="/Library/LaunchDaemons/$DAEMON_LABEL.plist"
HELPER_PATH=/usr/local/bin/focuspanic-helper
SUDOERS_FILE=/etc/sudoers.d/focuspanic
GUARDIAN_LOG=/Library/Logs/FocusPanic-guardian.log

now() { date +%s; }

ensure_guard_dir() {
    mkdir -p "$GUARD_DIR"
    chown root:wheel "$GUARD_DIR"
    chmod 700 "$GUARD_DIR"
}

log_event() {
    ensure_guard_dir
    printf '%s %s\n' "$(now)" "$1" > "$EVENT_FILE"
    chmod 600 "$EVENT_FILE"
}

flush_dns() {
    killall -HUP mDNSResponder 2>/dev/null || true
    dscacheutil -flushcache 2>/dev/null || true
}

set_dns_servers() {
    networksetup -listallnetworkservices 2>/dev/null | grep -v '^\*' | grep -v 'An asterisk' | while IFS= read -r iface; do
        [ -n "$iface" ] && networksetup -setdnsservers "$iface" "$@" 2>/dev/null || true
    done
}

set_family_dns() { set_dns_servers 1.1.1.3 1.0.0.3 2606:4700:4700::1113 2606:4700:4700::1003; }

remove_hosts_block() {
    if grep -q "BEGIN FOCUSPANIC" "$HOSTS"; then
        sed -i '' '/# >>> BEGIN FOCUSPANIC BLOCK/,/# <<< END FOCUSPANIC BLOCK/d' "$HOSTS"
        chmod 644 "$HOSTS"
    fi
}

# --- Secretos del compañero (PIN y respuesta de seguridad), guardados como hash con sal ---

hash_secret() { printf '%s:%s' "$1" "$2" | shasum -a 256 | cut -c1-64; }

store_secret() {
    local salt
    salt=$(openssl rand -hex 16) || return 1
    printf '%s %s\n' "$salt" "$(hash_secret "$salt" "$2")" > "$1.tmp" || return 1
    chmod 600 "$1.tmp"
    mv -f "$1.tmp" "$1"
}

matches_secret() {
    local salt stored
    [ -f "$1" ] || return 1
    read -r salt stored < "$1" || return 1
    [ -n "$salt" ] && [ "$(hash_secret "$salt" "$2")" = "$stored" ]
}

has_secrets() { [ -f "$PIN_FILE" ] || [ -f "$ANSWER_FILE" ]; }

# Tras 5 fallos seguidos hay que esperar 1 min, y la espera se duplica con cada fallo extra
# (tope 24 h): probar los 10 000 PIN de 4 dígitos deja de ser viable.
lockout_remaining() {
    local count=0 last=0 exp wait rem
    [ -f "$FAIL_FILE" ] && read -r count last < "$FAIL_FILE"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    if [ "$count" -lt 5 ]; then echo 0; return; fi
    exp=$((count - 5)); [ "$exp" -gt 11 ] && exp=11
    wait=$((60 << exp)); [ "$wait" -gt 86400 ] && wait=86400
    rem=$((last + wait - $(now)))
    if [ "$rem" -gt 0 ]; then echo "$rem"; else echo 0; fi
}

record_failure() {
    local count=0 last=0
    [ -f "$FAIL_FILE" ] && read -r count last < "$FAIL_FILE"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    printf '%s %s\n' "$((count + 1))" "$(now)" > "$FAIL_FILE"
    chmod 600 "$FAIL_FILE"
    log_event "pin-failure"
}

read_line() { local line=""; IFS= read -r line || true; printf '%s' "${line%$'\r'}"; }

# Comprueba $SECRET. Con "pin" solo vale el PIN; con "any" también la respuesta de seguridad.
# Si todavía no hay secretos configurados no hay nada que proteger y se permite.
check_secret() {
    local rem
    has_secrets || return 0
    rem=$(lockout_remaining)
    if [ "$rem" -gt 0 ]; then echo "LOCKED $rem"; return 1; fi
    if [ -n "$SECRET" ]; then
        if matches_secret "$PIN_FILE" "$SECRET" || { [ "$1" = any ] && matches_secret "$ANSWER_FILE" "$SECRET"; }; then
            rm -f "$FAIL_FILE"
            return 0
        fi
    fi
    record_failure
    echo "DENIED"
    return 1
}

# --- Guardián: relanza FocusPanic si alguien lo cierra o lo mata sin el PIN ---

console_uid() { stat -f %u /dev/console 2>/dev/null || echo 0; }

is_paused() {
    local until=0
    [ -f "$PAUSE_FILE" ] && read -r until < "$PAUSE_FILE"
    [[ "$until" =~ ^[0-9]+$ ]] || until=0
    [ "$until" -gt "$(now)" ] && return 0
    rm -f "$PAUSE_FILE"
    return 1
}

cmd_guardian() {
    local missing_since=0 uid user
    ensure_guard_dir
    while true; do
        sleep 3
        uid=$(console_uid)
        # Nadie con sesión, sesión cerrándose (sin Dock), pausa autorizada con PIN o la app ya corre
        if [ "$uid" -eq 0 ] || ! pgrep -u "$uid" -x Dock >/dev/null || is_paused || pgrep -u "$uid" -x FocusPanic >/dev/null; then
            missing_since=0
            continue
        fi
        # Margen para que un reinicio de la propia app o una actualización terminen solos
        if [ "$missing_since" -eq 0 ]; then missing_since=$(now); continue; fi
        [ $(( $(now) - missing_since )) -ge 8 ] || continue
        missing_since=0
        user=$(id -un "$uid" 2>/dev/null) || continue
        if [ ! -x "$APP_PATH/Contents/MacOS/FocusPanic" ] && [ -d "$APP_BACKUP" ]; then
            rm -rf "$APP_PATH"
            ditto "$APP_BACKUP" "$APP_PATH" && chown -R "$uid:admin" "$APP_PATH"
            log_event "app-restored"
        else
            log_event "app-relaunched"
        fi
        echo "$(date '+%F %T') FocusPanic relanzado para $user"
        launchctl asuser "$uid" sudo -u "$user" /usr/bin/open -g "$APP_PATH" >/dev/null 2>&1
    done
}

cmd_sync_app() {
    [ -x "$APP_PATH/Contents/MacOS/FocusPanic" ] || { echo "ERROR: no existe $APP_PATH"; return 1; }
    ensure_guard_dir
    rm -rf "$APP_BACKUP.tmp"
    ditto "$APP_PATH" "$APP_BACKUP.tmp" || return 1
    chown -R root:wheel "$APP_BACKUP.tmp"
    rm -rf "$APP_BACKUP"
    mv "$APP_BACKUP.tmp" "$APP_BACKUP"
    echo "OK"
}

cmd_install_daemon() {
    ensure_guard_dir
    cat > "$DAEMON_PLIST.tmp" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$DAEMON_LABEL</string>
    <key>ProgramArguments</key>
    <array><string>$HELPER_PATH</string><string>guardian</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$GUARDIAN_LOG</string>
    <key>StandardErrorPath</key><string>$GUARDIAN_LOG</string>
</dict>
</plist>
EOF
    chown root:wheel "$DAEMON_PLIST.tmp"
    chmod 644 "$DAEMON_PLIST.tmp"
    mv -f "$DAEMON_PLIST.tmp" "$DAEMON_PLIST"
    [ -d "$APP_BACKUP" ] || cmd_sync_app >/dev/null
    if launchctl print "system/$DAEMON_LABEL" >/dev/null 2>&1; then
        launchctl kickstart -k "system/$DAEMON_LABEL" || { echo "ERROR: no se pudo reiniciar el guardián"; exit 1; }
    else
        launchctl bootstrap system "$DAEMON_PLIST" || { echo "ERROR: no se pudo cargar el guardián"; exit 1; }
    fi
    echo "OK"
}

cmd_status() {
    local until=0 event=""
    [ -f "$PAUSE_FILE" ] && read -r until < "$PAUSE_FILE"
    [ -f "$EVENT_FILE" ] && event=$(head -1 "$EVENT_FILE")
    echo "version=$HELPER_VERSION"
    echo "pin=$([ -f "$PIN_FILE" ] && echo 1 || echo 0)"
    echo "answer=$([ -f "$ANSWER_FILE" ] && echo 1 || echo 0)"
    echo "guardian=$(launchctl print "system/$DAEMON_LABEL" >/dev/null 2>&1 && echo 1 || echo 0)"
    echo "paused_until=$until"
    echo "lockout=$(lockout_remaining)"
    echo "last_event=$event"
}

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: ejecútalo con sudo"
    exit 1
fi

ACTION="${1:-}"
case "$ACTION" in
    version)
        echo "$HELPER_VERSION"
        ;;
    status)
        cmd_status
        ;;
    apply)
        # El nuevo /etc/hosts llega por stdin (nunca una ruta: root no debe leer archivos arbitrarios)
        ensure_guard_dir
        TMP="$GUARD_DIR/hosts.new"
        head -c 8388608 > "$TMP"
        if ! grep -qF "# >>> BEGIN FOCUSPANIC BLOCK" "$TMP" || ! grep -qF "# <<< END FOCUSPANIC BLOCK" "$TMP"; then
            rm -f "$TMP"
            echo "ERROR: falta el bloque de FocusPanic"
            exit 1
        fi
        cp -f "$TMP" "$HOSTS"
        rm -f "$TMP"
        chown root:wheel "$HOSTS"
        chmod 644 "$HOSTS"
        set_family_dns
        flush_dns
        echo "OK"
        ;;
    apply-family-dns)
        set_family_dns
        flush_dns
        echo "OK"
        ;;
    remove)
        remove_hosts_block
        set_dns_servers Empty
        flush_dns
        echo "OK"
        ;;
    flush)
        flush_dns
        echo "OK"
        ;;
    verify)
        # stdin: secreto. $2: "pin" o "any"
        SECRET=$(read_line)
        check_secret "${2:-pin}" || exit 1
        echo "OK"
        ;;
    set-secrets)
        # stdin: secreto actual, nuevo PIN (vacío = no cambiar), nueva respuesta (vacía = no cambiar)
        SECRET=$(read_line)
        NEW_PIN=$(read_line)
        NEW_ANSWER=$(read_line)
        ensure_guard_dir
        check_secret any || exit 1
        if [ -n "$NEW_PIN" ]; then
            [[ "$NEW_PIN" =~ ^[[:print:]]{4,32}$ ]] || { echo "ERROR: el PIN debe tener de 4 a 32 caracteres"; exit 1; }
            store_secret "$PIN_FILE" "$NEW_PIN" || exit 1
        fi
        if [ -n "$NEW_ANSWER" ]; then
            store_secret "$ANSWER_FILE" "$NEW_ANSWER" || exit 1
        fi
        log_event "secrets-changed"
        echo "OK"
        ;;
    pause)
        # stdin: PIN. $2: minutos (1-1440) durante los que el guardián no relanza la app
        MINUTES="${2:-}"
        if ! [[ "$MINUTES" =~ ^[0-9]+$ ]] || [ "$MINUTES" -lt 1 ] || [ "$MINUTES" -gt 1440 ]; then
            echo "ERROR: los minutos deben estar entre 1 y 1440"
            exit 1
        fi
        SECRET=$(read_line)
        check_secret pin || exit 1
        ensure_guard_dir
        printf '%s\n' "$(( $(now) + MINUTES * 60 ))" > "$PAUSE_FILE"
        chmod 600 "$PAUSE_FILE"
        log_event "paused $MINUTES"
        echo "OK"
        ;;
    resume)
        rm -f "$PAUSE_FILE"
        echo "OK"
        ;;
    sync-app)
        cmd_sync_app || exit 1
        ;;
    install-daemon)
        cmd_install_daemon
        ;;
    guardian)
        cmd_guardian
        ;;
    uninstall)
        SECRET=$(read_line)
        check_secret pin || exit 1
        launchctl bootout "system/$DAEMON_LABEL" 2>/dev/null || true
        rm -f "$DAEMON_PLIST"
        remove_hosts_block
        set_dns_servers Empty
        flush_dns
        rm -rf "$GUARD_DIR"
        rm -f "$SUDOERS_FILE" "$HELPER_PATH"
        echo "OK"
        ;;
    *)
        echo "Uso: focuspanic-helper {version|status|apply|apply-family-dns|remove|flush|verify|set-secrets|pause|resume|sync-app|install-daemon|uninstall}"
        exit 1
        ;;
esac
"""#
}
