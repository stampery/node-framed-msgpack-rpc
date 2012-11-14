maxtaco/node-msgpack-rpc
========================

node-msgpack-rpc is an implementation of the
[Msgpack-RPC](http://redmine.msgpack.org/projects/msgpack/wiki/RPCDesign)
protocol specification for node.js.  Msgpack-RPC is built ontop of the
very fast [MessagePack](http://msgpack.org) serialization format. This
implementation supports tcp and unix socket transports.

This is a "fast" version of Msgpack-RPC.  The big difference here is
that the length of the packet is prepended to each packet, meaning we
don't need to keep iteratively decoding the packet over and over
again.  Seems weird they left this out.  This protocol is not
compatible with the existing Msgpack, but this module has the same
API.


Simple Usage
------------

If you don't care too much about keeping custom per-connection state, it's
easy to make a simple RPC server:

```javascript
var rpc = require('fast-msgpack-rpc');
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

Or, in beautiful [IcedCoffeeScript](https://github.com/maxtaco/coffee-script):

```coffee
await (c = rpc.createClient '127.0.0.1', 8000, defer(), "myprog.v1")
await c.invoke 'add', { a : 5, b : 4}, defer err, response
c.close()
```

Installation
------------

First you will need to install the [msgpack2](http://github.com/JulesAU/node-msgpack) add-on

To install node-msgpack-rpc with npm:

    npm install -g msgpack2


RPC Stream API
--------------

Clients and the streams passed to servers for incoming connections are both instances of MsgpackRPCStream.

Methods

    c.createClient(port, [hostname], [ready_cb]);
    c.invoke(method, [param1, param2, ...], cb);
    c.notify(method, [param1, param2, ...]);
    c.setTimeout(milliseconds);  // Setting this will cause requests to fail with err "timeout" if they don't recieve a response for the specified period
    c.close(); // Close the socket for this client
    c.stream // underlying net.Stream object

Events

    'ready' // emitted when we've connected to the server
    'request' // recieved request
    'notify' // recieved notification

