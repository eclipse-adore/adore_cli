# This Makefile contains useful targets that can be included in downstream projects.

ifeq ($(filter adore_cli.mk, $(notdir $(MAKEFILE_LIST))), adore_cli.mk)

# === SHELL AND EXPORT CONFIGURATION ===
.EXPORT_ALL_VARIABLES:
SHELL:=/bin/bash
MAKEFLAGS += --no-print-directory
.NOTPARALLEL:


# === ROS AND OS CONFIGURATION ===
ROS_DISTRO:=jazzy
OS_CODE_NAME:=noble

# === PROJECT CONFIGURATION ===
ADORE_CLI_PROJECT:=adore_cli_core
ADORE_CLI_MAKEFILE_PATH:=$(shell realpath "$(shell dirname "$(lastword $(MAKEFILE_LIST))")")

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

# === GIT AND BRANCH CONFIGURATION ===
BRANCH:=$(shell cd ${ADORE_CLI_MAKEFILE_PATH} && bash ${MAKE_GADGETS_PATH}/tools/branch_name.sh 2>/dev/null || echo NOBRANCH)
SHORT_HASH:=$(shell cd ${ADORE_CLI_MAKEFILE_PATH} && git rev-parse --short HEAD 2>/dev/null || echo NOHASH)
PARENT_BRANCH?= $(shell bash $(MAKE_GADGETS_PATH)/tools/branch_name.sh 2>/dev/null || echo NOBRANCH)
PARENT_SHORT_HASH?=$(shell git rev-parse --short HEAD 2>/dev/null || echo NOHASH)
PARENT_TAG:=${PARENT_BRANCH}_${PARENT_SHORT_HASH}

# === DOCKER IMAGE AND CONTAINER CONFIGURATION ===
# Three-layer architecture with user-agnostic core
ADORE_CLI_SYSTEM_TAG:=${BRANCH}_${SHORT_HASH}_${ARCH}
ADORE_CLI_SYSTEM_IMAGE:=adore_cli_system:${ADORE_CLI_SYSTEM_TAG}

ADORE_CLI_CORE_TAG:=${BRANCH}_${SHORT_HASH}_${ARCH}
ADORE_CLI_CORE_IMAGE:=adore_cli_core:${ADORE_CLI_CORE_TAG}

ADORE_CLI_USER_TAG:=${BRANCH}_${SHORT_HASH}_${ARCH}_${USER}
ADORE_CLI_USER_IMAGE:=adore_cli_user:${ADORE_CLI_USER_TAG}

ADORE_CLI_TAG:=${ADORE_CLI_CORE_TAG}_${PARENT_TAG}_${USER}
ADORE_CLI_IMAGE:=adore_cli:${ADORE_CLI_TAG}
ADORE_CLI_CONTAINER_NAME:=adore_cli_${ADORE_CLI_TAG}

# === DIRECTORY CONFIGURATION ===
SOURCE_DIRECTORY?=${REPO_DIRECTORY}
ADORE_CLI_WORKING_DIRECTORY?=${REPO_DIRECTORY}
ADORE_DIRECTORY?=${REPO_DIRECTORY}
DOCKER_COMPOSE_FILE?=${ADORE_CLI_MAKEFILE_PATH}/docker-compose.yaml
REPO_DIRECTORY:=${ADORE_CLI_MAKEFILE_PATH}

# === USER CONFIGURATION ===
UID := $(shell id -u)
GID := $(shell id -g)
ADORE_TAG ?= $(ADORE_CLI_TAG)

# === TAG HISTORY CONFIGURATION ===
ADORE_CLI_TAG_HISTORY_FILE:=${SOURCE_DIRECTORY}/.log/adore_cli_tag_history
ADORE_CLI_TEMP_DIR:=${SOURCE_DIRECTORY}/.log/temp
ADORE_CLI_HISTORY_VARS:=${ADORE_CLI_TEMP_DIR}/adore_cli_history_vars
ADORE_CLI_CHOICE_VARS:=${ADORE_CLI_TEMP_DIR}/adore_cli_choice_vars
ADORE_CLI_EFFECTIVE_VARS:=${ADORE_CLI_TEMP_DIR}/adore_cli_effective_vars

# === INCLUDES ===
include ${MAKE_GADGETS_PATH}/make_gadgets.mk
include ${MAKE_GADGETS_PATH}/docker/docker-tools.mk

# === DIRECTORY INITIALIZATION ===
$(shell mkdir -p "${ADORE_CLI_MAKEFILE_PATH}/.ccache")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.zsh_history")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.bash_history")
$(shell mkdir -p "${SOURCE_DIRECTORY}/.log")
$(shell mkdir -p "${ADORE_CLI_TEMP_DIR}")

