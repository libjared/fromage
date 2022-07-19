{ pkgs, config, options, lib, ... }:
with lib;

let
  cfg = config.fromage;

  ageBin = if cfg.isRage then "${cfg.pkg}/bin/rage" else "${cfg.pkg}/bin/age";

  # TODO: sort? or do attrSets have stable order?
  fileList = attrValues (mapAttrs (k: v: { name = k; } // v) cfg.file);
  identityArgs = concatStringsSep " " (map (p: ''-i "${p}"'') cfg.identityPaths);

  # relative path, ./.local/share/fromage
  secretOutPath = let
    # absolute path, /home/me/.local/share
    data = config.xdg.dataHome;
    # absolute path, /home/me
    home = config.home.homeDirectory;
    valid = hasPrefix home data;
    rel = removePrefix home data;
    result = "./${rel}/fromage";
  in (
    assert assertMsg valid "fromage requires 'config.xdg.dataHome' to be within 'config.home.homeDirectory'.";
    result
  );

  # Options for a secret file
  secretFile = types.submodule ({ name, ... }: {
    options = {
      src = mkOption {
        type = types.path;
        description = "Path primitive to the .age encrypted file";
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "Permissions mode of the decrypted file";
      };

      owner = mkOption {
        type = types.str;
        default = "";
        description = "Owner of the decrypted file. If set to an empty string, substitute the value of $UID at activation time.";
      };

      group = mkOption {
        type = types.str;
        default = "";
        description = "Group of the decrypted file. If set to an empty string, substitute the value of $(id -g) at activation time.";
      };
    };

    config = {};
  });
in
{
  options.fromage = {
    file = mkOption {
      type = types.attrsOf secretFile;
      default = { };
      description = "Attrset of secret files. The <name> is the filename of the decrypted file, which will be saved in ${config.xdg.dataHome}/fromage";
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

      # FIXME: disallow names with newlines, forward-slashes, or empty
      # TODO: test names with spaces, or start with dashes
      # FIXME: don't run steps when fileList is empty
      # FIXME: assert no duplicate names
      # TODO: when not verbose, make the decryption fail fast
      home.activation.verifySecrets = lib.hm.dag.entryBefore ["writeBoundary"] (
        let
          # if a file with the secret's name exists in home-files, die.
          conflictCommand = { name, ... }: ''
            if [[ -e "$newGenPath/home-files/${secretOutPath}/${name}" ]]; then
              errorEcho "Fail: secret ${name} already is already managed by home.files"
              exit 1
            fi
          '';
          conflictCommands = concatStringsSep "\n" (map conflictCommand fileList);

          # decrypt all .age files from the nix store, just to verify that the
          # provided identity will work on all secrets.
          # TODO: if in verbose mode:
          # for each secret, print if a file with the secret's name exists in $HOME, and if so, whether the contents match
          decryptCommand = { name, src, ... }: ''
            $VERBOSE_RUN _i 'Verifying decryption of secret named "${name}"'
            ${ageBin} --decrypt ${identityArgs} -o /dev/null "${src}"
          '';
          decryptCommands = concatStringsSep "\n" (map decryptCommand fileList);

          script = ''
            $VERBOSE_RUN _i "Checking for conflicts with other home-files"
            ${conflictCommands}

            ${decryptCommands}
          '';
        in script
      );

      # for each secret s:
      # decrypt s to temp file t.
      # if dest d exists, compare d with t. if they match, remove d.
      # mv t to d with the numbered backup.
      # set owner, group, and perms.
      # TODO: clean up old secrets and dirs
      # TODO: clean up tmp
      # TODO: support dry-run and verbose
      home.activation.decryptSecrets = lib.hm.dag.entryAfter ["writeBoundary" "onFilesChange"] (
        let
          decryptCommand = { name, src, owner, group, mode, ... }: let
            setOwner =
              if owner == "" then ''
                dOwner="$UID"
              '' else toShellVar "dOwner" owner;
            setGroup =
              if group == "" then ''
                dGroup="$(id -g)"
              '' else toShellVar "dGroup" group;
          in ''
            $VERBOSE_RUN _i 'Decrypting secret named "${name}"'
            t="$decryptedStore/${name}"
            d="${secretOutPath}/${name}"
            $DRY_RUN_CMD ${ageBin} --decrypt ${identityArgs} -o "$t" "${src}"
            if [[ -r "$d" ]]; then
              if cmp -s "$d" "$t"; then
                $DRY_RUN_CMD echo rm --verbose --interactive=never "$d"
              fi
            fi
            $DRY_RUN_CMD mv --backup=numbered "$t" "$d"
            ${setOwner}
            ${setGroup}
            ${toShellVar "dMode" mode}
            $DRY_RUN_CMD chown "$dOwner":"$dGroup" "$d"
            $DRY_RUN_CMD chmod "$dMode" "$d"
          '';
          decryptCommands = concatStringsSep "\n" (map decryptCommand fileList);
        in ''
          $DRY_RUN_CMD mkdir -p "${secretOutPath}"
          decryptedStore=$(mktemp -d --suffix "-fromage")
          ${decryptCommands}
        ''
      );
    }
  ]);
}
