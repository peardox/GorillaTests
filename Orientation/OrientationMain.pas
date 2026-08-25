unit OrientationMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Types3D,
  System.Math.Vectors, Gorilla.Control, Gorilla.Transform, Gorilla.Mesh,
  Gorilla.Model, FMX.Controls3D, Gorilla.Light, PolarViewport, FMX.Layouts,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects3D,
  FMX.TabControl, PolarCamera, FMX.Menus, FMX.Memo.Types, FMX.ScrollBox,
  FMX.Memo;

type

  TForm1 = class(TForm)
    MainMenu1: TMainMenu;
    OptionsMenu: TMenuItem;
    ModelTypeMenu: TMenuItem;
    DisplayMenu: TMenuItem;
    ModelTypeGLBMenu: TMenuItem;
    ModelTypeFBXMenu: TMenuItem;
    ModelTypeDAEMenu: TMenuItem;
    ModelTypeGLTFMenu: TMenuItem;
    ModelTypeOBJMenu: TMenuItem;
    ModelTypePLYMenu: TMenuItem;
    ModelTypeSTLMenu: TMenuItem;
    ModelTypeUSDCMenu: TMenuItem;
    TabControl1: TTabControl;
    GorillaTab: TTabItem;
    GorillaLayout: TLayout;
    ViewportLayout: TLayout;
    RadioGroupLayout: TLayout;
    DialsLayout: TLayout;
    AzimuthDial: TArcDial;
    InclinationBar: TTrackBar;
    RollDial: TArcDial;
    AzimuthLabel: TLabel;
    InclinationLabel: TLabel;
    RollLabel: TLabel;
    AzimuthText: TLabel;
    RollText: TLabel;
    InclinationText: TLabel;
    DebugTab: TTabItem;
    DebugLayout: TLayout;
    DebugMemo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ModelTypeDAEMenuClick(Sender: TObject);
    procedure ModelTypeFBXMenuClick(Sender: TObject);
    procedure ModelTypeGLBMenuClick(Sender: TObject);
    procedure ModelTypeGLTFMenuClick(Sender: TObject);
    procedure ModelTypeOBJMenuClick(Sender: TObject);
    procedure ModelTypePLYMenuClick(Sender: TObject);
    procedure ModelTypeSTLMenuClick(Sender: TObject);
    procedure ModelTypeUSDCMenuClick(Sender: TObject);
    procedure AzimuthDialChange(Sender: TObject);
    procedure RollDialChange(Sender: TObject);
    procedure InclinationBarChange(Sender: TObject);
    procedure DisplayMenuClick(Sender: TObject);
  private
    { Private declarations }
    FGroupBoxes: array of TGroupBox;
    FRadioButtons: array of TRadioButton;
    FAzimuth: Double;
    FInclination: Double;
    FRoll: Double;
    GorillaViewport: TPolarViewport;
    GorillaLight: TGorillaLight;
    GorillaModel: TGorillaModel;
    GorillaCamera: TPolarCamera;
    ModelDir: String;
    ModelPath: String;
    FLookAt: TPoint3D;
    FModelRotation: TPoint3D;
    FCameraUp: TPoint3D;
    procedure DoRadioChange(Sender: TObject);
    procedure SwitchModel(const AModel: String = '');
    procedure CreateUIBoxes;
    function GetModelRotation: TPoint3D;
    function GetLookAt: TPoint3D;
    function GetCameraUp: TPoint3D;
    procedure SetModelRotation(const V: TPoint3D);
    procedure SetLookAt(const V: TPoint3D);
    procedure SetCameraUp(const V: TPoint3D);
    procedure ChangeCameraUp(const which: Integer);
    procedure ChangeModelRotation(const which: Integer);
    procedure ChangeLookAt(const which: Integer);
    procedure DoCameraUp;
    procedure DoLookAt;
    procedure DoModelRotation;
    procedure DumpDisplayInfo;
  public
    { Public declarations }
    property LookAt: TPoint3D read GetLookAt write SetLookAt;
    property ModelRotation: TPoint3D read GetModelRotation write SetModelRotation;
    property CameraUp: TPoint3D read GetCameraUp write SetCameraUp;
  end;