# === HELPER FUNCTIONS ===
define cleanup_temp_files
	@rm -f "${ADORE_CLI_HISTORY_VARS}" "${ADORE_CLI_CHOICE_VARS}" "${ADORE_CLI_EFFECTIVE_VARS}"
endef


.PHONY: help_cli
help_cli: ## Show ADORe CLI help 
	@echo "=== ADORe CLI Help ==="
	@echo "=== Main User Targets ==="
	@echo "  build              Build complete ADORe CLI environment (recommended)"
	@echo "  cli                Start/attach to ADORe CLI (auto-builds ADORe CLI if needed, does not build nodes, libraries or vendor libraries)"
	@echo "  clean              Clean all images and build artifacts"
	@echo "  test               Run test suite"
	@echo "  help_cli           Show this help message"
	@echo "  info               Show current configuration"
	@echo "  build_status       Show status of all build layers"
	@echo ""
	@echo "=== Registry Targets ==="
	@echo "  try_pull_base_images    Try to pull base and core images from registry"
	@echo "  push_base_images        Push base and core images to registry"
	@echo "  registry_status         Show registry status for base images"
	@echo "  cleanup_registry_images Cleanup old images in registry (ros2 branch only)"
	@echo ""
	@echo "=== Advanced Targets ==="
	@echo "  debug_run          Launch interactive bash shell in user image"
	@echo "  debug_run_root     Launch interactive bash shell as root"
	@echo "  rebuild_force      Force rebuild all layers (ignore existing images)"

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

# Target: check_cross_compile_deps
# Description: Validates cross-compilation dependencies and sets up buildx if needed
# - Checks for qemu-static and buildx builder
# - Installs dependencies if missing
# - Creates and configures cross-compilation builder
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

# === TAG HISTORY MANAGEMENT ===

# Target: _cli_read_history
# Description: Reads and parses the tag history file
# - Creates log directory if needed
# - Parses stored tag/container/image information
# - Writes parsed values to temp file for subsequent targets
# Target: _cli_read_history
.PHONY: _cli_read_history
_cli_read_history:
	@mkdir -p "${ADORE_CLI_TEMP_DIR}"
	@if [ -f "${ADORE_CLI_TAG_HISTORY_FILE}" ]; then \
	    LAST_INFO=$$(cat "${ADORE_CLI_TAG_HISTORY_FILE}" 2>/dev/null || echo ""); \
	    if [ -n "$$LAST_INFO" ]; then \
	        echo "LAST_TAG=$$(echo "$$LAST_INFO" | cut -d'|' -f1)" > "${ADORE_CLI_HISTORY_VARS}"; \
	        echo "LAST_CONTAINER_NAME=$$(echo "$$LAST_INFO" | cut -d'|' -f2)" >> "${ADORE_CLI_HISTORY_VARS}"; \
	        echo "LAST_IMAGE=$$(echo "$$LAST_INFO" | cut -d'|' -f3)" >> "${ADORE_CLI_HISTORY_VARS}"; \
	    else \
	        echo "LAST_TAG=" > "${ADORE_CLI_HISTORY_VARS}"; \
	        echo "LAST_CONTAINER_NAME=" >> "${ADORE_CLI_HISTORY_VARS}"; \
	        echo "LAST_IMAGE=" >> "${ADORE_CLI_HISTORY_VARS}"; \
	    fi; \
	else \
	    echo "LAST_TAG=" > "${ADORE_CLI_HISTORY_VARS}"; \
	    echo "LAST_CONTAINER_NAME=" >> "${ADORE_CLI_HISTORY_VARS}"; \
	    echo "LAST_IMAGE=" >> "${ADORE_CLI_HISTORY_VARS}"; \
	fi

.PHONY: _cli_save_history
_cli_save_history:
	@echo "${ADORE_CLI_TAG}|${ADORE_CLI_CONTAINER_NAME}|${ADORE_CLI_IMAGE}" > "${ADORE_CLI_TAG_HISTORY_FILE}"

