# This Makefile contains useful targets that can be included in downstream projects.

ifeq ($(filter adore_cli.mk, $(notdir $(MAKEFILE_LIST))), adore_cli.mk)

# === SHELL AND EXPORT CONFIGURATION ===
SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.NOTPARALLEL:

# === IMMEDIATE USER IDENTIFICATION ===
override UID := $(strip $(shell id -u))
override GID := $(strip $(shell id -g))
override USER := $(strip $(shell whoami))

# Validate they're not empty
$(if $(UID),,$(error "Cannot determine UID"))
$(if $(GID),,$(error "Cannot determine GID"))  
$(if $(USER),,$(error "Cannot determine USER"))


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
TAG_HISTORY_SCRIPT:=${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh

# === CORE TAGGING LOGIC ===
# Force immediate evaluation to ensure UID/GID are available and properly trimmed
USER_TAG_UID_GID := UID$(UID)GID$(GID)

# Base tags (always use adore_cli repo info) - trim any whitespace
ADORE_CLI_BASE_TAG_CLEAN:=$(shell echo "${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}" | tr -d ' \t\n\r')
ifeq ($(ADORE_CLI_IS_DIRTY),true)
    ADORE_CLI_BASE_TAG_DEFAULT:=$(shell echo "${ADORE_CLI_BASE_TAG_CLEAN}_dirty" | tr -d ' \t\n\r')
else
    ADORE_CLI_BASE_TAG_DEFAULT:=$(shell echo "${ADORE_CLI_BASE_TAG_CLEAN}" | tr -d ' \t\n\r')
endif

# Core image tagging according to requirements (using uppercase RH) - trim any whitespace
ifeq ($(PARENT_IS_ADORE_CLI),true)
    ADORE_CLI_CORE_TAG_DEFAULT:=$(shell echo "${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}" | tr -d ' \t\n\r')
else
    ADORE_CLI_CORE_TAG_DEFAULT:=$(shell echo "${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${PARENT_BRANCH}_${PARENT_SHORT_HASH}_RH${REQUIREMENTS_SHORT_HASH}" | tr -d ' \t\n\r')
endif

# User image tagging with package hash, username, UID and GID (using uppercase PH) - trim any whitespace
ifeq ($(PARENT_IS_ADORE_CLI),true)
    ADORE_CLI_USER_TAG_DEFAULT:=$(shell echo "${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${USER}_${USER_TAG_UID_GID}" | tr -d ' \t\n\r')
else
    ADORE_CLI_USER_TAG_DEFAULT:=$(shell echo "${ARCH}_${ADORE_CLI_BRANCH}_${ADORE_CLI_SHORT_HASH}_${PARENT_BRANCH}_${PARENT_SHORT_HASH}_PH${PACKAGES_SHORT_HASH}_${USER}_${USER_TAG_UID_GID}" | tr -d ' \t\n\r')
endif

# Validate that the final tag doesn't contain empty UID/GID
ifeq ($(findstring UIDGID,$(ADORE_CLI_USER_TAG_DEFAULT)),UIDGID)
$(error "ERROR: User tag contains empty UID/GID: $(ADORE_CLI_USER_TAG_DEFAULT)")
endif

# Use default tags for runtime (will be overridden by smart selection)
# Allow environment variables to override makefile defaults (for runtime tag switching)
ADORE_CLI_BASE_TAG := $(or $(ADORE_CLI_BASE_TAG),${ADORE_CLI_BASE_TAG_DEFAULT})
ADORE_CLI_CORE_TAG := $(or $(ADORE_CLI_CORE_TAG),${ADORE_CLI_CORE_TAG_DEFAULT})
ADORE_CLI_TAG := $(or $(ADORE_CLI_TAG),${ADORE_CLI_USER_TAG_DEFAULT})

ADORE_CLI_BASE_IMAGE := $(or $(ADORE_CLI_BASE_IMAGE),adore_cli_base:${ADORE_CLI_BASE_TAG})
ADORE_CLI_CORE_IMAGE := $(or $(ADORE_CLI_CORE_IMAGE),adore_cli_core:${ADORE_CLI_CORE_TAG})
ADORE_CLI_IMAGE := $(or $(ADORE_CLI_IMAGE),adore_cli:${ADORE_CLI_TAG})
ADORE_CLI_CONTAINER_NAME := $(or $(ADORE_CLI_CONTAINER_NAME),adore_cli_${ADORE_CLI_TAG})

# === DIRECTORY CONFIGURATION ===
SOURCE_DIRECTORY?=${REPO_DIRECTORY}
ADORE_CLI_WORKING_DIRECTORY?=${SOURCE_DIRECTORY}
DOCKER_COMPOSE_FILE?=${ADORE_CLI_MAKEFILE_PATH}/docker-compose.yaml
REPO_DIRECTORY:=${ADORE_CLI_MAKEFILE_PATH}

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

.PHONY: _determine_actual_build_tags
_determine_actual_build_tags: _generate_requirements_manifest _generate_packages_manifest
	@echo "Determining actual build tags based on requirements and package changes..."
	@mkdir -p "${ADORE_CLI_TEMP_DIR}"
	@echo "=== Tag Determination Logic ==="
	@echo "Parent is ADORe CLI: ${PARENT_IS_ADORE_CLI}"
	@echo "Parent repo dirty: ${PARENT_IS_DIRTY}"
	@echo "Requirements short hash: ${REQUIREMENTS_SHORT_HASH}"
	@echo "Packages short hash: ${PACKAGES_SHORT_HASH}"
	@echo "User: ${USER} (UID: ${UID}, GID: ${GID})"
	@# Validate UID and GID are not empty
	@if [ -z "${UID}" ] || [ -z "${GID}" ]; then \
	    echo "ERROR: UID or GID is empty. UID=${UID}, GID=${GID}"; \
	    exit 1; \
	fi
	@REQUIREMENTS_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_requirements_manifest_changed); \
	PACKAGES_CHANGED=$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_packages_manifest_changed); \
	echo "Requirements manifest changed: $$REQUIREMENTS_CHANGED"; \
	echo "Packages manifest changed: $$PACKAGES_CHANGED"; \
	ACTUAL_BASE_TAG="$$(echo "${ADORE_CLI_BASE_TAG_DEFAULT}" | tr -d ' \t\n\r')"; \
	CORE_BASE_TAG="$$(echo "${ADORE_CLI_CORE_TAG_DEFAULT}" | tr -d ' \t\n\r')"; \
	if [ "$$REQUIREMENTS_CHANGED" = "true" ] || [ "${PARENT_IS_DIRTY}" = "true" ]; then \
	    echo "→ Requirements changed or parent dirty → rebuilding core layer"; \
	    ACTUAL_CORE_TAG="$${CORE_BASE_TAG}_dirty"; \
	else \
	    echo "→ No requirements changes → using clean core tag"; \
	    ACTUAL_CORE_TAG="$$CORE_BASE_TAG"; \
	fi; \
	USER_BASE_TAG="$$(echo "${ADORE_CLI_USER_TAG_DEFAULT}" | tr -d ' \t\n\r')"; \
	if [ "$$PACKAGES_CHANGED" = "true" ]; then \
	    echo "→ Packages changed → rebuilding user layer with current package hash"; \
	    ACTUAL_USER_TAG="$$USER_BASE_TAG"; \
	else \
	    echo "→ No package changes → using clean user tag with package hash"; \
	    ACTUAL_USER_TAG="$$USER_BASE_TAG"; \
	fi; \
	echo "Validating final tags..."; \
	if echo "$$ACTUAL_USER_TAG" | grep -q "UIDGID"; then \
	    echo "ERROR: User tag contains empty UID/GID: $$ACTUAL_USER_TAG"; \
	    echo "UID=${UID}, GID=${GID}, USER=${USER}"; \
	    exit 1; \
	fi; \
	printf "ACTUAL_BASE_TAG=%s\n" "$$ACTUAL_BASE_TAG" > "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	printf "ACTUAL_CORE_TAG=%s\n" "$$ACTUAL_CORE_TAG" >> "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	printf "ACTUAL_USER_TAG=%s\n" "$$ACTUAL_USER_TAG" >> "${ADORE_CLI_TEMP_DIR}/build_vars"; \
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

