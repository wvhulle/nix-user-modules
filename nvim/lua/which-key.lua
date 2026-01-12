-- Which-key configuration for keybinding discovery

require('which-key').setup({
  plugins = {
    spelling = { enabled = true },
  },
  win = {
    border = 'rounded',
  },
})
