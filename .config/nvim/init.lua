---------------------------------------------- === OPTIONS === ----------------------------------------------
vim.api.nvim_set_var('python_host_prog', '/usr/bin/python3')
vim.api.nvim_set_var('python3_host_prog', '/usr/bin/python3')

vim.cmd('syntax on')
vim.cmd('syntax enable')
vim.cmd('filetype on')
vim.cmd('filetype indent on')
vim.cmd('filetype plugin on')
vim.cmd('filetype plugin indent on')

-- jente has fucked up your entire install, happy debugging sucker
vim.o.background = "dark"

vim.o.termguicolors = false -- truecolours for better experience
vim.o.compatible = false
vim.o.ruler = true
vim.o.shiftround = true
vim.o.hlsearch = true
vim.o.cmdheight = 0

vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste('+'),
    ['*'] = require('vim.ui.clipboard.osc52').paste('*'),
  },
}
vim.o.clipboard = "unnamedplus"
vim.g.termfeatures = termfeatures


vim.o.autoread = true
vim.o.history = 5000
vim.o.backup = false -- disable backup
vim.o.swapfile = false -- disable swapfile
vim.o.writebackup = false -- disable backup
vim.o.autowrite = true -- autowrite buffer when it's not focused

vim.wo.wrap = false -- dont wrap lines
vim.wo.number = true -- enable number
vim.wo.relativenumber = true -- enable relativenumber
vim.o.hidden = true -- keep hidden buffers
vim.o.showmode = false -- don't show mode
vim.o.showcmd = false -- don't show last command on cmd
vim.o.shortmess = vim.o.shortmess .. "F" -- dont dhow filename on cmd

vim.o.showtabline = 1 -- always show tabs

vim.o.smartcase = true -- improve searching usinCLI
vim.o.ignorecase = true -- case insensitive on search
vim.o.re = 0 -- set regexp engine to auto
vim.o.inccommand = "split" -- incrementally show result of command

vim.o.laststatus = 3 -- always enable statusline
vim.o.cursorline = true -- enable cursorline
vim.o.cursorcolumn = true
vim.o.splitbelow = true -- split below instead of above
vim.o.splitright = true -- split right instead of left
vim.o.startofline = false -- don't go to the start of the line when moving to another file
-- vim.o.lazyredraw = true -- lazyredraw to make macro faster

vim.o.tabstop = 4 -- tabsize
vim.o.shiftwidth = 4 -- set indentation width
vim.o.softtabstop = 4
vim.o.expandtab = true -- use spaces instead of tabs
vim.o.autoindent = true -- enable autoindent
vim.o.smarttab = true -- make tab behaviour smarter
vim.o.smartindent = true -- smarter indentation

vim.o.scrolloff = 2 -- make scrolling better
vim.o.sidescroll = 10 -- make scrolling better
vim.o.sidescrolloff = 15 -- make scrolling better

vim.o.completeopt = 'menu,menuone,noinsert,noselect' -- better completion
vim.o.wildmode = 'longest,list,full'
vim.o.wildoptions = "pum"
vim.o.pumblend = 10
vim.o.pumheight = 10 -- limit completion items

vim.o.synmaxcol = 300 -- set limit for syntax highlighting in a single line
vim.o.updatetime = 100 -- set faster update time
vim.o.timeoutlen = 500 -- faster timeout wait time

vim.o.encoding = "UTF-8" -- set encoding
vim.o.mouse = "a" -- enable mouse supportcomment
vim.o.foldmethod = "marker" -- foldmethod using marker
vim.o.signcolumn = "yes" -- enable sign column all the time, 4 column

vim.g.loaded_netrw = 0 -- disable netrw
vim.g.loaded_netrwPlugin = 0 -- disable netrw plugin

vim.o.list = true -- display listchars
vim.o.listchars = "extends:›,precedes:‹,nbsp:␣,trail:·,tab:→\\ ,eol:¬" -- set listchars

---------------------------------------------- === PLUGINS === ----------------------------------------------
require("config.lazy")
require("utils.termcolors")
require("utils.diags")
require("utils.navigation")

