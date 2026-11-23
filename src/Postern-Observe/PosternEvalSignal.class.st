"
DEBUG evaluation outcome. The optional error class is the only exception metadata retained.
"
Class {
	#name : 'PosternEvalSignal',
	#superclass : 'PuntLogSignal',
	#instVars : [
		'errorClass'
	],
	#category : 'Postern-Observe',
	#package : 'Postern-Observe'
}

{ #category : 'accessing' }
PosternEvalSignal class >> level [
	^ PuntLogLevel debug
]

{ #category : 'error handling' }
PosternEvalSignal >> error: anError [
	errorClass := anError class name
]

{ #category : 'printing' }
PosternEvalSignal >> fieldsOn: aStream [
	errorClass ifNotNil: [ self field: 'errorClass' value: errorClass on: aStream ]
]
