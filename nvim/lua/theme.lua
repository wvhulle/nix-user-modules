-- Theme loading from dark-mode state file
-- Integrates with darkman for automatic light/dark switching

local M = {}

-- State file path (matches neovim-theme.nu)
local function get_theme_file()
  local xdg_state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
  return xdg_state .. "/nvim/theme"
end

-- Load theme from state file
function M.load_theme()
  local theme_file = get_theme_file()
  local f = io.open(theme_file, "r")

  if f then
    local theme = f:read("*l")
    f:close()

    if theme and theme ~= "" then
      -- Strip whitespace
      theme = theme:match("^%s*(.-)%s*$")

      local ok, err = pcall(vim.cmd.colorscheme, theme)
      if not ok then
        vim.notify("Theme '" .. theme .. "' not found, using catppuccin-mocha", vim.log.levels.WARN)
        vim.cmd.colorscheme("catppuccin-mocha")
      end
    end
  else
    -- Default to dark theme if state file doesn't exist
    vim.cmd.colorscheme("catppuccin-mocha")
  end
end

-- Setup catppuccin with both light and dark flavours
function M.setup_catppuccin()
  require('catppuccin').setup({
    flavour = 'mocha', -- default, will be overridden by load_theme
    background = {
      light = "latte",
      dark = "mocha",
    },
    integrations = {
      cmp = true,
      treesitter = true,
      telescope = { enabled = true },
      which_key = true,
      lsp_trouble = true,
      native_lsp = {
        enabled = true,
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
    },
  })
end

-- Setup autocommands and keymaps
function M.setup()
  -- Setup catppuccin first
  M.setup_catppuccin()

  -- Load initial theme
  M.load_theme()

  -- Reload theme when window gains focus (for dark-mode switches via darkman)
  vim.api.nvim_create_autocmd("FocusGained", {
    callback = M.load_theme,
    desc = "Reload theme on focus (dark-mode integration)",
  })

  -- Keybinding to manually reload theme
  vim.keymap.set('n', '<leader>tr', M.load_theme, { desc = 'Reload theme' })

  -- Quick toggle between light/dark (writes to state file)
  vim.keymap.set('n', '<leader>tt', function()
    local current = vim.g.colors_name or ""
    local new_theme

    if current:match("latte") or current:match("light") then
      new_theme = "catppuccin-mocha"
    else
      new_theme = "catppuccin-latte"
    end

    -- Write to state file
    local theme_file = get_theme_file()
    local dir = theme_file:match("(.*/)")
    if dir then
      os.execute("mkdir -p " .. dir)
    end
    local f = io.open(theme_file, "w")
    if f then
      f:write(new_theme)
      f:close()
    end

    vim.cmd.colorscheme(new_theme)
    vim.notify("Switched to " .. new_theme, vim.log.levels.INFO)
  end, { desc = 'Toggle light/dark theme' })
end

return M
