#!/bin/bash
set -e

echo "🔨 1. Compilando FocusPanic en modo Release para macOS (Apple Silicon & Intel)..."
swift build -c release

APP_NAME="FocusPanic"
BUILD_BINARY=".build/release/$APP_NAME"
TARGET_DIR="/Applications"
APP_BUNDLE="$TARGET_DIR/$APP_NAME.app"

# Si no tiene permisos en /Applications, usar ~/Applications
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
    APP_BUNDLE="$TARGET_DIR/$APP_NAME.app"
fi

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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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

# Registrar con LaunchServices para que el Dock y el Finder reconozcan el icono al instante
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE" 2>/dev/null || true
touch "$APP_BUNDLE"
killall Dock 2>/dev/null || true

echo "✨ 3. Aplicación instalada exitosamente con su icono en: $APP_BUNDLE"
echo "🚀 4. Puedes abrirla desde tu carpeta de Aplicaciones, Spotlight (Cmd + Espacio -> FocusPanic) o ejecutando:"
echo "   open '$APP_BUNDLE'"
