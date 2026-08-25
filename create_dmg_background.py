import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import subprocess

def create_background(scale=2):
    # Generamos directamente a Retina 2x (1320 x 840) para nitidez absoluta
    W, H = 660 * scale, 420 * scale
    img = Image.new("RGBA", (W, H), (15, 17, 24, 255))
    draw = ImageDraw.Draw(img)

    # 1. Fondo Degradado Deep Slate / Dark Indigo muy limpio
    for y in range(H):
        ratio = y / float(H)
        r = int(14 + 10 * ratio)
        g = int(16 + 8 * ratio)
        b = int(24 + 18 * ratio)
        draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

    # 2. Resplandor Ambiental Sutil en el Centro (Entre los dos iconos)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    g_draw.ellipse([W//2 - 220*scale, H//2 - 90*scale, W//2 + 220*scale, H//2 + 90*scale], fill=(225, 29, 72, 30))
    g_draw.ellipse([W//2 - 120*scale, H//2 - 50*scale, W//2 + 120*scale, H//2 + 50*scale], fill=(139, 92, 246, 25))
    glow = glow.filter(ImageFilter.GaussianBlur(50 * scale))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # 3. Flecha Neón Degradada de Alta Definición (Centro exacto entre X=170 y X=490)
    arrow_start_x = 270 * scale
    arrow_end_x = 390 * scale
    arrow_y = 190 * scale

    # Línea con esquinas redondeadas y gradiente
    for x in range(arrow_start_x, arrow_end_x - 18*scale):
        progress = (x - arrow_start_x) / float(arrow_end_x - arrow_start_x - 18*scale)
        r = int(244 * (1 - progress) + 139 * progress)
        g = int(63 * (1 - progress) + 92 * progress)
        b = int(94 * (1 - progress) + 246 * progress)
        draw.line([(x, arrow_y - 2*scale), (x, arrow_y + 2*scale)], fill=(r, g, b, 240), width=max(2, 5*scale))

    # Punta de flecha elegante
    points = [
        (arrow_end_x, arrow_y),
        (arrow_end_x - 22*scale, arrow_y - 12*scale),
        (arrow_end_x - 16*scale, arrow_y),
        (arrow_end_x - 22*scale, arrow_y + 12*scale)
    ]
    draw.polygon(points, fill=(139, 92, 246, 255))

    # 4. Tipografía Ultra-Nítida Apple SF Pro
    try:
        font_badge = ImageFont.truetype("/System/Library/Fonts/SFProText-Bold.otf", 11 * scale)
        font_title = ImageFont.truetype("/System/Library/Fonts/SFProDisplay-Bold.otf", 24 * scale)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFProText-Medium.otf", 13 * scale)
        font_foot = ImageFont.truetype("/System/Library/Fonts/SFProText-Medium.otf", 11 * scale)
    except:
        try:
            font_badge = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11 * scale)
            font_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24 * scale)
            font_sub = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13 * scale)
            font_foot = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11 * scale)
        except:
            font_badge = ImageFont.load_default()
            font_title = ImageFont.load_default()
            font_sub = ImageFont.load_default()
            font_foot = ImageFont.load_default()

    # Badge Superior FOCUSPANIC
    badge_box = [W//2 - 68*scale, 28*scale, W//2 + 68*scale, 48*scale]
    draw.rounded_rectangle(badge_box, radius=10*scale, fill=(244, 63, 94, 30), outline=(244, 63, 94, 100), width=max(1, 1*scale))
    draw.text((W // 2, 38 * scale), "FOCUSPANIC 1.0", fill=(255, 110, 140, 255), font=font_badge, anchor="mm")

    # Título & Subtítulo Blancos Puros
    draw.text((W // 2, 72 * scale), "Instalador de FocusPanic", fill=(255, 255, 255, 255), font=font_title, anchor="mm")
    draw.text((W // 2, 102 * scale), "Arrastra FocusPanic a la carpeta de Aplicaciones para comenzar", fill=(190, 200, 215, 235), font=font_sub, anchor="mm")

    # Pie de página
    draw.text((W // 2, 385 * scale), "🧠 Enfoque Radical & Bloqueo Antiprocrastinación para macOS", fill=(120, 130, 150, 200), font=font_foot, anchor="mm")

    return img

img_2x = create_background(scale=2)
img_1x = img_2x.resize((660, 420), Image.Resampling.LANCZOS)

img_1x.save("Resources/dmg_background.png", "PNG")
img_2x.save("Resources/dmg_background@2x.png", "PNG")

# Generar TIFF Retina HiDPI
subprocess.run([
    "tiffutil",
    "-cathidpicheck",
    "Resources/dmg_background.png",
    "Resources/dmg_background@2x.png",
    "-out",
    "Resources/dmg_background.tiff"
], check=True)

print("✅ Fondo limpio Retina TIFF generado con éxito en Resources/dmg_background.tiff")
