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

unit Spring.Collections.MultiSets;

interface

uses
  Generics.Collections,
  Generics.Defaults,
  Spring,
  Spring.Collections,
  Spring.Collections.Base,
  Spring.Collections.Dictionaries,
  Spring.Collections.Trees;

type
  TAbstractMultiSet<T> = class abstract(TCollectionBase<T>)
  private
    fCount: Integer;
  protected
  {$REGION 'Property Accessors'}
    function GetCount: Integer;
    function GetIsEmpty: Boolean;
  {$ENDREGION}
    function CreateMultiSet: IMultiSet<T>; virtual; abstract;
  public
  {$REGION 'Implements IMultiSet<T>'}
    function OrderedByCount: IReadOnlyMultiSet<T>;
    function SetEquals(const other: IEnumerable<T>): Boolean;
  {$ENDREGION}
  end;

  THashMultiSet<T> = class(TAbstractMultiSet<T>, IEnumerable<T>,
    IReadOnlyCollection<T>, IReadOnlyMultiSet<T>,
    ICollection<T>, IMultiSet<T>)
  private
  {$REGION 'Nested Types'}
    type
      TKeyValuePair = Generics.Collections.TPair<T, Integer>;
      TDictionaryItem = TDictionary<T, Integer>.TDictionaryItem;

      TEnumerator = class(TRefCountedObject, IEnumerator<T>)
      private
        {$IFDEF AUTOREFCOUNT}[Unsafe]{$ENDIF}
        fSource: THashMultiSet<T>;
        fEnumerator: IEnumerator<TKeyValuePair>;
        fRemainingCount: Integer;
        fVersion: Integer;
        function GetCurrent: T;
      public
        constructor Create(const source: THashMultiSet<T>);
        destructor Destroy; override;
        function MoveNext: Boolean;
      end;
  {$ENDREGION}
  private
    fItems: TDictionary<T, Integer>;
    fVersion: Integer;
  {$REGION 'Property Accessors'}
    function GetElements: IReadOnlyCollection<T>;
    function GetEntries: IReadOnlyCollection<TPair<T,Integer>>;
    function GetItem(const item: T): Integer;
    procedure SetItem(const item: T; count: Integer);
  {$ENDREGION}
  protected
    function CreateMultiSet: IMultiSet<T>; override;
  public
    constructor Create; override;
    constructor Create(const comparer: IEqualityComparer<T>); overload;
    destructor Destroy; override;

  {$REGION 'Implements IEnumerable<T>'}
    function GetEnumerator: IEnumerator<T>;
    function Contains(const value: T): Boolean; overload;
    function ToArray: TArray<T>;
  {$ENDREGION}

  {$REGION 'Implements ICollection<T>'}
    function Add(const item: T): Boolean; overload;
    function Remove(const item: T): Boolean; overload;
    procedure Clear;
    function Extract(const item: T): T;
  {$ENDREGION}

  {$REGION 'Implements IMultiSet<T>'}
    function Add(const item: T; count: Integer): Integer; overload;
    function Remove(const item: T; count: Integer): Integer; overload;
  {$ENDREGION}
  end;

  TTreeMultiSet<T> = class(TAbstractMultiSet<T>, IEnumerable<T>,
    IReadOnlyCollection<T>, IReadOnlyMultiSet<T>,
    ICollection<T>, IMultiSet<T>)
  private
  {$REGION 'Nested Types'}
    type
      PNode = TNodes<T, Integer>.PRedBlackTreeNode;

      TEnumerator = class(TRefCountedObject, IEnumerator<T>)
      private
        {$IFDEF AUTOREFCOUNT}[Unsafe]{$ENDIF}
        fSource: TTreeMultiSet<T>;
        fNode: PNode;
        fRemainingCount: Integer;
        fVersion: Integer;
        function GetCurrent: T;
      public
        constructor Create(const source: TTreeMultiSet<T>);
        destructor Destroy; override;
        function MoveNext: Boolean;
      end;

      TKeyCollection = class(TContainedReadOnlyCollection<T>,
        IEnumerable<T>, IReadOnlyCollection<T>)
      private
        {$IFDEF AUTOREFCOUNT}[Unsafe]{$ENDIF}
        fSource: TTreeMultiSet<T>;
      {$REGION 'Property Accessors'}
        function GetCount: Integer;
        function GetIsEmpty: Boolean;
      {$ENDREGION}
      public
        constructor Create(const source: TTreeMultiSet<T>);

      {$REGION 'Implements IEnumerable<TKey>'}
        function GetEnumerator: IEnumerator<T>;
        function Contains(const value: T): Boolean; overload;
        function ToArray: TArray<T>;
      {$ENDREGION}
      end;

      TKeyEnumerator = class(TRefCountedObject, IEnumerator<T>)
      private
        {$IFDEF AUTOREFCOUNT}[Unsafe]{$ENDIF}
        fSource: TTreeMultiSet<T>;
        fCurrentNode: PNode;
        fFinished: Boolean;
        fVersion: Integer;
        function GetCurrent: T;
      public
        constructor Create(const source: TTreeMultiSet<T>);
        destructor Destroy; override;
        function MoveNext: Boolean;
      end;

      TEntryCollection = class(TContainedReadOnlyCollection<TPair<T,Integer>>,
        IEnumerable<TPair<T,Integer>>, IReadOnlyCollection<TPair<T,Integer>>)
      private
        {$IFDEF AUTOREFCOUNT}[Unsafe]{$ENDIF}
        fSource: TTreeMultiSet<T>;
      {$REGION 'Property Accessors'}
        function GetCount: Integer;
        function GetIsEmpty: Boolean;
      {$ENDREGION}
      public
        constructor Create(const source: TTreeMultiSet<T>);

      {$REGION 'Implements IEnumerable<TKey>'}
        function GetEnumerator: IEnumerator<TPair<T,Integer>>;
        function Contains(const value: TPair<T,Integer>): Boolean; overload;
        function ToArray: TArray<TPair<T,Integer>>;
      {$ENDREGION}
      end;

      TEntryEnumerator = class(TRefCountedObject, IEnumerator<TPair<T,Integer>>)
      private
        {$IFDEF AUTOREFCOUNT}[Unsafe]{$ENDIF}
        fSource: TTreeMultiSet<T>;
        fCurrentNode: PNode;
        fFinished: Boolean;
        fVersion: Integer;
        function GetCurrent: TPair<T,Integer>;
      public
        constructor Create(const source: TTreeMultiSet<T>);
        destructor Destroy; override;
        function MoveNext: Boolean;
      end;
  {$ENDREGION}
  private
    fItems: TRedBlackTree<T, Integer>;
    fVersion: Integer;
    fKeys: TKeyCollection;
    fEntries: TEntryCollection;
  {$REGION 'Property Accessors'}
    function GetElements: IReadOnlyCollection<T>;
    function GetEntries: IReadOnlyCollection<TPair<T,Integer>>;
    function GetItem(const item: T): Integer;
    procedure SetItem(const item: T; count: Integer);
  {$ENDREGION}
    function DoMoveNext(var currentNode: PNode; var finished: Boolean;
      iteratorVersion: Integer): Boolean;
  protected
    function CreateMultiSet: IMultiSet<T>; override;
  public
    constructor Create; override;
    constructor Create(const comparer: IComparer<T>); overload;
    destructor Destroy; override;

  {$REGION 'Implements IEnumerable<T>'}
    function GetEnumerator: IEnumerator<T>;
    function Contains(const value: T): Boolean; overload;
    function ToArray: TArray<T>;
  {$ENDREGION}

  {$REGION 'Implements ICollection<T>'}
    function Add(const item: T): Boolean; overload;
    function Remove(const item: T): Boolean; overload;
    function Extract(const item: T): T;
    procedure Clear;
  {$ENDREGION}

  {$REGION 'Implements IMultiSet<T>'}
    function Add(const item: T; count: Integer): Integer; overload;
    function Remove(const item: T; count: Integer): Integer; overload;
  {$ENDREGION}
  end;

