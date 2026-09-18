{
  description = "Nix packaging and modules for Bend";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let
      mkBend = import ./lib/mk-bend.nix {
        inherit self;
        inherit (nixpkgs) lib;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        { pkgs, ... }:
        let
          update = import ./update.nix { inherit pkgs; };
          scan = import ./scan.nix { inherit pkgs; };

          module = import ./modules/options.nix { inherit self; };
          evaluated = pkgs.lib.evalModules {
            specialArgs = { inherit pkgs; };
            modules = [ module ];
          };
          docs = pkgs.nixosOptionsDoc {
            options = builtins.removeAttrs evaluated.options [ "_module" ];
          };
        in
        {
          packages = rec {
            default = bend;

            bend = (mkBend { inherit pkgs; }).package;

            docs-md = pkgs.runCommand "bend-options.md" { } ''
              mkdir -p $out
              cp ${docs.optionsCommonMark} $out/index.md
            '';

            docs-html = pkgs.runCommand "bend-options.html" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
              mkdir -p $out
              pandoc \
                --standalone \
                --metadata title="bend.nix options" \
                ${docs-md}/index.md \
                --output $out/index.html
            '';
          };

          formatter = pkgs.nixfmt;

          apps = {
            update = {
              type = "app";
              program = "${update}/bin/bend-update";
              meta.description = "Update Bend to the latest main commit";
            };
            scan = {
              type = "app";
              program = "${scan}/bin/bend-scan";
              meta.description = "Run repository security scans";
            };
          };
        };

      flake = {
        lib = {
          inherit mkBend;

          mkBendPackage = args: (mkBend args).package;
        };

        nixosModules = rec {
          default = bend;
          bend = import ./modules/nixos.nix { inherit self; };
        };

        homeModules = rec {
          default = bend;
          bend = import ./modules/home-manager.nix { inherit self; };
        };

        homeManagerModules = self.homeModules;

        overlays.default =
          _final: prev:
          let
            inherit (prev.stdenv.hostPlatform) system;
          in
          {
            bend = self.packages.${system}.bend;
          };
      };
    };
}
