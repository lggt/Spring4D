{***************************************************************************}
{                                                                           }
{           Spring Framework for Delphi                                     }
{                                                                           }
{           Copyright (c) 2009-2017 Spring4D Team                           }
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

unit Spring.Reactive.Observable.All;

interface

uses
  Spring,
  Spring.Reactive,
  Spring.Reactive.Internal.Producer,
  Spring.Reactive.Internal.Sink;

type
  TAll<T> = class(TProducer<Boolean>)
  private
    fSource: IObservable<T>;
    fPredicate: Predicate<T>;

    type
      TSink = class(TSink<Boolean>, IObserver<T>)
      private
        fParent: TAll<T>;
      public
        constructor Create(const parent: TAll<T>;
          const observer: IObserver<Boolean>; const cancel: IDisposable);
        destructor Destroy; override;
        procedure OnNext(const value: T);
        procedure OnCompleted;
      end;
  protected
    function Run(const observer: IObserver<Boolean>; const cancel: IDisposable;
      const setSink: Action<IDisposable>): IDisposable; override;
  public
    constructor Create(const source: IObservable<T>; const predicate: Predicate<T>);
  end;

implementation


{$REGION 'TAll<T>'}

constructor TAll<T>.Create(const source: IObservable<T>;
  const predicate: Predicate<T>);
begin
  inherited Create;
  fSource := source;
  fPredicate := predicate;
end;

function TAll<T>.Run(const observer: IObserver<Boolean>;
  const cancel: IDisposable; const setSink: Action<IDisposable>): IDisposable;
var
  sink: TSink;
begin
  sink := TSink.Create(Self, observer, cancel);
  setSink(sink);
  Result := fSource.Subscribe(sink);
end;

{$ENDREGION}


{$REGION 'TAll<T>.TSink'}

constructor TAll<T>.TSink.Create(const parent: TAll<T>;
  const observer: IObserver<Boolean>; const cancel: IDisposable);
begin
  inherited Create(observer, cancel);
  fParent := parent;
  fParent._AddRef;
end;

destructor TAll<T>.TSink.Destroy;
begin
  fParent._Release;
  inherited;
end;

procedure TAll<T>.TSink.OnCompleted;
begin
  Observer.OnNext(True);
  Observer.OnCompleted;
  Dispose;
end;

procedure TAll<T>.TSink.OnNext(const value: T);
var
  res: Boolean;
begin
  res := False;
  try
    res := fParent.fPredicate(value);
  except
    on e: Exception do
    begin
      Observer.OnError(e);
      Dispose;
      Exit;
    end;
  end;

  if not res then
  begin
    Observer.OnNext(False);
    Observer.OnCompleted;
    Dispose;
  end;
end;

{$ENDREGION}


end.
