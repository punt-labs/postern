"
Checks the Postern observability consumer boundary, including diagnostic payloads and the closed telemetry schemas.
"
Class {
	#name : 'PosternObservabilityTest',
	#superclass : 'TestCase',
	#category : 'Postern-Observe-Tests',
	#package : 'Postern-Observe-Tests'
}

{ #category : 'tests' }
PosternObservabilityTest >> testCounterSchemas [
	{ PosternServerStartedV1. PosternRequestCountV1. PosternEvalCountV1 } do: [ :schema |
		schema validateDefinition.
		self assert: schema schemaVersion equals: 1.
		self assert: schema signalKind equals: #counter.
		self assert: schema unit equals: '1' ]
]

{ #category : 'tests' }
PosternObservabilityTest >> testEvalSignalRetainsOnlyExceptionClass [
	| signal record |
	signal := PosternEvalSignal new
		message: 'Evaluation failed';
		error: (Error new messageText: 'private evaluation contents');
		yourself.
	record := PuntLogFormatter new format: signal.
	self assert: (record includesSubstring: 'errorClass=Error').
	self deny: (record includesSubstring: 'private evaluation contents').
	self assert: signal level equals: PuntLogLevel debug
]

{ #category : 'tests' }
PosternObservabilityTest >> testInitializePreservesRunningServer [
	| server pool state |
	pool := PosternObservability classPool.
	server := PosternServer startOn: 0.
	[ state := #(Guard ActiveServers OwnsLog OwnsTelemetry Bridge)
		collect: [ :key | pool at: key ].
	  PosternObservability initialize.
	  self assert: (#(Guard ActiveServers OwnsLog OwnsTelemetry Bridge)
		collect: [ :key | pool at: key ]) equals: state ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternObservabilityTest >> testOnlyClosedRouteNamesAreClassified [
	| delegate |
	delegate := PosternDelegate new.
	self assert: (delegate routeForSegment: 'repl') equals: #repl.
	self assert: (delegate routeForSegment: 'health') equals: #health.
	self assert: (delegate routeForSegment: 'help') equals: #help.
	self assert: (delegate routeForSegment: 'private-account') equals: #other
]

{ #category : 'tests' }
PosternObservabilityTest >> testRepeatedPreparationAttachesObserverOnlyOnce [
	| delegate activeServers before |
	delegate := PosternDelegate new.
	activeServers := [ PosternObservability classPool at: #ActiveServers ].
	before := activeServers value.
	[ delegate prepareToStart.
	  delegate prepareToStart.
	  self assert: activeServers value equals: before + 1 ]
		ensure: [ delegate close ].
	self assert: activeServers value equals: before
]

{ #category : 'tests' }
PosternObservabilityTest >> testRequestSchemaRejectsArbitraryPathsAndStatusStrings [
	self should: [
		(PosternRequestCountV1 new route: '/repl/private'; status: #success) asRecordAt: nil ]
		raise: Error.
	self should: [
		(PosternRequestCountV1 new route: #repl; status: 'clientError') asRecordAt: nil ]
		raise: Error.
	self assert: ((PosternRequestCountV1 new route: #repl; status: #clientError)
		asRecordAt: nil) attributes keys asSet equals: #('route' 'status' 'punt.schema.version') asSet
]

{ #category : 'tests' }
PosternObservabilityTest >> testRestartReattachesObserver [
	| server activeServers before |
	activeServers := [ PosternObservability classPool at: #ActiveServers ].
	before := activeServers value.
	server := PosternServer startOn: 0.
	[ self assert: activeServers value equals: before + 1.
	  server stop.
	  self assert: activeServers value equals: before.
	  server start.
	  self assert: activeServers value equals: before + 1.
	  server start.
	  self assert: activeServers value equals: before + 1 ]
		ensure: [ server stop ].
	self assert: activeServers value equals: before
]

{ #category : 'tests' }
PosternObservabilityTest >> testSourceBoundaries [
	self assert: (PuntLogSourceGate
		violationsInPackages: #('Postern-Core' 'Postern-Observe' 'Postern-Dashboard' 'Postern-IcebergExtensions')
		allowing: #(PosternObservability PosternRequestLogger)) isEmpty
]
