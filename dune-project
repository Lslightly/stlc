(lang dune 3.12)

(name stlc)

(generate_opam_files true)

(source
 (github Lslightly/stcl))

(authors "Lslightly")

(maintainers "Lslightly")

(license MIT)

(package
 (name stlc)
 (synopsis "stlc")
 (description "Simply typed lambda calculus")
 (depends ocaml dune)
 (tags
  (topics "type checker" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project

(using menhir 2.1)
