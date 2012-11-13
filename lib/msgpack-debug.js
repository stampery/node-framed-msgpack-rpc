
// Flags for what fields are in our debug messages
var F = { 
    NONE : 0,
    METHOD : 0x1,
    REMOTE : 0x2,
    SEQID : 0x4,
    TIMESTAMP : 0x8,
    ERROR : 0x10,
    ARG : 0x20,
    RES : 0x40,
    CLASS : 0x80,
    DIR : 0x100,
    VERBOSE : 0x200,
    ALL : 0xfffffff
};

F.LEVEL_0 = F.METHOD | F.CLASS | F.DIR;
F.LEVEL_1 = F.LEVEL_0 | F.SEQID | F.TIMESTAMP | F.REMOTE;
F.LEVEL_2 = F.LEVEL_1 | F.ERROR;
F.LEVEL_3 = F.LEVEL_2 | F.RES | F.ARGS;

// String versions of these flags
var sflags = {
    "m" : F.METHOD,
    "a" : F.REMOTE,
    "s" : F.SEQID,
    "t" : F.TIMESTAMP,
    "e" : F.ERROR,
    "p" : F.ARG,
    "r" : F.REPLY,
    "c" : F.CLASS,
    "d" : F.DIRECTION,
    "v" : F.VERBOSE,
    "A" : F.ALL,
    "0" : F.LEVEL_0,
    "1" : F.LEVEL_1,
    "2" : F.LEVEL_2,
    "3" : F.LEVEL_3
};

var dir = {
    INCOMING : 1,
    OUTGOING : 2,
};

var klass = {
    SERVER : 1,
    CLIENT_NOTIFY : 2,
    CLIENT_CALL : 3,
};

var F2S = {}
F2S[F.DIR] = {}
F2S[F.DIR][dir.INCOMING] = "in";
F2S[F.DIR][dir.OUTGOING] = "out";
F2S[F.CLASS] = {};
F2S[F.CLASS][klass.SERVER] = "server";
F2S[F.CLASS][klass.CLIENT_NOTIFY] = "cli.notify";
F2S[F.CLASS][klass.CLIENT_CALL] = "cli.call";

// Finally, export all of these constants...
exports.constants = {
    klass : klass,
    dir : dir,
    flags : F,
    sflags : sflags,
    field_to_string : F2S
};


//
// Convert a string of the form "1r" to the OR of those 
// consituent bitfields.
//
function sflags_to_flags (s) {
    var res = 0;
    for (var i = 0; i < s.length; i++) {
	var c = s.charAt(i);
	res |= F[c];
    }
    return res;
};
exports.sflags_to_flags = sflags_to_flags;

//
// Make a simple hook that takes an incoming message, turns on/off some
// fields based on the passed flags, puts in a timestamp, and then
// calls the given hook.
//
exports.make_hook = function (flgs, fn) {

    var sflags = flgs;
    if (typeof(flgs) == 'string') {
	sflags = sflags_to_flags (flgs);
    }

    return function (msg) {
	var new_msg = {}
	var keys = Object.keys(msg);

	for (var i in keys) {
	    var key = keys[i];
	    var do_copy = false;
	    var uck = key.toUpperCase();
	    var flag = F[uck];

	    // Usually don't copy the arg or res if it's in the other direction
	    if ((sflags & flag) != 0) {
		if (key == "res") {
		    do_copy = (msg.dir == dir.OUTGOING || (sflags & F.VERBOSE));
		} else if (key == "arg") {
		    do_copy = (msg.dir == dir.INCOMING || (sflags & F.VERBOSE));
		} else {
		    do_copy = true;
		}
	    }

	    if (do_copy) {
		f2s = F2S[flag];
		var val = msg[key];
		if (f2s) { val = f2s[val]; }
		new_msg[key] = val;
	    }
	}

	if (sflags & F.TIMESTAMP) {
	    new_msg.timestamp = (new Date()).getTime() / 1000.0;
	}
	fn(new_msg);
    };
};
