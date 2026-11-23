"
ZnReadEvalPrintDelegate subclass that normalizes LF to CR in input before evaluation. Provides optional token-based authentication (disabled by default). Tracks request count, last request time, and last request description for the dashboard widget.

### Examples

```
PosternDelegate new requestCount
>>> 0
```

"
Class {
	#name : 'PosternDelegate',
	#superclass : 'ZnReadEvalPrintDelegate',
	#instVars : [
		'token',
		'requestCount',
		'authEnabled',
		'lastRequestTime',
		'lastRequestDescription',
		'requestLogger',
		'server',
		'observability'
	],
	#category : 'Postern-Core',
	#package : 'Postern-Core'
}

{ #category : 'accessing' }
PosternDelegate >> authEnabled [
	^ authEnabled ifNil: [ authEnabled := false ]
]

{ #category : 'accessing' }
PosternDelegate >> authEnabled: aBoolean [
	authEnabled := aBoolean
]

{ #category : 'dependencies' }
PosternDelegate >> close [
	[ self release ] ensure: [
		observability ifNotNil: [ :observer |
			observability := nil.
			observer close ] ]
]

{ #category : 'private' }
PosternDelegate >> evaluate: string [
	| normalized |
	normalized := string copyReplaceAll: String lf with: String cr.
	observability ifNil: [ ^ super evaluate: normalized ].
	^ self evaluateObserved: normalized
]

{ #category : 'private' }
PosternDelegate >> evaluateObserved: string [
	| output |
	output := String streamContents: [ :out |
		[ out print: (self class compiler evaluate: string); cr.
		  observability ifNotNil: [ :observer | observer evalSucceeded ] ]
			on: Error do: [ :exception |
				observability ifNotNil: [ :observer | observer evalFailed: exception ].
				out print: exception; cr.
				exception signalerContext printDetails: out.
				exception signalerContext sender debugStack: 8 on: out ].
		out cr ].
	^ String lf join: output lines
]

{ #category : 'private - help' }
PosternDelegate >> handleHelpRequest: request [
	"Return the /help response for the given request. /help returns the
	table of contents; /help/<segment> returns the matching section or
	404 if unknown. URI parsing is wrapped in on:Error do: per the
	cascade-prevention pattern established in COE 2026-04-06.
	Body text is CR-to-LF normalized at the HTTP boundary: Pharo uses
	CR internally in string literals, but Markdown over HTTP expects
	LF (or CRLF). Section methods return whatever Pharo gives them."

	| pathSegments sub body markdown notFoundMessage |
	markdown := ZnMimeType fromString: 'text/markdown; charset=utf-8'.
	pathSegments := [ request uri segments ]
		on: Error
		do: [ :ex |
			observability ifNotNil: [ :observer | observer malformedRequest: ex ].
			^ ZnResponse new
				statusLine: ZnStatusLine badRequest;
				entity: (ZnEntity text: ex description);
				yourself ].
	pathSegments size <= 1
		ifTrue: [
			^ ZnResponse ok:
				(ZnEntity with: (self normalizeLineEndings: PosternHelp tableOfContents) type: markdown) ].
	sub := (pathSegments second ifNil: [ '' ]) asString.
	body := PosternHelp sectionFor: sub.
	body
		ifNotNil: [
			^ ZnResponse ok:
				(ZnEntity with: (self normalizeLineEndings: body) type: markdown) ].
	notFoundMessage := '/help has no section "' , sub , '"'.
	^ ZnResponse new
		statusLine: ZnStatusLine notFound;
		entity: (ZnEntity text: notFoundMessage);
		yourself
]

{ #category : 'public' }
PosternDelegate >> handleRequest: request [
	| segment response |
	segment := [ request uri firstPathSegment ]
		on: Error do: [ :ex |
			observability ifNotNil: [ :observer | observer malformedRequest: ex ].
			nil ].
	response := (self specialResponseFor: request segment: segment)
		ifNil: [ super handleRequest: request ].
	observability ifNotNil: [ :observer |
		observer requestOn: (self routeForSegment: segment) status: response status ].
	^ response
]

{ #category : 'initialization' }
PosternDelegate >> initialize [
	super initialize.
	requestCount := 0.
	authEnabled := false
]

{ #category : 'private' }
PosternDelegate >> isAuthenticated: request [
	self authEnabled ifFalse: [ ^ true ].
	token ifNil: [ ^ true ].
	^ (request headers at: 'X-Eval-Token' ifAbsent: [ '' ]) = token
]

{ #category : 'accessing' }
PosternDelegate >> lastRequestDescription [
	^ lastRequestDescription
]

{ #category : 'accessing' }
PosternDelegate >> lastRequestTime [
	^ lastRequestTime
]

{ #category : 'private - help' }
PosternDelegate >> normalizeLineEndings: aString [
	"Replace CR and CRLF line endings with LF for HTTP Markdown responses.
	Pharo string literals use CR; Markdown over HTTP expects LF or CRLF.
	Two-step: first collapse CRLF to LF, then replace any remaining bare CR."

	^ (aString copyReplaceAll: String crlf with: String lf)
		copyReplaceAll: String cr with: String lf
]

{ #category : 'private' }
PosternDelegate >> recordDashboardCleanupFailure: error [
	observability ifNotNil: [ :observer | observer dashboardCleanupFailed: error ]
]

{ #category : 'private' }
PosternDelegate >> prepareToStart [
	(self class canUnderstand: #attachObservability) ifTrue: [ self attachObservability ]
]

{ #category : 'private' }
PosternDelegate >> recordServerStarted [
	observability ifNotNil: [ :observer | observer serverStarted ]
]

{ #category : 'dependencies' }
PosternDelegate >> release [
	"Stop the dashboard logger if started; cleanup must not prevent shutdown."
	requestLogger ifNotNil: [
		[ requestLogger stop ]
			on: Error do: [ :ex |
				self recordDashboardCleanupFailure: ex ].
		requestLogger := nil ].
	super release
]

{ #category : 'accessing' }
PosternDelegate >> requestCount [
	^ requestCount ifNil: [ requestCount := 0 ]
]

{ #category : 'accessing' }
PosternDelegate >> requestLogger [
	"Lazy-init the shared eval-request logger for this delegate. One
	logger per server, shared across all dashboards observing it.
	The logger subscribes to ZnLogEvent on first access and lives with
	the delegate. It filters events by the owning server's serverId so
	that each dashboard only shows traffic for its own server.
	See COE 2026-04-06 round 7."
	^ requestLogger ifNil: [
		requestLogger := self requestLoggerClass new.
		requestLogger server: server.
		requestLogger start.
		requestLogger ]
]

{ #category : 'accessing' }
PosternDelegate >> requestLoggerClass [
	"Resolve the dashboard logger lazily so Postern-Core can load
	before Postern-Dashboard without introducing an Undeclared class
	reference during bootstrap."
	^ self class environment
		at: #PosternRequestLogger
		ifAbsent: [
			self error:
				'Postern-Dashboard is not loaded; PosternRequestLogger is unavailable' ]
]

{ #category : 'private' }
PosternDelegate >> routeForSegment: segment [
	(#(health help repl) includes: segment) ifFalse: [ ^ #other ].
	^ segment asSymbol
]

{ #category : 'accessing' }
PosternDelegate >> server [
	^ server
]

{ #category : 'accessing' }
PosternDelegate >> server: aZnServer [
	server := aZnServer
]

{ #category : 'private' }
PosternDelegate >> specialResponseFor: request segment: segment [
	segment = 'health'
		ifTrue: [ ^ ZnResponse ok: (ZnEntity text: 'ok') ].
	segment = 'help'
		ifTrue: [ ^ self handleHelpRequest: request ].
	(self isAuthenticated: request)
		ifFalse: [
			observability ifNotNil: [ :observer | observer authRejected ].
			^ ZnResponse unauthorized: 'X-Eval-Token' ].
	[ requestCount := self requestCount + 1.
	  lastRequestTime := DateAndTime now.
	  lastRequestDescription := segment ]
		on: Error do: [ :ex |
			observability ifNotNil: [ :observer | observer bookkeepingFailed: ex ] ].
	^ nil
]

{ #category : 'accessing' }
PosternDelegate >> token [
	^ token
]

{ #category : 'accessing' }
PosternDelegate >> token: aString [
	token := aString
]