# === TAG HISTORY AND ENVIRONMENT MANAGEMENT ===

.PHONY: _smart_environment_selection
_smart_environment_selection: _determine_actual_build_tags
	@echo "=== Smart Environment Selection ==="
	@echo "Current state:"
	@echo "  Base tag: ${ADORE_CLI_BASE_TAG_DEFAULT}"
	@echo "  Core tag: ${ADORE_CLI_CORE_TAG_DEFAULT}"  
	@echo "  User tag: ${ADORE_CLI_USER_TAG_DEFAULT}"
	@source "${ADORE_CLI_TEMP_DIR}/build_vars" && \
	ACTUAL_BASE_TAG="$$(echo "$$ACTUAL_BASE_TAG" | tr -d ' \t\n\r')" && \
	ACTUAL_CORE_TAG="$$(echo "$$ACTUAL_CORE_TAG" | tr -d ' \t\n\r')" && \
	ACTUAL_USER_TAG="$$(echo "$$ACTUAL_USER_TAG" | tr -d ' \t\n\r')" && \
	LAST_USER_TAG=$$(SOURCE_DIRECTORY="${SOURCE_DIRECTORY}" bash "${TAG_HISTORY_SCRIPT}" get_last 2>/dev/null || echo ""); \
	if [ -n "$$LAST_USER_TAG" ]; then \
	    echo "Last successful: $$LAST_USER_TAG"; \
	    if [ "$$LAST_USER_TAG" = "$$ACTUAL_USER_TAG" ]; then \
	        echo "Calculated tag matches last successful environment"; \
	        if SOURCE_DIRECTORY="${SOURCE_DIRECTORY}" bash "${TAG_HISTORY_SCRIPT}" check_exists "$$ACTUAL_USER_TAG"; then \
	            echo "Environment exists, using current configuration"; \
	            echo "use_current" > "${ADORE_CLI_TEMP_DIR}/env_action"; \
	        else \
	            echo "Environment missing, will build"; \
	            echo "build_missing" > "${ADORE_CLI_TEMP_DIR}/env_action"; \
	        fi; \
	    else \
	        echo "Tags differ, checking for changes..."; \
	        CHANGE_REASON="Tag calculation changed"; \
	        if [ "$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_requirements_manifest_changed)" = "true" ]; then \
	            CHANGE_REASON="Requirements files changed"; \
	        elif [ "$$(make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_packages_manifest_changed)" = "true" ]; then \
	            CHANGE_REASON="Package files changed"; \
	        elif [ "${PARENT_IS_DIRTY}" = "true" ]; then \
	            CHANGE_REASON="Git repository has uncommitted changes"; \
	        fi; \
	        echo "Change reason: $$CHANGE_REASON"; \
	        ACTION=$$(SOURCE_DIRECTORY="${SOURCE_DIRECTORY}" bash "${TAG_HISTORY_SCRIPT}" check_changes \
	            "$$LAST_USER_TAG" "" "$$LAST_USER_TAG" \
	            "$$ACTUAL_BASE_TAG" "$$ACTUAL_CORE_TAG" "$$ACTUAL_USER_TAG" \
	            "$$CHANGE_REASON"); \
	        if [ -z "$$ACTION" ]; then \
	            echo "ERROR: No action returned from tag history manager"; \
	            exit 1; \
	        fi; \
	        echo "$$ACTION" > "${ADORE_CLI_TEMP_DIR}/env_action"; \
	    fi; \
	else \
	    echo "No previous successful environment found"; \
	    if SOURCE_DIRECTORY="${SOURCE_DIRECTORY}" bash "${TAG_HISTORY_SCRIPT}" check_exists "$$ACTUAL_USER_TAG"; then \
	        echo "Calculated environment exists, will use it"; \
	        echo "use_current" > "${ADORE_CLI_TEMP_DIR}/env_action"; \
	    else \
	        echo "No existing environment found, will build new one"; \
	        echo "build_new" > "${ADORE_CLI_TEMP_DIR}/env_action"; \
	    fi; \
	fi
	@echo "Environment selection complete"

