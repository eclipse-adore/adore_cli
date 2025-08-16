# === SUPPRESS WARNINGS ===
MAKEFLAGS += --no-print-directory
.NOTPARALLEL:

# === SHELL AND EXPORT CONFIGURATION ===
SHELL:=/bin/bash
.EXPORT_ALL_VARIABLES:

# === PROJECT DIRECTORIES ===
ROOT_DIR:=$(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")
SOURCE_DIRECTORY:=${ROOT_DIR}
ADORE_CLI_WORKING_DIRECTORY:=${ROOT_DIR}

# === DOCKER CONFIGURATION ===
DOCKER_BUILDKIT?=1
COMPOSE_BAKE?=true

# === ROS CONFIGURATION ===
ROS_DISTRO:=jazzy
OS_CODE_NAME:=noble

# === INCLUDES ===
include ${ROOT_DIR}/adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/ci_teststand/ci_teststand.mk

# === BUILD TARGETS ===

.PHONY: build
build: _build_adore_cli_core build_adore_cli ## Complete build process for ADORe CLI environment

# === DEBUG AND DEVELOPMENT TARGETS ===

.PHONY: debug_run
debug_run:
	@echo "Starting debug session with user image: ${ADORE_CLI_USER_IMAGE}"
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_USER_IMAGE}

.PHONY: debug_run_root
debug_run_root:
	@echo "Starting root debug session with user image: ${ADORE_CLI_USER_IMAGE}"
	docker run -it --rm --user root --entrypoint /bin/bash ${ADORE_CLI_USER_IMAGE}

# === CLEANUP TARGETS ===

.PHONY: clean
clean:
	@echo "Cleaning build artifacts and Docker images..."
	@rm -rf build
	@echo "Removing ADORe CLI images..."
	@docker rmi $$(docker images -q ${ADORE_CLI_SYSTEM_IMAGE}) --force 2> /dev/null || true
	@docker rmi $$(docker images -q ${ADORE_CLI_CORE_IMAGE}) --force 2> /dev/null || true
	@docker rmi $$(docker images -q ${ADORE_CLI_USER_IMAGE}) --force 2> /dev/null || true
	@docker rmi $$(docker images -q ${ADORE_CLI_IMAGE}) --force 2> /dev/null || true
	@echo "Removing dangling images..."
	@docker rmi $$(docker images --filter "dangling=true" -q) --force > /dev/null 2>&1 || true
	@echo "Cleaning tag history..."
	@rm -f "${SOURCE_DIRECTORY}/.log/adore_cli_tag_history"

# === TEST TARGETS ===

.PHONY: test
test: ci_test

# === REMOVE THESE DUPLICATE TARGETS - THEY'RE ALREADY IN adore_cli.mk ===
# .PHONY: try_pull_base_images
# try_pull_base_images: ## Try to pull base and core images from registry
# 	@$(MAKE) --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk try_pull_base_images

# .PHONY: push_base_images  
# push_base_images: ## Push base and core images to registry
# 	@$(MAKE) --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk push_base_images

# .PHONY: cleanup_registry_images
# cleanup_registry_images: ## Cleanup old images in registry (ros2 branch only)
# 	@$(MAKE) --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk cleanup_registry_images

# .PHONY: registry_status
# registry_status: ## Show registry status for base images
# 	@$(MAKE) --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk registry_status

# .PHONY: save_docker_images
# save_docker_images: ## Save docker images (for CI artifact upload)
# 	@echo "Saving Docker images for CI..."
# 	@mkdir -p .log
# 	@docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "(adore_cli|ros)" > .log/docker_images.txt || true
# 	@echo "Docker images saved to .log/docker_images.txt"

# === INFORMATION TARGETS ===

.PHONY: info
info: ## Display current configuration and environment information
	@echo "=== ADORe CLI Configuration ==="
	@echo "ROOT_DIR: ${ROOT_DIR}"
	@echo "SOURCE_DIRECTORY: ${SOURCE_DIRECTORY}"
	@echo "ROS_DISTRO: ${ROS_DISTRO}"
	@echo "OS_CODE_NAME: ${OS_CODE_NAME}"
	@echo "ARCH: ${ARCH}"
	@echo "DOCKER_PLATFORM: ${DOCKER_PLATFORM}"
	@echo "CROSS_COMPILE: ${CROSS_COMPILE}"
	@echo "USER: ${USER}"
	@echo "UID: ${UID}"
	@echo "GID: ${GID}"
	@echo
	@echo "=== Docker Images ==="
	@echo "System Base: ${ADORE_CLI_SYSTEM_IMAGE}"
	@echo "Core Environment: ${ADORE_CLI_CORE_IMAGE}"
	@echo "User Layer: ${ADORE_CLI_USER_IMAGE}"
	@echo "Runtime: ${ADORE_CLI_IMAGE}"
	@echo "Container Name: ${ADORE_CLI_CONTAINER_NAME}"
	@echo
	@echo "=== Build Configuration ==="
	@echo "DOCKER_BUILDKIT: ${DOCKER_BUILDKIT}"
	@echo "COMPOSE_BAKE: ${COMPOSE_BAKE}"
	@echo "Git Branch: ${BRANCH}"
	@echo "Git Hash: ${SHORT_HASH}"