implementation

uses
  Spring.Events.Base,
  Spring.ResourceStrings;


{$REGION 'TAbstractMultiSet<T>'}

function TAbstractMultiSet<T>.GetCount: Integer;
begin
  Result := fCount;
end;

function TAbstractMultiSet<T>.GetIsEmpty: Boolean;
begin
  Result := fCount = 0;
end;

function TAbstractMultiSet<T>.OrderedByCount: IReadOnlyMultiSet<T>;
var
  entries: TArray<TPair<T,Integer>>;
  items: TArray<TPair<Integer,TPair<T,Integer>>>;
  i: Integer;
  localSet: IMultiSet<T>;
begin
  entries := IMultiSet<T>(this).Entries.ToArray;
  SetLength(items, Length(entries));
  for i := 0 to High(entries) do
  begin
    items[i].Key := i;
    items[i].Value := entries[i];
  end;
  TArray.Sort<TPair<Integer,TPair<T,Integer>>>(items,
    function(const left, right: TPair<Integer,TPair<T,Integer>>): Integer
    begin
      if left.Value.Value > right.Value.Value then
        Result := -1
      else if left.Value.Value < right.Value.Value then
        Result := 1
      else if left.Key < right.Key then
        Result := -1
      else
        Result := 1;
    end);
  localSet := THashMultiSet<T>.Create;
  for i := 0 to High(items) do
    localSet.Add(items[i].Value.Key, items[i].Value.Value);
  Result := localSet as IReadOnlyMultiSet<T>;
