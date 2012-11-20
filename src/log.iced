
#
# The standard logger for saying that things went wrong, or state changed,
# inside the RPC system.  You can of course change this to be whatever you'd
# like via the @log_obj member of the Transport class.
# 
exports.Logger = class Logger
  constructor : ({@prefix, @remote}) ->
    @prefix = "RPC" unless @prefix
    @remote = "-" unless @remote
    @output_hook = (m) -> console.log m

  set_remote : (r) -> @remote = r
  set_prefix : (p) -> @prefix = p

  info : (m) ->  
  warn : (m) ->  @_log m, "W"
  error : (m) -> @_log m, "E"
  fatal : (m) -> @_log m, "F"
  debug : (m) -> @_log m, "D"

  clone : -> new Logger { @prefix }

  _output : (m) -> console.log m
  
  _log : (m, l, ohook) ->
    parts = [ "RPC" ]
    parts.push "[#{l}]" if l
    parts.push @remote if @remote
    parts.push m
    ohook = @output_hook unless ohook
    ohook parts.join " "
    

