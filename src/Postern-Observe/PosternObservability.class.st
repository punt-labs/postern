"
Owns Postern observability at the HTTP server entry point. Shares one Zinc bridge and one pair of sinks across Postern servers in the same image; does not take over sinks already configured by a host tool.
"
Class {
	#name : 'PosternObservability',
	#superclass : 'Object',
	#classVars : [
		'ActiveServers',
		'Bridge',
		'Guard',
		'OwnsLog',
		'OwnsTelemetry'
	],
	#category : 'Postern-Observe',
	#package : 'Postern-Observe'
}

{ #category : 'recording' }
PosternObservability class >> authRejected [
	self emit: (PuntLogSecuritySignal new component: 'auth'; message: 'Eval token rejected')
]

{ #category : 'recording' }
PosternObservability class >> bookkeepingFailed: error [
	self recordError: error message: 'Request bookkeeping failed'
]

{ #category : 'operations' }
PosternObservability class >> close [
	self guard critical: [
		self emit: (PuntLogSignal new component: 'server'; message: 'Server stopped').
		ActiveServers := ActiveServers - 1.
		ActiveServers = 0 ifTrue: [ self stopSinks ] ]
]

{ #category : 'recording' }
PosternObservability class >> dashboardCleanupFailed: error [
	self recordError: error message: 'Dashboard logger cleanup failed'
]

{ #category : 'private' }
PosternObservability class >> emit: aSignal [
	OwnsLog ifTrue: [ aSignal emit ]
]

{ #category : 'recording' }
PosternObservability class >> evalFailed: error [
	self emit: (PosternEvalSignal new
		component: 'repl'; message: 'Evaluation failed'; error: error).
	self record: (PosternEvalCountV1 new outcome: #failed)
]

{ #category : 'recording' }
PosternObservability class >> evalSucceeded [
	self emit: (PosternEvalSignal new component: 'repl'; message: 'Evaluation succeeded').
	self record: (PosternEvalCountV1 new outcome: #succeeded)
]

{ #category : 'private' }
PosternObservability class >> guard [
	^ Guard
]

{ #category : 'class initialization' }
PosternObservability class >> initialize [
	Guard ifNotNil: [ ^ self ].
	Guard := Mutex new.
	ActiveServers := 0.
	OwnsLog := false.
	OwnsTelemetry := false
]

{ #category : 'recording' }
PosternObservability class >> malformedRequest: error [
	self emit: (PosternMalformedRequestSignal new
		component: 'http'; message: 'Malformed request'; error: error)
]

{ #category : 'operations' }
PosternObservability class >> open [
	self guard critical: [
		(ActiveServers = 0 and: [ Smalltalk os isWindows not ]) ifTrue: [
			[ self startLogging. self startTelemetry ]
				ifCurtailed: [ self stopSinks ] ].
		ActiveServers := ActiveServers + 1 ]
]

{ #category : 'private' }
PosternObservability class >> record: observation [
	OwnsTelemetry ifTrue: [ PuntTelemetry record: observation ]
]

{ #category : 'private' }
PosternObservability class >> recordError: error message: label [
	self emit: (PuntLogErrorSignal new component: 'server'; message: label; error: error)
]

{ #category : 'recording' }
PosternObservability class >> requestOn: route status: code [
	| statusClass |
	statusClass := #(informational success redirect clientError serverError)
		at: code // 100 ifAbsent: [ ^ self ].
	self record: (PosternRequestCountV1 new route: route; status: statusClass)
]

{ #category : 'recording' }
PosternObservability class >> serverStarted [
	self emit: (PuntLogSignal new component: 'server'; message: 'Server started').
	self record: PosternServerStartedV1 new
]

{ #category : 'private' }
PosternObservability class >> startLogging [
	| variables level |
	variables := OSEnvironment current.
	((variables at: 'POSTERN_LOG' ifAbsent: [ '' ]) asLowercase = 'off'
		or: [ PuntLog current notNil ]) ifTrue: [ ^ self ].
	level := (variables at: 'POSTERN_LOG_LEVEL' ifAbsent: [ '' ]) asLowercase = 'debug'
		ifTrue: [ PuntLogLevel debug ]
		ifFalse: [ PuntLogLevel info ].
	PuntLog startTool: 'postern' role: 'server' level: level.
	OwnsLog := true.
	Bridge := PuntLogZincBridge new.
	Bridge start
]

{ #category : 'private' }
PosternObservability class >> startTelemetry [
	PuntTelemetry current ifNotNil: [ ^ self ].
	[ PuntTelemetry
		startTool: 'postern'
		config: PuntTelemetryConfig new
		schemas: { PosternServerStartedV1. PosternRequestCountV1. PosternEvalCountV1 }.
	  OwnsTelemetry := true ]
		on: Error do: [ :error | self recordError: error message: 'Telemetry could not start' ]
]

{ #category : 'private' }
PosternObservability class >> stopSinks [
	[ OwnsTelemetry ifTrue: [ PuntTelemetry shutdown ] ]
		ensure: [
			OwnsTelemetry := false.
			Bridge ifNotNil: [ Bridge stop. Bridge := nil ].
			OwnsLog ifTrue: [ PuntLog stop. OwnsLog := false ] ]
]
