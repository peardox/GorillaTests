program BasicsTest;

uses
  System.StartUpCopy,
  FMX.Forms,
  BasicsTestMain in 'BasicsTestMain.pas' {Form1};

// ====== Start of Added for GPU ======
{
  Better version at....
  https://sources.debian.org/src/castle-game-engine/7.0~alpha.3%2Bdfsg2-4/examples/physics/physics_persistent_forces_components/physics_persistent_forces_components.dpr
}

{$if defined(MSWINDOWS)}
var
  NvOptimusEnablement: UInt32;
  AmdPowerXpressRequestHighPerformance: UInt32;
exports
  NvOptimusEnablement,
  AmdPowerXpressRequestHighPerformance;
{$endif}

{$R *.res}

begin
{$if defined(MSWINDOWS)}
  NvOptimusEnablement := 1;
  AmdPowerXpressRequestHighPerformance := 1;
{$endif}
  { Report any dumb memory leaks - switch to false for release }
  ReportMemoryLeaksOnShutdown := True;
// ====== End of Added for GPU ======

  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
