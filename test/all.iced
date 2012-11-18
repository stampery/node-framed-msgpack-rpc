
fs = require 'fs'
path = require 'path'
colors = require 'colors'
deep_equal = require 'deep-equal'

CHECK = "\u2714"
FUUUU = "\u2716"

##-----------------------------------------------------------------------

class Tester
  constructor : ->
    @_ok = true

  equal : (a,b,what) ->
    if not deep_equal a, b
      console.log "In #{what}: #{JSON.stringify a} != #{JSON.stringify b}".red
      @_ok = false

  test_rpc : (cli, method, arg, expected, cb) ->
    full = [ cli.program , method ].join "."
    await cli.invoke method, arg, defer error, result
    @check_rpc full, error, result, expected
    cb()

  error : (e) ->
    console.log e.red
    @_ok = false

  check_rpc: (name, error, result, expected) ->
    if error then @error "In #{name}: #{error}"
    else @equal result, expected, "#{name} RPC result"

  is_ok : () -> @_ok

##-----------------------------------------------------------------------

class Runner

  ##-----------------------------------------
  
  constructor : ->
    @_files = []
    @_launches = 0
    @_tests = 0
    @_successes = 0
    @_rc = 0

  ##-----------------------------------------
  
  err : (e) ->
    console.log e.red
    @_rc = -1

  ##-----------------------------------------
  
  load_files : (cb) ->
    @_dir = path.dirname __filename
    base = path.basename __filename
    await fs.readdir @_dir, defer err, files
    if err?
      ok = false
      @err "In reading #{@_dir}: #{err}"
    else
      ok = true
      re = /.*\.(iced|coffee)$/
      for file in files when file.match(re) and file isnt base
        @_files.push file
    cb ok
  
  ##-----------------------------------------
  
  run_files : (cb) ->
    for f in @_files
      await @run_file f, defer()
    cb()

  ##-----------------------------------------
  
  run_code : (f, code, cb) ->
    await code.init defer err if code.init?
    destroy = code.destroy
    delete code["init"]
    delete code["destroy"]
    if err
      @err "Failed to initialize file #{f}: #{err}"
    else
      for k,v of code
        @_tests++
        T = new Tester
        await v T, defer err
        if err
          @err "In #{f}/#{k}: #{err}"
        else if T.is_ok()
          @_successes++
          console.log "#{CHECK} #{f}: #{k}".green
        else
          console.log "#{FUUUU} #{f}: #{k}".bold.red
    cb()

  ##-----------------------------------------
  
  run_file : (f, cb) ->
    try
      dat = require path.join @_dir, f
      await @run_code f, dat, defer()
    catch e
      @err "In reading #{f}: #{e}\n#{e.stack}"
    cb()

  ##-----------------------------------------

  run : (cb) ->
    await @load_files defer ok
    await @run_files defer() if ok
    @report()
    cb @_rc
   
  ##-----------------------------------------

  report : () ->
    if @_rc < 0
      console.log "FAILURE due to test configuration issues".bold.red
    @_rc = -1 unless @_tests is @_successes
    f = if @_rc is 0 then colors.green else colors.red
    console.log f "Tests: #{@_successes}/#{@_tests} passed".bold
    return @_rc
    
  ##-----------------------------------------
  
##-----------------------------------------------------------------------

runner = new Runner()
await runner.run defer rc
process.exit rc

##-----------------------------------------------------------------------
