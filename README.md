maxtaco/node-framed-msgpack-rpc
========================

`framed-msgpack-rpc` (FMPRPC) is an RPC system for node.js.  It allows
clients to call remote prodecures on servers.  The remote procedures
are indentified by a simple string name.  Each RPC takes one argument,
and returns one object.  Of course, those objects can be arrays,
dictionaries, or any JSON object, so arguments and return values can
be complex and interesting.

FMRPC is a variation of the
[Msgpack-RPC](http://redmine.msgpack.org/projects/msgpack/wiki/RPCDesign)
protocol specification for node.js.  Msgpack-RPC communicates
JSON-like objects, that are efficiently encodede and decoded with the
[MessagePack](http://msgpack.org) serialization format. 

"Framed" Msgpack-RPC differs from standard Msgpack-RPC in a small way:
the encoding of the length of the packet is prepended to each
packet. This way, receivers can efficiently buffer data until a full
packet is available to decode. In an event-based context like node.js,
framing simplifies implementation, and yields a faster decoder,
especially for very large messages.

By convention, RPCs are grouped into _programs_, which can have
one or more _versions_.  Each (prog,vers) pair then has a collection
of procedures, meaning an RPC is identified unabmiguously by a 
(prog,vers,proc) triple.  In practice, these three strings are
joined with "." characters, and the dotted triple is the RPC name.

Due to framing, this protocol is not compatible with existing
Msgpack-RPC systems.  This implementation supports TCP transports only
at the current time.

Simple Usage
------------

The most simple way to write a server is with the `SimpleServer`
class as below:

```javascript
var rpc = require('framed-msgpack-rpc');
var srv= new rpc.Server ({
    programs : {
        "myprog.1" : {
            add : function(arg, response) {
                response.result(arg.a + arg.b);
            }
        }
    },
    port : 8000 
});
srv.listen(function (err) {
    if (err) {
        console.log("Error binding: " + err);
    }
});
```

a corresponding client might look like:

```javascript
var c = rpc.createClient('127.0.0.1', 8000, 
    function() {
        c.invoke('add', { a : 5, b : 4}, 
            function(err, response) {
                assert.equal(9, response);
                c.close();
            });
    }, "myprog.v1");
```

Or, equivalently, in beautiful 
[IcedCoffeeScript](https://github.com/maxtaco/coffee-script):

```coffee
await (c = rpc.createClient '127.0.0.1', 8000, defer(ok), "myprog.v1")
await c.invoke 'add', { a : 5, b : 4 }, defer err, response
c.close()
```

Advanced Usage
--------------
(documentation to come)

Installation
------------

First you will need to install the [msgpack2](http://github.com/JulesAU/node-msgpack) add-on

To install node-msgpack-rpc with npm:

    npm install -g msgpack2


Debug and Tracing Hooks
-----------------------

(documentation to come)