.PHONY: _execute_environment_action  
_execute_environment_action: _smart_environment_selection
	@echo "=== Executing Environment Action ==="
	@if [ ! -f "${ADORE_CLI_TEMP_DIR}/env_action" ]; then \
	    echo "ERROR: No environment action determined"; \
	    exit 1; \
	fi
	@ACTION=$$(cat "${ADORE_CLI_TEMP_DIR}/env_action" | tr -d ' \t\n\r'); \
	if [ -z "$$ACTION" ]; then \
	    echo "ERROR: Environment action is empty"; \
	    exit 1; \
	fi; \
	echo "Action: $$ACTION"; \
	case "$$ACTION" in \
	    use_current) \
	        echo "Using current environment configuration"; \
	        source "${ADORE_CLI_TEMP_DIR}/build_vars" && \
	        ACTUAL_BASE_TAG="$$(echo "$$ACTUAL_BASE_TAG" | tr -d ' \t\n\r')" && \
	        ACTUAL_CORE_TAG="$$(echo "$$ACTUAL_CORE_TAG" | tr -d ' \t\n\r')" && \
	        ACTUAL_USER_TAG="$$(echo "$$ACTUAL_USER_TAG" | tr -d ' \t\n\r')" && \
	        printf "FINAL_BASE_TAG=%s\n" "$$ACTUAL_BASE_TAG" > "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	        printf "FINAL_CORE_TAG=%s\n" "$$ACTUAL_CORE_TAG" >> "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	        printf "FINAL_USER_TAG=%s\n" "$$ACTUAL_USER_TAG" >> "${ADORE_CLI_TEMP_DIR}/final_tags"; \
	        ;; \
	    build_missing|build_new) \
	        echo "Building new environment..."; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers_smart; \
	        ;; \
	    abort) \
	        echo "User aborted operation"; \
	        exit 1; \
	        ;; \
	    *) \
	        echo "ERROR: Unknown action: $$ACTION"; \
	        exit 1; \
	        ;; \
	esac
	@echo "Environment action completed"

