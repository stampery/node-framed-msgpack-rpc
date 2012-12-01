net = require 'net'
{Lock} = require './lock'
{Dispatch} = require './dispatch'
log = require './log'
{Timer} = require './timer'
iced = require('./iced').runtime

##=======================================================================

#
# A shared wrapper object for which close is idempotent
# 
class StreamWrapper
  constructor : (@_tcp_stream, @_parent) ->
    @_generation = @_parent.next_generation()
    @_write_closed_warn = false

  # Return true if we did the actual close, and false otherwise
  close : ->
    ret = false
    if (x = @_tcp_stream)?
      ret = true
      @_tcp_stream = null
      @_parent._dispatch_reset()
      @_parent._packetizer_reset()
      x.end()
    return ret

  write : (msg, enc) ->
    if @_tcp_stream
      @_tcp_stream.write msg, enc
    else if not @_write_closed_warn
      @_write_closed_warn = true
      @_parent._warn "write on closed socket..."

  stream         : -> @_tcp_stream
  is_connected   : -> !! @_tcp_stream
  get_generation : -> @_generation

  remote_address : () ->
    if @_tcp_stream then @_tcp_stream.remoteAddress else null

##=======================================================================

exports.Transport = class Transport extends Dispatch

  ##-----------------------------------------
  # Public API
  # 

  constructor : ({ @port, @host, @tcp_opts, tcp_stream, @log_obj,
                   @parent, @do_tcp_delay, @hooks, debug_hook}) ->
    super
    
    @host = "localhost" if not @host or @host is "-"
    @tcp_opts = {} unless @tcp_opts
    @tcp_opts.host = @host
    @tcp_opts.port = @port
    @_explicit_close = false
    
    @_remote_str = [ @host, @port].join ":"
    @set_logger @log_obj 
    
    @_lock = new Lock()
    @_generation = 1
    
    @_debug_hook = debug_hook

    # We don't store the TCP stream directly, but rather, sadly,
    # a **wrapper** around the TCP stream.  This is to make stream
    # closes idempotent. The case we want to avoid is two closes
    # on us (due to errors), but the second closing the reconnected
    # stream, rather than the original stream.  This level of
    # indirection solves this.
    @_tcpw = null

    # potentially set @_tcpw to be non-null
    @_activate_stream tcp_stream if tcp_stream

  ##-----------------------------------------

  set_debug_hook : (h) -> @_debug_hook = h
   
  ##-----------------------------------------

  next_generation : () ->
    """To be called by StreamWrapper objects but not by
    average users."""
    ret = @_generation
    @_generation++
    return ret
 
  ##-----------------------------------------

  get_generation : () -> if @_tcpw then @_tcpw.get_generation() else -1 
 
  ##-----------------------------------------

  remote_address : () -> if @_tcpw? then @_tcpw.remote_address() else null
 
  ##-----------------------------------------

  set_logger : (o) ->
    o = log.new_default_logger() unless o
    @log_obj = o
    @log_obj.set_remote @_remote_str
   
  ##-----------------------------------------

  get_logger : () -> @log_obj
   
  ##-----------------------------------------

  is_connected : () -> @_tcpw?.is_connected()
   
  ##-----------------------------------------

  connect : (cb) ->
    await @_lock.acquire defer()
    if not @is_connected()
      await @_connect_critical_section defer err
    else
      err = null
    @_lock.release()
    cb err if cb
    @_reconnect() if err?

  ##-----------------------------------------

  close : () ->
    @_explicit_close = true
    if @_tcpw
      @_tcpw.close()
      @_tcpw = null

  #
  # /Public API
  ##---------------------------------------------------

  _warn  : (e) -> @log_obj.warn  e
  _info  : (e) -> @log_obj.info  e
  _fatal : (e) -> @log_obj.fatal e
  _debug : (e) -> @log_obj.debug e
  _error : (e) -> @log_obj.error e
  
  ##-----------------------------------------

  _close : (tcpw) ->
    # If an optional close hook was specified, call it here...
    @hooks?.eof?()
    @_reconnect() if tcpw.close()

  ##-----------------------------------------

  _handle_error : (e, tcpw) ->
    @_error e
    @_close tcpw
   
  ##-----------------------------------------
  
  _packetize_error : (err) ->
    # I think we'll always have the right TCP stream here
    # if we grab the one in the this object.  A packetizer
    # error will happen before any errors in the underlying
    # stream
    @_handle_error "In packetizer: #{err}", @_tcpw
    
  ##-----------------------------------------

  _handle_close : (tcpw) ->
    @_info "EOF on transport" unless @_explicit_close
    @_close tcpw
    
    # for TCP connections that are children of Listeners,
    # we close the connection here and disassociate
    @parent.close_child @ if @parent
   
  ##-----------------------------------------

  # In other classes we can override this...
  # See 'RobustTransport'
  _reconnect : () -> null
 
  ##-----------------------------------------
  
  _activate_stream : (x) ->

    @_info "connection established"

    # If optional hooks were specified, call them here
    @hooks?.connected?()

    # The current generation needs to be wrapped into this hook;
    # this way we don't close the next generation of connection
    # in the case of a reconnect....
    w = new StreamWrapper x, @
    @_tcpw = w

    #
    # MK 2012/12/20 -- Revisit me!
    # 
    # It if my current belief that we don't have to listen to the event
    # 'end', because a 'close' event will always follow it, and we do
    # act on the close event. The distance between the two gives us
    # the time to act on a TCP-half-close, which we are not doing.
    # So for now, we are going to ignore the 'end' and just act
    # on the 'close'.
    # 
    x.on 'error', (err) => @_handle_error err, w
    x.on 'close', ()    => @_handle_close w
    x.on 'data',  (msg) => @packetize_data msg

  ##-----------------------------------------
  
  _connect_critical_section : (cb) ->
    x = net.connect @tcp_opts
    x.setNoDelay true unless @do_tcp_delay

    # Some local switch codes....
    [ CON, ERR, CLS ] = [0..2]

    # We'll take any one of these three events...
    rv = new iced.Rendezvous
    x.on 'connect', rv.id(CON).defer()
    x.on 'error',   rv.id(ERR).defer(err)
    x.on 'close',   rv.id(CLS).defer()
    
    ok = false
    await rv.wait defer rv_id
    
    switch rv_id
      when CON then ok = true
      when ERR then @_warn err
      when CLS then @_warn "connection closed during open"

    if ok
      # Now remap the event emitters
      @_activate_stream x
      err = null
    else if not err?
      err = new Error "error in connection"

    cb err

  ##-----------------------------------------
  # To fulfill the packetizer contract, the following...
  
  _raw_write : (msg, encoding) ->
    if not @_tcpw?
      @_warn "write attempt with no active stream"
    else
      @_tcpw.write msg, encoding
 
  ##-----------------------------------------

