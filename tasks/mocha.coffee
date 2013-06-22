###
  grunt-mocha
  https://github.com/jcarnegie/grunt-mocha
 
  Copyright (c) 2013 Jeff Carnegie
  Licensed under the MIT license.
###


Mocha     = require "mocha"
requirejs = require "requirejs"
path      = require "path"
fs        = require "fs"
Base      = Mocha.reporters.Base

cwd     = process.cwd()
exists  = fs.existsSync || path.existsSync
handler = {}

module.exports = (grunt) ->
    # Add local node_modules to path
    module.paths.push(cwd, path.join(cwd, "node_modules"))

    grunt.registerMultiTask "mocha-server", "Run server-side Mocha tests as RequireJS modules", ->
        options = this.options
            asyncOnly: false
            bail: false
            # colors: undefined, shouldn't be defined
            coverage: false
            globals: []
            grep: false
            growl: false
            ignoreLeaks: false
            invert: false
            reporter: "list"
            require: []
            slow: 75
            timeout: 2000
            ui: "bdd"
            rjsConfig: {}
            env: "test"

        process.env.NODE_ENV = options.env

        # Mocha runner
        mocha = new Mocha()

        # Async function to ensure Grunt finishes
        async = this.async()

        # Original write function
        _stdout = process.stdout.write

        # Coverage output file
        output = null

        # Setup some settings
        mocha.ui(options.ui)
        mocha.reporter(options.reporter)
        mocha.suite.bail(options.bail)

        # Optional settings
        if options.timeout then mocha.suite.timeout options.timeout
        if options.grep then mocha.grep new RegExp(options.grep) 
        if options.growl then mocha.growl()
        if options.invert then mocha.invert()
        if options.ignoreLeaks then mocha.ignoreLeaks()
        if options.asyncOnly then mocha.asyncOnly()

        Base.useColors = true if options.colors == true
        Base.useColors = false if options.colors == false

        mocha.globals options.globals

        # Todo: will this work in CS?
        for option in options
            if options.hasOwnProperty option
                if option in handler
                    handler[option].call this, options[option]

        if !options.rjsConfig
            this.files.forEach (f) ->
                f.src.filter (file) ->
                    mocha.addFile file

        if options.reporter == "js-cov" || options.reporter == "html-cov"
            if !options.coverage then return grunt.fail.warn "Coverage option not set."

            # Check for coverage output file, else use default
            if options.coverage.output
                output = fs.createWriteStream(options.coverage.output, {flags: "w"})
            else
                output = fs.createWriteStream("coverage.html", {flags: "w"})

            # Check for coverage env option, else just set true
            if options.coverage.env
                process.env[options.coverage.env] = 1
            else
                process.env["COV"] = 1

            process.stdout.write = (chunk, encoding, cb) ->
                output.write(chunk, encoding, cb)

        run = ->
            mocha.run (failures) ->
                # Close output
                if output then output.end()

                # Restore default process.stdout.write
                process.stdout.write = _stdout

                if failures
                    grunt.fail.warn("Mocha tests failed.")

                async()

        if options.rjsConfig
            # forces mocha to define describe, it, etc in the global namespace
            mocha.suite.emit "pre-require", global, "", mocha

            # add the src files in the task config as deps in the RequireJS config
            options.rjsConfig.deps = this.filesSrc

            # set the RequireJS config
            requirejs.config options.rjsConfig

            # require the files via RequireJS
            requirejs [], -> run()
        else
            run()

handler.require = (f) ->
    files = [].concat(f)
    files.forEach (file) ->
        # Check for relative/absolute path
        if (exists(file) || exists(file + ".js"))
            # Append our cwd to import it
            require(path.join(cwd, file))
        else
            # Might just be a node_module
            require(file)
