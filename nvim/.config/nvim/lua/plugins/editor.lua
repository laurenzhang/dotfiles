return {
  -- autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = {
      -- wants to hook into <CR> mappings set by cmp
      "hrsh7th/nvim-cmp",
    },
    config = function()
      local npairs = require("nvim-autopairs")
      npairs.setup({
        disable_filetype = {
          "TelescopePrompt",
        },
      })
      npairs.add_rules(require("nvim-autopairs.rules.endwise-ruby"))
    end,
  },
}
