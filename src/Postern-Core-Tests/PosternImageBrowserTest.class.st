"
Tests for PosternImageBrowser introspection facade. Exercises class browsing, method source, hierarchy, code search, implementors, senders, selector suggestions, batch browse, and lint.
"
Class {
	#name : 'PosternImageBrowserTest',
	#superclass : 'TestCase',
	#category : 'Postern-Core-Tests',
	#package : 'Postern-Core-Tests'
}

{ #category : 'tests' }
PosternImageBrowserTest >> testBatchBrowse [
	| result |
	result := PosternImageBrowser batchBrowse: 'Object' withMethods: 'yourself printOn:'.
	self assert: (result includesSubstring: 'yourself').
	self assert: (result includesSubstring: 'printOn:')
]

{ #category : 'tests' }
PosternImageBrowserTest >> testBrowseClass [
	| result |
	result := PosternImageBrowser browseClass: 'Object'.
	self assert: (result includesSubstring: 'Object').
	self assert: (result includesSubstring: 'Instance variables').
	self assert: (result includesSubstring: 'Superclass chain')
]

{ #category : 'tests' }
PosternImageBrowserTest >> testBrowseClassNotFound [
	| result |
	result := PosternImageBrowser browseClass: 'NoSuchClass9999'.
	self assert: (result includesSubstring: 'not found')
]

{ #category : 'tests' }
PosternImageBrowserTest >> testBrowseHierarchy [
	| result |
	result := PosternImageBrowser browseHierarchy: 'OrderedCollection'.
	self assert: (result includesSubstring: 'SequenceableCollection')
]

{ #category : 'tests' }
PosternImageBrowserTest >> testBrowseMethod [
	| result |
	result := PosternImageBrowser browseMethod: 'Object' selector: 'yourself'.
	self assert: (result includesSubstring: 'yourself')
]

{ #category : 'tests' }
PosternImageBrowserTest >> testImplementorsOf [
	| result |
	result := PosternImageBrowser implementorsOf: 'yourself'.
	self assert: (result includesSubstring: 'Object')
]

{ #category : 'tests' }
PosternImageBrowserTest >> testLint [
	| result |
	result := PosternImageBrowser lint: 'PosternServer'.
	self assert: (result includesSubstring: 'No lint findings')
]

{ #category : 'tests' }
PosternImageBrowserTest >> testSearchCode [
	| result |
	result := PosternImageBrowser searchCode: 'yourself'.
	self deny: result isEmpty
]

{ #category : 'tests' }
PosternImageBrowserTest >> testSendersOf [
	| result |
	result := PosternImageBrowser sendersOf: 'yourself'.
	self deny: result isEmpty
]

{ #category : 'tests' }
PosternImageBrowserTest >> testSuggestSelector [
	| result |
	result := PosternImageBrowser suggestSelector: 'yourse' onClass: 'Object'.
	self assert: (result includesSubstring: 'yourself')
]
