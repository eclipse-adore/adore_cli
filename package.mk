ifeq ($(filter package.mk, $(notdir $(MAKEFILE_LIST))), package.mk)

PACKAGE_NAME      := adore_cli_$(ADORE_CLI_TAG)
PACKAGE_TEMP_DIR  := /tmp/$(PACKAGE_NAME)
PACKAGE_BUILD_DIR := $(SOURCE_DIRECTORY)/build

.PHONY: package
package: build save ## Build, save images, then produce a relocatable tar.gz in build/
	@echo "=== Creating package ==="
	@echo "  Package: $(PACKAGE_BUILD_DIR)/$(PACKAGE_NAME).tar.gz"
	@rm -rf "$(PACKAGE_TEMP_DIR)"
	@mkdir -p "$(PACKAGE_TEMP_DIR)/workspace/build"
	@tar -C "$(SOURCE_DIRECTORY)" \
	    --exclude="./.log" \
	    --exclude="./adore_cli/context" \
	    -cf - . | tar -C "$(PACKAGE_TEMP_DIR)/workspace" -xf -
	@cp "$(PACKAGE_BUILD_DIR)"/*.tar "$(PACKAGE_TEMP_DIR)/workspace/build/" 2>/dev/null || true
	@echo "$(ADORE_CLI_TAG)" > "$(PACKAGE_TEMP_DIR)/workspace/build/TAG"
	@tar -czf "$(PACKAGE_TEMP_DIR).tar.gz" -C /tmp "$(PACKAGE_NAME)"
	@mkdir -p "$(PACKAGE_BUILD_DIR)"
	@mv "$(PACKAGE_TEMP_DIR).tar.gz" "$(PACKAGE_BUILD_DIR)/$(PACKAGE_NAME).tar.gz"
	@rm -rf "$(PACKAGE_TEMP_DIR)"
	@echo "=== Package ready: $(PACKAGE_BUILD_DIR)/$(PACKAGE_NAME).tar.gz ==="

endif
