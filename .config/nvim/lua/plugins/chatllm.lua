return {
    {
        "jackMort/ChatGPT.nvim",
        event = "VeryLazy",
        config = function()
            require("chatgpt").setup()
        end,
        dependencies = {
            "MunifTanjim/nui.nvim",
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope.nvim"
        },
        config = function()
            local openrouter_key = vim.fn.getenv("OPENROUTER_API_KEY")
            require('chatgpt').setup {
                api_host_cmd = 'echo -n https://openrouter.ai/api',
                -- api_key_cmd = 'echo ' .. your_openrouter_apikey_as_string,
                api_key_cmd = 'echo ' .. openrouter_key,
                api_type_cmd = 'echo localai',
                openai_params = {
                    model = 'google/gemini-2.0-flash-001',
                    max_tokens = 1000,
                },
                extra_curl_params = {
                "-H", "HTTP-Referer: http://www.gooogle.com", --should not be empty, otherwise it will not display
                "-H", "X-Title: ChatGPTnvim"
                },
                chat = {
                    welcome_message = "",
                    default_system_message = "",
                    loading_text = "... waiting for answer ...",
                    question_sign = "", -- 🙂
                    answer_sign = "ﮧ", -- 🤖
                    max_line_length = 120,
                    sessions_window = {
                        active_sign = "  ",
                        inactive_sign = "  ",
                        current_line_sign = "",
                        border = {
                            style = "rounded",
                            text = {
                                top = " Sessions ",
                            },
                        },
                        win_options = {
                            winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
                        },
                    },
                }
            }
        end, 
    }
}
