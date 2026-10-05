-- PhaseArt / lines.vert geometry adapted from Tsugumori (MIT).
-- See LICENSE-Tsugumori. Fixed geometry, animated progress, wallpaper ink.
-- No clock uniform: after the presentation completes this shader is idle.
local morf = require("morf")
local ui = require("morf.ui")
local M = {}
function M.ramp(p, a, b)
  local x = math.max(0, math.min(1, (p - a) / (b - a)))
  return x * x * (3 - 2 * x)
end
morf.shader("tsugumori-phase", {
  kind = "surface", data = { state = 11 },
  fragment = [[
    function hash(x, y, seed)
      local n = (u32(x + 1.0) * u32(374761393)) ~ (u32(y + 1.0) * u32(668265263)) ~ (u32(seed + 1.0) * u32(1442695041))
      n = (n ~ (n >> u32(13))) * u32(1274126177)
      return f32(n ~ (n >> u32(16))) / 4294967296.0
    end
    function ramp(p, a, b)
      local x = clamp((p - a) / (b - a), 0.0, 1.0)
      return x * x * (3.0 - 2.0 * x)
    end
    function split(key, depth, p)
      local threshold = 0.58
      if depth < 0.5 then threshold = 0.19 end
      if depth > 1.5 or hash(key, depth, 34.0) <= threshold then return 0.0 end
      return ramp(p, 0.14 + depth * 0.15 + hash(key, 1.0, 2.0) * 0.08, 0.55 + depth * 0.15)
    end
    function line(q, a, b, width)
      local v = b - a
      local t = clamp(dot(q-a, v) / max(dot(v,v), 0.000001), 0.0, 1.0)
      return 1.0 - smoothstep(width * 0.5 - 0.5, width * 0.5 + 0.5, length(q-a-v*t))
    end
    function stroke(q, a, b, c, fraction, width)
      local first = length(b-a)
      local second = length(c-b)
      local drawn = (first + second) * fraction
      local result = 0.0
      if drawn > 0.001 then result = line(q, a, mix(a,b,clamp(drawn/first,0.0,1.0)),width) end
      if drawn > first + 0.001 then result = max(result, line(q,b,mix(b,c,clamp((drawn-first)/max(second,0.00001),0.0,1.0)),width)) end
      return result
    end
    function glyph(point, size, key, depth, p, mode, count, pixel)
      local q = point
      local angle = floor(hash(key,depth,27.0)*4.0)
      if angle < 0.5 then q = q
      elseif angle < 1.5 then q = vec2(q.y,0.0-q.x)
      elseif angle < 2.5 then q = 0.0-q
      else q = vec2(0.0-q.y,q.x) end
      local bend = (1.0-ramp(p,0.09+hash(key,depth,5.0)*0.14,0.65+depth*0.10))*(hash(key,depth,6.0)-0.5)*0.34
      local ink = 0.0
      local width = 1.0
      if mode > 0.5 then width = max(1.0,size*0.031*pixel) end
      local paths = 4.0
      if mode > 0.5 then paths = 5.0 end
      for path = 0, paths do
        local a = vec2(-0.36,-0.39)
        local b = vec2(-0.36,0.33)
        local c = vec2(-0.12,0.33)
        if path == 1 then a=vec2(-0.36,-0.12); b=vec2(0.32,-0.12); c=vec2(0.32,0.11)
        elseif path == 2 then a=vec2(0.02+bend,-0.40); b=vec2(0.02+bend,0.35); c=b
        elseif path == 3 then a=vec2(-0.12,0.12); b=vec2(0.35,0.12); c=vec2(0.35,0.40)
        elseif path == 4 then a=vec2(0.22,-0.40); b=vec2(0.40,-0.40); c=vec2(0.40,-0.24) end
        local order = hash(key,f32(path),13.0)
        local fraction = ramp(p,0.02+order*0.20,0.40+order*0.26)
        if mode > 0.5 then
          local bend = (hash(key,depth,17.0)-0.5)*0.26
          local wave = sin(count*0.24+key)*0.075
          if path == 0 then a=vec2(-0.35,-0.40); b=vec2(-0.35,0.34); c=vec2(-0.14,0.34)
          elseif path == 1 then a=vec2(-0.35,-0.13); b=vec2(0.31,-0.13); c=vec2(0.31,0.12)
          elseif path == 2 then a=vec2(0.02+bend,-0.39); b=vec2(0.02+bend,0.34); c=b
          elseif path == 3 then a=vec2(-0.12,0.12+wave); b=vec2(0.35,0.12+wave); c=vec2(0.35,0.39)
          elseif path == 4 then a=vec2(-0.40,-0.39); b=vec2(-0.20,-0.39); c=b
          else a=vec2(0.22,-0.40); b=vec2(0.40,-0.40); c=vec2(0.40,-0.25) end
          order=hash(key,f32(path),93.0)
          fraction=ramp(ramp(p,0.22,0.73),order*0.26,0.58+order*0.42)
        end
        ink = max(ink,stroke(q*pixel,a*size*pixel,b*size*pixel,c*size*pixel,fraction,width))
      end
      return ink
    end
    function fragment(uv, time, resolution)
      local p = state[0]
      local accent = vec3(state[1],state[2],state[3])
      local muted = vec3(state[4],state[5],state[6])
      local mode = state[7]
      local count = state[8]
      local extent = vec2(state[9],state[10])
      local size = 84.0
      local columns = ceil(extent.x / size)
      local rows = ceil(extent.y / size)
      local offset = (extent - vec2(columns,rows)*size)*0.5
      local point = uv*extent
      local pixel = 1.0
      if mode > 0.5 then
        size=78.0; columns=3.0; rows=3.0; offset=vec2(9.0)
        pixel=extent.x/252.0; point=uv*252.0
      end
      local cell = clamp(floor((point-offset)/size),vec2(0.0),vec2(columns-1.0,rows-1.0))
      local root = offset+(cell+vec2(0.5))*size
      local rootKey = cell.y*columns+cell.x+1.0
      local color = vec3(0.0)
      local coverage = 0.0
      local nodes = 20.0
      if mode > 0.5 then nodes=84.0 end
      for node = 0, nodes do
        local depth = 0.0
        local route0 = 0.0
        local route1 = 0.0
        local route2 = 0.0
        if node >= 21 then depth=3.0; route0=floor((node-21.0)/16.0); route1=floor(((node-21.0)%16.0)/4.0); route2=(node-21.0)%4.0
        elseif node >= 5 then depth=2.0; route0=floor((node-5.0)/4.0); route1=(node-5.0)%4.0
        elseif node >= 1 then depth=1.0; route0=node-1.0 end
        local key = rootKey
        local center = root
        local finalCenter = root
        local side = size
        local finalSize = size
        local alpha = 1.0
        local threshold = -4.0
        for d = 0, 2 do
          if d < depth then
            local child = route0
            if d == 1 then child=route1 elseif d == 2 then child=route2 end
            local direction = vec2(-1.0,-1.0)
            if child % 2 == 1 then direction=vec2(1.0,direction.y) end
            if child >= 2 then direction=vec2(direction.x,1.0) end
            local s = split(key,f32(d),p)
            if mode > 0.5 then s=ramp(count,threshold,threshold+2.2) end
            finalCenter=finalCenter+direction*finalSize*0.25
            finalSize=finalSize*0.5
            if mode > 0.5 then
              center=center+direction*side*0.25*s; side=side*0.5
              if d == 0 then threshold=-2.0+hash(key*5.0+child+1.0,f32(d),7.0)*25.0
              else threshold=threshold+6.0+hash(key*5.0+child+1.0,f32(d),7.0)*16.0 end
            else center=mix(center,finalCenter,s); side=mix(side*0.72,finalSize,s) end
            alpha=alpha*s
            key=key*5.0+f32(child)+1.0
          end
        end
        local division = split(key,f32(depth),p)
        if mode > 0.5 then
          division=0.0
          if depth < 3.0 then division=ramp(count,threshold,threshold+2.2) end
        end
        alpha=alpha*(1.0-division)*ramp(p,0.0,0.14)
        local q = point-center
        if alpha > 0.006 and max(abs(q.x),abs(q.y)) < side*0.59 then
          local tint = muted
          local strength = 0.47
          if hash(key,f32(depth),81.0)>0.968 then tint=accent; strength=0.82 end
          if mode > 0.5 then
            tint=mix(muted,accent,ramp(count*0.075+0.23-hash(key,f32(depth),61.0),0.0,0.2)); strength=1.0
          end
          local a = glyph(q,side,key,f32(depth),p,mode,count,pixel)*alpha*strength
          color=color+tint*a*(1.0-coverage)
          coverage=coverage+a*(1.0-coverage)
        end
      end
      return vec4(color/max(coverage,0.000001),coverage)
    end
  ]],
})
function M.field(C, progress, props, count)
  props.shader = "tsugumori-phase"
  local node = ui.Rect(props)
  local function update()
    local a, b = C.primary, C.outline
    morf.shader_data(node,"state",{progress(),a.r,a.g,a.b,b.r,b.g,b.b,count and 1 or 0,count and count() or 0,node.width,node.height})
  end
  morf.effect("tsugumori.phase." .. (props.id or "field"), update, { owner = node })
  -- Scene animations intentionally do not invalidate Lua bindings every
  -- frame. Upload only these eleven uniforms while a transition is active.
  local remaining = 0
  local timer
  timer = ui.Timer { interval = 16, ["repeat"] = true, running = false,
    on_triggered = function()
      update()
      remaining = remaining - 16
      if remaining <= 0 then timer.running = false end
    end }
  ui.reparent(timer, node)
  return node, function(ms)
    remaining = math.max(remaining, ms + 32)
    update()
    timer.running = true
  end
end
return M
