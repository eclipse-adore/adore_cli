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
ADORE_CLI_LOG_DIRECTORY ?= ${SOURCE_DIRECTORY}/.log/.adore_cli

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
GITHUB_REPOSITORY?=eclipse-adore/adore_cli

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
REQUIREMENTS_HASH_FULL:=$(shell bash ${ADORE_CLI_MAKEFILE_PATH}/tools/requirements_hashing_util.sh hash "${SOURCE_DIRECTORY}")
REQUIREMENTS_HASH_SHORT:=$(shell echo "${REQUIREMENTS_HASH_FULL}" | cut -c1-7)

# === PACKAGES HASH GENERATION ===
PACKAGES_SHORT_HASH:=$(shell find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | sort | xargs -r -I {} basename {} 2>/dev/null | sort | sha256sum 2>/dev/null | cut -d' ' -f1 2>/dev/null | cut -c1-7 || echo "0000000")

# === MANIFEST PATHS ===
REQUIREMENTS_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/requirements_manifest.sha256
PACKAGES_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/packages_manifest.sha256
LAST_REQUIREMENTS_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/last_requirements_manifest.sha256
LAST_PACKAGES_MANIFEST:=${SOURCE_DIRECTORY}/.log/.adore_cli/last_packages_manifest.sha256

# === TAG STATE FILES ===
BUILT_TAGS_FILE:=${SOURCE_DIRECTORY}/.log/.adore_cli/built_tags
ADORE_CLI_TEMP_DIR:=${SOURCE_DIRECTORY}/.log/.adore_cli/temp

# === DIRECTORY CONFIGURATION ===
SOURCE_DIRECTORY?=${REPO_DIRECTORY}
ADORE_CLI_WORKING_DIRECTORY?=${SOURCE_DIRECTORY}
DOCKER_COMPOSE_FILE?=${ADORE_CLI_MAKEFILE_PATH}/docker-compose.yaml
REPO_DIRECTORY:=${ADORE_CLI_MAKEFILE_PATH}

# === USER CONFIGURATION ===
# Use different variable names to avoid conflicts with shell built-ins
USER_UID := $(shell id -u)
USER_GID := $(shell id -g)
# For backward compatibility, also set UID/GID but handle them carefully
UID ?= $(USER_UID)
GID ?= $(USER_GID)

# === BRANCH SHORTENING LOGIC ===
# Docker tags are limited to 128 characters, so we shorten branch names:
# 1. Remove everything before and including "/" (e.g., feature/docs → docs)
# 2. Truncate to max 20 characters
# 3. Remove trailing underscores

# Shortened branch names for tagging (max 20 chars, no prefixes)
ADORE_CLI_BRANCH_SHORT:=$(shell echo "${ADORE_CLI_BRANCH}" | sed 's|.*/||' | cut -c1-20 | sed 's/_$$//')
PARENT_BRANCH_SHORT:=$(shell echo "${PARENT_BRANCH}" | sed 's|.*/||' | cut -c1-20 | sed 's/_$$//')

# === CORE TAGGING LOGIC ===
# Base tags using shortened branch names
ADORE_CLI_BASE_TAG_CLEAN:=${ARCH}_${ADORE_CLI_BRANCH_SHORT}_${ADORE_CLI_SHORT_HASH}
ifeq ($(ADORE_CLI_IS_DIRTY),true)
    ADORE_CLI_BASE_TAG_DEFAULT:=${ADORE_CLI_BASE_TAG_CLEAN}_dirty
else
    ADORE_CLI_BASE_TAG_DEFAULT:=${ADORE_CLI_BASE_TAG_CLEAN}
endif

# Core image tagging with shortened branch names
ifeq ($(PARENT_IS_ADORE_CLI),true)
    ADORE_CLI_CORE_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_BRANCH_SHORT}_${ADORE_CLI_SHORT_HASH}
else
    ADORE_CLI_CORE_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_SHORT_HASH}_RH${REQUIREMENTS_HASH_SHORT}
endif

