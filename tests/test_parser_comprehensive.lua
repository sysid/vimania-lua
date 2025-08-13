-- Comprehensive tests for vimania parser functionality
-- Focus on markdown link parsing with various cursor positions

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

describe('parser comprehensive', function()
  before_each(function()
    parser.setup({})
  end)
  
  describe('markdown link parsing with cursor positions', function()
    describe('simple markdown link', function()
      local test_line = '[GitHub](https://github.com)'
      local expected_url = 'https://github.com'
      
      -- Test cursor at different positions within the markdown link
      local test_cases = {
        {pos = 0, desc = 'cursor on opening bracket ['},
        {pos = 1, desc = 'cursor on G in GitHub'},
        {pos = 3, desc = 'cursor on t in GitHub'}, 
        {pos = 6, desc = 'cursor on b in GitHub'},
        {pos = 7, desc = 'cursor on closing bracket ]'},
        {pos = 8, desc = 'cursor on opening paren ('},
        {pos = 10, desc = 'cursor on t in https'},
        {pos = 15, desc = 'cursor on / in https://'},
        {pos = 20, desc = 'cursor on t in github'},
        {pos = 25, desc = 'cursor on o in .com'},
        {pos = 28, desc = 'cursor on closing paren )'},
      }
      
      for _, test_case in ipairs(test_cases) do
        it('should extract URL when ' .. test_case.desc, function()
          mock_vim_api({ row = 0, col = test_case.pos }, { test_line })
          local result = parser.parse_line_at_cursor()
          assert.are.equal(expected_url, result)
        end)
      end
    end)
    
    describe('complex markdown link with spaces and special characters', function()
      local test_line = '[GitHub - sysid/vimania-lua](https://github.com/sysid/vimania-lua)'
      local expected_url = 'https://github.com/sysid/vimania-lua'
      
      local test_cases = {
        {pos = 0, desc = 'cursor at start of link'},
        {pos = 5, desc = 'cursor on u in GitHub'}, 
        {pos = 10, desc = 'cursor on space'},
        {pos = 12, desc = 'cursor on s in sysid'},
        {pos = 20, desc = 'cursor on / in sysid/vimania'},
        {pos = 25, desc = 'cursor on i in vimania'},
        {pos = 30, desc = 'cursor on closing bracket'},
        {pos = 35, desc = 'cursor in URL part'},
        {pos = 50, desc = 'cursor on github.com'},
        {pos = 65, desc = 'cursor near end of URL'},
      }
      
      for _, test_case in ipairs(test_cases) do
        it('should extract URL when ' .. test_case.desc, function()
          if test_case.pos < #test_line then -- Only test valid positions
            mock_vim_api({ row = 0, col = test_case.pos }, { test_line })
            local result = parser.parse_line_at_cursor()
            assert.are.equal(expected_url, result)
          end
        end)
      end
    end)
    
    describe('multiple markdown links on same line', function()
      local test_line = 'See [GitHub](https://github.com) and [Google](https://google.com) links'
      
      it('should extract first URL when cursor on first link', function()
        mock_vim_api({ row = 0, col = 7 }, { test_line }) -- cursor on "GitHub"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('https://github.com', result)
      end)
      
      it('should extract second URL when cursor on second link', function()
        mock_vim_api({ row = 0, col = 40 }, { test_line }) -- cursor on "Google"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('https://google.com', result)
      end)
      
      it('should return nil when cursor between links', function()
        mock_vim_api({ row = 0, col = 30 }, { test_line }) -- cursor on " and "
        local result = parser.parse_line_at_cursor()
        assert.is_nil(result)
      end)
    end)
    
    describe('reference style links', function()
      it('should handle reference links [text][ref]', function()
        local lines = {
          'Check out [this project][project-ref] for more info',
          '',
          '[project-ref]: https://github.com/example/project'
        }
        mock_vim_api({ row = 0, col = 15 }, lines) -- cursor on "project"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('https://github.com/example/project', result)
      end)
      
      it('should handle implicit reference links [text][]', function()
        local lines = {
          'Check out [GitHub][] for more info',
          '',
          '[GitHub]: https://github.com'
        }
        mock_vim_api({ row = 0, col = 12 }, lines) -- cursor on "GitHub"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('https://github.com', result)
      end)
    end)
    
    describe('edge cases and special formats', function()
      it('should handle internal anchor links', function()
        local test_line = 'Jump to [section](#heading-name)'
        mock_vim_api({ row = 0, col = 12 }, { test_line }) -- cursor on "section"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('#heading-name', result)
      end)
      
      it('should handle file links with line numbers', function()
        local test_line = 'Open [config](config.lua:25)'
        mock_vim_api({ row = 0, col = 10 }, { test_line }) -- cursor on "config"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('config.lua:25', result)
      end)
      
      it('should handle file links with anchors', function()
        local test_line = 'See [docs](README.md#installation)'
        mock_vim_api({ row = 0, col = 8 }, { test_line }) -- cursor on "docs"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('README.md#installation', result)
      end)
      
      it('should handle pelican-style |filename| links', function()
        local test_line = 'Read [post]({filename}./blog-post.md)'
        mock_vim_api({ row = 0, col = 8 }, { test_line }) -- cursor on "post"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('{filename}./blog-post.md', result)
      end)
      
      it('should handle links with spaces in URLs', function()
        local test_line = '[Spaced Link](./path with spaces/file.md)'
        mock_vim_api({ row = 0, col = 5 }, { test_line }) -- cursor on "Spaced"
        local result = parser.parse_line_at_cursor()
        assert.are.equal('./path with spaces/file.md', result)
      end)
    end)
  end)
  
  describe('standalone URL detection', function()
    it('should detect standalone URLs when not in markdown links', function()
      local test_line = 'Visit https://example.com for info'
      
      -- Test different positions within the URL
      local test_cases = {
        {pos = 8, desc = 'cursor on h in https'},
        {pos = 15, desc = 'cursor on / in https://'},
        {pos = 20, desc = 'cursor on x in example'},
        {pos = 26, desc = 'cursor on o in .com'},
      }
      
      for _, test_case in ipairs(test_cases) do
        it('should detect URL when ' .. test_case.desc, function()
          mock_vim_api({ row = 0, col = test_case.pos }, { test_line })
          local result = parser.parse_line_at_cursor()
          assert.are.equal('https://example.com', result)
        end)
      end
    end)
    
    it('should not detect URLs inside markdown links as standalone', function()
      local test_line = '[Link](https://github.com) and https://google.com'
      
      -- Cursor on URL inside markdown link should extract from markdown
      mock_vim_api({ row = 0, col = 15 }, { test_line }) -- inside [Link](https://github.com)
      local result = parser.parse_line_at_cursor()
      assert.are.equal('https://github.com', result) -- Should get URL from markdown parsing
      
      -- Cursor on standalone URL should work normally  
      mock_vim_api({ row = 0, col = 45 }, { test_line }) -- on standalone https://google.com
      result = parser.parse_line_at_cursor()
      assert.are.equal('https://google.com', result)
    end)
  end)
  
  describe('priority and parsing order', function()
    it('should prioritize markdown links over standalone URLs', function()
      -- When cursor is on a URL that's part of a markdown link,
      -- it should return the URL extracted from markdown parsing, not standalone URL parsing
      local test_line = '[GitHub](https://github.com/user/repo)'
      
      -- Cursor directly on the URL part
      mock_vim_api({ row = 0, col = 20 }, { test_line }) -- cursor on "github.com"
      local result = parser.parse_line_at_cursor()
      assert.are.equal('https://github.com/user/repo', result)
    end)
    
    it('should fall back to file path detection when no URLs or markdown links', function()
      local test_line = 'Check file config.lua for settings'
      mock_vim_api({ row = 0, col = 15 }, { test_line }) -- cursor on "config.lua"
      local result = parser.parse_line_at_cursor()
      assert.are.equal('config.lua', result)
    end)
  end)
  
  describe('malformed or incomplete links', function()
    it('should handle incomplete markdown links gracefully', function()
      local test_line = '[Incomplete link without closing'
      mock_vim_api({ row = 0, col = 5 }, { test_line })
      local result = parser.parse_line_at_cursor()
      -- Should not crash and return nil or fall back to other parsing
      assert.is_truthy(result == nil or type(result) == 'string')
    end)
    
    it('should handle markdown links without URLs', function()
      local test_line = '[Empty link]()'
      mock_vim_api({ row = 0, col = 5 }, { test_line })
      local result = parser.parse_line_at_cursor()
      -- Should return empty string or nil
      assert.is_truthy(result == nil or result == '')
    end)
    
    it('should handle nested brackets gracefully', function()
      local test_line = '[Text with [nested] brackets](https://example.com)'
      mock_vim_api({ row = 0, col = 15 }, { test_line }) -- cursor on "nested"
      local result = parser.parse_line_at_cursor()
      assert.are.equal('https://example.com', result)
    end)
  end)
end)