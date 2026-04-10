"
Tests for PosternDashboard Spec2 presenter. Tests the presenter model without opening windows where possible, and carefully cleans up when windows must be opened.
"
Class {
	#name : 'PosternDashboardTest',
	#superclass : 'TestCase',
	#instVars : [
		'dashboard'
	],
	#category : 'Postern-Dashboard-Tests',
	#package : 'Postern-Dashboard-Tests'
}

{ #category : 'helpers' }
PosternDashboardTest >> addEntryToLogger: anEntry [
	"Add an entry directly to the model's logger buffer for testing."
	dashboard model logger entries addFirst: anEntry
]

{ #category : 'helpers' }
PosternDashboardTest >> newEntry: bodyString [
	^ PosternRequest new
		timestamp: DateAndTime now;
		method: 'POST';
		path: '/repl';
		statusCode: 200;
		duration: 42;
		requestBody: bodyString;
		responseBody: '7';
		yourself
]

{ #category : 'helpers' }
PosternDashboardTest >> newHealthEntry [
	^ PosternRequest new
		timestamp: DateAndTime now;
		method: 'GET';
		path: '/health';
		statusCode: 200;
		duration: 1;
		yourself
]

{ #category : 'running' }
PosternDashboardTest >> setUp [
	"Construct a dashboard via #headlessOnModel: so the test never
	touches Morphic, never starts a logger, and never forks a refresh
	process. The COE on 2026-04-06 traced cascading debugger storms to
	leaked loggers in test setUp paths — see bead 0ig."
	super setUp.
	dashboard := PosternDashboard headlessOnModel: PosternDashboardModel new
]

{ #category : 'running' }
PosternDashboardTest >> tearDown [
	"Round 7: model no longer owns startLogger/stopLogger. The local
	fallback logger used in headless construction is never started so
	it has no subscription to release. Just stop the refresh process if
	one was forked."
	dashboard ifNotNil: [
		dashboard stopRefreshProcess ].
	super tearDown
]

{ #category : 'tests' }
PosternDashboardTest >> testDefaultKeyboardFocusIsFilterInput [
	self assert: dashboard defaultKeyboardFocus identicalTo: dashboard filterInput
]

{ #category : 'tests' }
PosternDashboardTest >> testClearLog [
	self addEntryToLogger: (self newEntry: 'x').
	dashboard refreshLogTable.
	self assert: dashboard logTable items size equals: 1.
	dashboard clearLog.
	self assert: dashboard logTable items isEmpty
]

{ #category : 'tests' }
PosternDashboardTest >> testDetailPresenterFormatsCode [
	"Selecting a log entry pretty-prints the request body as Smalltalk."
	| detail |
	detail := dashboard detailPresenter.
	"formatCode: is private but we test it directly to verify formatting"
	self assert: (detail formatCode: '3+4') equals: '3 + 4'.
	self assert: (detail formatCode: 'a:=1.b:=2') equals: ('a := 1.', String cr, 'b := 2').
	"Non-Smalltalk text falls through unchanged"
	self assert: (detail formatCode: '{"error":"bad"}') equals: '{"error":"bad"}'.
	"Nil and empty"
	self assert: (detail formatCode: nil) equals: ''.
	self assert: (detail formatCode: '') equals: ''
]

{ #category : 'tests' }
PosternDashboardTest >> testFilterLogTable [
	self addEntryToLogger: (self newEntry: 'hello').
	self addEntryToLogger: self newHealthEntry.
	dashboard refreshLogTable.
	self assert: dashboard logTable items size equals: 2
]

{ #category : 'tests' }
PosternDashboardTest >> testInitializePresenters [
	self assert: dashboard model isNotNil.
	self assert: (dashboard model isKindOf: PosternDashboardModel).
	self assert: dashboard statusPresenter isNotNil.
	self assert: dashboard detailPresenter isNotNil.
	self assert: dashboard logTable isNotNil
]

{ #category : 'tests' }
PosternDashboardTest >> testRefreshLogTableShowsEntries [
	self addEntryToLogger: (self newEntry: '3 + 4').
	dashboard refreshLogTable.
	self assert: dashboard logTable items size equals: 1
]

{ #category : 'tests' }
PosternDashboardTest >> testToggleAuthTokenNoServer [
	dashboard statusPresenter toggleAuthToken.
	self assert: (dashboard statusPresenter authTokenLabel label includesSubstring: 'no server').
	dashboard statusPresenter toggleAuthToken.
	self assert: (dashboard statusPresenter authTokenLabel label includesSubstring: '********')
]

{ #category : 'tests' }
PosternDashboardTest >> testTogglePause [
	self deny: dashboard model isPaused.
	dashboard togglePause.
	self assert: dashboard model isPaused.
	dashboard togglePause.
	self deny: dashboard model isPaused
]

{ #category : 'tests' }
PosternDashboardTest >> testTwoDashboardsOnSameServerShareTheLogger [
	"Round 7 — System Browser pattern. Multiple dashboards on the same
	eval server share the underlying logger. Closing one window
	unsubscribes only that view; the logger keeps running and the
	other window keeps observing it. The load-bearing invariant is
	identity: m1 logger == m2 logger when both wrap the same server."

	| server m1 m2 d1 d2 sharedLogger |
	server := PosternDashboard findServer.
	server ifNil: [ ^ self skip: 'test requires a running eval server' ].
	m1 := PosternDashboardModel on: server.
	m2 := PosternDashboardModel on: server.
	self
		assert: m1 logger == m2 logger
		description: 'two models on the same server must share one logger'.
	d1 := PosternDashboard openOn: m1.
	d2 := PosternDashboard openOn: m2.
	[
		sharedLogger := m1 logger.
		self assert: sharedLogger isRunning.
		d1 windowClosed.
		Smalltalk garbageCollect.
		self
			assert: sharedLogger isRunning
			description: 'shared logger must survive d1 close'.
		self
			assert: m2 logger == sharedLogger
			description: 'd2 still references the same logger'
	] ensure: [
		d1 window ifNotNil: [ :w | w isClosed ifFalse: [ w close ] ].
		d2 window ifNotNil: [ :w | w isClosed ifFalse: [ w close ] ] ]
]

{ #category : 'tests' }
PosternDashboardTest >> testUpdateStatusNoServer [
	dashboard statusPresenter refresh.
	self assert: (dashboard statusPresenter statusLabel label includesSubstring: 'No Server')
]

{ #category : 'tests' }
PosternDashboardTest >> testWindowClosedReleasesViewResources [
	"Round 7 — windowClosed cleans up THIS view resources only:
	the refresh process this view forked, and this view subscription
	on the shared logger announcer. The shared logger itself is owned
	by the server delegate and keeps running."

	| server model live |
	server := PosternDashboard findServer.
	server ifNil: [ ^ self skip: 'test requires a running eval server' ].
	model := PosternDashboardModel on: server.
	live := PosternDashboard openOn: model.
	[
		self
			assert: live isRefreshProcessAlive
			description: 'view must have a running refresh process'.
		live windowClosed.
		Smalltalk garbageCollect.
		self
			deny: live isRefreshProcessAlive
			description: 'view refresh process must be terminated'.
		self
			assert: model logger isRunning
			description: 'shared logger must survive — owned by the server'
	] ensure: [
		live window ifNotNil: [ :w | w isClosed ifFalse: [ w close ] ] ]
]
