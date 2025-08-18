# This Makefile contains useful targets that can be included in downstream projects.

ifeq ($(filter adore_cli.mk, $(notdir $(MAKEFILE_LIST))), adore_cli.mk)

# === SHELL AND EXPORT CONFIGURATION ===
SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.NOTPARALLEL:

# Get the adore_cli makefile path
ADORE_CLI_MAKEFILE_PATH := $(shell dirname "$(realpath $(lastword $(MAKEFILE_LIST)))")

# Only set these if they haven't been set by a parent makefile
ROOT_DIR ?= ${ADORE_CLI_MAKEFILE_PATH}
SOURCE_DIRECTORY ?= ${ADORE_CLI_MAKEFILE_PATH}

# Set other paths relative to SOURCE_DIRECTORY (not ROOT_DIR)
SUBMODULES_PATH ?= ${SOURCE_DIRECTORY}/tools
VENDOR_PATH ?= ${SOURCE_DIRECTORY}/vendor

# Determine if parent is adore_cli
PARENT_IS_ADORE_CLI := $(shell [ "${SOURCE_DIRECTORY}" = "${ADORE_CLI_MAKEFILE_PATH}" ] && echo "true" || echo "false")

.EXPORT_ALL_VARIABLES:

# === ROS AND OS CONFIGURATION ===
DOCKER_BUILDKIT ?= 1
DOCKER_CONFIG ?= 
ROS_DISTRO ?= jazzy
OS_CODE_NAME ?= noble
HOSTNAME ?= "ADORe-CLI"

# === PROJECT CONFIGURATION ===
ADORE_CLI_PROJECT:=adore_cli
ADORE_CLI_MAKEFILE_PATH:=$(shell realpath "$(shell dirname "$(lastword $(MAKEFILE_LIST))")")

# Default GITHUB_REPOSITORY to prevent undefined variable warnings
GITHUB_REPOSITORY?=dlr-ts/adore_develop

# === PATH CONFIGURATION ===
MAKE_GADGETS_PATH:=${ADORE_CLI_MAKEFILE_PATH}/make_gadgets

