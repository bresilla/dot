local M = {}

local function smart_quit()
  local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })
  if #listed_buffers > 1 then
    vim.cmd('bdelete')
  else
    vim.cmd('qa')
  end
end

local function smart_quit_n_save()
  local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })
  vim.cmd('w')
  if #listed_buffers > 1 then
    vim.cmd('bdelete')
  else
    vim.cmd('qa')
  end
end

-- Create a user command `Q` that calls our function
vim.api.nvim_create_user_command('Q', smart_quit, {})
vim.api.nvim_create_user_command('QW', smart_quit_n_save, {})

-- Make :q and :qa call the new command :Q
-- So whenever you type :q or :qw, it will invoke `smart_quit()`.
vim.cmd([[
  cabbrev q  Q
  cabbrev qw QW
]])

return M

