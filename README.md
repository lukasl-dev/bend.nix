# bend.nix

<p align="center">
  <a href="https://lukasl-dev.github.io/bend.nix/">
    <img src="https://img.shields.io/badge/docs-options-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="Options">
  </a>
</p>

A Nix flake for [Bend](https://github.com/HigherOrderCO/Bend), a fast language that uses proofs to make important program properties enforceable.

It provides:

- packages for `nix run` and `nix build`
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

The package includes Bun to run Bend and Clang 19 to compile Bend programs to native binaries. Linux builds also include the X11 and ALSA headers and libraries needed by Bend's window and audio effects. CUDA is not included; GPU compilation on Linux still requires a CUDA 12 installation at `/usr/local/cuda`, as expected by upstream.

## Usage

```nix
{
  inputs.bend.url = "github:lukasl-dev/bend.nix";
}
```

### NixOS

```nix
{ inputs, ... }:
{
  imports = [ inputs.bend.nixosModules.default ];
  programs.bend.enable = true;
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
