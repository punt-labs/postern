"
A Spec2 presenter for monitoring the Postern eval server. Coordinates sub-presenters around a shared PosternDashboardModel.

### Opening

    PosternDashboard open.                          ""finds running server automatically — opens new window each time""
    PosternDashboard openOn: (PosternDashboardModel on: aZnServer).  ""monitor a specific server""

### Architecture

The dashboard is a view. Multiple instances are allowed — like the System Browser, each window is independent and owns its own resources (logger subscription, refresh process). Closing one window cleans up only that window's resources; other dashboards keep running.

Domain state lives in PosternDashboardModel, which is shared with PosternStatusPresenter and PosternRequestDetailPresenter via the Spec2 on: model pattern. The dashboard owns the log table, filter, toolbar, and refresh lifecycle.

### Cascade prevention (2026-04-06 COE)

The original design had a class-side Default singleton. Rounds 1-4b built workarounds on top of it; Round 5 removed it. The cascade root cause was leaked subscriptions on the singleton slot — without a singleton there is nothing to leak at the class level. Each window's lifecycle is self-contained. The exception-safety safely:describe: wrapping in windowClosed stays — it remains load-bearing regardless of the singleton question.
"
Class {
	#name : 'PosternDashboard',
	#superclass : 'SpPresenter',
	#instVars : [
		'model',
		'statusPresenter',
		'logTable',
		'detailPresenter',
		'filterInput',
		'pauseButton',
		'refreshProcess',
		'headless'
	],
	#category : 'Postern-Dashboard',
	#package : 'Postern-Dashboard'
}

