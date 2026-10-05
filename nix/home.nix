{ config, ... }:

let
  checkout = "${config.home.homeDirectory}/.dot";
  link = config.lib.file.mkOutOfStoreSymlink;
in
{
  xdg.enable = true;
  xdg.configFile = {
    kitty.source = link "${checkout}/.config/kitty";
    nvim.source = link "${checkout}/.config/nvim";
    oslo.source = link "${checkout}/.config/oslo";
  };
}
