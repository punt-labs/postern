# postern — Remote image driver for Pharo
#
# Image lifecycle:
#   make setup      — download Pharo VM + image, load all packages
#   make start      — launch Pharo with eval server on :8422
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
IMAGE := $(IMAGE_DIR)/Pharo.image
CHANGES := $(IMAGE_DIR)/Pharo.changes
VM := $(IMAGE_DIR)/pharo
VM_UI := $(IMAGE_DIR)/pharo-ui
PID_FILE := $(CURDIR)/.pharo.pid
LOG_FILE := $(CURDIR)/.pharo.log
SRC_DIR := $(CURDIR)/src
URL := http://localhost:$(PORT)/repl
CURL := curl -s -X POST $(URL) -H "Content-Type: text/plain"

# Tonel packages — auto-discovered from src/ directories containing package.st.
# Load order: production packages in dependency order, then test packages.
LOAD_PACKAGES_EXPR := | dir allPkgs priority sorted lfCount | dir := '$(SRC_DIR)' asFileReference. IceRepository registry detect: [ :r | r name = 'postern' ] ifNone: [ | r | r := IceRepositoryCreator new location: '$(CURDIR)' asFileReference; createRepository. r register. r ]. allPkgs := (dir children select: [ :d | d isDirectory and: [ (d / 'package.st') exists ] ]) collect: [ :d | d basename ]. priority := Dictionary new. priority at: 'Postern-Core' put: 10. priority at: 'Postern-Dashboard' put: 15. priority at: 'Postern-IcebergExtensions' put: 15. priority at: 'BaselineOfPostern' put: 20. sorted := allPkgs sorted: [ :a :b | | pa pb | pa := (a endsWith: '-Tests') ifTrue: [ 100 ] ifFalse: [ priority at: a ifAbsent: [ 50 ] ]. pb := (b endsWith: '-Tests') ifTrue: [ 100 ] ifFalse: [ priority at: b ifAbsent: [ 50 ] ]. pa = pb ifTrue: [ a < b ] ifFalse: [ pa < pb ] ]. sorted do: [ :name | | reader version | Transcript show: 'Loading package: ', name; cr. reader := TonelReader on: dir fileName: name. version := reader version. MCPackageLoader installSnapshot: version snapshot ]. lfCount := 0. Smalltalk globals allClasses do: [ :cls | (cls package name beginsWith: 'Postern') ifTrue: [ (cls methods, cls class methods) do: [ :m | | src | src := m sourceCode. (src includesSubstring: String lf) ifTrue: [ cls compile: (src copyReplaceAll: String lf with: String cr) classified: m protocolName. lfCount := lfCount + 1 ] ] ] ]. 'Loaded ', sorted size printString, ' packages, normalized ', lfCount printString, ' methods'

.PHONY: setup start stop save rebuild filein eval test status lint check check-packages transcript clean clean-image

# ── Setup ──────────────────────────────────────────────

$(IMAGE_DIR):
	mkdir -p $(IMAGE_DIR)

$(VM): | $(IMAGE_DIR)
	@echo ">> Downloading Pharo $(PHARO_VERSION)..."
	cd $(IMAGE_DIR) && curl -fsSL https://get.pharo.org/64/$(PHARO_VERSION)+vm | bash
	@echo "  ok Pharo downloaded"

$(IMAGE): $(VM)
	@echo ">> Downloading fresh Pharo $(PHARO_VERSION) image..."
	cd $(IMAGE_DIR) && curl -fsSL http://files.pharo.org/get-files/$(PHARO_VERSION)/pharoImage-x86_64.zip -o image.zip \
		&& unzip -o image.zip \
		&& mv Pharo*.image Pharo.image \
		&& mv Pharo*.changes Pharo.changes \
		&& rm -f image.zip
	@echo "  ok Fresh image ready"

setup: $(IMAGE)
	@echo ">> Loading Tonel packages into image..."
	$(VM) --headless $(IMAGE) eval --save "$(LOAD_PACKAGES_EXPR)"
	@echo "  ok All packages loaded and image saved"

# ── Run ────────────────────────────────────────────────

start: $(VM)
	@if [ -f $(PID_FILE) ] && kill -0 $$(cat $(PID_FILE)) 2>/dev/null; then \
		echo "Pharo already running (PID $$(cat $(PID_FILE)))"; \
	else \
		echo ">> Starting Pharo on port $(PORT)..."; \
		DISPLAY=$${DISPLAY:-:1} $(IMAGE_DIR)/pharo-vm/pharo $(IMAGE) eval --no-quit \
			"PosternServer startOn: $(PORT)" \
			> $(LOG_FILE) 2>&1 & \
		echo $$! > $(PID_FILE); \
		for i in $$(seq 1 30); do \
			if $(CURL) -d "'ready'" >/dev/null 2>&1; then \
				echo "  ok Eval server ready on port $(PORT)"; \
				exit 0; \
			fi; \
			sleep 1; \
		done; \
		echo "  FAIL Server did not start. Check $(LOG_FILE)"; \
		exit 1; \
	fi

stop:
	@if [ -f $(PID_FILE) ]; then \
		PID=$$(cat $(PID_FILE)); \
		if kill -0 $$PID 2>/dev/null; then \
			echo ">> Stopping Pharo (PID $$PID)..."; \
			sleep 1; \
			kill $$PID 2>/dev/null || true; \
			sleep 2; \
			kill -0 $$PID 2>/dev/null && kill -9 $$PID 2>/dev/null || true; \
		fi; \
		rm -f $(PID_FILE); \
	fi; \
	sleep 1; \
	for ORPHAN in $$(pgrep -x pharo 2>/dev/null); do \
		echo ">> Killing orphan VM (PID $$ORPHAN)..."; \
		kill $$ORPHAN 2>/dev/null || true; \
		sleep 1; \
		kill -0 $$ORPHAN 2>/dev/null && kill -9 $$ORPHAN 2>/dev/null || true; \
	done; \
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
	@$(CURL) -d @- || echo "Error: is the server running? (make start)"

test:
	@echo ">> Running Postern tests..."
	@$(CURL) -d \
		"| suite result | \
		suite := TestSuite new. \
		(Smalltalk globals allClasses select: [ :c | \
			(c includesBehavior: TestCase) and: [ \
				c package name endsWith: '-Tests' ] and: [ \
				c package name beginsWith: 'Postern-' ] ]) \
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
		UNREACHABLE) echo "  FAIL eval server not responding — start with make start"; exit 1 ;; \
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
		UNREACHABLE) echo "  FAIL eval server not responding — start with make start"; exit 1 ;; \
		*) echo "  FAIL unexpected: $$RESULT"; exit 1 ;; \
	esac

transcript:
	@$(CURL) -d "Transcript contents" || echo "Error: is the server running? (make start)"

# ── Clean ──────────────────────────────────────────────

clean-image:
	rm -f $(IMAGE) $(CHANGES) $(PID_FILE) $(LOG_FILE)
	rm -f $(IMAGE_DIR)/PharoDebug.log
	@echo "  ok Image removed"

clean:
	$(MAKE) stop 2>/dev/null || true
	rm -rf $(IMAGE_DIR) $(PID_FILE) $(LOG_FILE)
	rm -f PharoDebug.log
	@echo "  ok Clean"
