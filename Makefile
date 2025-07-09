# Android 16 AOSP Build System Makefile
# Provides convenient targets for building Android with custom ROM integration

# Default configuration
DEVICE ?= generic
ROM ?= lineageos
JOBS ?= $(shell nproc)
BUILD_TYPE ?= userdebug

# Directories
SCRIPTS_DIR := scripts
DOCS_DIR := docs
AOSP_DIR := aosp
ROMS_DIR := custom_roms
OUT_DIR := out

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Helper function to print colored messages
define print_status
	@echo -e "$(BLUE)[INFO]$(NC) $(1)"
endef

define print_success
	@echo -e "$(GREEN)[SUCCESS]$(NC) $(1)"
endef

define print_warning
	@echo -e "$(YELLOW)[WARNING]$(NC) $(1)"
endef

define print_error
	@echo -e "$(RED)[ERROR]$(NC) $(1)"
endef

.PHONY: help setup download integrate build clean flash info check-env

# Default target
all: help

help:
	@echo "Android 16 AOSP Build System"
	@echo "============================"
	@echo ""
	@echo "Available targets:"
	@echo "  setup          - Setup build environment"
	@echo "  download       - Download AOSP source code"
	@echo "  integrate      - Integrate custom ROM (specify ROM=name)"
	@echo "  build          - Build Android (specify DEVICE=codename)"
	@echo "  flash          - Flash built images to device"
	@echo "  clean          - Clean build artifacts"
	@echo "  info           - Show build information"
	@echo "  check-env      - Check build environment"
	@echo ""
	@echo "Configuration variables:"
	@echo "  DEVICE         - Target device codename (default: generic)"
	@echo "  ROM            - Custom ROM to integrate (default: lineageos)"
	@echo "  JOBS           - Number of parallel jobs (default: $(JOBS))"
	@echo "  BUILD_TYPE     - Build variant (default: userdebug)"
	@echo ""
	@echo "Examples:"
	@echo "  make setup"
	@echo "  make download"
	@echo "  make integrate ROM=lineageos"
	@echo "  make build DEVICE=pixel6 BUILD_TYPE=user"
	@echo "  make flash DEVICE=pixel6"
	@echo "  make clean"