.PHONY: _build_adore_cli_layers_smart
_build_adore_cli_layers_smart: 
	@echo "=== Smart ADORe CLI Build Process ==="
	@source "${ADORE_CLI_TEMP_DIR}/build_vars" && \
	ACTUAL_BASE_TAG="$$(echo "$$ACTUAL_BASE_TAG" | tr -d ' \t\n\r')" && \
	ACTUAL_CORE_TAG="$$(echo "$$ACTUAL_CORE_TAG" | tr -d ' \t\n\r')" && \
	ACTUAL_USER_TAG="$$(echo "$$ACTUAL_USER_TAG" | tr -d ' \t\n\r')" && \
	echo "Building with determined tags:" && \
	echo "  Base: adore_cli_base:$$ACTUAL_BASE_TAG" && \
	echo "  Core: adore_cli_core:$$ACTUAL_CORE_TAG" && \
	echo "  User: adore_cli:$$ACTUAL_USER_TAG" && \
	ADORE_CLI_BASE_IMAGE="adore_cli_base:$$ACTUAL_BASE_TAG" \
	ADORE_CLI_CORE_IMAGE="adore_cli_core:$$ACTUAL_CORE_TAG" \
	ADORE_CLI_IMAGE="adore_cli:$$ACTUAL_USER_TAG" \
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers_internal && \
	echo "Saving successful environment to history..." && \
	SOURCE_DIRECTORY="${SOURCE_DIRECTORY}" bash "${TAG_HISTORY_SCRIPT}" save "$$ACTUAL_BASE_TAG" "$$ACTUAL_CORE_TAG" "$$ACTUAL_USER_TAG" && \
	printf "FINAL_BASE_TAG=%s\n" "$$ACTUAL_BASE_TAG" > "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	printf "FINAL_CORE_TAG=%s\n" "$$ACTUAL_CORE_TAG" >> "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	printf "FINAL_USER_TAG=%s\n" "$$ACTUAL_USER_TAG" >> "${ADORE_CLI_TEMP_DIR}/final_tags"

.PHONY: _build_adore_cli_layers_internal
_build_adore_cli_layers_internal: check_cross_compile_deps
	@echo "=== ADORe CLI Multi-Layer Build Process ==="
	@echo "Building ADORe CLI with three-layer architecture..."
	@echo "Target architecture: ${ARCH}"
	@echo "Build strategy:"
	@echo "  1. Base layer:  Try registry pull → Use cache → Build locally"
	@echo "  2. Core layer:  Try registry pull → Use cache → Build locally"
	@echo "  3. User layer:  Use cache → Build locally (never pulled)"
	@echo ""
	@echo "Starting build process..."
	@echo "=========================="
	@if make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_base; then \
	    echo "✓ Base layer build successful"; \
	else \
	    echo "✗ Base layer build failed"; \
	    exit 1; \
	fi && \
	if make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_core; then \
	    echo "✓ Core layer build successful"; \
	else \
	    echo "✗ Core layer build failed"; \
	    exit 1; \
	fi && \
	if make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_user; then \
	    echo "✓ User layer build successful"; \
	else \
	    echo "✗ User layer build failed"; \
	    exit 1; \
	fi
	@echo "=========================="
	@echo "=== Multi-layer build process complete ==="
	@echo "✓ BUILD SUCCESSFUL!"