# Target: _cli_check_tag_changes
# Description: Compares current tags with historical tags and checks container status
# - Determines if tag has changed since last run
# - Checks if previous container is still running
# - Sets flags for subsequent decision making
# - Displays warning messages to user about changes
.PHONY: _cli_check_tag_changes
_cli_check_tag_changes: _cli_read_history
	@source "${ADORE_CLI_HISTORY_VARS}"; \
	if [ -n "$$LAST_TAG" ] && [ "$$LAST_TAG" != "${ADORE_CLI_TAG}" ]; then \
	    echo "TAG_CHANGED=true" > "${ADORE_CLI_CHOICE_VARS}"; \
	    echo "Warning: ADORE_CLI tag has changed"; \
	    echo "  Previous: $$LAST_IMAGE"; \
	    echo "  Current:  ${ADORE_CLI_IMAGE}"; \
	    echo; \
	    if [[ "$$(docker inspect -f '{{.State.Running}}' "$$LAST_CONTAINER_NAME" 2>/dev/null)" == "true" ]]; then \
	        echo "Previous container is still running: $$LAST_CONTAINER_NAME"; \
	        echo "CONTAINER_RUNNING=true" >> "${ADORE_CLI_CHOICE_VARS}"; \
	    else \
	        echo "CONTAINER_RUNNING=false" >> "${ADORE_CLI_CHOICE_VARS}"; \
	    fi; \
	else \
	    echo "TAG_CHANGED=false" > "${ADORE_CLI_CHOICE_VARS}"; \
	    echo "CONTAINER_RUNNING=false" >> "${ADORE_CLI_CHOICE_VARS}"; \
	fi

# Target: _cli_prompt_user
# Description: Prompts user for action when tag changes are detected
# - Shows different prompts based on container running status
# - Handles rebuild, attach, and abort options
# - Stores user choice for subsequent processing
.PHONY: _cli_prompt_user
_cli_prompt_user:
	@source "${ADORE_CLI_CHOICE_VARS}"; \
	if [ "$$TAG_CHANGED" = "true" ]; then \
	    if [ "$$CONTAINER_RUNNING" = "true" ]; then \
	        read -p "Choose action: (r)ebuild with new tag, (a)ttach to old container, or (q)abort? [r/a/q]: " choice; \
	    else \
	        read -p "Choose action: (r)ebuild with new tag, (a)ttach with old tag, or (q)abort? [r/a/q]: " choice; \
	    fi; \
	    echo "USER_CHOICE=$$choice" >> "${ADORE_CLI_CHOICE_VARS}"; \
	else \
	    echo "USER_CHOICE=continue" >> "${ADORE_CLI_CHOICE_VARS}"; \
	fi

# Target: _cli_handle_choice
# Description: Processes user choice and determines effective container configuration
# - Handles attach to old container/tag scenarios
# - Manages rebuild with new tag scenarios
# - Handles abort scenarios with proper cleanup
# - Sets effective variables for container execution
.PHONY: _cli_handle_choice
_cli_handle_choice: _cli_prompt_user
	@source "${ADORE_CLI_CHOICE_VARS}"; \
	source "${ADORE_CLI_HISTORY_VARS}"; \
	case "$$USER_CHOICE" in \
	    a|A) \
	        if [ "$$CONTAINER_RUNNING" = "true" ]; then \
	            echo "Attaching to previous container: $$LAST_CONTAINER_NAME"; \
	        else \
	            echo "Using previous tag: $$LAST_TAG"; \
	        fi; \
	        echo "EFFECTIVE_TAG=$$LAST_TAG" > "${ADORE_CLI_EFFECTIVE_VARS}"; \
	        echo "EFFECTIVE_CONTAINER_NAME=$$LAST_CONTAINER_NAME" >> "${ADORE_CLI_EFFECTIVE_VARS}"; \
	        echo "EFFECTIVE_IMAGE=$$LAST_IMAGE" >> "${ADORE_CLI_EFFECTIVE_VARS}"; \
	        ;; \
	    q|Q) \
	        echo "Aborted by user"; \
	        $(call cleanup_temp_files); \
	        exit 1; \
	        ;; \
	    *) \
	        if [ "$$TAG_CHANGED" = "true" ]; then \
	            echo "Rebuilding with new tag: ${ADORE_CLI_TAG}"; \
	            make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _cli_save_history; \
	        fi; \
	        echo "EFFECTIVE_TAG=${ADORE_CLI_TAG}" > "${ADORE_CLI_EFFECTIVE_VARS}"; \
	        echo "EFFECTIVE_CONTAINER_NAME=${ADORE_CLI_CONTAINER_NAME}" >> "${ADORE_CLI_EFFECTIVE_VARS}"; \
	        echo "EFFECTIVE_IMAGE=${ADORE_CLI_IMAGE}" >> "${ADORE_CLI_EFFECTIVE_VARS}"; \
	        ;; \
	esac; \
	if [ "$$USER_CHOICE" = "continue" ]; then \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _cli_save_history; \
	    echo "EFFECTIVE_TAG=${ADORE_CLI_TAG}" > "${ADORE_CLI_EFFECTIVE_VARS}"; \
	    echo "EFFECTIVE_CONTAINER_NAME=${ADORE_CLI_CONTAINER_NAME}" >> "${ADORE_CLI_EFFECTIVE_VARS}"; \
	    echo "EFFECTIVE_IMAGE=${ADORE_CLI_IMAGE}" >> "${ADORE_CLI_EFFECTIVE_VARS}"; \
	fi

