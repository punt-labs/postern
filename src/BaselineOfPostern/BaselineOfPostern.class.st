"
A Metacello baseline for the Postern package (Pharo 12 remote image driver).

Declares Postern-Core, Postern-Dashboard, Postern-IcebergExtensions, Postern-Observe, and test packages
with three loading groups: default (Core + Dashboard + IcebergExtensions + Observe), tests, and all.

Loading examples -- load default group:

  Metacello new
    baseline: 'Postern';
    repository: 'github://punt-labs/postern:main';
    load.

Loading examples -- load all including tests:

  Metacello new
    baseline: 'Postern';
    repository: 'github://punt-labs/postern:main';
    load: 'all'.
"
Class {
	#name : 'BaselineOfPostern',
	#superclass : 'BaselineOf',
	#category : 'BaselineOfPostern-Baseline',
	#package : 'BaselineOfPostern',
	#tag : 'Baseline'
}

{ #category : 'baselines' }
BaselineOfPostern >> baseline: spec [
	<baseline>
	spec for: #common do: [
		spec baseline: 'PuntObserve' with: [
			spec repository: 'github://punt-labs/punt-observe-pharo:main/src' ].
		spec
			package: 'Postern-Core';
			package: 'Postern-Core-Tests' with: [ spec requires: 'Postern-Core' ];
			package: 'Postern-Dashboard' with: [ spec requires: 'Postern-Core' ];
			package: 'Postern-Dashboard-Tests' with: [ spec requires: 'Postern-Dashboard' ];
			package: 'Postern-IcebergExtensions' with: [ spec requires: 'Postern-Core' ];
			package: 'Postern-IcebergExtensions-Tests' with: [ spec requires: 'Postern-IcebergExtensions' ];
			package: 'Postern-Observe' with: [ spec requires: #('Postern-Core' 'PuntObserve') ];
			package: 'Postern-Observe-Tests' with: [ spec requires: 'Postern-Observe' ].
		spec
			group: 'default' with: #('Postern-Core' 'Postern-Dashboard' 'Postern-IcebergExtensions' 'Postern-Observe');
			group: 'tests' with: #('Postern-Core-Tests' 'Postern-Dashboard-Tests' 'Postern-IcebergExtensions-Tests' 'Postern-Observe-Tests');
			group: 'all' with: #('default' 'tests') ]
]
