
##=======================================================================

# Flags for what fields are in our debug messages
F =
  NONE : 0
  METHOD : 0x1
  REMOTE : 0x2
  SEQID : 0x4
  TIMESTAMP : 0x8
  ERR : 0x10
  ARG : 0x20
  RES : 0x40
  TYPE : 0x80
  DIR : 0x100
  VERBOSE : 0x200
  ALL : 0xfffffff

F.LEVEL_0 = F.NONE
F.LEVEL_1 = F.METHOD | F.TYPE | F.DIR | F.TYPE
F.LEVEL_2 = F.LEVEL_1 | F.SEQID | F.TIMESTAMP | F.REMOTE
F.LEVEL_3 = F.LEVEL_2 | F.ERR
F.LEVEL_4 = F.LEVEL_3 | F.RES | F.ARGS

##=======================================================================

# String versions of these flags
SF =
  m : F.METHOD
  a : F.REMOTE
  s : F.SEQID
  t : F.TIMESTAMP
  e : F.ERROR
  p : F.ARG
  r : F.RES
  e : F.ERR
  c : F.TYPE
  d : F.DIRECTION
  v : F.VERBOSE
  A : F.ALL
  0 : F.LEVEL_0
  1 : F.LEVEL_1
  2 : F.LEVEL_2
  3 : F.LEVEL_3
  4 : F.LEVEL_4

##=======================================================================

dir =
  INCOMING : 1
  OUTGOING : 2

##=======================================================================

type =
  SERVER : 1
  CLIENT_NOTIFY : 2
  CLIENT_CALL : 3
  
##=======================================================================

F2S = {}
F2S[F.DIR] = {}
F2S[F.DIR][dir.INCOMING] = "in";
F2S[F.DIR][dir.OUTGOING] = "out";
F2S[F.TYPE] = {};
F2S[F.TYPE][type.SERVER] = "server";
F2S[F.TYPE][type.CLIENT_NOTIFY] = "cli.notify";
F2S[F.TYPE][type.CLIENT_INVOKE] = "cli.invoke";

##=======================================================================

# Finally, export all of these constants...
exports.constants =
  type : type
  dir : dir
  flags : F
  sflags : SF
  field_to_string : F2S

##=======================================================================

#
# Convert a string of the form "1r" to the OR of those
# consituent bitfields.
#
exports.sflags_to_flags = sflags_to_flags = (s) ->
  res = 0
  for i in [0...s.length]
    c = s.charAt i
    res |= SF[c]
  return res

##=======================================================================

show_arg = (msg, V) ->
  (V or
     ((msg.type is type.SERVER) and (msg.dir is dir.INCOMING)) or
     ((msg.type isnt type.SERVER) and (msg.dir is dir.OUTGOING)))
        
show_res = (msg, V) ->
  (V or
     ((msg.type is type.SERVER) and (msg.dir is dir.OUTGOING)) or
     ((msg.type isnt type.SERVER) and (msg.dir is dir.INCOMING)))

#
# Make a simple hook that takes an incoming message, turns on/off some
# fields based on the passed flags, puts in a timestamp, and then
# calls the given hook.
#
exports.make_hook = (flgs, fn) ->
  sflags = flgs
  sflags = sflags_to_flags flgs if typeof flgs is 'string'
  
  # Usually don't copy the arg or res if it's in the other direction,
  # but this can overpower that
  V = sflags & F.VERBOSE

  return (msg) ->
    new_msg = {}
    
    if (sflags & F.TIMESTAMP)
      new_msg.timestamp = (new Date()).getTime() / 1000.0
      
    for key,val of msg
      uck = key.toUpperCase()
      flag = F[uck]

      do_copy = if (sflags & flag) is 0 then false
      else if key is "res" then show_res msg, V
      else if key is "arg" then show_arg msg, V
      else true

      if do_copy
        val = f2s[val] if (f2s = F2S[flag])?
        new_msg[key] = val
        
    fn new_msg

##=======================================================================

exports.Message = class Message
  """A debug message --- a wrapper around a dictionary object, with
  a few additional methods."""

  constructor : (@_msg, @hook = null) ->

  response : (error, result) ->
    @_msg.err = error
    @_msg.res = result
    @_msg.dir = if dir.OUTGOING then dir.INCOMING else dir.OUTGOING

  msg : -> @_msg

  call : -> @hook @msg()

  set : (k,v) -> @msg[k] = v

##=======================================================================
