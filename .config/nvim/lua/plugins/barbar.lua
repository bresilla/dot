-- vim.keymap.set('n',            '<C-Pagedown>',             [[:bn<CR>]])
-- vim.keymap.set('n',            '<C-Pageup>',               [[:bp<CR>]])
vim.keymap.set('n',            '<C-Pagedown>',             [[:BufferNext<CR>]], { noremap = true, silent = true })
vim.keymap.set('n',            '<C-Pageup>',               [[:BufferPrevious<CR>]], { noremap = true, silent = true })

-- ctrl + > and ctrl + <
vim.keymap.set('n',            '<C-n>',                   [[:tabn<CR>]], { noremap = true, silent = true })

vim.keymap.set('n',            '<C-S-Pagedown>',           [[:BufferMoveNext<CR>]], { noremap = true, silent = true })
vim.keymap.set('n',            '<C-S-Pageup>',             [[:BufferMovePrevious<CR>]], { noremap = true, silent = true })

return {
  {'romgrk/barbar.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
    config = function()
      local barbar = require("barbar")
      barbar.setup({
        sidebar_filetypes = {
          NvimTree = true,
        },
        -- tabpages = false,
        -- highlight_alternate = false,
        icons = {
            separator = {left = '|', right = '|'},
            separator_at_end = true,
        },
        sort = false,
      })
    end,
    version = '^1.0.0',
  },
  {
    "tiagovla/scope.nvim",
    config = function()
      require('scope').setup({
        hooks = {
          pre_tab_leave = function()
            vim.api.nvim_exec_autocmds('User', {pattern = 'ScopeTabLeavePre'})
          end,
          post_tab_enter = function()
            vim.api.nvim_exec_autocmds('User', {pattern = 'ScopeTabEnterPost'})
          end,
        },
    
      })
    end,
  }
}
