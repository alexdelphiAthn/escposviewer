{******************************************************************************}
{                                                                              }
{  Módulo:       FMainDemo                                                     }
{    Tipo:       Formulario (Demo)                                             }
{                                                                              }
{  Descripción:                                                                }
{    Ejemplo de uso de EscPosRenderer: genera un ticket ESC/POS de ejemplo     }
{    (con EscPosBuilder), lo convierte en imagen y permite guardarlo como PNG. }
{    También permite abrir un archivo con comandos ESC/POS crudos.             }
{                                                                              }
{  Licencia: MIT. Ver LICENSE en la raíz del repositorio.                      }
{******************************************************************************}
unit FMainDemo;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.ComCtrls, EscPosRenderer, EscPosBuilder, EscPosScript;

type
  TFormDemo = class(TForm)
    Panel1: TPanel;
    btnGenerar: TButton;
    btnAbrir: TButton;
    btnScript: TButton;
    btnPNG: TButton;
    pnlAyuda: TPanel;
    lblAyuda: TLabel;
    lvComandos: TListView;
    SplitterAyuda: TSplitter;
    pnlEditor: TPanel;
    MemoScript: TMemo;
    Splitter1: TSplitter;
    ScrollBox1: TScrollBox;
    Image1: TImage;
    SaveDialog1: TSaveDialog;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure btnGenerarClick(Sender: TObject);
    procedure btnAbrirClick(Sender: TObject);
    procedure btnScriptClick(Sender: TObject);
    procedure btnPNGClick(Sender: TObject);
    procedure lvComandosDblClick(Sender: TObject);
    procedure MemoScriptDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure MemoScriptDragDrop(Sender, Source: TObject; X, Y: Integer);
  private
    FRenderer: TEscPosRenderer;
    function GenerarTicketEjemplo: string;
    procedure MostrarComandos(const AComandos: string);
    procedure CargarScriptEjemplo;
    procedure CargarAyudaComandos;
    procedure InsertarPlantilla(ALinea: Integer);
  public
  end;

var
  FormDemo: TFormDemo;

implementation

{$R *.dfm}

uses
  System.IOUtils;

const
  // Comando, parámetros, descripción, plantilla que se inserta en el editor
  AYUDA_COMANDOS: array[0..13, 0..3] of string = (
    ('INICIALIZAR', '', 'Reinicia la impresora y activa español',
     'INICIALIZAR'),
    ('FUENTE', 'A / B / C', 'Fuente A(12x24) B(9x17) C(7x14)',
     'FUENTE A'),
    ('ALINEAR', 'IZQUIERDA / CENTRO / DERECHA', 'Alineación del texto',
     'ALINEAR CENTRO'),
    ('NEGRITA', 'ON / OFF', 'Activa o desactiva la negrita',
     'NEGRITA ON'),
    ('SUBRAYADO', 'ON / OFF', 'Activa o desactiva el subrayado',
     'SUBRAYADO ON'),
    ('INVERSO', 'ON / OFF', 'Texto blanco sobre fondo negro',
     'INVERSO ON'),
    ('TAMANO', 'ancho alto (1-8)', 'Multiplicadores de tamaño de letra',
     'TAMANO 2 2'),
    ('TEXTO', 'texto...', 'Escribe texto sin salto de línea',
     'TEXTO Hola'),
    ('LINEA', 'texto...', 'Escribe una línea (vacío = línea en blanco)',
     'LINEA Hola mundo'),
    ('COLUMNAS', 'izq | der [| ancho]', 'Texto a izquierda y derecha',
     'COLUMNAS Concepto | 1,00'),
    ('SEPARADOR', '[carácter]', 'Línea separadora (por defecto -)',
     'SEPARADOR'),
    ('SALTAR', 'n', 'Salta n líneas en blanco',
     'SALTAR 3'),
    ('QR', 'texto [| módulo [| L/M/Q/H]]', 'Imprime un código QR',
     'QR https://example.com | 8 | M'),
    ('CORTAR', '[PARCIAL]', 'Corta el papel',
     'CORTAR'));
  // CAJON se omite de la ayuda: no tiene efecto visual en el visor

