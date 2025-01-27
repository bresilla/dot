return {
    {
        "yetone/avante.nvim",
        event = "VeryLazy",
        lazy = false,
        version = "*", -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
        opts = {
          provider = "openai",
          -- auto_suggestions_provider = "openai", 
            -- openai = {
              --   endpoint = "https://api.deepseek.com/v1",
              --   model = "deepseek-chat",
              --   timeout = 30000, -- Timeout in milliseconds
              --   temperature = 0,
              --   max_tokens = 4096,
              --   -- optional
              -- },
            openai = {
                endpoint = "https://openrouter.ai/api/v1",
                -- model = "anthropic/claude-3.5-sonnet",
                model = "meta-llama/llama-3.2-90b-vision-instruct:free",
                api_key_name="OPENROUTER_API_KEY_AVANTE",
                temperature = 0.6,
                max_tokens = 8000,
            },
            -- behaviour = {
            --   auto_suggestions = true,
            -- }
          },
        dependencies = {
          "stevearc/dressing.nvim",
          "nvim-lua/plenary.nvim",
          "MunifTanjim/nui.nvim",
        },
      },
}