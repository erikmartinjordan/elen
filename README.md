# elen

<p align="center">
  <img src="assets/icon.png" alt="elen icon" width="128" height="128" />
</p>

<p align="center">
  <strong>Sign PDFs with a date and signature stamp.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/github/downloads/erikmartinjordan/elen/total?label=Total%20downloads&style=flat-square" alt="Total downloads" />
</p>

A tiny native macOS app to sign PDFs: open a document, drag the **date** or the
**signature** stamp onto the page, and save a new signed PDF. Designed to be used
without any technical knowledge.

## Download

[Download the latest release](../../releases/latest) — a Developer ID signed and
notarized `.dmg`.

## Features

- Open a PDF and place a **date** (today) or **signature** stamp.
- Carry the stamp with the mouse; it previews exactly where it will land before you click.
- **Signature library**: keep several signatures and pick one from a dropdown.
  Create a new one by **drawing** with the trackpad or **scanning** it with the camera.
- Adjust the **ink color** and **stamp size**.
- Move a placed stamp by dragging, and resize it from the handles.
- Always saves a **new** file (`...-firmado.pdf`); the original is never touched.

## Usage

1. **Abrir documento** — open the PDF you want to sign.
2. Pick the **Fecha** or **Firma** stamp from the tray, move it over the page and click to stamp.
3. Move a stamp by dragging it, and resize it with the handles on the dashed box.
4. **Guardar PDF** — writes a new signed PDF next to the original.

## Requirements

- macOS 14 or newer.
- To build: Xcode / Swift 5.9+.

## Build

Build and run locally (ad-hoc signed):

```sh
./build.sh
open elen.app
```

## Signing, notarization and release

The GitHub Actions workflow (`.github/workflows/release.yml`) builds, signs with
Developer ID (hardened runtime), notarizes, staples and publishes the `.dmg` when
these repository secrets are set:

- `APPLE_DEVELOPER_ID_CERT_BASE64` — base64-encoded Developer ID Application `.p12`.
- `APPLE_DEVELOPER_ID_CERT_PASSWORD` — password for that `.p12`.
- `APPLE_ID` — Apple ID email used for notarization.
- `APPLE_ID_PASSWORD` — app-specific password for that Apple ID.

To publish, create a tag (`vX.Y.Z`) or run the **Release** workflow manually:

```sh
gh workflow run release.yml -f tag=v1.0.0
```

Locally you can also do it step by step:

```sh
./scripts/package.sh                                   # sign + build dist/elen.dmg
./scripts/notarize.sh --keychain-profile "AC_PASSWORD" # notarize + staple
```

## Icon

The app icon is generated from one of the variants in `make-icon-options.py`
(chosen in `make-appicon.py`):

```sh
python3 make-appicon.py   # writes AppIcon.icns and icon-master.png
```

Requires Pillow (`pip install pillow`). `icon-options/index.html` is a gallery to pick a variant.

## License

MIT — see [LICENSE](LICENSE).
