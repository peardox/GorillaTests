unit BasicsTestMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  System.Math.Vectors, Gorilla.Control, Gorilla.Transform, Gorilla.Mesh,
  Gorilla.Model, FMX.Controls3D, Gorilla.Camera, Gorilla.Viewport, FMX.Types3D,
  Gorilla.Light, Gorilla.Utils.Timer;

type
  TForm1 = class(TForm)
    GorillaViewport1: TGorillaViewport;
    GorillaLight1: TGorillaLight;
    GorillaModel1: TGorillaModel;
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
    ModelDir: String;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

// {$define HelmetModel}

uses Gorilla.GLB.Loader;

procedure TForm1.FormCreate(Sender: TObject);
begin
  if not DirectoryExists('models') then
    ModelDir := '..\..\..\';
  GorillaViewport1.UseFixedFrameRate := true;
  GorillaViewport1.FixedFrameRate := 500;
  GorillaViewport1.DiagnosticsActive := true;
//  GorillaViewport1.Scale.X := 2;
//  GorillaViewport1.Scale.Y := 2;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
{$ifdef HelmetModel}
  GorillaModel1.LoadFromFile( nil, ModelDir + 'models\DamagedHelmet\glTF-Binary\DamagedHelmet.glb', []);
  GorillaModel1.Position.Y := -0.25;
  GorillaModel1.Scale.Point := Point3D(1.75,1.75,1.75);
  GorillaModel1.RotationAngle.X := 180;
{$else}
  GorillaModel1.LoadFromFile( nil, ModelDir + 'models\GlassHurricaneCandleHolder\glTF-Binary\GlassHurricaneCandleHolder.glb', []);
  GorillaModel1.Position.Y := 1.65;
  GorillaModel1.Scale.Point := Point3D(10,10,10);
  GorillaModel1.RotationAngle.X := 180;
{$ifend}
//  GorillaModel1.IsStatic := true;
end;


end.
