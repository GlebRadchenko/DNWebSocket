# DNWebSocket

<p align="center">
<a href="https://developer.apple.com/swift/" target="_blank">
<img src="https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat" alt="Swift 4.0">
</a>
<a href="https://github.com/GlebRadchenko/DNWebSocket/blob/master/LICENSE" target="_blank">
<img src="https://img.shields.io/packagist/l/doctrine/orm.svg" alt="MIT">
</a>
</p>

Object-Oriented, Swift-style WebSocket Library ([RFC 6455](https://tools.ietf.org/html/rfc6455>)) for Swift-compatible Platforms.

- [Tests](#tests)
- [Installation](#installation)
- [Requirements](#requirements)
- [Usage](#usage)


## Tests

Conforms to all necessary Autobahn fuzzing tests. [Autobahn](https://github.com/crossbario/autobahn-testsuite)

Test results for DNWebSocket you can see [here](https://glebradchenko.github.io/dnwebsocket.github.io/).

In comparison with [SocketRocket](http://facebook.github.io/SocketRocket/results/), this library shows 2-10 times better performance in many Limits/Performance tests.

Cases 6.4.1, 6.4.2, 6.4.3, 6.4.4 received result Non-Strict due to perfomance improvements(it's complicated to validate each fragmented text message)

## Installation

### Cocoapods

To install DNWebSocket via [CocoaPods](http://cocoapods.org), get it:

```bash
$ gem install cocoapods
```

Then, create a `Podfile` in your project root directory:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Target Name>' do
    pod 'DNWebSocket', '~> 1.1.0'
end
```

And run:

```bash
$ pod install
```
For swift version < 4.2 use 1.0.2 version of pod.

### Swift Package Manager

Currently, I'm looking for a generic approach which will allow to use C libraries with all Package Managers.
So right now, please, use [DNWebSocket-SPM](https://github.com/GlebRadchenko/DNWebSocket-SPM) repo.

## Requirements

- iOS 8.0+ / macOS 10.10+ / tvOS 9.0+ / watchOS 2.0+
- Swift 4.0 + (but I didn't try earlier versions by the way :D)

## Usage

Import library as follows: 
 
  ``` swift
  import DNWebSocket
```

Now create websocket, configure it and connect:

``` swift
let websocket = WebSocket(url: URL(string: "wss://echo.websocket.org:80")!,
                          timeout: 10,
                          protocols: ["chat", "superchat"])

websocket.onConnect = {
    print("connected")
    websocket.sendPing(data: Data())
}

websocket.onData = { (data) in
    websocket.send(data: data)
}

websocket.onText = { (text) in
    websocket.send(string: text)
}

websocket.onPing = { (data) in
    websocket.sendPong(data: data)
}

websocket.onPong = { (data) in
    print("Received pong from server")
}

websocket.onDebugInfo = { (debugInfo) in
    print(debugInfo)
}

websocket.onDisconnect = { (error, closeCode) in
    print("disconnected: \(closeCode)")
}

websocket.connect()
```

You can create custom connection by accessing .settings and .securitySettings properties:

``` swift

websocket.settings.timeout = 5 // sec
websocket.settings.debugMode = true // will trigger .onDebugInfo callback and send .debug(String) event
websocket.settings.useCompression = true // false by default
websocket.settings.maskOutputData = true // true by default
websocket.settings.respondPingRequestsAutomatically = true // true by default 
websocket.settings.callbackQueue = .main

websocket.securitySettings.useSSL = false // true by default
websocket.securitySettings.overrideTrustHostname = true // false by default
websocket.securitySettings.trustHostname = /*your hostname*/
websocket.securitySettings.certificateValidationEnabled = true
websocket.securitySettings.cipherSuites = []

```
