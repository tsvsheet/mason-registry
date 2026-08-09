.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

here := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))

PACKAGE_FILES := $(wildcard $(here)packages/*/package.yaml)

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "\033[36m%-12s\033[0m %s\n",$$1,$$2}'

.PHONY: check
check: validate build ## Validate the definitions and compile the artifact

.PHONY: validate
validate: ## Validate schema and live upstream assets for every package
	$(here)scripts/validate

.PHONY: build
build: $(here)var/registry.json ## Compile the registry artifact mason consumes

$(here)var:
	@mkdir -p $@

# The packages directory itself is a prerequisite so adding or removing a
# package (which touches its mtime) rebuilds; var/ is order-only so file
# events inside it never force spurious rebuilds. Bound: make compares mtimes
# at its stat resolution, so a package added or removed within the same second
# as the previous build is invisible until anything touches the tree again —
# CI never hits this (fresh checkout), and the release always compiles fresh.
$(here)var/registry.json: $(PACKAGE_FILES) $(here)packages | $(here)var
	yq eval-all -o=json '[.]' $(PACKAGE_FILES) > $@
	jq -e 'type == "array" and length > 0' $@ > /dev/null
