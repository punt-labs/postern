"
Versioned request counter bucketed by a closed route and HTTP status class, without paths or identifiers.
"
Class {
	#name : 'PosternRequestCountV1',
	#superclass : 'PuntTelemetrySchema',
	#instVars : [
		'route',
		'status'
	],
	#category : 'Postern-Observe',
	#package : 'Postern-Observe'
}

{ #category : 'accessing' }
PosternRequestCountV1 class >> fieldSpecs [
	^ Dictionary new
		at: #route put: (PuntTelemetryField enum: #(health help repl other) required: true);
		at: #status put: (PuntTelemetryField enum: #(informational success redirect clientError serverError) required: true);
		yourself
]

{ #category : 'accessing' }
PosternRequestCountV1 class >> signalKind [
	^ #counter
]

{ #category : 'accessing' }
PosternRequestCountV1 class >> signalName [
	^ 'postern.http.requests'
]

{ #category : 'accessing' }
PosternRequestCountV1 class >> unit [
	^ '1'
]

{ #category : 'accessing' }
PosternRequestCountV1 >> route [
	^ route
]

{ #category : 'accessing' }
PosternRequestCountV1 >> route: aSymbol [
	route := aSymbol
]

{ #category : 'accessing' }
PosternRequestCountV1 >> status [
	^ status
]

{ #category : 'accessing' }
PosternRequestCountV1 >> status: aSymbol [
	status := aSymbol
]
