"
Tests for PosternRequest value object.
"
Class {
	#name : 'PosternRequestTest',
	#superclass : 'TestCase',
	#category : 'Postern-Dashboard-Tests',
	#package : 'Postern-Dashboard-Tests'
}

{ #category : 'helpers' }
PosternRequestTest >> newEntry [
	^ PosternRequest new
		timestamp: (DateAndTime year: 2025 month: 1 day: 15 hour: 14 minute: 30 second: 45);
		method: 'POST';
		path: '/repl';
		statusCode: 200;
		duration: 42;
		requestBody: '3 + 4';
		responseBody: '7';
		yourself
]

{ #category : 'tests' }
PosternRequestTest >> testBodySnippetShort [
	| entry |
	entry := self newEntry.
	self assert: entry bodySnippet equals: '3 + 4'
]

{ #category : 'tests' }
PosternRequestTest >> testBodySnippetTruncation [
	| entry |
	entry := self newEntry.
	entry requestBody: ('x' repeat: 100).
	self assert: entry bodySnippet size equals: 83.
	self assert: (entry bodySnippet endsWith: '...')
]

{ #category : 'tests' }
PosternRequestTest >> testIsClientError [
	| entry |
	entry := self newEntry.
	self deny: entry isClientError.
	entry statusCode: 401.
	self assert: entry isClientError.
	entry statusCode: 404.
	self assert: entry isClientError
]

{ #category : 'tests' }
PosternRequestTest >> testIsServerError [
	| entry |
	entry := self newEntry.
	self deny: entry isServerError.
	entry statusCode: 500.
	self assert: entry isServerError
]

{ #category : 'tests' }
PosternRequestTest >> testIsSuccess [
	| entry |
	entry := self newEntry.
	self assert: entry isSuccess.
	entry statusCode: 201.
	self assert: entry isSuccess.
	entry statusCode: 404.
	self deny: entry isSuccess
]

{ #category : 'tests' }
PosternRequestTest >> testMatchesFilter [
	| entry |
	entry := self newEntry.
	self assert: (entry matchesFilter: '').
	self assert: (entry matchesFilter: 'POST').
	self assert: (entry matchesFilter: 'post').
	self assert: (entry matchesFilter: 'repl').
	self assert: (entry matchesFilter: '200').
	self assert: (entry matchesFilter: '3 + 4').
	self deny: (entry matchesFilter: 'zzzzz')
]

{ #category : 'tests' }
PosternRequestTest >> testPrintOn [
	| entry |
	entry := self newEntry.
	self assert: (entry printString includesSubstring: 'POST').
	self assert: (entry printString includesSubstring: '/repl').
	self assert: (entry printString includesSubstring: '200').
	self assert: (entry printString includesSubstring: '42')
]

{ #category : 'tests' }
PosternRequestTest >> testRequestBodyDefault [
	self assert: PosternRequest new requestBody equals: ''
]

{ #category : 'tests' }
PosternRequestTest >> testResponseBodyDefault [
	self assert: PosternRequest new responseBody equals: ''
]

{ #category : 'tests' }
PosternRequestTest >> testStatusColor [
	| entry |
	entry := self newEntry.
	self assert: entry statusColor equals: (Color r: 0.0 g: 0.5 b: 0.0).
	entry statusCode: 401.
	self assert: entry statusColor equals: (Color r: 0.8 g: 0.5 b: 0.0).
	entry statusCode: 500.
	self assert: entry statusColor equals: Color red darker
]

{ #category : 'tests' }
PosternRequestTest >> testTimeString [
	| entry |
	entry := self newEntry.
	self assert: entry timeString equals: '14:30:45'
]
