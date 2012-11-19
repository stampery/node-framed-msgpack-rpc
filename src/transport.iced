
net = require 'net'
{Lock} = require './lock'
{Dispatch} = require './dispatch'

##=======================================================================

exports.TcpTransport = class TcpTransport extends Dispatch

  ##-----------------------------------------

  constructor : ({ @port, @host, @tcp_opts, @tcp_stream, @log_hook,
                   @parent, @do_tcp_delay, @reconnect_delay}) ->
    super
    
    @host = "localhost" if not @host or @host is "-"
    @tcp_opts = {} unless @tcp_opts
    @tcp_opts.host = @host
    @tcp_opts.port = @port
    
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

  reconnect : () ->
    throw new Error "Reconnect called when @tcp_stream != null" if @tcp_stream
    if @reconnect_delay?
      await setTimeout defer(), @reconnect_delay
      @_warn "reconnecting..."
      @connect()
 
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
  # To fulfill the packetizer contract, the following 1
  
  _raw_write : (msg, encoding) ->
    if @tcp_stream
      @tcp_stream.write msg, encoding
    else if not @_write_closed_warn
      @_write_closed_warn = true
      @_warn "attempt to write to closed connection"
 
  ##-----------------------------------------
