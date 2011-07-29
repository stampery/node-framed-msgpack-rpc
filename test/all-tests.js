#!/usr/bin/env node

if (module === require.main) {
    require('async_testing').run ("test/", process.ARGV);
}
