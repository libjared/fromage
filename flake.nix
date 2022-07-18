{
  description = "Home manager secret management with age";

  outputs = { self, nixpkgs }: {
    homeManagerModules.fromage = import ./module;
  };
}
