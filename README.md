# FocusPanic 🧠⚡
### Aplicación Nativa para macOS diseñada para TDAH / ADHD

**FocusPanic** es un sistema de bloqueo radical y enfoque consciente diseñado para neutralizar la impulsividad digital en personas con TDAH.

---

## ✨ Características Principales

1. **Botón de Pánico Instantáneo**:
   * Activa el modo de concentración con un solo clic o atajo.
   * Presets adaptados a TDAH: *Micro-Sprint (15 min)*, *Pomodoro TDAH (25 min)*, *Enfoque Profundo (45 min)*, *Hiperfoco (90 min)* y *Pánico/Entrega Ya (120 min)*.

2. **Bloqueo Universal en Todos los Navegadores**:
   * Funciona en **Safari, Chrome, Brave, Arc, Firefox, Edge**, etc., a través de `/etc/hosts` con vaciado atómico de caché DNS (`dscacheutil`, `mDNSResponder`).
   * Incluye catálogo de más de 20 sitios distractores predefinidos (Twitter/X, Instagram, YouTube, TikTok, Netflix, Reddit, Amazon, etc.) y permite añadir cualquier dominio personalizado.

3. **Bloqueo e Intercepción de Apps de Escritorio**:
   * Cierra automáticamente o previene la apertura de aplicaciones como Discord, Telegram, Steam, Slack, Mail, etc., durante el tiempo de concentración.

4. **Fricción Deliberada y Desbloqueo por Correo (Anti-Impulso TDAH)**:
   * **Paso 1 (Pausa Consciente)**: Exige transcribir una frase de reflexión para romper el bucle dopaminérgico automático.
   * **Paso 2 (Tiempo de Enfriamiento)**: Temporizador de retardo (delay de 3 a 10 min) antes de que el código sea accesible.
   * **Paso 3 (Código de Seguridad)**: Envío de clave de 6 dígitos con expiración a tu correo o al de un *Accountability Partner* (amigo/pareja/mentor).

5. **Doble Presencia en macOS**:
   * **Dock**: Ventana principal amplia con diseño moderno, glassmorphism y temporizador circular.
   * **Barra de Menús (Menu Bar)**: Icono de estado con cuenta regresiva en vivo (`24:59`) y menú emergente rápido.

6. **Pantalla de Intervención Local y Respiración Consciente**:
   * Servidor local embebido que entrega una página con ejercicio guiado de respiración cuando intentas abrir una pestaña bloqueada.

---

## 🛠️ Cómo Ejecutar

### Opción 1: Script Rápido
```bash
./run.sh
```

### Opción 2: Swift CLI
```bash
# Compilar y ejecutar
swift run
```

### Opción 3: Abrir en Xcode
Puedes abrir la carpeta directamente en Xcode para compilar, depurar o crear un `.app` distribuible:
```bash
xed .
```

---

## 🧪 Pruebas Unitarias
```bash
swift test
```
