return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    opts = {},
    config = function()
        require('render-markdown').setup({
            heading = {
                enabled = true,
            },
            paragraph = {
                enabled = true,
            },
            code = {
                enabled = true,
            },
            indent = {
                enabled = true,
            },
        })
    end,
}
}
