# postern — Remote image driver for Pharo
#
# Default:
#   make            — show this help
#
# Image lifecycle:
#   make setup      — download Pharo VM + image, load all packages
#   make start      — launch Pharo GUI with eval server on :8422
#   make start-headless — launch Postern headlessly on :8422
#   make start-ui   — alias for make start
#   make stop       — kill Pharo (no save — image is disposable)
#   make rebuild    — fresh image from scratch
#
# Development:
#   make filein     — reload all Tonel packages into running image
#   make eval       — interactive Smalltalk eval
#   make test       — run Postern tests
#   make status     — health check
#   make lint       — lint all Postern classes
#   make check      — verify all packages loaded + Iceberg working copy clean
#   make transcript — read Pharo Transcript

PHARO_VERSION := 120
PORT := 8422
IMAGE_DIR := $(CURDIR)/pharo
BOOTSTRAP_URL := https://get.pharo.org/64/$(PHARO_VERSION)+vm
BOOTSTRAP_SCRIPT := $(IMAGE_DIR)/bootstrap-pharo.sh
SETUP_STAMP := $(IMAGE_DIR)/.postern-setup
IMAGE := $(IMAGE_DIR)/Pharo.image
CHANGES := $(IMAGE_DIR)/Pharo.changes
VM := $(IMAGE_DIR)/pharo
PID_FILE := $(CURDIR)/.pharo.pid
LOG_FILE := $(CURDIR)/.pharo.log
SRC_DIR := $(CURDIR)/src
URL := http://localhost:$(PORT)/repl
HEALTH_URL := http://localhost:$(PORT)/health
CURL := curl -s -X POST $(URL) -H "Content-Type: text/plain"
HEALTHCHECK := curl -fsS $(HEALTH_URL)
SERVER_PATTERN := $(IMAGE) eval --no-quit PosternServer startOn: $(PORT)
OS := $(shell uname -s)
ifeq ($(OS),Darwin)
VM_UI := $(IMAGE_DIR)/pharo-vm/Pharo.app/Contents/MacOS/Pharo
else
VM_UI := $(IMAGE_DIR)/pharo-vm/pharo
endif
MAKEFLAGS += --no-print-directory
.DEFAULT_GOAL := help

# Tonel packages — auto-discovered from src/ directories containing package.st.
# Load order: production packages in dependency order, then test packages.
LOAD_PACKAGES_EXPR := | dir allPkgs priority sorted lfCount | dir := '$(SRC_DIR)' asFileReference. IceRepository registry detect: [ :r | r name = 'postern' ] ifNone: [ | r | r := IceRepositoryCreator new location: '$(CURDIR)' asFileReference; createRepository. r register. r ]. allPkgs := (dir children select: [ :d | d isDirectory and: [ (d / 'package.st') exists ] ]) collect: [ :d | d basename ]. priority := Dictionary new. priority at: 'Postern-Core' put: 10. priority at: 'Postern-Dashboard' put: 15. priority at: 'Postern-IcebergExtensions' put: 15. priority at: 'BaselineOfPostern' put: 20. sorted := allPkgs sorted: [ :a :b | | pa pb | pa := (a endsWith: '-Tests') ifTrue: [ 100 ] ifFalse: [ priority at: a ifAbsent: [ 50 ] ]. pb := (b endsWith: '-Tests') ifTrue: [ 100 ] ifFalse: [ priority at: b ifAbsent: [ 50 ] ]. pa = pb ifTrue: [ a < b ] ifFalse: [ pa < pb ] ]. sorted do: [ :name | | reader version | Transcript show: 'Loading package: ', name; cr. reader := TonelReader on: dir fileName: name. version := reader version. MCPackageLoader installSnapshot: version snapshot ]. lfCount := 0. Smalltalk globals allClasses do: [ :cls | (cls package name beginsWith: 'Postern') ifTrue: [ (cls methods, cls class methods) do: [ :m | | src | src := m sourceCode. (src includesSubstring: String lf) ifTrue: [ cls compile: (src copyReplaceAll: String lf with: String cr) classified: m protocolName. lfCount := lfCount + 1 ] ] ] ]. 'Loaded ', sorted size printString, ' packages, normalized ', lfCount printString, ' methods'

