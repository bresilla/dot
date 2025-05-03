-- your env var toggle function (unchanged)
local function toggle_header_source()
  local fname    = vim.fn.expand('%:t')
  local basename = vim.fn.expand('%:t:r')
  local ext      = string.lower(vim.fn.expand('%:e'))
  local search_dir = vim.env.TOP_HEAD
  if not search_dir or search_dir == '' then
    vim.notify('Environment variable TOP_HEAD is not set', vim.log.levels.WARN)
    return
  end

  local header_exts = { 'h', 'hh', 'hpp', 'hxx' }
  local source_exts = { 'c', 'cc', 'cpp', 'cxx' }

  local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
  end

  local candidates
  if contains(header_exts, ext) then
    candidates = source_exts
  elseif contains(source_exts, ext) then
    candidates = header_exts
  else
    vim.notify('Not a recognized header/source file: ' .. fname, vim.log.levels.INFO)
    return
  end

  for _, cand_ext in ipairs(candidates) do
    local pattern = string.format('**/%s.%s', basename, cand_ext)
    local matches = vim.fn.globpath(search_dir, pattern, '', true)
    if not vim.tbl_isempty(matches) then
      vim.cmd('edit ' .. vim.fn.fnameescape(matches[1]))
      return
    end
  end

  vim.notify(string.format(
    'No matching file found for %s with extensions: %s',
    fname, table.concat(candidates, ", ")
  ), vim.log.levels.INFO)
end

-- reusable header/source lists
local header_exts = { 'h', 'hh', 'hpp', 'hxx' }
local source_exts = { 'c', 'cc', 'cpp', 'cxx' }

-- check if two buffers are basename-identical but one is header, one is source
local function is_header_source_pair(bufnr1, bufnr2)
  local name1 = vim.fn.bufname(bufnr1)
  local name2 = vim.fn.bufname(bufnr2)
  if name1 == '' or name2 == '' then return false end

  local base1 = vim.fn.fnamemodify(name1, ':t:r')
  local ext1  = string.lower(vim.fn.fnamemodify(name1, ':e'))
  local base2 = vim.fn.fnamemodify(name2, ':t:r')
  local ext2  = string.lower(vim.fn.fnamemodify(name2, ':e'))

  if base1 ~= base2 then
    return false
  end

  local function contains(list, val)
    for _, v in ipairs(list) do if v == val then return true end end
    return false
  end

  return (contains(header_exts, ext1) and contains(source_exts, ext2))
      or (contains(header_exts, ext2) and contains(source_exts, ext1))
end

-- jump to the most‐recent buffer, skipping header/source partner if needed
local function jump_last_non_header_source()
  local cur = vim.api.nvim_get_current_buf()
  local all = vim.fn.getbufinfo({buflisted = 1})

  -- sort by lastused desc
  table.sort(all, function(a, b)
    return (a.lastused or 0) > (b.lastused or 0)
  end)

  -- collect all except current
  local others = {}
  for _, info in ipairs(all) do
    if info.bufnr ~= cur then
      table.insert(others, info)
    end
  end

  if #others == 0 then return end

  -- pick the top candidate
  local target = others[1]

  -- if it’s the header/source partner, and we have a “prevprev”, use that
  if is_header_source_pair(cur, target.bufnr) and #others >= 2 then
    target = others[2]
  end

  -- switch to it
  vim.cmd('buffer ' .. target.bufnr)
end

-- mappings
vim.keymap.set('n', '=', toggle_header_source, {
  noremap = true, silent = true,
  desc = 'Toggle between header and source (.h/.c, .hh/.cc, .hpp/.cpp, .hxx/.cxx) in $TOP_HEAD',
})

vim.keymap.set('n', '-', jump_last_non_header_source, {
  noremap = true, silent = true,
  desc = 'Go to last buffer, but skip header/source pair if that was the alternate',
})

