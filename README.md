# curly-preprocessor

This is a simple preprocessor initially intended to preprocess markdown files.

## Include files

```
{{file}}
```

This will include file `file.md`.

```
{{file.md}}
```

This will also include `file.md`.

```
{{package::file.md}}
```

This will include `node_modules/package/file.md`.

Indentation of the current line will be inserted before all lines of the include.
Let `file.md` content:
```
Some very
cool
lines
```

Then including it with:
```
some text
    {{file}}
```

Will result in
```
some text
    Some very
    cool
    lines
```

Including it in a paragraph:
```
    embed {{file}} into this line
```

Results in
```
    embed Some very
    cool
    lines into this line
```

## Macros

Set variable `foo` to `bar`

```
{{foo: bar}}
```

You can expand `foo` using {{:foo}}

Macros

```
  {{greet: Hello $1}}
```

Can be expanded using {{:greet world}}.

This way you can create macros:
```
{{ref: <a name="$1"></a>}}

And expand it {{:ref my-mark}}.

And then you can reference it [foo][my-mark].
```

## References

You often need cross referencing in a document. Create a reference to `bar`
in index (named `bar`):
```
{{@index: Some Term}}
```

You can dereference it with {{This is some text <some-term@index>}}

You can set an explicit name:
```
{{term@index: Some Term}}
```

This way you can create glossaries:

```markdown
  ## Glossary

  {{term@glossary: My Term}}
     Description of My Term

  ... and later or before you can reference it:

  {{My Term <term@glossary>}}
```

If you do not have multiple index lists, you can use the empty one for ease:

```
  {{ref@}}

  An you can {{reference it <ref@>}}
```

You can leave out the `:` and the `< >` in the forms, which are for explicit
syntactic clarity.  It is enough, to have the `@`-expression as first word or
last word.  If you have colon in your


## Directives

A directive is something, which has some input, and is replaced by its output.
General form is:
```
  {{{<directive>
    input
    for
    directive.
  }}}
```
input will be dedented by indentation of first line.

A directive can be any command, assume you have graphviz installed:
```
  {{{ dot -Tsvg
  digraph G {
    A -> B
  }
  }}}
```

Note that all node_modules/.bin in directory subtrees starting from current
working directory are included into path.  So with `npmjs install node-plantuml`
you can do
```
  {{{ puml generate | inline-img image/png
  @startuml
  Sally -> Harry : hello
  @enduml
  }}}
```

inline-img is shipped with this preprocessor and creates an image from input
data:
```
  <img src="data:image/png;base64,hEReIsTHEbaSE64enCoDedDAta">
```

You can also define Multiline macros:

```
  {{{macro:
  And here is text expanding $1
  and $2
  }}}
```

You can also expand using the multiline version:

```
  {{{:macro first second third
  and fourth parameter
  which is the only
  multiline one.
  }}}
```

Named parameters:
```
  {{{:macro name1=foo name2=bar name3=
  foo bar
  }}}
```

```
  {{{macro:
  ${name1} and so on ${name2} and finally ${name3}
  }}}
```

```
  {{{puml:
      {{{ puml generate | inline-img image/png
      @startuml
      $1
      @enduml
      }}}
  }}}
```

```
  {{{:puml
  A -> B hello
  }}}
```

## Filters

And for more readability you can define other filters.  They will be applied
before this filter after processing filter directives.  Filter directives are
applied when they are read for the rest of the file.  The filtered code will
be then also preprocessed.

```
{{| command to filter }}
```

Inline filter:

```
{{{| bash
tr ABC DEF
}}}
```

Or
```
{{{| perl -n
print
}}}
```

Example.  For more ease of use of plantuml, you can inject the curly code of
```
{{{:puml
  ...
}}}
```
around all code starting with `@startuml` and ending with `@enduml`.

{{{| perl -n
m{^(\s*)@plantuml\s*$} && print "$1{{{plantuml:\n$_";
m{^(\s*)@plantuml\s*$} && print "$_$1}}}\n";
}}}


### Commandline options

--inline-errors
    Display errors inline

--

## Escaping

If you want curlypp not to expand a curly-expression you can proceed it with "\".
```
\{{{
}}}
```
