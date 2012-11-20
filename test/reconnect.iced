{server,ReconnectTransport,Client} = require '../src/main'
{fork} = require 'child_process'

## Do the same test as test1, a second time, must to make
## sure that we can rebind a second time...

PORT = 8881
n = null

jenky_server_loop =  (cb) ->
  loop 
    n = fork __dirname + "/jenky_server.iced"
    await n.on 'message', defer msg
    if cb?
      t = cb
      cb = null
      t()
    await n.on 'exit', defer()

exports.init = (cb) ->
  await jenky_server_loop defer()
  cb null

exports.reconnect = (T, cb) ->
  
  x = new ReconnectTransport { port : PORT, host : "-" }
  await x.connect defer ok
  
  if not ok
    console.log "Failed to connect in TcpTransport..."
  else
    ok = false
    c = new Client x, "P.1"

    for i in [0..4]
      console.log "X #{i}"
      await T.test_rpc c, "foo", { i : 4 } , { y : 6 }, defer()
      await setTimeout defer(), 100

    x.close()
    n.kill 0
    
  cb ok
