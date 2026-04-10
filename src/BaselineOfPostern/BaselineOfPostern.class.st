"
A Metacello baseline for the Postern package (Pharo 12 remote image driver).

Declares Postern-Core, Postern-Dashboard, Postern-IcebergExtensions, and test packages
with three loading groups: default (Core + Dashboard + IcebergExtensions), tests, and all.

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
		spec
			package: 'Postern-Core';
			package: 'Postern-Core-Tests' with: [ spec requires: 'Postern-Core' ];
			package: 'Postern-Dashboard' with: [ spec requires: 'Postern-Core' ];
			package: 'Postern-Dashboard-Tests' with: [ spec requires: 'Postern-Dashboard' ];
			package: 'Postern-IcebergExtensions' with: [ spec requires: 'Postern-Core' ];
			package: 'Postern-IcebergExtensions-Tests' with: [ spec requires: 'Postern-IcebergExtensions' ].
		spec
			group: 'default' with: #('Postern-Core' 'Postern-Dashboard' 'Postern-IcebergExtensions');
			group: 'tests' with: #('Postern-Core-Tests' 'Postern-Dashboard-Tests' 'Postern-IcebergExtensions-Tests');
			group: 'all' with: #('default' 'tests') ]
]
