# VARIABLES ###################################################################

PACKAGE := api_development_course
MODULES := $(wildcard $(PACKAGE)/*.py)
PYTHON := python
PYTHON_VERSION := 311
VIRTUAL_ENV := $(shell poetry env info -p)
UML_FORMAT := mmd

#* Docker variables
IMAGE := api_development_course
VERSION := latest
DOCKER_CACHE := true


ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
	OPEN := start
	WHICH := where
else
    DETECTED_OS := $(shell sh -c 'uname 2>/dev/null || echo Unknown')
	OPEN := open
	WHICH := which
endif

# POETRY ######################################################################

# Example: make poetry-download PYTHON=python3
.PHONY: poetry-download
poetry-download: ## Download and install Poetry. Options: PYTHON=<python_command> default: python
	@ echo Downloading Poetry and installing using $(PYTHON)
	@ curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | $(PYTHON) -

.PHONY: poetry-remove
poetry-remove: ## Remove Poetry. Options: PYTHON=<python_command> default: python
	@ echo Removing Poetry
	@ curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | $(PYTHON) - --uninstall

# INSTALL #####################################################################

.PHONY: install
install: install-dependencies install-pre-commit ## Install dependencies and pre-commit hooks

.PHONY: install-dependencies
install-dependencies: ## Install package dependencies
	@ poetry env use python{{ cookiecutter.minimal_python_version }}
	@ poetry run python -m pip install -U pip
	@ poetry lock -n && poetry export --without-hashes > requirements.txt
	@ poetry install -n

.PHONY: install-pre-commit
install-pre-commit: ## Install pre-commit hooks
	@ poetry run pre-commit install

.PHONY: update-dependencies
update-dependencies:  ## Update dependencies
	@ poetry update --only main

.PHONY: update-dev-dependencies
update-dev-dependencies:  ## Update development dependencies
	@ poetry update --without main

.PHONY: update-dev-formatters
update-dev-formatters:  ## Update development dependencies: formatters
	@ poetry update --only formating

.PHONY: update-dev-linters
update-dev-linters:  ## Update development dependencies: linters
	@ poetry update --only linting

.PHONY: update-dev-testing
update-dev-testing:  ## Update development dependencies: security
	@ poetry update --only testing

.PHONY: update-dev-documentation
update-dev-documentation:  ## Update development dependencies: documentation
	@ poetry update --only documentation

.PHONY: update-ci
update-update-ci: ## Update pre-commit hooks
	@ poetry update --only ci

# FORMAT ######################################################################

.PHONY: format
format: format-black ## Format codestyle

.PHONY: format-black
format-black: ## Format code using black
	@ black --config pyproject.toml .

# LINT ########################################################################

.PHONY: lint
lint: lint-ruff format  ## Run linting and formatting operations

.PHONY: lint-ruff
lint-ruff: ## Lint with Ruff
	@ ruff check $(PACKAGE) tests --fix || true

# TEST ########################################################################

.PHONY: test
test: ## Run tests
	@ poetry run pytest -c pyproject.toml

.PHONY: test-read-coverage
test-coverage: ## Display test coverage in your browser
	$(OPEN) htmlcov/index.html


# DOCKER ######################################################################

# Example: make docker VERSION=latest
# Example: make docker IMAGE=<image_name> VERSION=0.1.0
.PHONY: docker-build
docker-build: ## Build docker image. Options: IMAGE=<image_name> default: config_parser | VERSION=<image_tag> default: latest | DOCKER_CACHE=false default: true
	@ echo Building docker $(IMAGE):$(VERSION) ...
ifeq ($(DOCKER_CACHE), false)
	@ docker build --tag $(IMAGE):$(VERSION) . --file ./docker/Dockerfile --target production --no-cache
else
	@ docker build --tag $(IMAGE):$(VERSION) . --file ./docker/Dockerfile --target production
endif

# Example: make docker VERSION=latest
# Example: make docker IMAGE=<image_name> VERSION=0.1.0
.PHONY: docker-build-dev
docker-build-dev: ## Build development docker image; version starts with "dev-". Options: IMAGE=<image_name> default: config_parser | VERSION=<image_tag> default: latest | DOCKER_CACHE=false default: true
	@ echo Building docker $(IMAGE):dev-$(VERSION) ...
ifeq ($(DOCKER_CACHE), false)
	@ docker build --tag $(IMAGE):dev-$(VERSION) . --file ./docker/Dockerfile --target development --no-cache
else
	@ docker build --tag $(IMAGE):dev-$(VERSION) . --file ./docker/Dockerfile --target development
endif

# Example: make docker VERSION=latest
# Example: make docker IMAGE=<image_name> VERSION=0.1.0
.PHONY: docker-build-test
docker-build-test: ## Build docker image to test code base; version stats with "test-". Options: IMAGE=<image_name> default: config_parser | VERSION=<image_tag> default: latest | DOCKER_CACHE=false default: true
	@ echo Building docker $(IMAGE):test-$(VERSION) ...
ifeq ($(DOCKER_CACHE), false)
	@ docker build --tag $(IMAGE):test-$(VERSION) . --file ./docker/Dockerfile --target test --no-cache
else
	@ docker build --tag $(IMAGE):test-$(VERSION) . --file ./docker/Dockerfile --target test
endif

# Example: make clean_docker VERSION=latest
# Example: make clean_docker IMAGE=<image_name> VERSION={{ cookiecutter.version }}
.PHONY: docker-remove
docker-remove: ## Remove docker image. Options: IMAGE=<image_name> default: api_development_course | VERSION=<image_tag> default: latest
	@ echo Removing docker $(IMAGE):$(VERSION) ...
	@ docker rmi -f $(IMAGE):$(VERSION)

# DOCUMENTATION ###############################################################

MKDOCS_INDEX := site/index.html

.PHONY: docs
docs: docs-mkdocs docs-uml ## Generate documentation and UML

.PHONY: docs-mkdocs
docs-mkdocs: $(MKDOCS_INDEX) ## Generate documentation
$(MKDOCS_INDEX): docs/requirements.txt mkdocs.yml
	@ mkdir -p docs/about
	@ cd docs && ln -sf ../README.md index.md
	@ cd docs/about && ln -sf ../../CHANGELOG.md changelog.md
	@ cd docs/about && ln -sf ../../CONTRIBUTING.md contributing.md
	@ cd docs/about && ln -sf ../../CODE_OF_CONDUCT.md code_of_conduct.md
	@ poetry run mkdocs build --clean --strict

docs/requirements.txt: poetry.lock
	@ mkdir -p docs/
	@ poetry export --with documentation --without-hashes | grep mkdocs > $@
	@ poetry export --with documentation --without-hashes | grep pygments >> $@
	@ poetry export --with documentation --without-hashes | grep pymdown >> $@

.PHONY: docs-uml
docs-uml: ## Generate UML documentation; If Graphviz is not installed, will generate plantuml (puml) instead of png files
ifeq ($(UML_FORMAT),puml)
	@ echo Graphviz not installed generating puml instead of png - consider installing Graphviz -
endif
	@ poetry run pyreverse $(PACKAGE) -p $(PACKAGE) -a 1 -f ALL -o $(UML_FORMAT) --ignore tests
	@ - mv -f classes_$(PACKAGE).$(UML_FORMAT) docs/classes.$(UML_FORMAT)
	@ - mv -f packages_$(PACKAGE).$(UML_FORMAT) docs/packages.$(UML_FORMAT)

.PHONY: docs-serve
docs-serve: docs ## Open documentation locally
	@ poetry run mkdocs serve

# @ eval "sleep 3; $(OPEN) http://127.0.0.1:8000" &

.PHONY: docs-publish
docs-publish: docs ## Deploy documentation to gh-pages
	@ mkdocs gh-deploy

# CLEANUP #####################################################################

.PHONY: clean
clean: clean-build clean-docs clean-test clean-compiled ## Delete all generated and temporary files

.PHONY: clean-build
clean-build: ## Delete package build
	@ rm -rf dist/
	@ echo Removed package build files

.PHONY: clean-docker
clean-docker: ## Delete all docker images by name. Options: IMAGE=<image_name> default: config_parser
	@ echo Removing all $(IMAGE) images
	@ docker rmi -f $(shell docker images $(IMAGE) -a -q)
	@ echo All $(IMAGE) images removed

.PHONY: clean-docs
clean-docs: ## Delete png files in docs directory
	@ rm -rf docs/*.$(UML_FORMAT) site
	@ echo Cleaned docs

.PHONY: clean-compiled
clean-compiled: ## Delete compiled python files
	@ find . | grep -E "(__pycache__|\.pyc|\.pyo$$)" | xargs rm -rf
	@ echo Compiled Python files removed

.PHONY: clean-test
clean-test: ## Delete test cache and coverage reports
	@ rm -rf .cache .pytest .coverage htmlcov
	@ echo Test data removed

.PHONY: clean-venv
clean-venv: ## Delete virtual environment.
	@ echo Removing virtual environment located at $(VIRTUAL_ENV)
	@ rm -rf $(VIRTUAL_ENV)
	@ echo Virtual enviroment removed

.PHONY: clean-all
clean-all: clean clean-docker clean-venv ## Run all cleaning tasks

# PUBLISHING ##################################################################

.PHONY: bump
bump: ## Update changelog and git tags based on commit changes
	poetry run cz bump --check-consistency --changelog
	git push
	git push --tags

# HELP ########################################################################

.PHONY: help
help: ## Show help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[$$()% a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help
