{
  description = "Home manager secret management with age";

  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, home-manager }:
    let
      example = (import ./test/example {
        inherit nixpkgs home-manager;
        fromage = self;
      }).activationPackage;
    in
    {
      homeManagerModules.fromage = import ./module;
      checks.x86_64-linux.example = example;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
