
net = require 'net'
{TcpTransport} = require './transport'

##=======================================================================

exports.TcpListener = class TcpListener

  ##-----------------------------------------

  constructor : ({@port, @host, @TransportClass}) ->
    @TransportClass = TcpTransport unless @TransportClass

  ##-----------------------------------------

  # Feel free to change this for your needs (if you want to wrap a connection
  # with something else)...
  make_new_transport : (c) ->
    new @TransportClass
      tcp_stream : c
      host : c.remoteAddress
      port : c.remotePort
      parent : @

  ##-----------------------------------------

  _got_new_connection : (c) ->
    # Call down to a subclass
    @got_new_connection @make_new_transport c

  ##-----------------------------------------

  _make_server : () ->
    @_tcp_server = net.createServer (c) => @_got_new_connection c

  ##-----------------------------------------

  _warn : (err, hook) ->
    hook = console.log unless hook
    addr = if @host then @host else "0.0.0.0"
    hook "#{addr}:#{@port}: #{err}"

  ##-----------------------------------------

  listen : (cb) ->
    @_make_server()
    
    [ OK, ERR ] = [0..1]
    rv = new iced.Rendzvous
    x = @_tcp_server
    x.listen @port, @host
    
    x.on 'error',     rv.id(ERR).defer err
    x.on 'listening', rv.id(OK).defer()
    
    await rv.wait defer which
    if which is OK
      err = null
      x.on 'error', (err) => @handle_error err
      x.on 'close', (err) => @handle_close()
    else
      @_tcp_server = null
      
    cb err

  ##-----------------------------------------

  listen_retry : (delay, cb, log_hook = null) ->
    go = true
    err = null
    while go
      await @listen defer err
      if err?.code == 'EADDRINUSE'
        @_warn err, log_hook
        await setTimeout defer(), delay
      else go = false
    cb err
      

