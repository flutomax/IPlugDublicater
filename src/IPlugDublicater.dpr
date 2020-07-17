program IPlugDublicater;

{
  IPlug Dublicater
  Based on Python shell script for Duplicating WDL-OL IPlug Projects
  Oli Larkin 2012-2019 http://www.olilarkin.co.uk
  Vasily Makarov 2020 http://stone-voices.ru
  License: WTFPL http://sam.zoy.org/wtfpl/COPYING

  fixed Manufacturer can contain spaces
}

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {FrmMain},
  uHelper in 'uHelper.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmMain, FrmMain);
  Application.Run;
end.
