SHELL:=/bin/bash

ROOT_DIR:=$(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")

.EXPORT_ALL_VARIABLES:
#SOURCE_DIRECTORY:=$(shell realpath "${ROOT_DIR}/..")
SOURCE_DIRECTORY:=${ROOT_DIR}
ADORE_CLI_WORKING_DIRECTORY:=${ROOT_DIR}
CATKIN_WORKSPACE_DIRECTORY:=${SOURCE_DIRECTORY}/catkin_workspace


include ${ROOT_DIR}/adore_cli.mk
include ${ADORE_CLI_MAKEFILE_PATH}/ci_teststand/ci_teststand.mk


.PHONY: _build_adore_cli_core
_build_adore_cli_core: 
	cd "${ADORE_CLI_MAKEFILE_PATH}" && \
    docker compose -f ${DOCKER_COMPOSE_FILE} build ${ADORE_CLI_PROJECT} \
                         --build-arg ADORE_CLI_PROJECT=${ADORE_CLI_PROJECT} \
                         --build-arg ADORE_CLI_PROJECT_X11_DISPLAY=${ADORE_CLI_CORE_PROJECT_X11_DISPLAY} \
                         --build-arg USER=${USER} \
                         --build-arg UID=${UID} \
                         --build-arg GID=${GID} \
                         --build-arg DOCKER_GID=${DOCKER_GID}

.PHONY: build_adore_cli_core_x11_display
build_adore_cli_core_x11_display: 
	docker compose -f ${DOCKER_COMPOSE_FILE} build ${ADORE_CLI_PROJECT_X11_DISPLAY} \
                         --build-arg ADORE_CLI_PROJECT=${ADORE_CLI_PROJECT} \
                         --build-arg ADORE_CLI_CORE_IMAGE=${ADORE_CLI_CORE_IMAGE} \
                         --build-arg USER=${USER} \
                         --build-arg UID=${UID} \
                         --build-arg GID=${GID} \
                         --build-arg DOCKER_GID=${DOCKER_GID}


.PHONY: build
build: _build_adore_cli_core build_adore_cli_core_x11_display build_adore_cli

.PHONY: debug_run
debug_run:
	docker run -it --rm --entrypoint /bin/bash ${ADORE_CLI_PROJECT}_x11_display:${ADORE_CLI_TAG}

.PHONY: debug_run_root
debug_run_root:
	docker run -it --rm --user root --entrypoint /bin/bash ${ADORE_CLI_PROJECT}_x11_display:${ADORE_CLI_TAG}

.PHONY: clean
clean:
	rm -rf build
	docker rmi $$(docker images -q ${ADORE_CLI_CORE_IMAGE}) --force 2> /dev/null || true
	docker rmi $$(docker images -q ${ADORE_CLI_CORE_X11_DISPLAY_IMAGE}) --force 2> /dev/null || true
	docker rmi $$(docker images --filter "dangling=true" -q) --force > /dev/null 2>&1 || true

.PHONY: test
test: ci_test

