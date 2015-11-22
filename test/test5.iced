{RobustTransport,Client} = require '../src/main'
{fork} = require 'child_process'
fs = require 'fs'
path = require 'path'

## Do the same test as test1, a second time, must to make
## sure that we can rebind a second time...

PORT = 8881
PATH = "/tmp/rpc.test5.sock"
n = null
restart = true

jenky_server_loop =  (args, cb) ->
  while restart
    n = fork path.join(__dirname,"support","jenky_server.js"), args, {}
    await n.on 'message', defer msg
    if cb?
      t = cb
      cb = null
      t()
    await n.on 'exit', defer()

exports.init = (cb) ->
  await jenky_server_loop [], defer()
  cb null

exports.reconnect = (T, cb) ->

  await T.connect PORT, "P.1", defer(x,c), {}
  if x
    tries = 4
    for i in [0...tries]
      restart = (i isnt tries-1)
      await T.test_rpc c, "foo", { i : 4 } , { y : 6 }, defer()
      await setTimeout defer(), 10
    x.close()
  cb()

exports.fork_unix_domain_socket = (T, cb) ->
  restart = true
  await jenky_server_loop ["-u", PATH ], defer()
  cb null

exports.reconnect_unix = (T, cb) ->

  await T.connect PATH , "P.1", defer(x,c), {}
  if x
    tries = 4
    for i in [0...tries]
      restart = (i isnt tries-1)
      await T.test_rpc c, "foo", { i : 4 } , { y : 6 }, defer()
      await setTimeout defer(), 10

    x.close()
    await fs.unlink PATH, defer()

  cb()
