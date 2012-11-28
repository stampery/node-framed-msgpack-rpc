# Framed Msgpack RPC

`framed-msgpack-rpc` (FMPRPC) is an RPC system for node.js.  It allows
clients to call remote procedures on servers.  An RPC consists of: (1)
a simple string name; (2) an argument that is a single JSON object;
(3) a reply that is also a single JSON object.  Of course, those
objects can be arrays, or dictionaries, so arguments and return values
can be complex and interesting.

FMPRPC is a variant of the
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

## Example

The simplest way to write a server is with the `Server`
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
        console.log("error connecting");
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
if err
    console.log "error connecting"
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
abstraction called an FMPRPC *Transport*.  This class represents a
stream of FMPRPC packets.  Clients and servers are built on top of
these streams, but not in one-to-one correspondence.  That is, several
clients and several servers can share the same Transport object. Thus,
FMPRPC supports multiplexing of many logically separated
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

```javascript
var x = new transport.Transport(opts);
```
Make a new TCP transport, where `opts` are:

* `port` - the port to connect to
* `host` - the host to connect to, or `localhost` if none was given
* `tcp_opts` - TCP options to pass to node's `net.connect` method, which 
 is `{}` by default
* `log_obj` - An object to use to log info, warnings, and errors on this 
 transport.  By default, the default logging to `console.log` will be used.
 See *Logging* below.
* `do_tcp_delay` - By default, the `Transport` will `setNoDelay` on
 TCP streams, but if you specify this flag as true, that behavior will
 be suppressed.
* `hooks` - Hooks to be called on connection error and EOF. Especially
 useful for `RobustTransport`s (see below).  The known hooks are
    * `hooks.connected` - Called when a transport is connected
    * `hooks.eof` - Called when a transport hits EOF.
* `debug_hook` - A debugging hook.  If set, it will turn on RPC tracing
 via the given debugging hook (a function). See _Debugging_ below.

The following two options are used internally by `Server` and `Listener`
classes, and should not be accessed directly:
* `tcp_stream` - Wrap an existing TCP stream 
* `parent` - A parent listener object

#### transport.RobustTransport

```javascript
var x = new transport.RobustTransport(opts, ropts);
```

A subclass of the above; with some more features:

* If disconnected, will attempt to reconnect until successful.
* Will queue calls issued in between a disconnect and a reconnect.
* Will warn of RPCs that are outstanding for more than the given
 threshholds.

The `opts` dictionary is as in `Transport`, but there are additional
options that can be specified via `ropts`:

* `reconnect_delay` - a float - the number of seconds to wait between
 connection attempts.
* `queue_max` - the maximum number of RPCs to queue while reconnecting
* `warn_threshhold` - RPCs that take more than this number of seconds
 are warned about via the logging object.
* `error_threshhold` - RPCs that take more than this number of seconds
 are errored about via the logging object. Also, a timer will be set
 up to warn after this many seconds if the RPC isn't completed in time,
 while the RPC is still outstanding.

#### transport.Transport.connect

```javascript
x.connect(function (err) { if (!err) { console.log("connected!") } });
```

Connect a transport if it's not already connected. Takes a single callback,
which takes one parameter --- an error that's null in the case of a 
success, and non-null otherwise. In the case of a `RobustTransport`, the
callback will be fired after the initial connection attempt, but will continue
to reconnect in the background. Additional error and warnings are issued
via the logger object, and an `info` is issued when a connection succeeds.
Also, if a `hooks.connected` was passed, it will be called on a successful
connection, both the first time, and after any subsequent reconnect.

#### transport.Transport.remote_address

```javascript
var ip = x.remote_address();
```

Get the IP address of the remote side of the connection.  Note that this
can change for a RobustTransport, if the DNS resolution for the given
hostname was updated and the connection was reestablished.  Will
return a string in dotted-quad notation.

#### transport.Transport.get_generation

```javascript
var g = x.get_generation()
```

Get the generation number of this stream connection.  In the case of a
regular Transport, it's always going to be 1.  In the case of a
`RobustTransport`, this number is incremented every time the
connection is reestablished.

#### transport.Transport.set_logger

