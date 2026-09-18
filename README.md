# bend.nix

<p align="center">
  <a href="https://lukasl-dev.github.io/bend.nix/">
    <img src="https://img.shields.io/badge/docs-options-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="Options">
  </a>
</p>

A Nix flake for [Bend](https://github.com/HigherOrderCO/Bend), a fast language that uses proofs to make important program properties enforceable.

It provides:

- packages for `nix run` and `nix build`
- a configurable package builder with optional CUDA support
- NixOS and Home Manager modules
- an overlay exposing `pkgs.bend`
- a daily update workflow tracking the latest commit on upstream's `main` branch

> [!IMPORTANT]
> This is an unofficial Nix flake and is not maintained by the Bend developers.

## Quick start

```bash
nix run github:lukasl-dev/bend.nix
```

Or build it locally:

```bash
nix build .#bend
```

The default package includes Bun to run Bend and Clang 19 to compile Bend programs to native binaries. Linux builds also include the X11 and ALSA headers and libraries needed by Bend's window and audio effects. CUDA remains opt-in so the default package stays free and relatively small.

## Usage

```nix
{
  inputs.bend.url = "github:lukasl-dev/bend.nix";
}
```

### NixOS

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.bend.nixosModules.default ];

  programs.bend = {
    enable = true;

    # Defaults to pkgs.config.cudaSupport. CUDA is supported only on Linux and
    # requires unfree packages.
    cuda = {
      enable = true;
      packages = pkgs.cudaPackages_12;
    };
  };
}
```

### Home Manager

```nix
{ inputs, ... }:
{
  imports = [ inputs.bend.homeModules.default ];
  programs.bend.enable = true;
}
```

### Overlay

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.bend.overlays.default ];
  environment.systemPackages = [ pkgs.bend ];
}
```

### Custom package

`programs.bend` constructs the appropriate package automatically. Use
`lib.mkBend` directly when a package is needed outside the NixOS or Home
Manager modules:

```nix
{ inputs, pkgs, ... }:
let
  bend = inputs.bend.lib.mkBend {
    inherit pkgs;
    modules = [
      {
        bend.cuda = {
          enable = true;
          packages = pkgs.cudaPackages_12;
        };
      }
    ];
  };
in
bend.package
```

CUDA packages use NVIDIA's unfree license, so the supplied `pkgs` must permit
unfree packages. Generated executables use the host NVIDIA driver at runtime.
The CUDA backend is supported only on Linux.

If only the derivation is needed, `lib.mkBendPackage` accepts the same
arguments and returns `bend.package` directly.

## Updating

Bend does not publish versioned releases for this source tree, so the package pins a specific commit from upstream's `main` branch. Update that pin manually with:

```bash
nix run .#update
```

The scheduled GitHub Actions workflow runs the same updater daily, builds the changed package, and commits the new revision and source hash. It deliberately does not create downstream release tags.

## Options

Generate the complete option reference in Markdown or HTML:

```bash
nix build .#docs-md
nix build .#docs-html
```

The output is available at `result/index.md` or `result/index.html`.
