{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.bend;
  current = builtins.fromJSON (builtins.readFile (self.outPath + "/VERSION.json"));
  inherit (current) rev date hash;

  src = pkgs.fetchFromGitHub {
    owner = "HigherOrderCO";
    repo = "Bend";
    inherit rev hash;
  };
in
{
  options.bend = {
    cudaSupport = lib.mkEnableOption "CUDA support for generated Bend executables";

    cudaPackages = lib.mkOption {
      # A Nixpkgs CUDA package set contains aliases and package functions, so
      # it is intentionally opaque here; package.nix selects only what it uses.
      type = lib.types.raw;
      default = pkgs.cudaPackages_12;
      defaultText = lib.literalExpression "pkgs.cudaPackages_12";
      description = "CUDA package set used when CUDA support is enabled.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      internal = true;
      readOnly = true;
    };
  };

  config.bend.finalPackage = pkgs.callPackage ../packages/package.nix {
    inherit src;
    version = "unstable-${date}-${builtins.substring 0 7 rev}";
    inherit (cfg) cudaSupport cudaPackages;
  };
}
