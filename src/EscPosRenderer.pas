{******************************************************************************}
{                                                                              }
{  Módulo:       EscPosRenderer                                                }
{    Tipo:       Librería                                                      }
{ Versión:       1.0.0                                                         }
{                                                                              }
{  Descripción:                                                                }
{    Renderizador de comandos ESC/POS a imagen (TBitmap / PNG).                }
{    Interpreta los comandos de una impresora térmica de 80 mm y dibuja el     }
{    ticket resultante: fuentes A/B/C, negrita, subrayado, alineación,         }
{    tamaños de carácter, modo inverso, imágenes raster (GS v 0 y ESC *),      }
{    códigos QR nativos (GS ( k) y corte de papel.                             }
{                                                                              }
{  Uso:                                                                        }
{    var Renderer := TEscPosRenderer.Create;                                   }
{    try                                                                       }
{      Renderer.Render(Comandos);          // string con bytes ESC/POS        }
{      Renderer.GuardarPNG('ticket.png');                                      }
{    finally                                                                   }
{      Renderer.Free;                                                          }
{    end;                                                                      }
{                                                                              }
{  Licencia: MIT. Ver LICENSE en la raíz del repositorio.                      }
{******************************************************************************}
unit EscPosRenderer;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Math,
  Vcl.Graphics, DelphiZXingQRCode;

const
  // Papel térmico de 80 mm a 203 dpi
  ANCHO_PAPEL_PIXELS_80MM = 576;

type
  TEscPosRenderer = class
  private
    FBitmap: TBitmap;
    FCanvas: TCanvas;
    FAnchoPapel: Integer;
    FCurrentY: Integer;
    FFuenteActual: Integer;   // 0=A(12x24), 1=B(9x17), 2=C(7x14)
    FNegrita: Boolean;
    FSubrayado: Boolean;
    FAlineacion: Integer;     // 0=Izq, 1=Centro, 2=Derecha
    FTamanoAncho: Integer;    // Multiplicador ancho (1-8)
    FTamanoAlto: Integer;     // Multiplicador alto (1-8)
    FInverso: Boolean;
    FQRTexto: string;
    FQRTamanoModulo: Integer;
    FQRNivelError: Integer;
    FNombreFuente: string;
    procedure ReiniciarEstado;
    procedure InicializarPapel(AAlto: Integer);
    procedure AsegurarAltoPapel(AAltoNecesario: Integer);
    procedure RecortarPapel(AAltoFinal: Integer);
    procedure ProcesarComandos(const Comandos: string);
    procedure ImprimirTexto(const Texto: string);
    procedure ImprimirImagenRaster(const Datos: string; Ancho, Alto: Integer);
    procedure NuevaLinea;
    procedure AjustarFuente;
    function ObtenerAltoLinea: Integer;
    procedure DibujarQRCode;
  public
    constructor Create(AAnchoPapelPixels: Integer = ANCHO_PAPEL_PIXELS_80MM);
    destructor Destroy; override;
    { Interpreta los comandos ESC/POS y devuelve el bitmap resultante.
      El bitmap es propiedad del renderer; usar Bitmap.Assign para copiarlo. }
    function Render(const Comandos: string): TBitmap;
    procedure GuardarPNG(const ARuta: string);
    procedure GuardarBMP(const ARuta: string);
    property Bitmap: TBitmap read FBitmap;
    { Fuente monoespaciada usada para el texto (por defecto Consolas). }
    property NombreFuente: string read FNombreFuente write FNombreFuente;
  end;

implementation

uses
  Vcl.Imaging.PngImage;

const
  MARGEN_PIXELS = 8;
  // Alto de fuentes en píxeles (aproximación a fuentes térmicas reales)
  FUENTE_A_ALTO = 24;
  FUENTE_B_ALTO = 17;
  FUENTE_C_ALTO = 14;
  ALTO_PAPEL_INICIAL = 2000;
  MARGEN_PAPEL_FINAL = 50;
  MARGEN_CRECIMIENTO_PAPEL = 500;
  ALTO_MINIMO = 64;

constructor TEscPosRenderer.Create(AAnchoPapelPixels: Integer);
begin
  inherited Create;
  FAnchoPapel := AAnchoPapelPixels;
  FNombreFuente := 'Consolas';
  FBitmap := TBitmap.Create;
  InicializarPapel(ALTO_PAPEL_INICIAL);
  ReiniciarEstado;
end;

destructor TEscPosRenderer.Destroy;
begin
  FreeAndNil(FBitmap);
  inherited;
end;

procedure TEscPosRenderer.ReiniciarEstado;
begin
  FCurrentY := MARGEN_PIXELS;
  FFuenteActual := 0;
  FNegrita := False;
  FSubrayado := False;
  FAlineacion := 0;
  FTamanoAncho := 1;
  FTamanoAlto := 1;
  FInverso := False;
  FQRTexto := '';
  FQRTamanoModulo := 8;
  FQRNivelError := 48;
end;

procedure TEscPosRenderer.InicializarPapel(AAlto: Integer);
begin
  if AAlto < ALTO_MINIMO then
    AAlto := ALTO_MINIMO;
  FBitmap.PixelFormat := pf24bit;
  FBitmap.Width := FAnchoPapel;
  FBitmap.Height := AAlto;
  FCanvas := FBitmap.Canvas;
  FCanvas.Brush.Style := bsSolid;
  FCanvas.Brush.Color := clWhite;
  FCanvas.FillRect(Rect(0, 0, FAnchoPapel, AAlto));
  FCanvas.Brush.Style := bsClear;
end;

procedure TEscPosRenderer.AsegurarAltoPapel(AAltoNecesario: Integer);
var
  iNuevoAlto: Integer;
  oBitmapActual: TBitmap;
begin
  if AAltoNecesario > FBitmap.Height then
  begin
    iNuevoAlto := Max(AAltoNecesario + MARGEN_CRECIMIENTO_PAPEL,
                      FBitmap.Height * 2);
    oBitmapActual := TBitmap.Create;
    try
      oBitmapActual.Assign(FBitmap);
      FBitmap.PixelFormat := pf24bit;
      FBitmap.Width := FAnchoPapel;
      FBitmap.Height := iNuevoAlto;
      FCanvas := FBitmap.Canvas;
      FCanvas.Brush.Style := bsSolid;
      FCanvas.Brush.Color := clWhite;
      FCanvas.FillRect(Rect(0, 0, FAnchoPapel, iNuevoAlto));
      FCanvas.Draw(0, 0, oBitmapActual);
      FCanvas.Brush.Style := bsClear;
    finally
      FreeAndNil(oBitmapActual);
    end;
  end;
end;

procedure TEscPosRenderer.RecortarPapel(AAltoFinal: Integer);
var
  oBitmapFinal: TBitmap;
begin
  if AAltoFinal < ALTO_MINIMO then
    AAltoFinal := ALTO_MINIMO;
  AsegurarAltoPapel(AAltoFinal);
  oBitmapFinal := TBitmap.Create;
  try
    oBitmapFinal.PixelFormat := pf24bit;
    oBitmapFinal.Width := FAnchoPapel;
    oBitmapFinal.Height := AAltoFinal;
    oBitmapFinal.Canvas.Brush.Style := bsSolid;
    oBitmapFinal.Canvas.Brush.Color := clWhite;
    oBitmapFinal.Canvas.FillRect(Rect(0, 0, FAnchoPapel, AAltoFinal));
    oBitmapFinal.Canvas.Draw(0, 0, FBitmap);
    FBitmap.Assign(oBitmapFinal);
  finally
    FreeAndNil(oBitmapFinal);
  end;
  FCanvas := FBitmap.Canvas;
end;

function TEscPosRenderer.Render(const Comandos: string): TBitmap;
begin
  InicializarPapel(ALTO_PAPEL_INICIAL);
  ReiniciarEstado;
  ProcesarComandos(Comandos);
  RecortarPapel(FCurrentY + MARGEN_PAPEL_FINAL);
  Result := FBitmap;
end;

procedure TEscPosRenderer.DibujarQRCode;
var
  QRCode: TDelphiZXIngQRCode;
  Row, Column: Integer;
  Scale: Integer;
  QRBitmap: TBitmap;
  x, y: Integer;
  StartX: Integer;
  QRWidth, QRHeight: Integer;
begin
  if FQRTexto <> '' then
  begin
    QRCode := TDelphiZXIngQRCode.Create;
    QRBitmap := TBitmap.Create;
    try
      // Nivel ESC/POS: 48=L, 49=M, 50=Q, 51=H.
      case FQRNivelError of
        49:
          QRCode.ErrorCorrectionLevel := qreM;
        50:
          QRCode.ErrorCorrectionLevel := qreQ;
        51:
          QRCode.ErrorCorrectionLevel := qreH;
      else
        QRCode.ErrorCorrectionLevel := qreL;
      end;
      QRCode.Encoding := TQRCodeEncoding(qrUTF8NoBOM);
      QRCode.QuietZone := 1;
      QRCode.Data := FQRTexto;
      // Escala basada en el tamaño del módulo.
      Scale := FQRTamanoModulo div 2;
      if Scale < 2 then
        Scale := 2;
      QRBitmap.Width := QRCode.Columns * Scale;
      QRBitmap.Height := QRCode.Rows * Scale;
      QRBitmap.PixelFormat := pf24bit;
      QRBitmap.Canvas.Brush.Color := clWhite;
      QRBitmap.Canvas.FillRect(Rect(0, 0, QRBitmap.Width, QRBitmap.Height));
      QRBitmap.Canvas.Brush.Color := clBlack;
      for Row := 0 to QRCode.Rows - 1 do
      begin
        for Column := 0 to QRCode.Columns - 1 do
        begin
          if QRCode.IsBlack[Row, Column] then
          begin
            x := Column * Scale;
            y := Row * Scale;
            QRBitmap.Canvas.FillRect(Rect(x, y, x + Scale, y + Scale));
          end;
        end;
      end;
      QRWidth := QRBitmap.Width;
      QRHeight := QRBitmap.Height;
      case FAlineacion of
        1:
          StartX := (FAnchoPapel - QRWidth) div 2;
        2:
          StartX := FAnchoPapel - QRWidth - MARGEN_PIXELS;
      else
        StartX := MARGEN_PIXELS;
      end;
      AsegurarAltoPapel(FCurrentY + QRHeight + MARGEN_PAPEL_FINAL);
      FCanvas.Draw(StartX, FCurrentY, QRBitmap);
      FCurrentY := FCurrentY + QRHeight;
    finally
      FreeAndNil(QRBitmap);
      FreeAndNil(QRCode);
    end;
  end;
end;

procedure TEscPosRenderer.ImprimirImagenRaster(const Datos: string;
                                               Ancho, Alto: Integer);
var
  X, Y: Integer;
  ByteIndex, BitIndex: Integer;
  StartX: Integer;
begin
  AsegurarAltoPapel(FCurrentY + Alto + MARGEN_PAPEL_FINAL);
  if Length(Datos) = 0 then
  begin
    FCurrentY := FCurrentY + Alto;
  end
  else
  begin
    // Calcular posición X según alineación
    case FAlineacion of
      1: StartX := (FAnchoPapel - Ancho) div 2;          // Centro
      2: StartX := FAnchoPapel - Ancho - MARGEN_PIXELS;  // Derecha
    else
      StartX := MARGEN_PIXELS;                           // Izquierda
    end;
    if StartX < 0 then
      StartX := 0;
    if StartX + Ancho > FAnchoPapel then
      Ancho := FAnchoPapel - StartX;
    for Y := 0 to Alto - 1 do
    begin
      for X := 0 to Ancho - 1 do
      begin
        ByteIndex := (X div 8) + 1;
        BitIndex := 7 - (X mod 8);
        if (ByteIndex <= Length(Datos)) and (ByteIndex > 0) then
        begin
          if ((Ord(Datos[ByteIndex]) and (1 shl BitIndex)) <> 0) then
          begin
            if (StartX + X < FAnchoPapel) and
               (FCurrentY + Y < FBitmap.Height) then
              FCanvas.Pixels[StartX + X, FCurrentY + Y] := clBlack;
          end;
        end;
      end;
    end;
    FCurrentY := FCurrentY + Alto;
  end;
end;

procedure TEscPosRenderer.ProcesarComandos(const Comandos: string);
var
  i: Integer;
  BufferTexto: string;
  function LeerByte: Byte;
  begin
    Inc(i);
    if i <= Length(Comandos) then
      Result := Ord(Comandos[i])
    else
      Result := 0;
  end;
  function LeerWord: Word;
  var
    Lo, Hi: Byte;
  begin
    Lo := LeerByte;
    Hi := LeerByte;
    Result := Lo + (Hi shl 8);
  end;
begin
  i := 1;
  BufferTexto := '';
  while i <= Length(Comandos) do
  begin
    case Comandos[i] of
      #27: // ESC
        begin
          Inc(i);
          if i > Length(Comandos) then Break;
          case Comandos[i] of
            '@': // Inicializar
              begin
                FFuenteActual := 0;
                FNegrita := False;
                FSubrayado := False;
                FAlineacion := 0;
                FTamanoAncho := 1;
                FTamanoAlto := 1;
                FInverso := False;
              end;
            'M', 'm': // Seleccionar fuente
              begin
                FFuenteActual := LeerByte;
                if FFuenteActual > 2 then FFuenteActual := 1;
              end;
            'E': // Negrita on/off
              begin
                FNegrita := LeerByte <> 0;
              end;
            '-': // Subrayado on/off
              begin
                var Modo := LeerByte;
                FSubrayado := Modo <> 0;
              end;
            'a': // Alineación
              begin
                FAlineacion := LeerByte;
                if FAlineacion > 2 then FAlineacion := 0;
              end;
            'd': // Saltar n líneas
              begin
                if BufferTexto <> '' then
                begin
                  ImprimirTexto(BufferTexto);
                  BufferTexto := '';
                end;
                var Lineas := LeerByte;
                FCurrentY := FCurrentY + (Lineas * ObtenerAltoLinea);
              end;
            't': // Seleccionar página de códigos (solo visual, ignorar)
              begin
                LeerByte;
              end;
            '*': // Gráficos raster (una línea)
              begin
                if BufferTexto <> '' then
                begin
                  ImprimirTexto(BufferTexto);
                  BufferTexto := '';
                end;
                var Modo := LeerByte;
                var Ancho := LeerWord;
                var BytesPorLinea := (Ancho + 7) div 8;
                var DatosImagen := '';
                for var j := 1 to BytesPorLinea do
                  DatosImagen := DatosImagen + Char(LeerByte);
                ImprimirImagenRaster(DatosImagen, Ancho, 1);
              end;
            'i': // Cortar papel
              begin
                // Visual: dibujar línea de corte
                AsegurarAltoPapel(FCurrentY + 20 + MARGEN_PAPEL_FINAL);
                FCanvas.Pen.Color := clGray;
                FCanvas.Pen.Style := psDash;
                FCanvas.MoveTo(0, FCurrentY + 10);
                FCanvas.LineTo(FAnchoPapel, FCurrentY + 10);
                FCurrentY := FCurrentY + 20;
              end;
            'p': // Abrir cajón (ignorar)
              begin
                Inc(i, 3); // Saltar parámetros
              end;
          end;
        end;
      #29: // GS
        begin
          Inc(i);
          if i > Length(Comandos) then Break;
          case Comandos[i] of
            '!': // Tamaño de carácter
              begin
                var Valor := LeerByte;
                FTamanoAncho := (Valor and $0F) + 1;
                FTamanoAlto := ((Valor shr 4) and $07) + 1;
                if FTamanoAncho > 8 then FTamanoAncho := 1;
                if FTamanoAlto > 8 then FTamanoAlto := 1;
              end;
            'B': // Modo blanco/negro invertido
              begin
                FInverso := LeerByte <> 0;
              end;
            '(': // Comandos función (incluye QR)
              begin
                Inc(i);
                if i > Length(Comandos) then Break;
                if Comandos[i] = 'k' then // Comando QR
                begin
                  var pL := LeerByte;
                  var pH := LeerByte;
                  var DataLength := pL + (pH * 256);
                  var Fn := LeerByte; // Función
                  var Cn := LeerByte; // Código de función
                  case Cn of
                    65: // 'A' - Seleccionar modelo (ignorar)
                      begin
                        for var j := 1 to DataLength - 2 do
                          LeerByte;
                      end;
                    67: // 'C' - Tamaño del módulo
                      begin
                        FQRTamanoModulo := LeerByte;
                        for var j := 1 to DataLength - 3 do
                          LeerByte;
                      end;
                    69: // 'E' - Nivel de corrección de errores
                      begin
                        FQRNivelError := LeerByte;
                        for var j := 1 to DataLength - 3 do
                          LeerByte;
                      end;
                    80: // 'P' - Almacenar datos
                      begin
                        LeerByte; // Saltar byte adicional
                        FQRTexto := '';
                        for var j := 1 to DataLength - 3 do
                          FQRTexto := FQRTexto + Char(LeerByte);
                      end;
                    81: // 'Q' - Imprimir QR
                      begin
                        for var j := 1 to DataLength - 2 do
                          LeerByte;
                        if BufferTexto <> '' then
                        begin
                          ImprimirTexto(BufferTexto);
                          BufferTexto := '';
                        end;
                        DibujarQRCode;
                        FQRTexto := ''; // Limpiar después de imprimir
                      end;
                  else
                    // Comando desconocido, saltar datos
                    for var j := 1 to DataLength - 2 do
                      LeerByte;
                  end;
                end
                else
                begin
                  // Otro comando con paréntesis, saltar
                  var pL := LeerByte;
                  var pH := LeerByte;
                  var DataLength := pL + (pH * 256);
                  for var j := 1 to DataLength do
                    LeerByte;
                end;
              end;
            'v': // Imprimir imagen raster (formato GS v 0)
              begin
                Inc(i);
                if i > Length(Comandos) then Break;
                if Comandos[i] = '0' then
                begin
                  var Modo := LeerByte;
                  var AnchoBytes := LeerWord;
                  var Alto := LeerWord;
                  if BufferTexto <> '' then
                  begin
                    ImprimirTexto(BufferTexto);
                    BufferTexto := '';
                  end;
                  var DatosImagen := '';
                  for var j := 1 to AnchoBytes * Alto do
                    DatosImagen := DatosImagen + Char(LeerByte);
                  var AnchoPixels := AnchoBytes * 8;
                  var X, Y: Integer;
                  var StartX: Integer;
                  case FAlineacion of
                    1: StartX := (FAnchoPapel - AnchoPixels) div 2;
                    2: StartX := FAnchoPapel - AnchoPixels - MARGEN_PIXELS;
                  else
                    StartX := MARGEN_PIXELS;
                  end;
                  AsegurarAltoPapel(FCurrentY + Alto + MARGEN_PAPEL_FINAL);
                  for Y := 0 to Alto - 1 do
                  begin
                    for X := 0 to AnchoPixels - 1 do
                    begin
                      var ByteIndex := Y * AnchoBytes + (X div 8);
                      var BitIndex := 7 - (X mod 8);
                      if (ByteIndex < Length(DatosImagen)) and
                         ((Ord(DatosImagen[ByteIndex + 1]) and
                         (1 shl BitIndex)) <> 0) then
                      begin
                        FCanvas.Pixels[StartX + X, FCurrentY + Y] := clBlack;
                      end;
                    end;
                  end;
                  FCurrentY := FCurrentY + Alto;
                end;
              end;
          end;
        end;
      #10: // LF - Nueva línea
        begin
          if BufferTexto <> '' then
          begin
            ImprimirTexto(BufferTexto);
            BufferTexto := '';
          end;
          NuevaLinea;
        end;
      #13: // CR - Retorno de carro (ignorar)
        begin
        end;
      #9: // TAB
        begin
          BufferTexto := BufferTexto + '    '; // 4 espacios
        end;
    else
      // Caracteres imprimibles
      if Ord(Comandos[i]) >= 32 then
        BufferTexto := BufferTexto + Comandos[i];
    end;
    Inc(i);
  end;
  // Imprimir texto restante
  if BufferTexto <> '' then
    ImprimirTexto(BufferTexto);
end;

procedure TEscPosRenderer.AjustarFuente;
var
  LogFont: TLogFont;
  AlturaPixels: Integer;
begin
  // 1. Determinar altura en PÍXELES reales (no puntos)
  case FFuenteActual of
    0: AlturaPixels := FUENTE_A_ALTO; // Fuente A (12x24)
    1: AlturaPixels := FUENTE_B_ALTO; // Fuente B (9x17)
    2: AlturaPixels := FUENTE_C_ALTO; // Fuente C (7x14)
  else
    AlturaPixels := FUENTE_B_ALTO;
  end;
  // Aplicar multiplicadores de tamaño ESC/POS
  AlturaPixels := AlturaPixels * FTamanoAlto;
  // 2. Obtener la estructura LogFont actual del Canvas
  if GetObject(FCanvas.Font.Handle, SizeOf(TLogFont), @LogFont) = 0 then
  begin
    FillChar(LogFont, SizeOf(LogFont), 0);
    StrPCopy(LogFont.lfFaceName, FNombreFuente);
  end;
  // 3. Configuración para nitidez (bordes duros como impresora térmica)
  LogFont.lfHeight := -AlturaPixels;
  LogFont.lfWidth := 0;
  LogFont.lfQuality := NONANTIALIASED_QUALITY;
  if FNegrita then
    LogFont.lfWeight := FW_BOLD
  else
    LogFont.lfWeight := FW_NORMAL;
  if FSubrayado then
    LogFont.lfUnderline := 1
  else
    LogFont.lfUnderline := 0;
  StrPCopy(LogFont.lfFaceName, FNombreFuente);
  // 4. Asignar la nueva fuente al Canvas
  FCanvas.Font.Handle := CreateFontIndirect(LogFont);
  FCanvas.Font.Color := clBlack;
  FCanvas.Brush.Style := bsClear;
end;

function TEscPosRenderer.ObtenerAltoLinea: Integer;
begin
  case FFuenteActual of
    0: Result := FUENTE_A_ALTO;
    1: Result := FUENTE_B_ALTO;
    2: Result := FUENTE_C_ALTO;
  else
    Result := FUENTE_B_ALTO;
  end;
  Result := Result * FTamanoAlto;
end;

procedure TEscPosRenderer.ImprimirTexto(const Texto: string);
var
  X: Integer;
  TextoWidth: Integer;
begin
  if Texto <> '' then
  begin
    AsegurarAltoPapel(FCurrentY + ObtenerAltoLinea + MARGEN_PAPEL_FINAL);
    AjustarFuente;
    // Windows nos dice el ancho real exacto de la frase
    TextoWidth := FCanvas.TextWidth(Texto);
    case FAlineacion of
      0: X := MARGEN_PIXELS;
      1: X := (FAnchoPapel - TextoWidth) div 2;
      2: X := FAnchoPapel - TextoWidth - MARGEN_PIXELS;
    else
      X := MARGEN_PIXELS;
    end;
    if FInverso then
    begin
      FCanvas.Brush.Style := bsSolid;
      FCanvas.Brush.Color := clBlack;
      FCanvas.Font.Color := clWhite;
    end
    else
    begin
      FCanvas.Brush.Style := bsClear;
      FCanvas.Font.Color := clBlack;
    end;
    FCanvas.TextOut(X, FCurrentY, Texto);
    FCanvas.Brush.Style := bsClear;
  end;
end;

procedure TEscPosRenderer.NuevaLinea;
begin
  FCurrentY := FCurrentY + ObtenerAltoLinea;
end;

procedure TEscPosRenderer.GuardarPNG(const ARuta: string);
var
  png: TPngImage;
begin
  png := TPngImage.Create;
  try
    png.Assign(FBitmap);
    png.SaveToFile(ARuta);
  finally
    FreeAndNil(png);
  end;
end;

procedure TEscPosRenderer.GuardarBMP(const ARuta: string);
begin
  FBitmap.SaveToFile(ARuta);
end;

end.
