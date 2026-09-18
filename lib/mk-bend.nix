{ self, lib }:
{
  pkgs,
  modules ? [ ],
  extraSpecialArgs ? { },
}:
let
  evaluated = lib.evalModules {
    specialArgs = {
      inherit self pkgs;
    }
    // extraSpecialArgs;
    modules = [ ./options.nix ] ++ modules;
  };
in
{
  inherit (evaluated) config options;
  inherit (evaluated.config.bend) cudaSupport cudaPackages;
  package = evaluated.config.bend.finalPackage;
}
