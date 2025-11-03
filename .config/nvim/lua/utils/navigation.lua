-- jump to implementation (smarter version)
local function jump_to_implementation()
  local params = vim.lsp.util.make_position_params()
  local ext = string.lower(vim.fn.expand('%:e'))
  local header_exts = { 'h', 'hh', 'hpp', 'hxx' }
  
  local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
  end
  
  -- First, try LSP's definition (works for most cases)
  vim.lsp.buf_request(0, 'textDocument/definition', params, function(err, result, ctx, config)
    if err or not result or vim.tbl_isempty(result) then
      -- If we're in a header file, try to find implementation in source file
      if contains(header_exts, ext) then
        -- Try implementation request as fallback
        vim.lsp.buf_request(0, 'textDocument/implementation', params, function(err2, result2, ctx2, config2)
          if err2 or not result2 or vim.tbl_isempty(result2) then
            vim.notify('No implementation found', vim.log.levels.INFO)
          else
            vim.lsp.util.jump_to_location(result2[1], 'utf-8')
          end
        end)
      else
        vim.notify('No definition found', vim.log.levels.INFO)
      end
      return
    end
    
    -- Handle the result (could be single location or array)
    local location = result
    if vim.islist(result) then
      location = result[1]
    end
    
    -- Jump to the location
    vim.lsp.util.jump_to_location(location, 'utf-8')
  end)
end

-- your env var toggle function (unchanged)
local function toggle_header_source()
  local fname    = vim.fn.expand('%:t')
  local basename = vim.fn.expand('%:t:r')
  local ext      = string.lower(vim.fn.expand('%:e'))

  -- read and split PFLDS into a Lua table of dirs
  local pflds = vim.env.PFLDS or ''
  if pflds == '' then
    vim.notify('Environment variable PFLDS is not set', vim.log.levels.WARN)
    return
  end
  local search_dirs = {}
  for dir in string.gmatch(pflds, '([^:]+)') do
    table.insert(search_dirs, dir)
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

  -- search each directory in turn for a matching basename + candidate ext
  for _, cand_ext in ipairs(candidates) do
    local pattern = string.format('**/%s.%s', basename, cand_ext)
    for _, dir in ipairs(search_dirs) do
      local matches = vim.fn.globpath(dir, pattern, false, true)
      if not vim.tbl_isempty(matches) then
        vim.cmd('edit ' .. vim.fn.fnameescape(matches[1]))
        return
      end
    end
  end

  vim.notify(string.format(
    'No matching file found for %s in PFLDS dirs (%s) with extensions: %s',
    fname,
    table.concat(search_dirs, ", "),
    table.concat(candidates, ", ")
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


-- define the file patterns you care about
local cpp_patterns = { "*.h",  "*.hh",  "*.hpp",  "*.hxx",
                       "*.c",  "*.cc",  "*.cpp",  "*.cxx" }

-- autocmd that fires when entering any of those buffers
vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = cpp_patterns,
  callback = function()
    -- buffer-local toggle header/source
    vim.keymap.set('n', '=', toggle_header_source, {
      buffer = true,
      noremap = true,
      silent = true,
      desc = 'Toggle between header and source in $TOP_HEAD',
    })
    -- buffer-local jump to implementation using LSP
    vim.keymap.set('n', '+', jump_to_implementation, {
      buffer = true,
      noremap = true,
      silent = true,
      desc = 'Jump to implementation (LSP)',
    })
    -- buffer-local jump-last, skipping header/source partner
    vim.keymap.set('n', '-', jump_last_non_header_source, {
      buffer = true,
      noremap = true,
      silent = true,
      desc = 'Go to last buffer, but skip header/source pair',
    })
  end,
})

vim.keymap.set('n', '-', "<cmd>:b#<CR>", {
    noremap = true,
    silent = true
})



------------ BUFER SAVE ------------
-- Save list of open buffer filenames and current file into a project‐specific file in /tmp
local function sav_buf_tmp()
  local cwd = vim.loop.cwd() or vim.fn.getcwd()
  local proj = vim.fn.fnamemodify(cwd, ':t')
  local file = vim.fn.expand("%:p")
  local buf_out_file = string.format('/tmp/nvim_%s_open_buffers', proj)
  local cur_file_out_file = string.format('/tmp/nvim_%s_current_file', proj)
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  local names = {}
  for _, info in ipairs(bufs) do
    if info.name ~= '' then
      table.insert(names, vim.fn.fnamemodify(info.name, ':p'))
    end
  end
  vim.fn.writefile(names, buf_out_file)
  vim.fn.writefile({file}, cur_file_out_file)
end

local group = vim.api.nvim_create_augroup("SetCurrentEditingFile", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
  group = group,
  callback = function()
    sav_buf_tmp()
  end,
})

