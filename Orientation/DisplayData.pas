unit DisplayData;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.MultiMon;

type
  TDisplayMode = record
    Width: Integer;
    Height: Integer;
    BitsPerPixel: Integer;
    RefreshRate: Integer; // Hz
    function ToString: string;
  end;

  TDisplayModeList = TList<TDisplayMode>;

  TDisplayInfo = record
    DeviceName: string;
    FriendlyName: string;
    MonitorRect: TRect;
    WorkRect: TRect;
    IsPrimary: Boolean;
    CurrentMode: TDisplayMode;
    AvailableModes: TDisplayModeList;
  end;

  TDisplayInfoList = TList<TDisplayInfo>;

  TPeardoxDisplays = class
  private
    FDisplays: TDisplayInfoList;
    function GetCount: Integer;
    function GetDisplay(AIndex: Integer): TDisplayInfo;
    procedure Refresh;
    procedure ClearDisplays;
  public
    constructor Create;
    destructor Destroy; override;

    property Count: Integer read GetCount;
    property Displays[AIndex: Integer]: TDisplayInfo
      read GetDisplay; default;
    property List: TDisplayInfoList read FDisplays;
  end;

implementation

uses
  System.StrUtils, System.Win.Registry;

const
  ENUM_CURRENT_SETTINGS = DWORD(-1);

  // DisplayDevice StateFlags (from wingdi.h)
  DISPLAY_DEVICE_ACTIVE = $00000001;
  DISPLAY_DEVICE_ATTACHED = $00000002;

  // EnumDisplayDevices flag (from winuser.h)
  EDD_GET_DEVICE_INTERFACE_NAME = $00000001;

  EDID_LENGTH = 128;
  EDID_DESCRIPTOR_START = 54;
  EDID_DESCRIPTOR_SIZE = 18;
  EDID_DESCRIPTOR_COUNT = 4;
  EDID_TAG_MONITOR_NAME = $FC;

{ TDisplayMode }

function TDisplayMode.ToString: string;
begin
  Result := Format('%d x %d, %d-bit, %d Hz',
    [Width, Height, BitsPerPixel, RefreshRate]);
end;

{ ---- EDID parsing ---- }

function ParseEdidMonitorName(const Edid: TBytes): string;
var
  I, Base, J: Integer;
  Ch: Byte;
begin
  Result := '';
  if Length(Edid) < EDID_LENGTH then
    Exit;

  for I := 0 to EDID_DESCRIPTOR_COUNT - 1 do
  begin
    Base := EDID_DESCRIPTOR_START + I * EDID_DESCRIPTOR_SIZE;

    if (Edid[Base] = 0) and (Edid[Base + 1] = 0) and
       (Edid[Base + 2] = 0) and
       (Edid[Base + 3] = EDID_TAG_MONITOR_NAME) then
    begin
      for J := Base + 5 to Base + EDID_DESCRIPTOR_SIZE - 1 do
      begin
        Ch := Edid[J];
        if Ch = $0A then
          Break;
        Result := Result + Char(Ch);
      end;
      Result := Trim(Result);
      Exit;
    end;
  end;
end;

function InterfacePathToInstancePath(const APath: string): string;
var
  S: string;
  P: Integer;
