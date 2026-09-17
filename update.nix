{ pkgs }:
pkgs.writeShellApplication {
  name = "bend-update";
  runtimeInputs = with pkgs; [
    coreutils
    git
    jq
    nix
  ];
  text = ''
    set -euo pipefail

    upstream=https://github.com/HigherOrderCO/Bend.git
    rev="$(git ls-remote "$upstream" refs/heads/main | cut -f1)"
    test -n "$rev"

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    git -C "$tmpdir" init --quiet
    git -C "$tmpdir" fetch --quiet --depth=1 "$upstream" "$rev"
    date="$(git -C "$tmpdir" show -s --format=%cs FETCH_HEAD)"

    source_json="$(nix store prefetch-file --json --unpack \
      "https://github.com/HigherOrderCO/Bend/archive/$rev.tar.gz")"
    hash="$(jq -r .hash <<< "$source_json")"

    jq \
      --arg rev "$rev" \
      --arg date "$date" \
      --arg hash "$hash" \
      '.rev = $rev | .date = $date | .hash = $hash' \
      VERSION.json > "$tmpdir/VERSION.json"

    mv "$tmpdir/VERSION.json" VERSION.json
    echo "Updated Bend to main@$rev ($date)"
  '';
}
