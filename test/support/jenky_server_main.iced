{net,log,server,ReconnectTransport,Client} = require '../../src/main'
fs = require 'fs'

exports.main = (argv) ->
  net.set_net_module require 'net'
  args = {}
  if argv.u?
    args.path = argv.u
    await fs.unlink args.path, defer err
  else
    args.port = 8881

  # Since we're being forked, do this.  We shouldn't really
  # be doing this in "-d" mode to all.iced, but it's OK for now.
  log.set_default_level log.levels.WARN

  # this is a jenky server that crashes every time it does anything!
  # useful for testing the reconnecting client...
  class P_v1 extends server.Handler
    h_foo : (arg, res) ->
      res.result { y : arg.i + 2 }
      process.exit 0

  args.classes = { "P.1" : P_v1 }
  s = new server.ContextualServer args
  await s.listen defer err
  process.send { ok : true }

