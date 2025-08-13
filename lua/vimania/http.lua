-- HTTP client for URL title fetching using plenary.curl
-- Lua port of Rust URL title fetching functionality

local M = {}
local utils = require('vimania.utils')

-- State
local state = {
  config = {}
}

-- Setup function
function M.setup(config)
  state.config = config or {}
end

-- Validate URL for security (SSRF protection)
-- Equivalent to validate_url from lib.rs
local function validate_url(url_str)
  local config = require('vimania.config')
  
  -- Parse URL
  local url_parts = utils.parse_url(url_str)
  if not url_parts then
    return nil, 'Invalid URL format'
  end
  
  -- Check allowed schemes
  local allowed_schemes = config.get_allowed_schemes()
  local scheme_allowed = false
  for _, scheme in ipairs(allowed_schemes) do
    if url_parts.scheme == scheme then
      scheme_allowed = true
      break
    end
  end
  
  if not scheme_allowed then
    return nil, 'Unsupported URL scheme: ' .. url_parts.scheme
  end
  
  -- Check for local/internal networks if security is enabled
  if config.should_block_local_networks() then
    if utils.is_local_network(url_parts.host) then
      return nil, 'Access to internal/local networks is not allowed: ' .. url_parts.host
    end
  end
  
  return url_parts, nil
end

-- Extract title from HTML content
-- Simple HTML title extraction using Lua patterns
local function extract_title_from_html(html_content)
  if not html_content or html_content == '' then
    return nil
  end
  
  -- Look for <title>...</title> tags (case insensitive)
  local title = html_content:match('<[Tt][Ii][Tt][Ll][Ee][^>]*>([^<]*)</[Tt][Ii][Tt][Ll][Ee]>')
  
  if title then
    -- Decode common HTML entities
    title = title:gsub('&amp;', '&')
    title = title:gsub('&lt;', '<')
    title = title:gsub('&gt;', '>')
    title = title:gsub('&quot;', '"')
    title = title:gsub('&#39;', "'")
    title = title:gsub('&nbsp;', ' ')
    
    -- Trim whitespace
    title = vim.trim(title)
    
    if title ~= '' then
      return title
    end
  end
  
  return nil
end

-- Get URL title synchronously
-- Equivalent to _get_url_title from lib.rs
function M.get_url_title_sync(url)
  -- Validate URL
  local url_parts, err = validate_url(url)
  if err then
    return nil, err
  end
  
  utils.log('INFO', 'Fetching URL title for: ' .. url)
  
  -- Check if plenary is available
  local ok, curl = pcall(require, 'plenary.curl')
  if not ok then
    return nil, 'plenary.nvim is required for HTTP requests'
  end
  
  -- Configure request
  local config = require('vimania.config')
  local timeout = config.get_timeout()
  
  local response = curl.get(url, {
    timeout = timeout,
    headers = {
      ['User-Agent'] = 'vimania-lua/2.0.0'
    }
  })
  
  if response.status ~= 200 then
    return nil, string.format('HTTP request failed with status %d', response.status)
  end
  
  if not response.body then
    return nil, 'Empty response body'
  end
  
  -- Extract title from HTML
  local title = extract_title_from_html(response.body)
  if not title then
    return nil, 'No title element found'
  end
  
  return title, nil
end

-- Get URL title asynchronously
-- Uses plenary.async for non-blocking operation
function M.get_url_title(url, callback)
  callback = callback or function() end
  
  -- Validate URL first (synchronous, fast)
  local url_parts, err = validate_url(url)
  if err then
    callback(nil, err)
    return
  end
  
  -- Check if plenary.async is available
  local async_ok, async = pcall(require, 'plenary.async')
  if not async_ok then
    -- Fall back to synchronous version
    local title, sync_err = M.get_url_title_sync(url)
    callback(title, sync_err)
    return
  end
  
  -- Use async version
  async.run(function()
    local curl_ok, curl = pcall(require, 'plenary.curl')
    if not curl_ok then
      callback(nil, 'plenary.nvim is required for HTTP requests')
      return
    end
    
    utils.log('INFO', 'Fetching URL title asynchronously for: ' .. url)
    
    local config = require('vimania.config')
    local timeout = config.get_timeout()
    
    -- Make async HTTP request
    local response = curl.get(url, {
      timeout = timeout,
      headers = {
        ['User-Agent'] = 'vimania-lua/2.0.0'
      }
    })
    
    if response.status ~= 200 then
      callback(nil, string.format('HTTP request failed with status %d', response.status))
      return
    end
    
    if not response.body then
      callback(nil, 'Empty response body')
      return
    end
    
    -- Extract title from HTML
    local title = extract_title_from_html(response.body)
    if not title then
      callback(nil, 'No title element found')
      return
    end
    
    -- Call back with result
    callback(title, nil)
  end)
end

-- Set vim global variable with URL title (for compatibility with original plugin)
function M.set_vim_url_title(url)
  M.get_url_title(url, function(title, err)
    vim.schedule(function()
      if err then
        utils.log('WARNING', string.format('Failed to get URL title for %s: %s', url, err))
        vim.g.vimania_url_title = 'UNKNOWN_URL_TITLE'
        vim.notify('[vimania] Failed to get URL title: ' .. err, vim.log.levels.WARN)
      else
        -- Escape single quotes for vim variable
        local escaped_title = title:gsub("'", "''")
        vim.g.vimania_url_title = escaped_title
        utils.log('DEBUG', 'Set vim variable g:vimania_url_title = ' .. escaped_title)
      end
    end)
  end)
end

-- Test function to check if HTTP client is working
function M.test_http_client()
  local test_url = 'https://httpbin.org/get'
  
  utils.log('INFO', 'Testing HTTP client with: ' .. test_url)
  
  M.get_url_title(test_url, function(title, err)
    if err then
      utils.log('ERROR', 'HTTP client test failed: ' .. err)
    else
      utils.log('INFO', 'HTTP client test successful. Title: ' .. (title or 'no title'))
    end
  end)
end

return M