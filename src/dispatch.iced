

{Packetizer} = require './packetizer'
debug = require './debug'

##=======================================================================

exports.Reponse = class Reponse
  constructor : (@dispatch, @seqid) ->
    @_debug_hook = null
    
  result : (res) ->
    @dispatch.response null, res

  error : (err) ->
    @dispatch.error err, null

##=======================================================================

exports.Dispatch = class Dispatch extends Packetizer

  REQUEST  : 0
  RESPONSE : 1
  NOTIFY   : 2

  ##-----------------------------------------

  constructor : () ->
    @_invocations = {}
    @_seqid = 1
    super

  ##-----------------------------------------

  _dispatch : (msg) ->

    # We can escape from this, but it's not great...
    if not msg instanceof Array or msg.length < 2
      @_warn "Bad input packet in dispatch"
      return

    switch (type = msg.shift())
      when @REQUEST
        [seqid,method,param] = msg
        response = new Reponse @, seqid
        @_dispatch_handle_request { method, param, response }
      when @NOTIFY
        [method,param] = msg
        @_dispatch_handle_request { method, param }
      when @RESPONSE
        [seqid,error,result] = msg
        @_dispatch_handle_response { seqid, error, result }
      else
        @_warn "Unknown message type: #{type}"

  ##-----------------------------------------

  _dispatch_handle_response : ({seqid, error, result}) ->
    cb = @_invocations[seqid]
    if cb
      delete @_invocations[seqid]
      cb error, result
    else
      @_warn "Unknown response for seqid=#{seqid}"
   
  ##-----------------------------------------

  _next_seqid : () ->
    ret = @_seqid
    @_seqid++
    return ret
 
  ##-----------------------------------------

  invoke : ({method, args, debug_hook}, cb) ->
    
    seqid = @_next_seqid()
    msg = [ @REQUEST, seqid, method, arg ]

    if debug_hook
      debug_msg = new debug.Message {
        method, seqid, arg,
        dir : debug.constants.dir.OUTGOING,
        remote : @remote()
        type : debug.constants.type.REQUEST
      }
      debug_hook debug_msg
        
    
    # Down to the packetizer, which will jump back up to the Transport!
    @send msg

    await (@_invocations[seqid] = defer(error,result) )

    if debug_hook
      debug_msg.response error, result
      debug_hook debug_msg
        
    cb error, result

  ##-----------------------------------------

  notify : ({method, args, debug_hook}) ->
    msg = [ @NOTIFY, method, arg ]

    if debug_hook
      debug_msg = new debug.Message {
        method, arg,
        dir : debug.constants.dir.OUTGOING,
        remote : @remote()
        type : debug.constants.type.NOTIFY
      }
      debug_hook debug_msg
        
    @send msg
