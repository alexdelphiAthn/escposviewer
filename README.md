# Visor ESC/POS

Visor de comandos **ESC/POS** para Delphi (VCL): interpreta el flujo de bytes que se envía a una impresora térmica de tickets y lo convierte en imagen (`TBitmap` / PNG), sin necesidad de tener la impresora.

Extraído del desarrollo real de un TPV en producción.

## Características

Interpreta los comandos ESC/POS más habituales de impresoras térmicas de 80 mm (203 dpi):

| Comando | Función |
|---|---|
| `ESC @` | Inicializar impresora |
| `ESC M n` | Fuente A (12x24), B (9x17), C (7x14) |
| `ESC E n` | Negrita |
| `ESC - n` | Subrayado |
| `ESC a n` | Alineación izquierda / centro / derecha |
| `ESC d n` | Saltar n líneas |
| `ESC i` | Corte de papel (se dibuja línea discontinua) |
| `ESC p ...` | Apertura de cajón (se ignora) |
| `ESC * ...` | Gráficos raster (línea) |
| `GS ! n` | Tamaño de carácter (multiplicadores 1-8) |
| `GS B n` | Modo inverso (blanco sobre negro) |
| `GS v 0 ...` | Imagen raster completa |
| `GS ( k ...` | Códigos QR nativos (modelo, módulo, nivel de error, datos) |

## Estructura

```
visor_escpos/
├── src/
│   ├── EscPosRenderer.pas   # ESC/POS → imagen (la unidad principal)
│   ├── EscPosBuilder.pas    # Composición de tickets ESC/POS + envío RAW a impresora
│   └── EscPosScript.pas     # Pseudocódigo → ESC/POS (compilador del mini-lenguaje)
├── lib/
│   └── DelphiZXingQRCode.pas  # Generación de QR (port de ZXing, Apache 2.0)
├── demo/
│   ├── VisorEscPosDemo.dpr  # Proyecto de ejemplo
│   ├── FMainDemo.pas
│   └── FMainDemo.dfm
├── ejemplos/                # Ficheros ESC/POS de muestra (abrir desde la demo)
└── tools/
    └── generar_ejemplos.py  # Script que genera los ficheros de ejemplos/
```

## Ficheros de ejemplo

En `ejemplos/` hay tickets ESC/POS listos para abrir con el botón *Abrir archivo ESC/POS...* de la demo:

| Fichero | Muestra |
|---|---|
| `01_cafeteria.escpos` | Ticket de bar: cabecera, columnas, total, QR |
| `02_supermercado.escpos` | Ticket largo: cabecera inversa, desglose de IVA |
| `03_estilos_texto.escpos` | Fuentes A/B/C, negrita, subrayado, inverso, tamaños |
| `04_alineaciones.escpos` | Alineaciones, columnas, saltos y cortes múltiples |
| `05_codigos_qr.escpos` | QR con distintos módulos, niveles de error y alineación |
| `06_imagen_raster.escpos` | Imágenes raster `GS v 0` con alineación |
| `07_entrada_concierto.escpos` | Entrada de evento: tamaños grandes, banda inversa, QR |

Se regeneran con `python tools/generar_ejemplos.py`.

## Uso rápido

```pascal
uses EscPosRenderer;

var
  Renderer: TEscPosRenderer;
begin
  Renderer := TEscPosRenderer.Create; // 576 px de ancho = papel de 80 mm
  try
    Renderer.Render(Comandos);        // string con los bytes ESC/POS
    Renderer.GuardarPNG('ticket.png');
    // o bien: Image1.Picture.Bitmap.Assign(Renderer.Bitmap);
  finally
    Renderer.Free;
  end;
end;
```

Para generar comandos ESC/POS desde Delphi (y opcionalmente imprimirlos en una impresora real vía spooler RAW):

