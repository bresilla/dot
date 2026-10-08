-- Direct manipulation has no animation. On release, match the finger's
-- speed and decelerate to rest, using the native compositor frame clock.
-- Android's FlingAnimationUtils uses this same distance/velocity handoff.
local M = { FLING = 450, TRAVEL = 16 }

function M.step(node, property, target, velocity, extent)
  local distance = target - (node[property] or 0)
  local remaining = math.abs(distance)
  local duration = math.min(300, 140 + 160 * math.sqrt(remaining / math.max(1, extent)))
  local speed = distance == 0 and 0 or math.max(0, (velocity or 0) * (distance > 0 and 1 or -1))
  if speed > 0 then duration = math.min(duration, 3000 * remaining / speed) end
  -- A cubic Hermite segment expressed as a Bezier: its initial derivative
  -- is the release velocity; its final derivative is zero. Bound the slope
  -- so even an extreme fling cannot overshoot a closed sheet or final page.
  local slope = remaining < .01 and 0 or math.min(3, speed * duration / (1000 * remaining))
  return { node=node, property=property, to=target, duration=duration,
    easing={1/3, slope/3, 2/3, 1} }
end

function M.fling(delta, velocity)
  return math.abs(delta) >= M.TRAVEL and math.abs(velocity or 0) >= M.FLING
end

return M