begin
  S := APath;
  if S.StartsWith('\\?\') or S.StartsWith('\\.\') then
    S := S.Substring(4);
  P := S.LastIndexOf('#');
  if P > 0 then
    S := S.Substring(0, P);
  Result := S.Replace('#', '\');
end;

function ReadEdidForDevice(const InstancePath: string): TBytes;
var
  Reg: TRegistry;
  KeyPath: string;
begin
  Result := nil;
  KeyPath := 'SYSTEM\CurrentControlSet\Enum\' + InstancePath +
    '\Device Parameters';

  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKeyReadOnly(KeyPath) then
    begin
      if Reg.ValueExists('EDID') then
      begin
        SetLength(Result, Reg.GetDataSize('EDID'));
        if Length(Result) > 0 then
          Reg.ReadBinaryData('EDID', Result[0], Length(Result));
      end;
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
  end;
end;

function GetFriendlyMonitorName(const GdiDeviceName: string): string;
var
  Monitor: TDisplayDevice;
  MonIdx: DWORD;
  InstancePath: string;
  Edid: TBytes;
begin
  Result := '';

  MonIdx := 0;
  FillChar(Monitor, SizeOf(Monitor), 0);
  Monitor.cb := SizeOf(TDisplayDevice);

  while EnumDisplayDevices(PChar(GdiDeviceName), MonIdx, Monitor,
    EDD_GET_DEVICE_INTERFACE_NAME) do
  begin
    if (Monitor.StateFlags and DISPLAY_DEVICE_ACTIVE) <> 0 then
    begin
      InstancePath := InterfacePathToInstancePath(
        string(Monitor.DeviceID));

      Edid := ReadEdidForDevice(InstancePath);
      if Length(Edid) >= EDID_LENGTH then
        Result := ParseEdidMonitorName(Edid);

      if Result = '' then
        Result := string(Monitor.DeviceString);

      if Result <> '' then
        Exit;
    end;

    Inc(MonIdx);
    FillChar(Monitor, SizeOf(Monitor), 0);
    Monitor.cb := SizeOf(TDisplayDevice);
  end;
end;

{ ---- Display mode enumeration ---- }

function DevModeToDisplayMode(const DevMode: TDevMode): TDisplayMode;
begin
  Result.Width := DevMode.dmPelsWidth;
  Result.Height := DevMode.dmPelsHeight;
  Result.BitsPerPixel := DevMode.dmBitsPerPel;
  Result.RefreshRate := DevMode.dmDisplayFrequency;
end;

function SameMode(const A, B: TDisplayMode): Boolean;
begin
  Result := (A.Width = B.Width) and (A.Height = B.Height) and
    (A.BitsPerPixel = B.BitsPerPixel) and (A.RefreshRate = B.RefreshRate);
end;

function GetCurrentMode(const DeviceName: string): TDisplayMode;
var
  DevMode: TDevMode;
begin
  FillChar(DevMode, SizeOf(DevMode), 0);
  DevMode.dmSize := SizeOf(TDevMode);

  if EnumDisplaySettings(PChar(DeviceName), ENUM_CURRENT_SETTINGS,
    DevMode) then
    Result := DevModeToDisplayMode(DevMode)
  else
    FillChar(Result, SizeOf(Result), 0);
end;

function GetAvailableModes(const DeviceName: string): TDisplayModeList;
var
  DevMode: TDevMode;
  ModeNum: DWORD;
  Mode: TDisplayMode;
  Existing: TDisplayMode;
  Found: Boolean;
begin
  Result := TDisplayModeList.Create;
  ModeNum := 0;

  FillChar(DevMode, SizeOf(DevMode), 0);
  DevMode.dmSize := SizeOf(TDevMode);

  while EnumDisplaySettings(PChar(DeviceName), ModeNum, DevMode) do
  begin
    Mode := DevModeToDisplayMode(DevMode);

    Found := False;
    for Existing in Result do
      if SameMode(Existing, Mode) then
      begin
        Found := True;
        Break;
      end;

    if not Found then
      Result.Add(Mode);

    Inc(ModeNum);
    FillChar(DevMode, SizeOf(DevMode), 0);
    DevMode.dmSize := SizeOf(TDevMode);
  end;
end;

{ ---- Monitor enumeration callback ---- }

function MonitorEnumProc(hMonitor: HMONITOR; hdcMonitor: HDC;
  lprcMonitor: PRect; dwData: LPARAM): BOOL; stdcall;
var
  List: TDisplayInfoList;
  Info: TMonitorInfoEx;
  Display: TDisplayInfo;
  Added: Boolean;
begin
  Result := True;
  List := TDisplayInfoList(dwData);

  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(TMonitorInfoEx);

  if not GetMonitorInfo(hMonitor, @Info) then
    Exit;

  Display := Default(TDisplayInfo);
  Added := False;
  try
    Display.DeviceName := string(Info.szDevice);
    Display.MonitorRect := Info.rcMonitor;
    Display.WorkRect := Info.rcWork;
    Display.IsPrimary := (Info.dwFlags and MONITORINFOF_PRIMARY) <> 0;
    Display.FriendlyName := GetFriendlyMonitorName(Display.DeviceName);
    Display.CurrentMode := GetCurrentMode(Display.DeviceName);
    Display.AvailableModes := GetAvailableModes(Display.DeviceName);

    List.Add(Display);
    Added := True;
  finally
    if not Added then
      Display.AvailableModes.Free;
  end;
end;

{ TPeardoxDisplays }

constructor TPeardoxDisplays.Create;
begin
  inherited Create;
  FDisplays := TDisplayInfoList.Create;
  Refresh;
end;

destructor TPeardoxDisplays.Destroy;
begin
  ClearDisplays;
  FDisplays.Free;
  inherited Destroy;
end;

procedure TPeardoxDisplays.ClearDisplays;
var
  Display: TDisplayInfo;
begin
  if FDisplays = nil then
    Exit;
  for Display in FDisplays do
    Display.AvailableModes.Free;
  FDisplays.Clear;
end;

procedure TPeardoxDisplays.Refresh;
begin
  ClearDisplays;
  EnumDisplayMonitors(0, nil, @MonitorEnumProc, LPARAM(FDisplays));
end;

function TPeardoxDisplays.GetCount: Integer;
begin
  Result := FDisplays.Count;
end;

function TPeardoxDisplays.GetDisplay(AIndex: Integer): TDisplayInfo;
begin
  Result := FDisplays[AIndex];
end;

end.