```pascal
uses EscPosBuilder;

var
  Ticket: TTicketTermico;
begin
  Ticket := TTicketTermico.Create('Nombre impresora Windows');
  try
    Ticket.Inicializar;
    Ticket.Alinear(alCentro);
    Ticket.Negrita(True);
    Ticket.EscribirLinea('MI TIENDA');
    Ticket.ImprimirQRNativo('https://example.com');
    Ticket.CortarPapel;
    Ticket.Imprimir; // envío RAW a la impresora
    // o: Comandos := Ticket.ObtenerComandos; // para el visor
  finally
    Ticket.Free;
  end;
end;
```

## Pseudocódigo (EscPosScript)

`EscPosScript.pas` compila un mini-lenguaje de texto plano a comandos ESC/POS, sin escribir Pascal. Cada comando corresponde a un método de `TTicketTermico`. Un comando por línea; `;` inicia comentario:

```
; Ticket mínimo
INICIALIZAR
ALINEAR CENTRO
TAMANO 2 2
NEGRITA ON
LINEA MI TIENDA
TAMANO 1 1
NEGRITA OFF
ALINEAR IZQUIERDA
SEPARADOR
COLUMNAS 2 x Cafe con leche | 3,00
COLUMNAS TOTAL | 3,00 EUR | 20
QR https://example.com | 8 | M
SALTAR 3
CORTAR
```

| Comando | Parámetros |
|---|---|
| `INICIALIZAR` | — |
| `FUENTE` | `A` / `B` / `C` |
| `ALINEAR` | `IZQUIERDA` / `CENTRO` / `DERECHA` |
| `NEGRITA`, `SUBRAYADO`, `INVERSO` | `ON` / `OFF` |
| `TAMANO` | ancho alto (multiplicadores 1-8) |
| `TEXTO` | texto sin salto de línea |
| `LINEA` | texto con salto (vacío = línea en blanco) |
| `COLUMNAS` | izquierda `\|` derecha `[\|` ancho`]` |
| `SEPARADOR` | carácter opcional (por defecto `-`) |
| `SALTAR` | n líneas |
| `QR` | texto `[\|` módulo `[\|` nivel L/M/Q/H`]]` |
| `CORTAR` | `PARCIAL` opcional |
| `CAJON` | — |

```pascal
uses EscPosScript;

Script := TEscPosScript.Create;
try
  Comandos := Script.Compilar(Memo.Lines.Text);
  if Script.Errores.Count > 0 then
    ShowMessage(Script.Errores.Text); // errores con número de línea
finally
  Script.Free;
end;
```

## Demo

Abrir `demo/VisorEscPosDemo.dpr` en Delphi (el IDE genera el `.dproj` automáticamente) y compilar. La demo:

1. Incluye un editor de pseudocódigo con vista previa y una columna de ayuda con todos los comandos: arrastre un comando al editor (o haga doble clic) para insertarlo, y pulse *Renderizar script*.
2. Genera un ticket de ejemplo por código (cabecera, columnas, total, QR y corte).
3. Permite abrir un archivo con comandos ESC/POS crudos (`.bin`, `.prn`, capturas del spooler...).
4. Guarda el resultado como PNG.

## Requisitos

- Delphi 10.3 Rio o superior (usa declaraciones `var` inline). VCL, Windows.
- Sin dependencias externas: la única librería de terceros (generación de QR) está incluida.

## Notas técnicas

- Los comandos se manejan como `string` donde cada carácter representa un byte (`Char(Ord(b))`). Al leer archivos, convertir byte a byte; no usar conversiones de codificación.
- El texto se dibuja con una fuente monoespaciada (Consolas por defecto, configurable con `NombreFuente`) sin suavizado, para imitar el aspecto de la impresora térmica.
- `EnviarComandoRAW` codifica el texto a CP858 (español) y preserva los bytes binarios de los comandos QR.

## Licencia

MIT (ver [LICENSE](LICENSE)). `DelphiZXingQRCode.pas` es un port de ZXing por Debenu Pty Ltd, bajo licencia Apache 2.0 (ver cabecera del archivo).
