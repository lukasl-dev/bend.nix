{
  lib,
  stdenvNoCC,
  makeWrapper,
  writeShellScriptBin,
  bun,
  clang_19,
  libX11,
  alsa-lib,
  xorgproto,
  src,
  version,
}:
let
  clang =
    if stdenvNoCC.hostPlatform.isLinux then
      writeShellScriptBin "clang" ''
        exec ${lib.getExe clang_19} \
          -isystem ${lib.getDev libX11}/include \
          -isystem ${lib.getDev xorgproto}/include \
          -isystem ${lib.getDev alsa-lib}/include \
          -L${lib.getLib libX11}/lib \
          -L${lib.getLib alsa-lib}/lib \
          -Wl,-rpath,${lib.getLib libX11}/lib \
          -Wl,-rpath,${lib.getLib alsa-lib}/lib \
          "$@"
      ''
    else
      clang_19;
in
stdenvNoCC.mkDerivation {
  pname = "bend";
  inherit src version;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/lib/bend/bend2" "$out/lib/bend/guide"
    cp bend2/{base.bend,bend.ts,comp.ts,main.ts} "$out/lib/bend/bend2/"
    cp -R bend2/effs "$out/lib/bend/bend2/"
    cp guide/GUIDE.md "$out/lib/bend/guide/"

    makeWrapper ${lib.getExe bun} "$out/bin/bend" \
      --add-flags "$out/lib/bend/bend2/main.ts" \
      --prefix PATH : ${lib.makeBinPath [ clang ]}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    case "$($out/bin/bend --version)" in
      "bend "*) ;;
      *) exit 1 ;;
    esac

    cat > hello.bend <<'BEND'
    import Base

    def main() -> IO(Unit):
      IO.print("Hello, world!")
    BEND

    test "$($out/bin/bend hello.bend)" = "Hello, world!"
    $out/bin/bend hello.bend -o hello
    test "$(./hello)" = "Hello, world!"

    ${lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      # Exercise the additional X11 headers and libraries exposed through the
      # wrapped compiler. Ordinary programs do not import these effects.
      $out/bin/bend demos/app_pong_game_2d/main.bend -o pong
      test -x pong
    ''}

    runHook postInstallCheck
  '';

  meta = {
    description = "Fast language that blocks AI mistakes via proof";
    homepage = "https://github.com/HigherOrderCO/Bend";
    license = lib.licenses.asl20;
    mainProgram = "bend";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = [
      {
        name = "Lukas";
        email = "me@lukasl.dev";
        github = "lukasl-dev";
      }
    ];
  };
}
