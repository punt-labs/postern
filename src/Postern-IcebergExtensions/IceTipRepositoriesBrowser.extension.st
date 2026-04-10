Extension { #name : 'IceTipRepositoriesBrowser' }

{ #category : '*Postern-IcebergExtensions' }
IceTipRepositoriesBrowser class >> posternCommandsWith: presenter forRootGroup: aCommandGroup [
    <extensionCommands>
    (aCommandGroup / IceTipBrowser selectionCommandGroupName)
        register: (PosternSyncReferenceCommitCommand forSpecContext: presenter)
]
