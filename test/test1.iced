{srv,transport,cli} = require '../src/main'

PORT = 8881

exports.init = (cb) ->
  
  s = new srv.Server
    port : PORT
    programs :
      "P.1" :
        foo : (arg, res) -> res.reply { y : arg.i + 2 }
        bar : (arg, res) -> res.reply { y : arg.j * arg.k }
        
  await s.listen defer err
  cb err

exports.test1 = (cb) ->
  x = new transport.TcpTransport { port : PORT, host : "-" }
  await x.connect defer ok
  if not ok
    console.log "Failed to connect in TcpTransport..."
  else
    ok = false
    c = new cli.Client x, "P.1"
    await cli.invoke "foo", { i : 4 }, defer err, res
    if err
      console.log "Error in call: #{err}"
    else if res.y isnt 6
      console.log "Res was wrong: #{JSON.stringify res}"
    else
      ok = true
  cb ok
