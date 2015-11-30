curlypp = require '../lib/main.coffee'
path = require 'path'

class OutStream
  constructor: ->
    @output = ''

  write: (s) ->
    @output += s

  end: ->


describe "curlypp", ->
  outstream = null

  beforeEach ->
    outstream = new OutStream()

  it 'can process a simple doc', ->

    curlypp """
      {{greeted: world}}
      Hello {{:greeted}}
    """.split(/\n/), {outstream}

    expect(outstream.output).toBe "Hello world"

  it 'can process an include', ->
    curlypp """
      {{test1.md}}
    """.split(/\n/), {outstream, dirname: path.resolve(__dirname, "fixtures")}

    expect(outstream.output).toBe "Hello world\n"

  it 'can process and filter an include', ->
    curlypp """
      {{test1.md | s/l/x/g}}
    """.split(/\n/), {outstream, dirname: path.resolve(__dirname, "fixtures")}

    expect(outstream.output).toBe "Hexxo worxd\n"

  it 'can process a macro with args', ->

    curlypp """
      {{greet: hello $1}}
      {{:greet world}}
    """.split(/\n/), {outstream}

    expect(outstream.output).toBe "hello world"

  #it 'can process a '
