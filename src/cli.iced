

##========================================================================
 
exports.Client = class Client

  #-----------------------------------------

  constructor : (@transport, @program = null) ->
    @debug_hook = null

  #-----------------------------------------

  invoke : (method, args, cb) ->
    arg = { @program, method, args, @debug_hook}
    await @transport.invoke arg, defer err, res
    cb err, res

  #-----------------------------------------

  notify : (method, args) ->
    method = @make_method method
    debug_hook = @_debug_hook
    program = @_program
    @transport.notify { @program, method, args, @debug_hook}
      
##========================================================================
