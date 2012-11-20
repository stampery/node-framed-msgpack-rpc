
net = require 'net'
{Lock} = require './lock'
{Dispatch} = require './dispatch'

##=======================================================================

exports.TcpTransport = class TcpTransport extends Dispatch

  ##-----------------------------------------

  constructor : ({ @port, @host, @tcp_opts, @tcp_stream, @log_hook,
                   @parent, @do_tcp_delay}) ->
    super
    
    @host = "localhost" if not @host or @host is "-"
    @tcp_opts = {} unless @tcp_opts
    @tcp_opts.host = @host
    @tcp_opts.port = @port
    @_explicit_close = false
    
    @_remote_str = [ @host,  @port].join ":"
    @_lock = new Lock()
    @_write_closed_warn = false
    @_generation = 1

  ##-----------------------------------------

  remote : () -> @_remote_str
   
  ##-----------------------------------------

  _warn : (err) ->
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
    @close()
    @_reconnect()
   
  ##-----------------------------------------

  handle_close : () ->
    @tcp_stream = null if @tcp_stream
    @_reconnect()
   
  ##-----------------------------------------

  _reconnect : () -> null
 
  ##-----------------------------------------
  
  activate_stream : () ->
    x = @tcp_stream
    x.on 'error', (err) => @handle_error err
    x.on 'close', ()    => @handle_close()
    x.on 'data',  (msg) =>
      @packetize_data msg

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
  
  _fatal : (err) ->
    @_warn err
    if @tcp_stream
      x = @tcp_stream
      @tcp_stream = null
      x.end()
 
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
      console.log "invoking....."
      @invoke w...
   
  ##-----------------------------------------
 
  _connect_loop : (re = false, cb) ->
    prfx = if re then "re" else ""
    i = 0
    await @_lock.acquire defer()
    while not @tcp_stream
      i++
      await setTimeout defer(), @reconnect_delay
      @_warn "#{prfx}connecting (attempt #{i})"
      await @_connect_critical_section defer ok
    @_warn "#{prfx}connected after #{i} attempts"
    @_flush_queue()
    @_lock.release()
    cb() if cb

  ##-----------------------------------------

  invoke : (arg, cb) ->
    console.log "XXX"
    if @tcp_stream
      super arg, cb
    else if @_waiters.length < @queue_max
      console.log "do push!"
      @_waiters.push [ arg, cb ]
    else
      console.log "queue overflow..."
      @_warn "Queue overflow for #{@make_method arg.program, arg.method}"
  
##=======================================================================

