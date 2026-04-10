"
Minimal test context stub for PosternSyncReferenceCommitCommandTest.

Provides a #repositoryModel accessor so a PosternSyncReferenceCommitCommand
can be constructed without a full IceTipRepositoriesBrowser presenter stack.

    PosternSyncTestContext new class name
    >>> #PosternSyncTestContext
"
Class {
	#name : 'PosternSyncTestContext',
	#superclass : 'Object',
	#instVars : [
		'model'
	],
	#category : 'Postern-IcebergExtensions-Tests',
	#package : 'Postern-IcebergExtensions-Tests'
}

{ #category : 'accessing' }
PosternSyncTestContext >> repositoryModel [
	^ model
]

{ #category : 'accessing' }
PosternSyncTestContext >> repositoryModel: aModel [
	model := aModel
]
