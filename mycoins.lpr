program mycoins;

{$mode objfpc}{$H+}

uses
  SysUtils, Interfaces, Forms, UIMain;

{$R *.res}

begin
  DefaultFormatSettings.ThousandSeparator := ' ';
  DefaultFormatSettings.DecimalSeparator := '.';
  DefaultFormatSettings.ShortDateFormat := 'yyyy-mm-dd';
  DefaultFormatSettings.DateSeparator := '-';

  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