.PHONY: _update_runtime_tags
_update_runtime_tags: _execute_environment_action
	@echo "=== Updating Runtime Tags ==="
	@if [ ! -f "${ADORE_CLI_TEMP_DIR}/final_tags" ]; then \
	    echo "ERROR: No final tags determined"; \
	    exit 1; \
	fi
	@source "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	FINAL_BASE_TAG="$$(echo "$$FINAL_BASE_TAG" | tr -d ' \t\n\r')" && \
	FINAL_CORE_TAG="$$(echo "$$FINAL_CORE_TAG" | tr -d ' \t\n\r')" && \
	FINAL_USER_TAG="$$(echo "$$FINAL_USER_TAG" | tr -d ' \t\n\r')" && \
	echo "Final runtime tags:" && \
	echo "  Base: adore_cli_base:$$FINAL_BASE_TAG" && \
	echo "  Core: adore_cli_core:$$FINAL_CORE_TAG" && \
	echo "  User: adore_cli:$$FINAL_USER_TAG" && \
	printf "export RUNTIME_BASE_TAG=\"%s\"\n" "$$FINAL_BASE_TAG" > "${ADORE_CLI_TEMP_DIR}/runtime_vars" && \
	printf "export RUNTIME_CORE_TAG=\"%s\"\n" "$$FINAL_CORE_TAG" >> "${ADORE_CLI_TEMP_DIR}/runtime_vars" && \
	printf "export RUNTIME_USER_TAG=\"%s\"\n" "$$FINAL_USER_TAG" >> "${ADORE_CLI_TEMP_DIR}/runtime_vars" && \
	echo "Runtime tags updated"

# === MAIN CLI TARGET ===

.PHONY: cli 
cli: docker_host_context_check _cli_smart_attach ## Start ADORe CLI docker context or attach to it if it is already running

.PHONY: _cli_smart_attach
_cli_smart_attach: _update_runtime_tags
	@echo "=== ADORe CLI Smart Attach ==="
	@source "${ADORE_CLI_TEMP_DIR}/runtime_vars" && \
	RUNTIME_USER_TAG="$$(echo "$$RUNTIME_USER_TAG" | tr -d ' \t\n\r')" && \
	RUNTIME_IMAGE="adore_cli:$$RUNTIME_USER_TAG" && \
	RUNTIME_CONTAINER="adore_cli_$$RUNTIME_USER_TAG" && \
	echo "Target container: $$RUNTIME_CONTAINER" && \
	echo "Target image: $$RUNTIME_IMAGE" && \
	echo "" && \
	if docker ps --format "{{.Names}}" | grep -q "^$$RUNTIME_CONTAINER$$"; then \
	    echo "✓ Container $$RUNTIME_CONTAINER is already running"; \
	    echo "Attaching to existing session..."; \
	    echo "Type 'exit' to detach from container (container will continue running)"; \
	    echo "Use 'make stop' to stop the container"; \
	    echo ""; \
	    docker exec -it "$$RUNTIME_CONTAINER" /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh"; \
	    echo ""; \
	    echo "Detached from container. Container is still running."; \
	    echo "Use 'make cli' to reattach or 'make stop' to stop it."; \
	elif docker ps -a --format "{{.Names}}" | grep -q "^$$RUNTIME_CONTAINER$$"; then \
	    echo "Container $$RUNTIME_CONTAINER exists but is stopped"; \
	    echo "Starting existing container..."; \
	    docker start "$$RUNTIME_CONTAINER"; \
	    echo "Attaching to restarted container..."; \
	    docker exec -it "$$RUNTIME_CONTAINER" /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh"; \
	else \
	    echo "No existing container found with name: $$RUNTIME_CONTAINER"; \
	    if ! docker image inspect "$$RUNTIME_IMAGE" >/dev/null 2>&1; then \
	        echo "ERROR: Required user image not found: $$RUNTIME_IMAGE"; \
	        echo "This should not happen after smart environment selection"; \
	        exit 1; \
	    fi; \
	    export ADORE_CLI_IMAGE="$$RUNTIME_IMAGE" && \
	    export ADORE_CLI_CONTAINER_NAME="$$RUNTIME_CONTAINER" && \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _start_and_attach_interactive; \
	fi

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
run: ## Execute a command in the ADORe CLI context `make run cmd="<command to execute>"`
	@export ADORE_CLI_NON_INTERACTIVE=1 && \
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_setup adore_cli_start adore_cli_run adore_cli_teardown

