program ReliefMapping;

{$APPTYPE CONSOLE}

{$R *.res}











{$R 'GLScene\Source\FmLibMaterialPicker.dfm' :TForm(FmLibMaterialPicker)}

uses
  System.SysUtils,
  System.Generics.Collections,
  Colors in 'Colors.pas',
  GLMultiPolygon in 'GLMultiPolygon.pas',
  Materials in 'Materials.pas',
  VectorGeometry in 'VectorGeometry.pas',
  VectorTypes in 'VectorTypes.pas',
  Cg.BombShader in 'GLScene\Source\Cg.BombShader.pas',
  Cg.GL in 'GLScene\Source\Cg.GL.pas',
  Cg.Import in 'GLScene\Source\Cg.Import.pas',
  Cg.PostTransformationShader in 'GLScene\Source\Cg.PostTransformationShader.pas',
  Cg.Register in 'GLScene\Source\Cg.Register.pas',
  Cg.Shader in 'GLScene\Source\Cg.Shader.pas',
  CUDA.APIComps in 'GLScene\Source\CUDA.APIComps.pas',
  CUDA.Compiler in 'GLScene\Source\CUDA.Compiler.pas',
  CUDA.Context in 'GLScene\Source\CUDA.Context.pas',
  CUDA.DataAccess in 'GLScene\Source\CUDA.DataAccess.pas',
  CUDA.EditorFm in 'GLScene\Source\CUDA.EditorFm.pas' {GLCUDAEditorForm},
  CUDA.FFTPlan in 'GLScene\Source\CUDA.FFTPlan.pas',
  CUDA.FourierTransform in 'GLScene\Source\CUDA.FourierTransform.pas',
  CUDA.Graphics in 'GLScene\Source\CUDA.Graphics.pas',
  CUDA.Import in 'GLScene\Source\CUDA.Import.pas',
  CUDA.ParallelPrimitives in 'GLScene\Source\CUDA.ParallelPrimitives.pas',
  CUDA.Parser in 'GLScene\Source\CUDA.Parser.pas',
  CUDA.PropEditors in 'GLScene\Source\CUDA.PropEditors.pas',
  CUDA.Register in 'GLScene\Source\CUDA.Register.pas',
  CUDA.Runtime in 'GLScene\Source\CUDA.Runtime.pas',
  CUDA.Utility in 'GLScene\Source\CUDA.Utility.pas',
  DWS.Classes in 'GLScene\Source\DWS.Classes.pas',
  DWS.HelperFunc in 'GLScene\Source\DWS.HelperFunc.pas',
  DWS.Objects in 'GLScene\Source\DWS.Objects.pas',
  DWS.OpenGL in 'GLScene\Source\DWS.OpenGL.pas',
  DWS.Scene in 'GLScene\Source\DWS.Scene.pas',
  DWS.Script in 'GLScene\Source\DWS.Script.pas',
  DWS.VectorGeometry in 'GLScene\Source\DWS.VectorGeometry.pas',
  FLibMaterialPicker in 'GLScene\Source\FLibMaterialPicker.pas' {GLLibMaterialPickerForm},
  FmGuiLayoutEditor in 'GLScene\Source\FmGuiLayoutEditor.pas' {GLLayoutEditorForm},
  FmGuiSkinEditor in 'GLScene\Source\FmGuiSkinEditor.pas' {GLSkinEditorForm},
  FmInfo in 'GLScene\Source\FmInfo.pas' {GLInfoForm},
  OpenGL1x;

type
  TParamType = (TString, TUnary, TFloat, TInteger);

  TParam = record
    Name: string[20];
    ParamType: TParamType;
    IsMandatory: boolean;
  end;

const
  // Command line switches
  SOURCEIMAGESWITCH: TParam = (Name: '-source-image'; ParamType: TParamType.TString; IsMandatory: true);
  RESULTIMAGESWITCH: TParam = (Name: '-result_image'; ParamType: TParamType.TString; IsMandatory: true);
  OVERWRITESWITCH: TParam = (Name: '-overwrite'; ParamType: TParamType.TUnary; IsMandatory: false);
  RESULTFORMATSWITCH: TParam = (Name: '-result_format '; ParamType: TParamType.TString; IsMandatory: true);
  CONTOURSWITCH: TParam = (Name: '-contour'; ParamType: TParamType.TString; IsMandatory: false);
  SOBELSCALESWITCH: TParam = (Name: '-sobel_scale'; ParamType: TParamType.TFloat; IsMandatory: false);
  SOBELFILTERSWITCH: TParam = (Name: '-sobel_filter'; ParamType: TParamType.TInteger; IsMandatory: false);
  WIDTHSWITCH: TParam = (Name: '-width'; ParamType: TParamType.TInteger; IsMandatory: true);
  HEIGHTSWITCH: TParam = (Name: '-height'; ParamType: TParamType.TInteger; IsMandatory: true);
  EDGESIZESWITCH: TParam = (Name: '-edge_size'; ParamType: TParamType.TInteger; IsMandatory: false);
  EDGERADIUSSWITCH: TParam = (Name: '-edge_radius'; ParamType: TParamType.TInteger; IsMandatory: false);
  EDGESCALESWITCH: TParam = (Name: '-edge-scale'; ParamType: TParamType.TFloat; IsMandatory: false);
  // Error messages
  PARAMNOTRECOGNIZEDEXCEPTION = 'Parameter not recognized: ';
  PARAMVALUENOTSUPPLIED = 'Parameter value not supplied: ';
  PARAMFLOATFORMATEXCEPTION = 'Parameter value invalid for a floating point: ';
  PARAMINTFORMATEXCEPTION = 'Parameter value invalid for an integer: ';
  MANDATORYPARAMMISSING = 'Mandatory parameter value not set: ';

