#!/usr/bin/env bash

nix flake lock
nix build '.#homeConfigurations.me@machine.activationPackage' --override-input fromage '..'
