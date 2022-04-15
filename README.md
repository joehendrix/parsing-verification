# Formalized Proofs of Parse

This repo contains artifacts used to formalize a *proof of parse* for a [Parsing
Expression Grammar (PEG)][PEG].  A PEG is a type of grammar used for describing
languages.  PEGs are most similar to context-free grammars, but are
*deterministic*.  Specifically, the choice operator in a PEG is deterministic
rather than non-determinstic.  A PEG lacks the elegant mathematical
characterization of CFGs as least-fixpoint over polynomials, but can
serve as a practical framework for describing grammars and generating
efficient parsers.

A *proof of parse* is a machine checkable certificate that proves a given
string can be parsed by a grammar.  Proofs of parse are highly similar to
*abstract syntax trees (ASTs)*.  The primary difference for PEGs is that
a proof of parse also needs to be able to capture that a substrings
*cannot* be parsed by a non-terminal in the grammar.  This is because a
the choice and negative look-ahead primitives may accept a substring only
if the substring is not accepted by other non-terminals.

In this repo, we have formalized PEGs and proofs-of-parse in both [PVS][PVS]
and [Lean 4][Lean4], and proved that proofs-of-parse are deterministic.
Specifically, we show in both languages that two different proofs of parse
will always agree on whether a string is in the language denoted by a grammar.
See comments in the respective `peg.pvs` and `peg.lean` files to understand
the formalization.

[PEG]: https://en.wikipedia.org/wiki/Parsing_expression_grammar
[PVS]: https://pvs.csl.sri.com/
[Lean4]: https://github.com/leanprover/lean4
