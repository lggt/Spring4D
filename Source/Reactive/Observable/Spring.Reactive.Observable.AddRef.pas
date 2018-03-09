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

unit Spring.Reactive.Observable.AddRef;

interface

uses
  Spring,
  Spring.Reactive,
  Spring.Reactive.Internal.Producer,
  Spring.Reactive.Internal.Sink;

type
  TAddRef<TSource> = class(TProducer<TSource>)
  private
    fSource: IObservable<TSource>;
    fRefCount: IRefCountDisposable;

    type
      TSink = class(TSink<TSource>, IObserver<TSource>)
      public
        procedure OnNext(const value: TSource);
      end;
  protected
    function CreateSink(const observer: IObserver<TSource>;
      const cancel: IDisposable): TObject; override;
    function Run(const sink: TObject): IDisposable; override;
  public
    constructor Create(const source: IObservable<TSource>; const refCount: IRefCountDisposable);
  end;

implementation

uses
  Spring.Reactive.Disposables;


{$REGION 'TAddRef<TSource>'}

constructor TAddRef<TSource>.Create(const source: IObservable<TSource>;
  const refCount: IRefCountDisposable);
begin
  inherited Create;
  fSource := source;
  fRefCount := refCount;
end;

function TAddRef<TSource>.CreateSink(const observer: IObserver<TSource>;
  const cancel: IDisposable): TObject;
var
  d: ICancelable;
begin
  d := TStableCompositeDisposable.Create(fRefCount.GetDisposable, cancel);
  Result := TSink.Create(observer, d);
end;

function TAddRef<TSource>.Run(const sink: TObject): IDisposable;
begin
  Result := fSource.Subscribe(TSink(sink));
end;

{$ENDREGION}


{$REGION 'TAddRef<TSource>.TSink'}

procedure TAddRef<TSource>.TSink.OnNext(const value: TSource);
begin
  Observer.OnNext(value);
end;

{$ENDREGION}


end.
