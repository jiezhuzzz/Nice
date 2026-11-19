# Every agenix secret: name (decrypted to /run/agenix/<name>) → source file
# under secrets/ and scope.
{
  nice.secrets = {
    github-ssh-key = {
      file = "ssh/github.age";
      scope = "personal";
    };
    git-signing-key = {
      file = "ssh/git-signing.age";
      scope = "personal";
    };
    chameleon-ssh-key = {
      file = "ssh/chameleon.age";
      scope = "personal";
    };
    lab-ssh-key = {
      file = "ssh/lab.age";
      scope = "personal";
    };
    home-ssh-key = {
      file = "ssh/home.age";
      scope = "personal";
    };
    rclone-gdrive-token = {
      file = "rclone/gdrive.age";
      scope = "personal";
    };
    rclone-box-token = {
      file = "rclone/box.age";
      scope = "personal";
    };
    waqi-token = {
      file = "glance/waqi-token.age";
      scope = "homelab";
    };
    cloudflare-token = {
      file = "caddy/cloudflare-token.age";
      scope = "homelab";
    };
    litellm-provider-keys = {
      file = "llm/provider-keys.age";
      scope = "homelab";
    };
    xuewen-provider-keys = {
      file = "llm/provider-keys.age";
      scope = "homelab";
    };
    media-filer-provider-keys = {
      file = "llm/provider-keys.age";
      scope = "homelab";
    };
    searxng-secret-key = {
      file = "searxng/secret-key.age";
      scope = "homelab";
    };
    vaultwarden-admin-token = {
      file = "vaultwarden/admin-token.age";
      scope = "homelab";
    };
    miniflux-admin-credentials = {
      file = "miniflux/admin-credentials.age";
      scope = "homelab";
    };
    jie-password-hash = {
      file = "users/jie-password-hash.age";
      scope = "homelab";
    };
  };
}
