
{unpack,pack} = require 'msgpack2'
{Ring} = require './ring'

##=======================================================================

msgpack_frame_len = (buf) ->
  bytes = buf[0]
  if buf < 0x80 then 1
  else if buf is 0xcc then 2
  else if buf is 0xcd then 3 
  else if buf is 0xce then 5
  else 0

##=======================================================================

class Packetizer
  """
  A packetizer that is used to read and write to an underlying stream
  (like a TcpTransport below).  Should be inherited by such a class.
  The subclasses should implement:
  
     @_write(msg,enc) - write this msg to the stream with the
       given encoding.
      
     @_fatal(err) - report an error with the stream
    
     @_dispatch(msg) - emit a packetized incoming message

  The subclass should call @packetize_data(m) whenever it has data to stuff
  into the packetizer's input path, and call @send(m) whenever it wants
  to stuff data into the packterizer's output path.
   
  """

  # The two states we can be in
  FRAME : 1
  DATA  : 2

  # results of getting
  OK : 0
  WAIT : 1
  ERR : -1

  ##-----------------------------------------
  
  constructor : ->
    super
    @_ring = new Ring()
    @_state = @FRAME
    @_next_msg_len = 0

  ##-----------------------------------------
  
  send : (msg) ->
    b2 = pack msg
    b1 = pack b2.length
    bufs = [ b1, b2 ]
    rc = 0
    enc = 'binary'
    for b in bufs
      @_raw_write b.toString(enc), enc
    return true

  ##-----------------------------------------

  _get_frame : () ->
    # We need at least one byte to get started
    return @WAIT unless @_ring.len() > 0

    # First get the frame's framing byte! This will tell us
    # how many more bytes we need to grab.  This is a bit of
    # an abstraction violation, but one worth it for implementation
    # simplicity and efficiency.
    f0 = @_ring.grab 1
    return @WAIT unless f0

    frame_len = msgpack_frame_len f0
    unless frame_len
      @_fatal "Bad frame header received"
      return @ERR

    # We now know how many bytes to suck in just to get the frame
    # header. If we can't get that much, we'll just have to wait!
    return @WAIT unless (f_full = @_ring.grab frame_len)?
    
    r = unpack f_full
    
    res = switch (typ = typeof r)
      when 'number'
      
        # See implementation of msgpack_frame_len above; this shouldn't
        # happen
        throw new Error "Negative len #{len} should not have happened" if r < 0
        
        @_ring.consume frame_len
        @_next_msg_len = r
        @_state = @DATA
        @OK
      when 'undefined'
        @WAIT
      else
        @_fatal "bad frame; got type=#{typ}, which is wrong"
        @ERR

    return res
       
  ##-----------------------------------------

  _get_msg: () ->
    l = @_next_msg_len
    
    ret = if l < @_ring.len() or not (b = @_ring.grab l)?
      @WAIT
    else if not (msg = unpack b)?
      @_fatal "bad encoding found in data/payload; len=#{l}"
      @ERR
    else
      @_ring.consume l
      @_state = @FRAME
      # Call down one level in the class hierarchy to the dispatcher
      @_dispatch msg
      @OK
    return ret
  
  ##-----------------------------------------
  
  packetize_data : (m) ->
    @_ring.buffer m
    go = @OK
    while go is @OK
      go = if @_state is @FRAME then @_get_frame() else @_get_msg()
     
##=======================================================================
