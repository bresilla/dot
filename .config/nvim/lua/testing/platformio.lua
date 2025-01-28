local M = {}

-- These environment variables match your Python plugin's ENV_VARIABLES.
M.ENV_VARIABLES = {
  "CPATH",
}

-- We store the original environment variables here so we can restore them.
M._original_env = {}

-- Helper function to run pio and parse the relevant JSON portion.
local function get_idestate(path)
  -- Build the command:
  --   pio -f -c vim run -t idedata -d {path}
  local cmd = {
    "pio", "-f", "-c", "vim", "run", "-t", "idedata", "-d", path
  }

  -- Execute the command and capture the output
  local handle = io.popen(table.concat(cmd, " "))
  local result = handle:read("*a")
  handle:close()

  -- The Python version scans each line for JSON braces.
  -- We'll replicate that approach here.
  local found_start = false
  local brace_count = 0
  local json_lines = {}

  for line in result:gmatch("[^\r\n]+") do
    if found_start and brace_count == 0 then
      break
    end
    if not found_start and line:match("^%{") then
      found_start = true
    end
    if found_start then
      table.insert(json_lines, line)
      -- Count braces to know when the JSON object ends
      local opens = select(2, line:gsub("%{", ""))
      local closes = select(2, line:gsub("%}", ""))
      brace_count = brace_count + opens - closes
    end
  end

  local json_str = table.concat(json_lines, "\n")
  -- Use Vim's built-in JSON decode
  return vim.fn.json_decode(json_str)
end

-------------------------------------------------------------------------------
-- Teardown: restore environment variables
-------------------------------------------------------------------------------
local function teardown_platformio_environment()
  for key, original_value in pairs(M._original_env) do
    -- If original_value is nil, you might want to clear the env var
    vim.fn.setenv(key, original_value or "")
  end
  -- Clear out the saved environment
  M._original_env = {}
end

-------------------------------------------------------------------------------
-- Setup: modify environment variables for PlatformIO
-------------------------------------------------------------------------------
local function setup_platformio_environment(args)
  -- The first argument is presumably the path to a file in the project.
  local file_path = args[1]
  if not file_path then
    vim.notify("No path provided to SetupPlatformioEnvironment", vim.log.levels.ERROR)
    return
  end

  local dir = vim.fn.fnamemodify(file_path, ":h")

  -- Fetch the idestate JSON data
  local idestate = get_idestate(dir)
  if not idestate then
    vim.notify("Failed to parse idestate from pio", vim.log.levels.ERROR)
    return
  end

  -- First tear down any existing environment from a previous call
  teardown_platformio_environment()

  -- Capture the original environment
  for _, varname in ipairs(M.ENV_VARIABLES) do
    M._original_env[varname] = vim.fn.getenv(varname)
  end

  -- Build up the new CPATH
  -- In your Python code: CPATH = ''.join(includes), etc.
  local includes = idestate.includes or {}
  local new_cpath = (M._original_env.CPATH or "")
  if #new_cpath > 0 and not new_cpath:match(":$") then
    -- Ensure we have a trailing colon if it's non-empty
    new_cpath = new_cpath .. ":"
  end
  new_cpath = new_cpath .. table.concat(includes, ":")

  -- Set environment
  vim.fn.setenv("CPATH", new_cpath)
end

-------------------------------------------------------------------------------
-- Public API: we expose `setup_plugin`, so the user can easily load commands
-------------------------------------------------------------------------------
function M.setup_plugin()
  -- Create user commands for Setup/Teardown
  vim.api.nvim_create_user_command(
    "SetupPlatformioEnvironment",
    function(opts)
      setup_platformio_environment(opts.fargs)
    end,
    { nargs = 1, complete = "file" }
  )

  vim.api.nvim_create_user_command(
    "TeardownPlatformioEnvironment",
    function(_)
      teardown_platformio_environment()
    end,
    {}
  )
end

return M
