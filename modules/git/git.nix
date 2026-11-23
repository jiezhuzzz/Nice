{nice, ...}: {
  den.aspects.git.homeManager = {pkgs, ...}: let
    allowedSigners = pkgs.writeText "allowed_signers" ''
      ${nice.user.email} ${nice.user.signingKey}
    '';
  in {
    programs.git = {
      enable = true;
      lfs.enable = true;
      attributes =
        ["* text=auto"]
        ++ map (extension: "*.${extension} binary") ["age" "png" "jpg" "jpeg" "gif" "ico" "webp" "avif" "heic" "psd" "drawio" "mp3" "mp4" "mov" "webm" "wav" "flac" "zip" "tar" "tar.gz" "tgz" "gz" "bz2" "xz" "zst" "7z" "rar" "exe" "dll" "so" "dylib" "a" "o" "pdb" "dmg" "iso" "pdf" "woff" "woff2" "ttf" "otf" "eot"]
        ++ [
          "*.md diff=markdown"
          "*.tex diff=tex"
          "*.py diff=python"
          "*.rb diff=ruby"
          "*.go diff=golang"
          "*.rs diff=rust"
          "*.css diff=css"
          "*.html diff=html"
        ];
      ignores = [
        ".DS_Store"
        ".codex/"
        ".claude/"
        ".agents/"
        ".direnv/"
        ".envrc.local"
      ];
      settings = {
        user.name = nice.user.fullName;
        user.email = nice.user.email;
        gpg.ssh.allowedSignersFile = toString allowedSigners;
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
        merge.conflictstyle = "zdiff3";
        diff.algorithm = "histogram";
        transfer.fsckobjects = true;
        fetch.fsckobjects = true;
        receive.fsckobjects = true;
        rebase.autosquash = true;
        rerere.enabled = true;
      };
    };
  };
}
