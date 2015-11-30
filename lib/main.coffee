tmp = require 'tmp'
path = require 'path'
fs = require 'fs'
{exec} = require 'child_process'
Q = require 'q'

runFilter = (command, content, {outstream, macro, refs}) ->
  cmd = command

  if content.trim() isnt ''
    name = tmp.tmpNameSync()
    fs.writeFileSync(name, content)
    cmd = command.concat([name])

  child = exec cmd, (error, stderr, stdout) ->
    curlypp stdout.split(/\n/), {outstream, dirname, macro, refs}

  return child.stdin

defineMacro = (macroName, argv, content, macro) ->
  argv = parseArgs(argv)
  {args, kwargs} = processArgv(argv)

  macro[macroName] =
    body: content
    name: macroName
    args: args
    kwargs: kwargs

applyMacro = (s, macro) ->
  argv = parseArgs(s)
  macroName = argv[0]
  argv = argv[1..]

  {args, kwargs} = processArgv(argv)
  #for k,v of macro[macroName].defaults

  s = macro[macroName].body.replace /\$(\d+)/, (m, num) -> args[parseInt(num)-1]
  s = s.replace /\$\{(\w+)\}/, (m, varname) -> kwargs[varname]

  s

  # s
  #
  #curlypp([s], {outstream, dirname, macro, refs})

processArgv = (argv) ->
  args = []
  kwargs = {}
  if argv?
    for arg in argv
      if m = arg.match /(\w+)=(.*)/
        name = m[1]
        value = m[2]
      else
        name = null
        value = arg

      if m = value.match /^"(.*)"$/
        value = value.replace(/\\"/g, '"').replace(/\\\\/g, '\\')

      if name?
        kwargs[name] = value
      else
        args.push value

  {args, kwargs}

parseArgs = (s) -> s.match /((?:\w+=)?"(?:[^\\"]+|\\"|\\\\)*"|\S+)/g

