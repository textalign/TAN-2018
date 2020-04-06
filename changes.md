# Changes made since last stable version

The following changes have been made since version 2018, and may not yet be documented in the current guidelines. See the git log of the dev branch for a more comprehensive account of all changes.

## General

The directories `do things` and `TAN-key` have been renamed `applications` and `vocabularies` respectively. (This ensures grammatical consistency among top-level directory names.)

The head has been revised. Better management of the `&lt;head>` was needed, along with semantic and grammatical clarity in its parts. The `&lt;head>` is now conceived of as consisting of sequential parts:
1. name/desc of the file
1. general declarations
1. links to other files
1. adjustments
1. vocabulary + ids
1. credits
1. change log
1. pending work.

For changes in standard vocabularies, see TAN-voc (olim TAN-key) below.

* General declarations included `&lt;license>` and `&lt;licensor>`; the latter now becomes @licensor, attached to the former; they are now joined by `&lt;numerals>`; `&lt;token-definition>`; `&lt;work>` (class 1 files); `&lt;version>` (class 1 files); `&lt;for-lang>`, `&lt;tok-starts-with>`, `&lt;tok-is>` (class 2 files)
* There may be more than one `&lt;license>` (since some things might be dual licensed). `&lt;licensor>` is removed and only `@licensor` in `&lt;license>` is allowed
* `&lt;key>` has been changed to `&lt;vocabulary>`. The files being pointed to, after all, are not providing key-value pairs, or anything similar to what we think of when we speak of keys. Really those files provide IRI + name + desc + location values for individual things. (Hence TAN-key files are now being called TAN-voc.)
* `&lt;definitions>` was strange, because what's happening there was not what we ordinarily mean by "define," which requires more than simply nomenclature. To assign IRIs and names to something is not to define it, but to label it. Furthermore, all the things that should populate this element are meant to resolve idrefs, and to supply extra vocabulary (note change above from `&lt;key>` to `&lt;vocabulary>`). So `&lt;definitions>` has been changed to `&lt;vocabulary-key>` (cf. comparable change mentioned above to `&lt;key>`) and any children that do not tether vocabulary items to idrefs (the traditional function of a key) have been moved up into the general declarations. 
* `&lt;alter>` was the only child of `&lt;head>` that was a verb. It has been changed to `&lt;adjustments>`, and because it has logical priority, it preceds `&lt;vocabulary-key>`..
* Required element `&lt;file-resp>` has been introduced. All TAN files have data that constitute a series of claims, and TAN requires all claims to be credited/blamed upon a claimant. This element specifies who, unless otherwise spcefied, should be treated as the claimant for the file.
* A `&lt;to-do>` has been introduced in the last section of `&lt;head>`. This takes the place of `@in-progress,` and uses `&lt;comment>`s to itemize the things that still need to be done to the file. `&lt;to-do>` is required, but it can be empty – a possible sign that the file is no longer in progress. Thus, users of TAN files will be better informed exactly what is meant by a file being in progress, and the owner of the file can keep a list of things that remain to be done.

Imprinting and referencing vocabulary has been streamlined and simplified. 

Imprinting vocabulary occurs when a file is resolved. Its head is altered as follows.

* Every `&lt;vocabulary>` is imprinted with the resolved vocabulary items that are mentioned in the host document. 
* After the `&lt;vocabulary-key>` are imprinted a series of `&lt;tan-vocabulary>` elements, each one pointing to a standard TAN vocabulary file, and containing those vocabulary items that are mentioned in the host document.
* Each vocabulary item is imprinted with `&lt;id>` or `&lt;alias>` if it has been assigned an id or an alias by a local file.
* Each vocabulary item `&lt;name>`, if it has not been normalized, is given a parallel `&lt;name norm="">`, The normalized form expedites subsequent queries.

Referencing vocabulary is facilitated primarily through the new function `tan:vocabulary()`, which allows for a rapid retrieval of some or all of a resolved file's vocabulary. The function is based upon the following principles.

