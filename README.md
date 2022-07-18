# fromage - [age](https://github.com/str4d/rage) secrets for nix home manager, decrypted upon profile activation

`fromage` is a module for [home-manager](https://github.com/nix-community/home-manager) that enables decryption of secrets when a home-manager profile is activated.

It is based on the [homeage](https://github.com/jordanisaacs/homeage) project.

## Features

- Filetype-agnostic declarative secrets can be used inside your home-manager flakes.
- Secrets are decrypted with an activation action, integrating seamlessly with home-manager.
- Encryption/decryption use the typical age workflow, with ssh or age keys.
- Extremely small, so inspect the source yourself!

## Overview

Secrets are encrypted by some external identity, and stored as an .age file in your home-manager flake.

**Build**: Encrypted secrets are copied to the Nix store.

**Pre-activation**: Before activating the profile, Home-manager verifies the secrets can be decrypted with the provided identity. Additionally, it verifies that no secret file's destination will conflict with an existing file.

**Post-activation**: After home-manager activates the rest of the profile, it decrypts all secrets and writes them to the detination in your home directory. If a file is decrypted and the destination already exists, it will loudly rename the original to a backup, unless the decrypted contents match the existing contents exactly.

**Runtime**: Secrets remain unencrypted in your home directory.

## Roadmap

- [ ] Implement pre-activation script
- [ ] Implement post-activation script
- [ ] Support passphrases
- [ ] Add tests

## Getting started

### Nix Flakes

The below example is mostly home-manager boilerplate. In a nutshell, add `fromage.homeManagerModules.fromage` to the list of modules and set a the proper options.

```nix
{
  inputs = {
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    fromage = {
      url = "github:libjared/fromage";
      # Optional
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, fromage, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86-64_linux";
      };
    in {
      homeManagerConfigurations = {
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
              fromage.identityPaths = [ "~/.ssh/id_ed25519" ];
              fromage.file."vpn-password" = {
                src = ./secrets/ta.key.age;
                dest = ".config/vpn/ta.key";
              };
            }
          ];

        };
      };
    };
}
```
