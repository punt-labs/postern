"
HTTP eval server for the Postern remote-eval surface. Wraps ZnServer with PosternDelegate, which normalizes LF line endings to CR before evaluation.

Binding and authentication policy:
- Loopback (localhost only): startOn: or startOn:withAuth: — safe for local development and CI
- Public (all interfaces): startPublicOn: — authentication always required; no unauthenticated public mode

Usage:
  PosternServer startOn: 8422.                   ""loopback, no auth""
  PosternServer startOn: 8422 withAuth: true.    ""loopback, auth required; token in .tmp/eval-token""
  PosternServer startPublicOn: 8422.             ""all interfaces, auth required; token in .tmp/eval-token""

### Examples

PosternServer new class name
>>> 'PosternServer'
"
Class {
	#name : 'PosternServer',
	#superclass : 'Object',
	#category : 'Postern-Core',
	#package : 'Postern-Core'
}

{ #category : 'private' }
PosternServer class >> generateToken [
	| hex chars rng |
	chars := '0123456789abcdef'.
	rng := Random new.
	hex := String new: 8.
	1 to: 8 do: [ :i |
		hex at: i put: (chars at: (rng nextInteger: 16)) ].
	^ hex
]

{ #category : 'instance creation' }
PosternServer class >> startOn: port [
	"Start on loopback with no authentication. Safe for local development."
	| server delegate |
	delegate := PosternDelegate new.
	server := ZnServer on: port.
	server bindingAddress: NetNameResolver loopBackAddress.
	server serverId: 'postern-', port printString.
	delegate server: server.
	server delegate: delegate.
	server start.
	^ server
]

{ #category : 'instance creation' }
PosternServer class >> startOn: port withAuth: aBoolean [
	"Start on loopback with optional authentication."
	| server delegate |
	delegate := PosternDelegate new.
	aBoolean ifTrue: [
		| token |
		token := self generateToken.
		delegate token: token.
		delegate authEnabled: true.
		'.tmp' asFileReference ensureCreateDirectory.
		('.tmp/eval-token' asFileReference)
			ensureDelete;
			writeStreamDo: [ :s | s nextPutAll: token ] ].
	server := ZnServer on: port.
	server bindingAddress: NetNameResolver loopBackAddress.
	server serverId: 'postern-', port printString.
	delegate server: server.
	server delegate: delegate.
	server start.
	^ server
]

{ #category : 'instance creation' }
PosternServer class >> startPublicOn: port [
	"Start on all interfaces with authentication required.
	 Auth is always enabled for public binding — there is no unauthenticated public mode."
	| server delegate token |
	delegate := PosternDelegate new.
	token := self generateToken.
	delegate token: token.
	delegate authEnabled: true.
	'.tmp' asFileReference ensureCreateDirectory.
	('.tmp/eval-token' asFileReference)
		ensureDelete;
		writeStreamDo: [ :s | s nextPutAll: token ].
	server := ZnServer on: port.
	server serverId: 'postern-', port printString.
	delegate server: server.
	server delegate: delegate.
	server start.
	^ server
]