procedure TFormDemo.FormCreate(Sender: TObject);
begin
  FRenderer := TEscPosRenderer.Create; // 576 px = papel de 80 mm
  CargarAyudaComandos;
  CargarScriptEjemplo;
  btnScriptClick(nil);
end;

procedure TFormDemo.CargarAyudaComandos;
var
  i: Integer;
  Item: TListItem;
begin
  lvComandos.Items.BeginUpdate;
  try
    lvComandos.Items.Clear;
    for i := Low(AYUDA_COMANDOS) to High(AYUDA_COMANDOS) do
    begin
      Item := lvComandos.Items.Add;
      Item.Caption := AYUDA_COMANDOS[i, 0];
      Item.SubItems.Add(AYUDA_COMANDOS[i, 1]);
      Item.SubItems.Add(AYUDA_COMANDOS[i, 2]);
    end;
  finally
    lvComandos.Items.EndUpdate;
  end;
end;

procedure TFormDemo.InsertarPlantilla(ALinea: Integer);
begin
  if lvComandos.ItemIndex >= 0 then
  begin
    if (ALinea < 0) or (ALinea > MemoScript.Lines.Count) then
      ALinea := MemoScript.Lines.Count;
    MemoScript.Lines.Insert(ALinea,
                            AYUDA_COMANDOS[lvComandos.ItemIndex, 3]);
    // Situar el cursor en la línea insertada
    MemoScript.CaretPos := TPoint.Create(0, ALinea);
    MemoScript.SetFocus;
  end;
end;

procedure TFormDemo.lvComandosDblClick(Sender: TObject);
begin
  // Doble clic: insertar después de la línea del cursor
  InsertarPlantilla(MemoScript.CaretPos.Y + 1);
end;

