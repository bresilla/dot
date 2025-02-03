return {{
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = "*", -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
    opts = {
        provider = "openai",
        openai = {
            endpoint = "https://openrouter.ai/api/v1",
            model = "deepseek/deepseek-r1",
            api_key_name = "OPENROUTER_API_KEY",
            temperature = 0.6,
            max_tokens = 8000
        }
    },
    dependencies = {"stevearc/dressing.nvim", "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim"}
}}
