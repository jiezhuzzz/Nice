let
  hhkb = 1278;

  escapeWhenAlone = description: condition: key: {
    inherit description;
    manipulators = [
      {
        type = "basic";
        conditions = [
          {
            type = condition;
            identifiers = [{vendor_id = hhkb;}];
          }
        ];
        from = {
          key_code = key;
          modifiers.optional = ["any"];
        };
        to = [
          {
            key_code = "left_control";
            lazy = true;
          }
        ];
        to_if_alone = [{key_code = "escape";}];
      }
    ];
  };
in {
  den.aspects.macos.karabiner.homeManager = {
    xdg.configFile."karabiner/karabiner.json" = {
      force = true;
      text = builtins.toJSON {
        global = {
          show_in_menu_bar = false;
        };
        profiles = [
          {
            name = "Default";
            selected = true;
            complex_modifications.rules = [
              (escapeWhenAlone "Caps Lock → Escape (alone) / Control (held) [any keyboard except HHKB]" "device_unless" "caps_lock")
              (escapeWhenAlone "Control → Escape (alone) / Control (held) [HHKB]" "device_if" "left_control")
            ];
            devices = [
              {
                identifiers = {
                  is_keyboard = true;
                  is_pointing_device = true;
                  vendor_id = hhkb;
                  product_id = 22;
                };
                ignore = false;
              }
              {
                # Lofree Flow2 over Bluetooth LE exposes no usable vendor/product
                # id, so it is matched by address.
                identifiers = {
                  device_address = "c8-01-29-28-fe-5e";
                  is_keyboard = true;
                  is_pointing_device = true;
                };
                ignore = false;
                treat_as_built_in_keyboard = true;
              }
              {
                # Lofree Flow2 wired: Karabiner ignores this composite
                # keyboard+pointing HID interface by default.
                identifiers = {
                  vendor_id = 14477;
                  product_id = 40;
                  is_keyboard = true;
                  is_pointing_device = true;
                };
                ignore = false;
                treat_as_built_in_keyboard = true;
              }
            ];
            virtual_hid_keyboard = {
              country_code = 0;
              keyboard_type_v2 = "ansi";
            };
          }
        ];
      };
    };
  };
}
