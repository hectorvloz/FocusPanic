<div align="center">

# 🧠⚡ FocusPanic
### Sistema Nativo de Enfoque Radical y Bloqueo Anti-Impulsividad para macOS
**Diseñado específicamente para personas con TDAH / ADHD y mentes altamente propensas a la distracción digital.**

[![macOS](https://img.shields.io/badge/macOS-13.0%2B%20Ventura%20%7C%20Sonoma%20%7C%20Sequoia-black?style=for-the-badge&logo=apple)](https://github.com/hectorvloz/FocusPanic/releases/latest)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Version](https://img.shields.io/badge/Release-v1.1.0-blue?style=for-the-badge)](https://github.com/hectorvloz/FocusPanic/releases/latest)
[![ADHD Optimized](https://img.shields.io/badge/ADHD-Optimized-success?style=for-the-badge&logo=brainly)](https://github.com/hectorvloz/FocusPanic)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=for-the-badge)](LICENSE)

<br/>

<!-- Botones de Acción Rápida -->
<p align="center">
  <a href="https://github.com/hectorvloz/FocusPanic/releases/latest/download/FocusPanic.dmg">
    <img src="https://img.shields.io/badge/⬇️_Descargar_Instalador-FocusPanic.dmg-007AFF?style=for-the-badge&logo=apple&logoColor=white" alt="Descargar FocusPanic DMG" height="42" />
  </a>
  <a href="https://github.com/hectorvloz/FocusPanic/releases/latest">
    <img src="https://img.shields.io/badge/📦_Ver_Releases-GitHub-24292e?style=for-the-badge&logo=github" alt="Ver Releases" height="42" />
  </a>
</p>

</div>

---

## ⚡ Instalación Rápida

Elige la forma que te sea más cómoda para instalar FocusPanic en tu Mac:

### 1. 🖥️ Instalación por Terminal en 1 solo comando (Recomendada)
Abre tu Terminal y pega la siguiente línea para descargar e instalar automáticamente la última versión en `/Applications`:

```bash
curl -fsSL https://raw.githubusercontent.com/hectorvloz/FocusPanic/main/install.sh | bash
```

### 2. 🍺 Mediante Homebrew Cask
```bash
brew install --cask https://raw.githubusercontent.com/hectorvloz/FocusPanic/main/Casks/focuspanic.rb
```

### 3. 💿 Descarga Directa del Instalador (.DMG)
1. Descarga el archivo oficial: [**FocusPanic.dmg**](https://github.com/hectorvloz/FocusPanic/releases/latest/download/FocusPanic.dmg).
2. Haz doble clic en el `.dmg` descargado.
3. Arrastra el icono de **FocusPanic** a tu carpeta de **Aplicaciones**.
4. ¡Listo! Ábrelo desde Spotlight (`Cmd + Espacio` ➔ *FocusPanic*) o el Launchpad.

---

## 🌟 ¿Por qué FocusPanic?

Las herramientas de productividad tradicionales fallan con el TDAH porque **son fáciles de apagar o ignorar**. Cuando el impulso dopaminérgico ataca, el cerebro salta barreras en milisegundos.

**FocusPanic introduce fricción deliberada, bloqueo a nivel de sistema operativo y técnicas cognitivas** diseñadas para hackear los momentos de debilidad:

* 🛑 **No hay atajos fáciles:** Si intentas desbloquear antes de tiempo, debes transcribir afirmaciones reflexivas y superar un período de enfriamiento programado.
* 🌐 **Bloqueo a nivel de kernel/DNS:** Funciona en **todos** los navegadores sin depender de extensiones que se puedan deshabilitar con un clic.
* 📱 **Anti-Doomscrolling:** Detecta patrones adictivos como los Estados de WhatsApp o feeds infinitos y activa ventanas de interrupción y respiración guiada.
* 🤝 **Accountability Real:** Puedes enviar el código de desbloqueo al correo de un amigo, pareja o mentor para no depender de tu propia fuerza de voluntad.

---

## ✨ Características Principales

### 🔴 1. Botón de Pánico Instantáneo
* Inicia sesiones de concentración inmediata con un solo toque o atajo global de teclado.
* **Presets Adaptados para TDAH:**
  * ⚡ **Micro-Sprint (15 min):** Para vencer la parálisis de inicio y arrancar una tarea pesada.
  * 🍅 **Pomodoro TDAH (25 min):** Intervalos clásicos con descansos estructurados.
  * 🎯 **Enfoque Profundo (45 min):** Ideal para programación, redacción o estudio intenso.
  * 🚀 **Hiperfoco (90 min):** Para sesiones de flujo creativo prolongado.
  * 🚨 **Pánico / Entrega Inmediata (120 min):** Máximo bloqueo de emergencia cuando el deadline es inminente.

### 🛡️ 2. Bloqueo Universal de Sitios Web
* Funciona en **Safari, Google Chrome, Arc, Brave, Firefox, Microsoft Edge, Opera** y cualquier app que realice peticiones web.
* Actúa a través del subsistema de red local (`/etc/hosts`) con vaciado atómico de caché DNS (`dscacheutil`, `mDNSResponder`).
* Catálogo inteligente predefinido: Twitter/X, Instagram, YouTube, TikTok, Reddit, Netflix, Twitch, Facebook, Amazon, etc.
* Añade cualquier dominio personalizado con un solo clic.

### 🚫 3. Bloqueo e Intercepción Activa de Apps
* Cierra o impide la ejecución de aplicaciones distractoras durante la sesión: **Discord, Telegram, Slack, Steam, WhatsApp, Mail, Spotify, etc.**
* Monitoreo proactivo en segundo plano para evitar que abras apps por hábito muscular involuntario.

### 🧘 4. Intervención en Estados de WhatsApp & Doomscrolling
* Servicio de vigilancia especializado para evitar caer en el bucle de "mirar estados" de WhatsApp Web y WhatsApp Desktop.
* Muestra una ventana de intervención a pantalla completa con ejercicios de respiración guiada para recuperar el control consciente.

### 🔞 5. Filtro de Contenido para Adultos & DNS Familiar
* Bloqueo estricto de más de 40 dominios y palabras clave de contenido para adultos y apuestas.
* Configuración automática opcional de **Cloudflare Families DNS (`1.1.1.3`)** para filtrado a nivel de resolución IP.

### 🔐 6. Fricción Deliberada y Desbloqueo de Emergencia (Anti-Impulso)
Para cancelar una sesión antes de que finalice, FocusPanic requiere superar un protocolo de 3 pasos:
1. **Paso 1 (Pausa Consciente):** Transcribir palabra por palabra una frase de reflexión para cortar el piloto automático del cerebro.
2. **Paso 2 (Tiempo de Enfriamiento):** Un temporizador de espera obligatorio (3 a 10 minutos) que da tiempo al pico de dopamina para disiparse.
3. **Paso 3 (Código de Seguridad):** Envío de un código numérico seguro con expiración a tu correo o al correo de tu *Accountability Partner*.

### 🔥 7. Racha de Hierro (Iron Streak)
* Mide tus días consecutivos de enfoque cumplido.
* Incluye sistema de **Congelamiento de Racha (Streak Freeze)** para proteger tu progreso en días libres o imprevistos.

### ⏳ 8. Límites Diarios de Aplicaciones & Horario de Descanso (Downtime)
* Define un tiempo máximo permitido al día para ciertas apps de ocio.
* **Toque de Queda Digital (Downtime):** Bloqueo automático durante tus horas de sueño para evitar el insomnio tecnológico.

### 🌐 9. Modo Nuclear / Whitelist
* ¿Necesitas aislamiento absoluto? Activa el **Modo Nuclear**: se bloquea todo Internet excepto los sitios expresamente autorizados para tu trabajo o estudio (e.g., GitHub, Notion, tu campus virtual).

### 🍏 10. Experiencia Nativa macOS
* **Barra de Menús (Menu Bar):** Cuenta regresiva viva en tiempo real (`24:59`) con popover desplegable para control rápido.
* **Ventana Principal:** Estética moderna, glassmorphism con efectos translúcidos de macOS, dark mode completo y retroalimentación háptica/sonora.
* **Inicio al Encender (Launch at Login):** Listo para proteger tu atención desde el primer segundo que inicias sesión.

### 🔄 11. Actualizador Automático Integrado (Auto-Updater)
* **Detección Automática de Releases:** Conexión directa y nativa con la API de GitHub Releases para comprobar si hay nuevas versiones al abrir la app o bajo demanda.
* **Instalación en 1 Clic:** Descarga transparente del instalador `.dmg`, reemplazo seguro en `/Applications` y reinicio automático de la app.
* **Historial y Novedades:** Muestra las notas de la versión directamente dentro de la aplicación para que siempre sepas qué ha mejorado.

---

## 🛠️ Compilación y Desarrollo Local

Si deseas compilar la aplicación desde las fuentes o contribuir al código:

### Requisitos
* macOS 13.0 (Ventura) o posterior.
* Xcode 15+ o Command Line Tools (`xcode-select --install`).
* Swift 5.9+.

### Clonar el repositorio
```bash
git clone https://github.com/hectorvloz/FocusPanic.git
cd FocusPanic
```

### Ejecutar en modo desarrollo
```bash
./run.sh
```

### Compilar e Instalar localmente en `/Applications`
```bash
./install.sh
```

### Crear el Instalador .DMG personalizado
```bash
./create_dmg.sh
```

---

## 🔒 Privacidad y Seguridad

* **100% Local:** Tus estadísticas, hábitos y configuraciones nunca salen de tu ordenador.
* **Sin Rastreadores ni Telemetría:** FocusPanic no recopila ningún tipo de dato personal.
* **Código Abierto:** Puedes auditar cada línea de código en este repositorio.

---

## 📄 Licencia

Este proyecto está bajo la Licencia **MIT**. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---

<div align="center">
  Hecho con ❤️ para quienes luchan cada día contra la distracción digital.
</div>
