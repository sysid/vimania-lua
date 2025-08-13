.DEFAULT_GOAL := help

VERSION = $(shell cat VERSION)

# Plugin paths
plugin_root = .
lua_src = $(plugin_root)/lua
tests_src = $(plugin_root)/tests

################################################################################
# Development \
DEVELOPMENT: ## ##############################################################

.PHONY: setup
setup: ## one-time development environment setup
	@echo "Setting up vimania-lua development environment..."
	@echo "✅ Pure Lua plugin - no additional setup required!"
	@echo "Ensure you have plenary.nvim installed in your Neovim config"

.PHONY: dev
dev: setup ## setup and open development environment
	@echo "Opening Neovim for development..."
	nvim .

.PHONY: check
check: test lint ## comprehensive check (lint + tests)

.PHONY: ci
ci: setup check ## simulate CI pipeline locally

################################################################################
# Testing \
TESTING: ## ##################################################################

.PHONY: test
test: ## run all tests using plenary.nvim
	@echo "Running vimania-lua test suite..."
	nvim --headless -c "lua require('tests.run_tests')" -c "qa"

.PHONY: test-interactive
test-interactive: ## run tests in interactive mode
	@echo "Running tests in interactive Neovim..."
	nvim -c "lua require('plenary.test_harness').test_directory('tests')"

.PHONY: test-file
test-file: ## run specific test file (usage: make test-file FILE=test_parser.lua)
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=test_parser.lua"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	nvim --headless -c "PlenaryBustedFile tests/$(FILE)" -c "qa"

.PHONY: test-utils
test-utils: ## run utility function tests
	nvim --headless -c "PlenaryBustedFile tests/test_utils.lua" -c "qa"

.PHONY: test-parser
test-parser: ## run parser tests
	nvim --headless -c "PlenaryBustedFile tests/test_parser.lua" -c "qa"

.PHONY: test-comprehensive
test-comprehensive: ## run comprehensive parser tests
	nvim --headless -c "PlenaryBustedFile tests/test_parser_comprehensive.lua" -c "qa"

.PHONY: test-real-world
test-real-world: ## run real-world scenario tests
	nvim --headless -c "PlenaryBustedFile tests/test_real_world_scenarios.lua" -c "qa"

.PHONY: test-link-selection
test-link-selection: ## run link selection tests
	nvim --headless -c "PlenaryBustedFile tests/test_link_selection.lua" -c "qa"

.PHONY: test-manual
test-manual: ## open test document for manual testing
	@echo "Opening test document for manual testing..."
	@echo "Position cursor on different links and press 'go' to test functionality"
	nvim tests/test_data/test.md

################################################################################
# Code Quality \
QUALITY: ## ##################################################################

.PHONY: lint
lint: ## run Lua linting (stylua if available)
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Running stylua formatting check..."; \
		stylua --check $(lua_src); \
	else \
		echo "stylua not found - install with: cargo install stylua"; \
		echo "Skipping lint check"; \
	fi

.PHONY: format
format: ## format Lua code with stylua
	@if command -v stylua >/dev/null 2>&1; then \
		echo "Formatting Lua code with stylua..."; \
		stylua $(lua_src); \
	else \
		echo "stylua not found - install with: cargo install stylua"; \
		exit 1; \
	fi

.PHONY: luacheck
luacheck: ## run luacheck for static analysis
	@if command -v luacheck >/dev/null 2>&1; then \
		echo "Running luacheck..."; \
		luacheck $(lua_src); \
	else \
		echo "luacheck not found - install with: luarocks install luacheck"; \
		echo "Skipping luacheck"; \
	fi

################################################################################
# Version Management \
VERSIONING: ## ###############################################################

.PHONY: bump-major
bump-major: check-github-token ## bump major version, tag and push
	bump-my-version bump --commit --tag major
	git push
	git push --tags
	@$(MAKE) create-release

.PHONY: bump-minor
bump-minor: check-github-token ## bump minor version, tag and push  
	bump-my-version bump --commit --tag minor
	git push
	git push --tags
	@$(MAKE) create-release

.PHONY: bump-patch
bump-patch: check-github-token ## bump patch version, tag and push
	bump-my-version bump --commit --tag patch
	git push
	git push --tags
	@$(MAKE) create-release

.PHONY: create-release
create-release: check-github-token ## create a release on GitHub via the gh cli
	@if ! command -v gh &>/dev/null; then \
		echo "You do not have the GitHub CLI (gh) installed. Please create the release manually."; \
		exit 1; \
	else \
		echo "Creating GitHub release for v$(VERSION)"; \
		gh release create "v$(VERSION)" --generate-notes --latest; \
	fi

.PHONY: check-github-token
check-github-token: ## check if GITHUB_TOKEN is set
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "GITHUB_TOKEN is not set. Please export your GitHub token before running this command."; \
		exit 1; \
	fi
	@echo "GITHUB_TOKEN is set"

.PHONY: version
version: ## show current version
	@echo "vimania-lua version: $(VERSION)"

################################################################################
# Documentation \
DOCUMENTATION: ## ############################################################

.PHONY: docs
docs: ## generate documentation
	@echo "Generating vimdoc from README.md..."
	@echo "Manual step: Update doc/vimania-lua.txt with current functionality"

################################################################################
# Plugin Management \
PLUGIN: ## ###################################################################

.PHONY: install-dev
install-dev: ## install plugin for development (symlink to nvim config)
	@echo "For development, add this to your Neovim config:"
	@echo "{ 'your-username/vimania-lua', dev = true, dir = '$(PWD)' }"

.PHONY: test-integration
test-integration: ## test plugin integration with real Neovim setup
	@echo "Testing plugin integration..."
	@echo "Make sure vimania-lua is loaded in your Neovim config"
	nvim -c "lua print(require('vimania'))" -c "qa"

################################################################################
# Cleanup \
CLEANUP: ## ##################################################################

.PHONY: clean
clean: ## remove build artifacts and temporary files
	@echo "Cleaning up..."
	find . -name "*.tmp" -delete
	find . -name "*.log" -delete
	find . -name ".DS_Store" -delete

################################################################################
# Utilities \
UTILITIES: ## #################################################################

.PHONY: _confirm
_confirm:
	@echo -n "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo "Action confirmed by user."

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([%a-zA-Z0-9_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		if target != "dummy":
			print("\033[36m%-20s\033[0m %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

.PHONY: help
help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)