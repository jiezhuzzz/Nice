{
  den.aspects.nixps.touchpad.nixos = {pkgs, ...}: {
    # The clickpad's physical button intermittently produces no POINTER_BUTTON
    # after boot: hid-generic races hid-multitouch for the device, and
    # re-binding to hid-multitouch restores it. The rebind is unconditional
    # because the bad state cannot be detected without a physical press.
    systemd.services.touchpad-rebind = {
      description = "Rebind the I2C-HID touchpad so its physical click works";
      wantedBy = ["multi-user.target"];
      after = ["systemd-udev-settle.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "touchpad-rebind" ''
          drv=/sys/bus/hid/drivers/hid-multitouch
          for dev in "$drv"/*:06CB:D01D.*; do
            [ -e "$dev" ] || continue
            id=$(basename "$dev")
            echo -n "$id" > "$drv/unbind" || true
            sleep 1
            echo -n "$id" > "$drv/bind" || true
          done
        '';
      };
    };
  };
}