.PHONY: adore_cli_up
adore_cli_up: adore_cli_setup adore_cli_start adore_cli_attach adore_cli_teardown 

.PHONY: stop_adore_cli
stop_adore_cli: docker_host_context_check adore_cli_teardown ## Stop adore_cli docker context if it is running

# === BUILD TARGETS ===

.PHONY: build_adore_cli
build_adore_cli: _build_adore_cli_layers_force ## Build The ADORe CLI Docker Context (always builds current state)

.PHONY: _build_adore_cli_layers  
_build_adore_cli_layers: _build_adore_cli_layers_force ## Complete build process for ADORe CLI environment (always builds current state)

.PHONY: _build_adore_cli_layers_force
_build_adore_cli_layers_force: check_cross_compile_deps _determine_actual_build_tags
	@echo "=== ADORe CLI Build Process (Force Build) ==="
	@echo "Building ADORe CLI with three-layer architecture..."
	@echo "Target architecture: ${ARCH}"
	@echo "Build strategy: Always build current calculated state"
	@echo ""
	@echo "Starting build process..."
	@echo "=========================="
	@source "${ADORE_CLI_TEMP_DIR}/build_vars" && \
	ACTUAL_BASE_TAG="$$(echo "$$ACTUAL_BASE_TAG" | tr -d ' \t\n\r')" && \
	ACTUAL_CORE_TAG="$$(echo "$$ACTUAL_CORE_TAG" | tr -d ' \t\n\r')" && \
	ACTUAL_USER_TAG="$$(echo "$$ACTUAL_USER_TAG" | tr -d ' \t\n\r')" && \
	echo "Building with determined tags:" && \
	echo "  Base: adore_cli_base:$$ACTUAL_BASE_TAG" && \
	echo "  Core: adore_cli_core:$$ACTUAL_CORE_TAG" && \
	echo "  User: adore_cli:$$ACTUAL_USER_TAG" && \
	ADORE_CLI_BASE_IMAGE="adore_cli_base:$$ACTUAL_BASE_TAG" \
	ADORE_CLI_CORE_IMAGE="adore_cli_core:$$ACTUAL_CORE_TAG" \
	ADORE_CLI_IMAGE="adore_cli:$$ACTUAL_USER_TAG" \
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers_internal && \
	echo "Saving successful environment to history..." && \
	SOURCE_DIRECTORY="${SOURCE_DIRECTORY}" bash "${TAG_HISTORY_SCRIPT}" save "$$ACTUAL_BASE_TAG" "$$ACTUAL_CORE_TAG" "$$ACTUAL_USER_TAG" && \
	printf "FINAL_BASE_TAG=%s\n" "$$ACTUAL_BASE_TAG" > "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	printf "FINAL_CORE_TAG=%s\n" "$$ACTUAL_CORE_TAG" >> "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	printf "FINAL_USER_TAG=%s\n" "$$ACTUAL_USER_TAG" >> "${ADORE_CLI_TEMP_DIR}/final_tags" && \
	echo "Build completed successfully!"

# === REBUILD TARGETS ===

