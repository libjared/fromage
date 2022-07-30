{
  description = "Home manager secret management with age";

  inputs = {
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nmd = {
      url = "gitlab:rycee/nmd";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, nmd }:
    let
      example = (import ./test/example {
        inherit nixpkgs home-manager;
        fromage = self;
      }).activationPackage;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = (import "${home-manager}/modules/lib/stdlib-extended.nix") pkgs.lib;
      docs = import ./docs {
        inherit pkgs lib;
        nmdSrc = nmd;
      };
    in
    {
      homeManagerModules.fromage = import ./module;
      checks.x86_64-linux.example = example;
      checks.x86_64-linux.docs = self.packages.x86_64-linux.docs-html;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      packages.x86_64-linux.docs-html = docs.manual.html;
    };
}
