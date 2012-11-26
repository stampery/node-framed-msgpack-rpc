maxtaco/node-fast-msgpack-rpc
========================

node-framed-msgpack-rpc is an implementation of the
[Msgpack-RPC](http://redmine.msgpack.org/projects/msgpack/wiki/RPCDesign)
protocol specification for node.js.  Msgpack-RPC is built ontop of the
very fast [MessagePack](http://msgpack.org) serialization format. This
implementation supports tcp and unix socket transports.

This is a "framed" version of Msgpack-RPC.  The big difference here is
that the length of the packet is prepended to each packet, meaning we
don't need to keep iteratively decoding the packet over and over
again.  Seems weird they left this out.  This protocol is not
compatible with the existing Msgpack.


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
