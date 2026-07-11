# ESC/POS Viewer

**English** | [Español](README.es.md)

**ESC/POS** command viewer for Delphi (VCL): it interprets the byte stream sent to a thermal receipt printer and turns it into an image (`TBitmap` / PNG) — no printer required.

Extracted from a real POS system in production.

## Features

Interprets the most common ESC/POS commands of 80 mm thermal printers (203 dpi):

| Command | Function |
|---|---|
| `ESC @` | Initialize printer |
| `ESC M n` | Font A (12x24), B (9x17), C (7x14) |
| `ESC E n` | Bold |
| `ESC - n` | Underline |
| `ESC a n` | Left / center / right alignment |
| `ESC d n` | Feed n lines |
| `ESC i` | Paper cut (drawn as a dashed line) |
| `ESC p ...` | Open cash drawer (ignored) |
| `ESC * ...` | Raster graphics (single line) |
| `GS ! n` | Character size (multipliers 1-8) |
| `GS B n` | Reverse mode (white on black) |
| `GS v 0 ...` | Full raster image |
| `GS ( k ...` | Native QR codes (model, module size, error level, data) |

## Structure

```
visor_escpos/
├── src/
│   ├── EscPosRenderer.pas   # ESC/POS → image (the main unit)
│   ├── EscPosBuilder.pas    # ESC/POS ticket composition + RAW printing
│   └── EscPosScript.pas     # Pseudocode → ESC/POS (mini-language compiler)
├── lib/
│   └── DelphiZXingQRCode.pas  # QR generation (ZXing port, Apache 2.0)
├── demo/
│   ├── VisorEscPosDemo.dpr  # Sample project
│   ├── FMainDemo.pas
│   └── FMainDemo.dfm
├── ejemplos/                # Sample ESC/POS files (open them from the demo)
└── tools/
    └── generar_ejemplos.py  # Script that generates the files in ejemplos/
```

## Sample files

`ejemplos/` contains ESC/POS tickets ready to open with the *Abrir archivo ESC/POS...* button of the demo:

| File | Shows |
|---|---|
| `01_cafeteria.escpos` | Coffee shop receipt: header, columns, total, QR |
| `02_supermercado.escpos` | Long receipt: reverse header, VAT breakdown |
| `03_estilos_texto.escpos` | Fonts A/B/C, bold, underline, reverse, sizes |
| `04_alineaciones.escpos` | Alignments, columns, feeds and multiple cuts |
| `05_codigos_qr.escpos` | QR with different module sizes, error levels and alignment |
| `06_imagen_raster.escpos` | `GS v 0` raster images with alignment |
| `07_entrada_concierto.escpos` | Event ticket: big sizes, reverse band, QR |

Regenerate them with `python tools/generar_ejemplos.py`.

## Quick start

```pascal
uses EscPosRenderer;

var
  Renderer: TEscPosRenderer;
begin
  Renderer := TEscPosRenderer.Create; // 576 px wide = 80 mm paper
  try
    Renderer.Render(Comandos);        // string holding the ESC/POS bytes
    Renderer.GuardarPNG('ticket.png');
    // or: Image1.Picture.Bitmap.Assign(Renderer.Bitmap);
  finally
    Renderer.Free;
  end;
end;
```

To generate ESC/POS commands from Delphi (and optionally print them on a real printer via the RAW spooler):

```pascal
uses EscPosBuilder;

var
  Ticket: TTicketTermico;
begin
  Ticket := TTicketTermico.Create('Windows printer name');
  try
    Ticket.Inicializar;
    Ticket.Alinear(alCentro);
    Ticket.Negrita(True);
    Ticket.EscribirLinea('MY STORE');
    Ticket.ImprimirQRNativo('https://example.com');
    Ticket.CortarPapel;
    Ticket.Imprimir; // RAW output to the printer
    // or: Comandos := Ticket.ObtenerComandos; // for the viewer
  finally
    Ticket.Free;
  end;
end;
```

## Pseudocode (EscPosScript)

`EscPosScript.pas` compiles a plain-text mini-language into ESC/POS commands, no Pascal required. Each command maps to a `TTicketTermico` method. One command per line; `;` starts a comment. Keywords are in Spanish:

```
; Minimal ticket
INICIALIZAR
ALINEAR CENTRO
TAMANO 2 2
NEGRITA ON
LINEA MY STORE
TAMANO 1 1
NEGRITA OFF
ALINEAR IZQUIERDA
SEPARADOR
COLUMNAS 2 x Coffee | 3,00
COLUMNAS TOTAL | 3,00 EUR | 20
QR https://example.com | 8 | M
SALTAR 3
CORTAR
```

| Command | Parameters |
|---|---|
| `INICIALIZAR` | — (initialize) |
| `FUENTE` | `A` / `B` / `C` (font) |
| `ALINEAR` | `IZQUIERDA` / `CENTRO` / `DERECHA` (align left/center/right) |
| `NEGRITA`, `SUBRAYADO`, `INVERSO` | `ON` / `OFF` (bold, underline, reverse) |
| `TAMANO` | width height (size multipliers 1-8) |
| `TEXTO` | text without line break |
| `LINEA` | text with line break (empty = blank line) |
| `COLUMNAS` | left `\|` right `[\|` width`]` (two-column line) |
| `SEPARADOR` | optional character (default `-`) (separator line) |
| `SALTAR` | n lines (feed) |
| `QR` | text `[\|` module `[\|` level L/M/Q/H`]]` |
| `IMAGEN` | path `[\|` scale 1-8`]` — rasterizes BMP/PNG/JPG to `GS v 0`; centered and shrunk to fit the paper |
| `CORTAR` | optional `PARCIAL` (cut / partial cut) |
| `CAJON` | — (open drawer) |

```pascal
uses EscPosScript;

Script := TEscPosScript.Create;
try
  Comandos := Script.Compilar(Memo.Lines.Text);
  if Script.Errores.Count > 0 then
    ShowMessage(Script.Errores.Text); // errors with line numbers
finally
  Script.Free;
end;
```

## Demo

Open `demo/VisorEscPosDemo.dpr` in Delphi (the IDE generates the `.dproj` automatically) and build. The demo:

1. Includes a pseudocode editor with live preview and a help column listing every command: drag a command onto the editor (or double-click) to insert it, then press *Renderizar script*.
2. Generates a sample ticket in code (header, columns, total, QR and cut).
3. Opens files with raw ESC/POS commands (`.bin`, `.prn`, spooler captures...).
4. Saves the result as PNG.

## Requirements

- Delphi 10.3 Rio or later (uses inline `var` declarations). VCL, Windows.
- No external dependencies: the only third-party library (QR generation) is included.

## Technical notes

- Commands are handled as a `string` where each character represents one byte (`Char(Ord(b))`). When reading files, convert byte by byte; do not apply encoding conversions.
- Text is drawn with a monospaced font (Consolas by default, configurable via `NombreFuente`) without antialiasing, to mimic the look of a thermal printer.
- `EnviarComandoRAW` encodes text as CP858 (Spanish code page) while preserving the binary bytes of QR commands.
- Identifiers and API names are in Spanish, as the library originates from a Spanish POS project.

## License

MIT (see [LICENSE](LICENSE)). `DelphiZXingQRCode.pas` is a ZXing port by Debenu Pty Ltd, under the Apache 2.0 license (see the file header).