# Target: _cli_execute
# Description: Executes the final container action based on effective configuration
# - Checks if target container is already running
# - Either attaches to existing container or starts new one
# - Uses effective variables determined by choice handling
# - Cleans up all temporary files after execution
.PHONY: _cli_execute
_cli_execute:
	@source "${ADORE_CLI_EFFECTIVE_VARS}"; \
	if [[ "$$(docker inspect -f '{{.State.Running}}' "$$EFFECTIVE_CONTAINER_NAME" 2>/dev/null)" == "true" ]]; then \
	    echo "Attaching to existing container: $$EFFECTIVE_CONTAINER_NAME"; \
	    docker exec -it "$$EFFECTIVE_CONTAINER_NAME" /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh" || true; \
	else \
	    echo "Starting new container with tag: $$EFFECTIVE_TAG"; \
	    cd "${ADORE_CLI_MAKEFILE_PATH}" && \
	    ADORE_CLI_TAG="$$EFFECTIVE_TAG" \
	    ADORE_CLI_CONTAINER_NAME="$$EFFECTIVE_CONTAINER_NAME" \
	    ADORE_CLI_IMAGE="$$EFFECTIVE_IMAGE" \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_up; \
	fi; \
	rm -f "${ADORE_CLI_HISTORY_VARS}" "${ADORE_CLI_CHOICE_VARS}" "${ADORE_CLI_EFFECTIVE_VARS}"

# === MAIN CLI TARGET ===

# Target: cli
# Description: Main entry point for ADORe CLI container management
# - Implements intelligent tag tracking and container reuse
# - Prompts user when environment changes are detected
# - Handles attach/rebuild/abort scenarios gracefully
# - Maintains history for seamless development workflow
# - Auto-builds missing images if not already present in Docker registry
# Flow: cli -> _cli_execute -> adore_cli_up -> adore_cli_setup -> build_fast_adore_cli
.PHONY: cli 
cli: docker_host_context_check _cli_check_tag_changes _cli_handle_choice _cli_execute ## Start ADORe CLI docker context or attach to it if it is already running

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

# Target: _build_adore_cli_core  
# Description: Internal target - smart multi-layer core build
# - Checks for existing layers and builds only what's missing
# - Maintains proper build order: system -> core -> user
# - Uses efficient caching and incremental building
# - Called automatically by main build target
.PHONY: _build_adore_cli_core
_build_adore_cli_core: check_cross_compile_deps
	@echo "=== ADORe CLI Core Build Process ==="
	@echo "Building ADORe CLI core with user-agnostic layers..."
	@echo "Checking layer dependencies..."
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_system_base
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_core_environment  
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _check_and_build_user_layer
	@echo "=== Core build process complete ==="

.PHONY: _check_and_build_user_layer
_check_and_build_user_layer:
	@if ! docker image inspect ${ADORE_CLI_USER_IMAGE} >/dev/null 2>&1; then \
	    echo "Building user customization layer: ${ADORE_CLI_USER_IMAGE}"; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user_layer; \
	else \
	    echo "✓ User customization layer exists: ${ADORE_CLI_USER_IMAGE}"; \
	fi

# === INTERNAL BUILD TARGETS ===
# These targets exist for advanced use cases, CI/CD, and debugging

