"
Zinc listener that binds the optional Postern observer to each start/stop cycle, including restarts of the same server.
"
Class {
	#name : 'PosternZincServer',
	#superclass : 'ZnManagingMultiThreadedServer',
	#category : 'Postern-Core',
	#package : 'Postern-Core'
}

{ #category : 'public' }
PosternZincServer >> start [
	| currentDelegate |
	currentDelegate := self delegate.
	self isRunning ifTrue: [ self stop: false ].
	[ (currentDelegate class canUnderstand: #prepareToStart) ifTrue: [ currentDelegate prepareToStart ].
	  super start.
	  (currentDelegate class canUnderstand: #recordServerStarted) ifTrue: [ currentDelegate recordServerStarted ] ]
		ifCurtailed: [
			self isRunning
				ifTrue: [ self stop ]
				ifFalse: [ self closeDelegate ] ]
]