.PHONY: help bootstrap setup start start-headless start-ui stop rebuild filein eval test status lint check check-packages transcript clean clean-image

# ── Setup ──────────────────────────────────────────────

help:
	@printf "%s\n" \
		"Postern make targets" \
		"" \
		"  make help         Show this help" \
		"  make setup        Download Pharo and load all Tonel packages" \
		"  make start        Start Postern with the Pharo UI on :$(PORT)" \
		"  make start-headless  Start Postern headlessly on :$(PORT)" \
		"  make start-ui     Alias for make start" \
		"  make stop         Stop the running Pharo VM without saving" \
		"  make rebuild      Recreate the disposable image from scratch" \
		"  make filein       Reload Tonel packages into the running image" \
		"  make eval         Send Smalltalk from stdin to the eval server" \
		"  make test         Run all Postern tests" \
		"  make lint         Run Renraku lint on Postern classes" \
		"  make status       Check the eval server and loaded class count" \
		"  make check        Verify packages are loaded and Iceberg is clean" \
		"  make transcript   Print the Pharo Transcript" \
		"  make clean-image  Remove the disposable image, logs, and setup state" \
		"  make clean        Remove the entire downloaded Pharo workspace"

$(IMAGE_DIR):
	mkdir -p $(IMAGE_DIR)

bootstrap: | $(IMAGE_DIR)
	@if [ -x $(VM) ] && [ -x $(VM_UI) ] && [ -f $(IMAGE) ] && [ -f $(CHANGES) ]; then \
		echo ">> Using existing Pharo $(PHARO_VERSION) download..."; \
	else \
		echo ">> Downloading Pharo $(PHARO_VERSION)..."; \
		rm -rf $(IMAGE_DIR)/pharo-vm $(IMAGE_DIR)/pharo-local; \
		rm -f $(VM) $(IMAGE) $(CHANGES) $(IMAGE_DIR)/Pharo*.sources; \
		rm -f $(BOOTSTRAP_SCRIPT); \
		curl -fsSL $(BOOTSTRAP_URL) -o $(BOOTSTRAP_SCRIPT); \
		cd $(IMAGE_DIR) && bash ./$(notdir $(BOOTSTRAP_SCRIPT)); \
		rm -f $(BOOTSTRAP_SCRIPT); \
	fi
	@test -x $(VM)
	@test -x $(VM_UI)
	@test -f $(IMAGE)
	@test -f $(CHANGES)
	@echo "  ok Pharo downloaded"

$(VM) $(VM_UI) $(IMAGE) $(CHANGES): | $(IMAGE_DIR)
	@$(MAKE) bootstrap

setup: $(SETUP_STAMP)

$(SETUP_STAMP): $(VM) $(VM_UI) $(IMAGE) $(CHANGES)
	@echo ">> Loading Tonel packages into image..."
	$(VM) $(IMAGE) eval --save "$(LOAD_PACKAGES_EXPR)"
	@touch $(SETUP_STAMP)
	@echo "  ok All packages loaded and image saved"

# ── Run ────────────────────────────────────────────────

start: $(SETUP_STAMP)
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "Pharo already running (PID $$(cat $(PID_FILE)))"; \
	else \
		if [ "$$(uname -s)" = "Linux" ] && [ -z "$$DISPLAY" ] && [ -z "$$WAYLAND_DISPLAY" ]; then \
			echo "  FAIL make start requires a GUI session on Linux (DISPLAY or WAYLAND_DISPLAY)."; \
			echo "       Use 'make start-headless' for a terminal-only session."; \
			exit 1; \
		fi; \
		echo ">> Starting Pharo UI on port $(PORT)..."; \
		nohup $(VM_UI) $(IMAGE) eval --no-quit \
			"PosternServer startOn: $(PORT)" \
			> $(LOG_FILE) 2>&1 < /dev/null & \
		echo $$! > $(PID_FILE); \
		for i in $$(seq 1 30); do \
			if $(HEALTHCHECK) >/dev/null 2>&1; then \
				echo "  ok Eval server ready on port $(PORT)"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		rm -f $(PID_FILE); \
		echo "  FAIL Server did not start. Check $(LOG_FILE)"; \
		exit 1; \
	fi

