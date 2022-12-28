{
  description = "Zephyr SDK for ARM Cortex-M";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let

      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in
    {

      packages = forAllSystems (system:
        let

          pkgs = nixpkgsFor.${system};

          platform = {
            aarch64-linux = "linux-aarch64";
            x86_64-linux = "linux-x86_64";
          }.${system} or (throw "Unsupported system: ${system}");

          hosttype = pkgs.lib.strings.removePrefix "linux-" platform;

        in
        rec {

          zephyr-sdk-arm = with pkgs; stdenv.mkDerivation rec {
            pname = "zephyr-sdk-arm";
            version = "0.15.1";

            src = fetchurl {
              url = "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${version}/zephyr-sdk-${version}_${platform}.tar.gz";
              sha256 = {
                aarch64-linux = "113z3g82y545y26n09j8l6pmw47mp1m7gr8jpzl8g8kn8fcxxifj";
                x86_64-linux = "1agvn07db6j7pngxsafzqshi864lk4j296vmvjg7n682a420cx0a";
              }.${system} or (throw "Unsupported system: ${system}");
            };

            nativeBuildInputs = [
              python38
              which
              cmake
              wget
            ];

            dontConfigure = true;
            dontBuild = true;
            dontPatchELF = true;
            dontStrip = true;

            installPhase = ''
              # Remove toolchains othan than arm-zephyr-eabi and host toolchain
              find . -maxdepth 1 -type d -name '*zephyr-elf' -not -name '${hosttype}-zephyr-elf' -exec rm -rf {} +
              
              mkdir -p $out
              mv * $out/
              
              bash $out/setup.sh -t arm-zephyr-eabi -h
              
              # Remove setup scripts
              rm $out/setup.sh \
                 $out/zephyr-sdk-${hosttype}-hosttools-standalone-0.9.sh 
              
              # Create symlinks for binaries
              mkdir -p $out/bin
              ln -s $out/arm-zephyr-eabi/bin/* $out/bin/
              ln -s $out/${hosttype}-zephyr-elf/bin/* $out/bin/
              ln -s $out/sysroots/x86_64-pokysdk-linux/usr/bin/* $out/bin/
            '';

            preFixup = ''
              find $out/arm-zephyr-eabi $out/${hosttype}-zephyr-elf -type f | while read f; do
                patchelf "$f" > /dev/null 2>&1 || continue
                patchelf --set-interpreter $(cat ${stdenv.cc}/nix-support/dynamic-linker) "$f" || true
                patchelf --set-rpath ${lib.makeLibraryPath [ "$out" stdenv.cc.cc ncurses5 python38 ]} "$f" || true
              done
            '';

            meta = with lib; {
              homepage = "https://www.zephyrproject.org/";
              description = "Zephyr SDK for ARM Cortex-M";
              platforms = [ "x86_64-linux" "aarch64-linux" ];
            };
          };

          default = zephyr-sdk-arm;

        });

    };

}
