.PHONY: help tf-init tf-plan tf-show tf-output tf-state tf-apply tf-validate tf-format tf-lint-fix tf-providers-lock

TF_DIR := src/tf
ENVRC := $(CURDIR)/.envrc
SHELL := bash

help:
	@echo "OpenTofu commands:"
	@echo "  Init:              make tf-init [ARGS='-backend=false']"
	@echo "  Plan:              make tf-plan [ARGS='-out=tfplan -destroy']"
	@echo "  Show:              make tf-show ARGS=<planfile>"
	@echo "  Output:            make tf-output [ARGS='-json']"
	@echo "  State:             make tf-state ARGS='<state cmd>'"
	@echo "  Apply:             make tf-apply [ARGS='-auto-approve tfplan']"
	@echo "  Validate:          make tf-validate"
	@echo "  Format check:      make tf-format"
	@echo "  Format fix:        make tf-lint-fix"
	@echo "  Providers lock:    make tf-providers-lock"

tf-init:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu init $(ARGS)

tf-plan:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu plan $(ARGS)

tf-show:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu show $(ARGS)

tf-output:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu output $(ARGS)

tf-state:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu state $(ARGS)

tf-apply:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu apply $(ARGS)

tf-validate:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu validate

tf-format:
	@cd $(TF_DIR) && tofu fmt -check -recursive

tf-lint-fix:
	@cd $(TF_DIR) && tofu fmt -recursive

tf-providers-lock:
	@source "$(ENVRC)" && cd $(TF_DIR) && tofu providers lock \
		-platform=darwin_amd64 \
		-platform=darwin_arm64 \
		-platform=linux_amd64 \
		-platform=linux_arm64 \
		-platform=windows_amd64 \
		-platform=windows_arm64
