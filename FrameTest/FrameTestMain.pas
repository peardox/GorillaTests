unit FrameTestMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Types3D,
  System.Math.Vectors, Gorilla.Control, Gorilla.Transform, Gorilla.Mesh,
  Gorilla.Model, FMX.Controls3D, Gorilla.Light, PolarViewport, FMX.Layouts,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects3D,
  FMX.TabControl, PolarCamera;

type

  TForm1 = class(TForm)
    OpenDialog1: TOpenDialog;
    TabControl1: TTabControl;
    TabItem1: TTabItem;
    Layout1: TLayout;
    Layout2: TLayout;
    Layout4: TLayout;
    Layout5: TLayout;
    Layout6: TLayout;
    Layout3: TLayout;
    Load: TButton;
    procedure FormCreate(Sender: TObject);
    procedure LoadClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Layout5Resize(Sender: TObject);
  private
    { Private declarations }
    GorillaViewport1: TPolarViewport;
    GorillaLight1: TGorillaLight;
    GorillaModel1: TGorillaModel;
    GorillaCamera1: TPolarCamera;
    ModelDir: String;
    ModelPath: String;
    procedure SwitchModel(const AModel: String = '');
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses Gorilla.GLB.Loader, Gorilla.FBX.Loader, Gorilla.DefTypes, System.Math;

{$R *.fmx}

procedure TForm1.FormCreate(Sender: TObject);
begin
  if not DirectoryExists('models') then
    ModelDir := '..\..\..\';
  ModelPath := ExpandFileName(ExtractFilePath(ParamStr(0)) + ModelDir);
  OpenDialog1.InitialDir := ModelPath;
  GorillaViewport1 := TPolarViewport.Create(Layout5);
  GorillaLight1 := TGorillaLight.Create(GorillaViewport1);
  GorillaLight1.Parent := GorillaViewport1;
  GorillaModel1 := TGorillaModel.Create(GorillaViewport1);
  GorillaModel1.Parent := GorillaViewport1;
  GorillaViewport1.UseFixedFrameRate := true;
  GorillaViewport1.FixedFrameRate := 500;
  GorillaViewport1.DiagnosticsActive := true;
  GorillaViewport1.UsingDesignCamera := False;
  GorillaCamera1 := TPolarCamera.Create(GorillaViewport1);
  GorillaCamera1.Parent := GorillaViewport1;
  GorillaViewport1.Camera := GorillaCamera1;

  GorillaCamera1.FOV := 60;

  Layout4.Width := 0;
end;

{$define TESTING}
{$define TIGHT}
// {$define SHOWING}

procedure TForm1.FormShow(Sender: TObject);
begin
  SwitchModel('C:\src\GorillaTest\models\Sticks\XBoxController\Joystick_Animated.glb');
end;

procedure TForm1.Layout5Resize(Sender: TObject);
begin
{$if defined(POLAR)}
{$else}
 // if(Assigned(GorillaModel1)) then
 //   GorillaViewport1.TightFocus(GorillaModel1.GetBoundingBox());
{$ifend}
end;

procedure TForm1.LoadClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
    begin
      SwitchModel(OpenDialog1.Filename);
    end
  else
    SwitchModel;
end;

function MaxDim(x, y, z: Single): Single;
begin
    Result := Max(x, y);
    Result := Max(Result, z);
end;

procedure TForm1.SwitchModel(const AModel: String);
var
  BBox: TBoundingBox;
  Cam, BCtr: TPoint3D;
  Scale, CamPos: Single;
begin
  if (AModel = String.Empty) or (not FileExists(AModel)) then
    begin
      GorillaModel1.LoadFromFile( nil, ModelDir + 'models\GlassHurricaneCandleHolder\glTF-Binary\GlassHurricaneCandleHolder.glb', []);
      GorillaModel1.Position.Y := 1.65;
      GorillaModel1.Scale.Point := Point3D(10, 10, 10);
      GorillaModel1.RotationAngle.X := 180;
      GorillaModel1.IsStatic := true;
    end
  else
    begin
      CamPos := -2.5;
      GorillaModel1.LoadFromFile(nil, AModel, []);
      BBox := GorillaModel1.GetBoundingBox();
      BCtr := BBox.CenterPoint;

      GorillaModel1.Position.Point := Point3D(BBox.TopLeftNear.X + (BBox.Width / 2),
                                              BBox.TopLeftNear.Y + (BBox.Height / 2),
                                              BBox.TopLeftNear.Z + (BBox.Depth / 2));

     GorillaModel1.RotationAngle.X := 180;

{$if defined(TIGHT)}
{$if defined(POLAR)}
      GorillaCamera1.LookAt := TPoint3D.Create(0, 0, 0);
      GorillaCamera1.Radius := 0.9;
      GorillaCamera1.SetPolarOrientation(90,0,0);
{$else}
      GorillaViewport1.TightFocus(GorillaModel1.GetBoundingBox());
{$ifend}
{$else}
      GorillaCamera1.PointCameraAtOrigin(Point3D(CamPos, CamPos, CamPos));
{$ifend}

{$if defined(SHOWING)}
      ShowMessage(Format('Dims - W: %.2f, H: %.2f, D: %.2f' + sLineBreak +
                    'Position - X: %.2f, Y: %.2f, Z: %.2f' + sLineBreak +
                    'Camera - X: %.2f, Y: %.2f, Z: %.2f' + sLineBreak +
                    'Rot - X: %.2f, Y: %.2f, Z: %.2f' + sLineBreak +
                    'TLN - X: %.2f, Y: %.2f, Z: %.2f' + sLineBreak +
                    'BRF - X: %.2f, Y: %.2f, Z: %.2f',
                    [BBox.Width, BBox.Height, BBox.Depth,
                    GorillaModel1.Position.X, GorillaModel1.Position.Y, GorillaModel1.Position.Z,
                    GorillaCamera1.Position.X, GorillaCamera1.Position.Y, GorillaCamera1.Position.Z,
                    GorillaCamera1.RotationAngle.X, GorillaCamera1.RotationAngle.Y, GorillaCamera1.RotationAngle.Z,
                    BBox.TopLeftNear.X, BBox.TopLeftNear.Y, BBox.TopLeftNear.Z,
                    BBox.BottomRightFar.X, BBox.BottomRightFar.Y, BBox.BottomRightFar.Z
                    ] )); // Bounds W: 0.97, H: 0.67, D: 0.37 Center X: 0.0. Y: 0.32. Z: 0.02
{$ifend}
    end;

end;


end.