{ #category : 'private' }
PosternDashboard class >> findServer [
	"Find a running eval server. Scans living ZnServer instances for one
	with a PosternDelegate. Returns nil if none found."
	^ ZnServer allSubInstances "not all servers are registered"
		detect: [ :s | s isRunning and: [ s delegate class == PosternDelegate ] ]
		ifNone: [ nil ]
]

{ #category : 'instance creation' }
PosternDashboard class >> headlessOnModel: aPosternDashboardModel [
	"Build a dashboard wired to aPosternDashboardModel without starting the
	logger or forking the refresh process. For tests and offline
	introspection only — production callers use #openOn: / #open which
	go through the normal updatePresenter path."
	^ self basicNew
		setHeadlessBeforeInitialization;
		setModelBeforeInitialization: aPosternDashboardModel;
		initialize;
		yourself
]

{ #category : 'world menu' }
PosternDashboard class >> menuCommandOn: aBuilder [
	<worldMenu>
	(aBuilder item: #Postern)
		label: 'Postern';
		order: 50.
	(aBuilder item: #PosternDashboard)
		parent: #Postern;
		label: 'Dashboard';
		action: [ self open ];
		icon: (self iconNamed: #smallInspectIt);
		help: 'Open the Postern dashboard with traffic monitor'
]

{ #category : 'instance creation' }
PosternDashboard class >> onModel: aPosternDashboardModel [
	"Internal constructor used by #openOn: — builds a dashboard wired
	to aPosternDashboardModel WITHOUT calling open on the window. #openOn:
	sends #open to the result; that is when Spec2's updatePresenter
	chain fires and the logger + refresh process start.

	Tests MUST NOT call this directly. Use headlessOnModel: instead —
	that sets the headless flag so updatePresenter short-circuits and
	no logger or refresh process leaks into the test image. See bead
	0ig and docs/coes/2026-04-06-dashboard-cascade.md for why."

	^ self basicNew
		setModelBeforeInitialization: aPosternDashboardModel;
		initialize;
		yourself
]

{ #category : 'instance creation' }
PosternDashboard class >> open [
	"Find a running PosternServer and open a dashboard window
	observing it. Multiple windows are allowed — each is independent
	like a System Browser. Returns the new dashboard, or nil if the
	user declined to start a server.

	0 servers: confirm dialog 'No eval server running. Start one?'
	   — if yes, start one on the default port and attach
	   — if no, return nil
	1 server: open a new dashboard observing it
	N servers: chooseFrom: dialog of port labels"

	| servers chosen |
	servers := ZnServer allSubInstances
		select: [ :s |
			s isRunning and: [ s delegate class == PosternDelegate ] ].
	servers ifEmpty: [
		(UIManager default
			confirm: 'No eval server is running. Start one on port 8422?')
				ifFalse: [ ^ nil ].
		PosternServer startOn: 8422.
		^ self openOn: (PosternDashboardModel on: self findServer) ].
	servers size = 1 ifTrue: [
		^ self openOn: (PosternDashboardModel on: servers first) ].
	chosen := UIManager default
		chooseFrom: (servers collect: [ :s | 'port ', s port printString ])
		values: servers
		title: 'Multiple eval servers running — choose one'.
	chosen ifNil: [ ^ nil ].
	^ self openOn: (PosternDashboardModel on: chosen)
]

{ #category : 'instance creation' }
PosternDashboard class >> openOn: aPosternDashboardModel [
	"Open a dashboard observing the given PosternDashboardModel. Multiple
	dashboards may observe the same or different models at the same
	time — each window is independent, System Browser style. Returns
	the constructed presenter; the window is reachable via #window."

	| presenter window |
	presenter := self onModel: aPosternDashboardModel.
	window := presenter open.
	window whenClosedDo: [ presenter windowClosed ].
	^ presenter
]

{ #category : 'accessing' }
PosternDashboard >> authTokenLabel [
	"Delegate to status presenter."
	^ statusPresenter authTokenLabel
]

{ #category : 'initialization' }
PosternDashboard >> buildToolbar [
	| toolbar |
	toolbar := self newToolbar.
	pauseButton := SpToolbarToggleButtonPresenter new
		label: 'Pause';
		icon: (self iconNamed: #stop);
		help: 'Pause/resume log capture';
		whenToggledDo: [ self togglePause ];
		yourself.
	toolbar addItem: pauseButton.
	toolbar addItem: (SpToolbarButtonPresenter new
		label: 'Clear';
		icon: (self iconNamed: #smallDelete);
		help: 'Clear all log entries';
		action: [ self clearLog ];
		yourself).
	toolbar addItem: (SpToolbarButtonPresenter new
		label: 'Copy Auth Token';
		icon: (self iconNamed: #smallCopy);
		help: 'Copy the auth token to clipboard';
		action: [ model copyAuthTokenToClipboard ];
		yourself)
		position: SpToolbarItemPosition right.
	toolbar addItem: (SpToolbarButtonPresenter new
		label: 'Show Auth Token';
		icon: (self iconNamed: #smallInspectIt);
		help: 'Show or hide the auth token';
		action: [ statusPresenter toggleAuthToken ];
		yourself)
		position: SpToolbarItemPosition right.
	toolbar beBoth.
	^ toolbar
]

{ #category : 'actions' }
PosternDashboard >> clearLog [
	model ifNil: [ ^ self ].
	model clearLog.
	self refreshLogTable.
	detailPresenter ifNotNil: [ detailPresenter clear ]
]

{ #category : 'initialization' }
PosternDashboard >> connectPresenters [
	logTable whenSelectionChangedDo: [ :selection |
		detailPresenter showEntry: selection selectedItem ].
	filterInput whenTextChangedDo: [ :text | self refreshLogTable ]
]

{ #category : 'actions' }
PosternDashboard >> copyAuthToken [
	"Delegate to model."
	model copyAuthTokenToClipboard
]

{ #category : 'layout' }
PosternDashboard >> defaultLayout [
	^ SpBoxLayout newTopToBottom
		spacing: 4;
		add: statusPresenter expand: false;
		add: (SpPanedLayout newTopToBottom
			positionOfSlider: 65 percent;
			add: logTable;
			add: detailPresenter;
			yourself);
		add: filterInput expand: false;
		yourself
]

{ #category : 'api - focus' }
PosternDashboard >> defaultKeyboardFocus [
	"Start keyboard focus in the filter field when the dashboard opens."
	^ filterInput
]

{ #category : 'accessing' }
PosternDashboard >> detailPresenter [
	"Exposed for testing."
	^ detailPresenter
]

{ #category : 'accessing' }
PosternDashboard >> filterInput [
	"Exposed for testing."
	^ filterInput
]

{ #category : 'private' }
PosternDashboard >> findServer [
	"Delegate to class side."
	^ self class findServer
]

{ #category : 'initialization' }
PosternDashboard >> initializeLogTable [
	logTable
		addColumn: ((SpStringTableColumn title: 'Time' evaluated: #timeString) width: 80; yourself);
		addColumn: ((SpStringTableColumn title: 'Method' evaluated: #method) width: 60; yourself);
		addColumn: ((SpStringTableColumn title: 'Path' evaluated: #path) width: 120; yourself);
		addColumn: ((SpStringTableColumn title: 'Status' evaluated: [ :e | e statusCode printString ])
			displayColor: [ :e | e statusColor ];
			width: 60;
			yourself);
		addColumn: ((SpStringTableColumn title: 'Duration' evaluated: [ :e | e duration printString, 'ms' ]) width: 70; yourself);
		addColumn: (SpStringTableColumn title: 'Body' evaluated: #bodySnippet);
		beResizable
]

{ #category : 'initialization' }
PosternDashboard >> initializePresenters [
	"Refuse to initialize without a pre-set model. The COE on
	2026-04-06 traced the cascade to this method silently lazy-creating
	a model with no server when constructed via 'new', then attaching a
	logger to ZnLogEvent that nothing owned. Force the openOn:/onModel:
	path so callers must supply a model."
	model ifNil: [
		self error: 'PosternDashboard requires a model. Use openOn: or onModel:, not new.' ].
	headless ifNil: [ headless := false ].
	statusPresenter := self instantiate: PosternStatusPresenter on: model.
	detailPresenter := self instantiate: PosternRequestDetailPresenter on: model.
	logTable := self newTable.
	self initializeLogTable.
	filterInput := self newTextInput.
	filterInput placeholder: 'Filter...'
]

{ #category : 'initialization' }
PosternDashboard >> initializeWindow: aWindowPresenter [
	super initializeWindow: aWindowPresenter.
	aWindowPresenter
		title: 'Postern Dashboard';
		initialExtent: 900 @ 700;
		toolbar: self buildToolbar
]

{ #category : 'testing' }
PosternDashboard >> isRefreshProcessAlive [
	"True if this dashboard's refresh process has been forked and has
	not terminated. Used by tests to verify per-window cleanup
	invariants on windowClosed."
	^ refreshProcess notNil and: [ refreshProcess isTerminated not ]
]

{ #category : 'accessing' }
PosternDashboard >> logTable [
	"Exposed for testing."
	^ logTable
]

{ #category : 'accessing' }
PosternDashboard >> logger [
	"Delegate to model."
	^ model logger
]

{ #category : 'accessing' }
PosternDashboard >> model [
	^ model
]

{ #category : 'updating' }
PosternDashboard >> onNewLogEntry: anEntry [
	model ifNil: [ ^ self ].
	self defer: [ self refreshLogTable ]
]

{ #category : 'actions' }
PosternDashboard >> refreshAll [
	statusPresenter refresh.
	self refreshLogTable
]

{ #category : 'actions' }
PosternDashboard >> refreshLogTable [
	| filterText |
	model ifNil: [ ^ self ].
	filterText := filterInput text ifNil: [ '' ].
	logTable items: (model filteredEntries: filterText)
]

{ #category : 'private' }
PosternDashboard >> safely: aBlock describe: aStepName [
	"Run aBlock. On any Error, log to Transcript with aStepName for
	diagnostics and swallow the exception. Used by windowClosed to
	guarantee no exception escapes the close handler — see COE at
	docs/coes/2026-04-06-dashboard-cascade.md."

	[ aBlock value ] on: Error do: [ :ex |
		Transcript
			show: 'PosternDashboard windowClosed: ';
			show: aStepName;
			show: ' raised ';
			show: ex class name;
			show: ' — ';
			show: (ex messageText ifNil: [ '' ]);
			show: ' (swallowed; cascade prevention)';
			cr ]
]

{ #category : 'accessing' }
PosternDashboard >> server [
	"Delegate to model."
	^ model server
]

{ #category : 'accessing' }
PosternDashboard >> server: aZnServer [
	"Set the server on the model."
	model server: aZnServer
]

{ #category : 'initialization' }
PosternDashboard >> setHeadlessBeforeInitialization [
	"Mark this dashboard as headless. Sent by headlessOnModel: BEFORE
	initialize so that updatePresenter short-circuits and no Morphic /
	logger / refresh process side effects fire. Tests only."
	headless := true
]

{ #category : 'accessing - model' }
PosternDashboard >> setModelBeforeInitialization: aPosternDashboardModel [
	model := aPosternDashboardModel
]

{ #category : 'lifecycle' }
PosternDashboard >> startRefreshProcess [
	self stopRefreshProcess.
	refreshProcess := [
		[ true ] whileTrue: [
			2 seconds wait.
			self defer: [ statusPresenter refresh ] ] ] forkAt: 30 named: 'PosternDashboard refresh'
]

{ #category : 'actions' }
PosternDashboard >> startServer [
	"Start a new eval server on port 8422 with auth enabled."
	model server: (PosternServer startOn: 8422 withAuth: true).
	statusPresenter refresh
]

{ #category : 'accessing' }
PosternDashboard >> statusLabel [
	"Delegate to status presenter."
	^ statusPresenter statusLabel
]

{ #category : 'accessing' }
PosternDashboard >> statusPresenter [
	"Exposed for testing."
	^ statusPresenter
]

{ #category : 'lifecycle' }
PosternDashboard >> stopRefreshProcess [
	refreshProcess ifNotNil: [
		refreshProcess terminate.
		refreshProcess := nil ]
]

{ #category : 'actions' }
PosternDashboard >> toggleAuthToken [
	"Delegate to status presenter."
	statusPresenter toggleAuthToken
]

{ #category : 'actions' }
PosternDashboard >> togglePause [
	model ifNil: [ ^ self ].
	model togglePause.
	model isPaused
		ifTrue: [
			pauseButton ifNotNil: [
				pauseButton label: 'Resume'.
				pauseButton icon: (self iconNamed: #glamorousGo) ] ]
		ifFalse: [
			pauseButton ifNotNil: [
				pauseButton label: 'Pause'.
				pauseButton icon: (self iconNamed: #stop) ] ]
]

{ #category : 'initialization' }
PosternDashboard >> updatePresenter [
	"Wire this view to the shared logger. The logger is owned by the
	server delegate and lives independently of any window — we only
	subscribe this view's presenter to its announcer for refresh
	notifications. Round 7: System Browser pattern."
	headless ifTrue: [ ^ self ].
	statusPresenter refresh.
	self refreshLogTable.
	model logger announcer
		when: PosternRequest
		send: #onNewLogEntry:
		to: self.
	self startRefreshProcess
]

{ #category : 'updating' }
PosternDashboard >> updateStatus [
	"Delegate to status presenter."
	statusPresenter refresh
]

{ #category : 'updating' }
PosternDashboard >> updateUptime [
	"No longer needed -- handled by status presenter refresh."
	"kept for compatibility"
]

{ #category : 'lifecycle' }
PosternDashboard >> windowClosed [
	"Cleanup on window close. Cascade-prevention invariant: this method
	MUST NOT raise into Morphic. Every cleanup step is individually
	exception-guarded because a raised exception from a close handler
	is the exact trigger for the 2026-04-06 debugger-storm cascade.

	Round 7: the shared logger is owned by the server delegate, not by
	this window. windowClosed only releases this view resources —
	the refresh process and the announcer subscription. The logger
	itself keeps running with the server."
	self safely: [ self stopRefreshProcess ] describe: 'stopRefreshProcess'.
	self safely: [
		model ifNotNil: [
			model logger announcer unsubscribe: self ] ] describe: 'unsubscribe view from logger'
]
