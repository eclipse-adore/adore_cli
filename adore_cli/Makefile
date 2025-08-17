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

# === MANIFEST PATHS ===
BUILD_TEMP_DIR:=.tmp
BUILD_PACKAGES_DIR:=${BUILD_TEMP_DIR}/packages
BUILD_CONTEXT_PACKAGES_DIR:=packages
PACKAGES_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/packages_manifest.sha256
PACKAGES_MANIFEST_TXT:=packages_manifest.txt

# Target: build
.PHONY: build
build: clean gather_packages
	@echo "Building ADORe CLI user layer..."
	@echo "Base image: ${ADORE_CLI_CORE_IMAGE}"
	@echo "Target image: ${ADORE_CLI_IMAGE}"
	@echo "Packages manifest: ${PACKAGES_MANIFEST}"
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
	@echo "=== Copying packages manifest from successful build ==="
	@make copy_packages_from_container

# Target: gather_packages
.PHONY: gather_packages
gather_packages:
	@echo "=== Gathering .deb packages for user layer ==="
	@echo "SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@echo "LOG_DIR: ${LOG_DIR}"
	@echo "VENDOR_PATH: ${VENDOR_PATH}"
	@echo "Build context: $(shell pwd)"
	
	# Clean up any existing temp directories
	@rm -rf "${BUILD_TEMP_DIR}" 2>/dev/null || true
	@rm -rf "${BUILD_CONTEXT_PACKAGES_DIR}" 2>/dev/null || true
	@rm -f "${PACKAGES_MANIFEST_TXT}" 2>/dev/null || true
	
	# Always create the log directory for packages
	@echo "Creating log packages directory: ${LOG_DIR}/packages"
	@mkdir -p "${LOG_DIR}/packages"
	
	# Always create local build context packages directory (required for Docker COPY)
	@echo "Creating build context packages directory: ./${BUILD_CONTEXT_PACKAGES_DIR}"
	@mkdir -p "${BUILD_CONTEXT_PACKAGES_DIR}"
	
	# Recursively search for .deb files in SOURCE_DIRECTORY/vendor
	@if [ -d "${VENDOR_PATH}" ]; then \
		echo "Recursively searching for .deb files in: ${VENDOR_PATH}"; \
		DEB_FILES=$$(find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null || echo ""); \
		if [ -n "$$DEB_FILES" ]; then \
			DEB_COUNT=$$(echo "$$DEB_FILES" | wc -l); \
			echo "Found $$DEB_COUNT .deb packages"; \
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
		AVAILABLE_DEBS=$$(find "${LOG_DIR}/packages" -name "*.deb" 2>/dev/null || echo ""); \
		if [ -n "$$AVAILABLE_DEBS" ]; then \
			echo "Copying packages to build context:"; \
			find "${LOG_DIR}/packages" -name "*.deb" -exec basename {} \; | while read -r deb_name; do \
				echo "  $$deb_name"; \
				cp "${LOG_DIR}/packages/$$deb_name" "${BUILD_CONTEXT_PACKAGES_DIR}/"; \
			done; \
		else \
			echo "No .deb packages found in log directory"; \
		fi; \
	fi
	
	# Always ensure directory exists with a placeholder for Docker COPY
	@echo "Ensuring build context packages directory is not empty..."
	@touch "${BUILD_CONTEXT_PACKAGES_DIR}/.gitkeep"
	
	# Generate package manifest for Docker build context (this ensures rebuild when packages change)
	@echo "=== Generating package manifest for build context ==="
	@if [ -d "${BUILD_CONTEXT_PACKAGES_DIR}" ]; then \
		echo "# Package manifest for ADORe CLI user layer" > "${PACKAGES_MANIFEST_TXT}"; \
		echo "# Generated: $$(date)" >> "${PACKAGES_MANIFEST_TXT}"; \
		PACKAGE_COUNT=$$(find "${BUILD_CONTEXT_PACKAGES_DIR}" -name "*.deb" 2>/dev/null | wc -l); \
		echo "# Total packages: $$PACKAGE_COUNT" >> "${PACKAGES_MANIFEST_TXT}"; \
		if [ "$$PACKAGE_COUNT" -gt 0 ]; then \
			echo "# Package list:" >> "${PACKAGES_MANIFEST_TXT}"; \
			find "${BUILD_CONTEXT_PACKAGES_DIR}" -name "*.deb" -exec basename {} \; | sort >> "${PACKAGES_MANIFEST_TXT}"; \
			echo "# Package checksums:" >> "${PACKAGES_MANIFEST_TXT}"; \
			find "${BUILD_CONTEXT_PACKAGES_DIR}" -name "*.deb" -exec sha256sum {} \; | sort >> "${PACKAGES_MANIFEST_TXT}"; \
		else \
			echo "# No packages found" >> "${PACKAGES_MANIFEST_TXT}"; \
		fi; \
		echo "Package manifest created: ${PACKAGES_MANIFEST_TXT}"; \
	fi
	
	# Set proper permissions
	@find "${BUILD_CONTEXT_PACKAGES_DIR}" -type d -exec chmod 755 {} \; 2>/dev/null || true
	@find "${BUILD_CONTEXT_PACKAGES_DIR}" -type f -exec chmod 644 {} \; 2>/dev/null || true
	@find "${BUILD_CONTEXT_PACKAGES_DIR}" -exec touch -t 197001010000 {} \; 2>/dev/null || true
	
	# Generate packages manifest for change detection
	@echo "=== Generating packages manifest for change detection ==="
	@if [ -d "${VENDOR_PATH}" ]; then \
		PACKAGE_COUNT=$$(find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | wc -l); \
		find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | \
		xargs -r sha256sum 2>/dev/null | sort > "${PACKAGES_MANIFEST}"; \
		echo "Packages manifest created with $$PACKAGE_COUNT entries"; \
	else \
		touch "${PACKAGES_MANIFEST}"; \
		echo "Packages manifest created with 0 entries"; \
	fi
	
	@echo "Final build context packages directory:"
	@ls -la "${BUILD_CONTEXT_PACKAGES_DIR}/" 2>/dev/null || echo "Failed to list packages directory"
	@echo "Final log packages directory:"
	@ls -la "${LOG_DIR}/packages/" 2>/dev/null || echo "Failed to list log packages directory"
	@echo "Package manifest summary:"
	@if [ -f "${PACKAGES_MANIFEST_TXT}" ]; then \
		head -10 "${PACKAGES_MANIFEST_TXT}"; \
		TOTAL_LINES=$$(wc -l < "${PACKAGES_MANIFEST_TXT}"); \
		if [ "$$TOTAL_LINES" -gt 10 ]; then \
			echo "... ($$(($$TOTAL_LINES - 10)) more lines)"; \
		fi; \
	fi
	@echo "=== Package gathering complete ==="