end;

function TAbstractMultiSet<T>.SetEquals(const other: IEnumerable<T>): Boolean;
var
  localSet: IMultiSet<T>;
  entry: TPair<T,Integer>;
begin
{$IFDEF SPRING_ENABLE_GUARD}
  Guard.CheckNotNull(Assigned(other), 'other');
{$ENDIF}

  localSet := CreateMultiSet;
  localSet.AddRange(other);

  if fCount <> localSet.Count then
    Exit(False);
  for entry in localSet.Entries do
    if IMultiSet<T>(this)[entry.Key] <> entry.Value then
      Exit(False);
  Result := True;
end;

{$ENDREGION}


{$REGION 'THashMultiSet<T>'}

constructor THashMultiSet<T>.Create;
begin
  Create(nil);
end;

constructor THashMultiSet<T>.Create(const comparer: IEqualityComparer<T>);
begin
  inherited Create;
  fItems := TContainedDictionary<T,Integer>.Create(Self, comparer, []);
end;

destructor THashMultiSet<T>.Destroy;
begin
  fItems.Free;
  inherited Destroy;
end;

function THashMultiSet<T>.CreateMultiSet: IMultiSet<T>;
begin
  Result := THashMultiSet<T>.Create(fItems.KeyComparer);
end;

function THashMultiSet<T>.Add(const item: T): Boolean;
begin
  Add(item, 1);
  Result := True;
end;

function THashMultiSet<T>.Add(const item: T; count: Integer): Integer;
var
  dictionaryItem: TDictionaryItem;
  i: Integer;
begin
  Guard.CheckTrue(count >= 0, 'count');

  IncUnchecked(fVersion);
  if fItems.FindItem(item, dictionaryItem) then
  begin
    Result := dictionaryItem.Value;
    dictionaryItem.Value := Result + count;
  end
  else
  begin
    Result := 0;
    dictionaryItem.Add(item, count);
  end;
  Inc(fCount, count);

  if Assigned(Notify) then
    for i := 1 to count do
      Notify(Self, item, caAdded);
end;

procedure THashMultiSet<T>.Clear;
var
  pair: TKeyValuePair;
  count: Integer;
begin
  if Assigned(Notify) then
    for pair in fItems do
      for count := pair.Value downto 1 do
        Notify(Self, pair.Key, caRemoved);

  fItems.Clear;
  fCount := 0;
end;

function THashMultiSet<T>.Contains(const value: T): Boolean;
begin
  Result := fItems.ContainsKey(value);
end;

function THashMultiSet<T>.Extract(const item: T): T;
begin
  if Remove(item) then // TODO: possibly change if/when implementing ownership
    Result := item
  else
    Result := Default(T);
end;

function THashMultiSet<T>.GetElements: IReadOnlyCollection<T>;
begin
  Result := fItems.Keys;
end;

function THashMultiSet<T>.GetEntries: IReadOnlyCollection<TPair<T, Integer>>;
begin
  Result := fItems;
end;

function THashMultiSet<T>.GetEnumerator: IEnumerator<T>;
begin
  Result := TEnumerator.Create(Self);
end;

function THashMultiSet<T>.GetItem(const item: T): Integer;
begin
  fItems.TryGetValue(item, Result);
