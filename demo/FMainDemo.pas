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
  Vcl.StdCtrls, EscPosRenderer, EscPosBuilder;

type
  TFormDemo = class(TForm)
    Panel1: TPanel;
    btnGenerar: TButton;
    btnAbrir: TButton;
    btnPNG: TButton;
    ScrollBox1: TScrollBox;
    Image1: TImage;
    SaveDialog1: TSaveDialog;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure btnGenerarClick(Sender: TObject);
    procedure btnAbrirClick(Sender: TObject);
    procedure btnPNGClick(Sender: TObject);
  private
    FRenderer: TEscPosRenderer;
    function GenerarTicketEjemplo: string;
    procedure MostrarComandos(const AComandos: string);
  public
  end;

var
  FormDemo: TFormDemo;

implementation

{$R *.dfm}

uses
  System.IOUtils;

procedure TFormDemo.FormCreate(Sender: TObject);
begin
  FRenderer := TEscPosRenderer.Create; // 576 px = papel de 80 mm
  btnGenerarClick(nil);
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
    Ticket.TextoColumnas('TOTAL', '8,70 EUR');
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
