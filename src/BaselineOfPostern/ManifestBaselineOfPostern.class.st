"
Package manifest for BaselineOfPostern. Declares Renraku false-positive suppressions.
"
Class {
	#name : 'ManifestBaselineOfPostern',
	#superclass : 'PackageManifest',
	#category : 'BaselineOfPostern-Manifest',
	#package : 'BaselineOfPostern',
	#tag : 'Manifest'
}

{ #category : 'code-critics' }
ManifestBaselineOfPostern class >> ruleClassNotReferencedRuleV1FalsePositive [
	<ignoreForCoverage>
	^ #(#(#(#RGClassDefinition #(#BaselineOfPostern)) #'2026-04-10T00:00:00.000000-00:00') )
]
