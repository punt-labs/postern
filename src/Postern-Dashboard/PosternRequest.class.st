"
A value object capturing one HTTP request/response handled by the PosternDelegate. Subclasses Announcement so it can be announced directly by PosternRequestLogger.

Instances are created by PosternRequestLogger from ZnServerTransactionEvent announcements. Each entry records the timestamp, HTTP method, URI path, status code, duration in milliseconds, and the request/response bodies.

### Examples

    PosternRequest new
        timestamp: DateAndTime now;
        method: ''POST'';
        path: ''/repl'';
        statusCode: 200;
        duration: 42;
        requestBody: ''3 + 4'';
        responseBody: ''7''
"
Class {
	#name : 'PosternRequest',
	#superclass : 'Announcement',
	#instVars : [
		'timestamp',
		'method',
		'path',
		'statusCode',
		'duration',
		'requestBody',
		'responseBody'
	],
	#category : 'Postern-Dashboard',
	#package : 'Postern-Dashboard'
}

{ #category : 'accessing' }
PosternRequest >> bodySnippet [
	"Return a short preview of the request body, truncated for table display."
	| body |
	body := self requestBody.
	^ body size > 80
		ifTrue: [ (body copyFrom: 1 to: 80), '...' ]
		ifFalse: [ body ]
]

{ #category : 'accessing' }
PosternRequest >> duration [
	^ duration
]

{ #category : 'accessing' }
PosternRequest >> duration: anInteger [
	duration := anInteger
]

{ #category : 'testing' }
PosternRequest >> isClientError [
	^ statusCode between: 400 and: 499
]

{ #category : 'testing' }
PosternRequest >> isServerError [
	^ statusCode between: 500 and: 599
]

{ #category : 'testing' }
PosternRequest >> isSuccess [
	^ statusCode between: 200 and: 299
]

{ #category : 'testing' }
PosternRequest >> matchesFilter: aString [
	"Return true if this entry matches the given filter substring (case-insensitive)."
	| filter |
	aString ifEmpty: [ ^ true ].
	filter := aString asLowercase.
	^ (method asLowercase includesSubstring: filter)
		or: [ (path asLowercase includesSubstring: filter)
		or: [ (self requestBody asLowercase includesSubstring: filter)
		or: [ statusCode printString includesSubstring: filter ] ] ]
]

{ #category : 'accessing' }
PosternRequest >> method [
	^ method
]

{ #category : 'accessing' }
PosternRequest >> method: aString [
	method := aString
]

{ #category : 'accessing' }
PosternRequest >> path [
	^ path
]

{ #category : 'accessing' }
PosternRequest >> path: aString [
	path := aString
]

{ #category : 'printing' }
PosternRequest >> printOn: aStream [
	aStream
		nextPutAll: self timeString;
		space;
		nextPutAll: method;
		space;
		nextPutAll: path;
		space;
		print: statusCode;
		space;
		print: duration;
		nextPutAll: 'ms'
]

{ #category : 'accessing' }
PosternRequest >> requestBody [
	^ requestBody ifNil: [ '' ]
]

{ #category : 'accessing' }
PosternRequest >> requestBody: aString [
	requestBody := aString
]

{ #category : 'accessing' }
PosternRequest >> responseBody [
	^ responseBody ifNil: [ '' ]
]

{ #category : 'accessing' }
PosternRequest >> responseBody: aString [
	responseBody := aString
]

{ #category : 'accessing' }
PosternRequest >> statusCode [
	^ statusCode
]

{ #category : 'accessing' }
PosternRequest >> statusCode: anInteger [
	statusCode := anInteger
]

{ #category : 'accessing' }
PosternRequest >> statusColor [
	"Return a color appropriate for the status code."
	self isSuccess ifTrue: [ ^ Color r: 0.0 g: 0.5 b: 0.0 ].
	self isClientError ifTrue: [ ^ Color r: 0.8 g: 0.5 b: 0.0 ].
	self isServerError ifTrue: [ ^ Color red darker ].
	^ Color black
]

{ #category : 'accessing' }
PosternRequest >> timeString [
	"Return the time portion formatted as HH:MM:SS."
	^ timestamp asTime print24
]

{ #category : 'accessing' }
PosternRequest >> timestamp [
	^ timestamp
]

{ #category : 'accessing' }
PosternRequest >> timestamp: aDateAndTime [
	timestamp := aDateAndTime
]
