

{Packetizer} = require './packetizer'
debug = require './debug'

##=======================================================================

exports.Reponse = class Reponse
  constructor : (@dispatch, @seqid) ->
    @debug = null
    
  result : (res) ->
    if @debug
      @debug.response null, res
      @debug.call()
    @dispatch.response null, res

  error : (err) ->
    if @debug
      @debug.response err, null
      @debug.call()
    @dispatch.error err, null

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
  
  @make_method : (prog, meth) ->
    if prog then [ prog, meth].join "." else meth
 
  ##-----------------------------------------

  invoke : ({program, method, args, debug_hook}, cb) ->

    method = @make_method program, method
    
    seqid = @_next_seqid()
    msg = [ @REQUEST, seqid, method, arg ]

    if debug_hook
      debug_msg = new debug.Message {
        method, seqid, arg,
        dir : debug.constants.dir.OUTGOING,
        remote : @remote()
        type : debug.constants.type.CLIENT_CALL
      }
      debug_hook debug_msg.msg()
        
    
    # Down to the packetizer, which will jump back up to the Transport!
    @send msg

    await (@_invocations[seqid] = defer(error,result) )

    if debug_hook
      debug_msg.response error, result
      debug_hook debug_msg.msg()
        
    cb error, result

  ##-----------------------------------------

  notify : ({program, method, args, debug_hook}) ->
    
    method = @make_method program, method
    
    msg = [ @NOTIFY, method, arg ]

    if debug_hook
      debug_msg = new debug.Message {
        method, arg,
        dir : debug.constants.dir.OUTGOING,
        remote : @remote()
        type : debug.constants.type.CALL_NOTIFY
      }
      debug_hook debug_msg.msg()
        
    @send msg

  ##-----------------------------------------

  _serve : ({method, param, response}) ->

    pair = @get_handler_pair method

    if debug_hook
      debug_msg = new debug.Message {
        method
        arg : param
        dir : debug.constants.dir.INCOMING
        remote : @remote()
        type : debug.constants.type.SERVER
        error : if pair then null else "unknown method"
      }, debug_hook

      response.debug = debug_msg if response
      debug_msg.call()

    if pair then handler.call self, param, response
    else if response? then response.error new Error "unknown method #{method}"
      
  ##-----------------------------------------
  # 

  # please override me!
  get_handler_pair : (m) ->
    h = @_handlers[m]
    if h then [ this, h ]
    else null

  add_handler : (method, hook, program = null) ->
    method = @make_method program, hook
    @_handlers[method] = hook

  add_program : (program, hooks) ->
    for method,hook of hooks:
      @add_handler method, hook, program

  add_programs : (programs) ->
    for program, hooks of programs
      @add_program program, hook

  #
  ##-----------------------------------------
