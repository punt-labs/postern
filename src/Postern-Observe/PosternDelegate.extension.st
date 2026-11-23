Extension { #name : 'PosternDelegate' }

{ #category : '*Postern-Observe' }
PosternDelegate >> attachObservability [
	observability ifNotNil: [ ^ self ].
	PosternObservability open.
	observability := PosternObservability
]
