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
        type = types.path;
        description = "Path primitive to the .age encrypted file";
      };

      dest = mkOption {
        type = types.str;
        description = "Path of the destination of the decrypted file, relative to $HOME";
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
      type = types.attrsOf secretFile;
      default = { };
      description = "Attrset of secret files";
    };

    pkg = mkOption {
      type = types.package;
      default = pkgs.age;
      description = "(R)age package to use";
    };

    isRage = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the binary that `pkg` provides is named \"rage\" instead of \"age\"";
    };

    identityPaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Absolute path to identity files used for age decryption. Must provide at least one path.";
    };
  };

  config = mkIf (cfg.file != { }) (mkMerge [
    {
      assertions = [{
        assertion = cfg.identityPaths != [ ];
        message = "fromage.identityPaths must be set.";
      }];

      # TODO: make activation script
    }
  ]);
}
