-- Test runner for vimania.nvim using plenary.test_harness

-- Ensure plenary is available
local ok, plenary = pcall(require, 'plenary')
if not ok then
  print('Error: plenary.nvim is required to run tests')
  os.exit(1)
end

-- Add the lua directory to package path for testing
local plugin_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ':p:h:h')
local lua_path = plugin_root .. '/lua/?.lua;' .. plugin_root .. '/lua/?/init.lua'
package.path = lua_path .. ';' .. package.path

print('Running vimania.lua test suite...')
print('Plugin root: ' .. plugin_root)
print('Test files:')

-- List test files that will be run
local test_files = {
  'test_utils.lua',
  'test_parser.lua', 
  'test_parser_comprehensive.lua',
  'test_link_selection.lua',
  'test_real_world_scenarios.lua'
}

for _, file in ipairs(test_files) do
  local file_path = plugin_root .. '/tests/' .. file
  if vim.fn.filereadable(file_path) == 1 then
    print('  ✓ ' .. file)
  else
    print('  ✗ ' .. file .. ' (missing)')
  end
end

print('\nStarting tests...\n')

-- Run all tests
require('plenary.test_harness').test_directory('.', {
  minimal_init = vim.fn.expand('~/.config/nvim/init.lua'),
  sequential = true
})