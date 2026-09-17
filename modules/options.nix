{ self }:
{
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
{
  options.programs.bend = {
    enable = lib.mkEnableOption "Bend";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.bend;
      defaultText = lib.literalExpression "inputs.bend.packages.\${pkgs.system}.bend";
      description = "The Bend package to install.";
    };
  };
}
