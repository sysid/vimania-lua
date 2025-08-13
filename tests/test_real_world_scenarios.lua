-- Real-world integration tests for vimania.nvim
-- These test scenarios that users actually encounter

local parser = require('vimania.parser')

-- Mock vim API for testing
local function mock_vim_api(cursor_pos, lines)
  _G.vim = _G.vim or {}
  vim.api = vim.api or {}
  
  vim.api.nvim_win_get_cursor = function()
    return { cursor_pos.row + 1, cursor_pos.col } -- Convert to 1-indexed for vim API
  end
  
  vim.api.nvim_buf_get_lines = function()
    return lines
  end
  
  vim.trim = vim.trim or function(s)
    return s:match('^%s*(.-)%s*$')
  end
  
  vim.pesc = vim.pesc or function(s)
    return (s:gsub('[%(%)%.%+%-%*%?%[%]%^%$%%]', '%%%1'))
  end
end

describe('real-world scenarios', function()
  before_each(function()
    parser.setup({})
  end)
  
  describe('the original bug scenario', function()
    -- This is the exact scenario reported by the user
    it('should handle GitHub link from /tmp/x.md', function()
      local lines = {
        '# Header 1',
        'Some content',
        '## Subheader 1.1', 
        'More content',
        '## Subheader 1.2',
        'More content',
        '### Subheader 1.2',
        'More content',
        '#### Subheader 1.2',
        'More content',
        '##### Subheader 1.2',
        'More content',
        '###### Subheader 1.2',
        'More content',
        '',
        '# Header 2',
        'Different content',
        '',
        '✅ **Consistent**: Leader key remains comma for muscle memory compatibility',
        '',
        '## Core Navigation',
        '| Key | Action | Vim Equivalent |',
        '|-----|--------|----------------|',
        '| `<C-p>` | Fuzzy file finder (proximity-sorted) | Enhanced version of `<leader>ff` |',
        '| `<leader>;` | Buffer switcher | `<leader>fb` |',
        '| `<leader><space>` | Clear search highlight | `<leader><cr>` |',
        '| `H`, `L` | Jump to start/end of line | `^`, `$` |',
        '| `<leader><leader>` | Toggle between buffers | Similar |',
        '',
        '',
        '[GitHub - sysid/vimania-lua](https://github.com/sysid/vimania-lua)',
        ''
      }
      
      local github_line_index = 30 -- 0-indexed, line 31 in the file
      local github_line = lines[github_line_index + 1]
      
      -- Test various cursor positions on the GitHub link line
      local test_cases = {
        {pos = 0, desc = 'cursor at start of line'},
        {pos = 5, desc = 'cursor on "u" in GitHub'},
        {pos = 10, desc = 'cursor on "b" in GitHub'}, 
        {pos = 15, desc = 'cursor on "s" in sysid'},
        {pos = 25, desc = 'cursor on "n" in vimania'},
        {pos = 30, desc = 'cursor on closing bracket "]"'},
        {pos = 32, desc = 'cursor on opening paren "("'},
        {pos = 40, desc = 'cursor in URL https part'},
        {pos = 50, desc = 'cursor on github.com'},
        {pos = 60, desc = 'cursor near end of URL'},
      }
      
      for _, test in ipairs(test_cases) do
        if test.pos < #github_line then
          mock_vim_api({ row = github_line_index, col = test.pos }, lines)
          local result = parser.parse_line_at_cursor()
          assert.are.equal('https://github.com/sysid/vimania-lua', result, 
                          string.format('Failed when %s (pos %d)', test.desc, test.pos))
        end
      end
    end)
  end)
  
  describe('common markdown document patterns', function()
    it('should handle README.md style link lists', function()
      local lines = {
        '# Project Name',
        '',
        '## Links',
        '- [Documentation](https://docs.example.com)',
        '- [GitHub Repository](https://github.com/user/repo)',  
        '- [Issue Tracker](https://github.com/user/repo/issues)',
        '- [Live Demo](https://demo.example.com)',
        ''
      }
      
      -- Test each link in the list
      local test_cases = {
        {row = 3, expected = 'https://docs.example.com', desc = 'Documentation link'},
        {row = 4, expected = 'https://github.com/user/repo', desc = 'GitHub repo link'},
        {row = 5, expected = 'https://github.com/user/repo/issues', desc = 'Issue tracker link'},
        {row = 6, expected = 'https://demo.example.com', desc = 'Live demo link'},
      }
      
      for _, test in ipairs(test_cases) do
        mock_vim_api({ row = test.row, col = 5 }, lines) -- cursor on link text
        local result = parser.parse_line_at_cursor()
        assert.are.equal(test.expected, result, test.desc)
      end
    end)
    
    it('should handle technical documentation with code examples', function()
      local lines = {
        '## Installation',
        '',
        'Install via [npm](https://npmjs.com):',
        '',
        '```bash',
        'npm install package-name',  
        '```',
        '',
        'See the [API docs](./docs/api.md) for usage.',
        'Check [GitHub](https://github.com/owner/repo) for issues.',
      }
      
      -- Test links mixed with code blocks and various formatting
      mock_vim_api({ row = 2, col = 15 }, lines) -- cursor on "npm" link
      local result1 = parser.parse_line_at_cursor() 
      assert.are.equal('https://npmjs.com', result1)
      
      mock_vim_api({ row = 8, col = 10 }, lines) -- cursor on "API docs" link
      local result2 = parser.parse_line_at_cursor()
      assert.are.equal('./docs/api.md', result2)
      
      mock_vim_api({ row = 9, col = 10 }, lines) -- cursor on "GitHub" link  
      local result3 = parser.parse_line_at_cursor()
      assert.are.equal('https://github.com/owner/repo', result3)
    end)
    
    it('should handle blog post style content', function()
      local lines = {
        '# My Blog Post',
        '',
        'I recently discovered [this amazing tool](https://example-tool.com)',
        'that really changed my workflow. You can read more about it in',
        'the [official documentation](https://docs.example-tool.com/guide).',
        '',
        'For a quick start, check out [section 3](#quick-start) below.',
        '',
        '## Quick Start {: #quick-start}',
        '',
        'First, visit [the download page](https://example-tool.com/download)',
        'and follow the instructions.'
      }
      
      -- Test inline links in flowing text
      mock_vim_api({ row = 2, col = 25 }, lines) -- cursor on "amazing tool" 
      local result1 = parser.parse_line_at_cursor()
      assert.are.equal('https://example-tool.com', result1)
      
      mock_vim_api({ row = 4, col = 15 }, lines) -- cursor on "official documentation"
      local result2 = parser.parse_line_at_cursor() 
      assert.are.equal('https://docs.example-tool.com/guide', result2)
      
      mock_vim_api({ row = 6, col = 25 }, lines) -- cursor on "section 3" internal link
      local result3 = parser.parse_line_at_cursor()
      assert.are.equal('#quick-start', result3)
      
      mock_vim_api({ row = 10, col = 15 }, lines) -- cursor on "download page"
      local result4 = parser.parse_line_at_cursor()
      assert.are.equal('https://example-tool.com/download', result4)
    end)
  end)
  
  describe('edge cases from real usage', function()
    it('should handle links with unusual characters', function()
      local lines = {
        '[Complex URL](https://api.example.com/v2/users?id=123&sort=name&format=json#results)',
        '[File with spaces](./path with spaces/my file.md)',
        '[Unicode 测试](https://example.com/测试)',
        '[Query params](https://search.com?q=test+query&lang=en)',
      }
      
      -- Test complex URL with path, query params, and fragment
      mock_vim_api({ row = 0, col = 5 }, lines)
      local result1 = parser.parse_line_at_cursor()
      assert.are.equal('https://api.example.com/v2/users?id=123&sort=name&format=json#results', result1)
      
      -- Test file path with spaces
      mock_vim_api({ row = 1, col = 5 }, lines)
      local result2 = parser.parse_line_at_cursor()
      assert.are.equal('./path with spaces/my file.md', result2)
      
      -- Test unicode in URL and text
      mock_vim_api({ row = 2, col = 5 }, lines) 
      local result3 = parser.parse_line_at_cursor()
      assert.are.equal('https://example.com/测试', result3)
      
      -- Test URL with encoded spaces in query
      mock_vim_api({ row = 3, col = 5 }, lines)
      local result4 = parser.parse_line_at_cursor()
      assert.are.equal('https://search.com?q=test+query&lang=en', result4)
    end)
    
    it('should handle mixed content lines', function()
      local lines = {
        'Text before [link](url.com) and text after',
        'Multiple [first](url1.com) and [second](url2.com) links',
        'Link [inside](inner.com) parentheses (like this)',
        'Reference [style][ref] and [direct](direct.com) mixed',
        '',
        '[ref]: https://reference.com'
      }
      
      -- Link with surrounding text
      mock_vim_api({ row = 0, col = 15 }, lines)
      local result1 = parser.parse_line_at_cursor()
      assert.are.equal('url.com', result1)
      
      -- First of multiple links
      mock_vim_api({ row = 1, col = 12 }, lines)
      local result2 = parser.parse_line_at_cursor() 
      assert.are.equal('url1.com', result2)
      
      -- Second of multiple links
      mock_vim_api({ row = 1, col = 30 }, lines)
      local result3 = parser.parse_line_at_cursor()
      assert.are.equal('url2.com', result3)
      
      -- Link inside parentheses
      mock_vim_api({ row = 2, col = 10 }, lines)
      local result4 = parser.parse_line_at_cursor()
      assert.are.equal('inner.com', result4)
      
      -- Reference style link
      mock_vim_api({ row = 3, col = 12 }, lines) 
      local result5 = parser.parse_line_at_cursor()
      assert.are.equal('https://reference.com', result5)
      
      -- Direct link mixed with reference
      mock_vim_api({ row = 3, col = 35 }, lines)
      local result6 = parser.parse_line_at_cursor()
      assert.are.equal('direct.com', result6)
    end)
  end)
  
  describe('parser priority verification', function()
    it('should prioritize markdown over standalone URL detection', function()
      -- This verifies the fix we implemented
      local lines = {
        '[GitHub](https://github.com) standalone https://example.com'
      }
      
      -- Cursor on URL inside markdown link should extract from markdown
      mock_vim_api({ row = 0, col = 20 }, lines) -- cursor on "github" in URL
      local result1 = parser.parse_line_at_cursor()
      assert.are.equal('https://github.com', result1)
      
      -- Cursor on standalone URL should work normally
      mock_vim_api({ row = 0, col = 45 }, lines) -- cursor on standalone URL
      local result2 = parser.parse_line_at_cursor()
      assert.are.equal('https://example.com', result2)
    end)
    
    it('should maintain backward compatibility', function()
      -- Ensure we didn\'t break existing functionality
      local lines = {
        'https://standalone.com',                    -- standalone URL
        './local-file.md',                         -- file path
        '[markdown](link.md)',                     -- markdown link  
        '[ref-link][ref]',                        -- reference link
        '',
        '[ref]: https://reference.com'
      }
      
      -- Standalone URL
      mock_vim_api({ row = 0, col = 10 }, lines)
      local result1 = parser.parse_line_at_cursor()
      assert.are.equal('https://standalone.com', result1)
      
      -- File path  
      mock_vim_api({ row = 1, col = 5 }, lines)
      local result2 = parser.parse_line_at_cursor()
      assert.are.equal('./local-file.md', result2)
      
      -- Markdown link
      mock_vim_api({ row = 2, col = 5 }, lines)
      local result3 = parser.parse_line_at_cursor()
      assert.are.equal('link.md', result3)
      
      -- Reference link
      mock_vim_api({ row = 3, col = 5 }, lines)
      local result4 = parser.parse_line_at_cursor() 
      assert.are.equal('https://reference.com', result4)
    end)
  end)
end)