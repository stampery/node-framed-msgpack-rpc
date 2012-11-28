
path = require 'path'
fs = require 'fs'

version = null

exports.get_version = (cb) ->
  err = null
  if not version?
    dir = path.dirname __filename
    pjs = path.join dir, "..", "package.json"
    v = null
    await fs.readFile pjs, defer err, version
    if not err?
      try
        data = JSON.parse p
        v = data.version
        version = v
      catch e
        err = e
  if not version? and not err?
    err = "failed to get version..."
  cb err, version
  
