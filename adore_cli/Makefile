SHELL := /bin/bash
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.DEFAULT_GOAL := build

ROOT_DIR := $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
DOCKER_BUILDKIT ?= 1
ROS_DISTRO      ?= jazzy
ARCH            ?= $(shell uname -m)
DOCKER_PLATFORM ?= linux/$(ARCH)
CROSS_COMPILE   ?= false

ifneq ($(SOURCE_DIRECTORY),)
    VENDOR_PATH := ${SOURCE_DIRECTORY}/vendor
else
    VENDOR_PATH := $(shell realpath "${ROOT_DIR}/../vendor")
endif

include ../adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/make_gadgets/make_gadgets.mk

CONTEXT_DIR      := ${ROOT_DIR}/context
REQUIREMENTS_DIR := ${SOURCE_DIRECTORY}/.log/.adore_cli/requirements

.PHONY: build
build: gather
	@make --file=${ADORE_CLI_MAKEFILE_PATH}/adore_cli.mk _build_user

.PHONY: gather
gather:
	@echo "=== Gathering application dependencies ==="
	@rm -rf ${CONTEXT_DIR}
	@mkdir -p ${CONTEXT_DIR}/vendor
	@bash ${ADORE_CLI_MAKEFILE_PATH}/tools/requirements_hashing_util.sh combine "${SOURCE_DIRECTORY}"
	@cp ${REQUIREMENTS_DIR}/combined_requirements.system ${CONTEXT_DIR}/requirements.system
	@cp ${REQUIREMENTS_DIR}/combined_requirements.pip3   ${CONTEXT_DIR}/requirements.pip3
	@cp ${REQUIREMENTS_DIR}/combined_requirements.ppa    ${CONTEXT_DIR}/requirements.ppa
	@find ${VENDOR_PATH}/build -name '*.deb' 2>/dev/null | sort | xargs -r -I{} cp {} ${CONTEXT_DIR}/vendor/
	@echo "  ppa    : $$(wc -l < ${CONTEXT_DIR}/requirements.ppa)"
	@echo "  system : $$(wc -l < ${CONTEXT_DIR}/requirements.system)"
	@echo "  pip3   : $$(wc -l < ${CONTEXT_DIR}/requirements.pip3)"
	@echo "  debs   : $$(find ${CONTEXT_DIR}/vendor -name '*.deb' | wc -l)"
	@echo "=== Gather complete ==="

.PHONY: clean
clean:
	@rm -rf ${CONTEXT_DIR}
	@docker rmi ${ADORE_CLI_IMAGE} 2>/dev/null || true
