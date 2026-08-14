return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
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
            anti_conceal = {
                enabled = false
            },
            indent = {
                enabled = false,
            },
            sign = {
                enabled = false,
            },
            file_types = {
                'markdown',
                'markdown.pandoc',
                'markdown_inline',
                'markdown.pandoc.inline',
                'md',
                'rmd',
                'qmd',
                'pandoc.markdown',
                'pandoc.markdown.inline',
                "copilot-chat",
            },
        })
    end,
}
}
