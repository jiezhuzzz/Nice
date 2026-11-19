{
  openssh,
  writeShellApplication,
}:
writeShellApplication {
  name = "sync-rclone-tokens";
  runtimeInputs = [openssh];
  text = builtins.readFile ./sync-rclone-tokens.sh;
  meta.description = "Copy this machine's agenix-decrypted rclone tokens to hosts without system agenix";
}
