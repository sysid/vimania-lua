# vimania-lua

**Advanced URI Handling for Modern Neovim**

A pure Lua reimplementation of the [vimania-uri-rs](https://github.com/sysid/vimania-uri-rs) plugin, providing lightning-fast URI navigation with zero external dependencies except plenary.nvim.

## ✨ Features

- **Pure Lua Implementation**: No Python, Rust, or system dependencies (except plenary.nvim)
- **Universal URI Support**: Handle web URLs, local files, internal links, and more
- **Smart Markdown Integration**: Auto-fetch page titles for reference-style links
- **Precise Navigation**: Jump to specific headings, line numbers, or anchors
- **Security First**: Built-in SSRF protection and comprehensive security auditing
- **Extensive Format Support**: Open HTML, DOCX, PPTX, images, audio, and more
- **Modern Architecture**: Native Neovim Lua APIs with async HTTP support
- **Zero Startup Overhead**: No external processes or compilation required

## 🚀 Why vimania-lua?

This is a complete rewrite of vimania-uri-rs in pure Lua, offering:
- **Faster Installation**: No build process or external dependencies
- **Better Integration**: Native Neovim APIs and async support
- **Easier Maintenance**: Single language codebase with modern Lua patterns
- **Enhanced Performance**: Leverages Neovim's built-in optimizations

## 📦 Installation

### Prerequisites
- Neovim 0.7+
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

### Using lazy.nvim
```lua
{
  'your-username/vimania-lua',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('vimania').setup({
      -- Optional configuration (see Configuration section)
    })
  end
}
```

### Using packer.nvim
```lua
use {
  'your-username/vimania-lua',
  requires = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('vimania').setup()
  end
}
```

### Using vim-plug
```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'your-username/vimania-lua'
```

Then in your `init.lua`:
```lua
require('vimania').setup()
```

## 🎯 Quick Start

**It's simple**: Position your cursor on any URI and press `go`.

```
go
```

That's it! The plugin intelligently determines how to handle the URI based on its type and context.

## 📝 Supported Link Types

### Local Text Links
`[foo](second.md)` will be opened inside Neovim.
If the target contains line number as in `[foo](second.md:30)`, the line will be jumped to.
Also anchors are supported, for example `[foo](second.md#custom-id)`.

### URL Links
`[google](https://google.com)` will be opened with the OS browser.

### Non-Text Files
If the file extension is not in the `extensions` configuration, non-text files will be opened via the operating system.
This behavior is handy when linking to binary documents, for example PDFs.

### Internal Links
`[Link Text](#Target)`, will link to the heading `# Target`.
Following the link will jump to the heading inside Neovim.
Currently both GitHub style anchors (all words lowercased and hyphenated) and custom IDs are supported.

### Reference Style Links
For links of the form `[foo][label]`, vimania will lookup the corresponding label and open the target referenced there.

### Implicit Name Links
For links of the form `[foo][]` will use `foo` as the label and then follow the logic of reference style links.

### Custom IDs via Attribute Lists
The ID a link target can be defined via attribute lists of the form `{: #someid ...}`.
This way fixed name references can be defined to prevent links from going stale after headings have been changed.

### Pelican Link Format
Vimania handles `|filename|` and `{filename}` links as expected, for example `[link](|filename|./second.md)` and `[link]({filename}../posts/second.md)`.

## ⚙️ Configuration

### Default Configuration
```lua
require('vimania').setup({
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
})
```

### Custom Key Mappings
If you prefer different key mappings:

```lua
require('vimania').setup({
  key_mapping = '<leader>go' -- Use leader+go instead of just go
})
```

Or disable automatic mappings and create your own:
```lua
require('vimania').setup({
  key_mapping = nil -- Disable automatic mapping
})

-- Create custom mappings
vim.keymap.set('n', '<leader>u', function() require('vimania').handle_uri() end, { desc = 'Handle URI' })
vim.keymap.set('n', '<leader>vl', function() require('vimania').paste_md_link() end, { desc = 'Paste MD link' })
```

## 🔧 Commands

- `:VimaniaHandleUri` - Handle URI at cursor position
- `:VimaniaGetUrlTitle <url>` - Get title for URL and set vim variable
- `:VimaniaPasteMdLink` - Paste markdown link from clipboard URL
- `:VimaniaFindLinkNext` - Find next link in buffer
- `:VimaniaFindLinkPrev` - Find previous link in buffer
- `:VimaniaEdit <path#anchor>` - Edit file with optional anchor
- `:VimaniaTestHttp` - Test HTTP client functionality

### Compatibility Commands
For compatibility with the original plugin:
- `:HandleMd` - Same as `:VimaniaHandleUri`
- `:GetURLTitle <url>` - Same as `:VimaniaGetUrlTitle`

## 🎮 Default Key Mappings

- `go` - Handle URI at cursor (`<Plug>(VimaniaHandleUri)`)
- `<leader>vl` - Paste markdown link from clipboard (`<Plug>(VimaniaPasteMdLink)`)

Additional plug mappings available:
- `<Plug>(VimaniaFindLinkNext)` - Find next link
- `<Plug>(VimaniaFindLinkPrev)` - Find previous link

## 🔒 Security Features

### SSRF Protection
The plugin includes built-in protection against Server-Side Request Forgery (SSRF) attacks:

- Blocks access to local networks (127.0.0.1, localhost, 192.168.x.x, etc.)
- Only allows HTTP and HTTPS schemes by default
- Validates URLs before making requests

You can configure security settings:
```lua
require('vimania').setup({
  security = {
    block_local_networks = false, -- Disable local network blocking
    allowed_schemes = { 'http', 'https', 'ftp' } -- Allow additional schemes
  }
})
```

## 🧪 Testing

### Running Tests

**Run all tests:**
```bash
# Headless mode (for CI/automation)
nvim --headless -c "lua require('tests.run_tests')" -c "qa"

# Interactive mode (for development)
nvim -c "lua require('plenary.test_harness').test_directory('tests')"
```

**Run specific test files:**
```bash
# Test utility functions
nvim --headless -c "PlenaryBustedFile tests/test_utils.lua" -c "qa"

# Test parsing logic
nvim --headless -c "PlenaryBustedFile tests/test_parser.lua" -c "qa"
```

### Manual Testing

**Test with sample data:**
```bash
# Open the test document with various link types
nvim tests/test_data/test.md

# Position cursor on different links and press 'go' to test functionality
```

**Test HTTP functionality:**
```vim
" Test URL title fetching
:VimaniaGetUrlTitle https://www.example.com

" Test HTTP client
:VimaniaTestHttp

" Test clipboard markdown link pasting (copy a URL first)
:VimaniaPasteMdLink
```

### Test Coverage

The test suite covers:
- ✅ **URL parsing and validation** (including SSRF protection)
- ✅ **File path parsing** (line numbers, anchors, expansions)
- ✅ **Markdown link parsing** (direct, reference, internal links)
- ✅ **Utility functions** (anchor conversion, network detection)
- ✅ **Security features** (local network blocking, scheme validation)
- ✅ **Manual integration tests** (comprehensive test document)

## 🐛 Troubleshooting

### Debug Mode
Enable debug logging to troubleshoot issues:
```lua
require('vimania').setup({
  log_level = 'DEBUG'
})
```

### Common Issues

**Plugin not working**: Make sure plenary.nvim is installed and loaded before vimania.

**HTTP requests failing**: Check your network connection and firewall settings.

**File paths not opening**: Verify the file exists and you have appropriate permissions.

**Key mapping conflicts**: Check for conflicting mappings with `:nmap go`.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality  
4. Run the test suite
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Credits

- Original inspiration from [vimania-uri-rs](https://github.com/sysid/vimania-uri-rs)
- Built with [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- URI handling based on work by Christopher Prohm (mdnav)# vimania-lua
