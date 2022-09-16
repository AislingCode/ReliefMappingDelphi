unit Materials;

interface

uses
  GDIPUTIL, GDIPAPI, GDIPOBJ, ActiveX, Classes, Graphics, Math,
  VectorGeometry, Contnrs, Colors, MatTypes, Jpeg, VectorTypes,
  FlowControl, ClusterIntf, MetaStorage, WeakRefs, {XMLDoc, XMLIntf, }NativeXML, GLBaseClass,
  LocalizerDictionaryUnit, uObjRegistryIntf;

{$I Dbg.inc}
{$DEFINE MIXED_RAYS_ENABLED}
{$DEFINE PBR_ENABLE}
{$I SetupLists.inc}

type
  TMaterial = class;
  PMaterial = ^TMaterial;
  TMaterialClass = class of TMaterial;
  TMaterialType = class;
  PMaterialType = ^TMaterialType;
	TMultiMaterial = class;
  TMaterialList = class;

  TMultiMaterialCreated = procedure (m: TObject; const ScrollTo: String = '') of object;
  TMonoMaterialCreated = procedure (m: TObject; const ScrollTo: String = '') of object;

  IMaterialLibrary = interface                   //должен реализовывать TGLLibMaterials
  ['{C6478877-4397-422B-BB26-BE7764390814}']
    function GetCount: Integer;
    function GetItem(const Index: Integer): TMaterial;
    function FindMaterial(const aName: string): TMaterial;
    function AddMultiMaterial(const aName: string; const Index: Integer; onMultiCreated: TMultiMaterialCreated): TMultiMaterial;
    function SetMonoMaterial(const MonoMaterialName: string; const OwnerIndex: Integer; onMonoCreated: TMonoMaterialCreated; MonoClass: TMaterialClass): TMaterial;
    function FindOldMaterialByNewMaterial(rendMaterial: TMaterial): Integer;
    procedure UpdateSetMaterial(aWndHandle: Cardinal; aMaterial: TMaterial);
  end;

  IMaterialContainer = interface                 //должен реализовывать TGLLibMaterial
  ['{F40E5E87-C55F-4259-B58A-89022D630410}']
    function GetContainerName: string;
    procedure GetMaterialLibrary(out ml: IMaterialLibrary);
    function IsMultiMaterial(): Boolean;
  end;

  ICompoundName = interface
  ['{73E0557F-7226-40B9-A73C-907FFDDD6D98}']
    function GetCompoundName: string;
  end;

  IMonoMaterialContainer = interface
  ['{7E578A6D-282E-41FD-9DA0-532BCCCCC11D}']
    function GetMonoMaterialList: TMaterialList;
  end;

  IXMLInf = interface
  ['{03DAEAEE-20AB-49BF-AB0F-9BD5FA8C5363}']
{    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0);
    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0);}
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0);
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0);
    function EqualTo(t: TObject): boolean;
    procedure WriteToFiler(WriteInfo: TWriteInfo);
    procedure ReadFromFiler(ReadInfo: TReadInfo);
  end;

  TInterfacedObjectList = class(TObjectList, IClusteredIO, IWeakRefsHolder)
  protected
{$IFDEF DEBUG_ADDREF}
    FRefCount: Integer;
{$ENDIF}
    FWeakRefs: IWeakRefsHolder;
    function GetWeakRefs: IWeakRefsHolder;
    property WeakRefs: IWeakRefsHolder read GetWeakRefs implements IWeakRefsHolder;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    procedure SaveObject(var SaveInfo: TSaveInfo);virtual; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;virtual;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;virtual;
{$IFDEF DEBUG_ADDREF}
  public
    destructor Destroy();override;
{$ENDIF}
  end;

  TSimpleInterfacedObject = class(TObject, IUnknown, IWeakRefsHolder)
  protected
{$IFDEF DEBUG_ADDREF}
    FRefCount: Integer;
{$ENDIF}
    FWeakRefs: IWeakRefsHolder;
    function GetWeakRefs: IWeakRefsHolder;
    property WeakRefs: IWeakRefsHolder read GetWeakRefs implements IWeakRefsHolder;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
{$IFDEF DEBUG_ADDREF}
  public
    destructor Destroy();override;
{$ENDIF}
    function HasWeakReferences: boolean;
  end;

  TMaterialTextureAtlas = class;
  TSimpleTexturesList = class;
  TMaterialParameter = class;
  TMaterialParameters = class;

  TMaterialRef = class(TThreadSafeWeakRef)
  public
    function LockRef: TMaterial;
  end;

  TMaterialParameterRef = class(TThreadSafeWeakRef)
  public
    function LockRef: TMaterialParameter;
  end;

  TMaterialParametersRef = class(TThreadSafeWeakRef)
  public
    function LockRef: TMaterialParameters;
  end;

  TMaterialParametersSmartRef = class
  private
    FOwnerLink: TMaterialRef;
    FLink: TMaterialParametersRef;
  public
    constructor Create(const p: TMaterialParameters);
    destructor Destroy;override;
    function LockRef: TMaterialParameters;
    procedure UnlockRef;
  end;

  TMaterialParameterSmartRef = class
  private
    FName: string;
    FListLink: TMaterialParametersSmartRef;
    FLink: TMaterialParameterRef;
  public
    constructor Create(const p: TMaterialParameter);
    destructor Destroy;override;
    function LockRef: TMaterialParameter;
    procedure UnlockRef;
  end;

  TNotifyEventRef = class(TThreadSafeWeakMethodRef)
  public
    procedure Notify(Sender: TObject);
  end;

//Абстрактный параметр материала
  TMaterialParameter = class(TSimpleInterfacedObject, IUnknown, ISomeParameter, IGroupedParameter, IClusteredIO, IWeakRefsHolder, IGUID)
  private
    FName, FAltName, FHint, FCategory: string;                                           //Имя параметра
    FCategoryOrder: Integer;
    FOwner: TObject;
    FOnChange: TNotifyEventRef;
    FInspectors: IParameterInspectorsList;
    FCustomizable: boolean;                                                              //Может ли пользователь менять параметр
    FOptional: Boolean;
    FLink: TMaterialParameterSmartRef;
		FWeakRefs: IWeakRefsHolder;
    FGUID: TGUID;
		property WeakRefs: IWeakRefsHolder read FWeakRefs implements IWeakRefsHolder;
    function GetName: string;
    function GetIntName: string;
    procedure SetIntName(aName: string);
    function GetType: integer;
    function Editable: boolean;
    function GetParameter: TObject;
    procedure AddInspector(aInspector: IParameterInspector);
    procedure RemoveInspector(aInspector: IParameterInspector);
    function GetCategory: string;
    function GetAltName: string;
    function GetCustom: boolean;
    procedure SetAltName(const Value: string);
    procedure SetCustom(const Value: boolean);
    function GetOnChange: TNotifyEvent;
    procedure SetOnChange(const Value: TNotifyEvent);
    function GetOptional: boolean;
    procedure SetOptional(const Value: boolean);
  protected
    FOffset: integer;                                                                    //Смещение в упакованном списке (адрес параметра относительно начала структуры с параметрами материала в буфере всех материалов шейдера)
    FType: TMaterialParameterType;                                                       //Тип параметра
    FUpdatable: boolean;
    procedure Setup;virtual;abstract;                                                    //Тут нужно как минимум проставить тип параметру
    procedure PlaceDataAt(p: pointer);virtual;abstract;                                  //Скопировать данные в указанный адрес
    procedure GetDataFrom(p: pointer);virtual;abstract;                                  //Прочитать данные из указанного адреса
    procedure SaveObject(var SaveInfo: TSaveInfo);virtual; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;virtual;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;virtual;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); overload; virtual;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); overload; virtual;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); overload; virtual;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); overload; virtual;
    procedure WriteToFiler(WriteInfo: TWriteInfo);virtual;
    procedure ReadFromFiler(ReadInfo: TReadInfo);virtual;
  public
    constructor Create(aOwner: TObject);virtual;
    destructor Destroy;override;
    procedure ParameterChanged;

    procedure Assign(src: TMaterialParameter);virtual;                                   //Скопировать целиком
    procedure AssignValue(src: TMaterialParameter);virtual;abstract;                     //Скопировать только значение (если тип несовместимый, то exception)
    procedure RelinkRefs(const src: TMaterialParameter);
    procedure PackAt(dst: pointer);                                                      //Скопировать данные в указанный адрес начала структуры
    procedure PackAt2(dst: pointer);                                                      //Скопировать данные в указанный адрес начала структуры (v2)
    procedure UnpackFrom2(src: pointer);
    procedure CountOffset(var offset: integer);                                          //Вычислить свое положение в упакованном буфере
    procedure ExtractFrom(conv: IMaterialConverter);virtual;abstract;                    //Прочитать значение из конвертера
    procedure UpdateFrom(conv: IMaterialConverter);
    procedure CopyTo(conv: IMaterialConverter);virtual;abstract;                         //Записать значение в конвертер (для этого он должен быть двунаправленным)

    function AsInteger: Integer;virtual;                                                 //Попытка прочитать как Integer(иначе Exception) и т.д.
    function AsFloat: Single;virtual;
    function AsFloat3: TAffineVector;virtual;
    function AsFloat4: TVector;virtual;
    function AsMatrix: TMatrix;virtual;
    function AsString(short: boolean = false): string;virtual;
    function AsTextureValue: TTextureValue;virtual;
    function AsMonoMaterial: TMaterial;virtual;
    function AsTexTransform: TTexTransformSettings; virtual;
    function AsReflStruct: TReflStruct; virtual;
    function AsTexWrapMode: TTexWrapMode; virtual;

    procedure SetAsInteger(const value: Integer);virtual;                                //Попытка записать как Integer(иначе Exception) и т.д.
    procedure SetAsFloat(const value: Single);virtual;
    procedure SetAsFloat3(const value: TAffineVector);virtual;
    procedure SetAsFloat4(const value: TVector);virtual;
    procedure SetAsMatrix(const value: TMatrix);virtual;
    procedure SetAsTextureValue(const value: TTextureValue);virtual;
    procedure SetAsString(const value: string);virtual;
    procedure SetAsMonoMaterial(const value: TMaterial);virtual;
    procedure SetAsTexTransform(const value: TTexTransformSettings); virtual;
    procedure SetAsReflStruct(const value: TReflStruct); virtual;
    procedure SetAsTexWrapMode(const value: TTexWrapMode); virtual;

    property Float: Single read AsFloat write SetAsFloat;
    property Int: Integer read AsInteger write SetAsInteger;
    property Float3: TAffineVector read AsFloat3 write SetAsFloat3;
    property Float4: TVector read AsFloat4 write SetAsFloat4;
    property Matrix: TMatrix read AsMatrix write SetAsMatrix;


    function GetShaderValue: string;virtual;                                             //Получить код значения параметра для шейдера
    function GetShaderDefaultValue: string;virtual;
    function GetShaderType: string;
    function GetShaderID: string;

    property OnChange: TNotifyEvent read GetOnChange write SetOnChange;
    property Owner: TObject read FOwner;
    procedure ChangeOwner(const newOwner: TObject);
    function GetMaterial: TMaterial;
    procedure Dump;virtual;
    procedure SetAtlas(atlas: TMaterialTextureAtlas; textures: TSimpleTexturesList);virtual;
    function RootClass: TClass;

		function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;

    property Updatable: boolean read FUpdatable write FUpdatable;

    function EqualTo(p: TMaterialParameter): boolean;virtual;

    function GetGlobalUniqueIdentifier: TGUID;

    procedure LinkTo(p: TMaterialParameter);
    function This: TMaterialParameter;
    property Customizable: boolean read GetCustom write SetCustom;
    property Optional: boolean read GetOptional write SetOptional;
    property AltName: string read GetAltName write SetAltName;
    property IntName: string read FName;
    property Category: string read FCategory;
    function Description: string;
    property ParameterType: TMaterialParameterType read FType;
  end;

  TMaterialParameterClass = class of TMaterialParameter;

  TIntegerMaterialParameter = class(TMaterialParameter, IIntegerParameter)
  private
    FValue: Integer;                                                                     //Это внутреннее значение
    PValue: PInteger;                                                                    //Это адрес значения. По-умолчанию ссылается на FValue, но для 2-х стороннего конвертера можно изменить адрес на внешний
    procedure SetValue(const Value: Integer);
  protected
    function GetValue: Integer;virtual;
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: Integer read GetValue write SetValue;
    property ValuePointer: PInteger read PValue write PValue;                            //Адрес значения. Его можно изменить, чтобы параметр читал/писал извне (а не из внутреннего значения)
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsInteger: Integer;override;
    function AsFloat: Single;override;
    function AsString(short: boolean): string;override;

    procedure SetAsInteger(const aValue: Integer);override;
    procedure SetAsFloat(const aValue: Single);override;

    function GetShaderValue: string;override;                                             //Получить код значения параметра для шейдера

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
  end;

  TTypeMaterialParameter = class(TIntegerMaterialParameter)
  protected
    function GetValue: Integer;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
  end;

  TIntEnumMaterialParameter = class(TIntegerMaterialParameter, IIntEnumParameter)
  private
    FCaptions: string;
  protected
    procedure Setup;override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override;
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    function GetEnumCaptions: string;
    procedure SetCaptions(const caps: array of string);
  end;

  TFloatMaterialParameter = class(TMaterialParameter, IFloatParameter)
  private
    FValue: Single;
    PValue: PSingle;
    function GetValue: Single;
    function GetPureValue: Single;
    procedure SetValue(const Value: Single);
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: Single read GetValue write SetValue;
    property ValuePointer: PSingle read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsInteger: Integer;override;
    function AsFloat: Single;override;
    function AsString(short: boolean): string;override;

    procedure SetAsInteger(const aValue: Integer);override;
    procedure SetAsFloat(const aValue: Single);override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
  end;

  TVoxelAngleMaterialParameter = class(TFloatMaterialParameter, IFloatParameter)
  private
    function GetValue: Single;
    procedure SetValue(const Value: Single);
  end;

  TNeedConvertedValueEvent = procedure (Sender: TObject; Read: boolean; var v: single) of object;

  TFloatMaterialParameterWithConverter = class(TFloatMaterialParameter, IFloatConverter)
  private
    FOnNeedValue: TNeedConvertedValueEvent;
    procedure ConvertedValue(Read: boolean; var Value: single);
  protected
    procedure Setup;override;
  public
    property OnNeedConvertedValue: TNeedConvertedValueEvent read FOnNeedValue write FOnNeedValue;
  end;

  TFloat3MaterialParameter = class(TMaterialParameter, IFloat3Parameter)
  private
    FValue: TAffineVector;
    PValue: PAffineVector;
    function GetValue: TAffineVector;
    procedure SetValue(const Value: TAffineVector);
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: TAffineVector read GetValue write SetValue;
    property ValuePointer: PAffineVector read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsFloat3: TAffineVector;override;
    function AsFloat4: TVector;override;
    function AsString(short: boolean): string;override;

    function GetShaderValue: string;override;
    function GetShaderDefaultValue: string;override;

    procedure SetAsFloat3(const aValue: TAffineVector);override;
    procedure SetAsFloat4(const aValue: TVector);override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
  end;

  TColorMaterialParameter = class(TFloat3MaterialParameter, IColorParameter)
  private
  protected
    procedure Setup;override;
    procedure SetColor(color: Cardinal);
    function GetColor: Cardinal;
  public
    property Color: Cardinal read GetColor write SetColor;
  end;

  TFlagsMaterialParameter = class(TIntegerMaterialParameter, IFlagsParameter)
  private
    FNames: array [TCeramicLanguage] of array of string;
    FVisibility: array of boolean;
    FBits: array of Integer;
    procedure SetFlag(Index: integer; NewValue: boolean);
    function GetFlag(Index: integer): boolean;
    function NumberOfUsedBits: integer;
    function GetFlagName(Index: integer): string;
    function GetFlagVisibility(Index: integer): boolean;
    function GetFlagBit(Index: integer): Integer;
    function FindFlagByName(const LangId: TCeramicLanguage; const name: string; var flagIndex: Integer): boolean;
    function Pack: string;
    procedure UnPack(aValue: string);
    function PackExtraNames: String;
    procedure UnPackExtraNames(aValue: string);
    function PackBits: string;
    procedure UnpackBits(const v: string);
    function PackVis: string;
    procedure UnpackVis(const v: string);
  protected
    procedure PlaceDataAt(p: pointer);override;
    procedure Setup;override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure SetFlagsNames(const LanguageId: TCeramicLanguage; names: array of string);
    procedure SetFlagsVisibility(vis: array of boolean);
    procedure SetFlagVisibility(Index: integer; newVisibility: boolean);
    procedure SetFlagsBits(bits: array of Integer);
    procedure StoreValue(var aValue: Integer);
    procedure SetFlagsByName(const LangID: TCeramicLanguage; const Script: string);
    procedure SetFlagByName(const aName: string; const aValue: boolean);
    function GetFlagByName(const aName: string): boolean;
  end;

  TFloat4MaterialParameter = class(TMaterialParameter, IFloat4Parameter)
  private
    FValue: TVector;
    PValue: PVector;
    function GetValue: TVector;
    procedure SetValue(const Value: TVector);
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: TVector read GetValue write SetValue;
    property ValuePointer: PVector read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsFloat3: TAffineVector;override;
    function AsFloat4: TVector;override;
    function AsString(short: boolean): string;override;

    function GetShaderValue: string;override;
    function GetShaderDefaultValue: string;override;

    procedure SetAsFloat3(const aValue: TAffineVector);override;
    procedure SetAsFloat4(const aValue: TVector);override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
  end;

  TMatrixMaterialParameter = class(TMaterialParameter, IMatrixParameter)
  private
    FValue: TMatrix;
    PValue: PMatrix;
    function GetValue: TMatrix;
    procedure SetValue(const Value: TMatrix);
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: TMatrix read GetValue write SetValue;
    property ValuePointer: PMatrix read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsMatrix: TMatrix;override;
    function AsString(short: boolean): string;override;
    function GetShaderValue: string;override;
    procedure SetAsMatrix(const aValue: TMatrix);override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
  end;

  TTexTransformMaterialParameter = class(TMaterialParameter, ITexTransformParameter)
  private
    FValue: TTexTransformSettings;
    PValue: PTexTransformSettings;
    FMatrixCashe: TMatrix;
    PMatrixCashe: PMatrix;
    function GetValue: TTexTransformSettings;
    procedure SetValue(const Value: TTexTransformSettings);
    function GetMatrixCashe: TMatrix;
    function GetMatrixCashePointer: PMatrix;
    function AngleEquals(Angle1, Angle2: Double): Boolean;
    function TransformEquals(Value1, Value2: TTexTransformSettings): Boolean;
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: TTexTransformSettings read GetValue write SetValue;
    property ValuePointer: PTexTransformSettings read PValue write PValue;
    property MatrixCashe: TMatrix read GetMatrixCashe;
    property MatrixCashePointer: PMatrix read GetMatrixCashePointer;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsTexTransform: TTexTransformSettings; override;
    function AsString(short: boolean): string; override;
    function AsMatrix: TMatrix; override;
    function GetRenderMatrix: TMatrix;

    procedure SetAsTexTransform(const value: TTexTransformSettings); override;
    procedure SetAsMatrix(const m: TMatrix); override;

    function GetShaderValue: string; override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
  end;

  TTexWrapModeMaterialParameter = class(TMaterialParameter, ITexWrapModeParameter)
  private
    FValue: TTexWrapMode;
    PValue: PTexWrapMode;
		procedure SetValue(const aValue: TTexWrapMode);
		function GetValue: TTexWrapMode;
    function IsEqual(const aValue: TTexWrapMode): Boolean;
  protected
    procedure Setup; override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override;
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo); override;
    procedure ReadFromFiler(ReadInfo: TReadInfo); override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter); override;
    property Value: TTexWrapMode read GetValue write SetValue;
    property ValuePointer: PTexWrapMode read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter); override;
    procedure CopyTo(conv: IMaterialConverter); override;
    function AsString(short: boolean): string; override;
    procedure SetAsString(const value: string); override;
    function AsTexWrapMode: TTexWrapMode; override;
    procedure SetAsTexWrapMode(const value: TTexWrapMode); override;
    //function GetShaderValue: string; override;
    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean; override;
  end;

  TTextureWrapMode = (wmClamp, wmWrap);

//Текстурный параметр. Содержит положение текстуры в атласе и масштаб текстурных координат
  TTextureMaterialParameter = class(TMaterialParameter, ITextureParameter)
  private
    FWrapMode: TTextureWrapMode;
    FValue: TTextureValue;
    PValue: PTextureValue;
    FEnabled: boolean;
    function GetValue: TTextureValue;
    procedure SetValue(const Value: TTextureValue);
    function GetEnabled: boolean;
    procedure SetEnabled(const Value: Boolean);
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: TTextureValue read GetValue write SetValue;
    property ValuePointer: PTextureValue read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;
    property Enabled: boolean read FEnabled write SetEnabled;

    function GetShaderValue: string;override;
    function GetShaderDefaultValue: string;override;

    function AsTextureValue: TTextureValue;override;
    function AsString(short: boolean): string;override;
    function GetAtlasPositionForShader: string;
    function GetAtlasScaleForShader: string;
    procedure SetAsTextureValue(const aValue: TTextureValue);override;
    procedure SetAtlas(atlas: TMaterialTextureAtlas; textures: TSimpleTexturesList);override;
    function EqualTo(p: TMaterialParameter): boolean;override;
    procedure TuneParameter;
  end;

  TStringMaterialParameter = class(TMaterialParameter, IStringParameter)
  private
    FValue: string;
    PValue: Pstring;
    function GetValue: string;
    procedure SetValue(const Value: string);
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override;
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: string read GetValue write SetValue;
    property ValuePointer: PString read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsString(short: boolean): string;override;
    function GetShaderValue: string;override;
    procedure SetAsString(const aValue: string);override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
  end;


  IMonoMaterialParameter = interface(ISomeParameter)
  ['{75B56B6E-DD2A-4CEB-8762-C999C46647AC}']
    procedure SetValue(const Value: string);
    function GetValue: string;
    procedure CreateMaterial(const mat: TMaterial; const newMatName: string; const withTextures: Boolean = True);
    procedure Rename(const newMatName: string);
    function GetMonoMaterialInd(): Integer;
    function GetMatLib(): IMaterialLibrary;
    function GetMonoMaterial(): TMaterial;
    function GetEnabled(): Boolean;
    function ClassFilter: TClass;
  end;

  TMonoMaterialParameter = class(TMaterialParameter, IMonoMaterialParameter)
  private
    FValue: string;
    PValue: PString;
    FMonoMaterialInd: Integer;
    FMatLib: TMaterialList;
    FClassFilter: TClass;
    function GetValue: string;
    procedure SetValue(const Value: string);
    function GetMonoMaterialInd(): Integer;
    function ClassFilter: TClass;
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject; override;
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: string read GetValue write SetValue;
    property ValuePointer: PString read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsMonoMaterial: TMaterial;override;
    function AsString(short: boolean): string;override;
    function GetShaderValue: string;override;
    procedure SetAsMonoMaterial(const aValue: TMaterial);override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
    function GetMatLib(): IMaterialLibrary;
    procedure Rename(const newMatName: string);
    function GetMonoMaterial(): TMaterial;
    function GetEnabled(): Boolean;
    procedure CreateMaterial(const mat: TMaterial; const newMatName: string; const withTextures: Boolean = True);
  end;

  TReflMaterialParameter = class(TMaterialParameter, IReflParameter)
  private
    FValue: TReflStruct;
    PValue: PReflStruct;
    function GetValue: TReflStruct;
    procedure SetValue(const Value: TReflStruct);
  protected
    procedure Setup;override;
    procedure PlaceDataAt(p: pointer);override;
    procedure GetDataFrom(p: pointer);override;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    procedure Assign(src: TMaterialParameter);override;
    procedure AssignValue(src: TMaterialParameter);override;
    property Value: TReflStruct read GetValue write SetValue;
    property ValuePointer: PReflStruct read PValue write PValue;
    procedure ExtractFrom(conv: IMaterialConverter);override;
    procedure CopyTo(conv: IMaterialConverter);override;

    function AsReflStruct: TReflStruct;override;
    function AsString(short: boolean): string;override;
    function GetShaderValue: string;override;
    procedure SetAsReflStruct(const aValue: TReflStruct);override;

    procedure Dump;override;
    function EqualTo(p: TMaterialParameter): boolean;override;
    function ReflStructEquals(const val1, val2: TReflStruct): Boolean;
  end;

  TMaterialTexture = class;

  TTexelComputeFunc = function (const TextureSize: TTextureSize): single of object;

  TTextureRef = class(TThreadSafeWeakRef)
  private
    FOwn: boolean;
  public
    constructor Create(const aRefTo: TMaterialTexture; Own: boolean);
    destructor Destroy;override;
    function LockRef: TMaterialTexture;
  end;

  TSimpleTexturesListItem = class(TSimpleInterfacedObject, IUnknown, IClusteredIO, IWeakRefsHolder, IGUID)
  private
    FOwner: TSimpleTexturesList;
    FData: TTextureRef;
    FDirtFlag: Boolean;
    FLocalPixelHash: string;
		FWeakRefs: IWeakRefsHolder;
    FGUID: TGUID;
		property WeakRefs: IWeakRefsHolder read FWeakRefs implements IWeakRefsHolder;
    procedure SetData(const Value: TMaterialTexture);
    procedure SetOwnedData(const Value: TMaterialTexture);
    function GetData: TMaterialTexture;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); overload;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); overload;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); overload;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); overload;
    function EqualTo(t: TSimpleTexturesListItem): boolean;
    procedure WriteToFiler(WriteInfo: TWriteInfo);
    procedure ReadFromFiler(ReadInfo: TReadInfo);
    procedure NotifyChange;
    function GetDataOwner: boolean;
    procedure SetDataOwner(const Value: boolean);
    procedure SetDataRef(const obj);
  public
    TextureName: string;
    TexelScale: single;
    constructor Create(aOwner: TSimpleTexturesList);
    destructor Destroy;override;
    procedure SaveObject(var SaveInfo: TSaveInfo); {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;
    property Data: TMaterialTexture read GetData write SetData;          //Просто ссылка
    property OwnedData: TMaterialTexture read GetData write SetOwnedData;//Стать владельцем экземпляра (т.е. удалит в деструкторе)
    property DataOwner: boolean read GetDataOwner write SetDataOwner;
    procedure PreloadTexture;
    function GetTextureID: string;
    procedure Assign(src: TSimpleTexturesListItem);
    procedure ExecCommand(cmd: cardinal; params: TCommandParams);
    function GetValidTextureName: string; //тут можно подменить имя
    function IsValid: Boolean;
    function GetOwner: TSimpleTexturesList;
    function ReadDataForRender(var aData: pointer; var aDataLen: integer): Boolean;
    procedure FinalizeReading;
		function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function GetGlobalUniqueIdentifier: TGUID;
  end;

  TSimpleTexturesList = class(TInterfacedObjectList, IUnknown, IClusteredIO, ITexturesList)
  private
    FOwner: TMaterial;
    FOnChange: TNotifyEventRef;
    function GetItem(index: integer): TSimpleTexturesListItem;
    function GetSampler(texName: string; out sampler: ITextureSampler): boolean;
    procedure SetSampler(texName: string; const sampler: ITextureSampler; OwnData: boolean = False);
    function GetValue(index: string): TMaterialTexture;
    procedure SetValue(index: string; const Value: TMaterialTexture);
    procedure NotifyChange;
    function GetOnChange: TNotifyEvent;
    procedure SetOnChange(const Value: TNotifyEvent);
  protected
    function AddObject(aTextureName: string; aTextureObject: TMaterialTexture): TSimpleTexturesListItem;
    function Find(TexName: string; var index: integer): boolean;
    function HasItem(const aTextureName: string): Boolean;
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); overload;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); overload;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); overload;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); overload;
    procedure WriteToFiler(WriteInfo: TWriteInfo);
    procedure ReadFromFiler(ReadInfo: TReadInfo);
  public
    Cache: array of record
      sampler: ITextureSampler;
      texelScale: single;
    end;
    constructor Create(const aOwner: TMaterial);
    destructor Destroy;override;
    procedure Assign(src: TList);
    procedure AssignFrom(src: TSimpleTexturesList);
    procedure AddTexture(aTextureID: string; aTexture: TMaterialTexture);overload;
    procedure SetTexture(aTextureID: string; aTexture: TMaterialTexture; OwnData: boolean);
    procedure GetTexture(index: integer; var obj);overload;
    procedure GetTexture(index: integer; var obj; var aTextureID: string);overload;
    function FindTextureItem(aName: string; var obj: TSimpleTexturesListItem): boolean;
    procedure ReadValues(params: TMaterialParameters; conv: IMaterialConverter);
    procedure WriteValues(params: TMaterialParameters; conv: IMaterialConverter);
    procedure AddToParameters(const params: TMaterialParameters);
    procedure SetupCache(TextureNames: array of string; Transform: array of PMatrix);
    property Items[index: integer]: TSimpleTexturesListItem read GetItem;default;
    property Values[index: string]: TMaterialTexture read GetValue write SetValue;
    procedure PreloadTextures;
    procedure SaveAll(Path: string);
    function EqualTo(t: TSimpleTexturesList): boolean;
    function ListTextures: string;
    function RemoveValue(aName: string): Boolean;
    property OnChange: TNotifyEvent read GetOnChange write SetOnChange;
    function RenameValue(aOldName, aNewName: string): boolean;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams);
    function GetOwner: TMaterial;
    procedure RemoveEmptyItems;
  end;

  TMaterialParamsTypeLibrary = class;
  TParameterFilterFunc = function (const p: TMaterialParameter): boolean;

//Параметры материала
  TMaterialParameters = class(TInterfacedObjectList, IUnknown, IChangeNotification)
  private
    FOwner: TObject;
    FUpdateCounter: integer;
    FOnMaterialChanged, FOnNotification: TNotifyEvent;
    FGroupNames: TStringList;
    FDirtFlag: Boolean;
    procedure SetNotification(Event: TNotifyEvent2);
    function IndexOf(ParamName: string): integer;
    function NewParameter(aName: string; aClass: TMaterialParameterClass): TMaterialParameter;
    procedure ReSort;                                                                              //Сортирует параметры так, чтобы они плотно упаковывались кратно float4
    procedure CountOffsets;                                                                        //Вычисляет положение параметра после упаковки
    function GetIntParam(index: string): TIntegerMaterialParameter;
    function GetFloat3Param(index: string): TFloat3MaterialParameter;
    function GetFloat4Param(index: string): TFloat4MaterialParameter;
    function GetColorParam(index: string): TColorMaterialParameter;
    function GetFloatParam(index: string): TFloatMaterialParameter;
    function GetMatrixParam(index: string): TMatrixMaterialParameter;
    function GetTextureParam(index: string): TTextureMaterialParameter;
    function GetReflMaterialParam(index: string): TReflMaterialParameter;
    function ExtractTextureIDs: TStringList;                                                       //Выдает список имен текстурных параметров
    function GetShaderValue(index: string): string;                                                //Выдает код положения параметра в упакованном буфере материалов для шейдера
    procedure ParameterChanged(Sender: TObject);
  public
    Cache: array of TMaterialParameter;                                                            //Кэш выборки группы параметров по именам (обновляется при вызове SetupCache)
    constructor Create(aOwner: TObject); overload;
    destructor Destroy;override;
    function NewInteger(aName: string): TIntegerMaterialParameter;
    function NewIntEnum(aName: string): TIntEnumMaterialParameter;
    function NewFloat(aName: string): TFloatMaterialParameter;
    function NewFloatWithConverter(aName: string): TFloatMaterialParameterWithConverter;
    function NewVoxelAngle(aName: string): TVoxelAngleMaterialParameter;
    function NewFloat3(aName: string): TFloat3MaterialParameter;
    function NewFloat4(aName: string): TFloat4MaterialParameter;
    function NewColor(aName: string): TColorMaterialParameter;
    function NewFlags(aName: string): TFlagsMaterialParameter;
    function NewMatrix(aName: string): TMatrixMaterialParameter;
    function NewTexture(aName: string): TTextureMaterialParameter;
    function NewString(aName: string): TStringMaterialParameter;
    function NewMonoMaterial(aName: string): TMonoMaterialParameter;
    function NewTexTransform(aName: string): TTexTransformMaterialParameter;
    function NewReflStruct(aName: string): TReflMaterialParameter;
    function NewTexWrapMode(aName: string): TTexWrapModeMaterialParameter;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure ShowAll;
    procedure AppendMissing(src: TMaterialParameters; CanMove: boolean);

    function FindParameter(aName: string; var p): boolean;overload;
    function FindParameter(aName: string): TMaterialParameter;overload;
    function RemoveParameter(aName: string): boolean;
    procedure JustDelete(const Index: Integer);

    function Parameter(const aIndex: Integer): TMaterialParameter;
    property IntegerParameter[index: string]: TIntegerMaterialParameter read GetIntParam;
    property FloatParameter[index: string]: TFloatMaterialParameter read GetFloatParam;
    property Float3Parameter[index: string]: TFloat3MaterialParameter read GetFloat3Param;
    property Float4Parameter[index: string]: TFloat4MaterialParameter read GetFloat4Param;
    property ColorParameter[index: string]: TColorMaterialParameter read GetColorParam;
    property MatrixParameter[index: string]: TMatrixMaterialParameter read GetMatrixParam;
    property TextureParameter[index: string]: TTextureMaterialParameter read GetTextureParam;
    property ReflMaterialParameter[index: string]: TReflMaterialParameter read GetReflMaterialParam;
    property ShaderValue[index: string]: string read GetShaderValue;

    function TotalNumFloats: integer;                                                              //Число float-ов, необходимых для хранения параметров данного материала
    procedure PackAt(dst: pointer);                                                                //Складывает данные параметров по указанному адресу
    procedure PackAt2(dst: pointer);                                                                //Складывает данные параметров по указанному адресу (v2)
    procedure UnpackFrom2(src: pointer);

    procedure Assign(src: TMaterialParameters);virtual;                                            //Копирует параметры
    procedure AssignFrom(src: TMaterialParameters);                                                //Копирует совпадающие по имени параметры (то же что и ReadValues)
    procedure AssignValuesFrom(src: TMaterialParameters; Filter: TParameterFilterFunc = nil; const RelinkRefs: boolean = false);      //Копирует только значения совпадающих по имени параметров
    procedure AssignOptionalParameters(src: TMaterialParameters);                                  //Копирует только опциональные параметры
    procedure ReadValues(conv: IMaterialConverter);                                                //Читает параметры другого материала через конвертер
    procedure WriteValues(conv: IMaterialConverter);                                                //Пишет параметры другого материала через конвертер
    procedure UpdateValues(conv: IMaterialConverter);                                                //Пишет параметры другого материала через конвертер

    property OnMaterialChanged: TNotifyEvent read FOnMaterialChanged write FOnMaterialChanged;
    property Owner: TObject read FOwner;
    function GetMaterial: TMaterial;

    procedure SetupCache(parameters: array of string);                                             //Кэширует выборку параметров по их именам (для быстрого доступа к ним)

    procedure SaveObject(var SaveInfo: TSaveInfo); override; {ok}
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject; override;

//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); overload;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); overload;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); overload;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); overload;
    procedure WriteToFiler(WriteInfo: TWriteInfo);
    procedure ReadFromFiler(ReadInfo: TReadInfo);

    procedure Dump;
    procedure DumpToClipboard;
    function CheckLinks: string;
    procedure SetAtlas(atlas: TMaterialTextureAtlas; textures: TSimpleTexturesList);

    procedure AddTypes(aLib: TMaterialParamsTypeLibrary);

    property GroupNames: TStringList read FGroupNames;

    function EqualTo(p: TMaterialParameters): boolean;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams);
    function ListTextures: string;
    function ListParams(CopyToClipboard: boolean = false): string;

    function UpgradeIntegerParameter(const OldName, NewName: string; const defaultValue: Integer = 0): TIntegerMaterialParameter;
    function UpgradeIntEnumParameter(const OldName, NewName: string; const defaultValue: Integer = 0): TIntEnumMaterialParameter;
    function UpgradeFlagsParameter(const OldName, NewName: string; const defaultValue: Cardinal = 0): TFlagsMaterialParameter;
    function UpgradeFloatParameter(const OldName, NewName: string; const defaultValue: Single = 0.0): TFloatMaterialParameter;
    function UpgradeFloat3Parameter(const OldName, NewName: string; const defaultValue1: Single = 0.0; const defaultValue2: Single = 0.0; const defaultValue3: Single = 0.0): TFloat3MaterialParameter;
    function UpgradeFloat4Parameter(const OldName, NewName: string; const defaultValue1: Single = 0.0; const defaultValue2: Single = 0.0; const defaultValue3: Single = 0.0; const defaultValue4: Single = 0.0): TFloat4MaterialParameter;
    function UpgradeColorParameter(const OldName, NewName: string; const defaultValue1: Single = 0.0; const defaultValue2: Single = 0.0; const defaultValue3: Single = 0.0): TColorMaterialParameter;
    function UpgradeMatrixParameter(const OldName, NewName: string; const defaultValue: PMatrix = nil): TMatrixMaterialParameter;
    function UpgradeTextureParameter(const OldName, NewName: string): TTextureMaterialParameter;
    function UpgradeTexTransform(const OldName, NewName: string; const defaultValue: TTexTransformSettings): TTexTransformMaterialParameter;
    function UpgradeReflParameter(const OldName, NewName: string; const defaultValue: TReflStruct): TReflMaterialParameter;
    function UpgradeTexWrapModeParameter(const OldName, NewName: string; const defaultValue: TTexWrapMode): TTexWrapModeMaterialParameter;
    function UpgradeMonoMaterialParameter(const OldName, NewName: string): TMonoMaterialParameter;
  end;

  TPointAAInfo = record
    ObjectID: integer;
    Material: TMaterial;
  end;

  TSurfacePointDebugInfo = class(TInterfacedObject, ISurfacePointDebugInfo)
  private
    FMsgs: TStringList;
  public
    constructor Create;
    destructor Destroy;override;
    procedure Paint(Painter: I3DCanvasPainter);virtual;abstract;
    procedure AddRay(const a, b, color: TAffineVector);virtual;abstract;
    function GetInfo: TObject;
    procedure AddMessage(const msg: string);
    function GetText: string;
  end;

//Точка какой-то поверхности. Содержит все, что доступно материалу для его вычисления
  TSurfacePoint = class
  public
    ResultColor: TVector;                                                                    //Сюда запишется результирующий цвет
    RecurseCount: integer;                                                                   //Индекс рекурсии (чтоб не зацикливалось)
    BackFace, Simple: boolean;                                                               //Флаг, что обратная грань
    Log: IDbgLog;
    function Material: TMaterial;virtual;abstract;                                           //Указатель на материал поверхности
    function WorldPosition(aIndex: integer = 0; RayDirection: PAffineVector = nil): TAffineVector;virtual;abstract;            //Мировая координата точки поверхности
    function EyePosition: TAffineVector;virtual;abstract;                                     //Мировое положение наблюдателя (на самом деле положение начала луча View)
    function Normal: TAffineVector;virtual;abstract;                                         //Нормаль поверхности (не регламентировано какая)
    function MaterialNormal: TAffineVector;                                                   //Нормаль поверхности с учетом материала
    procedure SetNormal(const n: TAffineVector);virtual;abstract;                            //Позволяет задать конкретную нормаль поверхности
    function Albedo: TAffineVector;virtual;abstract;                                         //Альбедо цвет
    procedure SetAlbedo(const a: TAffineVector);virtual;abstract;                            //Позволяет задать альбедо цвет
    function TangentSpace: TAffineMatrix;virtual;abstract;                                   //Перевод из тангет спейс в мир
    function View: TAffineVector;virtual;abstract;                                           //Направление взгляда (на поверхность)
    function NegView: TAffineVector;virtual;abstract;                                        //Обратное направление вгляда (с поверхности в точку, откуда пуляли луч)
    function TexCoord: TAffineVector;virtual;abstract;                                       //Текстурная координата
    function DirectLightsCount: integer;virtual;abstract;                                    //Количество аналитических источников
    function GetLightDirection(index: integer): TAffineVector;virtual;abstract;              //Направление i-го аналитического источника
    function GetLightVisibleAngle(index: integer): single;virtual;abstract;                   //Угловой размер источника света из точки поверхности (на самом деле тангенс половинного угла, т.к. именно он подставляется в апертуру ConeRay)
    function GetLightColor(index, EvalMode: integer): TAffineVector;virtual;abstract;         //Цвет источника берется из материала источника
    function DistanceToLight(index: integer): single;virtual;abstract;                       //Расстояние от EyePosition до поверхности (без учета переотражений)
    function Reflection(const aNormal: TAffineVector): TAffineVector;                        //Направление отраженного вектора
    function Refraction(const aNormal: TAffineVector; RefractionIndex: single): TAffineVector;//Направление преломленного вектора с учетом задности грани
    function TriAttribute(index: integer): integer;virtual;abstract;
//Пускает конилуч
    function ConeRay(const RayStart, RayDir: TAffineVector; Aperture: single;
      EvalMode: integer; OffsetInPercentOfVoxelSize: single = 1.0; IgnoreAutoFill: boolean = false; InitialOpacity: single = 0.0): TVector;virtual;abstract;
//Пускает луч трейсера. Возвращает точку поверхности, куда попал луч
    function KdRay(const RayStart, RayDir: TAffineVector; Face: integer; ViewRes: single; Ortho: boolean; var SurfacePoint: TSurfacePoint; MaxDist: single = Infinity): boolean;virtual;abstract;
//Пускает смешанный луч
    function MixedRay(const RayStart, RayDir: TAffineVector; Aperture: single;
      Face: integer; ViewRes: single; Ortho, Simple: boolean;
      EvalMode, RecurseCount: integer; MixStart, MixEnd, KdPower: Single;
      IgnoreAutoFill: boolean = false): TVector;virtual;abstract;
    function GetShadow(index: integer): single;virtual;abstract;                             //Тень от i-го источника в диапазоне 0-1
    function DistanceFromEyeForLod: single;virtual;abstract;                                 //Расстояние из глаза до точки с учетом переотражений для вычисления лодов
    function ViewResolution: single;virtual;abstract;                                         //Возвращает разрешение виртуальной камеры
    function IsOrthogonalView: boolean;virtual;abstract;                                     //Возвращает тип проекции
    function GetTexelSize: single;virtual;abstract;                                           //Возвращает отношение текстурной площади треугольника к реальной
    function GetDebugInfo(Aperture: single): ISurfacePointDebugInfo;virtual;abstract;
    procedure SetLog(const aLog: IDbgLog);
  end;

  ILayeredSurfacePoint = interface
  ['{A7949038-4ABB-49F9-94B7-D7EAAA65891A}']
    function GetInteger(index: integer): Integer;
    function GetVector(index: integer): TVector;
    procedure SetInteger(index: integer; const Value: Integer);
    procedure SetVector(index: integer; const Value: TVector);

    property Vectors[index: integer]: TVector read GetVector write SetVector;
    property Integers[index: integer]: Integer read GetInteger write SetInteger;
  end;

  TMaterialTextures = class;

  TMaterialAttributes = class(TStringList)
  end;

//Материал
  TMaterial = class(TSimpleInterfacedObject, IUnknown, IClusteredIO)
  private
    FOwner: TObject;
    FName: string;                                                              //Имя
    FParameters: TMaterialParameters;                                           //Список параметров
    FMetaData: TMetaStorage;                                                    //Опциональные параметры
    FTextures: TSimpleTexturesList;                                             //Список используемых текстур (соответствует списку параметров)
    FOnMaterialChanged: TNotifyEvent;
    FAttribs: TMaterialAttributes;
    FVersion: Integer;
    FTexDirtFlag: Boolean;
    procedure ParameterChanged(Sender: TObject);
    function GetAttribs: TMaterialAttributes;
    function GetName: string;
    procedure SetName(const Value: string);
    function GetFriendlyName: string;
    procedure SetFriendlyName(const Value: string);
    function GetSetID: string;
    function GetSetIndex: integer;
    procedure SetSetID(const Value: string);
    procedure SetSetIndex(const Value: integer);
  protected
    FType: integer;                                                             //Тип материала
    procedure InitParams;virtual;abstract;
    function UnknownParameter(const aName, aClass: string; var LoadInfo: TLoadInfo): TObject;virtual;
    procedure Upgrade;virtual;
    procedure Downgrade;virtual;
  public
    constructor Create(aOwner: TObject);overload;virtual;
    constructor CreateWithoutVersion(aOwner: TObject);
    destructor Destroy;override;
    procedure ValidateVersion;virtual;
    function RecreateParameters: boolean;
    procedure Assign(src: TMaterial);virtual;                                   //Копирование материала
    property Parameters: TMaterialParameters read FParameters;
    property MetaData: TMetaStorage read FMetaData;
{Список текстур. Это простой список, т.е. он содержит указатели на просто какие-то объекты
 (бывает еще список TMaterialTextures, дак вот он другой.) Список не контейнерный, он состоит из ссылок, например одна и та же текстура
  может лежать в таких списках у нескольких материалов
 При использовании EvalMaterialAt эти объекты должны реализовывать интерфейс ITextureSampler, иначе текстуры накладываться не будут (Можно использовать класс TMaterialTexture)
 При работе с шейдерами текстура берется из атласа, поэтому содержимое этого списка вообще не имеет значения,
  а имеют зачения одноименные параметры в списке параметров(Parameters), которые указывают где в атласе лежит соответствующая текстура
To Do:
 Наверное сделаю, что если список состоит из текстур из TTextureAtlas.AtlasContent, то параметры положений текстур в атласе будут обновляться автоматически (т.к. эти текстуры знают свое положение в атласе)}
    property Textures: TSimpleTexturesList read FTextures;
    property Name: string read GetName write SetName;
    property OnMaterialChanged: TNotifyEvent read FOnMaterialChanged write FOnMaterialChanged;
    property Owner: TObject read FOwner write FOwner;
    property MType: integer read FType;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);virtual;                    //Вычисление материала в заданной точке
    procedure Dump;
    function HiGlossy: boolean;virtual;  //Для автосглаживания
    function GetNormal(aPoint: TSurfacePoint): TAffineVector;virtual;                             //Нормаль точки с учетом свойств материала (учет бампа)
    function GetAAInfo(aPoint: TSurfacePoint): TPointAAInfo;                                      //Инфа необходимая для смарт сглаживания
    function QueryAAInfoEx(aPoint: TSurfacePoint): Cardinal;virtual;                              //Рекурсивный запрос инфы для сглаживания
    function GetDebugInfo(aPoint: TSurfacePoint): ISurfacePointDebugInfo;virtual;
    procedure DebugTrace(aPoint: TSurfacePoint; const debugInfo: ISurfacePointDebugInfo);virtual;
    function IsTransparent: boolean;virtual;                                                      //Отбрасывает ли тень
    function IsLightSource: boolean;virtual;
    function GetEmissive: TAffineVector;virtual;                                                  //Цвет самоизлучения
    class function GetShaderEmissive(const m: string): string;virtual;
    function GetAttenuation: Single;virtual;
    function GetEmissionLevel: Single;virtual;
    class function GetShaderAttenuation(const m: string): string;virtual;
    property Attributes: TMaterialAttributes read GetAttribs;
    function MIndex: integer;
    procedure SetAtlas(aAtlas: TMaterialTextureAtlas);virtual;
    procedure SaveObject(var SaveInfo: TSaveInfo); virtual;{ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject; virtual;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); overload;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); overload;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); overload; virtual;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); overload; virtual;
    function EqualTo(m: TMaterial): boolean;
    procedure WriteToFiler(WriteInfo: TWriteInfo); virtual;
    procedure ReadFromFiler(ReadInfo: TReadInfo; ReadType: boolean = false); virtual;
    function GetMaterialLibrary(out ml: IMaterialLibrary): boolean;
    function IsMultiMaterial(): Boolean; virtual;
    property Version: Integer read FVersion;
    procedure SetVersion(const v: Integer);
    procedure DropVersion;
    function GetIntegerParamValue(aParamName: string; const defValue: integer): integer;
    function GetFloatParamValue(aParamName: string; const defValue: single): single;
    function GetFloat3ParamValue(aParamName: string; const defValue: TAffineVector): TAffineVector;
    function GetFloat4ParamValue(aParamName: string; const defValue: TVector): TVector;
    function GetColorParamValue(aParamName: string; const defValue: TAffineVector): TAffineVector;
    function GetMatrixParamValue(aParamName: string; const defValue: TMatrix): TMatrix;
    function GetStringParamValue(aParamName: string; const defValue: string): string;
    function GetTexTransformParamValue(aParamName: string; defValue: TTexTransformSettings): TTexTransformSettings;
    procedure ResetTexturesTo(TexList: ITextureAtlas);
    property FriendlyName: string read GetFriendlyName write SetFriendlyName;
    property SetID: string read GetSetID write SetSetID;
    property SetIndex: integer read GetSetIndex write SetSetIndex;
    property TexDirtFlag: Boolean read FTexDirtFlag write FTexDirtFlag;
    procedure DeleteUnusedMaterials; virtual;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams); virtual;
    function HasGUIDedResources: Boolean;
    function Clone(aOwner: TObject): TMaterial;
    function GetDirectName: string;
    function GetCompoundName: string;
  end;

//Тип материала. Определяет поведение материала и необходимые параметры
  TMaterialType = class(TMaterial)
  protected
    procedure InitParams;override;
    procedure SetupParametersList;virtual;
  public
    constructor Create(aOwner: TObject);override;
    procedure ValidateVersion;override;
    class function GetTypeIndex: integer;virtual;abstract;
    function GetShaderEvaluationCase: string;virtual;
  end;

  TMaterialTypeClass = class of TMaterialType;

  TLightMaterial = class;

  TPBRMaterial = class(TMaterialType)
  private
  protected
    procedure Upgrade;override;
    procedure CalcPBRParams;virtual;
    function PBRParamsIsDefault: Boolean;
  public
  end;

  TDiffuseMaterial = class(TPBRMaterial, IMonoMaterialContainer)
  private
    FMatLib: TMaterialList;
    procedure RWConvertedValue(Sender: TObject; Read: boolean; var v: single);
    procedure ConvertFlags;
    function GetMonoMaterialList: TMaterialList;
  protected
    FLightMaterial: TMonoMaterialParameter;
    FAmbient, FDiffuse, FSpecular, FAlbedo, FRefraction, FEmission: TColorMaterialParameter;
    FRefractionIndex, FOpacity, FOldOpacity, FRoughness,
    FBlur, FAmbientLevel, FDiffuseLevel, FSpecularLevel, FRefractionLevel, FEmissionLevel,
    FSpecularBlur, FRefractionBlur, FSpecularFresnel, FSpecularKdPower, FRefractionKdPower,
    FAlbedoLevel, FTentacle, FEmissionAtt: TFloatMaterialParameter;
    FSpecularMixStart, FSpecularMixEnd, FRefractionMixStart, FRefractionMixEnd: TFloatMaterialParameterWithConverter;
    FOldLevels: TFloat3MaterialParameter;
    FOldAmbient, FOldSpecular, FOldDiffuse: TColorMaterialParameter;
    FReflectionFlags, FRefractionFlags, FFlags: TFlagsMaterialParameter;
    procedure SetupParametersList;override;
    function EvalAmbientColor5(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalAmbientColor5f(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalAmbientColor13(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalAmbientColor5Mixed(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalAmbientColor13Mixed(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalAmbientColor(mode: integer; sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalDirectLights(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalDirectLightsCRM(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalSpecularColor(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalRefractionColor(sp: TSurfacePoint; EvalMode: integer): TVector;
    function EvalHiReflections(aPoint: TSurfacePoint; EvalMode: integer): TVector;
    function EvalHiRefractions(aPoint: TSurfacePoint; EvalMode: integer): TVector;
    function EvalMixReflections(aPoint: TSurfacePoint; EvalMode: integer): TVector;
    function EvalMixRefractions(aPoint: TSurfacePoint; EvalMode: integer): TVector;
    function UnknownParameter(const aName, aClass: string; var LoadInfo: TLoadInfo): TObject;override;
    procedure Upgrade;override;
    procedure CalcPBRParams;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    class function GetTypeIndex: integer;override;
    function GetShaderEvaluationCase: string;override;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);override;
    function QueryAAInfoEx(aPoint: TSurfacePoint): Cardinal;override;
    function GetDebugInfo(aPoint: TSurfacePoint): ISurfacePointDebugInfo;override;
    procedure DebugTrace(aPoint: TSurfacePoint; const debugInfo: ISurfacePointDebugInfo);override;
    function IsTransparent: boolean;override;
    function IsLightSource: boolean;override;
    function GetAttenuation: Single;override;
    function GetEmissionLevel: Single;override;
    class function GetShaderAttenuation(const m: string): string;override;
    function GetEmissive: TAffineVector;override;
    class function GetShaderEmissive(const m: string): string;override;
    property SpecularLevel: TFloatMaterialParameter read FSpecularLevel;
    property SpecularBlur: TFloatMaterialParameter read FSpecularBlur;
    property LightMaterial: TMonoMaterialParameter read FLightMaterial;

    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveObject(var SaveInfo: TSaveInfo); override;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
                             const ChildClass: string; const ChildID: string): TObject; override;
    procedure WriteToFiler(WriteInfo: TWriteInfo); override;
    procedure ReadFromFiler(ReadInfo: TReadInfo; ReadType: boolean = false); override;
    procedure DeleteUnusedMaterials; override;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams); override;
    procedure ValidateVersion;override;
  end;

  TTextureMaterial = class(TDiffuseMaterial)
  protected
    FBaseMap: TTextureMaterialParameter;
    //FTexMatrix: TMatrixMaterialParameter;
    FTexTransform: TTexTransformMaterialParameter;
    FTexWrapMode: TTexWrapModeMaterialParameter;
    procedure SetupParametersList;override;
    procedure Upgrade;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    class function GetTypeIndex: integer;override;
    function GetShaderEvaluationCase: string;override;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);override;
    procedure SetAtlas(aAtlas: TMaterialTextureAtlas);override;
  end;

  TBumpMaterial = class(TTextureMaterial)
  protected
    FBumpMap: TTextureMaterialParameter;
    procedure SetupParametersList;override;
    procedure Upgrade;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    class function GetTypeIndex: integer;override;
    function GetShaderEvaluationCase: string;override;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);override;
    function GetNormal(aPoint: TSurfacePoint): TAffineVector;override;
  end;

  TBumpOnlyMaterial = class(TDiffuseMaterial)
  protected
    FBumpMap: TTextureMaterialParameter;
//    FTexMatrix: TMatrixMaterialParameter;
    FTexTransform: TTexTransformMaterialParameter;
    FTexWrapMode: TTexWrapModeMaterialParameter;
    procedure SetupParametersList;override;
    procedure Upgrade;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    class function GetTypeIndex: integer;override;
    function GetShaderEvaluationCase: string;override;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);override;
    function GetNormal(aPoint: TSurfacePoint): TAffineVector;override;
    procedure SetAtlas(aAtlas: TMaterialTextureAtlas);override;
  end;

  TDiffuseLightMaterial = class(TDiffuseMaterial)
  protected
    procedure SetupParametersList;override;
  public
    class function GetTypeIndex: integer;override;
    function IsLightSource: boolean;override;
    function IsTransparent: boolean;override;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);override;
  end;

  TRootLightMaterial = class(TMaterialType)
  protected
    FLightType: TIntegerMaterialParameter;
    FLightColor: TColorMaterialParameter;
    FLightPower: TFloatMaterialParameter;
    FEmissionColor: TColorMaterialParameter;
    FEmissionPower: TFloatMaterialParameter;
    FFlags: TFlagsMaterialParameter;
    procedure SetupParametersList;override;
    procedure Upgrade;override;
    function UnknownParameter(const aName, aClass: string; var LoadInfo: TLoadInfo): TObject;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    function IsTransparent: boolean;override;
    function GetEmissive: TAffineVector;override;
    function GetEmissionLevel: Single;override;
    property LightType: TIntegerMaterialParameter read FLightType;
    property Color: TColorMaterialParameter read FLightColor;     
    property EmissionColor: TColorMaterialParameter read FEmissionColor;
    property EmissionPower: TFloatMaterialParameter read FEmissionPower;
    property Power: TFloatMaterialParameter read FLightPower;
    property Flags: TFlagsMaterialParameter read FFlags;
  end;

  TLightMaterial = class(TRootLightMaterial)
  protected
    FAtt: TFloatMaterialParameter;
    FSpotUmbra, FSpotPenumbra, FSpotFalloff: TFloatMaterialParameter;
    FIntFlags: TFlagsMaterialParameter;
    procedure SetupParametersList;override;
    procedure Upgrade;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    class function GetTypeIndex: integer;override;
    function GetShaderEvaluationCase: string;override;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);override;
    function IsLightSource: boolean;override;
    class function GetShaderEmissive(const m: string): string;override;
    function GetAttenuation: Single;override;
    class function GetShaderAttenuation(const m: string): string;override;
    property Attenuation: TFloatMaterialParameter read FAtt;
    property SpotUmbra: TFloatMaterialParameter read FSpotUmbra;
    property SpotPenumbra: TFloatMaterialParameter read FSpotPenumbra;
    property SpotFalloff: TFloatMaterialParameter read FSpotFalloff;
  end;

  TLightMaterialClass = class of TLightMaterial;

  TInternalLightMaterial = class(TLightMaterial)
  public
    class function GetTypeIndex: integer;override;
  end;

  TSunMaterial = class(TLightMaterial)
  private
    FInnerRadius, FOuterRadius: TFloatMaterialParameter;
    function GetShine: boolean;
    procedure SetShine(const Value: boolean);
  protected
    procedure SetupParametersList;override;
    procedure Upgrade;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    class function GetTypeIndex: integer;override;
    function IsLightSource: boolean;override;
    property InnerRadius: TFloatMaterialParameter read FInnerRadius;
    property OuterRadius: TFloatMaterialParameter read FOuterRadius;
    property Shining: boolean read GetShine write SetShine;
  end;

  TWindowMaterial = class(TLightMaterial)
  public
    class function GetTypeIndex: integer;override;
  end;

  TSkyMaterial = class(TRootLightMaterial)
  private
    FAngle1, FAngle2: TFloatMaterialParameter;
  protected
    procedure SetupParametersList;override;
    procedure Upgrade;override;
  public
    constructor Create(aOwner: TObject);override;
    destructor Destroy;override;
    class function GetTypeIndex: integer;override;
    property Angle1: TFloatMaterialParameter read FAngle1;
    property Angle2: TFloatMaterialParameter read FAngle2;
  end;

  TMirrorMaterial = class(TDiffuseMaterial)
  public
    class function GetTypeIndex: integer;override;
//    function GetShaderEvaluationCase: string;override;
  end;

  TGlassMaterial = class(TDiffuseMaterial)
  public
    class function GetTypeIndex: integer;override;
//    function GetShaderEvaluationCase: string;override;
  end;

  TTileMaterial = class(TBumpMaterial)
  public
    class function GetTypeIndex: integer;override;
  end;

  TMultiMaterial = class(TMaterialType, IMonoMaterialContainer)
  private
  protected
    FMatCount: TIntegerMaterialParameter;
    FMatWeights: TTextureMaterialParameter;
    procedure SetupParametersList;override;
    procedure Upgrade;override;
    function UnknownParameter(const aName, aClass: string; var LoadInfo: TLoadInfo): TObject; override;
    function GetMonoMaterialList: TMaterialList;
  public
    FMatLib: TMaterialList;
    FMaterials: array [0..4] of TMonoMaterialParameter;
    constructor Create(aOwner: TObject; mat0: TMaterial; material0Name: string);overload;
    constructor Create(aOwner: TObject);override;
    destructor Destroy(); override;
    class function GetTypeIndex: integer;override;
    function GetShaderEvaluationCase: string;override;
    procedure EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);override;
    function IsMultiMaterial(): Boolean; override;
    function GetMatCount(): Integer;
    function GetMonoMaterial(ind: Integer): TMaterial;
    function GetFirstMonoMaterial: TMaterial;
    function ClearMatLib(): Integer;
    function ConsistMaterial(const lib: IMaterialLibrary; const matName: string; var monoMat: TMonoMaterialParameter): Boolean;
    function IsUsedMaterial(const mat: TMaterial): Boolean;
    procedure SwapMonoMaterials(const ind0, ind1: Integer);
    function ConsistTwoMaterials(const matName: string): Boolean;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveObject(var SaveInfo: TSaveInfo); override;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
                             const ChildClass: string; const ChildID: string): TObject; override;
    procedure WriteToFiler(WriteInfo: TWriteInfo); override;
    procedure ReadFromFiler(ReadInfo: TReadInfo; ReadType: boolean = false); override;
    //procedure Assign(src: TMaterial); override;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams); override;
    procedure ValidateVersion;override;
  end;

  TMaterialTypeLibrary = class;

//Список материалов
  TMaterialList = class(TInterfacedObjectList, IMaterialLibrary, IDirtControl)
  private
    FOwner: TObject;
    FNumFloatsInBlock: integer;
    FOnMaterialChanged: TNotifyEvent;
    procedure MaterialParameterChanged(Sender: TObject);
    function GetCount: Integer;
    function GetItem(const Index: Integer): TMaterial;
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;override;
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
    procedure ParametersChanged;
  public
    constructor Create(aOwner: TObject);
    destructor Destroy;override;
    function New(aType: integer; aName: string; WithoutVersion: boolean = false): TMaterial;overload;
    function New(aClass: TMaterialClass; aName: string; WithoutVersion: boolean = false): TMaterial;overload;
    function IndexOf(aName: string): Integer;
    function IndexOfMaterial(aObject: TObject): Integer;
    function GetOrAdd(aType: integer; aName: string; WithoutVersion: boolean = false): TMaterial;
    function Find(aName: string): TMaterial;
    function PackIntoBuffer(atlas: TMaterialTextureAtlas): TMemoryStream;                        //Упаковывает все материалы в списке в один буфер, пригодный для шейдера
    function PackIntoBuffer2(atlas: TMaterialTextureAtlas): TMemoryStream;                        //Упаковывает все материалы в списке в один буфер, пригодный для шейдера (v2)
    procedure UnpackFromBuffer2(stm: TStream);
    function GenerateShaderMaterialEvaluationFunction: string;                                   //Выдает строку кода для вставки в шейдер, вычисляющего цвет материалов
    property NumFloatsInBlock: integer read FNumFloatsInBlock;                                   //Размер блока, в который упакован каждый материал (во float-ах)
    property OnMaterialChanged: TNotifyEvent read FOnMaterialChanged write FOnMaterialChanged;
    property Owner: TObject read FOwner;
    function LoadFromFile(filename, check_hash: string): boolean;
    procedure SaveToFile(filename, hash: string);
    procedure TestModify;
    function GetOrCreateMaterialByClassAndName(aClass, aName: string; WithoutVersion: boolean = false): TMaterial;
    function GetOrCreateMaterialByClassAndNameAsObj(aClass, aName: string): TObject;
    function CreateMaterialByClassAndNameAsObj(aClass, aName: string): TObject;
    procedure PreloadTextures;
    function GenShaderLib: string;
    function GetShaderLib2: string;
    function GroupByType: TMaterialTypeLibrary;
    function AddMultiMaterial(const aName: string; const Index: Integer; onMultiCreated: TMultiMaterialCreated): TMultiMaterial;
    function SetMonoMaterial(const MonoMaterialName: string; const OwnerIndex: Integer; onMonoCreated: TMonoMaterialCreated; MonoClass: TMaterialClass): TMaterial;
    function FindOldMaterialByNewMaterial(rendMaterial: TMaterial): Integer;
    function FindMaterial(const aName: string): TMaterial;
    procedure UpdateSetMaterial(aWndHandle: Cardinal; aMaterial: TMaterial);
    procedure ExecCommand(cmd: cardinal; params: TCommandParams);
  end;

//Библиотека типов материалов объектов
  TMaterialTypeLibrary = class(TMaterialList)
  private
    function IndexOfType(aType: Integer): integer;
  public
    procedure RegisterTypes(aTypes: array of TMaterialTypeClass);
    function FindMaterialClass(aType: integer): TMaterialClass;
    function FindMaterialClassByName(aName: string): TMaterialClass;
    function FindMaterialTypeByClassName(aName: string): integer;
    function FindType(aType: Integer): TMaterialType;
    function GenShaderLib: string;
  end;

  TCommonTypeLibrary = class(TStringList)
  public
    constructor Create;
  end;

  TMaterialParamsTypeLibrary = class(TCommonTypeLibrary)
  public
    procedure RegisterTypes(aTypes: array of TMaterialParameterClass);
    function GetTypeByClassname(aClass: string): TMaterialParameterClass;
    function GetClassByType(const aType: TMaterialParameterType): TMaterialParameterClass;
  end;

  TMaterialTexturesTypeLibrary = class(TCommonTypeLibrary)
  private
    FReplaces: TStringList;
  public
    destructor Destroy;override;
    procedure RegisterTypes(aTypes: array of TClass);
    function GetTypeByClassname(aClass: string): TClass;
    procedure ReplaceType(const oldClass, newClass: TClass);
  end;

//Базовый класс конвертера материалов. Нужен для обмена данными между по-разному заданными материалами
//Дочерний класс содержит обычно содержит в себе указатель на материал, с которым нужно осуществить связь
//Он должен заполнить AssignKnownParameters, GetTexture и (если требуется двусторонняя связь) SetTexture
//После чего у TMaterialParameters и у TTexturesList есть методы ReadValues, которые копируют значения (по символьному имени)
//Он со счетчиком ссылок !!!!! Нужно работать как с интерфейсом !!!! Не надо вызывать Free - сам удаляется!!!!!
  TMaterialConverter = class(TMaterialParameters, IMaterialConverter)
  protected
    FRefCount: Integer;
    function HasParameter(aParamName: string): boolean;

    function GetInteger(aParamName: string): integer;
    function GetFloat(aParamName: string): single;
    function GetFloat3(aParamName: string): TAffineVector;
    function GetFloat4(aParamName: string): TVector;
    function GetMatrix(aParamName: string): TMatrix;
    function GetTextureValue(aParamName: string): TTextureValue;
    function GetString(aParamName: string): string;
    function GetTexWrapMode(aParamName: string): TTexWrapMode;

    procedure SetInteger(aParamName: string; const value: integer);
    procedure SetFloat(aParamName: string; const value: single);
    procedure SetFloat3(aParamName: string; const value: TAffineVector);
    procedure SetFloat4(aParamName: string; const value: TVector);
    procedure SetMatrix(aParamName: string; const value: TMatrix);
    procedure SetTextureValue(aParamName: string; const value: TTextureValue);
    procedure SetString(aParamName: string; const value: string);
    procedure SetTexWrapMode(aParamName: string; const value: TTexWrapMode);

    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    procedure AssignKnownParameters;virtual;abstract; //нужно заполнить известными значениями
    function GetTexture(aName: string): TObject;virtual; //нужно доопределить известными текстурами
    procedure SetTexture(aName: string; const value: TObject);virtual; //нужно доопределить известными текстурами
  public
    constructor Create;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    class function NewInstance: TObject; override;
  end;

//Абстрактный источник данных текстуры
  TTextureDataSource = class(TSimpleInterfacedObject, IClusteredIO)
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);virtual;abstract; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;virtual;abstract;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;virtual;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); overload; virtual; abstract;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); overload; virtual; abstract;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); overload; virtual; abstract;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); overload; virtual; abstract;
    function EqualTo(t: TTextureDataSource): boolean;virtual;abstract;
    procedure WriteToFiler(WriteInfo: TWriteInfo);virtual;abstract;
    procedure ReadFromFiler(ReadInfo: TReadInfo);virtual;abstract;
  public
    function GetData: TStream;virtual;abstract;
    function HasData: boolean;virtual;abstract;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams);virtual;
    function GetCopy: TTextureDataSource;virtual;abstract;
  end;

//Библиотечный источник данных текстуры
  TGUIDedTextureDataSource = class(TTextureDataSource)
  private
    FGUID: TGUID;
    FData: TStream;
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
    function GetHash: string;
  public
    constructor CreateWithGUID(const aGUID: TGUID);
    destructor Destroy; override;
    function GetData: TStream;override;
    function HasData: boolean;override;
    function GetGUID: TGUID;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams);override;
    function GetCopy: TTextureDataSource;override;
  end;

  TTextureDataSourceClass = class of TTextureDataSource;

//Памятный источник данных текстуры
  TMemoryTextureDataSource = class(TTextureDataSource)
  private
    FLazyData: ISomeStream;
    FStream: TMemoryStream;
    procedure SetStream(const Value: TMemoryStream);
    procedure CopyStream(const Value: TStream);
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    function EqualTo(t: TTextureDataSource): boolean;override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    constructor CreateFromFile(const filename: string);
    destructor Destroy;override;
    function GetData: TStream;override;
    function HasData: boolean;override;
    property Data: TMemoryStream read FStream write SetStream;    //сами данные. Можно назначить свой поток (в этом случае владельцем потока станет DataSource)
    function GetCopy: TTextureDataSource;override;
  end;

//Файловых источник данных текстуры
  TFileTextureDataSource = class(TTextureDataSource)
  private
    FIntData: TMemoryStream;
    FFilename: string;
    FStream: TFileStream;
    procedure OpenFile(filename: string);
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    function EqualTo(t: TTextureDataSource): boolean;override;
    procedure WriteToFiler(WriteInfo: TWriteInfo);override;
    procedure ReadFromFiler(ReadInfo: TReadInfo);override;
  public
    constructor Create(aFilename: string);
    destructor Destroy;override;
    function GetData: TStream;override;
    function HasData: boolean;override;
    property Filename: string read FFilename;
    function GetCopy: TTextureDataSource;override;
  end;

{Базовая текстура.
Она не умеет читать графические форматы - это нужно делать классами-потомками. Откуда читать указывается вызовом LoadFromFile или LoadFromMemory
Она умеет
- конвертировать форматы
- семплировать данные (пока только 2D линейная фильтрация)
- рисовать на себе другую такую текстуру
- готовить данные для создания текстуры в видеопамяти
}
  TTextureMipMap = record
    w, h, d: Integer;
    wxh: Integer;
    rowpitch, depthpitch: Integer;
    data: pointer;
  end;
  PTextureMipmap = ^TTextureMipMap;

  TsPattern = array of TAffineVector;
  TsKernel = array of array of Single;
  TRGBAFilter = function (c: TRGBA): TRGBA;
  TWrapMode = (WRAP_NONE, WRAP_CUT, WRAP_FLOOR, WRAP_BLACK);

  TMaterialTexture = class(TSimpleInterfacedObject, IResource, ITextureSampler, IChangableSampler,
    INormalMapGenerator, IStorableSampler, IClusteredIO, IXMLInf, IObjWithGUID)
  private
    //Создать провайдер на основе FData (FData при этом очиститься)
    procedure EnsureProvider(aForce: Boolean = False);

    procedure ITextureSampler.Preload = PreloadTexture;

    function SampleLinear2d(const uvw: TAffineVector): TVector;overload;
    function SampleLinear2d(const uvwl: TVector): TVector;overload;
    function GetTextureSize(mipLevel: integer = 0): TTextureSize;
    function NumberOfMips: integer;
    procedure ActualizePicture;

    procedure SaveObject(var SaveInfo: TSaveInfo);virtual; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;virtual;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;virtual;
    function GetProvider(ProviderClass: TTextureDataSourceClass): TTextureDataSource;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); overload; virtual;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); overload; virtual;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); overload; virtual;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); overload; virtual;
    function GetTextureObjType: integer;virtual;
    function EqualTo(t: TObject): boolean;
    procedure WriteToFiler(WriteInfo: TWriteInfo);virtual;
    procedure ReadFromFiler(ReadInfo: TReadInfo);virtual;

    procedure StretchDraw(Src, Dst: TTextureMipMap);overload;                                                 //нарисовать Src текстуру в Dst с переразмериванием
    procedure StretchDraw(Dst: TMaterialTexture);overload;
    function GaussFilter(t: Single; Src: TTextureMipMap): TTextureMipMap;                            //применить фильтр Гаусса 3x3
    function FilterRGBA(F: TRGBAFilter): TTextureMipMap;                                             //применить цветовой фильтр F
    function GenSobelKernel(Width: Integer): TsKernel;                                               //создать ядро фильтра Собеля
    procedure GenerateSobelNormalMapNxN(FilterWidth: Integer; Scale: Real; MipMap: Pointer;
      SignV: integer = 1; SignH: integer = 1);         //создать карту нормалей по картинке
    procedure DrawBorderOnNormalMap(BorderRadius, BorderWidth, BorderScale,                          //нарисовать в карту нормалей бордюр
      MapWidth, MapHeight: Single; SmoothEdge: Boolean; SignV: integer = 1; SignH: integer = 1;
      EnableV: boolean = true; EnableH: boolean = true; CombinePix: Integer = 1);
    function GetResourceName: string;
    //mmSize - ширина(высота) плитки в мм
    //pxSize - ширина(высота) карты плитки в пикс
    //BorderRadius - радиус скругления кромки в мм
    //BorderWidth  - ширина кромки в мм
    //BorderScale  - масштаб рельефа бордюра
    //BorderPattern - сгенерированный шаблон
    //aOutNormals - true - выдавать нормали, false - выдавать контур профиля
    //result - кол-во точек в шаблоне
    function GenBorderPatternEx(mmSize, pxSize, BorderRadius, BorderWidth, BorderScale: single;
      var BorderPattern: TsPattern; aOutNormals: boolean = true): integer;
    procedure DebugDrawBorderPattern(x, y, w, h: integer; BorderRadius,
      BorderWidth, BorderScale: single; img: TCanvas; Mode: integer);
    procedure CopyTo(dst: IChangableSampler);
    procedure SetProvider(const Value: TTextureDataSource);
    function GetSamplerObject: TObject;
    function GetTextureName: string;
    procedure SetTextureID(const Value: string);
    function CalcPixelHashFromData: string;
  protected
    FName: string;                                                                                   //имя текстуры
    FFormat: TTextureDataFormat;                                                                     //формат. По-умолчанию 32bit (R8G8B8A8)
    FWidth, FHeight, FDepth: integer;                                                                //Размеры в пикселях
    FUVWOffset: TAffineVector;
    FData: pointer;                                                                                  //Указатель на непрерывный блок данных (пикселей)
    FMips: array of TTextureMipMap;                                                                   //Мип уровни. Уровень 0 указывает на исходные данные
    FDataSize, FElementSize, FRowPitch, FDepthPitch, FWxH: integer;                                  //Размер данных и измерений
    FProvider: TTextureDataSource;                                                                   //Провайдер данных для текстуры (диск, память, сеть и.т.п)
    FOwnData: boolean;                                                                               //Если тру (по-умолчанию), то текстура отвечает за FData, иначе FData была назначено кем-то и менять нельзя
    FSourceName: string;
    FPixelHash: string;
    FGUIDLabel: IObjWithGUID;

    class function Lerp(const a, b: single; t: single): single;overload;
    class function Lerp(const a, b: TAffineVector; t: single): TAffineVector;overload;
    class function Lerp(const a, b: TVector; t: single): TVector;overload;

    procedure WriteRGBAUnSafed(x, y, z: integer; const color: TRGBA);overload;                         //запись RGBA текселя без проверки границ
    procedure WriteRGBAUnSafed(x, y, z: integer; var mip: TTextureMipMap; const color: TRGBA);overload;
    procedure WriteRGBASafed(x, y, z: integer; const color: TRGBA);overload;                           //запись RGBA текселя (безопасная)
    procedure WriteRGBASafed(x, y, z: integer; var mip: TTextureMipMap; const color: TRGBA);overload;
    //пиксельные ридеры
    function ReadRGBAUnSafed(x, y, z: integer): TRGBA;overload;                                        //чтение RGBA текселя без проверки границ
    function ReadRGBAUnSafed(x, y, z: integer; var mip: TTextureMipMap): TRGBA;overload;
    function ReadRGBACut(x, y, z: integer): TRGBA;overload;                                            //чтение RGBA текселя с насыщением координат
    function ReadRGBACut(x, y, z: integer; var mip: TTextureMipMap): TRGBA;overload;
    function ReadRGBAWrap(x, y, z: integer): TRGBA;overload;                                           //чтение RGBA текселя с зацикливанием координат
    function ReadRGBAWrap(x, y, z: integer; var mip: TTextureMipMap): TRGBA;overload;
    function ReadRGBATrunc(x, y, z: integer): TRGBA;overload;                                          //чтение RGBA текселя (за границами черный цвет)
    function ReadRGBATrunc(x, y, z: integer; var mip: TTextureMipMap): TRGBA;overload;

    function ReadVector(x, y, z: integer; WrapMode: TWrapMode = WRAP_FLOOR): TVector;overload;                                         //Читает 4 float значения (учитывая формат текстуры)
    function ReadVector(x, y, z: integer; var mip: TTextureMipMap; WrapMode: TWrapMode = WRAP_FLOOR): TVector;overload;                //Читает 4 float значения (учитывая формат текстуры) с указанного мипа
    function ReadPixel(x, y, mip: integer): TVector;
    procedure AllocateData;                                                                          //Выделяет память (создает FData)
    procedure SetupFormat(aFormat: TTextureDataFormat);                                              //Настраивает байтовые размеры измерений в соответствии с форматом и размерами текстуры
    procedure CreateMips;
    procedure DestroyMips;
    procedure TextureDataChanged;
    function GetBilinearValue2DPixelSpace(x, y, z: Single; var Mip: TTextureMipMap; WrapMode: TWrapMode = WRAP_FLOOR): TVector;         //Билинейное сэмплирование (координаты задаются в пикселях)
    function GetBiquadraticValue2DPixelSpace(x, y, z: Single; var Mip: TTextureMipMap; WrapMode: TWrapMode = WRAP_FLOOR): TVector;      //Биквадратное сэмплирование (координаты задаются в пикселях)
    function GetBicubicValue2DPixelSpace(x, y, z: Single; var Mip: TTextureMipMap; WrapMode: TWrapMode = WRAP_FLOOR): TVector;overload;          //Бикубич сэмплирование (координаты задаются в пикселях)
    function GetBicubicValue2DPixelSpace(x, y, z: Single; WrapMode: TWrapMode = WRAP_FLOOR): TVector;overload;
    procedure SetupDimensions(Width, Height, Depth: Integer; DoAllocateData: boolean = true);
  public
    constructor Create;virtual;
    constructor CreateNamed(const aName: string);
    destructor Destroy;override;
    procedure ExtractTextureTo(bmp: TBitmap; aFormat: TTextureDataFormat = tdf24bit; mipLevel: integer = 0);virtual;
    function GetBilinearInterpolatedValue(pos: TAffineVector; var Value: TVector): boolean;overload;    //Билинейное семплирование
    function GetBilinearInterpolatedValue(pos: TAffineVector; mip: integer; var Value: TVector; WrapMode: TWrapMode = WRAP_FLOOR): boolean;overload;    //Билинейное семплирование c указанного мипа
    function GetBiquadraticInterpolatedValue(pos: TAffineVector; mip: integer; var Value: TVector; WrapMode: TWrapMode = WRAP_FLOOR): boolean;overload; //Биквадратное семплирование c указанного мипа
    function GetBicubicInterpolatedValue(pos: TAffineVector; mip: integer; var Value: TVector; WrapMode: TWrapMode = WRAP_FLOOR): boolean;overload;    //Бикубическое семплирование c указанного мипа
    function GetBilinearInterpolatedValue(pos: TVector; var Value: TVector; WrapMode: TWrapMode = WRAP_FLOOR): boolean;overload;          //Трилинейное семплирование с мипами
    function GetTextureData(const RequiredFormat: TTextureDataFormat; var data: pointer;
      var datalen: integer; aCreateMips: Boolean = False): boolean;virtual; //Чтение текстуры из FProvider в FData
    procedure LoadFromFile(filename: string; aPreloadData: Boolean = false);                                                        //Указывает файл, из которого создавать текстуру (сразу не читает - только при вызове GetTextureData)
    procedure LoadFromMemory(p: pointer; datalen: integer; aPreloadData: Boolean = false);overload;                                 //Указывает память, откуда брать данные для текстуры (сразу не читает - только при вызове GetTextureData)
    procedure LoadFromMemory(stm: TMemoryStream; aPreloadData: Boolean = False);overload;                                            //Указывает память, откуда брать данные для текстуры (сразу не читает - только при вызове GetTextureData)
    function GetAddressOf(x, y, z: integer): pointer;                                                //Возвращает адрес пикселя
    procedure Draw(aTexture: TMaterialTexture; x, y, z: integer);                                    //Рисует на себе другую текстуру в указанном месте (используется при создании атласа)
    procedure PreloadTexture;
    function Empty: boolean;
//BorderRadius - радиус закругления в мм (если 0, то бордюра не будет),
//BorderWidth - ширина бордюра в мм (если 0, то бордюра не будет),
//BorderScale - масштаб закругления по Z (если 0, то бордюра не будет),
//MapWidth, MapHeight - реальные размеры плитки в мм
//Scale - масштабный коэффициент карты нормалей, KernelType - (3, 5, 7, ... - размер фильтра Собеля)
    procedure GenNormalMap(BorderRadius, BorderWidth, BorderScale, MapWidth, MapHeight,              //создать карту нормалей и добавить рамку к ней
      Scale: Single; KernelType: Integer; dst: IChangableSampler; NoMips: boolean = false;
        SobelDisabled: Boolean = false; EnableV: boolean = true; EnableH: boolean = true;
        CombinePix: Integer = 1);
    function GetFilename: string;
    function GetTextureID: string;
    function DetectExt(ForceLowLevel: boolean = false): string;overload;
    class function DetectExt(signature: cardinal): string;overload;
    function GetAsJpg(Quality: TJPEGQualityRange): TJpegImage;
    function GetAsBmp(aFormat: TTextureDataFormat = tdf24bit): Graphics.TBitmap;
    function GetAsPng: Graphics.TBitmap;virtual;abstract;
    procedure SaveToStream(const Stm: TStream);
    procedure SaveToStreamPng(const Stm: TStream);
    procedure SaveToFile(filename: string);
    procedure GetSize(var Width, Height, Depth: Integer);virtual;
    procedure Assign(const src: TMaterialTexture);
    property Provider: TTextureDataSource read FProvider write SetProvider;
    property TextureName: string read GetTextureName write FName;
    property TextureID: string read GetTextureID write SetTextureID;
    property SourceName: string read FSourceName write FSourceName;
    function DestFilename(aAllowNativeName: Boolean = False): string;
    procedure ClearData;
    function GetPixelHash(aForce: Boolean = False): string;
    procedure ExecCommand(cmd: cardinal; params: TCommandParams);
    function HasGUID: Boolean;
    function Clone: TMaterialTexture;
    procedure ApplySRGBCorrection(aGamma: Single; aMakeProvider: Boolean = False);
    property GUIDLabel: IObjWithGUID read FGUIDLabel implements IObjWithGUID; { IObjWithGUID }
  end;

//Текстура внутри атласа
  TAtlasMaterialTexture = class(TMaterialTexture)
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
//    procedure SaveToXml(const root: IXMLNode; const SaveFlags: cardinal = 0); override;
//    procedure LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal = 0); override;
    procedure SaveToXml(const root: TXMLNode; const SaveFlags: cardinal = 0); override;
    procedure LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal = 0); override;
    function GetTextureObjType: integer;override;
  public
    TextureAtlasPositionAndScale: array[TTextureWrapMode] of TTextureValue;                                                      //Положение и размер текстуры в атласе в формате для шейдера
    procedure SetMipmapDataFromAtlas(Atlas: TMaterialTextureAtlas);
  end;

//Атлас текстур. Напрямую не создается, только через TMaterialTextures
  TMaterialTextureAtlas = class(TMaterialTexture)
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;override;
  public
    AtlasContent: TMaterialTextures;
    constructor Create;override;
    destructor Destroy;override;
  end;

  TMaterialTextureClass = class of TMaterialTexture;

//Список текстур класса TMaterialTexture. Является их владельцем и умеет создавать атлас
  TMaterialTextures = class(TInterfacedObjectList, ITextureAtlas)
  private
    function GetTextureID(const Index: Integer): string;
    function GetTextureCount: Integer;
    function GetSampler(const aTextureID: string; out sampler: ITextureSampler): boolean;overload;
    function GetSampler(value: TTextureValue; out sampler: ITextureSampler): boolean;overload;
    procedure SetSampler(const sampler: ITextureSampler);
    function ListTextures: string;
  protected
    procedure SaveObject(var SaveInfo: TSaveInfo);override; {ok}
    function LoadParam(var LoadInfo: TLoadInfo): integer;override;
    function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
      const ChildClass: string; const ChildID: string): TObject;override;
  public
    function LoadFromFile(const filename: string): string;
    function New(aClass: TMaterialTextureClass; aName: string = ''): TMaterialTexture;
    function IndexOf(aTextureID: string): integer;
    function Find(aTextureID: string; var obj): boolean;
//Создает атлас всех текстур в списке. Доступ к текстурам по отдельности возможен через TMaterialTextureAtlas.AtlasContent (эти тектуры не будут иметь данных - их они берут в самом атласе)
//    function CreateAtlas(aName: string; aFormat: TTextureDataFormat; MaxWidth, MaxHeight, MaxDepth, Border: integer): TMaterialTextureAtlas;
    function CreateGoodAtlas(aName: string; aFormat: TTextureDataFormat; MaxWidth10, MaxHeight10, MaxWidth11, MaxHeight11,
                             Border: integer; Task: TSSTask = nil): TMaterialTextureAtlas;
//    function CreateHardAtlas(aContext: THardContext; aName: string; MaxWidth, MaxHeight, Border: Integer; Task: TSSTask = nil): THardTexture;
    function CreateHardAtlas(aName: string; MaxWidth, MaxHeight, Border: Integer; Task: TSSTask = nil): cardinal;
    function Texture(const aIndex: Integer): TMaterialTexture;
    procedure DeleteUnusedTextures();
    procedure AddUnique(const t: TMaterialTexture);
  end;

  function TextureValue(const Index: TAffineVector; const Scale: TVector2f): TTextureValue;
  function GetMaterialClass(aClassName: string): TMaterialClass;

  function IsNullPointAAInfo(const info: TPointAAInfo): boolean;
  function IsEmptyPointAAInfo(const info: TPointAAInfo): boolean;
  function PointAAInfoEquals(const a, b: TPointAAInfo): boolean;

const
  g_TextureFormatSize: array[TTextureDataFormat] of integer = (4, 3, 1);

  SideBlock = 1.0;
  Total5Weight = 1.0 / (1 + 4 * 0.707 * SideBlock);

var
  MaterialTypes: TMaterialTypeLibrary;
  MaterialParams: TMaterialParamsTypeLibrary;
  MaterialTextures: TMaterialTexturesTypeLibrary;

  AmbientMode: integer = 1;
  AmbientPitch: array[0..1] of TAffineVector = ((0, 45 / 180 * pi, 0), (30 / 180 * Pi, 45 / 180 * Pi, 60 / 180 * pi));
  AmbientTurn: array[0..1] of TAffineVector = ((0, 0, 0), (0, 0, 0));
  AmbientAperture: array[0..1] of TVector = ((1, 0, 1, 0), (0.53589838486224541294510731698826, 0.53589838486224541294510731698826, 0.53589838486224541294510731698826, 0.53589838486224541294510731698826));
  AmbientWeights: array[0..1] of TVector = ((Total5Weight, 0.0, SideBlock * 0.707 * Total5Weight, 0.0), (1.0 / 9.292, 0.866 / 9.292, 0.707 / 9.292, 0.5 / 9.292));
  LightKs: array[0..2] of single = (0.25, 1, 1);

  TexLod: single = 0.0;
  NumOfSubrays: integer = 4;

  SpecularOffset: single = 1.0;

  ForceUseMixedRay: boolean = true;
  DefaultMixedRayStart: single = 1;
  DefaultMixedRayEnd: single = 3.0;

  SpecularMixStart: single = 1.0;
  SpecularMixEnd: single = 6.0;

  RefractionMixStart: single = 1.0;
  RefractionMixEnd: single = 6.0;

  CommonMaterialTextureClass: TMaterialTextureClass;

const
  DefaultAmbientPitch: array[0..1] of TAffineVector = ((0, 45 / 180 * pi, 0), (30 / 180 * Pi, 45 / 180 * Pi, 60 / 180 * pi));
  DefaultAmbientTurn: array[0..1] of TAffineVector = ((0, 0, 0), (0, 0, 0));
  DefaultAmbientAperture: array[0..1] of TVector = ((1, 0, 1, 0), (0.53589838486224541294510731698826, 0.53589838486224541294510731698826, 0.53589838486224541294510731698826, 0.53589838486224541294510731698826));
  DefaultAmbientWeights: array[0..1] of TVector = ((Total5Weight, 0.0, SideBlock * 0.707 * Total5Weight, 0.0), (1.0 / 9.292, 0.866 / 9.292, 0.707 / 9.292, 0.5 / 9.292));
  DefaultLightKs: array[0..2] of single = (1, 1, 1);
  KdOctreeMixValue: single = 1.0;
  AmbientOffsetScale: single = 1.0;
  NullPointAAInfo: TPointAAInfo = (ObjectID: 0; Material: nil);
  EmptyPointAAInfo: TPointAAInfo = (ObjectID: -1; Material: Pointer($ffffffff));

  matFlagFastAmbient = 1;
  matFlagReflectionsAA = 2;
  matFlagRefractionsAA = 4;
  matFlagReflective = 8;
  matFlagRefractive = 16;
  matFlagLightSource = 32;
  matFlagHidden = 64;

  texSingleTexture = 0;
  texAtlasTexture = 1;

{$IFNDEF PBR_ENABLE}
  CurrentMaterialVersion = 8;
{$ELSE}
  CurrentMaterialVersion = 11;
{$ENDIF}

  function GetMaterialTextures: TMaterialTexturesTypeLibrary;

type
  TMapKinds = record
   name: string;
   altname, category: function (): string;
  end;
  PMapKinds = ^TMapKinds;
  TMapKindsList = array of PMapKinds;

// CATEGORIES
function cAlbedoCategory(): string;
function cAmbientCategory(): string;
function cDiffuseCategory(): string;
function cReflectCategory(): string;
function cRefractCategory(): string;
function cLightCategory(): string;
function cVoxCategory(): string;
function cBumpCategory(): string;
function cEmissionCategory(): string;
function cThinFilmCategory(): string;
function cPBRCategory(): string;
function cCoatCategory(): string;
function cMiscCategory(): string;

//для источников
function cLEmissionCategory(): string;
function cLVoxEmissionCategory(): string;
function cLVoxLightCategory(): string;
function cLLightCategory(): string;
function GetEmptyString(): string;

// MAP ALT NAMES
function GetAlbedoMapAltName(): string;
function GetAlbedoMapExAltName(): string;
function GetBumpMapAltName(): string;
function GetReflLevelMapAltName(): string;
function GetReflFresnelMapAltName(): string;
function GetReflBlurMapAltName(): string;
function GetReflectionMapAltName(): string;
function GetRefrLevelMapAltName(): string;
function GetRefrIndexMapAltName(): string;
function GetRefrBlurMapAltName(): string;
function GetWeightsMapAltName(): string;
function GetThinFilmMapAltName(): string;
function GetOpacityMapAltName(): string;
function GetEmissionMapAltName(): string;
function GetRMITMapAltName(): string;
function GetCoatColorMapAltName(): string;
function GetCoatBumpMapAltName(): string;
function GetCoatCRIMapAltName(): string;

const
  IdentityTransform: TTexTransformSettings = (Scale: (1, 1); Offset: (0, 0); Rotation: 0);
  IdentityTexWrap: TTexWrapMode = (U: twmWrap; V: twmWrap; W: twmWrap);

  cAlbedoMap:      TMapKinds = (name: 'albedoMap';      altname: GetAlbedoMapAltName;      category: cAlbedoCategory);
  cAlbedoMapEx:    TMapKinds = (name: 'albedoMapEx';    altname: GetAlbedoMapExAltName;    category: cMiscCategory);
  cBumpMap:        TMapKinds = (name: 'bumpMap';        altname: GetBumpMapAltName;        category: cBumpCategory);
  cReflLevelMap:   TMapKinds = (name: 'ReflLevelMap';   altname: GetReflLevelMapAltName;   category: cReflectCategory);
  cReflFresnelMap: TMapKinds = (name: 'ReflFresnelMap'; altname: GetReflFresnelMapAltName; category: cReflectCategory);
  cReflBlurMap:    TMapKinds = (name: 'ReflBlurMap';    altname: GetReflBlurMapAltName;    category: cReflectCategory);
  cReflectionMap:  TMapKinds = (name: 'ReflectionMap';  altname: GetReflectionMapAltName;  category: cReflectCategory);
  cRefrLevelMap:   TMapKinds = (name: 'RefrLevelMap';   altname: GetRefrLevelMapAltName;   category: cRefractCategory);
  cRefrIndexMap:   TMapKinds = (name: 'RefrIndexMap';   altname: GetRefrIndexMapAltName;   category: cRefractCategory);
  cRefrBlurMap:    TMapKinds = (name: 'RefrBlurMap';    altname: GetRefrBlurMapAltName;    category: cRefractCategory);
  cWeightsMap:     TMapKinds = (name: 'WeightsMap';     altname: GetWeightsMapAltName;     category: GetEmptyString);
  cThinFilmMap:    TMapKinds = (name: 'ThinFilmMap';    altname: GetThinFilmMapAltName;    category: cThinFilmCategory);
  cOpacityMap:     TMapKinds = (name: 'OpacityMap';     altname: GetOpacityMapAltName;     category: cPBRCategory);
  cEmissionMap:    TMapKinds = (name: 'EmissionMap';    altname: GetEmissionMapAltName;    category: cPBRCategory);
  cRMITMap:        TMapKinds = (name: 'RMITMap';        altname: GetRMITMapAltName;        category: cPBRCategory);
  cCoatColorMap:   TMapKinds = (name: 'CoatColorMap';   altname: GetCoatColorMapAltName;   category: cCoatCategory);
  cCoatBumpMap:    TMapKinds = (name: 'CoatBumpMap';    altname: GetCoatBumpMapAltName;    category: cCoatCategory);
  cCoatCRIMap:     TMapKinds = (name: 'CoatCRIMap';     altname: GetCoatCRIMapAltName;     category: cCoatCategory);

function GetCategoriesList: TStringList;
function GetMapKindsList: TMapKindsList;
function FindMapKindsByName(aName: string): PMapKinds;

var
  CategoriesList: TStringList;
  MapKindsList: TMapKindsList;

implementation

uses
  KdConst, Windows, SysUtils, VectorLists, TexPacker, KdBlockType, math2, AppLog,
  DateUtils, StrUtils, Clusters, Base64, md5util, ClipBrd, GUIDUtil, AxCtrls,
  GLResourceLibraryIntf, uCommands, ImagePack, uCustomFilers, TempStream,
  GuidParamsUnit, UnicodeUtil, CeramicVars, uObjRegistry, BlockTypes;

// CATEGORIES

function cPBRCategory(): string;
begin
  Result := tr('PBR');
end;

function cCoatCategory(): string;
begin
  Result := tr('PBR_Лак');
end;

function cMiscCategory(): string;
begin
  Result := tr('Прочее');
end;

function cThinFilmCategory(): string;
begin
  Result := tr('Тонкая_плёнка');
end;

function cAlbedoCategory(): string;
begin
  Result := tr('Альбедо');
end;

function cAmbientCategory(): string;
begin
  Result := tr('Фоновый');
end;

function cDiffuseCategory(): string;
begin
  Result := tr('Прямой');
end;

function cReflectCategory(): string;
begin
  Result := tr('Отражение');
end;

function cRefractCategory(): string;
begin
  Result := tr('Преломление');
end;

function cLightCategory(): string;
begin
  Result := tr('Источник');
end;

function cVoxCategory(): string;
begin
  Result := tr('Воксели');
end;

function cBumpCategory(): string;
begin
  Result := tr('Рельеф');
end;

function cEmissionCategory(): string;
begin
  Result := tr('Самосвечение');
end;

function GetEmptyString(): string;
begin
  Result := '';
end;

//для источников
function cLEmissionCategory(): string;
begin
  Result := tr('Цвет Сцены');
end;

function cLVoxEmissionCategory(): string;
begin
  Result := tr('Цвет Вокселей');
end;

function cLVoxLightCategory(): string;
begin
  Result := tr('Освещение Вокселей');
end;

function cLLightCategory(): string;
begin
  Result := tr('Освещение Сцены');
end;

function GetCategoriesList: TStringList;
begin
  Result := TStringList.Create;
  Result.Add(cAlbedoCategory);
  Result.Add(cAmbientCategory);
  Result.Add(cDiffuseCategory);
  Result.Add(cReflectCategory);
  Result.Add(cRefractCategory);
  Result.Add(cLightCategory);
  Result.Add(cVoxCategory);
  Result.Add(cBumpCategory);
  Result.Add(cEmissionCategory);
  Result.Add(cLEmissionCategory);
  Result.Add(cLVoxEmissionCategory);
  Result.Add(cLVoxLightCategory);
  Result.Add(cLLightCategory);
  Result.Add(cThinFilmCategory);
  Result.Add(cPBRCategory);
  Result.Add(cCoatCategory);
  Result.Add(cMiscCategory);
end;

// MAP ALT NAMES

function GetAlbedoMapAltName(): string;
begin
  Result := tr('Карта цвета');
end;

function GetAlbedoMapExAltName(): string;
begin
  Result := tr('Карта цвета для Com рендера');
end;

function GetBumpMapAltName(): string;
begin
  Result := tr('Карта рельефа');
end;

function GetReflLevelMapAltName(): string;
begin
  Result := tr('Карта уровней отражения');
end;

function GetReflFresnelMapAltName(): string;
begin
  Result := tr('Карта коэффициентов отражения');
end;

function GetReflBlurMapAltName(): string;
begin
  Result := tr('Карта размытия отражения');
end;

function GetReflectionMapAltName(): string;
begin
  Result := tr('Карта цвета отражения');
end;

function GetRefrLevelMapAltName(): string;
begin
  Result := tr('Карта уровней преломления');
end;

function GetRefrIndexMapAltName(): string;
begin
   Result := tr('Карта коэффициентов преломления');
end;

function GetRefrBlurMapAltName(): string;
begin
  Result := tr('Карта размытия преломления');
end;

function GetWeightsMapAltName(): string;
begin
  Result := tr('Карта мультиматериала');
end;

function GetThinFilmMapAltName(): string;
begin
  Result := tr('Карта толщины тонкой плёнки');
end;

function GetOpacityMapAltName(): string;
begin
  Result := tr('Карта непрозрачности');
end;

function GetEmissionMapAltName(): string;
begin
  Result := tr('Карта цвета светимости');
end;

function GetRMITMapAltName(): string;
begin
  Result := tr('Карта RMIT');
end;

function GetCoatColorMapAltName(): string;
begin
  Result := tr('Карта цвета лака');
end;

function GetCoatBumpMapAltName(): string;
begin
  Result := tr('Карта рельефа лака');
end;

function GetCoatCRIMapAltName(): string;
begin
  Result := tr('Карта CRI лака');
end;

function GetMapKindsList: TMapKindsList;
begin
  SetLength(Result, 18);
  Result[0] := @cAlbedoMap;
  Result[1] := @cBumpMap;
  Result[2] := @cReflLevelMap;
  Result[3] := @cReflFresnelMap;
  Result[4] := @cReflBlurMap;
  Result[5] := @cRefrLevelMap;
  Result[6] := @cRefrIndexMap;
  Result[7] := @cRefrBlurMap;
  Result[8] := @cReflectionMap;
  Result[9] := @cWeightsMap;
  Result[10]:= @cThinFilmMap;
  Result[11]:= @cAlbedoMapEx;
  Result[12]:= @cOpacityMap;
  Result[13]:= @cEmissionMap;
  Result[14]:= @cRMITMap;
  Result[15]:= @cCoatColorMap;
  Result[16]:= @cCoatBumpMap;
  Result[17]:= @cCoatCRIMap;
end;

function FindMapKindsByName(aName: string): PMapKinds;
var
  i: integer;
begin
  Result:=nil;
  for i:=0 to high(MapKindsList) do
    if MapKindsList[i].name = aName then
    begin
      Result:=MapKindsList[i];
      break;
    end;
end;

function GetMaterialClass(aClassName: string): TMaterialClass;
begin
  Result:=MaterialTypes.FindMaterialClassByName(aClassName);
end;

function TextureValue(const Index: TAffineVector; const Scale: TVector2f): TTextureValue;
begin
  Result.Index:=Index;
  Result.Scale:=Scale;
end;

function IsNullPointAAInfo(const info: TPointAAInfo): boolean;
begin
  Result:=PointAAInfoEquals(info, NullPointAAInfo);
end;

function IsEmptyPointAAInfo(const info: TPointAAInfo): boolean;
begin
  Result:=PointAAInfoEquals(info, EmptyPointAAInfo);
end;

function VectorEqualsEx(const V1, V2: TVector3f; threshold: Single): Boolean;
begin
  Result:=VectorLength(VectorSubtract(V1, V2))<threshold;
end;

function PointAAInfoEquals(const a, b: TPointAAInfo): boolean;
begin
  Result:={VectorEquals(a.Normal, b.Normal, 0.3) and }(a.ObjectID = b.ObjectID) and (a.Material = b.Material){ and (a.Deep = b.Deep)};
end;

function ExplodeStrChar(lim: Char; s: string): TStringList;
var
  i, j: integer;
begin
  Result:=TStringList.Create;
  i:=1;
  j:=1;
  while i < Length(s) do
  begin
    if s[i] = lim then
    begin
      Result.Add(Trim(Copy(s, j, i - j)));
      j:=i + 1;
    end;
    Inc(i);
  end;
  Result.Add(Trim(Copy(s, j, i - j + 1)));
end;

{ TIntegerMaterialParameter }

function TIntegerMaterialParameter.AsFloat: Single;
begin
  Result:=Value;
end;

function TIntegerMaterialParameter.AsInteger: Integer;
begin
  Result:=Value;
end;

procedure TIntegerMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TIntegerMaterialParameter then
    PValue^:=TIntegerMaterialParameter(src).Value;
  inherited;
end;

procedure TIntegerMaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsInteger;
end;

function TIntegerMaterialParameter.AsString(short: boolean): string;
begin
  Result:=IntToStr(Value);
end;

procedure TIntegerMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetInteger(FName, Value);
end;

procedure TIntegerMaterialParameter.Dump;
begin
  Log(Format('Parameter: %s = %d', [FName, Value]));
end;

function TIntegerMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TIntegerMaterialParameter) and (FValue = TIntegerMaterialParameter(p).FValue);
end;

procedure TIntegerMaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
  Value:=conv.GetInteger(FName);
end;

procedure TIntegerMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TIntegerMaterialParameter.GetShaderValue: string;
const
  xyzw: array [0..3] of char = ('x', 'y', 'z', 'w');
begin
  Result:='asint($MATLIST[matIndex + ' + IntToStr(FOffset shr 2) + '].' + xyzw[FOffset and 3] + ')';
end;

function TIntegerMaterialParameter.GetValue: Integer;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AsInteger;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;
{
procedure TIntegerMaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    Value := root.Attributes['Value'];
end;
}
procedure TIntegerMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    Value := root.AttributeByName['Value'].ValueAsInteger;
end;

function TIntegerMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btIntegerMaterialParameterValue: ReadInteger(PValue^);
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TIntegerMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TIntegerMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TIntegerMaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteInteger(btIntegerMaterialParameterValue, Value);
  except
    on e: exception do
      SaveInfo.Error('TIntegerMaterialParameter: ' + e.Message);
  end;
  inherited;
end;
{
procedure TIntegerMaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.Attributes['Value']:=Value;
end;
}
procedure TIntegerMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.GetOrCreateAttr('Value').ValueAsInteger := Value;
end;

procedure TIntegerMaterialParameter.SetAsFloat(const aValue: Single);
begin
  Value:=Trunc(aValue);
end;

procedure TIntegerMaterialParameter.SetAsInteger(const aValue: Integer);
begin
  Value:=aValue;
end;

procedure TIntegerMaterialParameter.Setup;
begin
  inherited;
  FType:=mptInteger;
  PValue:=@FValue;
end;

procedure TIntegerMaterialParameter.SetValue(const Value: integer);
var
  p: TMaterialParameter;
begin
  if GetValue <> Value then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsInteger(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TIntegerMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

{ TFloatMaterialParameter }

function TFloatMaterialParameter.AsFloat: Single;
begin
  Result:=Value;
end;

function TFloatMaterialParameter.AsInteger: Integer;
begin
  Result:=Trunc(Value);
end;

procedure TFloatMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TFloatMaterialParameter then
    PValue^:=TFloatMaterialParameter(src).Value;
  inherited;
end;

procedure TFloatMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetFloat(FName, Value);
end;

procedure TFloatMaterialParameter.Dump;
begin
  Log(Format('Parameter: %s = %.5f', [FName, Value]));
end;

function TFloatMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TFloatMaterialParameter) and (FValue = TFloatMaterialParameter(p).FValue);
end;

procedure TFloatMaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
  Value:=conv.GetFloat(FName);
end;

procedure TFloatMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TFloatMaterialParameter.GetValue: Single;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AsFloat;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;

function TFloatMaterialParameter.GetPureValue: Single;
begin
  Result:=PValue^;
end;
{
procedure TFloatMaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    Value := root.Attributes['Value'];
end;
}
procedure TFloatMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    Value := root.AttributeByName['Value'].ValueAsFloat;
end;

function TFloatMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btFloatMaterialParameterValue: ReadSingle(PValue^);
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TFloatMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TFloatMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TFloatMaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteSingle(btFloatMaterialParameterValue, Value);
  except
    on e: exception do
      SaveInfo.Error('TFloatMaterialParameter: ' + e.Message);
  end;
  inherited;
end;
{
procedure TFloatMaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.Attributes['Value']:=Value;
end;
}
procedure TFloatMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.GetOrCreateAttr('Value').ValueAsFloat := Value;
end;

procedure TFloatMaterialParameter.SetAsFloat(const aValue: Single);
begin
  Value:=aValue;
end;

procedure TFloatMaterialParameter.SetAsInteger(const aValue: Integer);
begin
  Value:=aValue;
end;

procedure TFloatMaterialParameter.Setup;
begin
  inherited;
  FType:=mptFloat;
  PValue:=@FValue;
end;

procedure TFloatMaterialParameter.SetValue(const Value: Single);
var
  p: TMaterialParameter;
begin
  if GetValue <> Value then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsFloat(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TFloatMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

function TFloatMaterialParameter.AsString(short: boolean): string;
begin
  if not short then
    Result:=FloatToStr(Value)
  else
    Result:=FloatToStr(RoundTo(Value, -4));
end;

procedure TFloatMaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsFloat;
end;

{ TFloat3MaterialParameter }

function TFloat3MaterialParameter.AsFloat3: TAffineVector;
begin
  Result:=Value;
end;

function TFloat3MaterialParameter.AsFloat4: TVector;
begin
  Result:=VectorMake(Value);
end;

procedure TFloat3MaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TFloat3MaterialParameter then
    PValue^:=TFloat3MaterialParameter(src).Value;
  inherited;
end;

procedure TFloat3MaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsFloat3;
end;

function TFloat3MaterialParameter.AsString(short: boolean): string;
begin
  if not short then
    Result:=FloatToStr(Value[0]) + ';' + FloatToStr(Value[1]) + ';' + FloatToStr(Value[2])
  else
    Result:=FloatToStr(RoundTo(Value[0], -4)) + ';' + FloatToStr(RoundTo(Value[1], -4)) + ';' + FloatToStr(RoundTo(Value[2], -4))
end;

procedure TFloat3MaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetFloat3(FName, Value);
end;

procedure TFloat3MaterialParameter.Dump;
begin
  Log(Format('Parameter: %s = %.5f   %.5f   %.5f', [FName, Value[0], Value[1], Value[2]]));
end;

function TFloat3MaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TFloat3MaterialParameter) and VectorEquals(FValue, TFloat3MaterialParameter(p).FValue);
end;

procedure TFloat3MaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
  Value:=conv.GetFloat3(FName);
end;

procedure TFloat3MaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TFloat3MaterialParameter.GetShaderDefaultValue: string;
begin
  Result:='float3(0, 0, 0)';
end;

function TFloat3MaterialParameter.GetShaderValue: string;
begin
  Result:='$MATLIST[matIndex + ' + IntToStr(FOffset shr 2) + '].';
  case FOffset and 3 of
    1: Result:=Result + 'yzw';
    2: Result:='float3(' + Result + 'zw, $MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].x)';
    3: Result:='float3(' + Result + 'w, $MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].xy)';
  else
    Result:=Result + 'xyz';
  end;
end;

function TFloat3MaterialParameter.GetValue: TAffineVector;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AsFloat3;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;
{
procedure TFloat3MaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and (root.HasAttribute('X')) and (root.HasAttribute('Y')) and (root.HasAttribute('Z')) then
  begin
    PValue[0]:=root.Attributes['X'];
    PValue[1]:=root.Attributes['Y'];
    PValue[2]:=root.Attributes['Z'];
  end;
end;
}
procedure TFloat3MaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and (root.HasAttribute('X')) and (root.HasAttribute('Y')) and (root.HasAttribute('Z')) then
  begin
    PValue[0]:=root.AttributeByName['X'].ValueAsFloat;
    PValue[1]:=root.AttributeByName['Y'].ValueAsFloat;
    PValue[2]:=root.AttributeByName['Z'].ValueAsFloat;
  end;
end;

function TFloat3MaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btFloat3MaterialParameterValue: ReadAffineVector(PValue^);
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TFloat3MaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TFloat3MaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TFloat3MaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteAffineVector(btFloat3MaterialParameterValue, PValue^);
  except
    on e: exception do
      SaveInfo.Error('TFloat3MaterialParameter: ' + e.Message);
  end;
  inherited;
end;
{
procedure TFloat3MaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    root.Attributes['X']:=PValue[0];
    root.Attributes['Y']:=PValue[1];
    root.Attributes['Z']:=PValue[2];
  end;
end;
}
procedure TFloat3MaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    root.GetOrCreateAttr('X').ValueAsFloat := PValue[0];
    root.GetOrCreateAttr('Y').ValueAsFloat := PValue[1];
    root.GetOrCreateAttr('Z').ValueAsFloat := PValue[2];
  end;
end;

procedure TFloat3MaterialParameter.SetAsFloat3(const aValue: TAffineVector);
begin
  Value:=aValue;
end;

procedure TFloat3MaterialParameter.SetAsFloat4(const aValue: TVector);
begin
  Value:=TVectorCoords(aValue).XYZ;
end;

procedure TFloat3MaterialParameter.Setup;
begin
  inherited;
  FType:=mptFloat3;
  PValue:=@FValue;
end;

procedure TFloat3MaterialParameter.SetValue(const Value: TAffineVector);
var
  p: TMaterialParameter;
begin
  if not VectorEquals(Value, GetValue) then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsFloat3(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TFloat3MaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

{ TFloat4MaterialParameter }

function TFloat4MaterialParameter.AsFloat3: TAffineVector;
begin
  Result:=TVectorCoords(Value).XYZ;
end;

function TFloat4MaterialParameter.AsFloat4: TVector;
begin
  Result:=Value;
end;

procedure TFloat4MaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TFloat4MaterialParameter then
    PValue^:=TFloat4MaterialParameter(src).Value;
  inherited;
end;

procedure TFloat4MaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsFloat4;
end;

function TFloat4MaterialParameter.AsString(short: boolean): string;
begin
  if not short then
    Result:=FloatToStr(Value[0]) + ';' + FloatToStr(Value[1]) + ';' + FloatToStr(Value[2]) + ';' + FloatToStr(Value[3])
  else
    Result:=FloatToStr(RoundTo(Value[0], -4)) + ';' + FloatToStr(RoundTo(Value[1], -4)) + ';' + FloatToStr(RoundTo(Value[2], -4)) + ';' + FloatToStr(RoundTo(Value[3], -4));
end;

procedure TFloat4MaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetFloat4(FName, Value);
end;

procedure TFloat4MaterialParameter.Dump;
begin
  Log(Format('Parameter: %s = %.5f   %.5f   %.5f   %.5f', [FName, Value[0], Value[1], Value[2], Value[3]]));
end;

function TFloat4MaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TFloat4MaterialParameter) and VectorEquals(FValue, TFloat4MaterialParameter(p).FValue);
end;

procedure TFloat4MaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
  Value:=conv.GetFloat4(FName);
end;

procedure TFloat4MaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TFloat4MaterialParameter.GetShaderDefaultValue: string;
begin
  Result:='float4(0, 0, 0, 0)';
end;

function TFloat4MaterialParameter.GetShaderValue: string;
begin
  Result:='$MATLIST[matIndex + ' + IntToStr(FOffset shr 2) + ']';
end;

function TFloat4MaterialParameter.GetValue: TVector;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AsFloat4;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;
{
procedure TFloat4MaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and (root.HasAttribute('X')) and (root.HasAttribute('Y')) and (root.HasAttribute('Z'))
    and (root.HasAttribute('W')) then
  begin
    PValue[0]:=root.Attributes['X'];
    PValue[1]:=root.Attributes['Y'];
    PValue[2]:=root.Attributes['Z'];
    PValue[3]:=root.Attributes['W'];
  end;
end;
}
procedure TFloat4MaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and (root.HasAttribute('X')) and (root.HasAttribute('Y')) and (root.HasAttribute('Z'))
    and (root.HasAttribute('W')) then
  begin
    PValue[0]:=root.AttributeByName['X'].ValueAsFloat;
    PValue[1]:=root.AttributeByName['Y'].ValueAsFloat;
    PValue[2]:=root.AttributeByName['Z'].ValueAsFloat;
    PValue[3]:=root.AttributeByName['W'].ValueAsFloat;
  end;
end;

function TFloat4MaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btFloat4MaterialParameterValue: ReadVector(PValue^);
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TFloat4MaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TFloat4MaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TFloat4MaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteVector(btFloat4MaterialParameterValue, PValue^);
  except
    on e: exception do
      SaveInfo.Error('TFloat4MaterialParameter: ' + e.Message);
  end;
  inherited;
end;
{
procedure TFloat4MaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    root.Attributes['X']:=PValue[0];
    root.Attributes['Y']:=PValue[1];
    root.Attributes['Z']:=PValue[2];
    root.Attributes['W']:=PValue[3];
  end;
end;
}
procedure TFloat4MaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    root.GetOrCreateAttr('X').ValueAsFloat := PValue[0];
    root.GetOrCreateAttr('Y').ValueAsFloat := PValue[1];
    root.GetOrCreateAttr('Z').ValueAsFloat := PValue[2];
    root.GetOrCreateAttr('W').ValueAsFloat := PValue[3];
  end;
end;

procedure TFloat4MaterialParameter.SetAsFloat3(
  const aValue: TAffineVector);
begin
  Value:=VectorMake(aValue);
end;

procedure TFloat4MaterialParameter.SetAsFloat4(const aValue: TVector);
begin
  Value:=aValue;
end;

procedure TFloat4MaterialParameter.Setup;
begin
  inherited;
  FType:=mptFloat4;
  PValue:=@FValue;
end;

procedure TFloat4MaterialParameter.SetValue(const Value: TVector);
var
  p: TMaterialParameter;
begin
  if not VectorEquals(Value, GetValue) then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsFloat4(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TFloat4MaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

{ TMatrixMaterialParameter }

function TMatrixMaterialParameter.AsMatrix: TMatrix;
begin
  Result:=Value;
end;

procedure TMatrixMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TMatrixMaterialParameter then
    PValue^:=TMatrixMaterialParameter(src).Value;
  inherited;
end;

procedure TMatrixMaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsMatrix;
end;

function TMatrixMaterialParameter.AsString(short: boolean): string;
var
  i, j: integer;
begin
  Result:='';
  if not short then
    for i:=0 to 3 do
      for j:=0 to 3 do
        Result:=Result + FloatToStr(Value[i][j]) + ';'
  else
    for i:=0 to 3 do
      for j:=0 to 3 do
        Result:=Result + FloatToStr(RoundTo(Value[i][j], -4)) + ';';
  SetLength(Result, Length(Result) - 1);
end;

procedure TMatrixMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetMatrix(FName, Value);
end;

procedure TMatrixMaterialParameter.Dump;
var
  m: TMatrix;
  i: integer;
begin
  inherited;
  m:=Value;
  for i:=0 to 3 do
    Log(Format('%.5f   %.5f   %.5f   %.5f', [m[0, i], m[1, i], m[2, i], m[3, i]]));
end;

function TMatrixMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TMatrixMaterialParameter) and MatrixEquals(FValue, TMatrixMaterialParameter(p).FValue);
end;

procedure TMatrixMaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
  Value:=conv.GetMatrix(FName);
end;

procedure TMatrixMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TMatrixMaterialParameter.GetShaderValue: string;
var
  i: integer;
begin
  i:=FOffset shr 2;
  Result:='float4x4(' +
    '$MATLIST[matIndex + ' + IntToStr(i) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 1) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 2) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 3) + '])';
end;

function TMatrixMaterialParameter.GetValue: TMatrix;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AsMatrix;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;
{
procedure TMatrixMaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and (root.HasAttribute('Value')) then
    DecodeBase64UtfToBuf(root.Attributes['Value'], PValue^, sizeof(FValue));
end;
}
procedure TMatrixMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and (root.HasAttribute('Value')) then
    DecodeBase64UtfToBuf(root.AttributeByName['Value'].Value, PValue^, sizeof(FValue));
end;

function TMatrixMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btMatrixMaterialParameterValue:
      begin
        ReadMatrix(PValue^);
        if MatrixEquals(PValue^, PMatrix(@NullHmgMatrix)^) then
          PValue^:=IdentityHmgMatrix;
      end;
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TMatrixMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TMatrixMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TMatrixMaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteMatrix(btMatrixMaterialParameterValue, PValue^);
  except
    on e: exception do
      SaveInfo.Error('TMatrixMaterialParameter: ' + e.Message);
  end;
  inherited;
end;
{
procedure TMatrixMaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.Attributes['Value']:=EncodeBase64Utf(PValue^, sizeof(FValue));
end;
}
procedure TMatrixMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.GetOrCreateAttr('Value').Value := EncodeBase64Utf(PValue^, sizeof(FValue));
end;

procedure TMatrixMaterialParameter.SetAsMatrix(const aValue: TMatrix);
begin
  Value:=aValue;
end;

procedure TMatrixMaterialParameter.Setup;
begin
  inherited;
  FType:=mptMatrix;
  PValue:=@FValue;
end;

procedure TMatrixMaterialParameter.SetValue(const Value: TMatrix);
var
  p: TMaterialParameter;
  m: TMatrix;
begin
  m:=GetValue;
  if not MatrixEquals(PMatrix(@Value)^, m) then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsMatrix(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TMatrixMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

{ TTexTransformMaterialParameter }

procedure TTexTransformMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TTexTransformMaterialParameter then
  begin
    PValue^ := TTexTransformMaterialParameter(src).Value;
    FMatrixCashe := TTexTransformMaterialParameter(src).FMatrixCashe;
  end;
  inherited;
end;

procedure TTexTransformMaterialParameter.AssignValue(src: TMaterialParameter);
begin
  if src is TTexTransformMaterialParameter then
  begin
    PValue^ := TTexTransformMaterialParameter(src).Value;
    FMatrixCashe := TTexTransformMaterialParameter(src).FMatrixCashe;
  end;
  inherited;
end;

function TTexTransformMaterialParameter.AsTexTransform: TTexTransformSettings;
begin
  Result := Value;
end;

function TTexTransformMaterialParameter.AsString(short: boolean): string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to High(FValue.All) do
  begin
    Result := Result + FloatToStr(FValue.All[i]);
    if i < High(FValue.All) then
      Result := Result + ';';
  end;
end;

function TTexTransformMaterialParameter.AsMatrix: TMatrix;
var
  mScale, mRotate, mTranslate: TMatrix;
begin
  mScale := CreateScaleMatrix(AffineVectorMake(FValue.Scale[0], FValue.Scale[1], 1));
  mRotate := CreateRotationMatrixZ(DegToRad(FValue.Rotation));
  mTranslate := CreateTranslationMatrix(AffineVectorMake(FValue.Offset[0], FValue.Offset[1], 0));
  Result := MatrixMultiply(mRotate, mScale);
  Result := MatrixMultiply(Result, mTranslate);
end;

procedure TTexTransformMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetMatrix(FName, FMatrixCashe);
end;

procedure TTexTransformMaterialParameter.Dump;
var
  S: String;
begin
  inherited;
  S := tr('Параметры преобразования текстуры:') +
    tr(' масштаб U=') + FloatToStr(FValue.Scale[0]) + ' V=' + FloatToStr(FValue.Scale[1]) +
    tr('; сдвиг U=') + FloatToStr(FValue.Offset[0]) + ' V=' + FloatToStr(FValue.Offset[1]) +
    tr('; поворот ') + FloatToStr(FValue.Rotation) + tr(' градусов');
  Log(S);
end;

function TTexTransformMaterialParameter.AngleEquals(Angle1, Angle2: Double): Boolean;
begin
  Angle1 := Angle1 - 360*Trunc(Angle1 / 360);
  if Angle1 < 0 then
    Angle1 := Angle1 + 360;
  Angle2 := Angle2 - 360*Trunc(Angle2 / 360);
  if Angle2 < 0 then
    Angle2 := Angle2 + 360;
  Result := Abs(Angle1 - Angle2) < 1e-5;
end;

function TTexTransformMaterialParameter.TransformEquals(Value1, Value2: TTexTransformSettings): Boolean;
begin
  Result := (Value1.Scale[0] = Value2.Scale[0]) and (Value1.Scale[1] = Value2.Scale[1]) and
    (Value1.Offset[0] = Value2.Offset[0]) and (Value1.Offset[1] = Value2.Offset[1]) and
    AngleEquals(Value1.Rotation, Value2.Rotation);
end;

function TTexTransformMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
var
  t: TTexTransformMaterialParameter;
begin
  Result := False;
  if inherited EqualTo(p) then
    if p is TTexTransformMaterialParameter then
    begin
      t := p as TTexTransformMaterialParameter;
      Result := TransformEquals(FValue, t.FValue);
    end;
end;

procedure TTexTransformMaterialParameter.ExtractFrom(conv: IMaterialConverter);
var
  m: TMatrix;
begin
  inherited;
  m := conv.GetMatrix(FName);
  SetAsMatrix(m);
end;

procedure TTexTransformMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TTexTransformMaterialParameter.GetShaderValue: string;
begin
  raise Exception.Create('TTexTransformMaterialParameter.GetShaderValue is not implemented yet');
end;

function TTexTransformMaterialParameter.GetValue: TTexTransformSettings;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p := FLink.LockRef;
    try
      if p <> nil then
      begin
        Result := p.AsTexTransform;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result := PValue^;
end;

function TTexTransformMaterialParameter.GetMatrixCashe: TMatrix;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p := FLink.LockRef;
    try
      if (p <> nil) and (p is TTexTransformMaterialParameter) then
      begin
        Result := (p as TTexTransformMaterialParameter).MatrixCashe;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result := FMatrixCashe;
end;

function TTexTransformMaterialParameter.GetMatrixCashePointer: PMatrix;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p := FLink.LockRef;
    try
      if (p <> nil) and (p is TTexTransformMaterialParameter) then
      begin
        Result := (p as TTexTransformMaterialParameter).MatrixCashePointer;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result := PMatrixCashe;
end;

procedure TTexTransformMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if Assigned(root) then
  begin
    if root.HasAttribute('Value') then
      DecodeBase64UtfToBuf(root.AttributeByName['Value'].Value, PValue^, sizeof(FValue));
    if root.HasAttribute('ScaleU') then
      FValue.Scale[0] := root.AttributeByName['ScaleU'].ValueAsFloat;
    if root.HasAttribute('ScaleV') then
      FValue.Scale[1] := root.AttributeByName['ScaleV'].ValueAsFloat;
    if root.HasAttribute('OffsetU') then
      FValue.Offset[0] := root.AttributeByName['OffsetU'].ValueAsFloat;
    if root.HasAttribute('OffsetV') then
      FValue.Offset[1] := root.AttributeByName['OffsetV'].ValueAsFloat;
    if root.HasAttribute('Rotation') then
      FValue.Rotation := root.AttributeByName['Rotation'].ValueAsFloat;
  end;
end;

function TTexTransformMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btTexTransformMaterialParameterValue:
        begin
          Read(PValue^, SizeOf(FValue));
          if (PValue^.Scale[0] = 0) then
            PValue^.Scale[0] := 1;
          if (PValue^.Scale[1] = 0) then
            PValue^.Scale[1] := 1;
        end;
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TTexTransformMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TTexTransformMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TTexTransformMaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    Write(btTexTransformMaterialParameterValue, PValue^, SizeOf(FValue));
  except
    on e: exception do
      SaveInfo.Error('TTexTransformMaterialParameter: ' + e.Message);
  end;
  inherited;
end;

procedure TTexTransformMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    //root.GetOrCreateAttr('Value').Value := EncodeBase64Utf(PValue^, sizeof(FValue));
    root.GetOrCreateAttr('ScaleU').ValueAsFloat := FValue.Scale[0];
    root.GetOrCreateAttr('ScaleV').ValueAsFloat := FValue.Scale[1];
    root.GetOrCreateAttr('OffsetU').ValueAsFloat := FValue.Offset[0];
    root.GetOrCreateAttr('OffsetV').ValueAsFloat := FValue.Offset[1];
    root.GetOrCreateAttr('Rotation').ValueAsFloat := FValue.Rotation;
  end;
end;

procedure TTexTransformMaterialParameter.Setup;
begin
  inherited;
  FValue.Scale[0] := 1;
  FValue.Scale[1] := 1;
  FType := mptTexTransform;
  PValue := @FValue;
  FMatrixCashe := AsMatrix;
  PMatrixCashe := @FMatrixCashe;
end;

procedure TTexTransformMaterialParameter.SetAsTexTransform(const value: TTexTransformSettings);
begin
  SetValue(value);
end;

procedure TTexTransformMaterialParameter.SetAsMatrix(const m: TMatrix);
var
  Transformation: TTexTransformSettings;
  nm: TMatrix;
begin
	Transformation.Scale[0] := VectorLength(m[0]) * Sign(m[0, 0]);
	Transformation.Scale[1] := VectorLength(m[1]) * Sign(m[1, 1]);
  Transformation.Offset[0] := m[3, 0];
  Transformation.Offset[1] := m[3, 1];
  nm := m;
  NormalizeMatrix(nm);
  Transformation.Rotation := RadToDeg(ArcCos(nm[0, 0])) * Sign(nm[0, 1]);
  SetValue(Transformation);
end;

procedure TTexTransformMaterialParameter.SetValue(const Value: TTexTransformSettings);
var
  p: TMaterialParameter;
  t: TTexTransformSettings;
begin
  t := GetValue;
  if not TransformEquals(t, Value) then
  begin
    if assigned(FLink) then
    begin
      p := FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsTexTransform(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    FMatrixCashe := AsMatrix;
    ParameterChanged;
  end;
end;

procedure TTexTransformMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

function TTexTransformMaterialParameter.GetRenderMatrix: TMatrix;
begin
	Result:=MatrixMultiply(AsMatrix, MatrixMultiply(
		CreateScaleMatrix(DAffineVectorMake(1, -1, 1)), CreateTranslationMatrix(AffineVectorMake(0, 1, 0))));
end;


{ TTexWrapModeMaterialParameter }

procedure TTexWrapModeMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TTexWrapModeMaterialParameter then
    PValue^ := TTexWrapModeMaterialParameter(src).Value;
  inherited;
end;

procedure TTexWrapModeMaterialParameter.AssignValue(
  src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsTexWrapMode;
end;

function TTexWrapModeMaterialParameter.AsString(short: boolean): string;
var
  i: Integer;
begin
  Result := '';
  for i:=Low(Value.All) to High(Value.All) do
  begin
    case Value.All[i] of
      twmClamp:   Result := Result + 'clamp';
    else
      Result := Result + 'wrap';
    end;
    if (i < High(Value.All)) then
      Result := Result + ';'
  end;
end;

function TTexWrapModeMaterialParameter.AsTexWrapMode: TTexWrapMode;
begin
  Result := Value;
end;

procedure TTexWrapModeMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetTexWrapMode(FName, Value);
end;

procedure TTexWrapModeMaterialParameter.Dump;
begin
  inherited;
  Log(tr('Границы текстуры:') + AsString(false));
end;

function TTexWrapModeMaterialParameter.EqualTo(
  p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TTexWrapModeMaterialParameter) and IsEqual(TTexWrapModeMaterialParameter(p).FValue);
end;

procedure TTexWrapModeMaterialParameter.ExtractFrom(
  conv: IMaterialConverter);
begin
  inherited;
  Value:=conv.GetTexWrapMode(FName);
end;

procedure TTexWrapModeMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TTexWrapModeMaterialParameter.GetValue: TTexWrapMode;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p := FLink.LockRef;
    try
      if p <> nil then
      begin
        Result := p.AsTexWrapMode;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result := PValue^;
end;

function TTexWrapModeMaterialParameter.IsEqual(
  const aValue: TTexWrapMode): Boolean;
begin
  Result := (FValue.U = aValue.U) and (FValue.V = aValue.V) and (FValue.W = aValue.W);
end;

procedure TTexWrapModeMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and (root.HasAttribute('Value')) then
    SetAsString(root.AttributeByName['Value'].Value);
end;

function TTexWrapModeMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btTexWrapModeMaterialParameterValue: Read(PValue^, sizeof(FValue));
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TTexWrapModeMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TTexWrapModeMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TTexWrapModeMaterialParameter.SaveObject(
  var SaveInfo: TSaveInfo);
begin
  with SaveInfo, Writer do
  try
    Write(btTexWrapModeMaterialParameterValue, PValue^, SizeOf(FValue));
  except
    on e: exception do
      SaveInfo.Error('TTexWrapModeMaterialParameter: ' + e.Message);
  end;
  inherited;
end;

procedure TTexWrapModeMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.GetOrCreateAttr('Value').Value := AsString(false);
end;

procedure TTexWrapModeMaterialParameter.SetAsString(const value: string);
  function ReadMode(str: string): TTexAddressMode;
  begin
    if LowerCase(str) = 'clamp' then
      Result := twmClamp
    else
      Result := twmWrap;
  end;
var
  i: integer;
begin
  with ExplodeStrChar(';', value) do
  try
    for i:=0 to Count - 1 do
      if (i <= High(FValue.All)) then
        FValue.All[i] := ReadMode(Strings[i]);
  finally
    Free;
  end;
end;

procedure TTexWrapModeMaterialParameter.SetAsTexWrapMode(
  const value: TTexWrapMode);
begin
  SetValue(value);
end;

procedure TTexWrapModeMaterialParameter.Setup;
begin
  inherited;
  FType := mptTexWrapMode;
  PValue := @FValue;
end;

procedure TTexWrapModeMaterialParameter.SetValue(
  const aValue: TTexWrapMode);
var
  p: TMaterialParameter;
begin
  if not IsEqual(aValue) then
  begin
    if assigned(FLink) then
    begin
      p := FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsTexWrapMode(aValue);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := aValue;
    ParameterChanged;
  end;
end;


procedure TTexWrapModeMaterialParameter.WriteToFiler(
  WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

{ TTextureMaterialParameter }

procedure TTextureMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TTextureMaterialParameter then
  begin
    PValue^:=TTextureMaterialParameter(src).Value;
    FEnabled:=TTextureMaterialParameter(src).FEnabled;
  end;
  inherited;
end;

procedure TTextureMaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsTextureValue;
  if src is TTextureMaterialParameter then
    FEnabled := TTextureMaterialParameter(src).FEnabled;
end;

function TTextureMaterialParameter.AsString(short: boolean): string;
begin
  Result:='';
end;

function TTextureMaterialParameter.AsTextureValue: TTextureValue;
begin
  Result:=Value;
end;

procedure TTextureMaterialParameter.TuneParameter;
var
  p: PMapKinds;
begin
  p:=FindMapKindsByName(FName);
  if Assigned(p) then
  begin
    FAltName := p.altname;
    FCategory := p.category;
    FCustomizable := True;
    FOptional := True;
  end;
end;

procedure TTextureMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetTextureValue(FName, Value);
end;

function TTextureMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TTextureMaterialParameter) and comparemem(@FValue, @TTextureMaterialParameter(p).FValue, sizeof(FValue)) and (FEnabled = TTextureMaterialParameter(p).FEnabled);
end;

procedure TTextureMaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
  Value:=conv.GetTextureValue(FName);
end;

function TTextureMaterialParameter.GetAtlasPositionForShader: string;
begin
  Result:='$MATLIST[matIndex + ' + IntToStr(FOffset shr 2) + '].';
  case FOffset and 3 of
    1: Result:=Result + 'yzw';
    2: Result:='float3(' + Result + 'zw, $MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].x)';
    3: Result:='float3(' + Result + 'w, $MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].xy)';
  else
    Result:=Result + 'xyz';
  end;
end;

function TTextureMaterialParameter.GetAtlasScaleForShader: string;
begin
  case FOffset and 3 of
    1: Result:='$MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].xy';
    2: Result:='$MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].yz';
    3: Result:='$MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].zw';
  else
    Result:='float2($MATLIST[matIndex + ' + IntToStr(FOffset shr 2) + '].' + 'w, $MATLIST[matIndex + ' + IntToStr((FOffset shr 2) + 1) + '].x)';
  end;
end;

procedure TTextureMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TTextureMaterialParameter.GetEnabled: boolean;
begin
  Result:=FEnabled;
end;

function TTextureMaterialParameter.GetShaderDefaultValue: string;
begin
  Result:='CreateAtlasUV(float4(0, 0, 0, 0), 0)';
end;

function TTextureMaterialParameter.GetShaderValue: string;
var
  i: integer;
begin
  i:=FOffset shr 2;
  Result:='CreateAtlasUV(' +
    '$MATLIST[matIndex + ' + IntToStr(i) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 1) + '].x)';
end;

function TTextureMaterialParameter.GetValue: TTextureValue;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AsTextureValue;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;
{
procedure TTextureMaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    if root.HasAttribute('Value') then
      DecodeBase64UtfToBuf(root.Attributes['Value'], PValue^, sizeof(FValue));
    if root.HasAttribute('Enabled') then
      FEnabled:=Boolean(root.Attributes['Enabled']);
  end;
end;
}
procedure TTextureMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    if root.HasAttribute('Value') then
      DecodeBase64UtfToBuf(root.AttributeByName['Value'].Value, PValue^, sizeof(FValue));
    if root.HasAttribute('Enabled') then
      FEnabled := Boolean(root.AttributeByName['Enabled'].ValueAsInteger);
  end;
end;

function TTextureMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btTextureMaterialParameterValue: Read(PValue^, sizeof(TTextureValue));
      btTextureMaterialParameterEnabled: ReadBoolean(FEnabled);
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TTextureMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

const
  cmTexMatParamEnable: cardinal = $81DAB346;

procedure TTextureMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  with ReadInfo.Reader do
  begin
    Read(FValue, SizeOf(FValue));
    if CheckMagic(cmTexMatParamEnable) then
      FEnabled:=ReadInfo.Reader.ReadBoolean;
  end;
end;

procedure TTextureMaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    Write(btTextureMaterialParameterValue, PValue^, SizeOf(TTextureValue));
    WriteBoolean(btTextureMaterialParameterEnabled, FEnabled);
  except
    on e: exception do
      SaveInfo.Error('TTextureMaterialParameter: ' + e.Message);
  end;
  inherited;
end;
{
procedure TTextureMaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    root.Attributes['Value']:=EncodeBase64Utf(PValue^, sizeof(FValue));
    root.Attributes['Enabled']:=Integer(FEnabled);
  end;
end;
}
procedure TTextureMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    root.GetOrCreateAttr('Value').Value := EncodeBase64Utf(PValue^, sizeof(FValue));
    root.GetOrCreateAttr('Enabled').ValueAsInteger := Integer(FEnabled);
  end;
end;

procedure TTextureMaterialParameter.SetAsTextureValue(
  const aValue: TTextureValue);
begin
  Value:=aValue;
end;

procedure TTextureMaterialParameter.SetAtlas(atlas: TMaterialTextureAtlas; textures: TSimpleTexturesList);
var
  t: TAtlasMaterialTexture;
  item: TSimpleTexturesListItem;
begin
  inherited;
  if textures.FindTextureItem(FName, item)
    and atlas.AtlasContent.Find(item.GetTextureID, t) then
      Value:=t.TextureAtlasPositionAndScale[FWrapMode];
end;

procedure TTextureMaterialParameter.SetEnabled(const Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled:=Value;
    ParameterChanged;
  end;
end;

procedure TTextureMaterialParameter.Setup;
begin
  inherited;
  FType:=mptTexture;
  FCustomizable:=true;
  FEnabled:=true;
  PValue:=@FValue;
end;

function TextureValueEquals(const v1, v2: TTextureValue): boolean;
var
  i: Integer;
begin
  Result := False;
  i := 0;
  while i < Length(v1.IndexArr) do
  begin
    if not VectorEquals(v1.IndexArr[i], v2.IndexArr[i]) then
      Exit;
    if not VectorEquals(TVector2f(v1.ScaleArr[i]), TVector2f(v2.ScaleArr[i])) then
      Exit;
    Inc(i);
  end;
  Result:=VectorEquals(v1.Index, v2.Index) and VectorEquals(TVector2f(v1.Scale), TVector2f(v2.Scale))
    and (v1.MaxLod = v2.MaxLod) and (v1.TexelScale = v2.TexelScale) and (v1.TexelSize[0] = v2.TexelSize[0])
    and (v1.TexelSize[1] = v2.TexelSize[1]);
end;

procedure TTextureMaterialParameter.SetValue(const Value: TTextureValue);
var
  p: TMaterialParameter;
begin
  if not TextureValueEquals(Value, GetValue) then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsTextureValue(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TTextureMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  with WriteInfo.Writer do
  begin
    Write(FValue, SizeOf(FValue));
    WriteMagic(cmTexMatParamEnable);
    WriteBoolean(FEnabled);
  end;
end;

{ TStringMaterialParameter }

function TStringMaterialParameter.AsString(short: boolean): string;
begin
  Result:=Value;
end;

procedure TStringMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TStringMaterialParameter then
    PValue^:=TStringMaterialParameter(src).Value;
  inherited;
end;

procedure TStringMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
  conv.SetString(FName, Value);
end;

procedure TStringMaterialParameter.Dump;
var
  m: TMatrix;
  i: integer;
begin
  inherited;
  Log(Format('Parameter: %s = %s', [FName, Value]));
end;

function TStringMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TStringMaterialParameter) and
          (LowerCase(FValue) = TStringMaterialParameter(p).FName);
end;

procedure TStringMaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
  Value := conv.GetString(FName);
end;

procedure TStringMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TStringMaterialParameter.GetShaderValue: string;
var
  i: integer;
begin
  {i:=FOffset shr 2;
  Result:='float4x4(' +
    '$MATLIST[matIndex + ' + IntToStr(i) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 1) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 2) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 3) + '])';}
  Result:='';
end;

function TStringMaterialParameter.GetValue: string;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AsString;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;
{
procedure TStringMaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and root.HasAttribute('Value') then
    Value := root.Attributes['Value'];
end;
}
procedure TStringMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) and root.HasAttribute('Value') then
    Value := Utf8ToAnsi(root.AttributeByName['Value'].Value);
end;

function TStringMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btStringMaterialParameterValue: ReadString(PValue^);
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TStringMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TStringMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  PValue^:=ReadInfo.Reader.ReadString();
end;

procedure TStringMaterialParameter.SaveObject(var SaveInfo: TSaveInfo);
begin
  with SaveInfo, Writer do
  begin
    WriteString(btStringMaterialParameterValue, PValue^);
  end;
  inherited;
end;
{
procedure TStringMaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.Attributes['Value']:=Value;
end;
}
procedure TStringMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.GetOrCreateAttr('Value').Value := AnsiToUtf8(Value);
end;

procedure TStringMaterialParameter.SetAsString(const aValue: string);
begin
  Value:=aValue;
end;

procedure TStringMaterialParameter.Setup;
begin
  inherited;
  //FType:=mptString;
  PValue:=@FValue;
end;

procedure TStringMaterialParameter.SetValue(const Value: string);
var
  p: TMaterialParameter;
begin
  if GetValue <> Value then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsString(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TStringMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.WriteString(FValue);
end;

procedure TStringMaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  Value:=src.AsString;
end;

{ TMonoMaterialParameter }

function TMonoMaterialParameter.AsMonoMaterial: TMaterial;
begin
  Result := FMatLib.Find(Value);
end;

procedure TMonoMaterialParameter.Assign(src: TMaterialParameter);
var
  mat: TMaterial;
  newMat: TMaterial;
  param: TMonoMaterialParameter;
  ind: Integer;
begin
  {if src is TMonoMaterialParameter then
  begin
    TMonoMaterialParameter(src).FMatLib
    matLib := TMaterialList(FValue.FOwner);
    ind := matLib.IndexOf(FValue.FName);
    if ind >= 0 then
      matLib.Delete(ind);
    //PValue^:=TMonoMaterialParameter(src).Value;
    PValue^.Assign(TMonoMaterialParameter(src).Value);
    FMonoMaterialInd := TMonoMaterialParameter(src).FMonoMaterialInd;
    FEnabled := TMonoMaterialParameter(src).FEnabled;
    if Value.FName <> '' then
      matLib.Add(Value);
  end;
  inherited;   }
  if (src is TMonoMaterialParameter) and (FMatLib <> nil) then
  begin
    ind := FMatLib.IndexOf(Value);
    if ind >= 0 then
      FMatLib.Delete(ind);
    param := TMonoMaterialParameter(src);
    mat := TMaterial(param.FMatLib.Find(param.Value));
    if mat <> nil then
    begin
      newMat := MaterialTypes.FindMaterialClassByName(mat.ClassName).Create(Self);
      newMat.Assign(mat);
      FMatLib.Add(newMat);
    end;
    Value := param.Value;
    FMonoMaterialInd := param.FMonoMaterialInd;
  end;
  inherited;
end;

procedure TMonoMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  if FMonoMaterialInd = 0 then
  begin
    inherited;
    AsMonoMaterial.Parameters.WriteValues(conv);
  end;
end;

procedure TMonoMaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  if FMonoMaterialInd = 0 then
  begin
    inherited;
    AsMonoMaterial.Parameters.ReadValues(conv);
  end;
end;

procedure TMonoMaterialParameter.Dump;
var
  m: TMatrix;
  i: integer;
begin
  inherited;
  Log(Format('Parameter: %s = %s', [FName, Value]));
end;

function TMonoMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=inherited EqualTo(p) and (p is TMonoMaterialParameter) and
          (LowerCase(Value) = LowerCase(TMonoMaterialParameter(p).Value)) and
          (AsMonoMaterial.EqualTo(TMonoMaterialParameter(p).AsMonoMaterial));
end;

procedure TMonoMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TMonoMaterialParameter.GetShaderValue: string;
var
  i: integer;
begin
  {i:=FOffset shr 2;
  Result:='float4x4(' +
    '$MATLIST[matIndex + ' + IntToStr(i) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 1) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 2) + '], ' +
    '$MATLIST[matIndex + ' + IntToStr(i + 3) + '])';}
  Result:='';
end;

function TMonoMaterialParameter.GetValue: string;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TMonoMaterialParameter then
      begin
        Result:=TMonoMaterialParameter(p).Value;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=PValue^;
end;

procedure TMonoMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TMonoMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  with WriteInfo.Writer do
  begin
    WriteInfo.Writer.WriteString(Value);
    Write(FMonoMaterialInd, SizeOf(FMonoMaterialInd));
    {Write(FMonoMaterialInd, SizeOf(FMonoMaterialInd));
    WriteBoolean(FEnabled);
    (PValue)^.WriteToFiler(WriteInfo);}
  end;
end;

procedure TMonoMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
var
  matName: string;
begin
  inherited;
  with ReadInfo.Reader do
  begin
    matName := ReadInfo.Reader.ReadString();
    Value := matName;
    Read(FMonoMaterialInd, SizeOf(FMonoMaterialInd));
  end;
end;

procedure TMonoMaterialParameter.SaveObject(var SaveInfo: TSaveInfo);
begin
  with SaveInfo, Writer do
  begin
    WriteString(btStringMaterialParameterValue, Value);
    WriteInteger(btIntegerMaterialParameterValue, FMonoMaterialInd);
    {WriteInteger(btIntegerMaterialParameterValue, FMonoMaterialInd);
    WriteBoolean(btTextureMaterialParameterEnabled, FEnabled);
    BeginChild(btMaterialListItem, Value.ClassName, Value.Name);
    Value.SaveObject(SaveInfo);
    EndChild;  }
  end;
  inherited;
end;

function TMonoMaterialParameter.GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
                                                const ChildClass: string; const ChildID: string): TObject;
var
  mat: TMaterial;
begin
  with LoadInfo do
  case ChildBlockType of
    btMaterialListItem:
    begin
      mat := MaterialTypes.FindMaterialClassByName(ChildClass).Create(FMatLib);
      Value := ChildID;
      if ChildID <> '' then
        FMatLib.Add(mat);
      Result := mat;
    end;
  else
    Result:=CL_UNKNOWN_OBJECT;
  end;
end;

function TMonoMaterialParameter.LoadParam(var LoadInfo: TLoadInfo): integer;
var
  Enabled: Boolean;
  matName: string;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btIntegerMaterialParameterValue: ReadInteger(FMonoMaterialInd);
      btTextureMaterialParameterEnabled: ReadBoolean(Enabled);
      btStringMaterialParameterValue:
      begin
        ReadString(matName);
        Value := matName;
      end;
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TMonoMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if Assigned(root) then
  begin
    root.GetOrCreateAttr('MonoMatName').Value := AnsiToUtf8(Value);
    root.GetOrCreateAttr('MonoMatInd').ValueAsInteger := FMonoMaterialInd;
    {root.GetOrCreateAttr('MonoMatInd').ValueAsInteger := FMonoMaterialInd;
    root.GetOrCreateAttr('Enabled').ValueAsInteger := Integer(FEnabled);
    Value.SaveToXml(root.NodeNew('MonoMaterial'), SaveFlags);}
  end;
end;

procedure TMonoMaterialParameter.LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal);
var
  enabled: Boolean;
  mat: TMaterial;
  node: TXMLNode;
  aType: Integer;
begin
  inherited;
  if Assigned(root) then
  begin
    if root.HasAttribute('MonoMatInd') then
      FMonoMaterialInd := root.AttributeByName['MonoMatInd'].ValueAsInteger;
    if root.HasAttribute('MonoMatName') then//загрузка по-новому
    begin
      Value := Utf8ToAnsi(root.AttributeByName['MonoMatName'].Value);
    end
    else
    begin//загрузка по-старому
      if root.HasAttribute('Enabled') then
        enabled := Boolean(root.AttributeByName['Enabled'].ValueAsInteger);
      node := root.FindNode('MonoMaterial');
      if Assigned(root) and (node.HasAttribute('Type')) then
      begin
        aType := node.AttributeByName['Type'].ValueAsInteger;
        mat := MaterialTypes.FindMaterialClass(aType).Create(FMatLib);
        mat.LoadFromXml(node, LoadFlags);
        Value := mat.FName;
        if mat.FName <> '' then
          FMatLib.Add(mat)
        else
          mat.Free;
      end;
    end;
  end;
end;

procedure TMonoMaterialParameter.SetAsMonoMaterial(const aValue: TMaterial);
begin
  //Value:=aValue;
end;

procedure TMonoMaterialParameter.Setup;
begin
  inherited;
  FType:=mptMonoMaterial;
  FValue := '';
  PValue:=@FValue;
end;

procedure TMonoMaterialParameter.SetValue(const Value: string);
var
  matLib: TMaterialList;
  ind: Integer;
  p: TMaterialParameter;
begin
  if (GetValue <> Value) then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p is TMonoMaterialParameter then
        begin
          TMonoMaterialParameter(p).SetValue(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

function FilterLoadParameters(const p: TMaterialParameter): boolean;
begin
  Result:=(p is TTextureMaterialParameter = false) and (p is TMonoMaterialParameter = false);
end;

procedure TMonoMaterialParameter.CreateMaterial(const mat: TMaterial; const newMatName: string;
                                                const withTextures: Boolean = True);
var
  newMat: TMaterial;
begin
  newMat := MaterialTypes.FindMaterialClassByName(mat.ClassName).Create(FMatLib);
  if withTextures then
    newMat.Assign(mat)
  else
    newMat.Parameters.AssignValuesFrom(mat.Parameters, FilterLoadParameters);
  newMat.FName := newMatName;
  newMat.FriendlyName := '';
  FMatLib.Add(newMat);
  Value := newMatName;
  ParameterChanged;
end;

function TMonoMaterialParameter.AsString(short: boolean): string;
begin
  Result:=Value;
end;

procedure TMonoMaterialParameter.AssignValue(src: TMaterialParameter);
var
  ind: Integer;
  mat, newMat: TMaterial;
  param: TMonoMaterialParameter;
begin
  inherited;
  if (src is TMonoMaterialParameter) then
  begin
    param := TMonoMaterialParameter(src);
    if (FMatLib <> nil) and (FMatLib <> param.FMatLib) then
    begin
      ind := FMatLib.IndexOf(Value);
      if ind >= 0 then
        FMatLib.Delete(ind);
    end;
    if (param.FMatLib <> nil) and (FMatLib <> param.FMatLib) then
    begin
      mat := TMaterial(param.FMatLib.Find(param.Value));
      if mat <> nil then
      begin
        newMat := MaterialTypes.FindMaterialClassByName(mat.ClassName).Create(Self);
        newMat.Assign(mat);
        FMatLib.Add(newMat);
      end;
    end;
    Value := TMonoMaterialParameter(src).Value;
  end;
  inherited;
end;

function TMonoMaterialParameter.GetMatLib: IMaterialLibrary;
begin
  Result := FMatLib;
end;

function TMonoMaterialParameter.GetMonoMaterialInd: Integer;
begin
  Result := FMonoMaterialInd;
end;

procedure TMonoMaterialParameter.Rename(const newMatName: string);
var
  mat: TMaterial;
begin
  mat := FMatLib.Find(Value);
  if mat <> nil then
  begin
    mat.Name := newMatName;
    mat.FriendlyName := '';
    Value := newMatName;
  end;
end;

function TMonoMaterialParameter.GetMonoMaterial: TMaterial;
begin
  Result := AsMonoMaterial;
end;

function TMonoMaterialParameter.GetEnabled: Boolean;
begin
  if Value <> '' then
    Result := True
  else
    Result := False;
end;

function TMonoMaterialParameter.ClassFilter: TClass;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TMonoMaterialParameter then
      begin
        Result:=TMonoMaterialParameter(p).ClassFilter;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=FClassFilter;
end;

{ TReflMaterialParameter }

function TReflMaterialParameter.AsReflStruct: TReflStruct;
begin
  Result:=Value;
end;

procedure TReflMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TReflMaterialParameter then
  begin
    PValue^:=TReflMaterialParameter(src).Value;
  end;
  inherited;
end;

procedure TReflMaterialParameter.AssignValue(src: TMaterialParameter);
begin
  inherited;
  if src is TReflMaterialParameter then
  begin
    Value := src.AsReflStruct;
  end;
end;

function TReflMaterialParameter.AsString(short: boolean): string;
var
  i: integer;
begin
  Result := IntToStr(Value.isMetal) + ';';
  Result := Result + FloatToStr(Value.index[0]) + ';' + FloatToStr(Value.index[1]) + ';' + FloatToStr(Value.index[2]) + ';';
  Result := Result + FloatToStr(Value.extinction[0]) + ';' + FloatToStr(Value.extinction[1]) + ';' + FloatToStr(Value.extinction[2]);
end;

procedure TReflMaterialParameter.CopyTo(conv: IMaterialConverter);
begin
  inherited;
end;

procedure TReflMaterialParameter.Dump;
var
  s: string;
begin
  inherited;
  s := 'isMetal: ' + IntToStr(Value.isMetal) + ';';
  s := s + 'index: ' + FloatToStr(Value.index[0]) + ';' + FloatToStr(Value.index[1]) + ';' + FloatToStr(Value.index[2]) + ';';
  s := s + 'extenction: ' + FloatToStr(Value.extinction[0]) + ';' + FloatToStr(Value.extinction[1]) + ';' + FloatToStr(Value.extinction[2]);
  Log(s);
end;

function TReflMaterialParameter.ReflStructEquals(const val1, val2: TReflStruct): Boolean;
begin
  Result := (val1.isMetal = val2.isMetal) and VectorEquals(val1.index, val2.index) and
             VectorEquals(val1.extinction, val2.extinction);
end;

function TReflMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
var
  rp: TReflMaterialParameter;
begin
  Result := False;
  if inherited EqualTo(p) and (p is TReflMaterialParameter) then
  begin
    rp := p as TReflMaterialParameter;
    Result := ReflStructEquals(Value, rp.Value);
  end;
end;

procedure TReflMaterialParameter.ExtractFrom(conv: IMaterialConverter);
begin
  inherited;
end;

procedure TReflMaterialParameter.GetDataFrom(p: pointer);
begin
  inherited;
  Move(p^, PValue^, sizeof(FValue));
end;

function TReflMaterialParameter.GetShaderValue: string;
begin

end;

function TReflMaterialParameter.GetValue: TReflStruct;
  var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p := FLink.LockRef;
    try
      if p <> nil then
      begin
        Result := p.AsReflStruct;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result := PValue^;
end;

procedure TReflMaterialParameter.LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal);
begin
  inherited;
  if Assigned(root) then
  begin
    if root.HasAttribute('isMetal') then
      FValue.isMetal := root.AttributeByName['isMetal'].ValueAsInteger;
    if root.HasAttribute('indexX') then
      FValue.index[0] := root.AttributeByName['indexX'].ValueAsFloat;
    if root.HasAttribute('indexY') then
      FValue.index[1] := root.AttributeByName['indexY'].ValueAsFloat;
    if root.HasAttribute('indexZ') then
      FValue.index[2] := root.AttributeByName['indexZ'].ValueAsFloat;
    if root.HasAttribute('extinctionX') then
      FValue.extinction[0] := root.AttributeByName['extinctionX'].ValueAsFloat;
    if root.HasAttribute('extinctionY') then
      FValue.extinction[1] := root.AttributeByName['extinctionY'].ValueAsFloat;
    if root.HasAttribute('extinctionZ') then
      FValue.extinction[2] := root.AttributeByName['extinctionZ'].ValueAsFloat;
  end;
end;

function TReflMaterialParameter.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btReflMaterialParameterValue:
        begin
          Read(PValue^, SizeOf(FValue));
        end;
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TReflMaterialParameter.PlaceDataAt(p: pointer);
begin
  inherited;
  Move(PValue^, p^, sizeof(FValue));
end;

procedure TReflMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  ReadInfo.Reader.Read(FValue, SizeOf(FValue));
end;

procedure TReflMaterialParameter.SaveObject(var SaveInfo: TSaveInfo);
begin
  with SaveInfo, Writer do
  try
    Write(btReflMaterialParameterValue, PValue^, SizeOf(FValue));
  except
    on e: exception do
      SaveInfo.Error('TReflMaterialParameter: ' + e.Message);
  end;
  inherited;
end;

procedure TReflMaterialParameter.SaveToXml(const root: TXMLNode; const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    root.GetOrCreateAttr('isMetal').ValueAsInteger := Value.isMetal;
    root.GetOrCreateAttr('indexX').ValueAsFloat := Value.index[0];
    root.GetOrCreateAttr('indexY').ValueAsFloat := Value.index[1];
    root.GetOrCreateAttr('indexZ').ValueAsFloat := Value.index[2];
    root.GetOrCreateAttr('extinctionX').ValueAsFloat := Value.extinction[0];
    root.GetOrCreateAttr('extinctionY').ValueAsFloat := Value.extinction[1];
    root.GetOrCreateAttr('extinctionZ').ValueAsFloat := Value.extinction[2];
  end;
end;

procedure TReflMaterialParameter.SetAsReflStruct(const aValue: TReflStruct);
begin
  Value := aValue;
end;

procedure TReflMaterialParameter.Setup;
begin
  inherited;
  FType := mptReflStruct;
  PValue := @FValue;
end;

procedure TReflMaterialParameter.SetValue(const Value: TReflStruct);
var
  p: TMaterialParameter;
begin
  if not ReflStructEquals(GetValue, Value) then
  begin
    if assigned(FLink) then
    begin
      p := FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsReflStruct(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    PValue^ := Value;
    ParameterChanged;
  end;
end;

procedure TReflMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.Write(FValue, SizeOf(FValue));
end;

{ TMaterialParameters }

procedure TMaterialParameters.AddTypes(aLib: TMaterialParamsTypeLibrary);
var
  i: integer;
begin
  for i:=0 to count - 1 do
    if aLib.IndexOf(TMaterialParameter(List[i]).RootClass.ClassName) = -1 then
      aLib.AddObject(TMaterialParameter(List[i]).RootClass.ClassName, List[i]);
end;

procedure TMaterialParameters.Assign(src: TMaterialParameters);
var
  i: integer;
  notFound: TList;
  p: TMaterialParameter;
begin
  notFound:=TList.Create;
  try
    for i:=0 to src.Count - 1 do
      if FindParameter(TMaterialParameter(src.List[i]).FName, p) then
        p.Assign(TMaterialParameter(src.List[i]))
      else
        notFound.Add(src.List[i]);
    for i:=0 to notFound.Count - 1 do
    begin
      p:=TMaterialParameter(notFound.List[i]);
      NewParameter(p.FName, TMaterialParameterClass(p.ClassType)).Assign(p);
    end;
  finally
    notFound.Free;
  end;
{ Если так делать, то ссылки на параметры в материалах поломаются
  Clear;
  for i:=0 to src.Count - 1 do
    NewParameter(TMaterialParameter(src.List[i]).FName,
      TMaterialParameterClass(TObject(src.List[i]).ClassType)).Assign(TMaterialParameter(src.List[i]));}
end;

procedure TMaterialParameters.AssignFrom(src: TMaterialParameters);
var
  i: integer;
  p: TMaterialParameter;
begin
  for i:=0 to count - 1 do
    if ((TMaterialParameter(List[i]).FType <> mptInteger) or (AnsiCompareText(TMaterialParameter(List[i]).FName, 'type') <> 0)) and
      src.FindParameter(TMaterialParameter(List[i]).FName, p) then
        TMaterialParameter(List[i]).Assign(p);
  ParameterChanged(nil);
end;

procedure TMaterialParameters.BeginUpdate;
begin
  Inc(FUpdateCounter);
end;

function TMaterialParameters.CheckLinks: string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to count - 1 do
    if (TMaterialParameter(List[i]).FInspectors <> nil) and (TMaterialParameter(List[i]).FInspectors.Count > 0) then
    begin
      Result:=Result + TMaterialParameter(List[i]).FName + ' ' + IParameterInspector(TMaterialParameter(List[i]).FInspectors[0]).QueryClassName + #13#10;
      exit;
    end;
end;

procedure TMaterialParameters.CountOffsets;
var
  i, offset: integer;
begin
  offset:=0;
  for i:=0 to count - 1 do
    TMaterialParameter(List[i]).CountOffset(offset);
end;

constructor TMaterialParameters.Create(aOwner: TObject);
begin
  FDirtFlag:=True;
  FOwner:=aOwner;
  FGroupNames:=TStringList.Create;
  Create;
  exit;
  ListParams;
end;

destructor TMaterialParameters.Destroy;
begin
  FGroupNames.Free;
  inherited;
end;

procedure TMaterialParameters.Dump;
var
  i: integer;
begin
  for i:=0 to count - 1 do
    TMaterialParameter(List[i]).Dump;
end;

procedure TMaterialParameters.EndUpdate;
begin
  if FUpdateCounter > 0 then
  begin
    Dec(FUpdateCounter);
    if FUpdateCounter = 0 then
      Resort;
  end;
end;

function TMaterialParameters.EqualTo(p: TMaterialParameters): boolean;
var
  i: integer;
  p0: TMaterialParameter;
begin
  Result:=false;
  if (Count <> p.Count) then exit;
  for i:=0 to Count-1 do
  begin
    if p.FindParameter(TMaterialParameter(List[i]).FName, p0) then
      Result:=TMaterialParameter(List[i]).EqualTo(p0)
    else
      Result:=false;

    if not Result then break;
  end;
end;

function TMaterialParameters.ExtractTextureIDs: TStringList;
var
  i: integer;
begin
  Result:=TStringList.Create;
  for i:=0 to count - 1 do
    if TObject(List[i]) is TTextureMaterialParameter then
      Result.Add(TTextureMaterialParameter(List[i]).FName);
end;

function TMaterialParameters.FindParameter(aName: string; var p): boolean;
var
  i: integer;
begin
  i:=IndexOf(aName);
  if i > -1 then
  begin
    Result:=true;
    TObject(p):=TMaterialParameter(List[i]);
  end
  else
    Result:=false;
end;

function TMaterialParameters.GetColorParam(
  index: string): TColorMaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TColorMaterialParameter then
      Result:=TColorMaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not color (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewColor(index);
end;

function TMaterialParameters.GetFloat3Param(
  index: string): TFloat3MaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TFloat3MaterialParameter then
      Result:=TFloat3MaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not float3 (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewFloat3(index);
end;

function TMaterialParameters.GetFloat4Param(
  index: string): TFloat4MaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TFloat4MaterialParameter then
      Result:=TFloat4MaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not float4 (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewFloat4(index);
end;

function TMaterialParameters.GetFloatParam(
  index: string): TFloatMaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TFloatMaterialParameter then
      Result:=TFloatMaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not float (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewFloat(index);
end;

function TMaterialParameters.GetIntParam(
  index: string): TIntegerMaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TIntegerMaterialParameter then
      Result:=TIntegerMaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not integer (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewInteger(index);
end;

function TMaterialParameters.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
var
  i: integer;
begin
  case ChildBlockType of
    btMaterialParameterItem:
    begin
      i:=IndexOf(ChildID);
      if i > -1 then
      begin
        Result:=TObject(List[i]);
        if (ChildClass <> '') and (ChildClass <> Result.ClassName) then
          Log('Parameter ' + ChildID + ' has incorrect class: ' + ChildClass + ' <> ' + Result.ClassName);
//        Log('Загружается существующий параметр');
      end
      else
      if FOwner is TMaterial then
        Result:=TMaterial(FOwner).UnknownParameter(ChildID, ChildClass, LoadInfo)
      else
      begin
        Result:=CL_SKIP_OBJECT;
//        Log('Пропуск неизвестного параметра ' + ChildID);
{        Result:=NewParameter(ChildID, MaterialParams.GetTypeByClassname(ChildClass));
        Log('Загружается новый параметр');}
      end;
    end;
  else
    Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID)
  end;
end;

function TMaterialParameters.GetMaterial: TMaterial;
begin
  if (FOwner is TMaterial) then
    Result:=TMaterial(FOwner)
  else
    Result:=nil;
end;

function TMaterialParameters.GetMatrixParam(
  index: string): TMatrixMaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TMatrixMaterialParameter then
      Result:=TMatrixMaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not Matrix (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewMatrix(index);
end;

function TMaterialParameters.GetShaderValue(index: string): string;
var
  p: TMaterialParameter;
begin
  if FindParameter(index, p) then
    Result:=p.GetShaderValue
  else
    Result:=index;
end;

function TMaterialParameters.GetTextureParam(
  index: string): TTextureMaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TTextureMaterialParameter then
      Result:=TTextureMaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not Texture (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewTexture(index);
end;

function TMaterialParameters.GetReflMaterialParam(index: string): TReflMaterialParameter;
var
  i: integer;
begin
  i:=IndexOf(index);
  if (i > -1) then
    if TObject(List[i]) is TReflMaterialParameter then
      Result:=TReflMaterialParameter(List[i])
    else
      raise Exception.Create('parameter ' + index + ' type is not ReflMaterial structure (' + TObject(List[i]).ClassName + ')')
  else
    Result:=NewReflStruct(index);
end;

function TMaterialParameters.IndexOf(ParamName: string): integer;
begin
  Result:=Count - 1;
  while(Result > -1) and (AnsiCompareText(TMaterialParameter(List[Result]).FName, ParamName) <> 0) do
    Dec(Result);
end;

function TMaterialParameters.ListTextures: string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to Count - 1 do
    if Items[i] is TTextureMaterialParameter then
      Result:=Result + TTextureMaterialParameter(Items[i]).FName + #13#10;
end;
{
procedure TMaterialParameters.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
var
  i: integer;
  node: IXMLNode;
  p: TMaterialParameter;
begin
  if assigned(root) then
  begin
    //Clear;
    for i:=0 to root.ChildNodes.Count - 1 do
    begin
      node:=root.ChildNodes[i];
      if node.HasAttribute('Type') and node.HasAttribute('Name') then
      begin
        if FindParameter(node.Attributes['Name'], p) then
          p.LoadFromXml(node, LoadFlags)
        else
          case TMaterialParameterType(node.Attributes['Type']) of
            mptInteger: NewInteger(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptFloat:   NewFloat(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptFloat3:  NewFloat3(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptFloat4:  NewFloat4(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptMatrix:  NewMatrix(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptTexture: NewTexture(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptColor:   NewColor(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptFlags:   NewFlags(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
            mptFloatConv: NewFloatWithConverter(node.Attributes['Name']).LoadFromXml(node, LoadFlags);
          end;
      end;
    end;
  end;
end;
}
procedure TMaterialParameters.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
var
  i: integer;
  node: TXMLNode;
  p: TMaterialParameter;
  aName: string;
begin
  if assigned(root) then
  begin
    //Clear;
    for i:=0 to root.NodeCount - 1 do
    begin
      node:=root.Nodes[i];
      if node.HasAttribute('Type') and node.HasAttribute('Name') then
      begin
        aName := Utf8ToAnsiEx(node.AttributeByName['Name'].Value, 1251);
        if FindParameter(aName, p) then
          p.LoadFromXml(node, LoadFlags)
        else
{          NewParameter(aName,
            MaterialParams.GetClassByType(TMaterialParameterType(node.AttributeByName['Type'].ValueAsInteger))).LoadFromXml(node, LoadFlags);}
          case TMaterialParameterType(node.AttributeByName['Type'].ValueAsInteger) of
            mptInteger: NewInteger(aName).LoadFromXml(node, LoadFlags);
            mptFloat:   NewFloat(aName).LoadFromXml(node, LoadFlags);
            mptFloat3:  NewFloat3(aName).LoadFromXml(node, LoadFlags);
            mptFloat4:  NewFloat4(aName).LoadFromXml(node, LoadFlags);
            mptMatrix:  NewMatrix(aName).LoadFromXml(node, LoadFlags);
            mptTexture: NewTexture(aName).LoadFromXml(node, LoadFlags);
            mptColor:   NewColor(aName).LoadFromXml(node, LoadFlags);
            mptFlags:   NewFlags(aName).LoadFromXml(node, LoadFlags);
            mptFloatConv: NewFloatWithConverter(aName).LoadFromXml(node, LoadFlags);
            mptMonoMaterial: NewMonoMaterial(aName).LoadFromXml(node, LoadFlags);
            mptIntEnum: NewIntEnum(aName).LoadFromXml(node, LoadFlags);
            mptTexTransform: NewTexTransform(aName).LoadFromXml(node, LoadFlags);
            mptReflStruct: NewReflStruct(aName).LoadFromXml(node, LoadFlags);
            mptTexWrapMode: NewTexWrapMode(aName).LoadFromXml(node, LoadFlags);
          end;
      end;
    end;
  end;
end;

function TMaterialParameters.NewColor(
  aName: string): TColorMaterialParameter;
begin
  Result:=TColorMaterialParameter(NewParameter(aName, TColorMaterialParameter));
end;

function TMaterialParameters.NewFlags(
  aName: string): TFlagsMaterialParameter;
begin
  Result:=TFlagsMaterialParameter(NewParameter(aName, TFlagsMaterialParameter));
end;

function TMaterialParameters.NewFloat(
  aName: string): TFloatMaterialParameter;
begin
  Result:=TFloatMaterialParameter(NewParameter(aName, TFloatMaterialParameter));
end;

function TMaterialParameters.NewFloat3(
  aName: string): TFloat3MaterialParameter;
begin
  Result:=TFloat3MaterialParameter(NewParameter(aName, TFloat3MaterialParameter));
end;

function TMaterialParameters.NewFloat4(
  aName: string): TFloat4MaterialParameter;
begin
  Result:=TFloat4MaterialParameter(NewParameter(aName, TFloat4MaterialParameter));
end;

function TMaterialParameters.NewFloatWithConverter(
  aName: string): TFloatMaterialParameterWithConverter;
begin
  Result:=TFloatMaterialParameterWithConverter(NewParameter(aName, TFloatMaterialParameterWithConverter));
end;

function TMaterialParameters.NewInteger(
  aName: string): TIntegerMaterialParameter;
begin
  Result:=TIntegerMaterialParameter(NewParameter(aName, TIntegerMaterialParameter));
end;

function TMaterialParameters.NewMatrix(
  aName: string): TMatrixMaterialParameter;
begin
  Result:=TMatrixMaterialParameter(NewParameter(aName, TMatrixMaterialParameter));
end;

function TMaterialParameters.NewParameter(aName: string;
  aClass: TMaterialParameterClass): TMaterialParameter;
begin
  Result:=aClass.Create(self);
  Result.FName:=aName;
  Result.OnChange:=ParameterChanged;
  Add(Result);
  ReSort;
end;

function TMaterialParameters.NewTexture(
  aName: string): TTextureMaterialParameter;
begin
  Result:=TTextureMaterialParameter(NewParameter(aName, TTextureMaterialParameter));
end;

function TMaterialParameters.NewTexTransform(aName: string): TTexTransformMaterialParameter;
begin
  Result := TTexTransformMaterialParameter(NewParameter(aName, TTexTransformMaterialParameter));
end;

function TMaterialParameters.NewReflStruct(aName: string): TReflMaterialParameter;
begin
  Result := TReflMaterialParameter(NewParameter(aName, TReflMaterialParameter));
end;

function TMaterialParameters.NewTexWrapMode(aName: string): TTexWrapModeMaterialParameter;
begin
  Result := TTexWrapModeMaterialParameter(NewParameter(aName, TTexWrapModeMaterialParameter));
end;

function TMaterialParameters.NewString(aName: string): TStringMaterialParameter;
begin
  Result := TStringMaterialParameter(NewParameter(aName, TStringMaterialParameter));
end;

function TMaterialParameters.NewMonoMaterial(aName: string): TMonoMaterialParameter;
var
  c: IMonoMaterialContainer;
begin
  Result := TMonoMaterialParameter(NewParameter(aName, TMonoMaterialParameter));
  if Supports(Owner, IMonoMaterialContainer, c) then
    Result.FMatLib := c.GetMonoMaterialList;
end;

function TMaterialParameters.NewVoxelAngle(
  aName: string): TVoxelAngleMaterialParameter;
begin
  Result:=TVoxelAngleMaterialParameter(NewParameter(aName, TVoxelAngleMaterialParameter));
end;

procedure TMaterialParameters.PackAt(dst: pointer);
var
  i: integer;
begin
  for i:=0 to count - 1 do
    TMaterialParameter(List[i]).PackAt(dst);
end;

procedure TMaterialParameters.PackAt2(dst: pointer);
var
  i: integer;
begin
  for i:=0 to count - 1 do
  try
    TMaterialParameter(List[i]).PackAt2(dst);
  except
  end;
end;

function TMaterialParameters.Parameter(
  const aIndex: Integer): TMaterialParameter;
begin
  Result:=TMaterialParameter(List[aIndex]);
end;

procedure TMaterialParameters.ParameterChanged(Sender: TObject);
begin
  FDirtFlag:=True;
  if assigned(FOnMaterialChanged) then
    FOnMaterialChanged(Sender);
  if assigned(FOnNotification) then
    FOnNotification(Sender);
end;

const
  cmMatParams = $005b5b5b;

procedure TMaterialParameters.ReadFromFiler(ReadInfo: TReadInfo);
  procedure ReadParams(Reader: TCustomReader);
  var
    i, aCount: integer;
    t: cardinal;
    aType: TMaterialParameterType;
    aName: string;
    p: TMaterialParameter;
  begin
      Reader.Read(aCount, SizeOf(aCount));
      BeginUpdate;
      //Clear;
      for i:=0 to aCount - 1 do
      begin
        aName:=Reader.ReadString();
        Reader.Read(t, sizeof(t));
        aType:=TMaterialParameterType(t);
        if FindParameter(aName, p) then
          p.ReadFromFiler(ReadInfo)
        else
          case aType of
            mptInteger: NewInteger(aName).ReadFromFiler(ReadInfo);
            mptFloat:   NewFloat(aName).ReadFromFiler(ReadInfo);
            mptFloat3:  NewFloat3(aName).ReadFromFiler(ReadInfo);
            mptFloat4:  NewFloat4(aName).ReadFromFiler(ReadInfo);
            mptMatrix:  NewMatrix(aName).ReadFromFiler(ReadInfo);
            mptTexture: NewTexture(aName).ReadFromFiler(ReadInfo);
            mptColor:   NewColor(aName).ReadFromFiler(ReadInfo);
            mptFlags:   NewFlags(aName).ReadFromFiler(ReadInfo);
            mptFloatConv: NewFloatWithConverter(aName).ReadFromFiler(ReadInfo);
          end;
      end;
      EndUpdate;
  end;
begin
  with ReadInfo do
  begin
    if Reader.CheckMagic(cmMatParams) then
    begin
      if Reader.ReadBoolean then
        ReadParams(Reader);
    end
    else
    begin
      ReadParams(Reader);
    end;
  end;
end;

procedure TMaterialParameters.ReadValues(conv: IMaterialConverter);
var
  i: integer;
begin
  for i:=0 to count - 1 do
    if ((TMaterialParameter(List[i]).FType <> mptInteger) or (AnsiCompareText(TMaterialParameter(List[i]).FName, 'type') <> 0))
      and conv.HasParameter(TMaterialParameter(List[i]).FName) then
    try
      TMaterialParameter(List[i]).ExtractFrom(conv);
    except
    end;
end;

function TMaterialParameters.RemoveParameter(aName: string): boolean;
var
  i: integer;
begin
  i:=IndexOf(aName);
  if i > -1 then
  begin
    Delete(i);
    Result:=true
  end
  else
    Result:=false;
end;

procedure TMaterialParameters.ReSort;
var
  st, s16, s5, s4, s3, s1, s0: TStringList;
  i, j: integer;
begin
  if FUpdateCounter > 0 then exit;
  exit;
  st:=TStringList.Create;
  st.Sorted:=true;
  st.CaseSensitive:=false;

  s16:=TStringList.Create;
  s16.Sorted:=true;
  s16.CaseSensitive:=false;

  s5:=TStringList.Create;
  s5.Sorted:=true;
  s5.CaseSensitive:=false;

  s4:=TStringList.Create;
  s4.Sorted:=true;
  s4.CaseSensitive:=false;

  s3:=TStringList.Create;
  s3.Sorted:=true;
  s3.CaseSensitive:=false;

  s1:=TStringList.Create;
  s1.Sorted:=true;
  s1.CaseSensitive:=false;

  s0:=TStringList.Create;
  s0.Sorted:=true;
  s0.CaseSensitive:=false;

  for i:=0 to count - 1 do
    if (TMaterialParameter(List[i]).FType = mptInteger) and (AnsiCompareText(TMaterialParameter(List[i]).FName, 'type') = 0) then
      st.AddObject(TMaterialParameter(List[i]).FName, List[i])
    else
    case TMaterialParameter(List[i]).FType of
      mptInteger, mptFloat: s1.AddObject(TMaterialParameter(List[i]).FName, List[i]);
      mptFloat3: s3.AddObject(TMaterialParameter(List[i]).FName, List[i]);
      mptFloat4: s4.AddObject(TMaterialParameter(List[i]).FName, List[i]);
      mptMatrix: s16.AddObject(TMaterialParameter(List[i]).FName, List[i]);
      mptTexture: s5.AddObject(TMaterialParameter(List[i]).FName, List[i]);
    else
      s0.AddObject(TMaterialParameter(List[i]).FName, List[i]);
    end;

  OwnsObjects:=false;
  Clear;
  for i:=0 to st.Count - 1 do
    Add(st.Objects[i]);
  j:=(4 - (st.count and 3)) and 3;
  case st.count and 3 of
    3:
      begin
        if s3.count > 0 then
        begin
          Add(s3.Objects[0]);
          s3.Delete(0);
        end
        else
          while (j > 0) and (s1.count > 0) do
          begin
            Add(s1.Objects[0]);
            s1.Delete(0);
            dec(j);
          end;
      end;
    2, 1:
        while (j > 0) and (s1.count > 0) do
        begin
          Add(s1.Objects[0]);
          s1.Delete(0);
          dec(j);
        end;
  end;
  for i:=0 to s16.Count - 1 do
    Add(s16.Objects[i]);
  for i:=0 to s4.Count - 1 do
    Add(s4.Objects[i]);
  for i:=0 to s5.Count - 1 do
  begin
    Add(s5.Objects[i]);
    if s3.Count > 0 then
    begin
      Add(s3.Objects[0]);
      s3.Delete(0);
    end
    else
    begin
      j:=3;
      while (j > 0) and (s1.Count > 0) do
      begin
        Add(s1.Objects[0]);
        s1.Delete(0);
        Dec(j);
      end;
    end;
  end;
  for i:=0 to s3.Count - 1 do
  begin
    Add(s3.Objects[i]);
    if s1.Count > 0 then
    begin
      Add(s1.Objects[0]);
      s1.Delete(0);
    end;
  end;
  for i:=0 to s1.Count - 1 do
    Add(s1.Objects[i]);
  for i:=0 to s0.Count - 1 do
    Add(s0.Objects[i]);
  OwnsObjects:=true;

  CountOffsets;

  s16.Free;
  s5.Free;
  s4.Free;
  s3.Free;
  s1.Free;
  s0.Free;
  st.Free;
end;

procedure TMaterialParameters.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
  i: integer;
begin
  with SaveInfo, Writer do
  try
    for i:=0 to count - 1 do
    begin
      BeginChild(btMaterialParameterItem, TObject(list[i]).ClassName, TMaterialParameter(List[i]).FName);
      try
        TMaterialParameter(List[i]).SaveObject(SaveInfo);
      finally
        EndChild;
      end;
    end;
  except
    on e: exception do
      SaveInfo.Error('TMaterialParameters: ' + e.Message);
  end;
  inherited;
end;
{
procedure TMaterialParameters.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
var
  i: integer;
begin
  if assigned(root) then
  begin
    //root.Attributes['Count']:=count;
    for i:=0 to count - 1 do
      TMaterialParameter(List[i]).SaveToXml(root.AddChild('p'), SaveFlags);
  end;
end;
}
procedure TMaterialParameters.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
var
  i: integer;
begin
  if assigned(root) then
  begin
    //root.Attributes['Count']:=count;
    for i:=0 to count - 1 do
      TMaterialParameter(List[i]).SaveToXml(root.NodeNew('p'), SaveFlags);
  end;
end;

procedure TMaterialParameters.SetAtlas(atlas: TMaterialTextureAtlas; textures: TSimpleTexturesList);
var
  i: integer;
begin
  for i:=0 to count - 1 do
    TMaterialParameter(List[i]).SetAtlas(atlas, textures);
end;

procedure TMaterialParameters.SetNotification(Event: TNotifyEvent2);
begin
  FOnNotification:=Event;
end;

procedure TMaterialParameters.SetupCache(parameters: array of string);
var
  i: integer;
begin
  if Length(Cache) < Length(parameters) then
    SetLength(Cache, Length(parameters));
  for i:=0 to High(parameters) do
    if not FindParameter(parameters[i], Cache[i]) then
      Cache[i]:=nil;
end;

function TMaterialParameters.TotalNumFloats: integer;
{var
  i: integer;}
begin
  CountOffsets;
{  Result:=0;
  for i:=0 to count - 1 do
    Inc(Result, NumFloatComponentsInMaterialParameter[TMaterialParameter(List[i]).FType]);}
  if Count > 0 then
    with TMaterialParameter(Last) do
      Result:=ceil((FOffset + NumFloatComponentsInMaterialParameter[FType]) * 0.25) shl 2
  else
    Result:=0;
end;

procedure TMaterialParameters.UnpackFrom2(src: pointer);
var
  i: integer;
begin
  for i:=0 to count - 1 do
    TMaterialParameter(List[i]).UnpackFrom2(src);
end;

procedure TMaterialParameters.UpdateValues(conv: IMaterialConverter);
var
  i: integer;
begin
  for i:=0 to count - 1 do
    if ((TMaterialParameter(List[i]).FType <> mptInteger) or (AnsiCompareText(TMaterialParameter(List[i]).FName, 'type') <> 0))
      and conv.HasParameter(TMaterialParameter(List[i]).FName) then
    try
      TMaterialParameter(List[i]).UpdateFrom(conv);
    except
    end;
end;

procedure TMaterialParameters.WriteToFiler(WriteInfo: TWriteInfo);
var
  i: integer;
begin
  with WriteInfo do
  begin
    Writer.WriteMagic(cmMatParams);
    Writer.WriteBoolean(FDirtFlag);
    if FDirtFlag then
    begin
      Writer.Write(count, SizeOf(count));
      for i:=0 to count - 1 do
        TMaterialParameter(List[i]).WriteToFiler(WriteInfo);
      FDirtFlag:=False;
    end;
  end;
end;

procedure TMaterialParameters.WriteValues(conv: IMaterialConverter);
var
  i: integer;
begin
  for i:=0 to count - 1 do
    if ((TMaterialParameter(List[i]).FType <> mptInteger) or (AnsiCompareText(TMaterialParameter(List[i]).FName, 'type') <> 0))
      and conv.HasParameter(TMaterialParameter(List[i]).FName) then
      TMaterialParameter(List[i]).CopyTo(conv);
end;

function TMaterialParameters.UpgradeIntegerParameter(const OldName,
  NewName: string; const defaultValue: Integer): TIntegerMaterialParameter;
var
  i: integer;
begin
  if AnsiCompareText(OldName, NewName) <> 0 then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TIntegerMaterialParameter(Parameter(i));
    if NewName <> '' then
    Result.FName:=NewName;
  end
  else
  begin
    Result:=NewInteger(NewName);
    Result.Value:=defaultValue;
  end;
end;

function TMaterialParameters.UpgradeFloatParameter(const OldName,
  NewName: string; const defaultValue: Single): TFloatMaterialParameter;
var
  i: integer;
begin
  if (AnsiCompareText(OldName, NewName) <> 0) then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    if Parameter(i).ClassType <> TFloatMaterialParameter then
    begin
      Result:=NewFloat(NewName);
      Result.Assign(Parameter(i));
      Delete(i);
    end
    else
      Result:=TFloatMaterialParameter(Parameter(i));
    if NewName <> '' then
      Result.FName:=NewName;
  end
  else
  begin
    Result:=NewFloat(NewName);
    Result.Value:=defaultValue;
  end;
end;

function TMaterialParameters.UpgradeColorParameter(const OldName,
  NewName: string; const defaultValue1, defaultValue2,
  defaultValue3: Single): TColorMaterialParameter;
var
  i: integer;
begin
  if AnsiCompareText(OldName, NewName) <> 0 then
  RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TColorMaterialParameter(Parameter(i));
    if NewName <> '' then
    Result.FName:=NewName;
  end
  else
  begin
    Result:=NewColor(NewName);
    Result.Value:=AffineVectorMake(defaultValue1, defaultValue2, defaultValue3);
  end;
end;

function TMaterialParameters.UpgradeFloat3Parameter(const OldName,
  NewName: string; const defaultValue1, defaultValue2,
  defaultValue3: Single): TFloat3MaterialParameter;
var
  i: integer;
begin
  if AnsiCompareText(OldName, NewName) <> 0 then
  RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TFloat3MaterialParameter(Parameter(i));
    if NewName <> '' then
    Result.FName:=NewName;
  end
  else
  begin
    Result:=NewFloat3(NewName);
    Result.Value:=AffineVectorMake(defaultValue1, defaultValue2, defaultValue3);
  end;
end;

function TMaterialParameters.UpgradeFloat4Parameter(const OldName,
  NewName: string; const defaultValue1, defaultValue2, defaultValue3,
  defaultValue4: Single): TFloat4MaterialParameter;
var
  i: integer;
  v: TVector4f;
begin
  if AnsiCompareText(OldName, NewName) <> 0 then
  RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TFloat4MaterialParameter(Parameter(i));
    if NewName <> '' then
    Result.FName:=NewName;
  end
  else
  begin
    Result:=NewFloat4(NewName);
    v[0]:=defaultValue1;
    v[1]:=defaultValue2;
    v[2]:=defaultValue3;
    v[3]:=defaultValue4;
    Result.Value:=v;
  end;
end;

function TMaterialParameters.UpgradeTextureParameter(const OldName,
  NewName: string): TTextureMaterialParameter;
var
  i: integer;
  v: TVector4f;
begin
  if AnsiCompareText(OldName, NewName) <> 0 then
  RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TTextureMaterialParameter(Parameter(i));
    if NewName <> '' then
    Result.FName:=NewName;
  end
  else
  begin
    Result:=NewTexture(NewName);
    Result.FEnabled:=False;
  end;
end;

procedure TMaterialParameters.ShowAll;
var
  i: integer;
begin
  for i:=0 to count - 1 do
    Parameter(i).FCustomizable:=true;
end;

procedure TMaterialParameters.AppendMissing(src: TMaterialParameters;
  CanMove: boolean);
var
  i: integer;
  p: TMaterialParameter;
begin
  for i:=src.Count - 1 downto 0 do
    if not FindParameter(src.Parameter(i).FName, p) then
      if CanMove then
      begin
        p:=src.Parameter(i);
        src.JustDelete(i);
        self.Add(p);
        p.ChangeOwner(self);
        p.OnChange:=ParameterChanged;
      end
      else
        NewParameter(p.FName, TMaterialParameterClass(p.ClassType)).Assign(p);
end;

procedure TMaterialParameters.JustDelete(const Index: Integer);
begin
  OwnsObjects:=false;
  Delete(Index);
  OwnsObjects:=true;
end;

function TMaterialParameters.FindParameter(
  aName: string): TMaterialParameter;
begin
  if not FindParameter(aName, Result) then
    Result:=nil;
end;

function TMaterialParameters.UpgradeMatrixParameter(const OldName,
  NewName: string; const defaultValue: PMatrix): TMatrixMaterialParameter;
var
  i: integer;
  v: TVector4f;
begin
  if AnsiCompareText(OldName, NewName) <> 0 then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TMatrixMaterialParameter(Parameter(i));
    if NewName <> '' then
      Result.FName:=NewName;
  end
  else
  begin
    Result:=NewMatrix(NewName);
    if defaultValue <> nil then
      Result.Value:=defaultValue^;
  end;
end;

function TMaterialParameters.UpgradeFlagsParameter(const OldName,
  NewName: string; const defaultValue: Cardinal): TFlagsMaterialParameter;
var
  i: integer;
begin
  if AnsiCompareText(OldName, NewName) <> 0 then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TFlagsMaterialParameter(Parameter(i));
    Result.FName:=NewName;
  end
  else
  begin
    Result:=NewFlags(NewName);
    Result.Value:=defaultValue;
  end;
end;

function TMaterialParameters.UpgradeIntEnumParameter(const OldName,
  NewName: string; const defaultValue: Integer): TIntEnumMaterialParameter;
var
  i: integer;
  t: TMaterialParameterType;
begin
  if (AnsiCompareText(OldName, NewName) <> 0) and (NewName <> '') then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    if Parameter(i) is TIntEnumMaterialParameter then
      Result:=TIntEnumMaterialParameter(Parameter(i))
    else
    begin
      Result:=NewIntEnum(NewName);
      t:=Result.FType;
      Result.Assign(Parameter(i));
      Result.FType:=t;
      Delete(i);
    end;
    if NewName <> '' then
      Result.FName:=NewName;
  end
  else
  begin
    Result:=NewIntEnum(NewName);
    Result.Value:=defaultValue;
  end;
end;

function TMaterialParameters.NewIntEnum(
  aName: string): TIntEnumMaterialParameter;
begin
  Result:=TIntEnumMaterialParameter(NewParameter(aName, TIntEnumMaterialParameter));
end;

function TMaterialParameters.ListParams(CopyToClipboard: boolean): string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to Count - 1 do
    with Parameter(i) do
      Result:=Result + ClassName + ': ' + GetName + ' = ' + AsString + #13#10;
  if CopyToClipboard then
    Clipboard.AsText:=Result;
end;

procedure TMaterialParameters.AssignValuesFrom(src: TMaterialParameters; Filter: TParameterFilterFunc; const RelinkRefs: boolean);
var
  i: Integer;
  old, new: TMaterialParameter;
begin
  for i:=0 to Count - 1 do
  begin
    new:=Parameter(i);
    if src.FindParameter(new.FName, old) and ((not assigned(Filter)) or Filter(new)) then
    begin
      new.AssignValue(old);
      if RelinkRefs then
        new.RelinkRefs(old);
    end
  end;
end;

procedure TMaterialParameters.AssignOptionalParameters(src: TMaterialParameters);
var
  i: integer;
  p: TMaterialParameter;
begin
  if Assigned(src) then
    for i:=0 to src.Count - 1 do
      if src.Parameter(i).Optional and not FindParameter(src.Parameter(i).FName, p) then
      begin
        p := NewParameter(src.Parameter(i).FName, TMaterialParameterClass(src.Parameter(i).ClassType));
        p.Assign(src.Parameter(i));
        if p is TTextureMaterialParameter then
          TTextureMaterialParameter(p).TuneParameter;
      end;
end;

function TMaterialParameters.UpgradeTexTransform(const OldName,
  NewName: string;
  const defaultValue: TTexTransformSettings): TTexTransformMaterialParameter;
var
  i: integer;
begin
  if (AnsiCompareText(OldName, NewName) <> 0) then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    if Parameter(i).ClassType <> TTexTransformMaterialParameter then
    begin
      Result:=NewTexTransform(NewName);
      if Parameter(i) is TMatrixMaterialParameter then
        // Делаем, чтобы версия ноль апгрейдилась правильно - домножаем на обратную матрицу
        Result.SetAsMatrix(MatrixMultiply(Parameter(i).AsMatrix(), MatrixMultiply(CreateScaleMatrix(AffineVectorMake(1, -1, 1)), CreateTranslationMatrix(AffineVectorMake(0, 1, 0)))))
      else
        Result.AssignValue(Parameter(i));
      Delete(i);
    end
    else
      Result:=TTexTransformMaterialParameter(Parameter(i));
    if NewName <> '' then
      Result.FName:=NewName;
  end
  else
  begin
    Result:=NewTexTransform(NewName);
    Result.Value:=defaultValue;
  end;
end;

function TMaterialParameters.UpgradeReflParameter(const OldName, NewName: string; const defaultValue: TReflStruct): TReflMaterialParameter;
var
  i: integer;
begin
  if (AnsiCompareText(OldName, NewName) <> 0) then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TReflMaterialParameter(Parameter(i));
    if NewName <> '' then
      Result.FName:=NewName;
  end
  else
  begin
    Result:=NewReflStruct(NewName);
    Result.Value:=defaultValue;
  end;
end;

function TMaterialParameters.UpgradeTexWrapModeParameter(const OldName, NewName: string; const defaultValue: TTexWrapMode): TTexWrapModeMaterialParameter;
var
  i: integer;
begin
  if (AnsiCompareText(OldName, NewName) <> 0) then
    RemoveParameter(NewName);
  i:=IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TTexWrapModeMaterialParameter(Parameter(i));
    if NewName <> '' then
      Result.FName:=NewName;
  end
  else
  begin
    Result:=NewTexWrapMode(NewName);
    Result.Value:=defaultValue;
  end;
end;

procedure TMaterialParameters.DumpToClipboard;
var
  i: integer;
  s: string;
begin
  s:='';
  for i:=0 to count - 1 do
    s:=s + Format('%d) %s = %s', [i, TMaterialParameter(List[i]).FName, TMaterialParameter(List[i]).AsString]) + #13#10;
  Clipboard.AsText:=s;
end;

procedure TMaterialParameters.ExecCommand(cmd: cardinal;
  params: TCommandParams);
begin
  case cmd of
    cMarkDurty: FDirtFlag := True;
  end;
end;

function TMaterialParameters.UpgradeMonoMaterialParameter(const OldName,
  NewName: string): TMonoMaterialParameter;
var
  i: integer;
begin
  //if (AnsiCompareText(OldName, NewName) <> 0) then
  //  RemoveParameter(NewName);
  i := IndexOf(OldName);
  if (i > -1) and (OldName <> '') then
  begin
    Result:=TMonoMaterialParameter(Parameter(i));
    if NewName <> '' then
      Result.FName := NewName;
  end
  else
  begin
    i := IndexOf(NewName);
    if (i > -1) then
      Result := TMonoMaterialParameter(Parameter(i))
    else
      Result := NewMonoMaterial(NewName);
  end;
end;

{ TMaterial }

procedure TMaterial.Assign(src: TMaterial);
begin
  if FName = '' then
    FName:=src.FName;
  FType:=src.FType;
  FVersion:=src.FVersion;
  FParameters.Assign(src.Parameters);
  FMetaData.Assign(src.MetaData);
  FTextures.Assign(src.Textures);
end;

constructor TMaterial.Create(aOwner: TObject);
begin
  FOwner:=aOwner;
  FParameters:=TMaterialParameters.Create(self);
  FParameters.OnMaterialChanged:=ParameterChanged;
  FMetaData:=TMetaStorage.Create;
  FTextures:=TSimpleTexturesList.Create(Self);
  //FTextures.OnChange:=ParameterChanged;
  FTextures.OnChange := FParameters.ParameterChanged;
  inherited Create;
end;

procedure TMaterial.DebugTrace(aPoint: TSurfacePoint;
  const debugInfo: ISurfacePointDebugInfo);
begin
  //empty
end;

destructor TMaterial.Destroy;
begin
  FParameters.Free;
  FMetaData.Free;
  FTextures.Free;
  FAttribs.Free;
  inherited;
end;

procedure TMaterial.Dump;
begin
  Log('Material: ' + FName);
  FParameters.Dump;
end;

function TMaterial.EqualTo(m: TMaterial): boolean;
begin
  Result:=(LowerCase(FName) = LowerCase(m.FName))and(FType = m.FType)and (FVersion = m.FVersion)and(FParameters.EqualTo(m.FParameters))and(FTextures.EqualTo(m.FTextures));
end;

procedure TMaterial.EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);
begin
  //nothing to do
end;

function TMaterial.GetAAInfo(aPoint: TSurfacePoint): TPointAAInfo;
begin
  Result.ObjectID:=aPoint.TriAttribute(tdObjectID);
  Result.Material:=self;
end;

function TMaterial.GetAttenuation: Single;
begin
  Result:=0.0;
end;

function TMaterial.GetAttribs: TMaterialAttributes;
begin
  if FAttribs = nil then
    FAttribs:=TMaterialAttributes.Create;
  Result:=FAttribs;
end;

function TMaterial.GetDebugInfo(aPoint: TSurfacePoint): ISurfacePointDebugInfo;
begin
  Result:=nil;
end;

function TMaterial.GetEmissionLevel: Single;
begin
  Result:=0.0;
end;

function TMaterial.GetEmissive: TAffineVector;
begin
  Result:=NullVector;
end;

function TMaterial.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
begin
  with LoadInfo do
    case ChildBlockType of
      btMaterialParameters:
      begin
        Result:=FParameters;
        if FVersion = 0 then
          FParameters.Clear;
      end;
      btMaterialTextures: Result:=FTextures;
    else
      Result:=CL_UNKNOWN_OBJECT;
    end;
end;

function TMaterial.GetMaterialLibrary(out ml: IMaterialLibrary): boolean;
var
  mc: IMaterialContainer;
begin
  Result := False;
  if Assigned(Owner) then
  begin
    if Owner.GetInterface(IMaterialContainer, mc) then
    begin
      mc.GetMaterialLibrary(ml);
      Result := True;
    end
    else
      Result := Owner.GetInterface(IMaterialLibrary, ml);
  end;
end;

function TMaterial.IsMultiMaterial(): Boolean;
begin
  Result := False;
end;

function TMaterial.GetName: string;
var
  mc: IMaterialContainer;
begin
  if Assigned(Owner) and Owner.GetInterface(IMaterialContainer, mc) then
    Result := mc.GetContainerName
  else
    Result := FName;
end;

function TMaterial.GetNormal(aPoint: TSurfacePoint): TAffineVector;
begin
  Result:=aPoint.Normal;
end;

class function TMaterial.GetShaderAttenuation(const m: string): string;
begin
  Result:='0.0';
end;

class function TMaterial.GetShaderEmissive(const m: string): string;
begin
  Result:='0.0';
end;

function TMaterial.HiGlossy: boolean;
begin
  Result:=false;
end;

function TMaterial.IsLightSource: boolean;
begin
  Result:=False;
end;

function TMaterial.IsTransparent: boolean;
begin
  Result:=false;
end;
{
procedure TMaterial.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  if assigned(root) then
  begin
    if root.HasAttribute('MaterialName') then
      FName:=root.Attributes['MaterialName'];
    if root.HasAttribute('Type') then
      FType:=root.Attributes['Type'];

    FParameters.LoadFromXml(Root.ChildNodes.FindNode('Parameters'), LoadFlags);
    FTextures.LoadFromXml(Root.ChildNodes.FindNode('Textures'), LoadFlags);
  end;
end;
}
procedure TMaterial.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  if assigned(root) then
  begin
    if root.HasAttribute('MaterialName') then
      FName:=Utf8ToAnsi(root.AttributeByName['MaterialName'].Value);
    if root.HasAttribute('Type') then
      FType:=root.AttributeByName['Type'].ValueAsInteger;

    if root.HasAttribute('Version') then
      FVersion:=root.AttributeByName['Version'].ValueAsInteger;

    FParameters.LoadFromXml(Root.FindNode('Parameters'), LoadFlags);
    //FTextures.LoadFromXml(Root.FindNode('Textures'), LoadFlags);
    FTextures.LoadFromXml(Root.NodeByName('Textures'), LoadFlags);
  end;
end;

function TMaterial.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btMaterial_Name:
      begin
        ReadString(FName);
        if FVersion <> CurrentMaterialVersion then
          LoadInfo.Assigner.AddExecTask(ValidateVersion);
      end;
      btMaterialType: ReadInteger(FType);
      btMaterialVersion: ReadInteger(FVersion);
    else
      Result:=CL_UNKNOWN_PARAM;
    end;
end;

function TMaterial.MIndex: integer;
begin
  if (Owner is TMaterialList) then
    Result := TMaterialList(Owner).IndexOfMaterial(self)
  else
    Result := -1;
end;

procedure TMaterial.ParameterChanged(Sender: TObject);
var
  dc: IDirtControl;
begin
  if (Sender is TSimpleTexturesList) or (Sender is TTextureMaterialParameter) then
    FTexDirtFlag := True;
  if assigned(FOnMaterialChanged) then
    FOnMaterialChanged(Sender);
  if Supports(FOwner, IDirtControl, dc) then
    dc.ParametersChanged;
end;

function TMaterial.QueryAAInfoEx(aPoint: TSurfacePoint): Cardinal;
begin
  Result:=0;
end;

const
  cmMatVersion = $17564738;

procedure TMaterial.WriteToFiler(WriteInfo: TWriteInfo);
begin
  with WriteInfo do
  begin
    Writer.Write(FType, SizeOf(FType));
    Writer.WriteString(FName);
    Writer.WriteMagic(cmMatVersion);
    Writer.Write(FVersion, sizeof(FVersion));
    FParameters.WriteToFiler(WriteInfo);
    FTextures.WriteToFiler(WriteInfo);
    FMetaData.WriteToFiler(WriteInfo);
  end;
end;

procedure TMaterial.ReadFromFiler(ReadInfo: TReadInfo; ReadType: boolean);
begin
  with ReadInfo do
  begin
    if ReadType then
      Reader.Read(FType, sizeof(FType));
    FName:=Reader.ReadString();
    if Reader.CheckMagic(cmMatVersion) then
      Reader.Read(FVersion, sizeof(FVersion));
    FParameters.ReadFromFiler(ReadInfo);
    FTextures.ReadFromFiler(ReadInfo);
    FMetaData.ReadFromFiler(ReadInfo);
  end;
end;

procedure TMaterial.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteString(btMaterial_Name, FName);
    WriteInteger(btMaterialType, FType);
    WriteInteger(btMaterialVersion, FVersion);
    BeginChild(btMaterialParameters);
    try
      FParameters.SaveObject(SaveInfo);
    finally
      EndChild;
    end;
    //if self is TTileMaterial = false then
    begin
      BeginChild(btMaterialTextures);
      try
        FTextures.SaveObject(SaveInfo);
      finally
        EndChild;
      end;
    end;
  except
    on e: exception do
      SaveInfo.Error('TMaterial: ' + e.Message);
  end;
end;
{
procedure TMaterial.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.Attributes['MaterialName']:=FName;
    root.Attributes['Type']:=FType;
    FParameters.SaveToXml(root.AddChild('Parameters'), SaveFlags);
    FTextures.SaveToXml(root.AddChild('Textures'), SaveFlags);
  end;
end;
}
procedure TMaterial.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.GetOrCreateAttr('MaterialName').Value := AnsiToUtf8(FName);
    root.GetOrCreateAttr('Type').ValueAsInteger := FType;
    root.GetOrCreateAttr('Version').ValueAsInteger := FVersion;
    FParameters.SaveToXml(root.NodeNew('Parameters'), SaveFlags);
    FTextures.SaveToXml(root.NodeNew('Textures'), SaveFlags);
  end;
end;

procedure TMaterial.SetAtlas(aAtlas: TMaterialTextureAtlas);
begin
  FTextures.AddToParameters(FParameters);
  FParameters.SetAtlas(aAtlas, FTextures);
end;

procedure TMaterial.SetName(const Value: string);
var
  mc: IMaterialContainer;
begin
  if (Owner = nil) or (not Owner.GetInterface(IMaterialContainer, mc)) then
    FName := Value;
end;

function TMaterial.UnknownParameter(const aName, aClass: string; var LoadInfo: TLoadInfo): TObject;
begin
  Result:=CL_SKIP_OBJECT;
end;

procedure TMaterial.Downgrade;
begin
  //Тут будет вызываться функция в dll
end;

procedure TMaterial.SetVersion(const v: Integer);
begin
  while FVersion > v do
  begin
    Downgrade;
    dec(FVersion);
  end;
  while FVersion < v do
  begin
    Upgrade;
    inc(FVersion);
  end;
end;

procedure TMaterial.Upgrade;
begin
end;

procedure TMaterial.ValidateVersion;
begin
  SetVersion(CurrentMaterialVersion);
end;

procedure TMaterial.DropVersion;
begin
  FVersion:=0;
end;

constructor TMaterial.CreateWithoutVersion(aOwner: TObject);
begin
  FVersion:=-1;
  Create(aOwner);
end;

function TMaterial.GetFloatParamValue(aParamName: string;
  const defValue: single): single;
var
  p: TFloatMaterialParameter;
begin
  if Parameters.FindParameter(aParamName, p) then
    Result:=p.Value
  else
    Result:=defValue;
end;

function TMaterial.GetFloat3ParamValue(aParamName: string;
  const defValue: TAffineVector): TAffineVector;
var
  p: TFloat3MaterialParameter;
begin
  if Parameters.FindParameter(aParamName, p) then
    Result:=p.Value
  else
    Result:=defValue;
end;

function TMaterial.GetFloat4ParamValue(aParamName: string;
  const defValue: TVector): TVector;
var
  p: TFloat4MaterialParameter;
begin
  if Parameters.FindParameter(aParamName, p) then
    Result:=p.Value
  else
    Result:=defValue;
end;

function TMaterial.GetColorParamValue(aParamName: string;
  const defValue: TAffineVector): TAffineVector;
begin
  Result:=GetFloat3ParamValue(aParamName, defValue);
end;

function TMaterial.GetIntegerParamValue(aParamName: string;
  const defValue: integer): integer;
var
  p: TIntegerMaterialParameter;
begin
  if Parameters.FindParameter(aParamName, p) then
    Result:=p.Value
  else
    Result:=defValue;
end;

function TMaterial.GetMatrixParamValue(aParamName: string;
  const defValue: TMatrix): TMatrix;
var
  p: TMatrixMaterialParameter;
begin
  if Parameters.FindParameter(aParamName, p) then
    Result:=p.Value
  else
    Result:=defValue;
end;

function TMaterial.GetStringParamValue(aParamName: string;
  const defValue: string): string;
var
  p: TStringMaterialParameter;
begin
  if Parameters.FindParameter(aParamName, p) then
    Result:=p.Value
  else
    Result:=defValue;
end;

function TMaterial.RecreateParameters: boolean;
var
  p: TMaterialParameters;
  new, old: TMaterialParameter;
  i, v: integer;
begin
  v := 0;
  p:=FParameters;
  FParameters:=TMaterialParameters.Create(self);
  FParameters.OnMaterialChanged:=ParameterChanged;
  try
    InitParams;
    v:=FVersion;
    FVersion:=0;
    ValidateVersion;
    for i:=0 to FParameters.Count - 1 do
    begin
      new:=FParameters.Parameter(i);
      if p.FindParameter(new.FName, old) then
        new.AssignValue(old);
    end;
    Result:=true;
  except
    on e: exception do
    begin
      Result:=false;
      FVersion:=v;
      FParameters.Free;
      FParameters:=p;
      p:=nil;
      MessageBox(0, PChar(tr('Не удалось пересоздать материал ') + FName + ': ' + e.Message), 'TMaterial', MB_OK or MB_ICONERROR);
    end;
  end;
  p.Free;
end;

procedure TMaterial.ResetTexturesTo(TexList: ITextureAtlas);
  procedure ResetData(texs: TSimpleTexturesList);
  var
    texName: string;
    texInd1: Integer;
    sampler: ITextureSampler;
  begin
    for texInd1 := 0 to texs.Count - 1 do
    begin
      texName := texs[texInd1].GetTextureID;
      if (TexList = nil) or not ITextureAtlas(TexList).GetSampler(TexName, Sampler) then
        Sampler := nil;
      texs.setSampler(texs[texInd1].TextureName, sampler);
    end;
  end;
var
  multiMat: TMultiMaterial;
  monoInd: Integer;
  monoMat: TMaterial;
begin
  ResetData(Textures);
  if isMultiMaterial then
  begin
    multiMat := TMultiMaterial(Self);
    for monoInd := 0 to multiMat.GetMatCount - 1 do
    begin
      monoMat := multiMat.GetMonoMaterial(monoInd);
      if monoMat <> nil then
        ResetData(monoMat.Textures);
    end;
  end;
end;

function TMaterial.GetFriendlyName: string;
begin
  if MetaData.IsExists('this') and MetaData['this'].IsExists('FriendlyName') then
    Result:=MetaData['this']['FriendlyName'].AsString
  else
    Result:='';
end;

procedure TMaterial.SetFriendlyName(const Value: string);
begin
  MetaData['this']['FriendlyName'].AsString := Value;
end;

procedure TMaterial.DeleteUnusedMaterials;
begin

end;

procedure TMaterial.ExecCommand(cmd: cardinal; params: TCommandParams);
begin
  case cmd of
    cMarkDurty, cEnumUsedGuids:
      begin
        Parameters.ExecCommand(cmd, params);
        Textures.ExecCommand(cmd, params);
      end;
    cChangeGUID, cCollectGUID, cImagePack, cFindTextureByID: Textures.ExecCommand(cmd, params);
  end;
end;

function TMaterial.GetSetID: string;
begin
  if MetaData.IsExists('set') then
    Result := MetaData['set']['id'].AsString
  else
    Result := '';
end;

function TMaterial.GetSetIndex: integer;
begin
  if MetaData.IsExists('set') then
    Result := MetaData['set']['index'].AsInteger
  else
    Result := 0;
end;

procedure TMaterial.SetSetID(const Value: string);
begin
  MetaData['set']['id'].AsString := Value;
end;

procedure TMaterial.SetSetIndex(const Value: integer);
begin
  MetaData['set']['index'].AsInteger := Value;
end;

function TMaterial.HasGUIDedResources: Boolean;
var
  p: TCommandParams;
begin
  p := TCommandParams.Create;
  try
    Textures.ExecCommand(cHasGUIDedResource, p);
    Result := p.Done;
  finally
    p.Free;
  end;
end;

function TMaterial.GetTexTransformParamValue(aParamName: string;
  defValue: TTexTransformSettings): TTexTransformSettings;
var
  p: TTexTransformMaterialParameter;
begin
  if Parameters.FindParameter(aParamName, p) then
    Result:=p.Value
  else
    Result:=defValue;
end;

function TMaterial.Clone(aOwner: TObject): TMaterial;
begin
  Result := TMaterial(TMaterialClass(ClassType).Create(aOwner));
  Result.Assign(Self);
end;

function TMaterial.GetDirectName: string;
begin
  Result := FName;
end;

function TMaterial.GetCompoundName: string;
var
  cn: ICompoundName;
begin
  if (Owner is TMaterialList) and (TMaterialList(Owner).Owner is TMaterial) then
  begin
    Result := TMaterial(TMaterialList(Owner).Owner).GetCompoundName;
    if (Result <> '') then
      Result := Result + '.' + FName
    else
      Result := FName;
  end
  else
  if Supports(Owner, ICompoundName, cn) then
    Result := cn.GetCompoundName
  else
    Result := FName;
end;

{ TMaterialParameter }

function TMaterialParameter.GetName: string;
begin
  if FAltName <> '' then
    Result:=FAltName
  else
    Result:=FName;// + ' [ ' + IntToStr(FOffset) + ', ' + GetShaderValue + ' ]';
(*{$IFNDEF RELEASE}
  Result:=Result + ' [ ' + IntToStr(GetType) + ' ]';
{$ENDIF}*)
end;

function TMaterialParameter.GetType: integer;
begin
  Result:=Integer(FType);
end;

procedure TMaterialParameter.PackAt(dst: pointer);
begin
  PlaceDataAt(pointer(Integer(dst) + FOffset * sizeof(single)));
end;

procedure TMaterialParameter.Assign(src: TMaterialParameter);
begin
  FName:=src.FName;
  FAltName:=src.FAltName;
  FHint:=src.FHint;
  FType:=src.FType;
  FCustomizable:=src.FCustomizable;
  FOptional:=src.FOptional;
  FUpdatable:=src.FUpdatable;
  FOffset:=src.FOffset;
  FCategory:=src.FCategory;
end;

function TMaterialParameter.AsFloat: Single;
begin
  raise Exception.Create('can''t convert ' + FName + ' to float');
end;

function TMaterialParameter.AsFloat3: TAffineVector;
begin
  raise Exception.Create('can''t convert ' + FName + ' to float3');
end;

function TMaterialParameter.AsFloat4: TVector;
begin
  raise Exception.Create('can''t convert ' + FName + ' to float4');
end;

function TMaterialParameter.AsInteger: Integer;
begin
  raise Exception.Create('can''t convert ' + FName + ' to integer');
end;

function TMaterialParameter.AsMatrix: TMatrix;
begin
  raise Exception.Create('can''t convert ' + FName + ' to matrix');
end;

function TMaterialParameter.AsTextureValue: TTextureValue;
begin
  raise Exception.Create('can''t convert ' + FName + ' to texturevalue');
end;

function TMaterialParameter.AsMonoMaterial: TMaterial;
begin
  raise Exception.Create('can''t convert ' + FName + ' to monomaterial');
end;

function TMaterialParameter.AsTexTransform: TTexTransformSettings;
begin
  raise Exception.Create('can''t convert ' + FName + ' to texture transformation settings');
end;

function TMaterialParameter.AsReflStruct: TReflStruct;
begin
  raise Exception.Create('can''t convert ' + FName + ' to reflection structure');
end;

function TMaterialParameter.AsTexWrapMode: TTexWrapMode;
begin
  raise Exception.Create('can''t convert ' + FName + ' to texture wrap mode');
end;

function TMaterialParameter.AsString(short: boolean): string;
begin
  raise Exception.Create('can''t convert ' + FName + ' to string');
end;

function TMaterialParameter.GetShaderValue: string;
const xyzw: array [0..3] of char = ('x', 'y', 'z', 'w');
begin
  Result:='$MATLIST[matIndex + ' + IntToStr(FOffset shr 2) + '].' + xyzw[FOffset and 3];
end;

procedure TMaterialParameter.CountOffset(var offset: integer);
var
  s, last: integer;
begin
  s:=NumFloatComponentsInMaterialParameter[FType];
  last:=(4 - offset mod 4) mod 4;
  if s > last then
    inc(offset, last);
  FOffset:=offset;
  inc(offset, s);
end;

constructor TMaterialParameter.Create;
begin
  CreateGUID(FGUID);
  FOwner:=aOwner;
  Setup;
  inherited Create;
end;

procedure TMaterialParameter.ParameterChanged;
begin
  if FInspectors <> nil then
    FInspectors.Notify(Self);
  if assigned(FOnChange) then
    FOnChange.Notify(self);
  if FWeakRefs <> nil then
    FWeakRefs.Notify(0);
end;

function TMaterialParameter.GetMaterial: TMaterial;
begin
  if (FOwner is TMaterialParameters) then
    Result:=TMaterialParameters(FOwner).GetMaterial
  else
    Result:=nil;
end;

procedure TMaterialParameter.SetAsFloat(const value: Single);
begin
  raise Exception.Create('can''t convert ' + FName + ' to float');
end;

procedure TMaterialParameter.SetAsFloat3(const value: TAffineVector);
begin
  raise Exception.Create('can''t convert ' + FName + ' to float3');
end;

procedure TMaterialParameter.SetAsFloat4(const value: TVector);
begin
  raise Exception.Create('can''t convert ' + FName + ' to float4');
end;

procedure TMaterialParameter.SetAsInteger(const value: Integer);
begin
  raise Exception.Create('can''t convert ' + FName + ' to integer');
end;

procedure TMaterialParameter.SetAsMatrix(const value: TMatrix);
begin
  raise Exception.Create('can''t convert ' + FName + ' to matrix');
end;

procedure TMaterialParameter.SetAsTextureValue(const value: TTextureValue);
begin
  raise Exception.Create('can''t convert ' + FName + ' to texture value');
end;
procedure TMaterialParameter.SetAsString(const value: string);
begin
  raise Exception.Create('can''t convert ' + FName + ' to string');
end;

procedure TMaterialParameter.SetAsMonoMaterial(const value: TMaterial);
begin
  raise Exception.Create('can''t convert ' + FName + ' to monoMaterial');
end;

procedure TMaterialParameter.SetAsTexTransform(const value: TTexTransformSettings);
begin
  raise Exception.Create('can''t convert ' + FName + ' to texture transformation settings');
end;

procedure TMaterialParameter.SetAsReflStruct(const value: TReflStruct);
begin
  raise Exception.Create('can''t convert ' + FName + ' to reflection struct');
end;

procedure TMaterialParameter.SetAsTexWrapMode(const value: TTexWrapMode);
begin
  raise Exception.Create('can''t convert ' + FName + ' to texture wrap mode');
end;

function TMaterialParameter.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
begin
  Result:=CL_UNKNOWN_OBJECT;
end;

function TMaterialParameter.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btMaterialParameterName    : begin Reader.ReadString(FName); {Dump; }end;
//      btMaterialParameterType    : FType:=TMaterialParameterType(Reader.ReadInteger);
      btMaterialParameterCustom  : ReadBoolean(FCustomizable);
      btMaterialParameterOptional: ReadBoolean(FOptional);
      btMaterialParameterAltName: ReadString(FAltName);
      btMaterialParameterHint    : ReadString(FHint);
      btMaterialParameterCategory: ReadString(FCategory);
      btMaterialParameterGuid :
      begin
        FGUID := ReadGUID;
        Identor.AddObject(GUIDToString(FGUID), TThreadSafeWeakRef.Create(Self));
      end;
    else
      Result:=CL_UNKNOWN_PARAM;
    end;
end;

procedure TMaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo do
  try
    Writer.WriteString(btMaterialParameterName, FName);
//    Writer.WriteInteger(btMaterialParameterType, Integer(FType));
    Writer.WriteBoolean(btMaterialParameterCustom, FCustomizable);
    Writer.WriteBoolean(btMaterialParameterOptional, FOptional);
    Writer.WriteGUID(btMaterialParameterGuid, FGUID);
    if FAltName <> '' then
      Writer.WriteString(btMaterialParameterAltName, FAltName);
    if FHint <> '' then
      Writer.WriteString(btMaterialParameterHint, FHint);
    if FCategory <> '' then
      Writer.WriteString(btMaterialParameterCategory, FCategory);
  except
    on e: exception do
      SaveInfo.Error('TMaterialParameter: ' + e.Message);
  end;
end;

function TMaterialParameter.Editable: boolean;
begin
  Result:=FCustomizable;
end;

procedure TMaterialParameter.Dump;
begin
  Log('Parameter: ' + FName);
end;

procedure TMaterialParameter.AddInspector(aInspector: IParameterInspector);
begin
  if FInspectors = nil then
    FInspectors:=TParameterInspectorList.Create;
  FInspectors.Add(aInspector);
end;

destructor TMaterialParameter.Destroy;
begin
  if assigned(FInspectors) then
    FInspectors.NotifyDestroy(Self);
  FInspectors:=nil;
  FLink.Free;
  FOnChange.Free;
  inherited;
end;

procedure TMaterialParameter.RemoveInspector(
  aInspector: IParameterInspector);
begin
  if FInspectors <> nil then
    if FInspectors.IndexOf(aInspector) = -1 then
      raise Exception.Create('inspector not found')
    else
      FInspectors.Remove(aInspector);
end;

function TMaterialParameter.GetParameter: TObject;
begin
  Result:=self;
end;

procedure TMaterialParameter.SetAtlas(atlas: TMaterialTextureAtlas; textures: TSimpleTexturesList);
begin
  //empty by default
end;

function TMaterialParameter.GetShaderType: string;
const
  TypeToHLSL: array[TMaterialParameterType] of string =
  ('int', 'float', 'float3', 'float4', 'float4x4', 'atlasUV', 'float3', 'uint', 'float', 'uint', 'int', '???', '???', '???');
begin
  Result:=TypeToHLSL[FType];
end;

function TMaterialParameter.RootClass: TClass;
begin
  Result:=ClassType;
  while (Result.ClassParent <> TMaterialParameter) do
    Result:=Result.ClassParent;
end;

type
  TParamID = class
  public
    ID: integer;
    Offset: integer;
    constructor Create(aID, aOffset: integer);
  end;

  TMaterialParameterIDs = class(TStringList)
  public
    constructor Create;
    destructor Destroy;override;
    procedure Clean;
    function Substitute(const s: string): string;
    function OffsetOf(const s: string): integer;
    function SortByIDs: TStringList;
  end;

procedure TMaterialParameterIDs.Clean;
var
  i: integer;
begin
  for i:=0 to count - 1 do
    Objects[i].Free;
end;

constructor TMaterialParameterIDs.Create;
begin
  inherited;
  Sorted:=true;
  CaseSensitive:=false;
  AddObject('Type', TParamID.Create(0, Integer(@PShaderMaterial(nil)^._type)));
  AddObject('Фон', TParamID.Create(1, Integer(@PShaderMaterial(nil)^.Ambient)));
  AddObject('Уровень фона', TParamID.Create(2, Integer(@PShaderMaterial(nil)^.AmbientLevel)));
  AddObject('старые уровни', TParamID.Create(3, Integer(@PShaderMaterial(nil)^.OldLevels)));
  AddObject('старый фон', TParamID.Create(4, Integer(@PShaderMaterial(nil)^.OldAmbient)));
  AddObject('старый рассеянный', TParamID.Create(5, Integer(@PShaderMaterial(nil)^.OldDiffuse)));
  AddObject('старый отраженный', TParamID.Create(6, Integer(@PShaderMaterial(nil)^.OldSpecular)));
  AddObject('Рассеянный', TParamID.Create(7, Integer(@PShaderMaterial(nil)^.Diffuse)));
  AddObject('Уровень рассеянного', TParamID.Create(8, Integer(@PShaderMaterial(nil)^.DiffuseLevel)));
  AddObject('Отраженный', TParamID.Create(9, Integer(@PShaderMaterial(nil)^.Reflection)));
  AddObject('Уровень отраженного', TParamID.Create(10, Integer(@PShaderMaterial(nil)^.ReflectionLevel)));
  AddObject('Начало отраженного смешивания', TParamID.Create(11, Integer(@PShaderMaterial(nil)^.ReflectionMixStart)));
  AddObject('Конец отраженного смешивания', TParamID.Create(12, Integer(@PShaderMaterial(nil)^.ReflectionMixEnd)));
  AddObject('Уровень отраженного Kd', TParamID.Create(13, Integer(@PShaderMaterial(nil)^.ReflectionKdLevel)));
  AddObject('Размытие отражений', TParamID.Create(14, Integer(@PShaderMaterial(nil)^.ReflectionBlur)));
  AddObject('Коэффициент френеля для отражений', TParamID.Create(15, Integer(@PShaderMaterial(nil)^.ReflectionFresnel)));
  AddObject('Преломленный', TParamID.Create(16, Integer(@PShaderMaterial(nil)^.Refraction)));
  AddObject('Уровень преломленного', TParamID.Create(17, Integer(@PShaderMaterial(nil)^.RefractionLevel)));
  AddObject('Начало преломленного смешивания', TParamID.Create(18, Integer(@PShaderMaterial(nil)^.RefractionMixStart)));
  AddObject('Конец преломленного смешивания', TParamID.Create(19, Integer(@PShaderMaterial(nil)^.RefractionMixEnd)));
  AddObject('Уровень преломленного Kd', TParamID.Create(20, Integer(@PShaderMaterial(nil)^.RefractionKdLevel)));
  AddObject('Размытие преломлений', TParamID.Create(21, Integer(@PShaderMaterial(nil)^.RefractionBlur)));
  AddObject('Коэффициент преломления', TParamID.Create(22, Integer(@PShaderMaterial(nil)^.RefractionIndex)));
  AddObject('Альбедо', TParamID.Create(23, Integer(@PShaderMaterial(nil)^.Albedo)));
  AddObject('Уровень альбедо', TParamID.Create(24, Integer(@PShaderMaterial(nil)^.AlbedoLevel)));
  AddObject('Непрозрачность', TParamID.Create(25, Integer(@PShaderMaterial(nil)^.Opacity)));
  AddObject('Старая непрозрачность', TParamID.Create(26, Integer(@PShaderMaterial(nil)^.OldOpacity)));
  AddObject('Самосвечение', TParamID.Create(27, Integer(@PShaderMaterial(nil)^.Emission)));
  AddObject('Уровень самосвечения', TParamID.Create(28, Integer(@PShaderMaterial(nil)^.EmissionLevel)));
  AddObject('Roughness', TParamID.Create(29, Integer(@PShaderMaterial(nil)^.Roughness)));
  AddObject('Blur', TParamID.Create(30, Integer(@PShaderMaterial(nil)^.Blur)));
  AddObject('Флаги материала', TParamID.Create(31, Integer(@PShaderMaterial(nil)^.Flags)));
  AddObject('BaseMap', TParamID.Create(32, Integer(@PShaderMaterial(nil)^.BaseMap)));
  AddObject('TexMatrix', TParamID.Create(33, Integer(@PShaderMaterial(nil)^.TexMatrix)));
  AddObject('BumpMap', TParamID.Create(34, Integer(@PShaderMaterial(nil)^.BumpMap)));
  AddObject('LightColor', TParamID.Create(35, Integer(@PShaderMaterial(nil)^.Emission)));
  AddObject('LightPower', TParamID.Create(38, Integer(@PShaderMaterial(nil)^.EmissionLevel)));
  AddObject('Затухание', TParamID.Create(36, Integer(@PShaderMaterial(nil)^.LightAttenuation)));
  AddObject('Флаги', TParamID.Create(37, Integer(@PShaderMaterial(nil)^.LightFlags)));
  AddObject('Tentacle', TParamID.Create(38, Integer(@PShaderMaterial(nil)^.Tentacle)));
  AddObject('Флаги отражений', TParamID.Create(39, Integer(@PShaderMaterial(nil)^.Flags)));
  AddObject('Флаги преломлений', TParamID.Create(40, Integer(@PShaderMaterial(nil)^.Flags)));
  AddObject('Прочие флаги', TParamID.Create(41, Integer(@PShaderMaterial(nil)^.Flags)));
end;

function SortByID(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result:=TParamID(List.Objects[Index1]).ID - TParamID(List.Objects[Index2]).ID;
end;

destructor TMaterialParameterIDs.Destroy;
begin
  Clean;
  inherited;
end;

function TMaterialParameterIDs.OffsetOf(const s: string): integer;
var
  i: integer;
begin
  if Find(s, i) then
    Result:=TParamID(Objects[i]).Offset
  else
    raise Exception.Create('Param ' + s + ' offset not found');
end;

function TMaterialParameterIDs.SortByIDs: TStringList;
begin
  Result:=TStringList.Create;
  Result.Assign(self);
  Result.CustomSort(SortByID);
end;

function TMaterialParameterIDs.Substitute(const s: string): string;
var
  i: integer;
begin
  if Find(s, i) then
    Result:=IntToStr(TParamID(Objects[i]).ID)
  else
    Result:='UNKNOWN';
end;

var
  ShaderIDs: TMaterialParameterIDs;

function GetParamIDs: TMaterialParameterIDs;
begin
  if ShaderIDs = nil then
    ShaderIDs:=TMaterialParameterIDs.Create;
  Result:=ShaderIDs;
end;

function TMaterialParameter.GetShaderID: string;
begin
  Result:=GetParamIDs.Substitute(FName);
end;

function TMaterialParameter.GetShaderDefaultValue: string;
begin
  Result:='0';
end;

procedure TMaterialParameter.PackAt2(dst: pointer);
begin
  PlaceDataAt(pointer(Integer(dst) + GetParamIDs.OffsetOf(FName)));
end;

procedure TMaterialParameter.UnpackFrom2(src: pointer);
begin
  GetDataFrom(pointer(Integer(src) + GetParamIDs.OffsetOf(FName)));
end;

procedure TMaterialParameter.UpdateFrom(conv: IMaterialConverter);
begin
  if FUpdatable then
    ExtractFrom(conv);
end;

function TMaterialParameter.GetIntName: string;
begin
  Result:=FName;
end;
{
procedure TMaterialParameter.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.Attributes['Name']:=FName;
    root.Attributes['AltName']:=FAltName;
    root.Attributes['Type']:=GetType;
    root.Attributes['Custom']:=FCustomizable;
  end;
end;
}
procedure TMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.GetOrCreateAttr('Name').Value := AnsiToUtf8Ex(FName, 1251);
    root.GetOrCreateAttr('AltName').Value := AnsiToUtf8(FAltName);
    root.GetOrCreateAttr('Type').ValueAsInteger := GetType;
    root.GetOrCreateAttr('Custom').ValueAsBool := FCustomizable;
    root.GetOrCreateAttr('Optional').ValueAsBool := FOptional;
    root.GetOrCreateAttr('Category').Value := AnsiToUtf8(FCategory);
  end;
end;

procedure TMaterialParameter.SetIntName(aName: string);
begin
  FName := aName;
end;
{
procedure TMaterialParameter.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  if assigned(root) then
  begin
    if root.HasAttribute('Type') then
      FType := TMaterialParameterType(root.Attributes['Type']);
    if root.HasAttribute('AltName') then
      FAltName:=root.Attributes['AltName'];
    if root.HasAttribute('Custom') then
      FCustomizable:=root.Attributes['Custom'];
  end;
end;
}
procedure TMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  if assigned(root) then
  begin
    if root.HasAttribute('Type') then
      FType := TMaterialParameterType(root.AttributeByName['Type'].ValueAsInteger);
    if root.HasAttribute('AltName') then
      FAltName := Utf8ToAnsi(root.AttributeByName['AltName'].Value);
    if root.HasAttribute('Custom') then
      FCustomizable := root.AttributeByName['Custom'].ValueAsBool;
    if root.HasAttribute('Optional') then
      FOptional := root.AttributeByName['Optional'].ValueAsBool;
    if root.HasAttribute('Category') then
      FCategory := Utf8ToAnsi(root.AttributeByName['Category'].Value);
  end;
end;

function TMaterialParameter.EqualTo(p: TMaterialParameter): boolean;
begin
  Result:=(LowerCase(FName) = LowerCase(p.FName))and
  (LowerCase(FAltName) = LowerCase(p.FAltName))and
  (FType = p.FType);
end;

const
  cmMatParamCategory: cardinal = 12345678;

procedure TMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
var
  t: cardinal;
begin
  with WriteInfo do
  begin
    Writer.WriteString(FName);
    t:=cardinal(FType);
    Writer.Write(t, sizeof(t));
    Writer.WriteString(FAltName);
    Writer.WriteMagic(cmMatParamCategory);
    Writer.WriteString(FCategory);
  end;
end;

procedure TMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  with ReadInfo do
  begin
    FAltName:=Reader.ReadString();
    if Reader.CheckMagic(cmMatParamCategory) then
      FCategory:=Reader.ReadString;
  end;
end;

procedure TMaterialParameter.ChangeOwner(const newOwner: TObject);
begin
  if assigned(FOnChange) and (FOnChange.LinkedTo = FOwner) then
    FOnChange.Free;
  FOwner:=newOwner;
end;

function TMaterialParameter.GetCategory: string;
begin
  Result:=FCategory;
end;

procedure TMaterialParameter.LinkTo(p: TMaterialParameter);
begin
  FreeAndNil(FLink);
  if p <> nil then
    FLink:=TMaterialParameterSmartRef.Create(p);
end;

function TMaterialParameter.This: TMaterialParameter;
begin
  Result:=self;
end;

function TMaterialParameter.GetAltName: string;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.AltName;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=FAltName;
end;

function TMaterialParameter.GetCustom: boolean;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.Customizable;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=FCustomizable;
end;

procedure TMaterialParameter.SetAltName(const Value: string);
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        p.AltName:=Value;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  FAltName:=Value;
end;

procedure TMaterialParameter.SetCustom(const Value: boolean);
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        p.Customizable:=Value;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  FCustomizable:=Value;
end;

function TMaterialParameter.GetOnChange: TNotifyEvent;
begin
  TMethod(Result) := FOnChange.LockRef;
  FOnChange.UnlockRef;
end;

procedure TMaterialParameter.SetOnChange(const Value: TNotifyEvent);
begin
  if FOnChange = nil then
    FOnChange := TNotifyEventRef.Create(TMethod(Value))
  else
    FOnChange.ModifyLink(TMethod(Value));
end;

function TMaterialParameter.GetOptional: boolean;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        Result:=p.Optional;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=FOptional;
end;

procedure TMaterialParameter.SetOptional(const Value: boolean);
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p <> nil then
      begin
        p.Optional:=Value;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  FOptional:=Value;
end;

function TMaterialParameter.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
	if IsEqualGUID(IID, IWeakRefsHolder) and (FWeakRefs = nil) then
		FWeakRefs:=TWeakRefList.Create;
	Result := inherited QueryInterface(IID, Obj);
end;

function TMaterialParameter.GetGlobalUniqueIdentifier: TGUID;
begin
  Result := FGUID;
end;

function TMaterialParameter.Description: string;
var
  m: TMaterial;
begin
  m := GetMaterial;
  if (m <> nil) then
  begin
    if m.GetFriendlyName <> '' then
      Result := m.GetFriendlyName + '.' + GetName
    else
      Result := m.GetName + '.' + GetName;
  end
  else
    Result := GetName;
end;

procedure TMaterialParameter.RelinkRefs(const src: TMaterialParameter);
begin
  if src.FWeakRefs <> nil then
    src.FWeakRefs.RelinkTo(Self);
end;

{ TMaterialList }

constructor TMaterialList.Create(aOwner: TObject);
begin
  FOwner:=aOwner;
  inherited Create;
end;

function TMaterialList.GetOrCreateMaterialByClassAndName(aClass,
  aName: string; WithoutVersion: boolean = false): TMaterial;
begin
  Result:=GetOrAdd(MaterialTypes.FindMaterialTypeByClassName(aClass), aName, WithoutVersion);
end;

function TMaterialList.GenerateShaderMaterialEvaluationFunction: string;
var
  i: integer;
  l: TIntegerList;
begin
  l:=TIntegerList.Create{$IFDEF OWNED_LISTS}(nil){$ENDIF};
  for i:=0 to count - 1 do
    l.AddSorted(TMaterial(List[i]).FType, true);

  Result:='';
  for i:=0 to l.count - 1 do
    Result:=Result + MaterialTypes.FindType(l.List[i]).GetShaderEvaluationCase;
  l.Free;

  Result:='[forcecase] switch( asuint($MATLIST[matIndex].x) ) {' + Result + '};';
end;

function TMaterialList.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
begin
  with LoadInfo do
    case ChildBlockType of
      btMaterialListItem: begin
        Result:=New(TMaterialClass(GetClass(ChildClass)), ChildID, true); {Log('Загружается материал ' + ChildID);}
      end;
    else
      Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID);
    end;
end;

function TMaterialList.GetOrAdd(aType: integer; aName: string; WithoutVersion: boolean): TMaterial;
var
  i: integer;
begin
  i:=IndexOf(aName);
  if i > -1 then
    Result:=TMaterial(List[i])
  else
    Result:=New(aType, aName, WithoutVersion);
end;

function TMaterialList.IndexOf(aName: string): Integer;
begin
  Result:=Count - 1;
  while (Result > -1) and (AnsiCompareText(TMaterial(List[Result]).FName, aName) <> 0) do
    Dec(Result);
end;

function TMaterialList.LoadFromFile(filename, check_hash: string): boolean;
var
  n: integer;
  f: TFileStream;
  hash: string;
begin
  if not FileExists(filename) then
  begin
    Result:=false;
    exit;
  end;
  f:=TFileStream.Create(filename, fmOpenRead);
  try
    f.Read(n, 4);
    SetLength(hash, n);
    f.Read(hash[1], n);
    if hash <> check_hash then
    begin
      Result:=false;
      exit;
    end;
    Result:=ReadCP3DB(f, self, 0, CONTENT_TYPE_MATERIAL_LIST) = 0;
  finally
    f.Free;
  end;
end;

function TMaterialList.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btMaterialListCount: Clear;
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TMaterialList.MaterialParameterChanged(Sender: TObject);
begin
  if assigned(FOnMaterialChanged) then
    FOnMaterialChanged(Sender);
end;

function TMaterialList.New(aType: integer; aName: string; WithoutVersion: boolean): TMaterial;
begin
  if WithoutVersion then
    Result:=MaterialTypes.FindMaterialClass(aType).CreateWithoutVersion(self)
  else
    Result:=MaterialTypes.FindMaterialClass(aType).Create(self);
  Result.FName:=aName;
  Result.OnMaterialChanged:=MaterialParameterChanged;
  Add(Result);
end;

function TMaterialList.New(aClass: TMaterialClass; aName: string; WithoutVersion: boolean): TMaterial;
begin
  if WithoutVersion then
    Result:=aClass.CreateWithoutVersion(self)
  else
    Result:=aClass.Create(self);
  Result.FName:=aName;
  Result.OnMaterialChanged:=MaterialParameterChanged;
  Add(Result);
end;

function TMaterialList.PackIntoBuffer(atlas: TMaterialTextureAtlas): TMemoryStream;
var
  i, csize, ssize: integer;
begin
  Result:=TMemoryStream.Create;
  ssize:=0;
  for i:=0 to count - 1 do
  begin
    csize:=TMaterial(List[i]).Parameters.TotalNumFloats;
    if csize > ssize then
      ssize:=csize;
    if atlas <> nil then
      TMaterial(List[i]).SetAtlas(atlas);  //Считываем положения наших текстур с атласа
  end;
  ssize:=ceil(ssize / 4) * 4; //Добиваем размер блока с данными до float4
  FNumFloatsInBlock:=ssize;
  ssize:=ssize * sizeof(single);  //Переводим размер блока в байты
  Result.Size:=ssize * count + 4 * 4;  //Вычисляем размер результата = размер_блока * кол-во_блоков + float4 (первый элемент равен размеру блока во float4, остальные не определены)
//todo: разобраться почему не работает (например на RICHESSE В2(на ноутах SR зависает на подготовке).cp3) и раскомментить
{  PCardinal(Result.Memory)^:=cardinal(FNumFloatsInBlock shr 2);
  for i:=0 to count - 1 do
    TMaterial(List[i]).Parameters.PackAt(pointer(Integer(Result.Memory) + 4 * 4 + ssize * i));}
end;

procedure TMaterialList.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
  i: integer;
begin
  with SaveInfo, Writer do
  try
    WriteInteger(btMaterialListCount, Count);
    for i:=0 to count - 1 do
    begin
      BeginChild(btMaterialListItem, TMaterial(List[i]).Name, TMaterial(List[i]).ClassName);
      try
        TMaterial(List[i]).SaveObject(SaveInfo);
      finally
        EndChild;
      end;
    end;
  except
    on e: exception do
      SaveInfo.Error('TMaterialList: ' + e.Message);
  end;
  inherited;
end;

procedure TMaterialList.SaveToFile(filename, hash: string);
var
  n: integer;
  f: TFileStream;
begin
  f:=TFileStream.Create(filename, fmCreate);
  try
    n:=Length(hash);
    f.Write(n, 4);
    f.Write(hash[1], n);
    WriteCP3DB(f, self, 0, CONTENT_TYPE_MATERIAL_LIST, COMPRESS_ZIP);
  finally
    f.Free;
  end;
end;

procedure TMaterialList.TestModify;
var
  i: integer;
//  v: TFloat4MaterialParameter;
  p: TFloat3MaterialParameter;
  f: TFloatMaterialParameter;
begin
  for i:=0 to count - 1 do
    with TMaterial(List[i]).Parameters do
    begin
{      if FindParameter('diffuse', v) then
        v.Value:=VectorMake(0.9, 0.9, 0.9, v.Value[3]);}
      if FindParameter('ambient', p) then
        p.Value:=AffineVectorMake(0.62745);
      if FindParameter('specular', p) then
        p.Value:=AffineVectorMake(1.0);
      if FindParameter('roughness', f) then
        f.Value:=0.3;
      if FindParameter('blur', f) then
        f.Value:=0.05;
    end;
end;

function TMaterialList.GetOrCreateMaterialByClassAndNameAsObj(aClass,
  aName: string): TObject;
begin
  Result:=GetOrCreateMaterialByClassAndName(aClass, aName, true);
end;

procedure TMaterialList.PreloadTextures;
var
  i: integer;
begin
  for i:=0 to count - 1 do
    TMaterial(List[i]).Textures.PreloadTextures;
end;

function TMaterialList.IndexOfMaterial(aObject: TObject): Integer;
begin
  Result:=inherited IndexOf(aObject);
end;

function TMaterialList.CreateMaterialByClassAndNameAsObj(aClass,
  aName: string): TObject;
begin
  Result:=New(MaterialTypes.FindMaterialTypeByClassName(aClass), aName);
end;

function TMaterialList.Find(aName: string): TMaterial;
var
  i: integer;
begin
  i:=IndexOf(aName);
  if i > -1 then
    Result:=TMaterial(List[i])
  else
    Result:=nil;
end;

function TMaterialList.GenShaderLib: string;
begin
{ Создает готовый исходник шейдера, который позволяет получать значения любого параметра материала по индексу материала и индексу параметра
  Нумерация параметров сквозная (номер статичный и задается в конструкторе класса параметра)

  Группируем материалы по типам. У каждого типа свой список параметров, соответственно нужна своя процедура чтения
}
  with GroupByType do
  try
    Result:=GenShaderLib;
  finally
    Free;
  end;
end;

function TMaterialList.GroupByType: TMaterialTypeLibrary;
var
  i: integer;
begin
  Result:=TMaterialTypeLibrary.Create(nil);
  for i:=0 to Count - 1 do
    if Result.IndexOfType(TMaterial(self.List[i]).FType) = -1 then
      Result.Add(TMaterialClass(TMaterial(self.List[i]).ClassType).Create(Result));
end;

function TMaterialList.GetShaderLib2: string;
var
//  libid: TGUID;
  lib: TStringList;
begin
//  CreateGUID(libid);
  lib:=TStringList.Create;
  try
    lib.Add('//Shader type library v2. Autogenerated');
    lib.Add('#ifndef matlibincluded');// + GUIDToString(libid));
    lib.Add('#define matlibincluded');// + GUIDToString(libid));
    lib.Add('');
    lib.Add('struct TTextureValue');
    lib.Add('{');
    lib.Add('  float  MaxLod;');
    lib.Add('  float  TexelScale;');
    lib.Add(' float2 TexelSize;');
    lib.Add(' float3 IndexArr[15];');
    lib.Add(' float2 ScaleArr[15];');
    lib.Add('};');
    lib.Add('');
    lib.Add('struct TMaterial');
    lib.Add('{');
    lib.Add(' uint Name[5];');
    lib.Add('  uint _type;');
    lib.Add('');
    lib.Add('  float3 Ambient;');
    lib.Add('  float AmbientLevel;');
    lib.Add('');
    lib.Add('  float3 OldLevels;');
    lib.Add('  float3 OldAmbient;');
    lib.Add('  float3 OldDiffuse;');
    lib.Add('  float3 OldSpecular;');
    lib.Add('');
    lib.Add('  float3 Diffuse;');
    lib.Add('  float DiffuseLevel;');
    lib.Add('');
    lib.Add('  float3 Reflection;');
    lib.Add('  float ReflectionLevel;');
    lib.Add('  float ReflectionMixStart;');
    lib.Add('  float ReflectionMixEnd;');
    lib.Add('  float ReflectionKdLevel;');
    lib.Add('  float ReflectionBlur;');
    lib.Add('  float ReflectionFresnel;');
    lib.Add('');
    lib.Add('  float3 Refraction;');
    lib.Add('  float RefractionLevel;');
    lib.Add('  float RefractionMixStart;');
    lib.Add('  float RefractionMixEnd;');
    lib.Add('  float RefractionKdLevel;');
    lib.Add('  float RefractionBlur;');
    lib.Add('  float RefractionIndex;');
    lib.Add('');
    lib.Add('  float3 Albedo;');
    lib.Add('  float AlbedoLevel;');
    lib.Add('');
    lib.Add('  float Opacity;');
    lib.Add('  float OldOpacity;');
    lib.Add('');
    lib.Add('  float3 Emission;');
    lib.Add('  float EmissionLevel;');
    lib.Add('');
    lib.Add('  float Roughness;');
    lib.Add('  float Blur;');
    lib.Add('');
    lib.Add('  uint Flags;');
    lib.Add('');
    lib.Add('  TTextureValue BaseMap;');
    lib.Add('  matrix TexMatrix;');
    lib.Add('  TTextureValue BumpMap;');
    lib.Add('');
    lib.Add('  float LightAttenuation;');
    lib.Add('  uint LightFlags;');
    lib.Add('  float MixOffset;');
    lib.Add('};');
    lib.Add('');
    lib.Add('#define TMaterialList StructuredBuffer <TMaterial>');
    lib.Add('#define TTextureAtlas Texture2D <float4>');
    lib.Add('');
    lib.Add('#endif');
    Result:=lib.Text;
  finally
    lib.Free;
  end;
end;

function TMaterialList.PackIntoBuffer2(
  atlas: TMaterialTextureAtlas): TMemoryStream;
var
  i, j: integer;
  sm: PShaderMaterial;
  m: TMaterial;
begin
  Result:=TMemoryStream.Create;
  Result.Size:=sizeof(TShaderMaterial) * Count;
  for i:=0 to count - 1 do
  begin
{    TMaterial(List[i]).Parameters.CountOffsets;
    TMaterial(List[i]).SetAtlas(atlas);  //Считываем положения наших текстур с атласа}
    m:=TMaterial(List[i]);
    sm:=PShaderMaterial(Integer(Result.Memory) + i * sizeof(TShaderMaterial));
    FillChar(sm^, Sizeof(sm^), 0);
    j:=Min(Length(m.Name), Length(sm.Name));
    while j > 0 do
    begin
      sm.Name[j - 1]:=m.Name[j];
      dec(j);
    end;
    m.Parameters.PackAt2(sm);
  end;
end;

procedure TMaterialList.UnpackFromBuffer2(stm: TStream);
var
  i, n: integer;
  sm: TShaderMaterial;
  m: TMaterial;
begin
  Clear;
  n:=stm.Size div sizeof(TShaderMaterial);
  for i:=0 to n - 1 do
  begin
    stm.Read(sm, sizeof(sm));
    m:=New(sm._type, sm.Name);
    m.Parameters.UnpackFrom2(@sm);
  end;
end;

function TMaterialList.FindMaterial(const aName: string): TMaterial;
begin
  Result:=Find(aName);
end;

function TMaterialList.GetCount: Integer;
begin
  Result:=Count;
end;

function TMaterialList.GetItem(const Index: Integer): TMaterial;
begin
  Result:=TMaterial(Items[Index]);
end;

procedure TMaterialList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  if (Ptr <> nil) and (TMaterial(Ptr).Owner = Self) then
    inherited;
end;

destructor TMaterialList.Destroy;
var
  i: integer;
  m: TMaterial;
  n: TNotifyEvent;
begin
  n:=Self.MaterialParameterChanged;
  for i:=0 to Count - 1 do
  begin
    m:=TMaterial(List[i]);
    if @m.FOnMaterialChanged = @n then
      m.OnMaterialChanged:=nil;
  end;
  inherited;
end;

function TMaterialList.AddMultiMaterial(const aName: string; const Index: Integer; onMultiCreated: TMultiMaterialCreated): TMultiMaterial;
begin
	Result:=nil;
end;

function TMaterialList.FindOldMaterialByNewMaterial(rendMaterial: TMaterial): Integer;
begin
	Result:=-1;
end;

function TMaterialList.SetMonoMaterial(const MonoMaterialName: string;
  const OwnerIndex: Integer; onMonoCreated: TMonoMaterialCreated;
  MonoClass: TMaterialClass): TMaterial;
begin
  Result:=nil;
end;

procedure TMaterialList.ParametersChanged;
begin
  if FOwner is TMaterialType then
    TMaterialType(FOwner).ParameterChanged(Self);
end;

procedure TMaterialList.ExecCommand(cmd: cardinal; params: TCommandParams);
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    TMaterial(Items[i]).ExecCommand(cmd, params);
end;

procedure TMaterialList.UpdateSetMaterial(aWndHandle: Cardinal; aMaterial: TMaterial);
begin
  //
end;

{ TSimpleTexturesList }

constructor TSimpleTexturesList.Create(const aOwner: TMaterial);
begin
  inherited Create;
  FOwner := aOwner;
end;

procedure TSimpleTexturesList.AddTexture(aTextureID: string; aTexture: TMaterialTexture);
begin
  AddObject(aTextureID, aTexture);
end;

procedure TSimpleTexturesList.Assign(src: TList);
var
  i: integer;
begin
  if src is TSimpleTexturesList then
  begin
    Clear;
    for i:=0 to TSimpleTexturesList(src).Count - 1 do
      with TSimpleTexturesList(src).Items[i] do
      begin
        //AddObject(TextureName, Data); //?
        AddObject(TextureName, nil).Assign(TSimpleTexturesList(src).Items[i]);
      end;
  end;
end;

procedure TSimpleTexturesList.GetTexture(index: integer; var obj);
begin
  TObject(obj):=Items[index].Data;
end;

function TSimpleTexturesList.FindTextureItem(aName: string; var obj: TSimpleTexturesListItem): boolean;
var
  i: integer;
begin
  if Find(aName, i) then
  begin
    obj:=Items[i];
    Result:=true;
  end
  else
    Result:=false;
end;

procedure TSimpleTexturesList.GetTexture(index: integer; var obj;
  var aTextureID: string);
begin
  with Items[index] do
  begin
    TObject(obj):=Data;
    aTextureID:=TextureName;
  end;
end;

procedure TSimpleTexturesList.ReadValues(params: TMaterialParameters; conv: IMaterialConverter);
var
  i, j: integer;
  t: TObject;
  found: boolean;
  notFounds: TStringList;
  p: TMaterialParameter;
begin
  notFounds:=TStringList.Create;
  notFounds.CaseSensitive:=false;
  notFounds.Sorted:=true;
//Это будет список неиспользуемых текстур
  for i:=0 to count - 1 do
    notFounds.Add(Items[i].TextureName);
//Вытаскиваем из параметров материала список нужных для него текстур
  with params.ExtractTextureIDs do
  try
    for i:=0 to count - 1 do
    begin
//Убираем из списка неиспользуемых, т.к. используется
      if notFounds.Find(Strings[i], j) then
        notFounds.Delete(j);
      found:=self.Find(Strings[i], j);
      if (not found) or (self.Items[j].Data = nil) then
      begin
  //Пытаемся найти в старом материале нужную текстуру
        t:=conv.GetTexture(Strings[i]);
  //Если текстура нашлась
        if t is TMaterialTexture then
        begin
  //Поищем текстуру в списке текстур материала
          if found then
  //Если текстура есть, то заменим ее на ту, что в старом материале
  //        if (self.Items[j].Data = nil) or ((self.Items[j].Data is TMaterialTexture) and (TMaterialTexture(self.Items[j].Data).Empty or (TMaterialTexture(self.Items[j].Data).DetectExt(true) = '.bmp')) ) then
              self.Items[j].Data:=TMaterialTexture(t)
    //        else
          else
  //Если текстуры нет, то добавим
            self.AddTexture(Strings[i], TMaterialTexture(t));
          if params.FindParameter(Strings[i], p) and (p is TTextureMaterialParameter) then
            TTextureMaterialParameter(p).Enabled:=true;
        end;
      end;
    end;
//Удалим неиспользуемые
    for i:=0 to notFounds.Count - 1 do
      if self.Find(notFounds[i], j) then
        self.Delete(j);
  finally
    Free;
    notFounds.Free;
  end;
end;

procedure TSimpleTexturesList.SetupCache(TextureNames: array of string; Transform: array of PMatrix);
var
  i: integer;
  t: TSimpleTexturesListItem;
begin
  if Length(Cache) < Length(TextureNames) then
    SetLength(Cache, Length(TextureNames));
  for i:=0 to High(TextureNames) do
    if FindTextureItem(TextureNames[i], t) then
    begin
      Cache[i].texelScale:=VectorLength(Transform[i][0]) * VectorLength(Transform[i][1]);
      if not t.Data.GetInterface(ITextureSampler, Cache[i].sampler) then
        Cache[i].sampler:=nil
      else
      with Cache[i].sampler.GetTextureSize do
        if Cache[i].texelScale = 0 then
          Cache[i].texelScale:=width * height
        else
          Cache[i].texelScale:= width * height *{/} Cache[i].texelScale;
    end;
end;

function TSimpleTexturesList.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
var
  i: integer;
begin
  case ChildBlockType of
    btSimpleTexturesListItem:
      if Find(ChildID, i) then
        Result:=Items[i]
      else
        Result:=AddObject(ChildID, nil);
  else
    Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID);
  end;
end;

procedure TSimpleTexturesList.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
  i: integer;
begin
  with SaveInfo, Writer do
  try
    for i:=0 to count - 1 do
      with Items[i] do
      begin
        BeginChild(btSimpleTexturesListItem, '', TextureName);
        try
          SaveObject(SaveInfo);
        finally
          EndChild;
        end;
      end;
  except
    on e: exception do
      SaveInfo.Error('TSimpleTexturesList: ' + e.Message);
  end;
  inherited;
end;

function TSimpleTexturesList.AddObject(aTextureName: string;
  aTextureObject: TMaterialTexture): TSimpleTexturesListItem;
var
  index: integer;
begin
  if not Find(aTextureName, index) then
  begin
    Result:=TSimpleTexturesListItem.Create(Self);
    Result.TextureName:=aTextureName;
    Result.Data:=aTextureObject;
    Insert(index, Result);
    NotifyChange;
  end
  else
    Result:=Items[index];
end;

function TSimpleTexturesList.GetItem(
  index: integer): TSimpleTexturesListItem;
begin
  Result:=TSimpleTexturesListItem(List[index]);
end;

function TSimpleTexturesList.Find(TexName: string;
  var index: integer): boolean;
var
  L, H, I, C: Integer;
begin
  Result := False;
  L := 0;
  H := Count - 1;
  while L <= H do
  begin
    I := (L + H) shr 1;
    C := AnsiCompareText(TSimpleTexturesListItem(List[I]).TextureName, TexName);
    if C < 0 then L := I + 1 else
    begin
      H := I - 1;
      if C = 0 then
      begin
        Result := True;
        L := I;
      end;
    end;
  end;
  Index := L;
end;

function TSimpleTexturesList.HasItem(const aTextureName: string): Boolean;
var
  i: integer;
begin
  Result := Find(aTextureName, i);
end;

procedure TSimpleTexturesList.PreloadTextures;
var
  i: integer;
begin
  for i:=0 to count - 1 do
    TSimpleTexturesListItem(List[i]).PreloadTexture;
end;

function TSimpleTexturesList.GetSampler(texName: string; out sampler: ITextureSampler): boolean;
var
  it: TSimpleTexturesListItem;
begin
  Result:=FindTextureItem(texName, it) and (it.Data <> nil) and it.Data.GetInterface(ITextureSampler, sampler);
end;

procedure TSimpleTexturesList.AssignFrom(src: TSimpleTexturesList);
var
  i, j: integer;
begin
  for i:=0 to src.Count - 1 do
    if Find(src.Items[i].TextureName, j) then
      Items[j].Data:=src.Items[i].Data
    else
    with src.Items[i] do
      self.AddObject(TextureName, Data);
end;

function TSimpleTexturesList.GetValue(index: string): TMaterialTexture;
var
  o: TSimpleTexturesListItem;
begin
  if FindTextureItem(index, o) then
    Result:=o.Data
  else
    Result:=nil;
end;

procedure TSimpleTexturesList.SetValue(index: string;
  const Value: TMaterialTexture);
var
  o: TSimpleTexturesListItem;
begin
  if FindTextureItem(index, o) then
    o.Data:=Value
  else
    AddTexture(index, Value);
end;

procedure TSimpleTexturesList.SaveAll(Path: string);
var
  i: integer;
  ss: IStorableSampler;
  f: TFileStream;
begin
  if (Count > 0) and ForceDirectories(Path) then
  begin
    for i:=0 to Count - 1 do
      if Items[i].Data.GetInterface(IStorableSampler, ss) then
      begin
        f:=TFileStream.Create(path + ss.GetFilename, fmCreate);
        try
          ss.SaveToStream(f);
        finally
          f.Free;
          ss:=nil;
        end;
      end;
  end;
end;

procedure TSimpleTexturesList.WriteValues(params: TMaterialParameters;
  conv: IMaterialConverter);
var
  i, j: integer;
  t: TObject;
begin
//Вытаскиваем из параметров материала список нужных для него текстур
  with params.ExtractTextureIDs do
  try
    for i:=0 to count - 1 do
    begin
//Пытаемся найти в старом материале нужную текстуру
      t:=conv.GetTexture(Strings[i]);
//Если текстура нашлась
      if t <> nil then
//Поищем текстуру в списке текстур материала
        if self.Find(Strings[i], j) then
          conv.SetTexture(Strings[i], self.Items[j].Data)
        else
//Если текстуры нет, то выключим
          conv.SetTexture(Strings[i], nil);
    end;
  finally
    Free;
  end;
end;
{
procedure TSimpleTexturesList.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
var
  i: integer;
begin
  if assigned(root) then
    for i:=0 to count - 1 do
      items[i].SaveToXml(root.AddChild('t'), SaveFlags);
end;
}
procedure TSimpleTexturesList.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
var
  i: integer;
begin
  if assigned(root) then
    for i:=0 to count - 1 do
      items[i].SaveToXml(root.NodeNew('t'), SaveFlags);
end;
{
procedure TSimpleTexturesList.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
var
  i: integer;
begin
  if assigned(root) then
    for i:=0 to count - 1 do
      items[i].SaveToXml(root.NodeNew('t'), SaveFlags);
end;

procedure TSimpleTexturesList.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
var
  i: integer;
  node: IXMLNode;
begin
  if assigned(root) then
  begin
    Clear;
    for i:=0 to root.ChildNodes.Count - 1 do
    begin
      node:=root.ChildNodes[i];
      if node.HasAttribute('TextureName') then
        AddObject(node.Attributes['TextureName'], nil).LoadFromXml(node, LoadFlags);
    end;
  end;
end;
}
procedure TSimpleTexturesList.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
var
  i: integer;
  node: TXMLNode;
begin
  if assigned(root) then
  begin
    Clear;
    for i:=0 to root.NodeCount - 1 do
    begin
      node:=root.Nodes[i];
      if node.HasAttribute('TextureName') then
        AddObject(Utf8ToAnsi(node.AttributeByName['TextureName'].Value), nil).LoadFromXml(node, LoadFlags);
    end;
  end;
end;

function TSimpleTexturesList.EqualTo(t: TSimpleTexturesList): boolean;
var
  i: integer;
  t0: TSimpleTexturesListItem;
begin
  Result:=False;
  if (Count <> t.Count) then exit;
  for i:=0 to Count-1 do
  begin
    if FindTextureItem(Items[i].TextureName, t0) then
      Result:=Items[i].EqualTo(t0)
    else
      Result:=False;

    if not Result then break;
  end;
end;

procedure TSimpleTexturesList.WriteToFiler(WriteInfo: TWriteInfo);
var
  i: integer;
begin
  with WriteInfo do
  begin
    Writer.Write(count, SizeOf(count));
    for i:=0 to count - 1 do
      items[i].WriteToFiler(WriteInfo);
  end;
end;

procedure TSimpleTexturesList.ReadFromFiler(ReadInfo: TReadInfo);
var
  i, aCount: integer;
begin
  with ReadInfo do
  begin
    Reader.Read(aCount, sizeof(aCount));
    for i:=0 to aCount - 1 do
      AddObject(Reader.ReadString, nil).ReadFromFiler(ReadInfo);
  end;
end;

procedure TSimpleTexturesList.AddToParameters(
  const params: TMaterialParameters);
var
  i: integer;
  p: TMaterialParameter;
begin
  for i:=0 to Count - 1 do
    with Items[i] do
      if (TextureName <> '') and (Data <> nil) and (params.FindParameter(TextureName, p) = false) then
        params.NewTexture(TextureName).FCustomizable:=true;
end;

function TSimpleTexturesList.ListTextures: string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to Count - 1 do
    Result:=Result + Items[i].TextureName + #13#10;
end;

function TSimpleTexturesList.RemoveValue(aName: string): Boolean;
var
  m: TSimpleTexturesListItem;
begin
  Result:=False;
  if FindTextureItem(aName, m) then
  begin
    Remove(m);
    Result:=True;
  end;
end;

procedure TSimpleTexturesList.SetSampler(texName: string;
  const sampler: ITextureSampler; OwnData: boolean);
begin
  if sampler = nil then
    AddObject(texName, nil).Data:=nil
  else
  begin
    if OwnData then
      AddObject(texName, sampler.GetSamplerObject as TMaterialTexture).OwnedData:=sampler.GetSamplerObject as TMaterialTexture
    else
      AddObject(texName, sampler.GetSamplerObject as TMaterialTexture).Data:=sampler.GetSamplerObject as TMaterialTexture;
  end;
end;

procedure TSimpleTexturesList.SetTexture(aTextureID: string;
  aTexture: TMaterialTexture; OwnData: boolean);
begin
  if OwnData then
    AddObject(aTextureID, aTexture).OwnedData:=aTexture
  else
    AddObject(aTextureID, aTexture).Data:=aTexture;
end;

procedure TSimpleTexturesList.NotifyChange;
begin
  if assigned(FOnChange) then
    FOnChange.Notify(self);
end;

function TSimpleTexturesList.RenameValue(aOldName,
  aNewName: string): boolean;
var
 i, j: Integer;
begin
  if Find(aOldName, i) and (Find(aNewName, j) = false) then
  begin
    Result:=true;
    Items[i].TextureName:=aNewName;
    Move(i, j);
  end
  else
    Result:=False;
end;

function TSimpleTexturesList.GetOnChange: TNotifyEvent;
begin
  TMethod(Result) := FOnChange.LockRef;
  FOnChange.UnlockRef;
end;

procedure TSimpleTexturesList.SetOnChange(const Value: TNotifyEvent);
begin
  if FOnChange = nil then
    FOnChange := TNotifyEventRef.Create(TMethod(Value))
  else
    FOnChange.ModifyLink(TMethod(Value));
end;

destructor TSimpleTexturesList.Destroy;
begin
  FOnChange.Free;
  inherited;
end;

procedure TSimpleTexturesList.ExecCommand(cmd: cardinal;
  params: TCommandParams);
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    if Assigned(Items[i]) then
    begin
      case cmd of
        cFindTextureByID: if not params.Done then
          Items[i].ExecCommand(cmd, params);
      else
        Items[i].ExecCommand(cmd, params);
      end;
    end;
end;

function TSimpleTexturesList.GetOwner: TMaterial;
begin
  Result := FOwner;
end;

procedure TSimpleTexturesList.RemoveEmptyItems;
var
  i: integer;
begin
  for i:=count - 1 downto 0 do
    if (Items[i].Data = nil) or Items[i].Data.Empty then
      Delete(i);
end;

{ TMaterialTypeLibrary }

function TMaterialTypeLibrary.FindMaterialClass(
  aType: integer): TMaterialClass;
begin
  Result:=TMaterialClass(FindType(aType).ClassType);
end;

function TMaterialTypeLibrary.FindMaterialClassByName(
  aName: string): TMaterialClass;
var
  i: integer;
begin
  for i:=0 to count - 1 do
    if TMaterial(List[i]).ClassName = aName then
    begin
      Result:=TMaterialClass(TMaterialType(List[i]).ClassType);
      exit;
    end;
  raise Exception.Create('Unknown material class ' + aName);
end;

function TMaterialTypeLibrary.FindMaterialTypeByClassName(
  aName: string): integer;
var
  found: TMaterialClass;
begin
  found:=FindMaterialClassByName(aName);
  if found <> nil then
    Result:=TMaterialTypeClass(found).GetTypeIndex
  else
    Result:=TDiffuseMaterial.GetTypeIndex;
end;

function TMaterialTypeLibrary.FindType(aType: Integer): TMaterialType;
var
  i: integer;
begin
  for i:=0 to count - 1 do
    if TMaterial(List[i]).FType = aType then
    begin
      Result:=TMaterialType(List[i]);
      exit;
    end;
  raise Exception.Create('Unknown material type ' + IntToStr(aType));
end;

function Capitalize(const s: string): string;
begin
  if (Length(s) > 0) then
    Result:=AnsiUpperCase(s[1]) + Copy(s, 2, Length(s))
  else
    Result:=s;
end;

function TMaterialTypeLibrary.GenShaderLib: string;
  function FindParamTypeForName(pName: string): string;
  var
    i: integer;
    p: TMaterialParameter;
  begin
    for i:=0 to count - 1 do
      with TMaterial(List[i]).FParameters do
        if FindParameter(pName, p) then
        begin
          with p.RootClass do
            Result:=Capitalize(Copy(ClassName, 2, Length(ClassName)));
          exit;
        end;
    Result:='';
  end;
var
  libid: TGUID;
  lib, s, f, u: TStringList;
  i, j, k: integer;
  m: TMaterial;
  p: TMaterialParameter;
  pl: TMaterialParamsTypeLibrary;
  t0, t, PARAM_TYPE, CAP_PARAM_TYPE, DEFAULT_VALUE: string;
begin
  CreateGUID(libid);
  s:=TStringList.Create;
  f:=TStringList.Create;
  u:=TStringList.Create;
  lib:=TStringList.Create;
  try
    s.Add('$PARAM_TYPE Get$CAP_PARAM_TYPEMaterialParameter( TMaterialList mats, uint matIndex, uint paramID )');
    s.Add('{');
//    s.Add('  matIndex = 1 + asuint( mats[0].x ) * matIndex;');
    s.Add('  switch ( asuint( mats[ matIndex ].x ) )');
    s.Add('  {');
    for i:=0 to count - 1 do
    begin
      m:=TMaterial(List[i]);
      m.FParameters.CountOffsets;
      s.Add('    case ' + IntToStr(m.FType) + ': return Get' + Copy(m.ClassName, 2, Length(m.ClassName)) + '$CAP_PARAM_TYPEMaterialParameter ( mats, matIndex, paramID );');
    end;
    s.Add('  };');
    s.Add('  return $DEFAULT_VALUE;');
    s.Add('};');
    s.Add('');
    t0:=s.Text;

    lib.Add('//Shader type library. Autogenerated');
    lib.Add('#ifndef ' + GUIDToString(libid));
    lib.Add('#define ' + GUIDToString(libid));
    lib.Add('');
    lib.Add('#define TMaterialList StructuredBuffer <float4>');
    lib.Add('#define TTextureAtlas Texture2D <float4>');
    lib.Add('');
    lib.Add('float4x4 mExtractMatrix( TMaterialList mats, uint offset )');
    lib.Add('{');
    lib.Add('  return float4x4(mats[offset + 0], mats[offset + 1], mats[offset + 2], mats[offset + 3]);');
    lib.Add('}');
    lib.Add('');
    lib.Add('uint MatIndexToMatOffset ( TMaterialList mats, uint matIndex )');
    lib.Add('{');
    lib.Add('  return asuint( mats[0].x ) * matIndex + 1;');
    lib.Add('};');
    lib.Add('');
    lib.Add('uint GetMaterialType ( TMaterialList mats, uint matOffset )');
    lib.Add('{');
    lib.Add('  return asuint( mats[matOffset].x );');
    lib.Add('};');
    lib.Add('');
    lib.Add('/* Available ParamIDs:');
    with GetParamIDs.SortByIDs do
    try
      for i:=0 to count - 1 do
        lib.Add(Format('  %3d - %-40s [%s]', [TParamID(Objects[i]).ID, Strings[i], FindParamTypeForName(Strings[i])]));
    finally
      Free;
    end;
    lib.Add('*/');
    lib.Add('');
    lib.Add('struct atlasUV {');
    lib.Add('  float3 index;');
    lib.Add('  float2 scale;');
    lib.Add('};');
    lib.Add('');
    lib.Add('atlasUV CreateAtlasUV(float4 v, float w) {');
    lib.Add('  atlasUV a;');
    lib.Add('  a.index = v.xyz;');
    lib.Add('  a.scale = float2(v.w, w);');
    lib.Add('  return a;');
    lib.Add('};');
    lib.Add('');
    pl:=TMaterialParamsTypeLibrary.Create;
    try
      for i:=0 to count - 1 do
        TMaterial(List[i]).FParameters.AddTypes(pl);
      for i:=0 to pl.Count - 1 do
      begin
        PARAM_TYPE:=TMaterialParameter(pl.Objects[i]).GetShaderType;
        CAP_PARAM_TYPE:=Capitalize(PARAM_TYPE);
        DEFAULT_VALUE:=TMaterialParameter(pl.Objects[i]).GetShaderDefaultValue;
        f.Clear;
        for j:=0 to count - 1 do
        begin
          m:=TMaterial(List[j]);
          m.Parameters.ReSort;
          f.Add(PARAM_TYPE + ' Get' + Copy(m.ClassName, 2, Length(m.ClassName)) + CAP_PARAM_TYPE + 'MaterialParameter ( TMaterialList mats, uint matIndex, uint paramID )');
          f.Add('{');
          u.Clear;
          for k:=0 to m.FParameters.Count - 1 do
          begin
            p:=TMaterialParameter(m.FParameters.List[k]);
            if p.RootClass = TMaterialParameter(pl.Objects[i]).RootClass then
              u.Add('    case ' + p.GetShaderID + ': return ' + AnsiReplaceStr(p.GetShaderValue, '$MATLIST', 'mats') + '; // ' + p.FName);
          end;
          if u.Count > 0 then
          begin
            f.Add('  switch ( paramID )');
            f.Add('  {');
            f.Add(u.Text);
            f.Add('  };');
          end;
          f.Add('  return ' + TMaterialParameter(pl.Objects[i]).GetShaderDefaultValue + ';');
          f.Add('};');
          f.Add('');
        end;
        lib.Add(f.Text);
        t:=AnsiReplaceStr(t0, '$PARAM_TYPE', PARAM_TYPE);
        t:=AnsiReplaceStr(t, '$CAP_PARAM_TYPE', CAP_PARAM_TYPE);
        t:=AnsiReplaceStr(t, '$DEFAULT_VALUE', DEFAULT_VALUE);
        lib.Add(t);
      end;
    finally
      pl.Free;
    end;

    lib.Add('#endif');
    Result:=lib.Text;
  finally
    lib.Free;
    s.Free;
    f.Free;
    u.Free;
  end;
end;

function TMaterialTypeLibrary.IndexOfType(aType: Integer): integer;
begin
  Result:=count - 1;
  while (Result > -1) and (TMaterial(List[Result]).FType <> aType) do
    dec(Result);
end;

procedure TMaterialTypeLibrary.RegisterTypes(
  aTypes: array of TMaterialTypeClass);
var
  i, index: integer;
begin
  for i:=0 to High(aTypes) do
  begin
    index:=IndexOfType(aTypes[i].GetTypeIndex);
    if index > -1 then
    begin
      TObject(List[index]).Free;
      List[index]:=aTypes[i].Create(self);
    end
    else
      Add(aTypes[i].Create(self));
  end;
end;

{ TMaterialType }

constructor TMaterialType.Create(aOwner: TObject);
begin
  inherited;
  if FVersion < 0 then
    FVersion:=0
  else
  begin
    SetupParametersList;
    SetVersion(CurrentMaterialVersion);
  end;
end;

function TMaterialType.GetShaderEvaluationCase: string;
begin
  Result:='case ' + IntToStr(FType) + ': { $RESULT = float4(1.0, 0.0, 0.0, 1.0); } break;';
end;

procedure TMaterialType.InitParams;
begin
  inherited;
  SetupParametersList;
end;

procedure TMaterialType.SetupParametersList;
begin
  FType:=GetTypeIndex;
  TTypeMaterialParameter(Parameters.NewParameter('Type', TTypeMaterialParameter)).Value:=FType;
end;

function CookTorrance( const base: TAffineVector; Roughness, Blur: single; const normal: TAffineVector; const lightdir: TAffineVector;
  const viewdir: TAffineVector; const lightatt: TAffineVector; const matambient: TAffineVector; matdiffuse: TVector;
  const matspecular, matlevels, LightColor: TAffineVector; ShadowDiff: single = 1.0; ShadowSpec: single = 1.0; AmbientSpec: single = 1.0 ): TVector;
var
  r2, cosd, cosd2, NL, NV, VH, exponent, D, F, G: single;
  ldir, H, fvTotalSpecular, fvTotalDiffuse, fvTotalAmbient: TAffineVector;
begin
  r2:=(Blur * Blur);
  ldir:=lightdir;
  H:=VectorNormalize(VectorAdd(ldir, viewdir));
  cosd:=VectorDotProduct( normal, H );
  cosd2:=cosd * cosd;
  NL:=VectorDotProduct( normal, ldir );
  NV:=VectorDotProduct( normal, viewdir );
  VH:=VectorDotProduct( viewdir, H );
  exponent:=( cosd2 - 1.0 ) / ( cosd2 * r2 * Blur );
  D:=Power( 2.71, exponent ) / ( r2 * cosd2 * cosd2 );
  F:=Roughness + (1.0 - Roughness) * (1.0 - NL);
  G:=min( 1.0, min( 2.0 * NV / VH * NL,  2.0 * cosd / VH * NV ) );
  fvTotalSpecular:=VectorScale(matspecular, max(0.0, F * G * D / NV ) * matlevels[2] * ShadowSpec);
  fvTotalDiffuse:=VectorScale(TVectorCoords(matdiffuse).xyz, max(0.0, NL) * matlevels[1] * ShadowDiff);
  fvTotalAmbient:=VectorScale(matambient, ((1.0 - abs(NL)) + matlevels[0]) * AmbientSpec);
  ScaleVector(fvTotalAmbient, LightColor);
  ScaleVector(fvTotalDiffuse, LightColor);
  ScaleVector(fvTotalSpecular, LightColor);
  TVectorCoords(Result).XYZ:=Saturate(VectorScale(VectorAdd( VectorScale(VectorAdd( fvTotalAmbient, fvTotalDiffuse ), base), fvTotalSpecular),
    1.0 / (VectorDotProduct(lightdir, lightdir) * lightatt[1] + lightatt[0])));
  Result[3]:=matdiffuse[3];
end;

procedure TMaterialType.ValidateVersion;
var
  p: TMaterialParameters;
begin
//Апгрейдим все параметры, которые загрузились
  inherited;
//Запоминаем их
  p:=FParameters;
//Заводим новый список
  FParameters:=TMaterialParameters.Create(self);
  FParameters.OnMaterialChanged:=ParameterChanged;
//Сбрасываем версию
  FVersion:=0;
//Создаем полный комплект параметров от версии 0
  SetupParametersList;
//Опять апгрейдим
  inherited;
  FParameters.AssignValuesFrom(p, nil, true);
  FParameters.AssignOptionalParameters(p);
  p.Free;
{//В загруженные параметры добавляем отсутствующие
  p.AppendMissing(FParameters, true);
//Удаляем временные параметры
  FParameters.Free;
//Восстанавливаем список
  FParameters:=p;}

//удаляем текстуры-пустышки
  FTextures.RemoveEmptyItems;
end;

{ TDiffuseMaterial }

function TDiffuseMaterial.EvalAmbientColor(mode: integer;
  sp: TSurfacePoint; EvalMode: integer): TVector;
begin
  case mode of
    1: Result:=EvalAmbientColor13(sp, EvalMode);
  else
    Result:=EvalAmbientColor5(sp, EvalMode);
  end;
end;

function TDiffuseMaterial.EvalAmbientColor13(sp: TSurfacePoint; EvalMode: integer): TVector;
const
  AmbientMode = 1;
var
  m: TMatrix;
  ma: TAffineMatrix;
  p, v: TAffineVector;
  app, sc: single;
begin
  p:=sp.WorldPosition(1);
  m:=CreatePlaneBasisZ(PlaneMake(p, sp.Normal));

  app:=AmbientAperture[AmbientMode, 0];
  if AmbientWeights[AmbientMode, 0] <> 0 then
    Result:=VectorScale{Alpha}(sp.ConeRay(p, PAffineVector(@m[2])^, app, EvalMode, AmbientOffsetScale, true), AmbientWeights[AmbientMode, 0])
  else
    Result:=NullHmgVector;

  if AmbientTurn[AmbientMode, 0] <> 0 then
    ma:=AffineMatrixMake(MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 0])))
  else
    ma:=AffineMatrixMake(m);
  app:=AmbientAperture[AmbientMode, 1];
  sc:=AmbientWeights[AmbientMode, 1];
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 0]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundY(ZVector,-AmbientPitch[AmbientMode, 0]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundX(ZVector, AmbientPitch[AmbientMode, 0]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundX(ZVector,-AmbientPitch[AmbientMode, 0]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
  end;

  if AmbientTurn[AmbientMode, 2] <> 0 then
    ma:=AffineMatrixMake(MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 2])))
  else
    ma:=AffineMatrixMake(m);
  app:=AmbientAperture[AmbientMode, 3];
  sc:=AmbientWeights[AmbientMode, 3];
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 2]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundY(ZVector,-AmbientPitch[AmbientMode, 2]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundX(ZVector, AmbientPitch[AmbientMode, 2]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundX(ZVector,-AmbientPitch[AmbientMode, 2]), ma), app, EvalMode, AmbientOffsetScale, true), sc));
  end;
  
  if AmbientTurn[AmbientMode, 1] <> 0 then
    ma:=AffineMatrixMake(MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 1])))
  else
    ma:=AffineMatrixMake(m);
  app:=AmbientAperture[AmbientMode, 2];
  sc:=AmbientWeights[AmbientMode, 2];
  v:=VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 1]);
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 0.25), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 0.75), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 1.25), ma), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 1.75), ma), app, EvalMode, AmbientOffsetScale, true), sc));
  end;
  
//  ScaleVector(TVectorCoords(Result).XYZ, FAmbient.Value);
//  ScaleVector(TVectorCoords(Result).XYZ, LightKs[0]);
end;

function TDiffuseMaterial.EvalAmbientColor5(sp: TSurfacePoint; EvalMode: integer): TVector;
const
  AmbientMode = 0;
var
  m: TMatrix;
  app, sc: single;
  p: TAffineVector;
  m1: TAffineMatrix;
begin
  p:=sp.WorldPosition(1);
  m:=CreatePlaneBasisZ(PlaneMake(p, sp.Normal));
  if AmbientTurn[AmbientMode, 1] <> 0 then
    m:=MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 1]));
  m1:=AffineMatrixMake(m);
  if AmbientWeights[AmbientMode, 0] <> 0 then
    Result:=VectorScale{Alpha}(sp.ConeRay(p, m1[2], AmbientAperture[AmbientMode, 0], EvalMode, AmbientOffsetScale, true), AmbientWeights[AmbientMode, 0])
  else
    Result:=NullHmgVector;
  app:=AmbientAperture[AmbientMode, 2];
  sc:=AmbientWeights[AmbientMode, 2];
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 1]), m1), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundY(ZVector,-AmbientPitch[AmbientMode, 1]), m1), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundX(ZVector, AmbientPitch[AmbientMode, 1]), m1), app, EvalMode, AmbientOffsetScale, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, VectorTransform(VectorRotateAroundX(ZVector,-AmbientPitch[AmbientMode, 1]), m1), app, EvalMode, AmbientOffsetScale, true), sc));
  end;
//  ScaleVector(TVectorCoords(Result).XYZ, FAmbient.Value);
//  ScaleVector(TVectorCoords(Result).XYZ, LightKs[0]);
end;

function TDiffuseMaterial.EvalAmbientColor5f(sp: TSurfacePoint; EvalMode: integer): TVector;
const
  AmbientMode = 0;
var
  m: TMatrix;
  p, v: TAffineVector;
begin
  p:=sp.WorldPosition(1);
  m:=CreatePlaneBasisZ(PlaneMake(p, sp.Normal));
  if AmbientWeights[AmbientMode, 0] <> 0 then
    Result:=VectorScale{Alpha}(sp.ConeRay(p, TVectorCoords(m[2]).XYZ, AmbientAperture[AmbientMode, 0], EvalMode, AmbientOffsetScale, true), AmbientWeights[AmbientMode, 0])
  else
    Result:=NullHmgVector;
  if AmbientWeights[AmbientMode, 2] <> 0 then
  begin
    v:=VectorNormalize(VectorAdd(TVectorCoords(m[2]).XYZ, TVectorCoords(m[0]).XYZ));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, v, AmbientAperture[AmbientMode, 2], EvalMode, AmbientOffsetScale, true), AmbientWeights[AmbientMode, 2]));

    v:=VectorNormalize(VectorSubtract(TVectorCoords(m[2]).XYZ, TVectorCoords(m[0]).XYZ));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, v, AmbientAperture[AmbientMode, 2], EvalMode, AmbientOffsetScale, true), AmbientWeights[AmbientMode, 2]));

    v:=VectorNormalize(VectorAdd(TVectorCoords(m[2]).XYZ, TVectorCoords(m[1]).XYZ));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, v, AmbientAperture[AmbientMode, 2], EvalMode, AmbientOffsetScale, true), AmbientWeights[AmbientMode, 2]));

    v:=VectorNormalize(VectorSubtract(TVectorCoords(m[2]).XYZ, TVectorCoords(m[1]).XYZ));
    AddVector(Result, VectorScale{Alpha}(sp.ConeRay(p, v, AmbientAperture[AmbientMode, 2], EvalMode, AmbientOffsetScale, true), AmbientWeights[AmbientMode, 2]));
  end;
//  ScaleVector(TVectorCoords(Result).XYZ, FAmbient.Value);
//  ScaleVector(TVectorCoords(Result).XYZ, LightKs[0]);
end;

function TDiffuseMaterial.EvalDirectLights(sp: TSurfacePoint; EvalMode: integer): TVector;
var
  i, n: integer;
  p, d, lc: TAffineVector;
  z, sc, dist, nl: single;
begin
  Result:=NullHmgVector;
  n:=sp.DirectLightsCount;
  if n > 0 then
  begin
    sc:=1.0;//1 / n;
    p:=sp.WorldPosition(2);
    for i:=0 to n - 1 do
    begin
      d:=sp.GetLightDirection(i);
      nl:=VectorDotProduct(sp.Normal, d);
      if nl > 0 then
      begin
        dist:=sp.DistanceToLight(i) + 1;
        z:=nl / (dist * dist) * (0.05 + 0.95 * sp.GetShadow(i));
        lc:=sp.GetLightColor(i, EvalMode);
        AddVector(TVectorCoords(Result).XYZ, VectorScale(lc, sc * z));
//        AddVector(TVectorCoords(Result).XYZ, VectorScale(sp.MixedRay(p, d, sp.GetLightVisibleAngle(i), 3, sp.ViewResolution, sp.IsOrthogonalView,  sp.Simple, EvalMode, sp.RecurseCount, 1, 2, 1), sc * z));
//        AddVector(TVectorCoords(Result).XYZ, VectorScale{Alpha}(sp.ConeRay(p, d, sp.GetLightVisibleAngle(i), EvalMode), sc * z));
//        AddVector(TVectorCoords(Result).XYZ, VectorScale{Alpha}(sp.ConeRay(VectorAdd(p, VectorScale(d, dist - 1 - 0.1)), VectorNegate(d), 0.01, EvalMode), sc * z));
      end;
    end;
  end;
//  ScaleVector(TVectorCoords(Result).XYZ, FDiffuse.Value);
//  ScaleVector(TVectorCoords(Result).XYZ, LightKs[1]);
end;

function TDiffuseMaterial.EvalDirectLightsCRM(sp: TSurfacePoint;
  EvalMode: integer): TVector;
var
  i, n: integer;
  sc, dist, sh: single;
begin
  Result:=NullHmgVector;
  n:=sp.DirectLightsCount;
  if n > 0 then
  begin
    sc:=1.0;//1 / n;
    for i:=0 to n - 1 do
    begin
      if EvalMode = memDefault then
        dist:=1.0
      else
      begin
        dist:=sp.DistanceToLight(i) + 1;
        dist:=1.0 / (dist * dist);
      end;
      sh:=(0.3 + 0.7 * sp.GetShadow(i));
      AddVector(TVectorCoords(Result).XYZ, VectorScale(CookTorrance(
        {VectorScale(}sp.Albedo{, FAlbedo.Value)}, FRoughness.Value, FBlur.Value, sp.Normal,
        sp.GetLightDirection(i), sp.NegView, XVector,
        VectorScale(FOldAmbient.Value, LightKs[0]), VectorMake(VectorScale(FOldDiffuse.Value, LightKs[1]), FOldOpacity.Value), VectorScale(FOldSpecular.Value, LightKs[2]),
        FOldLevels.Value, sp.GetLightColor(i, EvalMode), sh * dist, sh * dist, dist), sc));
    end;
  end;
  Result[3]:=FOldOpacity.Value;
end;

function TDiffuseMaterial.EvalHiReflections(aPoint: TSurfacePoint;
  EvalMode: integer): TVector;
var
  sp: TSurfacePoint;
begin
{  Result:=EvalSpecularColor(aPoint, EvalMode);
  exit;}
  if (aPoint.RecurseCount < NumOfSubrays) then
    if aPoint.KdRay(aPoint.WorldPosition, aPoint.Reflection(aPoint.Normal), 1, aPoint.ViewResolution, aPoint.IsOrthogonalView, sp) then
    begin
      sp.RecurseCount:=aPoint.RecurseCount + 1;
      sp.Simple:=sp.Simple or ((FFlags.FValue and matFlagReflective) = 0);
      sp.Material.EvalMaterialAt(sp, EvalMode);
      Result:=sp.ResultColor;
  //    ScaleVector(TVectorCoords(Result).XYZ, fresnel(VectorDotProduct(aPoint.Reflection(aPoint.Normal), aPoint.Normal), FRefractionIndex.Value));
      sp.Free;
    end
    else
      Result:=NullHmgVector
  else
    Result:=aPoint.ConeRay(aPoint.WorldPosition, aPoint.Reflection(aPoint.Normal), 0.001, EvalMode);
end;

function TDiffuseMaterial.EvalHiRefractions(aPoint: TSurfacePoint;
  EvalMode: integer): TVector;
var
  sp: TSurfacePoint;
  ref: TAffineVector;
begin
  if (aPoint.RecurseCount < NumOfSubrays) then
  begin
    if aPoint.Simple then
      ref:=aPoint.View
    else
      ref:=aPoint.Refraction(aPoint.Normal, FRefractionIndex.Value);
    if aPoint.KdRay(VectorAdd(aPoint.WorldPosition, VectorScale(ref, 1e-3)), ref, 3, aPoint.ViewResolution, aPoint.IsOrthogonalView, sp) then
    begin
      sp.RecurseCount:=aPoint.RecurseCount + 1;
      sp.Simple:=sp.Simple or ((FFlags.FValue and matFlagRefractive) = 0);
      sp.Material.EvalMaterialAt(sp, EvalMode);
      Result:=sp.ResultColor;
  //    ScaleVector(TVectorCoords(Result).XYZ, fresnel(VectorDotProduct(aPoint.Reflection(aPoint.Normal), aPoint.Normal), FRefractionIndex.Value));
      sp.Free;
    end
    else
      Result:=NullHmgVector;
  end
  else
  if (aPoint.BackFace) and (not aPoint.Simple) then
    Result:=aPoint.ConeRay(aPoint.WorldPosition, aPoint.Refraction(aPoint.Normal, FRefractionIndex.Value), 0.001, EvalMode)
  else
    Result:=aPoint.ConeRay(aPoint.WorldPosition, aPoint.View, 0.001, EvalMode);
end;

function IntToVec4(v: Integer): TVector;
const
  s = 1.0 / 255.0;
begin
  Result[0]:=(v and $FF) * s;
  Result[1]:=((v and $FF00) shr 8) * s;
  Result[2]:=((v and $FF0000) shr 16) * s;
  Result[3]:=((v and $FF000000) shr 24) * s;
end;

procedure TDiffuseMaterial.EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);
var
  n: integer;
  d, a, skd, rkd: TVector;
  al: TAffineVector;
  lp: ILayeredSurfacePoint;
  f2: single;
begin
  case EvalMode of
    memInit:
    begin
      TVectorCoords(aPoint.ResultColor).XYZ:=NullVector;
      aPoint.ResultColor[3]:=FOpacity.Value;
    end;
    memLight:
    begin
      aPoint.ResultColor:=EvalDirectLightsCRM(aPoint, EvalMode);
//      aPoint.ResultColor[3]:=FOpacity.Value;
//      ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, FDiffuse.Value);
//      ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, FAlbedo.Value);
//      ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, aPoint.Albedo);
//      AddVector(TVectorCoords(aPoint.ResultColor).XYZ, TVectorCoords(EvalSpecularColor(aPoint, EvalMode)).XYZ);
      if FEmissionLevel.FValue > 0 then
        AddVector(TVectorCoords(aPoint.ResultColor).XYZ, VectorScale(FEmission.FValue, FEmissionLevel.FValue));
      ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, aPoint.ResultColor[3] {* FDiffuseLevel.Value});
    end;
    memNext, memFinal:
    begin
{      aPoint.ResultColor:=IntToVec4(aPoint.TriAttribute(tdObjectID));
      exit;}
      if (aPoint.RecurseCount > 0) and aPoint.Simple then
      begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Eval ceramic lighting for %s. Recurse=%d', [Name, aPoint.RecurseCount]));{$ENDIF}
        d:=EvalDirectLightsCRM(aPoint, memLight);
        ScaleVector(TVectorCoords(d).XYZ, d[3]);
        if (EvalMode = memFinal) and (d[3] < 1.0) then
          rkd:=EvalMixRefractions(aPoint, EvalMode)
        else
          rkd:=NullHmgVector;
        ScaleVector(rkd, 1.0 - d[3]);
        AddVector(d, rkd);
        aPoint.ResultColor:=d;
        a:=NullHmgVector;
        skd:=NullHmgVector;
        rkd:=NullHmgVector;
      end
      else
      begin
{$IFNDEF RELEASE}
        if GetKeyState(VK_SHIFT) < 0 then
        begin
          aPoint.ResultColor:=VectorMake(aPoint.Albedo, 1.0);
          exit;
        end;
{$ENDIF}
        f2:=Fresnel(VectorDotProduct(aPoint.NegView, aPoint.Normal), FRefractionIndex.Value);

        if FDiffuseLevel.Value > 0 then
        begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Eval diffuse component for %s', [Name]));{$ENDIF}
          d:=EvalDirectLights(aPoint, EvalMode);
          ScaleVector(TVectorCoords(d).XYZ, FDiffuse.Value);
          ScaleVector(TVectorCoords(d).XYZ, FDiffuseLevel.Value * FOpacity.FValue);
        end
        else
          d:=NullHmgVector;

        if FAmbientLevel.Value > 0 then
        begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Eval ambient component for %s', [Name]));{$ENDIF}
          if ForceUseMixedRay then
            if (FFlags.FValue and matFlagFastAmbient) <> 0 then
              a:=EvalAmbientColor5Mixed(aPoint, EvalMode)
            else
              a:=EvalAmbientColor13Mixed(aPoint, EvalMode)
          else
            if (FFlags.FValue and matFlagFastAmbient) <> 0 then
              a:=EvalAmbientColor5(aPoint, EvalMode)
            else
              a:=EvalAmbientColor13(aPoint, EvalMode);
          ScaleVector(TVectorCoords(a).XYZ, FAmbient.Value);
          ScaleVector(TVectorCoords(a).XYZ, FAmbientLevel.Value * FOpacity.FValue);
        end
        else
          a:=NullHmgVector;

        if FSpecularLevel.Value > 0 then
        begin
          if (EvalMode = memFinal) {and (aPoint.ResultColor[3] < 0.999)} {$IFNDEF MIXED_RAYS_ENABLED}and (FSpecularKd.FValue > 0.0){$ENDIF} then
            skd:={$IFDEF MIXED_RAYS_ENABLED}EvalMixReflections{$ELSE}EvalHiReflections{$ENDIF}(aPoint, EvalMode)
          else
            skd:=NullHmgVector;

          {$IFNDEF MIXED_RAYS_ENABLED}
          if (EvalMode = memFinal) and (FSpecularKd.FValue < 1.0) then
            VectorCombine(TVectorCoords(EvalSpecularColor(aPoint, EvalMode)).XYZ, TVectorCoords(skd).XYZ,
              1.0 - FSpecularKd.FValue, FSpecularKd.FValue, TVectorCoords(skd).XYZ);
          {$ENDIF}

          ScaleVector(TVectorCoordS(skd).XYZ, FSpecular.Value);
          ScaleVector(TVectorCoordS(skd).XYZ, FSpecularLevel.Value * (FOpacity.FValue * Fresnel(VectorDotProduct(aPoint.Reflection(aPoint.Normal), aPoint.Normal), FSpecularFresnel.Value) + (1.0 - FOpacity.FValue) * f2));
        end
        else
          skd:=NullHmgVector;

        if (FRefractionLevel.Value > 0) and (FOpacity.Value < 1.0) then
        begin
          if (EvalMode = memFinal) {and (aPoint.ResultColor[3] < 0.999)} {$IFNDEF MIXED_RAYS_ENABLED}and (FRefractionKd.Value > 0.0){$ENDIF} then
            rkd:={$IFDEF MIXED_RAYS_ENABLED}EvalMixRefractions{$ELSE}EvalHiRefractions{$ENDIF}(aPoint, EvalMode)
          else
            rkd:=NullHmgVector;

          {$IFNDEF MIXED_RAYS_ENABLED}
          if (EvalMode = memFinal) and (FRefractionKd.Value < 1.0) then
            VectorCombine(TVectorCoords(EvalRefractionColor(aPoint, EvalMode)).XYZ, TVectorCoords(rkd).XYZ,
              1.0 - FRefractionKd.FValue, FRefractionKd.FValue, TVectorCoords(rkd).XYZ);
          {$ENDIF}

          ScaleVector(TVectorCoordS(rkd).XYZ, FRefraction.Value);
          ScaleVector(TVectorCoordS(rkd).XYZ, FRefractionLevel.Value * (1.0 - FOpacity.FValue) * (1.0 - f2));
        end
        else
          rkd:=NullHmgVector;

        TVectorCoords(aPoint.ResultColor).XYZ:=TVectorCoords(d).XYZ;
        AddVector(TVectorCoords(aPoint.ResultColor).XYZ, TVectorCoords(a).XYZ);

        al:=VectorScale(FAlbedo.Value, aPoint.Albedo);
        ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, al);
        ScaleVector(al, FAlbedoLevel.FValue);
        AddVector(TVectorCoords(aPoint.ResultColor).XYZ, al);

{        ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, FAlbedo.Value);
        ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, aPoint.Albedo);}

        AddVector(TVectorCoords(aPoint.ResultColor).XYZ, TVectorCoords(skd).XYZ);
        AddVector(TVectorCoords(aPoint.ResultColor).XYZ, TVectorCoords(rkd).XYZ);
        aPoint.ResultColor[3]:=FOpacity.Value * (1.0 - rkd[3]) + rkd[3];
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Combining components for %s. Total opacity = %.3f. Backface = %d', [Name, aPoint.ResultColor[3], Integer(aPoint.Backface)]));{$ENDIF}
      end;
      if FEmissionLevel.FValue > 0 then
        AddVector(TVectorCoords(aPoint.ResultColor).XYZ, VectorScale(FEmission.FValue, FEmissionLevel.FValue * FOpacity.FValue));
      if (EvalMode = memFinal) and aPoint.GetInterface(ILayeredSurfacePoint, lp) then
      begin
        lp.Vectors[0]:=d;
        lp.Vectors[1]:=a;
        lp.Vectors[2]:=skd;
        lp.Vectors[3]:=rkd;
        lp.Integers[0]:=Integer(self);
        lp:=nil;
      end;
    end;
    memDebug:
    begin
      aPoint.ResultColor:=EvalDirectLights(aPoint, EvalMode);
      AddVector(aPoint.ResultColor, EvalAmbientColor13(aPoint, EvalMode));
      ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, FAlbedo.Value);
      ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, aPoint.Albedo);
      aPoint.ResultColor[3]:=FOpacity.Value;
    end;
  else
{    aPoint.ResultColor[0]:=-VectorDotProduct(aPoint.Normal, VectorNormalize(aPoint.WorldPosition));
    aPoint.ResultColor:=VectorMake(aPoint.ResultColor[0], aPoint.ResultColor[0], aPoint.ResultColor[0], 1);
    exit;}
    n:=aPoint.DirectLightsCount;
    if n > 0 then
    begin
      aPoint.ResultColor:=EvalDirectLightsCRM(aPoint, EvalMode);
      ScaleVector(TVectorCoords(aPoint.ResultColor).XYZ, aPoint.ResultColor[3] / n);
{      for i:=0 to n - 1 do
      begin
        d:=CookTorrance( VectorScale(aPoint.Albedo, FAlbedo.Value), FRoughness.Value, FBlur.Value, aPoint.Normal,
          aPoint.GetLightDirection(i), aPoint.NegView, XVector,
          FAmbient.Value, VectorMake(FDiffuse.Value, FOpacity.Value), FSpecular.Value,
          AffineVectorMake(FOldAmbientLevel.Value, FDiffuseLevel.Value, FSpecularLevel.Value),
          Saturate(aPoint.GetLightColor(i)), aPoint.GetShadow(i) );
        AddVector(aPoint.ResultColor, d);
      end;
      if n > 1 then
        ScaleVector(aPoint.ResultColor, 1 / n);}
      if (FSpecularLevel.FValue > 0) and (FSpecularBlur.FValue = 0){(aPoint.ResultColor[3] < 0.999)} and (aPoint.RecurseCount < NumOfSubrays) then
        VectorCombine(aPoint.ResultColor, EvalHiReflections(aPoint, EvalMode),
          0.5, 0.5, aPoint.ResultColor);
      if (FRefractionLevel.FValue > 0) and (aPoint.ResultColor[3] < 0.999) and (aPoint.RecurseCount < NumOfSubrays) then
        VectorCombine(aPoint.ResultColor, EvalHiRefractions(aPoint, EvalMode),
          1.0, 1.0 - aPoint.ResultColor[3], aPoint.ResultColor);
    end;
  end;
  exit;
  FParameters.Dump;
  FParameters.DumpToClipboard;
end;

function TDiffuseMaterial.EvalMixReflections(aPoint: TSurfacePoint;
  EvalMode: integer): TVector;
begin
  if (aPoint.RecurseCount < NumOfSubrays) then
  begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Eval reflections for %s. Recurse %d < %d', [Name, aPoint.RecurseCount, NumOfSubrays]));{$ENDIF}
    Result:=aPoint.MixedRay(aPoint.WorldPosition, aPoint.Reflection(aPoint.Normal), FSpecularBlur.Value,
      1, aPoint.ViewResolution, aPoint.IsOrthogonalView, (FFlags.FValue and matFlagReflective) = 0, EvalMode, aPoint.RecurseCount,
      FSpecularMixStart.FValue, FSpecularMixEnd.FValue, FSpecularKdPower.FValue)
  end
  else
  begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Reflection eval as cone for %s. %d >= %d', [Name, aPoint.RecurseCount, NumOfSubrays]));{$ENDIF}
    Result:=aPoint.ConeRay(aPoint.WorldPosition, aPoint.Reflection(aPoint.Normal), Max(0.001, FSpecularBlur.Value), EvalMode);
  end;
end;

function TDiffuseMaterial.EvalMixRefractions(aPoint: TSurfacePoint;
  EvalMode: integer): TVector;
var
  ref: TAffineVector;
begin
  if (aPoint.RecurseCount < NumOfSubrays) then
  begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Eval refraction for %s. Recurse count %d < %d. Backface = %d', [Name, aPoint.RecurseCount, NumOfSubrays, Integer(aPoint.BackFace)]));{$ENDIF}
    if aPoint.Simple then
      ref:=aPoint.View
    else
      ref:=aPoint.Refraction(aPoint.Normal, FRefractionIndex.Value);
    Result:=aPoint.MixedRay(VectorAdd(aPoint.WorldPosition, VectorScale(ref, 1e-3)), ref, FRefractionBlur.Value,
      3, aPoint.ViewResolution, aPoint.IsOrthogonalView, FFlags.FValue and matFlagRefractive = 0, EvalMode, aPoint.RecurseCount,
      FRefractionMixStart.FValue, FRefractionMixEnd.FValue, FRefractionKdPower.FValue);
{    if aPoint.KdRay(VectorAdd(aPoint.WorldPosition, VectorScale(ref, 1e-3)), ref, 3, aPoint.ViewResolution, aPoint.IsOrthogonalView, sp) then
    begin
      sp.RecurseCount:=aPoint.RecurseCount + 1;
      sp.Material.EvalMaterialAt(sp, EvalMode);
      Result:=sp.ResultColor;
  //    ScaleVector(TVectorCoords(Result).XYZ, fresnel(VectorDotProduct(aPoint.Reflection(aPoint.Normal), aPoint.Normal), FRefractionIndex.Value));
      sp.Free;
    end
    else
      Result:=NullHmgVector;}
  end
  else
  if (aPoint.BackFace) and (not aPoint.Simple) then
  begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Eval backface refraction as cone for %s. Recurse count %d >= %d', [Name, aPoint.RecurseCount, NumOfSubrays]));{$ENDIF}
    Result:=aPoint.ConeRay(aPoint.WorldPosition, aPoint.Refraction(aPoint.Normal, FRefractionIndex.Value), Max(0.001, FRefractionBlur.Value), EvalMode);
  end
  else
  begin
{$IFDEF LOG_MATERIAL}if aPoint.Log <> nil then aPoint.Log.Write(Format('Eval refraction as cone for %s. Recurse count %d >= %d. Backface=%d', [Name, aPoint.RecurseCount, NumOfSubrays, Integer(aPoint.BackFace)]));{$ENDIF}
    Result:=aPoint.ConeRay(aPoint.WorldPosition, aPoint.View, Max(0.001, FRefractionBlur.Value), EvalMode);
  end
end;

function TDiffuseMaterial.EvalRefractionColor(sp: TSurfacePoint;
  EvalMode: integer): TVector;
begin
  Result:=sp.ConeRay(sp.WorldPosition, sp.View, 0.001 + FRefractionBlur.Value, EvalMode);
end;

function TDiffuseMaterial.EvalSpecularColor(sp: TSurfacePoint; EvalMode: integer): TVector;
begin
  Result:=sp.ConeRay(sp.WorldPosition, sp.Reflection(sp.Normal), 0.001 + FSpecularBlur.Value, EvalMode, SpecularOffset);
end;

function TDiffuseMaterial.GetShaderEvaluationCase: string;
begin
  Result:='case ' + IntToStr(FType) + ': ' +
  '$RESULT.xyz = CookTorrens( 1.0, ' +
  'float2(' + Parameters.ShaderValue['roughness'] + ', ' + Parameters.ShaderValue['blur'] + '), n, light, view, float3(1, 0, 0), ' +
  Parameters.ShaderValue['ambient'] + ', ' +
  Parameters.ShaderValue['diffuse'] + '.xyz, ' +
  Parameters.ShaderValue['specular'] + ', ' +
  Parameters.ShaderValue['levels'] + '); ' +
  '$RESULT.w = ' + Parameters.ShaderValue['diffuse'] + '.w; ' +
  'break;';
end;

class function TDiffuseMaterial.GetTypeIndex: integer;
begin
  Result:=1;
end;

procedure TDiffuseMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;
  with FParameters.NewColor('Альбедо') do
  begin
    FAlbedo.LinkTo(this);
    FAltName:=tr('Цвет рассеянного');
    FCustomizable:=true;
    Value:=XYZVector;
  end;

  with FParameters.NewFloat('Уровень альбедо') do
  begin
    FAlbedoLevel.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Уровень рассеянного');
    Value:=0;
  end;

  with Parameters.NewColor('Фон') do
  begin
    FAmbient.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Цвет окружающего');
  end;

  with FParameters.NewFloat('Уровень фона') do
  begin
    FAmbientLevel.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Уровень окружающего');
    Value:=1;
  end;

  FOldLevels.LinkTo(FParameters.NewFloat3('старые уровни'));
//  FOldLevels.FCustomizable:=true;
  FOldAmbient.LinkTo(FParameters.NewColor('старый фон'));
//  FOldAmbient.FCustomizable:=true;
  FOldDiffuse.LinkTo(FParameters.NewColor('старый рассеянный'));
//  FOldDiffuse.FCustomizable:=true;
  FOldSpecular.LinkTo(FParameters.NewColor('старый отраженный'));
//  FOldSpecular.FCustomizable:=true;

  with Parameters.NewColor('Рассеянный') do
  begin
    FDiffuse.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Цвет прямого');
  end;

  with FParameters.NewFloat('Уровень рассеянного') do
  begin
    FDiffuseLevel.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Уровень прямого');
    Value:=1;
  end;

  with Parameters.NewColor('Отраженный') do
  begin
    FSpecular.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Цвет отраженного');
  end;

  with FParameters.NewFloat('Уровень отраженного') do
  begin
    FSpecularLevel.LinkTo(this);
    FCustomizable:=true;
    Value:=1;
  end;

  with FParameters.NewFloatWithConverter('Начало отраженного смешивания') do
  begin
    FSpecularMixStart.LinkTo(this);
  //  FCustomizable:=true;
    Value:=SpecularMixStart;
    OnNeedConvertedValue:=RWConvertedValue;
  end;

  with FParameters.NewFloatWithConverter('Конец отраженного смешивания') do
  begin
    FSpecularMixEnd.LinkTo(this);
//  FCustomizable:=true;
    Value:=SpecularMixEnd;
    OnNeedConvertedValue:=RWConvertedValue;
  end;

  with FParameters.NewFloat('Уровень отраженного Kd') do
  begin
    FSpecularKdPower.LinkTo(this);
//    FCustomizable:=true;
    Value:=1;
  end;

  with FParameters.NewVoxelAngle('Размытие отражений') do
  begin
    FSpecularBlur.LinkTo(this);
    FCustomizable:=true;
    Value:=0.1;
  end;

  with FParameters.NewFloat('Коэффициент френеля для отражений') do
  begin
    FSpecularFresnel.LinkTo(this);
    FCustomizable:=true;
    Value:=1.01;
  end;

  with Parameters.NewFlags('Флаги отражений') do
  begin
    FReflectionFlags.LinkTo(this);
    FCustomizable:=true;
    SetFlagsNames(langRussian, ['Отражающий', 'Сглаживать отражения']);
    SetFlagsNames(langEnglish, ['Reflective', 'Smooth reflections']);
    SetFlagsVisibility([true, true]);
    SetFlagsBits([3, 1]);
  end;

  with FParameters.NewFloat('Непрозрачность') do
  begin
    FOpacity.LinkTo(this);
    FCustomizable:=true;
    Value:=1;
  end;

  with Parameters.NewColor('Преломленный') do
  begin
    FRefraction.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Цвет преломленного');
  end;
  
  with FParameters.NewFloat('Уровень преломленного') do
  begin
    FRefractionLevel.LinkTo(This);
    FCustomizable:=true;
    FAltName:=tr('Уровень преломленного');
    Value:=0;
  end;

  with FParameters.NewFloatWithConverter('Начало преломленного смешивания') do
  begin
    FRefractionMixStart.LinkTo(this);
  //  FCustomizable:=true;
    Value:=RefractionMixStart;
    OnNeedConvertedValue:=RWConvertedValue;
  end;

  with FParameters.NewFloatWithConverter('Конец преломленного смешивания') do
  begin
    FRefractionMixEnd.LinkTo(this);
  //  FCustomizable:=true;
    Value:=RefractionMixEnd;
    OnNeedConvertedValue:=RWConvertedValue;
  end;

  with FParameters.NewFloat('Уровень преломленного Kd') do
  begin
    FRefractionKdPower.LinkTo(this);
  //  FCustomizable:=true;
    Value:=1;
  end;
  
  with FParameters.NewVoxelAngle('Размытие преломлений') do
  begin
    FRefractionBlur.LinkTo(this);
    FCustomizable:=true;
    Value:=0.1;
  end;

  with FParameters.NewFloat('Коэффициент преломления') do
  begin
    FRefractionIndex.LinkTo(this);
    FCustomizable:=true;
    Value:=1;
  end;

  with Parameters.NewFlags('Флаги преломлений') do
  begin
    FRefractionFlags.LinkTo(this);
    FCustomizable:=true;
    SetFlagsNames(langRussian, ['Преломляющий', 'Сглаживать преломления']);
    SetFlagsNames(langEnglish, ['Refractive', 'Smooth refractions']);
    SetFlagsVisibility([true, true]);
    SetFlagsBits([4, 2]);
  end;

  with FParameters.NewFloat('Старая непрозрачность') do
  begin
    FOldOpacity.LinkTo(this);
  //  FCustomizable:=true;
    Value:=1;
    Updatable:=true;
  end;

  with Parameters.NewColor('Самосвечение') do
  begin
    FEmission.LinkTo(this);
    FCustomizable:=true;
    FAltName:=tr('Цвет самосвечения');
  end;
  
  with FParameters.NewFloat('Уровень самосвечения') do
  begin
    FEmissionLevel.LinkTo(this);
    FCustomizable:=true;
  end;

//['Быстрый фон', 'Сглаживать отражения', 'Сглаживать преломления', 'Отражающий', 'Преломляющий', 'Источник света']

  with Parameters.NewFlags('Прочие флаги') do
  begin
    FFlags.LinkTo(this);
    FCustomizable:=true;
    SetFlagsNames(langRussian, ['Быстрый фон', 'Источник света', 'Скрытый']);
    SetFlagsNames(langEnglish, ['Fast background', 'Light source', 'Hidden']);
    SetFlagsVisibility([false, true, false]);
    SetFlagsBits([0, 5, 6]);
  end;

  with Parameters.NewFloat('Затухание') do
  begin
    FEmissionAtt.LinkTo(this);
    FCustomizable:=true;
    FAltName := tr('Затухание');
  end;

  with FParameters.NewFloat('Roughness') do
  begin
    FRoughness.LinkTo(this);
  //  FCustomizable:=true;
    FAltName:=tr('Жесткость блика');
  end;

  with FParameters.NewFloat('Blur') do
  begin
    FBlur.LinkTo(this);
  //  FCustomizable:=true;
    FAltName:=tr('Размер блика');
  end;

  with Parameters.NewFloat('Tentacle') do
  begin
    FTentacle.LinkTo(this);
    FCustomizable:=true;
  end;

  with Parameters.NewFloat('filmIor') do
    FCustomizable:=true;

  with Parameters.NewFloat('filmMinThickness') do
    FCustomizable:=true;

  with Parameters.NewFloat('filmMaxThickness') do
    FCustomizable:=true;

  Parameters.EndUpdate;
end;

function TDiffuseMaterial.GetDebugInfo(aPoint: TSurfacePoint): ISurfacePointDebugInfo;
begin
  Result:=aPoint.GetDebugInfo(FSpecularBlur.FValue);
  DebugTrace(aPoint, Result);  
end;

function TDiffuseMaterial.QueryAAInfoEx(aPoint: TSurfacePoint): Cardinal;
var
  sp: TSurfacePoint;
  ref: TAffineVector;
function Rol3(Value: Integer): Cardinal; asm rol eax,3 end;
begin
  Result:=0;
  if (aPoint<>nil)and(aPoint.RecurseCount < NumOfSubrays) then begin
    //правая ветка
    if (FFlags.FValue and (matFlagReflectionsAA or matFlagReflective))=(matFlagReflectionsAA or matFlagReflective) then begin
      if aPoint.KdRay(aPoint.WorldPosition, aPoint.Reflection(GetNormal(aPoint)), 1, aPoint.ViewResolution, aPoint.IsOrthogonalView, sp)
      then begin
        sp.RecurseCount:=aPoint.RecurseCount + 1;
        Result:=Cardinal(sp.TriAttribute(tdObjectID)) + Cardinal(sp.Material);
        Result:=Result + Rol3(sp.Material.QueryAAInfoEx(sp));
        sp.Free;
      end;
    end;
    //левая ветка
    if (FFlags.FValue and (matFlagRefractionsAA or matFlagRefractive))=(matFlagRefractionsAA or matFlagRefractive) then begin
      ref:=aPoint.Refraction(GetNormal(aPoint), FRefractionIndex.FValue);
      if aPoint.KdRay(VectorAdd(aPoint.WorldPosition, VectorScale(ref, 0.001)), ref, 3,
        aPoint.ViewResolution, aPoint.IsOrthogonalView, sp)
      then begin
        sp.RecurseCount:=aPoint.RecurseCount + 1;
        Result:=Result + Cardinal(sp.TriAttribute(tdObjectID)) + Cardinal(sp.Material);
        Result:=Result + Rol3(sp.Material.QueryAAInfoEx(sp));
        sp.Free;
      end;
    end;
  end;
end;

procedure TDiffuseMaterial.RWConvertedValue(Sender: TObject; Read: boolean;
  var v: single);
  procedure SetValue(p: TFloatMaterialParameter; aperture: single);
  begin
    if Read then
      if aperture <> 0 then
        v:=p.Value * aperture
      else
        v:=p.Value
    else
      p.Value:=v / aperture;
  end;
begin
  if Sender = FSpecularMixStart then
    SetValue(FSpecularMixStart, FSpecularBlur.Value)
  else
  if Sender = FSpecularMixEnd then
    SetValue(FSpecularMixEnd, FSpecularBlur.Value)
  else
  if Sender = FRefractionMixStart then
    SetValue(FRefractionMixStart, FRefractionBlur.Value)
  else
  if Sender = FRefractionMixEnd then
    SetValue(FRefractionMixEnd, FRefractionBlur.Value);
end;

function TDiffuseMaterial.IsTransparent: boolean;
var
  f: Integer;
begin
  f:=0;
  FFlags.StoreValue(f);
  Result:=(FOpacity.FValue < 1.0) or ((f and matFlagHidden) <> 0);
end;

function TDiffuseMaterial.EvalAmbientColor13Mixed(sp: TSurfacePoint;
  EvalMode: integer): TVector;
const
  AmbientMode = 1;
var
  m: TMatrix;
  ma: TAffineMatrix;
  p, v: TAffineVector;
  app, sc: single;
begin

  p:=sp.WorldPosition(1);
  m:=CreatePlaneBasisZ(PlaneMake(p, sp.Normal));

  app:=AmbientAperture[AmbientMode, 0];
  if AmbientWeights[AmbientMode, 0] <> 0 then
    Result:=VectorScale{Alpha}(sp.MixedRay(p, PAffineVector(@m[2])^, app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0,
      true), AmbientWeights[AmbientMode, 0])
  else
    Result:=NullHmgVector;

  if AmbientTurn[AmbientMode, 0] <> 0 then
    ma:=AffineMatrixMake(MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 0])))
  else
    ma:=AffineMatrixMake(m);
  app:=AmbientAperture[AmbientMode, 1];
  sc:=AmbientWeights[AmbientMode, 1];
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 0]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundY(ZVector,-AmbientPitch[AmbientMode, 0]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundX(ZVector, AmbientPitch[AmbientMode, 0]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0,true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundX(ZVector,-AmbientPitch[AmbientMode, 0]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0,true), sc));
  end;

  if AmbientTurn[AmbientMode, 2] <> 0 then
    ma:=AffineMatrixMake(MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 2])))
  else
    ma:=AffineMatrixMake(m);
  app:=AmbientAperture[AmbientMode, 3];
  sc:=AmbientWeights[AmbientMode, 3];
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 2]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundY(ZVector,-AmbientPitch[AmbientMode, 2]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundX(ZVector, AmbientPitch[AmbientMode, 2]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundX(ZVector,-AmbientPitch[AmbientMode, 2]), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
  end;
  
  if AmbientTurn[AmbientMode, 1] <> 0 then
    ma:=AffineMatrixMake(MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 1])))
  else
    ma:=AffineMatrixMake(m);
  app:=AmbientAperture[AmbientMode, 2];
  sc:=AmbientWeights[AmbientMode, 2];
  v:=VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 1]);
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 0.25), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 0.75), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 1.25), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundZ(v, Pi * 1.75), ma), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
  end;
end;

function TDiffuseMaterial.EvalAmbientColor5Mixed(sp: TSurfacePoint;
  EvalMode: integer): TVector;
const
  AmbientMode = 0;
var
  m: TMatrix;
  app, sc: single;
  p: TAffineVector;
  m1: TAffineMatrix;
begin
  p:=sp.WorldPosition(1);
  m:=CreatePlaneBasisZ(PlaneMake(p, sp.Normal));
  if AmbientTurn[AmbientMode, 1] <> 0 then
    m:=MatrixMultiply(m, CreateRotationMatrix(m[2], AmbientTurn[AmbientMode, 1]));
  m1:=AffineMatrixMake(m);
  app:=AmbientAperture[AmbientMode, 0];
  if AmbientWeights[AmbientMode, 0] <> 0 then
    Result:=VectorScale{Alpha}(sp.MixedRay(p, m1[2], app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), AmbientWeights[AmbientMode, 0])
  else
    Result:=NullHmgVector;
  app:=AmbientAperture[AmbientMode, 2];
  sc:=AmbientWeights[AmbientMode, 2];
  if sc <> 0 then
  begin
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundY(ZVector, AmbientPitch[AmbientMode, 1]), m1), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundY(ZVector,-AmbientPitch[AmbientMode, 1]), m1), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundX(ZVector, AmbientPitch[AmbientMode, 1]), m1), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
    AddVector(Result, VectorScale{Alpha}(sp.MixedRay(p, VectorTransform(VectorRotateAroundX(ZVector,-AmbientPitch[AmbientMode, 1]), m1), app, 1, sp.ViewResolution, sp.IsOrthogonalView,
      FFlags.FValue and matFlagReflective = 0, EvalMode, sp.RecurseCount, DefaultMixedRayStart, DefaultMixedRayEnd, 1.0, true), sc));
  end;
end;

function TDiffuseMaterial.IsLightSource: boolean;
var
  f: Integer;
begin
  f:=0;
  FFlags.StoreValue(f);
  Result:=(f and matFlagLightSource) <> 0;
end;

function TDiffuseMaterial.GetEmissive: TAffineVector;
begin
  Result:=VectorScale(FEmission.Value, FEmissionLevel.Value);
end;

class function TDiffuseMaterial.GetShaderEmissive(const m: string): string;
begin
  Result:='(' + m + '.Emission * ' + m + '.EmissionLevel)';
end;

function TDiffuseMaterial.GetAttenuation: Single;
begin
  Result:=FEmissionAtt.Value;
end;

class function TDiffuseMaterial.GetShaderAttenuation(const m: string): string;
begin
  Result:='(' + m + '.LightAttenuation)';
end;

procedure TDiffuseMaterial.DebugTrace(aPoint: TSurfacePoint;
  const debugInfo: ISurfacePointDebugInfo);
const
  face: array[boolean] of integer = (2, 1);
var
  sp: TSurfacePoint;
begin
  inherited;
  debugInfo.AddMessage('First is back = ' + BoolToStr(aPoint.BackFace, true));
  if aPoint.KdRay(aPoint.WorldPosition(), VectorNegate(aPoint.Normal), face[aPoint.BackFace], aPoint.ViewResolution, aPoint.IsOrthogonalView, sp) then
  begin
    debugInfo.AddMessage(Format('Distance %.5f', [VectorDistance(aPoint.WorldPosition, sp.WorldPosition)]));
    debugInfo.AddRay(aPoint.WorldPosition, sp.WorldPosition, XZVector);
  end;
end;

function TDiffuseMaterial.UnknownParameter(const aName, aClass: string; var LoadInfo: TLoadInfo): TObject;
begin
  if aName = 'Флаги материала' then
  begin
    Result:=Parameters.NewFlags(aName);
    LoadInfo.Assigner.AddExecTask(ConvertFlags);
  end
  else
  if MaterialParams.GetTypeByClassname(aClass).InheritsFrom(TMonoMaterialParameter) then
  begin
    Result := Parameters.NewMonoMaterial(aName);
  end
  else
  begin
    Result:=Parameters.NewParameter(aName, MaterialParams.GetTypeByClassname(aClass));
//    Result:=CL_SKIP_OBJECT;
  end;
end;

procedure TDiffuseMaterial.ConvertFlags;
var
  f: TFlagsMaterialParameter;
begin
  if Parameters.FindParameter('Флаги материала', f) and assigned(FReflectionFlags) and assigned(FRefractionFlags) and assigned(FFlags) then
  begin
//['Быстрый фон', 'Сглаживать отражения', 'Сглаживать преломления', 'Отражающий', 'Преломляющий', 'Источник света']

    FReflectionFlags.SetFlag(0, f.GetFlag(3));
    FReflectionFlags.SetFlag(1, f.GetFlag(1));

    FRefractionFlags.SetFlag(0, f.GetFlag(4));
    FRefractionFlags.SetFlag(1, f.GetFlag(2));

    FFlags.SetFlag(0, f.GetFlag(0));
    FFlags.SetFlag(1, f.GetFlag(5));

    Parameters.Remove(f);
  end;
end;

function TDiffuseMaterial.GetEmissionLevel: Single;
begin
  Result:=FEmissionLevel.Value;
end;

procedure TDiffuseMaterial.Upgrade;
var
  i: integer;
  mat: TMaterial;
  reflStruct: TReflStruct;
  p: TFloatMaterialParameter;
  p1: TColorMaterialParameter;
begin
  inherited;
  if FVersion = 0 then
  begin
    Parameters.BeginUpdate;

    {with Parameters.UpgradeTextureParameter('BumpMap', 'bumpMap') do
    begin
      FAltName:='Карта рельефа';
      FCustomizable:=true;
      FCategory:=cBumpCategory;
    end;}
    Parameters.UpgradeTextureParameter('BumpMap', cBumpMap.name).TuneParameter;
    FTextures.RenameValue('bumpmap', cBumpMap.name);

    with Parameters.UpgradeFloatParameter('Уровень альбедо', 'albedoLevel', 0) do
    begin
      FAltName:=tr('Уровень рассеянного');
      FCustomizable:=true;
      FCategory:=cAlbedoCategory;
      FAlbedoLevel.LinkTo(this);
    end;

    with Parameters.UpgradeColorParameter('Альбедо', 'albedoColor', 1, 1, 1) do
    begin
      FAltName:=tr('Цвет рассеянного');
      FCustomizable:=true;
      FCategory:=cAlbedoCategory;
      FAlbedo.LinkTo(this);
    end;

    {with Parameters.UpgradeTextureParameter('BaseMap', 'albedoMap') do
    begin
      FAltName:='Карта цвета';
      FCategory:=cAlbedoCategory;
      FCustomizable:=true;
      TuneParameter;
    end;}
    Parameters.UpgradeTextureParameter('BaseMap', cAlbedoMap.name).TuneParameter;
    FTextures.RenameValue('basemap', cAlbedoMap.name);

{    with Parameters.UpgradeMatrixParameter('TexMatrix', 'texMatrix', @IdentityHmgMatrix) do
    begin
      FAltName:='Текстурная матрица';
      FCategory:=cAlbedoCategory;
      FUpdatable:=true;
      FCustomizable:=true;
    end;}

    // Что-то лень пока назначать карты, без них дофига
    {with newList.NewTexture('albedoLevelMap') do
    begin
      FAltName:='Карта уровня рассеянного';
      FEnabled:=false;
      FCustomizable:=true;
    end;}

    with Parameters.UpgradeFloatParameter('Уровень фона', 'ambientLevel', 1) do
    begin
      FAltName:=tr('Уровень окружающего');
      FCustomizable:=true;
      FCategory:=cAmbientCategory;
      FAmbientLevel.LinkTo(this);
      Value := Value;
    end;

    with Parameters.UpgradeColorParameter('Фон', 'ambientColor') do
    begin
      FAltName:=tr('Цвет окружающего');
      FCustomizable:=true;
      FCategory:=cAmbientCategory;
      FAmbient.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('Уровень рассеянного', 'diffuseLevel', 1) do
    begin
      FAltName:=tr('Уровень прямого');
      FCustomizable:=true;
      FCategory:=cDiffuseCategory;
      FDiffuseLevel.LinkTo(this);
      Value := Value;
    end;

    with Parameters.UpgradeColorParameter('Рассеянный', 'diffuseColor') do
    begin
      FAltName:=tr('Цвет прямого');
      FCustomizable:=true;
      FCategory:=cDiffuseCategory;
      FDiffuse.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('', 'diffuseRoughness', 0.0) do
    begin
      FAltName:=tr('Шероховатость прямого');
      FCustomizable:=true;
      FCategory:=cDiffuseCategory;
    end;

    with Parameters.UpgradeFloatParameter('Уровень отраженного', 'reflectionLevel') do
    begin
      FAltName:=tr('Уровень отраженного');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      FSpecularLevel.LinkTo(this);
    end;

    with Parameters.UpgradeColorParameter('Отраженный', 'reflectionColor') do
    begin
      FAltName:=tr('Цвет отраженного');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      FSpecular.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('Размытие отражений', 'reflectionRoughness', 0.12) do
    begin
      FAltName:=tr('Шероховатость отраженного');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      FSpecularBlur.LinkTo(this);
      Value := Sqrt(Value / 12);
    end;

    with Parameters.UpgradeFloatParameter('Коэффициент френеля для отражений', 'reflectionIndex', 1) do
    begin
      FAltName:=tr('Коэффициент отражения');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      FSpecularFresnel.LinkTo(this);
      if Value = 0 then
        Value := 100
      else
      if Value < 1 then
        Value := 1 / Value;
    end;

    with Parameters.UpgradeFloatParameter('', 'glareLevel') do
    begin
      FAltName:=tr('Уровень блика');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      Value := FSpecularLevel.Value;
    end;

    with Parameters.UpgradeFloatParameter('', 'glareRoughness') do
    begin
      FAltName:=tr('Размытие блика');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      Value := FSpecularBlur.Value;
    end;

    with Parameters.UpgradeFloatParameter('', 'glareIndex') do
    begin
      FAltName:=tr('Коэффициент отражения блика');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      Value := FSpecularFresnel.Value;
    end;

    Parameters.RemoveParameter('Начало отраженного смешивания');
    Parameters.RemoveParameter('Конец отраженного смешивания');
    Parameters.RemoveParameter('Уровень отраженного Kd');

    with Parameters.UpgradeFloatParameter('Непрозрачность', 'opacity', 1) do
    begin
      FAltName:=tr('Непрозрачность');
      FCustomizable:=true;
      FCategory:=cRefractCategory;
      FOpacity.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('Уровень преломленного', 'refractionLevel') do
    begin
      FAltName:=tr('Уровень преломленного');
      FCustomizable:=true;
      FCategory:=cRefractCategory;
      FRefractionLevel.LinkTo(this);
    end;

    with Parameters.UpgradeColorParameter('Преломленный', 'refractionColor') do
    begin
      FAltName:=tr('Цвет преломленного');
      FCustomizable:=true;
      FCategory:=cRefractCategory;
      FRefraction.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('Размытие преломлений', 'refractionRoughness', 0.12) do
    begin
      FAltName:=tr('Шероховатость преломленного');
      FCustomizable:=true;
      FCategory:=cRefractCategory;
      FRefractionBlur.LinkTo(this);
      Value := Sqrt(Value / 12);
    end;

    with Parameters.UpgradeFloatParameter('Коэффициент преломления', 'refractionIndex', 1) do
    begin
      FAltName:=tr('Коэффициент преломления');
      FCustomizable:=true;
      FCategory:=cRefractCategory;
      FSpecularFresnel.LinkTo(this);
      if Value = 0 then
        Value := 100
      else
      if Value < 1 then
        Value := 1 / Value;
    end;

    Parameters.RemoveParameter('Начало преломленного смешивания');
    Parameters.RemoveParameter('Конец преломленного смешивания');
    Parameters.RemoveParameter('Уровень преломленного Kd');

    with Parameters.UpgradeFloatParameter('Уровень самосвечения', 'emissionLevel', 0) do
    begin
      FAltName:=tr('Уровень самосвечения');
      FCustomizable:=true;
      FCategory:=cEmissionCategory;
      FEmissionLevel.LinkTo(this);
    end;

    with Parameters.UpgradeColorParameter('Самосвечение', 'emissionColor') do
    begin
      FAltName:=tr('Цвет самосвечения');
      FCustomizable:=true;
      FCategory:=cEmissionCategory;
      FEmission.LinkTo(this);
    end;

//  воксельные штуки
    with Parameters.UpgradeFloatParameter('', 'voxBackLevel', 0.7) do
    begin
      FAltName:=tr('Уровень ограничения затухания окружающего');
      FCategory:=cVoxCategory;
      FCustomizable:=true;
    end;

    with Parameters.UpgradeFloatParameter('', 'voxAmbientLevel') do
    begin
      FAltName:=tr('Уровень окружающего');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      Value:=1.0;
    end;

    with Parameters.UpgradeColorParameter('старый фон', 'voxAmbientColor') do
    begin
      FAltName:=tr('Цвет окружающего');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      FOldAmbient.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('', 'voxDiffuseLevel') do
    begin
      FAltName:=tr('Уровень прямого');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      if Parameters.IndexOf('старые уровни') <> -1 then
        Value:=Parameters.GetFloat3Param('старые уровни').Value[1];
    end;

    with Parameters.UpgradeColorParameter('старый рассеянный', 'voxDiffuseColor') do
    begin
      FAltName:=tr('Цвет прямого');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      FOldDiffuse.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('', 'voxDiffuseRoughness', 0.0) do
    begin
      FAltName:=tr('Шероховатость прямого');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
    end;

    with Parameters.UpgradeFloatParameter('', 'voxSpecularLevel', 0) do
    begin
      FAltName:=tr('Уровень отраженного');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      if Parameters.IndexOf('старые уровни') <> -1 then
        Value:=Parameters.GetFloat3Param('старые уровни').Value[2];
    end;
//    Parameters.RemoveParameter('старые уровни'); // TODO пусть пока живет для FOldLevels

    with Parameters.UpgradeColorParameter('старый отраженный', 'voxSpecularColor') do
    begin
      FAltName:=tr('Цвет отраженного');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      FOldSpecular.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('', 'voxReflectionRoughness', 0.01) do
    begin
      FAltName:=tr('Шероховатость отраженного');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      Value:=Parameters.GetFloatParam('reflectionRoughness').Value;
      FRoughness.LinkTo(this);
      FBlur.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('', 'voxReflectionIndex', 1) do
    begin
      FAltName:=tr('Коэффициент отражения');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      Value:=Parameters.GetFloatParam('reflectionIndex').Value;
    end;

    with Parameters.UpgradeFloatParameter('Старая непрозрачность', 'voxOpacity', 1) do
    begin
      FAltName:=tr('Непрозрачность');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      FOldOpacity.LinkTo(this);
    end;

    with Parameters.UpgradeFloatParameter('', 'voxEmissionLevel', 0) do
    begin
      FAltName:=tr('Уровень самосвечения');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      Value:=Parameters.GetFloatParam('emissionLevel').Value;
      FEmissionLevel.LinkTo(this);
    end;

    with Parameters.UpgradeColorParameter('', 'voxEmissionColor', 1, 1, 1) do
    begin
      FAltName:=tr('Цвет самосвечения');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
      Value:=Parameters.GetColorParam('emissionColor').Value;
      FEmission.LinkTo(this);
    end;

    with Parameters.UpgradeFlagsParameter('Прочие флаги', 'AuxFlags') do
    begin
      FAltName:=tr('Прочие флаги');
      FCustomizable:=true;
      FFlags.LinkTo(this);
    end;
//    Parameters.ShowAll;
    Parameters.RemoveParameter('Tentacle');

    Parameters.EndUpdate;
  end;
  if FVersion = 1 then
  begin
    Parameters.BeginUpdate;
    with Parameters.UpgradeTexTransform('texMatrix', 'texTransform', IdentityTransform) do
    begin
      FCustomizable:=true;
      FCategory:=cAlbedoCategory;
      FAltName:=tr('Трансформация текстуры');
    end;
    Parameters.EndUpdate;
  end;
  if FVersion = 2 then
  begin
    Parameters.BeginUpdate;
    reflStruct.isMetal:=0;
    reflStruct.index:=AffineVectorMake(1, 0, 0);
    reflStruct.extinction:=AffineVectorMake(0, 0, 0);
    with Parameters.UpgradeReflParameter('', 'reflectionParams', reflStruct) do
    begin
      FAltName:=tr('Параметры отражения');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      if Parameters.FindParameter('reflectionIndex', p) then
        FValue.index:=AffineVectorMake(p.FValue, 0, 0);
    end;
    Parameters.RemoveParameter('reflectionIndex');
    with Parameters.UpgradeReflParameter('', 'glareParams', reflStruct) do
    begin
      FAltName:=tr('Параметры блика');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      if Parameters.FindParameter('glareIndex', p) then
        FValue.index:=AffineVectorMake(p.FValue, 0, 0);
    end;
    Parameters.RemoveParameter('glareIndex');
    with Parameters.UpgradeColorParameter('', 'glareColor', 1, 1, 1) do
    begin
      FAltName:=tr('Цвет блика');
      FCustomizable:=true;
      FCategory:=cReflectCategory;
      if Parameters.FindParameter('reflectionColor', p1) then
        FValue:=p1.FValue;
    end;
    Parameters.EndUpdate;
  end;
  if FVersion = 3 then
  begin
    with Parameters.UpgradeFloatParameter('', 'diffuseRoughnessLevel', 0) do
    begin
      FAltName:=tr('Влияние шероховатости прямого');
      FCustomizable:=true;
      FCategory:=cDiffuseCategory;
    end;
    with Parameters.UpgradeFloatParameter('', 'voxDiffuseRoughnessLevel', 0) do
    begin
      FAltName:=tr('Влияние шероховатости прямого');
      FCustomizable:=true;
      FCategory:=cVoxCategory;
    end;
    with Parameters.UpgradeFloatParameter('', 'ambientOcclusion1', 0) do
    begin
      FAltName:=tr('Расстояние затенения');
      FCustomizable:=true;
      FCategory:=cAmbientCategory;
    end;
    with Parameters.UpgradeFloatParameter('', 'ambientOcclusion2', 0.5) do
    begin
      FAltName:=tr('Форма кривой затенения');
      FCustomizable:=true;
      FCategory:=cAmbientCategory;
    end;
    with Parameters.UpgradeFloatParameter('', 'ambientOcclusion3', 0) do
    begin
      FAltName:=tr('Процент затенения');
      FCustomizable:=true;
      FCategory:=cAmbientCategory;
    end;
  end;
  if FVersion = 4 then
  begin
    with Parameters.NewMonoMaterial('lightMaterial') do
    begin
      FAltName := tr('Источник света');
      FCustomizable := true;
      FCategory := cEmissionCategory;
      FClassFilter := TLightMaterial;
      FLightMaterial.LinkTo(This);
    end;
{    Parameters.RemoveParameter('emissionLevel');
    Parameters.RemoveParameter('voxEmissionLevel');
    Parameters.RemoveParameter('emissionColor');
    Parameters.RemoveParameter('voxEmissionColor');}
  end;
  if FVersion = 5 then
  begin
    with Parameters.UpgradeTexWrapModeParameter('', 'texWrapMode', IdentityTexWrap) do
    begin
      FAltName := tr('Вропинг текстурных координат');
      FCustomizable := true;
      FCategory := cAlbedoCategory;
    end;
  end;
  if FVersion = 7 then
  begin
    with Parameters.UpgradeFloatParameter('', 'filmIor', 1.5) do
    begin
      FAltName := tr('Коэффициент преломления плёнки');
      FCustomizable := true;
      FCategory := cThinFilmCategory;
    end;
    with Parameters.UpgradeFloatParameter('', 'filmMinThickness', 0) do
    begin
      FAltName := tr('Минимальная толщина плёнки в нм');
      FCustomizable := true;
      FCategory := cThinFilmCategory;
    end;
    with Parameters.UpgradeFloatParameter('', 'filmMaxThickness', 0) do
    begin
      FAltName := tr('Максимальная толщина плёнки в нм');
      FCustomizable := true;
      FCategory := cThinFilmCategory;
    end;
  end;

  if FVersion = 9 then
  begin
    Parameters.BeginUpdate;

    with Parameters.NewFloat('albedo_correction') do
    begin
      FAltName := tr('Коррекция Albedo для Com рендера');
      FCustomizable := true;
      FCategory := cAlbedoCategory;
      Value := 0;
    end;

    Parameters.EndUpdate;
  end;

  {if assigned(FMatLib) then
    for i := 0 to FMatLib.Count - 1 do
    begin
      TMaterial(FMatLib[i]).Upgrade;
      inc(TMaterial(FMatLib[i]).FVersion);
    end;}
end;

procedure TDiffuseMaterial.CalcPBRParams;
  function FresnelDieletricConductor(const Eta, Etak: TVector3f; CosTheta: Single): TVector3f;
  var
    CosTheta2, SinTheta2: Single;
    Eta2, Etak2, t0, t1, t2, t3, t4, a2plusb2, a, Rs, Rp: TVector3f;
  begin
    CosTheta2 := CosTheta * CosTheta;
    SinTheta2 := 1 - CosTheta2;
    Eta2 := VectorScale(Eta, Eta);
    Etak2 := VectorScale(Etak, Etak);

    t0 := VectorSubtract(VectorSubtract(Eta2, Etak2), SinTheta2);
    a2plusb2 := VectorPower(ClampVector(VectorAdd(VectorScale(t0, t0), VectorScale(VectorScale(Eta2, Etak2), 4))), 0.5);
    t1 := VectorAdd(a2plusb2, CosTheta2);
    a := VectorPower(ClampVector(VectorScale(VectorAdd(a2plusb2, t0), 0.5)), 0.5);
    t2 := VectorScale(VectorScale(a, CosTheta), 2);
    Rs := DivideVector(VectorSubtract(t1, t2), VectorAdd(t1, t2));

    t3 := VectorAdd(VectorScale(a2plusb2, CosTheta2), SinTheta2*SinTheta2);
    t4 := VectorScale(t2, SinTheta2);
    Rp := VectorScale(DivideVector(VectorSubtract(t3, t4), VectorAdd(t3, t4)), Rs);

    Result := VectorScale(VectorAdd(Rp, Rs), 0.5);
    if IsNan(Result[0]) or IsNan(Result[1]) or IsNan(Result[2]) then
      Result := XYZVector;
  end;
begin
  with Parameters do
  begin
    FloatParameter['pbr_opacity'].Value := 1.0;
    FloatParameter['pbr_emission'].Value := FloatParameter['emissionLevel'].Value;
    ColorParameter['pbr_emission_color'].Value := ColorParameter['emissionColor'].Value;
    FloatParameter['pbr_specular'].Value := 1.0;
    ColorParameter['pbr_specular_color'].Value := XYZVector;

    FloatParameter['pbr_transmittance'].Value := 1.0 - FloatParameter['opacity'].Value;
    ColorParameter['pbr_transmittance_color'].Value := ColorParameter['refractionColor'].Value;
    FloatParameter['pbr_transmittance_depth'].Value := 0.0;

    FloatParameter['pbr_thin_film_thickness'].Value := FloatParameter['filmMaxThickness'].Value;
    FloatParameter['pbr_thin_film_ior'].Value := FloatParameter['filmIor'].Value;

    with ReflMaterialParameter['reflectionParams'].Value do
    begin
      FloatParameter['pbr_roughness'].Value := ClampValue(ln(1.0 + 13.33 * ClampValue(FloatParameter['reflectionRoughness'].Value, 0.0, 0.33)) / ln(5.44), 0.0, 1.0);
      FloatParameter['pbr_specular_ior'].Value := 1.5;

      if (isMetal = 1) then
      begin //металл
        FloatParameter['pbr_metalness'].Value := 1.0;
        FloatParameter['pbr_base'].Value := FloatParameter['reflectionLevel'].Value;
        ColorParameter['pbr_base_color'].Value := FresnelDieletricConductor(index, extinction, 1);
      end
      else
      begin
        if (index[0] > 50) then //зеркало
        begin
          FloatParameter['pbr_metalness'].Value := 1.0;
          FloatParameter['pbr_base'].Value := 1.0;
          ColorParameter['pbr_base_color'].Value := XYZVector;
        end
        else //не металл
        begin
          FloatParameter['pbr_metalness'].Value := 0.0;
          FloatParameter['pbr_base'].Value := FloatParameter['diffuseLevel'].Value;
          ColorParameter['pbr_base_color'].Value := ColorParameter['albedoColor'].Value;
        end;
      end;
    end;
  end;
end;

constructor TDiffuseMaterial.Create(aOwner: TObject);
begin
  FMatLib := TMaterialList.Create(Self);
  FAmbient:=TColorMaterialParameter.Create(self);
  FAmbient.Value:=XYZVector;
  FDiffuse:=TColorMaterialParameter.Create(self);
  FDiffuse.Value:=XYZVector;
  FSpecular:=TColorMaterialParameter.Create(self);
  FSpecular.Value:=XYZVector;
  FAlbedo:=TColorMaterialParameter.Create(self);
  FAlbedo.Value:=XYZVector;
  FRefraction:=TColorMaterialParameter.Create(self);
  FRefraction.Value:=XYZVector;
  FEmission:=TColorMaterialParameter.Create(self);
  FEmission.Value:=XYZVector;
  FRefractionIndex:=TFloatMaterialParameter.Create(self);
  FOpacity:=TFloatMaterialParameter.Create(self);
  FOpacity.Value:=1.0;
  FOldOpacity:=TFloatMaterialParameter.Create(self);
  FOldOpacity.Value:=1.0;
  FRoughness:=TFloatMaterialParameter.Create(self);
  FBlur:=TFloatMaterialParameter.Create(self);
  FAmbientLevel:=TFloatMaterialParameter.Create(self);
  FDiffuseLevel:=TFloatMaterialParameter.Create(self);
  FDiffuseLevel.Value:=1.0;
  FSpecularLevel:=TFloatMaterialParameter.Create(self);
  FRefractionLevel:=TFloatMaterialParameter.Create(self);
  FEmissionLevel:=TFloatMaterialParameter.Create(self);
  FSpecularBlur:=TFloatMaterialParameter.Create(self);
  FRefractionBlur:=TFloatMaterialParameter.Create(self);
  FSpecularFresnel:=TFloatMaterialParameter.Create(self);
  FSpecularKdPower:=TFloatMaterialParameter.Create(self);
  FRefractionKdPower:=TFloatMaterialParameter.Create(self);
  FAlbedoLevel:=TFloatMaterialParameter.Create(self);
  FTentacle:=TFloatMaterialParameter.Create(self);
  FEmissionAtt:=TFloatMaterialParameter.Create(self);
  FSpecularMixStart:=TFloatMaterialParameterWithConverter.Create(self);
  FSpecularMixEnd:=TFloatMaterialParameterWithConverter.Create(self);
  FRefractionMixStart:=TFloatMaterialParameterWithConverter.Create(self);
  FRefractionMixEnd:=TFloatMaterialParameterWithConverter.Create(self);
  FOldLevels:=TFloat3MaterialParameter.Create(self);
  FOldAmbient:=TColorMaterialParameter.Create(self);
  FOldAmbient.Value:=XYZVector;
  FOldSpecular:=TColorMaterialParameter.Create(self);
  FOldSpecular.Value:=XYZVector;
  FOldDiffuse:=TColorMaterialParameter.Create(self);
  FOldDiffuse.Value:=XYZVector;
  FReflectionFlags:=TFlagsMaterialParameter.Create(self);
  FRefractionFlags:=TFlagsMaterialParameter.Create(self);
  FFlags:=TFlagsMaterialParameter.Create(self);
  FLightMaterial := TMonoMaterialParameter.Create(Self);
  FLightMaterial.FMatLib := FMatLib;
  inherited;
end;

destructor TDiffuseMaterial.Destroy;
begin
  FAmbient.Free;
  FDiffuse.Free;
  FSpecular.Free;
  FAlbedo.Free;
  FRefraction.Free;
  FEmission.Free;
  FRefractionIndex.Free;
  FOpacity.Free;
  FOldOpacity.Free;
  FRoughness.Free;
  FBlur.Free;
  FAmbientLevel.Free;
  FDiffuseLevel.Free;
  FSpecularLevel.Free;
  FRefractionLevel.Free;
  FEmissionLevel.Free;
  FSpecularBlur.Free;
  FRefractionBlur.Free;
  FSpecularFresnel.Free;
  FSpecularKdPower.Free;
  FRefractionKdPower.Free;
  FAlbedoLevel.Free;
  FTentacle.Free;
  FEmissionAtt.Free;
  FSpecularMixStart.Free;
  FSpecularMixEnd.Free;
  FRefractionMixStart.Free;
  FRefractionMixEnd.Free;
  FOldLevels.Free;
  FOldAmbient.Free;
  FOldSpecular.Free;
  FOldDiffuse.Free;
  FReflectionFlags.Free;
  FRefractionFlags.Free;
  FFlags.Free;
  FLightMaterial.Free;
  FMatLib.Free;
  inherited;
end;

function TDiffuseMaterial.GetMonoMaterialList: TMaterialList;
begin
  Result := FMatLib;
end;

function TDiffuseMaterial.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
var
  mat: TMaterial;
begin
  with LoadInfo do
    case ChildBlockType of
      btMaterialListItem:
      begin
        mat := MaterialTypes.FindMaterialClassByName(ChildClass).Create(FMatLib);
        if ChildID <> '' then
          FMatLib.Add(mat);
        Result := mat;
      end;
    else
      Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID);
    end;
end;

procedure TDiffuseMaterial.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
var
  libNode, matNode: TXmlNode;
  mat: TMaterial;
  i: Integer;
begin
  inherited;
  if assigned(root) then
  begin
    libNode := root.FindNode('MaterialsLibrary');
    if libNode <> nil then
    begin
      for i:=0 to libNode.NodeCount - 1 do
      begin
        matNode := libNode.Nodes[i];
		    if Assigned(matNode) and (matNode.HasAttribute('Type')) then
        begin
          mat := MaterialTypes.FindMaterialClass(matNode.AttributeByName['Type'].ValueAsInteger).Create(FMatLib);
          mat.LoadFromXml(matNode, loadFlags);
          FMatLib.Add(mat);
        end
      end;
    end;
  end;
end;

procedure TDiffuseMaterial.ReadFromFiler(ReadInfo: TReadInfo;
  ReadType: boolean);
var
  count, i, aType: Integer;
  mat: TMaterial;
begin
  inherited;
  FMatLib.Clear;
  if ReadInfo.Reader.CheckMagic($12345678) then
    with ReadInfo do
    begin
      Reader.Read(count, sizeof(count));
      for i := 0 to count - 1 do
      begin
        Reader.Read(aType, SizeOf(aType));
        mat := (MaterialTypes.FindMaterialClass(aType)).Create(FMatLib);
        FMatLib.Add(mat);
        mat.ReadFromFiler(ReadInfo);
      end;
    end;
end;

procedure TDiffuseMaterial.SaveObject(var SaveInfo: TSaveInfo);
var
  ind: Integer;
  mat: TMaterial;
begin
  inherited;
  with SaveInfo, Writer do
  try
    if FLightMaterial.Value <> '' then
    begin
      mat := FMatLib.Find(FLightMaterial.Value);
      if mat <> nil then
      begin
        BeginChild(btMaterialListItem, mat.ClassName, mat.Name);
        try
          mat.SaveObject(SaveInfo);
        finally
          EndChild;
        end;
      end
      else
        FLightMaterial.Value := '';
    end;
  except
    on e: exception do
      SaveInfo.Error('TMultiMaterial: ' + e.Message);
  end;
end;

procedure TDiffuseMaterial.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
var
  mat: TMaterial;
  libNode: TXmlNode;
begin
  inherited;
  if assigned(root) then
  begin
    libNode := root.NodeNew('MaterialsLibrary');
    if FLightMaterial.Value <> '' then
    begin
      mat := FMatLib.Find(FLightMaterial.Value);
      if mat <> nil then
        mat.SaveToXml(libNode.NodeNew('MonoMaterial'), SaveFlags)
      else
        FLightMaterial.Value := '';
    end;
  end;
end;

procedure TDiffuseMaterial.WriteToFiler(WriteInfo: TWriteInfo);
var
  i, count: Integer;
begin
  inherited;
  with WriteInfo do
  begin
    Writer.WriteMagic($12345678);
    count := FMatLib.Count;
    Writer.Write(count, SizeOf(count));
    for i := 0 to count - 1 do
    begin
      TMaterial(FMatLib[i]).WriteToFiler(WriteInfo);
    end;
  end;
end;

procedure TDiffuseMaterial.DeleteUnusedMaterials;
var
  c: IMonoMaterialContainer;
  list: TMaterialList;
  j: Integer;
begin
  inherited;
  if Supports(Self, IMonoMaterialContainer, c) then
  begin
    list := c.GetMonoMaterialList;
    for j := list.Count - 1 downto 0 do
      if LightMaterial.GetValue <> TMaterial(list[j]).Name then
        list.Delete(j);
  end;
end;

procedure TDiffuseMaterial.ExecCommand(cmd: cardinal;
  params: TCommandParams);
begin
  inherited;
  case cmd of
    cMarkDurty, cImagePack: FMatLib.ExecCommand(cmd, params);
    cRecalcPBRMaterial: if PBRParamsIsDefault then CalcPBRParams;
  end;
end;

procedure TDiffuseMaterial.ValidateVersion;
var
  i: integer;
begin
  inherited;
  if assigned(FMatLib) then
    for i := 0 to FMatLib.Count - 1 do
      TMaterial(FMatLib[i]).ValidateVersion;
end;

{ TTextureMaterial }

function ComputeLod(const DistanceFromEye, ViewResolution, TexelSize: single): single;
begin
  Result:=Max(0, Log2(DistanceFromEye * DistanceFromEye / (TexelSize * ViewResolution)) * 0.5);
end;

function LerpColor(colors: array of cardinal; value: single): TAffineVector;
var
  v1, v2: TAffineVector;
  t: single;
begin
  t:=value - floor(value);
  v1:=RGBAToAffineVector(TRGBA(colors[ClampValue(floor(value), 0, High(colors))]));
  v2:=RGBAToAffineVector(TRGBA(colors[ClampValue(ceil(value), 0, High(colors))]));
  Lerp(v1, v2, 1 - t, t, Result);
end;

constructor TTextureMaterial.Create(aOwner: TObject);
begin
  FBaseMap:=TTextureMaterialParameter.Create(self);
{  FTexMatrix:=TMatrixMaterialParameter.Create(self);
  FTexMatrix.Value:=IdentityHmgMatrix;}
  FTexTransform := TTexTransformMaterialParameter.Create(Self);
  FTexWrapMode := TTexWrapModeMaterialParameter.Create(Self);
  inherited;
end;

destructor TTextureMaterial.Destroy;
begin
  FBaseMap.Free;
//  FTexMatrix.Free;
  FTexTransform.Free;
  FTexWrapMode.Free;
  inherited;
end;

procedure TTextureMaterial.EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);
const
  colors: array[0..8] of cardinal = (0, $FFFFFF, $0000FF, $00FFFF, $00FF00, $FF00FF, $FFFF00, $FF0000, $00FF7F);
begin
  if FTextures.Cache = nil then
    FTextures.SetupCache(['basemap'], [{FTexMatrix.ValuePointer}FTexTransform.MatrixCashePointer]);
  if FTextures.Cache[0].sampler <> nil then
  begin
{$IFNDEF RELEASE}
    if GetKeyState(VK_SHIFT) < 0 then
    begin
      aPoint.SetAlbedo(LerpColor(colors, ComputeLod(aPoint.DistanceFromEyeForLod, aPoint.ViewResolution,
        aPoint.GetTexelSize / FTextures.Cache[0].texelScale)));
      inherited;
      exit;
    end;
{$ENDIF}
    aPoint.SetAlbedo(TVectorCoords(FTextures.Cache[0].Sampler.SampleLinear2d(
      VectorMake(VectorTransform(aPoint.TexCoord, {FTexMatrix.Value}FTexTransform.MatrixCashe),
      ComputeLod(aPoint.DistanceFromEyeForLod, aPoint.ViewResolution, aPoint.GetTexelSize / FTextures.Cache[0].texelScale)))).XYZ);
  end;
  inherited;
end;

function TTextureMaterial.GetShaderEvaluationCase: string;
var
  bm: TTextureMaterialParameter;
begin
  if Parameters.FindParameter('basemap', bm) then
    Result:='case ' + IntToStr(FType) + ': ' +
    'uv = mul( float4(uv, 0.0, 1.0 ), ' + Parameters.ShaderValue['texmatrix'] + ' ).xy;'+
    't = ' + bm.GetAtlasPositionForShader + ';' +
    't.xy += uv * ' + bm.GetAtlasScaleForShader + ';' +
    'base = $TEXATLAS.SampleLevel( $LINEARSAMPLER, t, 0.0 );' +
    '$RESULT.xyz = CookTorrens( base, ' +
    'float2(' + Parameters.ShaderValue['roughness'] + ', ' + Parameters.ShaderValue['blur'] + '), n, light, view, float3(1, 0, 0), ' +
    Parameters.ShaderValue['ambient'] + ', ' +
    Parameters.ShaderValue['diffuse'] + '.xyz, ' +
    Parameters.ShaderValue['specular'] + ', ' +
    Parameters.ShaderValue['levels'] + '); ' +
    '$RESULT.w = ' + Parameters.ShaderValue['diffuse'] + '.w; ' +
    'break;'
  else
    Result:=inherited GetShaderEvaluationCase;
end;

class function TTextureMaterial.GetTypeIndex: integer;
begin
  Result:=2;
end;

procedure TTextureMaterial.SetAtlas(aAtlas: TMaterialTextureAtlas);
var
  v: TTextureValue;
  i: integer;
  sc: Single;
  p: TTextureMaterialParameter;
begin
  inherited;
  sc:=(VectorLength({FTexMatrix.Value[0]}FTexTransform.MatrixCashe[0]) *
    VectorLength({FTexMatrix.Value[1]}FTexTransform.MatrixCashe[1]));
  for i:=0 to FParameters.Count - 1 do
    if FParameters[i] is TTextureMaterialParameter then
    begin
      p:=TTextureMaterialParameter(FParameters[i]);
      v:=p.Value;
      v.TexelScale:=v.TexelScale * sc;
      v.TexelScale:=0.5 * log2(v.TexelScale);
      p.Value:=v;
    end;
end;

procedure TTextureMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;

  with Parameters.NewTexture('BaseMap') do
  begin
    FBaseMap.LinkTo(this);
    FCustomizable:=true;
  end;

  with Parameters.NewTexWrapMode('texWrapMode') do
  begin
    FTexWrapMode.LinkTo(this);
    FCustomizable:=true;
  end;

{  with Parameters.NewMatrix('TexMatrix') do
  begin
    FTexMatrix.LinkTo(this);
    Value:=IdentityHmgMatrix;
    FCustomizable:=true;
    FUpdatable:=true;
  end;}

  Parameters.EndUpdate;
end;

procedure TTextureMaterial.Upgrade;
begin
  inherited;
  if FVersion = 0 then
  begin
    FBaseMap.LinkTo(FParameters.FindParameter('albedoMap'));
//    FTexMatrix.LinkTo(FParameters.FindParameter('texMatrix'));
  end;
  if FVersion = 1 then
    FTexTransform.LinkTo(FParameters.FindParameter('texTransform'));
  if FVersion = 5 then
    FTexWrapMode.LinkTo(FParameters.FindParameter('texWrapMode'));
end;

{ TBumpMaterial }

constructor TBumpMaterial.Create(aOwner: TObject);
begin
  FBumpMap:=TTextureMaterialParameter.Create(self);
  inherited;
end;

destructor TBumpMaterial.Destroy;
begin
  FBumpMap.Free;
  inherited;
end;

procedure TBumpMaterial.EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);
begin
  aPoint.SetNormal(GetNormal(aPoint));
  inherited;
end;

function TBumpMaterial.GetNormal(aPoint: TSurfacePoint): TAffineVector;
var
  nm, uvw: TAffineVector;
begin
  if FTextures.Cache = nil then
    FTextures.SetupCache(['basemap', 'bumpmap'],
      [{FTexMatrix.ValuePointer, FTexMatrix.ValuePointer}FTexTransform.MatrixCashePointer, FTexTransform.MatrixCashePointer]);
  if FTextures.Cache[1].sampler <> nil then
  begin
    uvw:=VectorTransform(aPoint.TexCoord, {FTexMatrix.Value}FTexTransform.MatrixCashe);
    nm:=VectorAdd(VectorScale(TVectorCoords(FTextures.Cache[1].sampler.SampleLinear2d(
      VectorMake(uvw, ComputeLod(aPoint.DistanceFromEyeForLod, aPoint.ViewResolution, aPoint.GetTexelSize / FTextures.Cache[1].texelScale)))).XYZ, 2.0), -1.0);
    Result:=VectorNormalize(VectorTransform(nm, aPoint.TangentSpace));
  end
  else
    Result:=inherited GetNormal(aPoint);
end;

function TBumpMaterial.GetShaderEvaluationCase: string;
var
  bm: TTextureMaterialParameter;
begin
  Result:=inherited GetShaderEvaluationCase;
  if Parameters.FindParameter('bumpmap', bm) then
    Insert(
    't = ' + bm.GetAtlasPositionForShader + ';' +
    't.xy += uv * ' + bm.GetAtlasScaleForShader + ';' +
    'bn = $TEXATLAS.SampleLevel( $LINEARSAMPLER, t, 0.0 ) * 2.0 - 1.0;' +
    'm[0] = tangent;' +
    'm[1] = binormal;' +
    'm[2] = n;' +
    'n = normalize( mul( bn, m ) );'
    , Result, AnsiPos('$RESULT.xyz = ', Result));
end;

class function TBumpMaterial.GetTypeIndex: integer;
begin
  Result:=3;
end;

procedure TBumpMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;
  with Parameters.NewTexture('BumpMap') do
  begin
    FBumpMap.LinkTo(this);
    FCustomizable:=true;
  end;
  Parameters.EndUpdate;
end;

procedure TBumpMaterial.Upgrade;
begin
  inherited;
  if FVersion = 0 then
  begin
    FBumpMap.LinkTo(FParameters.FindParameter('bumpMap'));
  end;
end;

{ TLightMaterial }

constructor TLightMaterial.Create(aOwner: TObject);
begin
  FAtt:=TFloatMaterialParameter.Create(self);
  FIntFlags:=TFlagsMaterialParameter.Create(self);

  FSpotUmbra:=TFloatMaterialParameter.Create(self);
  FSpotUmbra.Value:=20.0;
  FSpotPenumbra:=TFloatMaterialParameter.Create(self);
  FSpotPenumbra.Value:=60.0;
  FSpotFalloff:=TFloatMaterialParameter.Create(self);
  FSpotFalloff.Value:=2.0;
  inherited;
end;

destructor TLightMaterial.Destroy;
begin
  FAtt.Free;
  FIntFlags.Free;
  FSpotUmbra.Free;
  FSpotPenumbra.Free;
  FSpotFalloff.Free;
  inherited;
end;

procedure TLightMaterial.EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);
var
  dot, sc: single;
  lp: ILayeredSurfacePoint;
begin
//  dot:=ClampValue(VectorDotProduct(aPoint.NegView, aPoint.Normal), 0, 1);
  dot:=abs(VectorDotProduct(aPoint.NegView, aPoint.Normal));
  sc:=0.2 + 0.8 * (1.0 - Fresnel(dot, FAtt.FValue));
  if (EvalMode = memFinal) and aPoint.GetInterface(ILayeredSurfacePoint, lp) then
  begin
    with lp do
    begin
      Vectors[0]:=PointMake(VectorScale(FLightColor.Value, sc));
      Integers[0]:=Integer(self);
    end;
    lp:=nil;
  end;
  if EvalMode = memDefault then
    aPoint.ResultColor:=PointMake(sc, sc, sc)
  else
{  if EvalMode = memLight then
    aPoint.ResultColor:=NullHmgVector
  else}
    aPoint.ResultColor:=PointMake(VectorScale(GetEmissive, sc));
end;

function TLightMaterial.GetAttenuation: Single;
begin
  Result:=FAtt.Value;
end;

class function TLightMaterial.GetShaderAttenuation(const m: string): string;
begin
  Result:='(' + m + '.LightAttenuation)';
end;

class function TLightMaterial.GetShaderEmissive(const m: string): string;
begin
  Result:='(' + m + '.Emission * ' + m + '.EmissionLevel)';
end;

function TLightMaterial.GetShaderEvaluationCase: string;
begin
  Result:='case ' + IntToStr(FType) + ': ' +
  '$RESULT.xyz = ' + Parameters.ShaderValue['LightColor'] + ';' +
  '$RESULT.w = 1.0; ' +
  'break;'
end;

class function TLightMaterial.GetTypeIndex: integer;
begin
  Result:=0;
end;

function TLightMaterial.IsLightSource: boolean;
begin
  Result:=true;
end;

procedure TLightMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;
  with Parameters.UpgradeFloatParameter('', 'oldQuadAtt') do
  begin
    FAltName := tr('Уровень затухания в керамике');
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FAtt.LinkTo(this);
  end;

  with Parameters.UpgradeFlagsParameter('Прочие флаги', 'AuxFlags') do
  begin
    FCustomizable:=false;
    FIntFlags.LinkTo(this);
    SetFlagsNames(langRussian, ['Источник света']);
    SetFlagsNames(langEnglish, ['Light source']);
    SetFlagsVisibility([false]);
    SetFlag(0, true);
    SetFlagsBits([5])
  end;

  with Parameters.UpgradeFloatParameter('', 'LightSpotUmbra', 20.0) do
  begin
    FAltName := tr('Угол светлого пятна прожектора');
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FSpotUmbra.LinkTo(this);
  end;

  with Parameters.UpgradeFloatParameter('', 'LightSpotPenumbra', 60.0) do
  begin
    FAltName := tr('Угол прожектора');
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FSpotPenumbra.LinkTo(this);
  end;

  with Parameters.UpgradeFloatParameter('', 'LightSpotFalloff', 2.0) do
  begin
    FAltName := tr('Затухание на границе пятна');
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FSpotFalloff.LinkTo(this);
  end;
  Parameters.EndUpdate;
end;

procedure TLightMaterial.Upgrade();
var
  val: TVector3f;
begin
  inherited;
  //Exit;
  if FVersion = 0 then
  begin
    Parameters.BeginUpdate;

    with Parameters.UpgradeFloatParameter('Затухание', 'LightAttenuation', 0.98) do
    begin
      FAltName := tr('Уровень затухания');
      FCustomizable:=true;
      FCategory:=cLLightCategory;
    end;
                                                                   
    with Parameters.UpgradeFloatParameter('', 'voxLightAttenuation', 0.98) do
    begin
      FAltName := tr('Уровень затухания');
      FCustomizable:=true;
      FCategory:=cLVoxLightCategory;
    end;

    with Parameters.UpgradeFloatParameter('', 'voxOpacity', 0.0) do
    begin
      FAltName := tr('Непрозрачность');
      FCustomizable:=true;
      FCategory:=cLVoxEmissionCategory;
    end;

    Parameters.GetFloatParam('voxShadowDensity').FValue := 0.3;
    Parameters.GetFloatParam('EmissionLevel').FCustomizable := False;
    Parameters.GetColorParam('EmissionColor').FCustomizable := False;

    Parameters.EndUpdate;
  end;
end;

{ TDiffuseLightMaterial }

procedure TDiffuseLightMaterial.EvalMaterialAt(aPoint: TSurfacePoint;
  EvalMode: integer);
var
  dot, sc: single;
  lp: ILayeredSurfacePoint;
begin
//  dot:=ClampValue(VectorDotProduct(aPoint.NegView, aPoint.Normal), 0, 1);
  dot:=abs(VectorDotProduct(aPoint.NegView, aPoint.Normal));
  sc:=0.2 + 0.8 * (1.0 - Fresnel(dot, GetAttenuation));
  if (EvalMode = memFinal) and aPoint.GetInterface(ILayeredSurfacePoint, lp) then
  begin
    with lp do
    begin
      Vectors[0]:=PointMake(VectorScale(GetEmissive, sc));
      Integers[0]:=Integer(self);
    end;
    lp:=nil;
  end;
  if EvalMode = memDefault then
    aPoint.ResultColor:=PointMake(sc, sc, sc)
  else
{  if EvalMode = memLight then
    aPoint.ResultColor:=NullHmgVector
  else}
    aPoint.ResultColor:=PointMake(VectorScale(GetEmissive, sc));
end;

class function TDiffuseLightMaterial.GetTypeIndex: integer;
begin
  Result:=10;
end;

function TDiffuseLightMaterial.IsLightSource: boolean;
begin
  Result:=true;
end;

function TDiffuseLightMaterial.IsTransparent: boolean;
var
  f: Integer;
begin
  f:=0;
  FFlags.StoreValue(f);
  Result:=(f and matFlagHidden) <> 0;
end;

procedure TDiffuseLightMaterial.SetupParametersList;
begin
  inherited;
  FEmission.Value:=XYZVector;
  FEmissionLevel.Value:=10.0;
  FEmissionAtt.Value:=0.98;
  FFlags.SetFlagVisibility(2, true);
  FFlags.SetFlag(1, True);
  FFlags.SetFlag(2, true);
end;

{ TMirrorMaterial }

class function TMirrorMaterial.GetTypeIndex: integer;
begin
  Result:=4;
end;

{ TGlassMaterial }

class function TGlassMaterial.GetTypeIndex: integer;
begin
  Result:=5;
end;

{ TMaterialConverter }

constructor TMaterialConverter.Create;
begin
  inherited Create;
  AssignKnownParameters;
end;

function TMaterialConverter.GetFloat(aParamName: string): single;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsFloat
  else
    raise Exception.Create('unknown float parameter ' + aParamName);
end;

function TMaterialConverter.GetFloat3(aParamName: string): TAffineVector;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsFloat3
  else
    raise Exception.Create('unknown float3 parameter ' + aParamName);
end;

function TMaterialConverter.GetFloat4(aParamName: string): TVector;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsFloat4
  else
    raise Exception.Create('unknown float4 parameter ' + aParamName);
end;

function TMaterialConverter.GetInteger(aParamName: string): integer;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsInteger
  else
    raise Exception.Create('unknown integer parameter ' + aParamName);
end;

function TMaterialConverter.GetMatrix(aParamName: string): TMatrix;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsMatrix
  else
    raise Exception.Create('unknown matrix parameter ' + aParamName);
end;

function TMaterialConverter.GetTextureValue(
  aParamName: string): TTextureValue;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsTextureValue
  else
    raise Exception.Create('unknown texture parameter ' + aParamName);
end;

function TMaterialConverter.GetString(aParamName: string): string;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsString
  else
    raise Exception.Create('unknown string parameter ' + aParamName);
end;

function TMaterialConverter._AddRef: Integer;
begin
  Result := InterlockedIncrement(FRefCount);
end;

function TMaterialConverter._Release: Integer;
begin
  Result := InterlockedDecrement(FRefCount);
  if Result = 0 then
    Destroy;
end;

function TMaterialConverter.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TMaterialConverter.GetTexture(aName: string): TObject;
begin
  Result:=nil;
{  try
    raise Exception.Create('texture ' + aName + ' not found');
  except
  end;}
end;

procedure TMaterialConverter.AfterConstruction;
begin
  InterlockedDecrement(FRefCount);
  inherited;
end;

procedure TMaterialConverter.BeforeDestruction;
begin
  if FRefCount <> 0 then
    raise Exception.Create('trying to destroy linked object');
  inherited;
end;

class function TMaterialConverter.NewInstance: TObject;
begin
  Result := inherited NewInstance;
  TMaterialConverter(Result).FRefCount := 1;
end;

procedure TMaterialConverter.SetFloat(aParamName: string; const value: single);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsFloat(value)
  else
    raise Exception.Create('unknown float parameter ' + aParamName);
end;

procedure TMaterialConverter.SetFloat3(aParamName: string;
  const value: TAffineVector);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsFloat3(value)
  else
    raise Exception.Create('unknown float3 parameter ' + aParamName);
end;

procedure TMaterialConverter.SetFloat4(aParamName: string; const value: TVector);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsFloat4(value)
  else
    raise Exception.Create('unknown float4 parameter ' + aParamName);
end;

procedure TMaterialConverter.SetInteger(aParamName: string;
  const value: integer);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsInteger(value)
  else
    raise Exception.Create('unknown integer parameter ' + aParamName);
end;

procedure TMaterialConverter.SetMatrix(aParamName: string; const value: TMatrix);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsMatrix(value)
  else
    raise Exception.Create('unknown matrix parameter ' + aParamName);
end;

procedure TMaterialConverter.SetTexture(aName: string; const value: TObject);
begin
  raise Exception.Create('texture ' + aName + ' not found');
end;

procedure TMaterialConverter.SetTextureValue(aParamName: string;
  const value: TTextureValue);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsTextureValue(value)
  else
    raise Exception.Create('unknown texture value parameter ' + aParamName);
end;

procedure TMaterialConverter.SetString(aParamName: string; const value: string);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsString(value)
  else
    raise Exception.Create('unknown string parameter ' + aParamName);
end;

function TMaterialConverter.HasParameter(aParamName: string): boolean;
begin
  Result:=IndexOf(aParamName) > -1;
end;

function TMaterialConverter.GetTexWrapMode(
  aParamName: string): TTexWrapMode;
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    Result:=p.AsTexWrapMode
  else
    raise Exception.Create('unknown texture wrap mode parameter ' + aParamName);
end;

procedure TMaterialConverter.SetTexWrapMode(aParamName: string;
  const value: TTexWrapMode);
var
  p: TMaterialParameter;
begin
  if FindParameter(aParamName, p) then
    p.SetAsTexWrapMode(value)
  else
    raise Exception.Create('unknown texture wrap mode parameter ' + aParamName);
end;

{ TMaterialTextures }

function TMaterialTextures.New(aClass: TMaterialTextureClass;
  aName: string): TMaterialTexture;
begin
  Result:=aClass.Create;
  Result.FName:=aName;
  Add(Result);
end;
{
function TMaterialTextures.CreateAtlas(aName: string; aFormat: TTextureDataFormat;
  MaxWidth, MaxHeight, MaxDepth, Border: integer): TMaterialTextureAtlas;
const
  ZOffset: TAffineVector = (0.5, 0.5, 0.5);
var
  i: integer;
  p: TTexturePacker;
  s: TMaterialTexture;
  d: TAtlasMaterialTexture;
  tp: TVector3i;
  l: TList;
  InvSize: TAffineVector;
begin
  Result:=TMaterialTextureAtlas.Create;
  l:=TList.Create;
  p:=TTexturePacker.Create(MaxWidth, MaxHeight, MaxDepth);
  for i:=0 to count - 1 do
    l.Add(p.AddTexture(TMaterialTexture(List[i]).FWidth, TMaterialTexture(List[i]).FHeight, Border, TObject(List[i])));
  p.Pack;
  Result.FName:=aName;
  Result.FWidth:=p.TexWidth;
  Result.FHeight:=p.TexHeight;
  Result.FDepth:=p.TexDepth;
  InvSize[0]:=1.0 / Result.FWidth;
  InvSize[1]:=1.0 / Result.FHeight;
  InvSize[2]:=1.0 / Result.FDepth;
  Result.SetupFormat(aFormat);
  Result.AllocateData;
  for i:=0 to count - 1 do
  begin
    s:=TMaterialTexture(List[i]);
    tp:=p.GetTexPosition(l.List[i]);
    Result.Draw(s, tp[0], tp[1], tp[2]);
    d:=TAtlasMaterialTexture(Result.AtlasContent.New(s.FName, TAtlasMaterialTexture));
    d.FWidth:=s.FWidth;
    d.FHeight:=s.FHeight;
    d.FDepth:=s.FDepth;
    d.SetupFormat(aFormat);
    d.FRowPitch:=Result.FRowPitch;
    d.FDepthPitch:=Result.FDepthPitch;
    d.FWxH:=Result.FWxH;
    d.FDataSize:=0;
    d.FData:=Result.GetAddressOf(tp[0], tp[1], tp[2]);
    d.TextureAtlasPositionAndScale.Index[0]:=(tp[0] + 0.5) * InvSize[0];
    d.TextureAtlasPositionAndScale.Index[1]:=(tp[1] + 0.5) * InvSize[1];
    d.TextureAtlasPositionAndScale.Index[2]:=(tp[2] + 0.5) * InvSize[2];
    d.TextureAtlasPositionAndScale.Scale[0]:=(d.FWidth - 1) * InvSize[0];
    d.TextureAtlasPositionAndScale.Scale[1]:=(d.FHeight - 1) * InvSize[1];
    d.TextureAtlasPositionAndScale.MaxLod:=min(Trunc(log2(d.FWidth)), Trunc(log2(d.FHeight)));
    d.TextureAtlasPositionAndScale.TexelScale:=d.FWidth * d.FHeight;
    d.TextureAtlasPositionAndScale.TexelSize[0]:=0.5 / d.FWidth;
    d.TextureAtlasPositionAndScale.TexelSize[1]:=0.5 / d.FHeight;
  end;
  Result.CreateMips;
  for i:=0 to Result.AtlasContent.Count - 1 do
    TAtlasMaterialTexture(Result.AtlasContent.List[i]).SetMipmapDataFromAtlas(Result);
  p.Free;
  l.Free;
end;
}

function TMaterialTextures.IndexOf(aTextureID: string): integer;
begin
  Result:=count - 1;                                                      
  while (Result > -1) and (AnsiCompareText(TMaterialTexture(List[Result]).TextureID, aTextureID) <> 0) do
    dec(Result);
end;

function TMaterialTextures.Find(aTextureID: string; var obj): boolean;
var
  i: integer;
begin
  i:=IndexOf(aTextureID);
  if i > -1 then
  begin
    Result:=true;
    TObject(obj):=List[i];
  end
  else
    Result:=false;
end;

function TMaterialTextures.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
var
  cls: TClass;
begin
  with LoadInfo do
    case ChildBlockType of
      btMaterialTexturesItem:
      begin
        cls := MaterialTextures.GetTypeByClassname(ChildClass);
        if cls = nil then
          Result := CL_UNKNOWN_OBJECT
        else
          Result := TMaterialTextureClass(cls).CreateNamed(ChildID);
        Add(Result);
      end;
    else
      Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID);
    end;
end;

function TMaterialTextures.GetTextureID(
  const Index: Integer): string;
begin
  Result:=TMaterialTexture(Items[Index]).TextureID;
end;

function TMaterialTextures.GetTextureCount: Integer;
begin
  Result:=Count;
end;

function TMaterialTextures.GetSampler(const aTextureID: string;
  out sampler: ITextureSampler): boolean;
var
  t: TMaterialTexture;
begin
  Result:=Find(aTextureID, t) and Supports(t, ITextureSampler, sampler);
end;

procedure TMaterialTextures.SetSampler(const sampler: ITextureSampler);
begin
  if IndexOf(sampler.GetTextureID) = -1 then
    Add(sampler.GetSamplerObject);
end;

function TMaterialTextures.GetSampler(value: TTextureValue; out sampler: ITextureSampler): boolean;
begin
  Result:=false;
end;

function TMaterialTextures.ListTextures: string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to Count - 1 do
    Result:=Result + GetTextureID(i) + #13#10;
end;

function TMaterialTextures.LoadFromFile(const filename: string): string;
var
  tex: TMaterialTexture;
begin
  Result := '';
  if Assigned(CommonMaterialTextureClass) then
  begin
    //GetOrAdd(ExtractFileName(filename), CommonMaterialTextureClass).LoadFromFile(filename);
    tex := CommonMaterialTextureClass.CreateNamed(ExtractFileName(filename));
    tex.LoadFromFile(filename);
    Result := tex.TextureID;
    if (IndexOf(Result) = -1) then
      Add(tex)
    else
      tex.Free;
  end;
end;

procedure TMaterialTextures.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
  i: integer;
  l: TList;
begin
  l := nil;
  with SaveInfo, Writer do
  try
    if (sfSaveOnlyUsedTextures in SaveInfo.Flags) and (SaveInfo.KnownRefs <> nil) then
    begin
      l := TList.Create;
      for i := 0 to Count - 1 do
        if SaveInfo.KnownRefs.HasGUID(TMaterialTexture(List[i]).GUIDLabel.Guid) then
          l.Add(List[i]);
    end
    else
      l := Self;
    try
      WriteInteger(btMaterialTexturesCount, l.Count);
      for i:=0 to l.count - 1 do
      begin
        BeginChild(btMaterialTexturesItem, TMaterialTexture(l.List[i]).ClassName, TMaterialTexture(l.List[i]).FName);
        try
          TMaterialTexture(l.List[i]).SaveObject(SaveInfo);
        finally
          EndChild;
        end;
      end;
    finally
      if l <> self then
        l.Free;
    end;
  except
    on e: exception do
      SaveInfo.Error('TMaterialTextures: ' + e.Message);
  end;
  inherited;
end;

function TMaterialTextures.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btMaterialTexturesCount: Clear;
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

type
  TAtlasItem = class
    tex: TObject;
    w, h: Integer;
  constructor Create(tex: TObject; w, h: Integer);
  end;

constructor TAtlasItem.Create(tex: TObject; w, h: Integer);
begin
  Self.tex := tex;
  Self.w := w;
  Self.h := h;
end;

function TMaterialTextures.CreateGoodAtlas(aName: string;
  aFormat: TTextureDataFormat; MaxWidth10, MaxHeight10, MaxWidth11, MaxHeight11,
  Border: integer; Task: TSSTask): TMaterialTextureAtlas;
const
  ZOffset: TAffineVector = (0.5, 0.5, 0.5);
  exe: string = 'GridPacker.exe';
type
  TWH = record
    w, h: Integer;
  end;
  TInfo = record
    w, h: Integer;
    maxMipLevel: Integer;
    resize: Boolean;
    x, y: Integer;
  end;
var
  i, iw, ih, iter, j, k, texInd: integer;
  s: TMaterialTexture;
  d: TAtlasMaterialTexture;
  tp: TVector3i;
  InvSize: TAffineVector;
  temp: array [0..1] of TMaterialTexture;
  dataSize: Integer;
  texPacker: TTexturePacker;
  texSize: TVector3i;
  texList: TList;
  tex: TMaterialTexture;
  w2, h2: Integer;
  maxLod, indInTexList, aux: array of Integer;
  isMip: array of Boolean;
  col: TRGBA;
  wm: TTextureWrapMode;
begin
  Result:=TMaterialTextureAtlas.Create;
  if Count = 0 then exit;

  //TexPacker
  texPacker := TTexturePacker.Create(MaxWidth10, MaxHeight10, 1);
  texList := TList.Create();
  SetLength(maxLod, Count);
  SetLength(indInTexList, Count);

  SetLength(isMip, Count * 15);
  iter := 0;
  for i := 0 to count - 1 do
  begin
    // добавляем текстуру и её мипы
    w2 := TMaterialTexture(List[i]).FWidth;
    h2 := TMaterialTexture(List[i]).FHeight;
    {if (w2 <= 0) or (h2 <= 0) then
      Ошибон }
    maxLod[i] := -1;
    indInTexList[i] := iter;
    while True do
    begin
      texList.Add(TAtlasItem.Create(texPacker.AddTexture(w2, h2, Border, List[i]), w2, h2));
      if maxLod[i] = -1 then
        isMip[iter] := False
      else
        isMip[iter] := True;
      Inc(maxLod[i]);
      Inc(iter);
      if (w2 <= 1) and (h2 <= 1) then
      //if (w2 = 1) or (h2 = 1) then
        Break;
      w2 := (w2 + 1) div 2;
      h2 := (h2 + 1) div 2;
    end;
  end;

  if not texPacker.Pack() then
  begin
    texPacker.ChangeMaxSize(MaxWidth11, MaxHeight11, 1);
    if not texPacker.Pack() then
      raise Exception.Create('not enough atlas size');
  end;
  //endTexPacker;
  if Task <> nil then
    Task.BeginWork(tr('Создание атласа текстур'), texList.Count, 1);
  try
    Result.FName:=aName;
    Result.FWidth := texPacker.TexWidth;//atlaswh.w;
    Result.FHeight := texPacker.TexHeight;//atlaswh.h;
    Result.FDepth := 1;
    InvSize[0]:=1.0 / Result.FWidth;
    InvSize[1]:=1.0 / Result.FHeight;
    InvSize[2]:=1.0 / Result.FDepth;
    Result.SetupFormat(aFormat);
    Result.AllocateData;
    j := 0;
    temp[0] := nil;
    temp[1] := nil;
    for i:=0 to texList.Count - 1 do
    begin
      tex := TMaterialTexture(texPacker.GetContent(TAtlasItem(texList[i]).tex));
      if (tex.FWidth = 0) or (tex.FHeight = 0) then continue;
      FreeAndNil(temp[j]);
      temp[j] := TMaterialTexture.Create();
      temp[j].FName:=tex.FName;
      texSize := texPacker.GetDimensions(TAtlasItem(texList[i]).tex);
      temp[j].SetupDimensions(texSize[0], texSize[1], 1);
      temp[j].SetupFormat(tex.FFormat);
      if not isMip[i] then
        tex.StretchDraw(temp[j])
      else
        temp[1 - j].StretchDraw(temp[j]);
      s := temp[j];
      tp := texPacker.GetTexPosition(TAtlasItem(texList[i]).tex);
      Result.Draw(s, tp[0], tp[1], tp[2]);
      //Заполнение границ
      for iw := 0 to texSize[0] - 1 do
      begin
        Result.WriteRGBAUnSafed(tp[0] + iw, tp[1] - 1, 0, s.readRGBAUnSafed(iw, texSize[1] - 1, 0));
        Result.WriteRGBAUnSafed(tp[0] + iw, tp[1] + texSize[1], 0, s.readRGBAUnSafed(iw, 0, 0));
      end;
      for ih := 0 to texSize[1] - 1 do
      begin
        Result.WriteRGBAUnSafed(tp[0] - 1, tp[1] + ih, 0, s.ReadRGBAUnSafed(texsize[0] - 1, ih, 0));
        Result.WriteRGBAUnSafed(tp[0] + texSize[0], tp[1] + ih, 0, s.ReadRGBAUnSafed(0, ih, 0));
      end;
      Result.WriteRGBAUnSafed(tp[0] - 1, tp[1] - 1, 0, s.ReadRGBAUnSafed(texsize[0] - 1, texsize[1] - 1, 0));
      Result.WriteRGBAUnSafed(tp[0] + texSize[0], tp[1] - 1, 0, s.ReadRGBAUnSafed(0, texsize[1] - 1, 0));
      Result.WriteRGBAUnSafed(tp[0] - 1, tp[1] + texSize[1], 0, s.ReadRGBAUnSafed(texSize[0] - 1, 0, 0));
      Result.WriteRGBAUnSafed(tp[0] + texSize[0], tp[1] + texSize[1], 0, s.ReadRGBAUnSafed(0, 0, 0));
      //end Заполнение границ
      j := 1 - j;
      if Task <> nil then
        Task.IncrementProgress;
    end;
    FreeAndNil(temp[0]);
    FreeAndNil(temp[1]);
    for i := 0 to Count - 1 do
    begin
      s := TMaterialTexture(List[i]);
      d:=TAtlasMaterialTexture(Result.AtlasContent.New(TAtlasMaterialTexture, s.FName));
      d.FWidth:=s.FWidth;
      d.FHeight:=s.FHeight;
      d.FDepth:=s.FDepth;
      d.SetupFormat(aFormat);
      d.FRowPitch:=Result.FRowPitch;
      d.FDepthPitch:=Result.FDepthPitch;
      d.FWxH:=Result.FWxH;
      d.FDataSize:=0;
      tp := texPacker.GetTexPosition(TAtlasItem(texList[indInTexList[i]]).tex);
      d.FData:=Result.GetAddressOf(tp[0], tp[1], tp[2]);
      {for j := 0 to 2 do
      begin
        d.TextureAtlasPositionAndScale.Index[j]:=(tp[j])* InvSize[j];
      end;
      d.TextureAtlasPositionAndScale.Scale[0]:=(d.FWidth)* InvSize[0];
      d.TextureAtlasPositionAndScale.Scale[1]:=(d.FHeight)* InvSize[1];}
      for k := 0 to maxLod[i] do
      begin
        texInd := indInTexList[i] + k;
        tp := texPacker.GetTexPosition(TAtlasItem(texList[texInd]).tex);
        for j := 0 to 2 do
        begin
          d.TextureAtlasPositionAndScale[wmWrap].IndexArr[k][j]:=tp[j] * InvSize[j];
        end;
        d.TextureAtlasPositionAndScale[wmWrap].ScaleArr[k][0]:=TAtlasItem(texList[texInd]).w * InvSize[0];
        d.TextureAtlasPositionAndScale[wmWrap].ScaleArr[k][1]:=TAtlasItem(texList[texInd]).h * InvSize[1]; 
        for j := 0 to 2 do
        begin
          d.TextureAtlasPositionAndScale[wmClamp].IndexArr[k][j]:=(tp[j] + 0.5) * InvSize[j];
        end;
        d.TextureAtlasPositionAndScale[wmClamp].ScaleArr[k][0]:=(TAtlasItem(texList[texInd]).w - 1) * InvSize[0];
        d.TextureAtlasPositionAndScale[wmClamp].ScaleArr[k][1]:=(TAtlasItem(texList[texInd]).h - 1) * InvSize[1];
      end;
      for wm :=Low(TTextureWrapMode) to High(TTextureWrapMode) do
      begin
        d.TextureAtlasPositionAndScale[wm].MaxLod:=maxLod[i];
        d.TextureAtlasPositionAndScale[wm].TexelScale:=d.FWidth * d.FHeight;
        d.TextureAtlasPositionAndScale[wm].TexelSize[0]:=0.5 / d.FWidth;
        d.TextureAtlasPositionAndScale[wm].TexelSize[1]:=0.5 / d.FHeight;
      end;
    end;
    texPacker.Free();
    for i := 0 to texList.Count - 1 do
    begin
      TAtlasItem(texList[i]).Free();
    end;
    texList.Free();
    //Result.CreateMips;
    for i:=0 to Result.AtlasContent.Count - 1 do
      TAtlasMaterialTexture(Result.AtlasContent.List[i]).SetMipmapDataFromAtlas(Result);
  finally
    if Task <> nil then
      Task.EndWork;
  end;
end;

function TMaterialTextures.CreateHardAtlas(aName: string; MaxWidth,
  MaxHeight, Border: Integer; Task: TSSTask): cardinal;
begin
//continue here
  Result := 0;
end;

function TMaterialTextures.Texture(
  const aIndex: Integer): TMaterialTexture;
begin
  Result:=TMaterialTexture(List[aIndex]);
end;

procedure TMaterialTextures.DeleteUnusedTextures;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
  begin
    if (Texture(i).WeakRefs <> nil) then
    begin
      if Texture(i).WeakRefs.IsEmpty then
      begin
        Delete(i);
      end
    end
    else
      Delete(i);
  end;
end;

procedure TMaterialTextures.AddUnique(const t: TMaterialTexture);
begin
  if inherited IndexOf(t) = -1 then
    Add(t);
end;

{ TMaterialTexture }

constructor TMaterialTexture.Create;
begin
  FGUIDLabel := TGUIDLabel.Create(Self);
  inherited;
end;

destructor TMaterialTexture.Destroy;
begin
  ClearData;
  FProvider.Free;
  inherited;
end;

class function TMaterialTexture.Lerp(const a, b: single;
  t: single): single;
begin
  Result:=a + (b - a) * t;
end;

class function TMaterialTexture.Lerp(const a, b: TAffineVector;
  t: single): TAffineVector;
begin
  Result[0]:=a[0] + (b[0] - a[0]) * t;
  Result[1]:=a[1] + (b[1] - a[1]) * t;
  Result[2]:=a[2] + (b[2] - a[2]) * t;
end;

function TMaterialTexture.GetBilinearInterpolatedValue(
  pos: TAffineVector; var Value: TVector): boolean;
var
  x, y, z, dx: single;
  v1, v2: TVector;
  px, py, pz: integer;
begin
  if GetTextureData(FFormat, FData, FDataSize) then
  begin
//    SubtractVector(pos, FUVWOffset);
    x:=pos[0] * FWidth - 0.5;
    y:=pos[1] * FHeight - 0.5;
    z:=pos[2] * FDepth;
    px:=floor(x);
    py:=floor(y);
    pz:=floor(z);
    dx:=x - px;
    v1:=Lerp(ReadVector(px, py, pz), ReadVector(px + 1, py, pz), dx);
    v2:=Lerp(ReadVector(px, py + 1, pz), ReadVector(px + 1, py + 1, pz), dx);
    Value:=Lerp(v1, v2, y - py);
    Result:=true;
  end
  else
    Result:=false;
end;

class function TMaterialTexture.Lerp(const a, b: TVector;
  t: single): TVector;
begin
  Result[0]:=a[0] + (b[0] - a[0]) * t;
  Result[1]:=a[1] + (b[1] - a[1]) * t;
  Result[2]:=a[2] + (b[2] - a[2]) * t;
  Result[3]:=a[3] + (b[3] - a[3]) * t;
end;

procedure TMaterialTexture.LoadFromFile(filename: string; aPreloadData: Boolean);
begin
  FProvider.Free;
//  FProvider:=TFileTextureDataSource.Create(filename);
  FProvider:=TMemoryTextureDataSource.CreateFromFile(filename);
  FSourceName := filename;
  FPixelHash := '';
  ClearData;
  if aPreloadData then
    PreloadTexture;
end;

procedure TMaterialTexture.LoadFromMemory(p: pointer; datalen: integer; aPreloadData: Boolean);
begin
  if (FProvider = nil) or (FProvider.ClassType <> TMemoryTextureDataSource) then
  begin
    FProvider.Free;
    FProvider:=TMemoryTextureDataSource.Create;
  end;
  if TMemoryTextureDataSource(FProvider).Data = nil then
    TMemoryTextureDataSource(FProvider).Data:=TMemoryStream.Create;
  with TMemoryTextureDataSource(FProvider).Data do
  begin
    Size:=datalen;
    Move(p^, Memory^, datalen);
  end;
  FPixelHash := '';
  ClearData;
  if aPreloadData then
    PreloadTexture;
end;

procedure TMaterialTexture.AllocateData;
var
  ns: integer;
begin
  ns:=(FWidth * FHeight * FDepth) * FElementSize;
  if (FDataSize < ns) or (FData = nil) then
  begin
    ReallocMem(FData, ns);
    FillChar(FData^, ns, 0);
    FDataSize:=ns;
  end;
  FOwnData:=true;
end;

procedure TMaterialTexture.SetupFormat(aFormat: TTextureDataFormat);
begin
  FFormat:=aFormat;
  FElementSize:=g_TextureFormatSize[FFormat];
  FRowPitch:=FWidth * FElementSize;
  FDepthPitch:=FWidth * FHeight * FElementSize;
  FWxH:=FWidth * FHeight;
  if FWidth <> 0 then
    FUVWOffset[0]:=0.5 / FWidth
  else
    FUVWOffset[0]:=0.0;
  if FHeight <> 0 then
    FUVWOffset[1]:=0.5 / FHeight
  else
    FUVWOffset[1]:=0.0;
  if FDepth <> 0 then
    FUVWOffset[2]:=0.5 / FDepth
  else
    FUVWOffset[2]:=0.0;
end;

function TMaterialTexture.GetTextureData(
  const RequiredFormat: TTextureDataFormat; var data: pointer;
  var datalen: integer; aCreateMips: Boolean): boolean;
begin
  if RequiredFormat = FFormat then
  begin
    Result:=true;
    data:=FData;
    datalen:=FDataSize;
  end
  else
    Result:=false;
end;

procedure TMaterialTexture.Draw(aTexture: TMaterialTexture; x, y,
  z: integer);
var
  i, j, k: integer;
  color: TRGBA;
begin
  for k:=0 to aTexture.FDepth - 1 do
    for j:=0 to aTexture.FHeight - 1 do
      for i:=0 to aTexture.FWidth - 1 do
      begin
        color:=aTexture.ReadRGBAUnSafed(i, j, k);
        WriteRGBASafed(x + i, y + j, z + k, color);
      end;
end;

function TMaterialTexture.GetAddressOf(x, y, z: integer): pointer;
begin
  Result:=pointer(Integer(FData) + x * FElementSize + y * FRowPitch + z * FDepthPitch);
end;

function TMaterialTexture.SampleLinear2d(const uvw: TAffineVector): TVector;
begin
  if not GetBilinearInterpolatedValue(uvw, Result) then
    Result:=NullHmgVector;
end;

procedure TMaterialTexture.LoadFromMemory(stm: TMemoryStream; aPreloadData: Boolean);
begin
  if (FProvider = nil) or (FProvider.ClassType <> TMemoryTextureDataSource) then
  begin
    FProvider.Free;
    FProvider:=TMemoryTextureDataSource.Create;
  end;
  TMemoryTextureDataSource(FProvider).Data:=stm;
  FPixelHash := '';
  ClearData;
  if aPreloadData then
    PreloadTexture;
end;

procedure TMaterialTexture.ActualizePicture;
begin
  if (FProvider = nil) and (FData = nil) then
  begin
    if (FProvider = nil) and (FSourceName <> '') then
    begin
      if FileExists(vPathsAreRelativeTo + FSourceName) then
      begin
        FProvider := TMemoryTextureDataSource.CreateFromFile(vPathsAreRelativeTo + FSourceName);
        TextureDataChanged;
      end;
    end;
  end;
end;

function TMaterialTexture.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
var
  aClass: TTextureDataSourceClass;
begin
  case ChildBlockType of
    btMaterialTextureDataProvider:
    begin
      aClass:=TTextureDataSourceClass(MaterialTextures.GetTypeByClassname(ChildClass));
      if (aClass = nil) {or //(aClass = TLoadFromGLImageSource)} then
        aClass:=TMemoryTextureDataSource;
      Result:=GetProvider(aClass);
      TextureDataChanged;
    end;
    btGUIDLabel           : begin
                              if GUIDLabel = nil then
                                FGUIDLabel := TGUIDLabel.Create(Self);
                              Result := GUIDLabel.GetLabel;
                            end;
  else
    Result:=CL_UNKNOWN_OBJECT;
  end;
end;

function TMaterialTexture.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btMaterialTextureName   : FName:=ReadString;
      btMaterialTextureFormat : SetupFormat(TTextureDataFormat(ReadInteger));
      btMaterialTextureWidth  : begin ReadInteger(FWidth); SetupFormat(FFormat); end;
      btMaterialTextureHeight : begin ReadInteger(FHeight); SetupFormat(FFormat); end;
      btMaterialTextureDepth  : begin ReadInteger(FDepth); SetupFormat(FFormat); end;
      btMaterialTextureData   : begin FDataSize:=Size; AllocateData; Read(FData^, FDataSize); EnsureProvider; end;
      btMaterialTextureSourceName: FSourceName := ReadString;
      btMaterialTextureImagePixelHash: FPixelHash := ReadString;
//      btMaterialTextureImageGUID: read(FGUID, SizeOf(FGUID));  //DEPRICATED
      btMaterialTextureActualizeData: ActualizePicture;
    else
      Result:=CL_UNKNOWN_PARAM;
    end;
end;

procedure TMaterialTexture.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
  s: string;
begin
  with SaveInfo, Writer do
  try
    WriteString(btMaterialTextureName, FName);
    WriteInteger(btMaterialTextureFormat, Integer(FFormat));
    WriteInteger(btMaterialTextureWidth, FWidth);
    WriteInteger(btMaterialTextureHeight, FHeight);
    WriteInteger(btMaterialTextureDepth, FDepth);

    s := FSourceName;
    if (vPathsAreRelativeTo <> '') and (Pos(vPathsAreRelativeTo, FSourceName) = 1) then
      s := ExtractRelativePath(vPathsAreRelativeTo, FSourceName);
    WriteString(btMaterialTextureSourceName, s);

    EnsureProvider;

    //if LightWeight = false then
      if FProvider = nil then
      begin
        if (FData <> nil) then
          Write(btMaterialTextureData, FData^, FDataSize);
      end
      else
      begin
        BeginChild(btMaterialTextureDataProvider, FProvider.ClassName);
        try
          FProvider.SaveObject(SaveInfo);
        finally
          EndChild;
        end;
      end;

    WriteString(btMaterialTextureImagePixelHash, FPixelHash);
    if GUIDLabel <> nil then
      WriteChild(SaveInfo, GUIDLabel.GetLabel, btGUIDLabel);
  except
    on e: exception do
      SaveInfo.Error('TMaterialTexture: ' + e.Message);
  end;
end;

function TMaterialTexture.GetProvider(
  ProviderClass: TTextureDataSourceClass): TTextureDataSource;
begin
  if (FProvider = nil) or (FProvider.ClassType <> ProviderClass) then
  begin
    FProvider.Free;
    FProvider:=ProviderClass.Create;
  end;
  Result:=FProvider;
end;

function SwapRGB(const a: TRGB): TRGB;overload;
begin
  Result.r:=a.b;
  Result.g:=a.g;
  Result.b:=a.r;
end;

function SwapRGB(const a: TRGBA): TRGBA;overload;
begin
  Result.r:=a.b;
  Result.g:=a.g;
  Result.b:=a.r;
  Result.a:=a.a;
end;

procedure SaveMip(filename: string; var mip: TTextureMipMap; format: TTextureDataFormat);
var
  b: Graphics.TBitmap;
  i, j: integer;
  p32s, p32d: PRGBAArray;
  p24s, p24d: PRGBArray;
begin
  b:=Graphics.TBitmap.Create;
  case format of
    tdf32bit:
    begin
      b.PixelFormat:=pf32bit;
      b.Width:=mip.w;
      b.Height:=mip.h;
      for j:=0 to b.Height - 1 do
      begin
        p32d:=b.ScanLine[j];
        p32s:=PRGBAArray(Integer(mip.data) + mip.rowpitch * j);
        for i:=0 to b.Width - 1 do
          p32d[i]:=SwapRGB(p32s[i]);
      end;
    end;
    tdf24bit:
    begin
      b.PixelFormat:=pf24bit;
      b.Width:=mip.w;
      b.Height:=mip.h;
      for j:=0 to b.Height - 1 do
      begin
        p24d:=b.ScanLine[j];
        p24s:=PRGBArray(Integer(mip.data) + mip.rowpitch * j);
        for i:=0 to b.Width - 1 do
          p24d[i]:=SwapRGB(p24s[i]);
      end;
    end;
  end;
  b.SaveToFile(filename);
  b.Free;
end;

procedure TMaterialTexture.StretchDraw(Src, Dst: TTextureMipMap);
var
  x, y: Integer;
  dx0, dx, dy: Single;
  px, py: Single;
  v: TVector;
begin
  dx:=Src.w/Dst.w;
  dy:=Src.h/Dst.h;
  dx0:=(dx-1.0)*0.5;
  px:=dx0;
  py:=(dy-1.0)*0.5;
  for y:=0 to Dst.h-1 do begin
    for x:=0 to Dst.w-1 do begin
      //v:=GetBilinearValue2D(px, py, 0, Src);
      //v:=GetBiquadraticValue2DPixelSpace(px, py, 0, Src);
      v:=GetBicubicValue2DPixelSpace(px, py, 0, Src, WRAP_CUT);
      WriteRGBAUnSafed(x, y, 0, Dst, VectorToRGBA(Saturate(v)));
      px:=px+dx;
    end;
    px:=dx0;
    py:=py+dy;
  end;
end;

procedure TMaterialTexture.StretchDraw(Dst: TMaterialTexture);
var
  x, y: Integer;
  dx0, dx, dy: Single;
  px, py: Single;
  v: TVector;
begin
  dx:=FWidth/Dst.FWidth;
  dy:=FHeight/Dst.FHeight;
  dx0:=(dx-1.0)*0.5;
  px:=dx0;
  py:=(dy-1.0)*0.5;
  for y:=0 to Dst.FHeight-1 do begin
    for x:=0 to Dst.FWidth-1 do begin
      //v:=GetBilinearValue2D(px, py, 0, Src);
      //v:=GetBiquadraticValue2DPixelSpace(px, py, 0, Src);
      v:=GetBicubicValue2DPixelSpace(px, py, 0, WRAP_CUT);

      Dst.WriteRGBAUnSafed(x, y, 0, VectorToRGBA(Saturate(v)));
      px:=px+dx;
    end;
    px:=dx0;
    py:=py+dy;
  end;
end;

function TMaterialTexture.GetBilinearValue2DPixelSpace(x, y, z: Single; var Mip: TTextureMipMap; WrapMode: TWrapMode): TVector;
var
  dx, dy: Single;
  v1, v2: TVector;
  px, py, pz: integer;
begin
  if Mip.data <> nil then
  begin
    px:=floor(x);
    py:=floor(y);
    pz:=Round(z);
    dx:=x-px;
    dy:=y-py;

    v1:=Lerp(ReadVector(px, py,   pz, Mip, WrapMode), ReadVector(px+1, py,   pz, Mip, WrapMode), dx);
    v2:=Lerp(ReadVector(px, py+1, pz, Mip, WrapMode), ReadVector(px+1, py+1, pz, Mip, WrapMode), dx);
    Result:=Lerp(v1, v2, dy);
  end
  else
    Result:=NullHmgVector;
end;

function TMaterialTexture.GetBiquadraticValue2DPixelSpace(x, y, z: Single; var Mip: TTextureMipMap; WrapMode: TWrapMode): TVector;
var
  px, py, pz, i, j: integer;
  dx, dy: single;
  ka, kb, kc, ca, cb, cc: single;
  vec: array[-1..1, -1..1] of TVector;
begin
  if Mip.data <> nil then
  begin
    px:=round(x);
    py:=round(y);
    pz:=round(z);
    dx:=x - px;
    dy:=y - py;
    ka:=sqr(dx - 0.5) * 0.5;
    kb:=0.75 - dx * dx;
    kc:=ka + dx;
    ca:=sqr(dy - 0.5) * 0.5;
    cb:=0.75 - dy * dy;
    cc:=ca + dy;
    for i:=-1 to 1 do
      for j:=-1 to 1 do
        vec[i, j]:=ReadVector(px + i, py + j, pz, Mip, WrapMode);
    for i:=0 to 3 do
      Result[i]:=
        Ca * (Ka * vec[-1, -1][i] + Kb * vec[0, -1][i] + Kc * vec[1, -1][i]) +
        Cb * (Ka * vec[-1,  0][i] + Kb * vec[0,  0][i] + Kc * vec[1,  0][i]) +
        Cc * (Ka * vec[-1,  1][i] + Kb * vec[0,  1][i] + Kc * vec[1,  1][i]);
  end
  else
    Result:=NullHmgVector;
end;

procedure TMaterialTexture.CreateMips;
  procedure ComputePitches(var mip: TTextureMipMap);
  begin
    mip.wxh:=mip.w * mip.h;
    mip.rowpitch:=mip.w * FElementSize;
    mip.depthpitch:=mip.rowpitch * mip.h;
  end;
var
  i, n: integer;
  //tmp: TTextureMipMap;
begin
  DestroyMips;
  if (FWidth > 0) and (FHeight > 0) then
  begin
    n:=Trunc(Math.Max(Math.Max(Log2(FWidth), Log2(FHeight)), Log2(FDepth)));
    SetLength(FMips, n + 1);
    FillChar(FMips[0], Length(FMips) * sizeof(FMips[0]), 0);
    FMips[0].w:=FWidth;
    FMips[0].h:=FHeight;
    FMips[0].d:=FDepth;
    FMips[0].data:=FData;
    ComputePitches(FMips[0]);
    for i:=1 to n do
    begin
      FMips[i].w:=Max(1, Round(FMips[i - 1].w * 0.5));
      FMips[i].h:=Max(1, Round(FMips[i - 1].h * 0.5));
      FMips[i].d:=Max(1, Round(FMips[i - 1].d * 0.5));
      if FOwnData then
        GetMem(FMips[i].data, FMips[i].w * FMips[i].h * FMips[i].d * FElementSize)
      else
      begin
        FMips[i].data:=nil;
        continue;
      end;
      ComputePitches(FMips[i]);
      //tmp:=GaussFilter(0.0{0.4}, FMips[i-1]);
      //StretchDraw(tmp, FMips[i]);
      StretchDraw(FMips[i-1], FMips[i]);
      //FreeMem(tmp.data);
    end;
{    for i:=0 to n do
    begin
      ForceDirectories('c:\debug1\' + ExtractFileName(FName));
      SaveMip('c:\debug1\' + ExtractFileName(FName) + '\mip_' + IntToStr(i) + '.bmp', FMips[i], FFormat);
    end;}
  end;
end;

function TMaterialTexture.GetBilinearInterpolatedValue(pos: TVector;
  var Value: TVector; WrapMode: TWrapMode): boolean;
var
  maxmip, mip: integer;
  fmip, t: single;
  v1, v2: TVector;
begin
  if GetTextureData(FFormat, FData, FDataSize) then
  begin
    maxmip:=High(FMips);
    if maxmip < 0 then
      Result:=GetBilinearInterpolatedValue(TVectorCoords(pos).XYZ, Value)
    else
    begin
      fmip:=Math.Min(maxmip, pos[3]);
      mip:=Floor(fmip);
      t:=fmip-mip;
      if (t = 0) then
        Result:=GetBilinearInterpolatedValue(TVectorCoords(pos).XYZ, mip, Value, WrapMode)
      else
      begin
        if GetBilinearInterpolatedValue(TVectorCoords(pos).XYZ, mip, v1, WrapMode) and
          GetBilinearInterpolatedValue(TVectorCoords(pos).XYZ, mip + 1, v2, WrapMode) then
        begin
          Result:=true;
          Value:=Lerp(v1, v2, t);
        end
        else
          Result:=false;
      end;
    end;
  end
  else
    Result:=false;
end;

function TMaterialTexture.GetBilinearInterpolatedValue(pos: TAffineVector;
  mip: integer; var Value: TVector; WrapMode: TWrapMode): boolean;
var
  x, y, z: single;
begin
  if GetTextureData(FFormat, FData, FDataSize) and (FMips <> nil) and (FMips[mip].data <> nil) then
  begin
    x:=pos[0] * FMips[mip].w - 0.5;
    y:=pos[1] * FMips[mip].h - 0.5;
    z:=pos[2] * FMips[mip].d;

    Value:=GetBilinearValue2DPixelSpace(x, y, z, FMips[mip], WrapMode);
    Result:=true;
  end
  else
    Result:=false;
end;

function TMaterialTexture.ReadVector(x, y, z: integer; WrapMode: TWrapMode): TVector;
var
  c: TRGBA;
const
  k: Single = 1.0 / 255.0;
begin
  case WrapMode of
    WRAP_NONE:  c:=ReadRGBAUnSafed(x, y, z);
    WRAP_CUT:   c:=ReadRGBACut(x, y, z);
    WRAP_FLOOR: c:=ReadRGBAWrap(x, y, z);
    WRAP_BLACK: c:=ReadRGBATrunc(x, y, z);
  else
    raise Exception.Create('Unknown wrap mode');
  end;
  Result[0]:=c.r * k;
  Result[1]:=c.g * k;
  Result[2]:=c.b * k;
  Result[3]:=c.a * k;
end;

function TMaterialTexture.ReadVector(x, y, z: integer;
  var mip: TTextureMipMap; WrapMode: TWrapMode): TVector;
var
  c: TRGBA;
const
  k: Single = 1.0 / 255.0;
begin
  case WrapMode of
    WRAP_NONE:  c:=ReadRGBAUnSafed(x, y, z, mip);
    WRAP_CUT:   c:=ReadRGBACut(x, y, z, mip);
    WRAP_FLOOR: c:=ReadRGBAWrap(x, y, z, mip);
    WRAP_BLACK: c:=ReadRGBATrunc(x, y, z, mip);
  else
    raise Exception.Create('Unknown wrap mode');
  end;
  Result[0]:=c.r * k;
  Result[1]:=c.g * k;
  Result[2]:=c.b * k;
  Result[3]:=c.a * k;
end;

procedure TMaterialTexture.DestroyMips;
var
  i: integer;
begin
  for i:=High(FMips) downto 1 do // до 0 нельзя, т.к. 0 указывает на себя
    FreeMem(FMips[i].data);
  FMips:=nil;
end;

function TMaterialTexture.SampleLinear2d(const uvwl: TVector): TVector;
begin
  if not GetBilinearInterpolatedValue(uvwl, Result) then
    Result:=NullHmgVector;
end;

function TMaterialTexture.GetTextureSize(mipLevel: integer): TTextureSize;
begin
  GetTextureData(FFormat, FData, FDataSize);
  if (FMips <> nil) and (mipLevel > -1) and (mipLevel < Length(FMips)) then
  begin
    Result.width:=FMips[mipLevel].w;
    Result.height:=FMips[mipLevel].h;
    Result.depth:=FMips[mipLevel].d;
  end
  else
    FillChar(Result, sizeof(Result), 0);
end;

function cubicFilter(const w: TDVector; const c0, c1, c2, c3: single): double;overload;
begin
  Result:=c0 * w[0] + c1 * w[1] + c2 * w[2] + c3 * w[3];
end;

function cubicFilter(const w: TDVector; const c0, c1, c2, c3: TVector): TVector;overload;
begin
  Result[0]:=cubicFilter(w, c0[0], c1[0], c2[0], c3[0]);
  Result[1]:=cubicFilter(w, c0[1], c1[1], c2[1], c3[1]);
  Result[2]:=cubicFilter(w, c0[2], c1[2], c2[2], c3[2]);
  Result[3]:=cubicFilter(w, c0[3], c1[3], c2[3], c3[3]);
end;

function computeWeights(x: single): TDVector;
const
  A: TDMatrix = ((0, 1, 0, 0), (-1/3, -0.5, 1, -1/6), (0.5, -1, 0.5, 0), (-1/6, 0.5, -0.5, 1/6));
  B: TDMatrix = ((1, 0, 0, 0), (0, 0, 1, 0), (-3, 3, -2, -1), (2, -2, 1, 1));
var
  xv: TDVector;
begin
  xv[0]:=1;
  xv[1]:=x;
  xv[2]:=x*x;
  xv[3]:=xv[2] * x;
  Result:=VectorTransform(xv, A);
end;

function TMaterialTexture.GetBicubicInterpolatedValue(pos: TAffineVector;
  mip: integer; var Value: TVector; WrapMode: TWrapMode): boolean;
var
  x, y, z: single;
begin
  if GetTextureData(FFormat, FData, FDataSize) and (FMips <> nil) and (FMips[mip].data <> nil) then
  begin
    x:=pos[0] * FMips[mip].w - 0.5;
    y:=pos[1] * FMips[mip].h - 0.5;
    z:=pos[2] * FMips[mip].d;
    Value:=GetBicubicValue2DPixelSpace(x, y, z, FMips[mip], WrapMode);
    Result:=true;
  end
  else
    Result:=false;
end;

function TMaterialTexture.GetBiquadraticInterpolatedValue(pos: TAffineVector;
  mip: integer; var Value: TVector; WrapMode: TWrapMode): boolean;
var
  x, y, z: single;
begin
  if GetTextureData(FFormat, FData, FDataSize) and (FMips <> nil) and (FMips[mip].data <> nil) then
  begin
    x:=pos[0] * FMips[mip].w - 0.5;
    y:=pos[1] * FMips[mip].h - 0.5;
    z:=pos[2] * FMips[mip].d;

    Value:=GetBiquadraticValue2DPixelSpace(x, y, z, FMips[mip], WrapMode);

    Result:=true;
  end
  else
    Result:=false;
end;

procedure TMaterialTexture.TextureDataChanged;
begin
  if FOwnData then
    FreeMem(FData);
  FData:=nil;
  SetLength(FMips, 0);
  FWidth:=0;
  FHeight:=0;
  FDepth:=0;
  FDataSize:=0;
  FElementSize:=0;
  FRowPitch:=0;
  FDepthPitch:=0;
  FWxH:=0;
  FOwnData:=false;
end;

procedure TMaterialTexture.PreloadTexture;
begin
  if (FData = nil) and (FProvider <> nil) then
    GetTextureData(FFormat, FData, FDataSize);
end;

function TMaterialTexture.ReadPixel(x, y, mip: integer): TVector;
begin
  if FMips = nil then
    Result:=NullHmgVector
  else
    Result:=ReadVector(x, y, 0, FMips[Clamp(mip, 0, High(FMips))]);
end;

procedure TMaterialTexture.ExtractTextureTo(bmp: Graphics.TBitmap; aFormat: TTextureDataFormat;
  mipLevel: integer);
var
  i, j: integer;
  p24: PRGBArray;
  p32: PRGBAArray;
  NeedRelease: Boolean;
begin
  NeedRelease := (FData = nil);
  //предполагается, что FData всегда имеет формат tdf32bit
  if Assigned(bmp) and GetTextureData(FFormat, FData, FDataSize, (mipLevel > 0)) then
  try
    if (FMips <> nil) and (mipLevel > 0) and (mipLevel < Length(FMips)) then
    begin
      with GetTextureSize(mipLevel) do
      begin
        bmp.Width := width;
        bmp.Height := height;
      end;

      if (aFormat = tdf32bit) then
      begin
        bmp.PixelFormat := pf32Bit;
        for j:=0 to bmp.Height - 1 do
        begin
          p32:=bmp.Scanline[j];
          for i:=0 to bmp.Width - 1 do
            p32[i]:=RGBAToBGRA(ReadRGBAUnSafed(i, j, 0, FMips[mipLevel]));
        end;
      end
      else
      begin
        bmp.PixelFormat := pf24Bit;
        for j:=0 to FHeight - 1 do
        begin
          p24 := bmp.ScanLine[j];
          for i:=0 to FWidth - 1 do
            p24[i] := RGBAToBGR(ReadRGBAUnSafed(i, j, 0, FMips[mipLevel]));
        end;
      end;
    end
    else
    begin
      if (aFormat = tdf32bit) then
      begin
        bmp.PixelFormat := pf32Bit;
        bmp.Width := FWidth;
        bmp.Height := FHeight;
        for j:=0 to FHeight - 1 do
        begin
          p32 := bmp.ScanLine[j];
          for i:=0 to FWidth - 1 do
            p32[i] := RGBAToBGRA(ReadRGBAUnSafed(i, j, 0));
        end;
      end
      else
      begin
        bmp.PixelFormat := pf24Bit;
        bmp.Width := FWidth;
        bmp.Height := FHeight;
        for j:=0 to FHeight - 1 do
        begin
          p24 := bmp.ScanLine[j];
          for i:=0 to FWidth - 1 do
            p24[i] := RGBAToBGR(ReadRGBAUnSafed(i, j, 0));
        end;
      end;
    end;
  finally
    if NeedRelease then
      ClearData;
  end;
end;

function TMaterialTexture.NumberOfMips: integer;
begin
  if GetTextureData(FFormat, FData, FDataSize) then
    Result:=Length(FMips)
  else
    Result:=0;
end;

procedure TMaterialTexture.ClearData;
begin
  DestroyMips;
  if FOwnData then
    FreeMem(FData);
  FData:=nil;
  FWidth:=0;
  FHeight:=0;
  FDepth:=0;
  FDataSize:=0;
  FDepthPitch:=0;
  FRowPitch:=0;
  FWxH:=0;
end;

function TMaterialTexture.CalcPixelHashFromData: string;
begin
  Result := md5buf(FData^, FDataSize, 2);
end;

function TMaterialTexture.GetPixelHash(aForce: Boolean): string;
var
  NeedRelease: Boolean;
  //f: TFileStream;
begin
  if (FPixelHash = '') or aForce then
  try
    NeedRelease := FData = nil;
    if GetTextureData(tdf32bit, FData, FDataSize, False) then
    {
    f := TFileStream.Create('c:\debug1\1\x2.bin', fmCreate);
    try
      f.Write(FData^, FDataSize)
    finally
      f.Free;
    end;
    }
    begin
      FPixelHash := CalcPixelHashFromData;
      if NeedRelease then
          ClearData;
    end;
  except
  end;
  Result := FPixelHash;
end;

function TMaterialTexture.GaussFilter(t: Single;
  Src: TTextureMipMap): TTextureMipMap;
var
  Kernel: array [-1..+1] of array [-1..+1] of Single;
  procedure ComputePitches(var mip: TTextureMipMap);
  begin
    mip.wxh:=mip.w * mip.h;
     mip.rowpitch:=mip.w * FElementSize;
     mip.depthpitch:=mip.rowpitch * mip.h;
  end;
 procedure CalcGauss(t: Single);
 var
   i, j: Integer;
   s: Single;
   k: array [-1..1] of Single;
 begin
   s:=2*t+1;
   k[0]:=1/s;
   k[+1]:=(1-k[0])*0.5;
   k[-1]:=k[+1];
   for j:=-1 to 1 do
     for i:=-1 to 1 do
       Kernel[i, j]:=k[i]*k[j];
 end;
 function GetPixelKernel(x,y,z: Integer): TRGBA;
 var
   i, j: Integer;
   c, a: TVector;
 begin
   a:=NullHmgVector;
   for j:=-1 to 1 do begin
     for i:=-1 to 1 do begin
       c:=RGBAToVector(ReadRGBACut(x+i, y+j, 0, Src));
       ScaleVector(c, Kernel[i, j]);
       a:=VectorAdd(a, c);
     end;
   end;
   Result:=VectorToRGBA(Saturate(a));
 end;
var
  x, y: Integer;
begin
  Result.w:=Max(1, Src.w);
  Result.h:=Max(1, Src.h);
  Result.d:=1;
  GetMem(Result.data, Result.w * Result.h * Result.d * FElementSize);
  ComputePitches(Result);
  CalcGauss(t);
  for y:=0 to Result.h-1 do begin
    for x:=0 to Result.w-1 do begin
      WriteRGBAUnSafed(x, y, 0, Result, GetPixelKernel(x, y, 0));
    end;
  end;
end;

function TMaterialTexture.GenSobelKernel(Width: Integer): TsKernel;
var
  x, y, a, b, c: Integer;
begin
  SetLength(Result, Width);
  for x:=0 to Width-1 do
    SetLength(Result[x], Width);

  for x:=0 to Width div 2 - 1 do begin
    for y:=0 to Width-1 do begin
      a:=y+1;
      b:=Width-y;
      c:=Min(a, b)+x;
      Result[y,x]:=-c;
      Result[y,Width-x-1]:=+c;
    end;
  end;
end;

function TMaterialTexture.FilterRGBA(F: TRGBAFilter): TTextureMipMap;
var
  x, y: Integer;
begin
  Result.w:=FWidth;
  Result.h:=FHeight;
  Result.d:=1;
  Result.wxh:=FWxH;
  Result.rowpitch:=FRowPitch;
  Result.depthpitch:=FDepthPitch;
  GetMem(Result.data, Result.w * Result.h * Result.d * FElementSize);

  for y:=0 to FHeight-1 do begin
    for x:=0 to FWidth-1 do begin
      WriteRGBAUnSafed(x, y, 0, Result, F(ReadRGBAUnSafed(x, y, 0)));
    end;
  end;
end;

procedure TMaterialTexture.CopyTo(dst: IChangableSampler);
var
  x, y: Integer;
begin
  dst.SetupDimensions(FWidth, FHeight, FDepth);

  for y:=0 to FHeight-1 do begin
    for x:=0 to FWidth-1 do begin
      dst.WriteRGBAUnSafed(x, y, 0, ReadRGBAUnSafed(x, y, 0));
    end;
  end;
end;

procedure TMaterialTexture.GenNormalMap(BorderRadius, BorderWidth, BorderScale, MapWidth, MapHeight, Scale: Single;
  KernelType: Integer; dst: IChangableSampler; NoMips: boolean; SobelDisabled: Boolean; EnableV: boolean; EnableH: boolean;
  CombinePix: Integer);
var
  tmp0: TTextureMipMap;
begin
  if not SobelDisabled then
  begin
    dst.SetupDimensions(FWidth, FHeight, FDepth);
    tmp0:=FilterRGBA(grayRGB);
    dst.GenerateSobelNormalMapNxN(KernelType, Scale, @tmp0, -1, +1);
    FreeMem(tmp0.data);
  end
  else
    CopyTo(dst);

  dst.DrawBorderOnNormalMap(BorderRadius, BorderWidth, BorderScale, MapWidth, MapHeight, False, -1, +1, EnableV, EnableH, CombinePix);
  if not NoMips then
    dst.CreateMips;
end;

procedure TMaterialTexture.GenerateSobelNormalMapNxN(FilterWidth: Integer; Scale: Real; MipMap: pointer;
  SignV: integer; SignH: integer);
var
  Src: TTextureMipMap;
  SobelKernel: TsKernel;

  procedure Normalize(var SobelKernel: TsKernel);
  var
    Width, x, y: Integer;
    total, inv: Single;
  begin
    total:=0;
    Width:=Length(SobelKernel);
    for x:=0 to Width-1 do begin
      for y:=0 to Width-1 do begin
        total:=total+abs(SobelKernel[y,x]);
      end;
    end;
    inv:=1/total;
    for x:=0 to Width-1 do begin
      for y:=0 to Width-1 do begin
        SobelKernel[y,x]:=SobelKernel[y,x]*inv;
      end;
    end;
  end;

  function _GetNormal(Width, x, y: Integer; Scale: Single): TAffineVector;
  var
    i, j, c, hW: Integer;
    dx, dy: Single;
  const
    s = 1 / 255;
  begin
    hW:=Width div 2;
    x:=x - hW;
    y:=y - hW;
    dx:=0;
    dy:=0;
    for j:=0 to Width - 1 do
      for i:=0 to Width - 1 do
      begin
        c:=Self.ReadRGBACut(x+i, y+j, 0, Src).b;
        dx:=dx + SobelKernel[j,i]*c;
        dy:=dy + SobelKernel[i,j]*c;
      end;
    Result[0]:=-Scale*dx*s;
    Result[1]:= Scale*dy*s;
    Result[2]:=1;
    NormalizeVector(Result);
  end;

var
  x, y: Integer;
  Normal: TAffineVector;
  c0: TRGBA;
begin
  if Scale=0.0 then
  begin
    c0:=NormalToRGBA(ZVector);
    for y:=0 to FHeight-1 do
      for x:=0 to FWidth-1 do
        WriteRGBAUnSafed(x, y, 0, c0);
  end
  else
  begin
    Src:=PTextureMipmap(mipmap)^;
    FilterWidth:=Max(3, FilterWidth);
    SobelKernel:=GenSobelKernel(FilterWidth);
    Normalize(SobelKernel);

    for y:=0 to FHeight-1 do
      for x:=0 to FWidth-1 do
      begin
        Normal:=_GetNormal(FilterWidth, x, y, Scale);
        Normal[0]:=Normal[0] * SignH;
        Normal[1]:=Normal[1] * SignV;
        WriteRGBAUnSafed(x, y, 0, NormalToRGBA(Normal));
      end;
  end;

  FreeAndNil(FProvider);
end;

procedure TMaterialTexture.DebugDrawBorderPattern(x, y, w, h: integer; BorderRadius, BorderWidth, BorderScale: single;
  img: TCanvas; Mode: integer);
var
  BorderPattern: TsPattern;
  i, j, pos, txtWidth, Count: integer;
  Scale, sw: single;
  s: string;
begin
  BorderWidth:=Math.min(BorderWidth, BorderRadius);
  Count:=GenBorderPatternEx(BorderRadius, w, BorderRadius, BorderWidth, BorderScale, BorderPattern, false);

  if Assigned(BorderPattern)and(Count > 1) then begin
    if (Round(w*BorderPattern[Count-1][1])>h)
      then sw:=h/(BorderPattern[Count-1][1])
      else sw:=w;
    case Mode of
      0: begin //режим рисования эллипса
          img.MoveTo(x, y);
          img.LineTo(x + Round(sw*BorderPattern[0][0]), y);
          for i:=0 to Count-1 do begin
            img.LineTo(x + Round(sw*BorderPattern[i][0]), y - Round(sw*BorderPattern[i][1]));
          end;
          img.Pen.Color:=clBlack;
          img.Pen.Width:=1;
          s:=Format('%4.1f', [BorderRadius])+tr(' мм ');
          txtWidth:=img.TextWidth(s);
          j:=Round(sw*BorderPattern[0][0]);
          if (txtWidth+20)<j
            then pos:=((j - txtWidth) div 2)
            else pos:=j+10;
          img.TextOut(x + pos, y - 5, s);
      end;
      1: begin //режим рисования кромки
          img.MoveTo(x, y - Round(sw*BorderPattern[0][1]));
          for i:=0 to Count-1 do begin
            img.LineTo(x + Round(sw*BorderPattern[i][0]), y - Round(sw*BorderPattern[i][1]));
          end;
          img.Pen.Color:=clBlack;
          img.Pen.Width:=1;
          s:=Format('%4.1f', [BorderWidth])+tr(' мм ');
          txtWidth:=img.TextWidth(s);
          j:=Round(sw*BorderPattern[0][0]);
          if (txtWidth+20)<j
            then pos:=((j - txtWidth) div 2)
            else pos:=j+10;
          img.TextOut(x + pos, y - Round(sw*BorderPattern[0][1]) - 5, s);
      end;
    end;
  end;
end;

function TMaterialTexture.GenBorderPatternEx(mmSize, pxSize, BorderRadius, BorderWidth, BorderScale: single;
  var BorderPattern: TsPattern; aOutNormals: boolean): integer;
var
  i, Count: Integer;
  TexelSize, sx, step: Single;
begin
  result:=0;
  if (BorderRadius > 0) and (BorderWidth > 0) and (BorderScale > 0) and (mmSize > 0) and (pxSize > 0) then begin
    TexelSize:=mmSize / pxSize; //считаем размер текселя в мм
    step:=TexelSize / BorderRadius;
    sx:=step * 0.5;
    Count:=Trunc(BorderWidth / TexelSize);
    SetLength(BorderPattern, Count);
    for i:=Count - 1 downto 0 do
    begin
      if aOutNormals then
      begin //генерировать нормали
        BorderPattern[i][0]:=sx;
        BorderPattern[i][1]:=sqrt(1 - sx * sx) / BorderScale;
        NormalizeVector(BorderPattern[i]);
      end else
      begin //генерировать точки профиля
        BorderPattern[i][0]:=sx;
        BorderPattern[i][1]:=sqrt(1 - sx * sx) * BorderScale;
      end;
      sx:=sx + step;
    end;
    result:=Count;
  end;
end;

procedure TMaterialTexture.DrawBorderOnNormalMap(BorderRadius, BorderWidth, BorderScale, MapWidth, MapHeight: Single;
  SmoothEdge: Boolean;
  SignV: integer;
  SignH: integer;
  EnableV: boolean;
  EnableH: boolean;
  CombinePix: Integer);
var
  PatternV, PatternH, PatternC: TsPattern;
  Mask: array of Single;

  procedure VectorLerp(const V1: TAffineVector; var V2: TAffineVector; t: Single);
  var
    s: Single;
  begin
    s:=1 - t;
    V2[0]:=(s * V1[0]) + (t * V2[0]);
    V2[1]:=(s * V1[1]) + (t * V2[1]);
    V2[2]:=(s * V1[2]) + (t * V2[2]);
  end;
  procedure CombineNormalsEx(V1: TAffineVector; var V2: TAffineVector; a: Single);
  begin
    VectorLerp(AffineVectorMake(0,0,5), V1, a);
    NormalizeVector(V1);
    CombineNormals(V1, V2);
  end;
  //отрисовать горизонтальный бордюр
  procedure DrawBorderH(ky, sign: Integer);
  var
    x, y, offset, oy, BLenX, BLenY: Integer;
    V, Normal: TAffineVector;
    s: Double;
  begin
    s := 1;
    BLenX:=Length(PatternV);
    BLenY:=Length(PatternH);
    if (FWidth>0)and(FHeight>0)and(BLenY>0) then
    begin
      offset:=0;
      if ky > 0 then
        offset:=FHeight - 1;
      for y:=0 to BLenY-1 do
      begin
        oy:=offset - ky * y;
        Normal[0]:=0;
        Normal[1]:=sign * ky * PatternH[y][0];
        Normal[2]:=PatternH[y][1];
        if CombinePix = 1 then s:=y / BLenY;
        for x:=BLenX to FWidth-BLenX-1 do
        begin
          V:=Normal;
          case CombinePix of
            1: CombineNormalsEx(RGBAToNormal(ReadRGBAUnSafed(x, oy, 0)), V, s);
            2: CombineNormals(RGBAToNormal(ReadRGBAUnSafed(x, oy, 0)), V);
            //3: CombineNormalsM(RGBAToNormal(ReadRGBAUnSafed(x, oy, 0)), V);
          end;
          WriteRGBAUnSafed(x, oy, 0, NormalToRGBA(V));
        end;
      end;
    end;
  end;
  //отрисовать вертикальный бордюр
  procedure DrawBorderV(kx, sign: Integer);
  var
    x, y, ox, offset, BLenX, BLenY: Integer;
    V, Normal: TAffineVector;
    s: Double;
  begin
    s := 1;
    BLenX:=Length(PatternV);
    BLenY:=Length(PatternH);
    if (FWidth>0)and(FHeight>0)and(BLenX>0) then
    begin
      offset:=0;
      if kx > 0 then
        offset:=FWidth - 1;
      for x:=0 to BLenX - 1 do
      begin
        ox:=offset - kx * x;
        Normal[0]:=sign * kx * PatternV[x][0];
        Normal[1]:=0;
        Normal[2]:=PatternV[x][1];
        if CombinePix = 1 then s:=x / BLenX;
        for y:=BLenY to FHeight-BLenY-1 do
        begin
          V:=Normal;
          case CombinePix of
            1: CombineNormalsEx(RGBAToNormal(ReadRGBAUnSafed(ox, y, 0)), V, s);
            2: CombineNormals(RGBAToNormal(ReadRGBAUnSafed(ox, y, 0)), V);
            //3: CombineNormalsM(RGBAToNormal(ReadRGBAUnSafed(ox, y, 0)), V);
          end;
          WriteRGBAUnSafed(ox, y, 0, NormalToRGBA(V));
        end;
      end;
    end;
  end;
  //отрисовать угол
  procedure DrawBorderC(dx, dy, kx, ky, signX, signY: Integer);
  var
    x, y, ox, oy, offsetX, offsetY, BLenX, BLenY: Integer;
    V, Normal: TAffineVector;
    s: Double;
  begin
    BLenX:=Length(PatternV);
    BLenY:=Length(PatternH);
    offsetX:=0;
    if kx>0 then
      offsetX:=BLenX-1;
    offsetY:=0;
    if ky>0 then
      offsetY:=BLenY-1;
    for y:=0 to BLenY - 1 do
    begin
      oy:=offsetY - ky * y;
      for x:=0 to BLenX - 1 do
      begin
        ox:=offsetX - kx * x;
        V:=PatternC[ox + BLenX * oy];
        V[0]:=signX*kx*V[0];
        V[1]:=signY*ky*V[1];
        case CombinePix of
          1: CombineNormalsEx(RGBAToNormal(ReadRGBAUnSafed(x+dx, y+dy, 0)), V, Mask[ox + BLenX * oy]);
          2: CombineNormals(RGBAToNormal(ReadRGBAUnSafed(x+dx, y+dy, 0)), V);
          //3: CombineNormalsM(BGRAToNormal(ReadRGBAUnSafed(x+dx, y+dy, 0)), V);
        end;
        WriteRGBAUnSafed(x+dx, y+dy, 0, NormalToRGBA(V));
      end;
    end;
  end;
  //сгенерировать угловой паттерн
  procedure GenBorderPatternC;
  var
    x, y, BLenX, BLenY: Integer;
    Normal1, Normal2: TAffineVector;
    xs, ys, ysq: Single;
  begin
    BLenX:=Length(PatternV);
    BLenY:=Length(PatternH);
    SetLength(PatternC, BLenX*BLenY);
    SetLength(Mask, BLenX*BLenY);
    for y:=0 to BLenY - 1 do
    begin
      Normal1[0]:=0;
      Normal1[1]:=PatternH[y][0];
      Normal1[2]:=PatternH[y][1];
      ys:=y/BLenY;
      ysq:=Sqr(1-ys);
      for x:=0 to BLenX - 1 do
      begin
        xs:=x/BLenX;
        Mask[x + BLenX * y]:=max(0.0, 1.0 - Sqrt(Sqr(1-xs) + ysq));

        Normal2[0]:=PatternV[x][0];
        Normal2[1]:=0;
        Normal2[2]:=PatternV[x][1];

        if SmoothEdge then
          CombineNormals(Normal1, Normal2)
        else
          if (xs-ys>0.0) then Normal2:=Normal1;
        PatternC[x + BLenX * y]:=Normal2;
      end;
    end;
  end;
  {procedure GenBorderPattern(mmSize: single; pxSize: integer);
  var
    i: Integer;
    TexelSize, sx, step: Single;
  begin
    TexelSize:=mmSize / pxSize; //считаем размер текселя в мм
    step:=TexelSize / BorderRadius;
    sx:=step * 0.5;
    BorderWidthI:=Trunc(BorderWidth / TexelSize);
    SetLength(BorderPattern, BorderWidthI);
    for i:=BorderWidthI - 1 downto 0 do
    begin
      BorderPattern[i][0]:=sx;
      BorderPattern[i][1]:=sqrt(1 - sx * sx) * BorderScale;
      NormalizeVector(BorderPattern[i]);
      sx:=sx + step;
    end;
  end;}
begin
  if (BorderRadius > 0) and (BorderWidth > 0) and (BorderScale > 0) and (MapWidth > 0) and (EnableV or EnableH) then
  begin
    BorderWidth:=ClampValue(BorderWidth, 0, Math.min(MapWidth, MapHeight)/2);
    BorderWidth:=Math.min(BorderWidth, BorderRadius);

    if EnableV then
      GenBorderPatternEx(MapWidth, FWidth, BorderRadius, BorderWidth, BorderScale, PatternV);
    if EnableH then
      GenBorderPatternEx(MapHeight, FHeight, BorderRadius, BorderWidth, BorderScale, PatternH);

    //отрисовать вертикальные бордюры
    DrawBorderV(+1, SignH);
    DrawBorderV(-1, SignH);

    //отрисовать горизонтальные бордюры
    DrawBorderH(+1, SignV);
    DrawBorderH(-1, SignV);

    //отрисовать уголки
    GenBorderPatternC;
    DrawBorderC(FWidth-Length(PatternV), FHeight-Length(PatternH), 1, 1, SignH, SignV); //UP RIGHT
    DrawBorderC(0, FHeight-Length(PatternH), -1, 1, SignH, SignV); //UP LEFT
    DrawBorderC(FWidth-Length(PatternV), 0, 1, -1, SignH, SignV); //UP RIGHT
    DrawBorderC(0, 0, -1, -1, SignH, SignV); //DOWN LEFT

    FreeAndNil(FProvider);
  end;
end;

function TMaterialTexture.GetBicubicValue2DPixelSpace(x, y, z: Single;
  var Mip: TTextureMipMap; WrapMode: TWrapMode): TVector;
var
  dx, dy: single;
  px, py, pz, i, j: integer;
  vec: array[0..3, 0..3] of TVector;
  t: array[0..3] of TVector;
  wx, wy: TDVector;
begin
  if Mip.data <> nil then
  begin
    px:=floor(x);
    py:=floor(y);
    pz:=Round(z);
    dx:=x-px;
    dy:=y-py;

    for j:=0 to 3 do
      for i:=0 to 3 do
         vec[j, i]:=ReadVector(px + i - 1, py + j - 1, pz, Mip, WrapMode);

    wx:=computeWeights(dx);
    wy:=computeWeights(dy);

    t[0]:=cubicFilter(wx, vec[0][0], vec[0][1], vec[0][2], vec[0][3]);
    t[1]:=cubicFilter(wx, vec[1][0], vec[1][1], vec[1][2], vec[1][3]);
    t[2]:=cubicFilter(wx, vec[2][0], vec[2][1], vec[2][2], vec[2][3]);
    t[3]:=cubicFilter(wx, vec[3][0], vec[3][1], vec[3][2], vec[3][3]);

    Result:=cubicFilter(wy, t[0], t[1], t[2], t[3]);
  end
  else
    Result:=NullHmgVector;
end;

function TMaterialTexture.GetBicubicValue2DPixelSpace(x, y, z: Single; WrapMode: TWrapMode = WRAP_FLOOR): TVector;
var
  dx, dy: single;
  px, py, pz, i, j: integer;
  vec: array[0..3, 0..3] of TVector;
  t: array[0..3] of TVector;
  wx, wy: TDVector;
begin
  if GetTextureData(FFormat, FData, FDataSize) then
  begin
    px:=floor(x);
    py:=floor(y);
    pz:=Round(z);
    dx:=x-px;
    dy:=y-py;

    for j:=0 to 3 do
      for i:=0 to 3 do
         vec[j, i]:=ReadVector(px + i - 1, py + j - 1, pz, WrapMode);

    wx:=computeWeights(dx);
    wy:=computeWeights(dy);

    t[0]:=cubicFilter(wx, vec[0][0], vec[0][1], vec[0][2], vec[0][3]);
    t[1]:=cubicFilter(wx, vec[1][0], vec[1][1], vec[1][2], vec[1][3]);
    t[2]:=cubicFilter(wx, vec[2][0], vec[2][1], vec[2][2], vec[2][3]);
    t[3]:=cubicFilter(wx, vec[3][0], vec[3][1], vec[3][2], vec[3][3]);

    Result:=cubicFilter(wy, t[0], t[1], t[2], t[3]);
  end
  else
    Result:=NullHmgVector;
end;

function TMaterialTexture.Empty: boolean;
begin
  Result:=(FProvider = nil) or (FProvider.GetData = nil);
end;

procedure TMaterialTexture.WriteRGBAUnSafed(x, y, z: integer; const color: TRGBA);
begin
  case FFormat of
    tdf32bit: PRGBAArray(FData)[z*FWxH + y*FWidth + x]:=color;
    tdf24bit: PRGBArray (FData)[z*FWxH + y*FWidth + x]:=color.rgb;
    tdf8bit:  PByteArray(FData)[z*FWxH + y*FWidth + x]:=color.r;
  else
    raise Exception.Create('can''t read value - unsupported texture format');
  end;
end;

procedure TMaterialTexture.WriteRGBAUnSafed(x, y, z: integer;
  var mip: TTextureMipMap; const color: TRGBA);
begin
  case FFormat of
    tdf32bit: PRGBAArray(mip.data)[z*mip.wxh + y*mip.w + x]:=color;
    tdf24bit: PRGBArray (mip.data)[z*mip.wxh + y*mip.w + x]:=color.rgb;
    tdf8bit:  PByteArray(mip.data)[z*mip.wxh + y*mip.w + x]:=color.r;
  else
    raise Exception.Create('can''t write value - unsupported texture format');
  end;
end;

procedure TMaterialTexture.WriteRGBASafed(x, y, z: integer;
  const color: TRGBA);
begin
  if (x > -1) and (y > -1) and (z > -1) and (x < FWidth) and (y < FHeight) and (z < FDepth) then
    WriteRGBAUnSafed(x, y, z, color);
end;

procedure TMaterialTexture.WriteRGBASafed(x, y, z: integer;
  var mip: TTextureMipMap; const color: TRGBA);
begin
  if (x > -1) and (y > -1) and (z > -1) and (x < mip.w) and (y < mip.h) and (z < mip.d) then
    WriteRGBAUnSafed(x, y, z, mip, color);
end;

function TMaterialTexture.ReadRGBAUnSafed(x, y, z: integer): TRGBA;
begin
  Result.value:=0;
  case FFormat of
    tdf32bit: Result      :=PRGBAArray(FData)[z*FWxH + y*FWidth + x];
    tdf24bit: Result.rgb  :=PRGBArray (FData)[z*FWxH + y*FWidth + x];
    tdf8bit:  Result.value:=PByteArray(FData)[z*FWxH + y*FWidth + x];
  else
    raise Exception.Create('can''t read value - unsupported texture format');
  end;
end;

function TMaterialTexture.ReadRGBAUnSafed(x, y, z: integer;
  var mip: TTextureMipMap): TRGBA;
begin
  Result.value:=0;
  case FFormat of
    tdf32bit: Result      :=PRGBAArray(mip.data)[z*mip.wxh + y*mip.w + x];
    tdf24bit: Result.rgb  :=PRGBArray (mip.data)[z*mip.wxh + y*mip.w + x];
    tdf8bit:  Result.value:=PByteArray(mip.data)[z*mip.wxh + y*mip.w + x];
  else
    raise Exception.Create('can''t read value - unsupported texture format');
  end;
end;

function TMaterialTexture.ReadRGBACut(x, y, z: integer): TRGBA;
begin
  if (FWidth = 0) or (FHeight = 0) or (FDepth = 0) or (FData = nil) then
    Result.value:=0
  else
  begin
    x:=Clamp(x, FWidth-1);
    y:=Clamp(y, FHeight-1);
    z:=Clamp(z, FDepth-1);

    Result:=ReadRGBAUnSafed(x, y, z);
  end;
end;

function TMaterialTexture.ReadRGBACut(x, y, z: integer; var mip: TTextureMipMap): TRGBA;
begin
  x:=Clamp(x, mip.w-1);
  y:=Clamp(y, mip.h-1);
  z:=Clamp(z, mip.d-1);

  Result:=ReadRGBAUnSafed(x, y, z, mip);
end;

function TMaterialTexture.ReadRGBAWrap(x, y, z: integer): TRGBA;
begin
  if (FWidth = 0) or (FHeight = 0) or (FDepth = 0) or (FData = nil) then
    Result.value:=0
  else
  begin
    if x>=0
      then x:=(x mod FWidth)
      else x:=FWidth+((x+1) mod FWidth)-1;

    if y>=0
      then y:=(y mod FHeight)
      else y:=FHeight+((y+1) mod FHeight)-1;

    if z>=0
      then z:=(z mod FDepth)
      else z:=FDepth+((z+1) mod FDepth)-1;

    Result:=ReadRGBAUnSafed(x, y, z);
  end;
end;

function TMaterialTexture.ReadRGBAWrap(x, y, z: integer; var mip: TTextureMipMap): TRGBA;
begin
  if x>=0
    then x:=(x mod mip.w)
    else x:=mip.w+((x+1) mod mip.w)-1;

  if y>=0
    then y:=(y mod mip.h)
    else y:=mip.h+((y+1) mod mip.h)-1;

  if z>=0
    then z:=(z mod mip.d)
    else z:=mip.d+((z+1) mod mip.d)-1;

  Result:=ReadRGBAUnSafed(x, y, z, mip);
end;

function TMaterialTexture.ReadRGBATrunc(x, y, z: integer): TRGBA;
begin
  if (x > -1) and (y > -1) and (z > -1) and (x < FWidth) and (y < FHeight) and (z < FDepth) then
    Result:=ReadRGBAUnSafed(x, y, z)
  else
    Result.value:=0;
end;

function TMaterialTexture.ReadRGBATrunc(x, y, z: integer;
  var mip: TTextureMipMap): TRGBA;
begin
  if (x > -1) and (y > -1) and (z > -1) and (x < mip.w) and (y < mip.h) and (z < mip.d) then
    Result:=ReadRGBAUnSafed(x, y, z, mip)
  else
    Result.value:=0;
end;

procedure TMaterialTexture.SetupDimensions(Width, Height, Depth: Integer; DoAllocateData: boolean);
begin
  //ClearData;
  FWidth:=Width;
  FHeight:=Height;
  FDepth:=Depth;
  SetupFormat(FFormat);
  if DoAllocateData then
    AllocateData;
end;

function TMaterialTexture.GetResourceName: string;
begin
  Result:=FName;
end;

function TMaterialTexture.GetFilename: string;
begin
{  if AnsiLowerCase(ExtractFileExt(FName)) = '.nm' then
    Result:='.nm'
  else}
    Result:=ChangeFileExt(ExtractFileName(FName), DetectExt(true));
end;

procedure TMaterialTexture.SaveToStream(const Stm: TStream);
begin
  if (FProvider = nil) or (FProvider.GetData = nil) then
    if FData <> nil then
      with GetAsJpg(100) do
      try
        SaveToStream(stm);
      finally
        Free;
      end
    else
      raise Exception.Create('No texture data')
  else
    Stm.CopyFrom(FProvider.GetData, 0);
end;

procedure TMaterialTexture.SaveToStreamPng(const Stm: TStream);
var
  image: TGPImage;
  bmp: Graphics.TBitmap;
  aptr: IStream;
  encoderClsid: TGUID;
  stream: TMemoryStream;
  aptrN: Int64;
begin
  if (FProvider = nil) or (FProvider.GetData = nil) then
    if FData <> nil then
    begin
      stream := TMemoryStream.Create();
      image := nil;
      bmp := nil;
      try
        bmp := GetAsBmp();
        stream.Seek(0, 0);
        bmp.SaveToStream(stream);
        stream.Seek(0, 0);
        aptr := TStreamAdapter.Create(stream, soReference) as IStream;
        aptr.Seek(0, 0, aptrN);
        image := TGPImage.Create(aptr);
        aptr := nil;
        Stm.Seek(0, 0);
        aptr := TStreamAdapter.Create(Stm, soReference) as IStream;
        GetEncoderClsid('image/png', encoderClsid);
        image.Save(aptr, encoderClsid);
        aptr.Seek(0, 0, aptrN);
        Stm.Seek(0, 0);
      finally   
        aptr := nil;
        stream.Free();
        bmp.Free();
        image.Free();
      end;
    end
    else
      raise Exception.Create('No texture data')
  else
    Stm.CopyFrom(FProvider.GetData, 0);
end;

function TMaterialTexture.DetectExt(ForceLowLevel: boolean): string;
  function LowLevelDetect: string;
  var
    Signature: cardinal;
  begin
    if (FProvider = nil) or (FProvider.GetData = nil) then
      Result:=''
    else
    begin
      FProvider.GetData.Position:=0;
      FProvider.GetData.Read(Signature, 4);
      Result:=DetectExt(Signature);
    end;
  end;
begin
  if ForceLowLevel then
  begin
    Result:=LowLevelDetect;
    if Result <> '' then
      exit;
  end;
  if (FProvider = nil) or (FProvider.GetData = nil) then
    if FData <> nil then
      Result:='.png'
    else
      Result:=''
  else
  begin
    Result:=ExtractFileExt(ExtractFileName(FName));
    if Result = '' then
      Result:=LowLevelDetect;
  end;
end;

function TMaterialTexture.GetAsJpg(Quality: TJPEGQualityRange): TJpegImage;
var
  bmp: Graphics.TBitmap;
  i, j: integer;
  p: PRGBA;
begin
  Result:=TJpegImage.Create;
  if GetTextureData(FFormat, FData, FDataSize) then
  try
    bmp:=Graphics.TBitmap.Create;
    try
      bmp.PixelFormat:=pf32Bit;
      bmp.Width:=FWidth;
      bmp.Height:=FHeight;
      for j:=0 to FHeight - 1 do
      begin
        p:=bmp.ScanLine[j];//FHeight - 1 - j];
        for i:=0 to FWidth - 1 do
        begin
          p^:=RGBAToBGRA(ReadRGBAUnSafed(i, j, 0));
          inc(p);
        end;
      end;

      if (bmp.Height = 1) then
      begin
        bmp.Height:=2;
        p:=bmp.ScanLine[1];
        for i:=0 to FWidth - 1 do
          p^:=RGBAToBGRA(ReadRGBAUnSafed(i, 0, 0));;
      end;

      Result.Assign(bmp);
      Result.CompressionQuality:=Quality;
      Result.Compress;
      Result.JPEGNeeded;
    finally
      bmp.Free;
    end;
  finally
    ClearData;
  end;
end;

function TMaterialTexture.GetAsBmp(aFormat: TTextureDataFormat): Graphics.TBitmap;
begin
  Result := Graphics.TBitmap.Create;
  ExtractTextureTo(Result, aFormat);
end;

class function TMaterialTexture.DetectExt(signature: cardinal): string;
begin
  case Signature and $FFFF of
    $4949, $4D4D: Result:='.tif';
    $4D42: Result:='.bmp';
    $D8FF: Result:='.jpg';
  else
    case Signature of
      $38464947: Result:='.gif';
      $474E5089: Result:='.png';
    else
      Result:='';
    end;
  end;
end;

procedure TMaterialTexture.GetSize(var Width, Height, Depth: Integer);
begin
  PreloadTexture;
  Width:=FWidth;
  Height:=FHeight;
  Depth:=FDepth;
end;
{
procedure TMaterialTexture.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.Attributes['Name']:=FName;
    root.Attributes['Format']:=FFormat;
    root.Attributes['Width']:=FWidth;
    root.Attributes['Height']:=FHeight;
    root.Attributes['Depth']:=FDepth;

    if FProvider = nil then
    begin
      if Assigned(FData) then
        root.Attributes['Data']:=EncodeBase64Utf(FData^, FDataSize);
    end
    else
      FProvider.SaveToXml(root.AddChild('DataProvider'), SaveFlags);
  end;
end;
}
procedure TMaterialTexture.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.GetOrCreateAttr('Name').Value := AnsiToUtf8(FName);
    root.GetOrCreateAttr('Format').ValueAsInteger := Ord(FFormat);
    root.GetOrCreateAttr('Width').ValueAsInteger := FWidth;
    root.GetOrCreateAttr('Height').ValueAsInteger := FHeight;
    root.GetOrCreateAttr('Depth').ValueAsInteger := FDepth;

    if FProvider = nil then
    begin
      if Assigned(FData) then
        root.GetOrCreateAttr('Data').Value := EncodeBase64Utf(FData^, FDataSize);
    end
    else
      FProvider.SaveToXml(root.NodeNew('DataProvider'), SaveFlags);
  end;
end;
{
procedure TMaterialTexture.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
var
  s: string;
  node: IXMLNode;
begin
  if assigned(root) then
  begin
    if root.HasAttribute('Name') then
      FName:=root.Attributes['Name'];
    if root.HasAttribute('Width') then
      FWidth:=root.Attributes['Width'];
    if root.HasAttribute('Height') then
      FHeight:=root.Attributes['Height'];
    if root.HasAttribute('Depth') then
      FDepth:=root.Attributes['Depth'];
    if root.HasAttribute('Format') then
      SetupFormat(TTextureDataFormat(root.Attributes['Format']));

    if root.HasAttribute('Data') then
    begin
      s:=DecodeBase64Utf(root.Attributes['Data']);
      FDataSize:=length(s);
      AllocateData;
      move(s[1], FData^, FDataSize);
      CreateMips;
    end;

    node := root.ChildNodes.FindNode('DataProvider');
    if Assigned(node) then
    begin
      if node.HasAttribute('FileName') then
        FProvider:=TFileTextureDataSource.Create('')
      else
        FProvider:=TMemoryTextureDataSource.Create;

      FProvider.LoadFromXml(node, LoadFlags);
      TextureDataChanged;
      PreloadTexture;
    end;
  end;
end;
}
procedure TMaterialTexture.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
var
  s: string;
  node: TXMLNode;
begin
  if assigned(root) then
  begin
    if root.HasAttribute('Name') then
    begin
      FName := Utf8ToAnsi(root.AttributeByName['Name'].Value);
      //s := ExtractFilePath(ExcludeTrailingBackSlash(root.Document.Filename)) + 'Maps\' + FName;
      //if FileExists(s) then
      //  FSourceName := s;
    end;
    if root.HasAttribute('Width') then
      FWidth := root.AttributeByName['Width'].ValueAsInteger;
    if root.HasAttribute('Height') then
      FHeight := root.AttributeByName['Height'].ValueAsInteger;
    if root.HasAttribute('Depth') then
      FDepth := root.AttributeByName['Depth'].ValueAsInteger;
    if root.HasAttribute('Format') then
      SetupFormat(TTextureDataFormat(root.AttributeByName['Format'].ValueAsInteger));

    if root.HasAttribute('Data') then
    begin
      s := DecodeBase64Utf(root.AttributeByName['Data'].Value);
      FDataSize:=length(s);
      AllocateData;
      move(s[1], FData^, FDataSize);
      CreateMips;
    end;

    node := root.FindNode('DataProvider');
    if Assigned(node) then
    begin
      if node.HasAttribute('GUID') then
        FProvider := TGUIDedTextureDataSource.Create
      else
        if node.HasAttribute('FileName') then
          FProvider:=TFileTextureDataSource.Create('')
        else
          FProvider:=TMemoryTextureDataSource.Create;

      FProvider.LoadFromXml(node, LoadFlags);
      TextureDataChanged;
      //PreloadTexture;
    end;
  end;
end;

function TMaterialTexture.GetTextureObjType: integer;
begin
  Result := texSingleTexture;
end;

function TMaterialTexture.EqualTo(t: TObject): boolean;
begin
  Result := (t is TMaterialTexture) and
  (FFormat = TMaterialTexture(t).FFormat) and
  (FWidth = TMaterialTexture(t).FWidth) and
  (FHeight = TMaterialTexture(t).FHeight) and
  (FDepth = TMaterialTexture(t).FDepth) and
  (FDataSize = TMaterialTexture(t).FDataSize);

  if Result then
  begin
    if ((FProvider = nil)and(TMaterialTexture(t).FProvider = nil)) then
    begin         
      Result := (md5util.md5buf(FData^, FDataSize) = md5buf(TMaterialTexture(t).FData^, FDataSize));
    end
    else
    begin
      if (FProvider <> nil) then
        Result := FProvider.EqualTo(TMaterialTexture(t).FProvider)
      else
        Result := False;
    end;
  end;
end;

const mgTextureHash = $33445566;
      GUIDLabelMagic = $ACE0FBAC;
      
procedure TMaterialTexture.WriteToFiler(WriteInfo: TWriteInfo);
begin
  with WriteInfo do
  begin
    writer.WriteString(FName);
    writer.Write(FWidth, sizeof(FWidth));
    writer.Write(FHeight, sizeof(FHeight));
    writer.Write(FDepth, sizeof(FDepth));
    writer.Write(FFormat, sizeof(FFormat));

    EnsureProvider;

    writer.WriteBoolean(Assigned(FProvider));
    if FProvider <> nil then
      FProvider.WriteToFiler(WriteInfo);

    writer.WriteMagic(mgTextureHash);
    writer.WriteString(FPixelHash);
    if GUIDLabel <> nil then
    begin
      Writer.WriteMagic(GUIDLabelMagic);
      (GUIDLabel as IBufferedStreamIO).WriteToFiler(WriteInfo);
    end;
  end;
end;

procedure TMaterialTexture.ReadFromFiler(ReadInfo: TReadInfo);
var
  s: string;
  aType: integer;
begin
  with ReadInfo do
  begin
    FName:=Reader.ReadString;
    reader.Read(FWidth, sizeof(FWidth));
    reader.Read(FHeight, sizeof(FHeight));
    reader.Read(FDepth, sizeof(FDepth));
    reader.Read(FFormat, sizeof(FFormat));
    SetupFormat(FFormat);

    if not reader.ReadBoolean then //without provider
    begin
{      if reader.ReadBoolean then //with assigned data
      begin
        s:=DecodeBase64Utf(reader.ReadString);
        FDataSize:=length(s);
        AllocateData;
        move(s[1], FData^, FDataSize);
      end;}
    end
    else
    begin
      reader.Read(aType, sizeof(aType));
      case aType of
        0: FProvider:=TMemoryTextureDataSource.Create;
        1: FProvider:=TFileTextureDataSource.Create('');
      else
        FProvider:=TGUIDedTextureDataSource.Create;
      end;

      FProvider.ReadFromFiler(ReadInfo);
      TextureDataChanged;
    end;

    if reader.CheckMagic(mgTextureHash) then
      FPixelHash := reader.ReadString;

    if (Reader.CheckMagic(GUIDLabelMagic)) then
    begin
      if GUIDLabel = nil then
        FGUIDLabel := TGUIDLabel.Create(Self);
      (GUIDLabel as IBufferedStreamIO).ReadFromFiler(ReadInfo);
    end;
  end;
end;

procedure TMaterialTexture.Assign(const src: TMaterialTexture);
var
  data: pointer;
  dataLen: Integer;
begin
  if Assigned(src.Provider) then
  begin
    FName:=src.FName;
    FSourceName:=src.FSourceName;
    FWidth:=src.FWidth;
    FHeight:=src.FHeight;
    FDepth:=1;
    SetupFormat(src.FFormat);
    FProvider := src.Provider.GetCopy;
    FPixelHash := src.FPixelHash;
  end
  else
    if src.GetTextureData(src.FFormat, data, dataLen) then
    begin
      FName:=src.FName;
      FSourceName:=src.FSourceName;
      FWidth:=src.FWidth;
      FHeight:=src.FHeight;
      FDepth:=1;
      SetupFormat(src.FFormat);
      AllocateData;
      Move(data^, FData^, dataLen);
      CreateMips;
      FPixelHash := src.FPixelHash;
    end;
end;

function TMaterialTexture.Clone: TMaterialTexture;
begin
  Result := TMaterialTexture(TMaterialTextureClass(ClassType).Create);
  Result.Assign(Self);
end;

procedure TMaterialTexture.ApplySRGBCorrection(aGamma: Single; aMakeProvider: Boolean);
  function ConvertChannel(const src: Byte; gamma: Single = 2.4): Byte;
  var
    color: Single;
  begin
    color := src / 255;
    if color < 0.04045 then
      color := color / 12.92
    else
      color := Power((color + 0.055) / 1.055, gamma);
    if color > 1 then
      color := 1
    else
    if color < 0 then
      color := 0;
    Result := Round(255 * color);
  end;
var
  x, y: Integer;
  c: TRGBA;
begin
  PreloadTexture;
  for y:=0 to FHeight - 1 do
    for x:=0 to FWidth - 1 do
    begin
      c := ReadRGBAUnSafed(x, y, 0);
      c.R := ConvertChannel(c.R, aGamma);
      c.G := ConvertChannel(c.G, aGamma);
      c.B := ConvertChannel(c.B, aGamma);
      WriteRGBAUnSafed(x, y, 0, c);
    end;
  if aMakeProvider then
    EnsureProvider(True);
end;

procedure TMaterialTexture.SetProvider(const Value: TTextureDataSource);
begin
  FProvider.Free;
  FPixelHash := '';
  FProvider:=Value;
  ClearData;
end;

function TMaterialTexture.GetSamplerObject: TObject;
begin
  Result:=self;
end;

function TMaterialTexture.GetTextureID: string;
begin
  Result := GetPixelHash;
  {
  Result:=FTextureName;
  if Result='' then
  begin
    if Provider is TFileTextureDataSource then
      Result:=ExtractFileName(TFileTextureDataSource(Provider).FFilename);
  end; }
end;

constructor TMaterialTexture.CreateNamed(const aName: string);
begin
  Create;
  FName:=aName;
end;

procedure TMaterialTexture.SaveToFile(filename: string);
var
  f: TFileStream;
begin
  if ((FProvider = nil) or (FProvider.GetData = nil)) and (FData = nil) then
    raise Exception.Create('No texture data');

  if (FProvider = nil) or (FProvider.GetData = nil) then
  begin
    if Assigned(FData) then
      filename := ChangeFileExt(filename, '.jpg')
  end
  else
    filename := ChangeFileExt(filename, DetectExt(true));

  f := TFileStream.Create(filename, fmCreate);
  try
    SaveToStream(f);
  finally
    f.Free;
  end;
end;

procedure TMaterialTexture.ExecCommand(cmd: cardinal;
  params: TCommandParams);
begin
  case cmd of
    cImagePack: if (params is TImagePackParams) and (Provider is TMemoryTextureDataSource) then
      TImagePackParams(params).Pack(TMemoryTextureDataSource(Provider).Data);
    cHasGUIDedResource:
      if Assigned(params) and HasGUID then
        params.Done := True;
    cFindTextureByID:
      if (params is TFindObjectParams) and (AnsiCompareText(TFindObjectParams(params).ID, TextureID) = 0) then
      begin
        TFindObjectParams(params).Found := Self;
        params.Done := True;
      end;
  end;
  if Assigned(FProvider) then
    FProvider.ExecCommand(cmd, params);
end;

function TMaterialTexture.GetTextureName: string;
begin
  Result := FName;
end;

procedure TMaterialTexture.SetTextureID(const Value: string);
begin
  FPixelHash := Value;
end;

function TMaterialTexture.HasGUID: Boolean;
begin
  Result := FProvider is TGUIDedTextureDataSource;
end;

procedure TMaterialTexture.EnsureProvider(aForce: Boolean);
var
  ds: TMemoryTextureDataSource;
  hash: string;
begin
  if ((FProvider = nil) or aForce) and (FData <> nil) then
  begin
    //считаю хэш заранее, чтобы потом не распаковывать png
    hash := GetPixelHash(True);
    with GetAsPng do
    try
      ds := TMemoryTextureDataSource.Create;
      ds.Data := TMemoryStream.Create;
      SaveToStream(ds.GetData);
      Provider := ds;
      FPixelHash := hash;
    finally
      Free;
    end;
  end;
end;

function TMaterialTexture.DestFilename(aAllowNativeName: Boolean): string;
begin
  if aAllowNativeName and (SourceName <> '') then
    Result := ChangeFileExt(SourceName, DetectExt(true))
  else
    Result := TextureID + DetectExt(true);
end;

{ TFileTextureDataSource }

constructor TFileTextureDataSource.Create(aFilename: string);
begin
  inherited Create;
  FFilename:=aFilename;
end;

destructor TFileTextureDataSource.Destroy;
begin
  FStream.Free;
  FIntData.Free;
  inherited;
end;

function TFileTextureDataSource.EqualTo(t: TTextureDataSource): boolean;
begin
  Result:=(t is TFileTextureDataSource) and
  (FFilename = TFileTextureDataSource(t).FFilename);
  //тут надо будет допилить условия /?
end;

function TFileTextureDataSource.GetCopy: TTextureDataSource;
begin
  Result := TFileTextureDataSource.Create(FFilename);
end;

function TFileTextureDataSource.GetData: TStream;
begin
  if (FStream = nil) and FileExists(FFilename) then
    OpenFile(FFilename);
  if (FStream = nil) and (FIntData <> nil) then
  begin
    FIntData.Position:=0;
    Result:=FIntData;
    exit;
  end;
  if FStream <> nil then
    FStream.Position:=0;
  Result:=FStream;
end;

function TFileTextureDataSource.HasData: boolean;
begin
  Result:=assigned(FStream);
end;
{
procedure TFileTextureDataSource.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
var
  s: string;
begin
  if assigned(root) then
  begin
    if root.HasAttribute('FileName') then
      OpenFile(root.Attributes['FileName']);

    FIntData.Free;
    s:=DecodeBase64Utf(root.Text);
    FIntData:=TMemoryStream.Create;
    FIntData.Size:=Length(s);
    Move(s[1], FIntData.Memory^, Length(s));
  end;
end;
}
procedure TFileTextureDataSource.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
var
  s: string;
begin
  if assigned(root) then
  begin
    if root.HasAttribute('FileName') then
      OpenFile(Utf8ToAnsi(root.AttributeByName['FileName'].Value));

    FIntData.Free;
    s:=DecodeBase64Utf(root.Value);
    FIntData:=TMemoryStream.Create;
    FIntData.Size:=Length(s);
    Move(s[1], FIntData.Memory^, Length(s));
  end;
end;

function TFileTextureDataSource.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btFileTextureDataSourceFilename: OpenFile(Filename);
      btFileTextureDataSourceData:
      begin
        if FIntData = nil then
          FIntData:=TMemoryStream.Create;
        FIntData.Size:=Size;
        Read(FIntData.Memory^, Size);
      end;
    else
      Result:=CL_UNKNOWN_PARAM;
    end;
end;

procedure TFileTextureDataSource.OpenFile(filename: string);
begin
  if (FFilename <> filename) or (FStream = nil) then
  begin
    FFilename:=filename;
    FStream.Free;
    if FileExists(filename) then
      FStream:=TFileStream.Create(filename, fmOpenRead or fmShareDenyWrite)
    else
      FStream:=nil;
  end;
end;

procedure TFileTextureDataSource.ReadFromFiler(ReadInfo: TReadInfo);
var
  s: string;
begin
  with ReadInfo do
  begin
    OpenFile(Reader.ReadString);

    FIntData.Free;
    s:=DecodeBase64Utf(Reader.ReadString);
    FIntData:=TMemoryStream.Create;
    FIntData.Size:=Length(s);
    Move(s[1], FIntData.Memory^, Length(s));
  end;
end;

procedure TFileTextureDataSource.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteString(btFileTextureDataSourceFilename, Filename);
    //if not SaveInfo.LightWeight then
    //begin
      if (FIntData = nil) and (GetData <> nil) then
      begin
        FIntData:=TMemoryStream.Create;
        FIntData.Size:=GetData.Size;
        GetData.Read(FIntData.Memory^, FIntData.Size);
      end;
      if FIntData <> nil then
        Write(btFileTextureDataSourceData, FIntData.Memory^, FIntData.Size);
    //end;
  except
    on e: exception do
      SaveInfo.Error('TFileTextureDataSource: ' + e.Message);
  end;
  inherited;
end;
{
procedure TFileTextureDataSource.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.Attributes['FileName']:=Filename;
    if (FIntData = nil) and (GetData <> nil) then
    begin
      FIntData:=TMemoryStream.Create;
      FIntData.Size:=GetData.Size;
      GetData.Read(FIntData.Memory^, FIntData.Size);
    end;
    if FIntData <> nil then
      root.NodeValue := EncodeBase64Utf(FIntData.Memory^, FIntData.Size);
  end;
end;
}
procedure TFileTextureDataSource.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.GetOrCreateAttr('FileName').Value := AnsiToUtf8(Filename);
    if (FIntData = nil) and (GetData <> nil) then
    begin
      FIntData:=TMemoryStream.Create;
      FIntData.Size:=GetData.Size;
      GetData.Read(FIntData.Memory^, FIntData.Size);
    end;
    if FIntData <> nil then
      root.Value := EncodeBase64Utf(FIntData.Memory^, FIntData.Size);
  end;
end;

procedure TFileTextureDataSource.WriteToFiler(WriteInfo: TWriteInfo);
var
  aType: integer;
begin
  with WriteInfo do
  begin
    aType:=1;
    Writer.Write(aType, sizeof(aType));
    Writer.WriteString(Filename);

    if (FIntData = nil) and (GetData <> nil) then
    begin
      FIntData:=TMemoryStream.Create;
      FIntData.Size:=GetData.Size;
      GetData.Read(FIntData.Memory^, FIntData.Size);
    end;

    Writer.WriteString(EncodeBase64Utf(FIntData.Memory^, FIntData.Size));
  end;
end;

{ TGUIDedTextureDataSource }

constructor TGUIDedTextureDataSource.CreateWithGUID(const aGUID: TGUID);
begin
  inherited Create;
  FGUID := aGUID;
end;

destructor TGUIDedTextureDataSource.Destroy;
begin
  FData.Free;
  inherited;
end;

procedure TGUIDedTextureDataSource.ExecCommand(cmd: cardinal;
  params: TCommandParams);
begin
  case cmd of
    cChangeGUID:
      if (params is TChangeGUIDParams) and
      TChangeGUIDParams(params).FindGUID(FGUID) then
        FGUID := TChangeGUIDParams(params).GetNewGUID;
    cCollectGUID:
      if (params is TCollectGUIDParams) then
        TCollectGUIDParams(params).Add(FGUID);
  end;
end;

function TGUIDedTextureDataSource.GetCopy: TTextureDataSource;
begin
  Result := TGUIDedTextureDataSource.CreateWithGUID(FGUID);
end;

function TGUIDedTextureDataSource.GetData: TStream;
var
  res: ILibImage;
begin
  if (FData = nil) then
  begin
    res := MainResourceLibrary.GetImageByGUID(FGUID);
    if Assigned(res) then
      FData := TOleStream.Create(res.GetDecryptedData);
  end;
  Result := FData;
end;

function TGUIDedTextureDataSource.GetGUID: TGUID;
begin
  Result := FGUID;
end;

function TGUIDedTextureDataSource.GetHash: string;
var
  res: ILibImage;
begin
  Result := '';
  res := MainResourceLibrary.GetImageByGUID(FGUID);
  if Assigned(res) then
    Result := res.GetHash(htDataHash);
end;

function TGUIDedTextureDataSource.HasData: boolean;
begin
  Result := (GetData <> nil);
end;


procedure TGUIDedTextureDataSource.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  if assigned(root) then
  begin
    if root.HasAttribute('GUID') then
      FGUID := TextToGUID(Utf8ToAnsi(root.AttributeByName['GUID'].Value));
  end;
end;

function TGUIDedTextureDataSource.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btGUIDedTextureDataSourceGUID: Read(FGUID, SizeOf(FGUID));
    else
      Result:=CL_UNKNOWN_PARAM;
    end;
end;

procedure TGUIDedTextureDataSource.ReadFromFiler(ReadInfo: TReadInfo);
begin
  with ReadInfo do
  begin
    Reader.Read(FGUID, sizeof(FGUID));
  end;
end;

procedure TGUIDedTextureDataSource.SaveObject(var SaveInfo: TSaveInfo);
begin
  with SaveInfo, Writer do
  try
    if not GUIDisNULL(FGUID) then
      Write(btGUIDedTextureDataSourceGUID, FGUID, SizeOf(FGUID));
  except
    on e: exception do
      SaveInfo.Error('TGUIDedTextureDataSource: ' + e.Message);
  end;
end;

procedure TGUIDedTextureDataSource.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
const
  mfStoreGUIDedData = 32;
begin
  if assigned(root) then
  begin
    if (SaveFlags and mfStoreGUIDedData <> 0) and HasData then
      root.Value := EncodeBase64Utf(FData)
    else
      root.GetOrCreateAttr('GUID').Value := AnsiToUtf8(GUIDToText(FGUID));
  end;
end;

procedure TGUIDedTextureDataSource.WriteToFiler(WriteInfo: TWriteInfo);
var
  aType: integer;
begin
  with WriteInfo do
  begin
    aType := 2;
    Writer.Write(aType, sizeof(aType));
    Writer.Write(FGUID, sizeof(FGUID));
  end;
end;

{ TMemoryTextureDataSource }

constructor TMemoryTextureDataSource.CreateFromFile(
  const filename: string);
begin
  Create;
  Data:=TMemoryStream.Create;
  Data.LoadFromFile(filename);
end;

destructor TMemoryTextureDataSource.Destroy;
begin
  FStream.Free;
  inherited;
end;

function TMemoryTextureDataSource.EqualTo(t: TTextureDataSource): boolean;
begin
  Result:=(t is TMemoryTextureDataSource) and
  (FStream <> nil) and (TMemoryTextureDataSource(t).FStream <> nil) and
  (FStream.Size = TMemoryTextureDataSource(t).FStream.Size) and
  (md5buf(FStream.Memory^, FStream.Size) = md5buf(TMemoryTextureDataSource(t).FStream.Memory^, FStream.Size)) or
  ((FStream = nil) and (TMemoryTextureDataSource(t).FStream = nil));
end;

function TMemoryTextureDataSource.GetCopy: TTextureDataSource;
begin
  Result := TMemoryTextureDataSource.Create;
  TMemoryTextureDataSource(Result).CopyStream(GetData);
end;

function TMemoryTextureDataSource.GetData: TStream;
begin
  if (FStream = nil) and (FLazyData <> nil) and (FLazyData.Data <> nil) then
  begin
    FStream := TMemoryStream.Create;
    FStream.Size := FLazyData.Data.Size;
    FStream.CopyFrom(FLazyData.Data, 0);
    FLazyData := nil;
  end;
  if FStream <> nil then
    FStream.Position:=0;
  Result:=FStream;
end;

function TMemoryTextureDataSource.HasData: boolean;
begin
  Result:=assigned(FStream) or assigned(FLazyData);
end;
{
procedure TMemoryTextureDataSource.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
var
  s: string;
begin
  if assigned(root) then
  begin
    FStream.Free;
    s:=DecodeBase64Utf(root.Text);
    FStream:=TMemoryStream.Create;
    FStream.Size:=Length(s);
    Move(s[1], FStream.Memory^, Length(s));
  end;
end;
}
procedure TMemoryTextureDataSource.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
var
  s: string;
begin
  if assigned(root) then
  begin
    FStream.Free;
    s:=DecodeBase64Utf(root.Value);
    FStream:=TMemoryStream.Create;
    FStream.Size:=Length(s);
    Move(s[1], FStream.Memory^, Length(s));
  end;
end;

function TMemoryTextureDataSource.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btMemoryTextureDataSourceData:
        begin
          FreeAndNil(FStream);
//          FLazyData := CreateCP3Stream(Size);
          if FStream = nil then
            FStream:=TMemoryStream.Create;
          FStream.Size:=Size;
          Read(FStream.Memory^, Size);
        end;
    else
      Result:=CL_UNKNOWN_PARAM;
    end;
end;

const
  cmMemTexData = $abbaabba;

procedure TMemoryTextureDataSource.ReadFromFiler(ReadInfo: TReadInfo);
var
  s: string;
  aSize: integer;
begin
  with ReadInfo do
  begin
    FStream.Free;
    FStream:=TMemoryStream.Create;
    if Reader.CheckMagic(cmMemTexData) then
    begin
      Reader.Read(aSize, SizeOf(aSize));
      FStream.Size := aSize;
      if aSize > 0 then
        Reader.Read(FStream.Memory^, aSize);
    end
    else
    begin
      s:=DecodeBase64Utf(Reader.ReadString);
      FStream.Size:=Length(s);
      Move(s[1], FStream.Memory^, Length(s));
    end;
  end;
end;

procedure TMemoryTextureDataSource.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    GetData;
    if Assigned(FStream) then
      Write(btMemoryTextureDataSourceData, FStream.Memory^, FStream.Size);
  except
    on e: exception do
      SaveInfo.Error('TMemoryTextureDataSource: ' + e.Message);
  end;
  inherited;
end;

procedure TMemoryTextureDataSource.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    GetData;
    root.Value := EncodeBase64Utf(FStream.Memory^, FStream.Size);
  end;
end;

procedure TMemoryTextureDataSource.SetStream(const Value: TMemoryStream);
begin
  if FStream <> Value then
  begin
    FStream.Free;
    FStream := Value;
  end;
end;

procedure TMemoryTextureDataSource.CopyStream(const Value: TStream);
begin
  if (Value = nil) then Exit;
  if (FStream = nil) then
    FStream := TMemoryStream.Create
  else
    FStream.Clear;
  FStream.CopyFrom(Value, 0);
end;

procedure TMemoryTextureDataSource.WriteToFiler(WriteInfo: TWriteInfo);
var
  aType, aSize: integer;
begin
  with WriteInfo do
  begin
    aType:=0;
    Writer.Write(aType, sizeof(aType));
    GetData;
    Writer.WriteMagic(cmMemTexData);
    if FStream = nil then
      FStream := TMemoryStream.Create;
    aSize := FStream.Size;
    Writer.Write(aSize, SizeOf(aSize));
    Writer.Write(FStream.Memory^, aSize);
  end;
end;

{ TMaterialTextureAtlas }

constructor TMaterialTextureAtlas.Create;
begin
  inherited;
  AtlasContent:=TMaterialTextures.Create;
end;

destructor TMaterialTextureAtlas.Destroy;
begin
  AtlasContent.Free;
  inherited;
end;

function TMaterialTextureAtlas.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
begin
  with LoadInfo do
    case ChildBlockType of
      btMaterialTextureAtlasContent: begin AtlasContent.Clear; Result:=AtlasContent; end;
    else
      Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID);
    end;
end;

procedure TMaterialTextureAtlas.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    BeginChild(btMaterialTextureAtlasContent);
    try
      AtlasContent.SaveObject(SaveInfo);
    finally
      EndChild;
    end;
  except
    on e: exception do
      SaveInfo.Error('TMaterialTextureAtlas: ' + e.Message);
  end;
  inherited;
end;

{ TSurfacePoint }

function TSurfacePoint.MaterialNormal: TAffineVector;
begin
  if Material<>nil then
    Result:=Material.GetNormal(Self)
  else
    Result:=Self.Normal;
end;

function TSurfacePoint.Reflection(const aNormal: TAffineVector): TAffineVector;
begin
  Result:=VectorReflect(View, aNormal);
end;

function TSurfacePoint.Refraction(const aNormal: TAffineVector; RefractionIndex: single): TAffineVector;
begin
  Result:=View;
  if BackFace then
    VectorRefract(Result, PAffineVector(@aNormal)^, 1.0 / RefractionIndex)
  else
    VectorRefract(Result, PAffineVector(@aNormal)^, RefractionIndex);
end;

procedure TSurfacePoint.SetLog(const aLog: IDbgLog);
begin
  Log:=aLog;
end;

{ TInterfacedObjectList }

function TInterfacedObjectList._AddRef: Integer;
begin
{$IFDEF DEBUG_ADDREF}
  Result:=InterlockedIncrement(FRefCount);
{$ELSE}
  Result:=-1;
{$ENDIF}
end;

function TInterfacedObjectList._Release: Integer;
begin
{$IFDEF DEBUG_ADDREF}
  Result:=InterlockedDecrement(FRefCount);
{$ELSE}
  Result:=-1;
{$ENDIF}
end;

function TInterfacedObjectList.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
begin
  Result:=CL_UNKNOWN_OBJECT;
end;

function TInterfacedObjectList.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=CL_UNKNOWN_PARAM;
end;

function TInterfacedObjectList.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  if GetInterface(IID, obj) then
    Result:=0
  else
    Result:=E_NOINTERFACE;
end;

procedure TInterfacedObjectList.SaveObject(var SaveInfo: TSaveInfo); {ok} 
begin
  //empty
end;

{$IFDEF DEBUG_ADDREF}
destructor TInterfacedObjectList.Destroy;
begin
{$I DbgRef.inc}
  inherited;
end;
{$ENDIF}

function TInterfacedObjectList.GetWeakRefs: IWeakRefsHolder;
begin
  if FWeakRefs = nil then
    FWeakRefs := TWeakRefList.Create;
  Result := FWeakRefs;
end;

{ TTextureDataSource }

procedure TTextureDataSource.ExecCommand(cmd: cardinal;
  params: TCommandParams);
begin
  //
end;

function TTextureDataSource.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
begin
  Result:=CL_UNKNOWN_OBJECT;
end;

{ TAtlasMaterialTexture }

function TAtlasMaterialTexture.GetTextureObjType: integer;
begin
  Result := texAtlasTexture;
end;
{
procedure TAtlasMaterialTexture.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if root.HasAttribute('AtlasPositionAndScale') then
    DecodeBase64UtfToBuf(root.Attributes['AtlasPositionAndScale'], TextureAtlasPositionAndScale, sizeof(TextureAtlasPositionAndScale));
end;
}
procedure TAtlasMaterialTexture.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  inherited;
  if root.HasAttribute('AtlasPositionAndScale') then
    DecodeBase64UtfToBuf(root.AttributeByName['AtlasPositionAndScale'].Value, TextureAtlasPositionAndScale, sizeof(TextureAtlasPositionAndScale));
end;

function TAtlasMaterialTexture.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btAtlasMaterialTexturePosAndScale: Read(TextureAtlasPositionAndScale, sizeof(TextureAtlasPositionAndScale));
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TAtlasMaterialTexture.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    Write(btAtlasMaterialTexturePosAndScale, TextureAtlasPositionAndScale, sizeof(TextureAtlasPositionAndScale));
  except
    on e: exception do
      SaveInfo.Error('TAtlasMaterialTexture: ' + e.Message);
  end;
  inherited;
end;
{
procedure TAtlasMaterialTexture.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.Attributes['AtlasPositionAndScale'] := EncodeBase64Utf(TextureAtlasPositionAndScale, sizeof(TextureAtlasPositionAndScale));
end;
}
procedure TAtlasMaterialTexture.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.GetOrCreateAttr('AtlasPositionAndScale').Value :=
      EncodeBase64Utf(TextureAtlasPositionAndScale, sizeof(TextureAtlasPositionAndScale));
end;

procedure TAtlasMaterialTexture.SetMipmapDataFromAtlas(
  Atlas: TMaterialTextureAtlas);
begin
  {Нужно заполнить FMips[i].data и FMips[i]...pitches из Atlas}
  {$MESSAGE WARN 'not implemented'}
end;

{ TMaterialParamsTypeLibrary }

function TMaterialParamsTypeLibrary.GetClassByType(
  const aType: TMaterialParameterType): TMaterialParameterClass;
begin
  Result:=nil;
end;

function TMaterialParamsTypeLibrary.GetTypeByClassname(
  aClass: string): TMaterialParameterClass;
var
  i: integer;
begin
  i:=IndexOf(aClass);
  if i > -1 then
    Result:=TMaterialParameterClass(Objects[i])
  else
    Result:=nil;
end;

procedure TMaterialParamsTypeLibrary.RegisterTypes(
  aTypes: array of TMaterialParameterClass);
var
  i: integer;
begin
  for i:=0 to High(aTypes) do
    AddObject(aTypes[i].ClassName, TObject(aTypes[i]));
end;

{ TCommonTypeLibrary }

constructor TCommonTypeLibrary.Create;
begin
  inherited;
  Sorted:=true;
  Duplicates:=dupIgnore;
  CaseSensitive:=false;
end;

{ TMaterialTexturesTypeLibrary }

destructor TMaterialTexturesTypeLibrary.Destroy;
begin
  FReplaces.Free;
  inherited;
end;

function TMaterialTexturesTypeLibrary.GetTypeByClassname(
  aClass: string): TClass;
var
  i: integer;
begin
  i:=IndexOf(aClass);
  if i > -1 then
    Result:=TClass(Objects[i])
  else
    Result:=nil;
end;

procedure TMaterialTexturesTypeLibrary.RegisterTypes(
  aTypes: array of TClass);
var
  i, j: integer;
  o: TObject;
begin
  for i:=0 to High(aTypes) do
    if IndexOf(aTypes[i].Classname) = -1 then
    begin
      o := TObject(aTypes[i]);
      if (FReplaces <> nil) then
      begin
        j := FReplaces.IndexOf(aTypes[i].Classname);
        if j > -1 then
          o := TObject(FReplaces.Objects[j]);
      end;
      AddObject(aTypes[i].ClassName, o);
    end;
end;

procedure TMaterialTexturesTypeLibrary.ReplaceType(const oldClass,
  newClass: TClass);
var
  i: integer;
begin
  if FReplaces = nil then
    FReplaces := TStringList.Create;
  if FReplaces.Find(oldClass.Classname, i) then
    FReplaces.Delete(i);
  FReplaces.AddObject(oldClass.Classname, TObject(newClass));
  if Find(oldClass.Classname, i) then
    Delete(i);
  AddObject(oldClass.Classname, TObject(newClass));
end;

{ TSimpleTexturesListItem }

constructor TSimpleTexturesListItem.Create;
begin
  CreateGUID(FGUID);
  inherited Create;
  FDirtFlag:=True;
  FOwner:=aOwner;
  TexelScale:=1.0;
end;

destructor TSimpleTexturesListItem.Destroy;
begin
  FData.Free;
  inherited;
end;

function TSimpleTexturesListItem.EqualTo(
  t: TSimpleTexturesListItem): boolean;
var
  s1, s2: TMaterialTexture;
begin
  Result:=false;
  if assigned(FData) and assigned(t.FData) then
  begin
    s1:=FData.LockRef;
    s2:=t.FData.LockRef;
    try
      if (s1 <> nil) and (s2 <> nil) then
        Result:=s1.EqualTo(s2)
      else
        Result:=(s1 = nil) xor (s2 <> nil);
    finally
      FData.UnlockRef;
      t.FData.UnlockRef;
    end;
  end;
end;

function TSimpleTexturesListItem.GetData: TMaterialTexture;
begin
  if FData <> nil then
  begin
    Result:=FData.LockRef;
    FData.UnlockRef;
  end
  else
    Result:=nil;
end;

function TSimpleTexturesListItem.GetDataOwner: boolean;
begin
  Result:=FData.FOwn;
end;

function TSimpleTexturesListItem.GetLoadingChild(var LoadInfo: TLoadInfo;
  const ChildBlockType: cardinal; const ChildClass,
  ChildID: string): TObject;
var
  cls: TClass;
begin
  case ChildBlockType of
    btMaterialTextureItemData:
    begin
      if Data <> nil then
        Result:=Data
      else
      begin
        cls:=MaterialTextures.GetTypeByClassname(ChildClass);
        if cls = nil then
          Result:=CL_UNKNOWN_OBJECT
        else
        begin
          OwnedData:=TMaterialTextureClass(cls).CreateNamed(ChildID);
          Result:=Data;
        end;
      end;
    end
  else
    Result:=CL_UNKNOWN_OBJECT;
  end;
end;

function TSimpleTexturesListItem.GetTextureID: string;
var
  aTexture: TMaterialTexture;
begin
  Result := '';
  if Assigned(FData) then
  begin
    if (FLocalPixelHash <> '') then
      Result := FLocalPixelHash
    else
    begin
      aTexture := FData.LockRef;
      try
        if Assigned(aTexture) then
          Result := aTexture.TextureID;
      finally
        FData.UnlockRef;
      end;
    end;
  end;
end;

procedure TSimpleTexturesListItem.Assign(src: TSimpleTexturesListItem);
var
  dataClass: TMaterialTextureClass;
  t: TMaterialTexture;
begin
  if assigned(src) then
  begin
    TextureName := src.TextureName;
    if assigned(src.OwnedData) then
    begin
      //dataClass := GetMaterialTextures.GetTypeByClassname(src.OwnedData);
      dataClass := TMaterialTextureClass(GetMaterialTextures.GetTypeByClassname(src.OwnedData.ClassName));
      t := dataClass.Create();
      t.Assign(src.OwnedData);
      OwnedData := t;
    end
    else
      OwnedData := nil;
  end;
end;
{
procedure TSimpleTexturesListItem.LoadFromXml(const root: IXMLNode;
  const LoadFlags: cardinal);
var
  TexType: integer;
  dataClass: TMaterialTextureClass;
  xm: IXMLInf;
  t: TMaterialTexture;
begin
  if assigned(root) then
  begin
    if root.HasAttribute('Type') then
      TexType:=root.Attributes['Type'];
    if root.HasAttribute('TextureName') then
      TextureName:=root.Attributes['TextureName'];
    if root.HasAttribute('TextureClass') then
      dataClass:=TMaterialTextureClass(GetMaterialTextures.GetTypeByClassname(root.Attributes['TextureClass']))
    else
      dataClass:=nil;
    if dataClass = nil then
      case TexType of
        texSingleTexture: dataClass := TMaterialTexture;
        texAtlasTexture:  dataClass := TAtlasMaterialTexture;
      else
        dataClass := TMaterialTexture;
      end;
    t:=dataClass.Create;
    t.LoadFromXml(root, LoadFlags);
    OwnedData:=t;
  end;
end;
}
procedure TSimpleTexturesListItem.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
var
  TexType: integer;
  dataClass: TMaterialTextureClass;
  xm: IXMLInf;
  t: TMaterialTexture;
begin
  TexType := -1;
  if assigned(root) then
  begin
    if root.HasAttribute('Type') then
      TexType:=root.AttributeByName['Type'].ValueAsInteger;
    if root.HasAttribute('TextureName') then
      TextureName:=Utf8ToAnsi(root.AttributeByName['TextureName'].Value);
    if root.HasAttribute('TextureClass') then
      dataClass:=TMaterialTextureClass(
        GetMaterialTextures.GetTypeByClassname(Utf8ToAnsi(root.AttributeByName['TextureClass'].Value)))
    else
      dataClass:=nil;
    if dataClass = nil then
      case TexType of
        texSingleTexture: dataClass := TMaterialTexture;
        texAtlasTexture:  dataClass := TAtlasMaterialTexture;
      else
        dataClass := TMaterialTexture;
      end;
    t:=dataClass.Create;
    t.LoadFromXml(root, LoadFlags);
    OwnedData:=t;
  end;
end;

function TSimpleTexturesListItem.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btSimpleTexturesListItemGuid :
      begin
        FGUID := ReadGUID;
        Identor.AddObject(GUIDToString(FGUID), TThreadSafeWeakRef.Create(Self));
      end;
      btMaterialTextureItemDataGuid:
        Assigner.AddAssignTaskWithGUID(SetDataRef, ReadGUID);
    else
      Result:=CL_UNKNOWN_PARAM;
    end;
end;

procedure TSimpleTexturesListItem.NotifyChange;
begin
  FDirtFlag:=True;
  if FOwner <> nil then
    FOwner.NotifyChange;
  if FWeakRefs <> nil then
    FWeakRefs.Notify(0); 
end;

procedure TSimpleTexturesListItem.PreloadTexture;
var
  s: ITextureSampler;
begin
  if Data.GetInterface(ITextureSampler, s) then
  begin
    s.Preload;
    s:=nil;
  end;
end;

const
  cmTexData = $FACEDEDE;

procedure TSimpleTexturesListItem.ReadFromFiler(ReadInfo: TReadInfo);
var
  TexType: integer;
  t: TMaterialTexture;
  dataClass: TMaterialTextureClass;
begin
  with ReadInfo do
  begin
    if Reader.CheckMagic(cmTexData) then
    begin
      if Reader.ReadBoolean then
      begin
        dataClass:=TMaterialTextureClass(GetMaterialTextures.GetTypeByClassname(Reader.ReadString));
        Reader.Read(TexType, sizeof(TexType));
        t:=dataClass.Create;
        t.ReadFromFiler(ReadInfo);
        OwnedData:=t;
      end;
    end
    else
      dataClass:=nil;
  end;
end;

procedure TSimpleTexturesListItem.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
  t: TMaterialTexture;
begin
  with SaveInfo, Writer do
  try
    Writer.WriteGUID(btSimpleTexturesListItemGuid, FGUID);
    if assigned(FData) then
    begin
      t:=FData.LockRef;
      try
        if t <> nil then
        begin
          if (FData.FOwn = false) and (sfTexturesAssignedToMaterialStoreAsReferences in SaveInfo.Flags) then
            WriteGUID(btMaterialTextureItemDataGuid, t.GUIDLabel.GUID)
          else
            WriteChild(SaveInfo, t, btMaterialTextureItemData, t.ClassName, t.FName);
        end;
      finally
        FData.UnlockRef;
      end;
    end;
  except
    on e: exception do
      SaveInfo.Error('TSimpleTexturesListItem: ' + e.Message);
  end;
end;
{
procedure TSimpleTexturesListItem.SaveToXml(const root: IXMLNode;
  const SaveFlags: cardinal);
var
  t: TMaterialTexture;
begin
  if assigned(FData) then
  begin
    t:=FData.LockRef;
    try
      if assigned(root) and (t <> nil) then
      begin
        root.Attributes['TextureName']:=TextureName;
        root.Attributes['TextureClass']:=t.ClassName;
        root.Attributes['Type']:=t.GetTextureObjType;
        t.SaveToXml(root, SaveFlags);
      end;
    finally
      FData.UnlockRef;
    end;
  end;
end;
}
procedure TSimpleTexturesListItem.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
var
  t: TMaterialTexture;
begin
  if assigned(FData) then
  begin
    t:=FData.LockRef;
    try
      if assigned(root) and (t <> nil) then
      begin
        root.GetOrCreateAttr('TextureName').Value := AnsiToUtf8(TextureName);
        root.GetOrCreateAttr('TextureClass').Value := AnsiToUtf8(t.ClassName);
        root.GetOrCreateAttr('Type').ValueAsInteger := t.GetTextureObjType;
        t.SaveToXml(root, SaveFlags);
      end;
    finally
      FData.UnlockRef;
    end;
  end;
end;

procedure TSimpleTexturesListItem.SetData(const Value: TMaterialTexture);
begin
  if Data <> Value then
  begin
    FData.Free;
    if Value = nil then
      FData:=nil
    else
      FData:=TTextureRef.Create(Value, false);
    NotifyChange;
  end;
end;

procedure TSimpleTexturesListItem.SetDataOwner(const Value: boolean);
begin
  FData.FOwn:=Value;
end;

procedure TSimpleTexturesListItem.SetOwnedData(const Value: TMaterialTexture);
begin
  FData.Free;
  if Value = nil then
    FData:=nil
  else
    FData:=TTextureRef.Create(Value, true);
  NotifyChange;
end;

procedure TSimpleTexturesListItem.WriteToFiler(WriteInfo: TWriteInfo);
var
  t: TMaterialTexture;
  aType: integer;
begin
  if Assigned(Self) then
  begin
    WriteInfo.Writer.WriteString(TextureName);
    WriteInfo.Writer.WriteMagic(cmTexData);
    if assigned(FData) and FDirtFlag then
    begin
      t:=FData.LockRef;
      try
        WriteInfo.Writer.WriteBoolean(assigned(t));
        if t <> nil then
        begin
          WriteInfo.Writer.WriteString(t.ClassName);
          aType:=t.GetTextureObjType;
          WriteInfo.Writer.Write(aType, sizeof(aType));
          t.WriteToFiler(WriteInfo);
        end;
      finally
        FData.UnlockRef;
        FDirtFlag:=False;
      end;
    end
    else
      WriteInfo.Writer.WriteBoolean(false);
  end;
end;

procedure TSimpleTexturesListItem.ExecCommand(cmd: cardinal;
  params: TCommandParams);
var
  t: TMaterialTexture;
begin
  if (cmd = cMarkDurty) then
    FDirtFlag := True;
  t := Data;
  if Assigned(t) then
  begin
    if (cmd = cImagePack) and (params is TImagePackParams) then
    begin
      if (TextureName = cBumpMap.name) then
      begin
        TImagePackParams(params).SetPackFormat(ipfPNG);
        t.ExecCommand(cmd, params);
        TImagePackParams(params).SetPackFormat;
      end
      else
        if (TextureName = cWeightsMap.name) then
        begin
          TImagePackParams(params).SetPackFormat(ipfBMP);
          t.ExecCommand(cmd, params);
          TImagePackParams(params).SetPackFormat;
        end
        else
          t.ExecCommand(cmd, params);
    end
    else
      t.ExecCommand(cmd, params);
  end;
end;

function TSimpleTexturesListItem.GetValidTextureName: string;
begin
  Result := TextureName;
  if isComRender and (Result = cAlbedoMapEx.name) then
    Result := cAlbedoMap.name;
end;

function TSimpleTexturesListItem.IsValid: Boolean;
begin
  Result := True;
  if isComRender then
  begin
    if (TextureName = cAlbedoMap.name) and Assigned(FOwner) then
      Result := not FOwner.HasItem(cAlbedoMapEx.name);
  end
  else
    Result := (TextureName <> cAlbedoMapEx.name);
end;

function TSimpleTexturesListItem.GetOwner: TSimpleTexturesList;
begin
  Result := FOwner;
end;

function TSimpleTexturesListItem.ReadDataForRender(var aData: pointer; var aDataLen: integer): Boolean;
var
  aTexture: TMaterialTexture;
  aGamma: Double;
begin
  Result := False;
  if Assigned(FData) then
  begin
    aTexture := FData.LockRef;
    try
      if Assigned(aTexture) then
      begin
        FLocalPixelHash := '';
        //Производим гамма коррекцию карт альбедо
        if Assigned(FOwner) and Assigned(FOwner.FOwner) and (TextureName = cAlbedoMap.name) then
        with FOwner.FOwner.Parameters do
        begin
          aGamma := 0;
          case EXT_RENDER of
            rCom32..rCom64Warp: aGamma := FloatParameter['albedo_correction'].Value;
            rPBRender, rCloudRender: aGamma := FloatParameter['pbr_albedo_correction'].Value;
          end;
          if (aGamma > 0) then
          begin
            aTexture.ApplySRGBCorrection(aGamma);
            FLocalPixelHash := aTexture.CalcPixelHashFromData;
          end;
        end;

        Result := aTexture.GetTextureData(tdf32bit, aData, aDataLen);
      end;
    finally
      FData.UnlockRef;
    end;
  end;
end;

procedure TSimpleTexturesListItem.FinalizeReading;
var
  aTexture: TMaterialTexture;
begin
  if Assigned(FData) then
  begin
    aTexture := FData.LockRef;
    try
      if Assigned(aTexture) and Assigned(aTexture.Provider) then
        aTexture.ClearData;
    finally
      FData.UnlockRef;
    end;
  end;
end;

function TSimpleTexturesListItem.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
	if IsEqualGUID(IID, IWeakRefsHolder) and (FWeakRefs = nil) then
		FWeakRefs:=TWeakRefList.Create;
	Result := inherited QueryInterface(IID, Obj);
end;

function TSimpleTexturesListItem.GetGlobalUniqueIdentifier: TGUID;
begin
  Result := FGUID;
end;

procedure TSimpleTexturesListItem.SetDataRef(const obj);
begin
  if (pointer(obj) <> nil) and (TObject(obj) is TMaterialTexture) then
    Data := TMaterialTexture(obj);
end;

{ TSimpleInterfacedObject }

function TSimpleInterfacedObject._AddRef: Integer;
begin
{$IFDEF DEBUG_ADDREF}
  Result:=InterlockedIncrement(FRefCount);
{$ELSE}
  Result:=-1;
{$ENDIF}
end;

function TSimpleInterfacedObject._Release: Integer;
begin
{$IFDEF DEBUG_ADDREF}
  Result:=InterlockedDecrement(FRefCount);
{$ELSE}
  Result:=-1;
{$ENDIF}
end;

function TSimpleInterfacedObject.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  if GetInterface(IID, obj) then
    Result:=0
  else
    Result:=E_NOINTERFACE;
end;

{$IFDEF DEBUG_ADDREF}
destructor TSimpleInterfacedObject.Destroy;
begin
{$I DbgRef.inc}
  inherited;
end;
{$ENDIF}

function TSimpleInterfacedObject.GetWeakRefs: IWeakRefsHolder;
begin
  if FWeakRefs = nil then
    FWeakRefs := TWeakRefList.Create;
  Result := FWeakRefs;
end;

function TSimpleInterfacedObject.HasWeakReferences: boolean;
begin
  Result := (FWeakRefs <> nil) and (not FWeakRefs.IsEmpty);
end;

{ TTileMaterial }

class function TTileMaterial.GetTypeIndex: integer;
begin
  Result:=6;
end;

{TMultiMaterial}

constructor TMultiMaterial.Create(aOwner: TObject; mat0: TMaterial; material0Name: string);
var
  baseMat: TMaterial;
begin
  Create(aOwner);
  FMaterials[0].CreateMaterial(mat0, tr('Фон'));
  FMetaData.Assign(mat0.MetaData);
end;

constructor TMultiMaterial.Create(aOwner: TObject);
var
  i: Integer;
begin
  FMatLib := TMaterialList.Create(self);
  FMatCount:=TIntegerMaterialParameter.Create(self);
  FMatCount.Value:=5;
  for i := 0 to 4 do
  begin
    FMaterials[i] := TMonoMaterialParameter.Create(self);
    FMaterials[i].FMatLib := FMatLib;
    FMaterials[i].FValue := '';
    FMaterials[i].FMonoMaterialInd := i;
  end;
  FMatWeights := TTextureMaterialParameter.Create(self);
  inherited;
end;

destructor TMultiMaterial.Destroy();
var
  i: Integer;
begin    
  for i := 0 to 4 do
  begin
    FMaterials[i].Free;
  end;
  FMatLib.Free;
  FMatCount.Free;
  FMatWeights.Free;
  inherited;
end;

procedure TMultiMaterial.EvalMaterialAt(aPoint: TSurfacePoint; EvalMode: integer);
begin
  inherited;
end;

function TMultiMaterial.GetShaderEvaluationCase: string;
begin
  Result := '';
end;

class function TMultiMaterial.GetTypeIndex: integer;
begin
  Result := 11;
end;

procedure TMultiMaterial.SetupParametersList;
var
  i: Integer;
begin
  Parameters.BeginUpdate;
  inherited;
  with FParameters.NewInteger('MatCount') do
  begin
    FMatCount.LinkTo(this);
    FCustomizable:=False;
    Value:=5;
  end;
  for i := 0 to 4 do
  begin
    with Parameters.NewMonoMaterial('Материал ' + IntToStr(i)) do
    begin
      Value := '';
      FMaterials[i].LinkTo(this);
      FMonoMaterialInd := i;
      FClassFilter := TDiffuseMaterial;
      FCustomizable:=true;
      FAltName := tr('Материал ') + IntToStr(i);
    end;
  end;
  with FParameters.NewTexture(cWeightsMap.name) do
  begin
    FMatWeights.LinkTo(this);
    FAltName:=cWeightsMap.altname;
    FCustomizable:=true;
  end;
  Parameters.EndUpdate; 
end;

function TMultiMaterial.IsMultiMaterial(): Boolean;
begin
  Result := True;
end;

function TMultiMaterial.GetMatCount(): Integer;
begin
  Result := FMatCount.Value;
end;

function TMultiMaterial.GetMonoMaterial(ind: Integer): TMaterial;
begin
  Result := FMaterials[ind].AsMonoMaterial;
end;

function TMultiMaterial.GetFirstMonoMaterial: TMaterial;
var
  i: integer;
begin
  Result := nil;
  for i:=0 to 4 do
    if Assigned(GetMonoMaterial(i)) then
    begin
      Result := GetMonoMaterial(i);
      Break;
    end;
end;

procedure TMultiMaterial.Upgrade;
var
  i: integer;
  mat: TMaterial;
begin
  inherited;
  if FVersion = 6 then
  with Parameters do
  begin
    BeginUpdate;
    UpgradeMonoMaterialParameter('Материал 0', 'Material 0');
    UpgradeMonoMaterialParameter('Материал 1', 'Material 1');
    UpgradeMonoMaterialParameter('Материал 2', 'Material 2');
    UpgradeMonoMaterialParameter('Материал 3', 'Material 3');
    UpgradeMonoMaterialParameter('Материал 4', 'Material 4');
    EndUpdate;
  end;
  {for i:=0 to GetMatCount - 1 do
  begin
    mat := GetMonoMaterial(i);
    if mat <> nil then
      mat.Upgrade;
  end;}
  {for i := 0 to FMatLib.Count - 1 do
  begin
    TMaterial(FMatLib[i]).Upgrade;
    inc(TMaterial(FMatLib[i]).FVersion);
  end;}
end;

function TMultiMaterial.UnknownParameter(const aName, aClass: string; var LoadInfo: TLoadInfo): TObject;
begin
  if MaterialParams.GetTypeByClassname(aClass).InheritsFrom(TMonoMaterialParameter) then
  begin
    Result := Parameters.NewMonoMaterial(aName);
  end
  else
	begin
		Result:=Parameters.NewParameter(aName, MaterialParams.GetTypeByClassname(aClass));
	end;
end;

function TMultiMaterial.ClearMatLib: Integer;
var
  lInd, mInd: Integer;
  delInds: array of Boolean;
begin
  Result := 0;
  SetLength(delInds, FMatLib.Count);
  for lInd := 0 to FMatLib.Count - 1 do
  begin
    delInds[lInd] := True;
    if IsUsedMaterial(TMaterial(FMatLib[lInd])) then
      delInds[lInd] := False;
  end;
  for lInd := FMatLib.Count - 1 downto 0 do
  begin
    if delInds[lInd] then
    begin
      FMatLib.Delete(lInd);
      Inc(Result);
    end;
  end;
end;

function TMultiMaterial.ConsistMaterial(const lib: IMaterialLibrary; const matName: string;
                                        var monoMat: TMonoMaterialParameter): Boolean;
var
  i: Integer;
begin
  monoMat := nil;
  if lib = IMaterialLibrary(FMatLib) then
  begin
    for i := 0 to Length(FMaterials) - 1 do
    begin
      if FMaterials[i].Value = matName then
      begin
        monoMat := FMaterials[i];
        Result := True;
        Exit;
      end;
    end;
  end;
  Result := False;
end;
  
function TMultiMaterial.ConsistTwoMaterials(const matName: string): Boolean;
var
  i, count: Integer;
begin
  count := 0;
  for i := 0 to Length(Fmaterials) - 1 do
  begin
    if FMaterials[i].Value = matName then
      Inc(count);
  end;
  Result := count >= 2;
end;

function TMultiMaterial.IsUsedMaterial(const mat: TMaterial): Boolean;
var
  ind: Integer;
begin
  Result := False;
  for ind := 0 to Length(FMaterials) - 1 do
  begin
    if mat.FName = FMaterials[ind].Value then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TMultiMaterial.SwapMonoMaterials(const ind0, ind1: Integer);
var
  bufStr: string;
begin
  bufStr := FMaterials[ind0].Value;
  FMaterials[ind0].Value := FMaterials[ind1].Value;
  FMaterials[ind1].Value := bufStr;
  FMaterials[ind0].ParameterChanged;
  FMaterials[ind1].ParameterChanged;
end;
    
procedure TMultiMaterial.SaveToXml(const root: TXMLNode; const SaveFlags: cardinal);
var
  ind: Integer;
  mat: TMaterial;
  libNode: TXmlNode;
begin
  inherited;
  if assigned(root) then
  begin
    libNode := root.NodeNew('MaterialsLibrary');
    for ind := 0 to Length(FMaterials) - 1 do
    begin
      if FMaterials[ind].Value <> '' then
      begin
        mat := FMatLib.Find(FMaterials[ind].Value);
        if mat <> nil then
          mat.SaveToXml(libNode.NodeNew('MonoMaterial'), SaveFlags)
        else
          FMaterials[ind].Value := '';
      end;
    end;
  end;
end;

procedure TMultiMaterial.LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal);
var
  libNode, matNode: TXmlNode;
  mat: TMaterial;
  i: Integer;
begin
  inherited;
  if assigned(root) then
  begin
    libNode := root.FindNode('MaterialsLibrary');
    if libNode <> nil then
    begin
      for i:=0 to libNode.NodeCount - 1 do
      begin
        matNode := libNode.Nodes[i];
		    if Assigned(matNode) and (matNode.HasAttribute('Type')) then
        begin
          mat := MaterialTypes.FindMaterialClass(matNode.AttributeByName['Type'].ValueAsInteger).Create(FMatLib);
          mat.LoadFromXml(matNode, loadFlags);
          FMatLib.Add(mat);
        end
      end;
    end;
  end;
end;
      
procedure TMultiMaterial.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
  ind: Integer;
  mat: TMaterial;
begin
  inherited;
  with SaveInfo, Writer do
  try
    for ind := 0 to Length(FMaterials) - 1 do
    begin
      if FMaterials[ind].Value <> '' then
      begin
        mat := FMatLib.Find(FMaterials[ind].Value);
        if mat <> nil then
        begin
          BeginChild(btMaterialListItem, mat.ClassName, mat.Name);
          try
            mat.SaveObject(SaveInfo);
          finally
            EndChild;
          end;
        end
        else
          FMaterials[ind].Value := '';
      end;
    end;
  except
    on e: exception do
      SaveInfo.Error('TMultiMaterial: ' + e.Message);
  end;
end;

function TMultiMaterial.GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal; const ChildClass,
                                        ChildID: string): TObject;
var
  mat: TMaterial;
begin
  with LoadInfo do
    case ChildBlockType of
      btMaterialListItem:
      begin
        mat := MaterialTypes.FindMaterialClassByName(ChildClass).Create(FMatLib);
        if ChildID <> '' then
          FMatLib.Add(mat);
        Result := mat;
      end;
    else
      Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID);
    end;
end;

procedure TMultiMaterial.WriteToFiler(WriteInfo: TWriteInfo);
var
  i, count: Integer;
begin
  inherited;
  with WriteInfo do
  begin
    count := FMatLib.Count;
    Writer.Write(count, SizeOf(count));
    for i := 0 to count - 1 do
    begin
      TMaterial(FMatLib[i]).WriteToFiler(WriteInfo);
    end;
  end;
end;

procedure TMultiMaterial.ReadFromFiler(ReadInfo: TReadInfo; ReadType: boolean);
var
  count, i, aType: Integer;
  mat: TMaterial;
begin
  inherited;
  FMatLib.Clear;
  with ReadInfo do
  begin
    Reader.Read(count, sizeof(count));
    for i := 0 to count - 1 do
    begin
			Reader.Read(aType, SizeOf(aType));
      mat := (MaterialTypes.FindMaterialClass(aType)).Create(FMatLib);
      FMatLib.Add(mat);
      mat.ReadFromFiler(ReadInfo);
    end;
  end;
end;
     
{procedure TMultiMaterial.Assign(src: TMaterial);
var
  i: Integer;
  mat, newMat: TMaterial;
begin
  inherited;
  FMatLib.Clear;
  if (src is TMultiMaterial) then
    for i := 0 to TMultiMaterial(src).FMatLib.Count - 1 do
    begin
      mat := TMaterial(TMultiMaterial(src).FMatLib[i]);
			newMat := MaterialTypes.FindMaterialClassByName(mat.ClassName).Create(Self);
      newMat.Assign(mat);
    end;
end; }

function TMultiMaterial.GetMonoMaterialList: TMaterialList;
begin
  Result := FMatLib;
end;

procedure TMultiMaterial.ExecCommand(cmd: cardinal;
  params: TCommandParams);
begin
  inherited;
  case cmd of
    cMarkDurty, cImagePack, cRecalcPBRMaterial, cFindTextureByID: FMatLib.ExecCommand(cmd, params);
  end;
end;

procedure TMultiMaterial.ValidateVersion;
var
  i: integer;
begin
  inherited;
  for i := 0 to FMatLib.Count - 1 do
    TMaterial(FMatLib[i]).ValidateVersion;
end;

{ TColorMaterialParameter }

function TColorMaterialParameter.GetColor: cardinal;
begin
  Result:=VectorToRGBA(Value, 255).value;
end;

procedure TColorMaterialParameter.SetColor(color: cardinal);
begin
  Value:=RGBAToAffineVector(TRGBA(color));
end;

procedure TColorMaterialParameter.Setup;
begin
  inherited;
  FType:=mptColor;
end;

{ TFlagsMaterialParameter }

function TFlagsMaterialParameter.FindFlagByName(const LangId: TCeramicLanguage; const name: string;
  var flagIndex: Integer): boolean;
var
  p: TMaterialParameter;
  i: integer;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        Result:=TFlagsMaterialParameter(p).FindFlagByName(LangId, name, flagIndex);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=False;
  if FNames[LangId] <> nil then
    for i:=0 to High(FNames[LangId]) do
      if AnsiCompareText(FNames[LangId, i], name) = 0 then
      begin
        if FBits <> nil then
          if Length(FBits) = Length(FNames[LangId]) then
          begin
            Result:=true;
            flagIndex:=FBits[i];
          end
          else
        else
        begin
          Result:=true;
          flagIndex:=i;
        end
      end;
end;

function TFlagsMaterialParameter.Pack: string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to length(FNames[langRussian])-1 do
  begin
    Result:=Result + '"' + FNames[langRussian, i]+',';
    Result:=Result + format('%d', [GetFlagBit(i)])+',';
    Result:=Result + inttostr(ord(GetFlagVisibility(i)))+'"';
    if (i < (length(FNames[langRussian])-1)) then
      Result:=Result + ';';
  end;
end;

function TFlagsMaterialParameter.PackExtraNames: String;
var
  LangId: TCeramicLanguage;
  i: Integer;
  S: String;
begin
  Result := '';
  LangId := langRussian;
  while LangId < High(TCeramicLanguage) do
  begin
    Inc(LangId);
    S := '';
    for i := 0 to Length(FNames[LangId]) - 1 do
    begin
      if i > 0 then
        S := S + ';';
      S := S + '"' + FNames[LangId, i]+'"';
    end;
    if Length(Result) > 0 then
      Result := Result + '|';
    Result := Result + S;
  end;
end;

procedure TFlagsMaterialParameter.UnPack(aValue: string);
var
  i, j, k: integer;
  s: TStringList;
  ss: string;
begin
  s:=TStringList.Create;
  s.Delimiter:=';';
  try
    s.DelimitedText:=aValue;
    SetLength(FNames[langRussian], s.Count);
    SetLength(FVisibility, s.Count);
    SetLength(FBits, s.Count);
    for i:=0 to s.Count-1 do
    begin
      ss:=s.Strings[i];
      j:=PosEx(',', ss);
      FNames[langRussian, i]:=copy(ss, 1, j-1);
      k:=PosEx(',', ss, j+1);
      FBits[i]:=strtoint(copy(ss, j+1, k-j-1));
      FVisibility[i]:=Boolean(strtoint(ss[k+1]));
    end;
  finally
    s.Free;
  end;
end;

procedure TFlagsMaterialParameter.UnPackExtraNames(aValue: string);
var
  LangList, LangItems: TExplodedString;
  i, j: Integer;
  LangId: TCeramicLanguage;
  ss: String;
begin
  LangId := langRussian;
  LangList := ExplodeString(aValue, '|');
  for i := 0 to High(LangList) do
  begin
    if LangId = High(TCeramicLanguage) then exit;
    Inc(LangId);
    LangItems := ExplodeString(LangList[i], ';');
    SetLength(FNames[LangId], Length(LangItems));
    for j := 0 to High(LangItems) do
    begin
      ss := LangItems[j];
      if (Length(ss) > 0) and (ss[1] = '"') and (ss[Length(ss)] = '"') then
        ss := Copy(ss, 2, Length(ss) - 2);
      FNames[LangId, j]:= ss;
    end;
  end;
end;

function TFlagsMaterialParameter.GetFlag(Index: integer): boolean;
begin
  Result:=(Value and (1 shl Index)) <> 0;
end;

function TFlagsMaterialParameter.GetFlagBit(Index: integer): Integer;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        Result:=TFlagsMaterialParameter(p).GetFlagBit(Index);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  if Index < Length(FBits) then
    Result:=FBits[Index]
  else
    Result:=Index;
end;

function TFlagsMaterialParameter.GetFlagByName(
  const aName: string): boolean;
var
  fi: Integer;
begin
  if FindFlagByName(CurrentCeramicLanguage, aName, fi) then
    Result:=GetFlag(fi)
  else
    Result:=false;
end;

function TFlagsMaterialParameter.GetFlagName(Index: integer): string;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        Result:=TFlagsMaterialParameter(p).GetFlagName(Index);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  if Index < Length(FNames[CurrentCeramicLanguage]) then
    Result:=FNames[CurrentCeramicLanguage, Index]
  else
    Result:='not used';
end;

function TFlagsMaterialParameter.GetFlagVisibility(
  Index: integer): boolean;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        Result:=TFlagsMaterialParameter(p).GetFlagVisibility(Index);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  if Index < Length(FVisibility) then
    Result:=FVisibility[Index]
  else
    Result:=false;
end;

function TFlagsMaterialParameter.NumberOfUsedBits: integer;
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        Result:=TFlagsMaterialParameter(p).NumberOfUsedBits;
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  Result:=Length(FNames[CurrentCeramicLanguage]);
end;

procedure TFlagsMaterialParameter.PlaceDataAt(p: pointer);
var
  i: integer;
begin
  for i:=0 to NumberOfUsedBits - 1 do
    if GetFlag(i) then
      PCardinal(p)^:=PCardinal(p)^ or (1 shl GetFlagBit(i))
    else
      PCardinal(p)^:=PCardinal(p)^ and (not (1 shl GetFlagBit(i)));
end;

procedure TFlagsMaterialParameter.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
  with SaveInfo, Writer do
  try
    WriteString(btFlagsMaterialParameterValue, Pack);
  except
    on e: exception do
      SaveInfo.Error('TFlagsMaterialParameter: ' + e.Message);
  end;
  inherited;
end;

function TFlagsMaterialParameter.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btFlagsMaterialParameterValue: UnPack(ReadString);
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;
{
procedure TFlagsMaterialParameter.SaveToXml(const root: IXMLNode; const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.Attributes['FlagNames']:=Pack;
end;
}
procedure TFlagsMaterialParameter.SaveToXml(const root: TXMLNode; const SaveFlags: cardinal);
var
  S: String;
begin
  inherited;
  if assigned(root) then
  begin
    root.GetOrCreateAttr('FlagNames').Value := AnsiToUtf8(Pack);
    S := PackExtraNames;
    if Length(S) > 0 then
      root.GetOrCreateAttr('FlagExtraNames').Value := AnsiToUtf8(S);
    root.GetOrCreateAttr('FlagBits').Value := AnsiToUtf8(PackBits);
    root.GetOrCreateAttr('FlagVis').Value := AnsiToUtf8(PackVis);
  end;
end;
{
procedure TFlagsMaterialParameter.SaveToXml(const root: TXMLNode; const SaveFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    root.AttributeByName['FlagNames'].Value := Pack;
end;

procedure TFlagsMaterialParameter.LoadFromXml(const root: IXMLNode; const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
    UnPack(root.Attributes['FlagNames']);
end;
}
procedure TFlagsMaterialParameter.LoadFromXml(const root: TXMLNode; const LoadFlags: cardinal);
begin
  inherited;
  if assigned(root) then
  begin
    if root.HasAttribute('FlagNames') then
    begin
      UnPack(Utf8ToAnsi(root.AttributeByName['FlagNames'].Value));
      if root.HasAttribute('FlagExtraNames') then
        UnPackExtraNames(Utf8ToAnsi(root.AttributeByName['FlagExtraNames'].Value));
    end
    else
      Unpack('');
    if root.HasAttribute('FlagBits') then
      UnpackBits(Utf8ToAnsi(root.AttributeByName['FlagBits'].Value))
    else
      UnpackBits('');
    if root.HasAttribute('FlagVis') then
      UnpackVis(Utf8ToAnsi(root.AttributeByName['FlagVis'].Value))
    else
      UnpackVis('');
  end;
end;


const
  cFlagParamExtraNames = $01238662;

procedure TFlagsMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.WriteString(Pack);
  WriteInfo.Writer.WriteMagic(cFlagParamExtraNames);
  WriteInfo.Writer.WriteString(PackExtraNames);
end;

procedure TFlagsMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  UnPack(ReadInfo.Reader.ReadString);
  if ReadInfo.Reader.CheckMagic(cFlagParamExtraNames) then
    UnPackExtraNames(ReadInfo.Reader.ReadString);
end;

procedure TFlagsMaterialParameter.SetFlag(Index: integer; NewValue: boolean);
begin
  if NewValue then
    Value:=Value or (1 shl Index)
  else
    Value:=Value and (not (1 shl Index));
end;

procedure TFlagsMaterialParameter.SetFlagsByName(const LangID: TCeramicLanguage; const Script: string);
var
  i, fi, v: integer;
  f: TStringList;
begin
  with ExplodeStrChar(',', Script) do
  try
    for i:=0 to Count - 1 do
    begin
      f:=ExplodeStrChar('=', Strings[i]);
      if (f.Count = 2) and TryStrToInt(f[1], v) and FindFlagByName(LangID, f[0], fi) then
        SetFlag(fi, Boolean(v));
    end;
  finally
    Free;
  end;
end;

procedure TFlagsMaterialParameter.SetFlagsBits(bits: array of Integer);
var
  p: TMaterialParameter;
  i: integer;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        TFlagsMaterialParameter(p).SetFlagsBits(bits);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  SetLength(FBits, Length(bits));
  for i:=0 to High(bits) do
    FBits[i]:=bits[i];
end;

procedure TFlagsMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TFlagsMaterialParameter then
  begin
    UnPack(TFlagsMaterialParameter(src).Pack);
    UnPackExtraNames(TFlagsMaterialParameter(src).PackExtraNames);
    //UnPack(langEnglish, TFlagsMaterialParameter(src).Pack(langEnglish));
  end;
  inherited;
end;

procedure TFlagsMaterialParameter.SetFlagsNames(const LanguageId: TCeramicLanguage; names: array of string);
var
  p: TMaterialParameter;
  i: integer;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        TFlagsMaterialParameter(p).SetFlagsNames(LanguageId, names);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  SetLength(FNames[LanguageId], Length(names));
  for i:=0 to High(names) do
    FNames[LanguageId, i]:=names[i];
end;

procedure TFlagsMaterialParameter.SetFlagsVisibility(
  vis: array of boolean);
var
  p: TMaterialParameter;
  i: integer;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        TFlagsMaterialParameter(p).SetFlagsVisibility(vis);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  SetLength(FVisibility, Length(vis));
  for i:=0 to High(vis) do
    FVisibility[i]:=vis[i];
end;

procedure TFlagsMaterialParameter.Setup;
begin
  inherited;
  FType:=mptFlags;
end;

procedure TFlagsMaterialParameter.StoreValue(var aValue: Integer);
begin
  PlaceDataAt(@aValue);
end;

procedure TFlagsMaterialParameter.SetFlagByName(const aName: string;
  const aValue: boolean);
var
  fi: Integer;
begin
  if FindFlagByName(CurrentCeramicLanguage, aName, fi) then
    SetFlag(fi, aValue);
end;

procedure TFlagsMaterialParameter.SetFlagVisibility(Index: integer;
  newVisibility: boolean);
var
  p: TMaterialParameter;
begin
  if assigned(FLink) then
  begin
    p:=FLink.LockRef;
    try
      if p is TFlagsMaterialParameter then
      begin
        TFlagsMaterialParameter(p).SetFlagVisibility(Index, newVisibility);
        exit;
      end;
    finally
      FLink.UnlockRef;
    end;
  end;
  FVisibility[index]:=newVisibility;
end;

function TFlagsMaterialParameter.PackBits: string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to High(FBits) do
    Result:=Result + IntToStr(FBits[i]) + ';';
  if Length(Result) > 0 then
    SetLength(Result, Length(Result) - 1);
end;

procedure TFlagsMaterialParameter.UnpackBits(const v: string);
var
  i: Integer;
  e: TExplodedString;
begin
  e:=ExplodeString(v, ';');
  SetLength(FBits, Length(e));
  for i:=0 to High(e) do
    if not TryStrToInt(Trim(e[i]), FBits[i]) then
      FBits[i]:=i;
end;

function TFlagsMaterialParameter.PackVis: string;
var
  i: integer;
begin
  Result:='';
  for i:=0 to High(FVisibility) do
    Result:=Result + IntToStr(Integer(FVisibility[i])) + ';';
  if Length(Result) > 0 then
    SetLength(Result, Length(Result) - 1);
end;

procedure TFlagsMaterialParameter.UnpackVis(const v: string);
var
  i, j: Integer;
  e: TExplodedString;
begin
  e:=ExplodeString(v, ';');
  SetLength(FVisibility, Length(e));
  for i:=0 to High(e) do
    if TryStrToInt(Trim(e[i]), j) then
      FVisibility[i]:=Boolean(j)
    else
      FVisibility[i]:=true;
end;

{ TVoxelAngleMaterialParameter }

function TVoxelAngleMaterialParameter.GetValue: Single;
begin
  Result:=ArcTan(0.5 * Value) * 2.0 * 180 / PI;
end;

procedure TVoxelAngleMaterialParameter.SetValue(const Value: Single);
var
  p: TMaterialParameter;
begin
  if GetValue <> Value then
  begin
    if assigned(FLink) then
    begin
      p:=FLink.LockRef;
      try
        if p <> nil then
        begin
          p.SetAsFloat(Value);
          exit;
        end;
      finally
        FLink.UnlockRef;
      end;
    end;
    Self.Value:=Tan((Value / 180 * PI) * 0.5) * 2.0
  end;
end;

{ TSurfacePointDebugInfo }

procedure TSurfacePointDebugInfo.AddMessage(const msg: string);
begin
  FMsgs.Add(msg);
end;

constructor TSurfacePointDebugInfo.Create;
begin
  inherited;
  FMsgs:=TStringList.Create;
end;

destructor TSurfacePointDebugInfo.Destroy;
begin
  FMsgs.Free;
  inherited;
end;

function TSurfacePointDebugInfo.GetInfo: TObject;
begin
  Result:=self;
end;

function TSurfacePointDebugInfo.GetText: string;
begin
  Result:=FMsgs.Text;
end;

{ TFloatMaterialParameterWithConverter }

procedure TFloatMaterialParameterWithConverter.ConvertedValue(
  Read: boolean; var Value: single);
begin
  if assigned(FOnNeedValue) then
    FOnNeedValue(Self, Read, Value);
end;

procedure TFloatMaterialParameterWithConverter.Setup;
begin
  inherited;
  FType:=mptFloatConv;
end;

{ TSunMaterial }

constructor TSunMaterial.Create(aOwner: TObject);
begin
  FInnerRadius:=TFloatMaterialParameter.Create(self);
  FOuterRadius:=TFloatMaterialParameter.Create(self);
  inherited;
end;

destructor TSunMaterial.Destroy;
begin
  FInnerRadius.Free;
  FOuterRadius.Free;
  inherited;
end;

function TSunMaterial.GetShine: boolean;
begin
  Result:=FFlags.GetFlag(0);
end;

class function TSunMaterial.GetTypeIndex: integer;
begin
  Result:=7;
end;

function TSunMaterial.IsLightSource: boolean;
begin
  Result:=True;
end;

procedure TSunMaterial.SetShine(const Value: boolean);
begin
  FFlags.SetFlag(0, Value);
end;

procedure TSunMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;
  with Parameters.UpgradeFloatParameter('', 'SunInnerRadius', 1.5) do
  begin
    FCategory:=cLEmissionCategory;
    FInnerRadius.LinkTo(this);
    FAltName:=tr('Внутренний радиус');
    FCustomizable:=true;
  end;

  with Parameters.UpgradeFloatParameter('', 'SunOuterRadius', 2.5) do
  begin
    FCategory:=cLEmissionCategory;
    FOuterRadius.LinkTo(this);
    FAltName:=tr('Внешний радиус');
    FCustomizable:=true;
  end;
  Parameters.EndUpdate;
end;

procedure TSunMaterial.Upgrade;
begin
  inherited;

  if FVersion = 0 then
  begin
    Parameters.BeginUpdate;

    with Parameters.UpgradeFloatParameter('', 'voxSunAmbient', 0.0) do
    begin
      FCategory:=cLVoxLightCategory;
      FAltName:=tr('Уровень амбиента солнца');
      FCustomizable:=true;
    end;

    with Parameters.UpgradeFloatParameter('', 'voxSunRadius', 0.5) do
    begin
      FCategory:=cLVoxEmissionCategory;
      FAltName:=tr('Радиус');
      FCustomizable:=true;
    end;

    Parameters.GetFloatParam('voxShadowDensity').FValue := 1.0;
    Parameters.GetFloatParam('EmissionLevel').FValue := 15.0;
    Parameters.GetFloatParam('voxEmissionLevel').FValue := 10.0;
    Parameters.GetFloatParam('LightPower').FValue := 10.0;
    Parameters.GetFloatParam('voxLightPower').FValue := 10.0;

    Parameters.GetFloatParam('EmissionLevel').FCustomizable := True;
    Parameters.GetColorParam('EmissionColor').FCustomizable := True;

    Parameters.EndUpdate;
  end;
  if FVersion = 7 then
    FLightType.Customizable := False;
end;

{ TInternalLightMaterial }

class function TInternalLightMaterial.GetTypeIndex: integer;
begin
  Result:=8;
end;

{ TBumpOnlyMaterial }

constructor TBumpOnlyMaterial.Create(aOwner: TObject);
begin
  FBumpMap:=TTextureMaterialParameter.Create(self);
{  FTexMatrix:=TMatrixMaterialParameter.Create(self);
  FTexMatrix.Value:=IdentityHmgMatrix;}
  FTexTransform := TTexTransformMaterialParameter.Create(Self);
  FTexWrapMode := TTexWrapModeMaterialParameter.Create(Self);
  inherited;
end;

destructor TBumpOnlyMaterial.Destroy;
begin
  FBumpMap.Free;
//  FTexMatrix.Free;
  FTexTransform.Free;
  FTexWrapMode.Free;
  inherited;
end;

procedure TBumpOnlyMaterial.EvalMaterialAt(aPoint: TSurfacePoint;
  EvalMode: integer);
begin
  aPoint.SetNormal(GetNormal(aPoint));
  inherited;
end;

function TBumpOnlyMaterial.GetNormal(aPoint: TSurfacePoint): TAffineVector;
var
  nm, uvw: TAffineVector;
begin
  if FTextures.Cache = nil then
    FTextures.SetupCache(['basemap', 'bumpmap'],
      [{FTexMatrix.ValuePointer, FTexMatrix.ValuePointer}FTexTransform.MatrixCashePointer, FTexTransform.MatrixCashePointer]);
  if FTextures.Cache[1].sampler <> nil then
  begin
    uvw:=VectorTransform(aPoint.TexCoord, {FTexMatrix.Value}FTexTransform.MatrixCashe);
    nm:=VectorAdd(VectorScale(TVectorCoords(FTextures.Cache[1].sampler.SampleLinear2d(
      VectorMake(uvw, ComputeLod(aPoint.DistanceFromEyeForLod, aPoint.ViewResolution, aPoint.GetTexelSize / FTextures.Cache[1].texelScale)))).XYZ, 2.0), -1.0);
    Result:=VectorNormalize(VectorTransform(nm, aPoint.TangentSpace));
  end
  else
    Result:=inherited GetNormal(aPoint);
end;

function TBumpOnlyMaterial.GetShaderEvaluationCase: string;
var
  bm: TTextureMaterialParameter;
begin
  Result:=inherited GetShaderEvaluationCase;
  if Parameters.FindParameter('bumpmap', bm) then
    Insert(
    't = ' + bm.GetAtlasPositionForShader + ';' +
    't.xy += uv * ' + bm.GetAtlasScaleForShader + ';' +
    'bn = $TEXATLAS.SampleLevel( $LINEARSAMPLER, t, 0.0 ) * 2.0 - 1.0;' +
    'm[0] = tangent;' +
    'm[1] = binormal;' +
    'm[2] = n;' +
    'n = normalize( mul( bn, m ) );'
    , Result, AnsiPos('$RESULT.xyz = ', Result));
end;

class function TBumpOnlyMaterial.GetTypeIndex: integer;
begin
  Result:=9;
end;

procedure TBumpOnlyMaterial.SetAtlas(aAtlas: TMaterialTextureAtlas);
var
  v: TTextureValue;
begin
  inherited;
  v:=FBumpMap.Value;
  v.TexelScale:=v.TexelScale *{/}
    (VectorLength({FTexMatrix.Value[0]}FTexTransform.MatrixCashe[0]) * VectorLength({FTexMatrix.Value[1]}FTexTransform.MatrixCashe[1]));
  v.TexelScale:=0.5 * log2(v.TexelScale);
  FBumpMap.Value:=v;
end;                                                                                 

procedure TBumpOnlyMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;
  with Parameters.NewTexture('BumpMap') do
  begin
    FBumpMap.LinkTo(this);
    FCustomizable:=true;
  end;

  with Parameters.NewTexWrapMode('texWrapMode') do
  begin
    FTexWrapMode.LinkTo(this);
    FCustomizable:=true;
  end;

{  with Parameters.NewMatrix('TexMatrix') do
  begin
    FTexMatrix.LinkTo(this);
    Value:=IdentityHmgMatrix;
    FCustomizable:=true;
    FUpdatable:=True;
  end;}

  Parameters.EndUpdate;
end;

procedure TBumpOnlyMaterial.Upgrade;
begin
  inherited;
  if FVersion = 0 then
  begin
    FBumpMap.LinkTo(FParameters.FindParameter('bumpMap'));
//    FTexMatrix.LinkTo(FParameters.FindParameter('texMatrix'));
  end;
  if FVersion = 1 then
    FTexTransform.LinkTo(FParameters.FindParameter('texTransform'));
  if FVersion = 5 then
    FTexWrapMode.LinkTo(FParameters.FindParameter('texWrapMode'));
end;

{ TTypeMaterialParameter }

procedure TTypeMaterialParameter.GetDataFrom(p: pointer);
var
  v: Integer;
begin
  inherited;
  Move(p^, v, sizeof(FValue));
  Value:=v;
end;

function TTypeMaterialParameter.GetValue: Integer;
begin
  if (FOwner is TMaterialParameters) and (TMaterialParameters(FOwner).FOwner is TMaterial) then
    Result:=TMaterial(TMaterialParameters(FOwner).FOwner).FType
  else
    Result:=inherited GetValue;
end;

procedure TTypeMaterialParameter.PlaceDataAt(p: pointer);
var
  v: Integer;
begin
  inherited;
  v:=GetValue;
  Move(v, p^, sizeof(FValue));
end;

{ TParamID }

constructor TParamID.Create(aID, aOffset: integer);
begin
  ID:=aID;
  Offset:=aOffset;
end;

function GetMaterialTextures: TMaterialTexturesTypeLibrary;
begin
  if MaterialTextures = nil then
    MaterialTextures:=TMaterialTexturesTypeLibrary.Create;
  Result:=MaterialTextures;
end;

{ TTextureRef }

constructor TTextureRef.Create(const aRefTo: TMaterialTexture; Own: boolean);
begin
  inherited Create(aRefTo);
  FOwn:=Own;
end;

destructor TTextureRef.Destroy;
begin
  if FOwn then
  begin
    LockRef.Free;
    UnlockRef;
  end;
  inherited;
end;

function TTextureRef.LockRef: TMaterialTexture;
begin
  Result:=TMaterialTexture(inherited LockRef);
end;

{ TSkyMaterial }

constructor TSkyMaterial.Create(aOwner: TObject);
begin
  FAngle1:=TFloatMaterialParameter.Create(self);
  FAngle2:=TFloatMaterialParameter.Create(self);
  inherited;
end;

destructor TSkyMaterial.Destroy;
begin
  FAngle1.Free;
  FAngle2.Free;
  inherited;
end;

class function TSkyMaterial.GetTypeIndex: integer;
begin
  Result:=12;
end;

procedure TSkyMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;
  with Parameters.UpgradeFloatParameter('', 'SkyAngle1') do
  begin
    FCategory:=cLightCategory;
    FAngle1.LinkTo(this);
    FAltName:=tr('Угол поворота небесной сферы');
    FCustomizable:=true;
  end;

  with Parameters.UpgradeFloatParameter('', 'SkyAngle2') do
  begin
    FCategory:=cLightCategory;
    FAngle2.LinkTo(this);
    FAltName:=tr('Угол наклона небесной сферы');
    FCustomizable:=true;
  end;
  Parameters.EndUpdate;
end;

procedure TSkyMaterial.Upgrade;
begin
  inherited;

  if FVersion = 0 then
  begin
    Parameters.BeginUpdate;

    with Parameters.UpgradeFloatParameter('', 'voxSkyAmbient', 0.5) do
    begin
      FCategory:=cLVoxLightCategory;
      FAltName:=tr('Уровень амбиента неба');
      FCustomizable:=true;
    end;
       
    Parameters.GetFloatParam('voxShadowDensity').FValue := 0.5;
    Parameters.GetFloatParam('LightPower').FCustomizable := False;
    Parameters.GetColorParam('LightColor').FCustomizable := False;  
    Parameters.GetFloatParam('EmissionLevel').FCustomizable := True;
    Parameters.GetColorParam('EmissionColor').FCustomizable := True;
    Parameters.GetFloatParam('EmissionLevel').FValue := 10;

    Parameters.EndUpdate;
  end;
end;

{ TMaterialParameterRef }

function TMaterialParameterRef.LockRef: TMaterialParameter;
begin
  Result:=TMaterialParameter(inherited LockRef);
end;

{ TMaterialParametersRef }

function TMaterialParametersRef.LockRef: TMaterialParameters;
begin
  Result:=TMaterialParameters(inherited LockRef);
end;

{ TMaterialParameterSmartRef }

constructor TMaterialParameterSmartRef.Create(const p: TMaterialParameter);
begin
  inherited Create;
  if p <> nil then
  begin
    FName:=p.FName;
    if p.Owner is TMaterialParameters then
      FListLink:=TMaterialParametersSmartRef.Create(TMaterialParameters(p.Owner));
    FLink:=TMaterialParameterRef.Create(p);
  end
  else
    FLink:=TMaterialParameterRef.CreateStatic;
end;

destructor TMaterialParameterSmartRef.Destroy;
begin
  FListLink.Free;
  FLink.Free;
  inherited;
end;

function TMaterialParameterSmartRef.LockRef: TMaterialParameter;
  procedure TryRestoreLink;
  var
    list: TMaterialParameters;
    p: TMaterialParameter;
  begin
    if (FListLink <> nil) and (FName <> '') then
    begin
      list:=FListLink.LockRef;
      try
        if (list <> nil) and list.FindParameter(FName, p) then
          FLink.ModifyLink(p);
      finally
        FListLink.UnlockRef;
      end;
    end
  end;
begin
  Result:=FLink.LockRef;
  if Result = nil then
  begin
    FLink.UnlockRef;
    TryRestoreLink;
    Result:=FLink.LockRef;
  end;
end;

procedure TMaterialParameterSmartRef.UnlockRef;
begin
  FLink.UnlockRef;
end;

{ TRootLightMaterial }

constructor TRootLightMaterial.Create(aOwner: TObject);
begin
  FLightType:=TIntegerMaterialParameter.Create(self);
  FLightType.Value:=0;
  FLightColor:=TColorMaterialParameter.Create(self);
  FLightColor.Value:=XYZVector;
  FLightPower:=TFloatMaterialParameter.Create(self);
  FLightPower.Value:=10.0;
  FFlags:=TFlagsMaterialParameter.Create(self);
  FEmissionColor:=TColorMaterialParameter.Create(self);
  FEmissionColor.Value:=AffineVectorMake(1.0, 1.0, 1.0);
  FEmissionPower:=TFloatMaterialParameter.Create(self);
  FEmissionPower.Value:=10.0;
  inherited;
end;

destructor TRootLightMaterial.Destroy;
begin
  FLightType.Free;
  FLightColor.Free;
  FLightPower.Free;
  FFlags.Free;
  FEmissionColor.Free;
  FEmissionPower.Free;
  inherited;
end;

function TRootLightMaterial.GetEmissionLevel: Single;
begin
  Result:=FLightPower.Value;
end;

function TRootLightMaterial.GetEmissive: TAffineVector;
begin
  Result:=VectorScale(FLightColor.Value, FLightPower.Value);
end;

function TRootLightMaterial.IsTransparent: boolean;
begin
  Result:=not FFlags.GetFlag(0);
end;

procedure TRootLightMaterial.SetupParametersList;
begin
  Parameters.BeginUpdate;
  inherited;

  with Parameters.UpgradeIntegerParameter('', 'LightType', 0) do
  begin
    FAltName:=tr('Тип источника');
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FLightType.LinkTo(this);
  end;

  with Parameters.UpgradeFlagsParameter('Флаги', 'LightFlags', 0) do
  begin
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FFlags.LinkTo(this);
    SetFlagsNames(langRussian, ['Видимый']);
    SetFlagsNames(langEnglish, ['Visible']);
    SetFlagsVisibility([true]);
  end;

  //Цвет в сцене
  with Parameters.UpgradeFloatParameter('', 'EmissionLevel', 10.0) do
  begin
    FAltName := tr('Уровень материала источника');
    FCustomizable:=true;
    FCategory:=cLEmissionCategory;
    Value := Value;
    FEmissionPower.LinkTo(this);
  end;

  with Parameters.UpgradeColorParameter('', 'EmissionColor', 1.0, 1.0, 1.0) do
  begin
    FAltName:=tr('Цвет источника');
    FCustomizable:=true;
    FCategory:=cLEmissionCategory;
    FEmissionColor.LinkTo(this);
  end;

  //Цвет в вокселях
  with Parameters.UpgradeFloatParameter('', 'voxEmissionLevel', 10.0) do
  begin
    FAltName := tr('Уровень материала источника');
    FCustomizable:=true;
    FCategory:=cLVoxEmissionCategory;
  end;

  with Parameters.UpgradeColorParameter('', 'voxEmissionColor', 1.0, 1.0, 1.0) do
  begin
    FAltName:=tr('Цвет источника');
    FCustomizable:=true;
    FCategory:=cLVoxEmissionCategory;
  end;

  //Освещение сцены

  with Parameters.UpgradeFloatParameter('', 'LightPower', 10.0) do
  begin
    FAltName := tr('Уровень излучения источника');
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FLightPower.LinkTo(this);
    Value := Value;
  end;

  with Parameters.UpgradeColorParameter('', 'LightColor', 1.0, 1.0, 1.0) do
  begin
    FAltName:=tr('Цвет излучения источника');
    FCustomizable:=true;
    FCategory:=cLLightCategory;
    FLightColor.LinkTo(this);
  end;

  //Освещение вокселей
  with Parameters.UpgradeFloatParameter('', 'VoxLightPower', 10.0) do
  begin
    FAltName := tr('Уровень излучения источника');
    FCustomizable:=true;
    FCategory:=cLVoxLightCategory;
    Value := Value;
  end;

  with Parameters.UpgradeColorParameter('', 'VoxLightColor', 1.0, 1.0, 1.0) do
  begin
    FAltName:=tr('Цвет излучения источника');
    FCustomizable:=true;
    FCategory:=cLVoxLightCategory;
    FLightColor.LinkTo(this);
  end;

  with Parameters.UpgradeFloatParameter('', 'voxShadowDensity', 0.3) do
  begin
    FAltName := tr('Уровень тени');
    FCustomizable:=true;
    FCategory:=cLVoxLightCategory;
  end;

  Parameters.EndUpdate;
end;

function TRootLightMaterial.UnknownParameter(const aName, aClass: string;
  var LoadInfo: TLoadInfo): TObject;
begin
  Result:=Parameters.NewParameter(aName, MaterialParams.GetTypeByClassname(aClass));
end;

procedure TRootLightMaterial.Upgrade;
begin
  inherited;
  //Exit;
  if FVersion = 0 then
  begin
    Parameters.BeginUpdate;
    with Parameters.UpgradeFlagsParameter('Флаги', 'LightFlags', 0) do
      FFlags.LinkTo(this);

    with Parameters.UpgradeIntEnumParameter('LightType', '') do
    begin
      SetCaptions([tr('Прожектор'), tr('Точечный'), tr('Параллельный')]);
      FLightType.LinkTo(this);
    end;
               
    Parameters.GetFloatParam('EmissionLevel').FCustomizable := True;
    Parameters.GetColorParam('EmissionColor').FCustomizable := True;
    Parameters.EndUpdate;
  end;
end;

{ TWindowMaterial }

class function TWindowMaterial.GetTypeIndex: integer;
begin
  Result:=13;
end;

{ TMaterialRef }

function TMaterialRef.LockRef: TMaterial;
begin
  Result:=TMaterial(inherited LockRef);
end;

{ TMaterialParametersSmartRef }

constructor TMaterialParametersSmartRef.Create(
  const p: TMaterialParameters);
begin
  inherited Create;
  if p <> nil then
  begin
    if p.Owner is TMaterial then
      FOwnerLink:=TMaterialRef.Create(p.Owner);
    FLink:=TMaterialParametersRef.Create(p);
  end
  else
    FLink:=TMaterialParametersRef.CreateStatic;
end;

destructor TMaterialParametersSmartRef.Destroy;
begin
  FOwnerLink.Free;
  FLink.Free;
  inherited;
end;

function TMaterialParametersSmartRef.LockRef: TMaterialParameters;
  procedure TryRestoreLink;
  var
    m: TMaterial;
  begin
    if (FOwnerLink <> nil) then
    begin
      m:=FOwnerLink.LockRef;
      try
        if (m <> nil) and (m.FParameters <> nil) then
          FLink.ModifyLink(m.FParameters);
      finally
        FOwnerLink.UnlockRef;
      end;
    end
  end;
begin
  Result:=FLink.LockRef;
  if Result = nil then
  begin
    FLink.UnlockRef;
    TryRestoreLink;
    Result:=FLink.LockRef;
  end;
end;

procedure TMaterialParametersSmartRef.UnlockRef;
begin
  FLink.UnlockRef;
end;

{ TIntEnumMaterialParameter }

const
  cCapMagic = $01237811;

procedure TIntEnumMaterialParameter.Assign(src: TMaterialParameter);
begin
  if src is TIntEnumMaterialParameter then
  begin
    FCaptions:=TIntEnumMaterialParameter(src).FCaptions;
  end;
  inherited;
end;

function TIntEnumMaterialParameter.GetEnumCaptions: string;
begin
  Result:=AnsiReplaceStr(FCaptions, ';', #13#10);
end;

procedure TIntEnumMaterialParameter.LoadFromXml(const root: TXMLNode;
  const LoadFlags: cardinal);
begin
  if assigned(root) then
  begin
    FCaptions:=Utf8ToAnsi(root.AttributeByName['Caps'].Value);
  end;
  inherited;
end;

function TIntEnumMaterialParameter.LoadParam(
  var LoadInfo: TLoadInfo): integer;
begin
  Result:=0;
  with LoadInfo, Reader, CurrentBlock do
    case BlockType of
      btIntEnumParameterCaps: FCaptions:=ReadString;
    else
      Result:=inherited LoadParam(LoadInfo);
    end;
end;

procedure TIntEnumMaterialParameter.ReadFromFiler(ReadInfo: TReadInfo);
begin
  inherited;
  if ReadInfo.Reader.CheckMagic(cCapMagic) then
    FCaptions:=ReadInfo.Reader.ReadString;
end;

procedure TIntEnumMaterialParameter.SaveObject(var SaveInfo: TSaveInfo);
begin
  with SaveInfo, Writer do
  try
    WriteString(btIntEnumParameterCaps, FCaptions);
  except
    on e: exception do
      SaveInfo.Error('TIntEnumMaterialParameter: ' + e.Message);
  end;
  inherited;
end;

procedure TIntEnumMaterialParameter.SaveToXml(const root: TXMLNode;
  const SaveFlags: cardinal);
begin
  if assigned(root) then
  begin
    root.GetOrCreateAttr('Caps').Value := AnsiToUtf8(FCaptions);
  end;
  inherited;
end;

procedure TIntEnumMaterialParameter.SetCaptions(
  const caps: array of string);
var
  i: integer;
begin
  FCaptions:='';
  for i:=0 to High(caps) do
    FCaptions:=FCaptions + caps[i] + ';';
  if FCaptions <> '' then
    SetLength(FCaptions, Length(FCaptions) - 1);
end;

procedure TIntEnumMaterialParameter.Setup;
begin
  inherited;
  FType:=mptIntEnum;
end;

procedure TIntEnumMaterialParameter.WriteToFiler(WriteInfo: TWriteInfo);
begin
  inherited;
  WriteInfo.Writer.WriteMagic(cCapMagic);
  WriteInfo.Writer.WriteString(FCaptions);
end;

{ TNotifyEventRef }

procedure TNotifyEventRef.Notify(Sender: TObject);
var
  v: TNotifyEvent;
begin
  TMethod(v) := LockRef;
  try
    if assigned(v) then
      v(Sender);
  finally
    UnlockRef;
  end;
end;


{ TPBRMaterial }

procedure TPBRMaterial.Upgrade;
begin
  inherited;
{$IFDEF PBR_ENABLE}
  if FVersion = 8 then
  begin
    Parameters.BeginUpdate;

    with Parameters.NewFloat('pbr_opacity') do
    begin
      FAltName := tr('Непрозрачность');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 1;
    end;

    with Parameters.NewFloat('pbr_emission') do
    begin
      FAltName := tr('Множитель светимости');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0;
    end;

    with Parameters.NewColor('pbr_emission_color') do
    begin
      FAltName := tr('Цвет светимости');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := XYZVector;
    end;

    with Parameters.NewFloat('pbr_metalness') do
    begin
      FAltName := tr('Металличность');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0;
    end;

    with Parameters.NewFloat('pbr_base') do
    begin
      FAltName := tr('Базовый множитель');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0.8;
    end;

    with Parameters.NewColor('pbr_base_color') do
    begin
      FAltName := tr('Базовый цвет');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := XYZVector;
    end;

    with Parameters.NewFloat('pbr_specular') do
    begin
      FAltName := tr('Степень отражения');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 1;
    end;

    with Parameters.NewColor('pbr_specular_color') do
    begin
      FAltName := tr('Цвет отражения');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := XYZVector;
    end;

    with Parameters.NewFloat('pbr_roughness') do
    begin
      FAltName := tr('Шероховатость');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0.2;
    end;

    with Parameters.NewFloat('pbr_specular_ior') do
    begin
      FAltName := tr('Показатель преломления');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 1.5;
    end;

    with Parameters.NewFloat('pbr_transmittance') do
    begin
      FAltName := tr('Степень пропускания света');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0;
    end;

    with Parameters.NewColor('pbr_transmittance_color') do
    begin
      FAltName := tr('Цвет пропускания');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := XYZVector;
    end;

    with Parameters.NewFloat('pbr_transmittance_depth') do
    begin
      FAltName := tr('Глубина затухания');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0;
    end;

    with Parameters.NewFloat('pbr_thin_film_thickness') do
    begin
      FAltName := tr('Толщина плёнки');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0;
    end;

    with Parameters.NewFloat('pbr_thin_film_ior') do
    begin
      FAltName := tr('Коэффициент отражения плёнки');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 1.5;
    end;
  
    Parameters.EndUpdate;
  end;

  if FVersion = 9 then
  begin
    Parameters.BeginUpdate;

    with Parameters.NewFloat('pbr_albedo_correction') do
    begin
      FAltName := tr('Коррекция Albedo');
      FCustomizable := true;
      FCategory := cPBRCategory;
      Value := 0;
    end;

    Parameters.EndUpdate;
  end;

  if FVersion = 10 then
  begin
    Parameters.BeginUpdate;

    with Parameters.NewFloat('coat') do
    begin
      FAltName := tr('Степень влияния');
      FCustomizable := true;
      FCategory := cCoatCategory;
      Value := 0;
    end;

    with Parameters.NewColor('coat_color') do
    begin
      FAltName := tr('Цвет покрытия');
      FCustomizable := true;
      FCategory := cCoatCategory;
      Value := XYZVector;
    end;

    with Parameters.NewFloat('coat_roughness') do
    begin
      FAltName := tr('Шероховатость покрытия');
      FCustomizable := true;
      FCategory := cCoatCategory;
      Value := 0.1;
    end;

    with Parameters.NewFloat('coat_ior') do
    begin
      FAltName := tr('Коэффициент отражения покрытия');
      FCustomizable := true;
      FCategory := cCoatCategory;
      Value := 1.5;
    end;

    Parameters.EndUpdate;
  end;
{$ENDIF}
end;

procedure TPBRMaterial.CalcPBRParams;
begin
  //
end;

function TPBRMaterial.PBRParamsIsDefault: Boolean;
const
  pbr_base: Single = 0.8;
  pbr_roughness: Single = 0.2;
  pbr_specular_ior: Single = 1.5;
  pbr_thin_film_ior: Single = 1.5;
begin
  Result := False;
  with Parameters do
  begin
    if FloatParameter['pbr_opacity'].Value <> 1 then exit;
    if FloatParameter['pbr_emission'].Value <> 0 then exit;
    if not VectorEquals(ColorParameter['pbr_emission_color'].Value, XYZVector) then exit;
    if FloatParameter['pbr_metalness'].Value <> 0 then exit;
    if FloatParameter['pbr_base'].Value <> pbr_base then exit;
    if not VectorEquals(ColorParameter['pbr_base_color'].Value, XYZVector) then exit;
    if FloatParameter['pbr_specular'].Value <> 1 then exit;
    if not VectorEquals(ColorParameter['pbr_specular_color'].Value, XYZVector) then exit;
    if FloatParameter['pbr_roughness'].Value <> pbr_roughness then exit;
    if FloatParameter['pbr_specular_ior'].Value <> pbr_specular_ior then exit;
    if FloatParameter['pbr_transmittance'].Value <> 0 then exit;
    if not VectorEquals(ColorParameter['pbr_transmittance_color'].Value, XYZVector) then exit;
    if FloatParameter['pbr_transmittance_depth'].Value <> 0 then exit;
    if FloatParameter['pbr_thin_film_thickness'].Value <> 0 then exit;
    if FloatParameter['pbr_thin_film_ior'].Value <> pbr_thin_film_ior then exit;

    Result := True;
  end;
end;

initialization

  MaterialTypes:=TMaterialTypeLibrary.Create(nil);
  MaterialTypes.RegisterTypes([TLightMaterial, TDiffuseMaterial, TTextureMaterial, TBumpMaterial, TMirrorMaterial,
                               TGlassMaterial, TTileMaterial, TSunMaterial, TInternalLightMaterial,
                               TBumpOnlyMaterial, TDiffuseLightMaterial, TMultiMaterial, TSkyMaterial, TWindowMaterial]);

  MaterialParams:=TMaterialParamsTypeLibrary.Create;
  MaterialParams.RegisterTypes([TTypeMaterialParameter, TIntegerMaterialParameter, TIntEnumMaterialParameter, TFloatMaterialParameter, TFloatMaterialParameterWithConverter,
    TFloat3MaterialParameter, TFloat4MaterialParameter,
    TColorMaterialParameter, TMatrixMaterialParameter, TTextureMaterialParameter, TVoxelAngleMaterialParameter, TFlagsMaterialParameter,
    TMonoMaterialParameter, TTexTransformMaterialParameter, TReflMaterialParameter, TTexWrapModeMaterialParameter]);

  GetMaterialTextures.RegisterTypes([TMaterialTexture, TAtlasMaterialTexture, TMaterialTextureAtlas, TFileTextureDataSource, TMemoryTextureDataSource, TGUIDedTextureDataSource]);

  CategoriesList := GetCategoriesList;
  MapKindsList := GetMapKindsList;
  //RegisterClasses([TGLMaterialLibrary, TGLLibMaterial, TGLPatternMaterial]);
    {0: Result:=TLightMaterial;
    1: Result:=TDiffuseMaterial;
    2: Result:=TTextureMaterial;
    3: Result:=TBumpMaterial;
    4: Result:=TMirrorMaterial;
    5: Result:=TGlassMaterial;
    6: Result:=TTileMaterial;
    7: Result:=TSunMaterial;
    8: Result:=TInternalLightMaterial;
    9: Result:=TBumpOnlyMaterial;
    10: Result:=TDiffuseLightMaterial;
    11: Result:=TMultiMaterial;
    12: Result:=TSkyMaterial;
    13: Result:=TWindowMaterial}
finalization

  CategoriesList.Free;

  MaterialTypes.Free;
  MaterialParams.Free;
  MaterialTextures.Free;
  ShaderIDs.Free;

end.
