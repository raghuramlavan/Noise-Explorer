{
  description = "(Noise Explorer : Command-line tool can parse Noise Handshake Patterns)";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-20.09";

  # Upstream source tree(s).
  inputs.noise_explorer-src = { url = git+https://source.symbolic.software/noiseexplorer/noiseexplorer; flake = false; };

  outputs = { self, nixpkgs, noise_explorer-src}:
    let

      # Generate a user-friendly version numer.
      version = builtins.substring 1 0 noise_explorer-src.lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux"  "x86_64-darwin"];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

      nodeDependencies = (nixpkgsFor.x86_64-linux.callPackage ./default.nix {}).shell.nodeDependencies;

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: {

        noise_explorer = with final; stdenv.mkDerivation rec {
          name = "noice_explorer-${version}";

          src = noise_explorer-src;

          buildInputs = [ nodeDependencies ];
          buildPhase = ''
            cd src;
            echo "***** In build Phase ********"
            make parser
          '';
          installPhase = ''
                   cp -r ./ $out
                   echo $out
                   echo "shell complete"
          '';
          meta = {
            homepage = "https://www.gnu.org/software/hello/";
            description = "A program to show a familiar, friendly greeting";
          };
        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) noise_explorer;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.noise_explorer);

      # A NixOS module, if applicable (e.g. if the package provides a system service).
      nixosModules.noise_explorer=
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlay ];

          environment.systemPackages = [ pkgs.noise_explorer ];

          #systemd.services = { ... };
        };

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: {
        inherit (self.packages.${system}) noise_explorer;

        # Additional tests, if applicable.
        test =
          with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "noise_explorer-test-${version}";

            buildInputs = [ noise_explorer ];

            unpackPhase = "true";

            buildPhase = ''
              echo 'running some integration tests'
              [[ $(hello) = 'Hello, world!' ]]
            '';

            installPhase = "mkdir -p $out";
          };

        # A VM test of the NixOS module.
        vmTest =
          with import (nixpkgs + "/nixos/lib/testing-python.nix") {
            inherit system;
          };

          makeTest {
            nodes = {
              client = { ... }: {
                imports = [ self.nixosModules.hello ];
              };
            };

            testScript =
              ''
                start_all()
                client.wait_for_unit("multi-user.target")
                client.succeed("hello")
              '';
          };
      });

    };
}
