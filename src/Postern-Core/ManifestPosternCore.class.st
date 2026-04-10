"
Renraku rule false-positive declarations for the Postern-Core package.

PosternWidget is the menu-bar status strip for the eval server. It holds one slot per labelled status field (port, request count, uptime, last request, token visibility, etc.) plus button references and timer state. The slot count is the widget surface; collapsing them would split a single visual unit across multiple objects.

This class is installed without a tag so the package keeps a single PackageTag (#Uncategorized) and ReClassNotCategorizedRule does not fire on the other classes in the package.
"
Class {
	#name : 'ManifestPosternCore',
	#superclass : 'PackageManifest',
	#category : 'Postern-Core',
	#package : 'Postern-Core'
}

{ #category : 'code-critics' }
ManifestPosternCore class >> ruleRePackageManifestShouldBePackagedInManifestTagRuleV1FalsePositive [
	"This manifest is intentionally NOT in a Manifest package tag — see
	the class comment for the rationale."
	^ #(
		#(#(#RGClassDefinition #(#ManifestPosternCore)) #'2026-04-07T00:00:00+00:00')
	)
]
