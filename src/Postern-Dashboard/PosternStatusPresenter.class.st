"
Sub-presenter displaying server status and auth token. Instantiated on: a PosternDashboardModel. Queries the model for all display values.

### Layout

	Status: Running    Port: 8422    Requests: 2029    Uptime: 5h 6m
	Auth Token: ********

### Examples

	(PosternStatusPresenter on: PosternDashboardModel new) statusLabel label
	>>> 'Status: --'

	(PosternStatusPresenter on: PosternDashboardModel new) authTokenLabel label
	>>> 'Auth Token: ********'

"
Class {
	#name : 'PosternStatusPresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'model',
		'statusLabel',
		'portLabel',
		'requestCountLabel',
		'uptimeLabel',
		'authTokenLabel',
		'authTokenVisible'
	],
	#category : 'Postern-Dashboard',
	#package : 'Postern-Dashboard'
}

{ #category : 'accessing' }
PosternStatusPresenter >> authTokenLabel [
	"Exposed for testing."
	^ authTokenLabel
]

{ #category : 'layout' }
PosternStatusPresenter >> defaultLayout [
	| statusRow authRow |
	statusRow := SpBoxLayout newLeftToRight
		spacing: 15;
		add: statusLabel expand: false;
		add: portLabel expand: false;
		add: requestCountLabel expand: false;
		add: uptimeLabel expand: false;
		yourself.
	authRow := SpBoxLayout newLeftToRight
		spacing: 15;
		add: authTokenLabel expand: false;
		yourself.
	^ SpBoxLayout newTopToBottom
		spacing: 2;
		add: statusRow expand: false;
		add: authRow expand: false;
		yourself
]

{ #category : 'initialization' }
PosternStatusPresenter >> initializePresenters [
	authTokenVisible := false.
	statusLabel := self newLabel label: 'Status: --'.
	portLabel := self newLabel label: 'Port: ----'.
	requestCountLabel := self newLabel label: 'Requests: 0'.
	uptimeLabel := self newLabel label: 'Uptime: --'.
	authTokenLabel := self newLabel label: 'Auth Token: ********'
]

{ #category : 'accessing' }
PosternStatusPresenter >> model [
	^ model
]

{ #category : 'updating' }
PosternStatusPresenter >> refresh [
	"Update all labels from the model."
	| m |
	m := self model.
	m isRunning
		ifTrue: [ statusLabel label: 'Status: Running' ]
		ifFalse: [ statusLabel label: (m hasServer ifTrue: [ 'Status: Stopped' ] ifFalse: [ 'Status: No Server' ]) ].
	portLabel label: 'Port: ', (m hasServer ifTrue: [ m port printString ] ifFalse: [ '----' ]).
	requestCountLabel label: 'Requests: ', m requestCount printString.
	uptimeLabel label: 'Uptime: ', m uptimeString
]

{ #category : 'accessing - model' }
PosternStatusPresenter >> setModelBeforeInitialization: aPosternDashboardModel [
	model := aPosternDashboardModel
]

{ #category : 'accessing' }
PosternStatusPresenter >> statusLabel [
	"Exposed for testing."
	^ statusLabel
]

{ #category : 'actions' }
PosternStatusPresenter >> toggleAuthToken [
	"Toggle visibility of the auth token."
	authTokenVisible := authTokenVisible not.
	authTokenVisible
		ifTrue: [
			| token |
			token := self model authToken ifNil: [
				self model hasServer ifTrue: [ '(none)' ] ifFalse: [ '(no server)' ] ].
			authTokenLabel label: 'Auth Token: ', token ]
		ifFalse: [
			authTokenLabel label: 'Auth Token: ********' ]
]
