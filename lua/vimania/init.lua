-- vimania.nvim - Advanced URI handling for modern Neovim
-- Lua port of vimania-uri-rs with zero external dependencies except plenary.nvim

local M = {}

-- Plugin version
M.version = "2.0.0"

-- Default configuration
local default_config = {
  -- File extensions to open in Neovim (others use OS default)
  extensions = { '.md', '.txt', '.rst', '.py', '.conf', '.sh', '.json', '.yaml', '.yml' },
  
  -- Key mapping for URI navigation (default: 'go')
  key_mapping = 'go',
  
  -- Timeout for HTTP requests (milliseconds) 
  timeout = 3000,
  
  -- Log level (DEBUG, INFO, WARNING, ERROR)
  log_level = 'INFO',
  
  -- Custom browser command (optional)
  browser_cmd = nil,
  
  -- Security settings
  security = {
    -- Block access to local/internal networks (SSRF protection)
    block_local_networks = true,
    -- Allowed URL schemes
    allowed_schemes = { 'http', 'https' }
  }
}

-- Plugin state
local state = {
  config = {},
  initialized = false
}

-- Setup function called by user
function M.setup(opts)
  opts = opts or {}
  
  -- Merge user config with defaults
  state.config = vim.tbl_deep_extend('force', default_config, opts)
  
  -- Initialize plugin modules
  local ok, err = pcall(function()
    require('vimania.config').setup(state.config)
    require('vimania.parser').setup(state.config)
    require('vimania.navigator').setup(state.config)
    require('vimania.http').setup(state.config)
  end)
  
  if not ok then
    vim.notify('[vimania] Failed to initialize: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  
  state.initialized = true
  
  if state.config.log_level == 'DEBUG' then
    vim.notify('[vimania] Initialized successfully with config: ' .. vim.inspect(state.config), vim.log.levels.DEBUG)
  end
end

-- Main URI handling function - equivalent to HandleMd in original
function M.handle_uri()
  if not state.initialized then
    vim.notify('[vimania] Plugin not initialized. Call require("vimania").setup() first.', vim.log.levels.ERROR)
    return
  end
  
  local ok, result = pcall(function()
    return require('vimania.navigator').handle_uri_at_cursor()
  end)
  
  if not ok then
    vim.notify('[vimania] Error handling URI: ' .. tostring(result), vim.log.levels.ERROR)
  end
end

-- Get URL title function - equivalent to GetURLTitle in original
function M.get_url_title(url)
  if not state.initialized then
    vim.notify('[vimania] Plugin not initialized. Call require("vimania").setup() first.', vim.log.levels.ERROR)
    return
  end
  
  return require('vimania.http').get_url_title(url)
end

-- Paste markdown link function - equivalent to PasteMDLink in original
function M.paste_md_link()
  if not state.initialized then
    vim.notify('[vimania] Plugin not initialized. Call require("vimania").setup() first.', vim.log.levels.ERROR)
    return
  end
  
  local clipboard_content = vim.fn.getreg('+')
  if not clipboard_content or clipboard_content == '' then
    vim.notify('[vimania] Clipboard is empty', vim.log.levels.WARN)
    return
  end
  
  -- Check if clipboard contains a URL
  local utils = require('vimania.utils')
  if not utils.is_url(clipboard_content) then
    vim.notify('[vimania] Clipboard does not contain a valid URL', vim.log.levels.WARN)
    return
  end
  
  -- Get title asynchronously and insert markdown link
  require('vimania.http').get_url_title(clipboard_content, function(title, err)
    vim.schedule(function()
      if err then
        vim.notify('[vimania] Failed to get URL title: ' .. err, vim.log.levels.WARN)
        title = 'UNKNOWN_URL_TITLE'
      end
      
      local md_link = string.format('[%s](%s)', title or 'UNKNOWN_URL_TITLE', clipboard_content)
      vim.api.nvim_put({ md_link }, 'c', true, true)
    end)
  end)
end

-- Find next/previous link functions
function M.find_next_link()
  require('vimania.parser').find_next_link()
end

function M.find_prev_link()
  require('vimania.parser').find_prev_link()
end

-- Utility functions for external access
function M.get_config()
  return state.config
end

function M.is_initialized()
  return state.initialized
end

return M