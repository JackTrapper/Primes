program PrimePas;

{
	Passes: 8123, Time: 9.9999998 s, Avg: 1.2311 ms, Limit: 1000000, Count: 78498, Valid: Yes

	Intel Core i5-9400 @ 2.90 GHz
	32-bit

	v1.1 - Removed use of generics dictionary and TimeSpan, but inlined GetBit/ClearBit.
	v1.0 - Initial release
}

{$APPTYPE CONSOLE}

uses
	SysUtils,
	Classes,
	Math,
	Windows;

type
	TPrimeSieve = class
	private
		FSieveSize: Integer;
		FBitArray: array of ByteBool; //ByteBool: 4644. WordBool: 4232. LongBool: 3673

		function GetBit(Index: Integer): Boolean; inline;
		procedure ClearBit(Index: Integer); inline;
		procedure InitializeBits;
	public
		constructor Create(Size: Integer);
		destructor Destroy; override;

		procedure RunSieve; // Calculate the primes up to the specified limit

		function CountPrimes: Integer;
		function ValidateResults: Boolean;

		procedure PrintResults(ShowResults: Boolean; Duration: Double; Passes: Integer);
	end;

{ TPrimeSieve }

constructor TPrimeSieve.Create(Size: Integer);
begin
	inherited Create;

	FSieveSize := Size;

	//The optimization here is that we only store bits for *odd* numbers.
	// So FBitArray[3] is if 3 is prime
	// and FBitArray[4] is if 5 is prime
	//GetBit and SetBit do the work of "div 2"
	SetLength(FBitArray, (FSieveSize+1) div 2);
	InitializeBits;
end;

destructor TPrimeSieve.Destroy;
begin
	inherited;
end;

function TPrimeSieve.CountPrimes: Integer;
var
	count: Integer;
	i: Integer;
begin
	count := 0;
	for i := 0 to High(FBitArray) do
	begin
		if FBitArray[i] then
			Inc(count);
	end;

	Result := count;
end;

function TPrimeSieve.ValidateResults: Boolean;
var
	expected: Integer;
begin
	// Historical data for validating our results - the number of primes
	// to be found under some limit, such as 168 primes under 1000
	case FSieveSize of
	10: expected := 4; //nobody noticed that 1 is wrong? [2, 3, 5, 7]
	100: expected := 25;
	1000: expected := 168;
	10000: expected := 1229;
	100000: expected := 9592;
	1000000: expected := 78498;
	10000000: expected := 664579;
	100000000: expected := 5761455;
	else
		Result := False;
		Exit;
	end;

	Result := (Self.CountPrimes = expected);
end;

function TPrimeSieve.GetBit(Index: Integer): Boolean;
begin
//	if (Index mod 2 = 0) then //6494
	if (Index and 1) = 0 then //7213
	begin
		Result := False;
		Exit;
	end;

	Result := FBitArray[Index div 2];
end;

procedure TPrimeSieve.InitializeBits;
var
	i: Integer;
	remaining: Integer;
begin
	remaining := Length(FBitArray);
	i := 0;
	while remaining >= 8 do
	begin
		FBitArray[i]   := True;
		FBitArray[i+1] := True;
		FBitArray[i+2] := True;
		FBitArray[i+3] := True;
		FBitArray[i+4] := True;
		FBitArray[i+5] := True;
		FBitArray[i+6] := True;
		FBitArray[i+7] := True;
		Inc(i, 8);
		Dec(remaining, 8);
	end;
	while remaining > 0 do
	begin
		FBitArray[i] := True;
		Inc(i);
		Dec(remaining);
	end;
end;

procedure TPrimeSieve.ClearBit(Index: Integer);
const
	SWarning = 'You are setting even bits, which is sub-optimal';
begin
{
	Profiling shows 99% of the execution is spent here in ClearBit.
	Which is surprising, as you'd think the branch predictor would realize this branch is **never** taken.
}
	if ((Index and 1) = 0) then
	begin
//		Writeln('You are setting even bits, which is sub-optimal');	//6617
//		WriteLn(SWarning); //6612
//		No warning: 8113
		Exit;
	end;

	//Any compiler worth its salt converts "div 2" into "shr 1".
	//In this case Delphi is worth it's salt; emitting "sar".
	//(But don't forget: Delphi still can't hoist loop variables)
	FBitArray[Index div 2] := False;
end;


procedure TPrimeSieve.RunSieve;
var
	factor: Integer;
	q: Integer;
	num: Integer;
begin
	factor := 3;
	q := Floor(Sqrt(FSieveSize));

	while (factor <= q) do
	begin
		for num := factor to FSieveSize do
		begin
			if GetBit(num) then
			begin
				factor := num;
				Break;
			end;
		end;

		// If marking factor 3, you wouldn't mark 6 (it's a mult of 2) so start with the 3rd instance of this factor's multiple.
		// We can then step by factor * 2 because every second one is going to be even by definition
		num := factor*3;
		while num <= FSieveSize do
		begin
			ClearBit(num);
			Inc(num, factor*2);
		end;

		Inc(factor, 2);
	end;
end;

procedure TPrimeSieve.PrintResults(ShowResults: Boolean; Duration: Double; Passes: Integer);
var
	count: Integer;
	num: Integer;
const
	SYesNo: array[Boolean] of string = ('No', 'Yes');
begin
	if ShowResults then
		Write('2, ');

	count := 1;
	for num := 3 to FSieveSize do
	begin
		if GetBit(num) then
		begin
			if ShowResults then
				Write(IntToStr(num) + ', ');
			Inc(count);
		end;
	end;

	if ShowResults then
		WriteLn('');

	WriteLn(Format('Passes: %d, Time: %.7f s, Avg: %.4f ms, Limit: %d, Count: %d, Valid: %s',
			[Passes, Duration, Duration/Passes*1000, FSieveSize, count, SYesNo[ValidateResults]]));
end;

procedure Main;
var
	sieve: TPrimeSieve;
	dtStart: TDateTime;
	passes: Integer;
	dtEnd: TDateTime;
	totalSeconds: Real;
const
	TEN_SECONDS = 10.0/60/60/24;
begin
	passes := 0;
	sieve := nil;

	dtStart := Now;
	dtEnd := dtStart + TEN_SECONDS;
	while Now < dtEnd do
	begin
		if Assigned(sieve) then
			sieve.Free;

		sieve := TPrimeSieve.Create(1000000);
		sieve.RunSieve;
		Inc(passes);
	end;

	totalSeconds := (Now-dtStart)*24*60*60;
	if Assigned(sieve) then
		sieve.PrintResults(False, totalSeconds, passes);
end;

begin
	try
		Main;
		WriteLn('Press enter to close...');
		Readln;
	except
		on E: Exception do
			Writeln(E.ClassName, ': ', E.Message);
	end;
end.