ifeq ($(wildcard $(MAKE_GADGETS_PATH)/*),)
    $(info INFO: To clone submodules use: 'git submodule update --init --recursive')
    $(error "ERROR: ${MAKE_GADGETS_PATH} does not exist. Did you clone the submodules?")
endif

# === ARCHITECTURE AND PLATFORM CONFIGURATION ===
ARCH ?= $(shell uname -m)
DOCKER_PLATFORM ?= linux/$(ARCH)
CROSS_COMPILE ?= $(shell if [ "$(shell uname -m)" != "$(ARCH)" ]; then echo "true"; else echo "false"; fi)
MINIMUM_DOCKER_VERSION=28

# === GIT AND BRANCH CONFIGURATION FOR ADORE CLI REPO ===
ADORE_CLI_BRANCH:=$(shell cd ${ADORE_CLI_MAKEFILE_PATH} && bash ${MAKE_GADGETS_PATH}/tools/branch_name.sh 2>/dev/null || echo NOBRANCH)
ADORE_CLI_SHORT_HASH:=$(shell cd ${ADORE_CLI_MAKEFILE_PATH} && git rev-parse --short HEAD 2>/dev/null || echo NOHASH)
ADORE_CLI_IS_DIRTY:=$(shell cd ${ADORE_CLI_MAKEFILE_PATH} && if [ -n "$$(git status --porcelain 2>/dev/null)" ]; then echo "true"; else echo "false"; fi)

# === GIT AND BRANCH CONFIGURATION FOR PARENT REPO ===
PARENT_BRANCH?= $(shell bash $(MAKE_GADGETS_PATH)/tools/branch_name.sh 2>/dev/null || echo NOBRANCH)
PARENT_SHORT_HASH?=$(shell git rev-parse --short HEAD 2>/dev/null || echo NOHASH)
PARENT_IS_DIRTY:=$(shell cd ${SOURCE_DIRECTORY} && if [ -n "$$(git status --porcelain 2>/dev/null)" ]; then echo "true"; else echo "false"; fi)

# === REQUIREMENTS HASH GENERATION ===
REQUIREMENTS_SHORT_HASH:=$(shell find "${SOURCE_DIRECTORY}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) ! -path "*/ros_translator/*" ! -path "*/.log/*" ! -path "*/.git/*" ! -path "*/build/*" 2>/dev/null | xargs -r cat 2>/dev/null | sha256sum | cut -c1-7)

# === PACKAGES HASH GENERATION ===
# Hash only package names (basenames) for better determinism
PACKAGES_SHORT_HASH:=$(shell find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | sort | xargs -r -I {} basename {} 2>/dev/null | sort | sha256sum 2>/dev/null | cut -d' ' -f1 2>/dev/null | cut -c1-7 || echo "0000000")

# === MANIFEST PATHS ===
REQUIREMENTS_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/requirements_manifest.sha256
PACKAGES_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/packages_manifest.sha256
LAST_REQUIREMENTS_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/last_requirements_manifest.sha256
LAST_PACKAGES_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/last_packages_manifest.sha256

# === TAG STATE FILES ===
BUILT_TAGS_FILE:=${SOURCE_DIRECTORY}/.log/.adore_cli/built_tags
ADORE_CLI_TEMP_DIR:=${SOURCE_DIRECTORY}/.log/.adore_cli/temp

# === CORE TAGGING LOGIC ===
# Base tags (always use adore_cli repo info)
ADORE_CLI_BASE_TAG_CLEAN:=${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}
ifeq ($(ADORE_CLI_IS_DIRTY),true)
    ADORE_CLI_BASE_TAG_DEFAULT:=${ADORE_CLI_BASE_TAG_CLEAN}_dirty
else
    ADORE_CLI_BASE_TAG_DEFAULT:=${ADORE_CLI_BASE_TAG_CLEAN}
endif

# Core image tagging according to requirements (using uppercase RH)
ifeq ($(PARENT_IS_ADORE_CLI),true)
    ADORE_CLI_CORE_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}
else
    ADORE_CLI_CORE_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${PARENT_BRANCH}_${PARENT_SHORT_HASH}_RH${REQUIREMENTS_SHORT_HASH}
endif

# User image tagging with package hash, username, UID and GID (using uppercase PH)
ifeq ($(PARENT_IS_ADORE_CLI),true)
    ADORE_CLI_USER_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${USER}_UID${UID}GID${GID}
else
    ADORE_CLI_USER_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${PARENT_BRANCH}_${PARENT_SHORT_HASH}_PH${PACKAGES_SHORT_HASH}_${USER}_UID${UID}GID${GID}
endif

# Use default tags for runtime (simplified - no complex built tag logic)
ADORE_CLI_BASE_TAG:=${ADORE_CLI_BASE_TAG_DEFAULT}
ADORE_CLI_CORE_TAG:=${ADORE_CLI_CORE_TAG_DEFAULT}
ADORE_CLI_TAG:=${ADORE_CLI_USER_TAG_DEFAULT}

ADORE_CLI_BASE_IMAGE:=adore_cli_base:${ADORE_CLI_BASE_TAG}
ADORE_CLI_CORE_IMAGE:=adore_cli_core:${ADORE_CLI_CORE_TAG}
ADORE_CLI_IMAGE:=adore_cli:${ADORE_CLI_TAG}
ADORE_CLI_CONTAINER_NAME:=adore_cli_${ADORE_CLI_TAG}

# === DIRECTORY CONFIGURATION ===
SOURCE_DIRECTORY?=${REPO_DIRECTORY}
ADORE_CLI_WORKING_DIRECTORY?=${SOURCE_DIRECTORY}
DOCKER_COMPOSE_FILE?=${ADORE_CLI_MAKEFILE_PATH}/docker-compose.yaml
REPO_DIRECTORY:=${ADORE_CLI_MAKEFILE_PATH}

# === USER CONFIGURATION ===
UID := $(shell id -u)
GID := $(shell id -g)
ADORE_TAG ?= $(ADORE_CLI_TAG)

# === INCLUDES ===
include ${MAKE_GADGETS_PATH}/make_gadgets.mk
include ${MAKE_GADGETS_PATH}/docker/docker-tools.mk

# === DIRECTORY INITIALIZATION ===
$(shell mkdir -p "${ADORE_CLI_MAKEFILE_PATH}/.ccache")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.zsh_history")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.bash_history")
$(shell mkdir -p "${SOURCE_DIRECTORY}/.log/.adore_cli")
$(shell mkdir -p "${ADORE_CLI_TEMP_DIR}")

# === MANIFEST MANAGEMENT ===
.PHONY: _generate_requirements_manifest
_generate_requirements_manifest:
	@echo "Generating requirements manifest..."
	@mkdir -p "$(shell dirname ${REQUIREMENTS_MANIFEST})"
	@find "${SOURCE_DIRECTORY}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) ! -path "*/ros_translator/*" ! -path "*/.log/*" ! -path "*/.git/*" ! -path "*/build/*" 2>/dev/null | \
	xargs -r sha256sum 2>/dev/null | sort > "${REQUIREMENTS_MANIFEST}" || touch "${REQUIREMENTS_MANIFEST}"

.PHONY: _generate_packages_manifest
_generate_packages_manifest:
	@echo "Generating packages manifest..."
	@mkdir -p "$(shell dirname ${PACKAGES_MANIFEST})"
	@if [ -d "${VENDOR_PATH}" ]; then \
		find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | \
		sort | xargs -r -I {} basename {} 2>/dev/null | \
		sort | sha256sum > "${PACKAGES_MANIFEST}"; \
	else \
		touch "${PACKAGES_MANIFEST}"; \
	fi

.PHONY: _save_manifests
_save_manifests:
	@echo "Saving manifests as last known good..."
	@if [ -f "${REQUIREMENTS_MANIFEST}" ]; then cp "${REQUIREMENTS_MANIFEST}" "${LAST_REQUIREMENTS_MANIFEST}"; fi
	@if [ -f "${PACKAGES_MANIFEST}" ]; then cp "${PACKAGES_MANIFEST}" "${LAST_PACKAGES_MANIFEST}"; fi

.PHONY: _check_requirements_manifest_changed
_check_requirements_manifest_changed:
	@if [ -f "${REQUIREMENTS_MANIFEST}" ] && [ -f "${LAST_REQUIREMENTS_MANIFEST}" ]; then \
		if ! cmp -s "${REQUIREMENTS_MANIFEST}" "${LAST_REQUIREMENTS_MANIFEST}"; then \
			echo "true"; \
		else \
			echo "false"; \
		fi; \
	else \
		echo "true"; \
	fi

.PHONY: _check_packages_manifest_changed
_check_packages_manifest_changed:
	@if [ -f "${PACKAGES_MANIFEST}" ] && [ -f "${LAST_PACKAGES_MANIFEST}" ]; then \
		if ! cmp -s "${PACKAGES_MANIFEST}" "${LAST_PACKAGES_MANIFEST}"; then \
			echo "true"; \
		else \
			echo "false"; \
		fi; \
	else \
		echo "true"; \
	fi

.PHONY: _save_built_tags
_save_built_tags:
	@echo "Saving built image tags..."
	@mkdir -p "$(shell dirname ${BUILT_TAGS_FILE})"
	@echo "BASE=${ACTUAL_BASE_TAG}" > "${BUILT_TAGS_FILE}"
	@echo "CORE=${ACTUAL_CORE_TAG}" >> "${BUILT_TAGS_FILE}"
	@echo "USER=${ACTUAL_USER_TAG}" >> "${BUILT_TAGS_FILE}"
	@echo "Built tags saved to: ${BUILT_TAGS_FILE}"
	@echo "Contents:"
	@cat "${BUILT_TAGS_FILE}"

.PHONY: _determine_actual_build_tags
_determine_actual_build_tags: _generate_requirements_manifest _generate_packages_manifest
	@echo "Determining actual build tags based on requirements and package changes..."
	@mkdir -p "${ADORE_CLI_TEMP_DIR}"
	@echo "=== Tag Determination Logic ==="
	@echo "Parent is ADORe CLI: ${PARENT_IS_ADORE_CLI}"
	@echo "Parent repo dirty: ${PARENT_IS_DIRTY}"
	@echo "Requirements short hash: ${REQUIREMENTS_SHORT_HASH}"
	@echo "Packages short hash: ${PACKAGES_SHORT_HASH}"
	@echo "User: ${USER}"
	@REQUIREMENTS_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_requirements_manifest_changed); \
	PACKAGES_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_packages_manifest_changed); \
	echo "Requirements manifest changed: $$REQUIREMENTS_CHANGED"; \
	echo "Packages manifest changed: $$PACKAGES_CHANGED"; \
	ACTUAL_BASE_TAG="${ADORE_CLI_BASE_TAG_DEFAULT}"; \
	CORE_BASE_TAG="${ADORE_CLI_CORE_TAG_DEFAULT}"; \
	if [ "$$REQUIREMENTS_CHANGED" = "true" ] || [ "${PARENT_IS_DIRTY}" = "true" ]; then \
	    echo "→ Requirements changed or parent dirty → rebuilding core layer"; \
	    ACTUAL_CORE_TAG="$${CORE_BASE_TAG}_dirty"; \
	else \
	    echo "→ No requirements changes → using clean core tag"; \
	    ACTUAL_CORE_TAG="$$CORE_BASE_TAG"; \
	fi; \
	USER_BASE_TAG="${ADORE_CLI_USER_TAG_DEFAULT}"; \
	if [ "$$PACKAGES_CHANGED" = "true" ]; then \
	    echo "→ Packages changed → rebuilding user layer with current package hash"; \
	    ACTUAL_USER_TAG="$${USER_BASE_TAG}"; \
	else \
	    echo "→ No package changes → using clean user tag with package hash"; \
	    ACTUAL_USER_TAG="$$USER_BASE_TAG"; \
	fi; \
	echo "ACTUAL_BASE_TAG=$$ACTUAL_BASE_TAG" > "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	echo "ACTUAL_CORE_TAG=$$ACTUAL_CORE_TAG" >> "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	echo "ACTUAL_USER_TAG=$$ACTUAL_USER_TAG" >> "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	echo "=== Final Image Tags ==="; \
	echo "  Base: adore_cli_base:$$ACTUAL_BASE_TAG"; \
	echo "  Core: adore_cli_core:$$ACTUAL_CORE_TAG"; \
	echo "  User: adore_cli:$$ACTUAL_USER_TAG"

# === DOCKER VERSION AND DEPENDENCY CHECKS ===
.PHONY: check_docker_version
check_docker_version:
	@docker_version=$$(docker version --format '{{.Server.Version}}' 2>/dev/null | cut -d'.' -f1); \
	if [ -z "$$docker_version" ]; then \
	    echo "Error: Docker is not running or not installed"; \
	    exit 1; \
	elif [ "$$docker_version" -lt ${MINIMUM_DOCKER_VERSION} ]; then \
	    echo "Error: Docker version ${MINIMUM_DOCKER_VERSION}+ required, found version $$docker_version"; \
	    exit 1; \
	fi

.PHONY: check_cross_compile_deps
check_cross_compile_deps: check_docker_version
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    echo "Cross-compiling for $(ARCH) on $(shell uname -m)"; \
	    if ! which qemu-$(ARCH)-static >/dev/null || ! docker buildx inspect $(ARCH)builder >/dev/null 2>&1; then \
	        echo "Installing cross-compilation dependencies..."; \
	        sudo apt-get update && sudo apt-get install -y qemu-user-static binfmt-support; \
	        docker run --privileged --rm tonistiigi/binfmt --install $(ARCH); \
	        if ! docker buildx inspect $(ARCH)builder >/dev/null 2>&1; then \
	            docker buildx create --name $(ARCH)builder --driver docker-container --use; \
	        fi; \
	    fi; \
	    export DOCKER_BUILDX=1; \
	fi

# === MAIN CLI TARGET ===

.PHONY: cli 
cli: docker_host_context_check _cli_smart_attach ## Start ADORe CLI docker context or attach to it if it is already running

.PHONY: _cli_smart_attach
_cli_smart_attach:
	@echo "=== ADORe CLI Smart Attach ==="
	@echo "Target container: ${ADORE_CLI_CONTAINER_NAME}"
	@echo "Target image: ${ADORE_CLI_IMAGE}"
	@echo ""
	@if docker ps --format "{{.Names}}" | grep -q "^${ADORE_CLI_CONTAINER_NAME}$$"; then \
	    echo "✓ Container ${ADORE_CLI_CONTAINER_NAME} is already running"; \
	    echo "Attaching to existing session..."; \
	    echo "Type 'exit' to detach from container (container will continue running)"; \
	    echo "Use 'make stop' to stop the container"; \
	    echo ""; \
	    docker exec -it ${ADORE_CLI_CONTAINER_NAME} /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh"; \
	    echo ""; \
	    echo "Detached from container. Container is still running."; \
	    echo "Use 'make cli' to reattach or 'make stop' to stop it."; \
	elif docker ps -a --format "{{.Names}}" | grep -q "^${ADORE_CLI_CONTAINER_NAME}$$"; then \
	    echo "Container ${ADORE_CLI_CONTAINER_NAME} exists but is stopped"; \
	    echo "Starting existing container..."; \
	    docker start ${ADORE_CLI_CONTAINER_NAME}; \
	    echo "Attaching to restarted container..."; \
	    docker exec -it ${ADORE_CLI_CONTAINER_NAME} /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh"; \
	else \
	    echo "No existing container found with name: ${ADORE_CLI_CONTAINER_NAME}"; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _cli_build_and_start; \
	fi

.PHONY: _cli_build_and_start
_cli_build_and_start:
	@echo "=== Building and Starting New Container ==="
	@NEED_BUILD=false; \
	if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    echo "User image missing: ${ADORE_CLI_IMAGE}"; \
	    NEED_BUILD=true; \
	elif ! docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
	    echo "Core image missing: ${ADORE_CLI_CORE_IMAGE}"; \
	    NEED_BUILD=true; \
	elif ! docker image inspect ${ADORE_CLI_BASE_IMAGE} >/dev/null 2>&1; then \
	    echo "Base image missing: ${ADORE_CLI_BASE_IMAGE}"; \
	    NEED_BUILD=true; \
	fi; \
	if [ "$$NEED_BUILD" = "true" ]; then \
	    echo "Building missing images..."; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers; \
	else \
	    echo "✓ All required images exist"; \
	fi
	@echo "Starting new container..."
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _start_and_attach_interactive

.PHONY: _start_and_attach_interactive
_start_and_attach_interactive: adore_cli_setup adore_cli_start
	@echo "Container started. Attaching to interactive session..."
	@echo "Type 'exit' to detach from container (container will continue running)"
	@echo "Use 'make cli' to reattach or 'make stop' to stop the container"
	@echo ""
	@docker exec -it ${ADORE_CLI_CONTAINER_NAME} /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh"
	@echo ""
	@echo "Detached from container. Container is still running."
	@echo "Use 'make cli' to reattach or 'make stop' to stop it."

# === LIFECYCLE TARGETS ===
.PHONY: start
start: adore_cli_setup adore_cli_start ## Start the ADORe CLI docker compose context 

.PHONY: stop
stop: stop_adore_cli ## Stop ADORe CLI docker compose context if it is running

.PHONY: run
run: adore_cli_setup adore_cli_start adore_cli_run adore_cli_teardown ## Execute a command in the ADORe CLI context `make run cmd="<command to execute>"` 

.PHONY: adore_cli_up
adore_cli_up: adore_cli_setup adore_cli_start adore_cli_attach adore_cli_teardown 

.PHONY: stop_adore_cli
stop_adore_cli: docker_host_context_check adore_cli_teardown ## Stop adore_cli docker context if it is running

# === BUILD TARGETS ===

.PHONY: _build_adore_cli_layers
_build_adore_cli_layers: check_cross_compile_deps _determine_actual_build_tags
	@echo "=== ADORe CLI Multi-Layer Build Process ==="
	@echo "Building ADORe CLI with three-layer architecture..."
	@echo "Target architecture: ${ARCH}"
	@echo "ADORe CLI branch: ${ADORE_CLI_BRANCH} (${ADORE_CLI_SHORT_HASH})"
	@echo "ADORe CLI dirty: ${ADORE_CLI_IS_DIRTY}"
	@echo "Parent project: ${PARENT_BRANCH} (${PARENT_SHORT_HASH})"
	@echo "Parent dirty: ${PARENT_IS_DIRTY}"
	@echo "Requirements hash: ${REQUIREMENTS_SHORT_HASH}"
	@echo "Packages hash: ${PACKAGES_SHORT_HASH}"
	@echo "User: ${USER} (UID: ${UID}, GID: ${GID})"
	@echo ""
	@echo "Build strategy:"
	@echo "  1. Base layer:  Try registry pull → Use cache → Build locally"
	@echo "  2. Core layer:  Try registry pull → Use cache → Build locally"
	@echo "  3. User layer:  Use cache → Build locally (never pulled)"
	@echo ""
	@echo "Starting build process..."
	@echo "=========================="
	@source "${ADORE_CLI_TEMP_DIR}/build_vars" && \
	if ADORE_CLI_BASE_IMAGE="adore_cli_base:$$ACTUAL_BASE_TAG" make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_base; then \
	    echo "✓ Base layer build successful"; \
	else \
	    echo "✗ Base layer build failed"; \
	    echo ""; \
	    echo "BUILD FAILURE - TROUBLESHOOTING STEPS:"; \
	    echo "1. Check Docker daemon is running: docker info"; \
	    echo "2. Check disk space: df -h"; \
	    echo "3. Clean up Docker: docker system prune -f"; \
	    echo "4. Try building base layer manually:"; \
	    echo "   cd ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base && make build"; \
	    echo "5. If issues persist, check Docker logs: docker logs"; \
	    exit 1; \
	fi && \
	if ADORE_CLI_BASE_IMAGE="adore_cli_base:$$ACTUAL_BASE_TAG" ADORE_CLI_CORE_IMAGE="adore_cli_core:$$ACTUAL_CORE_TAG" make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_core; then \
	    echo "✓ Core layer build successful"; \
	else \
	    echo "✗ Core layer build failed"; \
	    echo ""; \
	    echo "BUILD FAILURE - TROUBLESHOOTING STEPS:"; \
	    echo "1. Check requirements files syntax in your project"; \
	    echo "2. Try building core layer manually:"; \
	    echo "   cd ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core && make build"; \
	    echo "3. Check for invalid package names: make debug_requirements"; \
	    echo "4. Clean and retry: make clean && make build"; \
	    exit 1; \
	fi && \
	if ADORE_CLI_IMAGE="adore_cli:$$ACTUAL_USER_TAG" ADORE_CLI_CORE_IMAGE="adore_cli_core:$$ACTUAL_CORE_TAG" make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_user; then \
	    echo "✓ User layer build successful"; \
	else \
	    echo "✗ User layer build failed"; \
	    echo ""; \
	    echo "BUILD FAILURE - TROUBLESHOOTING STEPS:"; \
	    echo "1. Check .deb packages in vendor/ directory"; \
	    echo "2. Try building user layer manually:"; \
	    echo "   cd ${ADORE_CLI_MAKEFILE_PATH}/adore_cli && make build"; \
	    echo "3. Check package dependencies: make debug_packages"; \
	    echo "4. Clean and retry: make clean && make build"; \
	    exit 1; \
	fi && \
	ACTUAL_BASE_TAG="$$ACTUAL_BASE_TAG" ACTUAL_CORE_TAG="$$ACTUAL_CORE_TAG" ACTUAL_USER_TAG="$$ACTUAL_USER_TAG" make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _save_built_tags
	@echo "=========================="
	@echo "=== Multi-layer build process complete ==="
	@source "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	echo "Final image: adore_cli:$$ACTUAL_USER_TAG"
	@echo ""
	@echo "✓ BUILD SUCCESSFUL!"
	@echo ""
	@echo "Next steps:"
	@echo "  Start development environment: make cli"
	@echo "  Run tests: make test"
	@echo "  View all ADORe CLI targets: make help_cli"
	@echo "  Check build status: make build_status"
	@echo ""
	@echo "If you encounter issues:"
	@echo "  Debug information: make adore_cli_info"
	@echo "  Force rebuild: make rebuild_force"
	@echo "  Clean and rebuild: make clean && make build"

.PHONY: build_adore_cli
build_adore_cli: _build_adore_cli_layers ## Build The ADORe CLI Docker Context

# === REBUILD TARGETS ===

.PHONY: rebuild_force
rebuild_force: ## Force rebuild all layers (ignore existing images and cache)
	@echo "=== FORCE REBUILD: Removing all existing ADORe CLI images ==="
	@echo "This will force rebuild all layers from scratch..."
	@echo ""
	@docker rmi ${ADORE_CLI_IMAGE} 2>/dev/null || true
	@docker rmi ${ADORE_CLI_CORE_IMAGE} 2>/dev/null || true  
	@docker rmi ${ADORE_CLI_BASE_IMAGE} 2>/dev/null || true
	@rm -f "${BUILT_TAGS_FILE}"
	@rm -f "${REQUIREMENTS_MANIFEST}" "${PACKAGES_MANIFEST}"
	@rm -f "${LAST_REQUIREMENTS_MANIFEST}" "${LAST_PACKAGES_MANIFEST}"
	@echo "Removed existing images and cache files"
	@echo "Starting complete rebuild..."
	@echo ""
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers

.PHONY: rebuild_from_layer
rebuild_from_layer: ## Rebuild from specific layer onwards. Usage: make rebuild_from_layer LAYER=base|core|user
	@if [ -z "$(LAYER)" ]; then \
	    echo "ERROR: LAYER parameter required"; \
	    echo "Usage: make rebuild_from_layer LAYER=base|core|user"; \
	    echo ""; \
	    echo "Examples:"; \
	    echo "  make rebuild_from_layer LAYER=base   # Rebuild base, core, and user layers"; \
	    echo "  make rebuild_from_layer LAYER=core   # Rebuild core and user layers"; \
	    echo "  make rebuild_from_layer LAYER=user   # Rebuild only user layer"; \
	    exit 1; \
	fi
	@echo "=== REBUILD FROM LAYER: $(LAYER) ==="
	@case "$(LAYER)" in \
	    base) \
	        echo "Rebuilding from base layer (all layers will be rebuilt)"; \
	        docker rmi ${ADORE_CLI_IMAGE} 2>/dev/null || true; \
	        docker rmi ${ADORE_CLI_CORE_IMAGE} 2>/dev/null || true; \
	        docker rmi ${ADORE_CLI_BASE_IMAGE} 2>/dev/null || true; \
	        ;; \
	    core) \
	        echo "Rebuilding from core layer (core and user layers will be rebuilt)"; \
	        docker rmi ${ADORE_CLI_IMAGE} 2>/dev/null || true; \
	        docker rmi ${ADORE_CLI_CORE_IMAGE} 2>/dev/null || true; \
	        ;; \
	    user) \
	        echo "Rebuilding user layer only"; \
	        docker rmi ${ADORE_CLI_IMAGE} 2>/dev/null || true; \
	        ;; \
	    *) \
	        echo "ERROR: Invalid layer '$(LAYER)'. Must be one of: base, core, user"; \
	        exit 1; \
	        ;; \
	esac
	@rm -f "${BUILT_TAGS_FILE}"
	@echo "Starting rebuild from $(LAYER) layer..."
	@echo ""
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers

# === INTERNAL BUILD TARGETS ===

.PHONY: _build_base_layer
_build_base_layer: check_cross_compile_deps
	@echo "Building base layer: ${ADORE_CLI_BASE_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    docker buildx build \
	        --builder=default \
	        --platform=$(DOCKER_PLATFORM) \
	        --target=adore_cli_base \
	        -t ${ADORE_CLI_BASE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base/Dockerfile.adore_cli_base \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base \
	        --load; \
	else \
	    docker build --network host \
	        --target=adore_cli_base \
	        -t ${ADORE_CLI_BASE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base/Dockerfile.adore_cli_base \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base; \
	fi

.PHONY: _build_core_layer
_build_core_layer: check_cross_compile_deps
	@echo "Building core layer: ${ADORE_CLI_CORE_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    docker buildx build \
	        --builder=default \
	        --platform=$(DOCKER_PLATFORM) \
	        --target=adore_cli_core \
	        -t ${ADORE_CLI_CORE_IMAGE} \
	        --build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core \
	        --load; \
	else \
	    docker build --network host \
	        --target=adore_cli_core \
	        -t ${ADORE_CLI_CORE_IMAGE} \
	        --build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core; \
	fi

.PHONY: _build_user_layer
_build_user_layer: check_cross_compile_deps
	@echo "Building user layer: ${ADORE_CLI_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    docker buildx build \
	        --builder=default \
	        --platform=$(DOCKER_PLATFORM) \
	        --target=adore_cli \
	        -t ${ADORE_CLI_IMAGE} \
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
	        --build-arg HOSTNAME=${HOSTNAME} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli/Dockerfile.adore_cli \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli \
	        --load; \
	else \
	    docker build --network host \
	        --target=adore_cli \
	        -t ${ADORE_CLI_IMAGE} \
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
	        --build-arg HOSTNAME=${HOSTNAME} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli/Dockerfile.adore_cli \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli; \
	fi

.PHONY: clean_adore_cli 
clean_adore_cli: ## Clean adore_cli docker context 
	@rm -f "${BUILT_TAGS_FILE}"
	cd "${ADORE_CLI_MAKEFILE_PATH}" && make clean

# === SMART BUILD TARGETS WITH MANIFEST CHECKING ===

.PHONY: _check_and_build_base
_check_and_build_base:
	@if ! docker image inspect ${ADORE_CLI_BASE_IMAGE} >/dev/null 2>&1; then \
	    echo "Base foundation image not found locally: ${ADORE_CLI_BASE_IMAGE}"; \
	    echo "Attempting to pull from registry..."; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _try_pull_base; \
	    if ! docker image inspect ${ADORE_CLI_BASE_IMAGE} >/dev/null 2>&1; then \
	        echo "Building base foundation layer locally: ${ADORE_CLI_BASE_IMAGE}"; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_base_layer; \
	    fi; \
	else \
	    echo "✓ Base foundation layer exists (using cache): ${ADORE_CLI_BASE_IMAGE}"; \
	fi

.PHONY: _check_and_build_core
_check_and_build_core:
	@if ! docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
	    echo "Core environment image not found locally: ${ADORE_CLI_CORE_IMAGE}"; \
	    echo "Attempting to pull from registry..."; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _try_pull_core; \
	    if ! docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
	        cd ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core && make gather_requirements; \
	        echo "Building core environment layer locally: ${ADORE_CLI_CORE_IMAGE}"; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core_layer; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _save_manifests; \
	    fi; \
	else \
	    echo "✓ Core environment layer exists (using cache): ${ADORE_CLI_CORE_IMAGE}"; \
	fi

.PHONY: _check_and_build_user
_check_and_build_user:
	@if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    echo "User layer image not found locally: ${ADORE_CLI_IMAGE}"; \
	    cd ${ADORE_CLI_MAKEFILE_PATH}/adore_cli && make gather_packages; \
	    echo "Building user layer locally: ${ADORE_CLI_IMAGE}"; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user_layer; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _save_manifests; \
	else \
	    echo "✓ User layer exists (using cache): ${ADORE_CLI_IMAGE}"; \
	fi

# === SETUP AND TEARDOWN ===

.PHONY: adore_cli_setup
adore_cli_setup: 
	@echo "Running adore_cli setup... SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.log/.adore_cli
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.ccache
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.bash_history
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.zsh_history
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.zsh_history.new

.PHONY: adore_cli_teardown
adore_cli_teardown:
	@echo "Running adore_cli teardown..."
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} down || true
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} rm -f || true
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} stop || true

.PHONY: adore_cli_start
adore_cli_start:
	@echo "Running adore_cli start..."
	@echo "  SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@echo "  ADORE_CLI_IMAGE: ${ADORE_CLI_IMAGE}"
	@echo "  ADORE_CLI_CONTAINER_NAME: ${ADORE_CLI_CONTAINER_NAME}"
	@echo "  Expected core image: ${ADORE_CLI_CORE_IMAGE}"
	@echo ${ADORE_CLI_MAKEFILE_PATH}
	@if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    echo "ERROR: Required user image not found: ${ADORE_CLI_IMAGE}"; \
	    echo "Available images with similar names:"; \
	    docker images --format "table {{.Repository}}:{{.Tag}}" | grep adore_cli || echo "  No adore_cli images found"; \
	    echo "Please run 'make build' first to create all required images"; \
	    exit 1; \
	fi
	cd ${ADORE_CLI_MAKEFILE_PATH} && \
	docker compose  -f ${DOCKER_COMPOSE_FILE} up \
	    --no-build \
	    --force-recreate \
	    --renew-anon-volumes \
	    --detach

.PHONY: adore_cli_run
adore_cli_run: ## Execute command in the ADORe CLI context. Usage: make adore_cli_run cmd="<your_command>"
	@if [ -z "$(cmd)" ]; then \
	    echo "Usage: make adore_cli_run cmd='<your_command>'"; \
	    exit 1; \
	fi
	@echo "Checking if container ${ADORE_CLI_CONTAINER_NAME} is running..."
	@if ! docker ps --filter "name=${ADORE_CLI_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${ADORE_CLI_CONTAINER_NAME}$$"; then \
	    echo "Container ${ADORE_CLI_CONTAINER_NAME} is not running. Starting it..."; \
	    make adore_cli_start; \
	fi
	@echo "Executing command in container ${ADORE_CLI_CONTAINER_NAME}: $(cmd)"
	docker exec --workdir /tmp/adore ${ADORE_CLI_CONTAINER_NAME} env DOCKER_EXEC_NON_INTERACTIVE=1 zsh -c "source ~/.zshrc && $(cmd)"; \

.PHONY: test_ros2_installation
test_ros2_installation:
	make run cmd="bash ${ADORE_CLI_MAKEFILE_PATH}/tools/test_ros2_installation.sh"

.PHONY: adore_cli_start_headless
adore_cli_start_headless: adore_cli_setup
	export DISPLAY_MODE=headless && make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_start 

.PHONY: adore_cli_attach
adore_cli_attach:
	@echo "Running adore_cli attach..."
	@docker exec -it ${ADORE_CLI_CONTAINER_NAME} /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh" || true

# === INFO TARGETS ===
.PHONY: branch_adore_cli
branch_adore_cli: ## Returns the current docker safe/sanitized branch for adore_cli 
	@printf "%s\n" ${ADORE_CLI_TAG}

.PHONY: image_adore_cli
image_adore_cli: ## Returns the current docker image name for adore_cli
	@echo "${ADORE_CLI_IMAGE}"

.PHONY: images_adore_cli
images_adore_cli: ## Returns all docker images for adore_cli
	@echo "${ADORE_CLI_BASE_IMAGE}"
	@echo "${ADORE_CLI_CORE_IMAGE}"
	@echo "${ADORE_CLI_IMAGE}"

.PHONY: container_name_adore_cli
container_name_adore_cli: ## Returns the container name for the adore_cli
	@echo "${ADORE_CLI_CONTAINER_NAME}"

.PHONY: adore_cli_info
adore_cli_info: ## Show configuration information for ADORe CLI
	@echo "=== ADORe CLI Configuration ==="
	@echo "ADORE_CLI_MAKEFILE_PATH: ${ADORE_CLI_MAKEFILE_PATH}"
	@echo "ROOT_DIR: ${ROOT_DIR}"
	@echo "SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@echo "VENDOR_PATH: ${VENDOR_PATH}"
	@echo "ROS_DISTRO: ${ROS_DISTRO}"
	@echo "OS_CODE_NAME: ${OS_CODE_NAME}"
	@echo "ARCH: ${ARCH}"
	@echo "DOCKER_PLATFORM: ${DOCKER_PLATFORM}"
	@echo "CROSS_COMPILE: ${CROSS_COMPILE}"
	@echo "USER: ${USER}"
	@echo "UID: ${UID}"
	@echo "GID: ${GID}"
	@echo "=== Docker Images ==="
	@echo "Base Foundation: ${ADORE_CLI_BASE_IMAGE}"
	@echo "Core Environment: ${ADORE_CLI_CORE_IMAGE}"
	@echo "User Layer: ${ADORE_CLI_IMAGE}"
	@echo "Container Name: ${ADORE_CLI_CONTAINER_NAME}"
	@echo "=== Build Configuration ==="
	@echo "DOCKER_BUILDKIT: ${DOCKER_BUILDKIT}"
	@echo "ADORe CLI Branch: ${ADORE_CLI_BRANCH}"
	@echo "ADORe CLI Hash: ${ADORE_CLI_SHORT_HASH}"
	@echo "ADORe CLI Dirty: ${ADORE_CLI_IS_DIRTY}"
	@echo "Parent Branch: ${PARENT_BRANCH}"
	@echo "Parent Hash: ${PARENT_SHORT_HASH}"
	@echo "Parent Dirty: ${PARENT_IS_DIRTY}"
	@echo "Parent is ADORe CLI: ${PARENT_IS_ADORE_CLI}"
	@echo "Requirements Hash: ${REQUIREMENTS_SHORT_HASH}"
	@echo "Packages Hash: ${PACKAGES_SHORT_HASH}"
	@echo "=== Built Tags Status ==="
	@if [ -f "${BUILT_TAGS_FILE}" ]; then \
	    echo "Built tags file exists: ${BUILT_TAGS_FILE}"; \
	    cat "${BUILT_TAGS_FILE}"; \
	else \
	    echo "No built tags file found at: ${BUILT_TAGS_FILE}"; \
	fi
	@echo "=== Manifest Status ==="
	@REQUIREMENTS_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_requirements_manifest_changed 2>/dev/null || echo "unknown"); \
	PACKAGES_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_packages_manifest_changed 2>/dev/null || echo "unknown"); \
	echo "Requirements Manifest Changed: $$REQUIREMENTS_CHANGED"; \
	echo "Packages Manifest Changed: $$PACKAGES_CHANGED"; \
	echo "Requirements Manifest: ${REQUIREMENTS_MANIFEST}"; \
	echo "Packages Manifest: ${PACKAGES_MANIFEST}"
	@echo "=== Paths Check ==="
	@echo "Called from: $(shell pwd)"
	@echo "Vendor exists: $(shell [ -d '${VENDOR_PATH}' ] && echo 'yes' || echo 'no')"
	@echo "Source is adore_cli: $(shell [ '${SOURCE_DIRECTORY}' = '${ADORE_CLI_MAKEFILE_PATH}' ] && echo 'yes' || echo 'no')"

.PHONY: build_status
build_status: ## Show status of all build layers
	@echo "=== ADORe CLI Build Status ==="
	@printf "%-20s %-60s %s\n" "Layer" "Image" "Status"
	@printf "%-20s %-60s %s\n" "----" "----" "----"
	@if docker image inspect ${ADORE_CLI_BASE_IMAGE} >/dev/null 2>&1; then \
	    printf "%-20s %-60s %s\n" "Base Foundation" "${ADORE_CLI_BASE_IMAGE}" "✓ EXISTS"; \
	else \
	    printf "%-20s %-60s %s\n" "Base Foundation" "${ADORE_CLI_BASE_IMAGE}" "✗ MISSING"; \
	fi
	@if docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
	    printf "%-20s %-60s %s\n" "Core Environment" "${ADORE_CLI_CORE_IMAGE}" "✓ EXISTS"; \
	else \
	    printf "%-20s %-60s %s\n" "Core Environment" "${ADORE_CLI_CORE_IMAGE}" "✗ MISSING"; \
	fi
	@if docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    printf "%-20s %-60s %s\n" "User Layer" "${ADORE_CLI_IMAGE}" "✓ EXISTS"; \
	else \
	    printf "%-20s %-60s %s\n" "User Layer" "${ADORE_CLI_IMAGE}" "✗ MISSING"; \
	fi

# === REGISTRY INTEGRATION ===

.PHONY: registry_status
registry_status:
	@echo "=== Registry Status ==="
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_PREFIX="ghcr.io/$${GITHUB_REPO}/"; \
	echo "Registry: $${REGISTRY_PREFIX}"; \
	echo "Checking base foundation: $${REGISTRY_PREFIX}${ADORE_CLI_BASE_IMAGE}"; \
	if docker manifest inspect "$${REGISTRY_PREFIX}${ADORE_CLI_BASE_IMAGE}" >/dev/null 2>&1; then \
	    echo "  ✓ Available in registry"; \
	else \
	    echo "  ✗ Not found in registry"; \
	fi; \
	echo "Checking core environment: $${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}"; \
	if docker manifest inspect "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}" >/dev/null 2>&1; then \
	    echo "  ✓ Available in registry"; \
	else \
	    echo "  ✗ Not found in registry"; \
	fi

.PHONY: try_pull_base_images
try_pull_base_images:
	@echo "=== Attempting to pull base and core images from registry ==="
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_PREFIX="ghcr.io/$${GITHUB_REPO}/"; \
	echo "Registry prefix: $${REGISTRY_PREFIX}"; \
	echo "Trying to pull base foundation: $${REGISTRY_PREFIX}${ADORE_CLI_BASE_IMAGE}"; \
	if docker pull "$${REGISTRY_PREFIX}${ADORE_CLI_BASE_IMAGE}" 2>/dev/null; then \
	    echo "✓ Pulled base foundation from registry"; \
	    docker tag "$${REGISTRY_PREFIX}${ADORE_CLI_BASE_IMAGE}" "${ADORE_CLI_BASE_IMAGE}"; \
	else \
	    echo "✗ Base foundation not found in registry"; \
	fi; \
	echo "Trying to pull core environment: $${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}"; \
	if docker pull "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}" 2>/dev/null; then \
	    echo "✓ Pulled core environment from registry"; \
	    docker tag "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}" "${ADORE_CLI_CORE_IMAGE}"; \
	else \
	    echo "✗ Core environment not found in registry"; \
	fi

.PHONY: push_base_images
push_base_images:
	@echo "=== Pushing base and core images to registry ==="
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_PREFIX="ghcr.io/$${GITHUB_REPO}/"; \
	echo "Registry prefix: $${REGISTRY_PREFIX}"; \
	if docker image inspect "${ADORE_CLI_BASE_IMAGE}" >/dev/null 2>&1; then \
	    echo "Tagging and pushing base foundation: ${ADORE_CLI_BASE_IMAGE}"; \
	    docker tag "${ADORE_CLI_BASE_IMAGE}" "$${REGISTRY_PREFIX}${ADORE_CLI_BASE_IMAGE}"; \
	    docker push "$${REGISTRY_PREFIX}${ADORE_CLI_BASE_IMAGE}"; \
	    echo "✓ Pushed base foundation"; \
	else \
	    echo "✗ Base foundation image not found locally"; \
	fi; \
	if docker image inspect "${ADORE_CLI_CORE_IMAGE}" >/dev/null 2>&1; then \
	    echo "Tagging and pushing core environment: ${ADORE_CLI_CORE_IMAGE}"; \
	    docker tag "${ADORE_CLI_CORE_IMAGE}" "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}"; \
	    docker push "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}"; \
	    echo "✓ Pushed core environment"; \
	else \
	    echo "✗ Core environment image not found locally"; \
	fi

.PHONY: cleanup_registry_images
cleanup_registry_images:
	@echo "=== Cleaning up old registry images ==="
	@if [ "$$(git branch --show-current 2>/dev/null || echo ${GITHUB_REF##*/})" != "ros2" ] && [ "${GITHUB_REF}" != "refs/heads/ros2" ]; then \
	    echo "Skipping cleanup - not on ros2 branch"; \
	    exit 0; \
	fi; \
	GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	echo "Getting last 2 commits from ros2 branch..."; \
	COMMITS=$$(git log --format="%H" -n 2 ros2 2>/dev/null || git log --format="%H" -n 2 HEAD); \
	echo "Commits to keep:"; \
	echo "$$COMMITS"; \
	KEEP_HASHES=""; \
	for commit in $$COMMITS; do \
	    short_hash=$$(echo $$commit | cut -c1-7); \
	    KEEP_HASHES="$$KEEP_HASHES $$short_hash"; \
	    echo "  - $$short_hash ($$commit)"; \
	done; \
	echo "Protected commit hashes:$$KEEP_HASHES"; \
	echo "Registry cleanup would preserve images with these hashes"

