SHELL:=/bin/bash

.DEFAULT_GOAL := all

ROOT_DIR:=$(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")


.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT?=1
DOCKER_CONFIG?=
ADORE_DIRECTORY?=$(shell realpath "${ROOT_DIR}/..")
SUBMODULES_PATH?=$(shell realpath "${ROOT_DIR}/..")
VENDOR_PATH?=$(shell realpath "${ROOT_DIR}/vendor")
TMP_DIR:=.tmp
ROS_DISTRO?=jazzy

USER := $(shell whoami)
UID := $(shell id -u)
GID := $(shell id -g)

include ../adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets/make_gadgets.mk

#TAG:=$(shell bash ${MAKE_GADGETS_PATH}/tools/branch_name.sh)

.PHONY: build
build: clean 
	bash gather_requirements_files.sh
	mkdir -p ${TMP_DIR}/packages
	find "${VENDOR_PATH}" -type f -name "*.deb" -exec cp {} "${TMP_DIR}/packages" \;
	cp "${VENDOR_PATH}/Makefile" "${TMP_DIR}"
	find "${TMP_DIR}" -type d -exec chmod 755 {} \;
	find "${TMP_DIR}" -type f -exec chmod 644 {} \;
	find "${TMP_DIR}" -exec touch -t 197001010000 {} \;
	docker build --network host \
                 --tag ${ADORE_CLI_IMAGE} \
                 --build-arg ADORE_CLI_CORE_X11_DISPLAY_IMAGE=${ADORE_CLI_CORE_X11_DISPLAY_IMAGE} \
                 --build-arg ROS_DISTRO=${ROS_DISTRO} \
                 --build-arg USER=${USER} .

.PHONY: debug_run
debug_run: set_env
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_IMAGE}

.PHONY:
clean: 
	rm -rf ${TMP_DIR}
