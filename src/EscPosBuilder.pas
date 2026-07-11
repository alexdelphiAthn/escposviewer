{******************************************************************************}
{                                                                              }
{  Módulo:       EscPosBuilder                                                 }
{    Tipo:       Librería                                                      }
{ Versión:       1.0.0                                                         }
{                                                                              }
{  Descripción:                                                                }
{    Composición y envío de tickets a impresoras térmicas ESC/POS.             }
{    Soporta fuentes, alineación, imágenes, códigos QR nativos, corte de       }
{    papel y apertura de cajón. Incluye envío RAW a impresoras Windows.        }
{                                                                              }
{  Licencia: MIT. Ver LICENSE en la raíz del repositorio.                      }
{******************************************************************************}
unit EscPosBuilder;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Winapi.WinSpool;

const
  N_CHAR_LIN = 42; // Caracteres por línea en fuente A / papel 80 mm

type
  TFuenteTermica = (ftRasterA, ftRasterB, ftRasterC);
  TAlineacion = (alIzquierda, alCentro, alDerecha);

  TTicketTermico = class
  private
    FComandos: TStringBuilder;
    FNombreImpresora: string;
    function ObtenerComandoFuente(AFuente: TFuenteTermica): string;
    function ObtenerComandoAlineacion(AAlineacion: TAlineacion): string;
  public
    constructor Create(const ANombreImpresora: string = '');
    destructor Destroy; override;
    procedure Inicializar;
    procedure ConfigurarEspanol;
    function ObtenerComandos: string;
    procedure SeleccionarFuente(AFuente: TFuenteTermica);
    procedure Alinear(AAlineacion: TAlineacion);
    procedure Negrita(AActivar: Boolean);
    procedure Subrayado(AActivar: Boolean);
    procedure TamanoDoble(AAncho, AAlto: Boolean);
    procedure EscribirLinea(const ATexto: string);
    procedure EscribirTexto(const ATexto: string);
    procedure SaltarLineas(ACantidad: Integer);
    procedure LineaSeparadora(ACaracter: Char = '-');
    procedure ImprimirImagen(ABitmap: Vcl.Graphics.TBitmap;
                             AEscala: Integer = 3);
    procedure CortarPapel(AParcial: Boolean = False);
    procedure AbrirCajon;
    procedure TextoColumnas(const AIzq, ADer: string;
                            AAncho: Integer = N_CHAR_LIN);
    procedure Imprimir;
    procedure Limpiar;
    procedure ImprimirQRNativo(const ATexto: string;
                               ATamanoModulo: Integer = 8;
                               ANivelError: Integer = 48);
    property NombreImpresora: string read FNombreImpresora
                                     write FNombreImpresora;
  end;

  { Envía datos RAW (bytes ESC/POS) directamente al spooler de Windows.
    Codifica el texto a CP858 (soporta español) preservando los bytes
    binarios de los comandos QR. }
  procedure EnviarComandoRAW(const ANombreImpresora: string;
                             const ADatos: string);

implementation

uses
  Winapi.Windows;

const
  ESC = #27;
  GS = #29;
  // Página de códigos 858 - Soporta español
  CMD_CODEPAGE_858 = ESC + 't' + #19;
  CMD_INICIALIZAR = ESC + '@';
  CMD_FUENTE_A = ESC + 'M' + #0;
  CMD_FUENTE_B = ESC + 'M' + #1;
  CMD_FUENTE_C = ESC + 'M' + #2;
  CMD_NEGRITA_ON = ESC + 'E' + #1;
  CMD_NEGRITA_OFF = ESC + 'E' + #0;
  CMD_SUBRAYADO_ON = ESC + '-' + #1;
  CMD_SUBRAYADO_OFF = ESC + '-' + #0;
  CMD_IZQUIERDA = ESC + 'a' + #0;
  CMD_CENTRO = ESC + 'a' + #1;
  CMD_DERECHA = ESC + 'a' + #2;
  CMD_TAMANO_NORMAL = GS + '!' + #0;
  CMD_CORTE_TOTAL = ESC + 'i';
  CMD_CORTE_PARCIAL = ESC + 'm';
  CMD_ABRIR_CAJON = ESC + 'p' + #0 + #50 + #250;

constructor TTicketTermico.Create(const ANombreImpresora: string);
begin
  inherited Create;
  FNombreImpresora := ANombreImpresora;
  FComandos := TStringBuilder.Create;
end;

destructor TTicketTermico.Destroy;
begin
  FreeAndNil(FComandos);
  inherited;
end;

procedure TTicketTermico.Inicializar;
begin
  FComandos.Append(CMD_INICIALIZAR);
  ConfigurarEspanol;
end;

procedure TTicketTermico.ConfigurarEspanol;
begin
  FComandos.Append(CMD_CODEPAGE_858);
end;

