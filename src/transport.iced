
net = require 'net'
{Lock} = require './lock'
{Dispatch} = require './dispatch'

##=======================================================================

exports.TcpTransport = class TcpTransport extends Dispatch

  ##-----------------------------------------

  constructor : (@_port, @_host = null, @_opts = {}) ->
    super
    @_connected = false
    @_host = "127.0.0.1" if not @_host or @_host is "-"
    @_tcp_stream = null
    @_remote_str = [ @_host,  @_port].join ":"
    
    @_tcp_opts = @_opts.tcp_opts or {}
    @_tcp_opts.host = @_host
    @_tcp_opts.port = @_port
    @_lock = new Lock()
    @_write_closed_warn = false
    @_generation = 1

  ##-----------------------------------------

  remote : () -> @_remote_str
   
  ##-----------------------------------------

  _warn : (err) ->
    fn = @_opts.log_hook or console.log
    fn "TcpTransport(#{@_remote_str}): #{err}"
   
  ##-----------------------------------------

  connect : (cb) ->
    await @_lock.acquire defer()
    if not @_tcp_stream?
      await @_connect_critical_section defer res
    else
      res = true
    @_lock.release()
    cb res

  ##-----------------------------------------
  
  _connect_critical_section : (cb) ->
    x = new net.createConnection @_tcp_opts, defer()
    x.setNoDelay true unless @_opts.delay
      
    events = { CON : 0, ERR : 1, CLS : 2 }

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
      x.on 'error', (err) => @handle_err err
      x.on 'close', ()    => @handle_close()
      x.on 'data',  (msg) => @packetize_data msg
      
      @_tcp_stream = x
      @_write_closed_warn = false
      @_generation++
      
    cb ok

  ##-----------------------------------------
  
  _fatal : (err) ->
    @_warn err
    if @_tcp_stream
      x = @_tcp_stream
      @_tcp_stream
      x.end()
 
  ##-----------------------------------------
  # To fulfill the packetizer contract, the following 1
  
  _raw_write : (msg, encoding) ->
    if @_tcp_stream
      @_tcp_stream.write msg, encoding
    else if not @_write_closed_warn
      @_write_closed_warn = true
      @_warn "attempt to write to closed connection"
 
  ##-----------------------------------------
