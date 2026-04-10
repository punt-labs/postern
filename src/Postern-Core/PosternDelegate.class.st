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
		'server'
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

{ #category : 'private' }
PosternDelegate >> evaluate: string [
	"Normalize LF to CR in input, then delegate to super."
	| normalized |
	normalized := string copyReplaceAll: String lf with: String cr.
	^ super evaluate: normalized
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
			Transcript
				show: 'PosternDelegate>>handleHelpRequest: uri segments failed (';
				show: ex class name;
				show: ')';
				cr.
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
	"Record bookkeeping then dispatch. Bookkeeping is wrapped so that a
	failure in clock or URI access never prevents the request from being
	served. Safety: cascade-prevention pass — see COE 2026-04-06.

	Both /health and /help are handled before the auth check. /help is
	exempt from auth per docs/designs/postern.md §4.6 — its content
	describes the auth protocol itself."
	| segment |
	segment := [ request uri firstPathSegment ]
		on: Error
		do: [ :ex |
			Transcript
				show: 'PosternDelegate>>handleRequest: uri parse failed (';
				show: ex class name;
				show: ') — falling back to nil segment';
				cr.
			nil ].
	segment = 'health'
		ifTrue: [ ^ ZnResponse ok: (ZnEntity text: 'ok') ].
	segment = 'help'
		ifTrue: [ ^ self handleHelpRequest: request ].
	(self isAuthenticated: request)
		ifFalse: [ ^ ZnResponse unauthorized: 'X-Eval-Token' ].
	[ requestCount := self requestCount + 1.
	  lastRequestTime := DateAndTime now.
	  lastRequestDescription := segment ]
		on: Error
		do: [ :ex |
			Transcript
				show: 'PosternDelegate bookkeeping suppressed: ';
				show: (ex messageText ifNil: [ ex class name ]);
				cr ].
	^ super handleRequest: request
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

{ #category : 'dependencies' }
PosternDelegate >> release [
	"Stop the request logger if started, then super. Called by ZnServer
	on stop. Cleanup is best-effort: a failure here must not prevent
	server shutdown. Failures are logged to Transcript for diagnostics."
	requestLogger ifNotNil: [
		[ requestLogger stop ]
			on: Error
			do: [ :ex |
				Transcript
					show: 'PosternDelegate>>release: requestLogger stop raised ';
					show: ex class name;
					show: ' — ';
					show: (ex messageText ifNil: [ '' ]);
					show: ' (swallowed for shutdown safety)';
					cr ].
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
		requestLogger := PosternRequestLogger new.
		requestLogger server: server.
		requestLogger start.
		requestLogger ]
]

{ #category : 'accessing' }
PosternDelegate >> server [
	^ server
]

{ #category : 'accessing' }
PosternDelegate >> server: aZnServer [
	server := aZnServer
]

{ #category : 'accessing' }
PosternDelegate >> token [
	^ token
]

{ #category : 'accessing' }
PosternDelegate >> token: aString [
	token := aString
]
