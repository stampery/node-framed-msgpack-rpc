

##========================================================================
 
exports.Client = class Client

  constructor : (@_transport, @_program = null) ->
    @_debug_hook = null

  make_method : (m) ->
    if @_program? then [ @_program, m].join "." else m

  invoke : (method, args, cb) ->
    method = @make_method method
    debug_hook = @_debug_hook
    await @_transport.invoke { method, args, debug_hook}, defer err, res
    cb err, res

  notify : (method, args) ->
    method = @make_method method
    debug_hook = @_debug_hook
    @_transport.notify { method, args, debug_hook}
      
