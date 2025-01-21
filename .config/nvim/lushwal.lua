vim.g.lushwal_configuration = {
    color_overrides = function(colors)
        local overrides = {
            red = colors.color5,
            orange = colors.color1,
            amaranth = colors.color5.mix(colors.color4, 34).saturate(46).darken(5),
        }
        return vim.tbl_extend("force", colors, overrides)
    end,
    transparent_background = false,
    compile_to_vimscript = true,
    terminal_colors = false,
    addons = {
        bufferline_nvim = true,
        dashboard_nvim = true,
        gitsigns_nvim = true,
        native_lsp = true,
        nvim_cmp = true,
        nvim_tree_lua = true,
        telescope_nvim = true,
        treesitter = true,
        which_key_nvim = true,
    },
}

return {
    {
        "oncomouse/lushwal.nvim",
        cmd = { "LushwalCompile" },
        dependencies = {
            { "rktjmp/lush.nvim" },
            { "rktjmp/shipwright.nvim" },
        },
        lazy = false,
    }
}
