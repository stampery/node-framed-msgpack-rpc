
{Packetizer} = require './packetizer'
dbg = require './debug'

##=======================================================================

exports.Reponse = class Reponse
  constructor : (@dispatch, @seqid) ->
    @debug = null
    
  result : (res) ->
    if @debug
      @debug.response null, res
      @debug.call()
    @dispatch.respond @seqid, null, res

  error : (err) ->
    if @debug
      @debug.response err, null
      @debug.call()
    @dispatch.respond @seqid, err, null

##=======================================================================

exports.Dispatch = class Dispatch extends Packetizer

  REQUEST  : 0
  RESPONSE : 1
  NOTIFY   : 2

  ##-----------------------------------------

  constructor : () ->
    @_invocations = {}
    @_handlers = {}
    @_seqid = 1
    @_debug_hook = null
    super

  ##-----------------------------------------

  _dispatch : (msg) ->

    # We can escape from this, but it's not great...
    if not msg instanceof Array or msg.length < 2
      @_warn "Bad input packet in dispatch"
    else
      switch (type = msg.shift())
        when @REQUEST
          [seqid,method,param] = msg
          response = new Reponse @, seqid
          @_serve { method, param, response }
        when @NOTIFY
          [method,param] = msg
          @_serve { method, param }
        when @RESPONSE
          [seqid,error,result] = msg
          @_dispatch_handle_response { seqid, error, result }
        else
          @_warn "Unknown message type: #{type}"

  ##-----------------------------------------

  _dispatch_handle_response : ({seqid, error, result}) ->
    @_call_cb { seqid, error, result }
    
  ##-----------------------------------------
  
  _call_cb : ({seqid, error, result}) ->
    cb = @_invocations[seqid]
    if cb
      delete @_invocations[seqid]
      cb error, result
   
  ##-----------------------------------------

  cancel : (seqid) -> @_call_cb { seqid, error : "cancelled", result : null } 
 
  ##-----------------------------------------

  _next_seqid : () ->
    ret = @_seqid
    @_seqid++
    return ret

  ##-----------------------------------------
  
  make_method : (prog, meth) ->
    if prog then [ prog, meth ].join "." else meth
 
  ##-----------------------------------------

  respond : (seqid, error, result) ->
    msg = [ @RESPONSE, seqid, error, result ]
    @send msg
   
  ##-----------------------------------------

  invoke : ({program, method, args, notify}, cb, out) ->

    method = @make_method program, method
    
    seqid = @_next_seqid()
    
    if notify
      type = @NOTIFY
      dtype = dbg.constants.type.CLIENT_NOTIFY
    else
      type = @REQUEST
      dtype = dbg.constants.type.CLIENT_CALL
      
    msg = [ type, seqid, method, args ]

    if @_debug_hook
      type = if notify then 
      debug_msg = new debug.Message {
        method, seqid, arg,
        dir : dbg.constants.dir.OUTGOING,
        remote : @remote()
        type : dtype
      }
      @_debug_hook debug_msg.msg()
        
    
    # Down to the packetizer, which will jump back up to the Transport!
    @send msg

    if cb? or not notify

      if out?
        out.cancel = () => @cancel seqid
        
      await (@_invocations[seqid] = defer(error,result) )

      if @_debug_hook
        debug_msg.response error, result
        @_debug_hook debug_msg.msg()
        
    cb error, result if cb

  ##-----------------------------------------

  _dispatch_force_eof : () ->
    @_warn "DFEOF"
    inv = @_invocations
    @_invocations = {}
    for key,cb of inv
      @_warn "-> DFEOF #{key}"
      cb "EOF from server", {}
   
  ##-----------------------------------------

  _serve : ({method, param, response}) ->

    pair = @get_handler_pair method

    if @_debug_hook
      debug_msg = new debug.Message {
        method
        arg : param
        dir : dbg.constants.dir.INCOMING
        remote : @remote()
        type : dbg.constants.type.SERVER
        error : if pair then null else "unknown method"
      }, @_debug_hook

      response.debug = debug_msg if response
      debug_msg.call()

    if pair then pair[1].call pair[0], param, response
    else if response? then response.error "unknown method: #{method}"
      
  ##-----------------------------------------

  # please override me!
  get_handler_this : (m) -> @

  # please override me!
  get_handler_pair : (m) ->
    h = @_handlers[m]
    if h then [ @get_handler_this(m), h ]
    else null

  add_handler : (method, hook, program = null) ->
    method = @make_method program, method
    @_handlers[method] = hook

  add_program : (program, hooks) ->
    for method,hook of hooks
      @add_handler method, hook, program

  add_programs : (programs) ->
    for program, hooks of programs
      @add_program program, hooks

  #
  ##-----------------------------------------
