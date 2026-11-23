"
Versioned eval counter; only the closed success or failure outcome is recorded.
"
Class {
	#name : 'PosternEvalCountV1',
	#superclass : 'PuntTelemetrySchema',
	#instVars : [
		'outcome'
	],
	#category : 'Postern-Observe',
	#package : 'Postern-Observe'
}

{ #category : 'accessing' }
PosternEvalCountV1 class >> fieldSpecs [
	^ Dictionary new
		at: #outcome put: (PuntTelemetryField enum: #(succeeded failed) required: true);
		yourself
]

{ #category : 'accessing' }
PosternEvalCountV1 class >> signalKind [
	^ #counter
]

{ #category : 'accessing' }
PosternEvalCountV1 class >> signalName [
	^ 'postern.repl.evaluations'
]

{ #category : 'accessing' }
PosternEvalCountV1 class >> unit [
	^ '1'
]

{ #category : 'accessing' }
PosternEvalCountV1 >> outcome [
	^ outcome
]

{ #category : 'accessing' }
PosternEvalCountV1 >> outcome: aSymbol [
	outcome := aSymbol
]
