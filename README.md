# mathe-to-tex
A program to convert Mathematica source text to LaTeX

## Usage:

`perl mathe2tex.pl <filename>`

  where `<filename>` is the .txt file of Mathematica to translate


### Future Steps:

When considering on how to move forward, there is still the issue of translating top level fractions. This issue is made particularly difficult due to the fact that the `FullForm` of Mathematica is not available unless it is retrieved by a user-instiantiated REPL of Mathematica. If this issue were to be overcome, or the input be changed from a raw text file to the `FullForm` of the desired source text, then it would open the opportunity to solve the top-level fraction issue. In addition, if the top-level expression is available, refactoring or adding additional functionality could possibly circumvent the need for Wolframscript. For example, if a functional programming were used (such as OCaml or Racket), we could construct types that match the different expressions available in Mathematica and using the `FullForm` as input. The key is to use `FullForm` of the desired expression so that way the program would have access to the expression try and be able to process. For example if it encountered a fraction it could do the following
` match e 
    Divide e e -> \frac{process(e)}{process(e)};
    Multiply e e -> (process(e))*(process(e));
    W n1 n2 e -> \Whyp{process(e_0) process(e_1) ... process(e_n1)}{process(e_0) process(e_1) ... process(e_n2)} etc... `
