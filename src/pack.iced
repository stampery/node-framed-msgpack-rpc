try
  mp = require 'msgpack'
catch e

if not mp?
  try
    mp = require 'msgpack4'
  catch e

if not mp?
  try
    pp = require 'purepack'
  catch e

if not mp? and not pp?
  throw new Error "Need either msgpack, msgpack4 or purepack to run"

##==============================================================================

_opts = {}

exports.set_opts = set_opts = (o) -> _pack_opts = o

# If we want to use byte arrays, we need purepack and not msgpack4 or msgpack!
exports.use_byte_arrays = () ->
  if not pp?
    pp = require 'purepack'
  mp = null
  set_opts { byte_arrays : true } 

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
