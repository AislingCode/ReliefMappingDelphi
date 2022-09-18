{: GLMultiPolygon<p>

   Object with support for complex polygons.<p>

 <b>History : </b><font size=-1><ul>
      <li>18/11/04 - SG - Fixed TGLMultiPolygonBase.Destroy memory leak (Neil)
      <li>05/09/03 - EG - TNotifyCollection moved to GLMisc
      <li>14/07/02 - EG - Code cleanups, dropped 'absolutes', fixed mem leaks
      <li>28/12/01 - EG - Added registration (Philipp Pammler)
      <li>19/12/01 - EG - Removed dependency to contnrs (D4 compatibility,
                           TObjectList replaced with TPersistentObjectList)
      <li>29/03/01 - Uwe - Fixes and improvements to TGLMultiPolygon
      <li>21/02/01 - EG - Now XOpenGL based (multitexture)
      <li>08/01/01 - EG - Compatibility fix (TGLLineNodes change),
                           Delphi 4 compatibility (removed TVectorPool) and
                           added/renamed some properties, various fixes
      <li>08/10/00 - EG - Added header, code contributed by Uwe Raabe
   </ul>
}
{ TODO

  ur:

  And I reactivated the TVectorPool object. The VectorLists are not suitable for this job.
  When the tesselator finds an intersection of edges it wants us to give him some storage
  for this new vertex, and he wants a pointer (see tessCombine). The pointers taken from
  TAffineVectorList become invalid after enlarging the capacity (makes a ReAllocMem), which
  can happen implicitly while adding. The TVectorPool keeps all pointers valid until the
  destruction itself.

  If anyone feels responsible: it would be fine to have a method ImportFromFile (dxf?) in
  the TGLContour and TGLMultiPolygonBase objects...
}
unit GLMultiPolygon;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Colors,
  Materials,
  VectorGeometry,
  VectorTypes,
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
  Classes, OpenGL1x, Spline, math, VectorGeometry, VectorLists, PersistentClasses,
	GLScene, GLObjects, GLMisc, GLBaseClass, GLTexture, GLGeomObjects, GeometryBB,
	PropTypes, GLDrawers, Alignments, Graphics, GLContours, ClusterIntf,
  LocalizerDictionaryUnit, uCustomFilers, Contnrs, Metastorage;

type
	TProgressCallback = procedure (progPos: integer; text: string) of object;{(Pos, Max: integer);stdcall;}

  TGLNodesList = class(TPersistentObjectList)
  private
    function GetNode(index: integer): TGLNode;
  public
    procedure AddScaledVector(s: double; Vec: TDAffineVector);
    procedure Add(node: TGLNode);
    property Nodes[index: integer]: TGLNode read GetNode; default;
  end;

	TGLContourNode = class(TGLNode)
  private
		FMoveAxis: TDAffineVector;
    FNormal: TDAffineVector;
	public
		constructor Create(Collection: TCollection); override;
		procedure Assign(Source: TPersistent);override;
		property MoveAxis: TDAffineVector read FMoveAxis write FMoveAxis;
		procedure SetAbsoluteDoublePosition(const vec: TDVector);override;
		procedure UpdateNodeAxis;
		procedure PrepareForMove;override;
    property Normal: TDAffineVector read FNormal write FNormal;

    procedure WriteToFiler(writer: TCustomWriter); override;
		procedure ReadFromFiler(reader: TCustomReader; FileVersion: integer); override;

		function LoadParam(var LoadInfo: TLoadInfo): integer; override;
		procedure SaveObject(var SaveInfo: TSaveInfo); override;
	end;

  // TGLContourNodes
  //
	TGLContourNodes = class(TGLNodes)
  private
    FEditMode: integer;
		procedure SetEditMode(const Value: integer);
	protected
		procedure SelectionChanged(newState: boolean; Sender: TObject; SenderClass: TClass);override;
	public
		constructor Create(AOwner: TPersistent; ItemClass: TCollectionItemClass = nil);
		procedure NotifyChange; override;
		function GetSceneObject: TObject;override;
		property EditMode: integer read FEditMode write SetEditMode;
		procedure UpdateNodesAxis;
		procedure BuildList(var rci: TRenderContextInfo; middle: boolean = false);override;
	end;

	TGLProfile = class;
	TCornerStyle = (csRound, csSmooth, csSharp);

  TMatrixArray = array of TDMatrix;

  TTransformationList = class
  private
    FList: TMatrixArray;
    FGrowIncrement: Integer;
    FCount: Integer;
  public
    constructor Create(const AGrowIncrement: Integer = 1);
    destructor Destroy; override;
    function Add(const m: TDMatrix): Integer;
    function GetItem(const i: Integer): TDMatrix;
    procedure SetItem(const i: Integer; const m: TDMatrix);
    function GetCount: Integer;
    property Count: Integer read GetCount;
    property Items[const i: Integer]: TDMatrix read GetItem write SetItem; default;
  end;

	// TGLContour
	//
	TGLContour = class(TInterfacedCollectionItem, IClusteredIO)
  private
		FNodes: TGLContourNodes;
    FDivision: Integer;
    FSplineMode: TLineSplineMode;
    FDescription: string;
    FHole: boolean;
    FNoDeriv: boolean;
    FMetastorage: TMetastorage;
    procedure SetNodes(const Value: TGLContourNodes);
    procedure SetDivision(Value: Integer);
    procedure SetSplineMode(const Value: TLineSplineMode);
    procedure SetDescription(const Value: string);

  protected
    procedure CreateNodes; dynamic;
    procedure NodesChanged(Sender: TObject);
    function GetDisplayName: string; override;

    procedure WriteToFiler(writer: TCustomWriter); virtual;
    procedure ReadFromFiler(reader: TCustomReader; FileVersion: integer); virtual;

		function LoadParam(var LoadInfo: TLoadInfo): integer;
		function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
			const ChildClass: string; const ChildID: string): TObject;
		procedure SaveObject(var SaveInfo: TSaveInfo); {ok}

  public
    constructor Create(Collection: TCollection); override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure AssignTo(Dest: TPersistent); override;
		procedure GetExtents(var min, max: TDAffineVector);
		function TransformedExtents(const m: TDMatrix; ExtentsInfo: PExtentsInfo = nil): TAABB;
		procedure Divide(const DivW: double; const time: double; forceLine: boolean); overload;
		procedure Divide(const DivW, DivH: double; const time: double; forceLine: boolean; const Out_C: TGLContour); overload;
		function ExtractParts(epsi: double): TPersistentObjectList;
		procedure BuildList(var rci: TRenderContextInfo);
		procedure SetEditMode(em: integer);
		function GetNormalVector(x, y: double; Profile: TGLProfile; Style: TCornerStyle;
			var Range: double; Offset: double): TDAffineVector;
		function DistanceToContour(x, y: double): double; overload;
		function DistanceToContour(x, y: double; var NearestP, Norm, Norm1,
			Norm2: TDAffineVector): double; overload;
		function PointInPolygon(x, y: double): boolean;
		procedure EncloseContour;
		procedure IntersectRay(const rayPoint, rayVector: TDAffineVector; Result: TDAffineVectorList);
		procedure DrawPoints(var rci: TRenderContextInfo);
		procedure DeleteShortSegments(e: double);
		procedure SetMinSegmentAngle(Angle, MaxSegmentLength: double);
		function PointInContour(const p: TDAffineVector): Boolean;
    function GetBarycenter: TDAffineVector;
    function GetEqualTransformations(const c: TGLContour; const InitialAngle, Tolerance: Double): TTransformationList;
    function GetMetastorage: TMetaStorage;
    function HasMetaStorage: boolean;
    function GetLength: Double;
    function GetAngle(const aNodeIndex: integer): Double;
	published
		{ Published Declarations }
		property Description: string read FDescription write SetDescription;
		{: The nodes list.<p> }
		property Nodes: TGLContourNodes read FNodes write SetNodes;
		{: Number of divisions for each segment in spline modes.<p>
		 Minimum 1 (disabled), ignored in lsmLines mode. }
		property Division: Integer read FDivision write SetDivision default 10;
		{: Default spline drawing mode.<p>
		 This mode is used only for the curve, not for the rotation path. }
		property SplineMode: TLineSplineMode read FSplineMode write SetSplineMode default lsmLines;
		property Hole: boolean read FHole write FHole;
		property NoDerivatives: boolean read FNoDeriv write FNoDeriv;
  end;

  TGLContourClass = class of TGLContour;

	TGLProfile = class(TGLContour)
	private
		FDefault: boolean;
		FRadius: Double;
    FEdgeWidth: Double;
		FHScale: Double;
    FScale: Double;
	public
		property IsDefault: boolean read FDefault write FDefault;
		property Radius: Double read FRadius write FRadius;
    property EdgeWidth: Double read FEdgeWidth write FEdgeWidth;
		property HeightScale: Double read FHScale write FHScale;
    property Scale: Double read FScale write FScale;
		procedure NormalizeDir;
		function GetNormTilt(Range: Double): TDAffineVector;
		constructor Create(Collection: TCollection); override;
	end;

  // TGLContours
  //
	TGLContours = class(TNotifyCollection, IClusteredIO)
	private
		function GetItems(index: Integer): TGLContour;
		procedure SetItems(index: Integer; const Value: TGLContour);
    function GetPath(i: Integer): TGLContourNodes;
    procedure SetPath(i: Integer; const value: TGLContourNodes);
  protected
		procedure SelectionChanged(newState: boolean; Sender: TObject; SenderClass: TClass);virtual;

  public
    constructor Create(AOwner: TComponent); overload; virtual;
		constructor CreateFromAABB(aabb: TAABB);
		constructor CreateFromContours(contours: TGLExContours);
		procedure WriteToFiler(writer: TCustomWriter); virtual;
		procedure ReadFromFiler(reader: TCustomReader; FileVersion: integer); virtual;
		function LoadParam(var LoadInfo: TLoadInfo): integer;
		function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
		  const ChildClass: string; const ChildID: string): TObject;
		procedure SaveObject(var SaveInfo: TSaveInfo); {ok}
		procedure AssignTo(Dest: TPersistent); override;
    function CalcSquare: Double;
    function GetLength: Double;
    function Add: TGLContour;
    function FindItemID(ID: Integer): TGLContour;
		procedure AddScaledVector(factor: Single; vector: TAffineVector); overload;
		procedure AddScaledVector(factor: Double; vector: TDAffineVector); overload;
		procedure Transform(m: TMatrix; useDouble: boolean = true);overload;
		procedure Transform(m: TDMatrix);overload;
		procedure ZeroZ;
    procedure Scale(Sx, Sy, Sz: double); overload;
    procedure Reverse;
		procedure AddContours(const aContours: TGLContours; transform: PMatrix = nil;
      aFreeSource: Boolean = False);
    procedure FlipHorizontal;
    procedure ToTextFile(fn: string; checkExist: boolean = false);
    procedure FromTextFile(fn: string);
    procedure SaveToStream(const aStream: TStream);
    procedure LoadFromStream(const aStream: TStream);
		function AddInternalContour(startIndex: integer = 0; used: TIntegerList = nil): TGLContour;
    function AddInternalContours: TGLContours;
    procedure ExcludeNotClosed;
		procedure KickEqualPoints(checkEnds: boolean);
    procedure KickPointsOnOneLine;
		property Items[index: Integer]: TGLContour read GetItems write SetItems; default;
		procedure Public_WriteToFiler(writer: TCustomWriter);
    procedure Public_ReadFromFiler(reader: TCustomReader; FileVersion: integer);
		procedure GetExtents(var min, max: TDAffineVector);
		function TransformedExtents(const m: TDMatrix; ExtentsInfo: PExtentsInfo = nil): TAABB;
		function GetSelf: TGLContours;
    procedure CopySingleToDouble;
    function CollectNodesAboveLine(lineAABB: TAABB; CheckX: boolean; Above: boolean): TGLNodesList;
		procedure Simmetrize;
		function Barycenter: TDAffineVector;
		procedure DeleteShortSegments(e: double);
		procedure SetMinSegmentAngle(Angle, MaxSegmentLength: double);
    function CountSolids: integer;
    function CountHoles: integer;
    procedure DoUpdate;
    function GetVectorList: TAffineVectorList;
		//ƒелает все контуры пр€моугольными (используетс€ дл€ булевых операций с зелеными окнами)
		function ConvertToRectangles: TGLContours;
		procedure Divide(const DivW: double; const time: TIntegerDoubleList); overload;
		function Divide(const DivW, DivH: double; const time: TIntegerDoubleList): TGLContours; overload;
		procedure DeleteWrongContours;
		procedure BuildList(var rci: TRenderContextInfo);
		function GetSceneObject: TObject;virtual;
		procedure SetEditMode(em: integer);
		class procedure GetExpandedContour(src, dst: TGLContours; const height: double);
		procedure ExpandBorder(height: double);
    property Path[i: Integer]: TGLContourNodes read GetPath write SetPath;
		procedure RetrieveOutline(List, BeginProc, AddVertexProc, EndProc: pointer;
			outlineOnly: boolean; normal: PAffineVector = nil);
		procedure Tesselate(var d: TPolygonDrawers; normal: PAffineVector = nil);overload;
		function Tesselate(normal: PAffineVector = nil): TPolygonDrawers;overload;
		function GetTriangles: TAffineVectorList;
		function GenNormalMap(TexWidth, TexHeight, AA: integer; Smoothness,
			Width, Height, EdgeWidth, EdgeRadius: double; Scale: Double = 1.0; Progress: TProgressCallback = nil): TBitmap;
		procedure GenNormalMapEx(src: TBitmap; TexWidth, TexHeight: integer; Smoothness,
			Width, Height, EdgeWidth, EdgeRadius: double; Scale: Double = 1.0; Progress: TProgressCallback = nil);
		procedure EncloseContours;
		function IntersectRay(const rayPoint, rayVector: TDAffineVector): TDAffineVectorList;
		procedure DrawPoints(var rci: TRenderContextInfo);
    procedure DrawLines(var rci: TRenderContextInfo; Color: TVector;
	    Pattern: word; width: single; Closed: boolean);
		function GetExtContours(transform: PDMatrix = nil; aForceClose: Boolean = True): TGLExContours;
		procedure SetContours(aContours: TGLExContours; aCloseIfNeeded: Boolean = False);
		procedure SetRect(width, height: double);
		function PointInContours(const p: TDAffineVector): Boolean;
    function SplitToPolygons: TObjectList;
    function ToJSON(const binaryDataExportPath: string): string;
	end;

  TGLContoursList = class(TPersistentObjectList)
  private
    function GetItem(index: integer): TGLContours;
    procedure SetItem(index: integer; const Value: TGLContours);
  public
    property Items[index: integer]: TGLContours read GetItem write SetItem; default;
    function IndexOfOwner(const aOwner: TPersistent): integer;
  end;

	TGLContoursList2Item = class
	public
		ContoursSK: TGLBaseSceneObject;
		Contours: TGLContours;
		constructor Create(aContoursSK: TGLBaseSceneObject; aContours: TGLContours);
		destructor Destroy;override;
	end;

	TGLContoursList2 = class(TPersistentObjectList)
  private
    function GetItem(index: integer): TGLContoursList2Item;
    procedure SetItem(index: integer; const Value: TGLContoursList2Item);
  public
		property Items[index: integer]: TGLContoursList2Item read GetItem write SetItem; default;
		destructor Destroy;override;
    function IndexOfOwner(const aOwner: TPersistent): integer;
  end;

  // TPolygonList
  //
  TPolygonList = class(TPersistentObjectList)
  private
    FAktList: TAffineVectorList;
    function GetList(I: Integer): TAffineVectorList;

  public
    procedure Add;
    property AktList: TAffineVectorList read FAktList;
    property List[I: Integer]: TAffineVectorList read GetList;
  end;

	// TMultiPolygonBase
  //
  {: Multipolygon is defined with multiple contours.<p>
     The contours have to be in the X-Y plane, otherwise they are projected
     to it (this is done automatically by the tesselator).<br>
     The plane normal is pointing in +Z. All contours are automatically closed,
     so there is no need to specify the last node equal to the first one.<br>
     Contours should be defined counterclockwise, the first contour (index = 0)
     is taken as is, all following are reversed. This means you can define the
		 outer contour first and the holes and cutouts after that. If you give the
     following contours in clockwise order, the first contour is extended.<p>

     TMultiPolygonBase will take the input contours and let the tesselator
     make an outline from it (this is done in RetreiveOutline). This outline is
     used for Rendering. Only when there are changes in the contours, the
     outline will be recalculated. The ouline in fact is a list of VectorLists. }
	TMultiPolygonBase = class(TGLSceneObject)
  private
    { Private Declarations }
		FContours: TGLContours;
    FOutline: TPolygonList;
		FContoursNormal: TAffineVector;
    FTexOffset, FTexScale: TDAffineVector;
		FDrawPolyAsMesh, FPolyCacheValid: boolean;
		FPolygonCache: TPolygonDrawers;

		procedure SetContours(const Value: TGLContours);
		function GetOutline: TPolygonList;
    procedure SetContoursNormal(const Value: TAffineVector);

		function GetTexOffset: TDAffineVector;
		procedure SetTexOffset(const off: TDAffineVector);

		function GetTexScale: TDAffineVector;
		procedure SetTexScale(const off: TDAffineVector);
		procedure SetDrawPolyAsMesh(const v: boolean);

	protected
		{ Protected Declarations }
		function GetDrawPolyAsMesh: boolean;
		procedure DoOnContextRecreate; override;
		procedure RetrieveOutline(List: TPolygonList);
		procedure ContourChanged(Sender: TObject); virtual;
		//property PNormal:PAffineVector read FPNormal;

		procedure WriteToFiler(var WriteInfo: TWriteInfo); override;
		procedure ReadFromFiler(var ReadInfo: TReadInfo); override;

		function LoadParam(var LoadInfo: TLoadInfo): integer; override;
		function GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
			const ChildClass: string; const ChildID: string): TObject; override;
		procedure SaveObject(var SaveInfo: TSaveInfo); override; {ok}

		procedure BuildPropertyPage(var po: TPropertyPageOptions); override;
		procedure RebuildPolyCache;
	public
		{ Public Declarations }
		constructor Create(AOwner: TComponent); override;
		destructor Destroy; override;
		procedure Assign(Source: TPersistent); override;

		procedure AddNode(const i: Integer; const coords: TGLCoordinates); overload;
		procedure AddNode(const i: Integer; const X, Y, Z: TGLfloat); overload;
		procedure AddNode(const i: Integer; const value: TVector); overload;
		procedure AddNode(const i: Integer; const value: TAffineVector); overload;

		function AxisAlignedBoundingBoxUnscaled(IncludeChildren: boolean = false; Validate: boolean = false): TAABB; override;
		function TransformedExtents(const m: TDMatrix; ExtentsInfo: PExtentsInfo = nil): TAABB;override;
		procedure CacheTrackPoints(AbsoluteToLocal: TDMatrix; HowMany: TTrackPointsType); override;
		function GetTrackPoints(Context: TObject; Types: TAlignmentTypeSet;
			IntersectObjects, SkipObjects: TPersistentObjectList;
			AbsoluteToLocal: PDMatrix): TTrackPointsList;override;

		property Outline: TPolygonList read GetOutline;
		property ContoursNormal: TAffineVector read FContoursNormal write SetContoursNormal;
    function GetOwnContours: TGLExContours; override;

		procedure RenderTesselatedPolygon(textured: Boolean;
			normal: PAffineVector; invertNormals: Boolean);

		procedure RenderPolygon(var rci: TRenderContextInfo; const Textured: boolean;
			normal: PAffinevector; invertNormals: boolean);

		property TexOffset: TDAffineVector read FTexOffset write SetTexOffset;
		property TexScale: TDAffineVector read FTexScale write SetTexScale;
		property DrawPolyAsMesh: boolean read FDrawPolyAsMesh write SetDrawPolyAsMesh;

