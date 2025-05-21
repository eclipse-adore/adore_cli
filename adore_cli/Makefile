SHELL := /bin/bash

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

.PHONY: build
build: clean gather
	@if [ "$(CROSS_COMPILE)" = "true" ]; then \
		echo "Cross-compiling for $(ARCH)..."; \
		docker buildx build --platform $(DOCKER_PLATFORM) \
			--tag ${ADORE_CLI_IMAGE} \
			--build-arg ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg USER=${USER} \
			--build-arg UID=${UID} \
			--build-arg GID=${GID} \
			--build-arg DOCKER_GID=${DOCKER_GID} \
			--load . ; \
	else \
		docker build --network host \
			--tag ${ADORE_CLI_IMAGE} \
			--build-arg ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
			--build-arg ROS_DISTRO=${ROS_DISTRO} \
			--build-arg USER=${USER} \
			--build-arg UID=${UID} \
			--build-arg GID=${GID} \
			--build-arg DOCKER_GID=${DOCKER_GID} \
			--build-arg USER=${USER} . ; \
	fi

.PHONY: gather
gather:
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

.PHONY: clean
clean:
	rm -rf ${TMP_DIR}
	docker rmi $$(docker images -q ${ADORE_CLI_IMAGE}) --force 2>/dev/null || true
	docker rmi $$(docker images --filter "dangling=true" -q) --force > /dev/null 2>&1 || true

