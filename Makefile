lexer.ml: lexer.mll
	ocamllex lexer.mli

parser.mli parser.ml: parser.mly
	menhir -v parser.mly

.depend: lexer.ml parser.mli parser.ml
	ocamldep *.ml *.mli > .depend

include .depend
