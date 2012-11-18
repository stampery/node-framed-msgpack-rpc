{server,Transport,Client} = require '../src/main'

## Do the same test as test1, a second time, must to make
## sure that we can rebind a second time...

PORT = 8881
s = null

class P_v1 extends server.Handler
  h_foo : (arg, res) -> res.result { y : arg.i + 2 }
  h_bar : (arg, res) -> res.result { y : arg.j * arg.k }

exports.init = (cb) ->
  
  s = new server.ContextualServer 
    port : PORT
    classes :
      "P.1" : P_v1
        
  await s.listen defer err
  cb err

exports.test1 = (T, cb) -> test_A T, cb
exports.test2 = (T, cb) -> test_A T, cb

test_A = (T, cb) -> 
  x = new Transport { port : PORT, host : "-" }
  await x.connect defer ok
  if not ok
    console.log "Failed to connect in TcpTransport..."
  else
    ok = false
    c = new Client x, "P.1"

    await T.test_rpc c, "foo", { i : 4 } , { y : 6 }, defer()
    await T.test_rpc c, "bar", { j : 2, k : 7 }, { y : 14}, defer()
    x.close()
    x = c = null
  cb ok

exports.destroy = (cb) ->
  await s.close defer()
  s = null
  cb()
