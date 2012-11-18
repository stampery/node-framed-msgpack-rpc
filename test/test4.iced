{server,Transport,Client} = require '../src/main'

## Do the same test as test1, a second time, must to make
## sure that we can rebind a second time...

PORT = 8881
s = null

crypto = require 'crypto'

class P_v1 extends server.Handler
  h_reflect : (arg, res) -> res.result arg

exports.init = (cb) ->
  
  s = new server.ContextualServer 
    port : PORT
    classes :
      "P.1" : P_v1
        
  await s.listen defer err
  cb err

exports.volley_of_strings = (T, cb) ->

  await T.connect PORT, "P.1", defer x, c
  
  if x
    
    args = []
    res = []
    err = []
    
    n = 100
    sz = 10000
    
    for i in [0..n]
      await crypto.randomBytes sz, defer ex, buf
      args[i] = { r : buf.toString 'base64' }
      
    await
      for a,i in args
        c.invoke "reflect", a, defer err[i], res[i]

    for a,i in args
      T.check_rpc "reflect #{i}", err[i], res[i], args[i]

    x.close()

  cb()


exports.destroy = (cb) ->
  await s.close defer()
  s = null
  cb()
