require('iced-coffee-script').register();
var main = require('./jenky_server_main').main;
var argv = require('optimist').usage('Usage: $0 [-u <unix-domain-socket>]').string('u').argv;
main(argv)