# Target: _build_system_base
# Description: Internal - builds system foundation layer only
.PHONY: _build_system_base
_build_system_base: check_cross_compile_deps
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    echo "Building system base (cross-compile): ${ADORE_CLI_SYSTEM_IMAGE}"; \
	    docker buildx build \
	        --builder=default \
	        --platform=$(DOCKER_PLATFORM) \
	        --target=system-base \
	        -t ${ADORE_CLI_SYSTEM_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${BRANCH} \
	        --build-arg SHORT_HASH=${SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/docker/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH} \
	        --load; \
	else \
	    echo "Building system base (native): ${ADORE_CLI_SYSTEM_IMAGE}"; \
	    docker build --network host \
	        --target=system-base \
	        -t ${ADORE_CLI_SYSTEM_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${BRANCH} \
	        --build-arg SHORT_HASH=${SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/docker/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH}; \
	fi

# Target: _build_core_environment
# Description: Internal - builds core ROS2 environment layer only
.PHONY: _build_core_environment  
_build_core_environment: check_cross_compile_deps
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    echo "Building core environment (cross-compile): ${ADORE_CLI_CORE_IMAGE}"; \
	    docker buildx build \
	        --builder=default \
	        --platform=$(DOCKER_PLATFORM) \
	        --target=adore_cli_core \
	        -t ${ADORE_CLI_CORE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${BRANCH} \
	        --build-arg SHORT_HASH=${SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/docker/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH} \
	        --load; \
	else \
	    echo "Building core environment (native): ${ADORE_CLI_CORE_IMAGE}"; \
	    docker build --network host \
	        --target=adore_cli_core \
	        -t ${ADORE_CLI_CORE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${BRANCH} \
	        --build-arg SHORT_HASH=${SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/docker/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH}; \
	fi

# Target: _build_user_layer
# Description: Internal - builds user customization layer only
.PHONY: _build_user_layer
_build_user_layer: check_cross_compile_deps
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    echo "Building user layer (cross-compile): ${ADORE_CLI_USER_IMAGE}"; \
	    docker buildx build \
	        --builder=default \
	        --platform=$(DOCKER_PLATFORM) \
	        --target=adore_cli_user \
	        -t ${ADORE_CLI_USER_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${BRANCH} \
	        --build-arg SHORT_HASH=${SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg USER=${USER} \
	        --build-arg UID=${UID} \
	        --build-arg GID=${GID} \
	        --build-arg HOSTNAME=${HOSTNAME:-ADORe-CLI} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/docker/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH} \
	        --load; \
	else \
	    echo "Building user layer (native): ${ADORE_CLI_USER_IMAGE}"; \
	    docker build --network host \
	        --target=adore_cli_user \
	        -t ${ADORE_CLI_USER_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg BRANCH=${BRANCH} \
	        --build-arg SHORT_HASH=${SHORT_HASH} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg USER=${USER} \
	        --build-arg UID=${UID} \
	        --build-arg GID=${GID} \
	        --build-arg HOSTNAME=${HOSTNAME:-ADORe-CLI} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/docker/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH}; \
	fi

# Target: build_fast_adore_cli
# Description: Fast conditional build - only builds if images are missing
# - Used by CLI target for automatic building
# - Checks all required images and builds missing ones
# - Optimized for speed - skips existing images
.PHONY: build_fast_adore_cli
build_fast_adore_cli:
	@echo "Checking required images..."
	@NEED_BUILD=false; \
	if ! docker image inspect ${ADORE_CLI_USER_IMAGE} >/dev/null 2>&1; then \
	    echo "User image missing: ${ADORE_CLI_USER_IMAGE}"; \
	    NEED_BUILD=true; \
	fi; \
	if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    echo "Runtime image missing: ${ADORE_CLI_IMAGE}"; \
	    NEED_BUILD=true; \
	fi; \
	if [ "$$NEED_BUILD" = "true" ]; then \
	    echo "Building missing images..."; \
	    cd "${ADORE_CLI_MAKEFILE_PATH}" && make build; \
	else \
	    echo "✓ All required images exist"; \
	fi

.PHONY: build_adore_cli_core
build_adore_cli_core: clean_adore_cli ## Builds the ADORe CLI core docker context/image
	@rm -f "${ADORE_CLI_TAG_HISTORY_FILE}"
	cd "${ADORE_CLI_MAKEFILE_PATH}" && make _build_adore_cli_core 

.PHONY: build_adore_cli
build_adore_cli: ## Builds the ADORe CLI runtime docker context/image
	@rm -f "${ADORE_CLI_TAG_HISTORY_FILE}"
	cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli" && make build 

.PHONY: clean_adore_cli 
clean_adore_cli: ## Clean adore_cli docker context 
	@rm -f "${ADORE_CLI_TAG_HISTORY_FILE}"
	$(call cleanup_temp_files)
	cd "${ADORE_CLI_MAKEFILE_PATH}" && make clean
	cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli" && make clean

# === ADVANCED BUILD TARGETS ===
# These targets are available for power users, CI/CD, and debugging

.PHONY: build_system_base
build_system_base: _build_system_base ## Advanced: Build system base layer only

.PHONY: build_core_environment  
build_core_environment: _build_core_environment ## Advanced: Build core environment layer only

.PHONY: build_user_layer
build_user_layer: _build_user_layer ## Advanced: Build user layer only

.PHONY: rebuild_force
rebuild_force: ## Advanced: Force rebuild all layers (ignore existing images)
	@echo "Force rebuilding all layers..."
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_system_base
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core_environment
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user_layer
	make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk build_adore_cli

.PHONY: rebuild_from_layer
rebuild_from_layer: ## Advanced: Rebuild from specific layer. Usage: make rebuild_from_layer LAYER=core
	@case "$(LAYER)" in \
	    system) \
	        echo "Rebuilding from system layer..."; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_system_base; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core_environment; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user_layer; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk build_adore_cli; \
	        ;; \
	    core) \
	        echo "Rebuilding from core layer..."; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core_environment; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user_layer; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk build_adore_cli; \
	        ;; \
	    user) \
	        echo "Rebuilding from user layer..."; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user_layer; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk build_adore_cli; \
	        ;; \
	    *) \
	        echo "Usage: make rebuild_from_layer LAYER=system|core|user"; \
	        exit 1; \
	        ;; \
	esac

# === SETUP AND TEARDOWN ===

# Target: adore_cli_setup  
# Description: Prepares the ADORe CLI environment for execution
# - Calls build_fast_adore_cli to ensure required images exist
# - Creates necessary directories (.log, .ccache)
# - Initializes shell history files for persistent command history
# - Called automatically by lifecycle targets before container operations
.PHONY: adore_cli_setup
adore_cli_setup: build_fast_adore_cli 
	@echo "Running adore_cli setup... SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.log
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
	echo ${ADORE_CLI_MAKEFILE_PATH}
	cd ${ADORE_CLI_MAKEFILE_PATH} && \
	docker compose  -f ${DOCKER_COMPOSE_FILE} up \
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
	@echo "${ADORE_CLI_USER_IMAGE}"

.PHONY: images_adore_cli
images_adore_cli: ## Returns all docker images for adore_cli
	@echo "${ADORE_CLI_SYSTEM_IMAGE}"
	@echo "${ADORE_CLI_CORE_IMAGE}"
	@echo "${ADORE_CLI_USER_IMAGE}"
	@echo "${ADORE_CLI_IMAGE}"

.PHONY: container_name_adore_cli
container_name_adore_cli: ## Returns the container name for the adore_cli
	@echo "${ADORE_CLI_CONTAINER_NAME}"

.PHONY: build_status
build_status: ## Show status of all build layers
	@echo "=== ADORe CLI Build Status ==="
	@printf "%-20s %-60s %s\n" "Layer" "Image" "Status"
	@printf "%-20s %-60s %s\n" "----" "----" "----"
	@if docker image inspect ${ADORE_CLI_SYSTEM_IMAGE} >/dev/null 2>&1; then \
	    printf "%-20s %-60s %s\n" "System Base" "${ADORE_CLI_SYSTEM_IMAGE}" "✓ EXISTS"; \
	else \
	    printf "%-20s %-60s %s\n" "System Base" "${ADORE_CLI_SYSTEM_IMAGE}" "✗ MISSING"; \
	fi
	@if docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
	    printf "%-20s %-60s %s\n" "Core Environment" "${ADORE_CLI_CORE_IMAGE}" "✓ EXISTS"; \
	else \
	    printf "%-20s %-60s %s\n" "Core Environment" "${ADORE_CLI_CORE_IMAGE}" "✗ MISSING"; \
	fi
	@if docker image inspect ${ADORE_CLI_USER_IMAGE} >/dev/null 2>&1; then \
	    printf "%-20s %-60s %s\n" "User Layer" "${ADORE_CLI_USER_IMAGE}" "✓ EXISTS"; \
	else \
	    printf "%-20s %-60s %s\n" "User Layer" "${ADORE_CLI_USER_IMAGE}" "✗ MISSING"; \
	fi
	@if docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    printf "%-20s %-60s %s\n" "Runtime" "${ADORE_CLI_IMAGE}" "✓ EXISTS"; \
	else \
	    printf "%-20s %-60s %s\n" "Runtime" "${ADORE_CLI_IMAGE}" "✗ MISSING"; \
	fi

# === REGISTRY INTEGRATION ===

# Target: registry_status
# Description: Shows status of base images in registry
# - Checks if system base and core environment images exist in GitHub Container Registry
# - Handles both CI environments (with GITHUB_REPOSITORY) and local development
# - Provides helpful error messages when repository information is not available
# - Uses docker manifest inspect to check image existence without downloading
.PHONY: registry_status
registry_status:
	@echo "=== Registry Status ==="
	@# Handle local vs CI environment
	@if [ -n "${GITHUB_REPOSITORY}" ]; then \
	    GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	elif [ -n "${GITHUB_REPOSITORY_OWNER}" ]; then \
	    GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY_OWNER}/adore_develop" | tr '[:upper:]' '[:lower:]'); \
	else \
	    echo "No GitHub repository information available."; \
	    echo "Registry status only works in CI environment or when GITHUB_REPOSITORY is set."; \
	    echo ""; \
	    echo "To test locally, set environment variable:"; \
	    echo "  export GITHUB_REPOSITORY=your-org/your-repo"; \
	    echo "  make registry_status"; \
	    exit 0; \
	fi; \
	REGISTRY_PREFIX="ghcr.io/$${GITHUB_REPO}/"; \
	echo "Registry: $${REGISTRY_PREFIX}"; \
	echo "Checking system base: $${REGISTRY_PREFIX}${ADORE_CLI_SYSTEM_IMAGE}"; \
	if docker manifest inspect "$${REGISTRY_PREFIX}${ADORE_CLI_SYSTEM_IMAGE}" >/dev/null 2>&1; then \
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

