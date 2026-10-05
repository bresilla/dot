-- The launcher's calculator: arithmetic in pure Lua, never `load`.
--
-- A small recursive-descent parser over numbers (1, 2.5, .5, 1e3, 0x1f),
-- + - * / % ^ (right-associative, above unary minus: -2^2 = -4),
-- parentheses, the constants pi, tau and e, and the functions sqrt, cbrt,
-- abs, floor, ceil, round, exp, ln, log (base 10, or log(x, base)), log2,
-- sin, cos, tan, asin, acos, atan (radians), min, max. Implicit
-- multiplication is not guessed at. It returns a value or an error message,
-- and the expression written back out the way the reference shows it:
-- spaced, with a nested operation in parentheses ("2 + (3 * 4)").
--
-- Nothing a person types can run code, read a file or loop: the input is
-- read once, left to right, and the depth of nesting is capped.

local M = {}

local MAX_DEPTH = 64
local MAX_LENGTH = 512

local CONSTANTS = { pi = math.pi, tau = 2 * math.pi, e = math.exp(1) }

local function log(x, base)
  if base then return math.log(x) / math.log(base) end
  return math.log(x, 10)
end

local FUNCTIONS = {
  sqrt = { 1, math.sqrt }, abs = { 1, math.abs }, floor = { 1, math.floor }, ceil = { 1, math.ceil },
  round = { 1, function(x) return math.floor(x + 0.5) end }, exp = { 1, math.exp },
  ln = { 1, math.log }, log = { 1, log, 2 }, log2 = { 1, function(x) return math.log(x, 2) end },
  sin = { 1, math.sin }, cos = { 1, math.cos }, tan = { 1, math.tan },
  asin = { 1, math.asin }, acos = { 1, math.acos }, atan = { 1, math.atan, 2 },
  cbrt = { 1, function(x) return x < 0 and -((-x) ^ (1 / 3)) or x ^ (1 / 3) end },
  min = { 1, math.min, 16 }, max = { 1, math.max, 16 },
}

-- ---------------------------------------------------------------- tokens --

