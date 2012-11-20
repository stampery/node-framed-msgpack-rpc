
net = require 'net'
{Lock} = require './lock'
{Dispatch} = require './dispatch'
{Logger} = require './log'

##=======================================================================

exports.TcpTransport = class TcpTransport extends Dispatch

  ##-----------------------------------------

  constructor : ({ @port, @host, @tcp_opts, @tcp_stream, @log_obj,
                   @parent, @do_tcp_delay}) ->
    super
    
    @host = "localhost" if not @host or @host is "-"
    @tcp_opts = {} unless @tcp_opts
    @tcp_opts.host = @host
    @tcp_opts.port = @port
    @_explicit_close = false
    
    @_remote_str = [ @host, @port].join ":"
    @log_obj = new Logger {} unless @log_obj
    @_lock = new Lock()
    @_write_closed_warn = false
    @_generation = 1
    @log_obj.set_remote @_remote_str

  ##-----------------------------------------

  remote : () -> @_remote_str
   
  ##-----------------------------------------

  _warn  : (e) -> @log_obj.warn  e
  _info  : (e) -> @log_obj.info  e
  _fatal : (e) -> @log_obj.fatal e
  _debug : (e) -> @log_obj.debug e
  _error : (e) -> @log_obj.error e
    
  ##-----------------------------------------

  connect : (cb) ->
    await @_lock.acquire defer()
    if not @tcp_stream?
      await @_connect_critical_section defer res
    else
      res = true
    @_lock.release()
    cb res if cb

  ##-----------------------------------------

  close : () ->
    @_explicit_close = true
    @_close @_generation

  ##-----------------------------------------
  
  _close : (g_wrapped) ->
    g_curr = @_generation
    @_generation++
    @_dispatch_force_eof()
    if (g_curr is g_wrapped) and @tcp_stream
      @tcp_stream.end()
      @tcp_stream = null
   
  ##-----------------------------------------

  _handle_error : (e, g) ->
    @_close g
    @_error e
    @_reconnect()
   
  ##-----------------------------------------
  
  _packetize_error : (err) ->
    @_handle_error "In packetizer: #{err}", @_generation
    
  ##-----------------------------------------

  _handle_close : (g) ->
    @_info "EOF on transport (generation=#{g})" unless @_explicit_close
    @_close g
    @_reconnect()
   
  ##-----------------------------------------

  # In other classes we can override this...
  # See 'ReconnectTcpTRansport'
  _reconnect : () -> null
 
  ##-----------------------------------------
  
  activate_stream : () ->
    x = @tcp_stream

    # The current generation needs to be wrapped into this hook;
    # this way we don't close the next generation of connection
    # in the case of a reconnect....
    cg = @_generation

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
    x.on 'error', (err) => @_handle_error cg, err
    x.on 'close', ()    => @_handle_close cg
    x.on 'data',  (msg) => @packetize_data msg

    @_write_closed_warn = false

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
      @tcp_stream = x
      # Now remap the event emitters
      @activate_stream()

    cb ok

  ##-----------------------------------------
  # To fulfill the packetizer contract, the following...
  
  _raw_write : (msg, encoding) ->
    if @tcp_stream
      @tcp_stream.write msg, encoding
    else if not @_write_closed_warn
      @_write_closed_warn = true
      @_warn "attempt to write to closed connection"
 
  ##-----------------------------------------

##=======================================================================

exports.RobustTransport = class RobustTransport extends TcpTransport
   
  ##-----------------------------------------

  # Take two dictionaries -- the first is as in TcpTransport,
  # and the second is configuration parameters specific to this
  # transport.
  #
  #    reconnect_delay -- the number of seconds to delay between attempts
  #       to reconnect to a downed server.
  # 
  #    queue_max -- the limit to how many calls we'll queue while we're
  #       waiting on a reconnect.
  # 
  #    warn_thresshold -- if a call takes more than this number of seconds,
  #       a warning will be fired when the RPC completes.
  # 
  #    error_threshhold -- if a call *is taking* more than this number of
  #       seconds, we will make an error output while the RPC is outstanding,
  #       and then make an error after we know how long it took.
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
    while not @tcp_stream and not @_explicit_close
      i++
      await setTimeout defer(), @reconnect_delay*1000
      @_info "#{prfx}connecting (attempt #{i})"
      await @_connect_critical_section defer ok if not @_explicit_close
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

    et = if @error_threshhold then @error_threshhold*1000 else 0
    wt = if @warn_threshhold then @warn_threshhold*1000 else 0

    # Keep a handle to this timeout so we can clear it later on success
    to = setTimeout rv.id(TIMEOUT).defer(), et if et

    # Make the actual RPC
    Dispatch.invoke.call @, meth, arg, rv.id(OK).defer rpc_res...

    # Wait for the first one...
    await rv.wait defer which

    # will we leak memory for the calls that never come back?
    flag = true
    
    while flag
      if which is TIMEOUT
        @_error "RPC call to '#{arg.meth}' is taking > #{et/1000}s"
        await rv.wait defer which
      else
        clearTimeout to
        flag = false

    dur = tm.stop()

    m =  if dur >= et then @_error
    else if dur >= wt then @_warn
    else                   null

    m.call @, "RPC call to '#{meth}' finished in #{dur/1000}s" if m

    cb rpc_res...
   
  ##-----------------------------------------

  invoke : (arg, cb) ->
    meth = @make_method arg.program, arg.method
    if @tcp_stream
      if @_time_rpcs then @_timed_invoke arg, cb
      else                super arg, cb
    else if @_waiters.length < @queue_max
      @_waiters.push [ arg, cb ]
      @_info "Queuing call to #{meth} (num queued: #{@_waiters.length})"
    else
      @_warn "Queue overflow for #{meth}"
  
##=======================================================================

