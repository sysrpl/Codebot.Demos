(********************************************************)
(*                                                      *)
(*  Debian Packager                                     *)
(*  http://www.getlazarus.org/apps/makedeb              *)
(*  Anthony Walter <admin@getlazarus.org>               *)
(*                                                      *)
(*  Released under ther GPL V3 license                  *)
(*                                                      *)
(*  Last Modified July 2022                             *)
(*                                                      *)
(********************************************************)

program makedeb;

{$mode delphi}

uses
  Codebot.System,
  Interfaces,
  Forms, Composer, DebianPack;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TComposeForm, ComposeForm);
  Application.Run;
end.

