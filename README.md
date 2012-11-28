# Framed Msgpack RPC

`framed-msgpack-rpc` (FMPRPC) is an RPC system for node.js.  It allows
clients to call remote procedures on servers.  An RPC consists of: (1)
a simple string name; (2) an argument that is a single JSON object;
(3) a reply that is also a single JSON object.  Of course, those
objects can be arrays, or dictionaries, so arguments and return values
can be complex and interesting.

FMRPC is a variant of the
[Msgpack-RPC](http://redmine.msgpack.org/projects/msgpack/wiki/RPCDesign)
protocol specification for node.js.  Msgpack-RPC communicates
binary JSON objects that are efficiently encoded and decoded with the
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

## Simple Use

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
    } else {
        console.log("Listening!");
    }
});
```

a corresponding client might look like:

```javascript
var x = rpc.createTransport({ host: '127.0.0.1', port : 8000 });
x.connect(function (err) {
    if (err) {
        console.log("error connecting: " + err);
    } else {
        var c = new rpc.Client(x, "myprog.1");
        c.invoke('add', { a : 5, b : 4}, function(err, response) {
            if (err) {
                console.log("error in RPC: " + err);
            } else { 
                assert.equal(9, response);
            }
            x.close();
        });
    }
});
```

Or, equivalently, in beautiful 
[IcedCoffeeScript](https://github.com/maxtaco/coffee-script):

```coffee
x = rpc.createTransport { host: '127.0.0.1', port : 8000 }
await x.connect defer err
if err?
    console.log "error connecting: #{err}"
else
    c = new rpc.Client x, "myprog.1"
    await c.invoke 'add', { a : 5, b : 4}, defer err, response
    if err? then console.log "error in RPC: #{err}"
    else assert.equal 9, response
    x.close()
```

## Installation

It should work to just install with npm:
   
    npm install -g framed-msgpack-rpc

If you install by hand, you will need to install the one dependency,
which is the [Msgpack C bindings](http://github.com/JulesAU/node-msgpack),
available as `msgpack2` on npm:

    npm install -g msgpack2


## Full API Documentation

If you are building real applications, it's good to look deeper than
the simple API introduced above. The full library is based on an
abstraction called an FMRPC *Transport*.  This class represents a
stream of FMRPC packets.  Clients and servers are built on top of
these streams, but not in one-to-one correspondence.  That is, several
clients and several servers can share the same Transport object. Thus,
FMRPC supports multiplexing of many logically separated
application-level streams over the same underlying TCP stream.

### Transports

The transport mechanics are available via the submodule `transport`:

```javascript

var transport = require('fast-msgpack-rpc').transport;
```

Transports are auto-allocated in the case of servers (as part of the listen
and connect process), but for clients, you'll find yourself allocating and
connecting them explicitly.

All transports are *stream transports* and for now are built atop TCP
streams.  Eventually we'll roll out support for Unix domain sockets, but there
is no plan for UDP support right now.

#### transport.Transport



### Clients

### Servers

### Logging Hooks

### Debug Hooks

## Internals

### Packetizer

### Dispatch
