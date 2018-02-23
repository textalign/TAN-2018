<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:import href="TAN-parameters.xsl"/>

   <!-- Core functions for all TAN files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:include href="../regex/regex-ext-tan-functions.xsl"/>
   <xsl:include href="../errors/TAN-core-errors.xsl"/>
   <xsl:include href="TAN-core-expand-functions.xsl"/>
   <xsl:include href="TAN-core-resolve-functions.xsl"/>
   <xsl:include href="TAN-core-string-functions.xsl"/>

   <xsl:character-map name="tan">
      <!-- This map included, so that users of TAN files can see where ZWJs and soft hyphens are in use. -->
      <xsl:output-character character="&#x200d;" string="&amp;#x200d;"/>
      <xsl:output-character character="&#xad;" string="&amp;#xad;"/>
   </xsl:character-map>

   <!-- DEFAULT TEMPLATE RULES -->
   <!-- Standard TAN templates will restrict themselves to priority levels -5 through 0 (default) -->
   <xsl:template priority="-5" match="document-node()" mode="#all">
      <xsl:document>
         <xsl:apply-templates mode="#current"/>
      </xsl:document>
   </xsl:template>
   <xsl:template priority="-5" match="*" mode="#all">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template priority="-5" match="comment() | processing-instruction()" mode="#all">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:error | tan:help | tan:warning | tan:fix | tan:fatal | tan:info"
      priority="-4" mode="#all">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:tail" mode="#all" priority="-4">
      <!-- We ignore, but retain, tails throughout -->
      <xsl:copy-of select="."/>
   </xsl:template>
   <!-- We include an empty template on a no-name element, to avoid validation warnings -->
   <xsl:template match="squelch" priority="-5"/>

   <!-- CORE GLOBAL VARIABLES -->

   <!-- general -->
   <xsl:variable name="TAN-version" select="'2018'"/>
   <xsl:variable name="previous-TAN-versions" select="('1 dev')"/>
   <xsl:variable name="regex-characters-not-permitted" select="'[&#xA0;&#x2000;-&#x200a;]'"/>
   <xsl:variable name="quot" select="'&quot;'"/>
   <xsl:variable name="apos" select='"&apos;"'/>
   <xsl:variable name="zwj" select="'&#x200d;'"/>
   <xsl:variable name="dhy" select="'&#xad;'"/>
   <xsl:variable name="shy" select="$dhy"/>
   <xsl:variable name="empty-doc" as="document-node()">
      <xsl:document/>
   </xsl:variable>
   <xsl:variable name="empty-element" as="element()">
      <empty/>
   </xsl:variable>
   <xsl:variable name="erroneously-looped-doc" as="document-node()">
      <xsl:document>
         <xsl:copy-of select="tan:error('inc03')"/>
      </xsl:document>
   </xsl:variable>
   <xsl:variable name="now" select="tan:dateTime-to-decimal(current-dateTime())"/>

   <xsl:variable name="elements-that-must-always-refer-to-tan-files"
      select="('morphology', 'inclusion', 'key')"/>
   <xsl:variable name="elements-that-refer-to-textual-items"
      select="('person', 'agent', 'scriptum', 'work', 'version', 'source')"/>
   <xsl:variable name="attributes-that-take-non-arabic-numerals" select="('ref', 'n', 'new')"/>
   <xsl:variable name="tag-urn-regex-pattern"
      select="'tag:([\-a-zA-Z0-9._%+]+@)?[\-a-zA-Z0-9.]+\.[A-Za-z]{2,4},\d{4}(-(0\d|1[0-2]))?(-([0-2]\d|3[01]))?:\S+'"/>

   <xsl:variable name="id-idrefs" select="doc('TAN-idrefs.xml')"/>

   <xsl:variable name="TAN-namespace" select="'tag:textalign.net,2015'"/>

   <xsl:variable name="validation-phase-names" select="('terse', 'normal', 'verbose')"
      as="xs:string+"/>
   <xsl:variable name="stated-validation-phase" as="xs:string?">
      <xsl:analyze-string select="string-join(/processing-instruction(), '')"
         regex="phase\s*=\s*.([a-z]+)">
         <xsl:matching-substring>
            <xsl:value-of select="lower-case(regex-group(1))"/>
         </xsl:matching-substring>
      </xsl:analyze-string>
   </xsl:variable>

   <!-- A major separator is meant to delimit hierarchies from each other, e.g., source, ref, and token-->
   <xsl:variable name="separator-major" select="'##'" as="xs:string"/>
   <!-- A hierarchy separator is meant to delimit levels in a reference hierarchy, e.g., within @ref -->
   <xsl:variable name="separator-hierarchy" select="' '" as="xs:string"/>
   <!-- A hierarchy separator is meant to delimit parts of a complex number, e.g., a letter + numeral combined, e.g., 7b becomes 7#2  -->
   <xsl:variable name="separator-hierarchy-minor" select="'#'" as="xs:string"/>

   <!-- If one wishes to see if an entire string matches the following patterns defined by these 
        variables, they must appear between the regular expression anchors ^ and $. -->
   <xsl:variable name="roman-numeral-pattern"
      select="'m{0,4}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})'"/>
   <xsl:variable name="latin-letter-numeral-pattern"
      select="'a+|b+|c+|d+|e+|f+|g+|h+|i+|j+|k+|l+|m+|n+|o+|p+|q+|r+|s+|t+|u+|v+|w+|x+|y+|z+'"/>
   <xsl:variable name="arabic-indic-numeral-pattern" select="'[٠١٢٣٤٥٦٧٨٩]+'"/>
   <xsl:variable name="greek-letter-numeral-pattern"
      select="'͵?([α-θΑ-ΘϛϚ]?[ρ-ωΡ-ΩϠϡ]?[ι-πΙ-ΠϘϙϞϟ]?[α-θΑ-ΘϛϚ]|[α-θΑ-ΘϛϚ]?[ρ-ωΡ-ΩϠϡ]?[ι-πΙ-ΠϘϙϞϟ][α-θΑ-ΘϛϚ]?|[α-θΑ-ΘϛϚ]?[ρ-ωΡ-ΩϠϡ][ι-πΙ-ΠϘϙϞϟ]?[α-θΑ-ΘϛϚ]?)ʹ?'"/>
   <xsl:variable name="syriac-letter-numeral-pattern"
      select="'[ܐܒܓܕܗܘܙܚܛ]?\p{Mc}?(ܬ?[ܩܪܫܬ]|[ܢܣܥܦܨ]\p{Mc})?\p{Mc}?[ܝܟܠܡܢܣܥܦܨ]?\p{Mc}?[ܐܒܓܕܗܘܙܚܛ]\p{Mc}?|[ܐܒܓܕܗܘܙܚܛ]?\p{Mc}?(ܬ?[ܩܪܫܬ]|[ܢܣܥܦܨ]\p{Mc})?\p{Mc}?[ܝܟܠܡܢܣܥܦܨ]\p{Mc}?[ܐܒܓܕܗܘܙܚܛ]?\p{Mc}?|[ܐܒܓܕܗܘܙܚܛ]?\p{Mc}?(ܬ?[ܩܪܫܬ]|[ܢܣܥܦܨ]\p{Mc})\p{Mc}?[ܝܟܠܡܢܣܥܦܨ]?\p{Mc}?[ܐܒܓܕܗܘܙܚܛ]?\p{Mc}?'"/>
   <xsl:variable name="nonlatin-letter-numeral-pattern"
      select="string-join(($arabic-indic-numeral-pattern, $greek-letter-numeral-pattern, $syriac-letter-numeral-pattern), '|')"/>
   <xsl:variable name="n-type-pattern"
      select="
         (concat('^(', $roman-numeral-pattern, ')$'),
         '^(\d+)$',
         concat('^(\d+)(', $latin-letter-numeral-pattern, ')$'),
         concat('^(', $latin-letter-numeral-pattern, ')$'),
         concat('^(', $latin-letter-numeral-pattern, ')(\d+)$'),
         concat('^(', $nonlatin-letter-numeral-pattern, ')$'),
         '(.)')"/>
   <xsl:param name="words-that-look-like-numbers" as="xs:string*" select="('A', 'I', 'Ει')"/>
   <xsl:variable name="n-type" select="('i', '1', '1a', 'a', 'a1', 'α', '$', 'i-or-a')"/>
   <xsl:variable name="n-type-label"
      select="
         ('Roman numerals', 'Arabic numerals', 'Arabic numerals + alphabet numeral', 'alphabet numeral', 'alphabet numeral + Arabic numeral',
         'non-Latin-alphabet numeral', 'string', 'Roman or alphabet numeral')"/>

   <!-- The following list of URN namespace com from the Official IANA Registry of URN Namespaces, https://www.iana.org/assignments/urn-namespaces/urn-namespaces.xhtml, accessed 5 January 2018 -->
   <xsl:variable name="official-urn-namespaces"
      select="
         ('3gpp',
         'adid',
         'alert',
         'bbf',
         'broadband-forum-org',
         'cablelabs',
         'ccsds',
         'cgi',
         'clei',
         'dgiwg',
         'dslforum-org',
         'dvb',
         'ebu',
         'eidr',
         'epc',
         'epcglobal',
         'eurosystem',
         'example',
         'fdc',
         'fipa',
         'geant',
         'globus',
         'gsma',
         'hbbtv',
         'ieee',
         'ietf',
         'iptc',
         'isan',
         'isbn',
         'iso',
         'issn',
         'ivis',
         'liberty',
         'mace',
         'mef',
         'mpeg',
         'mrn',
         'nato',
         'nbn',
         'nena',
         'newsml',
         'nfc',
         'nzl',
         'oasis',
         'ogc',
         'ogf',
         'oid',
         'oipf',
         'oma',
         'pin',
         'publicid',
         's1000d',
         'schac',
         'service',
         'smpte',
         'swift',
         'tva',
         'uci',
         'ucode',
         'uuid',
         'web3d',
         'xmlorg',
         'xmpp',
         'urn-1',
         'urn-2',
         'urn-3',
         'urn-4',
         'urn-5',
         'urn-6',
         'urn-7')"/>


   <!-- self -->
   <xsl:variable name="orig-self" select="/" as="document-node()"/>
   <xsl:variable name="self-resolved" select="tan:resolve-doc(/)" as="document-node()"/>
   <!-- More than one document is allowed in self expansions, because class-2 expansions must go hand-in-hand with the expansion of their class-1 dependencies. -->
   <xsl:variable name="self-expanded" select="tan:expand-doc($self-resolved)" as="document-node()+"/>

   <xsl:variable name="head" select="$self-resolved/*/tan:head"/>
   <xsl:variable name="body" select="$self-resolved/*/(tan:body, tei:text/tei:body)"/>
   <xsl:variable name="doc-id" select="/*/@id"/>
   <xsl:variable name="doc-type" select="name(/*)"/>
   <xsl:variable name="doc-class" select="tan:class-number($self-resolved)"/>
   <xsl:variable name="doc-uri" select="base-uri(/*)"/>
   <xsl:variable name="doc-parent-directory" select="tan:uri-directory($doc-uri)"/>
   <xsl:variable name="source-ids"
      select="
         if (exists($head/tan:source/@xml:id)) then
            $head/tan:source/@xml:id
         else
            for $i in (1 to count($head/tan:source))
            return
               string($i)"/>
   <xsl:variable name="all-ids"
      select="($head//(@xml:id, @id), /tei:TEI//descendant-or-self::tei:*/@xml:id)"/>
   <xsl:variable name="all-head-iris" select="$head//tan:IRI[not(ancestor::tan:error)]"/>
   <xsl:variable name="duplicate-ids" select="$all-ids[index-of($all-ids, .)[2]]"/>
   <xsl:variable name="duplicate-head-iris" select="$all-head-iris[index-of($all-head-iris, .)[2]]"/>

   <xsl:variable name="doc-namespace"
      select="substring-before(substring-after($doc-id, 'tag:'), ':')"/>
   <xsl:variable name="primary-agent"
      select="($head/tan:definitions/(tan:person, tan:organization, tan:algorithm)[tan:IRI[matches(., concat('^tag:', $doc-namespace))]])[1]"/>

   <!-- catalogs -->
   <xsl:variable name="doc-catalog-uris" select="tan:catalog-uris(/)"/>
   <xsl:variable name="doc-catalogs" select="tan:catalogs(/, $validation-phase = 'verbose')"
      as="document-node()*"/>
   <xsl:variable name="local-catalog" select="$doc-catalogs[1]"/>

   <!-- inclusions -->
   <xsl:variable name="inclusions-1st-da" select="tan:get-1st-doc(/*/tan:head/tan:inclusion)"/>
   <xsl:variable name="inclusions-resolved"
      select="tan:resolve-doc($inclusions-1st-da, false(), 'incl', /*/tan:head/tan:inclusion/@xml:id, (), ())"
      as="document-node()*"/>

   <!-- keys -->
   <xsl:key name="item-via-node-name" match="tan:item"
      use="tokenize(string-join(((ancestor-or-self::*/@affects-element)[last()], (ancestor-or-self::*/@affects-attribute)[last()]), ' '), '\s+')"/>
   <xsl:variable name="TAN-keyword-files" as="document-node()*"
      select="collection('../../TAN-key/collection.xml')"/>
   <xsl:variable name="TAN-keywords" as="document-node()*">
      <!-- We do not put dependency TAN-key files through the customary tan:expand-doc(), which relies upon $TAN-keywords -->
      <xsl:apply-templates select="$TAN-keyword-files" mode="expand-tan-key-dependencies">
         <xsl:with-param name="leave-breadcrumbs" tunnel="yes" select="false()"/>
      </xsl:apply-templates>
   </xsl:variable>
   <xsl:variable name="relationship-keywords-for-tan-files"
      select="tan:glossary('relationship', (), 'TAN files')"/>
   <xsl:variable name="keys-1st-da" select="tan:get-1st-doc($head/tan:key)"/>
   <xsl:variable name="keys-resolved" select="tan:resolve-doc($keys-1st-da)"/>
   <xsl:variable name="keys-expanded" select="tan:expand-doc($keys-resolved)"/>
   <xsl:variable name="all-keywords" select="($keys-expanded, $TAN-keywords)" as="document-node()*"/>

   <!-- sources -->
   <xsl:variable name="sources-1st-da" select="tan:get-1st-doc($head/tan:source)"/>
   <xsl:variable name="sources-must-be-altered"
      select="exists($head/tan:alter/(tan:equate, tan:rename, tan:reassign, tan:skip))"/>
   <xsl:variable name="sources-resolved" as="document-node()*"
      select="tan:resolve-doc($sources-1st-da, $sources-must-be-altered, 'src', $source-ids, (), ())"/>

   <!-- see-also, context -->
   <xsl:variable name="see-alsos-1st-da" select="tan:get-1st-doc($head/tan:see-also)"/>
   <xsl:variable name="see-alsos-resolved" select="tan:resolve-doc($see-alsos-1st-da)"/>

   <!-- relationships -->
   <xsl:variable name="relationships-reserved" select="tan:glossary('relationship')"/>
   <xsl:variable name="relationship-model" select="$relationships-reserved[tan:name = 'model']"/>
   <xsl:variable name="relationship-resegmented-copy"
      select="$relationships-reserved[tan:name = 'resegmented copy']"/>

   <!-- token definitions -->
   <xsl:variable name="token-definitions-reserved" select="$TAN-keywords//tan:token-definition"/>
   <xsl:variable name="token-definition-letters-only"
      select="$token-definitions-reserved[../tan:name = 'letters only']"/>
   <xsl:variable name="token-definition-letters-and-punctuation"
      select="$token-definitions-reserved[../tan:name = 'letters and punctuation']"/>
   <xsl:variable name="token-definition-nonspace"
      select="$token-definitions-reserved[../tan:name = 'nonspace']"/>
   <xsl:variable name="token-definition-default" select="$token-definitions-reserved[1]"/>

   <!-- morphologies -->
   <xsl:variable name="morphologies-1st-da"
      select="
         if ($doc-type = 'TAN-A-lm') then
            tan:get-1st-doc($head/tan:definitions/tan:morphology)
         else
            ()"/>
   <xsl:variable name="morphologies-resolved" as="document-node()*"
      select="
         if ($doc-type = 'TAN-A-lm') then
            tan:resolve-doc($morphologies-1st-da, false(), 'morphology', $head/tan:definitions/tan:morphology/@xml:id, (), ())
         else
            ()"/>

   <!-- CORE FUNCTIONS -->
   <!-- For general functions that take as input only strings, see the separate, included file (above). -->

   <!-- FUNCTIONS: NUMERICS -->

   <xsl:function name="tan:rom-to-int" as="xs:integer*">
      <!-- Input: any roman numeral less than 5000 -->
      <!-- Output: the numeral converted to an integer -->
      <xsl:param name="arg" as="xs:string*"/>
      <xsl:variable name="rom-cp"
         select="
            (109,
            100,
            99,
            108,
            120,
            118,
            105)"
         as="xs:integer+"/>
      <xsl:variable name="rom-cp-vals"
         select="
            (1000,
            500,
            100,
            50,
            10,
            5,
            1)"
         as="xs:integer+"/>
      <xsl:for-each select="$arg">
         <xsl:variable name="arg-lower" select="lower-case(.)"/>
         <xsl:if test="matches($arg-lower, concat('^', $roman-numeral-pattern, '$'))">
            <xsl:variable name="arg-seq" select="string-to-codepoints($arg-lower)"/>
            <xsl:variable name="arg-val-seq"
               select="
                  for $i in $arg-seq
                  return
                     $rom-cp-vals[index-of($rom-cp, $i)]"/>
            <xsl:variable name="arg-val-mod"
               select="
                  (for $i in (1 to count($arg-val-seq) - 1)
                  return
                     if ($arg-val-seq[$i] lt $arg-val-seq[$i + 1]) then
                        -1
                     else
                        1),
                  1"/>
            <xsl:value-of
               select="
                  sum(for $i in (1 to count($arg-val-seq))
                  return
                     $arg-val-seq[$i] * $arg-val-mod[$i])"
            />
         </xsl:if>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:aaa-to-int" as="xs:integer*">
      <!-- Input: any alphabet numerals -->
      <!-- Output:the integer equivalent -->
      <!-- Sequence goes a, b, c, ... z, aa, bb, ..., aaa, bbb, ....  E.g., 'ccc' - > 55 -->
      <xsl:param name="arg" as="xs:string*"/>
      <xsl:for-each select="$arg">
         <xsl:variable name="arg-lower" select="lower-case(.)"/>
         <xsl:if test="matches($arg-lower, concat('^(', $latin-letter-numeral-pattern, ')$'))">
            <xsl:variable name="arg-length" select="string-length($arg-lower)"/>
            <xsl:variable name="arg-val" select="string-to-codepoints($arg-lower)[1] - 96"/>
            <xsl:value-of select="$arg-val + ($arg-length - 1) * 26"/>
         </xsl:if>

      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:ara-to-int" as="xs:integer*">
      <!-- Input: Arabic-indic numerals -->
      <!-- Output: Integer values, if the input conforms to the correct pattern -->
      <xsl:param name="arabic-indic-numerals" as="xs:string*"/>
      <xsl:for-each
         select="$arabic-indic-numerals[matches(., concat('^', $arabic-indic-numeral-pattern, '$'))]">
         <xsl:copy-of select="xs:integer(translate(., '٠١٢٣٤٥٦٧٨٩', '0123456789'))"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:variable name="alphabet-numeral-key" as="element()">
      <key>
         <convert grc="α" syr="ܐ" int="1"/>
         <convert grc="β" syr="ܒ" int="2"/>
         <convert grc="γ" syr="ܓ" int="3"/>
         <convert grc="δ" syr="ܕ" int="4"/>
         <convert grc="ε" syr="ܗ" int="5"/>
         <convert grc="ϛ" syr="ܘ" int="6"/>
         <convert grc="ζ" syr="ܙ" int="7"/>
         <convert grc="η" syr="ܚ" int="8"/>
         <convert grc="θ" syr="ܛ" int="9"/>
         <convert grc="ι" syr="ܝ" int="10"/>
         <convert grc="κ" syr="ܟ" int="20"/>
         <convert grc="λ" syr="ܠ" int="30"/>
         <convert grc="μ" syr="ܡ" int="40"/>
         <convert grc="ν" syr="ܢ" int="50"/>
         <convert grc="ξ" syr="ܣ" int="60"/>
         <convert grc="ο" syr="ܥ" int="70"/>
         <convert grc="π" syr="ܦ" int="80"/>
         <convert grc="ϙ" syr="ܨ" int="90"/>
         <convert grc="ρ" syr="ܩ" int="100"/>
         <convert grc="σ" syr="ܪ" int="200"/>
         <convert grc="τ" syr="ܫ" int="300"/>
         <convert grc="υ" syr="ܬ" int="400"/>
         <convert grc="φ" syr="" int="500"/>
         <convert grc="χ" syr="" int="600"/>
         <convert grc="ψ" syr="" int="700"/>
         <convert grc="ω" syr="" int="800"/>
         <convert grc="ϡ" syr="" int="900"/>
      </key>
   </xsl:variable>

   <xsl:function name="tan:letter-to-number" as="xs:integer*">
      <!-- Input: any sequence of strings that represent alphabetic numerals -->
      <!-- Output: those numerals -->
      <!-- Works only for letter patterns that have been defined; anything else produces null results -->
      <xsl:param name="numerical-letters" as="xs:anyAtomicType*"/>
      <xsl:for-each select="$numerical-letters">
         <xsl:choose>
            <xsl:when test="matches(., concat('^', $arabic-indic-numeral-pattern, '$'))">
               <xsl:copy-of select="tan:ara-to-int(.)"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="this-letter-norm" select="replace(., '[͵ʹ]', '')"/>
               <xsl:variable name="pass1" as="xs:integer*">
                  <xsl:if test="string-length($this-letter-norm) gt 0">
                     <xsl:analyze-string select="$this-letter-norm" regex=".">
                        <xsl:matching-substring>
                           <xsl:variable name="this-letter" select="."/>
                           <xsl:choose>
                              <xsl:when test="matches(., '^\p{IsSyriac}+$')">
                                 <xsl:copy-of
                                    select="xs:integer(($alphabet-numeral-key/*[matches(@syr, $this-letter, 'i')][1]/@int))"
                                 />
                              </xsl:when>
                              <xsl:when test="matches(., '^\p{IsGreek}+$')">
                                 <xsl:copy-of
                                    select="xs:integer(($alphabet-numeral-key/*[matches(@grc, $this-letter, 'i')][1]/@int))"
                                 />
                              </xsl:when>
                           </xsl:choose>
                        </xsl:matching-substring>
                     </xsl:analyze-string>
                  </xsl:if>
               </xsl:variable>
               <xsl:value-of select="sum($pass1)"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:string-to-numerals" as="xs:string*">
      <!-- one-parameter version of the function below -->
      <xsl:param name="string-to-analyze" as="xs:string?"/>
      <xsl:copy-of select="tan:string-to-numerals($string-to-analyze, true(), false())"/>
   </xsl:function>
   <xsl:function name="tan:string-to-numerals" as="xs:string*">
      <!-- Input: a string thought to contain numerals of some type (e.g., Roman); a boolean indicating whether ambiguous letters should be treated as Roman numerals or letter numerals; a boolean indicating whether only numeral matches should be returned -->
      <!-- Output: the string with parts that look like numerals converted to Arabic numerals -->
      <!-- Does not take into account requests for help -->
      <xsl:param name="string-to-analyze" as="xs:string?"/>
      <xsl:param name="ambig-is-roman" as="xs:boolean?"/>
      <xsl:param name="return-only-numerals" as="xs:boolean?"/>
      <!--<xsl:variable name="string-parsed" as="element()*">
         <xsl:analyze-string select="$string-to-analyze" regex="\w+">
            <xsl:matching-substring>
               <tok>
                  <xsl:value-of select="."/>
               </tok>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
               <non-tok>
                  <xsl:value-of select="."/>
               </non-tok>
            </xsl:non-matching-substring>
         </xsl:analyze-string>
      </xsl:variable>-->
      <!--<xsl:variable name="string-analyzed" as="element()*">
         <xsl:apply-templates select="$string-parsed" mode="string-to-numerals">
            <xsl:with-param name="ambig-is-roman" select="($ambig-is-roman, true())[1]"/>
         </xsl:apply-templates>
      </xsl:variable>-->
      <xsl:variable name="string-analyzed"
         select="tan:analyze-numbers-in-string($string-to-analyze, $ambig-is-roman)"/>
      <xsl:choose>
         <xsl:when test="$return-only-numerals">
            <xsl:copy-of select="$string-analyzed/self::tan:tok[@number]"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="string-join($string-analyzed/text(), '')"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:function name="tan:analyze-numbers-in-string" as="element()*">
      <!-- Companion function to the above, this function returns the analysis in element form -->
      <xsl:param name="string-to-analyze" as="xs:string"/>
      <xsl:param name="ambig-is-roman" as="xs:boolean?"/>
      <xsl:variable name="string-parsed" as="element()*">
         <xsl:analyze-string select="$string-to-analyze" regex="\w+">
            <xsl:matching-substring>
               <tok>
                  <xsl:value-of select="."/>
               </tok>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
               <non-tok>
                  <xsl:value-of select="."/>
               </non-tok>
            </xsl:non-matching-substring>
         </xsl:analyze-string>
      </xsl:variable>
      <xsl:apply-templates select="$string-parsed" mode="string-to-numerals">
         <xsl:with-param name="ambig-is-roman" select="($ambig-is-roman, true())[1]"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="tan:tok" mode="string-to-numerals">
      <xsl:param name="ambig-is-roman" as="xs:boolean" select="true()"/>
      <xsl:copy>
         <xsl:choose>
            <xsl:when test=". castable as xs:integer">
               <xsl:attribute name="number" select="$n-type[2]"/>
               <xsl:attribute name="orig" select="."/>
               <xsl:value-of select="xs:integer(.)"/>
            </xsl:when>
            <xsl:when test="matches(., $n-type-pattern[3], 'i')">
               <xsl:attribute name="number" select="$n-type[3]"/>
               <xsl:attribute name="orig" select="."/>
               <xsl:value-of
                  select="concat(replace(., '\D+', ''), $separator-hierarchy-minor, tan:aaa-to-int(replace(., '\d+', '')))"
               />
            </xsl:when>
            <xsl:when test="matches(., $n-type-pattern[1], 'i') and $ambig-is-roman">
               <xsl:attribute name="number" select="$n-type[1]"/>
               <xsl:attribute name="orig" select="."/>
               <xsl:value-of select="tan:rom-to-int(.)"/>
            </xsl:when>
            <xsl:when test="matches(., $n-type-pattern[4], 'i')">
               <xsl:attribute name="number" select="$n-type[4]"/>
               <xsl:attribute name="orig" select="."/>
               <xsl:value-of select="tan:aaa-to-int(.)"/>
            </xsl:when>
            <xsl:when test="matches(., $n-type-pattern[1], 'i')">
               <xsl:attribute name="number" select="$n-type[1]"/>
               <xsl:attribute name="orig" select="."/>
               <xsl:value-of select="tan:rom-to-int(.)"/>
            </xsl:when>
            <xsl:when test="matches(., $n-type-pattern[5], 'i')">
               <xsl:attribute name="number" select="$n-type[5]"/>
               <xsl:attribute name="orig" select="."/>
               <xsl:value-of
                  select="concat(tan:aaa-to-int(replace(., '\d+', '')), $separator-hierarchy-minor, replace(., '\D+', ''))"
               />
            </xsl:when>
            <xsl:when test="matches(., $n-type-pattern[6], 'i')">
               <xsl:attribute name="number" select="$n-type[6]"/>
               <xsl:attribute name="orig" select="."/>
               <xsl:value-of select="tan:letter-to-number(.)"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:attribute name="non-number"/>
               <xsl:value-of select="."/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>
   <xsl:function name="tan:string-to-int" as="xs:integer*">
      <!-- Companion fonction to tan:string-to-numerals() -->
      <!-- Returns only those results that can be evaluated as integers -->
      <xsl:param name="string" as="xs:string?"/>
      <xsl:variable name="pass-1" select="tan:string-to-numerals($string)"/>
      <xsl:for-each select="$pass-1">
         <xsl:if test=". castable as xs:integer">
            <xsl:copy-of select="xs:integer(.)"/>
         </xsl:if>
      </xsl:for-each>
   </xsl:function>


   <!-- FUNCTIONS: DATE, TIME, VERSION -->

   <xsl:function name="tan:dateTime-to-decimal" as="xs:decimal*">
      <!-- Input: any xs:date or xs:dateTime -->
      <!-- Output: decimal between 0 and 1 that acts as a proxy for the date and time. These decimal values can then be sorted and compared. -->
      <!-- Example: (2015-05-10) - > 0.2015051 -->
      <!-- If input is not castable as a date or dateTime, 0 is returned -->
      <xsl:param name="time-or-dateTime" as="item()*"/>
      <xsl:for-each select="$time-or-dateTime">
         <xsl:variable name="utc" select="xs:dayTimeDuration('PT0H')"/>
         <xsl:variable name="dateTime" as="xs:dateTime?">
            <xsl:choose>
               <xsl:when test=". castable as xs:dateTime">
                  <xsl:value-of select="."/>
               </xsl:when>
               <xsl:when test=". castable as xs:date">
                  <xsl:value-of select="fn:dateTime(., xs:time('00:00:00'))"/>
               </xsl:when>
            </xsl:choose>
         </xsl:variable>
         <xsl:variable name="dt-adjusted-as-string"
            select="string(fn:adjust-dateTime-to-timezone($dateTime, $utc))"/>
         <xsl:value-of
            select="
               if (exists($dateTime)) then
                  number(concat('0.', replace(replace($dt-adjusted-as-string, '[-+]\d+:\d+$', ''), '\D+', '')))
               else
                  0"
         />
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:most-recent-dateTime" as="item()?">
      <!-- Input: a series of ISO-compliant date or dateTimes -->
      <!-- Output: the most recent one -->
      <xsl:param name="dateTimes" as="item()*"/>
      <xsl:variable name="decimal-val"
         select="
            for $i in $dateTimes
            return
               tan:dateTime-to-decimal($i)"/>
      <xsl:variable name="most-recent"
         select="
            if (exists($decimal-val)) then
               index-of($decimal-val, max($decimal-val))[1]
            else
               ()"/>
      <xsl:copy-of select="$dateTimes[$most-recent]"/>
   </xsl:function>


   <!-- Functions: sequences, general -->

   <xsl:function name="tan:duplicate-items" as="item()*">
      <!-- Input: any sequence of items -->
      <!-- Output: those items that appear in the sequence more than once -->
      <!-- This function parallels the standard fn:distinct-values() -->
      <xsl:param name="sequence" as="item()*"/>
      <xsl:copy-of select="$sequence[index-of($sequence, .)[2]]"/>
   </xsl:function>

   <xsl:function name="tan:distinct-items" as="item()*">
      <!-- Input: any sequence of items -->
      <!-- Output: Those items that are not deeply equal to any other item in the sequence -->
      <!-- This function is parallel to distinct-values(), but handles non-string input -->
      <xsl:param name="items" as="item()*"/>
      <xsl:copy-of select="$items[1]"/>
      <xsl:for-each select="$items[position() gt 1]">
         <xsl:variable name="this-item" select="."/>
         <xsl:if
            test="
               not(some $i in 1 to position()
                  satisfies deep-equal($this-item, $items[$i]))">
            <xsl:copy-of select="."/>
         </xsl:if>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:collate-sequences" as="xs:string*">
      <!-- This version of the function takes a sequence of elements, each of which contains a sequences of shallow elements with text content -->
      <xsl:param name="elements-with-elements" as="element()*"/>
      <xsl:variable name="diagnostics" select="false()" as="xs:boolean"/>
      <xsl:variable name="input-sorted" as="element()*">
         <xsl:for-each select="$elements-with-elements">
            <xsl:sort select="count(*)" order="descending"/>
            <xsl:choose>
               <xsl:when test="count(*) lt 1">
                  <xsl:message>Input elements without elements will be ignored</xsl:message>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="."/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="first-sequence" as="xs:string*">
         <xsl:for-each select="$input-sorted[1]/*">
            <xsl:value-of select="."/>
         </xsl:for-each>
      </xsl:variable>
      <xsl:if test="$diagnostics">
         <xsl:message select="tan:xml-to-string($input-sorted)"/>
         <xsl:message select="string-join($first-sequence, '; ')"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="count($input-sorted) lt 2">
            <xsl:if test="$diagnostics">
               <xsl:message>Function called with fewer than two sequences</xsl:message>
            </xsl:if>
            <xsl:copy-of select="$first-sequence"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="tan:collate-sequence-loop($input-sorted[position() gt 1], $first-sequence)"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:function name="tan:collate-sequence-loop" as="xs:string*">
      <xsl:param name="elements-with-elements" as="element()*"/>
      <xsl:param name="results-so-far" as="xs:string*"/>
      <xsl:choose>
         <xsl:when test="count($elements-with-elements) lt 1">
            <xsl:copy-of select="$results-so-far"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="next-sequence" as="xs:string*">
               <xsl:for-each select="$elements-with-elements[1]/*">
                  <xsl:value-of select="."/>
               </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="this-collation" select="tan:collate-pair-of-sequences($results-so-far, $next-sequence)"/>
            <xsl:copy-of select="tan:collate-sequence-loop($elements-with-elements[position() gt 1], $this-collation)"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="tan:collate-pair-of-sequences" as="xs:string*">
      <!-- Two-parameter version of the fuller one below, intended for collating pairs of sequences -->
      <xsl:param name="string-sequence-1" as="xs:string*"/>
      <xsl:param name="string-sequence-2" as="xs:string*"/>
      <xsl:copy-of
         select="tan:collate-pair-of-sequences($string-sequence-1, $string-sequence-2, false())"/>
   </xsl:function>

   <xsl:function name="tan:collate-pair-of-sequences" as="xs:string*">
      <!--  -->
      <!-- Input: two sequences of strings -->
      <!-- Output: a collation of the two strings, preserving their order -->
      <xsl:param name="string-sequence-1" as="xs:string*"/>
      <xsl:param name="string-sequence-2" as="xs:string*"/>
      <xsl:param name="exclude-unique" as="xs:boolean"/>
      <xsl:variable name="this-delimiter"
         select="tan:unique-char(($string-sequence-1, $string-sequence-2))"/>
      <xsl:variable name="string-1" select="string-join($string-sequence-1, $this-delimiter)"/>
      <xsl:variable name="string-2" select="string-join($string-sequence-2, $this-delimiter)"/>
      <xsl:variable name="string-diff" select="tan:diff($string-1, $string-2, false(), false(), 0)"/>
      <xsl:variable name="diagnostics" select="false()" as="xs:boolean?"/>
      <xsl:if test="$diagnostics">
         <xsl:message select="$string-1, $string-2, $this-delimiter"/>
         <xsl:message select="$string-diff"/>
      </xsl:if>
      <xsl:variable name="results-1" as="element()">
         <xsl:apply-templates select="$string-diff" mode="collate-sequence-1">
            <xsl:with-param name="delimiter-regex" select="tan:escape($this-delimiter)" tunnel="yes"
            />
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:if test="$diagnostics"><xsl:message select="$results-1"/></xsl:if>
      <xsl:variable name="results-2" as="element()">
         <xsl:apply-templates select="$results-1" mode="collate-sequence-2">
            <xsl:with-param name="delimiter-regex" select="tan:escape($this-delimiter)" tunnel="yes"
            />
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:if test="$diagnostics"><xsl:message select="$results-2"/></xsl:if>
      <xsl:choose>
         <xsl:when test="$exclude-unique">
            <xsl:copy-of select="$results-1/tan:common/text()"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="$results-2/*/text()"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:template match="tan:common" mode="collate-sequence-1">
      <!-- Restrict <common> to only true matches -->
      <xsl:param name="delimiter-regex" as="xs:string" tunnel="yes"/>
      <xsl:variable name="preceding-diffs"
         select="preceding-sibling::*[position() lt 3][self::tan:a or self::tan:b]"/>
      <xsl:variable name="following-diffs"
         select="following-sibling::*[position() lt 3][self::tan:a or self::tan:b]"/>
      <!-- If the preceding differences terminate in the delimiter, or the next differences start with it, then the opening or closing fragment in the <common> should be kept -->
      <xsl:variable name="opening-item-should-be-included"
         select="
            every $i in $preceding-diffs
               satisfies matches($i, concat($delimiter-regex, '$'))"/>
      <xsl:variable name="closing-item-should-be-included"
         select="
            every $i in $following-diffs
               satisfies matches($i, concat('^', $delimiter-regex))"/>
      <xsl:variable name="this-tokenized" select="tokenize(., $delimiter-regex)"/>
      <xsl:for-each select="$this-tokenized">
         <xsl:choose>
            <xsl:when test="string-length(.) lt 1"/>
            <xsl:when
               test="
                  (position() = 1 and not($opening-item-should-be-included)) or
                  (position() = count($this-tokenized) and (count($this-tokenized) gt 1) and not($closing-item-should-be-included))">
               <a>
                  <xsl:value-of select="."/>
                  <!-- We include the delimiter after initial fragments that get moved up, so they don't get conflated with fragments that follow -->
                  <xsl:if test="position() = 1 and count($this-tokenized) gt 1">
                     <xsl:value-of select="$delimiter-regex"/>
                  </xsl:if>
               </a>
               <b>
                  <xsl:value-of select="."/>
                  <xsl:if test="position() = 1 and count($this-tokenized) gt 1">
                     <xsl:value-of select="$delimiter-regex"/>
                  </xsl:if>
               </b>
            </xsl:when>
            <xsl:otherwise>
               <common>
                  <xsl:value-of select="."/>
               </common>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:template>
   <xsl:template match="tan:diff" mode="collate-sequence-2">
      <xsl:param name="delimiter-regex" as="xs:string" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each-group select="*" group-adjacent="local-name() = 'common'">
            <xsl:choose>
               <xsl:when test="current-grouping-key()">
                  <xsl:copy-of select="current-group()"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:for-each-group select="current-group()" group-by="local-name(.)">
                     <xsl:variable name="this-element-name" select="current-grouping-key()"/>
                     <xsl:variable name="this-val" select="string-join(current-group(), '')"/>
                     <xsl:for-each select="tokenize($this-val, $delimiter-regex)">
                        <xsl:element name="{$this-element-name}">
                           <xsl:value-of select="."/>
                        </xsl:element>
                     </xsl:for-each>
                  </xsl:for-each-group>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </xsl:copy>
   </xsl:template>


   <!-- FUNCTIONS: NODES -->

   <xsl:function name="tan:xml-to-string" as="xs:string?">
      <xsl:param name="fragment" as="item()*"/>
      <xsl:value-of select="tan:xml-to-string($fragment, false())"/>
   </xsl:function>
   <xsl:function name="tan:xml-to-string" as="xs:string?">
      <!-- Input: any fragment of XML; boolean indicating whether whitespace nodes should be ignored -->
      <!-- Output: a string representation of the fragment -->
      <!-- This function is used to represent XML fragments in a plain text message, useful in validation reports or in generating guidelines -->
      <xsl:param name="fragment" as="item()*"/>
      <xsl:param name="ignore-whitespace-text-nodes" as="xs:boolean"/>
      <xsl:variable name="results" as="xs:string*">
         <xsl:apply-templates select="$fragment" mode="fragment-to-text">
            <xsl:with-param name="ignore-whitespace-text-nodes"
               select="$ignore-whitespace-text-nodes" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:value-of select="string-join($results, '')"/>
   </xsl:function>
   <xsl:template match="*" mode="fragment-to-text">
      <xsl:text>&lt;</xsl:text>
      <xsl:value-of select="name()"/>
      <xsl:apply-templates select="@*" mode="#current"/>
      <xsl:choose>
         <xsl:when test="exists(node())">
            <xsl:text>></xsl:text>
            <xsl:apply-templates select="node()" mode="#current"/>
            <xsl:text>&lt;/</xsl:text>
            <xsl:value-of select="name()"/>
            <xsl:text>></xsl:text>
         </xsl:when>
         <xsl:otherwise>
            <xsl:text> /></xsl:text>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="@*" mode="fragment-to-text">
      <xsl:text> </xsl:text>
      <xsl:value-of select="name()"/>
      <xsl:text>='</xsl:text>
      <xsl:value-of select="."/>
      <xsl:text>'</xsl:text>
   </xsl:template>
   <xsl:template match="comment()" mode="fragment-to-text">
      <xsl:text>&lt;!--</xsl:text>
      <xsl:value-of select="."/>
      <xsl:text>--></xsl:text>
   </xsl:template>
   <xsl:template match="processing-instruction()" mode="fragment-to-text">
      <xsl:text>&lt;?</xsl:text>
      <xsl:value-of select="."/>
      <xsl:text>?></xsl:text>
   </xsl:template>
   <xsl:template match="text()" mode="fragment-to-text">
      <xsl:param name="ignore-whitespace-text-nodes" tunnel="yes" as="xs:boolean"/>
      <xsl:if test="not($ignore-whitespace-text-nodes) or matches(., '\S')">
         <xsl:value-of select="."/>
      </xsl:if>
   </xsl:template>

   <xsl:function name="tan:trim-long-text" as="item()*">
      <!-- Input: an XML fragment; an integer -->
      <!-- Output: the fragment with text nodes longer than the integer value abbreviated with an ellipsis -->
      <xsl:param name="xml-fragment" as="item()*"/>
      <xsl:param name="too-long" as="xs:integer"/>
      <xsl:variable name="input-as-node" as="element()">
         <node>
            <xsl:copy-of select="$xml-fragment"/>
         </node>
      </xsl:variable>
      <xsl:apply-templates select="$input-as-node/node()" mode="trim-long-text">
         <xsl:with-param name="too-long" select="$too-long" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="text()" mode="trim-long-text">
      <xsl:param name="too-long" as="xs:integer" tunnel="yes"/>
      <xsl:variable name="this-length" select="string-length(.)"/>
      <xsl:choose>
         <xsl:when test="$this-length ge $too-long and $too-long ge 3">
            <xsl:variable name="portion-length" select="($too-long - 1) idiv 2"/>
            <xsl:value-of select="substring(., 1, $portion-length)"/>
            <xsl:text>…</xsl:text>
            <xsl:value-of select="substring(., ($this-length - $portion-length))"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="*" mode="strip-all-attributes-except">
      <xsl:param name="attributes-to-keep" as="xs:string*" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*[name(.) = $attributes-to-keep]"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="*" mode="strip-specific-attributes">
      <xsl:param name="attributes-to-strip" as="xs:string*" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*[not(name(.) = $attributes-to-strip)]"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:copy-of" as="item()*">
      <!-- Input: any document fragment, and an optional integer specifying the depth of copy requested -->
      <!-- Output: a copy of the fragment to the depth specified -->
      <!-- This function depends upon the full version of tan:copy-of-except(); it is particularly useful for diagnostics, e.g., retrieving a long document's root element and its children, without descendants -->
      <xsl:param name="doc-fragment" as="item()*"/>
      <xsl:param name="exclude-elements-beyond-what-depth" as="xs:integer?"/>
      <xsl:copy-of
         select="tan:copy-of-except($doc-fragment, (), (), (), $exclude-elements-beyond-what-depth, ())"
      />
   </xsl:function>
   <xsl:function name="tan:copy-of-except" as="item()*">
      <!-- short version of the full function, below -->
      <xsl:param name="doc-fragment" as="item()*"/>
      <xsl:param name="exclude-elements-named" as="xs:string*"/>
      <xsl:param name="exclude-attributes-named" as="xs:string*"/>
      <xsl:param name="exclude-elements-with-attributes-named" as="xs:string*"/>
      <xsl:copy-of
         select="tan:copy-of-except($doc-fragment, $exclude-elements-named, $exclude-attributes-named, $exclude-elements-with-attributes-named, (), ())"
      />
   </xsl:function>
   <xsl:function name="tan:copy-of-except" as="item()*">
      <!-- Input: any document fragment; sequences of strings specifying names of elements to exclude, names of attributes to exclude, and names of attributes whose parent elements should be excluded; an integer beyond which depth copies should not be made -->
      <!-- Output: the same fragment, altered -->
      <!-- This function was written primarily to service the merge of TAN-A-div sources, where realigned divs could be extracted from their source documents -->
      <xsl:param name="doc-fragment" as="item()*"/>
      <xsl:param name="exclude-elements-named" as="xs:string*"/>
      <xsl:param name="exclude-attributes-named" as="xs:string*"/>
      <xsl:param name="exclude-elements-with-attributes-named" as="xs:string*"/>
      <xsl:param name="exclude-elements-beyond-what-depth" as="xs:integer?"/>
      <xsl:param name="shallow-skip-elements-named" as="xs:string*"/>
      <xsl:apply-templates select="$doc-fragment" mode="copy-of-except">
         <xsl:with-param name="exclude-elements-named" as="xs:string*"
            select="$exclude-elements-named" tunnel="yes"/>
         <xsl:with-param name="exclude-attributes-named" as="xs:string*"
            select="$exclude-attributes-named" tunnel="yes"/>
         <xsl:with-param name="exclude-elements-with-attributes-named" as="xs:string*"
            select="$exclude-elements-with-attributes-named" tunnel="yes"/>
         <xsl:with-param name="exclude-elements-beyond-what-depth"
            select="$exclude-elements-beyond-what-depth" tunnel="yes"/>
         <xsl:with-param name="current-depth" select="0"/>
         <xsl:with-param name="shallow-skip-elements-named" select="$shallow-skip-elements-named"
            tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="copy-of-except">
      <xsl:param name="exclude-elements-named" as="xs:string*" tunnel="yes"/>
      <xsl:param name="exclude-attributes-named" as="xs:string*" tunnel="yes"/>
      <xsl:param name="exclude-elements-with-attributes-named" as="xs:string*" tunnel="yes"/>
      <xsl:param name="exclude-elements-beyond-what-depth" as="xs:integer?" tunnel="yes"/>
      <xsl:param name="shallow-skip-elements-named" as="xs:string*" tunnel="yes"/>
      <xsl:param name="current-depth" as="xs:integer?"/>
      <xsl:choose>
         <xsl:when test="name() = $exclude-elements-named"/>
         <xsl:when test="name() = $shallow-skip-elements-named">
            <xsl:apply-templates mode="#current">
               <xsl:with-param name="current-depth"
                  select="
                     if (exists($current-depth)) then
                        $current-depth + 1
                     else
                        ()"
               />
            </xsl:apply-templates>
         </xsl:when>
         <xsl:when
            test="
               not(some $i in @*
                  satisfies name($i) = $exclude-elements-with-attributes-named)
               and not($current-depth ge $exclude-elements-beyond-what-depth)">
            <xsl:copy>
               <xsl:copy-of select="@*[not(name() = $exclude-attributes-named)]"/>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="current-depth"
                     select="
                        if (exists($current-depth)) then
                           $current-depth + 1
                        else
                           ()"
                  />
               </xsl:apply-templates>
            </xsl:copy>
         </xsl:when>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="*" mode="strip-duplicate-children-by-attribute-value">
      <xsl:param name="attribute-to-check" as="xs:string"/>
      <xsl:param name="keep-last-duplicate" as="xs:boolean"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each-group select="*"
            group-by="
               if (exists(@*[name(.) = $attribute-to-check])) then
                  @*[name(.) = $attribute-to-check]
               else
                  generate-id()">
            <xsl:choose>
               <xsl:when
                  test="(string-length(current-grouping-key()) gt 0) and (count(current-group()) gt 1)">
                  <xsl:copy-of
                     select="
                        current-group()[if ($keep-last-duplicate) then
                           last()
                        else
                           1]"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="current-group()"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:group-elements-by-shared-node-values" as="element()*">
      <!-- One-parameter version of the fuller one below.  -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:copy-of select="tan:group-elements-by-shared-node-values($elements-to-group, ())"/>
   </xsl:function>
   <xsl:function name="tan:group-elements-by-shared-node-values" as="element()*">
      <!-- Input: a sequence of elements; an optional string representing the name of children in the elements -->
      <!-- Output: the same elements, but grouped in <group> according to whether the text contents of the child elements specified are equal -->
      <!-- Each <group> will have an @n stipulating the position of the first element put in the group. That way the results can be sorted in order of their original elements -->
      <!-- Transitivity is assumed. If suppose elements X, Y, and Z have children values A and B; B and C; and C and D, respectively. All three elements will be grouped, even though Y and Z do not share children values directly.  -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:param name="regex-of-names-of-nodes-to-group-by" as="xs:string?"/>
      <xsl:copy-of
         select="tan:group-elements-by-shared-node-values-loop($elements-to-group, $regex-of-names-of-nodes-to-group-by, ())"
      />
   </xsl:function>
   <xsl:function name="tan:group-elements-by-shared-node-values-loop" as="element()*">
      <!-- Supporting loop function of the one above. -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:param name="regex-of-names-of-nodes-to-group-by" as="xs:string?"/>
      <xsl:param name="groups-so-far" as="element()*"/>
      <xsl:variable name="group-by-all-children" as="xs:boolean"
         select="string-length($regex-of-names-of-nodes-to-group-by) lt 1 or $regex-of-names-of-nodes-to-group-by = '*'"/>
      <xsl:variable name="this-element-to-group" select="$elements-to-group[1]"/>
      <xsl:choose>
         <xsl:when test="not(exists($this-element-to-group))">
            <xsl:for-each select="$groups-so-far">
               <xsl:sort select="xs:integer(@n)"/>
               <xsl:copy-of select="."/>
            </xsl:for-each>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="grouping-key"
               select="
                  $this-element-to-group/node()[if ($group-by-all-children) then
                     true()
                  else
                     matches(name(), $regex-of-names-of-nodes-to-group-by)]"/>
            <!-- The next variables look for nodes with the target names, and look for deep matches or shallow matches -->
            <xsl:variable name="matching-groups"
               select="
                  $groups-so-far[*/node()[if ($group-by-all-children) then
                     true()
                  else
                     matches(name(), $regex-of-names-of-nodes-to-group-by) and (. = $grouping-key or string-join(text(), '') = string-join($grouping-key/text(), ''))]]"/>
            <xsl:variable name="non-matching-groups"
               select="
                  $groups-so-far[not(*/node()[if ($group-by-all-children) then
                     true()
                  else
                     matches(name(), $regex-of-names-of-nodes-to-group-by) and (. = $grouping-key or string-join(text(), '') = string-join($grouping-key/text(), ''))])]"/>
            <xsl:variable name="this-group-n"
               select="($matching-groups/@n, count($groups-so-far) + 1)[1]"/>
            <xsl:variable name="new-groups" as="element()*">
               <xsl:copy-of select="$non-matching-groups"/>
               <group grouping-key="{$regex-of-names-of-nodes-to-group-by}" n="{$this-group-n}">
                  <xsl:copy-of select="$matching-groups/*"/>
                  <xsl:copy-of select="$this-element-to-group"/>
               </group>
            </xsl:variable>
            <xsl:copy-of
               select="tan:group-elements-by-shared-node-values-loop($elements-to-group[position() gt 1], $regex-of-names-of-nodes-to-group-by, $new-groups)"
            />
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="tan:pluck" as="item()*">
      <!-- Input: any document fragment or element; a number indicating a level in the hierarchy of the fragment; a boolean indicating whether leaf elements that fall short of the previous parameter should be included -->
      <!-- Output: the fragment of the tree that is beyond the point indicated, and perhaps (depending upon the third parameter) with other leafs that are not quite at that level -->
      <!-- This function was written primarily to serve tan:convert-ref-to-div-fragment(), to get a slice of divs that correspond to a range, without the ancestry of those divs -->
      <xsl:param name="fragment" as="item()*"/>
      <xsl:param name="pluck-beyond-level" as="xs:integer"/>
      <xsl:param name="keep-short-branch-leaves" as="xs:boolean"/>
      <xsl:apply-templates select="$fragment" mode="pluck">
         <xsl:with-param name="prune-above-level" select="$pluck-beyond-level" tunnel="yes"/>
         <xsl:with-param name="keep-short-branch-leaves" select="$keep-short-branch-leaves"
            tunnel="yes"/>
         <xsl:with-param name="currently-at" select="1"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="pluck">
      <xsl:param name="currently-at" as="xs:integer"/>
      <xsl:param name="prune-above-level" as="xs:integer" tunnel="yes"/>
      <xsl:param name="keep-short-branch-leaves" as="xs:boolean" tunnel="yes"/>
      <xsl:choose>
         <xsl:when test="$prune-above-level = $currently-at">
            <xsl:copy-of select="."/>
         </xsl:when>
         <xsl:when test="not(exists(*))">
            <xsl:if test="$keep-short-branch-leaves = true()">
               <xsl:copy-of select="."/>
            </xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="#current">
               <xsl:with-param name="currently-at" select="$currently-at + 1"/>
            </xsl:apply-templates>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="text()" mode="pluck">
      <xsl:if test="matches(., '\S')">
         <xsl:value-of select="."/>
      </xsl:if>
   </xsl:template>
   <xsl:template match="comment() | processing-instruction()" mode="pluck"/>

   <xsl:function name="tan:shallow-copy" as="element()*">
      <!-- one-parameter version of the fuller one, below -->
      <xsl:param name="elements" as="element()*"/>
      <xsl:copy-of select="tan:shallow-copy($elements, true())"/>
   </xsl:function>
   <xsl:function name="tan:shallow-copy" as="element()*">
      <!-- Input: any document fragment; boolean indicating whether attributes should be kept -->
      <!-- Output: a shallow copy of the fragment, perhaps with attributes -->
      <xsl:param name="elements" as="element()*"/>
      <xsl:param name="keep-attributes" as="xs:boolean"/>
      <xsl:for-each select="$elements">
         <xsl:copy>
            <xsl:if test="$keep-attributes = true()">
               <xsl:copy-of select="@*"/>
            </xsl:if>
         </xsl:copy>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:value-of" as="xs:string?">
      <!-- Input: any sequence of items -->
      <!-- Output: the value of each item -->
      <!-- Proxy for <xsl:value-of/>. Useful as a function in XPath expressions -->
      <xsl:param name="items" as="item()*"/>
      <xsl:value-of select="$items"/>
   </xsl:function>


   <!-- FUNCTIONS: SEQUENCES, TAN-SPECIFIC (e.g., @ref, @pos, @chars, ...) -->

   <xsl:function name="tan:normalize-sequence" as="xs:string?">
      <!-- Input: any string representing a sequence; the name of the attribute whence the value, i.e., @ref, @pos, @chars, @n -->
      <!-- Output: the string, normalized such that items may be found by tokenizing on ' , ' and parts of ranges on ' - ' -->
      <!-- Note, this function does nothing to analyze or convert types of numerals, and all help requests are left intact -->
      <!-- Here we're targeting tan:analyze-elements-with-numeral-attributes() template mode arabic-numerals, prelude to tan:sequence-expand(), tan:normalize-refs() -->
      <xsl:param name="sequence-string" as="xs:string?"/>
      <xsl:param name="attribute-name" as="xs:string"/>
      <xsl:choose>
         <xsl:when test="$attribute-name = ('ref', 'new')">
            <!-- atomic items here are separated by commas and hyphens, and not spaces -->
            <xsl:value-of
               select="lower-case(normalize-space(replace($sequence-string, '([-,])', ' $1 ')))"/>
         </xsl:when>
         <xsl:when test="$attribute-name = ('n')">
            <!-- atomic items here are separated by spaces, hyphens, and perhaps by a comma -->
            <xsl:variable name="space-and-comma-to-comma"
               select="replace($sequence-string, '\s+|\s*,\s*', ' , ')"/>
            <xsl:value-of
               select="normalize-space(replace($space-and-comma-to-comma, '(\d+)\s*-\s*(\d+)', '$1 - $2'))"
            />
         </xsl:when>
         <xsl:when test="$attribute-name = ('object')">
            <!-- atomic items here are separated purely by spaces, nothing else -->
            <xsl:value-of select="replace(normalize-space($sequence-string), ' ', ' , ')"/>
         </xsl:when>
         <xsl:when test="$attribute-name = ('affects-element', 'div-type')">
            <!-- atomic items here are separated by spaces, and perhaps by a comma, but not hyphens -->
            <xsl:value-of select="replace(normalize-space($sequence-string), ',? |, ?', ' , ')"/>
         </xsl:when>
         <xsl:otherwise>
            <!-- atomic items here are numbers separated by commas and hyphens and perhaps with the keywords "last" etc. -->
            <xsl:variable name="norm-last"
               select="replace($sequence-string, '(last|max|all)[ ,]+', 'last , ')"/>
            <xsl:variable name="norm-punct" select="replace($norm-last, '(\d)\s*([,-])', '$1 $2 ')"/>
            <xsl:variable name="space-to-comma"
               select="replace($norm-punct, '(\d)\s+(\d)', '$1 , $2')"/>
            <xsl:value-of select="normalize-space($space-to-comma)"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="tan:analyze-sequence" as="element()">
      <!-- two-parameter version of the fuller function below -->
      <xsl:param name="sequence-string" as="xs:string"/>
      <xsl:param name="name-of-attribute" as="xs:string?"/>
      <xsl:copy-of select="tan:analyze-sequence($sequence-string, $name-of-attribute, false())"/>
   </xsl:function>
   <xsl:function name="tan:analyze-sequence" as="element()">
      <!-- Input: any value of a sequence; a string of the name of the attribute for the sequence (default 'ref'); a boolean indicating whether ranges should be expanded -->
      <!-- Output: <analysis> with children elements that have the name of the second parameter (with @attr and an empty value inserted); those children are grouped by <range> if items are detected to be part of a range. -->
      <!-- If a request for help is detected, the flag will be removed and @help will be inserted at the appropriate place. -->
      <!-- If ranges are requested to be expanded, it is expected to apply only to integers, and will not operate on values of 'max' or 'last' -->
      <!-- This function normalizes strings ahead of time; no need to run that function beforehand -->
      <xsl:param name="sequence-string" as="xs:string"/>
      <xsl:param name="name-of-attribute" as="xs:string?"/>
      <xsl:param name="expand-ranges" as="xs:boolean"/>
      <xsl:variable name="attribute-name"
         select="
            if (string-length($name-of-attribute) lt 1) then
               'ref'
            else
               $name-of-attribute"/>
      <xsl:variable name="string-normalized"
         select="tan:normalize-sequence($sequence-string, $attribute-name)"/>
      <xsl:variable name="pass1" as="element()*">
         <xsl:variable name="these-item-groups" select="tokenize($string-normalized, ' , ')"/>
         <xsl:for-each select="$these-item-groups">
            <xsl:variable name="this-group" select="position()"/>
            <xsl:variable name="these-items" select="tokenize(., ' - ')"/>
            <xsl:for-each select="$these-items">
               <xsl:element name="{$attribute-name}">
                  <xsl:attribute name="attr"/>
                  <xsl:attribute name="pos" select="$this-group"/>
                  <xsl:if test="count($these-items) gt 1">
                     <xsl:attribute name="pos2" select="position()"/>
                  </xsl:if>
                  <xsl:variable name="this-val-checked" select="tan:help-extracted(.)"/>
                  <xsl:variable name="this-val" select="$this-val-checked/text()"/>
                  <xsl:copy-of select="$this-val-checked/@help"/>
                  <xsl:choose>
                     <xsl:when test="$attribute-name = ('ref', 'new')">
                        <!-- A reference returns both the full normalized form and the individual @n's parsed. -->
                        <!-- We avoid adding the text to the base node until after individual <n> values are calculated -->
                        <xsl:variable name="these-ns" select="tokenize(., '[^#\w\?_]+')"/>
                        <!-- we exclude from ns the hash, which is used to separate adjoining numbers, e.g., 1#2 representing 1b -->
                        <xsl:for-each select="$these-ns">
                           <xsl:variable name="this-val-checked" select="tan:help-extracted(.)"/>
                           <xsl:variable name="this-val" select="$this-val-checked/text()"/>
                           <n>
                              <xsl:copy-of select="$this-val-checked/@help"/>
                              <xsl:value-of select="$this-val"/>
                           </n>
                        </xsl:for-each>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:value-of select="$this-val"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:element>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="pass2" as="element()*">
         <xsl:choose>
            <xsl:when test="$attribute-name = ('ref', 'new')">
               <xsl:copy-of select="tan:analyze-ref-loop($pass1, (), ())"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$pass1"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <analysis>
         <xsl:for-each-group select="$pass2" group-adjacent="@pos">
            <xsl:variable name="elements-expanded-for-range" as="element()*">
               <xsl:choose>
                  <xsl:when test="count(current-group()) = 1">
                     <xsl:sequence select="current-group()"/>
                  </xsl:when>
                  <xsl:when test="$expand-ranges = true()">
                     <xsl:variable name="is-complex" select="exists(current-group()/*)"/>
                     <xsl:variable name="this-first" select="current-group()[1]"/>
                     <xsl:variable name="this-last" select="current-group()[last()]"/>
                     <xsl:variable name="element-name" select="name(current-group()[1])"/>
                     <xsl:variable name="first-value"
                        select="
                           if ($is-complex) then
                              $this-first/*[last()]
                           else
                              $this-first"/>
                     <xsl:variable name="last-value"
                        select="
                           if ($is-complex) then
                              $this-last/*[last()]
                           else
                              $this-last"/>
                     <xsl:variable name="this-sequence-expanded"
                        select="tan:expand-numerical-sequence(concat($first-value, ' - ', $last-value), xs:integer($last-value))"/>
                     <xsl:variable name="sequence-errors"
                        select="tan:sequence-error($this-sequence-expanded)"/>
                     <xsl:variable name="ref-range-errors" as="element()*">
                        <xsl:if test="$is-complex">
                           <xsl:variable name="n-count" select="count($this-first/*)"/>
                           <xsl:if test="$n-count gt 1">
                              <xsl:variable name="errant-n-pos"
                                 select="
                                    for $i in (1 to $n-count - 1)
                                    return
                                       if ($this-first/*[$i] = $this-last/*[$i]) then
                                          ()
                                       else
                                          $i"/>
                              <xsl:if test="exists($errant-n-pos)">
                                 <xsl:copy-of
                                    select="tan:error('seq05', 'only the leafmost level of the hierarchy should differ')"
                                 />
                              </xsl:if>
                           </xsl:if>
                        </xsl:if>
                     </xsl:variable>
                     <xsl:variable name="all-errors" select="$sequence-errors, $ref-range-errors"/>
                     <xsl:choose>
                        <xsl:when test="exists($all-errors)">
                           <xsl:copy-of select="$all-errors"/>
                           <xsl:copy-of select="current-group()"/>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:copy-of select="$this-first"/>
                           <xsl:for-each
                              select="$this-sequence-expanded[position() gt 1 and position() lt last()]">
                              <xsl:element name="{$element-name}">
                                 <xsl:attribute name="attr"/>
                                 <xsl:attribute name="guess"/>
                                 <xsl:choose>
                                    <xsl:when test="$is-complex">
                                       <xsl:variable name="this-context"
                                          select="$this-first/*[position() lt last()]"/>
                                       <xsl:value-of
                                          select="string-join(($this-context, string(.)), $separator-hierarchy)"/>
                                       <xsl:copy-of select="$this-context"/>
                                       <xsl:element name="{name($this-first/*[1])}">
                                          <xsl:value-of select="."/>
                                       </xsl:element>
                                    </xsl:when>
                                    <xsl:otherwise>
                                       <xsl:value-of select="."/>
                                    </xsl:otherwise>
                                 </xsl:choose>
                              </xsl:element>
                           </xsl:for-each>
                           <xsl:copy-of select="current-group()[position() gt 1]"/>
                        </xsl:otherwise>
                     </xsl:choose>

                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:sequence select="current-group()"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>
            <xsl:choose>
               <xsl:when test="count(current-group()) = 1">
                  <xsl:copy-of select="$elements-expanded-for-range"/>
               </xsl:when>
               <xsl:otherwise>
                  <range>
                     <xsl:if test="count(current-group()) ne 2">
                        <xsl:copy-of select="tan:error('seq04')"/>
                     </xsl:if>
                     <xsl:copy-of select="$elements-expanded-for-range"/>
                  </range>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </analysis>
   </xsl:function>
   <xsl:function name="tan:analyze-ref-loop" as="element()*">
      <!-- Input: elements from tan:analyze-sequence() that should be evaluated as a ref -->
      <!-- Output: the likely resolution of those refs -->
      <xsl:param name="elements-to-process" as="element()*"/>
      <xsl:param name="number-of-ns-in-last-item-processed" as="xs:integer?"/>
      <xsl:param name="current-contextual-ref" as="element()?"/>
      <xsl:variable name="this-element-to-process" select="$elements-to-process[1]"/>
      <xsl:variable name="number-of-ns" select="count($this-element-to-process/tan:n)"/>
      <xsl:variable name="number-of-contextual-ns" select="count($current-contextual-ref/tan:n)"/>
      <xsl:choose>
         <xsl:when test="not(exists($this-element-to-process))"/>
         <xsl:otherwise>
            <xsl:choose>
               <xsl:when
                  test="$number-of-ns gt $number-of-ns-in-last-item-processed or $number-of-ns ge $number-of-contextual-ns or not(exists($current-contextual-ref))">
                  <!-- e.g., ... 1, *2 1* ... -->
                  <xsl:element name="{name($this-element-to-process)}">
                     <xsl:copy-of select="$this-element-to-process/@*"/>
                     <xsl:value-of
                        select="string-join($this-element-to-process/*, $separator-hierarchy)"/>
                     <xsl:copy-of select="$this-element-to-process/*"/>
                  </xsl:element>
                  <xsl:copy-of
                     select="tan:analyze-ref-loop($elements-to-process[position() gt 1], $number-of-ns, $this-element-to-process)"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <xsl:variable name="new-children" as="element()*"
                     select="$current-contextual-ref/*[position() le ($number-of-contextual-ns - $number-of-ns)], $this-element-to-process/*"/>
                  <xsl:element name="{name($this-element-to-process)}">
                     <xsl:copy-of select="$this-element-to-process/@*"/>
                     <xsl:value-of select="string-join($new-children, $separator-hierarchy)"/>
                     <xsl:copy-of select="$new-children"/>
                  </xsl:element>
                  <xsl:copy-of
                     select="tan:analyze-ref-loop($elements-to-process[position() gt 1], $number-of-ns, $current-contextual-ref)"
                  />
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="tan:expand-pos-or-chars" as="xs:integer*">
      <!-- Input: any elements that are <pos>, <chars>, or <range>s; an integer representing what 'max' means -->
      <!-- Output: the elements converted to integers they represent -->
      <!-- Because the results are normally positive integers, the following should be treated as error codes:
            0 = value that falls below 1
            -1 = value that cannot be converted to an integer
            -2 = ranges that call for negative steps, e.g., '4 - 2' -->
      <xsl:param name="elements" as="element()*"/>
      <xsl:param name="max" as="xs:integer?"/>
      <xsl:for-each select="$elements">
         <xsl:variable name="elements-to-analyze"
            select="
               if (self::tan:range) then
                  (tan:pos, tan:chars)[position() = (1, last())]
               else
                  ."
            as="element()*"/>
         <xsl:variable name="ints-pass1" as="xs:integer*">
            <xsl:for-each select="$elements-to-analyze">
               <xsl:variable name="pass1a" as="xs:integer*">
                  <xsl:analyze-string select="." regex="(max|all|last)-?">
                     <xsl:matching-substring>
                        <xsl:copy-of select="$max"/>
                     </xsl:matching-substring>
                     <xsl:non-matching-substring>
                        <xsl:choose>
                           <xsl:when test=". castable as xs:integer">
                              <xsl:copy-of select="xs:integer(.)"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:copy-of select="-1"/>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:non-matching-substring>
                  </xsl:analyze-string>
               </xsl:variable>
               <xsl:copy-of
                  select="
                     if ($pass1a[2] = -1) then
                        -1
                     else
                        $pass1a[1] - ($pass1a[2], 0)[1]"
               />
            </xsl:for-each>
         </xsl:variable>
         <xsl:choose>
            <xsl:when
               test="
                  some $i in $ints-pass1
                     satisfies $i = -1">
               <xsl:copy-of select="-1"/>
            </xsl:when>
            <xsl:when
               test="
                  some $i in $ints-pass1
                     satisfies $i lt 1">
               <xsl:copy-of select="0"/>
            </xsl:when>
            <xsl:when test="count($ints-pass1) lt 2">
               <xsl:copy-of select="$ints-pass1"/>
            </xsl:when>
            <xsl:when test="$ints-pass1[2] le $ints-pass1[1]">
               <xsl:copy-of select="-2"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="$ints-pass1[1] to $ints-pass1[2]"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:expand-numerical-sequence" as="xs:integer*">
      <!-- Input: a string representing a TAN selector (used by @pos, @char), and an integer defining the value of 'last' -->
      <!-- Output: a sequence of numbers representing the positions selected, unsorted, and retaining duplicate values.
            Example: ("2 - 4, last-5 - last, 36", 50) -> (2, 3, 4, 45, 46, 47, 48, 49, 50, 36)
            Errors will be flagged as follows:
            0 = value that falls below 1
            -1 = value that surpasses the value of $max
            -2 = ranges that call for negative steps, e.g., '4 - 2' -->
      <xsl:param name="selector" as="xs:string?"/>
      <xsl:param name="max" as="xs:integer?"/>
      <!-- first normalize syntax -->
      <xsl:variable name="pass-1" select="tan:normalize-sequence($selector, 'pos')"/>
      <xsl:variable name="pass-2" as="xs:string*">
         <xsl:analyze-string select="$pass-1" regex="(last|max)(-\d+)?">
            <xsl:matching-substring>
               <xsl:variable name="second-numeral" select="replace(., '\D+', '')"/>
               <xsl:variable name="second-number"
                  select="
                     if (string-length($second-numeral) gt 0) then
                        number($second-numeral)
                     else
                        0"/>
               <xsl:value-of select="string(($max - $second-number))"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
               <xsl:value-of select="."/>
            </xsl:non-matching-substring>
         </xsl:analyze-string>
      </xsl:variable>
      <xsl:variable name="item" select="tokenize(string-join($pass-2, ''), ' ?, +')"/>
      <xsl:for-each select="$item">
         <xsl:variable name="range"
            select="
               for $i in tokenize(., ' - ')
               return
                  xs:integer($i)"/>
         <xsl:choose>
            <xsl:when test="$range[1] lt 1 or $range[2] lt 1">
               <xsl:copy-of select="0"/>
            </xsl:when>
            <xsl:when test="$range[1] gt $max or $range[2] gt $max">
               <xsl:copy-of select="-1"/>
            </xsl:when>
            <xsl:when test="$range[1] ge $range[2]">
               <xsl:copy-of select="-2"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="$range[1] to $range[last()]"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:sequence-error" as="element()*">
      <xsl:param name="results-of-sequence-expand" as="xs:integer*"/>
      <xsl:copy-of select="tan:sequence-error($results-of-sequence-expand, ())"/>
   </xsl:function>
   <xsl:function name="tan:sequence-error" as="element()*">
      <!-- Input: any results of the function tan:sequence-expand() -->
      <!-- Output: error nodes, if any -->
      <xsl:param name="results-of-sequence-expand" as="xs:integer*"/>
      <xsl:param name="message" as="xs:string?"/>
      <xsl:for-each select="$results-of-sequence-expand[. lt 1]">
         <xsl:if test=". = 0">
            <xsl:copy-of select="tan:error('seq01', $message)"/>
         </xsl:if>
         <xsl:if test=". = -1">
            <xsl:copy-of select="tan:error('seq02', $message)"/>
         </xsl:if>
         <xsl:if test=". = -2">
            <xsl:copy-of select="tan:error('seq03', $message)"/>
         </xsl:if>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:sequence-collapse" as="xs:string?">
      <!-- Input: a sequence of integers -->
      <!-- Output: a string that puts them in a TAN-like compact string -->
      <xsl:param name="integers" as="xs:integer*"/>
      <xsl:variable name="pass1" as="xs:integer*">
         <xsl:for-each select="$integers">
            <xsl:sort/>
            <xsl:copy-of select="."/>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="pass2" as="element()*">
         <xsl:for-each select="$pass1">
            <xsl:variable name="pos" select="position()"/>
            <xsl:variable name="prev" select="($pass1[$pos - 1], 0)[1]"/>
            <item val="{.}" diff-with-prev="{. - $prev}"/>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="pass3" as="xs:string*">
         <xsl:for-each-group select="$pass2"
            group-starting-with="*[xs:integer(@diff-with-prev) gt 1]">
            <xsl:choose>
               <xsl:when test="count(current-group()) gt 1">
                  <xsl:value-of
                     select="concat(current-group()[1]/@val, '-', current-group()[last()]/@val)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="current-group()/@val"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:value-of select="string-join($pass3, ', ')"/>
   </xsl:function>


   <!-- FUNCTIONS: ACCESSORS AND MANIPULATION OF URIS -->

   <xsl:function name="tan:cfn" as="xs:string*">
      <!-- Input: any items -->
      <!-- Output: the Current File Name, without extension, of the host document node of each item -->
      <xsl:param name="item" as="item()*"/>
      <xsl:for-each select="$item">
         <xsl:value-of select="replace(xs:string(tan:base-uri(.)), '.+/(.+)\.\w+$', '$1')"/>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:uri-directory" as="xs:string*">
      <!-- Input: any URIs, as strings -->
      <!-- Output: the file path -->
      <!-- NB, this function does not assume any URIs have been resolved -->
      <xsl:param name="uris" as="xs:string*"/>
      <xsl:for-each select="$uris">
         <xsl:value-of select="replace(., '[^/]+$', '')"/>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:base-uri" as="xs:anyURI?">
      <!-- Input: any node -->
      <!-- Output: the base uri of the node's document -->
      <!-- NB, this function differs from fn:base-uri in that it first looks for a @base-uri stamped at the document node. This is important because many TAN documents will be transformed, bound to variables, and so divorced from an original context dectable only through @base-uri. -->
      <xsl:param name="any-node" as="node()?"/>
      <xsl:copy-of select="(root($any-node)/*/@base-uri, base-uri($any-node))[1]"/>
   </xsl:function>
   <xsl:function name="tan:uri-relative-to" as="xs:string?">
      <!-- Input: two strings representing URIs -->
      <!-- Output: the first string resolved relative to the second string -->
      <!-- This function looks for common paths within two absolute URIs and tries to convert the first URI as a relative path -->
      <xsl:param name="uri-to-revise" as="xs:string?"/>
      <xsl:param name="uri-to-revise-against" as="xs:string?"/>
      <xsl:variable name="uri-a-resolved" select="resolve-uri($uri-to-revise)"/>
      <xsl:variable name="uri-b-resolved" select="resolve-uri($uri-to-revise-against)"/>
      <xsl:variable name="path-a" as="element()">
         <path-a>
            <xsl:if test="string-length($uri-a-resolved) gt 0">
               <xsl:analyze-string select="$uri-a-resolved" regex="/">
                  <xsl:non-matching-substring>
                     <step>
                        <xsl:value-of select="."/>
                     </step>
                  </xsl:non-matching-substring>
               </xsl:analyze-string>
            </xsl:if>
         </path-a>
      </xsl:variable>
      <xsl:variable name="path-b" as="element()">
         <path-b>
            <xsl:if test="string-length($uri-b-resolved) gt 0">
               <xsl:analyze-string select="$uri-b-resolved" regex="/">
                  <xsl:non-matching-substring>
                     <step>
                        <xsl:value-of select="."/>
                     </step>
                  </xsl:non-matching-substring>
               </xsl:analyze-string>
            </xsl:if>
         </path-b>
      </xsl:variable>
      <xsl:variable name="path-a-steps" select="count($path-a/tan:step)"/>
      <xsl:variable name="last-common-step"
         select="
            (for $i in (1 to $path-a-steps)
            return
               if ($path-a/tan:step[$i] = $path-b/tan:step[$i]) then
                  ()
               else
                  $i)[1] - 1"/>
      <xsl:variable name="new-path-a" as="element()">
         <path-a>
            <xsl:for-each
               select="$path-b/(tan:step[position() gt $last-common-step] except tan:step[last()])">
               <step>..</step>
            </xsl:for-each>
            <xsl:copy-of select="$path-a/tan:step[position() gt $last-common-step]"/>
         </path-a>
      </xsl:variable>
      <xsl:choose>
         <xsl:when test="matches($uri-to-revise, '^https?://')">
            <xsl:value-of select="$uri-to-revise"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="string-join($new-path-a/tan:step, '/')"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:function name="tan:catalog-uris" as="xs:string*">
      <!-- Input: a node from an XML file -->
      <!-- Output: URLs for locally available TAN catalog files, beginning with the immediate subdirectory and proceeding rootward -->
      <xsl:param name="input-node" as="node()?"/>
      <xsl:variable name="this-uri" select="tan:base-uri($input-node)"/>
      <xsl:variable name="doc-uri-steps" select="tokenize(string($this-uri), '/')"/>
      <xsl:for-each select="2 to count($doc-uri-steps)">
         <xsl:sort order="descending"/>
         <xsl:variable name="this-pos" select="."/>
         <xsl:variable name="this-dir-to-check"
            select="string-join($doc-uri-steps[position() le $this-pos], '/')"/>
         <xsl:variable name="this-uri-to-check"
            select="concat($this-dir-to-check, '/catalog.tan.xml')"/>
         <xsl:if test="doc-available($this-uri-to-check)">
            <xsl:value-of select="$this-uri-to-check"/>
         </xsl:if>
      </xsl:for-each>

   </xsl:function>
   <xsl:function name="tan:catalogs" as="document-node()*">
      <!-- Input: a node from an XML file -->
      <!-- Output: the TAN catalog documents available, beginning with the most local path and proceeding rootward -->
      <xsl:param name="input-node" as="node()?"/>
      <xsl:param name="strip-bad-hrefs" as="xs:boolean"/>
      <xsl:variable name="these-uris" select="tan:catalog-uris($input-node)"/>
      <xsl:for-each select="$these-uris">
         <xsl:choose>
            <xsl:when test="$strip-bad-hrefs">
               <xsl:variable name="this-uri" select="."/>
               <xsl:variable name="this-doc" select="doc(.)"/>
               <xsl:variable name="these-hrefs" select="$this-doc//@href"/>
               <xsl:variable name="doc-check"
                  select="
                     for $i in $these-hrefs
                     return
                        doc-available(resolve-uri($i, $this-uri))"/>
               <xsl:choose>
                  <xsl:when test="$doc-check = false()">
                     <xsl:variable name="bad-href-pos" select="index-of($doc-check, false())"/>
                     <xsl:variable name="bad-hrefs"
                        select="$these-hrefs[position() = $bad-href-pos]"/>
                     <xsl:message
                        select="concat('catalog at ', $this-uri, ' has faulty @hrefs: ', string-join($bad-hrefs, ', '))"/>
                     <xsl:apply-templates select="$this-doc" mode="cut-faulty-hrefs">
                        <xsl:with-param name="base-uri" select="$this-uri" tunnel="yes"/>
                        <xsl:with-param name="bad-hrefs" select="$bad-hrefs" tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:sequence select="$this-doc"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="doc(.)"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>
   <xsl:template match="/collection" mode="cut-faulty-hrefs">
      <xsl:param name="bad-hrefs" as="xs:string*" tunnel="yes"/>
      <xsl:param name="base-uri" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="base-uri" select="$base-uri"/>
         <xsl:copy-of
            select="tan:error('cat01', concat('In catalog file ', $base-uri, ' no document available at ', string-join($bad-hrefs, ', ')))"/>
         <xsl:apply-templates select="*[not(@href = $bad-hrefs)]" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="doc" mode="cut-faulty-hrefs">
      <xsl:param name="base-uri" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="href" select="resolve-uri(@href, $base-uri)"/>
      </xsl:copy>
   </xsl:template>


   <xsl:function name="tan:collection" as="document-node()*">
      <!-- Input: one or more catalog.tan.xml files; filtering parameters -->
      <!-- Output: documents that are available -->
      <xsl:param name="catalog-docs" as="document-node()*"/>
      <xsl:param name="root-names" as="xs:string*"/>
      <xsl:param name="id-matches" as="xs:string?"/>
      <xsl:param name="href-matches" as="xs:string?"/>
      <xsl:for-each select="$catalog-docs">
         <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
         <xsl:for-each select="collection/doc">
            <xsl:variable name="root-test" select="count($root-names) lt 1 or @root = $root-names"/>
            <xsl:variable name="id-test"
               select="
                  if (string-length($id-matches) gt 0) then
                     matches(@id, $id-matches)
                  else
                     true()"/>
            <xsl:variable name="href-test"
               select="
                  if (string-length($href-matches) gt 0) then
                     matches(@href, $href-matches)
                  else
                     true()"/>
            <xsl:if test="$root-test and $id-test and $href-test">
               <xsl:variable name="this-uri" select="resolve-uri(@href, string($this-base-uri))"/>
               <xsl:choose>
                  <xsl:when test="doc-available($this-uri)">
                     <xsl:sequence select="doc($this-uri)"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:document>
                        <xsl:copy-of
                           select="tan:error('cat01', concat('In catalog file ', $this-base-uri, ' no document available at ', @href))"
                        />
                     </xsl:document>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:if>
         </xsl:for-each>
      </xsl:for-each>
   </xsl:function>


   <!-- FUNCTIONS: TAN-SPECIFIC -->

   <xsl:variable name="tan-classes" as="element()">
      <tan>
         <class n="1">
            <root>TAN-T</root>
            <root>TEI</root>
         </class>
         <class n="2">
            <root>TAN-A-div</root>
            <root>TAN-A-tok</root>
            <root>TAN-A-lm</root>
         </class>
         <class n="3">
            <root>TAN-mor</root>
            <root>TAN-key</root>
            <root>TAN-c</root>
         </class>
      </tan>
   </xsl:variable>
   <xsl:function name="tan:tan-type" as="xs:string*">
      <!-- Input: any nodes -->
      <!-- Output: the names of the root elements; if not present, a zero-length string is returned -->
      <xsl:param name="nodes" as="node()*"/>
      <xsl:for-each select="$nodes">
         <xsl:copy-of select="name(root()/*[1])"/>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:class-number" as="xs:integer*">
      <!-- Input: any nodes of a TAN document -->
      <!-- Output: one digit per node, specifying which TAN class the file fits, based on the name of the root element. If no match is found in the root element, 0 is returned -->
      <xsl:param name="nodes" as="node()*"/>
      <xsl:for-each select="$nodes">
         <xsl:variable name="this-root-name" select="tan:tan-type(.)"/>
         <xsl:variable name="this-class"
            select="$tan-classes/tan:class[tan:root = $this-root-name]/@n"/>
         <xsl:copy-of
            select="
               if (exists($this-class)) then
                  $this-class
               else
                  0"
         />
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:must-refer-to-external-tan-file" as="xs:boolean">
      <!-- Input: node in a TAN document. -->
      <!-- Output: boolean value indicating whether the node or its parent must name or refer to a TAN file. -->
      <xsl:param name="node" as="node()"/>
      <xsl:variable name="class-2-elements-that-must-always-refer-to-tan-files" select="('source')"/>
      <xsl:variable name="this-class" select="tan:class-number($node)"/>
      <xsl:value-of
         select="
            if (
            ((name($node),
            name($node/parent::node())) = $elements-that-must-always-refer-to-tan-files)
            or ($node[(tan:relationship,
            preceding-sibling::tan:relationship) = $relationship-keywords-for-tan-files])
            or ((((name($node),
            name($node/parent::node())) = $class-2-elements-that-must-always-refer-to-tan-files)
            )
            and $this-class = 2)
            )
            then
               true()
            else
               false()"
      />
   </xsl:function>

   <xsl:function name="tan:get-doc-hist" as="element()*">
      <!-- Input: any TAN document -->
      <!-- Output: a sequence of elements with @when, @ed-when, and @when-accessed, sorted from most recent to least; each element includes @when-sort, a decimal that represents the value of the most recent time-date stamp in that element -->
      <xsl:param name="TAN-doc" as="document-node()*"/>
      <xsl:for-each select="$TAN-doc">
         <xsl:variable name="doc-hist-raw" as="element()*">
            <xsl:for-each select=".//*[@when | @ed-when | @when-accessed]">
               <xsl:variable name="these-dates" as="xs:decimal*"
                  select="
                     for $i in (@when | @ed-when | @when-accessed)
                     return
                        tan:dateTime-to-decimal($i)"/>
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:attribute name="when-sort" select="max($these-dates)"/>
                  <xsl:copy-of select="text()[matches(., '\S')]"/>
               </xsl:copy>
            </xsl:for-each>
         </xsl:variable>
         <history>
            <xsl:copy-of select="*/@*"/>
            <xsl:for-each select="$doc-hist-raw">
               <xsl:sort select="@when-sort" order="descending"/>
               <xsl:copy-of select="."/>
            </xsl:for-each>
         </history>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:last-change-agent" as="element()*">
      <!-- Input: any TAN document -->
      <!-- Output: the <person>, <organization>, or <algorithm> who made the last change -->
      <xsl:param name="TAN-doc" as="document-node()*"/>
      <xsl:for-each select="$TAN-doc">
         <xsl:variable name="change-log-sorted" as="element()*">
            <xsl:for-each select="root()/*/tan:head/tan:change">
               <xsl:sort select="tan:dateTime-to-decimal(@when)" order="descending"/>
               <xsl:copy-of select="."/>
            </xsl:for-each>
         </xsl:variable>
         <xsl:variable name="last-change-agent-idref"
            select="tokenize($change-log-sorted[1]/@who, '\s+')"/>
         <xsl:copy-of
            select="root()/*/tan:head/tan:definitions/*[@xml:id = $last-change-agent-idref]"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:conditions-hold" as="xs:boolean?">
      <!-- 2-param version of the master one, below -->
      <xsl:param name="element-with-condition-attributes" as="element()?"/>
      <xsl:param name="context-to-evaluate-against" as="item()*"/>
      <xsl:copy-of
         select="tan:conditions-hold($element-with-condition-attributes, $context-to-evaluate-against, ())"
      />
   </xsl:function>
   <xsl:function name="tan:conditions-hold" as="xs:boolean*">
      <!-- Input: a TAN element with attributes that should be checked for their truth value; a context against which the check the values -->
      <!-- Output: the input elements, with the relevant attributes replaced by a value indicating whether the condition holds -->
      <xsl:param name="element-with-condition-attributes" as="element()?"/>
      <xsl:param name="context-to-evaluate-against" as="item()*"/>
      <xsl:param name="test-sequence" as="xs:string*"/>
      <xsl:variable name="element-with-condition-attributes-sorted-and-distributed" as="element()*">
         <xsl:for-each select="$element-with-condition-attributes/@*">
            <xsl:sort select="(index-of($test-sequence, name(.)), 999)[1]"/>
            <where>
               <xsl:copy-of select="."/>
            </where>
         </xsl:for-each>
      </xsl:variable>
      <xsl:copy-of
         select="tan:condition-evaluation-loop($element-with-condition-attributes-sorted-and-distributed, $context-to-evaluate-against)"
      />
   </xsl:function>
   <xsl:function name="tan:condition-evaluation-loop" as="xs:boolean">
      <!-- Companion function to the one above, indicating whether the conditions in the attributes hold -->
      <xsl:param name="elements-with-condition-attributes-to-be-evaluated" as="element()*"/>
      <xsl:param name="context-to-evaluate-against" as="item()*"/>
      <xsl:choose>
         <xsl:when test="not(exists($elements-with-condition-attributes-to-be-evaluated))">
            <xsl:copy-of select="false()"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="next-element-to-evaluate"
               select="$elements-with-condition-attributes-to-be-evaluated[1]"/>
            <xsl:variable name="this-analysis" as="element()">
               <xsl:apply-templates select="$next-element-to-evaluate" mode="evaluate-conditions">
                  <xsl:with-param name="context" select="$context-to-evaluate-against" tunnel="yes"
                  />
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:choose>
               <xsl:when test="$this-analysis/@* = true()">
                  <xsl:copy-of select="true()"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of
                     select="tan:condition-evaluation-loop($elements-with-condition-attributes-to-be-evaluated[position() gt 1], $context-to-evaluate-against)"
                  />
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <xsl:template match="*" mode="evaluate-conditions">
      <xsl:copy>
         <xsl:apply-templates select="@*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <!-- If an unknown attribute is encountered, skip it -->
   <xsl:template match="@*" mode="evaluate-conditions"/>

   <!-- FUNCTIONS: TAN-SPECIFIC: POINTERS AND RESOLVING REFERENCES -->

   <!-- In TAN files many things need to refer to other things. Every pointing system requires two components. First, something is defined and assigned one or more locally unique identifiers (e.g., @xml:id, <IRI>, <name>). Second, something points to those things by means of a reference, using one of the unique values. -->
   <!-- There are two different kinds of id-ref pointing systems in TAN files: constructed and native. -->
   <!-- 
      Constructed pointing systems
         Q refs (breadcrumbs). A @q may be added to each element in a TAN file when it is first resolved. This unique id value helps tie the parts of an expansions to its original (critically important for basic validation). Because the value is unpredictable, no ref can be constructed until the ids are generated.
         div refs. Each <div> in a class 1 file is given one or more <ref>s that are constructed of the concatenations of its @n values (converted when possible to Arabic numerals) and those of its ancestors. These ids are pointed to via @ref's in class 2 documents. Because these pertain necessarily to class 2 documents, related functions will be found in stylesheets that include this one, e.g., TAN-class-2-functions.xsl
         token refs. Class 2 files may refer to a specific token by number (@pos) or value (@val), in conjunction with the tokenization definition being used.
         character refs. Class 2 files may refer to specific characters by number. 

      Native pointing systems
         @xml:id refs. A variety of attributes take one or more values, each of which is a reference to an @xml:id elsewhere in the <head> of a document or its sources. Because of the nature of @xml:id, these do not permit spaces, or letters outside the basic Latin alphabet. Spaces in a pointer indicate multiple values. There are specific assignments between ref and id, defined by the global variable $id-idrefs.
         glossary refs (@which to <name>). Many elements allow @which, containing a single ref to a <name> of an IRI- + name-defined <item> in the keyword glossary (the built-in TAN-key files, and any extra <key>s invoked by the file). Because <name> allows spaces and Unicode characters, @which cannot take multiple values. During document resolution, elements with @which are replaced by the glossary item. There are specific assignments between an element that takes @which and its keyword/glossary item, defined in the relevant TAN-key file (whether built in or secondary).
         
      In trying to process pointers, it is important to understand which kind of pointing system your are working with. Are you going from a reference to a definition, or from a definition to a glossary item?    
   -->

   <xsl:key name="q-ref" match="*" use="@q"/>
   <xsl:function name="tan:q-ref" as="xs:string*">
      <!-- Input: any elements -->
      <!-- Output: the q-ref of each element-->
      <!-- A q-ref is defined as a concatenated string  consisting of, for each ancestor and self, the name plus the number indicating which sibling it is of that type of element. -->
      <!-- This function is useful when trying to correlate an unbreadmarked file (an original TAN file) against its breadcrumbed counterpart (e.g., $self-resolved), to check for errors. If any changes in element names, e.g., TEI - > TAN-T, are made during the standard preparation process, those changes are made here as well. -->
      <xsl:param name="elements" as="element()*"/>
      <xsl:for-each select="$elements">
         <xsl:variable name="pass1" as="xs:string*">
            <xsl:for-each select="(ancestor::*[not(self::tei:text)], self::*)">
               <xsl:variable name="this-name" select="name()"/>
               <xsl:copy-of
                  select="
                     if ($this-name = 'TEI') then
                        'TAN-T'
                     else
                        $this-name"/>
               <xsl:copy-of
                  select="
                     if (exists(@q)) then
                        @q
                     else
                        string(count(preceding-sibling::*[name(.) = $this-name]) + 1)"
               />
            </xsl:for-each>
         </xsl:variable>
         <xsl:value-of select="string-join($pass1, ' ')"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:get-via-q-ref" as="node()*">
      <!-- Input: any number of qrefs, any number of q-reffed documents -->
      <!-- Output: the elements corresponding to the q-refs -->
      <!-- This function is used by the core validation routine, especially to associate errors in included elements with the primary including element -->
      <xsl:param name="q-ref" as="xs:string*"/>
      <xsl:param name="q-reffed-document" as="document-node()*"/>
      <xsl:for-each select="$q-reffed-document">
         <xsl:sequence select="key('q-ref', $q-ref, .)"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:definition" as="element()*">
      <!-- Input: an attribute or element that contains a text value -->
      <!-- Output: the corresponding entity in <definitions>. If a value does not exist, an <error> is returned. -->
      <!-- Assumes space normalization, and ignores help requests -->
      <xsl:param name="ref-nodes" as="node()*"/>
      <xsl:variable name="ref-node-head" select="root($ref-nodes[1])/*/tan:head"/>
      <xsl:variable name="this-head"
         select="
            if (not(exists($ref-node-head))) then
               $head
            else
               $ref-node-head"/>
      <xsl:for-each select="$ref-nodes">
         <xsl:variable name="this-ref-node" select="."/>
         <xsl:variable name="ref-node-name" select="name($this-ref-node)"/>
         <xsl:variable name="ref-val" as="xs:string?">
            <xsl:choose>
               <xsl:when test="$this-ref-node instance of element()">
                  <xsl:value-of select="$this-ref-node/text()[1]"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="$this-ref-node"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>
         <xsl:variable name="should-refer-to-which-element"
            select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs/@attribute = $ref-node-name]/tan:element"/>
         <xsl:variable name="all-possible-valid-entities"
            select="$this-head//*[name(.) = $should-refer-to-which-element]"/>
         <xsl:for-each select="tokenize($ref-val, ' +')">
            <xsl:variable name="this-val" select="."/>
            <xsl:variable name="entities-pointed-to"
               select="$all-possible-valid-entities[(@xml:id, @id) = $this-val]"/>
            <xsl:choose>
               <xsl:when test="count($entities-pointed-to) gt 1">
                  <xsl:copy-of select="tan:error('tan03')"/>
               </xsl:when>
               <xsl:when test="count($entities-pointed-to) lt 1">
                  <xsl:copy-of select="tan:error('tan05')"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="$entities-pointed-to"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:glossary" as="element()*">
      <!-- one-parameter version of the master one, below -->
      <xsl:param name="element-that-takes-attribute-which" as="item()"/>
      <xsl:sequence select="tan:glossary($element-that-takes-attribute-which, $keys-1st-da, ())"/>
   </xsl:function>
   <xsl:function name="tan:glossary" as="element()*">
      <!-- Input: any element that has @which (or a string value of the name of an element that takes @which); any TAN-key documents (expanded) other than the standard TAN ones; and an optional name that restricts the search to a particular group -->
      <!-- Output: the keyword <items> (most of which contain <IRI>, <name>, and <desc>) that are valid definitions for the element in question, filtered by matches on @which, if present in the first parameter -->
      <xsl:param name="element-that-takes-attribute-which" as="item()"/>
      <xsl:param name="extra-TAN-keys-expanded" as="document-node()*"/>
      <xsl:param name="group-name-alter" as="xs:string?"/>
      <xsl:variable name="element-name" as="xs:string?"
         select="
            if ($element-that-takes-attribute-which instance of xs:string) then
               $element-that-takes-attribute-which
            else
               name($element-that-takes-attribute-which)"/>
      <xsl:variable name="results-alter"
         select="
            if ($element-that-takes-attribute-which instance of element()) then
               $element-that-takes-attribute-which/@which
            else
               ()"/>
      <xsl:variable name="all-TAN-key-docs" select="$extra-TAN-keys-expanded, $TAN-keywords"/>
      <xsl:sequence
         select="
            for $i in $all-TAN-key-docs
            return
               key('item-via-node-name', $element-name, $i)[if (string-length($group-name-alter) gt 0) then
                  (ancestor::tan:group/tan:name = $group-name-alter)
               else
                  true()][if (string-length($results-alter) gt 0) then
                  (tan:name = $results-alter)
               else
                  true()]"
      />
   </xsl:function>


   <!-- FUNCTIONS: TAN-SPECIFIC: FILE PROCESSING: RETRIEVAL, RESOLUTION, EXPANSION, AND MERGING -->

   <!-- Step 1: is it available? -->
   <xsl:function name="tan:first-loc-available" as="xs:string?">
      <!-- Input: An element that is or contains one or more tan:location elements -->
      <!-- Output: the value of the first tan:location/@href to point to a document available, resolved If no location is available nothing is returned. -->
      <xsl:param name="element-that-is-location-or-parent-of-locations" as="element()?"/>
      <xsl:variable name="pass-1"
         select="tan:resolve-href($element-that-is-location-or-parent-of-locations)"/>
      <xsl:value-of select="($pass-1//@href[doc-available(.)])[1]"/>
   </xsl:function>

   <!-- Step 2: if so, get it -->
   <xsl:function name="tan:get-1st-doc" as="document-node()*">
      <!-- Input: any TAN elements naming files (e.g., <source>, <see-also>, <inclusion>, <key>; an indication whether some basic errors should be checked if the retrieved file is a TAN document -->
      <!-- Output: the first document available for each element, plus/or any relevant error messages. -->
      <xsl:param name="TAN-elements" as="element()*"/>
      <xsl:for-each select="$TAN-elements">
         <xsl:variable name="is-master-location" select="exists(self::tan:master-location)"/>
         <xsl:variable name="is-see-also" select="exists(self::tan:see-also)"/>
         <xsl:variable name="this-element" select="."/>
         <xsl:variable name="this-class" select="tan:class-number(.)"/>
         <xsl:variable name="first-la" select="tan:first-loc-available(.)"/>
         <xsl:variable name="this-id" select="root(.)/*/@id"/>
         <xsl:choose>
            <xsl:when test="string-length($first-la) lt 1">
               <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
               <xsl:variable name="these-hrefs" select="tan:resolve-href(.)"/>
               <xsl:variable name="these-tan-catalog-uris"
                  select="
                     for $i in $these-hrefs//@href
                     return
                        replace($i, '[^/]+$', 'catalog.tan.xml')"/>
               <xsl:variable name="these-tan-catalogs"
                  select="doc($these-tan-catalog-uris[doc-available(.)])"/>
               <xsl:variable name="these-IRIs"
                  select="
                     if (self::tan:master-location) then
                        root()/*/@id
                     else
                        tan:IRI"/>
               <xsl:variable name="possible-docs" as="element()*">
                  <xsl:apply-templates select="$these-tan-catalogs//doc[@id = $these-IRIs]"
                     mode="resolve-href"/>
               </xsl:variable>
               <xsl:variable name="possible-hrefs" as="element()*">
                  <xsl:for-each select="$possible-docs/@href">
                     <fix href="{tan:uri-relative-to(., string($this-base-uri))}"/>
                  </xsl:for-each>
               </xsl:variable>
               <xsl:variable name="this-message" as="xs:string*">
                  <xsl:if test="exists($possible-hrefs)">
                     <xsl:text>Try @href: </xsl:text>
                     <xsl:value-of
                        select="
                           string-join($possible-hrefs/@href, ', ')"
                     />
                  </xsl:if>
               </xsl:variable>
               <xsl:document>
                  <xsl:choose>
                     <xsl:when test="self::tan:inclusion">
                        <xsl:copy-of select="tan:error('inc04')"/>
                     </xsl:when>
                     <xsl:when test="self::tan:key">
                        <xsl:copy-of select="tan:error('whi04')"/>
                     </xsl:when>
                     <xsl:when test="$this-class = 1">
                        <xsl:copy-of select="tan:error('wrn01')"/>
                     </xsl:when>
                     <xsl:when
                        test="self::tan:source and not(exists(tan:location)) and tan:tan-type(.) = 'TAN-mor'"/>
                     <xsl:otherwise>
                        <xsl:copy-of
                           select="tan:error('loc01', string-join($this-message, ''), $possible-hrefs, 'replace-attributes')"
                        />
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:document>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="this-doc" select="doc($first-la)"/>
               <xsl:choose>
                  <xsl:when
                     test="($this-doc/*/@id = $this-id) and not($is-master-location or $is-see-also)">
                     <xsl:document>
                        <xsl:copy-of select="tan:error('tan16')"/>
                     </xsl:document>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:sequence select="$this-doc"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <!-- Step 3: resolve it -->
   <!-- See TAN-core-resolve-functions.xsl -->

   <!-- Step 4: expand it -->
   <!-- See TAN-core-expand-functions.xsl -->

   <!-- MERGING -->

   <xsl:function name="tan:merge-expanded-docs" as="document-node()?">
      <!-- Input: Any TAN documents that have been expanded at least tersely -->
      <!-- Output: A document that is a collation of the documents. There is one <head> per source, but only one <body>, with contents merged. -->
      <!-- Class 1 merging: All <div>s with the same <ref> values are grouped together. If the class 1 files are sources of a class 2 file, it is assumed that all actions in the <alter> have been performed. -->
      <!-- Class 2 merging: TBD -->
      <!-- Class 3 merging: TBD -->
      <!-- NB: Class 1 files should have their hierarchies in proper order; use reset-hierarchy beforehand if you're unsure -->
      <xsl:param name="expanded-docs" as="document-node()*"/>
      <xsl:variable name="doc-types" select="tan:tan-type($expanded-docs)"/>
      <xsl:variable name="merge-doc-ids" select="$expanded-docs/*/@id" as="xs:string*"/>
      <xsl:variable name="pre-merge-doc" as="document-node()">
         <!-- merging begins by creating a single document -->
         <xsl:document>
            <xsl:element name="{concat($doc-types[1],'-merge')}">
               <xsl:apply-templates select="$expanded-docs/tan:*/tan:head"
                  mode="merge-expanded-docs-prep"/>
               <body>
                  <xsl:apply-templates select="$expanded-docs/tan:*/tan:body"
                     mode="merge-expanded-docs-prep">
                     <xsl:with-param name="merge-doc-ids" select="$merge-doc-ids" tunnel="yes"/>
                  </xsl:apply-templates>
               </body>
            </xsl:element>
         </xsl:document>
      </xsl:variable>
      <xsl:variable name="merge-results" as="document-node()">
         <xsl:apply-templates select="$pre-merge-doc" mode="merge-divs"/>
      </xsl:variable>
      <!-- diagnostics, results -->
      <!--<xsl:copy-of select="$expanded-docs[1]"/>-->
      <!--<xsl:copy-of select="$pre-merge-doc"/>-->
      <xsl:copy-of select="$merge-results"/>
   </xsl:function>

</xsl:stylesheet>
