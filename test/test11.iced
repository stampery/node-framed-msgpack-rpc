
{server,transport,client} = require "../"

PORT = 19983

s = null

# A test in which client and server swap roles!

exports.server = (T,cb) ->

  s = new server.Server
    port : PORT
    programs :
      "P.1" :
        foo : (arg, res) ->
          await setTimeout defer(), 10
          c = new client.Client @, "Q.1"
          await c.invoke "cb", { i : arg.i, j : 15 }, defer err, res2
          if err?
            res.error err
          else
            res.result { y : res2.y*40 }

  await s.listen defer err
  cb err

exports.client = (T,cb) ->
  x = new transport.Transport { port : PORT, host : "-" }

  await x.connect defer err
  if err?
    console.log "Failed to connect in Transport..."
  else
    c = new client.Client x, "P.1"
    c.transport.add_programs {
      "Q.1" :
        cb : (arg, res) ->
          await setTimeout defer(), 10
          res.result { y : arg.i - arg.j }
    }
    await T.test_rpc c, "foo", { i : 20 }, { y : 200 }, defer()
    x.close()
    x = c = null
  cb err

exports.destroy = (cb) ->
  await s.close defer()
  s = null
  cb()
