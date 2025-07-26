.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: install
install: ## Install dependencies (SwiftLint and SwiftFormat)
	brew bundle

.PHONY: lint
lint: ## Run SwiftLint
	swiftlint

.PHONY: lint-fix
lint-fix: ## Run SwiftLint with auto-fix
	swiftlint --fix

.PHONY: format
format: ## Run SwiftFormat
	swiftformat .

.PHONY: format-check
format-check: ## Check if formatting is needed (CI-friendly)
	swiftformat . --lint

.PHONY: check
check: ## Run all checks (lint + format check)
	@echo "Running SwiftLint..."
	swiftlint
	@echo "\nChecking SwiftFormat..."
	swiftformat . --lint
	@echo "\nAll checks passed!"

.PHONY: fix
fix: ## Fix all issues (lint auto-fix + format)
	@echo "Running SwiftLint auto-fix..."
	swiftlint --fix
	@echo "\nRunning SwiftFormat..."
	swiftformat .
	@echo "\nAll fixes applied!"

.PHONY: build
build: ## Build the package
	swift build -Xswiftc -strict-concurrency=complete

.PHONY: test
test: ## Run tests
	swift test

.PHONY: clean
clean: ## Clean build artifacts
	swift package clean
	rm -rf .build

.PHONY: ci
ci: check build test ## Run CI checks (lint, format check, build, test)