-- Optional host integration. Other platforms keep using their local Lule
-- cache; NixOS supplies a shared image and an unprivileged copy helper.
local morf=require("morf")
local M={}
local ok,raw=pcall(morf.fs.read,morf.env("MORF_WALLPAPER_CONFIG") or "/etc/morf/wallpaper.json")
local cfg
if ok and type(raw)=="string" then
  local valid,value=pcall(morf.json.decode,raw)
  if valid and type(value)=="table" and type(value.directory)=="string" then cfg=value end
end
function M.palette(role)
  if role=="greet" and cfg then return cfg.directory.."/colors.json" end
end
function M.publish(image,palette)
  if not cfg or not cfg.command or morf.env("USER")~=cfg.user or image=="" then return end
  local dry=morf.env("CAELESTIA_DRY_RUN")
  if dry and dry~="" and dry~="0" then return end
  morf.run({cfg.command,"publish","--image="..image,"--palette="..palette},
    {timeout_ms=10000,max_output=4096},function(result)
      if not result.ok then morf.log("warn","caelestia: could not share the wallpaper: "..(result.stderr or "")) end
    end)
end
return M