var
  Form1: TForm1;

const
  // The type of model to load on startup
  // Valid options are dae, fbx, glb, gltf, obj, ply, stl and usdc
  DefaultLoadType: String = 'glb';

implementation

uses
  DisplayData,
  Gorilla.DefTypes, System.Math,
  Gorilla.GLB.Loader,
  Gorilla.GLTF.Loader,
  Gorilla.OBJ.Loader,
  Gorilla.USD.Loader,
  Gorilla.FBX.Loader,
  Gorilla.DAE.Loader,
  Gorilla.STL.Loader,
  Gorilla.PLY.Loader
  ;

{$R *.fmx}

// Compare 2 TPoint3D recs with Epsilon for Floating Poin
function Point3DDiffers(const A, B: TPoint3D; Epsilon: Single = 1E-6): Boolean;
begin
  Result := (Abs(A.X - B.X) > Epsilon) or
            (Abs(A.Y - B.Y) > Epsilon) or
            (Abs(A.Z - B.Z) > Epsilon);
end;

// Triggered by a RadioButton in the Model Rotation group
// Setting the value has the side-effect of
// chahging the Model's Orientation property
procedure TForm1.ChangeModelRotation(const which: Integer);
var
  old: TPoint3D;
begin
  old := FModelRotation;
  case which of
    0: ModelRotation := Point3D(  0, old.Y, old.Z);
    1: ModelRotation := Point3D( 90, old.Y, old.Z);
    2: ModelRotation := Point3D(180, old.Y, old.Z);
    3: ModelRotation := Point3D(270, old.Y, old.Z);
    4: ModelRotation := Point3D(old.X,  0, old.Z);
    5: ModelRotation := Point3D(old.X, 90, old.Z);
    6: ModelRotation := Point3D(old.X,180, old.Z);
    7: ModelRotation := Point3D(old.X,270, old.Z);
    8: ModelRotation := Point3D(old.X, old.Y,  0);
    9: ModelRotation := Point3D(old.X, old.Y, 90);
    10: ModelRotation := Point3D(old.X, old.Y,180);
    11: ModelRotation := Point3D(old.X, old.Y,270);
  end;
end;

// Update FAzimuth and display Text
procedure TForm1.AzimuthDialChange(Sender: TObject);
begin
  FAzimuth := -AzimuthDial.Value;
  if FAzimuth < 0 then
      FAzimuth := FAzimuth + 360;

  AzimuthText.Text := Format('%3.0f',[FAzimuth]);
end;

// Triggered by a RadioButton in the CameraUp group
// Setting the value has the side-effect of
// chahging the Camera's WorldUp property
procedure TForm1.ChangeCameraUp(const which: Integer);
begin
  case which of
    12: CameraUp := Point3D( 1, 0, 0);
    13: CameraUp := Point3D( 0, 1, 0);
    14: CameraUp := Point3D( 0 , 0, 1);
    15: CameraUp := Point3D(-1, 0, 0);
    16: CameraUp := Point3D( 0,-1, 0);
    17: CameraUp := Point3D( 0 , 0,-1);
  end;
end;

// Triggered by a RadioButton in the LookAt group
// Setting the value has the side-effect of
// chahging the Camera's LookAt property
procedure TForm1.ChangeLookAt(const which: Integer);
begin
  case which of
    18: LookAt := Point3D( 50,  0,  0);
    19: LookAt := Point3D(  0, 50,  0);
    20: LookAt := Point3D(  0,  0, 50);
    21: LookAt := Point3D(-50,  0,  0);
    22: LookAt := Point3D(  0,-50,  0);
    23: LookAt := Point3D(  0,  0,-50);
  end;
