{
  den.aspects.bash.homeManager = {
    config,
    lib,
    pkgs,
    ...
  }: let
    inherit (config.nice) appearance theme;

    exports = vars: lib.concatLines (lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") vars);

    faces = c: ''
      ble-face -s syntax_default           'fg=${c.text}'
      ble-face -s syntax_command           'fg=${c.blue}'
      ble-face -s syntax_quoted            'fg=${c.green}'
      ble-face -s syntax_quotation         'fg=${c.green}'
      ble-face -s syntax_expr              'fg=${c.peach}'
      ble-face -s syntax_error             'fg=${c.red},bg=${c.base}'
      ble-face -s syntax_varname           'fg=${c.flamingo}'
      ble-face -s syntax_delimiter         'fg=${c.overlay2}'
      ble-face -s syntax_param_expansion   'fg=${c.flamingo}'
      ble-face -s syntax_history_expansion 'fg=${c.yellow}'
      ble-face -s syntax_function_name     'fg=${c.blue}'
      ble-face -s syntax_comment           'fg=${c.overlay0}'
      ble-face -s syntax_glob              'fg=${c.peach}'
      ble-face -s syntax_brace             'fg=${c.mauve}'
      ble-face -s syntax_tilde             'fg=${c.pink}'
      ble-face -s syntax_document          'fg=${c.green}'
      ble-face -s syntax_document_begin    'fg=${c.peach}'

      ble-face -s command_builtin_dot 'fg=${c.sapphire}'
      ble-face -s command_builtin     'fg=${c.sapphire}'
      ble-face -s command_alias       'fg=${c.green}'
      ble-face -s command_function    'fg=${c.blue}'
      ble-face -s command_file        'fg=${c.blue}'
      ble-face -s command_keyword     'fg=${c.mauve}'
      ble-face -s command_jobs        'fg=${c.peach}'
      ble-face -s command_directory   'fg=${c.peach},underline'

      ble-face -s filename_directory  'fg=${c.blue},underline'
      ble-face -s filename_link       'fg=${c.teal},underline'
      ble-face -s filename_orphan     'fg=${c.red},underline'
      ble-face -s filename_executable 'fg=${c.green}'
      ble-face -s filename_url        'fg=${c.sapphire},underline'

      ble-face -s auto_complete       'fg=${c.overlay0}'
      ble-face -s region              'bg=${c.surface0}'
      ble-face -s region_target       'fg=${c.peach},bg=${c.surface1}'
      ble-face -s region_match        'fg=${c.peach},bg=${c.surface1}'
    '';
  in {
    programs.bash = {
      enable = true;
      # Bash has no way to hear of an appearance change, so each shell keeps
      # the one it started with. The terminal is asked before ble.sh loads:
      # once attached, ble.sh reads the terminal's replies itself.
      bashrcExtra = ''
        if [[ $- == *i* ]]; then
          source ${./terminal-appearance.bash}
          case $(terminal_appearance || echo "''${NICE_APPEARANCE-}") in
            light)
              ${exports appearance.exports.light}
              ;;
            *)
              ${exports appearance.exports.dark}
              ;;
          esac
          unset -f terminal_appearance
        fi

        source ${pkgs.blesh}/share/blesh/ble.sh --attach=prompt
      '';
    };

    xdg.configFile."blesh/init.sh".text = ''
      # Ghostty supports truecolor but does not always set COLORTERM.
      bleopt term_true_colors=semicolon

      case $NICE_APPEARANCE in
        light)
          ${faces theme.variants.light.palette}
          ;;
        *)
          ${faces theme.variants.dark.palette}
          ;;
      esac
    '';
  };
}
