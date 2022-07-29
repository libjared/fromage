{ pkgs, config, options, lib, ... }:
with lib;

let
  cfg = config.fromage;

  ageBin = if cfg.isRage then "${cfg.pkg}/bin/rage" else "${cfg.pkg}/bin/age";

  fileList = attrValues (mapAttrs (k: v: { name = k; } // v) cfg.file);
  identityArgs = concatStringsSep " " (map (p: ''-i "${escapeShellArg p}"'') cfg.identityPaths);

  # relative path, ./.local/share/fromage
  secretOutPath =
    let
      # absolute path, /home/me/.local/share
      data = config.xdg.dataHome;
      # absolute path, /home/me
      home = config.home.homeDirectory;
      rel = removePrefix home data;
      result = "./${rel}/fromage";
    in
    (
      assert assertMsg (hasPrefix home data) "fromage requires 'config.xdg.dataHome' to be within 'config.home.homeDirectory'.";
      assert assertMsg (hasSuffix "/fromage" result) "fromage data directory is in an unexpected location.";
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

    config = { };
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

  config = mkIf (fileList != [ ]) (
    {
      assertions = [
        {
          assertion = cfg.identityPaths != [ ];
          message = "fromage.identityPaths must be set.";
        }
        {
          assertion = all (file: file.name != "") fileList;
          message = "fromage.file.<name> cannot be empty string.";
        }
        {
          assertion = all (file: !(hasPrefix "-" file.name)) fileList;
          message = "fromage.file.<name> cannot start with a HYPHEN-MINUS character.";
        }
        {
          assertion = all (file: !(hasInfix "/" file.name)) fileList;
          message = "fromage.file.<name> cannot contain forward-slash characters.";
        }
        {
          assertion = all (file: !(hasInfix "\n" file.name)) fileList;
          message = "fromage.file.<name> cannot contain newline characters.";
        }
      ];

      # 1. if a file with the secret's name exists in home-files, die.
      # 2. decrypt all .age files from the nix store, just to verify that the
      # provided identity will work on all secrets.
      # TODO: test names with spaces
      # TODO: fail/pass quickly, without decrypting the whole thing
      home.activation.verifySecrets = lib.hm.dag.entryBefore [ "writeBoundary" ] (
        let
          script = ''
            ${functions}

            $VERBOSE_ECHO "Checking for conflicts with other home-files"
            secretOutPath=${escapeShellArg secretOutPath}
            $VERBOSE_ECHO "Will output secrets to $secretOutPath"

            ${conflictCommands}
            ${decryptCommands}
          '';
          conflictCommands = concatStringsSep "\n" (map conflictCommand fileList);
          conflictCommand = { name, ... }:
            ''verifyConflict ${escapeShellArg name}'';
          decryptCommands = concatStringsSep "\n" (map decryptCommand fileList);
          decryptCommand = { name, src, ... }:
            ''verifyDecrypt ${escapeShellArgs [ name src ]}'';
          functions = ''
            function verifyConflict() {
              local name="$1"

              $VERBOSE_ECHO "Verifying no conflicts of secret named \"$name\""
              if [[ -e "$newGenPath/home-files/$secretOutPath/$name" ]]; then
                errorEcho "Fail: secret \"$name\" already is already managed by home.files"
                exit 1
              fi
            }

            function verifyDecrypt() {
              local name="$1"
              local src="$2"

              $VERBOSE_ECHO "Verifying decryption of secret named \"$name\""
              ${ageBin} --decrypt ${identityArgs} -o /dev/null "$src"
            }
          '';
        in
        script
      );

      # create fromage directory. decrypt each secret directly to fromage
      # directory, setting owner, group, and perms.
      home.activation.decryptSecrets = lib.hm.dag.entryAfter [ "writeBoundary" "onFilesChange" ] (
        let
          script = ''
            ${functions}

            secretOutPath=${escapeShellArg secretOutPath}
            $DRY_RUN_CMD mkdir $VERBOSE_ARG -p "$secretOutPath"
            ${decryptCommands}
          '';
          decryptCommands = concatStringsSep "\n" (map decryptCommand fileList);
          decryptCommand = { name, src, owner, group, mode, ... }:
            ''decrypt ${escapeShellArgs [ name src owner group mode ]}'';
          functions = ''
            function decrypt() {
              local name="$1"
              local src="$2"
              local owner="$${3-$UID}"
              local group="$${4-$(id -g)}"
              local mode="$5"

              $VERBOSE_ECHO "Decrypting secret named \"$name\""

              local dest="$secretOutPath/$name"

              $DRY_RUN_CMD ${ageBin} --decrypt ${identityArgs} -o "$dest" "$src"
              $DRY_RUN_CMD chown $VERBOSE_ARG "$owner":"$group" "$dest"
              $DRY_RUN_CMD chmod $VERBOSE_ARG "$mode" "$dest"
            }
          '';
        in
        script
      );
    }
  );
}
