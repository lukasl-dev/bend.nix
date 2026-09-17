{ self }:
{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.bend;
in
{
  imports = [ (import ./options.nix { inherit self; }) ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
