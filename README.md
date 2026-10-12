# elen

App nativa de macOS para **firmar PDFs** de forma sencilla: abre un documento, arrastra
el sello de la **fecha** o de la **firma** sobre la página y guarda un PDF nuevo firmado.

Pensada para usarse sin conocimientos técnicos: metáfora de escritorio, sellos en 3D,
animación y sonido al estampar, y controles de color y tamaño.

## Funciones

- Abrir un PDF y colocar un sello de **fecha** (fecha de hoy) o de **firma**.
- El sello se lleva con el ratón y muestra dónde va a quedar antes de hacer clic.
- **Biblioteca de firmas**: guarda varias firmas y elígelas desde un desplegable.
  Se pueden crear **dibujando** con el trackpad o **escaneando** con la cámara.
- Ajuste de **color de tinta** y **tamaño** del sello.
- Los sellos ya colocados se pueden **mover** (arrastrar) y **redimensionar** (tiradores del recuadro).
- Guarda siempre un **PDF nuevo** (`...-firmado.pdf`), sin tocar el original.

## Requisitos

- macOS 14 o superior.
- Para compilar: Xcode/Swift 5.9+.

## Compilar y ejecutar

```sh
./build.sh
open elen.app
```

## Generar el icono

El icono se genera a partir de una de las variantes de `make-icon-options.py` (parámetro
`CHOSEN` en `make-appicon.py`):

```sh
python3 make-appicon.py   # crea AppIcon.icns e icon-master.png
```

Requiere Pillow (`pip install pillow`). En `icon-options/index.html` hay una galería para elegir.

## Firmar, notarizar y publicar

```sh
# 1) Compila, firma con Developer ID (hardened runtime) y crea dist/elen.dmg
./scripts/package.sh

# 2) Notariza y grapa el DMG (necesitas credenciales de notarytool)
./scripts/notarize.sh --keychain-profile "AC_PASSWORD"
```

## Estructura

```
Sources/elen/        Código Swift (SwiftUI + PDFKit + AVFoundation)
assets/              Iconos de los sellos (PNG)
fonts/               Fuentes caligráficas para el icono
scripts/             Empaquetado y notarización
```

## Licencia

MIT — ver [LICENSE](LICENSE).