# Target: try_pull_base_images
# Description: Attempts to pull base and core images from GitHub Container Registry
# - Tries to pull system base and core environment images from registry before building locally
# - Significantly speeds up builds when images are available in registry
# - Falls back gracefully when registry images are not available
# - Handles environment detection for both CI and local development
# - Tags pulled images with local names for use by build system
.PHONY: try_pull_base_images
try_pull_base_images:
	@echo "=== Attempting to pull base images from registry ==="
	@# Determine GitHub repository
	@if [ -n "${GITHUB_REPOSITORY}" ]; then \
	    GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	elif [ -n "${GITHUB_REPOSITORY_OWNER}" ]; then \
	    GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY_OWNER}/adore_develop" | tr '[:upper:]' '[:lower:]'); \
	else \
	    echo "No GitHub repository configured - skipping registry pull"; \
	    echo "Set GITHUB_REPOSITORY environment variable to enable registry features"; \
	    exit 0; \
	fi; \
	REGISTRY_PREFIX="ghcr.io/$${GITHUB_REPO}/"; \
	echo "Registry prefix: $${REGISTRY_PREFIX}"; \
	echo "Trying to pull system base: $${REGISTRY_PREFIX}${ADORE_CLI_SYSTEM_IMAGE}"; \
	if docker pull "$${REGISTRY_PREFIX}${ADORE_CLI_SYSTEM_IMAGE}" 2>/dev/null; then \
	    echo "✓ Pulled system base from registry"; \
	    docker tag "$${REGISTRY_PREFIX}${ADORE_CLI_SYSTEM_IMAGE}" "${ADORE_CLI_SYSTEM_IMAGE}"; \
	else \
	    echo "✗ System base not found in registry"; \
	fi; \
	echo "Trying to pull core environment: $${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}"; \
	if docker pull "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}" 2>/dev/null; then \
	    echo "✓ Pulled core environment from registry"; \
	    docker tag "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}" "${ADORE_CLI_CORE_IMAGE}"; \
	else \
	    echo "✗ Core environment not found in registry"; \
	fi

