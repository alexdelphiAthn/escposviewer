program VisorEscPosDemo;

uses
  Vcl.Forms,
  FMainDemo in 'FMainDemo.pas' {FormDemo},
  EscPosRenderer in '..\src\EscPosRenderer.pas',
  EscPosBuilder in '..\src\EscPosBuilder.pas',
  EscPosScript in '..\src\EscPosScript.pas',
  DelphiZXingQRCode in '..\lib\DelphiZXingQRCode.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Visor ESC/POS - Demo';
  Application.CreateForm(TFormDemo, FormDemo);
  Application.Run;
end.
