"
Subscribes to ZnLogEvent announcer for ZnServerTransactionEvent and captures each request/response as a PosternRequest. Maintains a bounded ring buffer (default 100 entries, configurable via maxEntries).

The logger has its own Announcer. Listeners (such as PosternDashboard) subscribe to receive PosternRequest announcements when new entries arrive.

### Examples

	PosternRequestLogger new
	>>> a PosternRequestLogger

	| logger |
	logger := PosternRequestLogger new.
	logger isRunning
	>>> false

	| logger |
	logger := PosternRequestLogger new.
	logger start.
	logger isRunning
	>>> true

"
Class {
	#name : 'PosternRequestLogger',
	#superclass : 'Object',
	#instVars : [
		'entries',
		'maxEntries',
		'announcer',
		'subscription',
		'paused',
		'server'
	],
	#category : 'Postern-Dashboard',
	#package : 'Postern-Dashboard'
}

{ #category : 'accessing' }
PosternRequestLogger >> announcer [
	^ announcer
]

{ #category : 'actions' }
PosternRequestLogger >> clear [
	"Remove all log entries."
	entries removeAll
]

{ #category : 'accessing' }
PosternRequestLogger >> entries [
	^ entries
]

{ #category : 'private' }
PosternRequestLogger >> handleEvent: aZnServerTransactionEvent [
	"Convert a Zinc server transaction event into a PosternRequest and store it.
	When a server is set, only log events from that server (matched by serverId).
	This ensures each dashboard only shows traffic for its own server."
	| entry request response |
	paused ifTrue: [ ^ self ].
	(server notNil and: [
		aZnServerTransactionEvent serverId ~= server serverId ])
			ifTrue: [ ^ self ].
	request := aZnServerTransactionEvent request.
	response := aZnServerTransactionEvent response.
	entry := PosternRequest new
		timestamp: DateAndTime now;
		method: request method;
		path: request uri printString;
		statusCode: response code;
		duration: aZnServerTransactionEvent duration;
		yourself.
	(request hasEntity and: [ request contentType isBinary not ])
		ifTrue: [ entry requestBody: request entity contents ].
	(response hasEntity and: [ response contentType isBinary not ])
		ifTrue: [ entry responseBody: response entity contents ].
	entries addFirst: entry.
	entries size > maxEntries ifTrue: [ entries removeLast ].
	announcer announce: entry
]

{ #category : 'initialization' }
PosternRequestLogger >> initialize [
	super initialize.
	entries := OrderedCollection new.
	maxEntries := 100.
	paused := false.
	announcer := Announcer new
]

{ #category : 'testing' }
PosternRequestLogger >> isPaused [
	^ paused
]

{ #category : 'testing' }
PosternRequestLogger >> isRunning [
	^ subscription notNil
]

{ #category : 'accessing' }
PosternRequestLogger >> maxEntries [
	^ maxEntries
]

{ #category : 'accessing' }
PosternRequestLogger >> maxEntries: anInteger [
	maxEntries := anInteger
]

{ #category : 'actions' }
PosternRequestLogger >> pause [
	paused := true
]

{ #category : 'actions' }
PosternRequestLogger >> resume [
	paused := false
]

{ #category : 'accessing' }
PosternRequestLogger >> server [
	^ server
]

{ #category : 'accessing' }
PosternRequestLogger >> server: aZnServer [
	server := aZnServer
]

{ #category : 'actions' }
PosternRequestLogger >> start [
	"Subscribe to ZnLogEvent announcer for server transaction events.
	This logger captures events into its own buffer; multiple loggers
	are fine — each subscription is independent. The 2026-04-06 cascade
	was caused by leaked subscriptions on a singleton dashboard, not by
	multiple loggers existing. The singleton has been removed (round 5),
	so no defensive cleanup is needed here.

	The leading self stop is the per-instance idempotence guard: if this
	logger was already running, drop the old subscription before
	installing a new one so we never double-subscribe the same instance."
	self stop.
	subscription := ZnLogEvent announcer
		when: ZnServerTransactionEvent
		send: #handleEvent:
		to: self
]

{ #category : 'actions' }
PosternRequestLogger >> stop [
	"Unsubscribe from ZnLogEvent announcer."
	subscription ifNotNil: [
		ZnLogEvent announcer removeSubscription: subscription.
		subscription := nil ]
]
