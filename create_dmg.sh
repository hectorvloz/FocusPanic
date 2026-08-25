#!/bin/bash
set -e

APP_NAME="FocusPanic"
VERSION="1.0"
VOL_NAME="FocusPanic"
DMG_FINAL="${APP_NAME}-Instalador.dmg"
DMG_TEMP="temp_rw.dmg"
STAGE_DIR="build_dmg_staging"

# 1. Generar fondo estilizado Retina multi-resolución
python3 create_dmg_background.py

# 2. Compilar
echo "🔨 1. Compilando $APP_NAME en modo Release..."
swift build -c release

# 3. Preparar staging
echo "📦 2. Preparando contenido del instalador..."
rm -rf "$STAGE_DIR" "$DMG_TEMP" "$DMG_FINAL" "FocusPanic.dmg"
mkdir -p "$STAGE_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$STAGE_DIR/$APP_NAME.app/Contents/Resources"
mkdir -p "$STAGE_DIR/.background"

# Copiar ejecutable
cp ".build/release/$APP_NAME" "$STAGE_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
chmod +x "$STAGE_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"

# Copiar iconos oficiales
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$STAGE_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"
fi
if [ -f "Resources/AppIcon.png" ]; then
    cp "Resources/AppIcon.png" "$STAGE_DIR/$APP_NAME.app/Contents/Resources/AppIcon.png"
fi

# Copiar imagen de fondo Retina TIFF y PNG
cp "Resources/dmg_background.tiff" "$STAGE_DIR/.background/dmg_background.tiff"
cp "Resources/dmg_background.png" "$STAGE_DIR/.background/dmg_background.png"

# PkgInfo
echo -n "APPL????" > "$STAGE_DIR/$APP_NAME.app/Contents/PkgInfo"

# Info.plist
cat <<EOF > "$STAGE_DIR/$APP_NAME.app/Contents/Info.plist"
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
    <string>$VERSION</string>
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

# Enlace simbólico a Aplicaciones
ln -s /Applications "$STAGE_DIR/Aplicaciones"

echo "💿 3. Creando imagen temporal de disco..."
hdiutil create -srcfolder "$STAGE_DIR" -volname "$VOL_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 80M "$DMG_TEMP"

echo "🎨 4. Configurando diseño visual de Finder en el instalador..."
# Desmontar volúmenes previos
hdiutil detach "/Volumes/$VOL_NAME" 2>/dev/null || true
hdiutil detach "/Volumes/FocusPanic Installer" 2>/dev/null || true

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')
sleep 2

# Script de Finder para posicionar con exactitud y aplicar el fondo TIFF Retina
osascript -e "
tell application \"Finder\"
    tell disk \"$VOL_NAME\"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {280, 140, 940, 560}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set text size of theViewOptions to 12
        set background picture of theViewOptions to file \".background:dmg_background.tiff\"
        set position of item \"$APP_NAME.app\" of container window to {170, 195}
        set position of item \"Aplicaciones\" of container window to {490, 195}
        update without registering applications
        delay 2
        close
    end tell
end tell
" || true

sync
sleep 2

echo "🔒 5. Desmontando y comprimiendo el instalador final..."
hdiutil detach "$DEVICE" || hdiutil detach "/Volumes/$VOL_NAME" -force

# Convertir a DMG final comprimido
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" -ov
rm -f "$DMG_TEMP"
rm -rf "$STAGE_DIR"

# Copia lista para compartir FocusPanic.dmg
cp "$DMG_FINAL" "FocusPanic.dmg"

echo "✨ =================================================== ✨"
echo "🎉 INSTALADOR PROFESIONAL CREADO CON ÉXITO:"
echo "📂 Archivo: $(pwd)/FocusPanic.dmg"
echo "✨ =================================================== ✨"
