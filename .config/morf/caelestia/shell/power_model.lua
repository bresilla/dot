-- Power readings and profile actions shared by visual packages.
local morf=require("morf")
local services=require("services")
local M={}
M.PROFILES={
  {id="power-saver",icon="energy_savings_leaf",name="Power saver",hint="Longest battery"},
  {id="balanced",icon="balance",name="Balanced",hint="The default"},
  {id="performance",icon="rocket_launch",name="Performance",hint="Fastest, hottest"},
}
function M.new(active,open_battery)
  local model=require("battery_model").new {opened=active}
  model.key,model.PROFILES="power",M.PROFILES
  model.message=morf.signal("caelestia.power.message","")
  local cached={available=false,active="",degraded="",supported={}}
  local function profiles()
    if not active() then return cached end
    local u=services.upower
    local p=u and u.state and u.state.profiles
    local supported={}
    if p and p.list then
      for i=1,p.list:len() do supported[p.list:get(i).name]=true end
    end
    cached={available=p and p.available==true or false,active=p and p.active or "",
      degraded=p and p.degraded or "",supported=supported}
    return cached
  end
  function model.profile() return profiles().active end
  function model.profile_available() return profiles().available end
  function model.supports(id) local p=profiles() return p.available and p.supported[id]==true end
  function model.profile_note()
    local p=profiles()
    if not p.available then return "Power profile service is unavailable." end
    if p.degraded~="" then return "Performance limited: "..p.degraded end
    return "Choose how the system balances energy and speed."
  end
  function model.select(id)
    if not active() then return false end
    local known=false
    for _,p in ipairs(M.PROFILES) do if id==p.id then known=true break end end
    if not known or not model.supports(id) then return false end
    local dry=morf.env("CAELESTIA_DRY_RUN")
    if dry and dry~="" and dry~="0" then return false end
    if model.profile()==id then return true end
    local ok,result,err=pcall(services.upower.set_profile,id)
    model.message:set(ok and result and "" or tostring(ok and (err or "Could not change power mode.") or result))
    return ok and not not result
  end
  function model.open_battery() if active() then open_battery() end end
  function model.summary()
    local s,b=model.state(),model.battery()
    local seconds=b.status=="Discharging" and s.time_left or s.time_to_full
    local words=b.status or "No battery"
    if seconds and seconds>0 then
      local left=model.duration(seconds)
      words=words..(b.status=="Discharging" and (", "..left.." left") or (", full in "..left))
    end
    if b.power and b.power>.05 then words=words..("  ·  %.1f W"):format(b.power) end
    return words
  end
  model.FACTS={
    {key="health",name="Health",value=function() local b=model.battery() return b.health and ("%d%%"):format(math.floor(b.health+.5)) or "--" end},
    {key="limit",name="Charge limit",value=function()
      local b=model.battery()
      if not b.charge_limit then return "--" end
      return b.charge_start and ("%d–%d%%"):format(b.charge_start,b.charge_limit) or ("%d%%"):format(b.charge_limit)
    end},
    {key="mode",name="Charge mode",value=function() return model.battery().charge_mode or "--" end},
    {key="cycles",name="Cycles",value=function() local n=model.battery().cycles return n and tostring(n) or "--" end},
    {key="temperature",name="Temperature",value=function() local n=model.battery().temperature return n and ("%.1f °C"):format(n) or "--" end},
    {key="charger",name="Charger",value=function() return model.state().ac and "Plugged in" or "Unplugged" end},
  }
  morf.effect("caelestia.power.visibility",function() if not active() then model.message:set("") end end)
  return model
end
return M
