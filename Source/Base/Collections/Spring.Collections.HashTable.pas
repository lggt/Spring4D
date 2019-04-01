{***************************************************************************}
{                                                                           }
{           Spring Framework for Delphi                                     }
{                                                                           }
{           Copyright (c) 2009-2019 Spring4D Team                           }
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
{$RANGECHECKS OFF}
{$OVERFLOWCHECKS OFF}
{$ASSERTIONS OFF}

unit Spring.Collections.HashTable;

interface

uses
  TypInfo;

type
  TKeyComparer = function(const left, right: Pointer): Boolean of object;

  THashTableEntry = record
    hashCode: Integer;
    bucketIndex: Integer;
    itemIndex: Integer;
  end;

  THashTable = record
  private
    function GetHashCode(index: Integer): Integer;
    function GetItem(index: Integer): Pointer;
    function GetKey(index: Integer): Pointer; inline;
    function GetCapacity: Integer;
    procedure SetCapacity(const Value: Integer);

    const KeyOffset = SizeOf(Integer);
  public
    Buckets: TArray<Integer>;
    Items: Pointer; // TArray<TItem>;
    Count: Integer;
    ItemCount: Integer;
    BucketIndexMask: Integer;
    BucketHashCodeMask: Integer;
    KeyComparer: TKeyComparer;

    ItemsInfo: PTypeInfo; // TypeInfo(TArray<TItem>)
    ItemSize: Integer;    // SizeOf(TItem)

    Version: Integer;

    procedure EnsureCompact;
    procedure Grow;
    procedure Pack;
    function Find(key: Pointer; var entry: THashTableEntry): Boolean;
    procedure Rehash(newCapacity: NativeInt);

    property Capacity: Integer read GetCapacity write SetCapacity;
  end;

implementation

uses
  Math,
  Spring;

const
  // use the MSB of the HashCode to note removed items
  RemovedFlag        = Integer($80000000);
  MinCapacity        = 6; // 75% load factor leads to min bucket count of 8
  BucketSentinelFlag = RemovedFlag; // note: the same as RemovedFlag
  EmptyBucket        = -1; // must be negative, note choice of BucketSentinelFlag
  UsedBucket         = -2; // likewise


{$REGION 'THashTable'}

function THashTable.GetCapacity: Integer;
begin
  Result := DynArrayLength(Items);
end;

function THashTable.GetHashCode(index: Integer): Integer;
begin
  Result := PInteger(PByte(Items) + index * ItemSize)^;
end;

function THashTable.GetItem(index: Integer): Pointer;
begin
  Result := PByte(Items) + index * ItemSize;
end;

function THashTable.GetKey(index: Integer): Pointer;
begin
  Result := PByte(Items) + index * ItemSize + KeyOffset;
end;

procedure THashTable.EnsureCompact;
begin
  if Count <> ItemCount then
    Rehash(Capacity);
end;

procedure THashTable.Grow;
var
  newCapacity: Integer;
begin
  newCapacity := Capacity;
  if newCapacity = 0 then
    newCapacity := MinCapacity
  else if 2 * Count >= DynArrayLength(Buckets) then
    // only grow if load factor is greater than 0.5
    newCapacity := newCapacity * 2;
  Rehash(newCapacity);
end;

procedure THashTable.Pack;
var
  sourceItemIndex, targetItemIndex: Integer;
begin
  targetItemIndex := 0;
  for sourceItemIndex := 0 to ItemCount - 1 do
    if GetHashCode(sourceItemIndex) >= 0 then
    begin
      if targetItemIndex < sourceItemIndex then
        CopyRecord(GetItem(targetItemIndex), GetItem(sourceItemIndex), ItemsInfo.TypeData.elType2^);
      Inc(targetItemIndex);
    end;
  FinalizeArray(GetItem(targetItemIndex), ItemsInfo.TypeData.elType2^, ItemCount - Count);
end;

function THashTable.Find(key: Pointer; var entry: THashTableEntry): Boolean;
var
  bucketIndex, bucketValue, itemIndex: Integer;
begin
  if Items <> nil then
  begin
    bucketIndex := entry.hashCode and BucketIndexMask;
    while True do
    begin
      bucketValue := Buckets[bucketIndex];

      if bucketValue = EmptyBucket then
      begin
        entry.bucketIndex := bucketIndex;
        entry.itemIndex := ItemCount;
        Exit(False);
      end;

      if (bucketValue <> UsedBucket)
        and (bucketValue and BucketHashCodeMask = entry.hashCode and BucketHashCodeMask) then
      begin
        itemIndex := bucketValue and BucketIndexMask;
        if KeyComparer(GetKey(itemIndex), key) then
        begin
          entry.bucketIndex := bucketIndex;
          entry.itemIndex := itemIndex;
          Exit(True);
        end;
      end;

      bucketIndex := (bucketIndex + 1) and BucketIndexMask;
    end;
  end
  else
  begin
//    entry.bucketIndex := EmptyBucket;
//    entry.itemIndex := -1;
    Result := False;
  end;
end;

procedure THashTable.Rehash(newCapacity: NativeInt);
var
  newBucketCount, i, hashCode: Integer;
  entry: THashTableEntry;
  item: PByte;
begin
  if newCapacity = 0 then
  begin
    Assert(Count = 0);
    Assert(ItemCount = 0);
    Assert(not Assigned(Buckets));
    Assert(not Assigned(Items));
    Exit;
  end;

  Assert(newCapacity >= Count);

  {$IFOPT Q+}{$DEFINE OVERFLOWCHECKS_OFF}{$Q-}{$ENDIF}
  Inc(Version);
  {$IFDEF OVERFLOWCHECKS_OFF}{$UNDEF OVERFLOWCHECKS_OFF}{$Q+}{$ENDIF}

  newBucketCount := NextPowerOf2(newCapacity * 4 div 3 - 1); // 75% load factor

  // compact the items array, if necessary
  if ItemCount > Count then
    Pack;

  // resize the items array, safe now that we have compacted it
  newCapacity := newBucketCount * 3 div 4;
  DynArraySetLength(Items, ItemsInfo, 1, @newCapacity);
  Assert(Capacity >= Count);

  // repopulate the bucket array
  BucketIndexMask := newBucketCount - 1;
  BucketHashCodeMask := not BucketIndexMask and not BucketSentinelFlag;
  SetLength(Buckets, newBucketCount);
  for i := 0 to newBucketCount - 1 do
    Buckets[i] := EmptyBucket;

  item := Items;
  for i := 0 to Count - 1 do
  begin
    hashCode := PInteger(item)^;
    entry.hashCode := hashCode;
    Find(item + KeyOffset, entry);
    Buckets[entry.bucketIndex] := i or (hashCode and BucketHashCodeMask);
    Inc(item, ItemSize);
  end;
  ItemCount := Count;
end;

procedure THashTable.SetCapacity(const value: Integer);
var
  newCapacity: Integer;
begin
  Guard.CheckRange(value >= Count, 'capacity');

  if value = 0 then
    newCapacity := 0
  else
    newCapacity := Math.Max(MinCapacity, value);
  if newCapacity <> Capacity then
    Rehash(newCapacity);
end;

{$ENDREGION}


end.
