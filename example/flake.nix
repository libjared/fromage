{
  inputs = {
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    fromage = {
      url = "github:libjared/fromage";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, fromage, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
    in {
      homeConfigurations = {
        "me@machine" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            fromage.homeManagerModules.fromage
            {
              home = {
                username = "me";
                homeDirectory = "/home/me";
                stateVersion = "22.11";
              };

              # CHECK HERE for fromage configuration
              # fromage.identityPaths = [ "~/.ssh/id_ed25519" ];
              fromage.identityPaths = [ ("" + ./key.txt) ];
              fromage.file."ta.key" = {
                src = ./secrets/mytakey.age;
              };
              # this will create ~/.local/share/fromage/ta.key
            }
          ];
        };
      };
      packages.x86_64-linux.default = self.homeConfigurations."me@machine".activationPackage;
    };
}
