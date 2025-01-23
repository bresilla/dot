vim.keymap.set('n',            '<C-Pagedown>',             [[:BufferNext<CR>]])
vim.keymap.set('n',            '<C-Pageup>',               [[:BufferPrevious<CR>]])

return {
  {'romgrk/barbar.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
    config = function()
      require("barbar").setup({
        sidebar_filetypes = {
          NvimTree = true,
        },
        -- tabpages = false,
        -- highlight_alternate = false,
        icons = {
            separator = {left = '|', right = '|'},
            separator_at_end = true,
        },
      })
    end,
    version = '^1.0.0',
  },
}
