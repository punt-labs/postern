"
Domain model for the Postern dashboard. Wraps a ZnServer and a PosternRequestLogger, providing a unified query API for presenters. Multiple sub-presenters share the same model instance.

The model announces state changes via its announcer so presenters can observe updates.

### Examples

	PosternDashboardModel new
	>>> a PosternDashboardModel

	PosternDashboardModel new hasServer
	>>> false

	PosternDashboardModel new isRunning
	>>> false

	PosternDashboardModel new port
	>>> 0

	PosternDashboardModel new uptimeString
	>>> '--'

"
Class {
	#name : 'PosternDashboardModel',
	#superclass : 'Object',
	#instVars : [
		'server',
		'logger',
		'startedAt'
	],
	#category : 'Postern-Dashboard',
	#package : 'Postern-Dashboard'
}

{ #category : 'instance creation' }
PosternDashboardModel class >> on: aZnServer [
	^ self new
		server: aZnServer;
		yourself
]

{ #category : 'accessing' }
PosternDashboardModel >> announcer [
	"Delegate to the shared logger announcer. Listeners that subscribe
	to model announcer are observing the same announcement stream as
	listeners on model logger announcer; both are the same object."
	^ self logger announcer
]

{ #category : 'accessing' }
PosternDashboardModel >> authToken [
	"Return the auth token string or nil."
	^ server ifNotNil: [ server delegate token ]
]

{ #category : 'actions' }
PosternDashboardModel >> clearLog [
	self logger clear
]

{ #category : 'actions' }
PosternDashboardModel >> copyAuthTokenToClipboard [
	self authToken ifNotNil: [ :token | Clipboard clipboardText: token ]
]

{ #category : 'accessing' }
PosternDashboardModel >> filteredEntries: filterText [
	"Return log entries matching the filter, or all if empty."
	^ filterText
		ifEmpty: [ self logger entries asArray ]
		ifNotEmpty: [ self logger entries select: [ :e | e matchesFilter: filterText ] ]
]

{ #category : 'testing' }
PosternDashboardModel >> hasServer [
	^ server notNil
]

{ #category : 'testing' }
PosternDashboardModel >> isAuthEnabled [
	^ server notNil and: [ server delegate authEnabled ]
]

{ #category : 'testing' }
PosternDashboardModel >> isPaused [
	^ self logger isPaused
]

{ #category : 'testing' }
PosternDashboardModel >> isRunning [
	^ server notNil and: [ server isRunning ]
]

{ #category : 'accessing' }
PosternDashboardModel >> logger [
	"Return the shared Postern request logger for this server. When a
	server is attached, the logger is owned by the server delegate and
	shared by all models observing this server (System Browser pattern).
	When no server is attached (test/headless construction), lazy-init
	a local unstarted logger that tests can populate directly."
	server ifNotNil: [ ^ server delegate requestLogger ].
	^ logger ifNil: [ logger := PosternRequestLogger new ]
]

{ #category : 'accessing' }
PosternDashboardModel >> port [
	^ server ifNotNil: [ server port ] ifNil: [ 0 ]
]

{ #category : 'accessing' }
PosternDashboardModel >> requestCount [
	^ self isRunning
		ifTrue: [ server delegate requestCount ]
		ifFalse: [ 0 ]
]

{ #category : 'accessing' }
PosternDashboardModel >> server [
	^ server
]

{ #category : 'accessing' }
PosternDashboardModel >> server: aZnServer [
	server := aZnServer.
	startedAt := (server notNil and: [ server isRunning ])
		ifTrue: [ DateAndTime now ]
		ifFalse: [ nil ]
]

{ #category : 'actions' }
PosternDashboardModel >> togglePause [
	self logger isPaused
		ifTrue: [ self logger resume ]
		ifFalse: [ self logger pause ]
]

{ #category : 'accessing' }
PosternDashboardModel >> uptimeString [
	"Return a human-readable uptime string."
	| duration totalHours minutes secs |
	(self isRunning and: [ startedAt notNil ])
		ifFalse: [ ^ '--' ].
	duration := DateAndTime now - startedAt.
	totalHours := duration asHours floor.
	minutes := duration minutes abs.
	secs := duration seconds abs.
	totalHours > 0
		ifTrue: [ ^ totalHours printString, 'h ', minutes printString, 'm' ]
		ifFalse: [ ^ minutes printString, 'm ', secs printString, 's' ]
]