.PHONY: rebuild_force
rebuild_force: ## Force rebuild all layers (ignore existing images and cache)
	@echo "=== FORCE REBUILD: Removing all existing ADORe CLI images ==="
	@echo "This will force rebuild all layers from scratch..."
	@echo ""
	@docker rmi ${ADORE_CLI_IMAGE} 2>/dev/null || true
	@docker rmi ${ADORE_CLI_CORE_IMAGE} 2>/dev/null || true  
	@docker rmi ${ADORE_CLI_BASE_IMAGE} 2>/dev/null || true
	@rm -f "${REQUIREMENTS_MANIFEST}" "${PACKAGES_MANIFEST}"
	@rm -f "${LAST_REQUIREMENTS_MANIFEST}" "${LAST_PACKAGES_MANIFEST}"
	@echo "Removed existing images and cache files"
	@echo "Starting complete rebuild..."
	@echo ""
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers_force

.PHONY: rebuild_from_layer
rebuild_from_layer: ## Rebuild from specific layer onwards. Usage: make rebuild_from_layer LAYER=base|core|user
	@if [ -z "$(LAYER)" ]; then \
	    echo "ERROR: LAYER parameter required"; \
	    echo "Usage: make rebuild_from_layer LAYER=base|core|user"; \
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
	@echo "Starting rebuild from $(LAYER) layer..."
	@echo ""
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_adore_cli_layers_force

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
	@if [ -f "${ADORE_CLI_TEMP_DIR}/build_vars" ]; then \
		source "${ADORE_CLI_TEMP_DIR}/build_vars" && \
		CORE_IMAGE_TO_CHECK="adore_cli_core:$$ACTUAL_CORE_TAG"; \
	else \
		CORE_IMAGE_TO_CHECK="${ADORE_CLI_CORE_IMAGE}"; \
	fi; \
	echo "Checking for core image: $$CORE_IMAGE_TO_CHECK"; \
	if ! docker image inspect "$$CORE_IMAGE_TO_CHECK" >/dev/null 2>&1; then \
	    echo "Core environment image not found locally: $$CORE_IMAGE_TO_CHECK"; \
	    echo "Attempting to pull from registry..."; \
	    ADORE_CLI_CORE_IMAGE="$$CORE_IMAGE_TO_CHECK" \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _try_pull_core; \
	    if ! docker image inspect "$$CORE_IMAGE_TO_CHECK" >/dev/null 2>&1; then \
	        cd ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core && make gather_requirements; \
	        echo "Building core environment layer locally: $$CORE_IMAGE_TO_CHECK"; \
	        ADORE_CLI_CORE_IMAGE="$$CORE_IMAGE_TO_CHECK" \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core_layer; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _save_manifests; \
	    fi; \
	else \
	    echo "✓ Core environment layer exists (using cache): $$CORE_IMAGE_TO_CHECK"; \
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
	@echo "  User: ${USER} (UID: ${UID}, GID: ${GID})"
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
	@echo "USER: ${USER} (UID: ${UID}, GID: ${GID})"
	@echo "ARCH: ${ARCH}"
	@echo "ROS_DISTRO: ${ROS_DISTRO}"
	@echo "=== Docker Images ==="
	@echo "Base Foundation: ${ADORE_CLI_BASE_IMAGE}"
	@echo "Core Environment: ${ADORE_CLI_CORE_IMAGE}"
	@echo "User Layer: ${ADORE_CLI_IMAGE}"
	@echo "Container Name: ${ADORE_CLI_CONTAINER_NAME}"
	@echo "=== Tag History ==="
	@LAST_USER_TAG=$$(SOURCE_DIRECTORY="${SOURCE_DIRECTORY}" bash "${TAG_HISTORY_SCRIPT}" get_last 2>/dev/null || echo "none"); \
	echo "Last successful environment: $$LAST_USER_TAG"

