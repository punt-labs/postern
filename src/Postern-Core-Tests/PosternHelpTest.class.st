"
Unit tests for PosternHelp — the /help endpoint content holder.

This class covers sectionFor: dispatch (happy path, unknown section, and
the blocked-selector guard that prevents /help/<segment> from being used
to invoke arbitrary class-side methods). Routing tests live in
PosternServerTest; drift-detection tests are deferred to bead 3kt.4.
"
Class {
	#name : 'PosternHelpTest',
	#superclass : 'TestCase',
	#category : 'Postern-Core-Tests',
	#package : 'Postern-Core-Tests'
}

{ #category : 'private' }
PosternHelpTest >> addLine: aLine toSnippets: snippets current: current [
	"Process one line of a code fence, accumulating into current
	and flushing to snippets when a new block starts.
	Returns the (possibly replaced) current collection."
	| cr isRef isNew |
	cr := String with: Character cr.
	isRef := self isClassRefLine: aLine.
	isNew := isRef not and: [
		self isNewBlockLine: aLine withPriorLines: current ].
	(isRef or: [ isNew ]) ifTrue: [
		current ifNotEmpty: [ snippets add: (cr join: current) ].
		^ OrderedCollection with: (isRef
			ifTrue: [ self stripClassRef: aLine ]
			ifFalse: [ aLine ]) ].
	current add: aLine.
	^ current
]

{ #category : 'private' }
PosternHelpTest >> canParseExpression: aString [
	"Answer true if RBParser can parse aString as an expression."
	^ [ RBParser parseExpression: aString. true ]
		on: CodeError
		do: [ :e | e return: false ]
]

{ #category : 'private' }
PosternHelpTest >> canParseMethod: aString [
	"Answer true if RBParser can parse aString as a method definition."
	^ [ RBParser parseMethod: aString. true ]
		on: CodeError
		do: [ :e | e return: false ]
]

{ #category : 'private' }
PosternHelpTest >> classNameAndMetaFrom: aString beforeArrow: idx [
	"Extract the class name and meta flag from text before ' >> '.
	Returns { className. isMeta } or nil if unparseable."
	| before className isMeta words |
	before := (aString copyFrom: 1 to: idx - 1) trimBoth.
	(before notEmpty and: [ before last = $( ])
		ifTrue: [ before := before allButLast trimRight ].
	words := before substrings: ' 	('.
	words ifEmpty: [ ^ nil ].
	className := words last.
	isMeta := className = 'class'.
	isMeta ifTrue: [
		words size < 2 ifTrue: [ ^ nil ].
		className := words at: words size - 1 ].
	^ { className. isMeta }
]

{ #category : 'private' }
PosternHelpTest >> extractFenceFrom: aString at: markerStart [
	"Extract a single code fence starting at markerStart.
	Returns position -> code (or position -> nil if malformed)."
	| codeStart codeEnd code |
	codeStart := markerStart + '```smalltalk' size.
	(codeStart <= aString size
		and: [ (aString at: codeStart) = Character cr ])
		ifTrue: [ codeStart := codeStart + 1 ].
	codeEnd := aString indexOfSubCollection: '```' startingAt: codeStart.
	codeEnd = 0
		ifTrue: [ ^ aString size + 1 -> nil ].
	code := aString copyFrom: codeStart to: codeEnd - 1.
	(code notEmpty and: [ code last = Character cr ])
		ifTrue: [ code := code allButLast ].
	^ codeEnd + 3 -> code
]

{ #category : 'private' }
PosternHelpTest >> isClassRefLine: aString [
	"Answer true if the line is a ClassName class >> or ClassName >> prefix."
	| trimmed |
	trimmed := aString trimLeft.
	^ (trimmed matchesRegex: '[A-Z][A-Za-z0-9]+ class >> .*')
		or: [ trimmed matchesRegex: '[A-Z][A-Za-z0-9]+ >> .*' ]
]

{ #category : 'private' }
PosternHelpTest >> isNewBlockLine: aString withPriorLines: aCollection [
	"Answer true if this line starts a new temp declaration block
	after prior statements."
	| trimmed |
	aCollection ifEmpty: [ ^ false ].
	trimmed := aString trimLeft.
	(trimmed matchesRegex: '\|[^|]+\|') ifFalse: [ ^ false ].
	^ aCollection anySatisfy: [ :prev |
		| pt |
		pt := prev trimLeft.
		pt notEmpty and: [ pt first ~= $" ] ]
]

{ #category : 'private' }
PosternHelpTest >> isNonSmalltalkLine: aString [
	"Answer true if the line is a non-Smalltalk comment like # => ..."
	| trimmed |
	trimmed := aString trimLeft.
	^ trimmed size > 1
		and: [ trimmed first = $# and: [ (trimmed at: 2) = $  ] ]
]

{ #category : 'private' }
PosternHelpTest >> parseSelectorReference: aLine [
	"Parse a ClassName >> #selector reference from a line.
	Returns { className. isMeta. selector } or nil."
	| idx classAndMeta |
	idx := aLine indexOfSubCollection: ' >> '.
	idx = 0 ifTrue: [ ^ nil ].
	classAndMeta := self classNameAndMetaFrom: aLine beforeArrow: idx.
	classAndMeta ifNil: [ ^ nil ].
	(self selectorReferencePlaceholders includes: classAndMeta first)
		ifTrue: [ ^ nil ].
	^ { classAndMeta first. classAndMeta second.
		self selectorFrom: aLine afterArrow: idx }
]

{ #category : 'private' }
PosternHelpTest >> parseSnippet: aString [
	"Try to parse a Smalltalk snippet as an expression, then as a
	method definition. Returns nil on success, or an error description
	on failure."
	| trimmed |
	trimmed := aString trimBoth.
	trimmed ifEmpty: [ ^ nil ].
	(self canParseExpression: trimmed) ifTrue: [ ^ nil ].
	(self canParseMethod: trimmed) ifTrue: [ ^ nil ].
	^ 'Unparseable: ' , (trimmed copyFrom: 1 to: (60 min: trimmed size))
]

{ #category : 'private' }
PosternHelpTest >> projectClassNamesIn: aString [
	"Extract backtick-quoted words that look like project class names."
	| names start |
	names := OrderedCollection new.
	start := 1.
	[ start := aString indexOf: $` startingAt: start.
	  start > 0 ] whileTrue: [
		| endTick word isProject |
		endTick := aString indexOf: $` startingAt: start + 1.
		endTick > 0
			ifTrue: [
				word := aString copyFrom: start + 1 to: endTick - 1.
				isProject := word notEmpty
					and: [ word first isUppercase
					and: [ (word allSatisfy: [ :c | c isAlphaNumeric ])
					and: [ self projectPrefixes anySatisfy: [ :p | word beginsWith: p ] ] ] ].
				isProject ifTrue: [ names add: word ].
				start := endTick + 1 ]
			ifFalse: [ start := aString size + 1 ] ].
	^ names
]

{ #category : 'private' }
PosternHelpTest >> projectPrefixes [
	"Class name prefixes that identify project-specific classes."
	^ #('Postern' 'ManifestPostern')
]

{ #category : 'private' }
PosternHelpTest >> sectionSelectors [
	"All class-side selectors in the 'help content' protocol."
	^ PosternHelp class selectorsInProtocol: 'help content'
]

{ #category : 'private' }
PosternHelpTest >> selectorFrom: aString afterArrow: idx [
	"Extract the selector name from text after ' >> '."
	| selectorPart |
	selectorPart := (aString copyFrom: idx + 4 to: aString size) trimLeft.
	(selectorPart notEmpty and: [ selectorPart first = $# ])
		ifTrue: [ selectorPart := selectorPart allButFirst ].
	^ (selectorPart substrings: ' )') first
]

{ #category : 'private' }
PosternHelpTest >> selectorReferencePlaceholders [
	"Class names used as placeholders in documentation examples."
	^ #('MyClass' 'MySubclass' 'MyClassTest' 'MyPackage')
]

{ #category : 'private' }
PosternHelpTest >> smalltalkFencesIn: aString [
	"Extract Smalltalk code fences from Markdown content."
	| fences start |
	fences := OrderedCollection new.
	start := 1.
	[ start := aString indexOfSubCollection: '```smalltalk' startingAt: start.
	  start > 0 ] whileTrue: [
		| result |
		result := self extractFenceFrom: aString at: start.
		result value ifNotNil: [ :code | fences add: code ].
		start := result key ].
	^ fences
]

{ #category : 'private' }
PosternHelpTest >> snippetsFrom: aCodeFence [
	"Split a code fence into individual parseable snippets.
	Handles fences with multiple method definitions separated by
	ClassName class >> prefixes, or multiple expression blocks
	separated by comment headers."
	| cr snippets lines current |
	cr := String with: Character cr.
	lines := aCodeFence lines reject: [ :line |
		self isNonSmalltalkLine: line ].
	snippets := OrderedCollection new.
	current := OrderedCollection new.
	lines do: [ :line |
		current := self addLine: line toSnippets: snippets current: current ].
	current ifNotEmpty: [ snippets add: (cr join: current) ].
	^ snippets
]

{ #category : 'private' }
PosternHelpTest >> stripClassRef: aString [
	"Strip the ClassName (class) >> prefix from a line, returning
	just the method signature part."
	| trimmed idx |
	trimmed := aString trimLeft.
	idx := trimmed indexOfSubCollection: ' >> '.
	^ trimmed copyFrom: idx + 4 to: trimmed size
]

{ #category : 'tests' }
PosternHelpTest >> testCodeFencesParse [
	"Mechanism 1: Every Smalltalk code fence in every section must
	parse via RBParser. Catches typos, deprecated syntax, and
	missing selectors in documented code examples."
	| failures |
	failures := OrderedCollection new.
	self sectionSelectors do: [ :sel |
		(self smalltalkFencesIn: (PosternHelp perform: sel)) do: [ :fence |
			(self snippetsFrom: fence) do: [ :snippet |
				(self parseSnippet: snippet) ifNotNil: [ :error |
					failures add: sel -> error ] ] ] ].
	self assert: failures isEmpty description: (String streamContents: [ :s |
		s nextPutAll: 'Unparseable code fences:'.
		failures do: [ :assoc |
			s cr; nextPutAll: assoc key asString; nextPutAll: ': '; nextPutAll: assoc value ] ])
]

{ #category : 'tests' }
PosternHelpTest >> testPharoVersionPin [
	"Mechanism 4: The help content was authored for a specific Pharo
	version. When the image is upgraded, this test fails, forcing
	a review of the help content."
	self
		assert: (SystemVersion current imageVersionString
			beginsWith: PosternHelp expectedPharoVersion)
		description: 'Pharo version changed from ',
			PosternHelp expectedPharoVersion,
			' to ',
			SystemVersion current imageVersionString,
			'. Review help content for compatibility.'
]

{ #category : 'tests' }
PosternHelpTest >> testReferencedProjectClassesExist [
	"Mechanism 3: Every backtick-quoted project class name in the
	help content must exist in the image. Catches renamed or
	removed classes."
	| failures |
	failures := OrderedCollection new.
	self sectionSelectors do: [ :sel |
		(self projectClassNamesIn: (PosternHelp perform: sel)) do: [ :name |
			(Smalltalk globals includesKey: name asSymbol)
				ifFalse: [ failures add: sel -> name ] ] ].
	self assert: failures isEmpty description: (String streamContents: [ :s |
		s nextPutAll: 'Missing project classes:'.
		failures do: [ :assoc |
			s cr; nextPutAll: assoc key asString;
				nextPutAll: ': `'; nextPutAll: assoc value; nextPutAll: '` not found' ] ])
]

{ #category : 'tests' }
PosternHelpTest >> testReferencedSelectorsExist [
	"Mechanism 2: Every ClassName >> #selector reference in the help
	content must resolve to an existing method. Catches renamed or
	removed methods."
	| failures |
	failures := OrderedCollection new.
	self sectionSelectors do: [ :sel |
		(PosternHelp perform: sel) lines do: [ :line |
			(self parseSelectorReference: line) ifNotNil: [ :ref |
				(self verifySelectorReference: ref) ifNotNil: [ :error |
					failures add: sel -> error ] ] ] ].
	self assert: failures isEmpty description: (String streamContents: [ :s |
		s nextPutAll: 'Broken selector references:'.
		failures do: [ :assoc |
			s cr; nextPutAll: assoc key asString; nextPutAll: ': '; nextPutAll: assoc value ] ])
]

{ #category : 'tests' }
PosternHelpTest >> testSectionForReturnsNilForBlockedSelector [
	"The dispatch table is a whitelist. Selectors that exist on the
	metaclass (class, name, sectionFor:, yourself, printOn:) must NOT
	be routed by sectionFor: — otherwise /help/<segment> would be a
	backdoor into the metaclass."
	self assert: (PosternHelp sectionFor: 'class') isNil.
	self assert: (PosternHelp sectionFor: 'sectionFor:') isNil.
	self assert: (PosternHelp sectionFor: 'name') isNil.
	self assert: (PosternHelp sectionFor: 'yourself') isNil.
	self assert: (PosternHelp sectionFor: 'printOn:') isNil
]

{ #category : 'tests' }
PosternHelpTest >> testSectionForReturnsNilForUnknownSection [
	self assert: (PosternHelp sectionFor: 'nonsense') isNil.
	self assert: (PosternHelp sectionFor: 'tableOfContents') isNil.
	self assert: (PosternHelp sectionFor: '') isNil
]

{ #category : 'tests' }
PosternHelpTest >> testSectionForReturnsStringForKnownSection [
	"All 9 sections return non-trivial Markdown content."
	| sections |
	sections := #( 'api' 'makefile' 'pharo' 'lint' 'dispatch' 'git' 'testing' 'safety' 'lessons' ).
	sections do: [ :name |
		| content |
		content := PosternHelp sectionFor: name.
		self assert: content isString.
		self assert: content size > 200.
		self deny: (content includesSubstring: 'TODO') ]
]

{ #category : 'tests' }
PosternHelpTest >> testTableOfContentsReturnsMarkdown [
	| toc |
	toc := PosternHelp tableOfContents.
	self assert: toc isString.
	self assert: (toc includesSubstring: '# Postern /help').
	self assert: (toc includesSubstring: '## Sections').
	self assert: (toc includesSubstring: '/help/api')
]

{ #category : 'private' }
PosternHelpTest >> verifySelectorReference: anArray [
	"Verify a parsed selector reference { className. isMeta. selector }.
	Returns nil if valid, or an error description string."
	| className isMeta selector classObj target |
	className := anArray first.
	isMeta := anArray second.
	selector := anArray third.
	classObj := Smalltalk globals at: className asSymbol ifAbsent: [ nil ].
	classObj ifNil: [ ^ 'class ' , className , ' not found' ].
	target := isMeta ifTrue: [ classObj class ] ifFalse: [ classObj ].
	(target canUnderstand: selector asSymbol) ifFalse: [
		^ String streamContents: [ :s |
			s nextPutAll: className.
			isMeta ifTrue: [ s nextPutAll: ' class' ].
			s nextPutAll: ' does not understand #'; nextPutAll: selector ] ].
	^ nil
]
