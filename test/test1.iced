
exports["test1: the cow jumped over the moon..."] = (cb) ->
  cb true
exports.test2 = (cb) ->
  cb false
exports.test3 = (cb) ->
  await setTimeout defer(),10
  cb true
exports.init = (cb) ->
  await setTimeout defer(),10
  cb null