procedure TFormDemo.MemoScriptDragOver(Sender, Source: TObject;
  X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := Source = lvComandos;
end;

procedure TFormDemo.MemoScriptDragDrop(Sender, Source: TObject;
  X, Y: Integer);
var
  iRes: Integer;
  iLinea: Integer;
begin
  // Averiguar sobre qué línea se ha soltado
  iRes := MemoScript.Perform(EM_CHARFROMPOS, 0, MakeLParam(X, Y));
  if iRes = -1 then
    iLinea := MemoScript.Lines.Count
  else
    iLinea := HiWord(iRes);
  InsertarPlantilla(iLinea);
end;

procedure TFormDemo.CargarScriptEjemplo;
begin
  MemoScript.Lines.Clear;
  MemoScript.Lines.Add('; Pseudocodigo ESC/POS - un comando por linea');
  MemoScript.Lines.Add('; Pulse "Renderizar script" para ver el resultado');
  MemoScript.Lines.Add('INICIALIZAR');
  MemoScript.Lines.Add('ALINEAR CENTRO');
  MemoScript.Lines.Add('TAMANO 2 2');
  MemoScript.Lines.Add('NEGRITA ON');
  MemoScript.Lines.Add('LINEA MI TIENDA');
  MemoScript.Lines.Add('TAMANO 1 1');
  MemoScript.Lines.Add('NEGRITA OFF');
  MemoScript.Lines.Add('LINEA C/ Ejemplo 123 - Madrid');
  MemoScript.Lines.Add('ALINEAR IZQUIERDA');
  MemoScript.Lines.Add('SEPARADOR');
  MemoScript.Lines.Add('COLUMNAS 2 x Cafe con leche | 3,00');
  MemoScript.Lines.Add('COLUMNAS 1 x Tostada con tomate | 2,50');
  MemoScript.Lines.Add('SEPARADOR');
  MemoScript.Lines.Add('NEGRITA ON');
  MemoScript.Lines.Add('TAMANO 1 2');
  MemoScript.Lines.Add('COLUMNAS TOTAL | 5,50 EUR | 20');
  MemoScript.Lines.Add('TAMANO 1 1');
  MemoScript.Lines.Add('NEGRITA OFF');
  MemoScript.Lines.Add('SEPARADOR');
  MemoScript.Lines.Add('ALINEAR CENTRO');
  MemoScript.Lines.Add('QR https://example.com | 8 | M');
  MemoScript.Lines.Add('SUBRAYADO ON');
  MemoScript.Lines.Add('LINEA Gracias por su visita');
  MemoScript.Lines.Add('SUBRAYADO OFF');
  MemoScript.Lines.Add('SALTAR 3');
  MemoScript.Lines.Add('CORTAR');
end;

procedure TFormDemo.btnScriptClick(Sender: TObject);
var
  Script: TEscPosScript;
begin
  Script := TEscPosScript.Create;
  try
    MostrarComandos(Script.Compilar(MemoScript.Lines.Text));
    if Script.Errores.Count > 0 then
      ShowMessage('Errores en el script:' + sLineBreak +
                  Script.Errores.Text);
  finally
    FreeAndNil(Script);
  end;
end;

function TFormDemo.GenerarTicketEjemplo: string;
var
  Ticket: TTicketTermico;
begin
  Ticket := TTicketTermico.Create;
  try
    Ticket.Inicializar;
    // Cabecera
    Ticket.Alinear(alCentro);
    Ticket.TamanoDoble(True, True);
    Ticket.Negrita(True);
    Ticket.EscribirLinea('MI TIENDA');
    Ticket.TamanoDoble(False, False);
    Ticket.Negrita(False);
    Ticket.EscribirLinea('C/ Ejemplo 123 - Madrid');
    Ticket.EscribirLinea('NIF: 12345678Z');
    Ticket.Alinear(alIzquierda);
    Ticket.LineaSeparadora;
    // Líneas de venta
    Ticket.TextoColumnas('2 x Cafe con leche', '3,00');
    Ticket.TextoColumnas('1 x Tostada tomate', '2,50');
    Ticket.TextoColumnas('1 x Zumo naranja', '3,20');
    Ticket.LineaSeparadora;
    Ticket.Negrita(True);
    Ticket.TamanoDoble(False, True);
    // A doble alto la fuente es mayor: reducir el ancho de columnas
    Ticket.TextoColumnas('TOTAL', '8,70 EUR', 20);
    Ticket.TamanoDoble(False, False);
    Ticket.Negrita(False);
    Ticket.LineaSeparadora;
    // Pie con QR
    Ticket.ImprimirQRNativo('https://github.com/', 8);
    Ticket.Alinear(alCentro);
    Ticket.EscribirLinea('Gracias por su visita');
    Ticket.SaltarLineas(3);
    Ticket.CortarPapel;
    Result := Ticket.ObtenerComandos;
  finally
    FreeAndNil(Ticket);
  end;
end;

procedure TFormDemo.MostrarComandos(const AComandos: string);
begin
  FRenderer.Render(AComandos);
  Image1.Picture.Bitmap.Assign(FRenderer.Bitmap);
end;

procedure TFormDemo.btnGenerarClick(Sender: TObject);
begin
  MostrarComandos(GenerarTicketEjemplo);
end;

procedure TFormDemo.btnAbrirClick(Sender: TObject);
var
  Bytes: TBytes;
  Comandos: string;
  i: Integer;
begin
  OpenDialog1.Filter :=
    'Archivos ESC/POS (*.bin;*.escpos;*.prn;*.txt)|*.bin;*.escpos;*.prn;*.txt|' +
    'Todos los archivos (*.*)|*.*';
  if OpenDialog1.Execute then
  begin
    // Leer bytes crudos y convertirlos 1:1 a string (byte -> Char)
    Bytes := TFile.ReadAllBytes(OpenDialog1.FileName);
    SetLength(Comandos, Length(Bytes));
    for i := 0 to High(Bytes) do
      Comandos[i + 1] := Char(Bytes[i]);
    MostrarComandos(Comandos);
  end;
end;

procedure TFormDemo.btnPNGClick(Sender: TObject);
begin
  SaveDialog1.Filter := 'PNG|*.png';
  SaveDialog1.DefaultExt := 'png';
  SaveDialog1.FileName := 'Ticket_' +
    FormatDateTime('yyyy_mm_dd_hh_nn_ss', Now) + '.png';
  if SaveDialog1.Execute then
  begin
    FRenderer.GuardarPNG(SaveDialog1.FileName);
    ShowMessage('PNG guardado en: ' + SaveDialog1.FileName);
  end;
end;

end.
