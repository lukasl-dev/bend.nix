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
  imports = [
    (import ../lib/options.nix {
      inherit self;
      optionPath = [
        "programs"
        "bend"
      ];
    })
  ];

  options.programs.bend.enable = lib.mkEnableOption "Bend";

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.finalPackage ];
  };
}
