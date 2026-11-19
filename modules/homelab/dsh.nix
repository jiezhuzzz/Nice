# SAFETY: dsh has no authentication and its agent runs commands as jie, so the
# tailnet is the whole access control: never a LAN port or a non-loopback bind.
{
  den.aspects.homelab.dsh = {
    nixos = {
      nice.web.services.dsh = {
        port = 3080;
        order = 130;
        tile = {
          title = "dsh";
          icon = "di:deepseek";
        };
      };
    };

    user.linger = true;

    homeManager = {
      config,
      inputs',
      lib,
      osConfig,
      pkgs,
      ...
    }: let
      llmAgents = inputs'.llm-agents.packages;

      # `dsh plugin` forwards to pnpm inside the profile dir, so pnpm has to be on
      # dsh's PATH.
      dsh = pkgs.symlinkJoin {
        name = "dsh-${llmAgents.dsh.version}";
        paths = [llmAgents.dsh];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/dsh --prefix PATH : ${lib.makeBinPath [pkgs.pnpm]}
        '';
        inherit (llmAgents.dsh) meta;
      };

      inherit (osConfig.nice.web.services.dsh) port;
      vhost = osConfig.nice.web.services.dsh.host;

      # systemd user units read none of home.sessionVariables.
      dshEnv = {
        DSH_HOME = "${config.xdg.dataHome}/dsh";
        DSH_TELEMETRY_DISABLED = "1";
      };
    in {
      home.packages = [dsh];

      home.sessionVariables = dshEnv;

      systemd.user.services.dsh-web = {
        Unit = {
          Description = "dsh web — DeepSeek Harness browser UI";
          Documentation = ["https://github.com/deepseek-ai/deepseek-harness"];
          After = ["network.target"];
        };

        Service = {
          # --trusted-host is not optional behind caddy: dsh fences /api on the Host
          # and Origin it is reached through, so the forwarded `Host: dsh.jiezhu.me`
          # draws a 403 on every API call while / still serves the UI.
          ExecStart = lib.concatStringsSep " " [
            "${dsh}/bin/dsh web"
            "--host 127.0.0.1"
            "--port ${toString port}"
            "--trusted-host ${vhost}"
          ];
          WorkingDirectory = "%h";
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") dshEnv;
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install.WantedBy = ["default.target"];
      };
    };
  };
}
