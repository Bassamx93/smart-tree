.PHONY: build xcframework zip clean help

# Variables
CARGO := cargo
PROJECT_NAME := smart-tree
VERSION := $(shell grep '^version' Cargo.toml | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
BUILD_DIR := target
RELEASE_DIR := $(BUILD_DIR)/release
XCFRAMEWORK_DIR := $(BUILD_DIR)/xcframework
XCFRAMEWORK_NAME := $(PROJECT_NAME).xcframework
OUTPUT_DIR := build_output

# Apple targets for xcframework
MACOS_ARM64_TARGET := aarch64-apple-darwin
MACOS_X86_64_TARGET := x86_64-apple-darwin
IOS_ARM64_TARGET := aarch64-apple-ios
IOS_SIM_ARM64_TARGET := aarch64-apple-ios-sim
IOS_X86_64_SIM_TARGET := x86_64-apple-ios

# Colors for output
GREEN := \033[0;32m
BLUE := \033[0;34m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help:
	@echo "$(BLUE)Smart Tree Build Targets$(NC)"
	@echo "========================"
	@echo "$(GREEN)make build$(NC)       - Build static libraries (release mode)"
	@echo "$(GREEN)make xcframework$(NC) - Build xcframework for Apple platforms"
	@echo "$(GREEN)make zip$(NC)         - Build xcframework and create release zip"
	@echo "$(GREEN)make clean$(NC)       - Clean build artifacts"
	@echo "$(GREEN)make help$(NC)        - Show this help message"
	@echo ""
	@echo "Project: $(PROJECT_NAME) v$(VERSION)"

build:
	@echo "$(BLUE)Building $(PROJECT_NAME) v$(VERSION)...$(NC)"
	@mkdir -p $(OUTPUT_DIR)
	$(CARGO) build --release 2>&1 | tee $(OUTPUT_DIR)/build.log
	@echo "$(GREEN)✓ Build complete!$(NC)"
	@echo "$(YELLOW)Output: $(RELEASE_DIR)/$(PROJECT_NAME)$(NC)"

build-macos-universal: build-macos-arm64 build-macos-x86_64
	@echo "$(BLUE)Creating universal macOS binary...$(NC)"
	@mkdir -p $(RELEASE_DIR)
	@lipo -create \
		$(RELEASE_DIR)/$(MACOS_ARM64_TARGET)/$(PROJECT_NAME) \
		$(RELEASE_DIR)/$(MACOS_X86_64_TARGET)/$(PROJECT_NAME) \
		-output $(RELEASE_DIR)/$(PROJECT_NAME)-macos-universal
	@echo "$(GREEN)✓ Universal binary created!$(NC)"

build-macos-arm64:
	@echo "$(BLUE)Building for macOS ARM64...$(NC)"
	@mkdir -p $(OUTPUT_DIR)
	rustup target add $(MACOS_ARM64_TARGET) 2>/dev/null || true
	$(CARGO) build --release --target=$(MACOS_ARM64_TARGET) 2>&1 | tee $(OUTPUT_DIR)/build-arm64.log
	@echo "$(GREEN)✓ macOS ARM64 build complete!$(NC)"

build-macos-x86_64:
	@echo "$(BLUE)Building for macOS x86_64...$(NC)"
	@mkdir -p $(OUTPUT_DIR)
	rustup target add $(MACOS_X86_64_TARGET) 2>/dev/null || true
	$(CARGO) build --release --target=$(MACOS_X86_64_TARGET) 2>&1 | tee $(OUTPUT_DIR)/build-x86_64.log
	@echo "$(GREEN)✓ macOS x86_64 build complete!$(NC)"

build-ios-arm64:
	@echo "$(BLUE)Building for iOS ARM64...$(NC)"
	@mkdir -p $(OUTPUT_DIR)
	rustup target add $(IOS_ARM64_TARGET) 2>/dev/null || true
	$(CARGO) build --release --target=$(IOS_ARM64_TARGET) 2>&1 | tee $(OUTPUT_DIR)/build-ios-arm64.log
	@echo "$(GREEN)✓ iOS ARM64 build complete!$(NC)"

build-ios-simulator:
	@echo "$(BLUE)Building for iOS Simulator...$(NC)"
	@mkdir -p $(OUTPUT_DIR)
	rustup target add $(IOS_SIM_ARM64_TARGET) 2>/dev/null || true
	$(CARGO) build --release --target=$(IOS_SIM_ARM64_TARGET) 2>&1 | tee $(OUTPUT_DIR)/build-ios-sim.log
	@echo "$(GREEN)✓ iOS Simulator build complete!$(NC)"

xcframework: build-macos-universal build-ios-arm64 build-ios-simulator
	@echo "$(BLUE)Creating xcframework...$(NC)"
	@mkdir -p $(XCFRAMEWORK_DIR)/$(XCFRAMEWORK_NAME)
	
	# Create macOS framework
	@mkdir -p $(XCFRAMEWORK_DIR)/macos.framework
	@cp -r $(RELEASE_DIR)/$(MACOS_ARM64_TARGET)/lib $(XCFRAMEWORK_DIR)/macos.framework/Modules 2>/dev/null || \
		mkdir -p $(XCFRAMEWORK_DIR)/macos.framework/Modules
	@cp $(RELEASE_DIR)/$(PROJECT_NAME)-macos-universal $(XCFRAMEWORK_DIR)/macos.framework/$(PROJECT_NAME)
	
	# Create iOS framework
	@mkdir -p $(XCFRAMEWORK_DIR)/ios.framework
	@mkdir -p $(XCFRAMEWORK_DIR)/ios.framework/Modules
	@cp $(RELEASE_DIR)/$(IOS_ARM64_TARGET)/lib$(PROJECT_NAME).a $(XCFRAMEWORK_DIR)/ios.framework/lib$(PROJECT_NAME).a 2>/dev/null || true
	
	# Create iOS Simulator framework
	@mkdir -p $(XCFRAMEWORK_DIR)/ios-simulator.framework
	@mkdir -p $(XCFRAMEWORK_DIR)/ios-simulator.framework/Modules
	@cp $(RELEASE_DIR)/$(IOS_SIM_ARM64_TARGET)/lib$(PROJECT_NAME).a $(XCFRAMEWORK_DIR)/ios-simulator.framework/lib$(PROJECT_NAME).a 2>/dev/null || true
	
	# Create module map
	@echo "module $(PROJECT_NAME) {" > $(XCFRAMEWORK_DIR)/macos.framework/Modules/module.modulemap
	@echo "  header \"$(PROJECT_NAME).h\"" >> $(XCFRAMEWORK_DIR)/macos.framework/Modules/module.modulemap
	@echo "  link \"$(PROJECT_NAME)\"" >> $(XCFRAMEWORK_DIR)/macos.framework/Modules/module.modulemap
	@echo "  export *" >> $(XCFRAMEWORK_DIR)/macos.framework/Modules/module.modulemap
	@echo "}" >> $(XCFRAMEWORK_DIR)/macos.framework/Modules/module.modulemap
	
	@echo "$(GREEN)✓ xcframework created at $(XCFRAMEWORK_DIR)$(NC)"

zip: xcframework
	@echo "$(BLUE)Creating release package...$(NC)"
	@mkdir -p $(OUTPUT_DIR)
	@cd $(XCFRAMEWORK_DIR) && \
		zip -r $(PWD)/$(OUTPUT_DIR)/$(PROJECT_NAME)-v$(VERSION).xcframework.zip $(XCFRAMEWORK_NAME)/ && \
		echo "$(GREEN)✓ Package created: $(OUTPUT_DIR)/$(PROJECT_NAME)-v$(VERSION).xcframework.zip$(NC)"
	@ls -lh $(OUTPUT_DIR)/$(PROJECT_NAME)-v$(VERSION).xcframework.zip
	@echo ""
	@echo "$(YELLOW)Ready for GitHub release upload!$(NC)"

clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	rm -rf $(BUILD_DIR)
	rm -rf $(OUTPUT_DIR)
	@echo "$(GREEN)✓ Clean complete!$(NC)"

info:
	@echo "$(BLUE)Build Information$(NC)"
	@echo "=================="
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Cargo: $(CARGO)"
	@echo "Build Directory: $(BUILD_DIR)"
	@echo "Release Directory: $(RELEASE_DIR)"
	@echo "Targets:"
	@echo "  - macOS ARM64: $(MACOS_ARM64_TARGET)"
	@echo "  - macOS x86_64: $(MACOS_X86_64_TARGET)"
	@echo "  - iOS ARM64: $(IOS_ARM64_TARGET)"
	@echo "  - iOS Simulator ARM64: $(IOS_SIM_ARM64_TARGET)"
