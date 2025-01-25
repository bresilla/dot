-- File: utils/watcher.lua
-- Description: A file-watcher module that watches a directory to catch file replacements.

local M = {}

function M.watch_file(filepath, on_change)
  local uv = vim.loop
  local fs_event = uv.new_fs_event()

  -- We watch the parent directory instead of the file itself:
  local dir = vim.fn.fnamemodify(filepath, ":h")  -- e.g. "/home/username/.cache/lule"
  local filename = vim.fn.fnamemodify(filepath, ":t")  -- e.g. "colors"

  -- Wrap callback in vim.schedule_wrap so that we can safely call Neovim functions.
  local callback = vim.schedule_wrap(function(err, changed_filename, status)
    if err then
      vim.api.nvim_err_writeln("Error watching directory: " .. err)
      return
    end

    -- Only trigger on_change if the file that changed is the specific file we care about
    if changed_filename == filename then
      on_change(filepath, status)
    end
  end)

  -- Attempt to start watching the directory
  local success, start_err = pcall(function()
    -- {} are the flags—if you want recursive watch on some platforms, you can set {recursive=true}
    fs_event:start(dir, {}, callback)
  end)

  if not success then
    vim.api.nvim_err_writeln("Failed to start watcher for " .. dir .. ": " .. start_err)
    fs_event:close()
    return nil
  end

  -- Return a handle object that allows stopping the watch.
  return {
    stop = function()
      fs_event:stop()
      fs_event:close()
    end,
  }
end

return M
