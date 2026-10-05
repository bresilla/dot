{ config, lib, ... }:

let
  checkout = "${config.home.homeDirectory}/.dot";
  link = config.lib.file.mkOutOfStoreSymlink;
  # Home Manager also writes files inside fontconfig and systemd. Link their
  # entries individually so both sets of files can share those directories.
  configLinks = prefix: directory:
    lib.concatMapAttrs (name: type:
      let target = if prefix == "" then name else "${prefix}/${name}";
      in if type == "directory" && (lib.hasPrefix "fontconfig" target || lib.hasPrefix "systemd" target)
        then configLinks target (directory + "/${name}")
        else { ${target}.source = link "${checkout}/.config/${target}"; }
    ) (builtins.readDir directory);
  homeFiles = lib.filterAttrs (name: _: lib.hasPrefix "." name
    && !(builtins.elem name [ ".git" ".gitignore" ".config" ])) (builtins.readDir ../.);
in
{
  xdg.enable = true;
  xdg.configFile = configLinks "" ../.config;
  home.file = lib.mapAttrs (name: _: {
    source = link "${checkout}/${name}";
  }) homeFiles // {
    ".zshenv".text = ''
      export ZDOTDIR="$HOME/.config/zsh"
      export NVIM_LOG_FILE=/dev/null
    '';
  };
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" "${config.home.homeDirectory}/.local/sbin" ];
}
