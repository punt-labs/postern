"
HTTP eval server for the Postern remote-eval surface. Wraps ZnServer with PosternDelegate, which normalizes LF line endings to CR before evaluation. Supports optional token-based authentication. Usage: PosternServer startOn: 8422 (no auth). PosternServer startOn: 8422 withAuth: true (auth enabled, token written to .tmp/eval-token).

### Examples

```
PosternServer new class name
>>> 'PosternServer'
```

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
	"Start a ZnServer with LF-normalizing eval delegate on the given port."
	| server delegate |
	delegate := PosternDelegate new.
	server := ZnServer on: port.
	server serverId: 'postern-', port printString.
	delegate server: server.
	server delegate: delegate.
	server start.
	^ server
]

{ #category : 'instance creation' }
PosternServer class >> startOn: port withAuth: aBoolean [
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
	server serverId: 'postern-', port printString.
	delegate server: server.
	server delegate: delegate.
	server start.
	^ server
]
