{srv,transport,cli} = require '../src/main'

PORT = 8881

exports.init = (cb) ->
  
  s = new srv.Server
    port : PORT
    programs :
      "P.1" :
        foo : (arg, res) -> res.result { y : arg.i + 2 }
        bar : (arg, res) -> res.result { y : arg.j * arg.k }
        
  await s.listen defer err
  if not err
    console.log "Listening on port #{PORT}..."
  cb err
  # Keep this guy in scope for a while...
  await setTimeout defer(), 10000


exports.test1 = (T, cb) -> test_A T, cb
exports.test2 = (T, cb) -> test_A T, cb

test_A = (T, cb) -> 
  x = new transport.TcpTransport { port : PORT, host : "-" }
  await x.connect defer ok
  if not ok
    console.log "Failed to connect in TcpTransport..."
  else
    ok = false
    c = new cli.Client x, "P.1"

    await T.test_rpc c, "foo", { i : 4 } , { y : 6 }, defer()
    await T.test_rpc c, "bar", { j : 2, k : 7 }, { y : 14}, defer()
    x = null
    c = null
    await setTimeout defer(), 10
  cb ok
