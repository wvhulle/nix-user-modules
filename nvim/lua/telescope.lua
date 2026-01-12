-- Telescope fuzzy finder configuration

local telescope = require('telescope')

telescope.setup({
  defaults = {
    file_ignore_patterns = { 'node_modules', '.git/', 'target/' },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
    },
  },
})

telescope.load_extension('fzf')