# User image tagging with shortened branch names and username truncation if needed
ifeq ($(PARENT_IS_ADORE_CLI),true)
    ADORE_CLI_USER_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_BRANCH_SHORT}_${ADORE_CLI_SHORT_HASH}_${USER}_UID${USER_UID}GID${USER_GID}
else
    # Truncate username to 8 chars to keep total tag length reasonable
    USER_SHORT:=$(shell echo "${USER}" | cut -c1-8)
    ADORE_CLI_USER_TAG_DEFAULT:=${ARCH}_${ADORE_CLI_BRANCH_SHORT}_${ADORE_CLI_SHORT_HASH}_${PARENT_BRANCH_SHORT}_${PARENT_SHORT_HASH}_RH${REQUIREMENTS_HASH_SHORT}_PH${PACKAGES_SHORT_HASH}_${USER_SHORT}_UID${USER_UID}GID${USER_GID}
endif

# Use default tags for runtime (simplified - no complex built tag logic)
ADORE_CLI_BASE_TAG:=${ADORE_CLI_BASE_TAG_DEFAULT}
ADORE_CLI_CORE_TAG:=${ADORE_CLI_CORE_TAG_DEFAULT}
ADORE_CLI_TAG:=${ADORE_CLI_USER_TAG_DEFAULT}

