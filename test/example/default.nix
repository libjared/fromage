{ nixpkgs, home-manager, fromage }:

let
  pkgs = import nixpkgs {
    system = "x86_64-linux";
  };
in
home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [
    fromage.homeManagerModules.fromage
    {
      home = {
        username = "me";
        homeDirectory = "/home/me";
        stateVersion = "22.11";
      };

      fromage.identityPaths = [ ("" + ./key.txt) ];
      fromage.file."ta.key" = {
        src = ./secrets/mytakey.age;
      };
    }
  ];
}
