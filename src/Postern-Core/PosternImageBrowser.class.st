"
Introspection facade for the Pharo image. Provides class browsing, method source, hierarchy navigation, code search, selector suggestions, and lint.

### Examples

```
(PosternImageBrowser browseClass: 'SmallInteger') includesSubstring: 'SmallInteger'
>>> true
```

"
Class {
	#name : 'PosternImageBrowser',
	#superclass : 'Object',
	#category : 'Postern-Core',
	#package : 'Postern-Core'
}

{ #category : 'browsing' }
PosternImageBrowser class >> batchBrowse: className withMethods: selectorNames [
	| result selectors |
	result := OrderedCollection new.
	result add: (self browseClass: className).
	result add: ''.
	selectors := selectorNames substrings.
	result addAll: (selectors collect: [ :sel |
		| cls header source |
		cls := Smalltalk globals at: className asSymbol ifAbsent: [ nil ].
		header := String streamContents: [ :s | s nextPutAll: '--- '; nextPutAll: className; nextPutAll: ' >> #'; nextPutAll: sel; nextPutAll: ' ---' ].
		source := (cls notNil and: [ cls canUnderstand: sel asSymbol ])
			ifTrue: [ (cls >> sel asSymbol) sourceCode ]
			ifFalse: [ '(not found)' ].
		String cr join: { header. source. '' } ]).
	^ String cr join: result
]

{ #category : 'operations' }
PosternImageBrowser class >> browseClass: className [
	"Return a comprehensive overview of a class (instance + class side)."
	| cls result |
	cls := Smalltalk globals at: className asSymbol ifAbsent: [
		^ 'Class not found: ', className ].
	result := OrderedCollection new.
	self classInfoFor: cls on: result.
	self instanceProtocolsFor: cls on: result.
	self classProtocolsFor: cls on: result.
	self subclassesFor: cls on: result.
	^ String cr join: result
]

{ #category : 'browsing' }
PosternImageBrowser class >> browseHierarchy: className [
	| cls result |
	cls := Smalltalk globals at: className asSymbol ifAbsent: [
		^ 'Class not found: ', className ].
	result := OrderedCollection new.
	result add: (String streamContents: [ :s | s nextPutAll: '=== Hierarchy of '; nextPutAll: cls name; nextPutAll: ' ===' ]).
	result add: ''.
	result add: '--- Superclasses (root first) ---'.
	result addAll: (cls allSuperclasses reversed collect: #name).
	result add: (String streamContents: [ :s | s nextPutAll: '  > '; nextPutAll: cls name; nextPutAll: '  <-- you are here' ]).
	result add: ''.
	result add: '--- Direct subclasses ---'.
	result addAll: ((cls subclasses sorted: [ :a :b | a name < b name ]) collect: [ :each | '  ', each name ]).
	cls subclasses ifEmpty: [ result add: '  (none)' ].
	^ String cr join: result
]

{ #category : 'browsing' }
PosternImageBrowser class >> browseMethod: className selector: selectorName [
	"Return the full source of a method."
	| cls |
	cls := Smalltalk globals at: className asSymbol ifAbsent: [
		^ 'Class not found: ', className ].
	(cls canUnderstand: selectorName asSymbol) ifFalse: [
		^ 'Method not found: ', className, ' >> #', selectorName ].
	^ (cls >> selectorName asSymbol) sourceCode
]

{ #category : 'private' }
PosternImageBrowser class >> classInfoFor: cls on: result [
	result add: '=== ', cls name, ' ==='.
	result add: 'Superclass chain: ', (', ' join: (cls allSuperclasses collect: #name)).
	result add: 'Instance variables: ', (', ' join: cls instVarNames).
	result add: 'Class variables: ', (', ' join: cls classVarNames).
	result add: ''.
	cls hasComment ifFalse: [ ^ self ].
	result add: '--- Comment ---'.
	result add: cls comment.
	result add: '' 
]

{ #category : 'private' }
PosternImageBrowser class >> classProtocolsFor: cls on: result [
	result add: '--- Class protocols ---'.
	result addAll: ((cls class protocolNames sorted) collect: [ :protocol |
		| selectors |
		selectors := (cls class selectorsInProtocol: protocol) sorted.
		String streamContents: [ :s | s nextPutAll: '  '; nextPutAll: protocol; nextPutAll: ': '; nextPutAll: (', ' join: selectors) ] ]).
	result add: '' 
]

{ #category : 'searching' }
PosternImageBrowser class >> implementorsOf: selectorName [
	"Find all implementors of a selector."
	| impls |
	impls := SystemNavigation default allImplementorsOf: selectorName asSymbol.
	impls ifEmpty: [ ^ 'No implementors of #', selectorName ].
	^ String cr join: (impls collect: [ :ref |
		ref methodClass name, ' >> #', ref selector ])
]

{ #category : 'private' }
PosternImageBrowser class >> instanceProtocolsFor: cls on: result [
	result add: '--- Instance protocols ---'.
	result addAll: ((cls protocolNames sorted) collect: [ :protocol |
		| selectors |
		selectors := (cls selectorsInProtocol: protocol) sorted.
		String streamContents: [ :s | s nextPutAll: '  '; nextPutAll: protocol; nextPutAll: ': '; nextPutAll: (', ' join: selectors) ] ]).
	result add: '' 
]

{ #category : 'browsing' }
PosternImageBrowser class >> lint: className [
	| cls methods results |
	cls := Smalltalk globals at: className asSymbol ifAbsent: [
		^ 'Class not found: ', className ].
	methods := cls methods asOrderedCollection.
	methods addAll: cls class methods.
	results := methods flatCollect: [ :method |
		method critiques collect: [ :critique |
			String streamContents: [ :s |
				s nextPutAll: method methodClass name;
				  nextPutAll: ' >> #';
				  nextPutAll: method selector;
				  nextPutAll: ': ';
				  nextPutAll: critique rule name ] ] ].
	results ifEmpty: [ ^ String streamContents: [ :s | s nextPutAll: 'No lint findings for '; nextPutAll: className ] ].
	^ String cr join: results
]

{ #category : 'searching' }
PosternImageBrowser class >> searchCode: aString [
	"Search all method source for a substring. Up to 50 matches."
	| matches count |
	matches := OrderedCollection new.
	count := 0.
	Smalltalk allClassesAndTraitsDo: [ :cls |
		cls methodsDo: [ :method |
			(method sourceCode includesSubstring: aString) ifTrue: [
				matches add: cls name, ' >> #', method selector.
				count := count + 1.
				count >= 50 ifTrue: [
					^ (String cr join: matches), String cr, '... (truncated at 50)' ] ] ] ].
	matches ifEmpty: [ ^ 'No methods found containing: ', aString ].
	^ String cr join: matches
]

{ #category : 'searching' }
PosternImageBrowser class >> sendersOf: selectorName [
	"Find all senders of a selector. Up to 50."
	| senders result |
	senders := SystemNavigation default allSendersOf: selectorName asSymbol.
	senders ifEmpty: [ ^ 'No senders of #', selectorName ].
	result := senders copyFrom: 1 to: (senders size min: 50).
	^ (String cr join: (result collect: [ :ref |
		ref methodClass name, ' >> #', ref selector ])),
		(senders size > 50
			ifTrue: [ String cr, '... (', (senders size - 50) printString, ' more)' ]
			ifFalse: [ '' ])
]

{ #category : 'private' }
PosternImageBrowser class >> subclassesFor: cls on: result [
	result add: 'Subclasses: ', (', ' join: (cls subclasses collect: #name))
]

{ #category : 'searching' }
PosternImageBrowser class >> suggestSelector: partial onClass: className [
	"Fuzzy-match selectors on a class. Returns up to 20 matches."
	| cls matches pat |
	cls := Smalltalk globals at: className asSymbol ifAbsent: [
		^ 'Class not found: ', className ].
	pat := partial asLowercase.
	matches := cls allSelectors
		select: [ :sel | sel asLowercase includesSubstring: pat ]
		thenCollect: [ :sel | sel asString ].
	matches := matches sorted copyFrom: 1 to: (matches size min: 20).
	matches ifEmpty: [ ^ 'No selectors matching "', partial, '" on ', className ].
	^ String cr join: matches
]