---------------------------------------------- === ATUOCMDS === ----------------------------------------------
-- === DEFAULT FILETYPE === "
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
        -- Check if the buffer is a real file (not a dashboard, terminal, etc.)
        if vim.fn.empty(vim.fn.expand("%")) == 0 and vim.bo.buftype == "" then
            vim.cmd([[retab]])
        end
    end
})

vim.cmd([[au BufNewFile,BufRead *.envrc   set syntax=sh]])
vim.cmd([[au BufNewFile,BufRead *.fol     set filetype=fol]])
-- === FOCUS === "
-- vim.cmd([[au WinLeave * set nocursorline nocursorcolumn norelativenumber]])
-- vim.cmd([[au WinEnter * set cursorline cursorcolumn relativenumber]])

-- === AUTOSAVE === "
vim.cmd([[au WinLeave,BufLeave,TabLeave,FocusLost * silent wall]])
---------------------------------------------- === BINDINGS === ----------------------------------------------
vim.g.mapleader = " "

-- === REMOVE HABITS === "
vim.keymap.set({'n', 'v'}, 'd', [["_d]])
vim.keymap.set({'n', 'v'}, 'c', [["_c]])
vim.keymap.set('n', '<S-Up>', [[<Nop>]])
vim.keymap.set('n', '<S-Down>', [[<Nop>]])

-- === CHANGE CASE === "
vim.keymap.set('n', '~', [[g~aw]])


-- === OTHERS === "
vim.keymap.set('n', '<C-a>', 'ggVG')
vim.keymap.set('n', '<C-e>', function()
    local file = vim.fn.expand('%:p')
    local path = (file ~= '' and vim.fn.filereadable(file) == 1) and file or vim.fn.getcwd()
    local result = vim.fn.system('hexe mux float --title="explorer" --command \'yazi "' .. path .. '" --chooser-file="$HEXE_FLOAT_RESULT_FILE"\'')
    result = vim.trim(result)
    if result ~= '' and vim.fn.filereadable(result) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(result))
    end
end, { silent = true, desc = "Open yazi explorer" })

vim.keymap.set('n', '<C-t>', function()
    local result = vim.trim(vim.fn.system([[hexe mux float --title="explorer" --size "20,98,-50,4" --command 'lis -Ac --selection-background=236 --cwd=${TOP_HEAD:-.} -o "$HEXE_FLOAT_RESULT_FILE"']]))
    if result == '' then
        return
    end

    local lines = vim.split(result, '\n', { trimempty = true })
    local selected = vim.trim(lines[#lines] or result):gsub('\r', '')
    if selected:sub(1, 1) ~= '/' then
        local base = vim.env.TOP_HEAD
        if not base or base == '' then
            base = vim.fn.getcwd()
        end
        selected = vim.fn.fnamemodify(base .. '/' .. selected, ':p')
    end

    if vim.fn.filereadable(selected) == 1 or vim.fn.isdirectory(selected) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(selected))
    else
        vim.notify('Could not open lis selection: ' .. selected, vim.log.levels.WARN)
    end
end, { silent = true, desc = "Open lis explorer" })

vim.keymap.set('n', '<C-p>', function()
    local result = vim.fn.system('hexe mux float --title="picker" --command \'tv find > "$HEXE_FLOAT_RESULT_FILE"\'')
    result = vim.trim(result)
    if result ~= '' and vim.fn.filereadable(result) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(result))
    end
end, { silent = true, desc = "Pick file with tv find" })

vim.keymap.set('n', '<C-f>', function()
    local result = vim.fn.system('hexe mux float --title="finder" --command \'tv text > "$HEXE_FLOAT_RESULT_FILE"\'')
    result = vim.trim(result)
    if result ~= '' then
        local file, line, col = result:match('([^:]+):(%d+):(%d+)')
        if not file then
            file, line = result:match('([^:]+):(%d+)')
        end
        if file and vim.fn.filereadable(file) == 1 then
            vim.cmd('edit ' .. vim.fn.fnameescape(file))
            vim.api.nvim_win_set_cursor(0, { tonumber(line), tonumber(col or 1) - 1 })
        end
    end
end, { silent = true, desc = "Find text with tv text" })

vim.keymap.set('n', '<C-o>', function()
    local dir = vim.fn.getcwd()
    vim.fn.system('hexe mux float --title="replace" --command \'serpl -p "' .. dir .. '"\'')
end, { silent = true, desc = "Search and replace with serpl" })

vim.keymap.set('n', '<C-b>', function()
    local bufs = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= '' then table.insert(bufs, name) end
        end
    end
    if #bufs == 0 then return end
    local buflist = table.concat(bufs, '\n')
    local result = vim.fn.system('hexe mux float --title="buffers" --command \'echo "' .. buflist:gsub('"', '\\"') .. '" | tv --preview "bat -n --color=always {0}" > "$HEXE_FLOAT_RESULT_FILE"\'')
    result = vim.trim(result)
    if result ~= '' and vim.fn.filereadable(result) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(result))
    end
end, { silent = true, desc = "Pick buffer" })

vim.keymap.set('n', '<C-q>', function()
    local qffile = vim.fn.getcwd() .. '/.quickfix'
    if vim.fn.filereadable(qffile) ~= 1 then return end
    local result = vim.fn.system('hexe mux float --title="quickfix" --command \'cat "' .. qffile .. '" | tv > "$HEXE_FLOAT_RESULT_FILE"\'')
    result = vim.trim(result)
    if result ~= '' then
        local file, line, col = result:match('([^:]+):(%d+):(%d+)')
        if file and vim.fn.filereadable(file) == 1 then
            vim.cmd('edit ' .. vim.fn.fnameescape(file))
            vim.api.nvim_win_set_cursor(0, { tonumber(line), tonumber(col) - 1 })
        end
    end
end, { silent = true, desc = "Pick from quickfix" })

vim.keymap.set('n', '<A-b>', function()
    vim.fn.system('hexe mux float --title="make build" --pass-env --command "bash -c \'_b; read -n1 -s\'"')
end, { silent = true, desc = "make build" })

vim.keymap.set('n', '<A-c>', function()
    vim.fn.system('hexe mux float --title="make config" --pass-env --command "bash -c \'_c; read -n1 -s\'"')
end, { silent = true, desc = "make config" })

vim.keymap.set('n', '<A-x>', function()
    vim.fn.system('hexe mux float --title="make reconfigure" --pass-env --command "bash -c \'_x; read -n1 -s\'"')
end, { silent = true, desc = "make reconfigure" })

vim.keymap.set('n', '<A-t>', function()
    vim.fn.system('hexe mux float --title="make test" --pass-env --command "bash -c \'_t; read -n1 -s\'"')
end, { silent = true, desc = "make test" })

-- === SPLIT NAVIGATION === "
local function smart_split_nav(direction, wincmd)
    local cur_win = vim.api.nvim_get_current_win()
    vim.cmd('wincmd ' .. wincmd)
    if vim.api.nvim_get_current_win() == cur_win then
        vim.fn.jobstart({'hexe', 'mux', 'focus', direction}, {detach = true})
    end
end

-- Map both <A-arrow> and raw escape sequences for terminal compatibility
for _, mapping in ipairs({
    {'<C-A-Up>', '<Esc>[1;3A', 'up', 'k'},
    {'<C-A-Down>', '<Esc>[1;3B', 'down', 'j'},
    {'<C-A-Left>', '<Esc>[1;3D', 'left', 'h'},
    {'<C-A-Right>', '<Esc>[1;3C', 'right', 'l'},
}) do
    local alt_key, esc_seq, direction, wincmd = mapping[1], mapping[2], mapping[3], mapping[4]
    local fn = function() smart_split_nav(direction, wincmd) end
    vim.keymap.set({'n', 'i', 't'}, alt_key, fn, { silent = true, desc = "Navigate " .. direction .. " split or mux" })
    vim.keymap.set({'n', 'i', 't'}, esc_seq, fn, { silent = true, desc = "Navigate " .. direction .. " split or mux" })
end

-- -- === MOVE LINES === "
-- vim.keymap.set('n', '<C-A-Up>', ':m .-2<CR>==', { remap = true, silent = true, desc = "Move line up" })
-- vim.keymap.set('n', '<C-A-Down>', ':m .+1<CR>==', { remap = true, silent = true, desc = "Move line down" })
-- vim.keymap.set('v', '<C-A-Up>', ":m '<-2<CR>gv=gv", { remap = true, silent = true, desc = "Move selection up" })
-- vim.keymap.set('v', '<C-A-Down>', ":m '>+1<CR>gv=gv", { remap = true, silent = true, desc = "Move selection down" })
-- vim.keymap.set('i', '<C-A-Up>', '<Esc>:m .-2<CR>==gi', { remap = true, silent = true, desc = "Move line up in insert mode" })
-- vim.keymap.set('i', '<C-A-Down>', '<Esc>:m .+1<CR>==gi', { remap = true, silent = true, desc = "Move line down in insert mode" })

-- === COMMENTING === "
vim.keymap.set('n', '#', 'gcc', { remap = true, desc = "Comment line" })
vim.keymap.set('v', '#', 'gc', { remap = true, desc = "Comment selection" })

-- === HOME/END KEYS === "
vim.keymap.set({'n', 'v'}, '<Home>', '^', { remap = true, silent = true, desc = "Go to beginning of line" })
vim.keymap.set({'n', 'v'}, '<Find>', '^', { remap = true, silent = true, desc = "Go to beginning of line" })
vim.keymap.set({'n', 'v'}, '<End>', '$', { remap = true, silent = true, desc = "Go to end of line" })
vim.keymap.set({'n', 'v'}, '<Select>', '$', { remap = true, silent = true, desc = "Go to end of line" })
vim.keymap.set('i', '<Home>', '<C-o>^', { remap = true, silent = true, desc = "Go to beginning of line in insert mode" })
vim.keymap.set('i', '<Find>', '<C-o>^', { remap = true, silent = true, desc = "Go to beginning of line in insert mode" })
vim.keymap.set('i', '<End>', '<C-o>$', { remap = true, silent = true, desc = "Go to end of line in insert mode" })
vim.keymap.set('i', '<Select>', '<C-o>$', { remap = true, silent = true, desc = "Go to end of line in insert mode" })


-------------------------------------------- === SMART_CLISE === ---------------------------------------------
vim.api.nvim_create_user_command('Q', function()
    local listed_buffers = vim.fn.getbufinfo({
        buflisted = 1
    })
    if #listed_buffers > 1 then
        vim.cmd('bd')
    else
        vim.cmd('qa')
    end
end, {})

vim.keymap.set({'n', 'i'}, '<C-w>', '<cmd>:Q<CR>', {
    noremap = true,
    silent = true
})

vim.cmd([[
  cabbrev q  Q
]])


-------------------------------------------- === CUSRSON POS === ------------------------------------------
local augroup = vim.api.nvim_create_augroup('RestoreCursor', { clear = true })
vim.api.nvim_create_autocmd('BufWinEnter', {
  pattern = '*',  -- Apply to all buffers
  group = augroup,
  callback = function()
    local pos = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    -- Check if the mark is valid
    if pos[1] > 0 and pos[1] <= line_count then
      vim.api.nvim_win_set_cursor(0, pos)
    end
  end,
})


-------------------------------------------- === WHITE SPACE === -------------------------------------------
vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*",
    callback = function()
        vim.cmd([[%s/^\s\+$//e]])
    end,
})


-------------------------------------------- === LAST MAP === ---------------------------------------------
vim.keymap.set('n', '<ESC>', function()
    vim.cmd(':noh') -- Clear search highlighting
    vim.fn.setreg('/', '') -- Clear the search register
    require('scrollbar.handlers.search').handler.hide()
    return [[<ESC>]]
end, {
    noremap = true,
    silent = true
})
