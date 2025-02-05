return {
    {
        "Kurama622/llm.nvim",
        dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim" },
        cmd = { "LLMSessionToggle" },
        config = function()
          require("llm").setup({
            prompt = "You are a helpful code assistant.",
    
            prefix = {
              user = { text = "> ", hl = "Title" },
              assistant = { text = "⚡ ", hl = "Added" },
            },
    
            style = "float", -- right | left | above | below | float
    
            url = "https://openrouter.ai/api/v1/chat/completions",
            model = "google/gemini-2.0-flash-exp:free",
            api_type = "openai",
    
            max_tokens = 1024,
            save_session = true,
            max_history = 20,
            history_path = "/tmp/llm_nvim_history",
            temperature = 0.3,
            top_p = 0.7,
    
            spinner = {
              text = {
                "󰧞󰧞",
                "󰧞󰧞",
                "󰧞󰧞",
                "󰧞󰧞",
              },
              hl = "Title",
            },
    
            display = {
              diff = {
                layout = "vertical", -- vertical|horizontal split for default provider
                opts = { "internal", "filler", "closeoff", "algorithm:patience", "followwrap", "linematch:120" },
                provider = "mini_diff", -- default|mini_diff
              },
            },
    
            -- stylua: ignore
            keys = {
              -- The keyboard mapping for the input window.
              ["Input:Cancel"]      = { mode = "n", key = "<C-c>" },
              ["Input:Submit"]      = { mode = "n", key = "<cr>" },
              ["Input:Resend"]      = { mode = "n", key = "<C-r>" },
    
              -- only works when "save_session = true"
              ["Input:HistoryNext"] = { mode = "n", key = "<C-j>" },
              ["Input:HistoryPrev"] = { mode = "n", key = "<C-k>" },
    
              -- The keyboard mapping for the output window in "split" style.
              ["Output:Ask"]        = { mode = "n", key = "i" },
              ["Output:Cancel"]     = { mode = "n", key = "<C-c>" },
              ["Output:Resend"]     = { mode = "n", key = "<C-r>" },
    
              -- The keyboard mapping for the output and input windows in "float" style.
              ["Session:Toggle"]    = { mode = "n", key = "<leader>ac" },
              ["Session:Close"]     = { mode = "n", key = "<esc>" },
            },
          })
        end,
        keys = {
          { "<leader>ac", mode = "n", "<cmd>LLMSessionToggle<cr>" },
        },
      },
}