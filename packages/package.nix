{
  lib,
  stdenvNoCC,
  makeWrapper,
  patchelf,
  runCommand,
  writeShellScriptBin,
  bun,
  clang_19,
  libX11,
  alsa-lib,
  xorgproto,
  src,
  version,
  cudaSupport ? false,
  cudaPackages ? null,
}:
let
  driverLib = "/run/opengl-driver/lib";

  clangWrapped =
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

  clang =
    if cudaSupport then
      writeShellScriptBin "clang" ''
        cuda=
        out=
        args=("$@")
        while (( $# > 0 )); do
          [[ $1 == -DBEND_CUDA=1 ]] && cuda=1
          if [[ $1 == -o && $# > 1 ]]; then
            out=$2
            shift
          fi
          shift
        done

        ${lib.getExe clangWrapped} \
          ''${cuda:+-Wl,-rpath,${cudaToolkit}/lib} \
          "''${args[@]}"
        status=$?

        if (( status == 0 )) && [[ -n $cuda && -n $out && -f $out ]]; then
          # Clang's Nix wrapper removes non-store RPATHs. Add the host driver
          # path afterwards so generated executables can load libcuda.so.1.
          ${lib.getExe patchelf} --add-rpath ${driverLib} "$out"
        fi
        exit $status
      ''
    else
      clangWrapped;

  cudaToolkit =
    if cudaSupport then
      let
        nvrtc = cudaPackages.cuda_nvrtc;
        cudart = cudaPackages.cuda_cudart;
      in
      runCommand "bend-cuda-${lib.getVersion nvrtc}" { } ''
        mkdir -p "$out/include" "$out/lib"
        ln -s lib "$out/lib64"

        # These are the only CUDA headers emitted Bend programs include.
        cp ${cudart}/include/cuda.h "$out/include/"
        cp ${nvrtc.include}/include/nvrtc.h "$out/include/"

        # Keep NVRTC and its builtins available when a generated executable
        # rebuilds its cached GPU program.
        for library in \
          ${nvrtc.lib}/lib/libnvrtc.so* \
          ${nvrtc.lib}/lib/libnvrtc-builtins.so*; do
          ln -s "$library" "$out/lib/"
        done

        # libcuda is supplied by the host NVIDIA driver at runtime. This stub
        # is needed only to link generated Bend executables; unlike a symlink,
        # copying it does not retain the CUDA runtime package in the closure.
        cp ${cudart}/lib/stubs/libcuda.so "$out/lib/libcuda.so"
      ''
    else
      null;
in
assert lib.assertMsg (!cudaSupport || stdenvNoCC.hostPlatform.isLinux) (
  "Bend's CUDA backend is supported only on Linux"
);
assert lib.assertMsg (!cudaSupport || cudaPackages != null) (
  "cudaPackages must be provided when cudaSupport is enabled"
);
stdenvNoCC.mkDerivation {
  pname = "bend";
  inherit src version;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  postPatch = lib.optionalString cudaSupport ''
    # This Bend revision predates CUDA_HOME support and hardcodes this path.
    substituteInPlace bend2/main.ts \
      --replace-fail /usr/local/cuda ${cudaToolkit}
  '';

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
      $out/bin/bend demos/app_pong_game_2d/main.bend -o pong.c
      ${lib.getExe clang} -std=c11 -O3 pong.c -lpthread -lm -lX11 -o pong
      test -x pong
    ''}

    ${lib.optionalString cudaSupport ''
      # Bend immediately executes GPU binaries to build their kernel cache,
      # which needs a real host driver and GPU. Compile and link the same C
      # command here without performing that device-dependent final step.
      $out/bin/bend tests/run/gpu_mark.bend -o gpu_mark.c
      ${lib.getExe clang} \
        -DBEND_CUDA=1 \
        -I${cudaToolkit}/include \
        -L${cudaToolkit}/lib \
        -O2 \
        gpu_mark.c \
        -lcuda \
        -lnvrtc \
        -o gpu_mark

      ${lib.getExe' clang_19 "readelf"} -d gpu_mark \
        | grep -F 'Shared library: [libcuda.so.1]'
      ${lib.getExe' clang_19 "readelf"} -d gpu_mark \
        | grep -F 'Shared library: [libnvrtc.so.'
      ${lib.getExe' clang_19 "readelf"} -d gpu_mark \
        | grep -F '${cudaToolkit}/lib'
      ${lib.getExe' clang_19 "readelf"} -d gpu_mark \
        | grep -F '${driverLib}'
      test -x gpu_mark
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

  passthru = {
    inherit cudaSupport;
  };
}
