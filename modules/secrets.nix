{lib, ...}: let
  scoped = scope: lib.mapAttrs (_: file: {inherit file scope;});
in {
  nice.secrets =
    scoped "personal" {
      github-ssh-key = "ssh/github.age";
      git-signing-key = "ssh/git-signing.age";
      chameleon-ssh-key = "ssh/chameleon.age";
      lab-ssh-key = "ssh/lab.age";
      home-ssh-key = "ssh/home.age";
      rclone-gdrive-token = "rclone/gdrive.age";
      rclone-box-token = "rclone/box.age";
    }
    // scoped "homelab" {
      waqi-token = "glance/waqi-token.age";
      cloudflare-token = "caddy/cloudflare-token.age";
      litellm-provider-keys = "llm/provider-keys.age";
      xuewen-provider-keys = "llm/provider-keys.age";
      media-filer-provider-keys = "llm/provider-keys.age";
      searxng-secret-key = "searxng/secret-key.age";
      vaultwarden-admin-token = "vaultwarden/admin-token.age";
      miniflux-admin-credentials = "miniflux/admin-credentials.age";
      jie-password-hash = "users/jie-password-hash.age";
    };
}
