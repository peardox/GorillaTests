unit PolarViewport;

interface

uses
  System.SysUtils, System.Classes, FMX.Types3D, System.Math,
  System.Math.Vectors, Gorilla.Viewport, Gorilla.Camera, Gorilla.DefTypes,
  PolarCamera;

type
  TPolarViewport = class(TGorillaViewport)
  private
    FPolarCamera: TPolarCamera;

    function GetViewportWidth: Single;
    function GetViewportHeight: Single;
    function GetAspectRatio: Single;
    function GetFOVRadians: Single;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Repositions the PolarCamera along its current view direction so the
    /// supplied bounding box fills as much of the viewport as possible.
    ///
    /// Strategy:
    ///   1. Find the centre of the bbox.
    ///   2. Project all 8 bbox corners onto the camera-right and camera-up axes
    ///      to find the half-extents visible in each screen dimension.
    ///   3. Use d = extent / tan(FOV/2) for both axes, adjusted for aspect.
    ///   4. Take the maximum required distance.
    ///   5. Move the camera to (centre - forward * distance).
    /// </summary>
    function TightFocus(const ABBox: TBoundingBox; const AutoFocus: Boolean = True): TPoint3D;
  end;

implementation

{ TPolarViewport }

constructor TPolarViewport.Create(AOwner: TComponent);
begin
  inherited;

  FPolarCamera := TPolarCamera.Create(Self);
  FPolarCamera.Parent := Self;

  // Wire up the viewport's camera to our polar camera
  Camera := FPolarCamera;
end;

destructor TPolarViewport.Destroy;
begin
  // FPolarCamera is owned by Self via TComponent, so it will be freed
  // automatically, but be explicit for clarity.
  FPolarCamera := nil;
  inherited;
end;

function TPolarViewport.GetViewportWidth: Single;
begin
  Result := Width;
end;

function TPolarViewport.GetViewportHeight: Single;
begin
  Result := Height;
end;

function TPolarViewport.GetAspectRatio: Single;
var
  H: Single;
begin
  H := GetViewportHeight;
  if H > 0 then
    Result := GetViewportWidth / H
  else
    Result := 1.0;
end;

function TPolarViewport.GetFOVRadians: Single;
begin
  // TCamera3D.AngleOfView is the vertical FOV in degrees
  Result := DegToRad(FPolarCamera.AngleOfView);
end;

function TPolarViewport.TightFocus(const ABBox: TBoundingBox; const AutoFocus: Boolean = True): TPoint3D;
var
  // Bbox derived values
  LMin, LMax: TPoint3D;
  LCenter: TPoint3D;
  LCorners: array[0..7] of TPoint3D;

  // Camera basis vectors (unit)
  LCamPos, LForward, LRight, LUp: TPoint3D;

  // Projection accumulators
  LProjectRight, LProjectUp, LProjectForward: Single;
  LMaxHalfH, LMaxHalfV, LMaxDepth: Single;

  // FOV derived
  LFovV: Single;
  LFovH: Single;

  // Required distances
  LDistForV, LDistForH, LRequiredDist: Single;

  I: Integer;
begin
  Result := TPoint3D.Zero;

  if FPolarCamera = nil then
    Exit;

  // ------------------------------------------------------------------
  // 1. Compute the 8 corners of the bounding box
  // ------------------------------------------------------------------
  LMin := ABBox.MinCorner;
  LMax := ABBox.MaxCorner;

  LCenter := TPoint3D.Create(
    (LMin.X + LMax.X) * 0.5,
    (LMin.Y + LMax.Y) * 0.5,
    (LMin.Z + LMax.Z) * 0.5
  );

  LCorners[0] := TPoint3D.Create(LMin.X, LMin.Y, LMin.Z);
  LCorners[1] := TPoint3D.Create(LMax.X, LMin.Y, LMin.Z);
  LCorners[2] := TPoint3D.Create(LMin.X, LMax.Y, LMin.Z);
  LCorners[3] := TPoint3D.Create(LMax.X, LMax.Y, LMin.Z);
  LCorners[4] := TPoint3D.Create(LMin.X, LMin.Y, LMax.Z);
  LCorners[5] := TPoint3D.Create(LMax.X, LMin.Y, LMax.Z);
  LCorners[6] := TPoint3D.Create(LMin.X, LMax.Y, LMax.Z);
  LCorners[7] := TPoint3D.Create(LMax.X, LMax.Y, LMax.Z);

  // ------------------------------------------------------------------
  // 2. Derive camera basis from current camera transform
  // ------------------------------------------------------------------
  LCamPos := TPoint3D(FPolarCamera.AbsolutePosition);

  LForward := (LCenter - LCamPos).Normalize;

  if LForward.Length < 0.0001 then
    LForward := TPoint3D.Create(0, 0, 1);

  LRight := TPoint3D.Create(0, 1, 0).CrossProduct(LForward).Normalize;

  if LRight.Length < 0.0001 then
    LRight := TPoint3D.Create(1, 0, 0);

  LUp := LForward.CrossProduct(LRight).Normalize;

  // ------------------------------------------------------------------
  // 3. Project every corner onto the camera axes
  // ------------------------------------------------------------------
  LMaxHalfH := 0;
  LMaxHalfV := 0;
  LMaxDepth := 0;

  for I := 0 to 7 do
  begin
    LProjectRight   := Abs((LCorners[I] - LCenter).DotProduct(LRight));
    LProjectUp      := Abs((LCorners[I] - LCenter).DotProduct(LUp));
    LProjectForward := Abs((LCorners[I] - LCenter).DotProduct(LForward));

    if LProjectRight   > LMaxHalfH then LMaxHalfH := LProjectRight;
    if LProjectUp      > LMaxHalfV then LMaxHalfV := LProjectUp;
    if LProjectForward > LMaxDepth  then LMaxDepth := LProjectForward;
  end;

  // ------------------------------------------------------------------
  // 4. Compute required distance
  // ------------------------------------------------------------------
  LFovV := GetFOVRadians * 0.5;
  LFovH := ArcTan(Tan(LFovV) * GetAspectRatio);

  if (LFovV < 0.0001) or (LFovH < 0.0001) then
    Exit;

  LDistForV := (LMaxHalfV / Tan(LFovV)) + LMaxDepth;
  LDistForH := (LMaxHalfH / Tan(LFovH)) + LMaxDepth;

  if LDistForH > LDistForV then
    LRequiredDist := LDistForH
  else
    LRequiredDist := LDistForV;

  // ------------------------------------------------------------------
  // 5. Compute new camera position and optionally apply it
  // ------------------------------------------------------------------
  Result := TPoint3D.Create(
    LCenter.X - LForward.X * LRequiredDist,
    LCenter.Y - LForward.Y * LRequiredDist,
    LCenter.Z - LForward.Z * LRequiredDist
  );

  if AutoFocus then
    FPolarCamera.PointCameraAt(Result, LCenter);
end;

end.
