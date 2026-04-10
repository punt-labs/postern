"
A Commander command that syncs IceWorkingCopy referenceCommit to the
filesystem HEAD after CLI git operations. Fixes the detached working copy
condition that appears when commits, pulls, or pushes happen outside Iceberg.

After execution, the Iceberg repositories browser refreshes automatically
via the IceRepositoryModified announcement.

    PosternSyncReferenceCommitCommand new class name
    >>> #PosternSyncReferenceCommitCommand
"
Class {
	#name : 'PosternSyncReferenceCommitCommand',
	#superclass : 'IceTipRepositoryCommand',
	#category : 'Postern-IcebergExtensions',
	#package : 'Postern-IcebergExtensions'
}

{ #category : 'default' }
PosternSyncReferenceCommitCommand class >> defaultDescription [
	^ 'Sync working copy reference commit to filesystem HEAD after CLI git operations.'
]

{ #category : 'default' }
PosternSyncReferenceCommitCommand class >> defaultName [
	^ 'Sync reference commit'
]

{ #category : 'executing' }
PosternSyncReferenceCommitCommand >> execute [
	| repo |
	self context ifNil: [ ^ self ].
	repo := self repository.
	repo ifNil: [ ^ self ].
	repo head isUnbornBranch ifTrue: [ ^ self ].
	repo workingCopy referenceCommit: repo head commit.
	Iceberg announcer announce: (IceRepositoryModified new repository: repo; yourself).
	^ self
]

{ #category : 'accessing' }
PosternSyncReferenceCommitCommand >> iconName [
	^ #smallUpdate
]