* For any element named X with `@which,` the normalized form of `@which` (defined by `tan:normalize-name()`) is assumed to point to the normalized form of `&lt;name>` of some single vocabulary item that has been defined for an element of name X. This is similar to the previous version, except that name normalization now affects &#x5F; (underscore) and - (hyphen), both of which are now treated as equivalent to spaces.
* For any element named X with an attribute Y that takes idrefs (e.g., `@src`, `@license`), the space-tokenized values of Y will be checked within vocabulary items suited for X, first against a target `&lt;id>` or `&lt;alias>` and, failing that, will check for a match against a `&lt;name>` . 
* Implication: `&lt;name>` becomes effectively another kind of identifier, like `@xml:id` or `@id.` But the latter are case sensitive and matched exactly whereas `&lt;name>`s are compared after normalization: everything changed to lowercase and hyphens and underscores replaced with spaces. Further, a match on `@xml:id/@id` overrides any matches on `&lt;name>`.
* Implication: attributes like `@who,` @license, `@subject` may take a mixture of idrefs and names. But someone typing a name value into ove of these attributes must be certain to replace word spaces with hyphens or underscores, because, in such attributes, spaces separate values.
* The new global variable $elements-supported-by-TAN-vocabulary-files specifies names of elements supported by TAN standard vocabulary. But now under the subdirectory `vocabularies` there is the subdirectory `extra`, which contains supplementary vocabularies that might be useful for specific communities of practice.
* `&lt;vocabulary>` may take `@which,` but only if it points to the items within the standard TAN-voc file vocabularies.TAN-voc.xml. This is the way the extra TAN vocabularies are invoked.
* Standard TAN-voc files now have all `&lt;name>` values normalized, to expedite validation.

Files are now resolved differently. 

* The goal is to return a file that can be interpreted without reference to vocabularies (including standard TAN ones) or inclusions. (One would still need to fetch files referenced by class-2 `&lt;source>`s, or `&lt;redivision>`, `&lt;successor>`, `&lt;see-also>` etc.)
* In resolving a file F, elements involved in inclusions are handled nearly at the very beginning. All inclusions are resolved recursively and returned to F as a set of `&lt;inclusion>`s that carry children errors, vocabulary items, and substitutions. The errors and vocabulary items are copied to F's `&lt;inclusion>` and individual substitutions are made in F. This means that inclusion now brings back not just specific elements, but the vocabulary upon which it depends. It also means ids/idrefs are qualified, with F's id/idrefs being distinct from any of F's inclusions' id/idrefs. This is important, because F might assign an id `foo` to a scriptum, but F's inclusion, to a person. This approach resolved other problems as well. Under the previous system, if you used `&lt;resp @include="incl1">` you would have to have also invoked `@include` for `&lt;role>` and `&lt;person>`. Previously, reference errors were reported not in the resolved file but only in terse expansion.
* Another important change in file resolution is in numbering schemes. Changes have been made to the way class 1 files are resolved with regard to values of `@n` (see below), to help reconcile synonyms. This means that when a class 1 file is resolved, its vocabulary must be resolved before values of `@n` can be normalized. This technique provides great flexibility to creators of class 1 files. But it complicates TAN-A files, In the 2018 schema, every `@ref` in a class 2 file was resolved independent of what the sources were doing. But in any claim that combines sources that have different systems of resolving ambiguous numerals (e.g., c as 3 in an alphabet system but 100 in Roman numerals), number resolution would require a complexity that is at present infeasible. In a future release, it is expected that TAN-A files will take `&lt;numeral>` specified for sources.
* Resolution of numbers now happens at the conclusion of `tan:resolve-doc()`, because it requires querying vocabulary..

The above treats default resolution of a TAN file. But sometimes we are interested in only a portion of the resolved file, not the whole thing. This requirement is especially important in dependencies of class 2 files. Normally only a portion of the file is of interest, so to resolve an entire class 1 dependent file is a waste of time. There are two points in validation when one must resolve a dependent file: expansion and template mode check-referred-doc.

Expansion has been streamlined, to avoid summoning global or in-scope variables that do not matter. XSLT operations ignore such unused variables, but Schematron validation seems not to. Thoroughly revised the way a hierarchy is reset in the course of expanding the sources of a class 2 file, using `@reset` to mark elements that need to be moved and `@has-been-reset` to mark those that have. Resetting has been moved from class 2 functions to class 1 functions.

New errors introduced: wrn07, wrn08, inc05, tan21, inc06, whi05, voc06, loc04, lnk07

