import os
import subprocess

from PIL import Image

from iconlib import BASE, VARIANTS, build

CHOSEN = 16  # opción elegida en la web

icon = build(VARIANTS[CHOSEN - 1], out_size=1024)
icon.save(os.path.join(BASE, "icon-master.png"))

iconset = os.path.join(BASE, "AppIcon.iconset")
os.makedirs(iconset, exist_ok=True)
specs = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for size, name in specs:
    icon.resize((size, size), Image.LANCZOS).save(os.path.join(iconset, name))
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(BASE, "AppIcon.icns")], check=True)
print(f"icono final (opción {CHOSEN}) generado")
