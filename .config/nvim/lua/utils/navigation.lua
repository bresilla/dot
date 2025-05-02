-- Toggle between .hpp and .cpp in $TOP_HEAD when you press '-'
local function toggle_cpp_header()
  local fname = vim.fn.expand('%:t')       -- e.g. "file1.hpp" or "file1.cpp"
  local basename = vim.fn.expand('%:t:r')  -- e.g. "file1"
  local ext = vim.fn.expand('%:e')         -- "hpp" or "cpp"

  local search_dir = vim.env.TOP_HEAD
  if not search_dir or search_dir == '' then
    vim.notify('Environment variable TOP_HEAD is not set', vim.log.levels.WARN)
    return
  end

  local target_ext
  if ext == 'hpp' then
    target_ext = 'cpp'
  elseif ext == 'cpp' then
    target_ext = 'hpp'
  else
    vim.notify('Not a .cpp or .hpp file: ' .. fname, vim.log.levels.INFO)
    return
  end

  -- search for basename.target_ext under $TOP_HEAD
  local pattern = string.format('**/%s.%s', basename, target_ext)
  local matches = vim.fn.globpath(search_dir, pattern, false, true)

  if #matches == 0 then
    vim.notify(string.format('No %s found for %s', target_ext, fname), vim.log.levels.INFO)
    return
  end

  -- open the first match
  vim.cmd('edit ' .. vim.fn.fnameescape(matches[1]))
end

-- bind '-' in normal mode to our toggle function
vim.keymap.set('n', '-', toggle_cpp_header, {
  noremap = true,
  silent = true,
  desc = "Toggle between .hpp and .cpp in $TOP_HEAD"
})

