{ pkgs }:
pkgs.writeShellApplication {
  name = "bend-scan";
  runtimeInputs = with pkgs; [
    gitleaks
    zizmor
  ];
  text = ''
    set -euo pipefail

    zizmor .github/workflows
    gitleaks dir --redact --config .gitleaks.toml .
  '';
}
