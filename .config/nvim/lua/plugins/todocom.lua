return {
    {
        "folke/todo-comments.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            vim.keymap.set(
                "n",
                "<leader>t",
                "<cmd>TodoTelescope<cr>",
                { noremap = true, silent = true }
            )
            local todo = require("todo-comments")
            todo.setup({
                signs = false,
            })
        end,
    }
}