//    procedure NotifyChange(Sender: TObject); override;
		procedure StructureChanged;override;

		procedure BuildCache(var ci: TCacheInfo);override;
		procedure BuildCOMCache(var p: TPrepareKdVertexDataParams);override;
		function GetOutlineContours(flags: TGetOutlineFlags): TGLExContours;override;

		procedure DropAGPCache;
    function TrySetAbsoluteDoubleUp(const up: TDVector): boolean;

  published
    { Published Declarations }
    property Contours: TGLContours read FContours write SetContours;
  end;

  // TGLMultiPolygon
  //
	{: A polygon that can have holes and multiple contours.<p>
	 Use the Path property to access a contour or one of the AddNode methods
	 to add a node to a contour (contours are allocated automatically). }
	TGLMultiPolygon = class(TMultiPolygonBase)
	private
		{ Private Declarations }

		FParts: TPolygonParts;
	protected
		{ Protected Declarations }
		procedure SetParts(const value: TPolygonParts);

		procedure WriteToFiler(var WriteInfo: TWriteInfo); override;
		procedure ReadFromFiler(var ReadInfo: TReadInfo); override;

		function LoadParam(var LoadInfo: TLoadInfo): integer; override;
		procedure SaveObject(var SaveInfo: TSaveInfo); override; {ok}

//    procedure DrawSelection(rci: TRenderContextInfo; shouldRenderSelf: boolean); override;
//		function IsMyReflection(var rci: TRenderContextInfo): boolean;virtual;

	public
		{ Public Declarations }
		constructor Create(AOwner: TComponent); override;
		procedure Assign(Source: TPersistent); override;
		procedure BuildList(var rci: TRenderContextInfo); override;
		procedure DoRender(var rci: TRenderContextInfo;
			renderSelf, renderChildren: Boolean); override;
		procedure DoExecCommand(cmd: cardinal; params: TCommandParams);override;
	published
    { Published Declarations }
		property Parts: TPolygonParts read FParts write SetParts default [ppTop, ppBottom];
//		procedure RecContoursChanged;virtual;
	end;

	procedure DrawArrow(var rci: TRenderContextInfo);
  procedure DrawArrowXY(var rci: TRenderContextInfo; R, G, B: Single);
	procedure DrawPoint(var rci: TRenderContextInfo; pos: TDAffineVector; R, G, B: Single);
	procedure DrawQuadPolygon3D(var rci: TRenderContextInfo; p1, p2, p3, p4: TDAffineVector; R, G, B: Single; BackFace: Boolean; IgnoreStencil: Boolean = True; obj: TObject = nil); overload;
  procedure DrawQuadPolygon3D(var rci: TRenderContextInfo; ab: TAABB; R, G, B: Single; BackFace: Boolean; IgnoreStencil: Boolean = True; obj: TObject = nil); overload;
	procedure DrawTriangle3D(var rci: TRenderContextInfo; p1, p2, p3: TDAffineVector; R, G, B: Single; BackFace: Boolean);
	procedure DrawLine(var rci: TRenderContextInfo; pos1, pos2: TDAffineVector; R, G, B, LineWidth: Single; IgnoreStencil: Boolean = True; obj: TObject = nil);
	procedure DrawLine3D(var rci: TRenderContextInfo; pos1, pos2: TDAffineVector; R, G, B, LineWidth: Single);
	procedure DrawQuad3D(var rci: TRenderContextInfo; p1, p2, p3, p4: TDAffineVector; R, G, B, LineWidth: Single; LinePattern: Cardinal); overload;
  procedure DrawQuad3D(var rci: TRenderContextInfo; hs, pos: TDAffineVector; R, G, B, LineWidth: Single; LinePattern: Cardinal); overload;
	procedure DrawAABB(var rci: TRenderContextInfo; aabb: TAABB; R, G, B, LineWidth: Single);
  procedure DrawContoursEx(var rci: TRenderContextInfo; c: TGLContours; R, G, B: Single;
    LinePattern: Cardinal = $FFFF; Smoozed: Boolean = True);

//-------------------------------------------------------------
//-------------------------------------------------------------
//-------------------------------------------------------------
implementation
//-------------------------------------------------------------
//-------------------------------------------------------------
//-------------------------------------------------------------

uses
{$I SetupCheck.inc}
{$IFDEF NETGUARD_PROTECTION}
  NetGuardHandler,
{$ENDIF}
  SysUtils, XOpenGL, PropEdit, GLInfo, GLContext, BlockTypes, StrUtils, uCommands,
  uLineGeometry, uNaiveJSON, TempStream, BaseTempStream, md5util, VectorTypes,
  IOUtils, IOTypes;

