object FormDemo: TFormDemo
  Left = 0
  Top = 0
  Caption = 'Visor ESC/POS - Demo'
  ClientHeight = 720
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnGenerar: TButton
      Left = 8
      Top = 8
      Width = 150
      Height = 25
      Caption = 'Ticket de ejemplo'
      TabOrder = 0
      OnClick = btnGenerarClick
    end
    object btnAbrir: TButton
      Left = 164
      Top = 8
      Width = 150
      Height = 25
      Caption = 'Abrir archivo ESC/POS...'
      TabOrder = 1
      OnClick = btnAbrirClick
    end
    object btnPNG: TButton
      Left = 320
      Top = 8
      Width = 150
      Height = 25
      Caption = 'Guardar PNG'
      TabOrder = 2
      OnClick = btnPNGClick
    end
  end
  object ScrollBox1: TScrollBox
    Left = 0
    Top = 41
    Width = 640
    Height = 679
    Align = alClient
    Color = clGray
    ParentColor = False
    TabOrder = 1
    object Image1: TImage
      Left = 16
      Top = 16
      Width = 576
      Height = 320
      AutoSize = True
    end
  end
  object SaveDialog1: TSaveDialog
    Left = 552
    Top = 64
  end
  object OpenDialog1: TOpenDialog
    Left = 552
    Top = 120
  end
end
