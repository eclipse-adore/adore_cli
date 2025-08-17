# === CORE ENVIRONMENT MAKEFILE ===
# Builds the ADORe CLI core environment layer with all discovered requirements

SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules

.DEFAULT_GOAL := all

ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?= 1
DOCKER_CONFIG?=
ROS_DISTRO?=jazzy

# Use SOURCE_DIRECTORY if provided, otherwise default to parent of adore_cli
SOURCE_DIRECTORY?=$(shell realpath "${ROOT_DIR}/../..")
VENDOR_PATH?=${SOURCE_DIRECTORY}/vendor

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
BUILD_REQUIREMENTS_DIR:=${BUILD_TEMP_DIR}/requirements
BUILD_CONTEXT_REQUIREMENTS_DIR:=.log/.adore_cli/requirements
REQUIREMENTS_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/requirements_manifest.sha256

# Target: build
.PHONY: build
build: clean gather_requirements
	@echo "Building ADORe CLI core environment..."
	@echo "Base image: ${ADORE_CLI_BASE_IMAGE}"
	@echo "Target image: ${ADORE_CLI_CORE_IMAGE}"
	@echo "Requirements manifest: ${REQUIREMENTS_MANIFEST}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
		docker buildx build \
			--builder=default \
			--platform $(DOCKER_PLATFORM) \
			--tag ${ADORE_CLI_CORE_IMAGE} \
			--build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${ADORE_CLI_BRANCH} \
			--build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
			--build-arg ARCH=${ARCH} \
			--load . ; \
	else \
		docker build --network host \
			--tag ${ADORE_CLI_CORE_IMAGE} \
			--build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${ADORE_CLI_BRANCH} \
			--build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
			--build-arg ARCH=${ARCH} . ; \
	fi
	@echo "=== Copying requirements manifest from successful build ==="
	@make copy_requirements_from_container

# Target: gather_requirements
# Description: Discovers and gathers all requirements files from the project tree
# - Creates build context requirements directory
# - Runs the gather script to find and process requirements
# - Copies results to build context for Docker
.PHONY: gather_requirements
gather_requirements:
	@echo "=== Gathering requirements for core layer ==="
	@echo "SOURCE_DIRECTORY: '${SOURCE_DIRECTORY}'"
	@echo "VENDOR_PATH: '${VENDOR_PATH}'"
	@echo "PWD: $(shell pwd)"
	@echo "Build context requirements: ${BUILD_CONTEXT_REQUIREMENTS_DIR}"
	
	@# Clean up any existing temp directories
	@rm -rf "${BUILD_TEMP_DIR}" 2>/dev/null || true
	@rm -rf "${BUILD_CONTEXT_REQUIREMENTS_DIR}" 2>/dev/null || true
	
	@# Create directories
	@mkdir -p "${BUILD_CONTEXT_REQUIREMENTS_DIR}"
	@mkdir -p "${BUILD_TEMP_DIR}"
	
	@# Export SOURCE_DIRECTORY for the script and run gathering
	@SOURCE_DIRECTORY='${SOURCE_DIRECTORY}' bash gather_requirements_files.sh
	
	@# Copy gathered requirements to build context
	@if [ -d "${SOURCE_DIRECTORY}/.log/.adore_cli/requirements" ]; then \
		echo "Copying requirements to build context..."; \
		cp -r "${SOURCE_DIRECTORY}/.log/.adore_cli/requirements/"* "${BUILD_CONTEXT_REQUIREMENTS_DIR}/" 2>/dev/null || true; \
	fi
	
	@# Always ensure build context has required structure
	@touch "${BUILD_CONTEXT_REQUIREMENTS_DIR}/.gitkeep"
	
	@echo "Build context contents:"; \
	ls -la "${BUILD_CONTEXT_REQUIREMENTS_DIR}" 2>/dev/null || echo "Empty build context"
	
	@echo "=== Requirements gathering complete ==="