end;

function THashMultiSet<T>.Remove(const item: T): Boolean;
begin
  Result := Remove(item, 1) > 0;
end;

function THashMultiSet<T>.Remove(const item: T; count: Integer): Integer;
var
  dictionaryItem: TDictionaryItem;
  i: Integer;
begin
  Guard.CheckTrue(count >= 0, 'count');

  IncUnchecked(fVersion);
  if fItems.FindItem(item, dictionaryItem) then
  begin
    Result := dictionaryItem.Value;
    if Result <= count then
    begin
      dictionaryItem.Remove;
      count := Result;
    end
    else
      dictionaryItem.Value := Result - count;
    Dec(fCount, count);
    if Assigned(Notify) then
      for i := 1 to count do
        Notify(Self, item, caRemoved);
  end
  else
    Result := 0;
end;

procedure THashMultiSet<T>.SetItem(const item: T; count: Integer);
begin
  if count < 0 then
    raise Error.ArgumentOutOfRange('count');

  if count = 0 then
    fItems.Remove(item)
  else
    fItems[item] := count;
end;

function THashMultiSet<T>.ToArray: TArray<T>;
var
  pair: TKeyValuePair;
  index, count: Integer;
begin
  SetLength(Result, fCount);
  index := 0;
  for pair in fItems do
    for count := 1 to pair.Value do
    begin
      Result[index] := pair.Key;
      Inc(index);
    end;
end;

{$ENDREGION}


{$REGION 'THashMultiSet<T>.TEnumerator'}

constructor THashMultiSet<T>.TEnumerator.Create(const source: THashMultiSet<T>);
begin
  inherited Create;
  fSource := source;
  fSource._AddRef;
  fEnumerator := fSource.fItems.GetEnumerator;
  fRemainingCount := 0;
  fVersion := fSource.fVersion;
end;

destructor THashMultiSet<T>.TEnumerator.Destroy;
begin
  fSource._Release;
  inherited Destroy;
end;

function THashMultiSet<T>.TEnumerator.GetCurrent: T;
begin
  Result := fEnumerator.Current.Key;
end;

function THashMultiSet<T>.TEnumerator.MoveNext: Boolean;
begin
  if fVersion <> fSource.fVersion then
    raise Error.EnumFailedVersion;

  if fRemainingCount = 0 then
  begin
    Result := fEnumerator.MoveNext;
    if Result then
      fRemainingCount := fEnumerator.Current.Value - 1;
  end
  else
  begin
    Dec(fRemainingCount);
    Result := True;
  end;
end;

{$ENDREGION}


{$REGION 'TTreeMultiSet<T>'}

constructor TTreeMultiSet<T>.Create;
begin
  Create(nil);
end;

constructor TTreeMultiSet<T>.Create(const comparer: IComparer<T>);
begin
  inherited Create;
  fItems := TRedBlackTree<T, Integer>.Create(comparer);
  fKeys := TKeyCollection.Create(Self);
  fEntries := TEntryCollection.Create(Self);
end;

destructor TTreeMultiSet<T>.Destroy;
begin
  fEntries.Free;
  fKeys.Free;
  fItems.Free;
  inherited;
end;

function TTreeMultiSet<T>.CreateMultiSet: IMultiSet<T>;
begin
  Result := TTreeMultiSet<T>.Create(fItems.Comparer);
end;

function TTreeMultiSet<T>.DoMoveNext(var currentNode: PNode;
  var finished: Boolean; iteratorVersion: Integer): Boolean;
begin
  if iteratorVersion <> fVersion then
    raise Error.EnumFailedVersion;

  if (fItems.Count = 0) or finished then
    Exit(False);

  if not Assigned(currentNode) then
    currentNode := fItems.Root.LeftMost
  else
    currentNode := currentNode.Next;
  Result := Assigned(currentNode);
  finished := not Result;
end;

function TTreeMultiSet<T>.Add(const item: T): Boolean;
begin
  Add(item, 1);
  Result := True;
end;

function TTreeMultiSet<T>.Add(const item: T; count: Integer): Integer;
var
  node: PNode;
  i: Integer;
