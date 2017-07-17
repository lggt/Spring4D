{***************************************************************************}
{                                                                           }
{           Spring Framework for Delphi                                     }
{                                                                           }
{           Copyright (c) 2009-2018 Spring4D Team                           }
{                                                                           }
{           http://www.spring4d.org                                         }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

{$I Spring.inc}

unit Spring.Container.Resolvers;

interface

uses
  Rtti,
  SysUtils,
  Spring,
  Spring.Collections,
  Spring.Container.Core;

type
  TResolverBase = class abstract(TInterfacedObject, IResolver)
  private
    fKernel: IKernel;
  protected
    property Kernel: IKernel read fKernel;
  public
    constructor Create(const kernel: IKernel);

    function CanResolve(const request: IRequest): Boolean; virtual;
    function Resolve(const request: IRequest): TValue; virtual; abstract;
  end;

  TDependencyResolver = class(TInterfacedObject, IDependencyResolver)
  private
    fKernel: IKernel;
    fResolvers: IList<IResolver>;
    property Kernel: IKernel read fKernel;
  protected
    function CanResolveFromArgument(const request: IRequest): Boolean; // TODO can be moved to IRequest
    function CanResolveFromContext(const request: IRequest): Boolean;
    function CanResolveFromResolvers(const request: IRequest): Boolean;
    function InternalResolveValue(const model: TComponentModel;
      serviceType: PTypeInfo; const instance: TValue): TValue;
  public
    constructor Create(const kernel: IKernel);

    function CanResolve(const request: IRequest): Boolean; overload;
    function CanResolve(const context: IContext;
      const targets: TArray<ITarget>;
      const arguments: TArray<TValue>): Boolean; overload;

    function Resolve(const request: IRequest): TValue; overload;
    function Resolve(const context: IContext;
      const targets: TArray<ITarget>;
      const arguments: TArray<TValue>): TArray<TValue>; overload;

    procedure AddResolver(const resolver: IResolver);
    procedure RemoveResolver(const resolver: IResolver);
  end;

  TLazyResolver = class(TResolverBase)
  private
    function InternalResolveClass(const request: IRequest;
      lazyKind: TLazyKind): TValue;
    function InternalResolveInterface(const request: IRequest;
      lazyKind: TLazyKind): TValue;
  public
    function CanResolve(const request: IRequest): Boolean; override;
    function Resolve(const request: IRequest): TValue; override;
  end;

  TDynamicArrayResolver = class(TResolverBase)
  public
    function CanResolve(const request: IRequest): Boolean; override;
    function Resolve(const request: IRequest): TValue; override;
  end;

  TListResolver = class(TResolverBase)
  public
    function CanResolve(const request: IRequest): Boolean; override;
    function Resolve(const request: IRequest): TValue; override;
  end;

  TComponentOwnerResolver = class(TResolverBase)
  private
    fVirtualIndex: SmallInt;
  public
    constructor Create(const kernel: IKernel);

    function CanResolve(const request: IRequest): Boolean; override;
    function Resolve(const request: IRequest): TValue; override;
  end;

  TDecoratorResolver = class(TInterfacedObject, IDecoratorResolver)
  private
    type
      TDecoratorEntry = record
        DecoratorModel: TComponentModel;
        Condition: Predicate<TComponentModel>;
      end;
  private
    fDecorators: IMultiMap<PTypeInfo, TDecoratorEntry>;
    function GetDecorators(decoratedType: PTypeInfo;
      const decoratedModel: TComponentModel): IEnumerable<TComponentModel>;
  public
    constructor Create;

    procedure AddDecorator(decoratedType: PTypeInfo;
      const decoratorModel: TComponentModel;
      const condition: Predicate<TComponentModel>);
    function Resolve(const request: IRequest;
      const model: TComponentModel; const decoratee: TValue): TValue;
  end;

implementation

uses
  Classes,
  StrUtils,
  TypInfo,
  Spring.Collections.Lists,
  Spring.Container.Context,
  Spring.Container.ResourceStrings,
  Spring.Reflection;


{$REGION 'TResolverBase'}

constructor TResolverBase.Create(const kernel: IKernel);
begin
{$IFNDEF DISABLE_GUARD}
  Guard.CheckNotNull(kernel, 'kernel');
{$ENDIF}

  inherited Create;
  fKernel := kernel;
end;

function TResolverBase.CanResolve(const request: IRequest): Boolean;
var
  parameter: TValue;
begin
  parameter := request.Parameter;
  if not parameter.IsEmpty and parameter.IsString then
    Result := not Kernel.Registry.HasService(request.Service, parameter.AsString)
      and (request.Service <> parameter.TypeInfo)
  else
    Result := not Kernel.Registry.HasService(request.Service)
      and (request.Service <> parameter.TypeInfo);
end;

{$ENDREGION}


{$REGION 'TDependencyResolver'}

constructor TDependencyResolver.Create(const kernel: IKernel);
begin
  inherited Create;
  fKernel := kernel;
  fResolvers := TCollections.CreateInterfaceList<IResolver>;
end;

procedure TDependencyResolver.AddResolver(
  const resolver: IResolver);
begin
  fResolvers.Add(resolver);
end;

procedure TDependencyResolver.RemoveResolver(
  const resolver: IResolver);
begin
  fResolvers.Remove(resolver);
end;

function TDependencyResolver.InternalResolveValue(const model: TComponentModel;
  serviceType: PTypeInfo; const instance: TValue): TValue;
var
  intf: Pointer;
begin
{$IFDEF SPRING_ENABLE_GUARD}
  Guard.CheckNotNull(serviceType, 'serviceType');
  Guard.CheckNotNull(not instance.IsEmpty, 'instance');
{$ENDIF}

  if serviceType.Kind = tkInterface then
  begin
    if instance.IsObject then
      instance.AsObject.GetInterface(serviceType.TypeData.Guid, intf)
    else
    begin
      if TType.IsDelegate(serviceType) then
      begin
        intf := nil;
        IInterface(intf) := instance.AsInterface;
      end
      else
        instance.AsInterface.QueryInterface(serviceType.TypeData.Guid, intf);
    end;
    TValue.MakeWithoutCopy(@intf, serviceType, Result);
    Result := Kernel.ProxyFactory.CreateInstance(Result, model, []);
  end
  else
    Result := instance;
end;

function TDependencyResolver.CanResolve(const request: IRequest): Boolean;
var
  argument: TValue;
  kind: TTypeKind;
  serviceName: string;
  serviceType: PTypeInfo;
  componentModel: TComponentModel;
begin
  if Assigned(request.Target) and (request.Target.TargetType = nil) then
    Exit(True);

  if CanResolveFromContext(request) then
    Exit(True);

  if CanResolveFromResolvers(request) then
    Exit(True);

  argument := request.Parameter;
  if argument.IsEmpty then
    Result := Kernel.Registry.HasService(request.Service)
  else if CanResolveFromArgument(request) then
    Result := True
  else if argument.TryAsType<TTypeKind>(Kind) and (kind = tkDynArray) then
    Result := Kernel.Registry.HasService(request.Service)
  else
  begin
    Result := argument.IsString;
    if Result then
    begin
      serviceName := argument.AsString;
      componentModel := Kernel.Registry.FindOne(serviceName);
      Result := Assigned(componentModel);
      if Result then
      begin
        serviceType := componentModel.Services[serviceName];
        Result := IsAssignableFrom(request.Service, serviceType);
      end;
    end;
  end;
end;

function TDependencyResolver.Resolve(const request: IRequest): TValue;
var
  i: Integer;
  componentModel: TComponentModel;
  instance: TValue;
begin
  if Assigned(request.Target) and (request.Target.TargetType = nil) then
    Exit(TValue.Empty);

  if CanResolveFromContext(request) then
    Exit(request.Context.Resolve(request));

  for i := fResolvers.Count - 1 downto 0 do
    if fResolvers[i].CanResolve(request) then
      Exit(fResolvers[i].Resolve(request));

  if CanResolveFromArgument(request) then
    Exit(request.Parameter);

  componentModel := Kernel.Registry.FindOne(request.Service, request.Parameter);

  if request.Context.EnterResolution(componentModel, instance) then
  try
    instance := componentModel.LifetimeManager.Resolve(request.Context, componentModel);
  finally
    request.Context.LeaveResolution(componentModel);
  end;
  Result := InternalResolveValue(componentModel, request.Service, instance);

  Result := Kernel.DecoratorResolver.Resolve(request, componentModel, Result);
end;

function TDependencyResolver.CanResolve(const context: IContext;
  const targets: TArray<ITarget>; const arguments: TArray<TValue>): Boolean;
var
  i: Integer;
  request: IRequest;
begin
  if Length(targets) = Length(arguments) then
  begin
    for i := Low(targets) to High(targets) do
    begin
      request := TRequest.Create(targets[i].TargetType, context, targets[i], arguments[i]);
      if not CanResolve(request) then
        Exit(False);
    end;
  end
  else if Length(arguments) = 0 then
  begin
    for i := Low(targets) to High(targets) do
    begin
      request := TRequest.Create(targets[i].TargetType, context, targets[i], nil);
      if not CanResolve(request) then
        Exit(False);
    end;
  end
  else
    Exit(False);
  Result := True;
end;

function TDependencyResolver.CanResolveFromArgument(
  const request: IRequest): Boolean;
var
  argument: TValue;
begin
  argument := request.Parameter;
  Result := Assigned(argument.TypeInfo) and argument.IsType(request.Service);
  if not Result and (argument.Kind in [tkInteger, tkFloat, tkInt64]) then
    Result := argument.Kind = request.Service.Kind;
  if Result and argument.IsString then
    Result := not Kernel.Registry.HasService(request.Service, argument.AsString);
end;

function TDependencyResolver.CanResolveFromContext(
  const request: IRequest): Boolean;
begin
  Result := Assigned(request.Context) and request.Context.CanResolve(request);
end;

function TDependencyResolver.CanResolveFromResolvers(
  const request: IRequest): Boolean;
var
  i: Integer;
begin
  for i := fResolvers.Count - 1 downto 0 do
    if fResolvers[i].CanResolve(request) then
      Exit(True);
  Result := False;
end;

function TDependencyResolver.Resolve(const context: IContext;
  const targets: TArray<ITarget>; const arguments: TArray<TValue>): TArray<TValue>;
var
  hasArgument: Boolean;
  i: Integer;
  request: IRequest;
begin
  hasArgument := Length(arguments) > 0;
  if hasArgument and (Length(arguments) <> Length(targets)) then
    raise EResolveException.CreateRes(@SUnsatisfiedResolutionArgumentCount);
  SetLength(Result, Length(targets));
  if hasArgument then
    for i := Low(targets) to High(targets) do
    begin
      request := TRequest.Create(targets[i].TargetType, context, targets[i], arguments[i]);
      Result[i] := Resolve(request);
    end
  else
    for i := Low(targets) to High(targets) do
    begin
      request := TRequest.Create(targets[i].TargetType, context, targets[i], nil);
      Result[i] := Resolve(request);
    end;
end;

{$ENDREGION}


{$REGION 'TLazyResolver'}

function TLazyResolver.CanResolve(const request: IRequest): Boolean;
var
  serviceType: PTypeInfo;
  newRequest: IRequest;
begin
  Result := inherited CanResolve(request) and IsLazyType(request.Service);
  if Result then
  begin
    serviceType := GetLazyType(request.Service);
    newRequest := TRequest.Create(serviceType, request.Context, request.Target, request.Parameter);
    Result := Kernel.Resolver.CanResolve(newRequest);
  end;
end;

function TLazyResolver.InternalResolveClass(const request: IRequest;
  lazyKind: TLazyKind): TValue;
var
  factory: Func<TObject>;
begin
  factory :=
    function: TObject
    begin
      Result := Kernel.Resolver.Resolve(request).AsObject;
    end;

  case lazyKind of
    lkFunc: Result := TValue.From<Func<TObject>>(factory);
    lkRecord: Result := TValue.From<Lazy<TObject>>(Lazy<TObject>.Create(factory));
    lkInterface: Result := TValue.From<ILazy<TObject>>(TLazy<TObject>.Create(factory));
  end;
end;

function TLazyResolver.InternalResolveInterface(const request: IRequest;
  lazyKind: TLazyKind): TValue;
var
  factory: Func<IInterface>;
begin
  factory :=
    function: IInterface
    begin
      Result := Kernel.Resolver.Resolve(request).AsInterface;
    end;

  case lazyKind of
    lkFunc: Result := TValue.From<Func<IInterface>>(factory);
    lkRecord: Result := TValue.From<Lazy<IInterface>>(Lazy<IInterface>.Create(factory));
    lkInterface: Result := TValue.From<ILazy<IInterface>>(TLazy<IInterface>.Create(factory));
  end;
end;

function TLazyResolver.Resolve(const request: IRequest): TValue;
var
  lazyKind: TLazyKind;
  serviceType: PTypeInfo;
  componentModel: TComponentModel;
  newRequest: IRequest;
  hasEntered: Boolean;
begin
  if not IsLazyType(request.Service) then
    raise EResolveException.CreateResFmt(@SCannotResolveType, [request.Service.TypeName]);

  lazyKind := GetLazyKind(request.Service);
  serviceType := GetLazyType(request.Service);
  if Kernel.Registry.HasService(serviceType) then
  begin
    componentModel := Kernel.Registry.FindOne(serviceType, request.Parameter);
    hasEntered := request.Context.EnterResolution(componentModel, Result);
  end
  else
  begin
    componentModel := nil;
    hasEntered := False;
  end;
  try
    newRequest := TRequest.Create(serviceType, request.Context, request.Target, request.Parameter);
    case serviceType.Kind of
      tkClass: Result := InternalResolveClass(newRequest, lazyKind);
      tkInterface: Result := InternalResolveInterface(newRequest, lazyKind);
    else
      raise EResolveException.CreateResFmt(@SCannotResolveType, [request.Service.TypeName]);
    end;
    TValueData(Result).FTypeInfo := request.Service;
  finally
    if hasEntered then
      request.Context.LeaveResolution(componentModel);
  end;
end;

{$ENDREGION}


{$REGION 'TDynamicArrayResolver'}

function TDynamicArrayResolver.CanResolve(const request: IRequest): Boolean;
var
  serviceType: PTypeInfo;
  newRequest: IRequest;
begin
  Result := inherited CanResolve(request) and (request.Service.Kind = tkDynArray);
  if Result then
  begin
    serviceType := request.Service.TypeData.DynArrElType^;
    newRequest := TRequest.Create(serviceType, request.Context, request.Target, TValue.From(tkDynArray));
    Result := Kernel.Resolver.CanResolve(newRequest);
  end;
end;

function TDynamicArrayResolver.Resolve(const request: IRequest): TValue;
var
  serviceType: PTypeInfo;
  lookupType: PTypeInfo;
  models: TArray<TComponentModel>;
  values: TArray<TValue>;
  i: Integer;
  serviceName: string;
  newRequest: IRequest;
begin
  if request.Service.Kind <> tkDynArray then
    raise EResolveException.CreateResFmt(@SCannotResolveType, [request.Service.TypeName]);
  serviceType := request.Service.TypeData.DynArrElType^;

  // TODO: remove dependency on lazy type
  if IsLazyType(serviceType) then
    lookupType := GetLazyType(serviceType)
  else
    lookupType := serviceType;
  models := Kernel.Registry.FindAll(lookupType).ToArray;

  SetLength(values, Length(models));
  for i := Low(models) to High(models) do
  begin
    serviceName := models[i].GetServiceName(lookupType);
    newRequest := TRequest.Create(serviceType, request.Context, request.Target, serviceName);
    values[i] := Kernel.Resolver.Resolve(newRequest);
  end;
  Result := TValue.FromArray(request.Service, values);
end;

{$ENDREGION}


{$REGION 'TListResolver'}

function TListResolver.CanResolve(const request: IRequest): Boolean;
const
  SupportedTypes: array[0..3] of string = (
    'IList<>', 'IReadOnlyList<>', 'ICollection<>', 'IEnumerable<>');
var
  targetType: TRttiType;
  method: TRttiMethod;
  newRequest: IRequest;
begin
  targetType := request.Service.RttiType;
  Result := inherited CanResolve(request) and targetType.IsGenericType
    and MatchText(targetType.GetGenericTypeDefinition, SupportedTypes)
    and targetType.TryGetMethod('ToArray', method);
  if Result then
  begin
    targetType := method.ReturnType.AsDynamicArray.ElementType;
    if not targetType.IsClassOrInterface then
      Exit(False);
    newRequest := TRequest.Create(targetType.Handle, request.Context, request.Target, TValue.From(tkDynArray));
    Result := Kernel.Resolver.CanResolve(newRequest);
  end;
end;

function TListResolver.Resolve(const request: IRequest): TValue;
var
  targetType: TRttiType;
  itemType: TRttiType;
  arrayType: TRttiType;
  newRequest: IRequest;
  values: TValue;
begin
  targetType := request.Service.RttiType;
  arrayType := targetType.GetMethod('ToArray').ReturnType;
  itemType := arrayType.AsDynamicArray.ElementType;
  newRequest := TRequest.Create(arrayType.Handle, request.Context, request.Target, request.Parameter);
  values := Kernel.Resolver.Resolve(newRequest);
  case itemType.TypeKind of
    tkClass:
    begin
      TValueData(values).FTypeInfo := TypeInfo(TArray<TObject>);
      Result := TValue.From(TList<TObject>.Create(
        values.AsType<TArray<TObject>>()));
    end;
    tkInterface:
    begin
      TValueData(values).FTypeInfo := TypeInfo(TArray<IInterface>);
      Result := TValue.From(TList<IInterface>.Create(
        values.AsType<TArray<IInterface>>()));
    end;
  else
    raise EResolveException.CreateResFmt(@SCannotResolveType, [request.Service.TypeName]);
  end;
  Result := Result.Cast(request.Service);
end;

{$ENDREGION}


{$REGION 'TComponentOwnerResolver'}

constructor TComponentOwnerResolver.Create(const kernel: IKernel);
begin
  inherited Create(kernel);
  fVirtualIndex := TType.GetType(TComponent).Constructors.First.VirtualIndex;
end;

function TComponentOwnerResolver.CanResolve(const request: IRequest): Boolean;
var
  target: ITarget;
  argument: TValue;
  method: TRttiMethod;
begin
  target := request.Target;
  if target = nil then
    Exit(False);
  argument := request.Parameter;
  if target.TargetType <> TypeInfo(TComponent) then
    Exit(False);
  if Kernel.Registry.HasService(TypeInfo(TComponent)) then
    Exit(False);
  if not argument.IsEmpty then
    Exit(False);
  if not (target.Target is TRttiParameter) then
    Exit(False);

  method := TRttiMethod(target.Target.Parent);
  Result := (method.VirtualIndex = fVirtualIndex)
    and (method.Parent.AsInstance.MetaclassType.InheritsFrom(TComponent));
end;

function TComponentOwnerResolver.Resolve(const request: IRequest): TValue;
begin
  TValue.Make(nil, TComponent.ClassInfo, Result);
end;

{$ENDREGION}


{$REGION 'TDecoratorResolver'}

constructor TDecoratorResolver.Create;
begin
  inherited Create;
  fDecorators := TCollections.CreateMultiMap<PTypeInfo, TDecoratorEntry>;
end;

procedure TDecoratorResolver.AddDecorator(decoratedType: PTypeInfo;
  const decoratorModel: TComponentModel;
  const condition: Predicate<TComponentModel>);
var
  entry: TDecoratorEntry;
begin
  entry.DecoratorModel := decoratorModel;
  entry.Condition := condition;
  fDecorators.Add(decoratedType, entry);
end;

function TDecoratorResolver.GetDecorators(decoratedType: PTypeInfo;
  const decoratedModel: TComponentModel): IEnumerable<TComponentModel>;
begin
  Result := TEnumerable.Select<TDecoratorEntry,TComponentModel>(
    fDecorators[decoratedType].Where(
      function(const entry: TDecoratorEntry): Boolean
      begin
        Result := not Assigned(entry.Condition) or entry.Condition(decoratedModel);
      end),
    function(const entry: TDecoratorEntry): TComponentModel
    begin
      Result := entry.DecoratorModel;
    end);
end;

function TDecoratorResolver.Resolve(const request: IRequest;
  const model: TComponentModel; const decoratee: TValue): TValue;
var
  decoratorModel: TComponentModel;
  index: Integer;
begin
  Result := decoratee;
  for decoratorModel in GetDecorators(request.Service, model) do
  begin
    // TODO: make this more explicit to just inject on the decorator constructor
    index := request.Context.AddArgument(TTypedValue.Create(Result, request.Service));
    try
      Result := decoratorModel.LifetimeManager.Resolve(request.Context, decoratorModel).Cast(request.Service);
    finally
      request.Context.RemoveTypedArgument(index);
    end;
  end;
end;

{$ENDREGION}


end.
