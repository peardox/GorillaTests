unit MathStuff;

interface

function MaxDim(x, y, z: Single): Single;

implementation

function Max(const A, B: Single): Single;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

function MaxDim(x, y, z: Single): Single;
begin
    Result := Max(x, y);
    Result := Max(Result, z);
end;

end.