# Target: copy_requirements_from_container
# Description: Copies the .tmp directory from a successful container build to SOURCE_DIRECTORY
# - Extracts the temporary requirements directory from the built container
# - Copies to SOURCE_DIRECTORY/.log/.adore_cli/requirements for persistence
# - Only runs if the build was successful (success marker exists)
.PHONY: copy_requirements_from_container
copy_requirements_from_container:
	@echo "=== Copying requirements from successful build ==="
	@if docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
		echo "Extracting .tmp directory from built image: ${ADORE_CLI_CORE_IMAGE}"; \
		CONTAINER_ID=$$(docker create ${ADORE_CLI_CORE_IMAGE}); \
		if docker cp "$$CONTAINER_ID:/tmp/.tmp" "${BUILD_TEMP_DIR}/" 2>/dev/null; then \
			echo "Successfully extracted .tmp directory"; \
			if [ -f "${BUILD_TEMP_DIR}/.tmp/requirements/build_success.marker" ]; then \
				echo "Build success marker found, copying requirements"; \
				mkdir -p "${SOURCE_DIRECTORY}/.log/.adore_cli"; \
				if [ -d "${BUILD_TEMP_DIR}/.tmp/requirements" ]; then \
					cp -r "${BUILD_TEMP_DIR}/.tmp/requirements" "${SOURCE_DIRECTORY}/.log/.adore_cli/"; \
					echo "Requirements copied to: ${SOURCE_DIRECTORY}/.log/.adore_cli/requirements"; \
					if [ -f "${SOURCE_DIRECTORY}/.log/.adore_cli/requirements/requirements_manifest.sha256" ]; then \
						cp "${SOURCE_DIRECTORY}/.log/.adore_cli/requirements/requirements_manifest.sha256" "${REQUIREMENTS_MANIFEST}"; \
						echo "Requirements manifest saved to: ${REQUIREMENTS_MANIFEST}"; \
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
		echo "Error: Core image ${ADORE_CLI_CORE_IMAGE} not found"; \
	fi

# Target: clean
# Description: Cleans up build artifacts and temporary directories
.PHONY: clean
clean:
	@echo "Cleaning core build artifacts..."
	@rm -rf "${BUILD_TEMP_DIR}" 2>/dev/null || true
	@rm -rf "${BUILD_CONTEXT_REQUIREMENTS_DIR}" 2>/dev/null || true

# Target: debug_requirements
# Description: Shows current requirements gathering status for debugging
.PHONY: debug_requirements
debug_requirements:
	@echo "=== Requirements Debug Info ==="
	@echo "SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@echo "VENDOR_PATH: ${VENDOR_PATH}"
	@echo "BUILD_CONTEXT_REQUIREMENTS_DIR: ${BUILD_CONTEXT_REQUIREMENTS_DIR}"
	@echo "REQUIREMENTS_MANIFEST: ${REQUIREMENTS_MANIFEST}"
	@echo ""
	@echo "Source directory exists: $(shell [ -d '${SOURCE_DIRECTORY}' ] && echo 'yes' || echo 'no')"
	@echo "Vendor directory exists: $(shell [ -d '${VENDOR_PATH}' ] && echo 'yes' || echo 'no')"
	@echo "Requirements manifest exists: $(shell [ -f '${REQUIREMENTS_MANIFEST}' ] && echo 'yes' || echo 'no')"
	@echo ""
	@if [ -f "${REQUIREMENTS_MANIFEST}" ]; then \
		echo "Current requirements manifest:"; \
		cat "${REQUIREMENTS_MANIFEST}"; \
	else \
		echo "No requirements manifest found"; \
	fi
	@echo ""
	@echo "Requirements files found in source tree:"
	@find "${SOURCE_DIRECTORY}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) ! -path "*/ros_translator/*" ! -path "*/.log/*" ! -path "*/.git/*" ! -path "*/build/*" 2>/dev/null | head -20 || echo "None found"