# Target: push_base_images
# Description: Pushes base and core images to GitHub Container Registry
# - Pushes only user-agnostic images (system base and core environment)
# - Tags images with proper registry prefix for GitHub Container Registry
# - Skips user-specific images to avoid bloating registry storage
# - Requires proper authentication and write permissions to registry
# - Used primarily in CI/CD pipelines to share base layers across builds
.PHONY: push_base_images
push_base_images:
	@echo "=== Pushing base and core images to registry ==="
	@# Determine GitHub repository
	@if [ -n "${GITHUB_REPOSITORY}" ]; then \
	    GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY}" | tr '[:upper:]' '[:lower:]'); \
	elif [ -n "${GITHUB_REPOSITORY_OWNER}" ]; then \
	    GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY_OWNER}/adore_develop" | tr '[:upper:]' '[:lower:]'); \
	else \
	    echo "No GitHub repository configured - cannot push to registry"; \
	    echo "Set GITHUB_REPOSITORY environment variable to enable registry push"; \
	    exit 1; \
	fi; \
	REGISTRY_PREFIX="ghcr.io/$${GITHUB_REPO}/"; \
	echo "Registry prefix: $${REGISTRY_PREFIX}"; \
	if docker image inspect "${ADORE_CLI_SYSTEM_IMAGE}" >/dev/null 2>&1; then \
	    echo "Tagging and pushing system base: ${ADORE_CLI_SYSTEM_IMAGE}"; \
	    docker tag "${ADORE_CLI_SYSTEM_IMAGE}" "$${REGISTRY_PREFIX}${ADORE_CLI_SYSTEM_IMAGE}"; \
	    docker push "$${REGISTRY_PREFIX}${ADORE_CLI_SYSTEM_IMAGE}"; \
	    echo "✓ Pushed system base"; \
	else \
	    echo "✗ System base image not found locally"; \
	fi; \
	if docker image inspect "${ADORE_CLI_CORE_IMAGE}" >/dev/null 2>&1; then \
	    echo "Tagging and pushing core environment: ${ADORE_CLI_CORE_IMAGE}"; \
	    docker tag "${ADORE_CLI_CORE_IMAGE}" "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}"; \
	    docker push "$${REGISTRY_PREFIX}${ADORE_CLI_CORE_IMAGE}"; \
	    echo "✓ Pushed core environment"; \
	else \
	    echo "✗ Core environment image not found locally"; \
	fi