end;

// Wrote this lot owing to frustration with Delphi crashing after I'd
// used the IDE to lay it out and it hung on me near the end.
procedure TForm1.CreateUIBoxes;
var
  HeadLabel: TLabel;
  Panel: TPanel;
  GroupBox: TGroupBox;
  RadioButton: TRadioButton;
  I, P, Index: Integer;
const
  PanelYOffset: Integer = 102;
  Cap: Array[0..2] of String = ('X', 'Y', 'Z');
  Ups: Array[0..5] of String = ('Up is +X', 'Up is +Y', 'Up is +Z','Up is -X', 'Up is -Y', 'Up is -Z');
  Looks: Array[0..5] of String = ('Look Along +X', 'Look Along +Y', 'Look Along +Z','Look Along -X', 'Look Along -Y', 'Look Along -Z');
begin
  SetLength(FGroupBoxes, 5);
  SetLength(FRadioButtons, (3 * 4) + 6 + 6);

  HeadLabel := TLabel.Create(RadioGroupLayout);
  HeadLabel.Parent := RadioGroupLayout;
  HeadLabel.Position.X := 8;
  HeadLabel.Position.Y := 0;
  HeadLabel.Width := 160;
  HeadLabel.Text := 'Model Rotation';
  HeadLabel.TextSettings.HorzAlign := TTextAlign.Center;

  for P := 0 to 2 do
    begin
      Panel := TPanel.Create(RadioGroupLayout);
      Panel.Parent := RadioGroupLayout;
      Panel.Position.X := 4;
      Panel.Position.Y := 24 + (P * PanelYOffset);
      Panel.Width := 150;
      Panel.Height := 90;
      GroupBox := TGroupBox.Create(Panel);
      GroupBox.Parent := Panel;
      GroupBox.Text := 'Rotation in ' + Cap[P];
      GroupBox.Position.X := 8;
      GroupBox.Position.Y := 0;
      GroupBox.Width := Panel.Width - 4;
      GroupBox.Height := Panel.Height - 4;
      for I := 0 to 3 do
        begin
          RadioButton := TRadioButton.Create(GroupBox);
          RadioButton.Parent := GroupBox;
          RadioButton.Text := IntToStr(I * 90) + ' Degrees';
          RadioButton.Position.X := 8;
          RadioButton.Position.Y := 16 + (I * 16);
          RadioButton.GroupName := 'RotationGroup' + IntToStr(P);
          Index := I + (P * 4);
          RadioButton.Tag := Index;
          FRadioButtons[Index] := RadioButton;
          FRadioButtons[Index].OnChange := DoRadioChange;
          if((I = 1) and (P = 0)) then // Set RotX Default
            FRadioButtons[Index].IsChecked := True
          else if((I = 0) and (P = 1)) then // Set RotY Default
            FRadioButtons[Index].IsChecked := True
          else if((I = 0) and (P = 2)) then // Set RotZ Default
            FRadioButtons[Index].IsChecked := True;
        end;
        FGroupBoxes[P] := GroupBox;
    end;

  HeadLabel := TLabel.Create(RadioGroupLayout);
  HeadLabel.Parent := RadioGroupLayout;
  HeadLabel.Position.X := 8;
  HeadLabel.Position.Y := 16 + (3*PanelYOffset);
  HeadLabel.Width := 160;
  HeadLabel.Text := 'World Up';
  HeadLabel.TextSettings.HorzAlign := TTextAlign.Center;

  Panel := TPanel.Create(RadioGroupLayout);
  Panel.Parent := RadioGroupLayout;
  Panel.Position.X := 4;
  Panel.Position.Y := 16 + 8 + 16 + (3*PanelYOffset);
  Panel.Width := 150;
  Panel.Height := 130;
  GroupBox := TGroupBox.Create(Panel);
  GroupBox.Parent := Panel;
  GroupBox.Text := 'Camera Up';
  GroupBox.Position.X := 8;
  GroupBox.Position.Y := 8;
  GroupBox.Width := Panel.Width - 4;
  GroupBox.Height := Panel.Height - 4;
  for I := 0 to 5 do
    begin
      RadioButton := TRadioButton.Create(GroupBox);
      RadioButton.Parent := GroupBox;
      RadioButton.Text := Ups[I];
      RadioButton.Position.X := 8;
      RadioButton.Position.Y := 16 + (I * 16);
      RadioButton.GroupName := 'UpGroup';
      Index := I + 12;
      RadioButton.Tag := Index;
      FRadioButtons[Index] := RadioButton;
      FRadioButtons[Index].OnChange := DoRadioChange;
      if(I = 1) then // Set UpY+ Default
        FRadioButtons[Index].IsChecked := True;
    end;
  FGroupBoxes[3] := GroupBox;

  HeadLabel := TLabel.Create(RadioGroupLayout);
  HeadLabel.Parent := RadioGroupLayout;
  HeadLabel.Position.X := 8;
  HeadLabel.Position.Y := 16 + 160 + (3*PanelYOffset);
  HeadLabel.Width := 160;
  HeadLabel.Text := 'Look At';
  HeadLabel.TextSettings.HorzAlign := TTextAlign.Center;

  Panel := TPanel.Create(RadioGroupLayout);
  Panel.Parent := RadioGroupLayout;
  Panel.Position.X := 4;
  Panel.Position.Y := 16 + 8 + 160 + 16 + (3*PanelYOffset);
  Panel.Width := 150;
  Panel.Height := 130;
  GroupBox := TGroupBox.Create(Panel);
  GroupBox.Parent := Panel;
  GroupBox.Text := 'Look At';
  GroupBox.Position.X := 8;
  GroupBox.Position.Y := 8;
  GroupBox.Width := Panel.Width - 4;
  GroupBox.Height := Panel.Height - 4;
  for I := 0 to 5 do
    begin
      RadioButton := TRadioButton.Create(GroupBox);
      RadioButton.Parent := GroupBox;
      RadioButton.Text := Looks[I];
      RadioButton.Position.X := 8;
      RadioButton.Position.Y := 16 + (I * 16);
      RadioButton.GroupName := 'LookGroup';
      Index := I + 18;
      RadioButton.Tag := Index;
      FRadioButtons[Index] := RadioButton;
      FRadioButtons[Index].OnChange := DoRadioChange;
      if(I = 0) then // Set Look Default
        FRadioButtons[Index].IsChecked := True;
    end;
  FGroupBoxes[4] := GroupBox;


