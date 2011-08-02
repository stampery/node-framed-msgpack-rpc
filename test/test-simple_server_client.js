
var msgpack_rpc = require('../lib/msgpack-rpc');


module.exports = {
    'simple server handler' : function(test) {
	var addition_called = false;
	var responses_received = 0;
	var notification_recieved = false;

	var events = 3;

	var trigger = function () {
	    events--;
	    if (events == 0) {
		test.ok (addition_called);
		test.ok (notification_received);
		test.equal (responses_received, 2);
		test.finish ();
		client.stream.end();
		server.close();
	    }
	}

	function ServerConnection (server, tcpStream) {
	    var that = new msgpack_rpc.ServerConnection (server, tcpStream);
	    that._verbose = true;
	    that._name = "tester";

	    that.add = function(a, b, response) { 
		addition_called = true;
		response.result(a + b);
	    };

	    that.temperature = function(temp, response) {
		test.equal(102.1, temp);
		test.equal(undefined, response);
		notification_received = true;
		trigger ();
		
	    };

	    that.smush = function (d, response) {
		var tot = 0;
		for (var k in d) {
		    tot += parseInt (k) + d[k];
		}
		response.result (tot);
	    }

	    return that;
	};

	var client = null;
	var server = msgpack_rpc.createServer(ServerConnection);
	
	server.listen(8030, function() {
	    client = msgpack_rpc.createClient(null, 8030, function() {
		client.invoke('add', 5, 7, function(err, response) {
		    responses_received ++;
		    test.equal(5 + 7, response);
		    trigger ();
		});
		
		client.notify('temperature', 102.1);
		
		client.invoke ('smush', { 1 : 2, 3 : 4, 5 : 6 }, 
			       function (err, response) {
				   responses_received++;
				   test.equal (response, 21);
				   trigger ();
			       });
	    });
	    
	});
	
    },
}