var
  // Command line parameters will be contained in a string dictionary, because
  // I couldn't find a good way to make a string - TObject dictionary that
  // accepts Booleans
  // Overwrite: boolean;
  //SobelScale: double;
  //EdgeScale: double = 1;
  SobelFilter, Width, Height, EdgeSize, EdgeRadius: integer;
  Params: TDictionary<TParam, string>;
  // Iterator
  var i: integer = 1;

procedure AssignParamValue(var _index: integer);
var
  Param: string;
  Key: TParam;
begin
  Param := ParamStr(_index);
  Key.Name := '';

  for var TmpKey: TParam in Params.Keys do
  begin
    if (String.Equals(TmpKey.Name, Param)) then
    begin
      Key := TmpKey;
      break;
    end;
  end;

  if (Key.Name = '') then
  begin
    raise Exception.Create(Concat(PARAMNOTRECOGNIZEDEXCEPTION, param));
  end;

  // Unary parameters
  if (Key.ParamType = TParamType.TUnary) then
  begin
    Params.AddOrSetValue(Key, '1');
  end
  // Floating point parameters with validation
  else if (Key.ParamType = TParamType.TFloat) then
  begin
    inc(_index);
    if (_index > ParamCount) then raise Exception.Create(Concat(PARAMVALUENOTSUPPLIED, param));
    try
      StrToFloat(ParamStr(_index));
    except
      on Exception : EConvertError do
        raise Exception.Create(concat(PARAMFLOATFORMATEXCEPTION, ParamStr(_index)));
    end;
    Params.AddOrSetValue(Key, ParamStr(_index));
  end
  // Integer parameters with validation
  else if (Key.ParamType = TParamType.TInteger) then
  begin
    inc(_index);
    if (_index > ParamCount) then raise Exception.Create(Concat(PARAMVALUENOTSUPPLIED, param));
    try
      StrToInt(ParamStr(_index));
    except
      on Exception : EConvertError do
        raise Exception.Create(concat(PARAMINTFORMATEXCEPTION, ParamStr(_index)));
    end;
    Params.AddOrSetValue(Key, ParamStr(_index));
  end
  // Other parameters w/o validation (strings)
  else
  begin // This inc-if-add block can potentially be extracted (DRY)
    inc(_index);
    if (_index > ParamCount) then raise Exception.Create(Concat(PARAMVALUENOTSUPPLIED, param));
    Params.AddOrSetValue(Key, ParamStr(_index));
  end;
end;

begin
  try
    // No parameters?
    if (ParamCount = 0) then
    begin
      // TODO: add help text
      Writeln('Help text here');
      Exit;
    end;

    // Init parameters dictionary with default values
    Params := TDictionary<TParam, string>.Create;
    Params.Add(SOURCEIMAGESWITCH, '');
    Params.Add(RESULTIMAGESWITCH, '');
    Params.Add(OVERWRITESWITCH, '');
    Params.Add(RESULTFORMATSWITCH, 'png');
    Params.Add(CONTOURSWITCH, '');
    Params.Add(SOBELSCALESWITCH, '');
    Params.Add(WIDTHSWITCH, '');
    Params.Add(HEIGHTSWITCH, '');
    Params.Add(EDGESIZESWITCH, '');
    Params.Add(EDGERADIUSSWITCH, '');
    Params.Add(EDGESCALESWITCH, '1');

    // Handling command line parameters. Strange, but I didn't find a better
    // or in-built way to do this.
    while i < ParamCount do
    begin
      AssignParamValue(i);
      inc(i);
    end;

    // Checking existance of mandatory parameters
    for var Kvp: TPair<TParam, string> in Params do
    begin
      if (Kvp.Key.IsMandatory) and (Kvp.Value = '') then
        raise Exception.Create(concat(MANDATORYPARAMMISSING, Kvp.Key.Name));
    end;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
