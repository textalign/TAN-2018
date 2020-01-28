<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:import href="../../parameters/validation-parameters.xsl"/>

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
      <xsl:copy copy-namespaces="no">
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template priority="-5" match="comment() | processing-instruction()" mode="#all">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template priority="-4" match="* | @*" mode="core-expansion-ad-hoc-pre-pass">
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
   <xsl:variable name="TAN-version" as="xs:string">2020</xsl:variable>
   <xsl:variable name="TAN-version-is-under-development" as="xs:boolean" select="true()"/>
   <xsl:variable name="previous-TAN-versions" select="('1 dev', '2018')"/>
   <xsl:variable name="internet-available" as="xs:boolean">
      <xsl:choose>
         <xsl:when test="$do-not-access-internet = true()">
            <xsl:value-of select="false()"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of
               select="unparsed-text-available('https://google.com') or unparsed-text-available('https://www.w3.org')"
            />
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>
   <xsl:variable name="regex-characters-not-permitted" as="xs:string"
      >[&#xA0;&#x2000;-&#x200a;]</xsl:variable>
   <xsl:variable name="regex-name-space-characters" as="xs:string">[_-]</xsl:variable>
   <xsl:variable name="quot" as="xs:string">"</xsl:variable>
   <xsl:variable name="apos" as="xs:string">'</xsl:variable>
   <xsl:variable name="zwj" as="xs:string">&#x200d;</xsl:variable>
   <!-- discretionary hyphens and soft hyphens are synonymous. -->
   <xsl:variable name="dhy" as="xs:string">&#xad;</xsl:variable>
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

   <xsl:variable name="names-of-attributes-that-take-idrefs" as="xs:string+" select="$id-idrefs/tan:id-idrefs/tan:id/tan:idrefs/@attribute"/>
   <xsl:variable name="names-of-attributes-that-may-take-multiple-space-delimited-values" as="xs:string+"
      select="$names-of-attributes-that-take-idrefs, ('n', 'affects-element', 'affects-attribute', 'item-type')"/>
   <xsl:variable name="names-of-attributes-that-permit-keyword-last" select="('pos', 'chars', 'm-has-how-many-features')"/>
   <xsl:variable name="names-of-attributes-that-are-case-indifferent" as="xs:string+" select="('code', 'n', 'ref', 'affects-element', 'affects-attribute', 'item-type', 'in-lang')"/>
   <xsl:variable name="names-of-elements-that-take-idrefs" as="xs:string+" select="$id-idrefs/tan:id-idrefs/tan:id/tan:idrefs/@element"/>
   <xsl:variable name="names-of-elements-that-must-always-refer-to-tan-files"
      select="('morphology', 'inclusion', 'vocabulary', 'redivision', 'model', 'successor', 'predecessor', 'annotation')"/>
   <xsl:variable name="names-of-elements-that-describe-text-creators" select="('person', 'organization')"/>
   <xsl:variable name="names-of-elements-that-describe-text-bearers" select="('scriptum', 'work', 'version', 'source')"/>
   <xsl:variable name="names-of-elements-that-describe-textual-entities"
      select="$names-of-elements-that-describe-text-creators, $names-of-elements-that-describe-text-bearers"/>
   <xsl:variable name="tag-urn-regex-pattern"
      select="'tag:([\-a-zA-Z0-9._%+]+@)?[\-a-zA-Z0-9.]+\.[A-Za-z]{2,4},\d{4}(-(0\d|1[0-2]))?(-([0-2]\d|3[01]))?:\S+'"/>

   <!-- The next variable contains the map between elements and attributes that may point to names or ids of those elements -->
   <xsl:variable name="id-idrefs" select="doc('TAN-idrefs.xml')"/>

   <xsl:variable name="TAN-namespace" select="'tag:textalign.net,2015:ns'"/>
   <xsl:variable name="TEI-namespace" select="'http://www.tei-c.org/ns/1.0'"/>
   <xsl:variable name="TAN-id-namespace" select="'tag:textalign.net,2015'"/>

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
   <xsl:variable name="all-selector" select="'*'" as="xs:string+"/>

   <!-- If one wishes to see if an entire string matches the following patterns defined by these 
        variables, they must appear between the regular expression anchors ^ and $. -->
   <xsl:variable name="roman-numeral-pattern"
      select="'m{0,4}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(im|ic|il|ix|iv|v?i{0,3})'"/>
   <xsl:variable name="latin-letter-numeral-pattern"
      select="'a+|b+|c+|d+|e+|f+|g+|h+|i+|j+|k+|l+|m+|n+|o+|p+|q+|r+|s+|t+|u+|v+|w+|x+|y+|z+'"/>
   <xsl:variable name="arabic-indic-numeral-pattern" select="'[٠١٢٣٤٥٦٧٨٩]+'"/>
   <xsl:variable name="greek-unit-regex" select="'[α-θΑ-ΘϛϚ]'"/>
   <xsl:variable name="greek-tens-regex" select="'[ι-πΙ-ΠϘϙϞϟ]'"/>
   <xsl:variable name="greek-hundreds-regex" select="'[ρ-ωΡ-ΩϠϡ]'"/>
   <xsl:variable name="greek-letter-numeral-pattern"
      select="concat('͵',  $greek-unit-regex,  '?(?', $greek-hundreds-regex, '?',  $greek-tens-regex,  '?',  $greek-unit-regex,  '|',  $greek-unit-regex,  '?', $greek-hundreds-regex, '?',  
      $greek-tens-regex,  $greek-unit-regex,  '?|',  $greek-unit-regex,  '?', $greek-hundreds-regex, '',  $greek-tens-regex,  '?',  $greek-unit-regex,  '?)ʹ?')"/>
   <xsl:variable name="syriac-unit-regex" select="'[ܐܒܓܕܗܘܙܚܛ]'"/>
   <xsl:variable name="syriac-tens-regex" select="'[ܝܟܠܡܢܣܥܦܨ]'"/>
   <xsl:variable name="syriac-hundreds-regex" select="'ܬ?[ܩܪܫܬ]|[ܢܣܥܦܨ]'"/>
   <!-- A Syriac numeral is either 1s/10s/100s/1000s, with other corresponding digits, perhaps with modifier marks inserted between digits -->
   <xsl:variable name="syriac-letter-numeral-pattern"
      select="concat($syriac-unit-regex, '?\p{Mc}?(', $syriac-hundreds-regex, '\p{Mc})?\p{Mc}?', $syriac-tens-regex, '?\p{Mc}?', $syriac-unit-regex, '\p{Mc}?|', 
      $syriac-unit-regex, '?\p{Mc}?(', $syriac-hundreds-regex, '\p{Mc})?\p{Mc}?', $syriac-tens-regex, '\p{Mc}?', $syriac-unit-regex, '?\p{Mc}?|', 
      $syriac-unit-regex, '?\p{Mc}?(', $syriac-hundreds-regex, '\p{Mc})\p{Mc}?', $syriac-tens-regex, '?\p{Mc}?', $syriac-unit-regex, '?\p{Mc}?')"
   />
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

   <!-- URN namespaces come from the Official IANA Registry of URN Namespaces, https://www.iana.org/assignments/urn-namespaces/urn-namespaces.xhtml, accessed 5 January 2018 -->
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
   <!--<xsl:variable name="self-expanded" select="$self-resolved" as="document-node()+"/>-->

   <xsl:variable name="head"
      select="
         if (exists(/*/tan:head)) then
            $self-resolved/*/tan:head
         else
            /*/*:head"/>

   <xsl:variable name="body"
      select="
         if ($doc-namespace = $TAN-namespace) then
            $self-resolved/*/(tan:body, tei:text/tei:body)
         else
            //*:body"/>
   <xsl:variable name="doc-id" select="/*/@id"/>
   <xsl:variable name="doc-is-error-test" select="matches($doc-id, '^tag:textalign.net,\d+:error-test')"/>
   <xsl:variable name="doc-type" select="name(/*)"/>
   <xsl:variable name="doc-class" select="tan:class-number($self-resolved)"/>
   <xsl:variable name="doc-uri" select="base-uri(/*)"/>
   <xsl:variable name="doc-parent-directory" select="tan:uri-directory(string($doc-uri))"/>
   <xsl:variable name="source-ids"
      select="
         if (exists($head/tan:source/@xml:id)) then
            $head/tan:source/@xml:id
         else
            for $i in (1 to count($head/tan:source))
            return
               string($i)"/>
   <xsl:variable name="all-ids"
      select="$head/(self::*, tan:vocabulary-key/*)/(@xml:id, @id), /tei:TEI//tei:*/@xml:id"/>
   <xsl:variable name="all-head-iris"
      select="$head//tan:IRI[not(ancestor::tan:error) and not(ancestor::tan:inclusion)]"/>
   <xsl:variable name="duplicate-ids" select="tan:duplicate-items($all-ids)"/>
   <xsl:variable name="duplicate-head-iris" select="tan:duplicate-items($all-head-iris)"/>
   <xsl:variable name="doc-namespace" select="namespace-uri(/*)"/>
   <xsl:variable name="doc-id-namespace" select="tan:doc-id-namespace($self-resolved)"/>
   <xsl:variable name="primary-agents" select="$head/tan:file-resp"/>

   <!-- catalogs -->
   <xsl:variable name="doc-catalog-uris" select="tan:catalog-uris(/)"/>
   <xsl:variable name="doc-catalogs" select="tan:catalogs(/, $validation-phase = 'verbose')"
      as="document-node()*"/>
   <xsl:variable name="local-catalog" select="$doc-catalogs[1]"/>

   <!-- inclusions -->
   <xsl:variable name="inclusions-resolved"
      select="tan:get-and-resolve-dependency(/*/tan:head/tan:inclusion)" as="document-node()*"/>

   <!-- vocabularies -->
   <!-- The following key allows you to quickly find in a TAN-voc file vocabulary <item>s for a particular element or attribute -->
   <xsl:key name="item-via-node-name" match="tan:item"
      use="tokenize(string-join((ancestor-or-self::*[@affects-element][1]/@affects-element, ancestor-or-self::*[@affects-attribute][1]/@affects-attribute), ' '), '\s+')"/>
   <!-- What elements are not covered by TAN files -->
   <xsl:variable name="elements-supported-by-TAN-vocabulary-files" as="xs:string+"
      select="
         ('bitext-relation', 'div-type', 'feature', 'group-type', 'license', 'modal', 'normalization',
         'reuse-type', 'role', 'token-definition', 'verb', 'vocabulary')"/>
   <!-- vocabularies: explicit, non-standard; we retain tan:key for the sake of legacy files -->
   <xsl:variable name="vocabularies-resolved"
      select="tan:get-and-resolve-dependency($head/(tan:vocabulary, tan:key[tan:location]))"/>
   <!-- vocabularies: standard TAN -->
   <xsl:variable name="TAN-vocabulary-files" as="document-node()*"
      select="collection('../../vocabularies/collection.xml')"/>
   <!-- We do not have $TAN-vocabularies-resolved since tan:resolve-doc() depends upon standard vocabularies already prepared independently -->
   <!-- TAN vocabularies are already written so as to need minimal resolution or expansion -->
   <xsl:variable name="TAN-vocabularies" as="document-node()*">
      <xsl:apply-templates select="$TAN-vocabulary-files[tan:TAN-voc]" mode="expand-standard-tan-voc">
         <xsl:with-param name="add-q-ids" tunnel="yes" select="false()"/>
         <xsl:with-param name="is-reserved" select="true()" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:variable>
   <xsl:variable name="all-vocabularies" select="($vocabularies-resolved, $TAN-vocabularies)"
      as="document-node()*"/>
   <xsl:variable name="TAN-vocabularies-vocabulary" select="$TAN-vocabularies[tan:TAN-voc/tan:body[@affects-element = 'vocabulary']]"/>
   <xsl:variable name="extra-vocabulary-files"
      select="
         for $i in $TAN-vocabularies-vocabulary/tan:TAN-voc/tan:body/tan:item[tan:location]
         return
            tan:get-1st-doc($i)"
   />
   <xsl:variable name="doc-vocabulary" select="tan:vocabulary((), (), ($head, $self-resolved/(tan:TAN-A, tan:TAN-voc)/tan:body))"/>

   <!-- sources -->
   <!--<xsl:variable name="sources-resolved"
      select="
         if ($is-validation) then
            tan:get-and-resolve-dependency($head/tan:source)
         else
            for $i in $head/tan:source
            return
               tan:resolve-doc(tan:get-1st-doc($i), true(), 'src', ($i/@xml:id, '1')[1])"/>-->
   <xsl:variable name="sources-resolved"
      select="
         for $i in $head/tan:source
         return
            tan:resolve-doc(tan:get-1st-doc($i), true(), tan:attr('src', ($i/@xml:id, '1')[1]))"
   />

   <!-- morphologies -->
   <!--<xsl:variable name="morphologies-resolved"
      select="tan:get-and-resolve-dependency($head/tan:vocabulary-key/tan:morphology)"/>-->
   <!--<xsl:variable name="morphologies-resolved"
      select="
         for $i in $head/tan:vocabulary-key/tan:morphology
         return
            tan:resolve-doc(tan:get-1st-doc($i), true(), 'morphology', ($i/@xml:id, '1')[1])"
   />-->
   <xsl:variable name="morphologies-resolved"
      select="
         for $i in $head/tan:vocabulary-key/tan:morphology
         return
            tan:resolve-doc(tan:get-1st-doc($i), true(), tan:attr('morphology', ($i/@xml:id, '1')[1]))"
   />

   <!-- token definitions -->
   <xsl:variable name="token-definitions-reserved" select="$TAN-vocabularies//tan:token-definition"/>
   <xsl:variable name="token-definition-letters-only"
      select="$token-definitions-reserved[../tan:name = 'letters only']"/>
   <xsl:variable name="token-definition-letters-and-punctuation"
      select="$token-definitions-reserved[../tan:name = 'letters and punctuation']"/>
   <xsl:variable name="token-definition-nonspace"
      select="$token-definitions-reserved[../tan:name = 'nonspace']"/>
   <xsl:variable name="token-definition-default" select="$token-definitions-reserved[1]"/>


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
      <xsl:copy-of select="tan:string-to-numerals($string-to-analyze, true(), false(), ())"/>
   </xsl:function>
   <xsl:function name="tan:string-to-numerals" as="xs:string*">
      <!-- Input: a string thought to contain numerals of some type (e.g., Roman); a boolean indicating whether ambiguous letters should be treated as Roman numerals or letter numerals; a boolean indicating whether only numeral matches should be returned -->
      <!-- Output: the string with parts that look like numerals converted to Arabic numerals -->
      <!-- Does not take into account requests for help -->
      <xsl:param name="string-to-analyze" as="xs:string?"/>
      <xsl:param name="ambig-is-roman" as="xs:boolean?"/>
      <xsl:param name="return-only-numerals" as="xs:boolean?"/>
      <xsl:param name="n-alias-items" as="element()*"/>
      <xsl:variable name="string-analyzed"
         select="tan:analyze-numbers-in-string($string-to-analyze, $ambig-is-roman, $n-alias-items)"/>
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
      <xsl:param name="n-alias-items" as="element()*"/>
      <xsl:variable name="string-parsed" as="element()*">
         <xsl:analyze-string select="$string-to-analyze" regex="[\w_]+">
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
         <xsl:with-param name="n-alias-items" select="$n-alias-items"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="tan:tok" mode="string-to-numerals">
      <xsl:param name="ambig-is-roman" as="xs:boolean" select="true()"/>
      <xsl:param name="n-alias-items" as="element()*"/>
      <xsl:variable name="this-tok" select="."/>
      <xsl:variable name="these-alias-matches" select="$n-alias-items[tan:name = $this-tok]"/>
      <xsl:copy>
         <xsl:choose>
            <xsl:when test="exists($these-alias-matches)">
               <xsl:attribute name="non-number"/>
               <xsl:value-of select="replace($these-alias-matches[1]/tan:name[1], '\s', '_')"/>
            </xsl:when>
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

   <xsl:function name="tan:ordinal" xml:id="f-ordinal" as="xs:string*">
      <!-- Input: one or more numerals
        Output: one or more strings with the English form of the ordinal form of the input number
        E.g., (1, 4, 17)  ->  ('first','fourth','17th'). 
        -->
      <xsl:param name="in" as="xs:integer*"/>
      <xsl:variable name="ordinals"
         select="
            ('first',
            'second',
            'third',
            'fourth',
            'fifth',
            'sixth',
            'seventh',
            'eighth',
            'ninth',
            'tenth')"/>
      <xsl:variable name="ordinal-suffixes"
         select="
            ('th',
            'st',
            'nd',
            'rd',
            'th',
            'th',
            'th',
            'th',
            'th',
            'th')"/>
      <xsl:copy-of
         select="
            for $i in $in
            return
               if (exists($ordinals[$i]))
               then
                  $ordinals[$i]
               else
                  if ($i lt 1) then
                     'none'
                  else
                     concat(xs:string($i), $ordinal-suffixes[($i mod 10) + 1])"
      />
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
                  <xsl:value-of select="dateTime(., xs:time('00:00:00'))"/>
               </xsl:when>
            </xsl:choose>
         </xsl:variable>
         <xsl:variable name="dt-adjusted-as-string"
            select="string(adjust-dateTime-to-timezone($dateTime, $utc))"/>
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
   
   <xsl:function name="tan:duplicate-values" as="item()*">
      <!-- synonym for tan:duplicate-items() -->
      <xsl:param name="sequence" as="item()*"/>
      <xsl:copy-of select="tan:duplicate-items($sequence)"/>
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
      <!-- Input: a series of elements with child elements that have text nodes -->
      <!-- Output: a series of strings representing the sequences, collated -->
      <xsl:param name="elements-with-elements" as="element()*"/>
      <!-- Start with the element that has the greatest number of elements; that will be the grid into which the other sequences will be fit -->
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
      
      <xsl:variable name="diagnostics-on" select="true()" as="xs:boolean"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:collate-sequences()'"/>
         <xsl:message select="'input sorted: ', $input-sorted"/>
         <xsl:message select="'first sequence: ', $first-sequence"/>
      </xsl:if>
      
      <xsl:choose>
         <xsl:when test="count($input-sorted) lt 2">
            <xsl:if test="$diagnostics-on">
               <xsl:message>Function called with fewer than two sequences</xsl:message>
            </xsl:if>
            <xsl:copy-of select="$first-sequence"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of
               select="tan:collate-sequence-loop($input-sorted[position() gt 1], $first-sequence)"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
   <xsl:function name="tan:collate-sequence-loop" as="xs:string*">
      <!-- This companion function to the one above takes a pair of sequences and merges them -->
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
            <xsl:variable name="this-collation"
               select="tan:collate-pair-of-sequences($results-so-far, $next-sequence)"/>
            <xsl:copy-of
               select="tan:collate-sequence-loop($elements-with-elements[position() gt 1], $this-collation)"
            />
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
      <xsl:variable name="results-1" as="element()">
         <xsl:apply-templates select="$string-diff" mode="collate-sequence-1">
            <xsl:with-param name="delimiter-regex" select="tan:escape($this-delimiter)" tunnel="yes"
            />
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:variable name="results-2" as="element()">
         <xsl:apply-templates select="$results-1" mode="collate-sequence-2">
            <xsl:with-param name="delimiter-regex" select="tan:escape($this-delimiter)" tunnel="yes"
            />
         </xsl:apply-templates>
      </xsl:variable>
      
      <xsl:variable name="diagnostics-on" select="true()" as="xs:boolean?"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:collate-pair-of-sequences()'"/>
         <xsl:message select="'string sequence 1: ', $string-sequence-1"/>
         <xsl:message select="'string sequence 2: ', $string-sequence-2"/>
         <xsl:message select="'this delimiter: ', $this-delimiter"/>
         <xsl:message select="'string diff: ', $string-diff"/>
         <xsl:message select="'results pass 1: ', $results-1"/>
         <xsl:message select="'results pass 2: ', $results-2"/>
      </xsl:if>
      
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
      <xsl:variable name="opening-item-should-be-excluded"
         select="
            count($preceding-diffs) gt 0 and
            (some $i in $preceding-diffs
               satisfies not(matches($i, concat($delimiter-regex, '$'))))"/>
      <xsl:variable name="closing-item-should-be-excluded"
         select="
            count($following-diffs) gt 0 and
            (some $i in $following-diffs
               satisfies not(matches($i, concat('^', $delimiter-regex))))"/>
      <xsl:variable name="this-tokenized" select="tokenize(., $delimiter-regex)"/>
      <xsl:for-each select="$this-tokenized">
         <xsl:choose>
            <xsl:when test="string-length(.) lt 1"/>
            <!-- split the first item into <a> and <b> if it should not be included -->
            <!-- split the last item into <a> and <b> if it's the 2nd or greater and it should not be included -->
            <xsl:when
               test="
                  (position() = 1 and $opening-item-should-be-excluded) or
                  (position() = count($this-tokenized) and (count($this-tokenized) gt 1) and $closing-item-should-be-excluded)">
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


   <xsl:function name="tan:most-common-item-count" as="xs:integer?">
      <!-- Input: any sequence of items -->
      <!-- Output: the count of the first item that appears most frequently -->
      <!-- If two or more items appear equally frequently, only the first is returned -->
      <!-- Written to help group <u> elements in tan:collate() -->
      <xsl:param name="sequence" as="item()*"/>
      <xsl:for-each-group select="$sequence" group-by=".">
         <xsl:sort select="count(current-group())" order="descending"/>
         <xsl:if test="position() = 1">
            <xsl:copy-of select="count(current-group())"/>
         </xsl:if>
      </xsl:for-each-group>
   </xsl:function>



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
      <!-- 1-parameter version of function below -->
      <xsl:param name="doc-fragment" as="item()*"/>
      <xsl:copy-of select="$doc-fragment"/>
   </xsl:function>
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
      <!-- This function was written primarily to service the merge of TAN-A sources, where realigned divs could be extracted from their source documents -->
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
   <xsl:function name="tan:group-elements-by-IRI" as="element()*">
      <!-- One-parameter version of the fuller one below.  -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:copy-of select="tan:group-elements-by-shared-node-values($elements-to-group, '^IRI$')"/>
   </xsl:function>
   <xsl:function name="tan:group-divs-by-ref" as="element()*">
      <!-- One-parameter version of the fuller one below.  -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:copy-of select="tan:group-elements-by-shared-node-values($elements-to-group, '^ref$')"/>
   </xsl:function>
   <xsl:function name="tan:group-elements-by-shared-node-values" as="element()*">
      <!-- Two-parameter version of the fuller one below -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:param name="regex-of-names-of-nodes-to-group-by" as="xs:string?"/>
      <xsl:copy-of select="tan:group-elements-by-shared-node-values($elements-to-group, $regex-of-names-of-nodes-to-group-by, false())"/>
   </xsl:function>
   <xsl:function name="tan:group-elements-by-shared-node-values" as="element()*">
      <!-- Input: a sequence of elements; an optional string representing the name of children in the elements -->
      <!-- Output: the same elements, but grouped in <group> according to whether the text contents of the child elements specified are equal -->
      <!-- Each <group> will have an @n stipulating the position of the first element put in the group. That way the results can be sorted in order of their original elements -->
      <!-- Transitivity is assumed. Suppose elements X, Y, and Z have children values A and B; B and C; and C and D, respectively. All three elements will be grouped, even though Y and Z do not directly share children values.  -->
      <xsl:param name="elements-to-group" as="element()*"/>
      <xsl:param name="regex-of-names-of-nodes-to-group-by" as="xs:string?"/>
      <xsl:param name="group-by-shallow-node-value" as="xs:boolean"/>
      <xsl:variable name="group-by-all-children" as="xs:boolean"
         select="string-length($regex-of-names-of-nodes-to-group-by) lt 1 or $regex-of-names-of-nodes-to-group-by = '*'"/>
      <xsl:variable name="elements-prepped-pass-1" as="element()*">
         <xsl:for-each select="$elements-to-group">
            <xsl:variable name="these-grouping-key-nodes" select="node()[matches(name(.), $regex-of-names-of-nodes-to-group-by)]"/>
            <item n="{position()}">
               <xsl:choose>
                  <xsl:when test="$group-by-all-children">
                     <xsl:apply-templates select="node()" mode="build-grouping-key">
                        <xsl:with-param name="group-by-shallow-node-value"
                           select="$group-by-shallow-node-value"/>
                     </xsl:apply-templates>
                  </xsl:when>
                  <xsl:when test="not(exists($these-grouping-key-nodes))">
                     <grouping-key/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates
                        select="$these-grouping-key-nodes"
                        mode="build-grouping-key">
                        <xsl:with-param name="group-by-shallow-node-value"
                           select="$group-by-shallow-node-value"/>
                     </xsl:apply-templates>
                  </xsl:otherwise>
               </xsl:choose>
               <xsl:copy-of select="."/>
            </item>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="duplicate-grouping-keys" select="tan:duplicate-items($elements-prepped-pass-1/tan:grouping-key)"/>
      <xsl:variable name="elements-prepped-pass-2" as="element()*">
         <xsl:for-each select="$elements-prepped-pass-1">
            <xsl:choose>
               <xsl:when test="tan:grouping-key = $duplicate-grouping-keys">
                  <xsl:copy-of select="."/>
               </xsl:when>
               <xsl:otherwise>
                  <group>
                     <xsl:copy-of select="@n"/>
                     <xsl:copy-of select="*"/>
                  </group>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable> 
      <xsl:variable name="items-with-duplicatative-keys-grouped" select="tan:group-elements-by-shared-node-values-loop($elements-prepped-pass-2/self::tan:item, (), 0)"/>
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:group-elements-by-shared-node-values()'"/>
         <xsl:message select="'elements to group: ', $elements-to-group"/>
         <xsl:message select="'name of node to group by (regular expression): ', $regex-of-names-of-nodes-to-group-by"/>
         <xsl:message select="'group by the shallow value of the node?', $group-by-shallow-node-value"/>
         <xsl:message select="'group by all children?', $group-by-all-children"/>
         <xsl:message select="'pass 1: ', $elements-prepped-pass-1"/>
         <xsl:message select="'duplicate grouping keys: ', $duplicate-grouping-keys"/>
         <xsl:message select="'pass 2 (pregrouped items that have unique keys): ', $elements-prepped-pass-2"/>
         <xsl:message select="'pass 3 (items with duplicative keys grouped): ', $items-with-duplicatative-keys-grouped"/>
      </xsl:if>
      
      <xsl:for-each select="$elements-prepped-pass-2/self::tan:group, $items-with-duplicatative-keys-grouped">
         <xsl:sort select="number(@n)"/>
         <xsl:copy>
            <xsl:copy-of select="@n"/>
            <xsl:copy-of select="* except tan:grouping-key"/>
         </xsl:copy>
      </xsl:for-each>
   </xsl:function>
   <xsl:template match="text()" mode="build-grouping-key">
      <grouping-key>
         <xsl:value-of select="."/>
      </grouping-key>
   </xsl:template>
   <xsl:template match="*" mode="build-grouping-key">
      <xsl:param name="group-by-shallow-node-value" as="xs:boolean?"/>
      <xsl:choose>
         <xsl:when test="$group-by-shallow-node-value">
            <xsl:apply-templates select="text()" mode="#current"></xsl:apply-templates>
         </xsl:when>
         <xsl:otherwise>
            <grouping-key><xsl:value-of select="."/></grouping-key>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:function name="tan:group-elements-by-shared-node-values-loop" as="element()*">
      <!-- supporting loop for the function above -->
      <xsl:param name="items-to-group" as="element()*"/>
      <xsl:param name="groups-so-far" as="element()*"/>
      <xsl:param name="loop-count" as="xs:integer"/>
      <xsl:choose>
         <xsl:when test="count($items-to-group) lt 1">
            <xsl:copy-of select="$groups-so-far"/>
         </xsl:when>
         <xsl:when test="$loop-count gt $loop-tolerance">
            <xsl:message select="'loop exceeds tolerance'"/>
            <xsl:copy-of select="$groups-so-far"/>
            <xsl:for-each select="$items-to-group">
               <group>
                  <xsl:copy-of select="@*"/>
                  <xsl:copy-of select="*"/>
               </group>
            </xsl:for-each>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="next-item" select="$items-to-group[1]"/>
            <xsl:variable name="related-items" select="$items-to-group[tan:grouping-key = $next-item/tan:grouping-key]"/>
            <xsl:variable name="groups-that-match" select="$groups-so-far[tan:grouping-key = $related-items/tan:grouping-key]"/>
            <xsl:variable name="new-group" as="element()">
               <group>
                  <xsl:copy-of select="($groups-that-match/@n, $related-items/@n)[1]"/>
                  <xsl:copy-of select="$groups-that-match/*, $related-items/*"/>
               </group>
            </xsl:variable>
            <xsl:copy-of
               select="tan:group-elements-by-shared-node-values-loop(($items-to-group except $related-items), (($groups-so-far except $groups-that-match), $new-group), $loop-count +1)"
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

   <xsl:function name="tan:shallow-copy" as="item()*">
      <!-- one-parameter version of the fuller one, below -->
      <xsl:param name="items" as="item()*"/>
      <xsl:copy-of select="tan:shallow-copy($items, 1)"/>
   </xsl:function>
   <xsl:function name="tan:shallow-copy" as="item()*">
      <!-- Input: any document fragment; boolean indicating whether attributes should be kept -->
      <!-- Output: a shallow copy of the fragment, perhaps with attributes -->
      <xsl:param name="items" as="item()*"/>
      <xsl:param name="depth" as="xs:integer"/>
      <xsl:apply-templates select="$items" mode="shallow-copy">
         <xsl:with-param name="levels-to-go" select="$depth"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="node() | document-node()" mode="shallow-copy">
      <xsl:param name="levels-to-go" as="xs:integer?"/>
      <xsl:if test="$levels-to-go gt 0">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current">
               <xsl:with-param name="levels-to-go" select="$levels-to-go - 1"/>
            </xsl:apply-templates>
         </xsl:copy>
      </xsl:if>
   </xsl:template>

   <xsl:function name="tan:value-of" as="xs:string?">
      <!-- Input: any sequence of items -->
      <!-- Output: the value of each item -->
      <!-- Proxy for <xsl:value-of/>. Useful as a function in XPath expressions -->
      <xsl:param name="items" as="item()*"/>
      <xsl:value-of select="$items"/>
   </xsl:function>

   <xsl:function name="tan:insert-as-first-child" as="item()*">
      <!-- Input: items to be changed; items to be inserted; strings representing the names of the elements that should receive the insertion -->
      <!-- Output: the first items, with the second items inserted in the appropriate place -->
      <xsl:param name="items-to-be-changed" as="item()*"/>
      <xsl:param name="items-to-insert-as-first-child" as="item()*"/>
      <xsl:param name="names-of-elements-to-receive-action" as="xs:string*"/>
      <xsl:apply-templates select="$items-to-be-changed" mode="insert-content">
         <xsl:with-param name="items-to-insert-as-first-child"
            select="$items-to-insert-as-first-child" tunnel="yes"/>
         <xsl:with-param name="names-of-elements-to-receive-action"
            select="$names-of-elements-to-receive-action" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:function name="tan:insert-as-last-child" as="item()*">
      <!-- Input: items to be changed; items to be inserted; strings representing the names of the elements that should receive the insertion -->
      <!-- Output: the first items, with the second items inserted in the appropriate place -->
      <!-- This function was written in service to a 2019 version of tan:vocabulary(), to allow deeply nested vocabulary items to receive select insertions -->
      <xsl:param name="items-to-be-changed" as="item()*"/>
      <xsl:param name="items-to-insert-as-last-child" as="item()*"/>
      <xsl:param name="names-of-elements-to-receive-action" as="xs:string*"/>
      <xsl:apply-templates select="$items-to-be-changed" mode="insert-content">
         <xsl:with-param name="items-to-insert-as-last-child"
            select="$items-to-insert-as-last-child" tunnel="yes"/>
         <xsl:with-param name="names-of-elements-to-receive-action"
            select="$names-of-elements-to-receive-action" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="insert-content">
      <xsl:param name="names-of-elements-to-receive-action" tunnel="yes"/>
      <xsl:param name="items-to-insert-as-first-child" tunnel="yes"/>
      <xsl:param name="items-to-insert-as-last-child" tunnel="yes"/>
      <xsl:variable name="allow-insertion" select="name() = $names-of-elements-to-receive-action"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$allow-insertion">
            <xsl:copy-of select="$items-to-insert-as-first-child"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
         <xsl:if test="$allow-insertion">
            <xsl:copy-of select="$items-to-insert-as-last-child"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:element-fingerprint" as="xs:string*">
      <!-- Input: any elements -->
      <!-- Output: for each element the string value of its name, its namespace, its attributes, and all descendant nodes -->
      <!-- This function is useful for determining whether any number of elements are deeply equal -->
      <!-- The built-in function deep-equal() works for pairs of elements; this looks for a way to evaluate sequences of elements -->
      <xsl:param name="element" as="element()*"/>
      <xsl:for-each select="$element">
         <xsl:variable name="results" as="xs:string*">
            <xsl:apply-templates select="$element" mode="element-fingerprint"/>
         </xsl:variable>
         <xsl:value-of select="string-join($results, '')"/>
      </xsl:for-each>
   </xsl:function>
   <xsl:template match="*" mode="element-fingerprint">
      <xsl:text>e#</xsl:text>
      <xsl:value-of select="name()"/>
      <xsl:text>ns#</xsl:text>
      <xsl:value-of select="namespace-uri()"/>
      <xsl:text>aa#</xsl:text>
      <xsl:for-each select="@*">
         <xsl:sort select="name()"/>
         <xsl:text>a#</xsl:text>
         <xsl:value-of select="name()"/>
         <xsl:text>#</xsl:text>
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:text>#</xsl:text>
      </xsl:for-each>
      <xsl:apply-templates select="node()" mode="#current"/>
   </xsl:template>
   <!-- We presume (perhaps wrongly) that comments and pi's in an element don't matter -->
   <xsl:template match="comment() | processing-instruction()" mode="element-fingerprint"/>
   <xsl:template match="text()" mode="element-fingerprint">
      <xsl:if test="matches(., '\S')">
         <xsl:text>t#</xsl:text>
         <xsl:value-of select="normalize-space(.)"/>
         <xsl:text>#</xsl:text>
      </xsl:if>
   </xsl:template>

   <xsl:function name="tan:stamp-q-id" as="item()*">
      <!-- 1-param version of the full one below -->
      <xsl:param name="items-to-stamp" as="item()*"/>
      <xsl:copy-of select="tan:stamp-q-id($items-to-stamp, false())"/>
   </xsl:function>
   <xsl:function name="tan:stamp-q-id" as="item()*">
      <!-- Input: any XML fragments -->
      <!-- Output: the fragments with @q added to each element with the value of generate-id() -->
      <xsl:param name="items-to-stamp" as="item()*"/>
      <xsl:param name="stamp-shallowly" as="xs:boolean"/>
      <xsl:apply-templates select="$items-to-stamp" mode="stamp-q-id">
         <xsl:with-param name="stamp-shallowly" select="$stamp-shallowly" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="stamp-q-id">
      <xsl:param name="stamp-shallowly" as="xs:boolean" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="q" select="generate-id(.)"/>
         <xsl:choose>
            <xsl:when test="$stamp-shallowly">
               <xsl:copy-of select="node()"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:node-before" as="xs:boolean">
      <!-- Input: two sequences of nodes -->
      <!-- Output: a boolean indicating whether one of the nodes in the first sequence precedes all the nodes of the second -->
      <xsl:param name="node-sequence-1" as="node()+"/>
      <xsl:param name="node-sequence-2" as="node()+"/>
      <xsl:variable name="remainder" select="$node-sequence-1/following::node()"/>
      <xsl:value-of
         select="
            every $i in $node-sequence-2
               satisfies exists($remainder intersect $i)"
      />
   </xsl:function>
   
   <xsl:function name="tan:indent-value" as="xs:integer*">
      <!-- Input: elements -->
      <!-- Output: the length of their indentation -->
      <xsl:param name="elements" as="element()*"/>
      <xsl:variable name="ancestor-preceding-text-nodes" as="xs:string*">
         <xsl:for-each select="$elements">
            <xsl:variable name="this-preceding-white-space-text-node"
               select="preceding-sibling::node()[1]/self::text()[not(matches(., '\S'))]"/>
            <xsl:choose>
               <xsl:when test="string-length($this-preceding-white-space-text-node) gt 0">
                  <!-- strip away the line feed and anything preceding it -->
                  <xsl:value-of select="replace($this-preceding-white-space-text-node, '.*\n', '')"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="''"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      <xsl:copy-of
         select="
            for $i in $ancestor-preceding-text-nodes
            return
               string-length($i)"
      />
   </xsl:function>
   <xsl:function name="tan:copy-indentation" as="item()*">
      <!-- Input: items that should be indented; an element whose indentation should be followed -->
      <!-- Output: the items, indented according to the pattern -->
      <xsl:param name="items-to-indent" as="item()*"/>
      <xsl:param name="model-element" as="element()"/>
      <xsl:variable name="model-ancestors" select="$model-element/ancestor-or-self::*"/>
      <xsl:variable name="inherited-indentation-quantities" select="tan:indent-value($model-ancestors)"/>
      <xsl:variable name="this-default-indentation"
         select="
            if (count($model-ancestors) gt 1) then
               ceiling($inherited-indentation-quantities[last()] div (count($model-ancestors) - 1))
            else
               $indent-value"
      />
      <xsl:apply-templates select="$items-to-indent" mode="indent-items">
         <xsl:with-param name="current-context-average-indentation" select="$inherited-indentation-quantities[last()]"/>
         <xsl:with-param name="default-indentation-increase" select="$this-default-indentation" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="indent-items">
      <xsl:param name="current-context-average-indentation" as="xs:integer"/>
      <xsl:param name="default-indentation-increase" as="xs:integer" tunnel="yes"/>
      <xsl:value-of select="concat('&#xa;', tan:fill(' ', $current-context-average-indentation))"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="current-context-average-indentation"
               select="$current-context-average-indentation + $default-indentation-increase"/>
         </xsl:apply-templates>
      </xsl:copy>
      <xsl:if test="not(exists(following-sibling::*))">
         <xsl:value-of select="concat('&#xa;', tan:fill(' ', ($current-context-average-indentation - $default-indentation-increase)))"/>
      </xsl:if>
   </xsl:template>
   <xsl:template match="text()" mode="indent-items">
      <xsl:if test="matches(., '\S')">
         <xsl:value-of select="."/>
      </xsl:if>
   </xsl:template>
   
   <xsl:function name="tan:attr" as="attribute()?">
      <!-- Input: two strings -->
      <!-- Output: an attribute by the name of the first string, with the value of the second -->
      <xsl:param name="attribute-name" as="xs:string?"/>
      <xsl:param name="attribute-value" as="xs:string?"/>
      <xsl:choose>
         <xsl:when test="$attribute-name castable as xs:NCName">
            <xsl:attribute name="{$attribute-name}" select="$attribute-value"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:message select="$attribute-name, ' is not a legal attribute name'"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>


   <!-- FUNCTIONS: SEQUENCES, TAN-SPECIFIC (e.g., @ref, @pos, @chars, ...) -->

   <xsl:function name="tan:normalize-sequence" as="xs:string*">
      <!-- Input: any string representing a sequence; the name of the attribute whence the value, i.e., @ref, @pos, @chars, @n -->
      <!-- Output: the string, normalized and sequenced into items; items that are ranges will have the beginning and end points separated by ' - ' -->
      <!-- Note, this function does not analyze or convert types of numerals, and all help requests are left intact; the function is most effective if numerals have been converted to Arabic ahead of time -->
      <!-- Here we're targeting tan:analyze-elements-with-numeral-attributes() template mode arabic-numerals, prelude to tan:sequence-expand(), tan:normalize-refs() -->
      <xsl:param name="sequence-string" as="xs:string?"/>
      <xsl:param name="attribute-name" as="xs:string"/>
      <xsl:variable name="seq-string-pass-1"
         select="
            if ($attribute-name = $names-of-attributes-that-are-case-indifferent) then
               lower-case(normalize-space($sequence-string))
            else
               normalize-space($sequence-string)"
      />
      <xsl:variable name="seq-string-normalized" as="xs:string?">
         <xsl:if test="string-length($seq-string-pass-1) gt 0">
            <!-- all hyphens are special characters, and adjacent spaces should not be treated as delimiting items -->
            <xsl:value-of select="replace($seq-string-pass-1, ' ?- ?', '-')"/>
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="primary-tokenization-pattern" as="xs:string">
         <xsl:choose>
            <xsl:when test="$attribute-name = $names-of-attributes-that-may-take-multiple-space-delimited-values"> +</xsl:when>
            <xsl:otherwise> *, *</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:normalize-sequence()'"/>
         <xsl:message select="'sequence string: ', $sequence-string"/>
         <xsl:message select="'attribute name: ', $attribute-name"/>
         <xsl:message select="'normalization pass 1: ', $seq-string-pass-1"/>
         <xsl:message select="'normalization pass 2: ', $seq-string-normalized"/>
         <xsl:message select="'tokenization pattern: ', $primary-tokenization-pattern"/>
      </xsl:if>
      <xsl:for-each select="tokenize($seq-string-normalized, $primary-tokenization-pattern)">
         <xsl:choose>
            <xsl:when test="$attribute-name = ('pos', 'chars', 'm-has-how-many-features')">
               <!-- These are attributes that allow data picker items or sequences, which have keywords "last" etc. -->
               <xsl:choose>
                  <xsl:when test=". = ('all', '*')">
                     <xsl:value-of select="'1 - last'"/>
                  </xsl:when>
                  <xsl:when test="matches(., '^((last|max)(-\d+)?|\d+)-((last|max)(-\d+)?|\d+)$')">
                     <xsl:variable name="these-items" as="xs:string+">
                        <xsl:analyze-string select="." regex="((last|max)(-\d+)?|\d+)">
                           <xsl:matching-substring>
                              <xsl:value-of select="replace(., 'max', 'last')"/>
                           </xsl:matching-substring>
                        </xsl:analyze-string>
                     </xsl:variable>
                     <xsl:value-of select="string-join($these-items, ' - ')"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:value-of select="replace(., '-', ' - ')"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="replace(., '-', ' - ')"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:analyze-sequence" as="element()">
      <!-- two-parameter version of the fuller function below -->
      <xsl:param name="sequence-string" as="xs:string"/>
      <xsl:param name="name-of-attribute" as="xs:string?"/>
      <xsl:copy-of select="tan:analyze-sequence($sequence-string, $name-of-attribute, false())"/>
   </xsl:function>
   <xsl:function name="tan:analyze-sequence" as="element()">
      <!-- three-parameter version of the fuller function below -->
      <xsl:param name="sequence-string" as="xs:string"/>
      <xsl:param name="name-of-attribute" as="xs:string?"/>
      <xsl:param name="expand-ranges" as="xs:boolean"/>
      <xsl:copy-of
         select="tan:analyze-sequence($sequence-string, $name-of-attribute, $expand-ranges, true())"
      />
   </xsl:function>
   <xsl:function name="tan:analyze-sequence" as="element()">
      <!-- Input: any string representing a sequence; the name of the attribute that held the sequence (default 'ref'); should ranges should be expanded?; are ambiguous numerals roman? -->
      <!-- Output: <analysis> with an expansion of the sequence placed in children elements that have the name of the second parameter (with @attr); those children have @from or @to if part of a range. -->
      <!-- If a sequence has a numerical value no numerals other than Arabic should be used. That means @pos and @chars in their original state, but also if @n, then it needs to have been normalized to Arabic numerals before entering this function -->
      <!-- The exception is @ref, which cannot be accurately converted to Arabic numerals before being studied in the context of a class 1 source -->
      <!-- This function expands only those @refs that are situated within an  <adjustments>, which need to be calculated before being taken to a class 1 source. -->
      <!-- If this function is asked to expand ranges within a @ref sequence, it will do so under the strict assumption that all ranges consist of numerically calculable sibling @ns that share the same mother reference. -->
      <!-- Matt 1 4-7 is ok. These are not: Matt-Mark, Matt 1:3-Matt 2, Matt 1:3-4:7 -->
      <!-- If a request for help is detected, the flag will be removed and @help will be inserted in the appropriate child element. -->
      <!-- If ranges are requested to be expanded, it is expected to apply only to integers, and will not operate on values of 'max' or 'last' -->
      <!-- This function normalizes strings; no need to run that function beforehand -->
      <xsl:param name="sequence-string" as="xs:string?"/>
      <xsl:param name="name-of-attribute" as="xs:string?"/>
      <xsl:param name="expand-ranges" as="xs:boolean"/>
      <xsl:param name="ambig-is-roman" as="xs:boolean?"/>
      <xsl:variable name="attribute-name"
         select="
            if (string-length($name-of-attribute) lt 1) then
               'ref'
            else
               $name-of-attribute"/>
      <xsl:variable name="is-div-ref" select="$attribute-name = ('ref', 'new')" as="xs:boolean"/>
      <xsl:variable name="string-normalized"
         select="tan:normalize-sequence($sequence-string, $attribute-name)"/>
      <xsl:variable name="pass-1" as="element()">
         <analysis>
            <xsl:for-each select="$string-normalized">
               <xsl:variable name="this-pos" select="position()"/>
               <xsl:variable name="this-value-or-these-range-components" select="tokenize(., ' - ')"/>
               <xsl:variable name="is-range"
                  select="count($this-value-or-these-range-components) gt 1"/>

               <xsl:for-each select="$this-value-or-these-range-components">
                  <xsl:variable name="this-val-checked" select="tan:help-extracted(.)"/>
                  <xsl:variable name="this-val" select="$this-val-checked/text()"/>
                  <xsl:element name="{$attribute-name}">
                     <xsl:attribute name="attr"/>
                     <xsl:if test="$is-range">
                        <xsl:attribute name="{if (position() = 1) then 'from' else 'to'}"/>
                     </xsl:if>
                     <xsl:copy-of select="$this-val-checked/@help"/>
                     <xsl:choose>
                        <xsl:when test="$is-div-ref">
                           <!-- A reference returns both the full normalized form and the individual @n's parsed. -->
                           <!-- We avoid adding the text value of the ref until after individual <n> values are calculated -->
                           <!-- we exclude from ns the hash, which is used to separate adjoining numbers, e.g., 1#2 representing 1b -->
                           <xsl:variable name="these-ns" select="tokenize(., '[^#\w\?_]+')"/>
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
         </analysis>
      </xsl:variable>
      <xsl:variable name="pass-2" as="element()">
         <xsl:choose>
            <xsl:when test="$is-div-ref">
               <analysis>
                  <xsl:copy-of select="tan:analyze-ref-loop($pass-1/*, (), ())"/>
               </analysis>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$pass-1"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:analyze-sequence()'"/>
         <xsl:message select="'sequence string: ', $sequence-string"/>
         <xsl:message select="'name of attribute: ', $name-of-attribute"/>
         <xsl:message select="'expand ranges? ', $expand-ranges"/>
         <xsl:message select="'ambig is roman? ', $ambig-is-roman"/>
         <xsl:message select="'string normalized: ', $string-normalized"/>
         <xsl:message select="'pass 1: ', $pass-1"/>
         <xsl:message select="'pass 2: ', $pass-2"/>
      </xsl:if>
      <xsl:apply-templates select="$pass-2" mode="check-and-expand-ranges">
         <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
         <xsl:with-param name="expand-ranges" select="$expand-ranges" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>

   <xsl:template match="*[@from][text()]" mode="check-and-expand-ranges">
      <xsl:param name="expand-ranges" tunnel="yes" as="xs:boolean"/>
      <xsl:variable name="this-to" select="following-sibling::*[1][@to]"/>
      <xsl:variable name="this-element-name" select="name(.)"/>
      <xsl:variable name="from-and-to-are-integers" select=". castable as xs:integer and $this-to castable as xs:integer"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on template mode check-and-expand-ranges for: ', ."/>
         <xsl:message select="'try to expand ranges? ', $expand-ranges"/>
         <xsl:message select="'this to: ', $this-to"/>
      </xsl:if>
      <xsl:copy-of select="."/>
      <xsl:choose>
         <xsl:when test="$expand-ranges and $from-and-to-are-integers">
            <xsl:variable name="from-int" select="xs:integer(.)"/>
            <xsl:variable name="to-int" select="xs:integer($this-to)"/>
            <xsl:variable name="this-sequence-expanded"
               select="tan:expand-numerical-sequence(concat(., ' - ', $this-to), max(($from-int, $to-int)))"/>
            <xsl:variable name="sequence-errors" select="tan:sequence-error($this-sequence-expanded)"/>
            <xsl:copy-of select="$sequence-errors"/>
            <xsl:for-each select="$this-sequence-expanded[position() gt 1 and position() lt last()]">
               <xsl:element name="{$this-element-name}">
                  <xsl:value-of select="."/>
               </xsl:element>
            </xsl:for-each>
         </xsl:when>
         <xsl:when test="$expand-ranges">
            <xsl:copy-of select="tan:error('seq05')"/>
         </xsl:when>
         <xsl:when test="$from-and-to-are-integers">
            <xsl:if test="xs:integer($this-to) le xs:integer(.)">
               <xsl:copy-of select="tan:error('seq03')"/>
            </xsl:if>
         </xsl:when>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="tan:ref[@from][tan:n]" priority="1" mode="check-and-expand-ranges">
      <xsl:param name="ambig-is-roman" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="expand-ranges" tunnel="yes" as="xs:boolean"/>
      <xsl:variable name="this-from" select="."/>
      <xsl:variable name="this-last-n" select="tan:n[last()]"/>
      <xsl:variable name="these-preceding-ns" select="tan:n except $this-last-n"/>
      <xsl:variable name="this-to" select="following-sibling::*[1][@to]"/>
      <xsl:variable name="this-to-last-n" select="$this-to/tan:n[last()]"/>
      <xsl:variable name="these-to-preceding-ns" select="$this-to/(tan:n except $this-to-last-n)"/>
      <xsl:variable name="element-name" select="name(.)"/>
      <xsl:variable name="first-value"
         select="tan:string-to-numerals(lower-case($this-last-n), $ambig-is-roman, false(), ())"/>
      <xsl:variable name="last-value"
         select="tan:string-to-numerals(lower-case($this-to-last-n), $ambig-is-roman, false(), ())"/>
      <xsl:variable name="this-sequence-expanded"
         select="tan:expand-numerical-sequence(concat($first-value, ' - ', $last-value), xs:integer($last-value))"/>
      <xsl:variable name="first-is-arabic" select="$first-value castable as xs:integer"/>
      <xsl:variable name="last-is-arabic" select="$last-value castable as xs:integer"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:value-of
            select="string-join(($these-preceding-ns, $first-value), $separator-hierarchy)"/>
         <xsl:copy-of select="$these-preceding-ns"/>
         <n>
            <xsl:value-of select="$first-value"/>
         </n>
      </xsl:copy>
      <xsl:choose>
         <xsl:when test="not($expand-ranges)"/>
         <xsl:when test="not($first-is-arabic) and not($last-is-arabic)">
            <xsl:copy-of
               select="tan:error('seq05', concat('neither ', $this-last-n, ' nor ', $this-to-last-n, ' are numerals'))"
            />
         </xsl:when>
         <xsl:when test="not($first-is-arabic)">
            <xsl:copy-of select="tan:error('seq05', concat($this-last-n, ' is not a numeral'))"/>
         </xsl:when>
         <xsl:when test="not($last-is-arabic)">
            <xsl:copy-of select="tan:error('seq05', concat($this-to-last-n, ' is not a numeral'))"/>
         </xsl:when>
         <xsl:when
            test="
               (count($these-preceding-ns) ne count($these-to-preceding-ns))
               or (some $i in (1 to max((count($these-preceding-ns), count($these-to-preceding-ns))))
                  satisfies ($these-preceding-ns[$i] ne $these-to-preceding-ns[$i]))">
            <xsl:copy-of
               select="tan:error('seq05', concat(string-join($these-preceding-ns, $separator-hierarchy), ' and ', string-join($these-to-preceding-ns, $separator-hierarchy), ' should be identical'))"
            />
         </xsl:when>
         <xsl:when test="xs:integer($first-value) ge xs:integer($last-value)">
            <xsl:copy-of
               select="tan:error('seq05', concat($this-last-n, ' should be less than ', $this-to-last-n))"
            />
         </xsl:when>
         <xsl:otherwise>
            <xsl:for-each select="xs:integer($first-value) + 1 to xs:integer($last-value) - 1">
               <ref>
                  <xsl:value-of
                     select="string-join(($these-preceding-ns, xs:string(.)), $separator-hierarchy)"/>
                  <xsl:copy-of select="$these-preceding-ns"/>
                  <n>
                     <xsl:value-of select="."/>
                  </n>
               </ref>
            </xsl:for-each>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:function name="tan:analyze-ref-loop" as="element()*">
      <!-- Input: elements from tan:analyze-sequence() that should have missing or assumed <n>s inserted into the <ref>s -->
      <!-- Output: the likely resolution of those <ref>s -->
      <!-- If the function moves from one <ref> to one with greater than or equal number of <n>s, the new one becomes the context; otherwise, the new <ref> attracts from the context any missing <n>s at its head -->
      <!-- This function takes a string such as "1.3-5, 8, 4.2-3" and converts it to "1.3, 1.5, 1.8, 4.2, 4.3" -->
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
      <!-- Input: any elements that are <pos> or <chars>; an integer value for 'max' -->
      <!-- Output: the elements converted to integers they represent -->
      <!-- Because the results are normally positive integers, the following should be treated as error codes:
            0 = value that falls below 1
            -1 = value that cannot be converted to an integer
            -2 = ranges that call for negative steps, e.g., '4 - 2' -->
      <xsl:param name="elements" as="element()*"/>
      <xsl:param name="max" as="xs:integer?"/>
      <xsl:variable name="elements-prepped" as="element()">
         <elements>
            <xsl:copy-of select="$elements"/>
         </elements>
      </xsl:variable>
      <xsl:for-each-group select="$elements-prepped/*"
         group-by="count((self::*, preceding-sibling::*)[not(@to)])">
         <xsl:variable name="elements-to-analyze" select="current-group()"/>
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
      </xsl:for-each-group>
   </xsl:function>

   <xsl:function name="tan:expand-numerical-sequence" as="xs:integer*">
      <!-- Input: a string representing a TAN selector (used by @pos, @char), and an integer defining the value of 'last' -->
      <!-- Output: a sequence of numbers representing the positions selected, unsorted, and retaining duplicate values.
            Example: ("2 - 4, last-5 - last, 36", 50) -> (2, 3, 4, 45, 46, 47, 48, 49, 50, 36)
            Errors will be flagged as follows:
            0 = value that falls below 1
            -1 = value that surpasses the value of $max
            -2 = ranges that call for negative steps, e.g., '4 - 2' -->
      <!-- This function assumes that all numerals are Arabic -->
      <xsl:param name="selector" as="xs:string?"/>
      <xsl:param name="max" as="xs:integer?"/>
      <!-- first normalize syntax -->
      <xsl:variable name="pass-1" select="tan:normalize-sequence($selector, 'pos')"/>
      <xsl:variable name="pass-2" as="xs:string*">
         <xsl:for-each select="$pass-1">
            <xsl:variable name="this-last-norm" as="xs:string+">
               <xsl:analyze-string select="." regex="last-?(\d*)">
                  <xsl:matching-substring>
                     <xsl:variable name="number-to-subtract"
                        select="
                           if (string-length(regex-group(1)) gt 0) then
                              number(regex-group(1))
                           else
                              0"
                     />
                     <xsl:value-of select="string(($max - $number-to-subtract))"/>
                  </xsl:matching-substring>
                  <xsl:non-matching-substring>
                     <xsl:value-of select="."/>
                  </xsl:non-matching-substring>
               </xsl:analyze-string>
            </xsl:variable>
            <xsl:value-of select="string-join($this-last-norm, '')"/>
         </xsl:for-each>
      </xsl:variable>
      <xsl:for-each select="$pass-2">
         <xsl:variable name="range"
            select="
               for $i in tokenize(., ' - ')
               return
                  xs:integer($i)"/>
         <xsl:choose>
            <xsl:when test="$range[1] lt 1 or $range[2] lt 1">
               <xsl:sequence select="0"/>
            </xsl:when>
            <xsl:when test="$range[1] gt $max or $range[2] gt $max">
               <xsl:sequence select="-1"/>
            </xsl:when>
            <xsl:when test="$range[1] gt $range[2]">
               <xsl:sequence select="-2"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$range[1] to $range[last()]"/>
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


   <!-- FUNCTIONS: STRINGS: see TAN-core-string-functions.xsl -->

   <!-- FUNCTIONS: ACCESSORS AND MANIPULATION OF URIS -->

   <xsl:function name="tan:cfn" as="xs:string*">
      <!-- Input: any items -->
      <!-- Output: the Current File Name, without extension, of the host document node of each item -->
      <xsl:param name="item" as="item()*"/>
      <xsl:for-each select="$item">
         <xsl:value-of select="replace(xs:string(tan:base-uri(.)), '.+/([^/]+)\.\w+$', '$1')"/>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:cfne" as="xs:string*">
      <!-- Input: any items -->
      <!-- Output: the Current File Name, with Extension, of the host document node of each item -->
      <xsl:param name="item" as="item()*"/>
      <xsl:for-each select="$item">
         <xsl:value-of select="replace(xs:string(tan:base-uri(.)), '.+/([^/]+\.\w+)$', '$1')"/>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:is-valid-uri" as="xs:boolean?">
      <!-- Input: a string -->
      <!-- Output: a boolean indicating whether the string is syntactically a valid uri -->
      <!-- This assumes not only absolute but relative uris will be checked, which means that a wide 
         variety of characters could be fed in, but not ones disallowed in pathnames, and the string must 
         not be zero length. -->
      <xsl:param name="uri-to-check" as="xs:string?"/>
      <xsl:copy-of select="not(matches($uri-to-check, '[\{\}\|\\\^\[\]`]')) and (string-length($uri-to-check) gt 0)"/>
   </xsl:function>
   <xsl:function name="tan:uri-directory" as="xs:string*">
      <!-- Input: any URIs, as strings -->
      <!-- Output: the file path -->
      <!-- NB, this function does not assume any URIs have been resolved -->
      <xsl:param name="uris" as="xs:string*"/>
      <xsl:for-each select="$uris">
         <xsl:choose>
            <xsl:when test="matches(., '/')">
               <xsl:value-of select="replace(., '(.*/)[^/]+$', '$1')"/>
            </xsl:when>
            <xsl:otherwise>.</xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:base-uri" as="xs:anyURI">
      <!-- Input: any node -->
      <!-- Output: the base uri of the node's document -->
      <!-- An explicit @xml:base has the highest priority over any native base-uri(). If the node is a fragment and has no declared or detected
         base uri, the static-base-uri() will be returned -->
      <xsl:param name="any-node" as="node()?"/>
      <xsl:variable name="specified-ancestral-xml-base-attrs" select="$any-node/ancestor-or-self::*[@xml:base], root($any-node)/*[@xml:base]"/>
      <xsl:variable name="default-xml-base" select="base-uri($any-node)"/>
      <xsl:choose>
         <xsl:when test="exists($specified-ancestral-xml-base-attrs)">
            <xsl:sequence select="$specified-ancestral-xml-base-attrs[1]/@xml:base"/>
         </xsl:when>
         <xsl:when test="string-length($default-xml-base) gt 0">
            <xsl:sequence select="$default-xml-base"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:sequence select="static-base-uri()"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
   <xsl:function name="tan:uri-relative-to" as="xs:string?">
      <!-- 2-parameter version of the one below -->
      <xsl:param name="uri-to-revise" as="xs:string?"/>
      <xsl:param name="uri-to-revise-against" as="xs:string?"/>
      <xsl:copy-of select="tan:uri-relative-to($uri-to-revise, $uri-to-revise-against, $uri-to-revise-against)"/>
   </xsl:function>
   <xsl:function name="tan:uri-relative-to" as="xs:string?">
      <!-- Input: two strings representing URIs; a third representing the base against which the first two should be resolved -->
      <!-- Output: the first string in a form relative to the second string -->
      <!-- This function looks for common paths within two absolute URIs and tries to convert the first URI as a relative path -->
      <xsl:param name="uri-to-revise" as="xs:string?"/>
      <xsl:param name="uri-to-revise-against" as="xs:string?"/>
      <xsl:param name="base-uri" as="xs:string?"/>
      <xsl:variable name="uri-a-resolved"
         select="
            if (tan:is-valid-uri($uri-to-revise)) then
               resolve-uri($uri-to-revise, $base-uri)
            else
               ()"
      />
      <xsl:variable name="uri-b-resolved"
         select="
            if (tan:is-valid-uri($uri-to-revise)) then
               resolve-uri($uri-to-revise-against, $base-uri)
            else
               ()"
      />
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
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:uri-relative-to()'"/>
         <xsl:message select="'uri to revise', $uri-to-revise"/>
         <xsl:message select="'uri to revise against', $uri-to-revise-against"/>
         <xsl:message select="'path a: ', $path-a"/>
         <xsl:message select="'path b: ', $path-b"/>
      </xsl:if>
      
      <xsl:choose>
         <xsl:when test="matches($uri-to-revise, '^https?://')">
            <xsl:value-of select="$uri-to-revise"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="string-join($new-path-a/tan:step, '/')"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:template match="node() | @*" mode="uri-relative-to">
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="@href" mode="uri-relative-to">
      <xsl:param name="base-uri" tunnel="yes" as="xs:string?"/>
      <xsl:variable name="this-base-uri"
         select="
            if (string-length($base-uri) gt 0) then
               $base-uri
            else
               tan:base-uri(.)"
      />
      <xsl:variable name="this-href-revised" select="tan:uri-relative-to(., $this-base-uri)"/>
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics on, template mode uri-relative-to'"/>
         <xsl:message select="'This @href:', ."/>
         <xsl:message select="'This base uri: ', $this-base-uri"/>
         <xsl:message select="'This href revised: ', $this-href-revised"/>
      </xsl:if>
      
      <xsl:attribute name="href" select="$this-href-revised"/>
   </xsl:template>
   
   
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
      <!-- Input: a node from an XML file; a boolean indicating whether bad @hrefs should be stripped -->
      <!-- Output: the TAN catalog documents available, beginning with the most local path and proceeding rootward -->
      <xsl:param name="input-node" as="node()?"/>
      <xsl:param name="strip-bad-hrefs" as="xs:boolean"/>
      <xsl:variable name="these-uris" select="tan:catalog-uris($input-node)"/>
      <xsl:for-each select="$these-uris">
         <xsl:choose>
            <xsl:when test="$strip-bad-hrefs">
               <xsl:variable name="this-uri" select="."/>
               <xsl:variable name="this-doc" select="doc(.)"/>
               <xsl:variable name="these-hrefs" select="$this-doc//@href[tan:is-valid-uri(.)]"/>
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
      <!-- One-parameter version of the master one, below -->
      <xsl:param name="catalog-docs" as="document-node()*"/>
      <xsl:copy-of select="tan:collection($catalog-docs, (), (), ())"/>
   </xsl:function>
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
            <root>TAN-A</root>
            <root>TAN-A-tok</root>
            <root>TAN-A-lm</root>
         </class>
         <class n="3">
            <root>TAN-mor</root>
            <root>TAN-voc</root>
            <root>TAN-c</root>
         </class>
      </tan>
   </xsl:variable>
   <xsl:function name="tan:tan-type" as="xs:string*">
      <!-- Input: any nodes -->
      <!-- Output: the names of the root elements; if not present, a zero-length string is returned -->
      <xsl:param name="nodes" as="node()*"/>
      <xsl:for-each select="$nodes/root()/*">
         <xsl:value-of select="name(.)"/>
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
            name($node/parent::node())) = $names-of-elements-that-must-always-refer-to-tan-files)
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

   <xsl:function name="tan:get-doc-history" as="element()*">
      <!-- Input: any TAN document -->
      <!-- Output: a sequence of elements with @when, @ed-when, @accessed-when, @claim-when, sorted from most recent to least; each element includes @when-sort, a decimal that represents the value of the most recent time-date stamp in that element -->
      <xsl:param name="TAN-doc" as="document-node()*"/>
      <xsl:for-each select="$TAN-doc">
         <xsl:variable name="doc-hist-raw" as="element()*">
            <xsl:apply-templates mode="get-doc-history"/>
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
   <xsl:template match="* | text() | comment() | processing-instruction() | document-node()"
      mode="get-doc-history">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <!-- We deeply skip anything that wasn't in the original -->
   <xsl:template match="tan:tan-vocabulary | tan:inclusion/tei:* | tan:inclusion/tan:TAN-T | tan:inclusion/tan:TAN-A | tan:inclusion/tan:TAN-A-tok | tan:inclusion/tan:TAN-A-lm | tan:inclusion/tan:TAN-mor | tan:inclusion/tan:TAN-voc" mode="get-doc-history"/>
   <xsl:template match="*[@when or @ed-when or @accessed-when or @claim-when]"
      mode="get-doc-history">
      <xsl:variable name="these-dates" as="xs:decimal*"
         select="
            for $i in (@when | @ed-when | @accessed-when | @claim-when)
            return
               tan:dateTime-to-decimal($i)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="when-sort" select="max($these-dates)"/>
         <xsl:copy-of select="text()[matches(., '\S')]"/>
      </xsl:copy>
      <xsl:apply-templates mode="#current"/>
   </xsl:template>

   <xsl:function name="tan:doc-id-namespace" as="xs:string?">
      <!-- Input: a TAN-doc -->
      <!-- Output: the namespace of the doc's @id -->
      <xsl:param name="TAN-doc" as="document-node()?"/>
      <xsl:variable name="this-id" select="$TAN-doc/*/@id"/>
      <xsl:if test="string-length($this-id) gt 0">
         <xsl:analyze-string select="$this-id" regex="^tag:[^:]+">
            <xsl:matching-substring>
               <xsl:value-of select="."/>
            </xsl:matching-substring>
         </xsl:analyze-string>
      </xsl:if>
   </xsl:function>

   <xsl:function name="tan:last-change-agent" as="element()*">
      <!-- Input: any TAN document -->
      <!-- Output: the <person>, <organization>, or <algorithm> who made the last change -->
      <xsl:param name="TAN-doc" as="document-node()*"/>
      <xsl:for-each select="$TAN-doc">
         <xsl:variable name="this-doc" select="."/>
         <xsl:variable name="this-doc-history" select="tan:get-doc-history(.)"/>
         <xsl:variable name="this-doc-head" select="$this-doc/*/tan:head"/>
         <xsl:variable name="last-change" select="$this-doc-history/*[@who][1]"/>
         <xsl:if test="exists($this-doc-head)">
            <xsl:copy-of
               select="tan:vocabulary(('person', 'organization', 'algorithm'), $last-change/@who, $this-doc/*/tan:head)/*"
            />
         </xsl:if>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:all-conditions-hold" as="xs:boolean?">
      <!-- 2-param version of the master one, below -->
      <xsl:param name="element-with-condition-attributes" as="element()?"/>
      <xsl:param name="context-to-evaluate-against" as="item()*"/>
      <xsl:copy-of
         select="tan:all-conditions-hold($element-with-condition-attributes, $context-to-evaluate-against, (), true())"
      />
   </xsl:function>
   <xsl:function name="tan:all-conditions-hold" as="xs:boolean">
      <!-- Input: a TAN element with attributes that should be checked for their truth value; a context against which to check the values; an optional sequence of strings indicates the names of elements that should be processed and in what order; a boolean indicating what value to return by default -->
      <!-- Output: true, if every condition holds; false otherwise -->
      <!-- If no conditions are found, the output reverts to the default -->
      <xsl:param name="element-with-condition-attributes" as="element()?"/>
      <xsl:param name="context-to-evaluate-against" as="item()*"/>
      <xsl:param name="evaluation-sequence" as="xs:string*"/>
      <xsl:param name="default-value" as="xs:boolean"/>
      <xsl:variable name="element-with-condition-attributes-sorted-and-distributed" as="element()*">
         <xsl:for-each select="$element-with-condition-attributes/@*">
            <xsl:sort select="(index-of($evaluation-sequence, name(.)), 999)[1]"/>
            <where>
               <xsl:copy-of select="."/>
            </where>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="loop-results" as="xs:boolean"
         select="tan:all-conditions-hold-evaluation-loop($element-with-condition-attributes-sorted-and-distributed, $context-to-evaluate-against, $default-value)"
      />
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:conditions-hold()'"/>
         <xsl:message select="'element with condition attributes: ', $element-with-condition-attributes"/>
         <xsl:message select="'context to evaluate against: ', $context-to-evaluate-against"/>
         <xsl:message select="'evaluation sequence: ', $evaluation-sequence"/>
         <xsl:message select="'conditions sorted and distributed: ', $element-with-condition-attributes-sorted-and-distributed"/>
         <xsl:message select="'loop results: ', $loop-results"/>
      </xsl:if>
      <xsl:value-of select="$loop-results"/>
   </xsl:function>
   <xsl:function name="tan:all-conditions-hold-evaluation-loop" as="xs:boolean">
      <!-- Companion function to the one above, indicating whether every condition holds -->
      <!-- It iterates through elements with condition attributes and checks each against the context; if a false is found, the loop ends 
         with a false; if no conditions are found the default value is returned; otherwise it returns true -->
      <!-- We use a loop function to avoid evaluating conditions that might be time-consuming -->
      <xsl:param name="elements-with-condition-attributes-to-be-evaluated" as="element()*"/>
      <xsl:param name="context-to-evaluate-against" as="item()*"/>
      <xsl:param name="current-value" as="xs:boolean"/>
      <xsl:choose>
         <xsl:when test="not(exists($elements-with-condition-attributes-to-be-evaluated))">
            <xsl:value-of select="$current-value"/>
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
               <xsl:when test="$this-analysis/@* = false()">
                  <xsl:copy-of select="false()"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of
                     select="tan:all-conditions-hold-evaluation-loop($elements-with-condition-attributes-to-be-evaluated[position() gt 1], $context-to-evaluate-against, true())"
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
   <!-- 
      CORE POINTING METHODS
         Vocabulary items: @xml:id, @id, <name>. This is the most common kind of pointing in a TAN file.
         Elements (breadcrumbs): @q may be added to each element in a TAN file when it is first resolved. This unique id value helps tie the parts of an expansions to its original (critically important for basic validation). Because the value is unpredictable, no ref can be constructed until the ids are generated.
         
      CLASS 2 TO CLASS 1 POINTING METHODS
         div refs. Each <div> in a class 1 file has one or more values for @n. References to that <div> consist of all permutations of those @n values (converted when possible to Arabic numerals) and those of its ancestors. When a class 1 file each one of those references is placed in an initial child <ref>. This is the main way class 2 documents refer to parts of class 1 documents, be means of @ref. Because this reference system pertains to class 2 documents, functions will be found in stylesheets that include this one, e.g., TAN-class-2-functions.xsl
         token refs. Class 2 files may refer to a specific token by number (@pos) or value/regular expression (@val/@rgx), in conjunction with the token definition being used.
         character refs. Class 2 files may refer to specific characters by number. 
   -->

   <xsl:key name="q-ref" match="*" use="@q"/>
   <xsl:function name="tan:q-ref" as="xs:string*">
      <!-- Input: any elements -->
      <!-- Output: the q-ref of each element-->
      <!-- A q-ref is defined as a concatenated string consisting of, for each ancestor and self, the name plus the number indicating which sibling it is of that type of element. -->
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

   <xsl:function name="tan:takes-idrefs" as="xs:boolean+">
      <!-- Input: any attributes -->
      <!-- Output: booleans, whether it takes idrefs or not -->
      <xsl:param name="attributes" as="attribute()+"/>
      <xsl:for-each select="$attributes">
         <xsl:value-of select="exists(tan:target-element-names(.))"/>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:target-element-names" as="xs:string*">
      <!-- Input: any strings, attributes, or elements -->
      <!-- Output: the names of the elements pointed to, if the name or the value of the input is the name of an element or attribute that takes idrefs -->
      <xsl:param name="items" as="item()*"/>
      <xsl:for-each select="$items">
         <xsl:variable name="this-item" select="."/>
         <xsl:variable name="this-item-val-norm" select="normalize-space($this-item)"/>
         <xsl:choose>
            <xsl:when test="$this-item instance of xs:string and string-length($this-item-val-norm) gt 0">
               <xsl:variable name="this-idref-entry"
                  select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs[(@element, @attribute) = $this-item-val-norm]]"/>
               <xsl:copy-of select="$this-idref-entry/tan:element/text()"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="this-is-attribute" select=". instance of attribute()"/>
               <xsl:variable name="this-is-element" select=". instance of element()"/>
               <xsl:variable name="this-name" select="name(.)"/>
               <xsl:variable name="this-parent-name" select="name(..)"/>
               <xsl:choose>
                  <xsl:when test="$this-name = 'which'">
                     <!-- @which always points to an element that has the name as its parent, and perhaps some other elements, as defined at TAN-idrefs.xml -->
                     <xsl:variable name="this-idref-entry"
                        select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs[@element = $this-parent-name]]"
                     />
                     <xsl:copy-of select="$this-parent-name, $this-idref-entry/tan:element/text()"/>
                  </xsl:when>
                  <xsl:when test="$this-is-element">
                     <xsl:variable name="this-idref-entry"
                        select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs[@element = $this-name]]"/>
                     <xsl:copy-of select="$this-name, $this-idref-entry/tan:element/text()"/>
                  </xsl:when>
                  <xsl:when test="$this-is-attribute">
                     <xsl:variable name="this-idref-entry"
                        select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs[@attribute = $this-name]]"/>
                     <xsl:copy-of select="$this-idref-entry/tan:element/text()"/>
                  </xsl:when>
               </xsl:choose>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:element-vocabulary" as="element()*">
      <!-- Input: elements, assumed to be tethered to their resolved document context -->
      <!-- Output: the vocabulary items for that element's attributes (@which, etc.) -->
      <!-- See full tan:vocabulary() function below -->
      <xsl:param name="element" as="element()*"/>
      <xsl:copy-of select="tan:attribute-vocabulary($element/@*)"/>
   </xsl:function>

   <xsl:function name="tan:attribute-vocabulary" as="element()*">
      <!-- Input: attributes, assumed to be tethered to their resolved document context -->
      <!-- Output: the vocabulary items for that element's attributes (@which, etc.) -->
      <!-- See full tan:vocabulary() function below -->
      <xsl:param name="attributes" as="attribute()*"/>
      <xsl:variable name="pass-1" as="element()*">
         <xsl:for-each-group select="$attributes[tan:takes-idrefs(.)]" group-by="tan:base-uri(.)">
            <!-- Group attributes first by document... -->
            <xsl:variable name="this-base-uri" select="current-grouping-key()"/>
            <xsl:variable name="this-root" select="current-group()/root()"/>
            <xsl:variable name="this-local-head" select="$this-root/*/tan:head"/>
            <xsl:for-each-group select="current-group()"
               group-by="
                  if (exists(ancestor::*[@include]) and not(name(.) = 'include')) then
                     tokenize(ancestor::*[@include][last()]/@include, '\s+')
                  else
                     ''">
               <!-- ...and then by inclusion... -->
               <!-- (inclusion is key because an included idref value might mean something completely different than what it means in the host document) -->
               <xsl:variable name="this-include-id" select="current-grouping-key()"/>
               <!-- Only TAN-A files (so far) allow @xml:id in the body, making them candidates for vocabulary -->
               <xsl:variable name="these-vocabulary-nodes"
                  select="
                     if (string-length($this-include-id) gt 0) then
                        $this-local-head/tan:inclusion[@xml:id = $this-include-id]
                     else
                        $this-local-head, $this-root/tan:TAN-A/tan:body"
               />
               <xsl:for-each-group select="current-group()" group-by="name(.)">
                  <!-- ...and then by the attribute name -->
                  <xsl:variable name="this-attribute-name" select="current-grouping-key()"/>
                  <xsl:variable name="this-is-which" select="$this-attribute-name = 'which'"/>
                  <!-- @which allows only one value, and spaces are allowed; in all other attributes a space separates distinct values (an underbar replacing a space in a <name>)-->
                  <xsl:variable name="these-attribute-values"
                     select="
                        if ($this-is-which) then
                           tan:normalize-name(current-group())
                        else
                           current-group()"
                  />
                  <xsl:variable name="target-element-names"
                     select="distinct-values(tan:target-element-names(current-group()))"/>
                  <xsl:variable name="diagnostics-on" select="false()"/>
                  <xsl:if test="$diagnostics-on">
                     <xsl:message select="'diagnostics on for tan:attribute-vocabulary()'"/>
                     <xsl:message select="'base uri: ', $this-base-uri"/>
                     <xsl:message select="'include id (if any): ', $this-include-id"/>
                     <xsl:message select="'attribute name: ', $this-attribute-name"/>
                     <xsl:message select="'attribute values: ', distinct-values(current-group())"/>
                     <xsl:message select="'target element names: ', $target-element-names"/>
                     <xsl:message select="'vocabulary nodes (shallow copy): ', tan:shallow-copy($these-vocabulary-nodes, 2)"/>
                  </xsl:if>
                  <xsl:copy-of
                     select="tan:vocabulary($target-element-names, $these-attribute-values, $these-vocabulary-nodes)"
                  />
               </xsl:for-each-group>
            </xsl:for-each-group>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:copy-of select="tan:distinct-items($pass-1)"/>
   </xsl:function>

   <xsl:function name="tan:vocabulary" as="element()*">
      <!-- 2-param version of fuller one below -->
      <xsl:param name="target-element-names" as="xs:string*"/>
      <xsl:param name="target-values" as="xs:string*"/>
      <xsl:copy-of select="tan:vocabulary($target-element-names, $target-values, $doc-vocabulary)"/>
   </xsl:function>

   <xsl:function name="tan:vocabulary" as="element()*">
      <!-- Input: two sequences of zero or more strings; a sequence of elements representing the ancestor of vocabulary in a resolved TAN file-->
      <!-- Output: the vocabulary items for the particular elements whose names match the first sequence and whose id, alias, or
         name values match the second sequence, found in descendants of the elements provided by the third sequence -->
      <!-- If either of the first two sequences are empty, or have an *, it is assumed that all possible values
      are sought. Therefore if the first two parameters are empty, the entire vocabulary will be returned -->
      <!-- The second parameter is assumed to have one value per item in the sequence. This is mandatory because it is designed to take two different types of values: @which (which is a single value and permits spaces) and other attributes (which can be multiple values, and spaces delimit values) -->
      <!-- If you approach this function with an attribute that points to elements, and you must first to retrieve that attribute's elements, you should run tan:target-element-names() beforehand to generate a list of element names that should be targeted -->
      <!-- It is assumed that the elements are the result of a fully resolved TAN file. -->
      <!-- If a value matches id or alias, no matches on name will be sought (locally redefined ids override name values) -->
      <!-- This function does not mark apparant errors, e.g., vocabulary items missing, or more than one for a single value -->
      <!-- If you are trying to work with vocabulary from an included document, the $resolved-vocabulary-ancestors should point exclusively to content (not self) of the appropriate resolved tan:include -->
      <xsl:param name="target-element-names" as="xs:string*"/>
      <xsl:param name="target-values" as="xs:string*"/>
      <xsl:param name="resolved-vocabulary-ancestors" as="element()*"/>

      <xsl:variable name="fetch-elements-named-whatever"
         select="(count($target-element-names) lt 1) or ($target-element-names = '*')"/>
      <!--<xsl:variable name="target-element-names-norm" as="xs:string*"
         select="tan:target-element-names($target-element-names)"/>-->

      <xsl:variable name="values-space-normalized"
         select="
            for $i in $target-values
            return
               normalize-space($i)"
      />
      <xsl:variable name="fetch-all-values"
         select="(count($values-space-normalized) lt 1) or ($target-values = ('')) or ($values-space-normalized = '*')"
      />
      
      <xsl:variable name="vocabulary-pass-1" as="element()*">
         <xsl:choose>
            <xsl:when test="$fetch-all-values">
               <xsl:apply-templates select="$resolved-vocabulary-ancestors"
                  mode="vocabulary-all-vals">
                  <xsl:with-param name="element-names" tunnel="yes" as="xs:string*"
                     select="
                        if ($fetch-elements-named-whatever) then
                           ()
                        else
                           $target-element-names"
                  />
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates select="$resolved-vocabulary-ancestors" mode="vocabulary-by-id">
                  <xsl:with-param name="element-names" tunnel="yes" as="xs:string*"
                     select="
                        if ($fetch-elements-named-whatever) then
                           ()
                        else
                           $target-element-names"
                  />
                  <xsl:with-param name="idrefs" tunnel="yes" as="xs:string*"
                     select="$values-space-normalized"/>
               </xsl:apply-templates>
               
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="values-not-yet-matched" select="$values-space-normalized[not(. = $vocabulary-pass-1//tan:match/tan:idref)]"/>
      <xsl:variable name="remaining-values-normalized-as-names" select="tan:normalize-name($values-not-yet-matched)"/>
      <xsl:variable name="vocabulary-pass-2" as="element()*">
         <xsl:if test="not($fetch-all-values) and exists($values-not-yet-matched)">
            <xsl:apply-templates select="$resolved-vocabulary-ancestors" mode="vocabulary-by-name">
               <xsl:with-param name="element-names" tunnel="yes" as="xs:string*"
                  select="
                     if ($fetch-elements-named-whatever) then
                        ()
                     else
                        $target-element-names"/>
               <xsl:with-param name="name-values" tunnel="yes" as="xs:string*"
                  select="$remaining-values-normalized-as-names"/>
            </xsl:apply-templates>
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="element-name-priority" as="xs:string+" select="('match', 'vocabulary', 'tan-vocabulary', 'inclusion')"/>
      <xsl:variable name="vocabulary-synthesis" as="element()*">
         <xsl:for-each-group select="$vocabulary-pass-1, $vocabulary-pass-2" group-by="name(.)">
            <xsl:sort select="index-of($element-name-priority, current-grouping-key())"/>
            <xsl:choose>
               <xsl:when test="current-grouping-key() = 'match'">
                  <local>
                     <xsl:copy-of select="tan:distinct-items(current-group()/(* except (tan:idref, tan:name-value)))"
                     />
                  </local>
               </xsl:when>
               <xsl:when test="current-grouping-key() = $element-name-priority">
                  <xsl:for-each-group select="current-group()[tan:match]" group-by="tan:IRI[1]">
                     <xsl:element name="{name(current-group()[1])}"
                        namespace="tag:textalign.net,2015:ns">
                        <xsl:copy-of select="current-group()[1]/(tan:IRI, tan:name, tan:desc)"/>
                        <xsl:copy-of
                           select="tan:distinct-items(current-group()/tan:match/(* except (tan:idref, tan:name-value)))"
                        />
                     </xsl:element>
                  </xsl:for-each-group>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:message select="'unclear what to do with these'"/>
                  <miscellaneous>
                     <xsl:copy-of select="tan:distinct-items(current-group())"/>
                  </miscellaneous>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group> 
      </xsl:variable>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics on for tan:vocabulary()'"/>
         <xsl:message select="'Target element names: ', $target-element-names"/>
         <xsl:message select="'Target values:', $target-values"/>
         <xsl:message select="'Resolved vocabulary ancestors:', $resolved-vocabulary-ancestors"/>
         <xsl:message select="'Fetch elements no matter their name?', $fetch-elements-named-whatever"/>
         <xsl:message select="'Target all values?', $fetch-all-values"/>
         <xsl:message select="'Values space-normalized:', $values-space-normalized"/>
         <xsl:message select="'Vocabulary pass 1 matches: ', $vocabulary-pass-1//tan:match"/>
         <xsl:message select="'Values not yet matched: ', $values-not-yet-matched"/>
         <xsl:message select="'Remaining values normalized: ', $remaining-values-normalized-as-names"/>
         <xsl:message select="'Vocabulary pass 2 matches: ', $vocabulary-pass-2//tan:match"/>
      </xsl:if>
      <xsl:copy-of select="$vocabulary-synthesis"/>
   </xsl:function>

   <xsl:template match="*" mode="vocabulary-all-vals vocabulary-by-id vocabulary-by-name">
      <!-- vocab trawling shallow skips by default -->
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <!-- vocab trawling ignores nested inclusion documents (but not <inclusion> itself) -->
   <xsl:template match="tan:inclusion/*/tan:head/tan:inclusion/*[tan:head]" priority="1"
      mode="vocabulary-all-vals vocabulary-by-id vocabulary-by-name"/>
   
   <xsl:template match="text() | comment() | processing-instruction()"
      mode="vocabulary-all-vals vocabulary-by-id vocabulary-by-name"/>
   <xsl:template priority="1" match="tan:vocabulary | tan:tan-vocabulary"
      mode="vocabulary-all-vals vocabulary-by-id vocabulary-by-name">
      <xsl:copy>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template priority="1"
      match="tan:vocabulary/tan:IRI | tan:vocabulary/tan:name | tan:vocabulary/tan:location | 
                    tan:tan-vocabulary/tan:IRI | tan:tan-vocabulary/tan:name | tan:tan-vocabulary/tan:location"
      mode="vocabulary-all-vals vocabulary-by-id vocabulary-by-name">
      <xsl:copy>
         <xsl:copy-of select="@* except @q"/>
         <xsl:value-of select="."/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="*[tan:IRI] | tan:token-definition | tan:item[tan:token-definition] | tan:claim" mode="vocabulary-all-vals">
      <xsl:param name="element-names" tunnel="yes" as="xs:string*"/>
      <xsl:variable name="element-name-matches" select="not(exists($element-names)) or (name(.), tan:affects-element) = $element-names"/>
      <xsl:if test="$element-name-matches">
         <match>
            <xsl:copy-of select="."/>
         </match>
      </xsl:if>
   </xsl:template>
   <!-- In the next template do not include *[tan:alias] in @match, as that will trip up on tan:vocabulary-key -->
   <xsl:template match="*[tan:id][tan:IRI] | tan:claim[tan:id]" mode="vocabulary-by-id">
      <xsl:param name="element-names" tunnel="yes" as="xs:string*"/>
      <xsl:param name="idrefs" tunnel="yes" as="xs:string*"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="element-name-matches" select="not(exists($element-names)) or (name(.), tan:affects-element) = $element-names"/>
      <!-- nonexistent parameters means anything for that value is allowed -->
      <xsl:variable name="matching-idrefs" select="$idrefs[. = $this-element/(tan:id, tan:alias)]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode vocabulary-by-id'"/>
         <xsl:message select="'This element: ', $this-element"/>
         <xsl:message select="'Idrefs: ', $idrefs"/>
         <xsl:message select="'Element names: ', $element-names"/>
         <xsl:message select="'Element name match?', $element-name-matches"/>
         <xsl:message select="'Matching idrefs:', $matching-idrefs"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="$element-name-matches and (not(exists($idrefs)) or exists($matching-idrefs))">
            <match>
               <xsl:for-each select="$matching-idrefs">
                  <idref>
                     <xsl:value-of select="."/>
                  </idref>
               </xsl:for-each>
               <xsl:copy-of select="."/>
            </match>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="#current"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="*[tan:IRI][tan:name] | tan:token-definition | tan:item[tan:token-definition]" mode="vocabulary-by-name">
      <xsl:param name="element-names" tunnel="yes" as="xs:string*"/>
      <xsl:param name="name-values" tunnel="yes" as="xs:string*"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="element-name-matches" select="not(exists($element-names)) or (name(.), tan:affects-element) = $element-names"/>
      <xsl:variable name="matching-name-values" select="$name-values[. = $this-element/tan:name]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode vocabulary-by-name'"/>
         <xsl:message select="'This element: ', $this-element"/>
         <xsl:message select="'Element names: ', $element-names"/>
         <xsl:message select="'Element name match?', $element-name-matches"/>
         <xsl:message select="'Name values: ', $name-values"/>
         <xsl:message select="'Matching name values:', $matching-name-values"/>
      </xsl:if>
      <xsl:if test="$element-name-matches and (not(exists($name-values)) or exists($matching-name-values))">
         <match>
            <xsl:for-each select="$matching-name-values">
               <name-value>
                  <xsl:value-of select="."/>
               </name-value>
            </xsl:for-each>
            <xsl:copy-of select="."/>
         </match>
      </xsl:if>
   </xsl:template>


   <!-- FUNCTIONS: TAN-SPECIFIC: FILE PROCESSING: RETRIEVAL, RESOLUTION, EXPANSION, AND MERGING -->

   <!-- Step 1: is it available? -->
   <xsl:function name="tan:first-loc-available" as="xs:string?">
      <!-- Input: An element that is or contains one or more tan:location elements -->
      <!-- Output: the value of the first tan:location/@href to point to a document available, resolved. If no location is available nothing is returned. -->
      <xsl:param name="element-with-href-in-self-or-descendants" as="element()?"/>
      <xsl:value-of select="tan:first-loc-available-loop($element-with-href-in-self-or-descendants//@href, 0)"/>
   </xsl:function>
   <xsl:function name="tan:first-loc-available-loop" as="xs:string?">
      <xsl:param name="href-attributes" as="attribute()*"/>
      <xsl:param name="loop-counter" as="xs:integer"/>
      <xsl:choose>
         <xsl:when test="$loop-counter gt $loop-tolerance">
            <xsl:message select="'loop tolerance exceeded in tan:first-loc-available()'"/>
         </xsl:when>
         <xsl:when test="not(exists($href-attributes))"/>
         <xsl:otherwise>
            <xsl:variable name="this-href-attribute" select="$href-attributes[1]"/>
            <xsl:variable name="this-href-is-local" select="tan:url-is-local($this-href-attribute)"/>
            <xsl:variable name="this-href-fetches-something"
               select="
                  if ($this-href-is-local or $internet-available)
                  then
                     doc-available($this-href-attribute)
                  else
                     false()"
            />
            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'diagnostics on for tan:first-loc-available-loop(), loop #', $loop-counter"/>
               <xsl:message select="'this href attribute: ', $this-href-attribute"/>
               <xsl:message select="'this href is local? ', $this-href-is-local"/>
               <xsl:message select="'internet available? ', $internet-available"/>
               <xsl:message select="'doc available? ', doc-available($this-href-attribute)"/>
               <xsl:message select="'this href fetches something? ', $this-href-fetches-something"/>
            </xsl:if>
            <xsl:choose>
               <xsl:when test="$this-href-fetches-something">
                  <xsl:value-of select="$this-href-attribute"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="tan:first-loc-available-loop($href-attributes[position() gt 1], ($loop-counter + 1))"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <!-- Step 2: if so, get it -->
   <xsl:function name="tan:url-is-local" as="xs:boolean">
      <xsl:param name="url-to-test" as="xs:string?"/>
      <xsl:choose>
         <xsl:when test="string-length($url-to-test) gt 0">
            <xsl:value-of select="not(matches($url-to-test, '^(https?|ftp)://'))"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="true()"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:function name="tan:get-1st-doc" as="document-node()*">
      <!-- Input: any TAN elements naming files (e.g., <source>, <see-also>, <inclusion>, <vocabulary> -->
      <!-- Output: the first document available for each element, plus any relevant error messages. -->
      <xsl:param name="TAN-elements" as="element()*"/>
      <xsl:for-each select="$TAN-elements">
         <xsl:variable name="this-element" select="."/>
         <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
         <xsl:variable name="this-element-resolved" as="element()?">
            <xsl:choose>
               <xsl:when test="exists($this-element//@href)">
                  <xsl:sequence select="$this-element"/>
               </xsl:when>
               <xsl:when test="exists(@which)">
                  <xsl:copy-of select="tan:element-vocabulary($this-element)/tan:item"/>
               </xsl:when>
            </xsl:choose>
         </xsl:variable>
         <xsl:variable name="this-element-norm" as="element()*">
            <xsl:apply-templates select="$this-element-resolved" mode="resolve-href">
               <xsl:with-param name="base-uri" tunnel="yes" select="$this-base-uri"/>
            </xsl:apply-templates>
         </xsl:variable>
         <xsl:variable name="is-master-location" select="exists(self::tan:master-location)"/>
         <xsl:variable name="is-see-also" select="exists(self::tan:see-also)"/>
         <xsl:variable name="this-class" select="tan:class-number(.)"/>
         <xsl:variable name="first-la" select="tan:first-loc-available($this-element-norm)"/>
         <xsl:variable name="this-id" select="root(.)/*/@id"/>
         <xsl:variable name="these-hrefs" select="$this-element-norm//@href"/>
         <xsl:variable name="some-href-is-local"
            select="
               some $i in $these-hrefs
                  satisfies tan:url-is-local($i)"/>
         <xsl:variable name="diagnostics-on" select="false()"/>
         <xsl:if test="$diagnostics-on">
            <xsl:message select="'diagnostics on for tan:get-1st-doc()'"/>
            <xsl:message select="'this element: ', $this-element"/>
            <xsl:message select="'this element root: ', tan:shallow-copy(root(.)/*)"/>
            <xsl:message select="'this base uri: ', $this-base-uri"/>
            <xsl:message select="'this element resolved: ', $this-element-resolved"/>
            <xsl:message select="'this element normalized: ', $this-element-norm"/>
            <xsl:message select="'some @href is local?', $some-href-is-local"/>
            <xsl:message select="'first location available: ', $first-la"/>
         </xsl:if>
         <xsl:choose>
            <xsl:when test="not(exists($these-hrefs))"/>
            <xsl:when test="string-length($first-la) lt 1">
               <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
               <xsl:variable name="these-hrefs-resolved" select="tan:resolve-href(.)"/>
               <xsl:variable name="these-tan-catalog-uris"
                  select="
                     for $i in $these-hrefs-resolved//@href
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
               <xsl:variable name="this-message-raw" as="xs:string*">
                  <xsl:value-of select="concat('No XML document found found at ', string-join($these-hrefs, ' '))"/>
                  <xsl:if test="exists($possible-hrefs)">
                     <xsl:value-of
                        select="concat(' For @href try: ', string-join($possible-hrefs/@href, ', '))"
                     />
                  </xsl:if>
                  <!--<xsl:value-of select="for $i in $these-hrefs return concat(' uri local? ', tan:url-is-local($i))"/>-->
               </xsl:variable>
               <xsl:variable name="this-message" select="string-join($this-message-raw, '')"/>
               <xsl:document>
                  <xsl:choose>
                     <xsl:when test="not($some-href-is-local) and not($internet-available)">
                        <xsl:copy-of select="tan:error('wrn09')"/>
                     </xsl:when>
                     <xsl:when test="self::tan:inclusion">
                        <xsl:copy-of
                           select="tan:error('inc04', $this-message, $possible-hrefs, 'replace-attributes')"
                        />
                     </xsl:when>
                     <xsl:when test="self::tan:vocabulary">
                        <xsl:copy-of
                           select="tan:error('whi04', $this-message, $possible-hrefs, 'replace-attributes')"
                        />
                     </xsl:when>
                     <xsl:when test="self::tan:master-location">
                        <xsl:copy-of
                           select="tan:error('wrn01', $this-message, $possible-hrefs, 'replace-attributes')"
                        />
                     </xsl:when>
                     <!-- Skip <source> in class 1 files when the URL points to non-XML. -->
                     <xsl:when
                        test="
                           self::tan:source and ($this-class = 1) and (some $i in $these-hrefs
                              satisfies ((unparsed-text-available($i))) or doc-available(concat('zip:', $i, '!/_rels/.rels')))"
                     />
                     <xsl:when
                        test="self::tan:source and not(exists(tan:location)) and tan:tan-type(.) = 'TAN-mor'"/>
                     <xsl:when test="self::tan:algorithm or self::tan:see-also">
                        <xsl:copy-of
                           select="tan:error('loc04', $this-message, $possible-hrefs, 'replace-attributes')"
                        />
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:copy-of
                           select="tan:error('loc01', $this-message, $possible-hrefs, 'replace-attributes')"
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
                     <!-- If the @id is identical, something is terribly wrong; to avoid possible endless recursion, the document is not returned -->
                     <xsl:document>
                        <error>
                           <xsl:copy-of select="$this-doc/*/@*"/>
                           <xsl:copy-of select="tan:error('tan16')/@*"/>
                           <xsl:copy-of select="tan:error('tan16')/*"/>
                        </error>
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
      <!-- Templates will be placed in the appropriate function file, e.g., class 1 merge templates are in TAN-class-1-functions.xsl -->
      <!-- Class 1 merging: All <div>s with the same <ref> values are grouped together. If the class 1 files are sources of a class 2 file, it is assumed that all actions in the <adjustments> have already been performed. -->
      <!-- Class 2 merging: TBD -->
      <!-- Class 3 merging: TBD -->
      <!-- NB: Class 1 files must have their hierarchies in proper order; use reset-hierarchy beforehand if you're unsure -->
      <xsl:param name="expanded-docs" as="document-node()*"/>
      <xsl:apply-templates select="$expanded-docs[1]" mode="merge-tan-docs">
         <xsl:with-param name="documents-to-merge" select="$expanded-docs[position() gt 1]"/>
      </xsl:apply-templates>
   </xsl:function>
   
   <!-- As of November 2019, merging is not defined for class 2 or class 3 files. When they are developed, some of the
   templates in TAN-class-1-functions.xsl may migrate here. -->
   
   <xsl:template match="document-node()" mode="merge-tan-docs">
      <xsl:param name="documents-to-merge" as="document-node()*"/>
      <xsl:document>
         <xsl:copy-of select="$documents-to-merge/*/preceding-sibling::node()"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="elements-to-merge" select="$documents-to-merge/*"/>
         </xsl:apply-templates>
         <xsl:copy-of select="$documents-to-merge/*/following-sibling::node()"/>
      </xsl:document>
   </xsl:template>
   

</xsl:stylesheet>
