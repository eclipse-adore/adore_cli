ifeq ($(filter adore_cli.mk, $(notdir $(MAKEFILE_LIST))), adore_cli.mk)

SHELL     := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.NOTPARALLEL:
cmd ?=

ADORE_CLI_MAKEFILE_PATH := $(shell dirname "$(realpath $(lastword $(MAKEFILE_LIST)))")

ROOT_DIR           ?= ${ADORE_CLI_MAKEFILE_PATH}
SOURCE_DIRECTORY   ?= ${ADORE_CLI_MAKEFILE_PATH}
VENDOR_PATH        ?= ${SOURCE_DIRECTORY}/vendor
ADORE_CLI_LOG_DIR  ?= ${SOURCE_DIRECTORY}/.log/.adore_cli
ADORE_CLI_LOG_DIRECTORY := ${ADORE_CLI_LOG_DIR}
ADORE_CLI_ACTIVE_CONTAINER_FILE := ${ADORE_CLI_LOG_DIR}/active_container

PARENT_IS_ADORE_CLI := $(shell [ "${SOURCE_DIRECTORY}" = "${ADORE_CLI_MAKEFILE_PATH}" ] && echo "true" || echo "false")

ADORE_CLI_REPO := $(shell cd "${ADORE_CLI_MAKEFILE_PATH}" && git config --get remote.origin.url 2>/dev/null | sed -e 's|.*github.com[:/]||' -e 's|\.git$$||' | tr '[:upper:]' '[:lower:]')
ifeq ($(ADORE_CLI_REPO),)
    ADORE_CLI_REPO := eclipse-adore/adore_cli
endif

ifeq ($(PARENT_IS_ADORE_CLI),true)
    PARENT_REPO := $(ADORE_CLI_REPO)
else
    PARENT_REPO := $(shell git config --get remote.origin.url 2>/dev/null | sed -e 's|.*github.com[:/]||' -e 's|\.git$$||' | tr '[:upper:]' '[:lower:]')
    ifeq ($(PARENT_REPO),)
        PARENT_REPO := $(shell git rev-parse --show-superproject-working-tree 2>/dev/null | xargs -I {} git -C {} config --get remote.origin.url 2>/dev/null | sed -e 's|.*github.com[:/]||' -e 's|\.git$$||' | tr '[:upper:]' '[:lower:]')
    endif
endif

.EXPORT_ALL_VARIABLES:

DOCKER_BUILDKIT  ?= 1
DOCKER_CONFIG    ?=
ROS_DISTRO       ?= jazzy
OS_CODE_NAME     ?= noble
HOSTNAME         ?= ADORe-CLI
GITHUB_REPOSITORY ?= eclipse-adore/adore_cli
MINIMUM_DOCKER_VERSION := 28

