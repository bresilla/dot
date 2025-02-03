return {
    {
        "bresilla/llmchat.nvim",
        lazy = false,
        config = function()
            -- vim.api.nvim_set_keymap("v", "<leader>ap",
            --     ":<C-U>lua require('my_telescope_plugin').run_api_on_selection()<CR>",
            --     { noremap = true, silent = true }
            -- )
            vim.keymap.set(
                "v",
                "<leader>ap",
                ":Llmchat<CR>",
                { noremap = true, silent = true },
                "llmchat"
            )
            -- require("llmchat").setup({})
        end
    }
}