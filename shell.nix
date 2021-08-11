{ pkgs ? import <nixpkgs> {}}:
let
  nodeEnv = pkgs.callPackage ./node-env.nix { };
  nodePackages = pkgs.callPackage ./node-packages.nix {
    globalBuildInputs = with pkgs; [ go rustc wasm wasm-pack cargo ];
    inherit nodeEnv;
  };
in nodePackages.shell

