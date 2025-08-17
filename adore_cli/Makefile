# === USER LAYER MAKEFILE ===
# Builds the final ADORe CLI user-customized layer
# This layer adds user account, installs .deb packages, and provides the final development environment

SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules

.DEFAULT_GOAL := all

ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?= 1
DOCKER_CONFIG?=
SUBMODULES_PATH?=$(shell realpath "${ROOT_DIR}/..")
ROS_DISTRO?=jazzy

# Determine source and log directories
ifneq ($(SOURCE_DIRECTORY),)
    LOG_DIR:=${SOURCE_DIRECTORY}/.log/.adore_cli
    VENDOR_PATH:=${SOURCE_DIRECTORY}/vendor
else
    LOG_DIR:=$(shell realpath "${ROOT_DIR}/..")/.log/.adore_cli
    VENDOR_PATH:=$(shell realpath "${ROOT_DIR}/../vendor")
endif

USER:=$(shell whoami)
UID:=$(shell id -u)
GID:=$(shell id -g)
DOCKER_GID:=$(shell getent group docker | cut -d: -f3)

CROSS_COMPILE?=false
ARCH?=amd64
DOCKER_PLATFORM?=linux/$(ARCH)

include ../adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets/make_gadgets.mk

# Target: build
# Description: Builds the final ADORe CLI user-customized layer
# - Uses the core environment image as the base layer
# - Installs .deb packages from vendor directory
# - Creates user account with proper permissions
# - Provides the final development environment ready for use
# - Supports both native and cross-compilation builds
.PHONY: build
build: clean gather_packages
	@echo "Building ADORe CLI user layer..."
	@echo "Base image: ${ADORE_CLI_CORE_IMAGE}"
	@echo "Target image: ${ADORE_CLI_IMAGE}"
	@echo "Current working directory: $(shell pwd)"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
		echo "Cross-compiling for $(ARCH)..."; \
		docker buildx build \
			--builder=default \
			--platform $(DOCKER_PLATFORM) \
			--tag ${ADORE_CLI_IMAGE} \
			--build-arg ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${ADORE_CLI_BRANCH} \
			--build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
			--build-arg PARENT_BRANCH=${PARENT_BRANCH} \
			--build-arg PARENT_SHORT_HASH=${PARENT_SHORT_HASH} \
			--build-arg ARCH=${ARCH} \
			--build-arg USER=${USER} \
			--build-arg UID=${UID} \
			--build-arg GID=${GID} \
			--build-arg HOSTNAME=${HOSTNAME:-ADORe-CLI} \
			--load . ; \
	else \
		echo "Building user layer (native): ${ADORE_CLI_IMAGE}"; \
		echo "Using core image: ${ADORE_CLI_CORE_IMAGE}"; \
		docker build --network host \
			--tag ${ADORE_CLI_IMAGE} \
			--build-arg ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${ADORE_CLI_BRANCH} \
			--build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
			--build-arg PARENT_BRANCH=${PARENT_BRANCH} \
			--build-arg PARENT_SHORT_HASH=${PARENT_SHORT_HASH} \
			--build-arg ARCH=${ARCH} \
			--build-arg USER=${USER} \
			--build-arg UID=${UID} \
			--build-arg GID=${GID} \
			--build-arg HOSTNAME=${HOSTNAME:-ADORe-CLI} . ; \
	fi

# Target: gather_packages
# Description: Collects .deb packages for user layer installation
# - Recursively searches for .deb files in ${SOURCE_DIRECTORY}/vendor
# - Stores packages in ${SOURCE_DIRECTORY}/.log/.adore_cli/packages  
# - Copies packages to local build context packages/ directory for Docker
# - Always creates packages directory even if empty to avoid Docker COPY errors
.PHONY: gather_packages
gather_packages:
	@echo "=== Gathering .deb packages for user layer ==="
	@echo "Source directory: ${SOURCE_DIRECTORY}"
	@echo "Log directory: ${LOG_DIR}"
	@echo "Vendor search path: ${VENDOR_PATH}"
	@echo "Build context: $(shell pwd)"
	
	# Always create the log directory for packages
	@echo "Creating log packages directory: ${LOG_DIR}/packages"
	mkdir -p "${LOG_DIR}/packages"
	
	# Always create local build context packages directory (required for Docker COPY)
	@echo "Creating build context packages directory: ./packages"
	mkdir -p packages
	
	# Recursively search for .deb files in SOURCE_DIRECTORY/vendor
	@if [ -d "${VENDOR_PATH}" ]; then \
		echo "Recursively searching for .deb files in: ${VENDOR_PATH}"; \
		DEB_FILES=$$(find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null); \
		DEB_COUNT=$$(echo "$$DEB_FILES" | grep -c . 2>/dev/null || echo 0); \
		echo "Found $$DEB_COUNT .deb packages"; \
		if [ $$DEB_COUNT -gt 0 ]; then \
			echo "Copying .deb files to log directory: ${LOG_DIR}/packages"; \
			echo "$$DEB_FILES" | while read -r deb_file; do \
				if [ -f "$$deb_file" ]; then \
					echo "  Copying: $$deb_file"; \
					cp "$$deb_file" "${LOG_DIR}/packages/"; \
				fi; \
			done; \
		else \
			echo "No .deb files found in vendor directory"; \
		fi; \
	else \
		echo "Vendor directory not found: ${VENDOR_PATH}"; \
	fi
	
	# Copy packages from log directory to local build context for Docker
	@echo "Copying packages from log to build context..."
	@if [ -d "${LOG_DIR}/packages" ]; then \
		AVAILABLE_DEBS=$$(find "${LOG_DIR}/packages" -name "*.deb" 2>/dev/null); \
		if [ -n "$$AVAILABLE_DEBS" ]; then \
			echo "Copying packages to build context:"; \
			find "${LOG_DIR}/packages" -name "*.deb" -exec basename {} \; | while read -r deb_name; do \
				echo "  $$deb_name"; \
				cp "${LOG_DIR}/packages/$$deb_name" packages/; \
			done; \
		else \
			echo "No .deb packages found in log directory"; \
		fi; \
	fi
	
	# Always ensure directory exists with a placeholder for Docker COPY
	@echo "Ensuring build context packages directory is not empty..."
	touch packages/.gitkeep
	
	# Set proper permissions
	find "packages" -type d -exec chmod 755 {} \; 2>/dev/null || true
	find "packages" -type f -exec chmod 644 {} \; 2>/dev/null || true
	find "packages" -exec touch -t 197001010000 {} \; 2>/dev/null || true
	
	@echo "Final build context packages directory:"
	@ls -la packages/ 2>/dev/null || echo "Failed to list packages directory"
	@echo "Final log packages directory:"
	@ls -la "${LOG_DIR}/packages/" 2>/dev/null || echo "Failed to list log packages directory"
	@echo "=== Package gathering complete ==="

.PHONY: debug_run
debug_run:
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY: debug_run_root
debug_run_root:
	docker run -it --rm --user root --entrypoint /bin/bash ${ADORE_CLI_IMAGE}
