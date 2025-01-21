local M = {}
-- Create a Lua function that checks how many listed buffers are open
-- If more than one, delete the current buffer
-- If only one, quit Neovim
local function smart_quit()
  -- Get the list of *listed* buffers
  local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })
  if #listed_buffers > 1 then
    -- If more than one buffer, just delete the current one
    vim.cmd('bdelete')
  else
    -- If it's the last buffer, then quit
    vim.cmd('qa')
  end
end

-- Create a user command `Q` that calls our function
vim.api.nvim_create_user_command('Q', smart_quit, {})

-- Make :q and :qa call the new command :Q
-- So whenever you type :q or :qa, it will invoke `smart_quit()`.
vim.cmd([[
  cabbrev q  Q
  cabbrev qa Q
]])

return M

