try
  mp = require 'msgpack'
catch e
if not mp
  try
    pp = require 'purepack'
  catch e
if not mp? and not pp?
  try
    mp = require 'msgpack2'
  catch e

if not mp? and not pp?
  throw new Error "Need either msgpack2 or purepack to run"

##==============================================================================

_opts = {}

exports.set_opts = (o) -> _pack_opts = o

exports.pack = (b) ->
  ret = if mp then mp.pack b
  else if pp then pp.pack b, 'buffer', _opts
  ret

exports.unpack = (b) ->
  pw = null
  if mp      then dat = mp.unpack b
  else if pp then [pw,dat] = pp.unpack b
  pw = pw.join("; ") if pw
  [pw, dat]

##==============================================================================