MAKE_GADGETS_PATH := ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets
ifeq ($(wildcard $(MAKE_GADGETS_PATH)/*),)
    $(info INFO: To clone submodules run: git submodule update --init --recursive)
    $(error ERROR: ${MAKE_GADGETS_PATH} does not exist)
endif

ARCH            ?= $(shell uname -m)
DOCKER_PLATFORM ?= linux/$(ARCH)
CROSS_COMPILE   ?= $(shell [ "$(shell uname -m)" != "$(ARCH)" ] && echo "true" || echo "false")

# adore_cli repo identity
ADORE_CLI_BRANCH     := $(shell cd ${ADORE_CLI_MAKEFILE_PATH} && bash ${MAKE_GADGETS_PATH}/tools/branch_name.sh 2>/dev/null || echo NOBRANCH)
ADORE_CLI_SHORT_HASH := $(shell cd ${ADORE_CLI_MAKEFILE_PATH} && git rev-parse --short HEAD 2>/dev/null || echo NOHASH)
ADORE_CLI_IS_DIRTY   := $(shell cd ${ADORE_CLI_MAKEFILE_PATH} && git status --porcelain 2>/dev/null | grep -q . && echo "true" || echo "false")

# Parent repo identity
PARENT_REPO := $(shell git config --get remote.origin.url 2>/dev/null | sed -e 's|.*github.com[:/]||' -e 's|\.git$$||' | tr '[:upper:]' '[:lower:]')
ifeq ($(PARENT_REPO),)
    PARENT_REPO := $(shell git rev-parse --show-superproject-working-tree 2>/dev/null | xargs -I {} git -C {} config --get remote.origin.url 2>/dev/null | sed -e 's|.*github.com[:/]||' -e 's|\.git$$||' | tr '[:upper:]' '[:lower:]')
endif

# Content hashes
REQUIREMENTS_HASH := $(shell bash ${ADORE_CLI_MAKEFILE_PATH}/tools/requirements_hashing_util.sh hash "${SOURCE_DIRECTORY}" 2>/dev/null | cut -c1-7)
PACKAGES_HASH     := $(shell find "${VENDOR_PATH}/build" -type f -name "*.deb" 2>/dev/null | sort | xargs -r -I{} basename {} | sort | sha256sum 2>/dev/null | cut -c1-7 || echo "0000000")

USER_UID := $(shell id -u)
USER_GID := $(shell id -g)
UID      ?= $(USER_UID)
GID      ?= $(USER_GID)

DISPLAY ?=

# Detect whether the host has an accessible X display to forward into the container.
# Checks (in order): VIRTUAL_DISPLAY=true in env forces virtual; xhost present + DISPLAY set
# + X11 socket exists enables forwarding.  When forwarding is not possible the variable is
# left empty — entrypoint.sh detects the situation independently and starts Xvfb itself.
# This avoids passing VIRTUAL_DISPLAY=true as a docker -e arg, which would be clobbered by
# the set -a / VIRTUAL_DISPLAY=false in adore_cli.env when the env file is sourced inside
# the container.
_HOST_DISPLAY_NUM := $(shell printf '%s' '$(DISPLAY)' | sed 's/.*://' | cut -d. -f1)
_HOST_X11_SOCKET  := /tmp/.X11-unix/X$(_HOST_DISPLAY_NUM)

_FORWARD_DISPLAY := $(shell \
    source "$(ADORE_CLI_MAKEFILE_PATH)/adore_cli.env" 2>/dev/null; \
    if [ "$${VIRTUAL_DISPLAY:-false}" = "true" ]; then echo false; \
    elif command -v xhost >/dev/null 2>&1 \
        && [ -n "$(DISPLAY)" ] \
        && [ -S "$(_HOST_X11_SOCKET)" ]; then echo true; \
    else echo false; fi)

DISPLAY_DOCKER_ARG := $(if $(filter true,$(_FORWARD_DISPLAY)),-e DISPLAY=$(DISPLAY),)
X11_UNIX_MOUNT     := $(if $(filter true,$(_FORWARD_DISPLAY)),$(if $(wildcard /tmp/.X11-unix),-v /tmp/.X11-unix:/tmp/.X11-unix,),)

# === IMAGE TAGS ===
# core:  tied to the adore_cli commit (changes when ROS layer or core packages change)
# base:  tied to adore_cli commit (changes when dev tools change)
# user:  portable across parent branches — arch + adore_cli commit + requirements + packages
ADORE_CLI_CORE_TAG := ${ARCH}_${ADORE_CLI_SHORT_HASH}
ADORE_CLI_BASE_TAG := ${ARCH}_${ADORE_CLI_SHORT_HASH}

#ifeq ($(ADORE_CLI_IS_DIRTY),true)
#    ADORE_CLI_USER_TAG_DIRTY_SUFFIX := _dirty
#else
ADORE_CLI_USER_TAG_DIRTY_SUFFIX :=
#endif

ADORE_CLI_USER_TAG := ${ARCH}_${ADORE_CLI_SHORT_HASH}_RH${REQUIREMENTS_HASH}_PH${PACKAGES_HASH}${ADORE_CLI_USER_TAG_DIRTY_SUFFIX}

ADORE_CLI_CORE_IMAGE     := adore_cli_core:${ADORE_CLI_CORE_TAG}
ADORE_CLI_BASE_IMAGE     := adore_cli_base:${ADORE_CLI_BASE_TAG}
ADORE_CLI_IMAGE          := adore_cli:${ADORE_CLI_USER_TAG}
SOURCE_DIRECTORY_HASH    := $(shell printf '%s' '${SOURCE_DIRECTORY}' | sha256sum | cut -c1-7)
ADORE_CLI_CONTAINER_NAME := adore_cli_${ADORE_CLI_USER_TAG}_$(shell whoami)_${SOURCE_DIRECTORY_HASH}
ADORE_CLI_WORKING_DIRECTORY ?= ${SOURCE_DIRECTORY}

ADORE_TAG  ?= $(ADORE_CLI_USER_TAG)
ADORE_CLI_TAG := $(ADORE_CLI_USER_TAG)

include ${MAKE_GADGETS_PATH}/make_gadgets.mk
include ${MAKE_GADGETS_PATH}/docker/docker-tools.mk

$(shell mkdir -p "${ADORE_CLI_MAKEFILE_PATH}/.ccache")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.zsh_history")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.zshrc")
$(shell touch "${ADORE_CLI_MAKEFILE_PATH}/.bash_history")
$(shell mkdir -p "${ADORE_CLI_LOG_DIR}")

# === CHANGE TRACKING ===


# === DOCKER CHECKS ===
.PHONY: check_docker_version
check_docker_version:
	@docker_version=$$(docker version --format '{{.Server.Version}}' 2>/dev/null | cut -d'.' -f1); \
	[ -z "$$docker_version" ] && echo "Error: Docker not running" && exit 1; \
	[ "$$docker_version" -lt ${MINIMUM_DOCKER_VERSION} ] && \
	    echo "Error: Docker ${MINIMUM_DOCKER_VERSION}+ required, found $$docker_version" && exit 1; \
	true

.PHONY: check_cross_compile_deps
check_cross_compile_deps: check_docker_version
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    if ! which qemu-$(ARCH)-static >/dev/null 2>&1 || ! docker buildx inspect $(ARCH)builder >/dev/null 2>&1; then \
	        sudo apt-get update && sudo apt-get install -y qemu-user-static binfmt-support; \
	        docker run --privileged --rm tonistiigi/binfmt --install $(ARCH); \
	        docker buildx inspect $(ARCH)builder >/dev/null 2>&1 || \
	            docker buildx create --name $(ARCH)builder --driver docker-container --use; \
	    fi; \
	fi

.PHONY: _build_core
_build_core: check_cross_compile_deps
	@echo "Building core: ${ADORE_CLI_CORE_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    docker buildx build --builder=default --platform=$(DOCKER_PLATFORM) --load \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        -t ${ADORE_CLI_CORE_IMAGE} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core; \
	else \
	    docker build --network host \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        -t ${ADORE_CLI_CORE_IMAGE} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core/Dockerfile.adore_cli_core \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core; \
	fi

.PHONY: _build_base
_build_base: check_cross_compile_deps
	@echo "Building base: ${ADORE_CLI_BASE_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    docker buildx build --builder=default --platform=$(DOCKER_PLATFORM) --load \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
	        -t ${ADORE_CLI_BASE_IMAGE} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base/Dockerfile.adore_cli_base \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base; \
	else \
	    docker build --network host \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg OS_CODE_NAME=${OS_CODE_NAME} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
	        -t ${ADORE_CLI_BASE_IMAGE} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base/Dockerfile.adore_cli_base \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base; \
	fi

.PHONY: _gather
_gather:
	@cd ${ADORE_CLI_MAKEFILE_PATH}/adore_cli && make gather

.PHONY: _build_user
_build_user: check_cross_compile_deps _gather
	@echo "Building user: ${ADORE_CLI_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
	    docker buildx build --builder=default --platform=$(DOCKER_PLATFORM) --load \
	        --build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        -t ${ADORE_CLI_IMAGE} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli/Dockerfile.adore_cli \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli; \
	else \
	    docker build --network host \
	        --build-arg ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
	        --build-arg ROS_DISTRO=${ROS_DISTRO} \
	        --build-arg ARCH=${ARCH} \
	        --build-arg BRANCH=${ADORE_CLI_BRANCH} \
	        --build-arg SHORT_HASH=${ADORE_CLI_SHORT_HASH} \
	        -t ${ADORE_CLI_IMAGE} \
	        -f ${ADORE_CLI_MAKEFILE_PATH}/adore_cli/Dockerfile.adore_cli \
	        ${ADORE_CLI_MAKEFILE_PATH}/adore_cli; \
	fi

.PHONY: _ensure_core
_ensure_core:
	@if ! docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1; then \
	    echo "Core image missing, attempting registry pull..."; \
	    docker pull "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_CORE_IMAGE}" 2>/dev/null && \
	        docker tag "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_CORE_IMAGE}" "${ADORE_CLI_CORE_IMAGE}" || \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core; \
	else echo "✓ Core: ${ADORE_CLI_CORE_IMAGE}"; fi

.PHONY: _ensure_base
_ensure_base: _ensure_core
	@if ! docker image inspect ${ADORE_CLI_BASE_IMAGE} >/dev/null 2>&1; then \
	    echo "Base image missing, attempting registry pull..."; \
	    docker pull "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_BASE_IMAGE}" 2>/dev/null && \
	        docker tag "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_BASE_IMAGE}" "${ADORE_CLI_BASE_IMAGE}" || \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_base; \
	else echo "✓ Base: ${ADORE_CLI_BASE_IMAGE}"; fi

.PHONY: _ensure_user
_ensure_user: _ensure_base
	@if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    echo "User image missing, attempting registry pull..."; \
	    ( docker pull "ghcr.io/${PARENT_REPO}/${ADORE_CLI_IMAGE}" 2>/dev/null && \
	        docker tag "ghcr.io/${PARENT_REPO}/${ADORE_CLI_IMAGE}" "${ADORE_CLI_IMAGE}" ) || \
	    ( docker pull "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_IMAGE}" 2>/dev/null && \
	        docker tag "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_IMAGE}" "${ADORE_CLI_IMAGE}" ) || \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user; \
	else echo "✓ User: ${ADORE_CLI_IMAGE}"; fi

# === MAIN TARGETS ===
.PHONY: cli
cli: docker_host_context_check _cli_attach ## Start or attach to ADORe CLI

.PHONY: _cli_attach
_cli_attach:
	@ACTIVE_CONTAINER=$$(cat "${ADORE_CLI_ACTIVE_CONTAINER_FILE}" 2>/dev/null || echo ""); \
	if [ -n "$$ACTIVE_CONTAINER" ] && docker ps --format "{{.Names}}" 2>/dev/null | grep -q "^$$ACTIVE_CONTAINER$$"; then \
	    ACTIVE_TAG=$$(echo "$$ACTIVE_CONTAINER" | sed 's/^adore_cli_//; s/_$(shell whoami)$$//'); \
	    echo "✓ Attaching to active session: $$ACTIVE_CONTAINER"; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action \
	        ADORE_CLI_USER_TAG="$$ACTIVE_TAG" \
	        ADORE_CLI_IMAGE="adore_cli:$$ACTIVE_TAG" \
	        ADORE_CLI_CONTAINER_NAME="$$ACTIVE_CONTAINER"; \
	else \
	    LAST_TAG=$$(bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" get_last 2>/dev/null || echo ""); \
	    CURRENT_TAG="${ADORE_CLI_USER_TAG}"; \
	    IMAGE_EXISTS=$$(docker image inspect "adore_cli:$$CURRENT_TAG" >/dev/null 2>&1 && echo "true" || echo "false"); \
	    if [ "$$IMAGE_EXISTS" = "true" ]; then \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _execute_environment_action; \
	    else \
	        bash "${ADORE_CLI_MAKEFILE_PATH}/tools/cli_prompt.sh" "$$LAST_TAG" "$$CURRENT_TAG" "${ADORE_CLI_MAKEFILE_PATH}"; \
	    fi; \
	fi

.PHONY: _execute_environment_action
_execute_environment_action:
	@if docker ps --format "{{.Names}}" | grep -q "^${ADORE_CLI_CONTAINER_NAME}$$"; then \
	    echo "✓ Attaching to running container: ${ADORE_CLI_CONTAINER_NAME}"; \
	elif docker ps -a --format "{{.Names}}" | grep -q "^${ADORE_CLI_CONTAINER_NAME}$$"; then \
	    echo "Restarting stopped container: ${ADORE_CLI_CONTAINER_NAME}"; \
	    docker start ${ADORE_CLI_CONTAINER_NAME}; \
	else \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_setup; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_start; \
	fi
	@echo "${ADORE_CLI_CONTAINER_NAME}" > "${ADORE_CLI_ACTIVE_CONTAINER_FILE}"
	@echo "Type 'exit' to detach  |  'make stop' to stop the container"
	@echo "Waiting for container user to be ready..."
	@timeout 15 bash -c \
	    'until docker exec ${ADORE_CLI_CONTAINER_NAME} id ${USER} >/dev/null 2>&1; do sleep 0.5; done'
	@timeout 15 bash -c \
	    'until docker exec ${ADORE_CLI_CONTAINER_NAME} id ${USER} >/dev/null 2>&1; do sleep 0.5; done'
	@docker exec -it \
	    --user ${USER_UID}:${USER_GID} \
	    -e HOME=/home/${USER} \
	    -e HISTFILE=/tmp/adore_cli/.zsh_history \
	    -e SOURCE_DIRECTORY=${SOURCE_DIRECTORY} \
	    -e ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} \
	    -e ADORE_CLI_IMAGE=${ADORE_CLI_IMAGE} \
	    -e ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
	    -e ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
	    -e ADORE_CLI_CONTAINER_NAME=${ADORE_CLI_CONTAINER_NAME} \
	    -e ROS_DISTRO=${ROS_DISTRO} \
	    ${ADORE_CLI_CONTAINER_NAME} \
	    /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh" || true
	@echo "Detached. Container still running. Use 'make cli' to reattach or 'make stop' to stop."

.PHONY: start
start: adore_cli_setup adore_cli_start ## Start the ADORe CLI container

.PHONY: stop
stop: stop_adore_cli ## Stop the ADORe CLI container

.PHONY: stop_adore_cli
stop_adore_cli: docker_host_context_check adore_cli_teardown ## Stop the ADORe CLI container

.PHONY: restart
restart: stop start ## Restart the ADORe CLI container

.PHONY: run
run: adore_cli_setup ## Run a command: make run cmd="<command>"
	@if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _ensure_user; \
	fi
	@RUNNING=$$(docker ps --filter "name=^${ADORE_CLI_CONTAINER_NAME}$$" --format "{{.Names}}"); \
	if [ -z "$$RUNNING" ]; then \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_start; \
	    docker exec --workdir /tmp/adore \
	        --user ${USER_UID}:${USER_GID} \
	        -e HOME=/home/${USER} \
	        -e HISTFILE=/tmp/adore_cli/.zsh_history \
	        ${ADORE_CLI_CONTAINER_NAME} \
	        env DOCKER_EXEC_NON_INTERACTIVE=1 zsh -c "source ~/.zshrc && $(cmd)"; \
	    make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk adore_cli_teardown; \
	else \
	    docker exec --workdir /tmp/adore \
	        --user ${USER_UID}:${USER_GID} \
	        -e HOME=/home/${USER} \
	        -e HISTFILE=/tmp/adore_cli/.zsh_history \
	        ${ADORE_CLI_CONTAINER_NAME} \
	        env DOCKER_EXEC_NON_INTERACTIVE=1 zsh -c "source ~/.zshrc && $(cmd)"; \
	fi

# === BUILD TARGETS ===
.PHONY: build_adore_cli
build_adore_cli: check_cross_compile_deps ## Build all three layers
	@echo "=== Building ADORe CLI ==="
	@echo ""
	@echo "  ros:${ROS_DISTRO}-ros-core-${OS_CODE_NAME}"
	@echo "    └── adore_cli_core  (bare ROS2 + rosbridge/zenoh)  : ${ADORE_CLI_CORE_IMAGE}"
	@echo "          └── adore_cli_base  (dev tools, x11, tracing, zsh, ccache)  : ${ADORE_CLI_BASE_IMAGE}"
	@echo "                └── adore_cli  (application .debs, runtime user)  : ${ADORE_CLI_IMAGE}"
	@echo ""
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _ensure_user || { echo "✗ Build failed"; exit 1; }
	@bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save \
	    "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_USER_TAG}" 2>/dev/null || true
	@echo "=== Build complete: ${ADORE_CLI_IMAGE} ==="

.PHONY: rebuild_force
rebuild_force: ## Force rebuild all layers from scratch
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk rebuild_from_layer LAYER=core

.PHONY: rebuild_from_layer
rebuild_from_layer: check_cross_compile_deps ## Rebuild from LAYER=core|base|user (no registry pull)
	@case "$(LAYER)" in \
	    core) \
	        docker rmi ${ADORE_CLI_IMAGE} ${ADORE_CLI_BASE_IMAGE} ${ADORE_CLI_CORE_IMAGE} 2>/dev/null || true; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_core _build_base _build_user ;; \
	    base) \
	        docker rmi ${ADORE_CLI_IMAGE} ${ADORE_CLI_BASE_IMAGE} 2>/dev/null || true; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_base _build_user ;; \
	    user) \
	        docker rmi ${ADORE_CLI_IMAGE} 2>/dev/null || true; \
	        make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user ;; \
	    *) echo "ERROR: LAYER must be core, base, or user"; exit 1 ;; \
	esac
	@bash "${ADORE_CLI_MAKEFILE_PATH}/tools/tag_history_manager.sh" save \
	    "${ADORE_CLI_CORE_TAG}" "${ADORE_CLI_BASE_TAG}" "${ADORE_CLI_USER_TAG}" 2>/dev/null || true

# === REGISTRY ===
.PHONY: clean_adore_cli
clean_adore_cli: ## Remove all adore_cli images and build artifacts
	@docker rmi ${ADORE_CLI_IMAGE}      2>/dev/null || true
	@docker rmi ${ADORE_CLI_BASE_IMAGE} 2>/dev/null || true
	@docker rmi ${ADORE_CLI_CORE_IMAGE} 2>/dev/null || true
	@cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli_core" && make clean
	@cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base" && make clean
	@cd "${ADORE_CLI_MAKEFILE_PATH}/adore_cli"      && make clean

.PHONY: clean_tag_history
clean_tag_history: ## Clear tag history so next build starts fresh
	@rm -f "${ADORE_CLI_LOG_DIR}/tag_history"
	@rm -f "${ADORE_CLI_LOG_DIR}/last_successful_env"

.PHONY: push_core_image
push_core_image: ## Push core image to the adore_cli registry
	docker tag  "${ADORE_CLI_CORE_IMAGE}" "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_CORE_IMAGE}"
	docker push "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_CORE_IMAGE}"

.PHONY: push_base_image
push_base_image: ## Push base image to the adore_cli registry
	docker tag  "${ADORE_CLI_BASE_IMAGE}" "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_BASE_IMAGE}"
	docker push "ghcr.io/${ADORE_CLI_REPO}/${ADORE_CLI_BASE_IMAGE}"

.PHONY: push_user_image
push_user_image: ## Push user image to the parent repo registry (or adore_cli registry if no parent)
	$(eval _USER_IMAGE_REPO := $(if $(filter-out $(ADORE_CLI_REPO),$(PARENT_REPO)),$(PARENT_REPO),$(ADORE_CLI_REPO)))
	docker tag  "${ADORE_CLI_IMAGE}" "ghcr.io/${_USER_IMAGE_REPO}/${ADORE_CLI_IMAGE}"
	docker push "ghcr.io/${_USER_IMAGE_REPO}/${ADORE_CLI_IMAGE}"

.PHONY: push_images
push_images: push_core_image push_base_image push_user_image ## Push all images to registry

# === CONTAINER LIFECYCLE ===
.PHONY: enable_x11_forwarding
enable_x11_forwarding:
	@command -v xhost >/dev/null 2>&1 && xhost +local:docker >/dev/null 2>&1 || true

.PHONY: disable_x11_forwarding
disable_x11_forwarding:
	@command -v xhost >/dev/null 2>&1 && xhost -local:docker >/dev/null 2>&1 || true

.PHONY: adore_cli_setup
adore_cli_setup:
	@touch ${HOME}/.gitconfig
	@mkdir -p ${ADORE_CLI_MAKEFILE_PATH}/.ccache
	@touch ${ADORE_CLI_MAKEFILE_PATH}/.bash_history ${ADORE_CLI_MAKEFILE_PATH}/.zsh_history
	@cp ${ADORE_CLI_MAKEFILE_PATH}/adore_cli_base/files/.zshrc ${ADORE_CLI_MAKEFILE_PATH}/.zshrc
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk enable_x11_forwarding

.PHONY: adore_cli_start
adore_cli_start:
	@bash -c '\
	if ! docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1; then \
	    echo "ERROR: Image not found: ${ADORE_CLI_IMAGE}. Run '\''make build'\'' first."; \
	    exit 1; \
	fi; \
	if docker ps --format "{{.Names}}" | grep -Fxq "${ADORE_CLI_CONTAINER_NAME}"; then \
	    echo "INFO: Container '\''${ADORE_CLI_CONTAINER_NAME}'\'' is already running."; \
	    echo "Run '\''make cli'\'' to attach to it."; \
	    exit 0; \
	fi; \
	if docker ps -a --format "{{.Names}}" | grep -Fxq "${ADORE_CLI_CONTAINER_NAME}"; then \
	    echo "INFO: Removing stopped container '\''${ADORE_CLI_CONTAINER_NAME}'\''..."; \
	    docker rm ${ADORE_CLI_CONTAINER_NAME} >/dev/null; \
	fi; \
	docker run \
	    --detach \
	    --init \
	    --name ${ADORE_CLI_CONTAINER_NAME} \
	    --hostname ${HOSTNAME} \
	    --network host \
	    --ipc host \
	    --pid host \
	    --platform ${DOCKER_PLATFORM} \
	    -e HOSTNAME=${HOSTNAME} \
	    -e TZ="$$(cat /etc/timezone 2>/dev/null || timedatectl show --property=Timezone --value 2>/dev/null || echo UTC)" \
	    -e SOURCE_DIRECTORY=${SOURCE_DIRECTORY} \
	    -e USER=${USER} \
	    -e UID=${USER_UID} \
	    -e GID=${USER_GID} \
	    ${DISPLAY_DOCKER_ARG} \
	    -e ROS_DISTRO=${ROS_DISTRO} \
	    -e HISTFILE=/tmp/adore_cli/.zsh_history \
	    -e ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} \
	    -e ADORE_CLI_IMAGE=${ADORE_CLI_IMAGE} \
	    -e ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
	    -e ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
	    -e ADORE_CLI_CONTAINER_NAME=${ADORE_CLI_CONTAINER_NAME} \
	    ${X11_UNIX_MOUNT} \
	    -v /var/run/docker.sock:/var/run/docker.sock \
	    -v ${ADORE_CLI_MAKEFILE_PATH}/.zshrc:/home/${USER}/.zshrc \
	    -v ${ADORE_CLI_MAKEFILE_PATH}:/tmp/adore_cli \
	    -v ${SOURCE_DIRECTORY}:/tmp/adore \
	    -v ${SOURCE_DIRECTORY}:${SOURCE_DIRECTORY} \
	    -v ${ADORE_CLI_MAKEFILE_PATH}/.ccache:/home/${USER}/.ccache \
	    -v ${SOURCE_DIRECTORY}/.log/.adore_cli:/var/log/adore_cli \
	    -v ${SOURCE_DIRECTORY}/.log:/var/log/ros2 \
	    -v ${SOURCE_DIRECTORY}/.log:/home/${USER}/.log \
	    -v ${HOME}/.gitconfig:/home/${USER}/.gitconfig:ro \
	    -v ${HOME}/.ssh:/home/${USER}/.ssh:ro \
	    --add-host ${HOSTNAME}:127.0.0.1 \
	    ${ADORE_CLI_IMAGE}; \
	'

	@echo "Waiting for entrypoint to complete display setup..."
	@timeout 30 bash -c \
	    'until docker exec ${ADORE_CLI_CONTAINER_NAME} test -f /tmp/.adore_display 2>/dev/null; do sleep 0.5; done'

ZENOH_LOG_DIR        := ${SOURCE_DIRECTORY}/.log/zenoh
ZENOH_ROUTER_PIDFILE := ${ZENOH_LOG_DIR}/zenoh_router.pid
ZENOH_BRIDGE_PIDFILE := ${ZENOH_LOG_DIR}/zenoh_bridge.pid

.PHONY: zenoh_stop
zenoh_stop:
	@if [ -f "${ZENOH_BRIDGE_PIDFILE}" ]; then \
	    BRIDGE_PID=$$(cat "${ZENOH_BRIDGE_PIDFILE}"); \
	    if kill -0 "$$BRIDGE_PID" 2>/dev/null; then \
	        echo "Stopping zenoh bridge (pid $$BRIDGE_PID)"; \
	        kill "$$BRIDGE_PID" 2>/dev/null || true; \
	    fi; \
	    rm -f "${ZENOH_BRIDGE_PIDFILE}"; \
	fi; \
	if [ -f "${ZENOH_ROUTER_PIDFILE}" ]; then \
	    ROUTER_PID=$$(cat "${ZENOH_ROUTER_PIDFILE}"); \
	    if kill -0 "$$ROUTER_PID" 2>/dev/null; then \
	        echo "Stopping zenoh router (pid $$ROUTER_PID)"; \
	        kill "$$ROUTER_PID" 2>/dev/null || true; \
	    fi; \
	    rm -f "${ZENOH_ROUTER_PIDFILE}"; \
	fi

.PHONY: adore_cli_teardown
adore_cli_teardown:
	@ACTIVE_CONTAINER=$$(cat "${ADORE_CLI_ACTIVE_CONTAINER_FILE}" 2>/dev/null || echo ""); \
	TARGET=$${ACTIVE_CONTAINER:-${ADORE_CLI_CONTAINER_NAME}}; \
	docker stop "$$TARGET" 2>/dev/null || true; \
	docker rm -f "$$TARGET" 2>/dev/null || true
	@rm -f "${ADORE_CLI_ACTIVE_CONTAINER_FILE}"
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk zenoh_stop
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk disable_x11_forwarding

.PHONY: adore_cli_attach
adore_cli_attach:
	@docker exec -it \
	    --user ${USER_UID}:${USER_GID} \
	    -e HOME=/home/${USER} \
	    -e HISTFILE=/tmp/adore_cli/.zsh_history \
	    -e SOURCE_DIRECTORY=${SOURCE_DIRECTORY} \
	    -e ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} \
	    -e ADORE_CLI_IMAGE=${ADORE_CLI_IMAGE} \
	    -e ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
	    -e ADORE_CLI_BASE_IMAGE=${ADORE_CLI_BASE_IMAGE} \
	    -e ADORE_CLI_CONTAINER_NAME=${ADORE_CLI_CONTAINER_NAME} \
	    -e ROS_DISTRO=${ROS_DISTRO} \
	    ${ADORE_CLI_CONTAINER_NAME} \
	    /bin/zsh -c "ADORE_CLI_WORKING_DIRECTORY=${ADORE_CLI_WORKING_DIRECTORY} bash /tmp/adore_cli/tools/adore_cli.sh" || true

.PHONY: adore_cli_run
adore_cli_run: ## Run a command in the container: make adore_cli_run cmd="..."
	@[ -z "$(cmd)" ] && echo "Usage: make adore_cli_run cmd='...'" && exit 1 || true
	docker exec --workdir /tmp/adore \
	    --user ${USER_UID}:${USER_GID} \
	    -e HOME=/home/${USER} \
	    -e HISTFILE=/tmp/adore_cli/.zsh_history \
	    ${ADORE_CLI_CONTAINER_NAME} \
	    env DOCKER_EXEC_NON_INTERACTIVE=1 zsh -c "source ~/.zshrc && $(cmd)"

.PHONY: test_ros2_installation
test_ros2_installation:
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk run cmd="bash ${ADORE_CLI_MAKEFILE_PATH}/tools/test_ros2_installation.sh"

# === INFO ===
.PHONY: adore_cli_info
adore_cli_info: ## Show current configuration
	@echo "=== ADORe CLI ==="
	@echo "  Core  : ${ADORE_CLI_CORE_IMAGE}"
	@echo "  Base  : ${ADORE_CLI_BASE_IMAGE}"
	@echo "  User  : ${ADORE_CLI_IMAGE}"
	@echo "  Container : ${ADORE_CLI_CONTAINER_NAME}"
	@echo "  Arch  : ${ARCH} | ROS: ${ROS_DISTRO}"
	@echo "  adore_cli branch : ${ADORE_CLI_BRANCH} (${ADORE_CLI_SHORT_HASH}) dirty=${ADORE_CLI_IS_DIRTY}"
	@echo "  Requirements hash: ${REQUIREMENTS_HASH}"
	@echo "  Packages hash    : ${PACKAGES_HASH}"

.PHONY: build_status
build_status: ## Show which images exist locally
	@printf "%-8s %-60s %s\n" "Layer" "Image" "Status"
	@printf "%-8s %-60s %s\n" "-----" "-----" "------"
	@docker image inspect ${ADORE_CLI_CORE_IMAGE} >/dev/null 2>&1 \
	    && printf "%-8s %-60s %s\n" "core" "${ADORE_CLI_CORE_IMAGE}" "✓" \
	    || printf "%-8s %-60s %s\n" "core" "${ADORE_CLI_CORE_IMAGE}" "✗ missing"
	@docker image inspect ${ADORE_CLI_BASE_IMAGE} >/dev/null 2>&1 \
	    && printf "%-8s %-60s %s\n" "base" "${ADORE_CLI_BASE_IMAGE}" "✓" \
	    || printf "%-8s %-60s %s\n" "base" "${ADORE_CLI_BASE_IMAGE}" "✗ missing"
	@docker image inspect ${ADORE_CLI_IMAGE} >/dev/null 2>&1 \
	    && printf "%-8s %-60s %s\n" "user" "${ADORE_CLI_IMAGE}" "✓" \
	    || printf "%-8s %-60s %s\n" "user" "${ADORE_CLI_IMAGE}" "✗ missing"

.PHONY: branch_adore_cli
branch_adore_cli:
	@echo "${ADORE_CLI_USER_TAG}"

.PHONY: image_adore_cli
image_adore_cli:
	@echo "${ADORE_CLI_IMAGE}"

.PHONY: images_adore_cli
images_adore_cli:
	@echo "${ADORE_CLI_CORE_IMAGE}"
	@echo "${ADORE_CLI_BASE_IMAGE}"
	@echo "${ADORE_CLI_IMAGE}"

.PHONY: container_name_adore_cli
container_name_adore_cli:
	@echo "${ADORE_CLI_CONTAINER_NAME}"

.PHONY: help_cli
help_cli: ## Show this help
	@echo "=== ADORe CLI Help ==="
	@echo ""
	@echo "Layer architecture:"
	@echo "  adore_cli_core  ← ros:${ROS_DISTRO}-ros-core  (bare ROS2 + rosbridge + zenoh)"
	@echo "  adore_cli_base  ← adore_cli_core              (dev tools, x11, tracing, zsh, ccache)"
	@echo "  adore_cli       ← adore_cli_base              (application .debs, runtime user)"
	@echo ""
	@echo "Common workflows:"
	@echo "  make build_adore_cli              # Build all three layers"
	@echo "  make cli                          # Start / attach to CLI"
	@echo "  make stop                         # Stop the container"
	@echo "  make run cmd=\"ros2 topic list\"    # Run a one-off command"
	@echo "  make rebuild_from_layer LAYER=base # Rebuild base + user"
	@echo "  make rebuild_force                # Rebuild everything"
	@echo "  make build_status                 # Check which images exist"
	@echo "  make adore_cli_info               # Show full configuration"

endif
