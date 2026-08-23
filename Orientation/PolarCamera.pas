unit PolarCamera;

interface

uses
  System.SysUtils, System.Classes, FMX.Types, Gorilla.Camera, Gorilla.DefTypes,
  System.Math, System.Math.Vectors, FMX.Types3D, FMX.Viewport3D;

type
  TPolarCamera = class(TGorillaCamera)
  private
    FWorldUp: TPoint3D;
    FLookAt:  TPoint3D;
    FRadius:  Single;
    function GetOwnerViewport: TViewport3D;
    function ComputeDefaultRadius: Single;
  public
    constructor Create(AOwner: TComponent); override;
    procedure PointCameraAt(const LookFrom, LookAt: TPoint3D);
    procedure PointCameraAtOrigin(const LookFrom: TPoint3D);
    procedure SetPolarOrientation(const Azimuth, Inclination, Roll: Single);
    property WorldUp: TPoint3D read FWorldUp write FWorldUp;
    property LookAt: TPoint3D read FLookAt write FLookAt;
    property Radius: Single   read FRadius write FRadius;
  end;

implementation

{ TPolarCamera }

constructor TPolarCamera.Create(AOwner: TComponent);
begin
  inherited;
  FWorldUp := TPoint3D.Create(0, 1, 0);
  FLookAt  := TPoint3D.Create(0, 0, 0);
  FRadius  := 0;
end;

function TPolarCamera.GetOwnerViewport: TViewport3D;
begin
  if Owner is TViewport3D then
    Result := TViewport3D(Owner)
  else
    Result := nil;
end;

function TPolarCamera.ComputeDefaultRadius: Single;
var
  VP: TViewport3D;
  HalfFOVRad, MinDim: Single;
begin
  Result := 10.0;
  VP := GetOwnerViewport;
  if not Assigned(VP) then
    Exit;
  MinDim := Min(VP.Width, VP.Height);
  if MinDim <= 0 then
    Exit;
  HalfFOVRad := DegToRad(AngleOfView * 0.5);
  if HalfFOVRad <= 0 then
    Exit;
  Result := (MinDim * 0.5) / Tan(HalfFOVRad);
end;

procedure TPolarCamera.PointCameraAt(const LookFrom, LookAt: TPoint3D);
var
  LForward, LRight, LUp: TPoint3D;
begin
  Position.Point := LookFrom;
  LForward := (LookAt - LookFrom).Normalize;
  LRight   := FWorldUp.CrossProduct(LForward).Normalize;
  LUp      := FWorldUp; // LForward.CrossProduct(LRight).Normalize;
  RotationAngle.Y := RadToDeg(ArcTan2(LForward.X, LForward.Z));
  RotationAngle.X := RadToDeg(ArcSin(-LForward.Y));
  RotationAngle.Z := RadToDeg(ArcTan2(-LRight.Y, LUp.Y));
end;

procedure TPolarCamera.PointCameraAtOrigin(const LookFrom: TPoint3D);
begin
  PointCameraAt(LookFrom, TPoint3D.Create(0, 0, 0));
end;

procedure TPolarCamera.SetPolarOrientation(
  const Azimuth, Inclination, Roll: Single);
var
  AzRad, InclRad, RollRad: Single;
  QYaw, QPitch, QRoll, QCombined: TQuaternion3D;
  M: TMatrix3D;
  QW, QX, QY, QZ: Single;
  SinPitch, CosPitch: Single;
  PitchRad, YawRad, RollRadOut: Single;
  EffectiveRadius: Single;
  LookFrom: TPoint3D;
begin
  // 1. Resolve radius
  if FRadius > 0 then
    EffectiveRadius := FRadius
  else
    EffectiveRadius := ComputeDefaultRadius;

  // 2. Spherical coords -> Cartesian LookFrom position on the sphere
  //    X = R * cos(Incl) * sin(Az)
  //    Y = R * sin(Incl)
  //    Z = R * cos(Incl) * cos(Az)
  AzRad   := DegToRad(Azimuth);
  InclRad := DegToRad(Inclination);
  RollRad := DegToRad(Roll);

  LookFrom.X := EffectiveRadius * Cos(InclRad) * Sin(AzRad);
  LookFrom.Y := EffectiveRadius * Sin(InclRad);
  LookFrom.Z := EffectiveRadius * Cos(InclRad) * Cos(AzRad);

  // Offset from origin by LookAt so orbiting works around any point
  LookFrom := LookFrom + FLookAt;

  // 3. Build orientation quaternions: Yaw -> Pitch -> Roll
  QYaw.ImagPart   := TPoint3D.Create(0, Sin(AzRad * 0.5), 0);
  QYaw.RealPart   := Cos(AzRad * 0.5);

  QPitch.ImagPart := TPoint3D.Create(Sin(InclRad * 0.5), 0, 0);
  QPitch.RealPart := Cos(InclRad * 0.5);

  QRoll.ImagPart  := TPoint3D.Create(0, 0, Sin(RollRad * 0.5));
  QRoll.RealPart  := Cos(RollRad * 0.5);

  QCombined := QYaw * QPitch * QRoll;
  QCombined := QCombined.Normalize;

  // 4. Quaternion -> rotation matrix
  QW := QCombined.RealPart;
  QX := QCombined.ImagPart.X;
  QY := QCombined.ImagPart.Y;
  QZ := QCombined.ImagPart.Z;

  M := TMatrix3D.Identity;
  M.m11 := 1 - 2*(QY*QY + QZ*QZ);
  M.m12 :=     2*(QX*QY + QW*QZ);
  M.m13 :=     2*(QX*QZ - QW*QY);
  M.m21 :=     2*(QX*QY - QW*QZ);
  M.m22 := 1 - 2*(QX*QX + QZ*QZ);
  M.m23 :=     2*(QY*QZ + QW*QX);
  M.m31 :=     2*(QX*QZ + QW*QY);
  M.m32 :=     2*(QY*QZ - QW*QX);
  M.m33 := 1 - 2*(QX*QX + QY*QY);

  // 5. Extract FMX Euler angles (Y -> X -> Z order)
  SinPitch := -M.m32;
  SinPitch := EnsureRange(SinPitch, -1.0, 1.0);
  PitchRad := ArcSin(SinPitch);
  CosPitch := Cos(PitchRad);

  if Abs(CosPitch) > 1.0e-6 then
  begin
    YawRad     := ArcTan2(M.m31, M.m33);
    RollRadOut := ArcTan2(M.m12, M.m22);
  end
  else
  begin
    // Gimbal lock at +/-90 inclination: absorb into yaw, zero roll
    if SinPitch < 0 then
      YawRad := ArcTan2(M.m21, M.m11)
    else
      YawRad := ArcTan2(-M.m21, M.m11);
    RollRadOut := 0;
  end;

  // 6. Apply rotation then call PointCameraAt to confirm the forward vector.
  //    PointCameraAt will overwrite RotationAngle.Y and .X but the quaternion
  //    path above provides the stable Roll that PointCameraAt cannot compute.
  RotationAngle.Y := RadToDeg(YawRad);
  RotationAngle.X := RadToDeg(PitchRad);
  RotationAngle.Z := RadToDeg(RollRadOut);

  PointCameraAt(LookFrom, FLookAt);
end;

end.
