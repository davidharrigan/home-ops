
.PHONY: pre-commit/init
pre-commit/init:
	pre-commit install --install-hooks
	pre-commit run --all-files