# Target: copy_packages_from_container
.PHONY: copy_packages_from_container
copy_packages_from_container:
	@echo "=== Copying packages from successful build ==="
	@if docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
		echo "Extracting .tmp directory from built image: ${ADORE_CLI_IMAGE}"; \
		CONTAINER_ID=$$(docker create ${ADORE_CLI_IMAGE}); \
		if docker cp "$$CONTAINER_ID:/tmp/.tmp" "${BUILD_TEMP_DIR}/" 2>/dev/null; then \
			echo "Successfully extracted .tmp directory"; \
			if [ -f "${BUILD_TEMP_DIR}/.tmp/packages/build_success.marker" ]; then \
				echo "Build success marker found, copying packages info"; \
				mkdir -p "${SOURCE_DIRECTORY}/.log/.adore_cli"; \
				if [ -d "${BUILD_TEMP_DIR}/.tmp/packages" ]; then \
					cp -r "${BUILD_TEMP_DIR}/.tmp/packages" "${SOURCE_DIRECTORY}/.log/.adore_cli/"; \
					echo "Package info copied to: ${SOURCE_DIRECTORY}/.log/.adore_cli/packages"; \
					if [ -f "${SOURCE_DIRECTORY}/.log/.adore_cli/packages/packages_manifest.sha256" ]; then \
						cp "${SOURCE_DIRECTORY}/.log/.adore_cli/packages/packages_manifest.sha256" "${PACKAGES_MANIFEST}"; \
						echo "Packages manifest saved to: ${PACKAGES_MANIFEST}"; \
					fi; \
				fi; \
			else \
				echo "Warning: No build success marker found"; \
			fi; \
		else \
			echo "Warning: Could not extract .tmp directory from container"; \
		fi; \
		docker rm "$$CONTAINER_ID" >/dev/null 2>&1 || true; \
	else \
		echo "Error: User image ${ADORE_CLI_IMAGE} not found"; \
	fi

# Target: clean
.PHONY: clean
clean:
	@echo "Cleaning user build artifacts..."
	@rm -rf "${BUILD_TEMP_DIR}" 2>/dev/null || true
	@rm -rf "${BUILD_CONTEXT_PACKAGES_DIR}" 2>/dev/null || true
	@rm -f "${PACKAGES_MANIFEST_TXT}" 2>/dev/null || true

.PHONY: debug_run
debug_run:
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY: debug_run_root
debug_run_root:
	docker run -it --rm --user root --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY: debug_packages
debug_packages:
	@echo "=== Packages Debug Info ==="
	@echo "SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@echo "VENDOR_PATH: ${VENDOR_PATH}"
	@echo "BUILD_CONTEXT_PACKAGES_DIR: ${BUILD_CONTEXT_PACKAGES_DIR}"
	@echo "PACKAGES_MANIFEST: ${PACKAGES_MANIFEST}"
	@echo "PACKAGES_MANIFEST_TXT: ${PACKAGES_MANIFEST_TXT}"
	@echo ""
	@echo "Source directory exists: $(shell [ -d '${SOURCE_DIRECTORY}' ] && echo 'yes' || echo 'no')"
	@echo "Vendor directory exists: $(shell [ -d '${VENDOR_PATH}' ] && echo 'yes' || echo 'no')"
	@echo "Packages manifest exists: $(shell [ -f '${PACKAGES_MANIFEST}' ] && echo 'yes' || echo 'no')"
	@echo "Build manifest exists: $(shell [ -f '${PACKAGES_MANIFEST_TXT}' ] && echo 'yes' || echo 'no')"
	@echo ""
	@if [ -f "${PACKAGES_MANIFEST}" ]; then \
		echo "Current packages manifest:"; \
		cat "${PACKAGES_MANIFEST}"; \
	else \
		echo "No packages manifest found"; \
	fi
	@echo ""
	@if [ -f "${PACKAGES_MANIFEST_TXT}" ]; then \
		echo "Build context manifest:"; \
		cat "${PACKAGES_MANIFEST_TXT}"; \
	else \
		echo "No build context manifest found"; \
	fi
	@echo ""
	@echo ".deb packages found in vendor:"
	@find "${VENDOR_PATH}" -name "*.deb" -type f 2>/dev/null | head -20 || echo "None found"

.PHONY: test_package_installation
test_package_installation:
	@echo "=== Testing Package Installation ==="
	@docker run --rm ${ADORE_CLI_IMAGE} dpkg -l | grep -E "(eigen3|helix|libopendrive|optinlc|osqp|adore-model-checker|ros2tools)" || echo "No expected packages found installed"
