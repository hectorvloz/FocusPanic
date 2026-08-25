import os
import shutil
from PIL import Image, ImageFilter

def generate_macos_standard_icon():
    source_path = "Resources/AppIcon.png"
    if not os.path.exists(source_path):
        print(f"Error: {source_path} no existe")
        return
    
    # Abrir la imagen original
    img = Image.open(source_path).convert("RGBA")
    
    # Si la imagen ya tiene contenido en un canvas completo, vamos a recortar al contenido real si es necesario
    # o escalarlo directamente al estándar de macOS (824x824 dentro de 1024x1024)
    target_canvas_size = 1024
    target_squircle_size = 824
    
    # Redimensionar el icono a 824x824 con alta calidad
    squircle_img = img.resize((target_squircle_size, target_squircle_size), Image.Resampling.LANCZOS)
    
    # Crear canvas final de 1024x1024 transparente
    canvas = Image.new("RGBA", (target_canvas_size, target_canvas_size), (0, 0, 0, 0))
    
    # Calcular posición centrada
    offset_x = (target_canvas_size - target_squircle_size) // 2 # 100 px
    offset_y = (target_canvas_size - target_squircle_size) // 2 + 4 # 104 px (ligero desplazamiento vertical típico de macOS)
    
    # Crear sombra suave nativa de macOS
    shadow_mask = squircle_img.split()[3]
    shadow_layer = Image.new("RGBA", (target_canvas_size, target_canvas_size), (0, 0, 0, 0))
    
    shadow_color = Image.new("RGBA", (target_squircle_size, target_squircle_size), (0, 0, 0, 60))
    shadow_layer.paste(shadow_color, (offset_x, offset_y + 10), shadow_mask)
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(radius=16))
    
    # Componer sombra y squircle
    canvas.paste(shadow_layer, (0, 0), shadow_layer)
    canvas.paste(squircle_img, (offset_x, offset_y), squircle_img)
    
    # Guardar la nueva AppIcon.png estandarizada
    canvas.save("Resources/AppIcon.png", format="PNG", optimize=True)
    print("✅ Resources/AppIcon.png estandarizada a la cuadrícula oficial de macOS (824px en canvas 1024px)")
    
    # Generar el iconset
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
    
    # Generar el archivo .icns usando iconutil
    os.system(f"iconutil -c icns {iconset_dir} -o Resources/AppIcon.icns")
    print("✅ Resources/AppIcon.icns generado con éxito")

if __name__ == "__main__":
    generate_macos_standard_icon()
