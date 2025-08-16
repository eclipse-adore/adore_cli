SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules


.DEFAULT_GOAL := all

ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?= 1
DOCKER_CONFIG?=
ADORE_DIRECTORY?=$(shell realpath "${ROOT_DIR}/..")
SUBMODULES_PATH?=$(shell realpath "${ROOT_DIR}/..")
VENDOR_PATH?=$(shell realpath "${ROOT_DIR}/vendor")
TMP_DIR:=.tmp
ROS_DISTRO?=jazzy

USER:=$(shell whoami)
UID:=$(shell id -u)
GID:=$(shell id -g)
DOCKER_GID:=$(shell getent group docker | cut -d: -f3)

CROSS_COMPILE?=false
ARCH?=amd64
DOCKER_PLATFORM?=linux/$(ARCH)

include ../adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets/make_gadgets.mk

# Target: build
# Description: Builds the ADORe CLI runtime development environment
# - Uses the user-customized core image as the base layer
# - Gathers and installs all discovered requirements from the project tree
# - Creates the final development environment with tools and dependencies
# - Supports both native and cross-compilation builds
.PHONY: build
build: clean gather
	@echo "Building ADORe CLI runtime environment..."
	@echo "Base image: ${ADORE_CLI_USER_IMAGE}"
	@echo "Target image: ${ADORE_CLI_IMAGE}"
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
		echo "Cross-compiling for $(ARCH)..."; \
		docker buildx build \
			--builder=default \
			--platform $(DOCKER_PLATFORM) \
			--tag ${ADORE_CLI_IMAGE} \
			--build-arg ADORE_CLI_USER_IMAGE=${ADORE_CLI_USER_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${BRANCH} \
			--build-arg SHORT_HASH=${SHORT_HASH} \
			--build-arg ARCH=${ARCH} \
			--build-arg USER=${USER} \
			--build-arg UID=${UID} \
			--build-arg GID=${GID} \
			--build-arg DOCKER_GID=${DOCKER_GID} \
			--load . ; \
	else \
		docker build --network host \
			--tag ${ADORE_CLI_IMAGE} \
			--build-arg ADORE_CLI_USER_IMAGE=${ADORE_CLI_USER_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg OS_CODE_NAME=${OS_CODE_NAME} \
			--build-arg BRANCH=${BRANCH} \
			--build-arg SHORT_HASH=${SHORT_HASH} \
			--build-arg ARCH=${ARCH} \
			--build-arg USER=${USER} \
			--build-arg UID=${UID} \
			--build-arg GID=${GID} \
			--build-arg DOCKER_GID=${DOCKER_GID} \
			--build-arg USER=${USER} . ; \
	fi

# Target: gather
# Description: Collects all requirements files and packages for the build
# - Executes requirements gathering script to scan project tree
# - Copies vendor packages and makefiles to build context
# - Sets proper permissions and timestamps for reproducible builds
.PHONY: gather
gather:
	@echo "Gathering requirements and packages..."
	bash gather_requirements_files.sh
	mkdir -p ${TMP_DIR}/packages
	find "${VENDOR_PATH}" -type f -name "*.deb" -exec cp {} "${TMP_DIR}/packages" \;
	cp "${VENDOR_PATH}/Makefile" "${TMP_DIR}"
	find "${TMP_DIR}" -type d -exec chmod 755 {} \;
	find "${TMP_DIR}" -type f -exec chmod 644 {} \;
	find "${TMP_DIR}" -exec touch -t 197001010000 {} \;

.PHONY: debug_run
debug_run:
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY: debug_run_root
debug_run_root:
	docker run -it --rm --user root --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

# Target: clean
# Description: Comprehensive cleanup of build artifacts and images
# - Removes temporary build directory and all contents
# - Removes the runtime Docker image from local registry
# - Cleans up dangling images to free disk space
.PHONY: clean
clean:
	@echo "Cleaning adore_cli runtime build artifacts..."
	@rm -rf ${TMP_DIR}
	@echo "Removing runtime image: ${ADORE_CLI_IMAGE}"
	@docker rmi $$(docker images -q ${ADORE_CLI_IMAGE}) --force 2>/dev/null || true
	@echo "Removing dangling images..."
	@docker rmi $$(docker images --filter "dangling=true" -q) --force > /dev/null 2>&1 || true
