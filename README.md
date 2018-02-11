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

Conforms to all necessary Autobahn fuzzing tests. [Autobahn](http://autobahn.ws/testsuite/>)

Test results for DNWebSocket you can see [here](https://glebradchenko.github.io/dnwebsocket.github.io/).

In comparison with [SocketRocket](http://facebook.github.io/SocketRocket/results/), this library shows 2-10 times better performance in many Limits/Performance tests.

Cases 6.4.1, 6.4.2, 6.4.3, 6.4.4 received result Non-Strict due to perfomance improvements(it's complicated to validate each fragmented text message)