##=======================================================================

exports.RobustTransport = class RobustTransport extends Transport
   
  ##-----------------------------------------

  # Take two dictionaries -- the first is as in Transport,
  # and the second is configuration parameters specific to this
  # transport.
  #
  #    reconnect_delay -- the number of seconds to delay between attempts
  #       to reconnect to a downed server.
  # 
  #    queue_max -- the limit to how many calls we'll queue while we're
  #       waiting on a reconnect.
  # 
  #    warn_threshhold -- if a call takes more than this number of seconds,
  #       a warning will be fired when the RPC completes.
  # 
  #    error_threshhold -- if a call *is taking* more than this number of
  #       seconds, we will make an error output while the RPC is outstanding,
  #       and then make an error after we know how long it took.
  #
  #      
  constructor : (sd, d = {}) ->
    super sd
    
    { @queue_max, @warn_threshhold, @error_threshhold} = d

    # in seconds
    @reconnect_delay = if (x = d.reconnect_delay) then x else 1
    @_time_rpcs = @warn_threshhold? or @error_threshhold?
    
    @queue_max = d.queue_max or 1000
    @_waiters = []
   
  ##-----------------------------------------

  _reconnect : () ->
    # Do not reconnect on an explicit close
    @_connect_loop true if not @_explicit_close

  ##-----------------------------------------

  _flush_queue : () ->
    tmp = @_waiters
    @_waiters = []
    for w in tmp
      @invoke w...
  
  ##-----------------------------------------
 
  _connect_loop : (re = false, cb) ->
    prfx = if re then "re" else ""
    i = 0
    
    await @_lock.acquire defer()

    go = true
    while go
      i++
      if @is_connected() or @_explicit_close
        go = false
      else
        @_info "#{prfx}connecting (attempt #{i})"
        await @_connect_critical_section defer err
        if err?
          await setTimeout defer(), @reconnect_delay*1000
        else
          go = false
    
    if @is_connected()
      s = if i is 1 then "" else "s"
      @_warn "#{prfx}connected after #{i} attempt#{s}"
      @_flush_queue()
      
    @_lock.release()
    cb() if cb

  ##-----------------------------------------

  _timed_invoke : (arg, cb) ->

    [ OK, TIMEOUT ] = [0..1]
    tm = new Timer start : true
    rv = new iced.Rendezvous
    meth = @make_method arg.program, arg.method

    et = if @error_threshhold then @error_threshhold*1000 else 0
    wt = if @warn_threshhold then @warn_threshhold*1000 else 0

    # Keep a handle to this timeout so we can clear it later on success
    to = setTimeout rv.id(TIMEOUT).defer(), et if et

    # Make the actual RPC
    Dispatch.prototype.invoke.call @, arg, rv.id(OK).defer rpc_res...

    # Wait for the first one...
    await rv.wait defer which

    # will we leak memory for the calls that never come back?
    flag = true
    
    while flag
      if which is TIMEOUT
        @_error "RPC call to '#{meth}' is taking > #{et/1000}s"
        await rv.wait defer which
      else
        clearTimeout to
        flag = false

    dur = tm.stop()

    m =  if et and dur >= et then @_error
    else if wt and dur >= wt then @_warn
    else                     null

    m.call @, "RPC call to '#{meth}' finished in #{dur/1000}s" if m

    cb rpc_res...
   
  ##-----------------------------------------

  invoke : (arg, cb) ->
    meth = @make_method arg.program, arg.method
    if @is_connected()
      if @_time_rpcs then @_timed_invoke arg, cb
      else                super arg, cb
    else if @_explicit_close
      @_warn "invoke call after explicit close"
      cb "socket was closed", {}
    else if @_waiters.length < @queue_max
      @_waiters.push [ arg, cb ]
      @_info "Queuing call to #{meth} (num queued: #{@_waiters.length})"
    else
      @_warn "Queue overflow for #{meth}"
  
##=======================================================================

exports.createTransport = (opts) ->
  if opts.robust then new RobustTransport opts, opts
  else                new Transport opts

##=======================================================================

