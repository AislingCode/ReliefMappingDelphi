program ReliefMapping;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Generics.Collections;

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
  PARAMNOTRECOGNIZEDEXCEPTION = 'Parameter is not recognized: ';
  PARAMVALUENOTSUPPLIED = 'Parameter value is not supplied: ';
  PARAMFLOATFORMATEXCEPTION = 'Parameter value is invalid for a floating point: ';
  PARAMINTFORMATEXCEPTION = 'Parameter value is invalid for an integer: ';
  MANDATORYPARAMMISSING = 'Mandatory parameter value is not set: ';

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
