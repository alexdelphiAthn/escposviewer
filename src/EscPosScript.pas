{******************************************************************************}
{                                                                              }
{  Módulo:       EscPosScript                                                  }
{    Tipo:       Librería                                                      }
{ Versión:       1.0.0                                                         }
{                                                                              }
{  Descripción:                                                                }
{    Compilador de pseudocódigo a comandos ESC/POS. Permite describir un       }
{    ticket en texto plano (un comando por línea, en español) y obtener el     }
{    flujo de bytes ESC/POS listo para el visor o para una impresora real.     }
{                                                                              }
{  Lenguaje (un comando por línea, ';' inicia comentario):                     }
{    INICIALIZAR                                                               }
{    FUENTE A|B|C                                                              }
{    ALINEAR IZQUIERDA|CENTRO|DERECHA                                          }
{    NEGRITA ON|OFF          SUBRAYADO ON|OFF        INVERSO ON|OFF            }
{    TAMANO ancho alto       (multiplicadores 1-8)                             }
{    TEXTO texto...          (sin salto de línea)                              }
{    LINEA texto...          (con salto; sin argumento = línea en blanco)      }
{    COLUMNAS izquierda | derecha [| ancho]                                    }
{    SEPARADOR [carácter]                                                      }
{    SALTAR n                                                                  }
{    QR texto [| módulo 1-16 [| nivel L|M|Q|H]]                                }
{    CORTAR [PARCIAL]                                                          }
{    CAJON                                                                     }
{                                                                              }
{  Uso:                                                                        }
{    var Script := TEscPosScript.Create;                                       }
{    try                                                                       }
{      Comandos := Script.Compilar(Memo.Lines.Text);                           }
{      if Script.Errores.Count > 0 then                                        }
{        ShowMessage(Script.Errores.Text);                                     }
{    finally                                                                   }
{      Script.Free;                                                            }
{    end;                                                                      }
{                                                                              }
{  Licencia: MIT. Ver LICENSE en la raíz del repositorio.                      }
{******************************************************************************}
unit EscPosScript;

interface

uses
  System.SysUtils, System.Classes, EscPosBuilder;