# Setup build environment
setup:
	$(call print_status,"Setting up build environment...")
	@chmod +x $(SCRIPTS_DIR)/*.sh
	@$(SCRIPTS_DIR)/setup_environment.sh
	$(call print_success,"Build environment setup completed")

# Download AOSP source
download: check-env
	$(call print_status,"Downloading Android 16 AOSP source...")
	@$(SCRIPTS_DIR)/download_aosp.sh
	$(call print_success,"AOSP source download completed")

# Integrate custom ROM
integrate: check-env
	$(call print_status,"Integrating custom ROM: $(ROM)")
	@$(SCRIPTS_DIR)/integrate_custom_rom.sh $(ROM)
	$(call print_success,"Custom ROM integration completed")

# Build Android
build: check-env
	$(call print_status,"Building Android 16 for $(DEVICE) ($(BUILD_TYPE))")
	@$(SCRIPTS_DIR)/build_android.sh $(DEVICE) $(BUILD_TYPE) -j$(JOBS)
	$(call print_success,"Android build completed")

# Build specific targets
build-system: check-env
	$(call print_status,"Building system image for $(DEVICE)")
	@$(SCRIPTS_DIR)/build_android.sh $(DEVICE) $(BUILD_TYPE) -j$(JOBS) --images-only

build-boot: check-env
	$(call print_status,"Building boot image for $(DEVICE)")
	@$(SCRIPTS_DIR)/build_android.sh $(DEVICE) $(BUILD_TYPE) -j$(JOBS) --kernel-only

build-recovery: check-env
	$(call print_status,"Building recovery image for $(DEVICE)")
	@$(SCRIPTS_DIR)/build_android.sh $(DEVICE) $(BUILD_TYPE) -j$(JOBS) --recovery

build-ota: check-env
	$(call print_status,"Building OTA package for $(DEVICE)")
	@$(SCRIPTS_DIR)/build_android.sh $(DEVICE) $(BUILD_TYPE) -j$(JOBS) --ota

# Flash device
flash: check-env
	$(call print_status,"Flashing $(DEVICE) with built images")
	@$(SCRIPTS_DIR)/flash_device.sh $(DEVICE)

flash-system: check-env
	$(call print_status,"Flashing system partition for $(DEVICE)")
	@$(SCRIPTS_DIR)/flash_device.sh -t system $(DEVICE)

flash-boot: check-env
	$(call print_status,"Flashing boot partition for $(DEVICE)")
	@$(SCRIPTS_DIR)/flash_device.sh -t boot $(DEVICE)

flash-recovery: check-env
	$(call print_status,"Flashing recovery partition for $(DEVICE)")
	@$(SCRIPTS_DIR)/flash_device.sh -t recovery $(DEVICE)

flash-wipe: check-env
	$(call print_status,"Flashing $(DEVICE) with data wipe")
	@$(SCRIPTS_DIR)/flash_device.sh -w $(DEVICE)

# Clean targets
clean:
	$(call print_status,"Cleaning build artifacts...")
	@if [ -d "$(OUT_DIR)" ]; then \
		rm -rf $(OUT_DIR); \
		$(call print_success,"Build output cleaned"); \
	else \
		$(call print_warning,"No build output to clean"); \
	fi

clean-ccache:
	$(call print_status,"Cleaning ccache...")
	@if command -v ccache >/dev/null 2>&1; then \
		ccache -C; \
		$(call print_success,"ccache cleaned"); \
	else \
		$(call print_warning,"ccache not installed"); \
	fi

clean-all: clean clean-ccache
	$(call print_status,"Performing deep clean...")
	@if [ -d "$(AOSP_DIR)" ]; then \
		cd $(AOSP_DIR) && repo forall -c 'git clean -fd'; \
		cd $(AOSP_DIR) && repo forall -c 'git reset --hard'; \
		$(call print_success,"AOSP source cleaned"); \
	fi

# Information and diagnostics
info:
	$(call print_status,"Collecting build information...")
	@$(SCRIPTS_DIR)/collect_build_info.sh

check-env:
	@if [ ! -f "$(SCRIPTS_DIR)/setup_environment.sh" ]; then \
		$(call print_error,"Scripts not found. Please ensure you're in the project root directory."); \
		exit 1; \
	fi
	@if [ ! -d "$(AOSP_DIR)" ] && [ "$@" != "setup" ] && [ "$@" != "download" ]; then \
		$(call print_warning,"AOSP source not found. Run 'make download' first."); \
	fi

# Development targets
sync:
	$(call print_status,"Syncing AOSP source...")
	@if [ -d "$(AOSP_DIR)" ]; then \
		cd $(AOSP_DIR) && repo sync -c -j4; \
		$(call print_success,"AOSP source synced"); \
	else \
		$(call print_error,"AOSP directory not found. Run 'make download' first."); \
	fi

status:
	$(call print_status,"Checking repository status...")
	@if [ -d "$(AOSP_DIR)" ]; then \
		cd $(AOSP_DIR) && repo status; \
	else \
		$(call print_error,"AOSP directory not found."); \
	fi

# Device-specific quick builds
pixel6: DEVICE=pixel6
pixel6: build

pixel7: DEVICE=pixel7
pixel7: build

oneplus9: DEVICE=oneplus9
oneplus9: build

# ROM-specific integrations
lineageos: ROM=lineageos
lineageos: integrate

evolutionx: ROM=evolutionx
evolutionx: integrate

crdroid: ROM=crdroid
crdroid: integrate

# Utility targets
backup:
	$(call print_status,"Creating backup of important files...")
	@tar -czf backup_$(shell date +%Y%m%d_%H%M%S).tar.gz \
		build_config.sh \
		device_configs/ \
		patches/ \
		local_manifest.xml \
		2>/dev/null || true
	$(call print_success,"Backup created")

docs:
	$(call print_status,"Opening documentation...")
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open $(DOCS_DIR)/troubleshooting.md; \
	elif command -v open >/dev/null 2>&1; then \
		open $(DOCS_DIR)/troubleshooting.md; \
	else \
		$(call print_status,"Please open $(DOCS_DIR)/troubleshooting.md manually"); \
	fi

# Test targets for CI/CD
test-setup:
	$(call print_status,"Testing setup script...")
	@$(SCRIPTS_DIR)/setup_environment.sh --dry-run || true

test-build:
	$(call print_status,"Testing build configuration...")
	@$(SCRIPTS_DIR)/build_android.sh --check-only || true

# Install dependencies (Ubuntu/Debian)
install-deps:
	$(call print_status,"Installing build dependencies...")
	@sudo apt-get update
	@sudo apt-get install -y \
		git-core gnupg flex bison build-essential zip curl \
		zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev \
		lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip \
		fontconfig python3 python3-pip bc rsync ccache
	$(call print_success,"Dependencies installed")

# Show current configuration
config:
	@echo "Current Configuration:"
	@echo "====================="
	@echo "Device:     $(DEVICE)"
	@echo "ROM:        $(ROM)"
	@echo "Jobs:       $(JOBS)"
	@echo "Build Type: $(BUILD_TYPE)"
	@echo ""
	@echo "Directories:"
	@echo "AOSP:       $(AOSP_DIR)"
	@echo "ROMs:       $(ROMS_DIR)"
	@echo "Output:     $(OUT_DIR)"
	@echo "Scripts:    $(SCRIPTS_DIR)"