procedure DrawArrowXY(var rci: TRenderContextInfo; R, G, B: Single);
var
	s, size: single;
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	//glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	glDepthFunc(GL_ALWAYS);
	glStencilFunc(GL_ALWAYS, 0, $FF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
	glDisable(GL_BLEND);
	glBegin(GL_TRIANGLES);
  size:=0.4;
	if rci.PixelSize > 1/200 then
		s:=1.0
	else
		s:=rci.PixelSize * 200;
  //0
  glColor4f(R, G, B, 1);
	glVertex2f(0, 0.2 * s + size);
	glVertex2f(-0.02 * s, 0);
	glVertex2f(+0.02 * s, 0);

	glVertex2f(0.2 * s + size, 0);
	glVertex2f(0, +0.02 * s);
	glVertex2f(0, -0.02 * s);
  
  //Y
	glColor4f(0, 0, 1, 1);
	glVertex2f(0, 0.2 * s + size);
	glVertex2f(-0.04 * s, -0.05 * s + size);
	glVertex2f(0, -0.01 * s + size);

	glVertex2f(0, 0.2 * s + size);
	glVertex2f(0, -0.01 * s + size);
	glVertex2f(0.04 * s, -0.05 * s + size);

  //X
  glColor4f(1, 0, 0, 1);
	glVertex2f(0.2 * s + size, 0);
	glVertex2f(-0.01 * s + size, 0);
	glVertex2f(-0.05 * s + size, -0.04 * s);

	glVertex2f(0.2 * s + size, 0);
	glVertex2f(-0.05 * s + size, 0.04 * s);
	glVertex2f(-0.01 * s + size, 0);
	glEnd;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawPoint(var rci: TRenderContextInfo; pos: TDAffineVector; R, G, B: Single);
var
	s: single;
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	//glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	glDepthFunc(GL_ALWAYS);
	glStencilFunc(GL_ALWAYS, 0, $FF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  glPushMatrix;
  glTranslatef(Pos[0], Pos[1], Pos[2]);
	glDisable(GL_BLEND);
	glBegin(GL_TRIANGLES);
	if rci.PixelSize > 1/200 then
		s:=1.0
	else
		s:=rci.PixelSize * 200;

  //0
	glColor4f(R, G, B, 1);
	glVertex2f(0, 0.02 * s);
	glVertex2f(-0.02 * s, 0);
	glVertex2f(0, -0.02 * s);

	glVertex2f(0, 0.02 * s);
	glVertex2f(0, -0.02 * s);
	glVertex2f(0.02 * s, 0);

	glEnd;
  glPopMatrix;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawQuadPolygon3D(var rci: TRenderContextInfo; p1, p2, p3, p4: TDAffineVector; R, G, B: Single; BackFace: Boolean;
  IgnoreStencil: Boolean; obj: TObject);
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	//glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	//glDepthFunc(GL_ALWAYS);
  if IgnoreStencil then
  begin
    glStencilFunc(GL_ALWAYS, 0, $FF);
    glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  end;
  if BackFace then
  	glFrontFace(GL_CW)
  else
  	glFrontFace(GL_CCW);

	glDisable(GL_BLEND);
	glBegin(GL_QUADS);

  if Assigned(obj) then
    SetPointerColor(obj, rci)
  else
	  glColor4f(R, G, B, 1);

	glVertex3f(p1[0], p1[1], p1[2]);
	glVertex3f(p2[0], p2[1], p2[2]);
	glVertex3f(p3[0], p3[1], p3[2]);
	glVertex3f(p4[0], p4[1], p4[2]);

	glEnd;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawQuadPolygon3D(var rci: TRenderContextInfo; ab: TAABB; R, G, B: Single; BackFace: Boolean;
  IgnoreStencil: Boolean; obj: TObject);
var
  p1, p2, p3, p4: TDAffineVector;
begin
  p1 := DAffineVectorMake(ab.min[0], ab.min[1], 0);
  p2 := DAffineVectorMake(ab.min[0], ab.max[1], 0);
  p3 := DAffineVectorMake(ab.max[0], ab.max[1], 0);
  p4 := DAffineVectorMake(ab.max[0], ab.min[1], 0);
  DrawQuadPolygon3D(rci, p1, p2, p3, p4, R, G, B, BackFace, IgnoreStencil, obj);
end;

procedure DrawTriangle3D(var rci: TRenderContextInfo; p1, p2, p3: TDAffineVector; R, G, B: Single; BackFace: Boolean);
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	//glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	//glDepthFunc(GL_ALWAYS);
	glStencilFunc(GL_ALWAYS, 0, $FF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);

  if BackFace then
  	glFrontFace(GL_CW)
  else
  	glFrontFace(GL_CCW);

	glDisable(GL_BLEND);
	glBegin(GL_TRIANGLES);

	glColor4f(R, G, B, 1);
	glVertex3f(p1[0], p1[1], p1[2]);
	glVertex3f(p2[0], p2[1], p2[2]);
	glVertex3f(p3[0], p3[1], p3[2]);

	glEnd;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawLine(var rci: TRenderContextInfo; pos1, pos2: TDAffineVector; R, G, B, LineWidth: Single;
  IgnoreStencil: Boolean; obj: TObject);
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	//glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	glDepthFunc(GL_ALWAYS);
  if IgnoreStencil then
  begin
    glStencilFunc(GL_ALWAYS, 0, $FF);
    glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  end;
  //glPushMatrix;
  //glTranslatef(Pos1[0], Pos1[1], Pos1[2]);
  if rci.drawState = dsRendering then
  begin
    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  end
  else
  	glDisable(GL_BLEND);

  glLineWidth(LineWidth);

  if Assigned(obj) then
    SetPointerColor(obj, rci)
  else
	  glColor4f(R, G, B, 1);

	glBegin(GL_LINES);
  	glVertex2f(pos1[0], pos1[1]);
  	glVertex2f(pos2[0], pos2[1]);
	glEnd;
  //glPopMatrix;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawLine3D(var rci: TRenderContextInfo; pos1, pos2: TDAffineVector; R, G, B, LineWidth: Single);
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	//glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	glDepthFunc(GL_ALWAYS);
	glStencilFunc(GL_ALWAYS, 0, $FF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  //glPushMatrix;
  //glTranslatef(Pos1[0], Pos1[1], Pos1[2]);
	glDisable(GL_BLEND);

  glLineWidth(LineWidth);
  glEnable(GL_LINE_SMOOTH);

	glBegin(GL_LINES);

	glColor4f(R, G, B, 1);
	glVertex3f(pos1[0], pos1[1], pos1[2]);
	glVertex3f(pos2[0], pos2[1], pos2[2]);

	glEnd;
  //glPopMatrix;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawQuad3D(var rci: TRenderContextInfo; p1, p2, p3, p4: TDAffineVector; R, G, B, LineWidth: Single;
  LinePattern: Cardinal);
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	//glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	glDepthFunc(GL_ALWAYS);
	glStencilFunc(GL_ALWAYS, 0, $FF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  //glPushMatrix;
	glDisable(GL_BLEND);

  glDisable(GL_TEXTURE_2D);
  glActiveTextureARB(GL_TEXTURE0_ARB + 1);
  glDisable(GL_TEXTURE_2D);
  glActiveTextureARB(GL_TEXTURE0_ARB);

  glLineWidth(LineWidth);
  glEnable(GL_LINE_SMOOTH);

	if LinePattern and $FFFF <> $FFFF then
	begin
		glEnable(GL_LINE_STIPPLE);
		glLineStipple((LinePattern and $FFFF0000) shr 16, LinePattern and $FFFF);
	end;

	glBegin(GL_LINE_STRIP);

	glColor4f(R, G, B, 1);
	glVertex3f(p1[0], p1[1], p1[2]);
	glVertex3f(p2[0], p2[1], p2[2]);
  glVertex3f(p3[0], p3[1], p3[2]);
  glVertex3f(p4[0], p4[1], p4[2]);
  glVertex3f(p1[0], p1[1], p1[2]);

	glEnd;
  //glPopMatrix;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawQuad3D(var rci: TRenderContextInfo; hs, pos: TDAffineVector; R, G, B, LineWidth: Single;
  LinePattern: Cardinal);
var
  p1, p2, p3, p4: TDAffineVector;
begin
  p1 := VectorAdd(pos, DAffineVectorMake(-hs[0], +hs[1], 0));
  p2 := VectorAdd(pos, DAffineVectorMake(+hs[0], +hs[1], 0));
  p3 := VectorAdd(pos, DAffineVectorMake(+hs[0], -hs[1], 0));
  p4 := VectorAdd(pos, DAffineVectorMake(-hs[0], -hs[1], 0));
  DrawQuad3D(rci, p1, p2, p3, p4, R, G, B, LineWidth, LinePattern);
end;

procedure DrawAABB(var rci: TRenderContextInfo; aabb: TAABB; R, G, B, LineWidth: Single);
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glColor4f(R, G, B, 0);
	glDisable(GL_LIGHTING);
	glDepthFunc(GL_ALWAYS);
	glStencilFunc(GL_ALWAYS, 0, $FF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
	glDisable(GL_BLEND);

	glLineWidth(LineWidth);
	glEnable(GL_LINE_SMOOTH);

	glBegin(GL_LINE_STRIP);

	glVertex2f(aabb.min[0], aabb.min[1]);
	glVertex2f(aabb.min[0], aabb.max[1]);
	glVertex2f(aabb.max[0], aabb.max[1]);
	glVertex2f(aabb.max[0], aabb.min[1]);
	glVertex2f(aabb.min[0], aabb.min[1]);

	glEnd;

	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

procedure DrawContoursEx(var rci: TRenderContextInfo; c: TGLContours; R, G, B: Single;
  LinePattern: Cardinal; Smoozed: Boolean);
var
	i, j, k: integer;
const
  alphas: array [0..1] of single = (1.0, 0.6);
  widthes: array [0..1] of single = (1.5, 5.0);
begin
  if assigned(rci.ShaderHandle) then
    rci.ShaderHandle.PushState(false);
  glPushAttrib(GL_ALL_ATTRIB_BITS);
  glDisable(GL_LIGHTING);
  glDepthFunc(GL_ALWAYS);
  glStencilFunc(GL_ALWAYS, 0, $FF);
  glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
  //glDisable(GL_BLEND);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  glDisable(GL_TEXTURE_2D);
  glActiveTextureARB(GL_TEXTURE0_ARB + 1);
  glDisable(GL_TEXTURE_2D);
  glActiveTextureARB(GL_TEXTURE0_ARB);

  if LinePattern and $FFFF <> $FFFF then
  begin
    glEnable(GL_LINE_STIPPLE);
    glLineStipple((LinePattern and $FFFF0000) shr 16, LinePattern and $FFFF);
  end;

  if Smoozed then
    glEnable(GL_LINE_SMOOTH);

  for k:=1 downto 0 do
  begin
    glLineWidth(widthes[k]) ;//(2*k + 1) * 0.5);

    if k=0 then
      glColor4f(1.0, 1.0, 1.0, alphas[k])
    else
      glColor4f(R, G, B, alphas[k]);

    for j:=0 to c.Count - 1 do
    with c[j] do
    begin
      glBegin(GL_LINE_STRIP);
      for i:=0 to Nodes.Count - 1 do
        glVertex3dv(PGLDouble(Nodes[i].AsDoubleAddress));

      glVertex3dv(PGLDouble(Nodes[0].AsDoubleAddress));
      glEnd;
    end;
  end;

  glPopAttrib;
  if assigned(rci.ShaderHandle) then
    rci.ShaderHandle.PopState;
end;

procedure DrawArrow(var rci: TRenderContextInfo);
var
	s: single;
begin
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PushState(false);
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glColor4f(1, 0, 0, 1);
	glDisable(GL_LIGHTING);
	glDepthFunc(GL_ALWAYS);
	glStencilFunc(GL_ALWAYS, 0, $FF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
	glDisable(GL_BLEND);
	glBegin(GL_TRIANGLES);
	if rci.PixelSize > 1/200 then
		s:=1.0
	else
		s:=rci.PixelSize * 200;
	glVertex2f(0, 0.2 * s);
	glVertex2f(-0.04 * s, -0.05 * s);
	glVertex2f(0, -0.01 * s);

	glVertex2f(0, 0.2 * s);
	glVertex2f(0, -0.01 * s);
	glVertex2f(0.04 * s, -0.05 * s);
	glEnd;
	glPopAttrib;
	if assigned(rci.ShaderHandle) then
		rci.ShaderHandle.PopState;
end;

// ------------------
// ------------------ TPolygonList ------------------
// ------------------

// Add
//

procedure TPolygonList.Add;
begin
  FAktList:=TAffineVectorList.Create;
  inherited Add(FAktList);
end;

// GetList
//

function TPolygonList.GetList(i: Integer): TAffineVectorList;
begin
  Result:=TAffineVectorList(Items[i]);
end;


// ------------------
// ------------------ TTransformationList ------------------
// ------------------

constructor TTransformationList.Create(const AGrowIncrement: Integer = 1);
begin
  inherited Create;
  FGrowIncrement := Max(1, AGrowIncrement);
end;

destructor TTransformationList.Destroy;
begin
  inherited Destroy;
end;

function TTransformationList.Add(const m: TDMatrix): Integer;
begin
  while Length(FList) <= FCount do
    SetLength(FList, Length(FList) + FGrowIncrement);
  Result := FCount;
  FList[FCount] := m;
  Inc(FCount);
end;

function TTransformationList.GetItem(const i: Integer): TDMatrix;
begin
  if (i < 0) or (i >= FCount) then
    raise ERangeError.Create('TTransformationList.GetItem index out of range');
  Result := FList[i];
end;

procedure TTransformationList.SetItem(const i: Integer; const m: TDMatrix);
begin
  if (i < 0) or (i >= FCount) then
    raise ERangeError.Create('TTransformationList.SetItem index out of range');
  FList[i] := m;
end;

function TTransformationList.GetCount: Integer;
begin
  Result := FCount;
end;


// ------------------
// ------------------ TGLContour ------------------
// ------------------

constructor TGLContour.Create(Collection: TCollection);
begin
  inherited;
  CreateNodes;
  FDivision:=10;
  FSplineMode:=lsmLines;
end;

procedure TGLContour.CreateNodes;
begin
  FNodes:=TGLContourNodes.Create(Self);
end;

destructor TGLContour.Destroy;
begin
  FNodes.Free;
  FMetastorage.Free;
  inherited;
end;

procedure TGLContour.Assign(Source: TPersistent);
begin
  if Source is TGLContour then
  begin
    FNodes.Assign(TGLContour(Source).FNodes);
    FDivision:=TGLContour(Source).FDivision;
    FSplineMode:=TGLContour(Source).FSplineMode;
    FDescription:=TGLContour(Source).FDescription;
		FHole:=TGLContour(Source).Hole;
		FNoDeriv:=TGLContour(Source).NoDerivatives;
		if TGLContour(Source).FMetastorage = nil then
			FreeAndNil(FMetastorage)
		else
			GetMetaStorage.Assign(TGLContour(Source).FMetastorage, false);
  end
  else
  if Source is TGLLines then
  begin
    FNodes.Assign(TGLLines(Source).Nodes);
    FDivision:=TGLLines(Source).Division;
    FSplineMode:=TGLLines(Source).SplineMode;
    FHole:= not FNodes.IsCCW;
		if TGLLines(Source).HasMetaData = false then
			FreeAndNil(FMetastorage)
		else
			GetMetaStorage.Assign(TGLLines(Source).GetMetastorage, true);
  end
  else
    inherited;
end;

function TGLContour.GetDisplayName: string;
begin
  result:=Description;
  if result = '' then
    result:=Format('GLContour: %d nodes', [Nodes.Count]);
end;

procedure TGLContour.NodesChanged(Sender: TObject);
begin
  Changed(false);
end;

procedure TGLContour.SetDescription(const Value: string);
begin
  FDescription:=Value;
end;

procedure TGLContour.SetDivision(Value: Integer);
begin
  if Value < 1 then
    Value:=1;
  if Value <> FDivision then
  begin
    FDivision:=value;
    Changed(false);
  end;
end;

procedure TGLContour.SetNodes(const Value: TGLContourNodes);
begin
  FNodes.Assign(Value);
  Changed(false);
end;

procedure TGLContour.SetSplineMode(const Value: TLineSplineMode);
begin
  if FSplineMode <> value then
  begin
    FSplineMode:=value;
    Changed(false);
  end;
end;

{ TGLContours }

function TGLContours.CalcSquare: Double;
begin
  Result := 0.0;
  with GetExtContours(nil) do
  try
    Result := Square;
  finally
    Free;
  end;
end;

function TGLContours.GetLength: Double;
var
  i: integer;
begin
  Result := 0.0;
  for i:=0 to Count - 1 do
    Result := Result + GetItems(i).GetLength;
end;

function TGLContours.Add: TGLContour;
begin
  Result:=TGLContour(inherited Add);
end;

function TGLContours.AddInternalContour(startIndex: integer = 0; used: TIntegerList = nil): TGLContour;
var
  e: TIntegerList;
  n: TGLNode;
  con: TGLContour;

  procedure AddNode(v: TDVector; uid: integer);
  begin
    con.Nodes.AddNode(v, uid);
  end;

  function VectorEquals(a, b: TDVector): boolean;
  const
    epsilon = 1E-3;
  begin
    Result:=VectorDistance(a, b) <= epsilon;
  end;

  function OtherEnd(Node: TGLNode): TGLNode;
  var
    ni, nc, i: integer;
    c: TCollection;
  begin
    ni:=Node.Index;
    c:=Node.Collection;
    nc:=c.Count - 1;
    if ni = 0 then
    begin
      if Assigned(con) then
        for i:=0 to nc do
          with TGLNode(c.Items[i]) do
            AddNode(AsDoubleVector, UserID);
      Result:=TGLNode(c.Items[nc]);
    end
    else
      if ni = nc then
    begin
      if Assigned(con) then
        for i:=nc downto 0 do
          with TGLNode(c.Items[i]) do
            AddNode(AsDoubleVector, UserID);
      Result:=TGLNode(c.Items[0]);
    end
    else
      Result:=Node;
  end;

  function FindNext(Node: TGLNode; var exclude: TIntegerList; var res: TGLNode): Boolean;
  var
    i, j: integer;
  begin
    Result:=false;
    if not Assigned(Node) then
      exit;
    j:=TGLContour(Node.Collection.Owner).Index;
    if exclude.IndexOf(j) = -1 then
    begin
      res:=OtherEnd(Node);
      Result:=true;
      Exclude.Add(j);
      if Assigned(used) then
      begin
        j:=Used.IndexOf(j);
        if j > -1 then
          Used.Delete(j);
      end;
    end
    else
      for i:=0 to Count - 1 do
        if (exclude.IndexOf(i) = -1) then
          if VectorEquals(Items[i].Nodes[0].AsDoubleVector, Node.AsDoubleVector) then
          begin
            Res:=Items[i].Nodes[0];
            Result:=true;
            Break;
          end
          else
            if VectorEquals(Items[i].Nodes[Items[i].Nodes.Count - 1].AsDoubleVector, Node.AsDoubleVector) then
          begin
            Res:=Items[i].Nodes[Items[i].Nodes.Count - 1];
            Result:=true;
            Break;
          end;
  end;

begin
  Result:=nil;
  if startIndex >= Count then
    exit;
  e:=TIntegerList.Create;
  if Items[startIndex].Nodes.Count > 0 then
    n:=Items[startIndex].Nodes[0];
  con:=nil;
  while FindNext(n, e, n) do
  begin
  end;
  e.Clear;
  con:=Add;
  e.Add(con.Index);
  repeat
  until FindNext(n, e, n) = false;
  e.Free;
  con.Nodes.SetCCW;
  Result:=Con;
end;

function TGLContours.AddInternalContours: TGLContours;
var
	u: TIntegerList;
	n: TGLContour;
begin
  Result:=TGLContours.Create(nil);
  u:=TIntegerList.Create;
  u.AddSerie(0, 1, Count);
  while u.Count > 0 do
  begin
		n:=AddInternalContour(u[0], u);
		if n.Nodes.Count > 2 then
			Result.Add.Assign(n);
		n.Free;
  end;
  u.Free;

end;

procedure TGLContours.AddScaledVector(factor: Single;
  vector: TAffineVector);
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.Translate(VectorScale(vector, factor));
end;

procedure TGLContours.AddScaledVector(factor: Double;
  vector: TDAffineVector);
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.Translate(VectorScale(vector, factor));
end;

procedure TGLContours.AssignTo(Dest: TPersistent);
begin
  if Dest is TGLContours then
    TGLContours(Dest).Assign(Self)
  else
    inherited;
end;

procedure TGLContours.CopySingleToDouble;
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.CopySingleToDouble;
end;

constructor TGLContours.Create(AOwner: TComponent);
begin
  Create(AOwner, TGLContour);
end;

procedure TGLContours.ExcludeNotClosed;
var
  i: integer;
begin
  i:=0;
  while i < Count do
  begin
    with Items[i] do
      if not Nodes[0].EqualTo(Nodes[Nodes.Count - 1]) then
        Delete(i)
      else
        Inc(i);
  end;
end;

function TGLContours.FindItemID(ID: Integer): TGLContour;
begin
  result:=TGLContour(inherited FindItemId(Id));
end;

procedure TGLContours.FlipHorizontal;
var
  i: integer;
  b: Boolean;
begin
  for i:=0 to Count - 1 do
  begin
    b:=Items[i].Nodes.IsCCW;
    Items[i].Nodes.FlipHorizontal;
    if b then
      Items[i].Nodes.SetCCW
    else
      Items[i].Nodes.SetCW;
  end;
end;

procedure TGLContours.LoadFromStream(const aStream: TStream);
var
  l: TStringList;
  i, n, j, k, nn: integer;
  x, y, z: double;
  ok: Boolean;
begin
  if Assigned(aStream) then
  begin
    l := TStringList.Create;
    try
      l.LoadFromStream(aStream);
      Clear;

      k := 0;
      n := strtoint(l.Strings[k]);
      inc(k);
      for i:=1 to n do
        with add do
        begin
          nn := strtoint(l.Strings[k]);
          inc(k);
          for j:=1 to nn do
          begin
            ok :=        TryStrToFloat(AnsiReplaceStr(l.Strings[k+0], '.', DecimalSeparator), x);
            ok := ok and TryStrToFloat(AnsiReplaceStr(l.Strings[k+1], '.', DecimalSeparator), y);
            ok := ok and TryStrToFloat(AnsiReplaceStr(l.Strings[k+2], '.', DecimalSeparator), z);
            if ok then
              Nodes.AddNode(DAffineVectorMake(x, y, z));
            inc(k, 3);
          end;
          Hole := Boolean(strtoint(l.Strings[k]));
          Inc(k);
        end;
    finally
      l.Free;
    end;
  end;
end;

procedure TGLContours.FromTextFile(fn: string);
var
  f: TextFile;
  i, n, j, nn, h: integer;
  x, y, z: double;
begin
  Clear;
  AssignFile(f, fn);
	try
    Reset(f);
    ReadLn(f, n);
    for i:=1 to n do
      with add do
      begin
        ReadLn(f, nn);
        for j:=1 to nn do
        begin
          ReadLn(f, x);
          ReadLn(f, y);
          ReadLn(f, z);
          Nodes.AddNode(DAffineVectorMake(x, y, z));
        end;
        ReadLn(f, h);
        Hole:=Boolean(h);
      end;
  finally
    CloseFile(f);
  end;
end;

procedure TGLContours.GetExtents(var min, max: TDAffineVector);
var
	i: integer;
	aabb, tmp: TAABB;
const
	cBigValue: TDAffineVector = (1E50, 1E50, 1E50);
	cSmallValue: TDAffineVector = (-1E50, -1E50, -1E50);
begin
	tmp.min:=cBigValue;
	tmp.max:=cSmallValue;
	for i:=0 to Count - 1 do
	begin
		Items[i].GetExtents(aabb.min, aabb.max);
		AddAABB(tmp, aabb);
	end;
	min:=tmp.min;
	max:=tmp.max;
end;

function TGLContours.GetItems(index: Integer): TGLContour;
begin
  result:=TGLContour(inherited Items[index]);
end;

function TGLContours.GetSelf: TGLContours;
begin
  Result:=self;
end;

function TGLContours.GetPath(i: Integer): TGLContourNodes;
begin
	Assert(i >= 0);
	while i >= Count do
		Add;
	Result:=Items[i].Nodes;
end;

procedure TGLContours.SetPath(i: Integer; const value: TGLContourNodes);
begin
  Assert(i >= 0);
	while i >= Count do
		Add;
	Items[i].Nodes.Assign(value);
end;

procedure TGLContours.KickEqualPoints(checkEnds: boolean);
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.KickEqualPoints(CheckEnds);
end;

procedure TGLContours.KickPointsOnOneLine;
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.KickPointsOnOneLine;
end;

procedure TGLContours.Public_ReadFromFiler(reader: TCustomReader; FileVersion: integer);
begin
  ReadFromFiler(Reader, FileVersion);
end;

procedure TGLContours.Public_WriteToFiler(writer: TCustomWriter);
begin
  WriteToFiler(Writer);
end;

procedure TGLContours.ReadFromFiler(reader: TCustomReader; FileVersion: integer);
var
  i, n: integer;
begin
	try
	Clear;
	Reader.Read(N, SizeOf(Integer));
	for i:=0 to n - 1 do
		Add.ReadFromFiler(Reader, FileVersion);
	except
		exit;
	end;
	DeleteWrongContours;
end;

procedure TGLContours.Reverse;
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.Reverse;
end;

procedure TGLContours.SetItems(index: Integer; const Value: TGLContour);
begin
  inherited Items[index]:=value;
end;

{ TMultiPolygonBase }

// Create
//

constructor TMultiPolygonBase.Create(AOwner: TComponent);
begin
  inherited;
  FContours:=TGLContours.Create(Self);
  FContours.OnNotifyChange:=ContourChanged;
  FContoursNormal:=AffineVectorMake(0, 0, 1);
  FTexOffset:=NullDVector;
  FTexScale:=XYZDVector;
	FDrawPolyAsMesh:=true;
	ObjectStyle:=ObjectStyle + [osDirectDraw];
end;

// Destroy
//

destructor TMultiPolygonBase.Destroy;
begin
  FOutline.CleanFree;
  FContours.Free;
	FPolygonCache.Free;
  inherited;
end;

// Assign
//

procedure TMultiPolygonBase.Assign(Source: TPersistent);
begin
  if Source is TMultiPolygonBase then
  begin
		FContours.Assign(TMultiPolygonBase(Source).FContours);
		FTexOffset:=TMultiPolygonBase(Source).FTexOffset;
		FTexScale:=TMultiPolygonBase(Source).FTexScale;
		FDrawPolyAsMesh:=TMultiPolygonBase(Source).FDrawPolyAsMesh;
		RebuildPolyCache;
	end;
  //	 else
  inherited;
end;

procedure TMultiPolygonBase.BuildCache(var ci: TCacheInfo);
var
	c: TGLExContours;
	p: TPolygonDrawers;
begin
	if DoNotRenderSelf = false then
	begin
		c:=GetClipedOutlineContours(ci);
		if c <> nil then
		try
			p:=c.Tesselate;
			TMaterialMeshDrawers(ci.drawers).GetOrAddByMaterial(TObjectWithMaterialWrapper.Create(Self)).AddPolygonDrawers(
				p, ci.transform.MatrixAsAddress,
				DAffineVectorMake(-FTexOffset[0], -FTexOffset[1], 0),
				FTexScale, CacheObjectID, ci.Layer);
			p.Free;
			ci.CachedObjects.Add(self);
		finally
			c.Free;
		end;
	end;
end;

procedure TMultiPolygonBase.BuildCOMCache(var p: TPrepareKdVertexDataParams);
var
	c: TGLExContours;
	mesh: TPolygonDrawers;
	m: TDMatrix;
begin
	if p.isCachableObject(self) and (p.DisableSurfaces = false) then
	begin
		c:=GetClipedOutlineContours(p.ci);
		if (c <> nil) then
		try
			if (c.Count > 0) then
			begin
				mesh:=c.Tesselate;
				m:=p.ci.transform.Matrix;

				if p.DoBuildCacheMode then
				begin
					TMaterialMeshDrawers(p.ci.drawers).GetOrAddByMaterial(TObjectWithMaterialWrapper.Create(Self)).AddPolygonDrawers(
						mesh, @m,
						DAffineVectorMake(-FTexOffset[0], -FTexOffset[1], 0),
						FTexScale, p.AddHidableObjectCRC(mesh.getCRC, @m), p.ci.Layer);
					p.ci.CachedObjects.Add(self);
				end
				else
					p.AddHiddenObject(mesh.getCRC, @m);

				mesh.Free;
			end;
		finally
			c.Free;
		end;
	end;
end;

// ContourChanged
//

procedure TMultiPolygonBase.ContourChanged(Sender: TObject);
begin
  if Assigned(FOutline) then
  begin
    // force a RetrieveOutline with next Render
    FOutline.CleanFree;
    FOutline:=nil;
	end;
  StructureChanged;
	if assigned (FPolygonCache) then
		RebuildPolyCache;
  if WeakRefs <> nil then
    WeakRefs.Notify(cParentGeometryChanged);
  ChildExecCommand(cParentGeometryChanged, nil);
end;

// AddNode (vector)
//

procedure TMultiPolygonBase.AddNode(const i: Integer; const value: TVector);
begin
	FContours.Path[i].AddNode(value);
end;

// AddNode (float)
//

procedure TMultiPolygonBase.AddNode(const i: Integer; const x, y, z: TGLfloat);
begin
  FContours.Path[i].AddNode(x, y, z);
end;

// AddNode (coords)
//

procedure TMultiPolygonBase.AddNode(const i: Integer; const coords: TGLCoordinates);
begin
  FContours.Path[i].AddNode(coords);
end;

// AddNode (affine vector)
//

procedure TMultiPolygonBase.AddNode(const I: Integer; const value: TAffineVector);
begin
  FContours.Path[i].AddNode(value);
end;

// Assign
//

procedure TMultiPolygonBase.SetContours(const Value: TGLContours);
begin
  FContours.Assign(Value);
end;

// GetOutline
//

function TMultiPolygonBase.GetOutline: TPolygonList;
begin
  if not Assigned(FOutline) then
  begin
    FOutline:=TPolygonList.Create;
    RetrieveOutline(FOutline);
  end;
  Result:=FOutline;
end;

// GetContour
//

//
// Tessellation routines (OpenGL callbacks)
//

var
  vVertexPool: TVectorPool;
	vVertexList: TAffineVectorList;
	vTexCoordList: TAffineVectorList;

procedure tessError(errno: TGLEnum); stdcall;
begin
  Assert(False, IntToStr(errno) + ' : ' + gluErrorString(errno));
end;

procedure tessIssueVertex(vertexData: Pointer); stdcall;
begin
  xglTexCoord2fv(vertexData);
  glVertex3fv(vertexData);
end;

procedure tessAddVertex(vertexData: Pointer; polygonData: Pointer); stdcall;
begin
	vVertexList.Add(PAffineVector(vertexData)^);
	vTexCoordList.Add(PAffineVector(vertexData)^);
end;

procedure tessBegin(aType: TGLEnum; drawers: TPolygonDrawers);stdcall;
begin
	with TPolygonDrawer(drawers.Add(aType)) do
	begin
		vVertexList:=Vertices;
		vTexCoordList:=TexCoords;
	end;
end;

procedure tessEnd;stdcall;
begin
end;

procedure tessCombine(coords: {PVector{}PDoubleVector; vertex_data: PMatrix;
  weight: PVector; var outData: Pointer); stdcall;
begin
  vVertexPool.GetNewVector(outData);
  SetVector(PAffineVector(outData)^, coords[0], coords[1], coords[2]);
end;

procedure tessBeginList(typ: TGLEnum; polygonData: Pointer); stdcall;
begin
  TPolygonList(polygonData).Add;
end;

procedure tessIssueVertexList(vertexData: Pointer; polygonData: Pointer); stdcall;
begin
  TPolygonList(polygonData).AktList.Add(PAffineVector(vertexData)^);
end;

procedure TMultiPolygonBase.RetrieveOutline(List: TPolygonList);
var
  i, n: Integer;
  tess: PGLUTesselator;

  procedure TesselatePath(contour: TGLContour; inverted: Boolean);

    procedure IssueVertex(v: TAffineVector);
    var
      dblVector: TAffineDblVector;
      p: PAffineVector;
    begin
      vVertexPool.GetNewVector(Pointer(p));
      p^:=v;
      SetVector(dblVector, v);
      gluTessVertex(tess, dblVector, p);
    end;

  var
    i, n: Integer;
    spline: TCubicSpline;
    f: Single;
    splineDivisions: Integer;
    nodes: TGLContourNodes;
  begin
    gluTessBeginContour(tess);
    nodes:=contour.Nodes;
    if contour.SplineMode = lsmLines then
      splineDivisions:=0
    else
      splineDivisions:=contour.Division;
    if splineDivisions > 1 then
    begin
      spline:=nodes.CreateNewCubicSpline;
      try
        f:=1 / splineDivisions;
        n:=splineDivisions * (nodes.Count - 1);
        if inverted then
        begin
          for i:=n downto 0 do
            IssueVertex(spline.SplineAffineVector(i * f))
        end
        else
        begin
          for i:=0 to n do
            IssueVertex(spline.SplineAffineVector(i * f));
        end;
      finally
        spline.Free;
      end;
    end
    else
    begin
      n:=nodes.Count - 1;
      if inverted then
      begin
        for i:=n downto 0 do
          IssueVertex(nodes[i].AsAffineVector)
      end
      else
      begin
        for i:=0 to n do
          IssueVertex(nodes[i].AsAffineVector);
      end;
    end;
    gluTessEndContour(tess);
  end;

begin
  List.Clear;
  if (Contours.Count > 0) and (FContours.Path[0].Count > 2) then
  begin
    // Vertex count
    n:=0;
    for i:=0 to Contours.Count - 1 do
      n:=n + FContours.Path[i].Count;
    // Create and initialize the GLU tesselator
    vVertexPool:=TVectorPool.Create(n, SizeOf(TAffineVector));
    tess:=gluNewTess;
    try
      // register callbacks
      gluTessCallback(tess, GLU_TESS_BEGIN_DATA, @tessBeginList);
      gluTessCallback(tess, GLU_TESS_END_DATA, nil);
      gluTessCallback(tess, GLU_TESS_VERTEX_DATA, @tessIssueVertexList);
      gluTessCallback(tess, GLU_TESS_ERROR, @tessError);
      gluTessCallback(tess, GLU_TESS_COMBINE, @tessCombine);

      // issue normal
      gluTessNormal(tess, FContoursNormal[0], FContoursNormal[1], FContoursNormal[2]);

      // set properties
      gluTessProperty(Tess, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_POSITIVE);
      gluTessProperty(Tess, GLU_TESS_BOUNDARY_ONLY, GL_TRUE);

      gluTessBeginPolygon(tess, List);
      { я это забил, чтобы нулевой контур не отличалс€ от остальных
              // outside contour
               TesselatePath(Contours[0], False);
               // inside contours
               for n:=1 to Contours.Count-1 do
                  TesselatePath(Contours[n], True);}

      //      gluTessBeginContour(tess);
      for n:=0 to Contours.Count - 1 do
        TesselatePath(Contours[n], False);
      //      gluTessEndContour(tess);

      gluTessEndPolygon(tess);
    finally
      gluDeleteTess(tess);
      vVertexPool.Free;
      vVertexPool:=nil;
    end;
  end;
end;

// RenderTesselatedPolygon
//

{procedure TMultiPolygonBase.RenderTesselatedPolygon(textured: Boolean;
  normal: PAffineVector;
  invertNormals: Boolean);
var
  tess: PGLUTesselator;

  procedure IssueVertex(v: TAffineVector);
  var
    dblVector: TAffineDblVector;
    p: PAffineVector;
  begin
    vVertexPool.GetNewVector(Pointer(p));
    p^:=v;
    SetVector(dblVector, v);
    gluTessVertex(tess, dblVector, p);
  end;

var
  i, n: Integer;
  m: TMatrix;
begin
 // call to Outline will call RetrieveOutline if necessary
  if (Outline.Count = 0) or (Outline.List[0].Count < 2) then
    Exit;
 // Vertex count
  n:=0;
  for i:=0 to Outline.Count - 1 do
    n:=n + Outline.List[i].Count;
 // Create and initialize a vertex pool and the GLU tesselator
  vVertexPool:=TVectorPool.Create(n, Sizeof(TAffineVector));
  tess:=gluNewTess;
  glGetFloatV(GL_TEXTURE_MATRIX, @m);
  try
    glMatrixMode(GL_TEXTURE);
    glTranslatef(-FTexOffset[0], -FTexOffset[1], -FTexOffset[2]);
    glScaleF(FTexScale[0], FTexScale[1], FTexScale[2]);
    glMatrixMode(GL_MODELVIEW);
    gluTessCallback(tess, GLU_TESS_BEGIN, @glBegin);
    if textured then
      gluTessCallback(tess, GLU_TESS_VERTEX, @tessIssueVertex)
    else
      gluTessCallback(tess, GLU_TESS_VERTEX, @glVertex3fv);
    gluTessCallback(tess, GLU_TESS_END, @glEnd);
    gluTessCallback(tess, GLU_TESS_ERROR, @tessError);
    gluTessCallback(tess, GLU_TESS_COMBINE, @tessCombine);
    // Issue normal
    if Assigned(normal) then
    begin
      glNormal3fv(PGLFloat(normal));
      gluTessNormal(tess, normal[0], normal[1], normal[2]);
    end;
    gluTessProperty(Tess, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_POSITIVE);
    // Issue polygon
    gluTessBeginPolygon(tess, nil);
    //        gluTessBeginContour(tess);
    for n:=0 to Outline.Count - 1 do
    begin
      with Outline.List[n] do
      begin
        gluTessBeginContour(tess);
        if invertNormals then
          for i:=Count - 1 downto 0 do
            IssueVertex(Items[i])
        else
          for i:=0 to Count - 1 do
            IssueVertex(Items[i]);
        gluTessEndContour(tess);
      end;
    end;
    //        gluTessEndContour(tess);
    gluTessEndPolygon(tess);
  finally
    gluDeleteTess(tess);
    vVertexPool.Free;
    vVertexPool:=nil;
    glMatrixMode(GL_TEXTURE);
    glLoadMatrixF(@m);
    glMatrixMode(GL_MODELVIEW);
  end;
end;      }
// RenderTesselatedPolygon
//

procedure TMultiPolygonBase.RenderTesselatedPolygon(textured: Boolean;
  normal: PAffineVector;
  invertNormals: Boolean);
var
  tess: PGLUTesselator;

  procedure IssueVertex(v: TAffineVector);
  var
    dblVector: TAffineDblVector;
    p: PAffineVector;
  begin
		vVertexPool.GetNewVector(Pointer(p));
    p^:=v;
    SetVector(dblVector, v);
    gluTessVertex(tess, dblVector, p);
  end;

var
  i, n: Integer;
begin
{$IFNDEF NETGUARD_PROTECTION}
	if FDrawPolyAsMesh and (not assigned(FPolygonCache)) then
		FPolygonCache:=TPolygonDrawers.Create(Material);
	if assigned(FPolygonCache) and (not FPolyCacheValid) then
	begin
		FPolygonCache.Clean;
		FPolyCacheValid:=true;
	end;

 // call to Outline will call RetrieveOutline if necessary
  if (Outline.Count = 0) or (Outline.List[0].Count < 2) then
    Exit;
 // Vertex count
  n:=0;
  for i:=0 to Outline.Count - 1 do
    n:=n + Outline.List[i].Count;
 // Create and initialize a vertex pool and the GLU tesselator
	vVertexPool:=TVectorPool.Create(n, Sizeof(TAffineVector));
  tess:=gluNewTess;
	try
		if FDrawPolyAsMesh then
		begin
			gluTessCallback(tess, GLU_TESS_VERTEX_DATA, @tessAddVertex);
			gluTessCallback(tess, GLU_TESS_BEGIN_DATA, @tessBegin);
			gluTessCallback(tess, GLU_TESS_END, @tessEnd);
		end
		else
		begin
			gluTessCallback(tess, GLU_TESS_BEGIN_DATA, @glBegin);
			if textured then
				gluTessCallback(tess, GLU_TESS_VERTEX_DATA, @tessIssueVertex)
			else
				gluTessCallback(tess, GLU_TESS_VERTEX_DATA, @glVertex3fv);
			gluTessCallback(tess, GLU_TESS_END, @glEnd);
		end;
		gluTessCallback(tess, GLU_TESS_ERROR, @tessError);
		gluTessCallback(tess, GLU_TESS_COMBINE, @tessCombine);
    // Issue normal
    if Assigned(normal) then
    begin
			if not FDrawPolyAsMesh then
				glNormal3fv(PGLFloat(normal));
			gluTessNormal(tess, normal[0], normal[1], normal[2]);
    end;
    gluTessProperty(Tess, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_POSITIVE);
    // Issue polygon
    gluTessBeginPolygon(tess, FPolygonCache);
		//        gluTessBeginContour(tess);
    for n:=0 to Outline.Count - 1 do
    begin
      with Outline.List[n] do
      begin
        gluTessBeginContour(tess);
        if invertNormals then
          for i:=Count - 1 downto 0 do
            IssueVertex(Items[i])
        else
          for i:=0 to Count - 1 do
            IssueVertex(Items[i]);
        gluTessEndContour(tess);
      end;
    end;
    //        gluTessEndContour(tess);
    gluTessEndPolygon(tess);
  finally
    gluDeleteTess(tess);
		vVertexPool.Free;
		vVertexPool:=nil;
		vTexCoordList:=nil;
		vVertexList:=nil;
  end;
{$ELSE}
	if FDrawPolyAsMesh then
  begin
    FreeAndNil(FPolygonCache);
    FPolyCacheValid := NetGuard.TesselateQuery(FContours, FPolygonCache);
  end
  else
  begin
    if assigned(FPolygonCache) and (not FPolyCacheValid) then
    begin
      FPolygonCache.Clean;
      FPolyCacheValid:=true;
    end;

   // call to Outline will call RetrieveOutline if necessary
    if (Outline.Count = 0) or (Outline.List[0].Count < 2) then
      Exit;
   // Vertex count
    n:=0;
    for i:=0 to Outline.Count - 1 do
      n:=n + Outline.List[i].Count;
   // Create and initialize a vertex pool and the GLU tesselator
    vVertexPool:=TVectorPool.Create(n, Sizeof(TAffineVector));
    tess:=gluNewTess;
    try
      gluTessCallback(tess, GLU_TESS_BEGIN_DATA, @glBegin);
      if textured then
        gluTessCallback(tess, GLU_TESS_VERTEX_DATA, @tessIssueVertex)
      else
        gluTessCallback(tess, GLU_TESS_VERTEX_DATA, @glVertex3fv);
      gluTessCallback(tess, GLU_TESS_END, @glEnd);

      gluTessCallback(tess, GLU_TESS_ERROR, @tessError);
      gluTessCallback(tess, GLU_TESS_COMBINE, @tessCombine);
      // Issue normal
      if Assigned(normal) then
      begin
        glNormal3fv(PGLFloat(normal));
        gluTessNormal(tess, normal[0], normal[1], normal[2]);
      end;
      gluTessProperty(Tess, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_POSITIVE);
      // Issue polygon
      gluTessBeginPolygon(tess, FPolygonCache);
      //        gluTessBeginContour(tess);
      for n:=0 to Outline.Count - 1 do
      begin
        with Outline.List[n] do
        begin
          gluTessBeginContour(tess);
          if invertNormals then
            for i:=Count - 1 downto 0 do
              IssueVertex(Items[i])
          else
            for i:=0 to Count - 1 do
              IssueVertex(Items[i]);
          gluTessEndContour(tess);
        end;
      end;
      //        gluTessEndContour(tess);
      gluTessEndPolygon(tess);
    finally
      gluDeleteTess(tess);
      vVertexPool.Free;
      vVertexPool:=nil;
      vTexCoordList:=nil;
      vVertexList:=nil;
    end;
  end;
{$ENDIF}
end;


// ------------------
// ------------------ TGLMultiPolygon ------------------
// ------------------

// Create
//

constructor TGLMultiPolygon.Create(AOwner: TComponent);
begin
  inherited;
  FParts:= [ppTop];
end;

// Assign
//

procedure TGLMultiPolygon.Assign(Source: TPersistent);
begin
	if Source is TGLMultiPolygon then
	begin
		FParts:=TGLMultiPolygon(Source).FParts;
	end;
	inherited;
end;

// BuildList
//

procedure TGLMultiPolygon.BuildList(var rci: TRenderContextInfo);
var
	normal: TAffineVector;
	backup: boolean;
//	b: boolean;
begin
  if (rfSelectionFramePass in rci.RenderFlags) and FDrawingSelection{ and (Visible or (rci.proxySubObject and (not rci.RootIsHidden)))} then
  begin
    DrawContoursEx(rci, FContours, 0.0, 0.0, 1.0);
    Exit;
  end;
	//		SaveDepthToDisk ('c:\debug\stencil', rci);}
	if (Outline.Count < 1) then
		Exit;
	normal:=ContoursNormal;
	backup:=rci.IgnoreMaterials;
	rci.ignoreMaterials:=true;
//	b:=not IsMyReflection(rci);
	// Render
	// tessellate top polygon
	if (ppTop in FParts) {or rci.mirrorrendering {and ((not rci.mirrorrendering) or b)} then
	begin
		if rci.ShaderHandle is TGLBasicShaderOld then
			TGLBasicShaderOld(rci.ShaderHandle).SetTangentBinormal(1, 0, 0, 0, 1, 0);
//    RenderTesselatedPolygon(True, @normal, False);
		RenderPolygon(rci, True, @normal, false);
	end;
	// tessellate bottom polygon
	if (ppBottom in FParts) {or rci.mirrorrendering{and ((not rci.mirrorrendering) or (not b))} then
	begin
		if rci.ShaderHandle is TGLBasicShaderOld then
			TGLBasicShaderOld(rci.ShaderHandle).SetTangentBinormal(-1, 0, 0, 0, -1, 0);
		NegateVector(normal);
//    RenderTesselatedPolygon(True, @normal, True)
		RenderPolygon(rci, true, @normal, true);
	end;
	if (ppContours in FParts) then
	begin
		if rci.ShaderHandle is TGLBasicShaderOld then
			TGLBasicShaderOld(rci.ShaderHandle).SetTangentBinormal(1, 0, 0, 0, 1, 0);
		FContours.BuildList(rci);
	end;
	rci.ignoreMaterials:=backup;
end;

// SetParts
//

procedure TGLMultiPolygon.SetParts(const value: TPolygonParts);
begin
  if FParts <> value then
  begin
    FParts:=value;
    StructureChanged;
  end;
end;

// SetContoursNormal
//

procedure TMultiPolygonBase.SetContoursNormal(const Value: TAffineVector);
begin
  FContoursNormal:=Value;
end;

// ------------------
// ------------------ TGLContourNodes ------------------
// ------------------

// NotifyChange
//

procedure TGLContourNodes.BuildList(var rci: TRenderContextInfo;
  middle: boolean);
begin
  inherited BuildList(rci, FEditMode = 1);
end;

constructor TGLContourNodes.Create(AOwner: TPersistent;
  ItemClass: TCollectionItemClass);
begin
	if not assigned(ItemClass) then
		inherited Create(AOwner, TGLContourNode)
	else
		inherited;
end;

function TGLContourNodes.GetSceneObject: TObject;
begin
	Result:=TGLContours(TGLContour(Owner).Collection).GetSceneObject;
end;

procedure TGLContourNodes.NotifyChange;
begin
  if (GetOwner <> nil) then
    (GetOwner as TGLContour).Changed(False);
end;

procedure TGLContours.SaveToStream(const aStream: TStream);
var
  i, j: integer;
  l: TStringList;
  fs: TFormatSettings;
function FloatToText(Value: Double): string;
const
  FORMATSTR = '0.00000000000000E+0000';
begin
  if Value >= 0.0 then
    Result := ' ' + FormatFloat(FORMATSTR, Value, fs)
  else
    Result := '-' + FormatFloat(FORMATSTR, Abs(Value), fs);
end;
begin
  if Assigned(aStream) then
  begin
    FillChar(fs, sizeof(fs), #0);
    fs.DecimalSeparator := '.';
    l := TStringList.Create;
    try
      l.Add(inttostr(Count));
      for i:=0 to Count - 1 do
        with Items[i] do
        begin
          l.Add(inttostr(Nodes.Count));
          for j:=0 to Nodes.Count - 1 do
          begin
            l.Add(FloatToText(Nodes[j].DoubleX));
            l.Add(FloatToText(Nodes[j].DoubleY));
            l.Add(FloatToText(Nodes[j].DoubleZ));
          end;
          l.Add(inttostr(Ord(Hole)));
        end;
      l.SaveToStream(aStream);
    finally
      l.Free;
    end;
  end;
end;

//-------------------------------------------------------------
//-------------------------------------------------------------
//-------------------------------------------------------------

procedure TGLContours.ToTextFile(fn: string; checkExist: boolean = false);
var
  f: TextFile;
  i, n, j, nn: integer;
  x, y, z: double;
  ext: string;
begin
  if checkExist and FileExists(fn) then
  begin
    i:=0;
    ext:=ExtractFileExt(fn);
    System.Delete(fn, pos(ext, fn), length(ext));
    while FileExists(fn + inttostr(i) + ext) do
      inc(i);
    fn:=fn + inttostr(i) + ext;
  end;
  AssignFile(f, fn);
  Rewrite(f);
  n:=Count;
  WriteLn(f, n);
  for i:=0 to n - 1 do
    with Items[i] do
    begin
      nn:=Nodes.Count;
      WriteLn(f, nn);
      for j:=0 to nn - 1 do
      begin
        x:=Nodes[j].DoubleX;
        y:=Nodes[j].DoubleY;
        z:=Nodes[j].DoubleZ;
        WriteLn(f, x);
        WriteLn(f, y);
        WriteLn(f, z);
      end;
      WriteLn(f, Ord(Hole));
    end;
  CloseFile(f);
end;

procedure TGLContours.Transform(m: TMatrix; useDouble: boolean = true);
var
	i: integer;
begin
	for i:=0 to Count - 1 do
		Items[i].Nodes.Transform(m, UseDouble);
end;

procedure TGLContour.AssignTo(Dest: TPersistent);
var
  i: integer;
begin
  if Dest is TGLLines then
  begin
    TGLLines(Dest).Nodes.Clear;
    for i:=0 to Nodes.Count - 1 do
      TGLLines(Dest).Nodes.Add.Assign(Nodes[i]);
    TGLLines(Dest).Division:=FDivision;
    TGLLines(Dest).SplineMode:=FSplineMode;
    if FHole then
      TGLLines(Dest).Nodes.SetCW
    else
      TGLLines(Dest).Nodes.SetCCW;
    if FMetastorage <> nil then
      TGLLines(Dest).GetMetaStorage.Assign(FMetastorage, True);
  end
  else
  if Dest is TGLNodes then
  begin
    for i:=0 to Nodes.Count - 1 do
      TGLNodes(Dest).Add.Assign(Nodes[i]);
  end
  else
  if Dest is TGLContour then
    TGLContour(Dest).Assign(Self)
  else
    inherited;
end;

procedure TGLContour.ReadFromFiler(reader: TCustomReader; FileVersion: integer);
var
  info: TReadInfo;
begin
//	Try
	FNodes.ReadFromFiler(Reader, FileVersion);
{	except
	if (self.Collection.Owner) is TGLBaseSceneObject then
		ThrowTime('c:\debug1\info.txt', TGLBaseSceneObject(self.Collection.Owner).RusName);
	end;}
	Reader.Read(FDivision, SizeOf(Integer));
  Reader.Read(FSplineMode, SizeOf(TLineSplineMode));
  FDescription:=Reader.ReadString();
	FHole:=Reader.ReadBoolean();
	if FileVersion < 21 then
		FHole:=FNodes.IsCCW = false;
  if FileVersion >= 55 then
  begin
    if Reader.ReadBoolean then
    begin
      FillChar(info, sizeof(info), 0);
      info.Reader := reader;
      info.FileVersion := FileVersion;
      info.Assigner := TAssigner.Create(true);
      info.Identor := TIdentor.Create(true);
      info.Updater := TUpdater.Create(true, nil);
      GetMetastorage.ReadFromFiler(info);
      info.Assigner.AssignThem(info.Identor, nil, nil, info.Updater);
    end;
  end;
end;

procedure TGLContour.WriteToFiler(writer: TCustomWriter);
var
  info: TWriteInfo;
begin
  FNodes.WriteToFiler(writer);
  Writer.Write(FDivision, SizeOf(Integer));
  Writer.Write(FSplineMode, SizeOf(TLineSplineMode));
  Writer.WriteString(FDescription);
  Writer.WriteBoolean(FHole);
  Writer.WriteBoolean(FMetastorage <> nil);
  if FMetastorage <> nil then
  begin
    FillChar(info, sizeof(info), 0);
    info.Writer := writer;
    FMetastorage.WriteToFiler(info);
  end;
end;

function TGLContour.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
	Result:=0;
	with LoadInfo, Reader, CurrentBlock do
		case BlockType of
					btContourDivision	: ReadInteger(FDivision);
					btSplineMode			: Read(FSplineMode, SizeOf(TLineSplineMode));
					btDescription			: ReadString(FDescription);
					btIsHole					: ReadBoolean(FHole);
		else
			Result:=1;
		end;
end;

function TGLContour.GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
	const ChildClass: string; const ChildID: string): TObject;
begin
	case ChildBlockType of
		btContourNodes	: Result:=FNodes;
    btMetaStorage   :
    begin
      FreeAndNil(FMetaStorage);
      Result := GetMetastorage;
    end;
	else
		Result:=nil;
	end;
end;

procedure TGLContour.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
	with SaveInfo, Writer do
	try
		BeginChild(btContourNodes);
		try
			FNodes.SaveObject(SaveInfo);
		finally
			EndChild;
		end;
		WriteInteger(btContourDivision, FDivision);
		Write(btSplineMode, FSplineMode, SizeOf(TLineSplineMode));
		WriteString(btDescription, FDescription);
		WriteBoolean(btIsHole, FHole);
    if FMetastorage <> nil then
      WriteChild(SaveInfo, FMetastorage, btMetaStorage);
	except
		on e: exception do
			SaveInfo.Error('TGLContour: ' + e.Message);
	end;
end;

procedure TGLContours.WriteToFiler(writer: TCustomWriter);
var
  i, n: integer;
begin
  N:=Count;
  Writer.Write(N, SizeOf(Integer));
  for i:=0 to n - 1 do
    Items[i].WriteToFiler(Writer);
end;

function TGLContours.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
	Result:=0;
	with LoadInfo, Reader, CurrentBlock do
		case BlockType of
					btContoursListCount	: begin
																	Clear;
																	ReadInteger;
																end;
		else
			Result:=1;
		end;
end;

function TGLContours.GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
	const ChildClass: string; const ChildID: string): TObject;
begin
	case ChildBlockType of
		btContour: Result:=Add;
	else
		Result:=nil;
	end;
end;

procedure TGLContours.SaveObject(var SaveInfo: TSaveInfo); {ok}
var
	i: integer;
begin
	with SaveInfo, Writer do
	try
		WriteInteger(btContoursListCount, Count);
		for i:=0 to count - 1 do
		begin
			BeginChild(btContour);
			try
				Items[i].SaveObject(SaveInfo);
			finally
				EndChild;
			end;
		end;
	except
		on e: exception do
			SaveInfo.Error('TGLContours: ' + e.Message);
	end;
end;

procedure TMultiPolygonBase.ReadFromFiler(var ReadInfo: TReadInfo);
begin
	with ReadInfo do
	begin
	FContours.ReadFromFiler(Reader, ReadInfo.FileVersion);
	Reader.Read(FContoursNormal, SizeOf(TAffineVector));
	Reader.Read(FTexOffset, Sizeof(TDAffineVector));
	Reader.Read(FTexScale, Sizeof(TDAffineVector));
	end;
	inherited;
end;

procedure TMultiPolygonBase.WriteToFiler(var WriteInfo: TWriteInfo);
begin
	with WriteInfo do
	begin
	FContours.WriteToFiler(Writer);
	Writer.Write(FContoursNormal, SizeOf(TAffineVector));
	Writer.Write(FTexOffset, Sizeof(TDAffineVector));
	Writer.Write(FTexScale, Sizeof(TDAffineVector));
	end;
	inherited;
end;

function TMultiPolygonBase.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
	Result:=0;
	with LoadInfo, Reader, CurrentBlock do
		case BlockType of
					btPolygonNormal	 	: ReadAffineVector(FContoursNormal);
					btPolygonTexOffset: ReadDAffineVector(FTexOffset);
					btPolygonTexScale	: ReadDAffineVector(FTexScale);
		else
			Result:=inherited LoadParam(LoadInfo);
		end;
end;

function TMultiPolygonBase.GetLoadingChild(var LoadInfo: TLoadInfo; const ChildBlockType: cardinal;
	const ChildClass: string; const ChildID: string): TObject;
begin
	case ChildBlockType of
		btPolygonContours: Result:=FContours;
	else
		Result:=inherited GetLoadingChild(LoadInfo, ChildBlockType, ChildClass, ChildID);
	end;
end;

procedure TMultiPolygonBase.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
	with SaveInfo, Writer do
	try
		BeginChild(btPolygonContours);
		try
			FContours.SaveObject(SaveInfo);
		finally
			EndChild;
		end;
		WriteAffineVector(btPolygonNormal, FContoursNormal);
		WriteDAffineVector(btPolygonTexOffset, FTexOffset);
		WriteDAffineVector(btPolygonTexScale, FTexScale);
	except
		on e: exception do
			SaveInfo.Error('TMultiPolygonBase: ' + e.Message);
	end;
	inherited;
end;

procedure TGLMultiPolygon.ReadFromFiler(var ReadInfo: TReadInfo);
begin
	with ReadInfo do
	begin
	Reader.Read(FParts, SizeOf(TPolygonParts));
	end;
	inherited;
end;

procedure TGLMultiPolygon.WriteToFiler(var WriteInfo: TWriteInfo);
begin
	with WriteInfo do
	begin
	Writer.Write(FParts, SizeOf(TPolygonParts));
	end;
	inherited;
end;

function TGLMultiPolygon.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
	Result:=0;
	with LoadInfo, Reader, CurrentBlock do
		case BlockType of
					btPolygonParts	: Read(FParts, sizeof(TPolygonParts));
		else
			Result:=inherited LoadParam(LoadInfo);
		end;
end;

procedure TGLMultiPolygon.SaveObject(var SaveInfo: TSaveInfo); {ok}
begin
	with SaveInfo, Writer do
	try
		Write(btPolygonParts, FParts, sizeof(TPolygonParts));
	except
		on e: exception do
			SaveInfo.Error('TGLMultiPolygon: ' + e.Message);
	end;
	inherited;
end;

function TMultiPolygonBase.AxisAlignedBoundingBoxUnscaled(IncludeChildren: boolean; Validate: boolean): TAABB;
begin
  FContours.GetExtents(Result.min, Result.max);
end;

procedure TGLContour.GetExtents(var min, max: TDAffineVector);
begin
	FNodes.GetExtents(min, max);
end;


constructor TGLContours.CreateFromAABB(aabb: TAABB);
begin
  Create(nil);
  Add.Nodes.AddAABB(aabb);
end;

function TGLContours.Barycenter: TDAffineVector;
var
  mi, ma: TDAffineVector;
begin
  GetExtents(mi, ma);
  Result:=VectorScale(VectorAdd(mi, ma), 0.5);
end;

procedure TGLContours.Simmetrize;
var
  bc: TDAffineVector;
begin
  bc:=Barycenter;
  AddScaledVector(-1, bc);
end;

function TGLContours.CountHoles: integer;
var
  i: integer;
begin
  Result:=0;
  for i:=0 to Count - 1 do
    if Items[i].FHole then
      Inc(Result);
end;

function TGLContours.CountSolids: integer;
begin
  Result:=Count - CountHoles;
end;

procedure TGLContours.DoUpdate;
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    if Items[i].Hole then
      Items[i].Nodes.SetCW
    else
      Items[i].Nodes.SetCCW;
end;

function TGLContours.GetVectorList: TAffineVectorList;
var
  i: integer;
begin
  Result:=TAffineVectorList.Create;
  for i:=0 to Count - 1 do
    Result.Add(Items[i].Nodes.GetVectorList, true);
end;


function TGLContours.ConvertToRectangles: TGLContours;
var
  i: integer;
  aabb: TAABB;
begin
  Result:=TGLContours.Create(nil);
  for i:=0 to Count - 1 do
    with Result.Add.Nodes do
    begin
      with aabb do
        self[i].Nodes.GetExtents(min, max);
      AddAABB(aabb, self[i].Hole);
    end;
end;

procedure TGLContours.Scale(Sx, Sy, Sz: double);
var
  i: integer;
  v: TDAffineVector;
begin
  SetVector(v, Sx, Sy, Sz);
  for i:=0 to Count - 1 do
    Items[i].Nodes.Scale(v);
end;

procedure TGLContours.Divide(const DivW: double; const time: TIntegerDoubleList);
var
  i: integer;
begin
  if not assigned(time) then
    for i:=0 to Count - 1 do
      Items[i].Divide(DivW, 0, false)
  else
	if Count <= time.Count then
    for i:=0 to Count - 1 do
			Items[i].Divide(DivW, time[i].d, time[i].i and 2 <> 0)
  else
  begin
    for i:=0 to time.Count - 1 do
			Items[i].Divide(DivW, time[i].d, time[i].i and 2 <> 0);
		for i:=time.Count - 1 to Count - 1 do
      Items[i].Divide(DivW, 0, false);
  end;
end;

function TGLContours.Divide(const DivW, DivH: double; const time: TIntegerDoubleList): TGLContours;
var
  i: integer;
begin
  Result:=TGLContours.Create(nil);
  if not assigned(time) then
    for i:=0 to Count - 1 do
      Items[i].Divide(DivW, DivH, 0, false, Result.Add)
  else
	if Count <= time.Count then
	begin
		for i:=0 to Count - 1 do
			if time[i].i and 1 = 0 then
				Items[i].Divide(DivW, DivH, time[i].d, time[i].i and 2 <> 0, Result.Add)
			else
				Result.Add.Assign(Items[i]);
	end
	else
	begin
		for i:=0 to time.Count - 1 do
			if time[i].i and 1 = 0 then
				Items[i].Divide(DivW, DivH, time[i].d, time[i].i and 2 <> 0, Result.Add)
			else
				Result.Add.Assign(Items[i]);
		for i:=time.Count - 1 to Count - 1 do
			Items[i].Divide(DivW, DivH, 0, false, Result.Add);
  end;
end;

procedure TGLContours.AddContours(const aContours: TGLContours;
	transform: PMatrix; aFreeSource: Boolean);
var
	i: integer;
begin
	if not assigned(transform) then
		for i:=0 to aContours.Count - 1 do
			Add.Assign(aContours[i])
	else
		for i:=0 to aContours.Count - 1 do
			with Add do
			begin
				Assign(aContours[i]);
        Nodes.Transform(transform^);
			end;
  if aFreeSource then
    aContours.Free;
end;

procedure TGLContours.ZeroZ;
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.ZeroZ;
end;

procedure TGLContours.DeleteWrongContours;
var
	i: integer;
begin
	if count = 0 then exit;
	BeginUpdate;
	i:=count-1;
	while i>-1 do
	begin
		if Items[i].Nodes.Count < 3 then
			Delete(i);
		dec(i);
	end;
	EndUpdate;
end;

procedure TGLContours.BuildList(var rci: TRenderContextInfo);
var
	i: integer;
begin
	if rci.mirrorrendering then
		exit;
	for i:=0 to count-1 do
		Items[i].BuildList(rci);
end;

procedure TGLContours.SelectionChanged(newState: boolean; Sender: TObject;
  SenderClass: TClass);
begin
	if Owner is TGLBaseSceneObject then
		with TGLBaseSceneObject(Owner) do
			if assigned(scene) then
				Scene.SelectionChanged(newState, Sender, SenderClass);
end;

function TGLContours.GetSceneObject: TObject;
begin
	Result:=Owner;
end;

procedure TGLContours.SetEditMode(em: integer);
var
	i: integer;
begin
	for i:=0 to count-1 do
		Items[i].SetEditMode(em);
end;

class procedure TGLContours.GetExpandedContour(src, dst: TGLContours;
  const height: double);
var
  i, j, k, m, l, sc: integer;
  n1, n2, v1, v2, a, b, c: TDAffineVector;
  plane: THmgDblPlane;
  ip: TDVector;
  mainaabb: TAABB;
begin
  dst.Clear;
	if (height = 0) or (src.Count = 0) or (src[0].Nodes.Count < 3) then
	begin
		dst.Assign(src);
		Exit;
	end;
	with MainAABB do
	begin
		src.GetExtents(min, max);
		if VectorDistance(min, max) < 1E-5 then
		begin
      dst.Assign(src);
      Exit;
    end;
  end;
  if src.Count > 0 then
    for l:=0 to src.Count - 1 do
    begin
      m:=src.Items[l].Nodes.Count;
      if m > 0 then
        with dst.Add.Nodes do
          for i:=0 to m - 1 do
          begin
            a:=src.Items[l].Nodes[i].AsDoubleAffineVector;
            j:=i;
            sc:=0;
            repeat
              j:=(j + 1) mod m;
              b:=src.Items[l].Nodes[j].AsDoubleAffineVector;
              v1:=VectorSubtract(b, a);
              inc(sc);
            until (VectorLength(v1) > 1E-5) or (sc > m);
            if sc > m then
              break;
						n1[0]:=v1[1];
            n1[1]:=-v1[0];
            n1[2]:=0;
            NormalizeVector(n1);
            k:=j;
            sc:=0;
            repeat
              k:=(k + 1) mod m;
              c:=src.Items[l].Nodes[k].AsDoubleAffineVector;
              v2:=VectorSubtract(c, b);
              inc(sc);
            until (VectorLength(v2) > 1E-5) or (sc > m);
            if sc > m then
              break;
						n2[0]:=v2[1];
            n2[1]:=-v2[0];
            n2[2]:=0;
            NormalizeVector(n2);
						a:=VectorAdd(a, VectorScale(n1, height));
            c:=VectorAdd(c, VectorScale(n2, height));
            Plane:=DPlaneMake(c, n2);
            ip:=DVectorMake(c);
            IntersectLinePlane(DVectorMake(a), DVectorMake(v1), plane, @ip);
            AddNode(ip);
          end;
		end;
end;

procedure TGLContours.ExpandBorder(height: double);
var
	c: TGLContours;
begin
	c:=TGLContours.Create(nil);
	GetExpandedContour(self, c, height);
	Assign(c);
	c.Free;	
end;

procedure TGLContours.RetrieveOutline(List, BeginProc, AddVertexProc, EndProc: pointer;
	outlineOnly: boolean; normal: PAffineVector = nil);
var
	i, n: Integer;
	tess: PGLUTesselator;

	procedure TesselatePath(contour: TGLContour; inverted: Boolean);

		procedure IssueVertex(v: TAffineVector);
		var
			dblVector: TAffineDblVector;
			p: PAffineVector;
		begin
			vVertexPool.GetNewVector(Pointer(p));
			p^:=v;
			SetVector(dblVector, v);
			gluTessVertex(tess, dblVector, p);
		end;

  var
    i, n: Integer;
    spline: TCubicSpline;
    f: Single;
    splineDivisions: Integer;
    nodes: TGLContourNodes;
  begin
    gluTessBeginContour(tess);
    nodes:=contour.Nodes;
    if contour.SplineMode = lsmLines then
      splineDivisions:=0
    else
      splineDivisions:=contour.Division;
    if splineDivisions > 1 then
    begin
      spline:=nodes.CreateNewCubicSpline;
			try
        f:=1 / splineDivisions;
        n:=splineDivisions * (nodes.Count - 1);
        if inverted then
        begin
          for i:=n downto 0 do
            IssueVertex(spline.SplineAffineVector(i * f))
        end
        else
        begin
          for i:=0 to n do
            IssueVertex(spline.SplineAffineVector(i * f));
        end;
      finally
        spline.Free;
      end;
    end
    else
    begin
      n:=nodes.Count - 1;
      if inverted then
      begin
        for i:=n downto 0 do
          IssueVertex(nodes[i].AsAffineVector)
      end
      else
      begin
        for i:=0 to n do
          IssueVertex(nodes[i].AsAffineVector);
      end;
    end;
		gluTessEndContour(tess);
	end;

begin
	if (Count > 0) and (Path[0].Count > 2) then
	begin
		// Vertex count
		n:=0;
    for i:=0 to Count - 1 do
      n:=n + Path[i].Count;
    // Create and initialize the GLU tesselator
    vVertexPool:=TVectorPool.Create(n, SizeOf(TAffineVector));
    tess:=gluNewTess;
    try
      // register callbacks
      gluTessCallback(tess, GLU_TESS_BEGIN_DATA, BeginProc);
      gluTessCallback(tess, GLU_TESS_END, EndProc);
			gluTessCallback(tess, GLU_TESS_VERTEX_DATA, AddVertexProc);
			
      gluTessCallback(tess, GLU_TESS_ERROR, @tessError);
      gluTessCallback(tess, GLU_TESS_COMBINE, @tessCombine);

      // issue normal
			if assigned(normal) then
				gluTessNormal(tess, normal[0], normal[1], normal[2])
			else
				gluTessNormal(tess, 0, 0, 1);

      // set properties
      gluTessProperty(Tess, GLU_TESS_WINDING_RULE, GLU_TESS_WINDING_POSITIVE);
			if outlineOnly then
				gluTessProperty(Tess, GLU_TESS_BOUNDARY_ONLY, GL_TRUE);

      try
        gluTessBeginPolygon(tess, List);
        for n:=0 to Count - 1 do
          TesselatePath(Items[n], False);
        gluTessEndPolygon(tess);
      except
        // давим gluTessError
      end;

    finally
      gluDeleteTess(tess);
      vVertexPool.Free;
			vVertexPool:=nil;
    end;
  end;
end;

procedure TGLContours.Tesselate(var d: TPolygonDrawers; normal: PAffineVector = nil);
begin
	RetrieveOutLine(d, @tessBegin, @tessAddVertex, @tessEnd, false, normal);
end;

function TGLContours.Tesselate(normal: PAffineVector = nil): TPolygonDrawers;
begin
{	if owner is TGLCustomSceneObject then
		Result:=TPolygonDrawers.Create(TGLCustomSceneObject(Owner).Material)
	else}
	Result:=TPolygonDrawers.Create(nil);
  if normal <> nil then
    Result.Normal := Normal^;
	Tesselate(Result, normal);
end;

function TGLContours.GetTriangles: TAffineVectorList;
var
	d: TPolygonDrawers;
	i: integer;
begin
	d:=Tesselate;
	d.ConvertToTriangles;
	Result:=TAffineVectorList.Create;
	for i:=0 to d.Count - 1 do
		Result.Add(d[i].Vertices);
end;

function TGLContours.TransformedExtents(const m: TDMatrix;
  ExtentsInfo: PExtentsInfo): TAABB;
var
	i: integer;
	ext: TExtentsInfo;
begin
	Result:=UndefinedAABB;
	if ExtentsInfo = nil then
		for i:=0 to Count - 1 do
			AddAABB(Result, Items[i].TransformedExtents(m))
	else
	begin
		ExtentsInfo^:=UndefinedExtents;
		for i:=0 to Count - 1 do
			AddAABB(Result, Items[i].TransformedExtents(m, @ext), ExtentsInfo^, ext);
	end;
end;

function TGLContours.GenNormalMap(TexWidth, TexHeight, AA: integer; Smoothness,
	Width, Height, EdgeWidth, EdgeRadius: double; Scale: double; Progress: TProgressCallback): TBitmap;
type
	TGLPixel24 = packed record
			b, g, r: Byte;
	 end;
	 PGLPixel24 = ^TGLPixel24;
	TGLPixel24Array = array [0..0] of TGLPixel24;
	PGLPixel24Array = ^TGLPixel24Array;
var
	i, j, k, l, m, n: integer;
	x, y, x2, y2, dx, dy, daa, a, r2: double;
	Range, LastRange, factor, Left, Top: double;
	spotsize, ss2: double;
	ssx, ssy: integer;
	Norm, Norm1, Norm2: TDAffineVector;
	NormalMap: array of TDAffineVector;
	profile: TGLProfile;
	sl: PGLPixel24Array;

	R: double;
	N1, N2, Tilt: TDAffineVector;
	Nearest: TDAffineVector;
begin
	EncloseContours;

	SetLength(NormalMap, TexHeight * TexWidth);

	Result:=TBitmap.Create;
	Result.PixelFormat:=pf24bit;
	Result.Width:=TexWidth;
	Result.Height:=TexHeight;

	dx:=Width / (TexWidth);
	dy:=Height / (TexHeight);
	daa:=(AA - 1) / (2 * AA);
	Left:=-Width / 2;
	Top:=-Height / 2;

	profile:=TGLProfile.Create(nil);
	profile.FRadius:=EdgeRadius;
  profile.EdgeWidth:=EdgeWidth;
  profile.Scale:=Scale;

	spotsize:=Smoothness * EdgeWidth / 2;
	ss2:=Sqr(spotsize);
	ssx:=Round(spotsize / Abs(dx));
	ssy:=Round(spotsize / Abs(dy));

	if @Progress <> nil then
		Progress(0, '');

	for j:=0 to TexHeight - 1 do
		for i:=0 to TexWidth - 1 do
			NormalMap[i + TexWidth * j]:=ZDVector;

	for j:=0 to TexHeight - 1 do
	begin
		for i:=0 to TexWidth - 1 do
		begin
			x:=Left + dx * (i + 0.5);
			y:=Top + dy * (j + 0.5);

			Norm:=NullDVector;
			Norm1:=ZDVector;
			Range:=1E10;

			for k:=0 to Count - 1 do
				begin
					Norm2:=Items[k].GetNormalVector(x, y,	profile, csSharp, LastRange, 0.0);
					if Abs(LastRange) < Abs(Range) then
					begin
						Norm1:=Norm2;
						Range:=LastRange;
					end;
				end;

			if Abs(Range) < 0.25*(Abs(dx) + Abs(dy)) then
			begin
				for l:=0 to AA - 1 do
				for m:=0 to AA - 1 do
				begin
					x2:=x + dx * (l / AA - daa);
					y2:=y + dy * (m / AA - daa);
					Norm1:=ZDVector;
					Range:=1E10;

					for k:=0 to Count - 1 do
					begin
						Norm2:=Items[k].GetNormalVector(x2, y2,	profile, csSharp, LastRange, 0.0);
						if Abs(LastRange) < Abs(Range) then
						begin
							Norm1:=Norm2;
							Range:=LastRange;
						end;
					end;
					Norm:=VectorAdd(Norm, Norm1);
				end;
				NormalizeVector(Norm);
			end
			else Norm:=Norm1;

			NormalMap[i + TexWidth * j]:=Norm;
		end;
		if @Progress <> nil then
			Progress(j, '');
	end;

	for j:=0 to TexHeight - 1 do
	begin
		for i:=0 to TexWidth - 1 do
		begin
			Norm:=NormalMap[i + TexWidth * j];
			Norm1:=NullDVector;
			Norm2:=NullDVector;

			if Norm[2] < 1 then
			begin
				for l:=-ssx to ssx do
					for m:=-ssy to ssy do
					begin
						r2:=Sqr(l * dx) + Sqr(m * dy);
						if ((i + l) >= 0) and ((i + l) < TexWidth) and
							((j + m) >= 0) and ((j + m) < TexHeight) and	(r2 <= ss2)
							and (NormalMap[(i + l) + TexWidth * (j + m)][2] < 1) then
						begin
							Norm1:=NormalMap[(i + l) + TexWidth * (j + m)];
							Norm1[2]:=0;
							NormalizeVector(Norm1);
							if ss2 > 0 then factor:=(ss2 - r2) / ss2 else factor:=1; //! ??????? ???????
							ScaleVector(Norm1, factor);
							AddVector(Norm2, Norm1);
						end;
					end;

				NormalizeVector(Norm2);
				a:=Sqrt(Sqr(Norm[0]) + Sqr(Norm[1]));
				ScaleVector(Norm2, a);
				Norm1:=Norm;
				Norm1[2]:=0;
				if VectorDotProduct(Norm1, Norm2) > -0.9 then
				begin
					Norm[0]:=Norm2[0];
					Norm[1]:=Norm2[1];
				end
				else
				begin
					Norm[0]:=-Norm2[0];
					Norm[1]:=-Norm2[1];
				end;
				NormalMap[i + TexWidth * j]:=Norm;
			end;
		end;
		if @Progress <> nil then
			Progress(TexHeight + j, '');
	end;

	for j:=0 to TexHeight - 1 do
	begin
		sl:=PGLPixel24Array(Result.ScanLine[TexHeight - 1 - j]);
		for i:=0 to TexWidth - 1 do
			with sl[i] do
			begin
				r:=Trunc(255 * (NormalMap[i + TexWidth * j][0] + 1) / 2);
				g:=Trunc(255 * (NormalMap[i + TexWidth * j][1] + 1) / 2);
				b:=Trunc(255 * (NormalMap[i + TexWidth * j][2] + 1) / 2);
			end;
	end;
  profile.Free;
end;

procedure TGLContours.EncloseContours;
var
	i: integer;
begin
	for i:=0 to count - 1 do
		Items[i].EncloseContour;
end;

function TGLContours.IntersectRay(const rayPoint,
  rayVector: TDAffineVector): TDAffineVectorList;
var
	i: integer;
begin
	Result:=TDAffineVectorList.Create;
	for i:=0 to count - 1 do
		Items[i].IntersectRay(rayPoint, rayVector, Result);
end;

procedure TGLContours.DrawPoints(var rci: TRenderContextInfo);
var
	i: integer;
begin
	for i:=0 to count - 1 do
		Items[i].DrawPoints(rci);
end;

procedure TGLContours.Transform(m: TDMatrix);
var
	i: integer;
begin
	for i:=0 to Count - 1 do
		Items[i].Nodes.Transform(m);
end;

procedure TGLContours.DeleteShortSegments(e: double);
var
	i: integer;
begin
	for i:=0 to count - 1 do
		Items[i].DeleteShortSegments(e);
end;

procedure TGLContours.SetMinSegmentAngle(Angle, MaxSegmentLength: double);
var
	i: integer;
begin
	for i:=0 to count - 1 do
		Items[i].SetMinSegmentAngle(Angle, MaxSegmentLength);
end;

function TGLContours.GetExtContours(transform: PDMatrix; aForceClose: Boolean): TGLExContours;
var
  i, j: integer;
  v: TDAffineVector;
begin
  Result := TGLExContours.Create;
  Result.BeginUpdate;
  for i:=0 to count - 1 do
    with Items[i], Result.Add do
    begin
      Hole := FHole;
      for j:=0 to Nodes.Count - 2 do
      begin
        v := Nodes[j].AsDoubleAffineVector;
        v[2] := 0.0;
        Add(TGLExContourLineSegment).AsVector := v;
        if Nodes[j].HasMetaData then
          Last.GetMetaStorage.Assign(Nodes[j].GetMetaStorage, true);
      end;
      if not Nodes.Last.EqualTo(Nodes.First) then
      begin
        v := Nodes.Last.AsDoubleAffineVector;
        v[2] := 0.0;
        if aForceClose then
          Add(TGLExContourLineSegment).AsVector := v
        else
          Add(TGLExContourSegmentEnd).AsVector := v;
        if Nodes.Last.HasMetaData then
          Last.GetMetaStorage.Assign(Nodes.Last.GetMetaStorage, true);
      end;
    end;
  if Assigned(transform) then
    Result.Transform(transform, true);
  Result.EndUpdate;
end;

procedure TGLContours.SetContours(aContours: TGLExContours; aCloseIfNeeded: Boolean);
var
	i, j, k: integer;
	c1: TGLExContour;
	c2: TGLContour;
  segs: TDAffineVectorList;
begin
  BeginUpdate;
	Clear;
	if assigned(aContours) then
		for i:=0 to aContours.Count - 1 do
		begin
			c1:=TGLExContour(aContours.List[i]);
			c2:=Add;
			c2.Nodes.BeginUpdate;
			for j:=0 to c1.count - 1 do
      begin
        segs := c1.Segments[j].GetSegments;
        try
					for k:=0 to segs.Count - 1 do
          begin
						c2.Nodes.AddNode(segs.Items[k]);
            if c1.Segments[j].HasMetaData then
              c2.Nodes.Last.GetMetaStorage.Assign(c1.Segments[j].GetMetaStorage, true);
          end;
        finally
          segs.Free;
        end;
      end;
//				c2.Nodes.AddNode(c1.Segments[j].AsVector);
      if aCloseIfNeeded and c1.IsClosed then
        c2.EncloseContour;
			c2.Nodes.EndUpdate;
		end;
	EndUpdate;
end;

constructor TGLContours.CreateFromContours(contours: TGLExContours);
begin
	Create(nil);
	SetContours(contours);
end;

procedure TGLContours.SetRect(width, height: double);
begin
	Clear;
	with Add.Nodes do
	begin
		AddNode(-width * 0.5, -height * 0.5, 0.0);
		AddNode( width * 0.5, -height * 0.5, 0.0);
		AddNode( width * 0.5,  height * 0.5, 0.0);
		AddNode(-width * 0.5,  height * 0.5, 0.0);
	end;
end;

function TGLContours.PointInContours(const p: TDAffineVector): Boolean;
var
	i: integer;
begin
	Result:=false;
	for i:=0 to Count-1 do
	begin
		if Items[i].PointInContour(p) then
		begin
			if not Items[i].Hole then
				Result:=True;
			Exit;
		end;
	end;
end;

{-$DEFINE CERAMICWEB_MODE}
{$IFDEF CERAMICWEB_MODE}
function ContToExCont(Src: TGLContours): TGLExContours;
var
	i, j: integer;
	v: TDAffineVector;
begin
	Result:=TGLExContours.Create;
	Result.BeginUpdate;
	for i:=0 to Src.count - 1 do
		with Result.Add do
		begin
			Hole:=Src[i].Hole;
			for j:=0 to Src[i].Nodes.Count - 2 do
			begin
				v:=Src[i].Nodes[j].AsDoubleAffineVector;
				v[2]:=0.0;
				Add(TGLExContourLineSegment).AsVector:=v;
			end;
			if (Src[i].Nodes.Last <> nil) and (not Src[i].Nodes.Last.EqualTo(Src[i].Nodes.First)) then
			begin
				v:=Src[i].Nodes.Last.AsDoubleAffineVector;
				v[2]:=0.0;
				Add(TGLExContourLineSegment).AsVector:=v;
			end;
		end;
	Result.EndUpdate;
end;
{$ENDIF}

procedure TGLContours.GenNormalMapEx(src: TBitmap; TexWidth, TexHeight: integer;
	Smoothness, Width, Height, EdgeWidth, EdgeRadius,
  Scale: Double; Progress: TProgressCallback);
type
  //Tfin = record case byte of 1:(AsFloat: Single);
  //                           2:(AsInt: Integer); end;
  Tfin = record AsFloat: Single; AsInt: Integer end;

	Tbgr = packed record
  	b, g, r: Byte;
  end;
  Tbgra=record case byte of 1:(b, g, r, a: Byte);
                            2:(Color: integer);
                            3:(bgr: Tbgr; alpha: byte); end;

	TGLPixel32Array = array [0..0] of Tbgra;
	PGLPixel32Array = ^TGLPixel32Array;

	TGLPixel24Array = array [0..0] of Tbgr;
	PGLPixel24Array = ^TGLPixel24Array;

  function NormalToBGR(Normal: TAffineVector): Tbgr;
  begin
    Normal[0]:=(Normal[0]+1.0)*0.5;
    Normal[1]:=(Normal[1]+1.0)*0.5;
    Normal[2]:=(Normal[2]+1.0)*0.5;

    result.r:=round(Normal[0]*255);
    result.g:=round(Normal[1]*255);
    result.b:=round(Normal[2]*255);
  end;
  function BGRToNormal(c: Tbgr): TAffineVector;
  const
    s: Single = 2/255;
  begin
    result[0]:=c.r*s-1;
    result[1]:=c.g*s-1;
    result[2]:=c.b*s-1;
  end;
  procedure CombineNormals(const V1: TAffineVector; var V2: TAffineVector);
  begin
    V2[0]:=V1[0]+V2[0];
    V2[1]:=V1[1]+V2[1];
    V2[2]:=V1[2]*V2[2];
    NormalizeVector(V2);
  end;
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
var
	i, j, k, l, m, n: integer;
	x, y, dx, dy, a, r2: double;
	Range, LastRange, factor, Left, Top: double;
	spotsize, ss2: double;
	ssx, ssy: integer;
	Norm, Norm1, Norm2: TDAffineVector;
	NormalMap: array of TDAffineVector;
  Mask: array of Tfin;
	profile: TGLProfile;
	sl: PGLPixel24Array;

	R: double;
	N1, N2, Tilt: TDAffineVector;
	Nearest: TDAffineVector;
  Normal: TAffineVector;
  HasHoles: Boolean;
begin
	EncloseContours;

{$IFDEF CERAMICWEB_MODE}
    with ContToExCont(Self) do
    begin
      ToTextFile('c:\debug1\1.txt');
      Free;
    end;
{$ENDIF}
  Src.PixelFormat:=pf24bit;

	SetLength(NormalMap, TexHeight * TexWidth);
  SetLength(Mask, TexHeight * TexWidth);

	dx:=Width / (TexWidth);
	dy:=Height / (TexHeight);
	Left:=-Width / 2;
	Top:=-Height / 2;

	profile:=TGLProfile.Create(nil);
	profile.FRadius:=EdgeRadius;
  profile.EdgeWidth:=EdgeWidth;
  profile.Scale:=Scale;

	spotsize:=Smoothness * EdgeWidth / 2;
	ss2:=Sqr(spotsize);
	ssx:=Round(spotsize / Abs(dx));
	ssy:=Round(spotsize / Abs(dy));

	if @Progress <> nil then
		Progress(0, '');

	//for j:=0 to TexHeight - 1 do
	//	for i:=0 to TexWidth - 1 do
	//		NormalMap[i + TexWidth * j]:=ZDVector;

  HasHoles := False;
  for k:=0 to Count - 1 do
    if Items[k].Hole then
    begin
      HasHoles := True;
      Break;
    end;

  //цикл построени€ карты индексов контуров
  //ToDo: можно растеризовать
	for j:=0 to TexHeight - 1 do
	begin
		for i:=0 to TexWidth - 1 do
		begin
			x:=Left + dx * (i + 0.5);
			y:=Top + dy * (j + 0.5);
      m := -1;
      if (not HasHoles) then
        for k:=0 to Count - 1 do
          if (Items[k].PointInPolygon(x, y)) then
          begin
            m := k;
            Mask[i + TexWidth * j].AsFloat := ClampValue(Items[k].DistanceToContour(x, y) / EdgeWidth, 0.0, 1.0);
            break;
          end;

      if m = -1 then
      begin
        Range:=1E10;
        for k:=0 to Count - 1 do
        begin
          LastRange := Items[k].DistanceToContour(x, y);
          if Abs(LastRange) < Abs(Range) then
          begin
            Range := LastRange;
            m := k;
          end;
        end;
      end;
      Mask[i + TexWidth * j].AsInt := m;
    end;
		if @Progress <> nil then
			Progress(j, '');
  end;

  //цикл построени€ карты нормалей и маски
	for j:=0 to TexHeight - 1 do
	begin
		for i:=0 to TexWidth - 1 do
		begin
			x:=Left + dx * (i + 0.5);
			y:=Top + dy * (j + 0.5);

			Norm :=NullDVector;
			Norm1:=ZDVector;
			Range:=1E10;

      m := Mask[i + TexWidth * j].AsInt;
      if m <> -1 then
        Norm1 := Items[m].GetNormalVector(x, y,	profile, csSharp, LastRange, 0.0);
      {
      else
      begin
        //цикл по контурам
        for k:=0 to Count - 1 do
        begin
          Norm2 := Items[k].GetNormalVector(x, y,	profile, csSharp, LastRange, 0.0);
          if Abs(LastRange) < Abs(Range) then
          begin
            Norm1 := Norm2;
            Range := LastRange;
          end;
        end;
      end;
      }
      //Mask[i + TexWidth * j].AsFloat:=ClampValue(Range / EdgeWidth, 0.0, 1.0);
{$IFDEF CERAMICWEB_MODE}
      Norm1[1]:=-Norm1[1];
{$ENDIF}
			NormalMap[i + TexWidth * j]:=Norm1;
		end;
		if @Progress <> nil then
			Progress(TexHeight + j, '');
	end;

  //цикл размыти€
	for j:=0 to TexHeight - 1 do
	begin
		for i:=0 to TexWidth - 1 do
		begin
      R:=Mask[i + TexWidth * j].AsFloat;
      //размываем только край
      if (R = 0.0)or(R = 1.0) then Continue;
			Norm:=NormalMap[i + TexWidth * j];
			Norm1:=NullDVector;
			Norm2:=NullDVector;

			if Norm[2] < 1 then
			begin
				for l:=-ssx to ssx do
					for m:=-ssy to ssy do
					begin
						r2:=Sqr(l * dx) + Sqr(m * dy);
						if ((i + l) >= 0) and ((i + l) < TexWidth) and
							((j + m) >= 0) and ((j + m) < TexHeight) and	(r2 <= ss2)
							and (NormalMap[(i + l) + TexWidth * (j + m)][2] < 1) then
						begin
							Norm1:=NormalMap[(i + l) + TexWidth * (j + m)];
							Norm1[2]:=0;
							NormalizeVector(Norm1);
							if ss2 > 0 then factor:=(ss2 - r2) / ss2 else factor:=1;
							ScaleVector(Norm1, factor);
							AddVector(Norm2, Norm1);
						end;
					end;

				NormalizeVector(Norm2);
				a:=Sqrt(Sqr(Norm[0]) + Sqr(Norm[1]));
				ScaleVector(Norm2, a);
				Norm1:=Norm;
				Norm1[2]:=0;
				if VectorDotProduct(Norm1, Norm2) > -0.9 then
				begin
					Norm[0]:=Norm2[0];
					Norm[1]:=Norm2[1];
				end
				else
				begin
					Norm[0]:=-Norm2[0];
					Norm[1]:=-Norm2[1];
				end;
				NormalMap[i + TexWidth * j]:=Norm;
			end;
		end;
		if @Progress <> nil then
			Progress(TexHeight*2 + j, '');
	end;

	for j:=0 to TexHeight - 1 do
	begin
		sl:=PGLPixel24Array(Src.ScanLine[TexHeight - 1 - j]);
		for i:=0 to TexWidth - 1 do begin
      Normal:=AffineVectorMake(NormalMap[i + TexWidth * j]);
      CombineNormalsEx(BGRToNormal(sl[i]), Normal, Mask[i + TexWidth * j].AsFloat);
      sl[i]:=NormalToBGR(Normal);
    end;
	end;
  profile.Free;
end;

procedure TGLContours.DrawLines(var rci: TRenderContextInfo; Color: TVector;
  Pattern: word; width: single; Closed: boolean);
var
  i: integer;
begin
  for i:=0 to Count - 1 do
    Items[i].Nodes.DrawLines(rci, Color, Pattern, width, Closed);
end;

function TGLContours.SplitToPolygons: TObjectList;
var
  i, j: integer;
  n: TGLContours;
  c: TGLContour;
  ab1, ab2: TAABB;
begin
  Result := TObjectList.Create;
  for i := 0 to Count - 1 do
  begin
    c := Items[i];
    if c.Nodes.IsCCW then
    begin
      n := TGLContours.Create(nil);
      n.Add.Assign(c);
      Result.Add(n);
    end;
  end;
  for i := 0 to Count - 1 do
  begin
    c := Items[i];
    c.GetExtents(ab1.min, ab1.max);
    if c.Nodes.IsCCW = false then
    begin
      for j := 0 to Result.Count - 1 do
      begin
        n := TGLContours(Result[j]);
        n.GetExtents(ab2.min, ab2.max);
        if IntersectAABBsAbsoluteXY(ab1, ab2) then
          n.Add.Assign(c);
      end;
    end;
  end;
end;

function TGLContours.ToJSON(const binaryDataExportPath: string): string;
type
  TContoursHeader = packed record
    prefix: array[0..3] of AnsiChar;
    data_type: Integer;
    num_contours: Integer;
    file_version: Integer;
  end;
  TContourHeader = packed record
    prefix: array[0..3] of AnsiChar;
    CCW: byte;
    ContourType: byte;
    num_nodes: Integer;                
  end;
var
  i, j: integer;
  c: TGLContour;
  m: TTempFileStream;
  h: TContoursHeader;
  h2: TContourHeader;
  data: array of TVector3d;
begin
  if Self = nil then
  begin
    Result := 'null';
    exit;
  end;
  m := TTempFileStream.Create;
  try
    FillChar(h, sizeof(h), 0);
    FillChar(h2, sizeof(h2), 0);
    h.prefix := 'GCNT';
    h2.prefix := 'CNDT';
    h.data_type := 1;
    h.num_contours := Count;
    h.file_version := 1;
    m.Write(h, sizeof(h));
    for i := 0 to Count - 1 do
    begin
      c := Items[i];
      h2.num_nodes := c.Nodes.Count;
      h2.CCW := Byte(c.Nodes.IsCCW);
      h2.ContourType := Byte(c.SplineMode);
      if Length(data) < h2.num_nodes then
        SetLength(data, h2.num_nodes);
      for j := 0 to h2.num_nodes - 1 do
        data[j] := c.Nodes[j].AsDoubleAffineVector;
      m.Write(h2, sizeof(h2));
      m.Write(data[0], sizeof(data[0]) * h2.num_nodes);
    end;
    Result := md5stream(m);
    with TFileStream.Create(IncludeTrailingPathDelimiter(binaryDataExportPath) + Result, fmCreate) do
    try
      CopyFrom(m, 0);
    finally
      Free;
    end;
  finally
    m.Free;
  end;
end;

{ TGLNodesList }

procedure TGLNodesList.Add(node: TGLNode);
begin
	inherited Add(node);
end;

procedure TGLNodesList.AddScaledVector(s: double; Vec: TDAffineVector);
var
	i: integer;
begin
	for i:=0 to Count - 1 do
		Nodes[i].AsDoubleAffineVector:=VectorAdd(Nodes[i].AsDoubleAffineVector, VectorScale(vec, s));
end;

function TGLNodesList.GetNode(index: integer): TGLNode;
begin
	Result:=TGLNode(inherited Items[index]);
end;

function TGLContours.CollectNodesAboveLine(lineAABB: TAABB;
	CheckX, Above: boolean): TGLNodesList;

const
	BoolSign: array[false..true] of integer = (-1, 1);

var
	i, j: integer;
	chk: TDAffineVector;

begin
  Result:=TGLNodesList.Create;

  if Above then
    chk:=lineAABB.max
  else
    chk:=lineAABB.min;

  if CheckX then
  begin
    for i:=0 to Count - 1 do
      with Items[i].Nodes do
        for j:=0 to Count - 1 do
					if Items[j].DoubleX * boolsign[Above] >= chk[0] * boolsign[Above] then
						Result.Add(Items[j]);
	end
	else
	begin
		for i:=0 to Count - 1 do
			with Items[i].Nodes do
				for j:=0 to Count - 1 do
          if Items[j].DoubleY * boolsign[Above] >= chk[1] * boolsign[Above] then
            Result.Add(Items[j]);
  end;
end;

procedure TMultiPolygonBase.CacheTrackPoints(AbsoluteToLocal: TDMatrix;
  HowMany: TTrackPointsType);
var
  i, j: integer;
  m: TDMatrix;
begin
	TrackPoints.TempVector:=VectorTransform(GlobalDoublePosition, AbsoluteToLocal);
  M:=MatrixMultiply(AbsoluteLocalDoubleMatrix, AbsoluteToLocal);
  with TransformedAxisAlignedBoundingBox(AbsoluteToLocal) do
  begin
    TrackPoints.Init(5, 5, min, max);
    {		addPoint (Self, min);
      addPOint (Self, max);}
  end;
  for i:=0 to FContours.Count - 1 do
		with FContours[i].Nodes do
		begin
			for j:=0 to Count - 1 do
				with Items[j] do
					TrackPoints.Add(VectorTransform(AsDoubleAffineVector, M));
			TrackPoints.Add(VectorTransform(GeomCenterInDouble, M));
		end;
end;

{procedure TGLMultiPolygon.DrawSelection(rci: TRenderContextInfo;
	shouldRenderSelf: boolean);
begin
	if ObjectType = otApplication then
		if rci.rendering = rOpaqueOnly then
			inherited DrawSelection(rci, true)
		else
	else
		inherited;
end;}

{ TGLContoursList }

function TGLContoursList.GetItem(index: integer): TGLContours;
begin
  Result:=TGLContours(inherited Items[index]);
end;

function TGLContoursList.IndexOfOwner(const aOwner: TPersistent): integer;
begin
  Result:=Count - 1;
  while (Result > -1) and (Items[Result].Owner <> aOwner) do
    dec(Result);
end;

procedure TGLContoursList.SetItem(index: integer;
  const Value: TGLContours);
begin
  inherited Items[index]:=Value;
end;

procedure TGLContour.Divide(const DivW: double; const time: double; forceLine: boolean);
var
  n: TDAffineVectorList;
begin
	if forceLine or (SplineMode = lsmLines) then
	begin
		n:=DivideLine(Nodes, DivW, time, forceLine);
		try
			Nodes.Clear;
			Nodes.AddVectors(n);
		finally
			n.Free;
		end;
	end
	else
	case SplineMode of
		lsmCubicSpline:
			begin
				n:=DivideSpline(Nodes.CreateNewCubicSpline, DivW, lsdmLeft, Division, true);
				try
					Nodes.Clear;
					Nodes.AddVectors(n);
				finally
					n.Free;
					SplineMode:=lsmLines;
				end;
			end;
	end;
end;

procedure TGLContour.Divide(const DivW, DivH: double; const time: double;
	forceLine: boolean; const Out_C: TGLContour);
var
	n, o: TDAffineVectorList;
begin
	if forceLine or (SplineMode = lsmLines) then
			begin
				n:=TDAffineVectorList.Create;
				o:=TDAffineVectorList.Create;
				DivideLine(Nodes, DivW, DivH, time, n, o, forceLine);
				try
					Nodes.Clear;
					Nodes.AddVectors(n);
					out_c.Nodes.Clear;
					out_c.Nodes.AddVectors(o);
				finally
					n.Free;
					o.Free;
				end;
			end
	else
	case SplineMode of
		lsmCubicSpline:
			begin
				n:=DivideSpline(Nodes.CreateNewCubicSpline, DivW, lsdmLeft, Division, true);
				try
					Nodes.Clear;
					Nodes.AddVectors(n);
				finally
					n.Free;
					SplineMode:=lsmLines;
				end;
			end;
	end;
end;

function TMultiPolygonBase.GetTexOffset: TDAffineVector;
begin
  Result:=FTexOffset;
end;

function TMultiPolygonBase.GetTexScale: TDAffineVector;
begin
  Result:=FTexScale;
end;

procedure TMultiPolygonBase.SetTexOffset(const off: TDAffineVector);
begin
  if not VectorEquals(FTexOffset, off) then
  begin
    FTexOffset:=off;
    StructureChanged;
  end;
end;

procedure TMultiPolygonBase.SetTexScale(const off: TDAffineVector);
begin
  if not VectorEquals(FTexScale, off) then
  begin
    FTexScale:=off;
    StructureChanged;
  end;
end;

procedure TMultiPolygonBase.BuildPropertyPage(
  var po: TPropertyPageOptions);
begin
  inherited;
  if ptTexOffset in po.ToShow then
    TPropEdit(FPropertyPage).AddProperty(pitVec, TVecPropParams.Create(commonStep, opvsTex),
      TVec3Property.Create(GetTexOffset, SetTexOffset, 1, MakeRange(-10, 10)),
      tr('—мещение текстуры'), ptTexOffset);

  if ptTexScale in po.ToShow then
    TPropEdit(FPropertyPage).AddProperty(pitVec, TVecPropParams.Create(commonStep, opvsTex),
      TVec3Property.Create(GetTexScale, SetTexScale, 1, MakeRange(-10, 10)),
      tr('ћасштаб текстуры'), ptTexScale);
end;

{ TGLContoursList2 }

destructor TGLContoursList2.Destroy;
begin
	DoClean;
	inherited;
end;

function TGLContoursList2.GetItem(index: integer): TGLContoursList2Item;
begin
	Result:=TGLContoursList2Item(inherited Items[index]);
end;

function TGLContoursList2.IndexOfOwner(const aOwner: TPersistent): integer;
begin
	Result:=count-1;
	while (result>-1) and (items[Result].Contours.Owner <> aOwner) do
		dec(result);
end;

procedure TGLContoursList2.SetItem(index: integer;
  const Value: TGLContoursList2Item);
begin

end;

{ TGLContoursList2Item }

constructor TGLContoursList2Item.Create(aContoursSK: TGLBaseSceneObject;
  aContours: TGLContours);
begin
	inherited Create;
	Contours:=aContours;
	ContoursSK:=aContoursSK;
end;

destructor TGLContoursList2Item.Destroy;
begin
	Contours.Free;
  inherited;
end;

function TGLContour.ExtractParts(epsi: double): TPersistentObjectList;
var
	i, j: integer;
	c: TGLContour;
begin
	Result:=TPersistentObjectList.Create;
	i:=0;
	while i < nodes.count - 1 do
	begin
//		if VectorDistance(nodes[i].AsDoubleAffineVector, nodes[i+1].AsDoubleAffineVector) < epsi then
		if VectorDistance(nodes[i].AsDoubleAffineVector, nodes[i+1].AsDoubleAffineVector) < epsi then
		begin
			c:=TGLContour.Create(nil);
			c.Hole:=self.Hole;
			Result.Add(c);
			c.SplineMode:=lsmCubicSpline;
			c.NoDerivatives:=true;
			c.Nodes.AddNode(nodes[i].AsDoubleAffineVector);
			j:=i + 1;
			while (j < nodes.Count - 1) and (VectorDistance(nodes[j].AsDoubleAffineVector, nodes[j + 1].AsDoubleAffineVector) < epsi) do
			begin
				c.Nodes.AddNode(nodes[j].AsDoubleAffineVector);
				inc(j);
			end;
			c.Nodes.AddNode(nodes[j].AsDoubleAffineVector);
		end
		else
		begin
			c:=TGLContour.Create(nil);
			c.Hole:=self.Hole;
			Result.Add(c);
			c.Nodes.AddNode(nodes[i].AsDoubleAffineVector);
			j:=i + 1;
			while (j < nodes.Count - 1) and (VectorDistance(nodes[j].AsDoubleAffineVector, nodes[j + 1].AsDoubleAffineVector) >= epsi) do
			begin
				c.Nodes.AddNode(nodes[j].AsDoubleAffineVector);
				inc(j);
			end;
			c.Nodes.AddNode(nodes[j].AsDoubleAffineVector);
		end;
		i:=j;
	end;
end;

procedure TMultiPolygonBase.DoOnContextRecreate;
begin
	inherited;
	DropAGPCache;
end;

procedure TMultiPolygonBase.RenderPolygon(var rci: TRenderContextInfo;
	const Textured: boolean; normal: PAffinevector; invertNormals: boolean);
	procedure DrawPolyCache;
	begin
		if assigned(Normal) then
			FPolygonCache.Normal:=Normal^;
		if invertNormals then
		begin
			glFrontFace(GL_CW);
			FPolygonCache.Draw(rci, Self);
			glFrontFace(GL_CCW);
		end
		else
			FPolygonCache.Draw(rci, Self);
	end;
var
	m: TMatrix;
begin
	if textured then
	begin
		glGetFloatV(GL_TEXTURE_MATRIX, @m);
		glMatrixMode(GL_TEXTURE);
		glTranslatef(-FTexOffset[0], -FTexOffset[1], -FTexOffset[2]);
		glScaleF(FTexScale[0], FTexScale[1], FTexScale[2]);
		glMatrixMode(GL_MODELVIEW);
	end;
	if FDrawPolyAsMesh then
		If Assigned(FPolygonCache) and FPolyCacheValid then
			DrawPolyCache
		else
		begin
			if not assigned(Normal) then
				normal:=@ZVector
			else
			if InvertNormals then
				NegateVector(normal^);
			RenderTesselatedPolygon(true, normal, false);
			DrawPolyCache;
		end
	else
		RenderTesselatedPolygon(textured, normal, invertNormals);
	if textured then
	begin
		glMatrixMode(GL_TEXTURE);
		glLoadMatrixF(@m);
		glMatrixMode(GL_MODELVIEW);
	end;
end;

procedure TMultiPolygonBase.StructureChanged;
begin
	RebuildPolyCache;
	inherited;
end;

procedure TMultiPolygonBase.DropAGPCache;
begin
	if assigned(FPolygonCache) then
		FPolygonCache.DropAGPCache;
end;

function TMultiPolygonBase.GetDrawPolyAsMesh: boolean;
begin
	Result:=FDrawPolyAsMesh;
end;

procedure TMultiPolygonBase.SetDrawPolyAsMesh(const v: boolean);
begin
	if FDrawPolyAsMesh <> v then
	begin
		FDrawPolyAsMesh:=v;
		if v = false then
			RebuildPolyCache;
	end;
end;

procedure TMultiPolygonBase.RebuildPolyCache;
begin
	FPolyCacheValid:=false;
end;

{procedure TMultiPolygonBase.NotifyChange(Sender: TObject);
begin
	if (sender = self.Material) and assigned(FPolygonCache) then
		RebuildPolyCache;
	inherited;
end;}

{function TGLMultiPolygon.IsMyReflection(
	var rci: TRenderContextInfo): boolean;
begin
	result:=rci.reflectioncnt mod 2 = 0;
end;}

procedure TGLContour.BuildList(var rci: TRenderContextInfo);
const
	col: array[boolean] of TVector = ((0, 0, 1, 1), (1, 0, 0, 1));
begin
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glEnable(GL_STENCIL_TEST);
	glStencilFunc(GL_ALWAYS, 1, $FFFF);
	glStencilOp(GL_ZERO, GL_ZERO, GL_ZERO);
	glStencilMask($FF);
	glEnable(GL_DEPTH_TEST);
	glDepthMask(true);
	glDepthFunc(GL_ALWAYS);
	glDisable(GL_LIGHTING);
	if not(rci.drawState in [dsSelecting, dsPicking]) then
		FNodes.DrawLines(rci, col[FNodes.EditMode = 1], $FF00, 3, true);
	FNodes.BuildList(rci);
	glPopAttrib;	
end;

procedure TGLContourNodes.SelectionChanged(newState: boolean;
  Sender: TObject; SenderClass: TClass);
begin
	TGLContours(TGLContour(owner).Collection).SelectionChanged(newState, Sender, SenderClass);
end;

procedure TGLContourNode.SetAbsoluteDoublePosition(const vec: TDVector);
var
	d: TDAffineVector;
begin
	if TGLContourNodes(collection).FEditMode = 1 then
	begin
		d:=VectorSubtract(VectorTransform(PDAffineVector(@vec)^, InvAbsoluteLocalDoubleMatrix), AsDoubleAffineVector);
		d:=VectorScale(FMoveAxis, VectorDotProduct(FMoveAxis, d));
		AsDoubleAffineVector:=VectorAdd(AsDoubleAffineVector, d);
		with TGLContourNodes(collection) do
			with Items[(Self.Index + 1) mod count] do
				AsDoubleAffineVector:=VectorAdd(AsDoubleAffineVector, d);
	end
	else
		inherited;
end;

procedure TGLContourNodes.SetEditMode(const Value: integer);
begin
	if FEditMode <> value then
	begin
		FEditMode := Value;
{		if FEditMode = 1 then
			UpdateNodesAxis;}
	end;
end;

procedure TGLContourNodes.UpdateNodesAxis;
var
	i: integer;
begin
	for i:=0 to count-1 do
		TGLContourNode(Items[i]).FMoveAxis:=Normal2d(i);
end;

{ TGLContourNode }

procedure TGLContourNode.Assign(Source: TPersistent);
begin
  inherited;
	if source is TGLContourNode then
	begin
		FMoveAxis:=TGLContourNode(Source).FMoveAxis;
    FNormal := TGLContourNode(Source).FNormal;
	end;
end;

procedure TGLContourNode.UpdateNodeAxis;
begin
	FMoveAxis:=TGLContourNodes(collection).Normal2D(index);
end;

procedure TGLContourNode.PrepareForMove;
begin
	if TGLContourNodes(Collection).FEditMode = 1 then
		UpdateNodeAxis;
	inherited;
end;

procedure TGLContour.SetEditMode(em: integer);
begin
	Nodes.SetEditMode(em);
end;

constructor TGLContourNode.Create(Collection: TCollection);
begin
  inherited;
  FNormal := ZDVector;
end;

function TGLContourNode.LoadParam(var LoadInfo: TLoadInfo): integer;
begin
	Result:=0;
	with LoadInfo, Reader, CurrentBlock do
		case BlockType of
      btContourNodeNormal: FNormal := ReadDAffineVector;
		else
			Result:=inherited LoadParam(LoadInfo);
		end;
end;

procedure TGLContourNode.ReadFromFiler(reader: TCustomReader;
  FileVersion: integer);
begin
  if FileVersion >= 51 then
    Reader.Read(FNormal, sizeof(FNormal));
  inherited;
end;

procedure TGLContourNode.SaveObject(var SaveInfo: TSaveInfo);
begin
	with SaveInfo, Writer do
	try
		WriteDAffineVector(btContourNodeNormal, FNormal);
	except
		on e: exception do
			SaveInfo.Error('TGLContourNode: ' + e.Message);
	end;
	inherited;
end;

procedure TGLContourNode.WriteToFiler(writer: TCustomWriter);
begin
	Writer.Write(FNormal, SizeOf(FNormal));
  inherited;
end;

{ TGLProfile }

constructor TGLProfile.Create(Collection: TCollection);
begin
	inherited;
	FDefault:=true;
	FRadius:=0.01;
  FEdgeWidth:=FRadius;
	FHScale:=1.0;
  FScale:=1.0;
end;

function TGLProfile.GetNormTilt(Range: double): TDAffineVector;
var
	R: double;
	Slope: TDAffineVector;

	function FindNearestPointSlope(R: double): TDAffineVector;
	var
		i: integer;
		Pos, Alt, NewAlt: double;
	begin
		Alt:=-1E10;
		Result:=XDVector;
		for i:=0 to Nodes.Count - 2 do
			if (Nodes[i].DoubleX < R) and (Nodes[i+1].DoubleX > R) then
			begin
				Pos:=(R - Nodes[i].DoubleX) / (Nodes[i+1].DoubleX - Nodes[i].DoubleX);
				NewAlt:=(Nodes[i+1].DoubleY - Nodes[i].DoubleY) * Pos + Nodes[i].DoubleY;
				if NewAlt > Alt then
				begin
					Alt:=NewAlt;
					Result:=VectorNormalize(VectorSubtract(Nodes[i+1].AsDoubleAffineVector,
						Nodes[i].AsDoubleAffineVector));
				end;
			end;
	end;

begin
	if FDefault then
	begin
    Range:=ClampValue(Range, 0.0, EdgeWidth);
    R:=1 - (Range + (FRadius-EdgeWidth)) / FRadius;
		//R:=1 - Range / FRadius;
		{if IsInRangeD(R, 1E-6, 1-1E-6) then
		begin
			Result[0]:=-R/Sqrt(1 - R);
			Result[1]:=1;
			Result[2]:=0;
			NormalizeVector(Result);
		end
		else
		if IsInRange(R, 1 - 1E-6, 1) then
			Result:=MinusXDVector
		else
			Result:=YDVector;
	end}
    //R:=ClampValue(R, 0.0, 1.0);
    Result[0]:=-R;
    Result[1]:=Sqrt(1 - R*R)/FScale;
    Result[2]:=0;
    NormalizeVector(Result);
	end
	else
	begin
		R:=(Nodes.Last.DoubleX - Nodes.First.DoubleX) * Range / FRadius + Nodes.First.DoubleX; ///!!
		if IsInRangeD(R, Nodes.First.DoubleX + 1E-6, Nodes.Last.DoubleX - 1E-6) then
		begin
			Slope:=FindNearestPointSlope(R);
			Result[0]:=-FHScale * Slope[1];
			Result[1]:=Slope[0];
			Result[2]:=0;
			if Result[1] < 0 then
			begin
				Result[0]:=-Result[0];
				Result[1]:=-Result[1];
			end;
			//NormalizeVector(Result);
		end
		else	Result:=YDVector;
	end;
	//Result:=NearestData.DistanceY;
	//function IntersectLines(Nodes: TGLNodes; CN: TPersistentObjectList; Point, LinePoint, Dir: TDAffineVector; var tData: TTrackPointInfo): Double;
end;

procedure TGLProfile.NormalizeDir;
begin
	if not FDefault and (Nodes.First.DoubleX > Nodes.Last.DoubleX) then
		Nodes.Reverse;
end;

{procedure TGLMultiPolygon.RecContoursChanged;
var
	i: integer;
begin
	with CollectChildrenByClass(TGLBaseContentClipWindow, TPersistentObjectList, false, [bsolCliped]) do
	try
		for i:=0 to Count - 1 do
			if Items[i] is TGLBlackBorderWindow then
				TGLBlackBorderWindow(Items[i]).UpdateBorder
			else
			with TGLBaseContentClipWindow(Items[i]) do
				PickContour(Parent);
	finally
		free;
	end;
end;}

function TMultiPolygonBase.GetTrackPoints(Context: TObject; Types: TAlignmentTypeSet;
	IntersectObjects, SkipObjects: TPersistentObjectList;
	AbsoluteToLocal: PDMatrix): TTrackPointsList;
var
	i, j: integer;
	m: TDMatrix;
begin
	Result:=TTrackPointsList.Create;
	if ([TRACK_NODES, TRACK_MPOINT] * Types = []) or (assigned(SkipObjects) and (SkipObjects.IndexOf(self) > -1)) then exit;
	if assigned(AbsoluteToLocal) then
		m:=MatrixMultiply(AbsoluteLocalDoubleMatrix, AbsoluteToLocal^)
	else
		m:=AbsoluteLocalDoubleMatrix;
	for i:=0 to Contours.Count - 1 do
		with Contours[i].Nodes do
			for j:=0 to Count - 1 do
				with Items[j] do
				begin
					if TRACK_NODES in Types then
						Result.Add(Self, Context, VectorTransform(AsDoubleAffineVector, m), TRACK_NODES, NullDVector, 0);
					if TRACK_MPOINT in Types then
						Result.Add(Self, Context, VectorTransform(VectorScale(VectorAdd(AsDoubleAffineVector, Items[(j + 1) mod Count].AsDoubleAffineVector), 0.5), m), TRACK_NODES, NullDVector, 0);
					end;
end;

function TMultiPolygonBase.TransformedExtents(const m: TDMatrix;
  ExtentsInfo: PExtentsInfo): TAABB;
begin
	Result:=FContours.TransformedExtents(m, ExtentsInfo);
end;

function TMultiPolygonBase.GetOutlineContours(flags: TGetOutlineFlags): TGLExContours;
var
	i, j: integer;
	v: TDAffineVector;
begin
	Result:=TGLExContours.Create;
	Result.BeginUpdate;
	for i:=0 to FContours.count - 1 do
		with FContours[i], Result.Add do
		begin
			Hole:=FHole;
			for j:=0 to Nodes.Count - 2 do
			begin
				v:=Nodes[j].AsDoubleAffineVector;
				v[2]:=0.0;
				Add(TGLExContourLineSegment).AsVector:=v;
        if Nodes[j].HasMetaData then
          Last.GetMetaStorage.Assign(Nodes[j].GetMetaStorage, true);
			end;
			if (Nodes.Last <> nil) and (not Nodes.Last.EqualTo(Nodes.First)) then
			begin
				v:=Nodes.Last.AsDoubleAffineVector;
				v[2]:=0.0;
				Add(TGLExContourLineSegment).AsVector:=v;
        if Nodes.Last.HasMetaData then
          Last.GetMetaStorage.Assign(Nodes.Last.GetMetaStorage, true);
			end;
		end;
	Result.EndUpdate;
end;

function TGLContour.TransformedExtents(const m: TDMatrix;
  ExtentsInfo: PExtentsInfo): TAABB;
begin
	if FSplineMode = lsmCubicSpline then
		with FNodes.CreateNewCubicSpline do
		begin
			Result:=TransformedExtents(m, ExtentsInfo);
			Free;
		end
	else
		Result:=FNodes.TransformedExtents(m, ExtentsInfo);
end;

function TGLContour.GetNormalVector(x, y: double; Profile: TGLProfile;
  Style: TCornerStyle; var Range: double; Offset: double): TDAffineVector;
var
	R: double;
	Norm, N, N1, N2, Tilt: TDAffineVector;
	Nearest: TDAffineVector;
begin
	R:=DistanceToContour(X, Y, Nearest, Norm, N1, N2)+Offset;
	Range:=R;
	case Style of
		csRound:
		begin
			Tilt:=Profile.GetNormTilt(R);
			Result[0]:=Norm[0] * Tilt[0];
			Result[1]:=Norm[1] * Tilt[0];
			Result[2]:=Tilt[1];
		end;
		csSmooth:
		begin
			if Abs(VectorDotProduct(N1, Norm)) > Abs(VectorDotProduct(N2, Norm)) then	N:=N1
			else N:=N2;
			Tilt:=Profile.GetNormTilt(Abs(VectorDotProduct(N, Norm)) * R);
			Result[0]:=Norm[0] * Tilt[0];
			Result[1]:=Norm[1] * Tilt[0];
			Result[2]:=Tilt[1];
		end;
		csSharp:
		begin
			if Abs(VectorDotProduct(N1, Norm)) > Abs(VectorDotProduct(N2, Norm)) then	N:=N1
			else N:=N2;
			if VectorDotProduct(N, Norm) < 0 then ScaleVector(N, -1);
			Tilt:=Profile.GetNormTilt(Abs(VectorDotProduct(N, Norm)) * R);
			Result[0]:=N[0] * Tilt[0];
			Result[1]:=N[1] * Tilt[0];
			Result[2]:=Tilt[1];
		end;
	end;
end;

function TGLContour.DistanceToContour(x, y: double): double;
var
	i: integer;
	a, p, project, w: TDAffineVector;
	lineDirection: TDAffineVector;
	c1, c2, b, R: Double;
begin
	Result:=1E10;
	p:=DAffineVectorMake(x, y, 0);

	for i:=0 to Nodes.Count - 2 do
		if ((Min(Nodes[i].DoubleX, Nodes[i+1].DoubleX) - x) <= Result) and
				((x - Max(Nodes[i].DoubleX, Nodes[i+1].DoubleX)) <= Result) and
				((Min(Nodes[i].DoubleY, Nodes[i+1].DoubleY) - y) <= Result) and
				((y - Max(Nodes[i].DoubleY, Nodes[i+1].DoubleY)) <= Result) then
		begin
			lineDirection:=VectorSubtract(Nodes[i+1].AsDoubleAffineVector,
				Nodes[i].AsDoubleAffineVector);
			w:=VectorSubtract(p, Nodes[i].AsDoubleAffineVector);

			c1:=VectorDotProduct(w, lineDirection);
			c2:=VectorDotProduct(lineDirection, lineDirection);
			if c2 = 0 then c2 := 1;
			b:=ClampValue(c1 / c2, 0, 1);
			project:=VectorScale(lineDirection, b);
			VectorAdd(Nodes[i].AsDoubleAffineVector, VectorScale(lineDirection, b), a);
			R:=VectorLength(VectorSubtract(p, a));

			if R < Result then
				Result:=R;
		end;

	//if not (PointInPolygon(X, Y) xor FHole) then
	//	Result:=-Result;
end;

function TGLContour.DistanceToContour(x, y: double; var NearestP, Norm,
  Norm1, Norm2: TDAffineVector): double;
var
	i: integer;
	a, p, project, w: TDAffineVector;
	Slope, lineDirection: TDAffineVector;
	c1, c2, b, R: Double;
begin
	Result:=1E10;
	Norm:=NullDVector;
	NearestP:=NullDVector;
	p:=DAffineVectorMake(x, y, 0);

	for i:=0 to Nodes.Count - 2 do
		if ((Min(Nodes[i].DoubleX, Nodes[i+1].DoubleX) - x) <= Result) and
				((x - Max(Nodes[i].DoubleX, Nodes[i+1].DoubleX)) <= Result) and
				((Min(Nodes[i].DoubleY, Nodes[i+1].DoubleY) - y) <= Result) and
				((y - Max(Nodes[i].DoubleY, Nodes[i+1].DoubleY)) <= Result) then
		begin
			lineDirection:=VectorSubtract(Nodes[i+1].AsDoubleAffineVector,
				Nodes[i].AsDoubleAffineVector);
			w:=VectorSubtract(p, Nodes[i].AsDoubleAffineVector);

			c1:=VectorDotProduct(w, lineDirection);
			c2:=VectorDotProduct(lineDirection, lineDirection);
			if c2 = 0 then c2 := 1;
			b:=ClampValue(c1 / c2, 0, 1);
			project:=VectorScale(lineDirection, b);
			VectorAdd(Nodes[i].AsDoubleAffineVector, VectorScale(lineDirection, b), a);
			R:=VectorLength(VectorSubtract(p, a));

			if R < Result then
			begin
				Result:=R;
				NearestP:=a;
				if R <> 0 then Norm:=VectorScale(VectorSubtract(p, a), 1/R);
				Norm1:=Norm;
				Norm2:=Norm;

				if b = 0 then
				begin
					Slope:=VectorNormalize(lineDirection);
					Norm2[0]:=Slope[1];
					Norm2[1]:=-Slope[0];
					Slope:=VectorNormalize(VectorSubtract(Nodes[i].AsDoubleAffineVector,
						Nodes[(i + Nodes.Count - 2) mod Nodes.Count].AsDoubleAffineVector));
					Norm1[0]:=Slope[1];
					Norm1[1]:=-Slope[0];
				end;

				if b = 1 then
				begin
					Slope:=VectorNormalize(lineDirection);
					Norm1[0]:=Slope[1];
					Norm1[1]:=-Slope[0];
					Slope:=VectorNormalize(
						VectorSubtract(Nodes[(i + 2) mod Nodes.Count].AsDoubleAffineVector,
						Nodes[i + 1].AsDoubleAffineVector));
					Norm2[0]:=Slope[1];
					Norm2[1]:=-Slope[0];
				end;
			end;
		end;

	if not (PointInPolygon(X, Y) xor FHole) then
	begin
		Result:=-Result;
		ScaleVector(Norm, -1);
		ScaleVector(Norm1, -1);
		ScaleVector(Norm2, -1);
	end;
end;

function TGLContour.PointInPolygon(x, y: double): boolean;
var
	I, J: Integer;
begin
	Result := False;
	J := FNodes.Count - 1;
	for I := 0 to FNodes.Count - 1 do
	begin
		if ((((FNodes[I].DoubleY <= Y) and (Y < FNodes[J].DoubleY)) or
				 ((FNodes[J].DoubleY <= Y) and (Y < FNodes[I].DoubleY))) and
			(X < (FNodes[J].DoubleX - FNodes[I].DoubleX) * (Y - FNodes[I].DoubleY) /
				(FNodes[J].DoubleY - FNodes[I].DoubleY) + FNodes[I].DoubleX)) then
			Result := not Result;
		J := I;
	end;
end;

procedure TGLContour.EncloseContour;
begin
	if not VectorEquals(
		Nodes.First.AsDoubleAffineVector,
		Nodes.Last.AsDoubleAffineVector, 1e-5) then
    begin
      Nodes.Add.Assign(Nodes.First);
    end;
end;

procedure TGLContour.IntersectRay(const rayPoint,
  rayVector: TDAffineVector; Result: TDAffineVectorList);
begin
	if SplineMode = lsmLines then
		FNodes.IntersectRay(rayPoint, rayVector, true, Result);
end;

procedure TGLMultiPolygon.DoRender(var rci: TRenderContextInfo; renderSelf,
	renderChildren: Boolean);
begin
	if (rci.rendering = rLastPass) then
	begin
		if (rci.drawState = dsSelecting) and rci.Tracking then
		begin
			SetPointerColor(self, rci);
			glPushAttrib(GL_ENABLE_BIT);
			glDisable(GL_DEPTH_TEST);
			glDisable(GL_STENCIL_TEST);
			FContours.DrawPoints(rci);
			glPopAttrib;
		end;
	end
	else
	begin
		inherited;
		if renderSelf and (rci.drawState = dsSelecting) and rci.Tracking and ((not Selected) or (rci.SkipSelected = false)) and (FContours.Count > 0) then
			rci.LastPassRendering.Add(self);
	end;
end;

procedure TGLContour.DrawPoints(var rci: TRenderContextInfo);
begin
	FNodes.DrawPoints(rci);
end;

procedure TGLContour.DeleteShortSegments(e: double);
var
	i: integer;
begin
	i:=0;
	while (i + 1 < Nodes.Count) do
		If VectorDistance(Nodes[i].AsDoubleAffineVector, Nodes[(i + 1) mod Nodes.Count].AsDoubleAffineVector) < e then
			Nodes.Delete(i + 1)
		else
			inc(i);
end;

procedure TGLContour.SetMinSegmentAngle(Angle, MaxSegmentLength: double);
var
	a, b: extended;
	i: integer;
begin
	i:=0;
	if Nodes.Count > 1 then
	begin
		a:=AbsAngle(VectorSubtract(Nodes[(i + 1) mod Nodes.Count].AsDoubleAffineVector, Nodes[i].AsDoubleAffineVector), true);
		while (i + 1 < Nodes.Count) do
		begin
			b:=AbsAngle(VectorSubtract(Nodes[(i + 1) mod Nodes.Count].AsDoubleAffineVector, Nodes[i].AsDoubleAffineVector), true);
			If (VectorDistance(Nodes[i].AsDoubleAffineVector, Nodes[(i + 1) mod Nodes.Count].AsDoubleAffineVector) < MaxSegmentLength) and
				(abs(ToPiAngle(b - a)) < Angle) then
				Nodes.Delete(i + 1)
			else
			begin
				inc(i);
				a:=AbsAngle(VectorSubtract(Nodes[(i + 1) mod Nodes.Count].AsDoubleAffineVector, Nodes[i].AsDoubleAffineVector), true);
			end;
		end;
	end;
end;

function TGLContour.GetAngle(const aNodeIndex: integer): Double;
var
  s1, s2: TDAffineVector;
  aClosed: Boolean;
  i1, i2: integer;
begin
  Result := 0;
  if (Nodes.Count > 1) and (aNodeIndex < Nodes.Count) then
  begin
    aClosed := VectorEquals(Nodes.First.AsDoubleAffineVector, Nodes.Last.AsDoubleAffineVector, 1e-5);
    if aClosed then
    begin
      if (aNodeIndex = 0) then
      begin
        i1 := (aNodeIndex + 1) mod Nodes.Count;
        i2 := (aNodeIndex + Nodes.Count - 2) mod Nodes.Count;
      end
      else
      if (aNodeIndex = Nodes.Count - 1) then
      begin
        i1 := (aNodeIndex + 2) mod Nodes.Count;
        i2 := (aNodeIndex + Nodes.Count - 1) mod Nodes.Count;
      end
      else
      begin
        i1 := (aNodeIndex + 1) mod Nodes.Count;
        i2 := (aNodeIndex + Nodes.Count - 1) mod Nodes.Count;
      end;
    end
    else
    begin
      i1 := (aNodeIndex + 1) mod Nodes.Count;
      i2 := (aNodeIndex + Nodes.Count - 1) mod Nodes.Count;
    end;
    s1 := VectorSubtract(Nodes[i1].AsDoubleAffineVector, Nodes[aNodeIndex].AsDoubleAffineVector);
    s2 := VectorSubtract(Nodes[i2].AsDoubleAffineVector, Nodes[aNodeIndex].AsDoubleAffineVector);
    Result := ArcCos(VectorAngleCosine(s1, s2));
  end;
end;

function TGLContour.PointInContour(const p: TDAffineVector): Boolean;
var
	I, J: integer;
	a, b: PDAffineVector;
begin
	Result:=false;

	J := Nodes.Count - 1;
	for I := 0 to J do
	begin
		a:=PDAffineVector(nodes[I].AsDoubleAddress);
		b:=PDAffineVector(nodes[J].AsDoubleAddress);
		if ((((a[1] <= p[1]) and (p[1] < b[1])) or ((b[1] <= p[1]) and (p[1] < a[1])))
			and (p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0])) then
			Result := not Result;
		J := I;
	end;
end;

function TGLContour.GetBarycenter: TDAffineVector;
var
  min, max: TDAffineVector;
begin
  GetExtents(min, max);
  Result := VectorLerp(min, max, 0.5);
end;

function TGLContour.GetEqualTransformations(const c: TGLContour; const InitialAngle, Tolerance: Double): TTransformationList;

  function GetNode(const c: TGLContour; const i: Integer): TGLNode;
  begin
    if i >= c.Nodes.Count then
      Result := c.Nodes.Items[i - c.Nodes.Count]
    else
      Result := c.Nodes.Items[i];
  end;

  function AreNodesEqual(const c1, c2: TGLContour): Boolean;
  var
    Shift: Integer;
    i: Integer;
  begin
    Result := c1.Nodes.Count = c2.Nodes.Count;
    for Shift := 0 to c1.Nodes.Count - 1 do
    begin
      Result := True;
      for i := 0 to c1.Nodes.Count - 1 do
        if not VectorEquals(c1.Nodes.Items[i].AsDoubleAffineVector, GetNode(c2, Shift + i).AsDoubleAffineVector, Tolerance) then
        begin
          Result := False;
          Break;
        end;
      if Result then
        Break;
    end;
  end;

var
  MyCopy, cCopy, RotatedCopy: TGLContours;
  MyCenter, cCenter: TDAffineVector;
  i: Integer;
  a: Double;
  m1, m2, r: TDMatrix;
begin
  Result := TTransformationList.Create;
  if (Nodes.Count <> c.Nodes.Count) or (Nodes.Count = 0) then
    Exit;

  MyCopy := TGLContours.Create(nil);
  cCopy := TGLContours.Create(nil);
  try
    // —оздадим копии сравниваемых контуров, чтоб не портить оригиналы:
    MyCopy.Add.Assign(Self);
    cCopy.Add.Assign(c);

    // ѕочистим сравниваемые контуры:
    MyCopy.KickEqualPoints(True);
    MyCopy.KickPointsOnOneLine;
    cCopy.KickEqualPoints(True);
    cCopy.KickPointsOnOneLine;

    // ѕеренесем оба контура в соотв. точки ÷“:
    MyCopy.Transform(CreateTranslationMatrixD(VectorNegate(GetBarycenter)));
    if InitialAngle <> 0 then
      MyCopy.Transform(CreateRotationDMatrixZ(InitialAngle));
    m1 := CreateTranslationMatrixD(VectorNegate(c.GetBarycenter));
    cCopy.Transform(m1);
    m2 := CreateTranslationMatrixD(GetBarycenter);
    //MyCopy.ToTextFile('k:\c000.txt');

    for i := 0 to cCopy[0].Nodes.Count - 1 do
    begin
      a := ArcCos(VectorAngleCosine(MyCopy[0].Nodes[0].AsDoubleAffineVector, cCopy[0].Nodes[i].AsDoubleAffineVector));
      if VectorDotProduct(GetRightNormal(MyCopy[0].Nodes[0].AsDoubleAffineVector), cCopy[0].Nodes[i].AsDoubleAffineVector) < 0 then
        a := 2*Pi - a;
      RotatedCopy := TGLContours.Create(nil);
      try
        RotatedCopy.Assign(cCopy);
        r := CreateRotationDMatrixZ(a);
        RotatedCopy.Transform(r);
        //RotatedCopy.ToTextFile('k:\c_rotated' + IntToStr(i) + '.txt');
        if AreNodesEqual(MyCopy[0], RotatedCopy[0]) then
        begin
          Result.Add(MatrixMultiply(MatrixMultiply(m1, r), m2));
        end;
      finally
        RotatedCopy.Free;
      end;
    end;
  finally
    MyCopy.Free;
    cCopy.Free;
  end;
end;


procedure TGLMultiPolygon.DoExecCommand(cmd: cardinal;
	params: TCommandParams);
begin
	case cmd of
		cEnumSceneLights:
			if IsLightSource and (params is TListCommandParams) then
				TListCommandParams(params).List.Add(self);
		cGetClipedContours:
		with TGetClipedContoursParams(params) do
		begin
			ClipWindowObject:=Self;
			SetContours(GetOutlineContours(Flags));
			Done:=True;
			exit;
		end;
	end;
	inherited;
end;

function TMultiPolygonBase.TrySetAbsoluteDoubleUp(
  const up: TDVector): boolean;
var
  newUp, dir: TDAffineVector;
  m, nm: TDMatrix;
begin
  dir := DAffineVectorMake(AbsoluteDoubleDirection);
  newUp := DAffineVectorMake(up);
  newUp := VectorSubtract(newUp, VectorScale(dir, VectorDotProduct(dir, newUp)));
  if VectorLength(newUp) > 1e-4 then
  begin
    NormalizeVector(newUp);
    m := AnglePreservingMatrixInvert(DoubleMatrix);
    AbsoluteDoubleUp := DVectorMake(newUp);
    nm := MatrixMultiply(DoubleMatrix, m);
    Contours.Transform(nm);
    Result := True;
  end
  else
    Result := false;
end;

function TMultiPolygonBase.GetOwnContours: TGLExContours;
begin
  Result := GetOutlineContours([ofDoNotStore]);
end;

function TGLContour.GetMetastorage: TMetaStorage;
begin
  if FMetastorage = nil then
    FMetastorage := TMetaStorage.Create;
  Result := FMetastorage;
end;

function TGLContour.HasMetaStorage: boolean;
begin
  Result := FMetastorage <> nil;
end;

function TGLContour.GetLength: Double;
var
  i: integer;
begin
  Result := 0;
  if (Nodes.Count > 1) then
    for i:=0 to Nodes.Count - 2 do
      Result := Result + VectorDistance(Nodes[i].AsDoubleAffineVector, Nodes[i + 1].AsDoubleAffineVector);
end;

initialization
	//-------------------------------------------------------------
	//-------------------------------------------------------------
	//-------------------------------------------------------------

	RegisterClasses([TGLMultiPolygon]);

end.


