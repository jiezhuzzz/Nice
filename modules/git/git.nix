{nice, ...}: {
  den.aspects.git.homeManager = {pkgs, ...}: let
    allowedSigners = pkgs.writeText "allowed_signers" ''
      ${nice.user.email} ${nice.user.signingKey}
    '';
  in {
    programs.git = {
      enable = true;
      lfs.enable = true;
      attributes = [
        "* text=auto"
        "*.age binary"
        "*.png binary"
        "*.jpg binary"
        "*.jpeg binary"
        "*.gif binary"
        "*.ico binary"
        "*.webp binary"
        "*.avif binary"
        "*.heic binary"
        "*.psd binary"
        "*.drawio binary"
        "*.mp3 binary"
        "*.mp4 binary"
        "*.mov binary"
        "*.webm binary"
        "*.wav binary"
        "*.flac binary"
        "*.zip binary"
        "*.tar binary"
        "*.tar.gz binary"
        "*.tgz binary"
        "*.gz binary"
        "*.bz2 binary"
        "*.xz binary"
        "*.zst binary"
        "*.7z binary"
        "*.rar binary"
        "*.exe binary"
        "*.dll binary"
        "*.so binary"
        "*.dylib binary"
        "*.a binary"
        "*.o binary"
        "*.pdb binary"
        "*.dmg binary"
        "*.iso binary"
        "*.pdf binary"
        "*.woff binary"
        "*.woff2 binary"
        "*.ttf binary"
        "*.otf binary"
        "*.eot binary"
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
