import os
import shutil
from PIL import Image, ImageDraw, ImageFilter

def generate_macos_standard_icon():
    src_path = "/Users/hector/.gemini/antigravity-ide/brain/a575d413-2d6a-439e-b975-5ed628ec5726/focuspanic_app_icon_1787777162781.jpg"
    if not os.path.exists(src_path):
        src_path = "Resources/AppIcon.png"
    
    img = Image.open(src_path).convert("RGBA")
    
    # 1. Recortar exactamente la tarjeta squircle con su fondo oscuro original y su logo brillante
    crop_box = (158, 158, 866, 866)
    squircle_img = img.crop(crop_box)
    
    # 2. Redimensionar al estándar de macOS: 824x824
    target_size = 824
    squircle_resized = squircle_img.resize((target_size, target_size), Image.Resampling.LANCZOS)
    
    # 3. Crear máscara Squircle oficial de Apple con 4x supersampling para bordes ultra suaves
    scale = 4
    mask_size = target_size * scale
    mask = Image.new("L", (mask_size, mask_size), 0)
    draw = ImageDraw.Draw(mask)
    corner_radius = int(185 * scale)
    draw.rounded_rectangle([0, 0, mask_size, mask_size], radius=corner_radius, fill=255)
    mask = mask.resize((target_size, target_size), Image.Resampling.LANCZOS)
    
    # 4. Aplicar la máscara (conserva 100% el fondo oscuro y el logo original por dentro, y hace transparentes solo las esquinas exteriores)
    squircle_final = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    squircle_final.paste(squircle_resized, (0, 0), mask)
    
    # 5. Canvas transparente 1024x1024 con sombra nativa de macOS
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    offset_x = (1024 - target_size) // 2 # 100
    offset_y = (1024 - target_size) // 2 + 6 # 106
    
    # Sombra suave de macOS
    shadow_layer = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shadow_color = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 95))
    shadow_layer.paste(shadow_color, (offset_x, offset_y + 14), mask)
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=20))
    
    canvas.paste(shadow_layer, (0, 0), shadow_layer)
    canvas.paste(squircle_final, (offset_x, offset_y), squircle_final)
    
    os.makedirs("Resources", exist_ok=True)
    canvas.save("Resources/AppIcon.png", format="PNG", optimize=True)
    print("✅ Resources/AppIcon.png generado exactamente con el fondo oscuro original y el logo minimalista")
    
    # 6. Generar .iconset y .icns
    iconset_dir = "Resources/AppIcon.iconset"
    if os.path.exists(iconset_dir):
        shutil.rmtree(iconset_dir)
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    for filename, size in sizes:
        resized = canvas.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, filename), format="PNG", optimize=True)
    
    os.system(f"iconutil -c icns {iconset_dir} -o Resources/AppIcon.icns")
    print("✅ Resources/AppIcon.icns generado con éxito")

if __name__ == "__main__":
    generate_macos_standard_icon()
