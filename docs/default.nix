{ pkgs, lib, nmdSrc }:

let
  nmd = import nmdSrc { inherit lib pkgs; };

  fromageModuleDocs = nmd.buildModulesDocs {
    modules = import ../module/modules.nix {
      inherit lib pkgs;
      check = false;
    };
    moduleRootPaths = [ ./.. ];
    mkModuleUrl = path:
      "https://github.com/libjared/fromage/blob/main/${path}#blob-path";
    channelName = "fromage";
    docBook.id = "fromage-options";
  };

  docs = nmd.buildDocBookDocs {
    pathName = "fromage";
    projectName = "fromage";
    modulesDocs = [ fromageModuleDocs ];
    documentsDirectory = ./.;
    documentType = "book";
    chunkToc = ''
      <toc>
        <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-fromage-manual">
          <?dbhtml filename="index.html"?>
          <d:tocentry linkend="ch-options">
            <?dbhtml filename="options.html"?>
          </d:tocentry>
        </d:tocentry>
      </toc>
    '';
  };
in
{
  manual = { inherit (docs) html htmlOpenTool; };
}