.PHONY: build_status
build_status: ## Show status of all build layers
	@echo "=== ADORe CLI Build Status ==="
	@printf "%-20s %-60s %s\n" "Layer" "Image" "Status"
	@printf "%-20s %-60s %s\n" "----" "----" "----"
	@# Use final tags if available, otherwise use defaults
	@if [ -f "${ADORE_CLI_TEMP_DIR}/final_tags" ]; then \
		source "${ADORE_CLI_TEMP_DIR}/final_tags" && \
		BASE_IMAGE="adore_cli_base:$$FINAL_BASE_TAG" && \
		CORE_IMAGE="adore_cli_core:$$FINAL_CORE_TAG" && \
		USER_IMAGE="adore_cli:$$FINAL_USER_TAG"; \
	else \
		BASE_IMAGE="${ADORE_CLI_BASE_IMAGE}" && \
		CORE_IMAGE="${ADORE_CLI_CORE_IMAGE}" && \
		USER_IMAGE="${ADORE_CLI_IMAGE}"; \
	fi; \
	if docker image inspect "$$BASE_IMAGE" >/dev/null 2>&1; then \
		printf "%-20s %-60s %s\n" "Base Foundation" "$$BASE_IMAGE" "✓ EXISTS"; \
	else \
		printf "%-20s %-60s %s\n" "Base Foundation" "$$BASE_IMAGE" "✗ MISSING"; \
	fi; \
	if docker image inspect "$$CORE_IMAGE" >/dev/null 2>&1; then \
		printf "%-20s %-60s %s\n" "Core Environment" "$$CORE_IMAGE" "✓ EXISTS"; \
	else \
		printf "%-20s %-60s %s\n" "Core Environment" "$$CORE_IMAGE" "✗ MISSING"; \
	fi; \
	if docker image inspect "$$USER_IMAGE" >/dev/null 2>&1; then \
		printf "%-20s %-60s %s\n" "User Layer" "$$USER_IMAGE" "✓ EXISTS"; \
	else \
		printf "%-20s %-60s %s\n" "User Layer" "$$USER_IMAGE" "✗ MISSING"; \
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
	@echo "Smart Environment Management:"
	@echo "  build              Build current calculated environment (always builds)"
	@echo "  cli                Start development environment (smart selection)"
	@echo "  run cmd=\"...\"       Execute command (non-interactive, always continues)"
	@echo ""
	@echo "Environment Status:"
	@echo "  build_status       Show status of all build layers"
	@echo "  adore_cli_info     Show current configuration and last environment"
	@echo ""
	@echo "Smart Features:"
	@echo "  - 'make cli' will prompt you when changes are detected"
	@echo "  - 'make run' always continues with existing environment"
	@echo "  - 'make build' always builds the current state"
	@echo ""
	@echo "Choices when prompted:"
	@echo "  [C] Continue - Keep using your current working environment"
	@echo "  [B] Build    - Build new environment with current changes"  
	@echo "  [A] Abort    - Cancel and exit"

.PHONY: debug_tags
debug_tags: _determine_actual_build_tags ## Debug tag calculation
	@echo "=== DEBUG: Tag Calculation ==="
	@echo "Raw variables:"
	@echo "  ARCH: '${ARCH}'"
	@echo "  ADORE_CLI_BRANCH: '${ADORE_CLI_BRANCH}'"
	@echo "  ADORE_CLI_SHORT_HASH: '${ADORE_CLI_SHORT_HASH}'"
	@echo "  PARENT_BRANCH: '${PARENT_BRANCH}'"
	@echo "  PARENT_SHORT_HASH: '${PARENT_SHORT_HASH}'"
	@echo "  REQUIREMENTS_SHORT_HASH: '${REQUIREMENTS_SHORT_HASH}'"
	@echo "  USER: '${USER}'"
	@echo "  UID: '${UID}'"
	@echo "  GID: '${GID}'"
	@echo ""
	@echo "Calculated default tags:"
	@echo "  Base: '${ADORE_CLI_BASE_TAG_DEFAULT}'"
	@echo "  Core: '${ADORE_CLI_CORE_TAG_DEFAULT}'"
	@echo "  User: '${ADORE_CLI_USER_TAG_DEFAULT}'"
	@echo ""
	@echo "Current runtime tags:"
	@echo "  Base: '${ADORE_CLI_BASE_TAG}'"
	@echo "  Core: '${ADORE_CLI_CORE_TAG}'"
	@echo "  User: '${ADORE_CLI_TAG}'"
	@echo ""
	@if [ -f "${ADORE_CLI_TEMP_DIR}/build_vars" ]; then \
		echo "Build vars file contents:"; \
		cat "${ADORE_CLI_TEMP_DIR}/build_vars"; \
	else \
		echo "No build_vars file found"; \
	fi
	@echo ""
	@if [ -f "${ADORE_CLI_TEMP_DIR}/final_tags" ]; then \
		echo "Final tags file contents:"; \
		cat "${ADORE_CLI_TEMP_DIR}/final_tags"; \
	else \
		echo "No final_tags file found"; \
	fi

endif
