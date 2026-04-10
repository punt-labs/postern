"
Tests for PosternServer and PosternDelegate. Verifies server startup, LF-to-CR normalization in the eval delegate, and binding address policy.
"
Class {
	#name : 'PosternServerTest',
	#superclass : 'TestCase',
	#category : 'Postern-Core-Tests',
	#package : 'Postern-Core-Tests'
}

{ #category : 'tests' }
PosternServerTest >> testAuthAcceptsWithCorrectToken [
	| server delegate response |
	server := PosternServer startOn: 8499 withAuth: true.
	delegate := server delegate.
	[ response := ZnClient new
		url: 'http://localhost:8499/repl';
		headerAt: 'X-Eval-Token' put: delegate token;
		entity: (ZnEntity text: '3 + 4');
		post;
		response.
	self assert: response status equals: 200.
	self assert: (response entity contents includesSubstring: '7') ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testAuthDisabledByDefault [
	| delegate |
	delegate := PosternDelegate new.
	self deny: delegate authEnabled
]

{ #category : 'tests' }
PosternServerTest >> testAuthRejectsWithoutToken [
	| server response |
	server := PosternServer startOn: 8499 withAuth: true.
	[ response := ZnClient new
		url: 'http://localhost:8499/repl';
		entity: (ZnEntity text: '3 + 4');
		post;
		response.
	self assert: response status equals: 401 ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testAuthRejectsWrongToken [
	| server response |
	server := PosternServer startOn: 8499 withAuth: true.
	[ response := ZnClient new
		url: 'http://localhost:8499/repl';
		headerAt: 'X-Eval-Token' put: 'wrongtoken';
		entity: (ZnEntity text: '3 + 4');
		post;
		response.
	self assert: response status equals: 401 ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testDelegateNormalizesLfToCr [
	| delegate input result |
	delegate := PosternDelegate new.
	input := '| x |' , String lf , 'x := 42' , String lf , 'x'.
	result := delegate evaluate: input.
	self assert: (result includesSubstring: '42')
]

{ #category : 'tests' }
PosternServerTest >> testDelegatePreservesPureCrInput [
	| delegate input result |
	delegate := PosternDelegate new.
	input := '3 + 4'.
	result := delegate evaluate: input.
	self assert: (result includesSubstring: '7')
]

{ #category : 'tests' }
PosternServerTest >> testHealthEndpointNoAuth [
	| server response |
	server := PosternServer startOn: 8499.
	[ response := ZnClient new
		url: 'http://localhost:8499/health';
		get;
		response.
	self assert: response status equals: 200.
	self assert: response entity contents equals: 'ok' ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testHealthEndpointWithAuthEnabled [
	| server response |
	server := PosternServer startOn: 8499 withAuth: true.
	[ response := ZnClient new
		url: 'http://localhost:8499/health';
		get;
		response.
	self assert: response status equals: 200.
	self assert: response entity contents equals: 'ok' ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testHelpApiRouteReturnsApiStub [
	| server response |
	server := PosternServer startOn: 8499.
	[ response := ZnClient new
		url: 'http://localhost:8499/help/api';
		get;
		response.
	self assert: response status equals: 200.
	self assert: (response entity contents includesSubstring: '# /help/api').
	self assert: (response entity contents size > 200).
	self assert: response entity contentType main equals: 'text'.
	self assert: response entity contentType sub equals: 'markdown' ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testHelpRouteIsAuthExempt [
	| server response subResponse notFoundResponse |
	server := PosternServer startOn: 8499 withAuth: true.
	[ response := ZnClient new
		url: 'http://localhost:8499/help';
		get;
		response.
	self assert: response status equals: 200.
	subResponse := ZnClient new
		url: 'http://localhost:8499/help/api';
		get;
		response.
	self assert: subResponse status equals: 200.
	notFoundResponse := ZnClient new
		url: 'http://localhost:8499/help/nonsense';
		get;
		response.
	self assert: notFoundResponse status equals: 404 ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testHelpRouteReturnsTableOfContents [
	| server response contents |
	server := PosternServer startOn: 8499.
	[ response := ZnClient new
		url: 'http://localhost:8499/help';
		get;
		response.
	self assert: response status equals: 200.
	contents := response entity contents.
	self assert: (contents includesSubstring: '# Postern /help').
	self assert: (contents includesSubstring: '## Sections').
	self assert: (contents includesSubstring: '/help/api').
	self assert: response entity contentType main equals: 'text'.
	self assert: response entity contentType sub equals: 'markdown' ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testHelpUnknownSectionReturns404 [
	| server response |
	server := PosternServer startOn: 8499.
	[ response := ZnClient new
		url: 'http://localhost:8499/help/nonsense';
		get;
		response.
	self assert: response status equals: 404.
	self assert: (response entity contents includesSubstring: 'nonsense') ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testReplRouteUnchanged [
	"Regression: the /repl eval endpoint must continue to work after
	the /help routes were added."
	| server response |
	server := PosternServer startOn: 8499.
	[ response := ZnClient new
		url: 'http://localhost:8499/repl';
		entity: (ZnEntity text: '3 + 4');
		post;
		response.
	self assert: response status equals: 200.
	self assert: (response entity contents includesSubstring: '7') ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testRequestCountIncrements [
	| server delegate |
	server := PosternServer startOn: 8499.
	delegate := server delegate.
	[ self assert: delegate requestCount equals: 0.
	ZnClient new
		url: 'http://localhost:8499/repl';
		entity: (ZnEntity text: '3 + 4');
		post.
	self assert: delegate requestCount equals: 1.
	ZnClient new
		url: 'http://localhost:8499/repl';
		entity: (ZnEntity text: '5 + 6');
		post.
	self assert: delegate requestCount equals: 2 ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testStartOnBindsToLoopback [
	"startOn: must bind to loopback only."
	| server |
	server := PosternServer startOn: 8500.
	[ self assert: server bindingAddress equals: NetNameResolver loopBackAddress ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testStartOnCreatesRunningServer [
	| server |
	server := PosternServer startOn: 8499.
	[ self assert: server isRunning ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testStartOnUsesPosternDelegate [
	| server |
	server := PosternServer startOn: 8499.
	[ self assert: (server delegate isKindOf: PosternDelegate) ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testStartOnWithAuthBindsToLoopback [
	"startOn:withAuth: must bind to loopback only."
	| server |
	server := PosternServer startOn: 8500 withAuth: true.
	[ self assert: server bindingAddress equals: NetNameResolver loopBackAddress ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testStartOnWithAuthFalseBindsToLoopback [
	"withAuth: false must still bind to loopback."
	| server |
	server := PosternServer startOn: 8500 withAuth: false.
	[ self assert: server bindingAddress equals: NetNameResolver loopBackAddress ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testStartPublicOnAlwaysEnablesAuth [
	"startPublicOn: must always enable authentication."
	| server delegate |
	server := PosternServer startPublicOn: 8500.
	delegate := server delegate.
	[ self assert: delegate authEnabled.
	self assert: delegate token isNotNil.
	self assert: delegate token isNotEmpty ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testStartPublicOnBindsToAllInterfaces [
	"startPublicOn: must bind to all interfaces (nil bindingAddress = no restriction)."
	| server |
	server := PosternServer startPublicOn: 8500.
	[ self assert: server bindingAddress isNil ]
		ensure: [ server stop ]
]

{ #category : 'tests' }
PosternServerTest >> testTokenGeneration [
	| token |
	token := PosternServer generateToken.
	self assert: token size equals: 8.
	self assert: (token allSatisfy: [ :c | '0123456789abcdef' includes: c ])
]