curlypp = (lines, {outstream, dirname, macro, refs}) ->

  if typeof lines is 'string'
    dirname = path.dirname(lines)
    lines = fs.readFileSync(lines).split(/\n/)

  line    = null
  mode    = null
  content = null
  indent  = null
  command = null
  completeLine = null

  unless macro
    macro = {}
  unless refs
    refs = {GLOBAL: {}}

  outdented = (content) ->
    if content instanceof Array
      content = content.join("\n")

    indent = content.match(/^(\s*)/)[1]

    if indent isnt ''
      content.replace (new RegExp("^#{indent}", 'm')), ''
    else
      content

  processFilter = (line) ->
    if mode is 'filter'
      if m = line.match /^(\s*)\}\}\}\s*$/
        if m[1] is indent
          outstream = runFilter command, outdented(content), {outstream, macro, refs}
          return true

      content += line
      return true

    if m = line.match /^(\s*)\{\{\{\s*\|\s*(.*)/
      mode    = 'filter'
      indent  = m[1]
      command = m[2].split
      content = ''
      return true

    return false

  applyMultiline = (firstLine, content, outstream) ->
    if m = firstLine.match /\|\s*(.*)/
      command = m[1].split(/\s+/)
      return runFilter command, outdented(content), {outstream, macro, refs}

    if m = firstLine.match /:\s*(.*)/
      s = applyMacro m[1],macro

      curlypp(s.split(/\n/), {outstream, dirname, macro, refs})
      return outstream

    if m = firstLine.match /(\w+)\s*:\s*(.*)/
      defineMacro m[1], m[2], content, macro
      return outstream

  processMultiline = (line) ->
    if mode is 'multiline'
      if m = line.match /^(\s*)\}\}\}\s*$/
        if m[1] is indent
          outstream = applyMultiline firstLine, outdented(content), outstream
          return true

      content.push line
      return true

    if m = line.match /^(\s*)\{\{\{\s*(.*)/
      mode    = 'multiline'
      indent  = m[1]
      firstLine = m[2]
      content = []
      return true

    return false

  debugger

  for line,lineno in lines
    # process incomplete lines
    if line.match /\\$/
      incompleteLine = incompleteLine + line[...line.length-1]
      continue

    if incompleteLine?
      line = incompleteLine + line
      incompleteLine = null

    continue if processMultiline line

    exprs = line.split /\{\{(.*?)\}\}/g

    for expr,i in exprs

      if i % 2 == 0
        outstream.write expr
        continue

      expr = expr.trim()
      if m = expr.match /^([\w\-]+)@([\w\-]*)(?:\s*:)?\s+(.*)/
        [ match, refName, indexName, caption ] = m

        if indexName is ''
          indexName = 'GLOBAL'

        if indexName not of refs
          refs[indexName] = {}

        refs[indexName][refName] =
          name: refName
          index: indexName
          caption: caption

        outstream.write """<a name="#{indexName}-#{refName}">"""
        if caption
          outstream.write """<span class="index #{indexName}">#{caption}</span>"""

      else if m = expr.match /^(.*)\s*<([\w\-]+)@([\w\-]*)>$/
        [ match, caption, refName, indexName ] = m

        outstream.write """<a href="##{indexName}-#{refName}" class="ref #{indexName}">#{caption}</a>"""

      else if m = expr.match /^(.*)\s*([\w\-]+)@([\w\-]*)$/
        [ match, caption, refName, indexName ] = m

        outstream.write """<a href="##{indexName}-#{refName}" class="ref #{indexName}">#{caption}</a>"""

      else if m = expr.match /^([\w\-]+):\s*(.*)$/
        defineMacro m[1], '', m[2], macro

      else if m = expr.match /^:\s*(.*)$/
        [ match, varName ] = m
        s = applyMacro m[1],macro
        curlypp(s.split(/\n/), {outstream, dirname, macro, refs})

      else if m = expr.match /^(.*?)\:\:(.*)/
        [ match, pkg, path] = m
        s = null
        for pkgdir in ['node_modules', 'bower_comonents']
          try
            dir = path.dirname(path.resolve(dirname, pkgdir, pkg, path))
            s = fs.readfileSync(path.resolve dirname, pkgdir, pkg, path)
            s = s.toString()
            break
          catch
            continue
        unless s?
          throw new Error "could not find #{expr}"

        curlypp s.split(/\n/), {outstream, dirname: dir, macro, refs}

      else
        filters = expr.split /\s*\|\s*/
        filename = filters[0]
        filters = filters[1..]

        try
          s = fs.readFileSync(path.resolve dirname, filename).toString()
          if filters
            myOutstream = outstream

            createOutstream = (outstream, f) ->
              write: (s) ->
                f(s, outstream)
              end: ->
                outstream.end()

            filters.reverse()

            _filters = []

            filters.forEach (f) ->
              if m = f.match /^s\/((?:\\\/|[^\/]+)*)\/((?:\\\/|[^\/]+)*)\/([gm]*)$/
                [pattern, replacement, flags] = m[1..]
                pattern = new RegExp(pattern, flags)
                do (pattern, replacement) ->
                  myOutstream = createOutstream myOutstream, (s, outstream) ->
                    outstream.write s.replace pattern, replacement
              else
                myOutstream = createOutstream myOutstream, (s, outstream) ->
                  child = exec f, (error, stdout, stderr) ->
                    outstream.write(stdout)
                  child.stdin.write(s)
                  child.stdin.end()

            # _filters = []
            # for f in filters
            #   if m = f.match /^s\/((?:\\\/|[^\/]+)*)\/((?:\\\/|[^\/]+)*)\/([gm]*)$/
            #     do (m) ->
            #       [pattern, replacement, flags] = m[1..]
            #       pattern = new RegExp(pattern, flags)
            #       _filters.push (s, callback) ->
            #         callback(s.replace pattern, replacement)
            #   else
            #     do (f) ->
            #       _filters.push (s, callback) ->
            #         child = exec f, (error, stdout, stderr) ->
            #           callback(stdout)
            #         child.stdin.write(s)
            #         child.stdin.end()

            # myoutstream = {
            #   write: (s) ->
            #     debugger
            #     promises = []
            #     promise = Q(s)
            #     _filters.forEach (f) ->
            #       promise = promise.then (s) ->
            #         deferred = Q.defer()
            #         f s, (s) ->
            #           debugger
            #           deferred.resolve(s)
            #         deferred.promise
            #
            #     promise.then (s) ->
            #       outstream.write(s)
            #   end: ->
            #     outstream.end()
            # }

          curlypp s.split(/\n/), {outstream: myOutstream, dirname: dir, macro, refs}
        catch e
          console.log e.stack
          throw new Error "could not find #{expr}"

    if lineno != lines.length-1 and not (exprs.length == 3 and exprs[0] is '' and exprs[2] is '')
      outstream.write("\n")

module.exports = curlypp
