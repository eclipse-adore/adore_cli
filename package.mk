ifeq ($(filter package.mk, $(notdir $(MAKEFILE_LIST))), package.mk)


PACKAGE_NAME     := adore_cli_$(ADORE_CLI_TAG)
PACKAGE_TEMP_DIR := /tmp/$(PACKAGE_NAME)
PACKAGE_BUILD_DIR:= $(SOURCE_DIRECTORY)/build

.PHONY: package
package: build save ## Build and save all layers then produce a tar.gz in build/
	@echo "=== Creating package ==="
	@echo "  Package: $(PACKAGE_BUILD_DIR)/$(PACKAGE_NAME).tar.gz"
	@echo "$(ADORE_CLI_TAG)" > "/tmp/$(PACKAGE_NAME)/TAG"
	@tar -czf "/tmp/$(PACKAGE_NAME).tar.gz" -C /tmp "$(PACKAGE_NAME)"
	@mkdir -p "$(PACKAGE_BUILD_DIR)"
	@mv "/tmp/$(PACKAGE_NAME).tar.gz" "$(PACKAGE_BUILD_DIR)/$(PACKAGE_NAME).tar.gz"
	@rm -rf "$(PACKAGE_TEMP_DIR)"
	@echo "=== Package ready: $(PACKAGE_BUILD_DIR)/$(PACKAGE_NAME).tar.gz ==="

endif