function TTicketTermico.ObtenerComandos: string;
begin
  Result := FComandos.ToString;
end;

function TTicketTermico.ObtenerComandoFuente(AFuente: TFuenteTermica): string;
begin
  case AFuente of
    ftRasterA: Result := CMD_FUENTE_A;
    ftRasterB: Result := CMD_FUENTE_B;
    ftRasterC: Result := CMD_FUENTE_C;
  else
    Result := CMD_FUENTE_A;
  end;
end;

function TTicketTermico.ObtenerComandoAlineacion(
  AAlineacion: TAlineacion): string;
begin
  case AAlineacion of
    alIzquierda: Result := CMD_IZQUIERDA;
    alCentro: Result := CMD_CENTRO;
    alDerecha: Result := CMD_DERECHA;
  else
    Result := CMD_IZQUIERDA;
  end;
end;

procedure TTicketTermico.SeleccionarFuente(AFuente: TFuenteTermica);
begin
  FComandos.Append(ObtenerComandoFuente(AFuente));
end;

procedure TTicketTermico.Alinear(AAlineacion: TAlineacion);
begin
  FComandos.Append(ObtenerComandoAlineacion(AAlineacion));
end;

procedure TTicketTermico.Negrita(AActivar: Boolean);
begin
  if AActivar then
    FComandos.Append(CMD_NEGRITA_ON)
  else
    FComandos.Append(CMD_NEGRITA_OFF);
end;

procedure TTicketTermico.Subrayado(AActivar: Boolean);
begin
  if AActivar then
    FComandos.Append(CMD_SUBRAYADO_ON)
  else
    FComandos.Append(CMD_SUBRAYADO_OFF);
end;

procedure TTicketTermico.TamanoDoble(AAncho, AAlto: Boolean);
var
  Valor: Byte;
begin
  Valor := 0;
  if AAncho then
    Valor := Valor or $20;
  if AAlto then
    Valor := Valor or $10;
  FComandos.Append(GS + '!' + Chr(Valor));
end;

