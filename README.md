# fromage - [age](https://github.com/FiloSottile/age) secrets for Nix home-manager, decrypted upon profile activation

`fromage` is a module for [home-manager](https://github.com/nix-community/home-manager) that enables decryption of secrets when a home-manager profile is activated.

It is based on the [homeage](https://github.com/jordanisaacs/homeage) project.

## Features

- Filetype-agnostic declarative secrets can be used inside your home-manager flakes.
- Secrets are decrypted with an activation step, integrating seamlessly with home-manager.
- Decryption uses the typical age workflow with ssh or age keys.
- Extremely small, so inspect the source yourself!

## Overview

Secrets are encrypted by some external identity, and stored as an .age file in your home-manager flake.

**Build**: Encrypted secrets are copied to the Nix store.

**Pre-writeBoundary**: Before activating the profile, home-manager verifies the secrets can be decrypted with the provided identity. Additionally, it verifies that no secret file conflicts with a file that home-manager already manages.

**Post-writeBoundary**: After home-manager activates the rest of the profile, it decrypts all secrets and writes them to `~/.local/share/fromage/`. Secret files are re-decrypted each time a generation with this module is activated.

**Runtime**: Secrets remain unencrypted in that directory.

## Roadmap

- [ ] Support passphrases
- [ ] Add more tests

## Getting started

### Nix Flakes

The below example is mostly home-manager boilerplate. In a nutshell, add `fromage.homeManagerModules.fromage` to the list of modules and set the proper options.

```nix
{
  inputs = {
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    fromage = {
      url = "github:libjared/fromage";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, fromage, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
    in
    {
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
              fromage.identityPaths = [ "/home/me/.ssh/id_ed25519" ];
              fromage.file."ta.key" = {
                src = ./secrets/mytakey.age;
              };
              # this will create ~/.local/share/fromage/ta.key
            }
          ];
        };
      };
    };
}
```
