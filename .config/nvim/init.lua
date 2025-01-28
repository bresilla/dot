---------------------------------------------- === OPTIONS === ----------------------------------------------
vim.api.nvim_set_var( 'python_host_prog', '/usr/bin/python3' )
vim.api.nvim_set_var( 'python3_host_prog', '/usr/bin/python3' )

vim.cmd('syntax on')
vim.cmd('syntax enable')
vim.cmd('filetype on')
vim.cmd('filetype indent on')
vim.cmd('filetype plugin on')
vim.cmd('filetype plugin indent on')



-- jente has fucked up your entire install, happy debugging sucker
vim.o.background = "dark"

vim.o.termguicolors = true                                              -- truecolours for better experience
vim.o.compatible = false
vim.o.ruler = true
vim.o.shiftround = true
vim.o.hlsearch = true
vim.o.cmdheight = 0

vim.o.autoread = true
vim.o.history = 5000
vim.o.backup = false                                                    -- disable backup
vim.o.swapfile = false                                                  -- disable swapfile
vim.o.writebackup = false                                               -- disable backup
vim.o.autowrite = true                                                  -- autowrite buffer when it's not focused

vim.wo.wrap = false                                                      -- dont wrap lines
vim.wo.number = true                                                     -- enable number
vim.wo.relativenumber = true                                             -- enable relativenumber
vim.o.hidden = true                                                     -- keep hidden buffers
vim.o.showmode = false                                                  -- don't show mode
vim.o.showcmd = false                                                   -- don't show last command on cmd
vim.o.shortmess = vim.o.shortmess .. "F"                                -- dont dhow filename on cmd

vim.o.showtabline = 1                                                   -- always show tabs

vim.o.smartcase = true                                                  -- improve searching using '/'
vim.o.hlsearch = true                                                   -- highlight matching search
vim.o.incsearch = true
vim.o.ignorecase = true                                                 -- case insensitive on search
vim.o.re = 0                                                            -- set regexp engine to auto
vim.o.inccommand = "split"                                              -- incrementally show result of command

vim.o.laststatus = 3                                                    -- always enable statusline
vim.o.cursorline = true                                                 -- enable cursorline
vim.o.cursorcolumn = true
vim.o.splitbelow = true                                                 -- split below instead of above
vim.o.splitright = true                                                 -- split right instead of left
vim.o.startofline = false                                               -- don't go to the start of the line when moving to another file
vim.o.lazyredraw = true                                                 -- lazyredraw to make macro faster

vim.o.tabstop = 4                                                       -- tabsize
vim.o.shiftwidth = 4                                                    -- set indentation width
vim.o.softtabstop = 4
vim.o.expandtab = true                                                  -- use spaces instead of tabs
vim.o.autoindent = true                                                 -- enable autoindent
vim.o.smarttab = true                                                   -- make tab behaviour smarter
vim.o.smartindent = true                                                -- smarter indentation

vim.o.scrolloff = 2                                                     -- make scrolling better
vim.o.sidescroll = 10                                                   -- make scrolling better
vim.o.sidescrolloff = 15                                                -- make scrolling better

vim.o.completeopt = 'menu,menuone,noinsert,noselect'                 -- better completion
vim.o.wildmode ='longest,list,full'
vim.o.wildoptions = "pum"
vim.o.pumblend = 10
vim.o.pumheight = 10                                                    -- limit completion items

vim.o.synmaxcol = 300                                                   -- set limit for syntax highlighting in a single line
vim.o.updatetime = 100                                                  -- set faster update time
vim.o.timeoutlen = 500                                                  -- faster timeout wait time

vim.o.encoding = "UTF-8"                                                -- set encoding
vim.o.mouse = "a"                                                       -- enable mouse supportcomment
vim.o.foldmethod = "marker"                                             -- foldmethod using marker
vim.o.signcolumn = "yes"                                                -- enable sign column all the time, 4 column

vim.g.loaded_netrw = 1                                                  -- disable netrw
vim.g.loaded_netrwPlugin = 1                                            -- disable netrw plugin

vim.o.list = true                                                       -- display listchars
vim.o.listchars = "extends:›,precedes:‹,nbsp:␣,trail:·,tab:→\\ ,eol:¬"  -- set listchars

---------------------------------------------- === PLUGINS === ----------------------------------------------
require("config.lazy")
require("utils.colors")


---------------------------------------------- === ATUOCMDS === ----------------------------------------------
-- === DEFAULT FILETYPE === "
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
      -- Check if the buffer is a real file (not a dashboard, terminal, etc.)
      if vim.fn.empty(vim.fn.expand("%")) == 0 and vim.bo.buftype == "" then
        vim.cmd([[retab]])
      end
    end,
})

vim.cmd([[au BufNewFile,BufRead *.envrc   set syntax=sh]])
-- === FOCUS === "
-- vim.cmd([[au WinLeave * set nocursorline nocursorcolumn norelativenumber]])
-- vim.cmd([[au WinEnter * set cursorline cursorcolumn relativenumber]])

-- === AUTOSAVE === "
vim.cmd([[au WinLeave,BufLeave,TabLeave,FocusLost * silent wall]])

--- === HIGHLGHT ON YANK
vim.cmd([[au TextYankPost * silent! lua vim.highlight.on_yank()]])
vim.highlight.on_yank { on_visual = true }

---------------------------------------------- === BINDINGS === ----------------------------------------------
vim.g.mapleader = " "

-- === SWITCH TO LAST TABS === "
vim.keymap.set('n', '-', "<cmd>:b#<CR>", { noremap = true, silent = true })


-- === REMOVE HABITS === "
vim.keymap.set({'n', 'v'}, 'd',             [["_d]])
vim.keymap.set({'n', 'v'}, 'c',             [["_c]])
vim.keymap.set('n', '<S-Up>',               [[<Nop>]])
vim.keymap.set('n', '<S-Down>',             [[<Nop>]])

-- === CHANGE CASE === "
vim.keymap.set('n', '~',                   [[g~aw]])

-------------------------------------------- === SMART_CLISE === ---------------------------------------------
vim.api.nvim_create_user_command('Q', function()
    local listed_buffers = vim.fn.getbufinfo({ buflisted = 1 })
    if #listed_buffers > 1 then
        vim.cmd('bd')
    else
        vim.cmd('qa')
    end
end, {})

vim.keymap.set({'n', 'i'}, '<C-w>', '<cmd>:Q<CR>', { noremap = true, silent = true })

vim.cmd([[
  cabbrev q  Q
]])

-------------------------------------------- === LAST MAP === ---------------------------------------------
vim.keymap.set('n', '<ESC>', function()
    vim.cmd(':noh') -- Clear search highlighting
    vim.fn.setreg('/', '') -- Clear the search register
    return [[<ESC>]]
end, { noremap = true, silent = true })
