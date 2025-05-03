-- Toggle between various header and source extensions in $TOP_HEAD when you press '-'
local function toggle_header_source()
  local fname    = vim.fn.expand('%:t')       -- filename, e.g. "file1.hpp" or "file1.cxx"
  local basename = vim.fn.expand('%:t:r')     -- base name without extension, e.g. "file1"
  -- get the extension and normalize to lowercase
  local ext = string.lower(vim.fn.expand('%:e'))

  local search_dir = vim.env.TOP_HEAD
  if not search_dir or search_dir == '' then
    vim.notify('Environment variable TOP_HEAD is not set', vim.log.levels.WARN)
    return
  end

  -- Define header and source extension groups
  local header_exts = { 'h', 'hh', 'hpp', 'hxx' }
  local source_exts = { 'c', 'cc', 'cpp', 'cxx' }

  -- Helper: check if a value exists in list
  local function contains(list, value)
    for _, v in ipairs(list) do
      if v == value then
        return true
      end
    end
    return false
  end

  -- Determine candidate extensions based on current file type
  local candidates
  if contains(header_exts, ext) then
    candidates = source_exts
  elseif contains(source_exts, ext) then
    candidates = header_exts
  else
    vim.notify('Not a recognized header/source file: ' .. fname, vim.log.levels.INFO)
    return
  end

  -- Try each candidate extension in order, open the first match
  for _, cand_ext in ipairs(candidates) do
    local pattern = string.format('**/%s.%s', basename, cand_ext)
    local matches = vim.fn.globpath(search_dir, pattern, '', true)
    if not vim.tbl_isempty(matches) then
      vim.cmd('edit ' .. vim.fn.fnameescape(matches[1]))
      return
    end
  end

  -- If no matches found
  vim.notify(string.format('No matching file found for %s with extensions: %s', fname, table.concat(candidates, ", ")), vim.log.levels.INFO)
end

-- Bind '-' in normal mode to our toggle function
vim.keymap.set('n', '-', toggle_header_source, {
  noremap = true,
  silent  = true,
  desc    = 'Toggle between header and source (.h/.c, .hh/.cc, .hpp/.cpp, .hxx/.cxx) in $TOP_HEAD',
})

