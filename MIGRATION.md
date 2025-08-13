# Migration Guide: vimania-uri-rs → vimania-lua

This document outlines the migration from the Rust/Python hybrid vimania-uri-rs plugin to the pure Lua vimania-lua implementation.

## Overview

vimania-lua is a complete rewrite of vimania-uri-rs in pure Lua, maintaining full feature parity while eliminating external dependencies (except plenary.nvim).

## Key Differences

### Dependencies
- **Before**: Python 3.10+, Rust toolchain, maturin, system packages
- **After**: Only plenary.nvim (pure Lua plugin)

### Performance
- **Before**: Fast runtime but slow installation/build process
- **After**: Instant installation, fast runtime with async support

### Architecture
- **Before**: Rust core + Python wrapper + Vim script interface
- **After**: Pure Lua with modern Neovim APIs

## Installation Migration

### Old Installation (vimania-uri-rs)
```vim
" vim-plug
Plug 'https://github.com/sysid/vimania-uri-rs.git', {
  \ 'do': 'pip install vimania-uri-rs --upgrade --target ~/.vim/plugged/vimania-uri-rs/pythonx',
  \ 'branch': 'main'
  \ }

" Or build from source
Plug 'https://github.com/sysid/vimania-uri-rs.git', {
  \ 'do': 'python3 build.py',
  \ 'branch': 'main'
  \ }
```

### New Installation (vimania-lua)
```lua
-- lazy.nvim
{
  'your-username/vimania-lua',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('vimania').setup()
  end
}
```

## Configuration Migration

### Old Configuration (vimania-uri-rs)
```vim
" File extensions
let g:vimania_uri_extensions = ['.md', '.txt', '.rst']

" Log level
let g:vimania_uri_log_level = 'INFO'

" Timeout
let g:vimania_uri_timeout = 3000

" Browser command
let g:vimania_uri_browser_cmd = 'firefox'
```

### New Configuration (vimania-lua)
```lua
require('vimania').setup({
  -- File extensions  
  extensions = { '.md', '.txt', '.rst' },
  
  -- Log level
  log_level = 'INFO',
  
  -- Timeout (now in milliseconds, not seconds)
  timeout = 3000,
  
  -- Browser command
  browser_cmd = 'firefox',
  
  -- New security options
  security = {
    block_local_networks = true,
    allowed_schemes = { 'http', 'https' }
  }
})
```

## Feature Parity

### ✅ Fully Supported
- All link types (local files, URLs, internal links, references)
- Line number navigation (`:30`)
- Anchor navigation (`#heading`)
- SSRF protection
- URL title fetching
- Cross-platform file opening
- Pelican link format
- Custom ID attribute lists
- Reference-style links

### ✅ Enhanced Features
- Async URL title fetching (non-blocking)
- Better error handling with vim.notify
- Modern Lua patterns and APIs
- Improved logging system
- More comprehensive security options

### 🔄 Changed Behavior
- HTTP timeout now specified in milliseconds (was seconds)
- Configuration via Lua table instead of vim variables
- Automatic initialization if no setup() called
- Enhanced debug logging format

## Command Compatibility

All original commands are preserved for backward compatibility:

| Original | New | Status |
|----------|-----|--------|
| `:HandleMd` | `:VimaniaHandleUri` | ✅ Both work |
| `:GetURLTitle` | `:VimaniaGetUrlTitle` | ✅ Both work |
| `go` mapping | `go` mapping | ✅ Same |
| `<leader>vl` mapping | `<leader>vl` mapping | ✅ Same |

## Migration Steps

1. **Remove old plugin**:
   ```vim
   " Remove from your plugin manager
   " Plug 'sysid/vimania-uri-rs' 
   ```

2. **Add new plugin**:
   ```lua
   -- Add to lazy.nvim or your plugin manager
   {
     'your-username/vimania-lua',
     dependencies = { 'nvim-lua/plenary.nvim' },
     config = function()
       require('vimania').setup()
     end
   }
   ```

3. **Update configuration**:
   - Convert vim variables to Lua table format
   - Update timeout units if needed (seconds → milliseconds)
   - Remove Python-specific settings

4. **Test functionality**:
   - Verify all link types work as expected
   - Test URL title fetching
   - Check file opening behavior
   - Validate security features

## Breaking Changes

### None for Basic Usage
If you used the plugin with default settings, no changes are required. All commands and key mappings work identically.

### Configuration Format
The main breaking change is configuration format:
- Old: Vim variables (`let g:vimania_uri_extensions = [...]`)
- New: Lua setup function (`require('vimania').setup({...})`)

### Python API Removal
If you were calling Python functions directly:
```python
# This no longer works
xUriMgr.call_handle_md2()
```

Use Lua API instead:
```lua
require('vimania').handle_uri()
```

## Advantages of Migration

1. **Faster Installation**: No build process or compilation
2. **Reduced Dependencies**: Only plenary.nvim required
3. **Better Performance**: Native Lua implementation
4. **Modern APIs**: Uses latest Neovim features
5. **Improved Maintainability**: Single language codebase
6. **Enhanced Security**: More comprehensive SSRF protection
7. **Async Support**: Non-blocking URL requests

## Rollback Plan

If you need to rollback to the old plugin:

1. Remove vimania-lua from your plugin manager
2. Re-add vimania-uri-rs with build configuration
3. Restore old vim variable configuration
4. Restart Neovim

The old plugin repository remains available for this purpose.

## Support

For migration issues:
1. Check the [troubleshooting guide](README.md#troubleshooting)
2. Enable debug mode: `log_level = 'DEBUG'`
3. Compare behavior with test files in `tests/test_data/`
4. Open an issue with debug output

## Testing Migration

Use the provided test file to verify functionality:
```bash
nvim tests/test_data/test.md
```

Test each link type with `go` to ensure proper migration.