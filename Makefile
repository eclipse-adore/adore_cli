# === SUPPRESS WARNINGS ===
MAKEFLAGS += --no-print-directory
.NOTPARALLEL:

# === SHELL AND EXPORT CONFIGURATION ===
SHELL:=/bin/bash
.EXPORT_ALL_VARIABLES:

# === PROJECT DIRECTORIES ===
ROOT_DIR:=$(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")
ADORE_CLI_WORKING_DIRECTORY:=${SOURCE_DIRECTORY}


# === DOCKER CONFIGURATION ===
DOCKER_BUILDKIT?=1
COMPOSE_BAKE?=true

# === ROS CONFIGURATION ===
ROS_DISTRO:=jazzy
OS_CODE_NAME:=noble

USER_UID:=$(shell id -u)
USER_GID:=$(shell id -g)
UID:=${USER_UID}
GID:=${USER_GID}

# === INCLUDES ===
include ${ROOT_DIR}/adore_cli.mk
-include ${ADORE_CLI_MAKEFILE_PATH}/ci_teststand/ci_teststand.mk

# === BUILD TARGETS ===

.PHONY: build
build: clean _build_adore_cli_layers ## Complete build process for ADORe CLI environment

# === DEBUG AND DEVELOPMENT TARGETS ===

.PHONY: debug_run
debug_run:
	@echo "Starting debug session with user image: ${ADORE_CLI_IMAGE}"
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY: debug_run_root
debug_run_root:
	@echo "Starting root debug session with user image: ${ADORE_CLI_IMAGE}"
	docker run -it --rm --user root --entrypoint /bin/bash ${ADORE_CLI_IMAGE}


.PHONY: save
save: save_docker_images ## Save all ADORe Docker images to disk in .docker_cache

# === CLEANUP TARGETS ===

.PHONY: clean
clean:
	@echo "Cleaning build artifacts and Docker images..."
	make stop || true
	@rm -rf build
	@rm -rf adore_cli/.tmp
	@rm -rf adore_cli/packages
	@rm -rf adore_cli/packages_manifest.txt
	@rm -rf adore_cli_core/.log
	@rm -rf ros2_workspace/build
	@rm -rf ros2_workspace/install
	@rm -rf ros2_workspace/log
	@rm -rf "${ADORE_CLI_LOG_DIRECTORY}"
	@rm -rf "${ADORE_CLI_MAKEFILE_PATH}/.log/.adore_cli"
	cd adore_cli_core && make clean
	cd adore_cli && make clean

	@echo "Removing ADORe CLI images..."
	@docker rmi $$(docker images -q ${ADORE_CLI_BASE_IMAGE}) --force 2> /dev/null || true
	@docker rmi $$(docker images -q ${ADORE_CLI_CORE_IMAGE}) --force 2> /dev/null || true
	@docker rmi $$(docker images -q ${ADORE_CLI_IMAGE}) --force 2> /dev/null || true
	@echo "Removing dangling images..."
	@docker rmi $$(docker images --filter "dangling=true" -q) --force > /dev/null 2>&1 || true

# === TEST TARGETS ===

.PHONY: logs
logs:
	docker logs "$$(make container_name_adore_cli)"

.PHONY: test
test: ci_test
