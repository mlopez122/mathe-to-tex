#!/usr/bin/wolframscript -print All
SetOptions[$Output, FormatType -> TeXForm]
(*
* Usage: wolframscript -file fullify.wls <filename>
* Prints each line as a FullForm Expr to be evaluated/processed
*)
t = TeXForm[$ScriptCommandLine[[2]]]
Print[t]