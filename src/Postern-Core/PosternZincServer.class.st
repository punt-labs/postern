"
Zinc listener that binds the optional Postern observer to each start/stop cycle, including restarts of the same server.
"
Class {
	#name : 'PosternZincServer',
	#superclass : 'ZnManagingMultiThreadedServer',
	#category : 'Postern-Core',
	#package : 'Postern-Core'
}

{ #category : 'initialize-release' }
PosternZincServer >> start [
	| posternDelegate |
	posternDelegate := self delegate.
	self isRunning ifTrue: [ self stop: false ].
	[ posternDelegate prepareToStart.
	  super start.
	  posternDelegate recordServerStarted ]
		ifCurtailed: [
			self isRunning
				ifTrue: [ self stop ]
				ifFalse: [ posternDelegate close ] ]
]