```javascript
x.set_logger(new logger.Logger({prefix : ">", level : logger.WARN}));
```

Set the logger object on this Transport to be the passed logger. 
You can pass a subclass of the given `Logger` class if you need
custom behavior to fit in with your logging system.

#### transport.Transport.is_connected

```javascript
var b = x.is_connected();
```

Returns a bool, which is `true` if the transport is currently connected,
and `false` otherwise.

#### transport.Transport.close

```javascript
x.close()
```

Call to actively close the given connection.  It will trigger all of the
regular hooks and warnings that an implicit close would.  In the case
of a `RobustTransport`, the transport will not attempt a reconnection.

#### transport.Transport.get_logger

```javascript
var l = x.get_logger()
```

If you want to grab to the logger on the given transport, use this
method.  For instance, you can change the verbosity level with
`x.get_logger().set_level(2)` if you are using the standard logging
object.

#### transport.Transport.set_debug_hook

```javascript
x.set_debug_hook(function(m) {})
```

Report that an RPC call was made or answered, either on the server or 
client. See *Debugging* below for more details.

#### transport.createTransport or rpc.createTransport

```javascript
var x = rpc.createTransport(opts)
```

Create either a new `Transport` or `RobustTransport` with just one call.
The `opts` array is as above, but with a few differences.  First, the
`opts` here is the merge of the `opts` and `ropts` above for the case
of `RobustTransports`s; and second, an option of `robust : true` will
enable the robust variety of the transport.

Note that by default, I like function to use underscores rather than
camel case, but there's a lot of functions like `createConnection` 
in the standard library, so this particular function is in camel
case.  Sorry for the inconsistency.

### Clients

`Clients` are thin wrappers around `Transports`, allowing RPC client
calls.  Several clients can share the same Transport.  Import the
client libraries as a submodule:

```javascript
var client = require('framed-msgpack-rpc').client;
```

The API is as follows:

#### client.Client

Make a new RPC client:

```
var c = new client.Client(x, prog);
```

Where `x` is a `transport.Transport` and `prog` is the name of an RPC
program.  Examples for `prog` are of the form `myprog.1`, meaning the
program is called `myprog` and the version is 1.

Given a client, you can now make RPC calls over the specified connection:

#### client.Client.invoke

Use a Client to invoke an RPC as follows:

```javscript
c.invoke(proc, arg, function(err, res) {});
```

The parameters are:

* proc - The name of the RPC procedure.  It is joined with the
 RPC `program.version` specified when the client was allocated, yielding
 a dotted triple that's sent over the wire.
* arg - A JSON object that's the argument to the RPC.
* cb - A callback that's fired once there is a reply to the RPC. `err`
is `null` in the success case, and non-null otherwise.  The `res` object is
optionally returned in a success case, giving the reply to the RPC.  If
the server supplied a `null` result, then `res` can still be `null` in
the case of success.

#### client.Client.notify

As above, but don't wait for a reply:

```javscript
c.notify(proc, arg);
```

Here, there is no callback, and no way to check if the sever received
the message (or got an error).

### Servers

To write a server, the programmer must specify a series of *hooks*
that handle individual RPCs.  There are a few ways to achieve these
ends with this library.  The big difference is what is the `this`
object for the hook.  In the case of the `server.Server` and
`server.SimpleServer` classes, the `this` object is the server itself.
In the `server.ContextualServer` class, the `this` object is a
per-connection context object.  The first two are good for most cases.

You can get the server library through the submodule server:

```javascript
var server = require('framed-msgpack-rpc').server;
```

But most of the classes are also rexported from the top-level module.

#### server.Server

Create a new server object; specify a port to bind to, a host IP
address to bind to, and also a set of RPC handlers.

```javascript
var s = new server.Server(opts);
```

For `opts`, the fields are:

* `port` - A port to bind to
* `host` - A host IP to bind to
* `TransportClass` - A transport class to use when allocating a new
 Transport for an incoming connection.  By default, it's `transport.Transport`
* `log_obj` - A log object to log errors, and also to assign to 
  (via `make_child`) to child connections. Use the default log class
  (which logs to `console.log`) if unspecified.