ADORE_CLI_BASE_IMAGE:=adore_cli_base:${ADORE_CLI_BASE_TAG}
ADORE_CLI_CORE_IMAGE:=adore_cli_core:${ADORE_CLI_CORE_TAG}
ADORE_CLI_IMAGE:=adore_cli:${ADORE_CLI_TAG}
ADORE_CLI_CONTAINER_NAME:=adore_cli_${ADORE_CLI_TAG}

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
.PHONY: _generate_current_manifests_only
_generate_current_manifests_only:
	@echo "Generating current manifests for comparison..."
	@mkdir -p "$(shell dirname ${REQUIREMENTS_MANIFEST})"
	@find "${SOURCE_DIRECTORY}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) \
		! -path "*/ros_translator/*" \
		! -path "*/.log/*" \
		! -path "*/.git/*" \
		! -path "*/build/*" \
		! -path "*/.tmp/*" \
		2>/dev/null | \
		sort | \
		xargs -r sha256sum 2>/dev/null | \
		sort > "${REQUIREMENTS_MANIFEST}" || touch "${REQUIREMENTS_MANIFEST}"
	@if [ -d "${VENDOR_PATH}" ]; then \
		find "${VENDOR_PATH}" -type f -name "*.deb" 2>/dev/null | \
		sort | \
		xargs -r sha256sum 2>/dev/null | \
		sort > "${PACKAGES_MANIFEST}"; \
	else \
		touch "${PACKAGES_MANIFEST}"; \
	fi

.PHONY: _generate_requirements_manifest
_generate_requirements_manifest:
	@echo "Generating requirements manifest..."
	@echo "  Using source directory: ${SOURCE_DIRECTORY}"
	@mkdir -p "$(shell dirname ${REQUIREMENTS_MANIFEST})"
	@(cd "${SOURCE_DIRECTORY}" && find . -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) \
		! -path "*/.log/*" \
		! -path "*/.git/*" \
		! -path "*/build/*" \
		! -path "*/.tmp/*" \
		2>/dev/null | \
		sort | \
		xargs -r sha256sum 2>/dev/null | \
		sed "s|  ${SOURCE_DIRECTORY}/|  |g" | \
		sed 's|  \./|  |g' | \
		sort) > "${REQUIREMENTS_MANIFEST}" || touch "${REQUIREMENTS_MANIFEST}"
	@echo "  Generated: ${REQUIREMENTS_MANIFEST}"

.PHONY: _save_manifests
_save_manifests:
	@echo "Saving manifests as last known good..."
	@if [ -f "${REQUIREMENTS_MANIFEST}" ]; then \
		cp "${REQUIREMENTS_MANIFEST}" "${LAST_REQUIREMENTS_MANIFEST}"; \
		echo "Requirements manifest saved"; \
	fi
	@if [ -f "${PACKAGES_MANIFEST}" ]; then \
		cp "${PACKAGES_MANIFEST}" "${LAST_PACKAGES_MANIFEST}"; \
		echo "Packages manifest saved"; \
	fi

.PHONY: _check_requirements_manifest_changed
_check_requirements_manifest_changed:
	@if [ -f "${LAST_REQUIREMENTS_MANIFEST}" ] && [ -f "${REQUIREMENTS_MANIFEST}" ]; then \
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
	@if [ -f "${LAST_PACKAGES_MANIFEST}" ] && [ -f "${PACKAGES_MANIFEST}" ]; then \
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
_determine_actual_build_tags:
	@echo "Determining actual build tags based on requirements and package changes..."
	@mkdir -p "${ADORE_CLI_TEMP_DIR}"
	@echo "=== Tag Determination Logic ==="
	@echo "Parent is ADORe CLI: ${PARENT_IS_ADORE_CLI}"
	@echo "Parent repo dirty: ${PARENT_IS_DIRTY}"
	@echo "Requirements short hash: ${REQUIREMENTS_HASH_SHORT}"
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
	@echo "Checking for environment changes..."
	@echo ""
	@if [ -f "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" ]; then \
		LAST_SUCCESSFUL_TAG=$$(bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" get_last 2>/dev/null || echo ""); \
		if [ -n "$$LAST_SUCCESSFUL_TAG" ]; then \
			echo "Found tag history with last successful environment: $$LAST_SUCCESSFUL_TAG"; \
			CALCULATED_TAG="${ADORE_CLI_TAG}"; \
			echo "Current calculated environment: $$CALCULATED_TAG"; \
			echo ""; \
			if [ "$$LAST_SUCCESSFUL_TAG" = "$$CALCULATED_TAG" ]; then \
				echo "✓ Environment unchanged since last successful build"; \
				if docker image inspect "adore_cli:$$CALCULATED_TAG" >/dev/null 2>&1; then \
					echo "✓ Required image exists"; \
					make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action; \
				else \
					echo "✗ Required image missing, building..."; \
					make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers; \
					bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || true; \
					make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action; \
				fi; \
			else \
				chmod +x "${ADORE_CLI_MAKEFILE_PATH}/tools/cli_prompt.sh"; \
				bash "${ADORE_CLI_MAKEFILE_PATH}/tools/cli_prompt.sh" "$$LAST_SUCCESSFUL_TAG" "$$CALCULATED_TAG" "${ADORE_CLI_MAKEFILE_PATH}"; \
			fi; \
		else \
			echo "No tag history found, building new environment..."; \
			make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers; \
			bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || true; \
			make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action; \
		fi; \
	else \
		echo "Tag history manager not found, using fallback..."; \
		make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _fallback_change_detection; \
	fi

.PHONY: _execute_last_successful_environment
_execute_last_successful_environment:
	@echo "Using last successful environment: ${LAST_TAG}"
	@# Extract core tag from last successful user tag
	@LAST_CORE_TAG=$$(echo "${LAST_TAG}" | sed -E 's/^(.+)_PH[a-f0-9]{7}_.*$$/\1/'); \
	if [[ "$$LAST_CORE_TAG" == "${LAST_TAG}" ]]; then \
		LAST_CORE_TAG=$$(echo "${LAST_TAG}" | sed -E 's/^(.+)_[^_]+_UID.*$$/\1/'); \
	fi; \
	echo "Extracted core tag: $$LAST_CORE_TAG"; \
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action \
		ADORE_CLI_TAG="${LAST_TAG}" \
		ADORE_CLI_IMAGE="adore_cli:${LAST_TAG}" \
		ADORE_CLI_CONTAINER_NAME="adore_cli_${LAST_TAG}" \
		ADORE_CLI_CORE_IMAGE="adore_cli_core:$$LAST_CORE_TAG"

.PHONY: _execute_environment_action
_execute_environment_action:
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
	    if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	        echo "Required image not found: ${ADORE_CLI_IMAGE}"; \
	        echo "Building missing images..."; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers; \
	        if [ -f "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" ]; then \
	            bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || true; \
	        fi; \
	    fi; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _start_and_attach_interactive; \
	fi

.PHONY: _fallback_change_detection
_fallback_change_detection:
	@echo "Using fallback change detection..."
	@REQUIREMENTS_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_requirements_manifest_changed 2>/dev/null || echo "true"); \
	PACKAGES_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_packages_manifest_changed 2>/dev/null || echo "true"); \
	if [ "$$REQUIREMENTS_CHANGED" = "true" ] || [ "$$PACKAGES_CHANGED" = "true" ]; then \
		echo "⚠️  Environment changes detected:"; \
		[ "$$REQUIREMENTS_CHANGED" = "true" ] && echo "  - Requirements files changed (*.system, *.pip3, *.ppa)"; \
		[ "$$PACKAGES_CHANGED" = "true" ] && echo "  - Package files changed (*.deb in vendor/)"; \
		echo ""; \
		echo "The environment needs to be rebuilt before starting CLI."; \
		echo "This may take several minutes depending on changes."; \
		echo ""; \
		printf "Rebuild now? [y/N]: "; \
		read -r answer; \
		case "$$answer" in \
			[yY]|[yY][eE][sS]) \
				echo "Rebuilding environment..."; \
				make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers; \
				if [ -f "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" ]; then \
					bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || true; \
				fi; \
				make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action; \
				;; \
			*) \
				echo "Aborted. Run 'make build' manually when ready."; \
				exit 1; \
				;; \
		esac; \
	else \
		echo "✓ No environment changes detected"; \
		make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action; \
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
run: adore_cli_setup _run_non_interactive ## Execute a command in the ADORe CLI context `make run cmd="<command to execute>"` 

.PHONY: _run_non_interactive
_run_non_interactive:
	@echo "=== ADORe CLI Non-Interactive Run ==="
	@# For run target, always use current tags without prompting
	@if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
		echo "Required image not found: ${ADORE_CLI_IMAGE}"; \
		echo "Building automatically for non-interactive run..."; \
		FORCE_NON_INTERACTIVE=true make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers; \
		if [ -f "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" ]; then \
			bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || true; \
		fi; \
	fi
	@CONTAINER_WAS_RUNNING=false; \
	if docker ps --filter "name=${ADORE_CLI_CONTAINER_NAME}" --format "{{.Names}}" | grep -q "^${ADORE_CLI_CONTAINER_NAME}$$"; then \
		echo "Container ${ADORE_CLI_CONTAINER_NAME} is already running - using existing session"; \
		CONTAINER_WAS_RUNNING=true; \
	else \
		echo "Container ${ADORE_CLI_CONTAINER_NAME} is not running - starting it for this command"; \
		make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_start; \
	fi; \
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_run; \
	if [ "$$CONTAINER_WAS_RUNNING" = "false" ]; then \
		echo "Stopping container that was started for this command"; \
		make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_teardown; \
	else \
		echo "Leaving existing container running"; \
	fi

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
	@echo "Requirements hash: ${REQUIREMENTS_HASH_SHORT}"
	@echo "Packages hash: ${PACKAGES_SHORT_HASH}"
	@echo "User: ${USER} (UID: ${USER_UID}, GID: ${USER_GID})"
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
		echo "1. Clean docker build cache with: 'docker buildx prune  && docker builder prune'"; \
	    echo "2. Clean and retry: make clean && make build"; \
		echo "3. Restart the docker engine with: 'sudo systemctl docker restart'"; \
	    exit 1; \
	fi && \
	ACTUAL_BASE_TAG="$$ACTUAL_BASE_TAG" ACTUAL_CORE_TAG="$$ACTUAL_CORE_TAG" ACTUAL_USER_TAG="$$ACTUAL_USER_TAG" make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _save_built_tags
	@echo "=========================="
	@echo "=== Multi-layer build process complete ==="
	@source "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	echo "Final image: adore_cli:$$ACTUAL_USER_TAG"
	@echo ""
	@echo "✓ BUILD SUCCESSFUL!"
	@echo "Saving manifests as last known good state..."
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _save_manifests
	@echo "Saving successful environment to tag history..."
	@if [ -f "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" ]; then \
		bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_TAG}" 2>/dev/null || echo "Warning: Could not save to tag history"; \
	fi
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
build_adore_cli: clean_tag_history _build_adore_cli_layers ## Build The ADORe CLI Docker Context

.PHONY: clean_tag_history
clean_tag_history:
	@echo "Cleaning ADORe CLI tag history..."
	@rm -f "${SOURCE_DIRECTORY}/.log/.adore_cli/tag_history"
	@rm -f "${SOURCE_DIRECTORY}/.log/.adore_cli/last_successful_env"
	@rm -f "${SOURCE_DIRECTORY}/.log/.adore_cli/adore_cli_tag_history"


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
	docker pull ros:${ROS_DISTRO}-ros-core-${OS_CODE_NAME} > /dev/null 2>&1 || true
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
	        --build-arg UID=${USER_UID} \
	        --build-arg GID=${USER_GID} \
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
	        --build-arg UID=${USER_UID} \
	        --build-arg GID=${USER_GID} \
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
	else \
	    echo "✓ User layer exists (using cache): ${ADORE_CLI_IMAGE}"; \
	fi

# === SETUP AND TEARDOWN ===

.PHONY: adore_cli_setup
adore_cli_setup: 
	@echo "Running adore_cli setup... SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@touch ${HOME}/.gitconfig
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.log/.adore_cli
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.ccache
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.bash_history
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.zsh_history
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.zsh_history.new
	@if command -v xhost >/dev/null 2>&1; then \
		echo "Configuring X11 access for Docker with 'xhost +local:docker'"; \
		xhost +local:docker; \
	else \
		echo "xhost not available - skipping X11 configuration (headless mode)"; \
	fi

.PHONY: adore_cli_teardown
adore_cli_teardown:
	@echo "Running adore_cli teardown..."
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} down 2>/dev/null || true
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} rm -f 2>/dev/null || true
	@cd ${ADORE_CLI_MAKEFILE_PATH} && docker compose -f ${DOCKER_COMPOSE_FILE} stop 2>/dev/null || true
	@if command -v xhost >/dev/null 2>&1; then \
		echo "Removing X11 access for Docker with 'xhost -local:docker'"; \
		xhost -local:docker || true; \
	else \
		echo "xhost not available - skipping X11 cleanup"; \
	fi

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
	@echo "USER_UID: ${USER_UID}"
	@echo "USER_GID: ${USER_GID}"
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
	@echo "Requirements Hash: ${REQUIREMENTS_HASH_SHORT}"
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

.PHONY: show_changes
show_changes: ## Show detailed information about detected changes
	@echo "=== Environment Change Analysis ==="
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _generate_current_manifests_only
	@REQUIREMENTS_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_requirements_manifest_changed 2>/dev/null || echo "true"); \
	PACKAGES_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_packages_manifest_changed 2>/dev/null || echo "true"); \
	echo "Requirements changed: $$REQUIREMENTS_CHANGED"; \
	echo "Packages changed: $$PACKAGES_CHANGED"; \
	echo ""; \
	if [ "$$REQUIREMENTS_CHANGED" = "true" ]; then \
		echo "=== Requirements Changes ==="; \
		echo "Current hash: ${REQUIREMENTS_HASH_SHORT}"; \
		if [ -f "${LAST_REQUIREMENTS_MANIFEST}" ] && [ -f "${REQUIREMENTS_MANIFEST}" ]; then \
			echo "Detailed diff:"; \
			diff -u "${LAST_REQUIREMENTS_MANIFEST}" "${REQUIREMENTS_MANIFEST}" || true; \
		fi; \
		echo "Current requirement files:"; \
		find "${SOURCE_DIRECTORY}" -name "*.system" -o -name "*.pip3" -o -name "*.ppa" | head -10; \
		echo ""; \
	fi; \
	if [ "$$PACKAGES_CHANGED" = "true" ]; then \
		echo "=== Package Changes ==="; \
		echo "Current hash: ${PACKAGES_SHORT_HASH}"; \
		if [ -f "${LAST_PACKAGES_MANIFEST}" ] && [ -f "${PACKAGES_MANIFEST}" ]; then \
			echo "Detailed diff:"; \
			diff -u "${LAST_PACKAGES_MANIFEST}" "${PACKAGES_MANIFEST}" || true; \
		fi; \
		echo "Current .deb files:"; \
		find "${VENDOR_PATH}" -name "*.deb" 2>/dev/null | head -10; \
		echo ""; \
	fi

.PHONY: reset_change_tracking
reset_change_tracking: ## Reset change tracking (force rebuild on next cli)
	@echo "Resetting change tracking manifests..."
	@rm -f "${REQUIREMENTS_MANIFEST}" "${PACKAGES_MANIFEST}"
	@rm -f "${LAST_REQUIREMENTS_MANIFEST}" "${LAST_PACKAGES_MANIFEST}"
	@echo "Change tracking reset. Next 'make cli' will trigger rebuild."

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

.PHONY: push_base_image
push_base_image:
	@echo "=== Pushing base image to registry ==="
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
	fi

.PHONY: push_core_image
push_core_image:
	@echo "=== Pushing base image to registry ==="
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_PREFIX="ghcr.io/$${GITHUB_REPO}/"; \
	echo "Registry prefix: $${REGISTRY_PREFIX}"; \
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
	@echo "  Requirements hash: ${REQUIREMENTS_HASH_SHORT}"
	@echo "  Packages hash: ${PACKAGES_SHORT_HASH}"
	@echo "  User: ${USER} (UID: ${USER_UID}, GID: ${USER_GID})"
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
	@echo "  show_changes       Show detailed change information"
	@echo "  reset_change_tracking  Reset change detection"
	@echo ""
	@echo "=== Registry Targets ==="
	@echo "  registry_status    Check availability of images in registry"
	@echo "  try_pull_base_images  Attempt to pull base/core from registry"
	@echo "  push_base_image    Push base image to registry"
	@echo "  push_core_image    Push core image to registry"
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
	@echo "  - make cli         # Will detect changes and prompt to rebuild"
	@echo "  - make show_changes # See what changed"
	@echo ""
	@echo "Troubleshooting Build Issues:"
	@echo "  1. make build_status          # Check which layers exist"
	@echo "  2. make adore_cli_info        # Show configuration"
	@echo "  3. make show_changes          # See what changed"
	@echo "  4. make rebuild_force         # Force complete rebuild"
	@echo "  5. make rebuild_from_layer LAYER=core  # Rebuild from core layer"
	@echo "  6. docker system prune -f     # Clean Docker cache if space issues"
	@echo "  7. docker builder prune       # Stale docker cache can cause non-deterministic failures. Try pruning the docker builder cache."
	@echo "  8. sudo systemctl restart docker # Frequent network changes such as WIFI changes can break docker routing causing random build failures."

.PHONY: debug_hashes
debug_hashes: ## Debug hash calculation
	@echo "=== Hash Debug Information ==="
	@echo "Requirements files found:"
	@find "${SOURCE_DIRECTORY}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) \
		! -path "*/ros_translator/*" ! -path "*/.log/*" ! -path "*/.git/*" ! -path "*/build/*" ! -path "*/.tmp/*" \
		2>/dev/null || echo "  None found"
	@echo ""
	@echo "Requirements hash calculation:"
	@echo "  Raw content hash: $(shell find "${SOURCE_DIRECTORY}" -type f \( -name "*.system" -o -name "*.pip3" -o -name "*.ppa" \) ! -path "*/ros_translator/*" ! -path "*/.log/*" ! -path "*/.git/*" ! -path "*/build/*" 2>/dev/null | xargs -r cat 2>/dev/null | sha256sum | cut -c1-7)"
	@echo "  REQUIREMENTS_HASH_SHORT: ${REQUIREMENTS_HASH_SHORT}"
	@echo ""
	@echo "Package files found:"
	@find "${VENDOR_PATH}" -name "*.deb" 2>/dev/null || echo "  None found"
	@echo ""
	@echo "Package hash calculation:"
	@echo "  PACKAGES_SHORT_HASH: ${PACKAGES_SHORT_HASH}"
	@echo ""
	@echo "Calculated tags:"
	@echo "  Core: ${ADORE_CLI_CORE_TAG}"
	@echo "  User: ${ADORE_CLI_TAG}"

endif
