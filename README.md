maxtaco/node-framed-msgpack-rpc
========================

`framed-msgpack-rpc` is a variation of the
[Msgpack-RPC](http://redmine.msgpack.org/projects/msgpack/wiki/RPCDesign)
protocol specification for node.js.  Msgpack-RPC communicates
JSON-like objects, that are efficiently encodede and decoded with the
[MessagePack](http://msgpack.org) serialization format. This
implementation supports TCP transports only at the current time.

"Framed" Msgpack-RPC differs from standard Msgpack-RPC in a small way:
the encoding of the length of the packet is prepended to each
packet. This way, receivers can efficiently buffer data until a full
packet is available to decode. In an event-based context like node.js,
framing simplifies implementation, and yields a faster decoder,
espeically for very large messages.

Due to framing, this protocol is not compatible with existing
Msgpack-RPC systems.


Simple Usage
------------

If you don't care too much about keeping custom per-connection state, it's
easy to make a simple RPC server:

```javascript
var rpc = require('framed-msgpack-rpc');
var srv = rpc.createServer({
   "myprog.v1" : {
      add : function(arg, response) {
         response.result(arg.a + arg.b);
      }
   }
});
srv.listen(8000);
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
