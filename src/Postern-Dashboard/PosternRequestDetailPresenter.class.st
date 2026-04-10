"
Sub-presenter showing the request body and response body for a selected PosternRequest. Instantiated on: a PosternDashboardModel.

### Usage (inside a parent presenter)

	detailPresenter := self instantiate: PosternRequestDetailPresenter on: model.
	detailPresenter showEntry: anEntry.

### Examples

	(PosternRequestDetailPresenter on: PosternDashboardModel new) model class name
	>>> #PosternDashboardModel

"
Class {
	#name : 'PosternRequestDetailPresenter',
	#superclass : 'SpPresenter',
	#instVars : [
		'model',
		'requestText',
		'responseText'
	],
	#category : 'Postern-Dashboard',
	#package : 'Postern-Dashboard'
}

{ #category : 'api' }
PosternRequestDetailPresenter >> clear [
	requestText text: ''.
	responseText text: ''
]

{ #category : 'layout' }
PosternRequestDetailPresenter >> defaultLayout [
	^ SpPanedLayout newTopToBottom
		add: requestText;
		add: responseText;
		yourself
]

{ #category : 'private' }
PosternRequestDetailPresenter >> formatCode: aString [
	"Attempt to pretty-print aString as Smalltalk. Returns the
	formatted source, or the original string if parsing fails
	(e.g. plain text, JSON, error messages)."
	| trimmed |
	trimmed := aString ifNil: [ ^ '' ].
	trimmed := trimmed trimBoth.
	trimmed ifEmpty: [ ^ '' ].
	^ [ RBSimpleFormatter format: (RBParser parseExpression: trimmed) ]
		on: Error
		do: [ :ex | trimmed ]
]

{ #category : 'initialization' }
PosternRequestDetailPresenter >> initializePresenters [
	requestText := self newCode
		beForScripting;
		beNotEditable;
		withoutLineNumbers;
		yourself.
	responseText := self newCode
		beForScripting;
		beNotEditable;
		withoutLineNumbers;
		yourself
]

{ #category : 'accessing' }
PosternRequestDetailPresenter >> model [
	^ model
]

{ #category : 'accessing - model' }
PosternRequestDetailPresenter >> setModelBeforeInitialization: aPosternDashboardModel [
	model := aPosternDashboardModel
]

{ #category : 'api' }
PosternRequestDetailPresenter >> showEntry: anEntry [
	"Display the request and response bodies for the given log entry."
	anEntry
		ifNil: [ self clear ]
		ifNotNil: [
			requestText text: (self formatCode: anEntry requestBody).
			responseText text: (self formatCode: anEntry responseBody) ]
]
