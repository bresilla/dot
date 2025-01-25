local M = {}

function M.run_every_2s(on_tick)
  local uv = vim.loop
  local timer = uv.new_timer()

  -- Wrap the callback in vim.schedule_wrap to avoid issues
  -- with calling Neovim API asynchronously
  local callback = vim.schedule_wrap(function()
    on_tick()
  end)

  -- Start the timer: 0 ms for the first wait, then 2000 ms intervals
  timer:start(0, 2000, callback)

  -- Return an object that allows stopping the timer
  return {
    stop = function()
      timer:stop()
      timer:close()
    end
  }
end

return M
