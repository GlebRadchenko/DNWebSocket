# DNWebSocket

<p align="center">
<a href="https://developer.apple.com/swift/" target="_blank">
<img src="https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat" alt="Swift 4.0">
</a>
<a href="https://developer.apple.com/swift/" target="_blank">
<img src="https://img.shields.io/badge/Platforms-%20Linux%20%26%20OS%20X%20-brightgreen.svg?style=flat" alt="iOS, macOS, watchOS, tvOS, Linux">
</a>
<a href="https://github.com/GlebRadchenko/DNWebSocket/blob/master/LICENSE" target="_blank">
<img src="https://img.shields.io/aur/license/yaourt.svg?style=flat" alt="MIT">
</a>
</p>

Object-Oriented, Swift-style WebSocket Library ([RFC 6455](https://tools.ietf.org/html/rfc6455>)) for Swift-compatible Platforms.
Conforms to all necessary Autobahn fuzzing tests. [Autobahn](http://autobahn.ws/testsuite/>)

Test results for DNWebSocket you can see [here](https://glebradchenko.github.io/dnwebsocket.github.io/).

Cases 6.4.1, 6.4.2, 6.4.3, 6.4.4 received result Non-Strict due to perfomance improvements(it's complicated to validate each fragmented text message)
