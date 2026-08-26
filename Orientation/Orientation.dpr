program Orientation;

uses
  System.StartUpCopy,
  FMX.Forms,
  OrientationMain in 'OrientationMain.pas' {Form1},
  PolarCamera in 'PolarCamera.pas',
  PolarViewport in 'PolarViewport.pas',
  DisplayData in 'DisplayData.pas',
  GpuPreference in 'GpuPreference.pas';

{$define HIPERF}
// {$define POWERSAVE}

begin
  { Report any dumb memory leaks - switch to false for release }
  ReportMemoryLeaksOnShutdown := True;
{$if defined(MSWINDOWS)}
  {$if defined(HIPERF)}
  SetGpuPreference(gpHighPerformance);
  {$elseif defined(POWERSAVE)}
  SetGpuPreference(gpPowerSaving);
  {$ELSE}
  SetGpuPreference(gpAutomatic);
  {$ifend}
{$ifend}

  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