begin
  Guard.CheckTrue(count >= 0, 'count');

  IncUnchecked(fVersion);
  node := fItems.FindNode(item);
  if Assigned(node) then
  begin
    Result := node.Value;
    node.Value := Result + count;
  end
  else
  begin
    Result := 0;
    fItems.Add(item, count);
  end;
  Inc(fCount, count);

  if Assigned(Notify) then
    for i := 1 to count do
      Notify(Self, item, caAdded);
end;

procedure TTreeMultiSet<T>.Clear;
var
  node: PNode;
  count: Integer;
begin
  if Assigned(Notify) then
  begin
    node := fItems.Root.LeftMost;
    while Assigned(node) do
    begin
      for count := node.Value downto 1 do
        Notify(Self, node.Key, caRemoved);
      node := node.Next;
    end;
  end;

  fItems.Clear;
  fCount := 0;
end;

function TTreeMultiSet<T>.Contains(const value: T): Boolean;
begin
  Result := Assigned(fItems.FindNode(value));
end;

function TTreeMultiSet<T>.Extract(const item: T): T;
begin
  if Remove(item) then // TODO: possibly change if/when implementing ownership
    Result := item
  else
    Result := Default(T);
end;

function TTreeMultiSet<T>.GetElements: IReadOnlyCollection<T>;
begin
  Result := fKeys;
end;

function TTreeMultiSet<T>.GetEntries: IReadOnlyCollection<TPair<T, Integer>>;
begin
  Result := fEntries;
end;

function TTreeMultiSet<T>.GetEnumerator: IEnumerator<T>;
begin
  Result := TEnumerator.Create(Self);
end;

function TTreeMultiSet<T>.GetItem(const item: T): Integer;
begin
  fItems.Find(item, Result);
end;

function TTreeMultiSet<T>.Remove(const item: T): Boolean;
begin
  Result := Remove(item, 1) > 0;
end;

function TTreeMultiSet<T>.Remove(const item: T; count: Integer): Integer;
var
  node: PNode;
  i: Integer;
begin
  Guard.CheckTrue(count >= 0, 'count');

  IncUnchecked(fVersion);
  node := fItems.FindNode(item);
  if Assigned(node) then
  begin
    Result := node.Value;
    if Result <= count then
    begin
      fItems.DeleteNode(node);
      count := Result;
    end
    else
      node.Value := Result - count;
    Dec(fCount, count);
    if Assigned(Notify) then
      for i := 1 to count do
        Notify(Self, item, caRemoved);
  end
  else
    Result := 0;
end;

procedure TTreeMultiSet<T>.SetItem(const item: T; count: Integer);
begin
  if count < 0 then
    raise Error.ArgumentOutOfRange('count');

  if count = 0 then
    fItems.Delete(item)
  else
    fItems.AddOrSet(item, count);
end;

function TTreeMultiSet<T>.ToArray: TArray<T>;
var
  node: PNode;
  index, count: Integer;
begin
  SetLength(Result, fCount);
  index := 0;
  node := fItems.Root.LeftMost;
  while Assigned(node) do
  begin
    for count := 1 to node.Value do
    begin
      Result[index] := node.Key;
      Inc(index);
    end;
    node := node.Next;
  end;
end;

{$ENDREGION}


{$REGION 'TTreeMultiSet<T>.TEnumerator'}

constructor TTreeMultiSet<T>.TEnumerator.Create(
  const source: TTreeMultiSet<T>);
begin
  inherited Create;
  fSource := source;
  fSource._AddRef;
  fRemainingCount := 0;
  fVersion := fSource.fVersion;
end;

destructor TTreeMultiSet<T>.TEnumerator.Destroy;
begin
  fSource._Release;
  inherited;
end;

function TTreeMultiSet<T>.TEnumerator.GetCurrent: T;
begin
  Result := fNode.Key;
end;

function TTreeMultiSet<T>.TEnumerator.MoveNext: Boolean;
var
  node: PNode;
begin
  if fVersion <> fSource.fVersion then
    raise Error.EnumFailedVersion;

  if fRemainingCount = 0 then
  begin
    if not Assigned(fNode) then
      node := fSource.fItems.Root.LeftMost
    else
      node := fNode.Next;

    Result := Assigned(node);
    if Result then
    begin
      fNode := node;
      fRemainingCount := node.Value - 1;
    end;
  end
  else
  begin
    Dec(fRemainingCount);
    Result := True;
  end;
