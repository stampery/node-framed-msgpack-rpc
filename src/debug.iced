
##=======================================================================

# Flags for what fields are in our debug messages
F =
  NONE : 0
  METHOD : 0x1
  REMOTE : 0x2
  SEQID : 0x4
  TIMESTAMP : 0x8
  ERROR : 0x10
  ARG : 0x20
  RES : 0x40
  CLASS : 0x80
  DIR : 0x100
  VERBOSE : 0x200
  ALL : 0xfffffff

F.LEVEL_0 = F.NONE;
F.LEVEL_1 = F.METHOD | F.CLASS | F.DIR;
F.LEVEL_2 = F.LEVEL_1 | F.SEQID | F.TIMESTAMP | F.REMOTE;
F.LEVEL_3 = F.LEVEL_2 | F.ERROR;
F.LEVEL_4 = F.LEVEL_3 | F.RES | F.ARGS;

##=======================================================================

# String versions of these flags
sflags =
  m : F.METHOD
  a : F.REMOTE
  s : F.SEQID
  t : F.TIMESTAMP
  e : F.ERROR
  p : F.ARG
  r : F.REPLY
  c : F.CLASS
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
F2S[F.CLASS] = {};
F2S[F.CLASS][type.SERVER] = "server";
F2S[F.CLASS][type.CLIENT_NOTIFY] = "cli.notify";
F2S[F.CLASS][type.CLIENT_CALL] = "cli.call";

##=======================================================================

# Finally, export all of these constants...
exports.constants =
  type : type
  dir : dir
  flags : F
  sflags : sflags
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
    res |= sflags[c]
  return res

##=======================================================================

#
# Make a simple hook that takes an incoming message, turns on/off some
# fields based on the passed flags, puts in a timestamp, and then
# calls the given hook.
#
exports.make_hook = (flgs, fn) ->
  sflags = flgs
  sflags = sflags_to_flags flgs if typeof flgs is 'string'

  return (msg) ->
    new_msg = {}
    
    if (sflags & F.TIMESTAMP)
      new_msg.timestamp = (new Date()).getTime() / 1000.0
      
    for key,val of msg
      uck = key.toUpperCase()
      flag = F[uck]

      # Usually don't copy the arg or res if it's in the other direction,
      # but this can overpower that
      V = sflags & F.VERBOSE
      
      do_copy = if (sflags & flag) is 0 then false
      else if key is "res" then (msg.dir is dir.OUTGOING or V)
      else if key is "arg" then (msg.dir is dir.INCOMING or V)
      else true

      if do_copy
        f2s = F2S[flag]
        val = f2s val if (f2s = F2S[flag])?
        new_msg[key] = val
        
    fn new_msg

##=======================================================================

exports.Message = class Message

  constructor : (@msg, @hook = null) ->

  response : (error, result) ->
    @msg.error = error
    @msg.result = result
    @msg.dir = if dir.OUTGOING then dir.INCOMING else dir.OUTGOING

  msg : -> @msg

  call : -> @hook @msg()

  set : (k,v) -> @msg[k] = v
