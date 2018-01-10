# Changes

Many changes have taken place for the January 2018 release of TAN. Here are the most significant:

* This version of TAN is treated as semi-stable. Only cosmetic or critical changes will be made to this version. Energy for improving TAN will be devoted to the next version.
* All Schematron validation allows three phases -- terse, normal, or verbose -- from fastest (quietest) to slowest (chattiest).
* In TAN validation, a document is first resolved (inclusions and keys are made explicit; numeration systems are converted to Arabic numerals; some other important steps take place), and then it is expanded. Under expansion, attributes are converted to elements (one per value) and normalized, and errors are checked. The process of expansion not only serves validation (the main goal), but makes the process of converting the TAN document (and its derivatives) into HTML and otherwise reusing it.

Major changes to specific parts of the functions:

* Global variable $self-core-errors-marked → $self-expansion with phase set to terse
* Global variable $self-prepped → $self-expansion. $self-expansion takes three different levels, depending upon validation phase
* Priorities introduced in default templates, -5 through 0 (default)

Major changes to specific parts of the schemas:

* `<declarations>` are replaced by two elements: `<definitions>` and zero or more `<alter>`s (alterations to sources).
* All entities are now defined in `<definitions>`, including `<persons>` (formerly called `<agents>`) and `<roles>`
* Validation now does not try to evaluate numerical forms throughout the document before resolving them (too lengthy a process). Instead `<definitions>` takes `<ambiguous-letter-numerals-are-roman>` (default = true). Be warned: you should not try to mix Roman and letter numbering in the same document.
* `<filter>`s have been moved to `<alter>`
* the class 2 `<alter>` includes child elements that specify alterations to be applied to the source(s): `<skip>`, `<rename>`, `<equate>`, and `<reassign>`
* Generally speaking, the greater the number of `<alter>` actions in a class 2 file, the longer it takes to validate
* `<rename-div-ns>`, `<split-leaf-div-at>`, `<equate-works>`, `<realign>`, `<anchor-div-ref>` have been dropped in favor of the the new `<alter>` actions (now available to all class 2 files, not just TAN-A-div).
* `@div-type-ref` has been renamed `@div-type.`
* The concept of splitting leaf divs has been dropped (replaced by `<reassign>`), so there is no more `@seg.` `<reassign>` moves not only the tokens but any non-tokens that immediately follow.
* `<agent>`s have been replaced by `<person>`, `<organization>`, and `<algorithm>`
* `<period>` has been introduced, to allow id-based references to multiple non-contiguous periods of time
* eliminated the following: `<transliteration>` (seemed ridiculous), `<equate-div-types>` (doesn't matter for validation), `@claim-rationale.`
* TAN-c has been eliminated as a format. Its functionality is taken over by TAN-A-div.
* `@cont` has been replaced by `<group>`
* TAN-LM has been renamed TAN-A-lm, unifying the naming conventions of class 2 files
* `@context` is gone from TAN-mor `<report>`s and `<assert>`s, which are now placed within `<where>`s, which have attributes that specify the conditions that must hold before the `<report>`s and `<assert>`s are validated.
* `<rights-excluding-sources>` and `<rights-source-only>` have been removed. The former is replaced by `<license>` and `<licensor>`.
* language-specific and source-specific TAN-A-lms are now joined. Lexicon doesn't have `<for-lang>`.
* TAN-A-lm assertions can be made without referring to a specifying token (for tokens that have no ambiguity)
* catalog.tan.xml has been introduced as a new class 3 format. This format builds upon the generic catalog.xml file described by Saxonica --  https://www.saxonica.com/documentation9.5/sourcedocs/collections.html -- by restricting the listings exclusively to TAN files, and adding simple data about each file.
* the special regular expression extension has been updated to Unicode 10.0, and the character class `\k{}` has been changed to `\u{}`.