end;

{$ENDREGION}


{$REGION 'TTreeMultiSet<T>.TKeyCollection'}

constructor TTreeMultiSet<T>.TKeyCollection.Create(
  const source: TTreeMultiSet<T>);
begin
  inherited Create(source);
  fSource := source;
end;

function TTreeMultiSet<T>.TKeyCollection.Contains(const value: T): Boolean;
begin
  Result := fSource.fItems.Exists(value);
end;

function TTreeMultiSet<T>.TKeyCollection.GetCount: Integer;
begin
  Result := fSource.fItems.Count;
end;

function TTreeMultiSet<T>.TKeyCollection.GetEnumerator: IEnumerator<T>;
begin
  Result := TKeyEnumerator.Create(fSource);
end;

function TTreeMultiSet<T>.TKeyCollection.GetIsEmpty: Boolean;
begin
  Result := fSource.fItems.Count = 0;
end;

function TTreeMultiSet<T>.TKeyCollection.ToArray: TArray<T>;
var
  i: Integer;
  node: PNode;
begin
  SetLength(Result, fSource.fItems.Count);
  i := 0;
  node := fSource.fItems.Root.LeftMost;
  while Assigned(node) do
  begin
    Result[i] := node.Key;
    node := node.Next;
    Inc(i);
  end;
end;

{$ENDREGION}


{$REGION 'TTreeMultiSet<T>.TKeyEnumerator'}

constructor TTreeMultiSet<T>.TKeyEnumerator.Create(
  const source: TTreeMultiSet<T>);
begin
  inherited Create;
  fSource := source;
  fSource._AddRef;
  fVersion := fSource.fVersion;
end;

destructor TTreeMultiSet<T>.TKeyEnumerator.Destroy;
begin
  fSource._Release;
  inherited;
end;

function TTreeMultiSet<T>.TKeyEnumerator.GetCurrent: T;
begin
  Result := fCurrentNode.Key;
end;

function TTreeMultiSet<T>.TKeyEnumerator.MoveNext: Boolean;
begin
  Result := fSource.DoMoveNext(fCurrentNode, fFinished, fVersion);
end;

{$ENDREGION}


{$REGION 'TTreeMultiSet<T>.TEntryCollection'}

constructor TTreeMultiSet<T>.TEntryCollection.Create(
  const source: TTreeMultiSet<T>);
begin
  inherited Create(source);
  fSource := source;
end;

function TTreeMultiSet<T>.TEntryCollection.Contains(
  const value: TPair<T, Integer>): Boolean;
var
  foundValue: Integer;
begin
  Result := fSource.fItems.Find(value.Key, foundValue)
    and (value.Value = foundValue);
end;

function TTreeMultiSet<T>.TEntryCollection.GetCount: Integer;
begin
  Result := fSource.fItems.Count;
end;

function TTreeMultiSet<T>.TEntryCollection.GetEnumerator: IEnumerator<TPair<T, Integer>>;
begin
  Result := TEntryEnumerator.Create(fSource);
end;

function TTreeMultiSet<T>.TEntryCollection.GetIsEmpty: Boolean;
begin
  Result := fSource.fItems.Count = 0;
end;

function TTreeMultiSet<T>.TEntryCollection.ToArray: TArray<TPair<T, Integer>>;
begin
  Result := fSource.fItems.ToArray;
end;

{$ENDREGION}


{$REGION 'TTreeMultiSet<T>.TEntryEnumerator'}

constructor TTreeMultiSet<T>.TEntryEnumerator.Create(
  const source: TTreeMultiSet<T>);
begin
  inherited Create;
  fSource := source;
  fSource._AddRef;
  fVersion := fSource.fVersion;
end;

destructor TTreeMultiSet<T>.TEntryEnumerator.Destroy;
begin
  fSource._Release;
  inherited;
end;

function TTreeMultiSet<T>.TEntryEnumerator.GetCurrent: TPair<T, Integer>;
begin
  Result.Key := fCurrentNode.Key;
  Result.Value := fCurrentNode.Value;
end;

function TTreeMultiSet<T>.TEntryEnumerator.MoveNext: Boolean;
begin
  Result := fSource.DoMoveNext(fCurrentNode, fFinished, fVersion);
end;

{$ENDREGION}


end.