end;

// Call DumpDisplayInfo to show Display Information on Debug Tab
procedure TForm1.DisplayMenuClick(Sender: TObject);
begin
    DumpDisplayInfo;
end;

// Action a CameraUp property change
procedure TForm1.DoCameraUp;
begin
  if Assigned(GorillaCamera) then
    GorillaCamera.WorldUp := FCameraUp;
end;

// Action a LookAt property change
procedure TForm1.DoLookAt;
begin
  if Assigned(GorillaCamera) then
    begin
      GorillaCamera.ResetRotationAngle;
      GorillaCamera.PointCameraAt(Point3D(0, 0, 0), FLookAt);
    end;
end;

// Action a ModelRotation property change
procedure TForm1.DoModelRotation;
begin
  if Assigned(GorillaModel) then
    begin
      GorillaModel.ResetRotationAngle;
      GorillaModel.RotationAngle.X := FModelRotation.X;
      GorillaModel.RotationAngle.Y := FModelRotation.Y;
      GorillaModel.RotationAngle.Z := FModelRotation.Z;
    end;
end;

// All RadioButtons use this as their onChange event.
// The RadioButtons have their Tag proerty set to
// incrementing values from 0 to 23
// This Tag is then passed on to the Change procedure
// for the various groups
procedure TForm1.DoRadioChange(Sender: TObject);
var
  which: Integer;
