#!/bin/bash
set -e

APP_NAME="FocusPanic"
REPO="hectorvloz/FocusPanic"
TARGET_DIR="/Applications"
APP_BUNDLE="$TARGET_DIR/$APP_NAME.app"

# Si no tiene permisos de escritura en /Applications, usar ~/Applications
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
    APP_BUNDLE="$TARGET_DIR/$APP_NAME.app"
fi

# ==============================================================================
# MODO 1: INSTALACIÓN RÁPIDA POR TERMINAL (curl ... | bash) O SIN CÓDIGO FUENTE
# ==============================================================================
if [ ! -f "Package.swift" ]; then
    echo "🧠⚡ ============================================================"
    echo "   Instalando FocusPanic para macOS..."
    echo "============================================================"
    
    TMP_DMG="/tmp/FocusPanic.dmg"
    DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/FocusPanic.dmg"
    
    echo "📥 Descargando última versión de FocusPanic..."
    curl -fsSL -L "$DOWNLOAD_URL" -o "$TMP_DMG"
    
    echo "💿 Montando imagen de disco..."
    MOUNT_DIR=$(mktemp -d /tmp/focuspanic-mount.XXXXXX)
    hdiutil attach -nobrowse -quiet -mountpoint "$MOUNT_DIR" "$TMP_DMG"
    
    echo "📦 Copiando $APP_NAME a $TARGET_DIR..."
    rm -rf "$APP_BUNDLE"
    cp -R "$MOUNT_DIR/$APP_NAME.app" "$TARGET_DIR/"
    
    echo "🔒 Desmontando y limpiando..."
    hdiutil detach "$MOUNT_DIR" -quiet || true
    rm -rf "$MOUNT_DIR" "$TMP_DMG"
    
    # Quitar bandera de cuarentena de macOS Gatekeeper
    xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true
    
    # Actualizar cache de iconos
    killall usernoted 2>/dev/null || true
    killall NotificationCenter 2>/dev/null || true
    
    echo ""
    echo "✨ ============================================================"
    echo "🎉 ¡FocusPanic instalado con éxito en $APP_BUNDLE!"
    echo "🚀 Puedes iniciarlo desde Spotlight (Cmd + Espacio -> FocusPanic)"
    echo "   o ejecutando en terminal: open '$APP_BUNDLE'"
    echo "============================================================"
    exit 0
fi

# ==============================================================================
# MODO 2: COMPILACIÓN DESDE CÓDIGO FUENTE (Repositorio Local)
# ==============================================================================
echo "🔨 1. Compilando FocusPanic en modo Release para macOS..."
swift build -c release

BUILD_BINARY=".build/release/$APP_NAME"

echo "📦 2. Creando el Bundle de la aplicación macOS en: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copiar ejecutable
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copiar iconos oficiales de la app sin bordes
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "Resources/AppIcon.png" ]; then
    cp "Resources/AppIcon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
fi

# Crear PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Crear Info.plist con icono oficial y permisos
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.focuspanic.mac</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>FocusPanic necesita controlar Safari para cerrar pestañas bloqueadas durante el Modo Enfoque.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>FocusPanic requiere configurar el motor de bloqueo de red de macOS.</string>
</dict>
</plist>
EOF

# Firmar la app con firma ad-hoc e identificador estable
codesign --force --deep --sign - --identifier "com.focuspanic.mac" --requirements '=designated => identifier "com.focuspanic.mac"' "$APP_BUNDLE" 2>/dev/null || true

# Quitar bandera de cuarentena si aplica
xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

# Actualizar focuspanic-helper con Cloudflare Families DNS (1.1.1.3) si ya existe
if [ -f "/usr/local/bin/focuspanic-helper" ]; then
    cat << 'EOF_HELPER' > /tmp/focuspanic-helper
#!/bin/bash
ACTION="$1"
HOSTS="/etc/hosts"
case "$ACTION" in
    apply)
        if [ -f "$2" ]; then
            cp -f "$2" "$HOSTS"
            chmod 644 "$HOSTS"
            networksetup -listallnetworkservices 2>/dev/null | grep -v '^\*' | grep -v 'An asterisk' | while IFS= read -r iface; do
                [ -n "$iface" ] && networksetup -setdnsservers "$iface" 1.1.1.3 1.0.0.3 2606:4700:4700::1113 2606:4700:4700::1003 2>/dev/null || true
            done
            killall -HUP mDNSResponder 2>/dev/null || true
            dscacheutil -flushcache 2>/dev/null || true
            rm -f "$2"
            echo "OK"
        else
            echo "ERROR" && exit 1
        fi
        ;;
    remove)
        if grep -q "BEGIN FOCUSPANIC" "$HOSTS"; then
            sed -i '' '/# >>> BEGIN FOCUSPANIC BLOCK/,/# <<< END FOCUSPANIC BLOCK/d' "$HOSTS"
            chmod 644 "$HOSTS"
        fi
        networksetup -listallnetworkservices 2>/dev/null | grep -v '^\*' | grep -v 'An asterisk' | while IFS= read -r iface; do
            [ -n "$iface" ] && networksetup -setdnsservers "$iface" "Empty" 2>/dev/null || true
        done
        killall -HUP mDNSResponder 2>/dev/null || true
        dscacheutil -flushcache 2>/dev/null || true
        echo "OK"
        ;;
    apply-family-dns)
        networksetup -listallnetworkservices 2>/dev/null | grep -v '^\*' | grep -v 'An asterisk' | while IFS= read -r iface; do
            [ -n "$iface" ] && networksetup -setdnsservers "$iface" 1.1.1.3 1.0.0.3 2606:4700:4700::1113 2606:4700:4700::1003 2>/dev/null || true
        done
        killall -HUP mDNSResponder 2>/dev/null || true
        dscacheutil -flushcache 2>/dev/null || true
        echo "OK"
        ;;
    flush)
        killall -HUP mDNSResponder 2>/dev/null || true
        dscacheutil -flushcache 2>/dev/null || true
        echo "OK"
        ;;
    *)
        echo "Usage: focuspanic-helper {apply|remove|flush|apply-family-dns} [file]"; exit 1;;
esac
EOF_HELPER
    cp -f /tmp/focuspanic-helper /usr/local/bin/focuspanic-helper 2>/dev/null || true
    chmod 755 /usr/local/bin/focuspanic-helper 2>/dev/null || true
    rm -f /tmp/focuspanic-helper
fi

# Actualizar el cache de iconos y notificaciones de macOS
killall usernoted 2>/dev/null || true
killall NotificationCenter 2>/dev/null || true

echo "✨ 3. Aplicación instalada exitosamente con su icono en: $APP_BUNDLE"
echo "🚀 4. Puedes abrirla desde tu carpeta de Aplicaciones, Spotlight (Cmd + Espacio -> FocusPanic) o ejecutando:"
echo "   open '$APP_BUNDLE'"
