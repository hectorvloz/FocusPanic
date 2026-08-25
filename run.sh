#!/bin/bash
set -e

echo "🚀 Iniciando FocusPanic para macOS..."
swift build -c release
echo "✨ Compilación completada con éxito."

# Ejecutar binario
.build/release/FocusPanic