# Target: cleanup_registry_images
# Description: Cleans up old images in registry, keeping last 2 commits for ros2 branch
# - Gets last 2 commits from ros2 branch for retention policy
# - Identifies images to keep based on commit hashes in image tags
# - Only runs on ros2 branch to avoid affecting development branches
# - Prevents registry storage bloat by removing outdated base images
# - Currently logs cleanup actions - actual deletion requires GitHub API integration
.PHONY: cleanup_registry_images
cleanup_registry_images:
	@echo "=== Cleaning up old registry images ==="
	@if [ "$$(git branch --show-current 2>/dev/null || echo ${GITHUB_REF##*/})" != "ros2" ] && [ "${GITHUB_REF}" != "refs/heads/ros2" ]; then \
	    echo "Skipping cleanup - not on ros2 branch"; \
	    exit 0; \
	fi; \
	GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY:-local/adore_cli}" | tr '[:upper:]' '[:lower:]'); \
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

# Updated build targets to use registry
.PHONY: _check_and_build_system_base
_check_and_build_system_base:
	@if ! docker image inspect ${ADORE_CLI_SYSTEM_IMAGE} >/dev/null 2>&1; then \
	    echo "System base image not found locally: ${ADORE_CLI_SYSTEM_IMAGE}"; \
	    echo "Attempting to pull from registry..."; \
	    if ! make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _try_pull_system_base; then \
	        echo "Building system base layer locally: ${ADORE_CLI_SYSTEM_IMAGE}"; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_system_base; \
	    fi; \
	else \
	    echo "✓ System base layer exists: ${ADORE_CLI_SYSTEM_IMAGE}"; \
	fi

.PHONY: _check_and_build_core_environment
_check_and_build_core_environment:
	@if ! docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
	    echo "Core environment image not found locally: ${ADORE_CLI_CORE_IMAGE}"; \
	    echo "Attempting to pull from registry..."; \
	    if ! make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _try_pull_core_environment; then \
	        echo "Building core environment layer locally: ${ADORE_CLI_CORE_IMAGE}"; \
	        $(MAKE) --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core_environment; \
	    fi; \
	else \
	    echo "✓ Core environment layer exists: ${ADORE_CLI_CORE_IMAGE}"; \
	fi

# Helper targets for individual image pulling
.PHONY: _try_pull_system_base
_try_pull_system_base:
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY:-local/adore_cli}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_IMAGE="ghcr.io/$${GITHUB_REPO}/${ADORE_CLI_SYSTEM_IMAGE}"; \
	if docker pull "$$REGISTRY_IMAGE" 2>/dev/null; then \
	    docker tag "$$REGISTRY_IMAGE" "${ADORE_CLI_SYSTEM_IMAGE}"; \
	    echo "✓ Pulled system base from registry"; \
	    exit 0; \
	else \
	    echo "✗ System base not available in registry"; \
	    exit 1; \
	fi

.PHONY: _try_pull_core_environment
_try_pull_core_environment:
	@GITHUB_REPO=$$(echo "${GITHUB_REPOSITORY:-local/adore_cli}" | tr '[:upper:]' '[:lower:]'); \
	REGISTRY_IMAGE="ghcr.io/$${GITHUB_REPO}/${ADORE_CLI_CORE_IMAGE}"; \
	if docker pull "$$REGISTRY_IMAGE" 2>/dev/null; then \
	    docker tag "$$REGISTRY_IMAGE" "${ADORE_CLI_CORE_IMAGE}"; \
	    echo "✓ Pulled core environment from registry"; \
	    exit 0; \
	else \
	    echo "✗ Core environment not available in registry"; \
	    exit 1; \
	fi

endif
