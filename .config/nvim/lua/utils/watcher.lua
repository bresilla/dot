local M = {}

function M.watch_file(filepath, on_change)
  local uv = vim.loop
  local fs_event = uv.new_fs_event()

  -- Wrap the callback so it doesn't break Neovim when triggered asynchronously.
  local callback = vim.schedule_wrap(function(err, fname, status)
    if err then
      vim.api.nvim_err_writeln("Error watching file: " .. err)
      return
    end
    -- `status` is a table containing flags about the event
    -- For example: { change = true, rename = false }
    on_change(fname, status)
  end)

  local success, err = pcall(function()
    fs_event:start(filepath, {}, callback)
  end)

  if not success then
    vim.api.nvim_err_writeln("Failed to start file watch: " .. err)
    fs_event:close()
    return nil
  end

  -- Return an object that allows stopping the watch
  return {
    stop = function()
      fs_event:stop()
      fs_event:close()
    end
  }
end

return M