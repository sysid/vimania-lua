-- Configuration management for vimania.nvim

local M = {}

local state = {
  config = {}
}

-- Setup configuration
function M.setup(config)
  state.config = config or {}
end

-- Get configuration value
function M.get(key, default)
  if key == nil then
    return state.config
  end
  
  local keys = vim.split(key, '%.', { plain = true })
  local value = state.config
  
  for _, k in ipairs(keys) do
    if type(value) ~= 'table' or value[k] == nil then
      return default
    end
    value = value[k]
  end
  
  return value
end

-- Check if extension should be opened in Neovim
function M.should_open_in_nvim(file_path)
  local extensions = M.get('extensions', {})
  if not extensions or #extensions == 0 then
    return true -- Default to opening in nvim if no extensions specified
  end
  
  -- Parse file path to remove anchors before checking extension
  local utils = require('vimania.utils')
  local parsed = utils.parse_file_path(file_path)
  local clean_path = parsed.path
  
  -- Debug logging
  print(string.format("[DEBUG] should_open_in_nvim: original='%s', parsed='%s'", file_path, clean_path))
  
  local ext = vim.fn.fnamemodify(clean_path, ':e')
  if ext and ext ~= '' then
    ext = '.' .. ext
    print(string.format("[DEBUG] Extension found: '%s'", ext))
    for _, allowed_ext in ipairs(extensions) do
      if allowed_ext == ext then
        print(string.format("[DEBUG] Match found! Extension '%s' is allowed", ext))
        return true
      end
    end
  else
    print("[DEBUG] No extension found")
  end
  
  print("[DEBUG] No matching extension found, opening with OS")
  return false
end

-- Get timeout value in milliseconds
function M.get_timeout()
  return M.get('timeout', 3000)
end

-- Get log level
function M.get_log_level()
  return M.get('log_level', 'INFO')
end

-- Check security settings
function M.should_block_local_networks()
  return M.get('security.block_local_networks', true)
end

function M.get_allowed_schemes()
  return M.get('security.allowed_schemes', { 'http', 'https' })
end

-- Get browser command
function M.get_browser_cmd()
  return M.get('browser_cmd')
end

-- Get key mapping
function M.get_key_mapping()
  return M.get('key_mapping', 'go')
end

return M