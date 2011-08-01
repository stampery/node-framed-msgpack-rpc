var msgpack = require ('msgpack-0.4');

// Wrap a nicer JavaScript API that wraps the direct MessagePack bindings.
//
// ....BUT
//
//    Perform the simple optimization of prepending the packet length before
//    each packet, that way we can be much more efficient about decoding...
//

var buffer = require('buffer');
var events = require('events');
var sys = require('sys');

var unpack, pack;
exports.pack = pack = msgpack.pack;
exports.unpack = unpack = msgpack.unpack;

function Stream (s) {
    var self = this;

    events.EventEmitter.call(self);

    // Buffer of incomplete stream data
    self.buf = null;

    // Send a message down the stream
    // 
    // Allows the caller to pass additional arguments, which are passed
    // faithfully down to the write() method of the underlying stream.
    self.send = function(m) {
        // Sigh, no arguments.slice() method
        var args = [pack(m)];
        for (i = 1; i < arguments.length; i++) {
            args.push(arguments[i]);
        }
	var len = 0;
	for (i = 0; i < args.length; i++) { len += args[i].length; }
	args.unshift (pack(len));

        return s.write.apply(s, args);
    };

    // Listen for data from the underlying stream, consuming it and emitting
    // 'msg' events as we find whole messages.
    s.addListener('data', function(d) {
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
	    var llen = self.buf.len - rem;

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
