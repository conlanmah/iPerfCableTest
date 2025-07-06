# If you don't know what this is, ignore it.
# This file does not affect anything unless you are using Nix

{ pkgs ? import <nixpkgs> { } }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    iproute2 
    iperf 
    psmisc
  ];
}
