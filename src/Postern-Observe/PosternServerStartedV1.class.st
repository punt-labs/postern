"
Versioned counter incremented once per Postern server start; carries no attributes.
"
Class {
	#name : 'PosternServerStartedV1',
	#superclass : 'PuntTelemetrySchema',
	#category : 'Postern-Observe',
	#package : 'Postern-Observe'
}

{ #category : 'accessing' }
PosternServerStartedV1 class >> signalKind [
	^ #counter
]

{ #category : 'accessing' }
PosternServerStartedV1 class >> signalName [
	^ 'postern.server.started'
]

{ #category : 'accessing' }
PosternServerStartedV1 class >> unit [
	^ '1'
]
