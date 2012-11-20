
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
    
    fn = @log_hook or console.log
    fn "TcpTransport(#{@_remote_str}): #{err}"
   
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
    if @tcp_stream
      @tcp_stream.end()
      @tcp_stream = null
   
  ##-----------------------------------------

  handle_error : (e) ->
    @_warn e
    @_dispatch_force_eof()
    @close()
    @_reconnect()
   
  ##-----------------------------------------

  handle_close : () ->
    @tcp_stream = null if @tcp_stream
    @_reconnect()
   
  ##-----------------------------------------

  # In other classes we can override this...
  # See 'ReconnectTcpTRansport'
  _reconnect : () -> null
 
  ##-----------------------------------------
  
  activate_stream : () ->
    x = @tcp_stream
    x.on 'error', (err) => @handle_error err
    x.on 'close', ()    => @handle_close()
    x.on 'data',  (msg) => @packetize_data msg

    @_write_closed_warn = false
    @_generation++

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

exports.ReconnectTcpTransport = class ReconnectTcpTransport extends TcpTransport
   
  ##-----------------------------------------

  constructor : (d) ->
    super d

    # in milliseconds...
    @reconnect_delay = d.reconnect_delay or 1000
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
      await setTimeout defer(), @reconnect_delay
      @_info "#{prfx}connecting (attempt #{i})"
      await @_connect_critical_section defer ok if not @_explicit_close
    @_warn "#{prfx}connected after #{i} attempts"
    @_flush_queue()
    @_lock.release()
    cb() if cb

  ##-----------------------------------------

  invoke : (arg, cb) ->
    meth = @make_method arg.program, arg.method
    if @tcp_stream
      super arg, cb
    else if @_waiters.length < @queue_max
      @_waiters.push [ arg, cb ]
      @_info "Queuing call to #{meth} (num queued: #{@_waiters.length})"
    else
      console.log "queue overflow..."
      @_warn "Queue overflow for #{meth}"
  
##=======================================================================