local function tokens(text)
  local out, i = {}, 1
  local n = #text
  while i <= n do
    local c = text:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif text:match("^0[xX]%x", i) then
      local hex = text:match("^0[xX](%x+)", i)
      out[#out + 1] = { kind = "number", value = tonumber(hex, 16), text = "0x" .. hex }
      i = i + 2 + #hex
    elseif c:match("[%d.]") then
      local num = text:match("^%d*%.?%d*[eE][%+%-]?%d+", i) or text:match("^%d*%.?%d*", i)
      local value = tonumber(num)
      if not value then return nil, "unexpected " .. num end
      out[#out + 1] = { kind = "number", value = value, text = num }
      i = i + #num
    elseif c:match("[%a_]") then
      local word = text:match("^[%a_][%w_]*", i)
      out[#out + 1] = { kind = "name", value = word:lower() }
      i = i + #word
    elseif c:match("[%+%-%*/%%%^%(%),]") or text:sub(i, i + 1) == "**" then
      if text:sub(i, i + 1) == "**" then
        out[#out + 1] = { kind = "op", value = "^" }
        i = i + 2
      else
        local ops = { ["×"] = "*", ["÷"] = "/" }
        out[#out + 1] = { kind = "op", value = ops[c] or c }
        i = i + 1
      end
    elseif text:sub(i, i + 1) == "×" or text:sub(i, i + 1) == "÷" then
      out[#out + 1] = { kind = "op", value = text:sub(i, i + 1) == "×" and "*" or "/" }
      i = i + 2
    else
      return nil, "unexpected " .. c
    end
  end
  return out
end

-- ---------------------------------------------------------------- parser --

-- expression := term (("+" | "-") term)*
-- term       := unary (("*" | "/" | "%") unary)*
-- unary      := ("-" | "+") unary | power
-- power      := atom ("^" unary)?
-- atom       := number | constant | name "(" args ")" | "(" expression ")"
local function parse(list)
  local pos, depth = 1, 0
  local function peek() return list[pos] end
  local function take() pos = pos + 1 return list[pos - 1] end
  local function is(kind, value)
    local t = list[pos]
    return t and t.kind == kind and (value == nil or t.value == value)
  end

  local expression
  local function deeper()
    depth = depth + 1
    if depth > MAX_DEPTH then error({ calc = "too deeply nested" }) end
  end

  local function atom()
    local t = take()
    if not t then error({ calc = "unfinished" }) end
    if t.kind == "number" then return { "num", t.value, t.text } end
    if t.kind == "op" and t.value == "(" then
      deeper()
      local inner = expression()
      depth = depth - 1
      if not is("op", ")") then error({ calc = "missing )" }) end
      take()
      return { "group", inner }
    end
    if t.kind == "name" then
      if is("op", "(") then
        local f = FUNCTIONS[t.value]
        if not f then error({ calc = "no function " .. t.value }) end
        take()
        deeper()
        local args = { expression() }
        while is("op", ",") do
          take()
          args[#args + 1] = expression()
        end
        depth = depth - 1
        if not is("op", ")") then error({ calc = "missing )" }) end
        take()
        if #args < f[1] or #args > (f[3] or f[1]) then error({ calc = t.value .. ": wrong number of arguments" }) end
        return { "call", t.value, args }
      end
      if CONSTANTS[t.value] then return { "const", t.value } end
      error({ calc = "unknown " .. t.value })
    end
    error({ calc = "unexpected " .. tostring(t.value) })
  end

  local unary
  local function power()
    local base = atom()
    if is("op", "^") then
      take()
      deeper()
      local exponent = unary()
      depth = depth - 1
      return { "bin", "^", base, exponent }
    end
    return base
  end

  function unary()
    if is("op", "-") or is("op", "+") then
      local sign = take().value
      deeper()
      local operand = unary()
      depth = depth - 1
      if sign == "+" then return operand end
      return { "neg", operand }
    end
    return power()
  end

  local function term()
    local left = unary()
    while is("op", "*") or is("op", "/") or is("op", "%") do
      local op = take().value
      left = { "bin", op, left, unary() }
    end
    return left
  end

  function expression()
    local left = term()
    while is("op", "+") or is("op", "-") do
      local op = take().value
      left = { "bin", op, left, term() }
    end
    return left
  end

  local tree = expression()
  if peek() then error({ calc = "unexpected " .. tostring(peek().value) }) end
  return tree
end

-- ------------------------------------------------------------- evaluate --

local function eval(node)
  local kind = node[1]
  if kind == "num" then return node[2] end
  if kind == "const" then return CONSTANTS[node[2]] end
  if kind == "group" then return eval(node[2]) end
  if kind == "neg" then return -eval(node[2]) end
  if kind == "call" then
    local args = {}
    for i, a in ipairs(node[3]) do args[i] = eval(a) end
    return FUNCTIONS[node[2]][2](table.unpack(args))
  end
  local a, b = eval(node[3]), eval(node[4])
  local op = node[2]
  if op == "+" then return a + b end
  if op == "-" then return a - b end
  if op == "*" then return a * b end
  if op == "/" then
    if b == 0 then error({ calc = "division by zero" }) end
    return a / b
  end
  if op == "%" then
    if b == 0 then error({ calc = "division by zero" }) end
    return math.fmod(a, b)
  end
  return a ^ b
end

-- ---------------------------------------------------------------- write --

local function write(node, parent)
  local kind = node[1]
  if kind == "num" then return node[3] end
  if kind == "const" then return node[2] == "pi" and "π" or node[2] end
  if kind == "group" then return write(node[2], parent) end
  if kind == "neg" then return "-" .. write(node[2], "neg") end
  if kind == "call" then
    local args = {}
    for i, a in ipairs(node[3]) do args[i] = write(a) end
    return node[2] .. "(" .. table.concat(args, ", ") .. ")"
  end
  local text = write(node[3], node) .. " " .. node[2] .. " " .. write(node[4], node)
  -- An operation inside another is bracketed, whatever precedence says.
  if parent and parent ~= "neg" and parent[1] == "bin" then return "(" .. text .. ")" end
  if parent == "neg" then return "(" .. text .. ")" end
  return text
end

--- A number as the calculator shows it: an integer bare, otherwise up to
--- twelve significant digits without trailing zeros.
function M.format(value)
  if value ~= value then return "undefined" end
  if value == math.huge then return "∞" end
  if value == -math.huge then return "-∞" end
  if value == math.floor(value) and math.abs(value) < 1e15 then return ("%.0f"):format(value) end
  local text = ("%.12g"):format(value)
  if text:find("e") then return text end
  return (text:gsub("(%..-)0+$", "%1"):gsub("%.$", ""))
end

--- `value, shown` for an expression -- `shown` is "2 + (3 * 4) = 14" --
--- or `nil, why`.
function M.evaluate(text)
  text = tostring(text or "")
  if #text > MAX_LENGTH then return nil, "too long" end
  if text:match("^%s*$") then return nil, "empty" end
  local list, err = tokens(text)
  if not list then return nil, err end
  local ok, tree = pcall(parse, list)
  if not ok then return nil, type(tree) == "table" and tree.calc or tostring(tree) end
  local ok2, value = pcall(eval, tree)
  if not ok2 then return nil, type(value) == "table" and value.calc or tostring(value) end
  if type(value) ~= "number" then return nil, "not a number" end
  local result = M.format(value)
  return value, write(tree) .. " = " .. result, result
end

return M
