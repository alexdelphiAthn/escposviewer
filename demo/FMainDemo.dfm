object FormDemo: TFormDemo
  Left = 0
  Top = 0
  Caption = 'Visor ESC/POS - Demo'
  ClientHeight = 720
  ClientWidth = 1300
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
    Width = 1300
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnGenerar: TButton
      Left = 8
      Top = 8
      Width = 140
      Height = 25
      Caption = 'Ticket de ejemplo'
      TabOrder = 0
      OnClick = btnGenerarClick
    end
    object btnAbrir: TButton
      Left = 154
      Top = 8
      Width = 160
      Height = 25
      Caption = 'Abrir archivo ESC/POS...'
      TabOrder = 1
      OnClick = btnAbrirClick
    end
    object btnScript: TButton
      Left = 320
      Top = 8
      Width = 140
      Height = 25
      Caption = 'Renderizar script'
      Default = True
      TabOrder = 2
      OnClick = btnScriptClick
    end
    object btnPNG: TButton
      Left = 466
      Top = 8
      Width = 140
      Height = 25
      Caption = 'Guardar PNG'
      TabOrder = 3
      OnClick = btnPNGClick
    end
  end
  object pnlAyuda: TPanel
    Left = 0
    Top = 41
    Width = 360
    Height = 679
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object lblAyuda: TLabel
      Left = 0
      Top = 0
      Width = 360
      Height = 20
      Align = alTop
      Alignment = taCenter
      AutoSize = False
      Caption = 'Arrastre un comando al editor (o doble clic)'
      Layout = tlCenter
    end
    object lvComandos: TListView
      Left = 0
      Top = 20
      Width = 360
      Height = 659
      Align = alClient
      Columns = <
        item
          Caption = 'Comando'
          Width = 85
        end
        item
          Caption = 'Parametros'
          Width = 115
        end
        item
          Caption = 'Para que sirve'
          Width = 140
        end>
      DragMode = dmAutomatic
      GridLines = True
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvComandosDblClick
    end
  end
  object SplitterAyuda: TSplitter
    Left = 360
    Top = 41
    Width = 5
    Height = 679
    ResizeStyle = rsUpdate
  end
  object pnlEditor: TPanel
    Left = 365
    Top = 41
    Width = 360
    Height = 679
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 2
    object MemoScript: TMemo
      Left = 0
      Top = 0
      Width = 360
      Height = 679
      Align = alClient
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
      OnDragDrop = MemoScriptDragDrop
      OnDragOver = MemoScriptDragOver
    end
  end
  object Splitter1: TSplitter
    Left = 725
    Top = 41
    Width = 5
    Height = 679
    ResizeStyle = rsUpdate
  end
  object ScrollBox1: TScrollBox
    Left = 730
    Top = 41
    Width = 570
    Height = 679
    Align = alClient
    Color = clGray
    ParentColor = False
    TabOrder = 3
    object Image1: TImage
      Left = 16
      Top = 16
      Width = 576
      Height = 320
      AutoSize = True
    end
  end
  object SaveDialog1: TSaveDialog
    Left = 1224
    Top = 64
  end
  object OpenDialog1: TOpenDialog
    Left = 1224
    Top = 120
  end
end
