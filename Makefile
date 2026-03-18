MAKEFLAGS += --no-print-directory
.NOTPARALLEL:

SHELL := /bin/bash
.EXPORT_ALL_VARIABLES:

ROOT_DIR                  := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")
ADORE_CLI_WORKING_DIRECTORY := ${SOURCE_DIRECTORY}

DOCKER_BUILDKIT ?= 1
ROS_DISTRO      := jazzy
OS_CODE_NAME    := noble

USER_UID := $(shell id -u)
USER_GID := $(shell id -g)
UID      := ${USER_UID}
GID      := ${USER_GID}

include ${ROOT_DIR}/adore_cli.mk
include ${ROOT_DIR}/package.mk
-include ${ADORE_CLI_MAKEFILE_PATH}/ci_teststand/ci_teststand.mk

.PHONY: build
build: clean build_adore_cli ## Build all ADORe CLI layers

.PHONY: debug_run
debug_run:
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY: debug_run_root
debug_run_root:
	docker run -it --rm --user root --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY: save
save: save_docker_images ## Save all ADORe Docker images to disk in .docker_cache

.PHONY: save_docker_images
save_docker_images:
	@source ${ROOT_DIR}/ci.env && \
	echo "Saving docker images to file, output directory: ${ROOT_DIR}/build" && \
	echo "  images: $${docker_images[@]}"
	@mkdir -p "${ROOT_DIR}/build"
	@source ${ROOT_DIR}/ci.env && \
	for docker_image in "$${docker_images[@]}"; do \
	    safe_name="$${docker_image//\//_}"; safe_name="$${safe_name//:/_}"; \
	    if docker image inspect "$${docker_image}" >/dev/null 2>&1; then \
	        echo "  Saving image: $${docker_image} to ${ROOT_DIR}/build/$${safe_name}.tar"; \
	        docker save --output "${ROOT_DIR}/build/$${safe_name}.tar" "$${docker_image}"; \
	    else \
	        echo "  Skipping image (not present locally): $${docker_image}"; \
	    fi; \
	done

.PHONY: clean_all
clean_all: ## Remove all adore_cli* Docker images regardless of tag
	@echo "Cleaning all ADORe CLI Docker images..."
	@docker images "adore_cli*" -q | xargs -r docker rmi -f 2>/dev/null || true

.PHONY: clean
clean: clean_all ## Remove images and all build artifacts
	@echo "Cleaning build artifacts..."
	@make stop || true
	@rm -rf build
	@rm -rf adore_cli/.tmp adore_cli/packages adore_cli/packages_manifest.txt adore_cli/context
	@rm -rf adore_cli_core/.log adore_cli_core/.tmp
	@rm -rf adore_cli_base/.tmp
	@rm -rf ros2_workspace/build ros2_workspace/install ros2_workspace/log
	@rm -rf "${ADORE_CLI_LOG_DIRECTORY}"
	@rm -rf "${ADORE_CLI_MAKEFILE_PATH}/.log/.adore_cli"
	@cd adore_cli_core && make clean
	@cd adore_cli_base && make clean
	@cd adore_cli      && make clean
	@docker rmi $$(docker images -q ${ADORE_CLI_CORE_IMAGE}) --force 2>/dev/null || true
	@docker rmi $$(docker images -q ${ADORE_CLI_BASE_IMAGE}) --force 2>/dev/null || true
	@docker rmi $$(docker images -q ${ADORE_CLI_IMAGE})      --force 2>/dev/null || true
	@docker rmi $$(docker images --filter "dangling=true" -q) --force 2>/dev/null || true

.PHONY: logs
logs:
	docker logs "$$(make container_name_adore_cli)"

.PHONY: test
test: ci_test
