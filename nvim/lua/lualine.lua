-- Lualine statusline configuration

require('lualine').setup({
  options = {
    theme = 'catppuccin',
    component_separators = { left = '|', right = '|' },
    section_separators = { left = "", right = "" },
  },
  sections = {
    lualine_c = {
      { 'filename', path = 1 },
    },
  },
})
