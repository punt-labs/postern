"
Tests for PosternSyncReferenceCommitCommand.

    PosternSyncReferenceCommitCommandTest new class name
    >>> #PosternSyncReferenceCommitCommandTest
"
Class {
	#name : 'PosternSyncReferenceCommitCommandTest',
	#superclass : 'TestCase',
	#category : 'Postern-IcebergExtensions-Tests',
	#package : 'Postern-IcebergExtensions-Tests'
}

{ #category : 'tests' }
PosternSyncReferenceCommitCommandTest >> testDefaultDescription [
	self assert: PosternSyncReferenceCommitCommand defaultDescription
		equals: 'Sync working copy reference commit to filesystem HEAD after CLI git operations.'
]

{ #category : 'tests' }
PosternSyncReferenceCommitCommandTest >> testDefaultName [
	self assert: PosternSyncReferenceCommitCommand defaultName
		equals: 'Sync reference commit'
]

{ #category : 'tests' }
PosternSyncReferenceCommitCommandTest >> testExecuteCoreSetsReferenceCommit [
	"Verify execute sets referenceCommit: to repo head commit via the full
	 command call chain. Uses PosternSyncTestContext stub to provide a
	 real IceTipRepositoryModel without needing the full browser stack."
	| repo repoModel ctx cmd before |
	repo := IceRepository registry
		detect: [ :r | r name = 'claude-agent-sdk-smalltalk' ]
		ifNone: [ nil ].
	repo ifNil: [ self skip ].
	repo head isUnbornBranch ifTrue: [ self skip ].
	repoModel := IceTipRepositoryModel on: repo.
	ctx := PosternSyncTestContext new
		repositoryModel: repoModel;
		yourself.
	cmd := PosternSyncReferenceCommitCommand new
		context: ctx;
		yourself.
	before := repo workingCopy referenceCommit.
	[
		cmd execute.
		self assert: repo workingCopy referenceCommit id equals: repo head commit id
	] ensure: [
		repo workingCopy referenceCommit: before
	]
]

{ #category : 'tests' }
PosternSyncReferenceCommitCommandTest >> testExecuteNoContextReturnsGracefully [
	"execute with no context set must return self without error.
	 A fresh PosternSyncReferenceCommitCommand new has nil context —
	 the first guard (self context ifNil: [ ^ self ]) must fire."
	| cmd result |
	cmd := PosternSyncReferenceCommitCommand new.
	result := cmd execute.
	self assert: result identicalTo: cmd
]

{ #category : 'tests' }
PosternSyncReferenceCommitCommandTest >> testExtensionMethodExists [
	self assert: (IceTipRepositoriesBrowser respondsTo: #posternCommandsWith:forRootGroup:)
]

{ #category : 'tests' }
PosternSyncReferenceCommitCommandTest >> testIconName [
	self assert: PosternSyncReferenceCommitCommand new iconName
		equals: #smallUpdate
]

{ #category : 'tests' }
PosternSyncReferenceCommitCommandTest >> testIsSubclassOfIceTipRepositoryCommand [
	self assert: PosternSyncReferenceCommitCommand superclass
		equals: IceTipRepositoryCommand
]
