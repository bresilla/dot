-- Set key mappings for Lua files
vim.api.nvim_create_autocmd("FileType", {
    pattern = "lua",
    callback = function()
        vim.keymap.set("n", "<leader>s", function()
            vim.cmd("source %")
            print("Sourced Lua file: " .. vim.fn.expand("%"))
        end, { buffer = true, desc = "Source current Lua file" })
        vim.keymap.set("v", "<leader>c", 
            ":Chat<CR>",
            { noremap = true, silent = true },
            "llmchat"
        )
    end,
  })

vim.keymap.set("n", "<leader>c", 
  ":Chat<CR>",
  { noremap = true, silent = true },
  "llmchat"
)