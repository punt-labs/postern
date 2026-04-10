"
Tests for PosternRequestLogger. Uses synthetic ZnServerTransactionEvent objects rather than making real HTTP requests, to avoid interfering with the running eval server.
"
Class {
	#name : 'PosternRequestLoggerTest',
	#superclass : 'TestCase',
	#category : 'Postern-Dashboard-Tests',
	#package : 'Postern-Dashboard-Tests'
}

{ #category : 'helpers' }
PosternRequestLoggerTest >> newEventMethod: methodString path: pathString body: bodyString status: statusInteger [
	"Create a synthetic ZnServerTransactionEvent without making real HTTP requests."
	| request response timing event |
	request := ZnRequest method: methodString asSymbol url: pathString asZnUrl.
	bodyString ifNotNil: [
		request entity: (ZnEntity text: bodyString) ].
	response := ZnResponse statusCode: statusInteger.
	response entity: (ZnEntity text: 'ok').
	timing := ZnServerTransactionTiming new.
	timing handlerDuration: 40.
	timing responseDuration: 2.
	event := ZnServerTransactionEvent new.
	event request: request.
	event response: response.
	event timing: timing.
	^ event
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testAnnouncesNewEntries [

	| logger received |
	logger := PosternRequestLogger new.
	received := OrderedCollection new.
	logger announcer
		when: PosternRequest
		do: [ :entry | received add: entry ]
		for: self.
	logger handleEvent: (self
			 newEventMethod: 'POST'
			 path: '/repl'
			 body: 'x'
			 status: 200).
	self assert: received size equals: 1.
	self assert: received first method equals: 'POST'
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testClear [
	| logger |
	logger := PosternRequestLogger new.
	logger handleEvent: (self newEventMethod: 'POST' path: '/repl' body: 'x' status: 200).
	self assert: logger entries size equals: 1.
	logger clear.
	self assert: logger entries isEmpty
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testFiltersByServer [
	"A logger with a server set only captures events whose serverId matches."
	| serverA serverB loggerA loggerB eventA eventB |
	serverA := ZnServer on: 19001.
	serverA serverId: 'postern-19001'.
	serverB := ZnServer on: 19002.
	serverB serverId: 'postern-19002'.
	loggerA := PosternRequestLogger new.
	loggerA server: serverA.
	loggerB := PosternRequestLogger new.
	loggerB server: serverB.
	eventA := self newEventMethod: 'POST' path: '/repl' body: '1+1' status: 200.
	eventA serverId: 'postern-19001'.
	eventB := self newEventMethod: 'POST' path: '/repl' body: '2+2' status: 200.
	eventB serverId: 'postern-19002'.
	loggerA handleEvent: eventA.
	loggerA handleEvent: eventB.
	loggerB handleEvent: eventA.
	loggerB handleEvent: eventB.
	self assert: loggerA entries size equals: 1.
	self assert: loggerA entries first requestBody equals: '1+1'.
	self assert: loggerB entries size equals: 1.
	self assert: loggerB entries first requestBody equals: '2+2'
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testHandleEvent [
	| logger event |
	logger := PosternRequestLogger new.
	event := self newEventMethod: 'POST' path: '/repl' body: '3 + 4' status: 200.
	logger handleEvent: event.
	self assert: logger entries size equals: 1.
	self assert: logger entries first method equals: 'POST'.
	self assert: logger entries first statusCode equals: 200.
	self assert: logger entries first requestBody equals: '3 + 4'.
	self assert: logger entries first duration equals: 42
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testInitialize [
	| logger |
	logger := PosternRequestLogger new.
	self assert: logger entries isEmpty.
	self assert: logger maxEntries equals: 100.
	self deny: logger isPaused.
	self deny: logger isRunning
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testMaxEntriesEnforced [
	| logger |
	logger := PosternRequestLogger new.
	logger maxEntries: 3.
	1 to: 5 do: [ :i |
		logger handleEvent: (self newEventMethod: 'POST' path: '/repl' body: i printString status: 200) ].
	self assert: logger entries size equals: 3.
	self assert: logger entries first requestBody equals: '5'.
	self assert: logger entries last requestBody equals: '3'
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testNewestFirst [
	| logger |
	logger := PosternRequestLogger new.
	logger handleEvent: (self newEventMethod: 'POST' path: '/repl' body: 'first' status: 200).
	logger handleEvent: (self newEventMethod: 'GET' path: '/health' body: nil status: 200).
	self assert: logger entries first method equals: 'GET'.
	self assert: logger entries second method equals: 'POST'
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testNoServerCapturesAll [
	"A logger without a server set captures events from any server (backward compat)."
	| logger eventA eventB |
	logger := PosternRequestLogger new.
	eventA := self newEventMethod: 'POST' path: '/repl' body: '1+1' status: 200.
	eventA serverId: 'postern-19001'.
	eventB := self newEventMethod: 'POST' path: '/repl' body: '2+2' status: 200.
	eventB serverId: 'postern-19002'.
	logger handleEvent: eventA.
	logger handleEvent: eventB.
	self assert: logger entries size equals: 2
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testPauseResume [
	| logger |
	logger := PosternRequestLogger new.
	logger handleEvent: (self newEventMethod: 'POST' path: '/repl' body: 'a' status: 200).
	self assert: logger entries size equals: 1.
	logger pause.
	self assert: logger isPaused.
	logger handleEvent: (self newEventMethod: 'POST' path: '/repl' body: 'b' status: 200).
	self assert: logger entries size equals: 1.
	logger resume.
	self deny: logger isPaused.
	logger handleEvent: (self newEventMethod: 'POST' path: '/repl' body: 'c' status: 200).
	self assert: logger entries size equals: 2
]

{ #category : 'tests' }
PosternRequestLoggerTest >> testStartStop [
	| logger |
	logger := PosternRequestLogger new.
	logger start.
	[ self assert: logger isRunning ]
		ensure: [ logger stop ].
	self deny: logger isRunning
]
