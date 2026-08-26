program TemplateBlank;

uses
  System.StartUpCopy,
  FMX.Forms,
// GpuPreference is Windows Specific
{$if defined(MSWINDOWS)}
  GpuPreference in 'GpuPreference.pas',
{$ifend}
  Unit1 in 'Unit1.pas' {Form1};

// Choose which profile to default to
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
