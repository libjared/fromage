{ pkgs

  # Note, this should be "the standard library" + HM extensions.
, lib

  # Whether to enable module type checking.
, check ? true
}:

let

  modules = [
    ./default.nix
  ];

  pkgsModule = { config, ... }: {
    config = {
      _module.args.baseModules = modules;
      _module.args.pkgsPath = lib.mkDefault pkgs.path;
      _module.args.pkgs = lib.mkDefault pkgs;
      _module.check = check;
      lib = lib.hm;
    };
  };

in
modules ++ [ pkgsModule ]