.PHONY: _try_pull_base
_try_pull_base:
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_IMAGE="ghcr.io/$${GITHUB_REPO}/${ADORE_CLI_BASE_IMAGE}"; \
	if docker pull "$$REGISTRY_IMAGE" 2>/dev/null; then \
	    docker tag "$$REGISTRY_IMAGE" "${ADORE_CLI_BASE_IMAGE}"; \
	    echo "✓ Pulled base foundation from registry"; \
	    exit 0; \
	else \
	    echo "✗ Base foundation not available in registry"; \
	    exit 1; \
	fi

.PHONY: _try_pull_core
_try_pull_core:
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_IMAGE="ghcr.io/$${GITHUB_REPO}/${ADORE_CLI_CORE_IMAGE}"; \
	if docker pull "$$REGISTRY_IMAGE" 2>/dev/null; then \
	    docker tag "$$REGISTRY_IMAGE" "${ADORE_CLI_CORE_IMAGE}"; \
	    echo "✓ Pulled core environment from registry"; \
	    exit 0; \
	else \
	    echo "✗ Core environment not available in registry"; \
	    exit 1; \
	fi

# === HELP TARGETS ===

.PHONY: help_cli
help_cli: ## Show ADORe CLI help 
	@echo "=== ADORe CLI Help ==="
	@echo ""
	@echo "ADORe CLI uses a three-layer Docker architecture for efficient builds:"
	@echo "  Target architecture: ${ARCH}"
	@echo "  ADORe CLI branch: ${ADORE_CLI_BRANCH} (${ADORE_CLI_SHORT_HASH})"
	@echo "  Parent project: ${PARENT_BRANCH} (${PARENT_SHORT_HASH})"
	@echo "  Requirements hash: ${REQUIREMENTS_SHORT_HASH}"
	@echo "  Packages hash: ${PACKAGES_SHORT_HASH}"
	@echo "  User: ${USER} (UID: ${UID}, GID: ${GID})"
	@echo ""
	@echo "Build strategy:"
	@echo "  1. Base layer:  OS + ROS2 foundation (highly cacheable)"
	@echo "  2. Core layer:  Complete environment + dependencies (shareable)"
	@echo "  3. User layer:  User customization + packages (user-specific)"
	@echo ""
	@echo "=== Main User Targets ==="
	@echo "  build              Build complete ADORe CLI environment (recommended first step)"
	@echo "  cli                Start/attach to ADORe CLI (auto-builds if needed)"
	@echo "  start              Start ADORe CLI in background"
	@echo "  stop               Stop ADORe CLI container"
	@echo "  run cmd=\"...\"       Execute command in ADORe CLI"
	@echo "  clean              Clean all images and build artifacts"
	@echo "  test               Run test suite"
	@echo ""
	@echo "=== Build and Debug Targets ==="
	@echo "  rebuild_force      Force rebuild all layers (ignore cache)"
	@echo "  rebuild_from_layer LAYER=base|core|user  Rebuild from specific layer"
	@echo "  build_status       Show status of all build layers"
	@echo "  adore_cli_info     Show current configuration"
	@echo "  debug_run          Launch interactive bash shell in user image"
	@echo "  debug_run_root     Launch interactive bash shell as root"
	@echo ""
	@echo "=== Registry Targets ==="
	@echo "  registry_status    Check availability of images in registry"
	@echo "  try_pull_base_images  Attempt to pull base/core from registry"
	@echo "  push_base_images   Push base/core images to registry"
	@echo ""
	@echo "=== Information Targets ==="
	@echo "  help_cli           Show this help message"
	@echo "  image_adore_cli    Show current user image name"
	@echo "  images_adore_cli   Show all image names"
	@echo "  container_name_adore_cli  Show container name"
	@echo "  branch_adore_cli   Show current tag"
	@echo ""
	@echo "=== Common Workflows ==="
	@echo ""
	@echo "First Time Setup:"
	@echo "  1. make build      # Build all layers"
	@echo "  2. make cli        # Start development environment"
	@echo ""
	@echo "Daily Development:"
	@echo "  - make cli         # Start/attach to environment"
	@echo "  - make stop        # Stop when done"
	@echo ""
	@echo "When Requirements Change:"
	@echo "  - make build       # Rebuild affected layers automatically"
	@echo "  - make cli         # Start with new environment"
	@echo ""
	@echo "Troubleshooting Build Issues:"
	@echo "  1. make build_status          # Check which layers exist"
	@echo "  2. make adore_cli_info        # Show configuration"
	@echo "  3. make rebuild_force         # Force complete rebuild"
	@echo "  4. make rebuild_from_layer LAYER=core  # Rebuild from core layer"
	@echo "  5. docker system prune -f    # Clean Docker cache if space issues"
	@echo ""
	@echo "Partial Rebuilds:"
	@echo "  - make rebuild_from_layer LAYER=base   # Rebuild all layers"
	@echo "  - make rebuild_from_layer LAYER=core   # Rebuild core + user"
	@echo "  - make rebuild_from_layer LAYER=user   # Rebuild user layer only"
	@echo ""
	@echo "=== Getting Help ==="
	@echo "  For build failures: Check error messages and try troubleshooting steps above"
	@echo "  For runtime issues: make adore_cli_info to check configuration"
	@echo "  For Docker issues: Ensure Docker daemon is running and has sufficient space"

endif
