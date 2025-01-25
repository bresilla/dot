return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      local copilot = require("copilot")

      -- vim.api.nvim_create_autocmd('User', {
      --   pattern = 'BlinkCmpMenuOpen',
      --   callback = function()
      --     require("copilot.suggestion").dismiss()
      --     vim.b.copilot_suggestion_hidden = true
      --   end,
      -- })
      
      -- vim.api.nvim_create_autocmd('User', {
      --   pattern = 'BlinkCmpMenuClose',
      --   callback = function()
      --     vim.b.copilot_suggestion_hidden = false
      --   end,
      -- })

      copilot.setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          hide_during_completion = true,
          debounce = 75,
          keymap = {
            accept = "<Tab>",
            accept_word = false,
            accept_line = false,
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        panel = { enabled = false },
      })
    end,
  }
}
