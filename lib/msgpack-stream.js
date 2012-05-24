var msgpack = require ('msgpack2');

// Wrap a nicer JavaScript API that wraps the direct MessagePack bindings.
//
// ....BUT
//
//    Perform the simple optimization of prepending the packet length before
//    each packet, that way we can be much more efficient about decoding...
//

var buffer = require('buffer');
var events = require('events');
var sys = require('util');

var unpack, pack;
exports.pack = pack = msgpack.pack;
exports.unpack = unpack = msgpack.unpack;

function Stream (s) {
    var self = this;

    events.EventEmitter.call(self);

    // Buffer of incomplete stream data
    self.buf = null;

    //
    // Send one packed message down the stream. Prefix with the number
    // of bytes in the packet, also sent in packed form.
    //
    self.send = function(m) {
        // Sigh, no arguments.slice() method
	var b2 = pack (m);
	var b1 = pack (b2.length);

	var bufs = [ b1, b2 ];

	var rc = 0;
	var enc = 'binary';
	for (var i in bufs) {
	    // Note that at some point we might start buffering stuff
	    // in user space.  Node.js seems to be handling that for us,
	    // though there isn't a great way to back-pressure the
	    // sender...
	    s.write (bufs[i].toString (enc), enc);
	}
	return true;
    };

    // Listen for data from the underlying stream, consuming it and emitting
    // 'msg' events as we find whole messages.
    s.on('data', function(d) {
	
        // Make sure that self.buf reflects the entirety of the unread stream
        // of bytes; it needs to be a single buffer
        if (self.buf) {
            var b = new buffer.Buffer(self.buf.length + d.length);
            self.buf.copy(b, 0, 0, self.buf.length);
            d.copy(b, self.buf.length, 0, d.length);

            self.buf = b;
        } else {
            self.buf = d;
        }

        // Consume messages from the stream, one by one
        while (self.buf && self.buf.length > 0) {

            var len = unpack(self.buf);
            if (typeof (len) == 'undefined') {
                break;
            }

	    // The remaining bytes in the buffer
	    var rem = unpack.bytes_remaining;

	    // The length of the 'len' field itself
	    var llen = self.buf.length - rem;

	    // We need to wait for this stream to fill up
	    if (rem < len) { 
		break;
	    }

	    var msg = unpack (self.buf.slice (llen));
	    if (!msg) {
		self.emit ('error', new Error ("bad encoding found"));
	    } else {
		self.emit('msg', msg);
	    }
	    self.buf = self.buf.slice (llen + len);
        }
    });
};

sys.inherits(Stream, events.EventEmitter);
exports.Stream = Stream;
