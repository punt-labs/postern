"
Malformed request warning containing only the exception class, never URI or parser text.
"
Class {
	#name : 'PosternMalformedRequestSignal',
	#superclass : 'PuntLogSecuritySignal',
	#instVars : [
		'errorClass'
	],
	#category : 'Postern-Observe',
	#package : 'Postern-Observe'
}

{ #category : 'error handling' }
PosternMalformedRequestSignal >> error: anError [
	errorClass := anError class name
]

{ #category : 'printing' }
PosternMalformedRequestSignal >> fieldsOn: aStream [
	self field: 'errorClass' value: errorClass on: aStream
]