* `programs` - Programs to support, following this JSON schema:

```javascript
{
    prog_1 : {
        proc_1 : function (arg, res, x) { /* ... */ },
        proc_2 : function (arg, res, x) { /* ... */ },
        /* etc ... */
    },
    prog_2 : {
        proc_1 : function (arg, res, x) { /* ... */ }
    }
}
```

Each hook in the object is called once per RPC.  The `arg` argument is
the argument specified by the remote client.  The `res` argument is
what the hook should call to send its reply to the client (by calling
`res.result(some_object)`).  A server can also reject the RPC via
`res.error(some_error_string)`).  The final argument, `x`, is the
transport over which the RPC came in to the server.  For instance, the
server can call `x.remote_address()` to figure out who the remote
client is.

#### server.SimpleServer

A `SimpleServer` behaves like a `Server` but is simplified in some
ways.  First off, it only handles one program, which is typically
set on object construction.  Second off, it depends on inheritance;
I've used CoffeeScript here, but you can use hand-rolled JavaScript
style inheritance too. Finally, it infers your method hooks: on
construction, it iterators over all methods in the current object,
and infers that a hook of the form `h_foo` handles the RPC `foo`.

Here's an example:

```coffeescript
class MyServer extends server.SimpleServer

  constructor : (d) ->
    super d 
    @set_program_name "myprog.1"

  h_reflect : (arg, res, x) -> res.result arg
  h_null    : (arg, res, x) -> res.result null
  h_add     : (arg, res, x) -> res.result { sum : arg.x + arg.y }
```

Most methods below are good for both `SimpleServer` and `Server`.
The former has a few extra; see the code in [server.iced](https://github.com/maxtaco/node-framed-msgpack-rpc/blob/master/src/server.iced).

#### server.ContextualServer

Here's an example:

```coffeescript
class Prog1 extends server.Handler
  h_foo : (arg, res) -> 
    console.log "RPC to foo() from #{@transport.remote_address()}"
    res.result { y : arg.i + 2 }
  h_bar : (arg, res) -> res.result { y : arg.j * arg.k }

s = new server.ContextualServer 
  port : 8881
  classes :
    "prog.1" : Prog1
        
await s.listen defer err
console.log "Error: #{err}" if err?
```

Construct a `server.ContextualServer` with a `classes` object that
maps program names to classes.  When a new connection is established, one
object is made for each program in that dictionary, and then that new
object becomes the `this` object for RPCs on that program on
that connection.  It's not quite so crazy when you see it in action;
see the code in
[server.iced](https://github.com/maxtaco/node-framed-msgpack-rpc/blob/master/src/server.iced).

#### server.Server.listen

Bind to a port, and listen for incoming connections

```javascript
s.listen(function(err) {});
```

On success, the callback is fired with `null`, and otherwise,
an error object is passed.

#### server.Server.listen_retry

As above, but keep retrying if binding failed:

```javascript
s.listen_retry(delay, function(err) {});
```

The retry happens every `delay` seconds.  The given function is called
back with `null` once the reconnection happens, or with the actual
error if it was other than `err.code = 'EADDRINUSE'`.

#### server.Server.close

Close a server, and give back its port to the OS.

#### server.Server.set_port

Before calling `listen`, you can use this method to set the port
that the `Server` is going to bind to.

#### server.Server.walk_children

Walk the list of children, calling the specified function on each
child connection in the list:

```javascript
s.walk_children (function(ch) {});
```

### Logging Hooks

To come. See [log.iced](https://github.com/maxtaco/node-framed-msgpack-rpc/blob/master/src/log.iced) for details.

### Debug Hooks

To come. See [debug.iced](https://github.com/maxtaco/node-framed-msgpack-rpc/blob/master/src/debug.iced) for details.


## Internals

### Packetizer

To come. See [packetizer.iced](https://github.com/maxtaco/node-framed-msgpack-rpc/blob/master/src/packetizer.iced) for details.

### Dispatch

To come. See [dispatch.iced](https://github.com/maxtaco/node-framed-msgpack-rpc/blob/master/src/dispatch.iced) for details.