Deleted errors: tan13 (an `&lt;alias>` should be able to combine different element types, esp. `&lt;person>` and `&lt;organization>`; it's up to other elements that use the `&lt;alias>` `@ids` to import the correct kinds of vocabulary items); all vrb error codes (consolidated in clm error codes), tei02, tei03 (handled by ODD file).

Errors named tky... are now renamed voc...

New elements: `&lt;predecessor>` and `&lt;successor>`, to leave a sequence of file revisions.

New attributes: `@claim-when`

New functions: `tan:last-change-agent()`, `tan:trim-long-text()`, `tan:catalogs()`, `tan:chop-string()` (2 parameters), `tan:collate-sequences()`, `tan:collate-pair-of-sequences()`, `tan:catalog-uris()`, `tan:collection()`, `tan:unique-char()`, `tan:most-common-item-count()`, `tan:vertical-stops()` (to support `tan:diff()`), `tan:nested-phrase-loop()` (supports `tan:chop-string()`), `tan:primary-agent()`; `tan:revise-href()`; `tan:lm-data()`; `tan:takes-idrefs()`; `tan:target-element-names()`; `tan:consolidate-resolved-vocab-items()`; `tan:element-vocabulary()`; `tan:attribute-vocabulary()`; `tan:vocabulary()`, `tan:get-and-resolve-dependency()`, `tan:fill()`, `tan:ordinal()` (moved from extra functions), `tan:duplicate-values()` (alias for `tan:duplicate-items()`, `tan:node-before()`, `tan:indent-value()`, `tan:copy-indentation()`, `tan:url-is-local()`, `tan:imprint-adjustment-locator()` (for adjusting class-1 sources of class-2 files), `tan:attr()`, `tan:is-valid-uri()`

Deleted functions: `tan:glossary()` (replaced by new `tan:vocabulary()`), `tan:definition()` (replaced by new `tan:vocabulary()`), `tan:evaluate-morphological-test()`, `tan:resolve-idref()`

Moved `tan:element-fingerprint()` from extra functions to main functions

New global variables: $shy (same as $dhy), $doc-catalog-uris, $doc-catalogs, $local-catalog, $relationships-reserved, $relationship-model, $relationship-resegmented-copy, $break-marker-regex, $loop-tolerance, $elements-supported-by-TAN-vocabulary-files, $is-validation, $TAN-version-is-under-development, $internet-available, $names-of-attributes-that-take-idrefs, $names-of-attributes-that-may-take-multiple-space-delimited-values, $names-of-attributes-that-permit-keyword-last, $names-of-attributes-that-are-case-indifferent, $names-of-elements-that-take-idrefs, $names-of-elements-that-describe-text-creators, $names-of-elements-that-describe-text-bearers, $names-of-elements-that-describe-textual-entities, $TEI-namespace, TAN-id-namespace, $doc-is-error-test, $doc-id-namespace, $TAN-vocabularies-vocabulary

Supplied main parameters directory, to hold global parameters most likely to change. Includes parameters for main validation, and those supporting appications.

$help-trigger moved to the validation parameters file, to allow easier manipulation of its value.

New frameworks file added, to enhance oXygen functionality

Introduced the concept of catalogs.

`&lt;ambiguous-numerals-are-roman>` has been replaced by `&lt;numerals priority="letters|roman">`. This is briefer, and allows flexibility for growth, e.g., in TAN-A files where one might specify which sources follow which schemes.

Some functions are furnished with local variable $diagnostics, to allow for ad hoc testing.

Tokens that straddle two leaf divs (marked by discretionary hyphen or the zero-width joiner) are now rejoined at the end of the first leaf div, leaving the second leaf div without the word fragment. As a new principle, counting within a leaf div should begin with the first complete word.

Some enhancement of functions: 

* `tan:resolve-href()` now has a longer version that provides breadcrumbs.
* `tan:diff()` greatly revised. If a string is considerably long, a search is first done for sequences of unique words that are shared between the strings, then the pieces between are fed to `tan:diff()`; if the string is not too long, it follows the normal routine, now converted to a two-loop process easier to diagnose. Snap-to-word has been made more reliable.
* `tan:tokenize-div()` (and related templates) adjusted to do a better job taking into account special div-end characters and token counting.
* `tan:tokenize-text()`: extended to four parameters, to add either `@q` or `@pos`
* `tan:infuse-divs()` adjusted to take into account special endings of leaf divs
* `tan:chop-string()` now allows a parameter that preserves parenthetical phrases (most suited to chopping into sentences or clauses).
* `tan:shallow-copy()` now has a two-parameter version, to allow copying to a specified depth.
* `tan:definition()` now has a two-parameter version, to allow queries on values that have been separated from their contextual document.
* `tan:resolve-doc()` now has a 2-parameter version.
* `tan:error()` now supports messagnig functions (validation won't do this, but they would be useful for XSLT transformations)
* `tan:strip-duplicates()` has been renamed `tan:remove-duplicate-siblings()` and moved to the extra functions file.
* `tan:resolve-alias()` has been simplified. Each `&lt;alias>` is inserted with `&lt;idref>` for every terminal value. Nothing is done to check the validity of the references.
* `tan:analyze-sequence()`, `tan:analyze-ref()` revised to be more straightforward, stable.
* Debugged `tan:conditions-hold()`, which requires an extra parameter indicating whether the fallback value should be true or false if a condition is not even found.
* regular expressions submodule now includes `tan:n-to-dec()` and `tan:dec-to-n()`, to permit conversions from decimal to base N systems (N = 2 through 16 or 64) or vice versa. 

## TAN-T(EI)

To facilitate the expedient processing of `&lt;see-also>`, new elements have been introduced: `&lt;model>`, `&lt;redivision>`, `&lt;annotation>`, and `&lt;companion-version>` (different version of the same work in the same scriptum). A model (only one allowed) specifies another class 1 file that has been used as a model for division types and `@n` values. A redivision is the exact same work, version, and scriptum, but segmented and labeled with a different type of reference system. An `&lt;annotation>` is a class 2 file that makes the class 1 file a `&lt;source>`.

The TEI ODD file has been adjusted, to handle natively the alternation between `@include` and `&lt;div>`'s ordinary attributes.

In the service of merging different sources, the new `tan:group-divs()` groups together `&lt;div>`s that might have multiple `&lt;ref>`s and be in their own peculiar sequence. It was written to preserve as best as possible the original sequence of each reference within a given source.

If a leaf div ends in a special line-end character, the first `&lt;tok>` or `&lt;non-tok>`s with `@n=1` will be taken from the next leaf div and fused at the end. If the first element so moved matches in name the last element of the original leaf div, they will be fused together. That is, if the leaf div ends with `&lt;tok>` and the next one starts with a `&lt;tok>` (or, vice versa, both `&lt;non-tok>`) they will become one element. If they are different elements, then the transfer still happens, but no fusion takes place.

Leaf Div Uniqueness Rule has been downgraded to a warning. The problem is that some non-leaf divs can through a transformation easily become leaf divs. Some scripta are encoded such that leaf divs are broken up (see Bodëús's edition of Aristotle's Categories, at 2a35, 2b5, and 2b6b). And some translations must be encoded so that leaf divs interleave. The final example that convinced me that the LDUR rule had to be downgraded was Migne's Patrology. One homily would have a final section that straddled the top of, say, columns 83 and 84, and the very next homily would begin with the remaining part of column 83, then go to 84. In this case, there were no subcolumn letters. If the two homilies were treated as component parts of a single work, then the LDUR had to be violated, or one must be forced to include line numeration (very time consuming). The process also made me realize that the notion of leaf div is relative and arbitrary. A leaf might easily in another version contain leaves, or be dropped, to make its non-leaf parent a leaf div.

New `@n` alias method. There are some values of `@n` that are frustrating to use, e.g., ep, epi, and epilogue, or Mt, Matt, and Matthew. Now, any TAN-voc file may include `@affects-attribute="n,"` and the `&lt;name>`s in each item will be treated as synonyms. When the file is resolved, during the process that converts non-Arabic numerals to Arabic numerals, any specially invoked TAN-voc items will be checked, and matching values of `@n` will be converted to the normalized form of the first `&lt;name>` in the first `&lt;item>` found. That means that communities of practice can work with common TAN-voc files, and not worry about having to use the same abbreviations.

Along with the new approach to `@n` above comes the new element `&lt;n-alias>` and its accompanying `@div-type.` This element, part of `&lt;head>`, specifies which div types are affected by any aliases for `@n.` Including this element expedites validation. In a test on a file of the New Testament with about 40,000 elements, validation without `&lt;n-alias>` took about 23 seconds longer than validation without the TAN-voc file; with it (`&lt;n-alias div-type="bk"/>`, affecting only the 27 topmost `&lt;div>`s), negligibly longer (1/10th of a second or shorter).

## TAN-A-div (now TAN-A)

Now renamed TAN-A, because this is the most generic form of an alignment or annotation file. In theory, it could be used to express TAN-A-tok and TAN-A-lm, but not vice versa.

Added $datatypes-that-require-unit-specification, to modify rules that forced some objects to be set as elements instead of attributes within claims.

`&lt;locus>` is now `&lt;at-ref>`, and is treated as an opt-in element. That is, a claim may not include it unless it is part of a verb type that explicitly allows it.

`&lt;in-lang>` introduced as an opt-in claim element, to support claims about translations.

A scriptum `&lt;subject>` and `&lt;object>` may take descendant `&lt;div>`s to specify a particular place in scripta. This allows for more precise claims to be made, e.g., Bonner 2015, volume 1 pages 14-27 provides a transcription of manuscript A, folios 14-23.

`&lt;claim>` is now allowed to take `@xml:id,` so that claims might be more easily used as components of other claims. This is the first and (so far) only descendant of a `&lt;body>` in any TAN format that takes `@xml:id,` and therefore qualify as vocabulary items.

The profile of `&lt;claim>`--what it may take or not--depends now largely on how verbs are defined. See TAN-voc file  description below on verbs. 

## TAN-A-lm

New `@tok-pop.` (Need to write error rules.)

`&lt;ana>` and `&lt;lm>` may now take `@lexicon,` @grammar

Deleted error tlm01 since morphological files may be language-specific and credit their sources.

New element: `&lt;tok-starts-with>`, `&lt;tok-is>` (meant to optimize a process that might require working with thousands of TAN-A-lm files)

## TAN-mor

`@lexicon` and `@morphology` allowed in more elements within `&lt;body>`.

## TAN-key (now TAN-voc)

New name TAN-voc

`@which` in a TAN-voc file may point to its own vocabulary

`@affects-attribute` introduced, to permit synonymity within values of `@n`. This opens up a vocabulary file to serve as an alias for `@n` in class 1 files.

New errors introduced: tky05

Standard TAN-voc file for relationships has been removed. If a relationship is deemed to be important, it will be codified in a new element name (e.g., `&lt;model>` was introduced to replace the relationship vocabulary item for models).

Standard TAN-voc file for vocabularies has been added. These point to the supplementary TAN-voc files under vocabularies/extra/, to allow for those extra vocabularies to be invoked by means of `&lt;vocabulary which=""/>` in any TAN file.

group-types.TAN-voc.xml and verbs.TAN-voc.xml have been revised in light of a revision of the hierarchy of textuals. New textual verbs have been introduced accordingly, and structured more clearly. These groups, however, do not affect validation.

Verbs are now treated as exceptional (the same way tokenization patterns are), and promoted from `&lt;item>` to `&lt;verb>`. By default, verbs require a subject and an object, and may allow place or period, and do not allow `&lt;in-lang>` or `&lt;at-ref>`. Users may now specify the construction of a `&lt;verb>`s through a child `&lt;constraint>`s, which specify requirements for subject, object, place, period, in-lang, at-ref, each allowed as an attribute or a child element. The required `@status` specifies whether the given element is required, allowed, or disallowed. Subjects and objects may be defined according to an item type (the name of the element expected, in `@item-type).` An object may be defined as a datatype (`@content-datatype),` with an optional regular expression defining the datatype's lexical constraint (`@content-lexical-constraint).`

Error reporting on claims has now been generalized according to constraints specified under a `&lt;verb>`'s vocabulary.

Claims may now take `@xml:id,` allowing them to be referenced as vocabulary, and to be made parts of claims. Therefore claims may now not only nest, but become the subject or object of claims that are not ancestors.

## Extra functions

`tan:node-type()`

`tan:resolve-attr-which()` removed (no longer needed with new approach to vocabulary)

template text-only

`tan:element-fingerprint()`

`tan:add-attribute()`

`tan:tree-to-sequence()` and `tan:sequence-to-tree()`

global variables to define the ends of words, clauses, sentences

`tan:int-to-aaa()`, `tan:int-to-grc()`, tan:dec-to-bin, tan:base64-to-dec, tan:base64-to-bin, `tan:integers-to-sequence()`

`tan:acronym()`

`tan:search-morpheus()`

`tan:lang-catalog()`

`tan:ordinal()` moved to main function set

tan:counts-to-firsts renamed `tan:lengths-to-positions()`

`tan:batch-replace-advanced()`

`tan:initial-upper-case()`

`tan:title-case()`

`tancommas-and-ands()` (series of strings with commas (including option for Oxford comma) and and inserted) 

## Extra variables

$applications-uri-collection, $applications-collection

$error-tests, $error-markers

$TAN-feature-vocabulary

## Advanced / recommended best practices

Class 1 filenames should terminate in something that expresses the principal type of reference system (logical or scriptum-based) followed by a string indicating whether the reference system is native to the scriptum or if it follows some other reference system. Example: ar.cat.fra.1844.saint-hilaire.ref-logical-native.xml indicates that the logical (i.e., non-scriptum-based) reference system is native to the French edition. But ar.cat.fra.1844.saint-hilaire.ref-logical-after-grc.xml indicates that the transcription has been divided and labeled following the Greek archetype.