begin
  if Sender is TRadioButton then
    begin
      which := TRadioButton(Sender).Tag;

      if((which >= 0) and (which <= 11)) then
        ChangeModelRotation(which)
      else if((which >= 12) and (which <= 17)) then
        ChangeCameraUp(which)
      else if((which >= 18) and (which <= 23)) then
        ChangeLookAt(which);
    end;
end;

// On startup load a default Model as specified by DefaultLoadType
// The directory layout of models/Orientation follows this pattern
// to allow easy addition of new Model types
procedure TForm1.FormShow(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/' + DefaultLoadType + '/Orientation.' + DefaultLoadType);
end;

// Getter for CameraUp
function TForm1.GetCameraUp: TPoint3D;
begin
  Result := FCameraUp;
end;

// Getter for ModelRotation
function TForm1.GetModelRotation: TPoint3D;
begin
  Result := FModelRotation;
end;

// Update FInclanation and display Text
procedure TForm1.InclinationBarChange(Sender: TObject);
begin
  FInclination := -(InclinationBar.Value - 90);

  InclinationText.Text := Format('%2.0f',[FInclination]);
end;

// Getter for LookAt
function TForm1.GetLookAt: TPoint3D;
begin
  Result := FLookAt;
end;

// Menu Handlers * 8
// Very boring, just switch to model of the correct Model type
procedure TForm1.ModelTypeDAEMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/dae/Orientation.dae');
end;

procedure TForm1.ModelTypeFBXMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/fbx/Orientation.fbx');
end;

procedure TForm1.ModelTypeGLBMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/glb/Orientation.glb');
end;

procedure TForm1.ModelTypeGLTFMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/gltf/Orientation.gltf');
end;

procedure TForm1.ModelTypeOBJMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/obj/Orientation.obj');
end;

procedure TForm1.ModelTypePLYMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/ply/Orientation.ply');
end;

procedure TForm1.ModelTypeSTLMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/stl/Orientation.stl');
end;

procedure TForm1.ModelTypeUSDCMenuClick(Sender: TObject);
begin
  SwitchModel(ModelDir + 'models/Orientation/usdc/Orientation.usdc');
end;

// Update FRoll and display Text
procedure TForm1.RollDialChange(Sender: TObject);
begin
  FRoll := -RollDial.Value;
  if FRoll < 0 then
      FRoll := FRoll + 360;

  RollText.Text := Format('%3.0f',[FRoll]);
end;

// Setter for CameraUp also actions it
procedure TForm1.SetCameraUp(const V: TPoint3D);
begin
  if Point3DDiffers(FCameraUp, V) then
    begin
      FCameraUp := V;
      DoCameraUp;
    end;
end;

// Setter for ModelRotation also actions it
procedure TForm1.SetModelRotation(const V: TPoint3D);
begin
  if Point3DDiffers(FModelRotation, V) then
    begin
      FModelRotation := V;
      DoModelRotation;
    end;
end;

// Setter for LookAt also actions it
procedure TForm1.SetLookAt(const V: TPoint3D);
begin
  if Point3DDiffers(FLookAt, V) then
    begin
      FLookAt := V;
      DoLookAt;
    end;
end;

// Load a Model Clearing any old model first (so it Switches them)
// GorillaModel will be Nil on first call but set on subsequent calls
procedure TForm1.SwitchModel(const AModel: String);
var
  BBox: TBoundingBox;
begin
  if (AModel = String.Empty) or (not FileExists(AModel)) then
    begin
      ShowMessage('Model Not Found ' + AModel);
      Exit;
    end;

// Use this before typing Clear
//  if GorillaModel <> Nil then
//    FreeAndNil(GorillaModel);

  if GorillaModel = Nil then
    begin
      GorillaModel := TGorillaModel.Create(GorillaViewport);
      GorillaModel.Parent := GorillaViewport;
    end;

  GorillaModel.Clear;

  try
    GorillaModel.LoadFromFile(nil, AModel, []);
    BBox := GorillaModel.GetBoundingBox();

    GorillaModel.Position.Point := Point3D(BBox.TopLeftNear.X + (BBox.Width / 2),
                                            BBox.TopLeftNear.Y + (BBox.Height / 2),
                                            BBox.TopLeftNear.Z + (BBox.Depth / 2));
// Old Test values
{ Test Values
    CameraUp := Point3D(0, 1, 0);
    ModelRotation := Point3D(90, 0, 0);
    LookAt := Point3D(50, 0, 0);
}
    DoCameraUp;
    DoLookAt;
    DoModelRotation;

    Caption := 'Orientation : ' + AModel + ' : ' + FloatToStr(ViewportLayout.Width) + ' x ' + FloatToStr(ViewportLayout.Height);
  except
    on E : Exception do
      begin
        ShowMessage('Can''t Load Model : ' + AModel + sLineBreak +
                    'Exception class name : '+ E.ClassName   + sLineBreak +
                    'Exception message : ' + E.Message);
        FreeAndNil(GorillaModel);
      end;
  end;
end;

// Show Display Information on Debug Tab
procedure TForm1.DumpDisplayInfo;
var
  Displays: TPeardoxDisplays;
  Display: TDisplayInfo;
  Mode: TDisplayMode;
  I: Integer;
begin
  DebugMemo.Lines.Clear;

  Displays := TPeardoxDisplays.Create;
  try
    for I := 0 to Displays.Count - 1 do
    begin
      Display := Displays[I];

      DebugMemo.Lines.Add(Format('Device: %s', [Display.DeviceName]));
      DebugMemo.Lines.Add(Format('  FriendlyName: %s', [Display.FriendlyName]));
      DebugMemo.Lines.Add(Format('  Primary: %s', [BoolToStr(Display.IsPrimary, True)]));
      DebugMemo.Lines.Add(Format('  Bounds: (%d, %d) - (%d, %d)',
        [Display.MonitorRect.Left, Display.MonitorRect.Top,
         Display.MonitorRect.Right, Display.MonitorRect.Bottom]));
      DebugMemo.Lines.Add(Format('  Work Area: (%d, %d) - (%d, %d)',
        [Display.WorkRect.Left, Display.WorkRect.Top,
         Display.WorkRect.Right, Display.WorkRect.Bottom]));
       DebugMemo.Lines.Add('  Current: ' + Display.CurrentMode.ToString);
      DebugMemo.Lines.Add('  Available modes:');
      for Mode in Display.AvailableModes do
        DebugMemo.Lines.Add('    ' + Mode.ToString);
      DebugMemo.Lines.Add('');
    end;
  finally
    Displays.Free; // frees the list
  end;
end;

// Initialise a load of stuff
procedure TForm1.FormCreate(Sender: TObject);
begin
  TabControl1.ActiveTab := GorillaTab;

  if not DirectoryExists('models') then
    ModelDir := '../../../';

  CreateUIBoxes;
  ModelPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + ModelDir);
  GorillaViewport := TPolarViewport.Create(ViewportLayout);
  GorillaLight := TGorillaLight.Create(GorillaViewport);
  GorillaLight.Parent := GorillaViewport;
  GorillaLight.LightType := TLightType.Point;
  GorillaViewport.UseFixedFrameRate := true;
  // GorillaViewport.VSync := true;
  GorillaViewport.FixedFrameRate := 2000;
  GorillaViewport.DiagnosticsActive := true;
  GorillaViewport.UsingDesignCamera := False;
  GorillaCamera := TPolarCamera.Create(GorillaViewport);
  GorillaCamera.Parent := GorillaViewport;
  GorillaViewport.Camera := GorillaCamera;
  GorillaModel := Nil;
  GorillaCamera.FOV := 60;

end;


end.