start-headless: $(SETUP_STAMP)
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "Pharo already running (PID $$(cat $(PID_FILE)))"; \
	else \
		echo ">> Starting Pharo headlessly on port $(PORT)..."; \
		nohup $(VM) $(IMAGE) eval --no-quit \
			"PosternServer startOn: $(PORT)" \
			> $(LOG_FILE) 2>&1 < /dev/null & \
		echo $$! > $(PID_FILE); \
		for i in $$(seq 1 30); do \
			if $(HEALTHCHECK) >/dev/null 2>&1; then \
				echo "  ok Eval server ready on port $(PORT)"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		rm -f $(PID_FILE); \
		echo "  FAIL Server did not start. Check $(LOG_FILE)"; \
		exit 1; \
	fi

start-ui: start

stop:
	@collect_descendants() { \
		pending="$$1"; \
		while [ -n "$$pending" ]; do \
			set -- $$pending; \
			current="$$1"; \
			shift; \
			pending="$$*"; \
			for next_pid in $$(pgrep -P "$$current" 2>/dev/null || true); do \
				printf '%s\n' "$$next_pid"; \
				pending="$$pending $$next_pid"; \
			done; \
		done; \
	}; \
	TARGETS=""; \
	if [ -f $(PID_FILE) ]; then \
		PID=$$(cat $(PID_FILE)); \
		if kill -0 $$PID 2>/dev/null; then \
			echo ">> Stopping Pharo (PID $$PID)..."; \
			TARGETS="$$(collect_descendants "$$PID") $$PID"; \
		fi; \
	fi; \
	if [ -z "$$TARGETS" ]; then \
		PATTERN="$(SERVER_PATTERN)"; \
		TARGETS="$$(pgrep -f "$$PATTERN" 2>/dev/null || true)"; \
		if [ -n "$$TARGETS" ]; then \
			echo ">> Stopping Postern processes matching this repo's image..."; \
		fi; \
	fi; \
	for TARGET in $$TARGETS; do \
		[ -n "$$TARGET" ] || continue; \
		echo ">> Killing Postern process (PID $$TARGET)..."; \
		kill $$TARGET 2>/dev/null || true; \
	done; \
	sleep 1; \
	for TARGET in $$TARGETS; do \
		[ -n "$$TARGET" ] || continue; \
		kill -0 $$TARGET 2>/dev/null && kill -9 $$TARGET 2>/dev/null || true; \
	done; \
	rm -f $(PID_FILE); \
	echo "  ok Stopped"

rebuild: stop clean-image setup
	@echo "  ok Fresh image rebuilt"

# ── Development ────────────────────────────────────────

filein:
	@echo ">> Reloading Tonel packages..."
	@$(CURL) -d "$(LOAD_PACKAGES_EXPR)"
	@echo ""

eval:
	@if [ -t 0 ]; then echo "Type Smalltalk, Ctrl-D to send:"; fi
	@$(CURL) -d @- || echo "Error: is the server running? (make start for GUI, or make start-headless)"

test:
	@echo ">> Running Postern tests..."
	@$(CURL) -d \
		"| suite result | \
		suite := TestSuite new. \
		(Smalltalk globals allClasses select: [ :c | \
			(c includesBehavior: TestCase) and: [ \
				(c package name endsWith: '-Tests') and: [ \
					c package name beginsWith: 'Postern-' ] ] ]) \
			do: [ :cls | suite addTests: cls buildSuite tests ]. \
		suite tests ifEmpty: [ 'No test classes found' ] \
			ifNotEmpty: [ \
				result := suite run. \
				'Tests: ', result runCount printString, \
				'  Passed: ', result passedCount printString, \
				'  Failures: ', result failureCount printString, \
				'  Errors: ', result errorCount printString ]"
	@echo ""

status:
	@echo ">> Checking eval server on port $(PORT)..."
	@$(CURL) -d \
		"| classes | \
		classes := Smalltalk globals allClasses select: [ :c | \
			c package name beginsWith: 'Postern-' ]. \
		'alive -- ', classes size printString, ' Postern classes loaded'" \
		&& echo "" || echo "Not responding on port $(PORT)."

