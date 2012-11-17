

##========================================================================
 
exports.Client = class Client

  #-----------------------------------------

  constructor : (@transport, @program = null) ->

  #-----------------------------------------

  invoke : (method, args, cb) ->
    arg = { @program, method, args }
    await @transport.invoke arg, defer err, res
    cb err, res

  #-----------------------------------------

  notify : (method, args) ->
    method = @make_method method
    program = @_program
    @transport.notify { @program, method, args }
      
##========================================================================
