
var msgpack_rpc = require('../lib/msgpack-rpc');


module.exports = {
    'simple server handler' : function(test) {
	var addition_called = false;
	var response_received = false;
	var notification_recieved = false;

	var events = 2;

	var trigger = function () {
	    events--;
	    if (events == 0) {
		test.ok (addition_called);
		test.ok (notification_received);
		test.ok (response_received);
		test.finish ();
		server.close();
	    }
	}


	var handler = {
	    'add' : function(a, b, response) { 
		addition_called = true;
		response.result(a + b);
	    },
	    'temperature' : function(temp, response) {
		test.equal(102.1, temp);
		test.equal(undefined, response);
		notification_received = true;
		trigger ();
		
	    }
	};
	
	var server = msgpack_rpc.createServer();
	server.setHandler(handler);
	
	server.listen(8030, function() {
	    var client = msgpack_rpc.createClient(null, 8030, function() {
		client.invoke('add', 5, 7, function(err, response) {
		    response_received = true;
		    test.equal(5 + 7, response);
		    client.stream.end();
		    trigger ();
		});
		
		client.notify('temperature', 102.1);
	    });
	    
	});
	
    },
}
