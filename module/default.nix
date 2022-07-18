{ pkgs, config, options, lib, ... }:
with lib;

let
  cfg = config.fromage;

  ageBin = if cfg.isRage then "${cfg.pkg}/bin/rage" else "${cfg.pkg}/bin/age";

  identities = builtins.concatStringsSep " " (map (path: "-i ${path}") cfg.identityPaths);

  # Options for a secret file
  secretFile = types.submodule ({ name, ... }: {
    options = {
      src = mkOption {
        description = "Path primitive to the .age encrypted file";
        type = types.path;
      };

      dest = mkOption {
        description = "Path of the destination of the decrypted file, relative to $HOME";
        type = types.str;
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "Permissions mode of the decrypted file";
      };

      owner = mkOption {
        type = types.str;
        default = "$UID";
        description = "Owner of the decrypted file";
      };

      group = mkOption {
        type = types.str;
        default = "$(id -g)";
        description = "Group of the decrypted file";
      };
    };

    config = {
      # TODO: pick a better default
      decryptPath = mkDefault name;
    };
  });
in
{
  options.fromage = {
    file = mkOption {
      description = "Attrset of secret files";
      default = { };
      type = types.attrsOf secretFile;
    };

    pkg = mkOption {
      description = "(R)age package to use";
      default = pkgs.age;
      type = types.package;
    };

    isRage = mkOption {
      description = "Whether the binary that `pkg` provides is named \"rage\" instead of \"age\"";
      default = false;
      type = types.bool;
    };

    identityPaths = mkOption {
      description = "Absolute path to identity files used for age decryption. Must provide at least one path.";
      default = [ ];
      type = types.listOf types.str;
    };
  };

  config = mkIf (cfg.file != { }) (mkMerge [
    {
      assertions = [{
        assertion = cfg.identityPaths != [ ];
        message = "secret.identityPaths must be set.";
      }];

      # TODO: make activation script
    }
  ]);
}
