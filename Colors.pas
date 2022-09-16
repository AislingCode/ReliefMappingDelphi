unit Colors;

interface

uses
	VectorTypes;

type
	PRGBArray = ^TRGBArray;
	TRGB = packed record r, g, b: byte end;
	PRGB = ^TRGB;
	TRGBArray = array[0..0] of TRGB;

	PRGBAArray = ^TRGBAArray;
	TRGBA = record case integer of 0: (r, g, b, a: byte); 1: (value: cardinal); 2: (rgb: TRGB; alpha: byte) end;
	PRGBA = ^TRGBA;
	TRGBAArray = array[0..0] of TRGBA;

  function RGBAToBGRA(c: TRGBA): TRGBA;
  function RGBAToBGR(c: TRGBA): TRGB;

  function NormalToRGBA(Normal: TVector3f): TRGBA;
  function RGBAToNormal(c: TRGBA): TVector3f;
  procedure CombineNormals(const V1: TVector3f; var V2: TVector3f);

	function grayRGB(c: TRGBA): TRGBA;

	function VectorToRGBA(const v: TVector4f): TRGBA;overload;
	function VectorToRGBA(const v: TVector3f; alpha: byte = 0): TRGBA;overload;

	function VectorToBGRA(const v: TVector4f): TRGBA;overload;
	function VectorToBGRA(const v: TVector3f; alpha: byte = 0): TRGBA;overload;

	function RGBAToAffineVector(v: TRGBA): TVector3f;
	function RGBAToVector(v: TRGBA): TVector4f;

	function BGRAToAffineVector(v: TRGBA): TVector3f;
	function BGRAToVector(v: TRGBA): TVector4f;

	procedure SetDebugThreadName(const Name: string);

implementation

uses
	Windows;

const
  k: Single = 1 /255;

function RGBAToBGRA(c: TRGBA): TRGBA;
begin
  Result.r:=c.b;
  Result.g:=c.g;
  Result.b:=c.r;
  Result.a:=c.a;
end;

function RGBAToBGR(c: TRGBA): TRGB;
begin
  Result.r:=c.b;
  Result.g:=c.g;
  Result.b:=c.r;
end;

function NormalToRGBA(Normal: TVector3f): TRGBA;
begin
  Normal[0]:=(Normal[0]+1.0)*0.5;
  Normal[1]:=(Normal[1]+1.0)*0.5;
  Normal[2]:=(Normal[2]+1.0)*0.5;

  result.r:=round(Normal[0]*255);
  result.g:=round(Normal[1]*255);
  result.b:=round(Normal[2]*255);
  result.a:=0;
end;

function RGBAToNormal(c: TRGBA): TVector3f;
const
  s: Single = 2/255;
begin
  result[0]:=c.r*s-1;
  result[1]:=c.g*s-1;
  result[2]:=c.b*s-1;
  c.a:=0;
end;

procedure CombineNormals(const V1: TVector3f; var V2: TVector3f);
var
	l, il: single;
begin
	V2[0]:=V1[0] + V2[0];
	V2[1]:=V1[1] + V2[1];
	V2[2]:=V1[2] * V2[2]; //это не ошибка, так задумано Сеней
	l:=sqrt(v2[0] * v2[0] + v2[1] * v2[1] + v2[2] * v2[2]);
	il:=1.0 / l;
	V2[0]:=V2[0] * il;
	V2[1]:=V2[1] * il;
	V2[2]:=V2[2] * il;
end;

function grayRGB(c: TRGBA): TRGBA;
begin
  Result.r:=(c.r+c.g+c.b) div 3;
  Result.g:=result.r;
  Result.b:=result.r;
  Result.a:=c.a;
end;

function VectorToRGBA(const v: TVector4f): TRGBA;
begin
	Result.r:=Round(v[0] * 255);
	Result.g:=Round(v[1] * 255);
	Result.b:=Round(v[2] * 255);
	Result.a:=Round(v[3] * 255);
end;

function VectorToBGRA(const v: TVector4f): TRGBA;
begin
	Result.r:=Round(v[2] * 255);
	Result.g:=Round(v[1] * 255);
	Result.b:=Round(v[0] * 255);
	Result.a:=Round(v[3] * 255);
end;

function VectorToRGBA(const v: TVector3f; alpha: byte): TRGBA;
begin
	Result.r:=Round(v[0] * 255);
	Result.g:=Round(v[1] * 255);
	Result.b:=Round(v[2] * 255);
	Result.a:=alpha;
end;

function VectorToBGRA(const v: TVector3f; alpha: byte): TRGBA;
begin
	Result.r:=Round(v[2] * 255);
	Result.g:=Round(v[1] * 255);
	Result.b:=Round(v[0] * 255);
	Result.a:=alpha;
end;

function RGBAToAffineVector(v: TRGBA): TVector3f;
begin
	Result[0]:=v.r * k;
	Result[1]:=v.g * k;
	Result[2]:=v.b * k;
end;

function RGBAToVector(v: TRGBA): TVector4f;
begin
	Result[0]:=v.r * k;
	Result[1]:=v.g * k;
	Result[2]:=v.b * k;
	Result[3]:=v.a * k;
end;

function BGRAToAffineVector(v: TRGBA): TVector3f;
begin
	Result[0]:=v.b * k;
	Result[1]:=v.g * k;
	Result[2]:=v.r * k;
end;

function BGRAToVector(v: TRGBA): TVector4f;
begin
	Result[0]:=v.b * k;
	Result[1]:=v.g * k;
	Result[2]:=v.r * k;
	Result[3]:=v.a * k;
end;

procedure SetDebugThreadName(const Name: string);
type
  TThreadNameInfo = record
    FType: LongWord;     // must be 0x1000
    FName: PChar;        // pointer to name (in user address space)
    FThreadID: LongWord; // thread ID (-1 indicates caller thread)
    FFlags: LongWord;    // reserved for future use, must be zero
  end;
var
  ThreadNameInfo: TThreadNameInfo;
begin
  ThreadNameInfo.FType := $1000;
  ThreadNameInfo.FName := PChar(Name);
  ThreadNameInfo.FThreadID := $FFFFFFFF;
  ThreadNameInfo.FFlags := 0;
	try
    RaiseException( $406D1388, 0, sizeof(ThreadNameInfo) div sizeof(LongWord), @ThreadNameInfo );
  except
  end;
end;

end.
