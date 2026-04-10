"
Tests for PosternDashboardModel domain model.
"
Class {
	#name : 'PosternDashboardModelTest',
	#superclass : 'TestCase',
	#instVars : [
		'model'
	],
	#category : 'Postern-Dashboard-Tests',
	#package : 'Postern-Dashboard-Tests'
}

{ #category : 'running' }
PosternDashboardModelTest >> setUp [
	super setUp.
	model := PosternDashboardModel new
]

{ #category : 'tests' }
PosternDashboardModelTest >> testAnnouncesLogEntries [
	"Round 7: the model announcer is the logger announcer. handleEvent:
	announces directly on that announcer. No subscribe-to-restart dance
	needed; the local fallback logger receives the synthetic event and
	the subscriber sees it on the same announcer."

	| received |
	received := OrderedCollection new.
	model announcer
		when: PosternRequest
		do: [ :e | received add: e ]
		for: self.
	model logger handleEvent: (PosternRequestLoggerTest new
		newEventMethod: 'POST'
		path: '/repl'
		body: 'x'
		status: 200).
	self assert: received size equals: 1
]

{ #category : 'tests' }
PosternDashboardModelTest >> testClearLog [
	model logger entries addFirst: (PosternRequest new
		timestamp: DateAndTime now;
		method: 'GET';
		path: '/health';
		statusCode: 200;
		duration: 1;
		yourself).
	self assert: model logger entries size equals: 1.
	model clearLog.
	self assert: model logger entries isEmpty
]

{ #category : 'tests' }
PosternDashboardModelTest >> testCopyAuthTokenToClipboardNoServer [
	"Should not error when no server."
	model copyAuthTokenToClipboard
]

{ #category : 'tests' }
PosternDashboardModelTest >> testFilteredEntriesEmpty [
	self assert: (model filteredEntries: '') isEmpty.
	self assert: (model filteredEntries: 'foo') isEmpty
]

{ #category : 'tests' }
PosternDashboardModelTest >> testFilteredEntriesWithData [
	| entry |
	entry := PosternRequest new
		timestamp: DateAndTime now;
		method: 'POST';
		path: '/repl';
		statusCode: 200;
		duration: 42;
		requestBody: '3 + 4';
		yourself.
	model logger entries addFirst: entry.
	self assert: (model filteredEntries: '') size equals: 1.
	self assert: (model filteredEntries: 'repl') size equals: 1.
	self assert: (model filteredEntries: 'zzz') isEmpty
]

{ #category : 'tests' }
PosternDashboardModelTest >> testInitialize [
	self deny: model hasServer.
	self deny: model isRunning.
	self assert: model port equals: 0.
	self assert: model requestCount equals: 0.
	self assert: model authToken isNil.
	self assert: model uptimeString equals: '--'.
	self deny: model isPaused.
	self assert: model logger isNotNil
]

{ #category : 'tests' }
PosternDashboardModelTest >> testTogglePause [
	self deny: model isPaused.
	model togglePause.
	self assert: model isPaused.
	model togglePause.
	self deny: model isPaused
]