type
  TEscPosScript = class
  private
    FErrores: TStringList;
    procedure AnotarError(ALinea: Integer; const AMensaje: string);
    function ParsearBooleano(const AValor: string; ALinea: Integer): Boolean;
    function ParsearEntero(const AValor: string; ADefecto: Integer): Integer;
    procedure EjecutarComando(ATicket: TTicketTermico; const AComando: string;
                              const AResto: string; ALinea: Integer);
    procedure ComandoAlinear(ATicket: TTicketTermico; const AResto: string;
                             ALinea: Integer);
    procedure ComandoFuente(ATicket: TTicketTermico; const AResto: string;
                            ALinea: Integer);
    procedure ComandoTamano(ATicket: TTicketTermico; const AResto: string;
                            ALinea: Integer);
    procedure ComandoColumnas(ATicket: TTicketTermico; const AResto: string;
                              ALinea: Integer);
    procedure ComandoQR(ATicket: TTicketTermico; const AResto: string;
                        ALinea: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    { Compila el pseudocódigo y devuelve los bytes ESC/POS como string.
      Los errores (con número de línea) quedan en Errores; las líneas
      erróneas se ignoran y la compilación continúa. }
    function Compilar(const AScript: string): string;
    property Errores: TStringList read FErrores;
  end;

implementation

constructor TEscPosScript.Create;
begin
  inherited Create;
  FErrores := TStringList.Create;
end;

destructor TEscPosScript.Destroy;
begin
  FreeAndNil(FErrores);
  inherited;
end;

procedure TEscPosScript.AnotarError(ALinea: Integer; const AMensaje: string);
begin
  FErrores.Add(Format('Línea %d: %s', [ALinea, AMensaje]));
end;

function TEscPosScript.ParsearBooleano(const AValor: string;
                                       ALinea: Integer): Boolean;
var
  sValor: string;
begin
  sValor := UpperCase(Trim(AValor));
  if (sValor = 'ON') or (sValor = 'SI') or (sValor = '1') then
    Result := True
  else if (sValor = 'OFF') or (sValor = 'NO') or (sValor = '0') or
          (sValor = '') then
    Result := False
  else
  begin
    AnotarError(ALinea, 'Valor no reconocido "' + AValor +
                        '" (use ON/OFF)');
    Result := False;
  end;
end;

function TEscPosScript.ParsearEntero(const AValor: string;
                                     ADefecto: Integer): Integer;
begin
  Result := StrToIntDef(Trim(AValor), ADefecto);
end;

procedure TEscPosScript.ComandoAlinear(ATicket: TTicketTermico;
                                       const AResto: string; ALinea: Integer);
var
  sValor: string;
begin
  sValor := UpperCase(Trim(AResto));
  if (sValor = 'IZQUIERDA') or (sValor = 'IZQ') then
    ATicket.Alinear(alIzquierda)
  else if sValor = 'CENTRO' then
    ATicket.Alinear(alCentro)
  else if (sValor = 'DERECHA') or (sValor = 'DER') then
    ATicket.Alinear(alDerecha)
  else
    AnotarError(ALinea, 'Alineación no reconocida "' + AResto +
                        '" (use IZQUIERDA/CENTRO/DERECHA)');
end;

procedure TEscPosScript.ComandoFuente(ATicket: TTicketTermico;
                                      const AResto: string; ALinea: Integer);
var
  sValor: string;
begin
  sValor := UpperCase(Trim(AResto));
  if sValor = 'A' then
    ATicket.SeleccionarFuente(ftRasterA)
  else if sValor = 'B' then
    ATicket.SeleccionarFuente(ftRasterB)
  else if sValor = 'C' then
    ATicket.SeleccionarFuente(ftRasterC)
  else
    AnotarError(ALinea, 'Fuente no reconocida "' + AResto +
                        '" (use A/B/C)');
end;

procedure TEscPosScript.ComandoTamano(ATicket: TTicketTermico;
                                      const AResto: string; ALinea: Integer);
var
  Partes: TArray<string>;
begin
  Partes := Trim(AResto).Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(Partes) = 2 then
    ATicket.Tamano(ParsearEntero(Partes[0], 1), ParsearEntero(Partes[1], 1))
  else
    AnotarError(ALinea, 'TAMANO requiere dos números: ancho alto (1-8)');
end;

procedure TEscPosScript.ComandoColumnas(ATicket: TTicketTermico;
                                        const AResto: string; ALinea: Integer);
var
  Partes: TArray<string>;
begin
  Partes := AResto.Split(['|']);
  if Length(Partes) >= 3 then
    ATicket.TextoColumnas(Trim(Partes[0]), Trim(Partes[1]),
                          ParsearEntero(Partes[2], N_CHAR_LIN))
  else if Length(Partes) = 2 then
    ATicket.TextoColumnas(Trim(Partes[0]), Trim(Partes[1]))
  else
    AnotarError(ALinea,
                'COLUMNAS requiere: izquierda | derecha [| ancho]');
end;

procedure TEscPosScript.ComandoQR(ATicket: TTicketTermico;
                                  const AResto: string; ALinea: Integer);
var
  Partes: TArray<string>;
  iModulo: Integer;
  iNivel: Integer;
  sNivel: string;
begin
  Partes := AResto.Split(['|']);
  if (Length(Partes) = 0) or (Trim(Partes[0]) = '') then
    AnotarError(ALinea, 'QR requiere un texto')
  else
  begin
    iModulo := 8;
    iNivel := 48; // L
    if Length(Partes) >= 2 then
      iModulo := ParsearEntero(Partes[1], 8);
    if Length(Partes) >= 3 then
    begin
      sNivel := UpperCase(Trim(Partes[2]));
      if sNivel = 'L' then
        iNivel := 48
      else if sNivel = 'M' then
        iNivel := 49
      else if sNivel = 'Q' then
        iNivel := 50
      else if sNivel = 'H' then
        iNivel := 51
      else
        AnotarError(ALinea, 'Nivel QR no reconocido "' + Partes[2] +
                            '" (use L/M/Q/H)');
    end;
    ATicket.ImprimirQRNativo(Trim(Partes[0]), iModulo, iNivel);
  end;
end;

procedure TEscPosScript.EjecutarComando(ATicket: TTicketTermico;
                                        const AComando: string;
                                        const AResto: string; ALinea: Integer);
begin
  if AComando = 'INICIALIZAR' then
    ATicket.Inicializar
  else if AComando = 'FUENTE' then
    ComandoFuente(ATicket, AResto, ALinea)
  else if AComando = 'ALINEAR' then
    ComandoAlinear(ATicket, AResto, ALinea)
  else if AComando = 'NEGRITA' then
    ATicket.Negrita(ParsearBooleano(AResto, ALinea))
  else if AComando = 'SUBRAYADO' then
    ATicket.Subrayado(ParsearBooleano(AResto, ALinea))
  else if AComando = 'INVERSO' then
    ATicket.Inverso(ParsearBooleano(AResto, ALinea))
  else if (AComando = 'TAMANO') or (AComando = 'TAMAÑO') then
    ComandoTamano(ATicket, AResto, ALinea)
  else if AComando = 'TEXTO' then
    ATicket.EscribirTexto(AResto)
  else if AComando = 'LINEA' then
    ATicket.EscribirLinea(AResto)
  else if AComando = 'COLUMNAS' then
    ComandoColumnas(ATicket, AResto, ALinea)
  else if AComando = 'SEPARADOR' then
  begin
    if Trim(AResto) <> '' then
      ATicket.LineaSeparadora(Trim(AResto)[1])
    else
      ATicket.LineaSeparadora;
  end
  else if AComando = 'SALTAR' then
    ATicket.SaltarLineas(ParsearEntero(AResto, 1))
  else if AComando = 'QR' then
    ComandoQR(ATicket, AResto, ALinea)
  else if AComando = 'CORTAR' then
    ATicket.CortarPapel(UpperCase(Trim(AResto)) = 'PARCIAL')
  else if AComando = 'CAJON' then
    ATicket.AbrirCajon
  else
    AnotarError(ALinea, 'Comando no reconocido "' + AComando + '"');
end;

function TEscPosScript.Compilar(const AScript: string): string;
var
  Lineas: TStringList;
  Ticket: TTicketTermico;
  i: Integer;
  p: Integer;
  sLinea: string;
  sComando: string;
  sResto: string;
begin
  FErrores.Clear;
  Lineas := TStringList.Create;
  Ticket := TTicketTermico.Create;
  try
    Lineas.Text := AScript;
    for i := 0 to Lineas.Count - 1 do
    begin
      sLinea := Trim(Lineas[i]);
      // Líneas vacías y comentarios se ignoran
      if (sLinea <> '') and (not sLinea.StartsWith(';')) then
      begin
        p := Pos(' ', sLinea);
        if p > 0 then
        begin
          sComando := UpperCase(Copy(sLinea, 1, p - 1));
          sResto := Trim(Copy(sLinea, p + 1, MaxInt));
        end
        else
        begin
          sComando := UpperCase(sLinea);
          sResto := '';
        end;
        EjecutarComando(Ticket, sComando, sResto, i + 1);
      end;
    end;
    Result := Ticket.ObtenerComandos;
  finally
    FreeAndNil(Ticket);
    FreeAndNil(Lineas);
  end;
end;

end.