lint:
	@echo ">> Linting Postern classes..."
	@$(CURL) -d \
		"| classes results | \
		classes := Smalltalk globals allClasses select: [ :c | \
			(c package name beginsWith: 'Postern') or: [ \
				c package name beginsWith: 'BaselineOfPostern' ] ]. \
		results := OrderedCollection new. \
		classes do: [ :cls | \
			| findings methods | \
			methods := cls methods asOrderedCollection. \
			methods addAll: cls class methods. \
			findings := OrderedCollection new. \
			methods do: [ :m | \
				m critiques do: [ :c | \
					findings add: (m methodClass name, ' >> #', m selector, ': ', c rule name) ] ]. \
			cls critiques do: [ :c | \
				findings add: (cls name, ': ', c rule name) ]. \
			findings ifEmpty: [ results add: cls name, ': clean' ] \
				ifNotEmpty: [ results addAll: findings ] ]. \
		results ifEmpty: [ 'No Postern classes found' ] \
			ifNotEmpty: [ String cr join: results ]"
	@echo ""

check: check-packages
	@RESULT=$$($(CURL) -d \
		"| repo diff | \
		repo := IceRepository registry detect: [ :r | r name = 'postern' ] ifNone: [ nil ]. \
		repo ifNil: [ 'ERROR: no repo registered' ] ifNotNil: [ \
			diff := repo workingCopyDiff. \
			diff isEmpty ifTrue: [ 'clean' ] ifFalse: [ 'DIRTY' ] ]" \
		2>/dev/null) || RESULT="UNREACHABLE"; \
		case "$$RESULT" in \
			*clean*) echo "  ok Iceberg working copy clean" ;; \
			*DIRTY*) echo "  FAIL Iceberg has uncommitted image changes — commit via Iceberg before pushing"; exit 1 ;; \
			UNREACHABLE) echo "  FAIL eval server not responding — start with make start (GUI) or make start-headless"; exit 1 ;; \
			*) echo "  FAIL unexpected: $$RESULT"; exit 1 ;; \
		esac

check-packages:
	@echo ">> Checking package completeness..."
	@RESULT=$$($(CURL) -d \
		"| dir expected loaded missing | \
		dir := '$(SRC_DIR)' asFileReference. \
		expected := ((dir children select: [ :d | d isDirectory and: [ (d / 'package.st') exists ] ]) collect: [ :d | d basename ]) asSet. \
		loaded := (Smalltalk globals allClasses select: [ :c | \
			c package name beginsWith: 'Postern-' ]) \
			collect: [ :c | c package name ] as: Set. \
		missing := expected difference: loaded. \
		missing isEmpty \
			ifTrue: [ 'OK:', expected size printString, ' packages on disk, all loaded in image' ] \
			ifFalse: [ 'MISSING:', (', ' join: missing sorted) ]" \
		2>/dev/null) || RESULT="UNREACHABLE"; \
		case "$$RESULT" in \
			*OK*) echo "  ok $$RESULT" ;; \
			*MISSING*) echo "  FAIL Packages on disk but not loaded in image: $$RESULT"; exit 1 ;; \
			UNREACHABLE) echo "  FAIL eval server not responding — start with make start (GUI) or make start-headless"; exit 1 ;; \
			*) echo "  FAIL unexpected: $$RESULT"; exit 1 ;; \
		esac

transcript:
	@$(CURL) -d "Transcript contents" || echo "Error: is the server running? (make start for GUI, or make start-headless)"

# ── Clean ──────────────────────────────────────────────

clean-image:
	rm -f $(IMAGE) $(CHANGES) $(PID_FILE) $(LOG_FILE)
	rm -f $(BOOTSTRAP_SCRIPT) $(SETUP_STAMP)
	rm -f $(IMAGE_DIR)/.pharo-bootstrap
	rm -f $(IMAGE_DIR)/PharoDebug.log
	@echo "  ok Image removed"

clean:
	$(MAKE) stop 2>/dev/null || true
	rm -rf $(IMAGE_DIR) $(PID_FILE) $(LOG_FILE)
	rm -f PharoDebug.log
	@echo "  ok Clean"
