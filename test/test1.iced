
exports.test1 = (cb) ->
  cb true
exports.test2 = (cb) ->
  cb false
exports.test3 = (cb) ->
  await setTimeout defer(),1000
  cb true
