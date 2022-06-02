{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.kitty;

  eitherStrBoolInt = with types; either str (either bool int);

  optionalPackage = opt:
    optional (opt != null && opt.package != null) opt.package;

  toKittyConfig = generators.toKeyValue {
    mkKeyValue = key: value:
      let
        value' =
          (if isBool value then lib.hm.booleans.yesNo else toString) value;
      in "${key} ${value'}";
  };

  toKittyKeybindings = generators.toKeyValue {
    mkKeyValue = key: command: "map ${key} ${command}";
  };

  toKittyEnv =
    generators.toKeyValue { mkKeyValue = name: value: "env ${name}=${value}"; };

in {
  options.programs.kitty = {
    enable = mkEnableOption "Kitty terminal emulator";

    package = mkOption {
      type = types.nullOr types.package;
      default = pkgs.kitty;
      defaultText = literalExpression "pkgs.kitty";
      description = ''
        Kitty package to install.
      '';
    };

    darwinLaunchOptions = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = null;
      description = "Command-line options to use when launched by Mac OS GUI";
      example = literalExpression ''
        [
          "--single-instance"
          "--directory=/tmp/my-dir"
          "--listen-on=unix:/tmp/my-socket"
        ]
      '';
    };

    settings = mkOption {
      type = types.attrsOf eitherStrBoolInt;
      default = { };
      example = literalExpression ''
        {
          scrollback_lines = 10000;
          enable_audio_bell = false;
          update_check_interval = 0;
        }
      '';
      description = ''
        Configuration written to
        <filename>$XDG_CONFIG_HOME/kitty/kitty.conf</filename>. See
        <link xlink:href="https://sw.kovidgoyal.net/kitty/conf.html" />
        for the documentation.
      '';
    };

    theme = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Apply a Kitty color theme. This option takes the friendly name of
        any theme given by the command <command>kitty +kitten themes</command>.
        See <link xlink:href="https://github.com/kovidgoyal/kitty-themes"/>
        for more details.
      '';
      example = "Space Gray Eighties";
    };

    font = mkOption {
      type = types.nullOr hm.types.fontType;
      default = null;
      description = "The font to use.";
    };

    keybindings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Mapping of keybindings to actions.";
      example = literalExpression ''
        {
          "ctrl+c" = "copy_or_interrupt";
          "ctrl+f>2" = "set_font_size 20";
        }
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables to set or override.";
      example = literalExpression ''
        {
          "LS_COLORS" = "1";
        }
      '';
    };

    extraConfig = mkOption {
      default = "";
      type = types.lines;
      description = "Additional configuration to add.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = (cfg.darwinLaunchOptions != null)
        -> pkgs.stdenv.hostPlatform.isDarwin;
      message = ''
        The 'programs.kitty.darwinLaunchOptions' option is only available on darwin.
      '';
    }];

    home.packages = optionalPackage cfg.package ++ optionalPackage cfg.font;

    xdg.configFile."kitty/kitty.conf" = {
      text = ''
        # Generated by Home Manager.
        # See https://sw.kovidgoyal.net/kitty/conf.html

        ${optionalString (cfg.font != null) ''
          font_family ${cfg.font.name}
          ${optionalString (cfg.font.size != null)
          "font_size ${toString cfg.font.size}"}
        ''}

        ${optionalString (cfg.theme != null) ''
          include ${pkgs.kitty-themes}/${
            (head (filter (x: x.name == cfg.theme) (builtins.fromJSON
              (builtins.readFile "${pkgs.kitty-themes}/themes.json")))).file
          }
        ''}

        ${toKittyConfig cfg.settings}

        ${toKittyKeybindings cfg.keybindings}

        ${toKittyEnv cfg.environment}

        ${cfg.extraConfig}
      '';
    } // optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      onChange = ''
        ${pkgs.procps}/bin/pkill -USR1 -u $USER kitty || true
      '';
    };

    xdg.configFile."kitty/macos-launch-services-cmdline" =
      mkIf (cfg.darwinLaunchOptions != null) {
        text = concatStringsSep " " cfg.darwinLaunchOptions;
      };
  };
}
