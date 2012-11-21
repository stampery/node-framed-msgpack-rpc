{server,Transport,Client} = require '../src/main'

## Do the same test as test1, a second time, must to make
## sure that we can rebind a second time...

PORT = 8881
s = null

crypto = require 'crypto'
rj = require 'random-json'

##=======================================================================

class P_v1 extends server.Handler
  h_reflect : (arg, res) ->
    res.result arg
    # Now, generate some random junk in the buffer, and then send it down
    # the pipe!
    @transport._raw_write new Buffer [3...10]

##=======================================================================

exports.init = (cb) ->
  
  s = new server.ContextualServer 
    port : PORT
    classes :
      "P.1" : P_v1
        
  await s.listen defer err
  cb err

##=======================================================================

exports.reconnect_after_error = (T, cb) ->

  rtops = {}

  await T.connect PORT, "P.1", defer(x, c), rtops
  
  if x
    x.set_logger T.logger()

    arg =
      x : "simple stuff here"
      v : [0..100]
      
    n = 4
    for i in [0...n]
      await T.test_rpc c, "reflect", arg, arg, defer()
      await setTimeout defer(), 100

    x.close()

  cb()

##=======================================================================

exports.destroy = (cb) ->
  await s.close defer()
  s = null
  cb()