procedure TTicketTermico.EscribirLinea(const ATexto: string);
begin
  FComandos.Append(ATexto + #13#10);
end;

procedure TTicketTermico.EscribirTexto(const ATexto: string);
begin
  FComandos.Append(ATexto);
end;

procedure TTicketTermico.SaltarLineas(ACantidad: Integer);
begin
  FComandos.Append(ESC + 'd' + Chr(ACantidad));
end;

procedure TTicketTermico.LineaSeparadora(ACaracter: Char);
begin
  EscribirLinea(StringOfChar(ACaracter, N_CHAR_LIN));
end;

procedure TTicketTermico.TextoColumnas(const AIzq, ADer: string;
                                       AAncho: Integer = N_CHAR_LIN);
var
  Espacios: Integer;
begin
  Espacios := AAncho - Length(AIzq) - Length(ADer);
  if Espacios < 1 then
    Espacios := 1;
  EscribirLinea(AIzq + StringOfChar(' ', Espacios) + ADer);
end;

procedure TTicketTermico.ImprimirQRNativo(const ATexto: string;
                                          ATamanoModulo: Integer = 8;
                                          ANivelError: Integer = 48);
var
  pL, pH: Byte;
  DataLength: Integer;
begin
  DataLength := Length(ATexto) + 3;
  pL := DataLength mod 256;
  pH := DataLength div 256;
  Alinear(alCentro);
  FComandos.Append(#29#40#107#4#0#49#65#50#0);                        // Modelo
  FComandos.Append(#29#40#107#3#0#49#67 + Chr(ATamanoModulo));        // Tamaño
  FComandos.Append(#29#40#107#3#0#49#69 + Chr(ANivelError));          // Nivel
  FComandos.Append(#29#40#107 + Chr(pL) + Chr(pH) + #49#80#48 + ATexto);
  FComandos.Append(#29#40#107#3#0#49#81#48);                          // Imprimir
  FComandos.Append(#13#10);
  Alinear(alIzquierda);
end;

procedure TTicketTermico.ImprimirImagen(ABitmap: Vcl.Graphics.TBitmap;
                                        AEscala: Integer = 3);
var
  x, y: Integer;
  BitmapMono, BitmapEscalado: Vcl.Graphics.TBitmap;
  Color: TColor;
  BytesAncho: Integer;
  DatosImagen: TBytes;
  ByteIndex: Integer;
  xSrc, ySrc: Integer;
begin
  BitmapEscalado := Vcl.Graphics.TBitmap.Create;
  BitmapMono := Vcl.Graphics.TBitmap.Create;
  try
    // Escalar el bitmap original píxel a píxel para mantener nitidez
    BitmapEscalado.Width := ABitmap.Width * AEscala;
    BitmapEscalado.Height := ABitmap.Height * AEscala;
    for y := 0 to BitmapEscalado.Height - 1 do
    begin
      ySrc := y div AEscala;
      for x := 0 to BitmapEscalado.Width - 1 do
      begin
        xSrc := x div AEscala;
        BitmapEscalado.Canvas.Pixels[x, y] := ABitmap.Canvas.Pixels[xSrc, ySrc];
      end;
    end;
    // Convertir a monocromo
    BitmapMono.Monochrome := True;
    BitmapMono.Width := BitmapEscalado.Width;
    BitmapMono.Height := BitmapEscalado.Height;
    BitmapMono.Canvas.Draw(0, 0, BitmapEscalado);
    BytesAncho := (BitmapMono.Width + 7) div 8;
    SetLength(DatosImagen, BytesAncho * BitmapMono.Height);
    // Convertir imagen a bytes
    for y := 0 to BitmapMono.Height - 1 do
    begin
      for x := 0 to BitmapMono.Width - 1 do
      begin
        Color := BitmapMono.Canvas.Pixels[x, y];
        if (Color and $FFFFFF) < $808080 then
        begin
          ByteIndex := y * BytesAncho + (x div 8);
          DatosImagen[ByteIndex] := DatosImagen[ByteIndex]
             or (128 shr (x mod 8));
        end;
      end;
    end;
    Alinear(alCentro);
    FComandos.Append(GS + 'v0' + Chr(0) +
                     Chr(Lo(BytesAncho)) + Chr(Hi(BytesAncho)) +
                     Chr(Lo(BitmapMono.Height)) + Chr(Hi(BitmapMono.Height)));
    for ByteIndex := 0 to High(DatosImagen) do
      FComandos.Append(Chr(DatosImagen[ByteIndex]));
    FComandos.Append(#13#10);
  finally
    FreeAndNil(BitmapMono);
    FreeAndNil(BitmapEscalado);
  end;
  Alinear(alIzquierda);
end;

procedure TTicketTermico.CortarPapel(AParcial: Boolean);
begin
  if AParcial then
    FComandos.Append(CMD_CORTE_PARCIAL)
  else
    FComandos.Append(CMD_CORTE_TOTAL);
end;

procedure TTicketTermico.AbrirCajon;
begin
  FComandos.Append(CMD_ABRIR_CAJON);
end;

procedure TTicketTermico.Imprimir;
begin
  EnviarComandoRAW(FNombreImpresora, FComandos.ToString);
end;

procedure TTicketTermico.Limpiar;
begin
  FComandos.Clear;
end;

procedure EnviarComandoRAW(const ANombreImpresora: string;
                           const ADatos: string);
var
  hPrinter: THandle;
  DocInfo: TDocInfo1;
  BytesEscritos: DWORD;
  DatosRaw: TBytes;
  i: Integer;
  CP858: TEncoding;
begin
  if ANombreImpresora = '' then
    raise Exception.Create('Nombre de impresora vacío');
  if not OpenPrinter(PChar(ANombreImpresora), hPrinter, nil) then
    raise Exception.CreateFmt('No se pudo abrir la impresora: %s',
                              [ANombreImpresora]);
  try
    DocInfo.pDocName := 'Ticket ESC/POS';
    DocInfo.pOutputFile := nil;
    DocInfo.pDatatype := 'RAW';
    if (StartDocPrinter(hPrinter, 1, @DocInfo) = 0) then
      raise Exception.Create('Error al iniciar documento');
    try
      if StartPagePrinter(hPrinter) then
      begin
        try
          CP858 := TEncoding.GetEncoding(858);
          try
            // Convertir el string completo a CP858 primero
            DatosRaw := CP858.GetBytes(ADatos);
            // Corregir los bytes de comandos QR que CP858 pudo alterar:
            // buscar secuencias GS ( k y restaurar pL/pH del original
            i := 0;
            while (i < Length(DatosRaw) - 4) do
            begin
              if ((DatosRaw[i] = $1D) and
                 (DatosRaw[i+1] = $28) and
                 (DatosRaw[i+2] = $6B)) then
              begin
                if i+4 < Length(ADatos) then
                begin
                  DatosRaw[i+3] := Ord(ADatos[i+4]); // pL
                  DatosRaw[i+4] := Ord(ADatos[i+5]); // pH
                end;
                Inc(i, 5);
              end
              else
                Inc(i);
            end;
          finally
            FreeAndNil(CP858);
          end;
          if not WritePrinter(hPrinter,
                              @DatosRaw[0],
                              Length(DatosRaw),
                              BytesEscritos) then
            raise Exception.Create('Error al escribir en impresora');
        finally
          EndPagePrinter(hPrinter);
        end;
      end;
      EndDocPrinter(hPrinter);
    except
      on E: Exception do
      begin
        EndDocPrinter(hPrinter);
        raise;
      end;
    end;
  finally
    ClosePrinter(hPrinter);
  end;
end;

end.
