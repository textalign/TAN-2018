<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0" 
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="2.0">

   <!-- Core functions for class 1 files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <!-- The following key presumes that the class 1 document has been expanded at least tersely -->
   <xsl:key name="div-via-ref" match="tan:div" use="tan:ref/text()"/>
   <xsl:key name="div-via-orig-ref" match="tan:div"
      use="(tan:ref/tan:orig-ref, tan:ref[not(tan:orig-ref)]/text())"/>

   <!-- CLASS 1 GLOBAL VARIABLES -->

   <xsl:variable name="tokenization-nonspace"
      select="$token-definitions-reserved[following-sibling::tan:name = 'nonspace']"/>
   <xsl:variable name="dependency-vocabulary-should-be-resolved" select="true()"/>

   <!-- redivisions -->
   <xsl:variable name="redivisions-1st-da" select="tan:get-1st-doc($head/tan:redivision)"/>
   <!--<xsl:variable name="redivisions-resolved"
      select="tan:resolve-doc($redivisions-1st-da, false(), 'redivision', (), $dependency-vocabulary-should-be-resolved)"/>-->
   <xsl:variable name="redivisions-resolved"
      select="tan:resolve-doc($redivisions-1st-da, false(), tan:attr('relationship', 'redivision'))"/>

   <!-- models -->
   <xsl:variable name="model-1st-da" select="tan:get-1st-doc($head/tan:model[1])"/>
   <!--<xsl:variable name="model-resolved"
      select="tan:resolve-doc($model-1st-da, false(), 'model', (), $dependency-vocabulary-should-be-resolved)"/>-->
   <xsl:variable name="model-resolved"
      select="tan:resolve-doc($model-1st-da, false(), tan:attr('relationship', 'model'))"/>

   <!-- annotations -->
   <xsl:variable name="annotations-1st-da" select="tan:get-1st-doc($head/tan:annotation)"/>
   <!--<xsl:variable name="annotations-resolved"
      select="tan:resolve-doc($annotations-1st-da, false(), 'annotation', (), $dependency-vocabulary-should-be-resolved)"/>-->
   <xsl:variable name="annotations-resolved"
      select="tan:resolve-doc($annotations-1st-da, false(), tan:attr('relationship', 'annotation'))"/>



   <!-- CLASS 1 FUNCTIONS: TEXT -->

   <xsl:variable name="special-end-div-chars" select="($zwj, $dhy)" as="xs:string+"/>
   <xsl:variable name="special-end-div-chars-regex"
      select="concat('\s*[', string-join($special-end-div-chars, ''), ']\s*$')" as="xs:string"/>
   <!-- regular expression to detect parts of a transcription that specify a line, column, or page break; these should be excluded from transcriptions and be rendered with markup -->
   <xsl:param name="break-marker-regex">[\|‖  ⁣￺]</xsl:param>


   <xsl:function name="tan:text-join" as="xs:string?">
      <!-- Input: any document fragment of a TAN class 1 body, whether raw, resolved, or expanded  -->
      <!-- Output: a single string that joins and normalizes the leaf div text according to TAN rules -->
      <!-- All special leaf-div-end characters will be stripped, except the last -->
      <xsl:param name="items" as="item()*"/>
      <xsl:variable name="results" as="element()">
         <results>
            <xsl:apply-templates select="$items" mode="text-join"/>
         </results>
      </xsl:variable>
      <xsl:value-of select="$results"/>
   </xsl:function>
   <xsl:template match="* | text()" mode="text-join">
      <xsl:apply-templates select="*" mode="#current"/>
   </xsl:template>
   <xsl:template match="*:div[not(*:div)]" mode="text-join">
      <xsl:variable name="nonspace-text-nodes" select="text()[matches(., '\S')]"/>
      <xsl:variable name="is-not-last-leaf-div"
         select="exists(following::*:div[not(*:div)][text()[matches(., '\S')] or tan:tok or tei:*])"/>
      <xsl:variable name="text-nodes-to-process" as="xs:string*">
         <xsl:choose>
            <xsl:when test="exists(tan:tok)">
               <xsl:sequence select="(tan:tok, tan:non-tok)/text()"/>
            </xsl:when>
            <xsl:when test="exists(tei:*)">
               <xsl:value-of select="normalize-space(string-join(descendant::tei:*/text(), ''))"/>
            </xsl:when>
            <xsl:when test="exists($nonspace-text-nodes)">
               <!--<xsl:variable name="text-nodes" select="text()"/>-->
               <!--<xsl:variable name="text-node-count" select="count($text-nodes)"/>-->
               <!--<xsl:value-of select="string-join($text-nodes, '')"/>-->
               <xsl:sequence select="text()"/>
               <!--<xsl:value-of select="normalize-space(string-join(text(), ''))"/>-->
            </xsl:when>
         </xsl:choose>
      </xsl:variable>
      <!--<xsl:if test="exists($text-nodes-to-process) and (@type = ('s','par','ic'))">
         <xsl:message select="., $is-not-last-leaf-div"/></xsl:if>-->
      <xsl:value-of select="tan:normalize-div-text($text-nodes-to-process, $is-not-last-leaf-div)"/>
   </xsl:template>

   <xsl:function name="tan:normalize-div-text" as="xs:string*">
      <!-- One-parameter version of the fuller one, below. -->
      <xsl:param name="single-leaf-div-text-nodes" as="xs:string*"/>
      <xsl:copy-of select="tan:normalize-div-text($single-leaf-div-text-nodes, false())"/>
   </xsl:function>
   <xsl:function name="tan:normalize-div-text" as="xs:string*">
      <!-- Input: any sequence of strings, presumed to be text nodes of a single leaf div; a boolean indicating whether special div-end characters should be retained or not -->
      <!-- Output: the same sequence, normalized according to TAN rules. Each item in the sequence is space normalized and then if its end matches one of the special div-end characters, ZWJ U+200D or SOFT HYPHEN U+AD, the character is removed; otherwise a space is added at the end. Zero-length strings are skipped. -->
      <!-- This function is designed specifically for TAN's commitment to nonmixed content. That is, every TAN element contains either elements or non-whitespace text but not both, which also means that whitespace text nodes are effectively ignored. It is assumed that every TAN element is followed by a notional whitespace. -->
      <!-- The second parameter is important, because output will be used to normalize and repopulate leaf <div>s (where special div-end characters should be retained) or to concatenate leaf <div> text (where those characters should be deleted) -->
      <xsl:param name="single-leaf-div-text-nodes" as="xs:string*"/>
      <xsl:param name="remove-special-div-end-chars" as="xs:boolean"/>
      <xsl:variable name="nodes-joined-and-normalized" select="normalize-space(string-join($single-leaf-div-text-nodes, ''))"/>
      <xsl:variable name="nodes-end-with-special-div-chars" select="matches($nodes-joined-and-normalized, $special-end-div-chars-regex)"/>
      <xsl:variable name="join-end-normalized" as="xs:string*">
         <xsl:choose>
            <xsl:when test="$nodes-end-with-special-div-chars and $remove-special-div-end-chars">
               <xsl:value-of select="replace($nodes-joined-and-normalized, $special-end-div-chars-regex, '')"/>
            </xsl:when>
            <xsl:when test="$nodes-end-with-special-div-chars">
               <xsl:value-of select="replace($nodes-joined-and-normalized, $special-end-div-chars-regex, '$1')"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="concat($nodes-joined-and-normalized, ' ')"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:normalize-div-text()'"/>
         <xsl:message select="'remove special div-end characters? :', $remove-special-div-end-chars"/>
         <xsl:message select="'nodes joined and normalized: ', $nodes-joined-and-normalized"/>
         <xsl:message select="'results: ', string-join($join-end-normalized, '')"/>
      </xsl:if>
      <xsl:value-of select="string-join($join-end-normalized, '')"/>
   </xsl:function>

   <xsl:function name="tan:tokenize-div" as="item()*">
      <!-- Input: any items, a <token-definition> -->
      <!-- Output: the items with <div>s in tokenized form -->
      <xsl:param name="input" as="item()*"/>
      <xsl:param name="token-definitions" as="element(tan:token-definition)"/>
      <xsl:apply-templates select="$input" mode="tokenize-div">
         <xsl:with-param name="token-definitions" select="$token-definitions" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="tan:div[not((tan:div, tan:tok))]/text()" mode="tokenize-div">
      <xsl:param name="token-definition" as="element()?" tunnel="yes"/>
      <xsl:param name="add-q-attr" as="xs:boolean?" tunnel="yes"/>
      <xsl:param name="add-pos-attr" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="this-text" select="tan:normalize-div-text(., true())"/>
      <xsl:variable name="prev-leaf" select="preceding::tan:div[not(tan:div)][1]"/>
      <xsl:variable name="first-tok-is-fragment"
         select="matches($prev-leaf, $special-end-div-chars-regex)"/>
      <xsl:variable name="this-tokenized" as="element()*">
         <xsl:copy-of select="tan:tokenize-text($this-text, $token-definition, true(), $add-q-attr = true(), $add-pos-attr)"/>
      </xsl:variable>
      <xsl:variable name="last-tok" select="$this-tokenized/tan:tok[last()]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode tokenize-div'"/>
         <xsl:message select="'token definition: ', $token-definition"/>
         <xsl:message select="'first token is fragment?', $first-tok-is-fragment"/>
         <xsl:message select="'add @q?', $add-q-attr"/>
         <xsl:message select="'add @pos?', $add-pos-attr"/>
      </xsl:if>
      <xsl:if test="not($first-tok-is-fragment)">
         <xsl:copy-of select="$this-tokenized/*[xs:integer(@n) = 1]"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="matches(., $special-end-div-chars-regex)">
            <!-- get next token -->
            <xsl:variable name="next-leaf" select="following::tan:div[not(tan:div)][1]"/>
            <xsl:variable name="next-leaf-tokenized"
               select="tan:tokenize-text($next-leaf/text(), $token-definition, true())"/>
            <xsl:variable name="next-leaf-fragment"
               select="$next-leaf-tokenized/*[xs:integer(@n) = 1]"/>
            <xsl:copy-of select="$this-tokenized/*[xs:integer(@n) gt 1][not(@n = $last-tok/@n)]"/>
            <xsl:for-each-group select="($this-tokenized/*[@n = $last-tok/@n], $next-leaf-fragment)"
               group-adjacent="name(.)">
               <xsl:element name="{current-grouping-key()}">
                  <xsl:copy-of select="current-group()[1]/@*"/>
                  <xsl:value-of select="string-join(current-group(), '')"/>
               </xsl:element>
            </xsl:for-each-group>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="$this-tokenized/*[xs:integer(@n) gt 1]"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>




   <!-- CLASS 1 FUNCTIONS: FILE PROCESSING: EXPANSION, MERGING -->

   <!-- PROCESSING CLASS 1 DOCUMENTS -->

   <!-- EXPANDING -->

   <!-- TERSE EXPANSION -->

   <xsl:template match="tan:redivision" mode="core-expansion-terse">
      <xsl:variable name="these-iris" select="tan:IRI"/>
      <xsl:variable name="this-doc-work" select="/*/tan:head/tan:work"/>
      <xsl:variable name="this-doc-work-vocab"
         select="tan:vocabulary('work', $this-doc-work/@which, parent::tan:head)"/>
      <xsl:variable name="this-doc-source" select="/*/tan:head/tan:source"/>
      <xsl:variable name="this-doc-source-vocab"
         select="tan:vocabulary('work', $this-doc-source/@which, parent::tan:head)"/>
      <xsl:variable name="this-redivision-doc-resolved"
         select="$redivisions-resolved[*/@id = $these-iris]"/>
      <xsl:variable name="target-1st-da" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="target-doc-resolved"
         select="
            if (exists($this-redivision-doc-resolved)) then
               $this-redivision-doc-resolved
            else
               tan:resolve-doc($target-1st-da)"/>
      <xsl:variable name="target-doc-work" select="$target-doc-resolved/*/tan:head/tan:work"/>
      <xsl:variable name="target-doc-work-vocab"
         select="tan:vocabulary('work', $target-doc-work/@which, $target-doc-resolved/*/tan:head)"/>
      <xsl:variable name="target-doc-source" select="$target-doc-resolved/*/tan:head/tan:source"/>
      <xsl:variable name="target-doc-source-vocab"
         select="tan:vocabulary('source', $target-doc-source/@which, $target-doc-resolved/*/tan:head)"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics on, tan:redivision, template mode core-expansion-terse'"/>
         <xsl:message select="'Target doc resolved (shallow:) ', tan:shallow-copy($target-doc-resolved/*)"/>
         <xsl:message select="'This work vocab:', $this-doc-work-vocab"/>
         <xsl:message select="'This source vocab:', $this-doc-source-vocab"/>
         <xsl:message select="'Target doc work vocab:', $target-doc-work-vocab"/>
         <xsl:message select="'Target doc source vocab: ', $target-doc-source-vocab"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="not(($target-doc-source, $target-doc-source-vocab)//tan:IRI = ($this-doc-source, $this-doc-source-vocab)/tan:IRI)">
            <xsl:copy-of select="tan:error('cl101')"/>
         </xsl:if>
         <xsl:if
            test="not(($target-doc-work, $target-doc-work-vocab)//tan:IRI = ($this-doc-work, $this-doc-work-vocab)/tan:IRI)">
            <xsl:copy-of select="tan:error('cl102')"/>
         </xsl:if>
         <xsl:if
            test="
               exists(root()/*/tan:head/tan:version) and
               exists($target-doc-resolved/*/tan:head/tan:version) and
               not(root()/*/tan:head/tan:version/tan:IRI = $target-doc-resolved/*/tan:head/tan:version/tan:IRI)">
            <xsl:copy-of select="tan:error('cl103')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:model" mode="core-expansion-terse">
      <xsl:variable name="these-iris" select="tan:IRI"/>
      <xsl:variable name="this-doc-work" select="/*/tan:head/tan:work"/>
      <xsl:variable name="this-doc-work-vocab"
         select="tan:vocabulary('work', $this-doc-work/@which, parent::tan:head)"/>
      <xsl:variable name="this-model-doc-resolved" select="$model-resolved[*/@id = $these-iris]"/>
      <xsl:variable name="target-1st-da" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="target-doc-resolved"
         select="
            if (exists($this-model-doc-resolved)) then
               $this-model-doc-resolved
            else
               tan:resolve-doc($target-1st-da)"/>
      <xsl:variable name="target-doc-work" select="$target-doc-resolved/*/tan:head/tan:work"/>
      <xsl:variable name="target-doc-work-vocab"
         select="tan:vocabulary('work', $target-doc-work/@which, $target-doc-resolved/*/tan:head)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="not(($target-doc-work, $target-doc-work-vocab)//tan:IRI = ($this-doc-work, $this-doc-work-vocab)/tan:IRI)">
            <xsl:copy-of select="tan:error('cl102')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tei:teiHeader" mode="#all" priority="-4">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tei:div[not(tei:div)]/tei:*" priority="1"
      mode="resolve-numerals core-expansion-terse-attributes">
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="tan:TAN-T | tei:TEI"
      mode="core-expansion-terse dependency-adjustments-pass-1">
      <!-- Homogenize tei:TEI to tan:TAN-T -->
      <xsl:param name="class-2-doc" tunnel="yes" as="document-node()?"/>
      <xsl:variable name="vocabulary" select="$class-2-doc/*/tan:head/tan:vocabulary-key"/>
      <xsl:variable name="this-src-id" select="@src"/>
      <xsl:variable name="is-self" select="@id = $doc-id" as="xs:boolean"/>
      <xsl:variable name="this-work-group"
         select="$vocabulary/tan:group[tan:work/@src = $this-src-id]"/>
      <!--<xsl:variable name="these-div-types" select="tan:head/tan:vocabulary-key/tan:div-type"/>-->
      <xsl:variable name="this-last-change-agent" select="tan:last-change-agent(root(.))"/>

      <xsl:variable name="ambig-is-roman"
         select="not($class-2-doc/*/tan:head/tan:numerals/@priority = 'letters')"/>
      <xsl:variable name="n-alias-items"
         select="tan:head/tan:vocabulary/tan:item[tan:affects-attribute = 'n']"/>
      <xsl:variable name="these-adjustments"
         select="$class-2-doc/*/tan:head/tan:adjustments[(tan:src, tan:where/tan:src) = ($this-src-id, $all-selector)]"/>
      <xsl:variable name="these-adjustments-resolved" as="element()*">
         <xsl:apply-templates select="$these-adjustments" mode="resolve-numerals">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
            <xsl:with-param name="n-alias-items" select="$n-alias-items" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode: core-expansion-terse AND dependency-adjustments-pass-1'"/>
         <xsl:message select="'this root element: ', tan:shallow-copy(.)"/>
         <xsl:message select="'ambig is roman: ', $ambig-is-roman"/>
         <xsl:message select="'n alias items: ', $n-alias-items"/>
         <xsl:message select="'adjustments resolved: ', $these-adjustments-resolved"/>
      </xsl:if>
      <TAN-T>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($this-work-group)">
            <xsl:attribute name="work" select="$this-work-group/@n"/>
         </xsl:if>
         <xsl:if test="exists($this-last-change-agent/self::tan:algorithm)">
            <xsl:copy-of select="tan:error('wrn07', 'The last change was made by an algorithm.')"/>
         </xsl:if>
         <xsl:if test="(@TAN-version = $TAN-version) and $TAN-version-is-under-development">
            <xsl:copy-of select="tan:error('wrn04')"/>
         </xsl:if>
         <xsl:if test="not(@TAN-version = $TAN-version)">
            <xsl:variable name="conversion-tools-uri" select="'../../applications/convert/'"/>
            <xsl:variable name="this-message" as="xs:string*">
               <xsl:text>Should be version </xsl:text>
               <xsl:value-of select="$TAN-version"/>
               <xsl:if test="@TAN-version = $previous-TAN-versions">
                  <xsl:value-of
                     select="concat('; to convert older versions to the current one, try ', resolve-uri($conversion-tools-uri, static-base-uri()))"
                  />
               </xsl:if>
            </xsl:variable>
            <xsl:copy-of select="tan:error('tan20', string-join($this-message, ''))"/>
         </xsl:if>
         <expanded>terse</expanded>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="adjustment-actions-resolved" tunnel="yes"
               select="$these-adjustments-resolved/(tan:skip, tan:rename, tan:equate)"/>
         </xsl:apply-templates>
      </TAN-T>
   </xsl:template>
   <xsl:template match="tei:body" mode="core-expansion-terse dependency-adjustments-pass-1">
      <body>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </body>
   </xsl:template>
   <xsl:template match="tei:text" mode="core-expansion-terse dependency-adjustments-pass-1">
      <!-- Makes sure the tei:body rises rootward one level, as is customary in TAN and HTML -->
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <xsl:template match="tan:div | tei:div"
      mode="core-expansion-terse dependency-expansion-terse-no-adjustments">
      <!-- streamlined expansion of <div>s; applied to dependencies of class-2 files only when there are no more adjustment items to process -->
      <xsl:param name="parent-new-refs" as="element()*" select="$empty-element"/>
      <xsl:variable name="is-tei" select="namespace-uri() = 'http://www.tei-c.org/ns/1.0'"
         as="xs:boolean"/>
      <xsl:variable name="this-n-analyzed"
         select="
            if (exists(@n)) then
               tan:analyze-sequence(@n, 'n', true())
            else
               ()"
      />
      <xsl:variable name="new-refs" as="element()*">
         <xsl:for-each select="$parent-new-refs">
            <xsl:variable name="this-ref" select="."/>
            <xsl:for-each select="$this-n-analyzed/*">
               <ref>
                  <xsl:value-of select="string-join(($this-ref/text(), .), $separator-hierarchy)"/>
                  <xsl:copy-of select="$this-ref/*"/>
                  <n>
                     <xsl:value-of select="."/>
                  </n>
               </ref>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="is-leaf-div" select="not(exists(*:div))"/>
      <xsl:variable name="diagnostics-on" select="false()" as="xs:boolean"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode core-expansion-terse, for: ', ."/>
         <xsl:message select="$this-n-analyzed"/>
      </xsl:if>
      <div>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$this-n-analyzed/*"/>
         <xsl:copy-of select="$new-refs"/>
         <xsl:if
            test="
               some $i in $this-n-analyzed
                  satisfies matches(., '^0\d')">
            <xsl:copy-of select="tan:error('cl117')"/>
         </xsl:if>
         <xsl:apply-templates select="*" mode="#current">
            <xsl:with-param name="parent-new-refs" select="$new-refs"/>
         </xsl:apply-templates>
         <xsl:if test="$is-leaf-div">
            <xsl:choose>
               <xsl:when test="$is-tei">
                  <xsl:value-of select="tan:normalize-div-text(.//tei:*/text())"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="tan:normalize-div-text(text())"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
         <!--<xsl:value-of select="$text-normalized"/>-->
      </div>
   </xsl:template>

   <xsl:function name="tan:imprint-adjustment-locator" as="element()*">
      <!-- one-parameter version of the full one below -->
      <xsl:param name="adjustment-action-locators" as="element()*"/>
      <xsl:copy-of select="tan:imprint-adjustment-locator($adjustment-action-locators, ())"/>
   </xsl:function>
   <xsl:function name="tan:imprint-adjustment-locator" as="element()*">
      <!-- Input: any locator from an adjustment action (ref, n, div-type, from-tok, through-tok); any errors to report -->
      <!-- Output: the locator wrapped in its ancestral element and wrapping any errors -->
      <!-- This function is used to mark class 1 files with a record of locators in class 2 adjustments -->
      <xsl:param name="adjustment-action-locators" as="element()*"/>
      <xsl:param name="errors-to-report" as="element()*"/>
      <xsl:for-each select="$adjustment-action-locators">
         <xsl:variable name="this-locators-adjustment-action-ancestor"
            select="ancestor::*[name() = ('skip', 'rename', 'equate', 'reassign')]"/>
         <xsl:choose>
            <xsl:when test="exists($this-locators-adjustment-action-ancestor)">
               <xsl:element name="{name($this-locators-adjustment-action-ancestor)}">
                  <xsl:copy-of select="$this-locators-adjustment-action-ancestor/@*"/>
                  <xsl:copy>
                     <xsl:copy-of select="@*"/>
                     <xsl:copy-of select="$errors-to-report"/>
                     <xsl:copy-of select="node()"/>
                  </xsl:copy>
               </xsl:element>
            </xsl:when>
            <xsl:otherwise>
               <xsl:message select="'no adjustment ancestor is found for ', ."/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>
   <xsl:template match="tan:ref | tan:n | tan:div-type | tan:from-tok | tan:through-tok"
      mode="imprint-adjustment-action">
      <!-- This template is used to leave the imprint of a class-2 adjustment action within a class-1 file. -->
      <!-- It imprints both the ref, n, or div-type, wrapped in a copy of its parent (with attributes) -->
      <xsl:param name="errors" as="element()*"/>
      <xsl:variable name="this-locators-adjustment-action-ancestor"
         select="ancestor::*[parent::tan:adjustments]"/>
      <xsl:variable name="this-adjustment-action-name"
         select="
            if (exists($this-locators-adjustment-action-ancestor)) then
               name($this-locators-adjustment-action-ancestor)
            else
               'missing-action-name'"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode imprint-adjustment-action, for: ', ."/>
         <xsl:message select="'adjustment action name: ', $this-adjustment-action-name"/>
      </xsl:if>
      <xsl:element name="{$this-adjustment-action-name}">
         <xsl:copy-of select="$this-locators-adjustment-action-ancestor/@*"/>
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="text()"/>
            <xsl:copy-of select="$errors"/>
         </xsl:copy>
      </xsl:element>
   </xsl:template>


   <xsl:template match="tan:div | tei:div" mode="dependency-adjustments-pass-1">
      <!-- This template applies <skip>, <rename>, and <equate> in class 2 <adjustments> upon a dependency class 1 file. -->
      <!-- Errors in <adjustments> are embedded to report back to the dependent class 2 file. In those cases, the error is associated not with the specific instruction but its locator, i.e., the element + @q version of the the expanded forms of @div-type, @n, @ref. -->
      <xsl:param name="adjustment-actions-resolved" tunnel="yes" as="element()*"/>
      <xsl:param name="parent-orig-refs" as="element()*" select="$empty-element"/>
      <xsl:param name="parent-new-refs" as="element()*" select="$empty-element"/>

      <xsl:variable name="these-div-types-analyzed"
         select="tan:analyze-sequence(@type, 'type', false())"/>
      <xsl:variable name="these-ns-analyzed" select="tan:analyze-sequence(@n, 'n', true())"/>
      <xsl:variable name="these-refs-analyzed" as="element()*">
         <xsl:for-each select="$parent-new-refs">
            <xsl:variable name="this-ref" select="."/>
            <xsl:for-each select="$these-ns-analyzed/*">
               <ref>
                  <xsl:value-of select="string-join(($this-ref/text(), .), $separator-hierarchy)"/>
                  <xsl:copy-of select="$this-ref/*"/>
                  <xsl:copy-of select="."/>
               </ref>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>

      <xsl:variable name="these-adjustment-action-locators"
         select="
            $adjustment-actions-resolved/(tan:div-type[. = $these-div-types-analyzed/*],
            tan:n[. = $these-ns-analyzed/*], tan:ref[text() = $these-refs-analyzed/text()])"/>

      <xsl:variable name="skip-locators"
         select="$these-adjustment-action-locators[parent::tan:skip]"/>
      <xsl:variable name="first-skip-locator" select="$skip-locators[1]"/>
      <xsl:variable name="rename-locators"
         select="$these-adjustment-action-locators[parent::tan:rename]"/>
      <xsl:variable name="equate-locators"
         select="$these-adjustment-action-locators[parent::tan:equate]"/>

      <xsl:choose>
         <xsl:when test="exists($skip-locators)">
            <!-- Before any other adjustment, we deal with skips, the more drastic action. -->
            <!-- Leave the marker for the primary skip's locator  -->
            <xsl:copy-of select="tan:imprint-adjustment-locator($first-skip-locator)"/>
            <!-- error: excess skips -->
            <xsl:copy-of
               select="tan:imprint-adjustment-locator($skip-locators[position() gt 1], tan:error('cl214'))"/>
            <!-- error: a div is marked to be both skipped and renamed -->
            <xsl:copy-of
               select="tan:imprint-adjustment-locator($rename-locators, tan:error('cl218'))"/>
            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'diagnostics on, template mode dependency-adjustments-pass-1'"/>
               <xsl:message select="'adjustment actions resolved: ', $adjustment-actions-resolved"/>
               <xsl:message select="'skip locators: ', $skip-locators"/>
               <xsl:message select="'rename locators: ', $rename-locators"/>
            </xsl:if>
            <!-- if it's a shallow skip, keep going; otherwise drop out -->
            <xsl:if
               test="not(exists($first-skip-locator/../@shallow)) or $first-skip-locator/../@shallow = true()">
               <xsl:apply-templates select="*:div" mode="#current">
                  <!-- original refs retain this node's properties, even if it is being skipped, to trace refs based on the legacy system -->
                  <xsl:with-param name="parent-orig-refs" select="$these-refs-analyzed"/>
                  <xsl:with-param name="parent-new-refs" select="$parent-new-refs"/>
               </xsl:apply-templates>
            </xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <!-- We are not skipping, so now we can analyze <rename>, <equate> -->
            <xsl:variable name="is-tei" select="namespace-uri() = 'http://www.tei-c.org/ns/1.0'"
               as="xs:boolean"/>
            <xsl:variable name="rename-n-locators-overridden-by-rename-ref-locators"
               select="$rename-locators[self::tan:n = $rename-locators/self::tan:ref/tan:n[last()]]"/>
            <xsl:variable name="rename-locators-allowed"
               select="$rename-locators except $rename-n-locators-overridden-by-rename-ref-locators"/>
            <xsl:variable name="equate-locators-that-match-rename-locators"
               select="$equate-locators[. = $rename-locators/self::tan:n]"/>
            <xsl:variable name="duplicate-equate-locator-vals"
               select="tan:duplicate-items($equate-locators/text())"/>

            <!-- First, expand @n, doing any renaming or equating; this will be used to build <ref>, below -->
            <xsl:variable name="new-ns" as="element()*">
               <xsl:for-each select="$these-ns-analyzed/*">
                  <xsl:variable name="this-n" select="."/>
                  <xsl:variable name="this-n-rename-locators"
                     select="$rename-locators-allowed[self::tan:n = $this-n]"/>
                  <xsl:variable name="first-rename-locator" select="$this-n-rename-locators[1]"/>
                  <xsl:variable name="this-n-equate-locators" select="$equate-locators[. = $this-n]"/>
                  <xsl:variable name="these-n-equates" select="$this-n-equate-locators/parent::tan:equate"/>
                  <xsl:for-each select="$these-n-equates">
                     <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:copy-of select="tan:n[not(. = $these-ns-analyzed/*)]"/>
                     </xsl:copy>
                  </xsl:for-each>
                  <xsl:choose>
                     <!-- copy the value, unless there is a rename adjustment action to be performed -->
                     <xsl:when test="not(exists($first-rename-locator))">
                        <xsl:copy-of select="."/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:variable name="this-sibl-new" select="$first-rename-locator/../tan:new"/>
                        <xsl:variable name="this-sibl-by" select="$first-rename-locator/../tan:by"/>
                        <xsl:copy-of select="$this-sibl-new/tan:n"/>
                        <xsl:if test="exists($this-sibl-by) and ($this-n castable as xs:integer)">
                           <xsl:variable name="incr" select="xs:integer($this-sibl-by)"/>
                           <n>
                              <xsl:value-of select="xs:integer($this-n) + $incr"/>
                           </n>
                        </xsl:if>
                        <xsl:variable name="first-rename-errors" as="element()*">
                           <xsl:if test="$this-sibl-new = $this-n">
                              <xsl:copy-of select="tan:error('cl203')"/>
                           </xsl:if>
                           <xsl:if
                              test="exists($this-sibl-by) and not($this-n castable as xs:integer)">
                              <xsl:copy-of select="tan:error('cl213')"/>
                           </xsl:if>
                        </xsl:variable>
                        <xsl:copy-of select="tan:imprint-adjustment-locator($first-rename-locator)"
                        />
                     </xsl:otherwise>
                  </xsl:choose>
                  <!-- duplicate renames should be flagged -->
                  <xsl:variable name="duplicate-rename-errors"
                     select="tan:error('cl212', concat('duplicate renaming rules for @n ', $this-n, '; only the first has been applied'))"/>
                  <xsl:copy-of
                     select="tan:imprint-adjustment-locator($this-n-rename-locators[position() gt 1], $duplicate-rename-errors)"
                  />
               </xsl:for-each>
            </xsl:variable>

            <!-- Now take the new analysis of @n and create a set of references -->
            <!-- If there is a <rename> that causes a change in hierarchy, or changes any ancestral @ns, then flag the div with @reset, to indicate the div needs to be reset within the hierarchy -->
            <xsl:variable name="new-refs" as="element()*">
               <xsl:for-each select="$new-ns">
                  <!-- We take the text value because the <n>s might have <errors> inside -->
                  <xsl:variable name="this-n-val" select="descendant-or-self::tan:n/text()"/>
                  <xsl:for-each select="$parent-new-refs">
                     <xsl:variable name="this-parental-ref" select="text()"/>
                     <xsl:variable name="these-parental-ns" select="tan:n"/>
                     <xsl:variable name="this-ref"
                        select="string-join(($these-parental-ns, $this-n-val), $separator-hierarchy)"/>
                     <xsl:variable name="this-ref-rename-locator"
                        select="$rename-locators-allowed[self::tan:ref/text() = $this-ref]"/>
                     <xsl:variable name="first-rename-locator" select="$this-ref-rename-locator[1]"/>
                     <xsl:variable name="first-rename-locator-pos" select="count($first-rename-locator/preceding-sibling::tan:ref) + 1"/>
                     <ref>
                        <xsl:choose>
                           <!-- copy the value, unless there is a rename adjustment action to be performed -->
                           <xsl:when test="not(exists($first-rename-locator))">
                              <xsl:value-of select="$this-ref"/>
                              <xsl:copy-of select="$these-parental-ns"/>
                              <n>
                                 <xsl:value-of select="$this-n-val"/>
                              </n>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:variable name="this-sibl-new"
                                 select="$first-rename-locator/../tan:new"/>
                              <xsl:variable name="this-sibl-by"
                                 select="$first-rename-locator/../tan:by"/>
                              <xsl:choose>
                                 <xsl:when test="exists($this-sibl-new)">
                                    <xsl:variable name="these-new-parental-ns"
                                       select="$this-sibl-new/tan:ref[$first-rename-locator-pos]/tan:n[not(position() = last())]"/>
                                    <xsl:variable name="this-new-parental-ref"
                                       select="string-join($these-new-parental-ns, $separator-hierarchy)"/>
                                    <xsl:variable name="hierarchy-needs-to-be-reset"
                                       select="
                                          (count($these-parental-ns) ne count($these-new-parental-ns))
                                          or ((string-length($this-parental-ref) gt 0) and not($this-parental-ref = $this-new-parental-ref))"/>
                                    <xsl:if test="$hierarchy-needs-to-be-reset = true()">
                                       <xsl:attribute name="reset"/>
                                    </xsl:if>
                                    <xsl:copy-of select="$this-sibl-new/tan:ref[$first-rename-locator-pos]/node()"/>
                                 </xsl:when>
                                 <xsl:when
                                    test="exists($this-sibl-by) and ($this-n-val castable as xs:integer)">
                                    <xsl:variable name="incr" select="xs:integer($this-sibl-by)"/>
                                    <xsl:value-of select="xs:integer($this-n-val) + $incr"/>
                                 </xsl:when>
                                 <xsl:otherwise>
                                    <xsl:value-of select="$this-n-val"/>
                                 </xsl:otherwise>
                              </xsl:choose>
                              <!-- embed the first rename locator record -->
                              <xsl:variable name="first-rename-locator-errors" as="element()*">
                                 <xsl:if test="$this-sibl-new/tan:ref/text() = $this-ref">
                                    <xsl:copy-of select="tan:error('cl203')"/>
                                 </xsl:if>
                                 <xsl:if
                                    test="exists($this-sibl-by) and not($this-n-val castable as xs:integer)">
                                    <xsl:copy-of select="tan:error('cl213')"/>
                                 </xsl:if>
                              </xsl:variable>
                              <xsl:copy-of
                                 select="tan:imprint-adjustment-locator($first-rename-locator, $first-rename-locator-errors)"
                              />
                           </xsl:otherwise>
                        </xsl:choose>
                        <!-- duplicate renames should be flagged -->
                        <xsl:variable name="duplicate-rename-errors"
                           select="tan:error('cl212', concat('duplicate renaming rules for @ref ', $this-ref, '; only the first has been applied'))"/>
                        <xsl:copy-of
                           select="tan:imprint-adjustment-locator($this-ref-rename-locator[position() gt 1], $duplicate-rename-errors)"
                        />
                     </ref>
                  </xsl:for-each>
               </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="is-leaf-div" select="not(exists(*:div))"/>

            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'diagnostics on, template mode: dependency-adjustments-pass-1'"
               />
               <xsl:message select="'this div: ', tan:shallow-copy(.)"/>
               <xsl:message select="'original parent refs: ', $parent-orig-refs"/>
               <xsl:message select="'new parent refs: ', $parent-new-refs"/>
               <xsl:message select="'adjustment actions resolved: ', $adjustment-actions-resolved"/>
               <xsl:message select="'skip locators: ', $skip-locators"/>
               <xsl:message select="'rename locators: ', $rename-locators"/>
               <xsl:message select="'rename locators allowed: ', $rename-locators-allowed"/>
               <xsl:message select="'equate locators: ', $equate-locators"/>
               <xsl:message select="'div types analyzed: ', $these-div-types-analyzed"/>
               <xsl:message select="'div ns analyzed: ', $these-ns-analyzed"/>
               <xsl:message select="'div refs analyzed: ', $these-refs-analyzed"/>
               <xsl:message select="'new ns: ', $new-ns"/>
               <xsl:message select="'new refs: ', $new-refs"/>
            </xsl:if>

            <!-- Homogenize tei:div to tan:div -->
            <div>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="$new-ns"/>
               <xsl:copy-of select="$new-refs"/>
               <xsl:if
                  test="
                     some $i in $new-ns
                        satisfies matches($i, '^0')">
                  <xsl:copy-of select="tan:error('cl117')"/>
               </xsl:if>
               <xsl:copy-of
                  select="tan:imprint-adjustment-locator($rename-n-locators-overridden-by-rename-ref-locators, tan:error('cl206'))"/>
               <xsl:copy-of
                  select="tan:imprint-adjustment-locator($equate-locators-that-match-rename-locators, tan:error('cl204'))"/>
               <xsl:copy-of
                  select="tan:imprint-adjustment-locator($equate-locators[text() = $duplicate-equate-locator-vals], tan:error('cl205'))"/>
               <xsl:choose>
                  <xsl:when test="$is-leaf-div and $is-tei">
                     <xsl:apply-templates select="*" mode="#current"/>
                     <!-- If this is TEI, we add a plain text version of the text -->
                     <xsl:value-of select="tan:normalize-div-text(string-join(.//tei:*/text(), ''))"
                     />
                  </xsl:when>
                  <xsl:when test="$is-leaf-div">
                     <xsl:value-of select="tan:normalize-div-text(text())"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates mode="#current">
                        <xsl:with-param name="parent-orig-refs" select="$these-refs-analyzed"/>
                        <xsl:with-param name="parent-new-refs" select="$new-refs"/>
                     </xsl:apply-templates>
                  </xsl:otherwise>
               </xsl:choose>
            </div>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="* | comment() | processing-instruction()" mode="selective-shallow-skip">
      <xsl:param name="nodes-to-deep-copy" tunnel="yes"/>
      <xsl:param name="nodes-to-deep-skip" tunnel="yes"/>
      <xsl:choose>
         <xsl:when
            test="
               some $i in $nodes-to-deep-skip
                  satisfies deep-equal($i, .)"
         />
         <xsl:when
            test="
               some $i in $nodes-to-deep-copy
                  satisfies deep-equal($i, .)">
            <xsl:copy-of select="."/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="#current"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="tei:lb | tei:pb | tei:cb"
      mode="core-expansion-terse dependency-adjustments-pass-1 normalize-tei-space">
      <xsl:variable name="leaf-div" select="ancestor::tei:div[1]"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="div-text-pass-1" as="element()">
         <text>
            <xsl:apply-templates select="$leaf-div" mode="selective-shallow-skip">
               <xsl:with-param name="nodes-to-deep-copy" tunnel="yes" select="$this-element"/>
               <xsl:with-param name="nodes-to-deep-skip" tunnel="yes" select="$leaf-div/tan:type"/>
            </xsl:apply-templates>
         </text>
      </xsl:variable>
      <xsl:variable name="prev-text-joined" select="$div-text-pass-1/text()[1]"/>
      <xsl:variable name="next-text-joined" select="$div-text-pass-1/text()[2]"/>
      <xsl:variable name="break-mark-check" as="element()?">
         <xsl:if test="string-length($prev-text-joined) gt 0">
            <xsl:analyze-string select="$prev-text-joined" regex="{$break-marker-regex}\s*$"
               flags="x">
               <xsl:matching-substring>
                  <match>
                     <xsl:value-of select="."/>
                  </match>
               </xsl:matching-substring>
            </xsl:analyze-string>
         </xsl:if>
         <xsl:if test="string-length($next-text-joined) gt 0">
            <xsl:analyze-string select="$next-text-joined" regex="^\s*{$break-marker-regex}"
               flags="x">
               <xsl:matching-substring>
                  <match>
                     <xsl:value-of select="."/>
                  </match>
               </xsl:matching-substring>
            </xsl:analyze-string>
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="text-should-be-joined" select="@break = ('no', 'n', 'false')"
         as="xs:boolean"/>
      <xsl:variable name="element-has-adjacent-space"
         select="
            (if (string-length($prev-text-joined) lt 1) then
               true()
            else
               matches($prev-text-joined, '\s$'))
            or (if (string-length($next-text-joined) lt 1) then
               true()
            else
               matches($next-text-joined, '^\s'))"
      />
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($break-mark-check) and not(exists(@rend))">
            <xsl:variable name="this-message"
               select="concat($break-mark-check/tan:match, ' looks like a break mark')"/>
            <xsl:copy-of select="tan:error('tei04', $this-message)"/>
         </xsl:if>
         <xsl:if test="not($text-should-be-joined) and not($element-has-adjacent-space)">
            <xsl:copy-of select="tan:error('tei05', concat('prev text: [', $prev-text-joined, ']; next text: [', $next-text-joined, ']'))"/>
         </xsl:if>
         <xsl:if test="$text-should-be-joined and $element-has-adjacent-space">
            <xsl:copy-of select="tan:error('tei06')"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:div[not(tan:div)]/text()" mode="dependency-adjustments-pass-1">
      <xsl:variable name="is-last-text-node" select="not(exists(following-sibling::text()))"/>
      <xsl:value-of select="tan:normalize-div-text(., $is-last-text-node)"/>
   </xsl:template>
   <xsl:template match="tan:div/comment()" mode="dependency-adjustments-pass-1"/>

   <!-- Especially for class-2 sources: reset hierarchy -->

   <xsl:key name="divs-to-reset" match="tan:div" use="tan:ref/@reset"/>

   <xsl:template match="/" mode="reset-hierarchy">
      <xsl:param name="divs-to-reset" tunnel="yes" as="element()*"/>
      <xsl:param name="process-entire-document" tunnel="yes" as="xs:boolean?"/>
      <xsl:variable name="this-src" select="*/@src"/>
      <xsl:variable name="these-divs-to-reset" select="$divs-to-reset[root()/*/@src = $this-src]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode: reset-hierarchy'"/>
         <xsl:message select="'divs to reset: ', $these-divs-to-reset"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="($process-entire-document = true()) or exists($these-divs-to-reset)">
            <xsl:document>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="divs-to-reset" select="$these-divs-to-reset" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:document>
         </xsl:when>
         <xsl:otherwise>
            <xsl:sequence select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tan:head" mode="reset-hierarchy">
      <xsl:copy-of select="."/>
   </xsl:template>

   <!-- We need to get rid of any nested divs marked for resetting -->
   <xsl:template match="tan:div[tan:ref/@reset]" mode="reset-hierarchy clean-reset-divs-2"/>

   <xsl:template match="tan:body | tan:div" mode="reset-hierarchy">
      <!-- Each item in $divs-to-reset will fall into one of four categories:
         1 those that should be children of a sibling div (to be ignored)
         2 those that should be incorporated into a descendant div (to be passed on)
         3 those that should be merged with the current div (merge with current)
         4 everything else (to be added as final children)
      -->
      <xsl:param name="fragmented-siblings" as="element()*"/>
      <xsl:param name="divs-to-reset" tunnel="yes"/>
      <xsl:variable name="these-ns" select="tan:n"/>
      <xsl:variable name="these-refs"
         select="
            if (self::tan:body) then
               ''
            else
               tan:ref/text()"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="is-leaf-div" select="not(exists(tan:div))" as="xs:boolean"/>
      <xsl:variable name="this-n-level" select="count(tan:ref[1]/tan:n)"/>
      <xsl:variable name="next-n-level" select="$this-n-level + 1"/>
      <xsl:variable name="next-ns" select="tan:div[not(tan:ref/@reset)]/tan:n"/>

      <!-- fragments -->
      <xsl:variable name="relevant-fragments"
         select="$fragmented-siblings[tan:ref/text() = $these-refs]"/>
      <xsl:variable name="first-fragment" select="$relevant-fragments[1]"/>
      <xsl:variable name="missing-fragments" select="$relevant-fragments[not(@q = $this-q)]"/>
      <xsl:variable name="this-self"
         select="
            if (exists($relevant-fragments)) then
               $relevant-fragments
            else
               ."/>
      <xsl:variable name="children-divs-to-group" select="$this-self/tan:div"/>
      <xsl:variable name="children-divs-grouped"
         select="tan:group-elements-by-shared-node-values($children-divs-to-group, '^ref$', true())"
         as="element()*"/>
      <xsl:variable name="fragmented-children" as="element()*"
         select="$children-divs-grouped[count(tan:div) gt 1]/tan:div"/>

      <!-- divs to reset -->
      <xsl:variable name="divs-to-reset-that-belong-to-siblings"
         select="
            if (self::tan:body) then
               ()
            else
               $divs-to-reset[tan:ref[tan:n[$this-n-level][not(. = $these-ns)]]]"/>
      <xsl:variable name="divs-to-reset-of-interest"
         select="$divs-to-reset except $divs-to-reset-that-belong-to-siblings"/>
      <xsl:variable name="divs-to-reset-to-pass-on-to-children"
         select="$divs-to-reset-of-interest[tan:ref[tan:n[$next-n-level] = $next-ns][count(tan:n) gt $this-n-level]]"/>
      <xsl:variable name="divs-to-reset-to-merge"
         select="$divs-to-reset-of-interest[tan:ref[tan:n[$this-n-level] = $these-ns][count(tan:n) eq $this-n-level]]"/>
      <xsl:variable name="divs-to-reset-to-copy-here"
         select="$divs-to-reset-of-interest except ($divs-to-reset-to-pass-on-to-children, $divs-to-reset-to-merge)"/>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode reset-hierarchy, for: ', ."/>
         <xsl:message select="'level in hierarchy: ', $this-n-level"/>
         <xsl:message
            select="'other div fragments that correspond to this div: ', $missing-fragments"/>
         <xsl:message select="'children divs grouped: ', $children-divs-grouped"/>
         <xsl:message select="'fragmented children: ', $fragmented-children"/>
         <xsl:message
            select="'divs to reset that belong to siblings: ', $divs-to-reset-that-belong-to-siblings"/>
         <xsl:message
            select="'divs to reset to pass on to children: ', $divs-to-reset-to-pass-on-to-children"/>
         <xsl:message select="'divs to reset to merge: ', $divs-to-reset-to-merge"/>
         <xsl:message select="'divs to reset to copy here: ', $divs-to-reset-to-copy-here"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:choose>
            <xsl:when test="exists($relevant-fragments) and not($this-q = $first-fragment/@q)">
               <xsl:comment select="'merged with div @q= ', $first-fragment/@q"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- check for errors in mixing leaf and non-leaf divs -->
               <xsl:choose>
                  <xsl:when test="$is-leaf-div">
                     <xsl:variable name="missing-non-leaf-fragments"
                        select="$missing-fragments[tan:div]"/>
                     <xsl:variable
                        name="missing-non-leaf-fragments-first-adjustment-action-locators"
                        select="$missing-non-leaf-fragments/(self::tan:div, tan:ref)/(tan:rename, tan:reassign)[1]/(tan:ref, tan:n)"/>
                     <xsl:variable name="non-leaf-divs-to-reset-that-must-be-copied-or-merged"
                        select="$divs-to-reset-to-pass-on-to-children, $divs-to-reset-to-merge[tan:div], $divs-to-reset-to-copy-here"/>
                     <xsl:variable
                        name="non-leaf-divs-to-reset-that-must-be-copied-or-merged-first-adjustment-action-locators"
                        select="$non-leaf-divs-to-reset-that-must-be-copied-or-merged/(self::tan:div, tan:ref)/(tan:rename, tan:reassign)[1]/tan:ref"/>
                     <xsl:if test="$diagnostics-on">
                        <xsl:message
                           select="'missing non-leaf fragments: ', $missing-non-leaf-fragments"/>
                        <xsl:message
                           select="'first adjustment action locators in missing non-leaf fragments: ', $missing-non-leaf-fragments-first-adjustment-action-locators"/>
                        <xsl:message
                           select="'non-leaf divs to reset that must be copied or merged: ', $non-leaf-divs-to-reset-that-must-be-copied-or-merged"/>
                        <xsl:message
                           select="'first adjustment action locators in non-leaf divs to reset that must be copied or merged: ', $non-leaf-divs-to-reset-that-must-be-copied-or-merged-first-adjustment-action-locators"
                        />
                     </xsl:if>
                     <xsl:copy-of
                        select="tan:imprint-adjustment-locator($missing-non-leaf-fragments-first-adjustment-action-locators, tan:error('cl217'))"/>
                     <xsl:copy-of
                        select="tan:imprint-adjustment-locator($non-leaf-divs-to-reset-that-must-be-copied-or-merged-first-adjustment-action-locators, tan:error('cl217'))"
                     />
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:variable name="missing-leaf-fragments"
                        select="$missing-fragments[not(tan:div)]"/>
                     <xsl:variable name="missing-leaf-fragments-first-adjustment-action-locators"
                        select="$missing-leaf-fragments/(self::tan:div, tan:ref)/(tan:rename, tan:reassign)[1]/(tan:ref, tan:n)"/>
                     <xsl:variable name="leaf-divs-to-reset-that-must-be-copied-or-merged"
                        select="$divs-to-reset-to-merge[not(tan:div)]"/>
                     <xsl:variable
                        name="leaf-divs-to-reset-that-must-be-copied-or-merged-first-adjustment-action-locators"
                        select="$leaf-divs-to-reset-that-must-be-copied-or-merged/(self::tan:div, tan:ref)/(tan:rename, tan:reassign)[1]/tan:ref"/>
                     <xsl:if test="$diagnostics-on">
                        <xsl:message select="'missing leaf fragments: ', $missing-leaf-fragments"/>
                        <xsl:message
                           select="'first adjustment action locators in missing leaf fragments: ', $missing-leaf-fragments-first-adjustment-action-locators"/>
                        <xsl:message
                           select="'leaf divs to reset that must be copied or merged: ', $leaf-divs-to-reset-that-must-be-copied-or-merged"/>
                        <xsl:message
                           select="'first adjustment action locators in leaf divs to reset that must be copied or merged: ', $leaf-divs-to-reset-that-must-be-copied-or-merged-first-adjustment-action-locators"
                        />
                     </xsl:if>
                     <xsl:copy-of
                        select="tan:imprint-adjustment-locator($missing-leaf-fragments-first-adjustment-action-locators, tan:error('cl217'))"/>
                     <xsl:copy-of
                        select="tan:imprint-adjustment-locator($leaf-divs-to-reset-that-must-be-copied-or-merged-first-adjustment-action-locators, tan:error('cl217'))"
                     />
                  </xsl:otherwise>
               </xsl:choose>
               <xsl:apply-templates select="$this-self/(* except (tan:tok, tan:non-tok))"
                  mode="#current">
                  <xsl:with-param name="fragmented-siblings" select="$fragmented-children"/>
                  <xsl:with-param name="divs-to-reset"
                     select="$divs-to-reset-to-pass-on-to-children, $divs-to-reset-to-merge/tan:div"
                     tunnel="yes"/>
               </xsl:apply-templates>
               <xsl:for-each select="$divs-to-reset-to-merge/tan:ref">
                  <xsl:copy>
                     <xsl:copy-of select="@* except @reset"/>
                     <xsl:attribute name="has-been-reset"/>
                     <xsl:copy-of select="node()"/>
                  </xsl:copy>
               </xsl:for-each>
               <xsl:copy-of select="$this-self/(text(), tan:tok, tan:non-tok)"/>
               <xsl:copy-of select="$divs-to-reset-to-merge/(text(), tan:tok, tan:non-tok)"/>
               <!--<xsl:value-of select="tan:normalize-div-text((text(), $divs-to-merge/(self::*, tan:tok, tan:non-tok)/text()))"/>-->
               <xsl:apply-templates select="$divs-to-reset-to-copy-here" mode="clean-reset-divs-1">
                  <xsl:with-param name="level" select="$next-n-level"/>
               </xsl:apply-templates>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:div" mode="clean-reset-divs-1">
      <xsl:param name="level" as="xs:integer"/>
      <xsl:choose>
         <!-- If an orphaned div is say 4 levels deep and has been placed as a child of the first level, then some dummy <div>s need to be built up to represent the hierarchy -->
         <xsl:when test="count(tan:ref[1]/tan:n) gt $level">
            <div>
               <xsl:for-each select="tan:ref">
                  <xsl:copy>
                     <xsl:value-of select="text()"/>
                     <xsl:copy-of select="tan:n[position() le $level]"/>
                  </xsl:copy>
               </xsl:for-each>
               <xsl:apply-templates select="." mode="#current">
                  <xsl:with-param name="level" select="$level + 1"/>
               </xsl:apply-templates>
            </div>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:attribute name="has-been-reset"/>
               <xsl:apply-templates mode="clean-reset-divs-2"/>
            </xsl:copy>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <!-- Remove any @reset or temporarily added attribute -->
   <xsl:template match="tan:ref" mode="clean-reset-divs-2">
      <xsl:copy>
         <xsl:copy-of select="@* except (@reset)"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>


   <!-- 2nd pass of adjustments for class-2 sources: tokenize selectively, apply <reassign>s -->

   <xsl:template match="/" mode="dependency-adjustments-pass-2">
      <xsl:param name="class-2-doc" tunnel="yes" as="document-node()?"/>
      <xsl:variable name="this-src-id" select="*/@src"/>
      <xsl:variable name="this-token-definition"
         select="($class-2-doc/*/tan:head/tan:token-definition[tan:src = $this-src-id], $token-definition-default)[1]"/>

      <xsl:variable name="ambig-is-roman"
         select="not($class-2-doc/*/tan:head/tan:numerals/@priority = 'letters')"/>
      <xsl:variable name="n-alias-items"
         select="tan:TAN-T/tan:head/tan:vocabulary/tan:item[tan:affects-attribute = 'n']"/>
      <xsl:variable name="these-reassigns"
         select="$class-2-doc/*/tan:head/tan:adjustments[(tan:src, tan:where/tan:src) = ($this-src-id, $all-selector)]/tan:reassign"/>
      <xsl:variable name="these-reassigns-resolved" as="element()*">
         <xsl:apply-templates select="$these-reassigns" mode="resolve-numerals">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
            <xsl:with-param name="n-alias-items" select="$n-alias-items" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode dependency-adjustments-pass-2, for: ', tan:shallow-copy(*)"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="exists($these-reassigns)">
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'applying reassigns to ', $this-src-id"/>
               <xsl:message select="'reassigns (resolved): ', $these-reassigns-resolved"/>
               <xsl:message select="'token definition: ', $this-token-definition"/>
            </xsl:if>
            <xsl:document>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="adjustment-reassigns" select="$these-reassigns-resolved"
                     tunnel="yes"/>
                  <xsl:with-param name="token-definition" select="$this-token-definition"
                     tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:document>
         </xsl:when>
         <xsl:otherwise>
            <xsl:sequence select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tan:head" mode="dependency-adjustments-pass-2">
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="tan:div" mode="dependency-adjustments-pass-2">
      <!-- We do not break the template out according to leaf divs and non-leaf divs because in the course of renaming, mixed <div>s might have been created -->
      <xsl:param name="adjustment-reassigns" as="element()*" tunnel="yes"/>
      <xsl:param name="token-definition" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-div" select="."/>
      <xsl:variable name="these-ns" select="tan:n"/>
      <xsl:variable name="this-n-level" select="count(tan:ref[1]/tan:n)"/>
      <xsl:variable name="next-n-level" select="$this-n-level + 1"/>
      <xsl:variable name="next-ns" select="tan:div[not(tan:ref/@reset)]/tan:n"/>
      <!-- During adjustments pass 1, it is possible that non-leaf <div>s were moved into leaf <div>s or vice versa, 
         so the test is not whether there is text or <tok>s but whether there are <div>s -->
      <xsl:variable name="is-leaf-div" select="not(exists(tan:div))"/>
      <xsl:variable name="these-refs" select="tan:ref/text()"/>
      <xsl:variable name="these-reassign-adjustments"
         select="$adjustment-reassigns[tan:passage/tan:ref/text() = $these-refs]"/>
      <xsl:variable name="reassigns-to-pass-to-children"
         select="$adjustment-reassigns[tan:passage/tan:ref[tan:n[$this-n-level] = $these-ns][tan:n[$next-n-level] = $next-ns]]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message
            select="'diagnostics on, template mode dependency-adjustments-pass-2, for: ', ."/>
         <xsl:message select="'these reassigns: ', $these-reassign-adjustments"/>
         <xsl:message select="'reassigns to pass to children: ', $reassigns-to-pass-to-children"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="count($adjustment-reassigns) lt 1">
            <xsl:copy-of select="."/>
         </xsl:when>
         <xsl:when test="not($is-leaf-div)">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of
                  select="tan:imprint-adjustment-locator($these-reassign-adjustments/tan:passage/tan:ref[text() = $these-refs], tan:error('rea04'))"/>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="adjustment-reassigns" tunnel="yes"
                     select="$reassigns-to-pass-to-children"/>
               </xsl:apply-templates>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="text-tokenized"
               select="tan:tokenize-text(text(), $token-definition, true())"/>
            <xsl:variable name="previous-ref-renames" select="$this-div/tan:rename"/>
            <xsl:variable name="reassigns-with-passages-expanded" as="element()*">
               <xsl:apply-templates select="$these-reassign-adjustments" mode="expand-reassigns">
                  <xsl:with-param name="text-tokenized" select="$text-tokenized" tunnel="yes"/>
                  <xsl:with-param name="restrict-to-refs" select="$these-refs" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:variable name="duplicate-tok-ns"
               select="
                  tan:duplicate-items(for $i in $reassigns-with-passages-expanded/tan:passage
                  return
                     distinct-values($i//tan:tok/@n))"
            />
            <xsl:variable name="passages-with-faulty-locators"
               select="$reassigns-with-passages-expanded/tan:passage[exists(.//tan:error)]"/>
            <xsl:variable name="overlapping-passages"
               select="$reassigns-with-passages-expanded/tan:passage[.//tan:tok/@n = $duplicate-tok-ns]"/>
            <xsl:variable name="actionable-passages"
               select="$reassigns-with-passages-expanded/tan:passage except ($passages-with-faulty-locators, $overlapping-passages)"/>
            <xsl:variable name="text-tokenized-and-marked" as="element()*">
               <!-- imprint <passage q=""/> within each <tok> and <non-tok>, a simple grouping key for the next stage -->
               <xsl:apply-templates select="$text-tokenized" mode="mark-reassigns">
                  <xsl:with-param name="reassign-passages-expanded" select="$actionable-passages"
                     tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'text tokenized: ', $text-tokenized"/>
               <xsl:message select="'previous renames: ', $previous-ref-renames"/>
               <xsl:message select="'reassigns expanded: ', $reassigns-with-passages-expanded"/>
               <xsl:message select="'duplicates of tok @n: ', $duplicate-tok-ns"/>
               <xsl:message
                  select="'reassign passages with faulty locators: ', $passages-with-faulty-locators"/>
               <xsl:message select="'overlapping reassign passages: ', $overlapping-passages"/>
               <xsl:message
                  select="'reassign passages that can be acted upon: ', $actionable-passages"/>
               <xsl:message select="'text marked: ', $text-tokenized-and-marked"/>
            </xsl:if>
            <xsl:for-each-group select="$text-tokenized-and-marked/*" group-by="tan:reassign/@q">
               <xsl:variable name="do-not-reassign" select="current-grouping-key() = 'none'"/>
               <xsl:variable name="this-group-pos" select="position()"/>
               <div>
                  <xsl:copy-of select="$this-div/@*"/>
                  <xsl:if test="$this-group-pos = 1">
                     <!-- record the <ref>s that successfully hit -->
                     <xsl:copy-of select="$reassigns-with-passages-expanded/tan:passage/tan:ref"/>
                     <xsl:copy-of
                        select="tan:imprint-adjustment-locator($passages-with-faulty-locators/*)"/>
                     <xsl:copy-of
                        select="tan:imprint-adjustment-locator($overlapping-passages, tan:error('rea02'))"
                     />
                     <xsl:if test="exists($previous-ref-renames) and exists($actionable-passages)">
                        <xsl:copy-of
                           select="tan:imprint-adjustment-locator(($previous-ref-renames/*, $actionable-passages), tan:error('rea03'))"
                        />
                     </xsl:if>
                  </xsl:if>
                  <xsl:choose>
                     <xsl:when test="$do-not-reassign">
                        <xsl:copy-of select="$this-div/(* except (tan:tok, tan:non-tok))"/>
                        <xsl:apply-templates select="current-group()" mode="unmark-tokens"/>
                        <!--<xsl:copy-of select="tan:copy-of-except(current-group(), 'reassign', (), ())"/>-->
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:variable name="this-reassign-q-val" select="current-grouping-key()"/>
                        <!--<xsl:variable name="this-reassign-passage" select="$actionable-passages[@q = $this-reassign-q-val]"/>-->
                        <xsl:variable name="this-reassign"
                           select="$actionable-passages/parent::tan:reassign[@q = $this-reassign-q-val]"/>
                        <!--<xsl:copy-of
                           select="tan:imprint-adjustment-locator($this-reassign-passage/tan:ref)"/>-->
                        <xsl:copy-of select="$this-reassign/tan:to/tan:ref"/>
                        <xsl:copy-of select="current-group()"/>
                        <!--<xsl:apply-templates select="current-group()" mode="unmark-tokens"/>-->
                        <!--<xsl:copy-of select="tan:copy-of-except(current-group(), 'reassign', (), ())"/>-->
                     </xsl:otherwise>
                  </xsl:choose>
               </div>
            </xsl:for-each-group>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tan:passage" mode="expand-reassigns">
      <xsl:param name="restrict-to-refs" tunnel="yes"/>
      <xsl:if test="tan:ref/text() = $restrict-to-refs">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
         </xsl:copy>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:from-tok" mode="expand-reassigns">
      <xsl:param name="text-tokenized" tunnel="yes" as="element()"/>
      <!-- The strategy here is to find the tokens referred to by a <from-tok> + <through-tok> locatorr pair -->
      <!-- Reference errors are embedded in the locator elements; the tokens referred to are embedded within the locators; tokens between them are copied between them -->
      <!-- We do not copy <non-tok>s because we are interested only in @n values, to later determine if there are any duplicates, to detect overlapping passages -->
      <xsl:variable name="this-from" select="."/>
      <xsl:variable name="this-through" select="following-sibling::tan:through-tok[1]"/>
      <xsl:variable name="possible-toks-for-this-from-tok"
         select="
            $text-tokenized/tan:tok[if (exists($this-from/tan:rgx)) then
               tan:matches(., $this-from/tan:rgx)
            else
               . = $this-from/tan:val]"/>
      <xsl:variable name="pos-for-this-from-tok"
         select="tan:expand-pos-or-chars($this-from/tan:pos, count($possible-toks-for-this-from-tok))"/>
      <xsl:variable name="that-from-tok"
         select="$possible-toks-for-this-from-tok[position() = $pos-for-this-from-tok]"/>

      <xsl:variable name="possible-toks-for-this-through-toks"
         select="
            $text-tokenized/tan:tok[if (exists($this-through/tan:rgx)) then
               tan:matches(., $this-through/tan:rgx)
            else
               . = $this-through/tan:val]"/>
      <xsl:variable name="pos-for-this-through-tok"
         select="tan:expand-pos-or-chars($this-through/tan:pos, count($possible-toks-for-this-through-toks))"/>
      <xsl:variable name="that-through-tok"
         select="$possible-toks-for-this-through-toks[position() = $pos-for-this-through-tok]"/>

      <xsl:variable name="those-ns"
         select="xs:integer($that-from-tok/@n), xs:integer($that-through-tok/@n)"/>
      <xsl:variable name="that-min-n" select="min($those-ns)"/>
      <xsl:variable name="that-max-n" select="max($those-ns)"/>

      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$that-from-tok"/>
         <xsl:if test="not(exists($that-from-tok))">
            <xsl:copy-of select="tan:error('tok01')"/>
         </xsl:if>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
      <xsl:for-each select="($that-min-n + 1) to ($that-max-n - 1)">
         <xsl:variable name="this-median-n" select="."/>
         <xsl:copy-of select="$text-tokenized/tan:tok[@n = $this-median-n]"/>
      </xsl:for-each>
      <through-tok>
         <xsl:copy-of select="$this-through/@*"/>
         <xsl:if test="not(exists($that-through-tok))">
            <xsl:copy-of select="tan:error('tok01')"/>
         </xsl:if>
         <xsl:if test="$those-ns[2] lt $those-ns[1]">
            <xsl:copy-of select="tan:error('rea01')"/>
         </xsl:if>
         <xsl:copy-of select="$that-through-tok"/>
         <xsl:copy-of select="$this-through/node()"/>
      </through-tok>
   </xsl:template>
   <xsl:template match="tan:through-tok" mode="expand-reassigns"/>

   <xsl:template match="tan:tok | tan:non-tok" mode="mark-reassigns">
      <xsl:param name="reassign-passages-expanded" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-n" select="@n"/>
      <xsl:variable name="this-reassign-passage-locator"
         select="$reassign-passages-expanded//descendant-or-self::*[tan:tok/@n = $this-n]"/>
      <xsl:variable name="this-tok-n" select="self::tan:tok/@n"/>
      <xsl:variable name="is-passage-start" select="self::tan:tok and $this-reassign-passage-locator/self::tan:from-tok"/>
      <xsl:variable name="is-passage-end" select="$this-reassign-passage-locator/self::tan:through-tok and not(exists(following-sibling::*[1][@n = $this-n]))"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <!-- Add a @q id if one doesn't exist -->
         <xsl:if test="not(exists(@q))">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:choose>
            <xsl:when test="$is-passage-start">
               <xsl:variable name="this-passage-marker"
                  select="tan:imprint-adjustment-locator($this-reassign-passage-locator/ancestor-or-self::tan:passage/tan:ref)"/>
               <xsl:copy-of
                  select="tan:copy-of-except($this-passage-marker, ('from-tok', 'through-tok'), (), ())"/>
               <xsl:copy-of select="tan:imprint-adjustment-locator($this-reassign-passage-locator)"/>
               <xsl:copy-of select="node()"/>
            </xsl:when>
            <xsl:when test="$is-passage-end">
               <xsl:copy-of select="node()"/>
               <xsl:copy-of select="tan:imprint-adjustment-locator($this-reassign-passage-locator)"
               />
            </xsl:when>
            <xsl:when test="not(exists($this-reassign-passage-locator))">
               <reassign q="none"/>
               <xsl:copy-of select="node()"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="tan:shallow-copy($this-reassign-passage-locator/ancestor::tan:reassign)"/>
               <xsl:copy-of select="node()"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>

   <!-- we get rid of grouping keys that were implanted in the tokens -->
   <xsl:template match="tan:tok/* | tan:non-tok/*" mode="unmark-tokens"/>


   <xsl:template match="/" priority="1" mode="mark-dependencies-pass-1">
      <xsl:param name="class-2-doc" tunnel="yes" as="document-node()?"/>
      <xsl:variable name="this-src-id" select="*/@src"/>
      <xsl:variable name="this-token-definition"
         select="$class-2-doc/*/tan:head/tan:token-definition[tan:src = $this-src-id][1]"/>
      <!--<xsl:variable name="this-token-definition-attr-which-norm" select="replace($this-token-definition/@which, '\s+', '_')"/>-->
      <xsl:variable name="this-token-definition-vocabulary" select="tan:vocabulary('token-definition', $this-token-definition/@which, $class-2-doc/*/tan:head)"/>
      <xsl:variable name="this-token-definition-resolved" as="element()">
         <xsl:choose>
            <xsl:when test="exists($this-token-definition/@pattern)">
               <xsl:sequence select="$this-token-definition"/>
            </xsl:when>
            <xsl:when test="$this-token-definition-vocabulary">
               <xsl:copy-of select="($this-token-definition-vocabulary/(tan:item, tan:token-definition))[1]"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$token-definition-default"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:variable name="ambig-is-roman"
         select="not($class-2-doc/*/tan:head/tan:numerals/@priority = 'letters')"/>
      <xsl:variable name="n-alias-items"
         select="tan:TAN-T/tan:head/tan:vocabulary/tan:item[tan:affects-attribute = 'n']"/>
      <xsl:variable name="doc-2-refs-to-this-src" select="$class-2-doc/*/tan:body//*[tan:src = $this-src-id or tan:work = $this-src-id]"/>
      <xsl:variable name="these-ref-parents"
         select="$doc-2-refs-to-this-src/descendant-or-self::*[tan:ref]"/>
      <xsl:variable name="these-ref-parents-resolved" as="element()*">
         <xsl:apply-templates select="$these-ref-parents" mode="resolve-numerals">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
            <xsl:with-param name="n-alias-items" select="$n-alias-items" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      
      <xsl:variable name="tan-a-lm-general-claims" select="$doc-2-refs-to-this-src/self::tan:tok[not(@ref)]"/>
      <xsl:variable name="tokenize-here-universally" select="exists($tan-a-lm-general-claims)"/>
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message
            select="'diagnostics on for template mode mark-dependencies-pass-1, treating dependency document @src = ', xs:string($this-src-id)"/>
         <xsl:message select="'token definition: ', $this-token-definition-resolved"/>
         <xsl:message select="'ambiguous is Roman?', $ambig-is-roman"/>
         <xsl:message select="'tokenize universally?', $tokenize-here-universally"/>
         <xsl:message select="'ref parents (before resolution): ', $these-ref-parents"/>
         <xsl:message select="'ref parents (resolved): ', $these-ref-parents-resolved"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="exists($these-ref-parents) or $tokenize-here-universally">
            
            <xsl:document>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="ref-parents" select="$these-ref-parents-resolved"
                     tunnel="yes"/>
                  <xsl:with-param name="token-definition" select="$this-token-definition-resolved"
                     tunnel="yes"/>
                  <!-- tokenization is by default off, until turned on in specific places where there are token-based references -->
                  <xsl:with-param name="tokenize-leaf-div" tunnel="yes" select="$tokenize-here-universally"/>
               </xsl:apply-templates>
            </xsl:document>
         </xsl:when>
         <xsl:otherwise>
            <xsl:sequence select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tan:div" mode="mark-dependencies-pass-1">
      <xsl:param name="ref-parents" tunnel="yes" as="element()*"/>

      <xsl:param name="tokenize-leaf-div" tunnel="yes" as="xs:boolean"/>
      <xsl:variable name="is-leaf-div" select="not(exists(tan:div))"/>
      <xsl:variable name="these-ns" select="tan:n"/>
      <xsl:variable name="this-n-level" select="count(tan:ref[1]/tan:n)"/>
      <xsl:variable name="next-n-level" select="$this-n-level + 1"/>
      <xsl:variable name="next-ns" select="tan:div[not(tan:ref/@reset)]/tan:n"/>
      <xsl:variable name="these-refs" select="tan:ref/text()"/>
      <xsl:variable name="these-ref-parents" select="$ref-parents[tan:ref/text() = $these-refs]"/>
      <xsl:variable name="ref-parents-to-pass-to-children"
         select="$ref-parents[tan:ref[tan:n[$this-n-level] = $these-ns][tan:n[$next-n-level] = $next-ns]]"/>
      <xsl:variable name="claim-requires-tokenization" select="exists($these-ref-parents//tan:pos)"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode mark-dependencies-pass-1, for: ', ."/>
         <xsl:message select="'ref parents: ', $ref-parents"/>
         <xsl:message select="'tokenize leaf div? ', $tokenize-leaf-div"/>
         <xsl:message select="'this n level: ', $this-n-level"/>
         <xsl:message select="'picked ref parents: ', $these-ref-parents"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="* except tan:div"/>
         <!-- Leave a marker for any div claims -->
         <xsl:copy-of select="tan:shallow-copy($these-ref-parents/tan:ref[text() = $these-refs])"/>
         <xsl:apply-templates select="(tan:div, text())" mode="#current">
            <xsl:with-param name="tokenize-leaf-div" tunnel="yes"
               select="$tokenize-leaf-div or $claim-requires-tokenization"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:div/text()[matches(., '\S')]" mode="mark-dependencies-pass-1">
      <xsl:param name="token-definition" tunnel="yes" as="element()*"/>
      <xsl:param name="tokenize-leaf-div" tunnel="yes" as="xs:boolean"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode: mark-dependencies-pass-1'"/>
         <xsl:message select="'tokenize leaf div?', $tokenize-leaf-div"/>
         <xsl:message select="'token definition: ', $token-definition"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="$tokenize-leaf-div">
            <xsl:variable name="this-text-tokenized"
               select="tan:tokenize-text(., $token-definition, true())"/>
            <xsl:copy-of select="tan:stamp-q-id($this-text-tokenized/*)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>


   <xsl:template match="/" mode="mark-dependencies-pass-2">
      <xsl:param name="class-2-doc" tunnel="yes" as="document-node()?"/>
      <xsl:variable name="this-src-id" select="*/@src"/>
      <xsl:variable name="this-work-id" select="*/@work"/>
      <xsl:variable name="ambig-is-roman"
         select="not($class-2-doc/*/tan:head/tan:numerals/@priority = 'letters')"/>
      <xsl:variable name="n-alias-items"
         select="tan:TAN-T/tan:head/tan:vocabulary/tan:item[tan:affects-attribute = 'n']"/>
      <xsl:variable name="items-mentioning-this-src-or-work" select="$class-2-doc/*/tan:body//*[(tan:src = $this-src-id) or (tan:work = $this-work-id)]"/>
      <xsl:variable name="these-ref-parents-with-pos"
         select="$items-mentioning-this-src-or-work/descendant-or-self::*[tan:ref][descendant::tan:pos]"
      />
      <xsl:variable name="these-universal-toks" select="$items-mentioning-this-src-or-work/self::tan:tok[not(@ref)]"/>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message
            select="'template mode mark-dependencies-pass-2, diagnostics on at document node for doc with root element @src ', string($this-src-id)"/>
         <xsl:message select="'ambiguous numbers are roman? ', $ambig-is-roman"/>
         <xsl:message select="'n alias items: ', $n-alias-items"/>
         <xsl:message select="'items mentioning this document as a source or work:', $items-mentioning-this-src-or-work"/>
         <xsl:message select="'ref parents: ', $these-ref-parents-with-pos"/>
         <xsl:message select="'universal tok elements:', $these-universal-toks"/>
      </xsl:if>

      <xsl:choose>
         <xsl:when test="exists($these-ref-parents-with-pos) or exists($these-universal-toks)">
            <xsl:document>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="src-id" select="$this-src-id" tunnel="yes"/>
                  <xsl:with-param name="ref-parents" select="$these-ref-parents-with-pos"
                     tunnel="yes"/>
                  <xsl:with-param name="universal-toks" select="$these-universal-toks" tunnel="yes"
                  />
               </xsl:apply-templates>
            </xsl:document>
         </xsl:when>
         <xsl:otherwise>
            <xsl:sequence select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tan:div" mode="mark-dependencies-pass-2">
      <xsl:param name="src-id" tunnel="yes" as="xs:string"/>
      <xsl:param name="ref-parents" tunnel="yes" as="element()*"/>
      <xsl:variable name="these-toks" select="descendant::tan:tok"/>
      <xsl:variable name="is-tokenized-div" select="exists($these-toks)"/>
      <xsl:variable name="these-ref-q-marks" select="tan:ref/@q"/>
      <xsl:variable name="these-ref-parents" select="$ref-parents[tan:ref/@q = $these-ref-q-marks]"/>
      <xsl:variable name="these-pos-parents"
         select="$these-ref-parents/descendant-or-self::*[tan:pos]"/>
      <xsl:variable name="these-pos-parents-marked" as="element()*">
         <!-- We take all token pointers, and see what they match -->
         <xsl:apply-templates select="$these-pos-parents" mode="mark-tok-pos">
            <xsl:with-param name="src-id" select="$src-id" tunnel="yes"/>
            <xsl:with-param name="refs" select="tan:ref" tunnel="yes"/>
            <xsl:with-param name="tok-elements" tunnel="yes" select="$these-toks"/>
         </xsl:apply-templates>
      </xsl:variable>
      
      <xsl:variable name="diagnostics-on" as="xs:boolean" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for ref ', tan:ref[1]/text()"/>
         <xsl:message select="'This div (shallow):', tan:shallow-copy(., 2)"/>
         <xsl:message select="'is tokenized div:', $is-tokenized-div"/>
         <xsl:message select="'ref markers:', $these-ref-q-marks"/>
         <xsl:message select="'matching class 2 ref parents: ', $these-ref-parents"/>
         <xsl:message select="'these pos parents: ', $these-pos-parents"/>
         <xsl:message select="'pos parents marked: ', $these-pos-parents-marked"/>
      </xsl:if>
      
      <xsl:choose>
         <xsl:when test="$is-tokenized-div">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="$these-pos-parents-marked/tan:pos[tan:error]"/>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="tok-refs" select="$these-pos-parents-marked" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tan:tok" mode="mark-dependencies-pass-2">
      <xsl:param name="tok-refs" tunnel="yes" as="element()*"/>
      <xsl:param name="universal-toks" tunnel="yes" as="element()*"/>
      <xsl:variable name="this-tok" select="."/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="these-universal-toks" select="$universal-toks[tan:val = $this-tok]"/>
      <xsl:variable name="these-tok-refs" select="$tok-refs//tan:pos[tan:tok/@q = $this-q]"/>
      <xsl:variable name="these-chars-refs" select="$these-tok-refs/../tan:chars"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for: ', ."/>
         <xsl:message select="'possible tok refs: ', $tok-refs"/>
         <xsl:message select="'these tok refs: ', $these-tok-refs"/>
         <xsl:message select="'these char refs: ', $these-chars-refs"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="tan:shallow-copy($these-universal-toks)"/>
         <xsl:copy-of select="tan:shallow-copy($these-tok-refs)"/>
         <xsl:if test="exists($these-chars-refs)">
            <xsl:variable name="these-chars" as="element()*">
               <xsl:for-each select="tan:chop-string(.)">
                  <c n="{position()}">
                     <xsl:value-of select="."/>
                  </c>
               </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="chars-marked" as="element()*">
               <xsl:apply-templates select="$these-chars-refs" mode="mark-tok-chars">
                  <xsl:with-param name="c-elements" tunnel="yes" select="$these-chars"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:apply-templates select="$these-chars" mode="#current">
               <xsl:with-param name="c-refs" select="$chars-marked"/>
            </xsl:apply-templates>
         </xsl:if>
         <!--<xsl:value-of select="."/>-->
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:c" mode="mark-dependencies-pass-2">
      <xsl:param name="c-refs" as="element()*"/>
      <xsl:variable name="this-n" select="@n"/>
      <xsl:variable name="these-chars-refs" select="$c-refs[tan:c/@n = $this-n]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="tan:shallow-copy($these-chars-refs)"/>
         <xsl:value-of select="."/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:pos" mode="mark-tok-pos">
      <xsl:param name="src-id" tunnel="yes" as="xs:string"/>
      <xsl:param name="refs" tunnel="yes" as="element()+"/>
      <xsl:param name="tok-elements" tunnel="yes" as="element()*"/>
      <xsl:variable name="this-parent" select=".."/>
      <xsl:variable name="these-possible-toks"
         select="
            $tok-elements[text()[if (exists($this-parent/tan:rgx)) then
               tan:matches(., $this-parent/tan:rgx)
            else
               . = $this-parent/tan:val]]"/>
      <xsl:variable name="this-pos" select="tan:expand-pos-or-chars(., count($these-possible-toks))"/>
      <xsl:variable name="this-tok" select="$these-possible-toks[$this-pos]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for: ', ."/>
         <xsl:message select="'possible toks: ', $these-possible-toks"/>
         <xsl:message select="'this pos: ', $this-pos"/>
         <xsl:message select="'chosen tok: ', $this-tok"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:choose>
            <xsl:when test="exists($this-tok)">
               <xsl:copy-of select="$this-tok"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="poss-tok-count" select="count($these-possible-toks)"/>
               <xsl:variable name="this-message-parts" as="xs:string+">
                  <xsl:text>Source</xsl:text>
                  <xsl:value-of select="$src-id"/>
                  <xsl:text>at</xsl:text>
                  <xsl:value-of select="$refs/text()"/>
                  <xsl:text>has</xsl:text>
                  <xsl:value-of select="$poss-tok-count"/>

                  <xsl:choose>
                     <xsl:when test="$poss-tok-count = 1">
                        <xsl:text>token matching</xsl:text>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>tokens matching</xsl:text>
                     </xsl:otherwise>
                  </xsl:choose>
                  <xsl:choose>
                     <xsl:when test="exists($this-parent/tan:rgx)">
                        <xsl:text>regular expression</xsl:text>
                        <xsl:value-of select="$this-parent/tan:rgx"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:text>value</xsl:text>
                        <xsl:value-of select="$this-parent/tan:val"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:variable>
               <xsl:copy-of select="tan:error('tok01', string-join($this-message-parts, ' '))"/>
               <xsl:if test="exists($these-possible-toks)">
                  <xsl:if test="$this-pos gt count($these-possible-toks)">
                     <xsl:copy-of select="tan:error('seq02')"/>
                  </xsl:if>
                  <xsl:if test="$this-pos lt count($these-possible-toks)">
                     <xsl:copy-of select="tan:error('seq01')"/>
                  </xsl:if>
               </xsl:if>
            </xsl:otherwise>
         </xsl:choose>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:chars" mode="mark-tok-chars">
      <xsl:param name="c-elements" tunnel="yes" as="element()+"/>
      <xsl:variable name="this-chars" select="tan:expand-pos-or-chars(., count($c-elements))"/>
      <xsl:variable name="this-c" select="$c-elements[$this-chars]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$this-c"/>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>


   <!-- Stripping dependencies to just the markers allows faster assessment of class-2 pointers -->
   <xsl:template match="tan:head | text()" mode="strip-dependencies-to-markers"/>
   <xsl:template match="/*" mode="strip-dependencies-to-markers">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="*" mode="strip-dependencies-to-markers">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <xsl:template
      match="tan:skip | tan:rename | tan:equate | tan:reassign | tan:ref | tan:pos | tan:chars | tan:tok[@val]"
      mode="strip-dependencies-to-markers">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <points-to>
            <xsl:attribute name="element" select="name(parent::*)"/>
            <xsl:copy-of select="../@*"/>
         </points-to>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>
   


   <!-- NORMAL EXPANSION -->

   <xsl:template match="tan:body | tan:div" mode="core-expansion-normal">
      <xsl:param name="fragmented-siblings" as="element()*"/>
      <xsl:variable name="these-ns" select="tan:n"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="is-leaf-div" select="exists(self::tan:div[not(tan:div)])"/>
      <xsl:variable name="relevant-fragments" select="$fragmented-siblings[tan:n = $these-ns]"/>
      <xsl:variable name="this-fragment" select="$relevant-fragments[@q = $this-q]"/>
      <xsl:variable name="corresponding-fragments"
         select="$relevant-fragments except $this-fragment"/>
      <xsl:variable name="children-grouped"
         select="tan:group-elements-by-shared-node-values((tan:div, $corresponding-fragments/tan:div), '^n$')"
         as="element()*"/>
      <xsl:variable name="fragmented-children" as="element()*"
         select="$children-grouped[count(tan:div) gt 1]/tan:div"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode core-expansion-normal, for: ', ."/>
         <xsl:message select="'fragmented siblings: ', $fragmented-siblings"/>
         <xsl:message select="'children grouped: ', $children-grouped"/>
         <xsl:message select="'fragmented children: ', $fragmented-children"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($corresponding-fragments)">
            <xsl:copy-of select="tan:error('cl109')"/>
            <xsl:choose>
               <xsl:when test="$is-leaf-div">
                  <xsl:variable name="corresponding-fragment-is-not-leaf-div"
                     select="exists($corresponding-fragments/tan:div)"/>
                  <xsl:if test="$corresponding-fragment-is-not-leaf-div">
                     <xsl:copy-of select="tan:error('cl118')"/>
                  </xsl:if>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:variable name="corresponding-fragment-is-leaf-div"
                     select="exists($corresponding-fragments[not(tan:div)])"/>
                  <xsl:if test="$corresponding-fragment-is-leaf-div">
                     <xsl:copy-of select="tan:error('cl118')"/>
                  </xsl:if>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
         <xsl:if
            test="
               $is-leaf-div and
               (not(some $i in text()
                  satisfies matches($i, '\S')) or not(exists(text())))">
            <xsl:copy-of select="tan:error('cl110')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="fragmented-siblings" select="$fragmented-children"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:TAN-T/tan:body" mode="core-expansion-normal-old">
      <xsl:variable name="all-refs" select=".//tan:div/tan:ref/text()"/>
      <xsl:variable name="duplicate-refs" select="tan:duplicate-items($all-refs)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-refs" select="$duplicate-refs" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:div" mode="core-expansion-normal-old">
      <xsl:param name="duplicate-refs" tunnel="yes"/>
      <xsl:variable name="this-ref" select="tan:ref/text()"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$this-ref = $duplicate-refs">
            <xsl:copy-of select="tan:error('cl109', $this-ref)"/>
         </xsl:if>
         <xsl:if
            test="
               not(exists(tan:div)) and
               (not(some $i in text()
                  satisfies matches($i, '\S')) or not(exists(text())))">
            <xsl:copy-of select="tan:error('cl110')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:body" mode="dependency-expansion-normal">
      <xsl:param name="token-definition" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-src-id" select="../@src"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="token-definition"
               select="($token-definition[tan:src = $this-src-id])[1]" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:div" mode="dependency-expansion-normal">
      <xsl:param name="token-definition" as="element()*" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:choose>
            <!-- A token definition is a tacit request to tokenize any divs that haven't been tokenized yet -->
            <xsl:when test="exists($token-definition) and not(exists((tan:tok, tan:div)))">
               <xsl:apply-templates select="(*, comment())" mode="#current"/>
               <xsl:copy-of select="tan:tokenize-text(text(), $token-definition, true())/*"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>




   <!-- VERBOSE EXPANSION -->

   <!-- Pass 1: fetch <redivision> normalized text and imprint a <diff> against the current base text; fetch <model> div structure -->
   <xsl:template match="tan:head" mode="class-1-expansion-verbose-pass-1">
      <xsl:variable name="base-text" select="tan:text-join(../tan:body)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="base-text" select="$base-text"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:redivision" mode="class-1-expansion-verbose-pass-1">
      <xsl:param name="base-text" as="xs:string?"/>
      <xsl:variable name="this-redivision-number" select="count(preceding-sibling::tan:redivision) + 1"/>
      <xsl:variable name="this-redivision-resolved" as="document-node()?">
         <xsl:choose>
            <xsl:when test="root()/*/@id = $doc-id">
               <xsl:sequence select="$redivisions-resolved[$this-redivision-number]"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="this-1st-da" select="tan:get-1st-doc(.)"/>
               <xsl:copy-of select="tan:resolve-doc($this-1st-da)"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="this-text" select="tan:text-join($this-redivision-resolved)"/>
      <xsl:variable name="this-diff" select="tan:diff($base-text, $this-text, true())"/>
      <xsl:variable name="this-diff-analyzed" select="tan:analyze-leaf-div-string-length($this-diff)"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode: class-1-expansion-verbose-pass-1'"/>
         <xsl:message select="'this redivision doc resolved: ', $this-redivision-resolved"/>
         <xsl:message select="'differences between base text and redivision text: ', $this-diff"/>
         <xsl:message select="'differences analyzed: ', $this-diff-analyzed"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <xsl:if test="exists($this-diff-analyzed/(tan:a, tan:b))">
            <xsl:copy-of select="tan:error('cl104')"/>
         </xsl:if>
         <xsl:copy-of select="$this-diff-analyzed"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:model" mode="class-1-expansion-verbose-pass-1">
      <xsl:variable name="this-model-resolved" as="document-node()?">
         <xsl:choose>
            <xsl:when test="root()/*/@id = $doc-id">
               <xsl:sequence select="$model-resolved"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="this-1st-da" select="tan:get-1st-doc(.)"/>
               <xsl:copy-of select="tan:resolve-doc($this-1st-da)"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="this-model-expanded" select="tan:expand-doc($this-model-resolved, 'terse')"/>
      <xsl:variable name="this-base-and-model-merged" select="tan:merge-expanded-docs((/, $this-model-expanded))"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <xsl:copy-of select="tan:copy-of-except($this-base-and-model-merged/tan:TAN-T_merge/tan:body, ('error', 'warning'), 'q', ())"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:body" mode="class-1-expansion-verbose-pass-1">
      <!-- Anticiptae the next pass, which will check redivisions against the current text, by analyzing the leaf div string length -->
      <xsl:variable name="redivisions-exist" select="exists(../tan:head/tan:redivision)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:choose>
            <xsl:when test="$redivisions-exist">
               <xsl:copy-of select="tan:analyze-leaf-div-string-length(*)"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>
   
   
   <!-- In pass 2, we convert the <diff>s in any <redivision> into something more concise, for flagging errors in pass 3 -->
   <!-- We also evaluate the differences between the base document and its model; and look for reference numbers mistakenly in the text itself -->
   <xsl:template match="tan:head" mode="class-1-expansion-verbose-pass-2">
      <xsl:variable name="base-text-pos-integers" as="xs:integer*"
         select="
            if (exists(tan:redivision)) then
               ../tan:body//tan:div/@string-pos
            else
               ()"
      />
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode: class-1-expansion-verbose-pass-2'"/>
         <xsl:message select="'base text pos integers: ', $base-text-pos-integers"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="base-text-pos-integers" select="$base-text-pos-integers" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:redivision/tan:diff" mode="class-1-expansion-verbose-pass-2">
      <!-- The goal here is first to punctuate the diff elements with empty <div string-pos=""> anchors -->
      <!-- and then to rebuild the diff fragments within newly built <div>s  -->
      <xsl:variable name="diff-spiked" as="element()">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
         </xsl:copy>
      </xsl:variable>
      <xsl:for-each-group select="$diff-spiked/*" group-starting-with="tan:div">
         <xsl:if test="exists(current-group()/(self::tan:a, self::tan:b))">
            <div>
               <xsl:copy-of select="current-group()[1]/@*"/>
               <diff>
                  <xsl:copy-of select="$diff-spiked/@*"/>
                  <xsl:copy-of select="current-group()[position() gt 1]"/>
               </diff>
            </div>
         </xsl:if>
      </xsl:for-each-group> 
   </xsl:template>
   <xsl:template match="tan:redivision/tan:diff/tan:b" mode="class-1-expansion-verbose-pass-2">
      <!-- if there's a <b> without a comparion <a> then copy it without variables; <b>'s with companion <a>s get processed with the <a> -->
      <xsl:if test="not(exists(preceding-sibling::*[1]/self::tan:a))">
         <xsl:copy>
            <xsl:value-of select="."/>
         </xsl:copy>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:redivision/tan:diff/tan:common | tan:redivision/tan:diff/tan:a" mode="class-1-expansion-verbose-pass-2">
      <xsl:param name="base-text-pos-integers" tunnel="yes" as="xs:integer+"/>
      <xsl:variable name="this-text" select="text()"/>
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="this-string-pos" select="xs:integer(@string-pos)"/>
      <xsl:variable name="this-string-length" select="xs:integer(@string-length)"/>
      <xsl:variable name="next-string-pos" select="$this-string-pos + $this-string-length + 1"/>
      <xsl:variable name="integers-of-interest" select="$base-text-pos-integers[(. ge $this-string-pos) and (. lt $next-string-pos)]"/>
      <xsl:variable name="integers-of-interest-count" select="count($integers-of-interest)"/>
      <xsl:variable name="anchor-places"
         select="
            for $i in $integers-of-interest
            return
               ($i - $this-string-pos + 1)"
      />
      <xsl:variable name="segment-lengths"
         select="
            for $i in (1 to $integers-of-interest-count)
            return
               if ($i = $integers-of-interest-count) then
                  $this-string-length
               else
                  ($anchor-places[$i + 1] - $anchor-places[$i])"
      />
      <xsl:variable name="this-is-a" select="self::tan:a"/>
      <xsl:variable name="this-b"
         select="
            if ($this-is-a) then
               following-sibling::*[1]/self::tan:b
            else
               ()"
      />
      <xsl:variable name="this-b-text" select="$this-b/text()"/>
      <xsl:variable name="this-b-segmented" as="xs:string*">
         <xsl:analyze-string select="$this-b-text" regex="\S+\s*">
            <xsl:matching-substring>
               <xsl:value-of select="."/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
               <xsl:value-of select="."/>
            </xsl:non-matching-substring>
         </xsl:analyze-string>
      </xsl:variable>
      <xsl:variable name="this-b-length" select="count($this-b-segmented)"/>
      <xsl:variable name="b-to-a-ratio" select="$this-b-length div $this-string-length"/>
      <xsl:variable name="b-anchor-places"
         select="
            for $i in $anchor-places
            return
               ceiling($i * $b-to-a-ratio)"
      />
      <xsl:variable name="b-segment-lengths"
         select="
            for $i in (1 to $integers-of-interest-count)
            return
               if ($i = $integers-of-interest-count) then
                  $this-b-length
               else
                  ($b-anchor-places[$i + 1] - $b-anchor-places[$i])"
      />
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode: class-1-expansion-verbose'"/>
         <xsl:message select="'checking diff element, ', ."/>
         <xsl:message select="'integers of interest: ', $integers-of-interest"/>
         <xsl:message select="'anchor places: ', $anchor-places"/>
         <xsl:message select="'segment lengths: ', $segment-lengths"/>
         <xsl:if test="exists($this-b)">
            <xsl:message select="'companion b: ', $this-b"/>
            <xsl:message select="'b segmented: ', string-join($this-b-segmented, '| ')"/>
            <xsl:message select="'b anchor places: ', $b-anchor-places"/>
            <xsl:message select="'b segment lengths: ', $b-segment-lengths"/>
         </xsl:if>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="exists($integers-of-interest)">
            <xsl:if test="$anchor-places[1] gt 1">
               <xsl:element name="{$this-name}">
                  <xsl:value-of select="substring($this-text, 1, $anchor-places[1] - 1)"/>
               </xsl:element>
               <xsl:if test="exists($this-b)">
                  <xsl:variable name="these-b-toks" select="subsequence($this-b-segmented, 1, $b-anchor-places[1] - 1)"/>
                  <xsl:if test="exists($these-b-toks)">
                     <b>
                        <xsl:value-of select="string-join($these-b-toks, '')"/>
                     </b>
                  </xsl:if>
               </xsl:if>
            </xsl:if>
            <xsl:for-each select="$anchor-places">
               <xsl:variable name="this-pos" select="position()"/>
               <xsl:variable name="this-segment"
                  select="substring($this-text, ., $segment-lengths[$this-pos])"/>
               <div string-pos="{$integers-of-interest[$this-pos]}"/>
               <xsl:element name="{$this-name}">
                  <xsl:value-of select="$this-segment"/>
               </xsl:element>
               <xsl:if test="exists($this-b)">
                  <xsl:variable name="these-b-toks" select="subsequence($this-b-segmented, $b-anchor-places[$this-pos], $b-segment-lengths[$this-pos])"/>
                  <xsl:if test="exists($these-b-toks)">
                     <b>
                        <xsl:value-of select="string-join($these-b-toks, '')"/>
                     </b>
                  </xsl:if>
               </xsl:if>
            </xsl:for-each>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="tan:model" mode="class-1-expansion-verbose-pass-2">
      <xsl:variable name="all-divs" select="tan:body//tan:div[tan:div]"/>
      <xsl:variable name="defective-divs" select="$all-divs[count(tan:src) = 1]"/>
      <xsl:variable name="these-defective-divs" select="$defective-divs[tan:src = '1']"/>
      <xsl:variable name="those-defective-divs" select="$defective-divs[tan:src = '2']"/>
      <xsl:variable name="this-message" as="xs:string*">
         <xsl:text>This file and its model diverge: </xsl:text>
         <xsl:value-of
            select="
               if (exists($these-defective-divs)) then
                  concat('uniquely here: ', string-join($these-defective-divs/tan:ref/text(), '; '), ' ')
               else
                  ()"/>
         <xsl:value-of
            select="
               if (exists($those-defective-divs)) then
                  concat('unique to model: ', string-join($those-defective-divs/tan:ref/text(), '; '), ' ')
               else
                  ()"
         />
      </xsl:variable>
      <xsl:variable name="diagnostics-on" as="xs:boolean" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode: class-1-expansion-verbose-pass-2'"/>
         <xsl:message select="'defective divs: ', $defective-divs"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($defective-divs)">
            <xsl:copy-of select="tan:error('cl107', string-join($this-message, ''))"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:model/tan:body" mode="class-1-expansion-verbose-pass-2">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:TAN-T/tan:body" mode="class-1-expansion-verbose-pass-2">
      <xsl:variable name="self-and-model-merged" select="../tan:head/tan:model[1]/tan:body"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="self-and-model-merged" tunnel="yes"
               select="$self-and-model-merged"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:div" mode="class-1-expansion-verbose-pass-2">
      <xsl:param name="self-and-model-merged" tunnel="yes" as="element()?"/>
      <xsl:variable name="is-leaf-div" select="not(exists(tan:div))"/>
      <xsl:variable name="matching-merged-div"
         select="
            if (exists($self-and-model-merged)) then
               key('div-via-ref', tan:ref/text(), $self-and-model-merged)
            else
               ()"
      />
      <xsl:variable name="this-is-defective" select="not($matching-merged-div/tan:src = '2')"/>
      <xsl:variable name="model-children-missing-here"
         select="$matching-merged-div/tan:div[not(@type = '#version')][not(tan:src = '1')]"/>
      <xsl:variable name="n-needs-help" select="exists(tan:n/@help)"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode: class-1-expansion-verbose-pass-2'"/>
         <xsl:message select="'checking: ', tan:shallow-copy(.)"/>
         <xsl:message select="'exists self and model merged? ', exists($self-and-model-merged)"/>
         <xsl:message select="'matching merged div: ', $matching-merged-div"/>
         <xsl:message select="'this is defective?', $this-is-defective"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$this-is-defective">
            <xsl:copy-of select="tan:error('cl107', 'no div with this ref appears in the model')"/>
         </xsl:if>
         <xsl:if test="exists($model-children-missing-here)">
            <xsl:copy-of
               select="tan:error('cl107', concat('children in model missing here: ', string-join($model-children-missing-here//tan:ref/text(), ', ')))"
            />
         </xsl:if>
         <xsl:if test="$n-needs-help or $this-is-defective">
            <xsl:variable name="unmatched-model-leaf-siblings-in-model"
               select="$matching-merged-div/(preceding-sibling::tan:div, following-sibling::tan:div)[@type = '#version'][tan:src = '2']"/>
            <xsl:variable name="unmatched-model-non-leaf-siblings-in-model"
               select="$matching-merged-div/(preceding-sibling::tan:div, following-sibling::tan:div)[not(@type = '#version')][not(tan:src = '1')]"/>
            <!--<xsl:variable name="this-message"
               select="
                  if (not(exists($unmatched-model-non-leaf-siblings-in-model))) then
                     'no siblings in the model suggest themselves as alternatives'
                  else
                     concat('the model has siblings not yet used here: ', string-join($unmatched-model-non-leaf-siblings-in-model/tan:ref/tan:n[last()], ', '))"/>-->
            <xsl:variable name="this-message">
               <xsl:choose>
                  <xsl:when test="exists($unmatched-model-leaf-siblings-in-model)">
                     <xsl:value-of select="'The parent of this element in the model is a leaf div.'"/>
                  </xsl:when>
                  <xsl:when test="exists($unmatched-model-non-leaf-siblings-in-model)">
                     <xsl:value-of
                        select="concat('The model has siblings not yet used here, @n = ', string-join($unmatched-model-non-leaf-siblings-in-model/tan:ref/tan:n[last()], ', '))"
                     />
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:text>No siblings in the model suggest themselves as alternatives</xsl:text>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>
            <xsl:variable name="this-fix" as="element()*">
               <xsl:for-each select="$unmatched-model-non-leaf-siblings-in-model/tan:ref">
                  <element n="{tan:n[last()]}"/>
               </xsl:for-each>
            </xsl:variable>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'unused siblings in the model: ', $unmatched-model-non-leaf-siblings-in-model"/>
            </xsl:if>
            <xsl:copy-of select="tan:help($this-message, $this-fix, 'copy-attributes')"/>
         </xsl:if>
         <!-- Check to see if the values of @n or @ref are present -->
         <xsl:if test="$is-leaf-div">
            <xsl:variable name="this-text" select="text()"/>
            <xsl:variable name="go-up-to" select="20"/>
            <xsl:variable name="opening-text" select="substring($this-text, 1, $go-up-to)"/>
            <xsl:variable name="opening-text-analyzed"
               select="tan:analyze-numbers-in-string($opening-text, true(), ())"/>
            <xsl:variable name="opening-text-as-numerals"
               select="tan:string-to-numerals($opening-text, true(), true(), ())"/>
            <xsl:variable name="opening-text-replacement"
               select="string-join($opening-text-analyzed/text(), '')"/>
            <xsl:if test="($opening-text-analyzed/self::tan:tok)[1] = tan:n">
               <xsl:copy-of
                  select="tan:error('cl115', 'opening seems to duplicate @n ', concat($opening-text-replacement, substring($this-text, $go-up-to + 1)), 'replace-text')"
               />
            </xsl:if>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'opening text: ', $opening-text"/>
               <xsl:message select="'opening text analyzed: ', $opening-text-analyzed"/>
               <xsl:message select="'opening text as numerals: ', $opening-text-as-numerals"/>
               <xsl:message select="'opening text replacement: ', $opening-text-replacement"/>
            </xsl:if>
            <xsl:for-each select="tan:ref[tan:n]">
               <xsl:variable name="n-qty" select="count(tan:n)"/>
               <xsl:variable name="this-ref" select="text()"/>
               <xsl:if
                  test="
                     ($n-qty gt 1) and
                     (every $i in (1 to $n-qty)
                        satisfies tan:n[$i] = ($opening-text-analyzed[@number])[$i])">
                  <xsl:copy-of
                     select="tan:error('cl116', concat('opening seems to duplicate the reference for this &lt;div>: ', $this-ref), concat($opening-text-replacement, substring($this-text, $go-up-to + 1)), 'replace-text')"
                  />
               </xsl:if>
            </xsl:for-each>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   
   <!-- Pass 3: register redivision errors in each leaf div; register errors in <redivision> -->
   <xsl:template match="tan:body" mode="class-1-expansion-verbose-pass-3">
      <xsl:variable name="redivision-diffs-to-process" select="../tan:head/tan:redivision/tan:div[tan:diff]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="redivision-diffs" tunnel="yes" select="$redivision-diffs-to-process"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:div[not(tan:div)]" mode="class-1-expansion-verbose-pass-3">
      <xsl:param name="redivision-diffs" tunnel="yes" as="element()*"/>
      <xsl:variable name="this-string-pos" select="@string-pos"/>
      <xsl:variable name="diffs-of-interest" select="$redivision-diffs[@string-pos = $this-string-pos]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each select="$diffs-of-interest">
            <xsl:variable name="this-redivision-position" select="count(../preceding-sibling::tan:division) + 1"/>
            <xsl:variable name="this-replacement-text" select="string-join(tan:diff/(* except tan:a), '')"/>
            <xsl:copy-of
               select="tan:error('cl104', concat('Differs with redivision #', $this-redivision-position, ' (a = this text; b = redivision; common = text without difference): ', tan:xml-to-string(tan:diff/*)), $this-replacement-text, 'replace-text')"
            />
         </xsl:for-each>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="/*" mode="class-1-expansion-verbose-pass-2-old">
      <!-- Evaluate each redivision -->
      <xsl:variable name="redivisions" select="tan:head/tan:redivision"/>
      <xsl:variable name="these-redivisions" as="document-node()*">
         <xsl:for-each select="$redivisions">
            <xsl:variable name="these-iris" select="tan:IRI"/>
            <xsl:variable name="this-redivision-resolved"
               select="$redivisions-resolved[*/@id = $these-iris]"/>
            <xsl:sequence
               select="
                  if (exists($this-redivision-resolved)) then
                     $this-redivision-resolved
                  else
                     tan:resolve-doc(tan:get-1st-doc(.))"
            />
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="this-doc-text" select="tan:text-join(tan:body)"/>
      <xsl:variable name="these-redivision-diffs" as="element()*">
         <xsl:for-each select="$these-redivisions">
            <xsl:variable name="that-doc-text"
               select="tan:text-join(*/(tan:body, tei:text/tei:body))"/>
            <xsl:copy-of select="tan:diff($this-doc-text, $that-doc-text, true())"/>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="relevant-redivision-nos" as="xs:integer*"
         select="
            for $i in (1 to count($redivisions))
            return
               if (exists($these-redivision-diffs[$i]/(tan:a, tan:b))) then
                  $i
               else
                  ()"/>
      <xsl:variable name="relevant-redivisions"
         select="$redivisions[position() = $relevant-redivision-nos]"/>
      <xsl:variable name="relevant-redivision-diffs"
         select="tan:analyze-leaf-div-string-length($these-redivision-diffs[position() = $relevant-redivision-nos])"
         as="element()*"/>
      <xsl:variable name="redivision-diffs-prepped" as="element()*">
         <xsl:for-each select="$relevant-redivision-diffs">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:for-each-group select="*" group-adjacent="name(.) = 'common'">
                  <xsl:if test="current-grouping-key() = false()">
                     <xsl:variable name="anchor-pos" as="xs:integer?"
                        select="xs:integer((current-group()/@string-pos)[1])"/>
                     <xsl:variable name="anchor-pos-checked" as="xs:integer">
                        <xsl:choose>
                           <xsl:when test="exists($anchor-pos)">
                              <xsl:copy-of select="$anchor-pos"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:variable name="most-recent-anchor"
                                 select="(current-group()[1]/preceding-sibling::*[@string-pos and @string-length])[1]"/>
                              <xsl:choose>
                                 <xsl:when test="exists($most-recent-anchor)">
                                    <xsl:copy-of
                                       select="xs:integer($most-recent-anchor/@string-pos) + xs:integer($most-recent-anchor/@string-length) - 1"
                                    />
                                 </xsl:when>
                                 <xsl:otherwise>
                                    <xsl:copy-of select="1"/>
                                 </xsl:otherwise>
                              </xsl:choose>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:variable>
                     <xsl:variable name="this-anchor"
                        select="string-join(current-group()/self::tan:a, '')"/>
                     <xsl:variable name="anchor-length" select="tan:string-length($this-anchor)"/>
                     <xsl:variable name="replace-text-chopped"
                        select="tan:chop-string(string-join(current-group()/self::tan:b, ''))"/>
                     <xsl:variable name="replace-length" select="count($replace-text-chopped)"/>
                     <xsl:variable name="replace-text-snapped-to-words" as="xs:string*">
                        <xsl:for-each-group select="$replace-text-chopped"
                           group-adjacent="matches(., '\s')">
                           <xsl:variable name="this-group-count" select="count(current-group())"/>
                           <xsl:value-of select="string-join(current-group(), '')"/>
                           <xsl:if test="$this-group-count gt 1">
                              <xsl:for-each select="2 to $this-group-count">
                                 <xsl:value-of select="''"/>
                              </xsl:for-each>
                           </xsl:if>
                        </xsl:for-each-group>
                     </xsl:variable>
                     <xsl:choose>
                        <xsl:when test="$anchor-length = 0">
                           <c pos="{$anchor-pos-checked}" insert="">
                              <xsl:value-of select="current-group()/self::tan:b"/>
                           </c>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:for-each select="1 to $anchor-length">
                              <xsl:variable name="prev-int" select=". - 1"/>
                              <xsl:variable name="this-int" select="."/>
                              <xsl:variable name="prev-pos"
                                 select="$prev-int div $anchor-length * $replace-length"/>
                              <xsl:variable name="this-pos"
                                 select="$this-int div $anchor-length * $replace-length"/>
                              <xsl:variable name="next-pos" select="xs:integer($this-pos) + 1"/>
                              <c pos="{$anchor-pos-checked + . - 1}">
                                 <xsl:value-of
                                    select="$replace-text-snapped-to-words[position() gt $prev-pos and position() le $this-pos]"
                                 />
                              </c>
                           </xsl:for-each>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:if>
               </xsl:for-each-group>
            </xsl:copy>
         </xsl:for-each>
      </xsl:variable>

      <!-- Evaluate the model (only one model is allowed) -->
      <!--<xsl:variable name="see-also-model"
         select="(tan:head/tan:see-also[tan:vocabulary-key-item(tan:relationship)/tan:name = 'model'])[1]"/>-->
      <xsl:variable name="this-model" select="tan:head/tan:model[1]"/>
      <xsl:variable name="model-already-resolved"
         select="$model-resolved[*/@id = $this-model/tan:IRI]"/>
      <xsl:variable name="this-model-resolved"
         select="
            if (exists($model-already-resolved)) then
               $model-already-resolved
            else
               tan:resolve-doc(tan:get-1st-doc($this-model))"
         as="document-node()?"/>
      <xsl:variable name="this-model-expanded"
         select="tan:expand-doc($this-model-resolved, 'terse')"/>
      <xsl:variable name="self-and-model-merged"
         select="
            if (exists($this-model)) then
               tan:merge-expanded-docs((root(), $this-model-expanded))
            else
               ()"/>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics turned on, template class-1-expansion-verbose, for: ', ."/>
         <xsl:message select="'redivisions resolved: ', $these-redivisions"/>
         <xsl:message select="'redivision diffs: ', $these-redivision-diffs"/>
         <xsl:message select="'model resolved: ', $this-model-resolved"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="bad-see-alsos" select="$relevant-redivisions" tunnel="yes"/>
            <xsl:with-param name="text-redivisions" select="$redivision-diffs-prepped" tunnel="yes"/>
            <xsl:with-param name="self-and-model-merged" select="$self-and-model-merged"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   
   <xsl:template match="tan:redivision" mode="class-1-expansion-verbose-pass-2-old">
      <xsl:param name="bad-see-alsos" tunnel="yes"/>
      <xsl:variable name="this-is-bad" select="$bad-see-alsos/tan:IRI = tan:IRI"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$this-is-bad">
            <xsl:copy-of select="tan:error('cl104')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:body" mode="class-1-expansion-verbose-pass-2-old">
      <xsl:param name="text-redivisions" tunnel="yes"/>
      <xsl:variable name="this-revised-body"
         select="
            if (exists($text-redivisions)) then
               tan:analyze-leaf-div-string-length(.)
            else
               ."/>
      <xsl:variable name="leaf-div-pass-1" as="element()*">
         <!-- First, look to see if any leaf divs showed up as anomalies in the diff operation with any redivision -->
         <xsl:apply-templates select="$this-revised-body/*" mode="#current"/>
      </xsl:variable>
      <xsl:variable name="leaf-div-pass-2" as="element()*">
         <!-- Now collect adjacent groups of those erroneous divs, so that they might be rectified en bloc -->
         <xsl:for-each-group select="$leaf-div-pass-1//tan:div[not(tan:div)]"
            group-adjacent="exists(tan:error[@xml:id = 'cl104'])">
            <xsl:variable name="this-group" select="current-group()"/>

            <xsl:for-each select="current-group()[current-grouping-key()]">
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:if test="position() = 1 and count($this-group) gt 1">
                     <xsl:variable name="this-fix" as="element()*">
                        <xsl:for-each select="$this-group">
                           <xsl:variable name="this-div" select="."/>
                           <xsl:copy copy-namespaces="no">
                              <xsl:for-each
                                 select="@*[name(.) = ('n', 'type', 'ed-when', 'ed-who')]">
                                 <xsl:variable name="this-att-name" select="name(.)"/>
                                 <xsl:variable name="orig-attr"
                                    select="$this-div/@*[name(.) = concat('orig-', $this-att-name)]"/>
                                 <xsl:choose>
                                    <xsl:when test="exists($orig-attr)">
                                       <xsl:attribute name="{$this-att-name}" select="$orig-attr"/>
                                    </xsl:when>
                                    <xsl:otherwise>
                                       <xsl:copy-of select="."/>
                                    </xsl:otherwise>
                                 </xsl:choose>
                              </xsl:for-each>
                              <xsl:value-of select="tan:error[@xml:id = 'cl104']/tan:fix"/>
                           </xsl:copy>
                        </xsl:for-each>
                     </xsl:variable>
                     <xsl:copy-of
                        select="tan:error('cl104', concat(string(count($this-group)), ' adjacent leaf divs need fixing'), $this-fix, 'replace-self-and-next-leaf-divs')"
                     />
                  </xsl:if>
                  <xsl:copy-of select="node()"/>
               </xsl:copy>
            </xsl:for-each>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates select="$this-revised-body/node()" mode="#current">
            <xsl:with-param name="leaf-div-replacements" select="$leaf-div-pass-2" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:div" mode="class-1-expansion-verbose-pass-2-old">
      <xsl:param name="text-redivisions" tunnel="yes"/>
      <xsl:param name="leaf-div-replacements" as="element()*" tunnel="yes"/>
      <xsl:param name="self-and-model-merged" tunnel="yes"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="this-replacement" select="$leaf-div-replacements[@q = $this-q]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode class-1-expansion-verbose, for: ', ."/>
         <xsl:message select="'text redivisions: ', $text-redivisions"/>
         <xsl:message select="'leaf div replacements: ', $leaf-div-replacements"/>
         <xsl:message select="'self and model merged: ', $self-and-model-merged"/>
         <xsl:message select="'this replacement: ', $this-replacement"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="exists($this-replacement)">
            <xsl:copy-of select="$this-replacement"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="char-start" select="@string-pos" as="xs:integer?"/>
            <xsl:variable name="char-end" select="$char-start + xs:integer(@string-length)"
               as="xs:integer?"/>
            <xsl:variable name="these-redivisions" as="element()*">
               <xsl:for-each select="$text-redivisions">
                  <xsl:copy>
                     <xsl:copy-of select="@*"/>
                     <xsl:attribute name="alt" select="position()"/>
                     <xsl:copy-of
                        select="tan:c[xs:integer(@pos) ge $char-start and xs:integer(@pos) le $char-end]"
                     />
                  </xsl:copy>
               </xsl:for-each>
            </xsl:variable>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:variable name="this-text"
                  select="
                     tan:normalize-div-text(if (tan:tok) then
                        string-join((tan:tok, tan:non-tok), '')
                     else
                        text())"/>
               <xsl:if test="not(exists(tan:div)) and exists($these-redivisions)">
                  <!-- If it's a leaf div, and there is text from a redivision, process the options -->
                  <xsl:variable name="these-char-nos"
                     select="
                        for $i in (1 to @string-length)
                        return
                           @string-pos + $i"/>
                  <xsl:variable name="this-text-chopped" select="tan:chop-string($this-text)"/>
                  <xsl:variable name="this-char-count" select="count($this-text-chopped)"/>
                  <xsl:variable name="replacements" as="xs:string*">
                     <xsl:for-each select="$these-redivisions[tan:c]">
                        <xsl:variable name="these-cs" select="tan:c"/>
                        <xsl:variable name="pass1" as="xs:string*">
                           <xsl:for-each select="$this-text-chopped">
                              <xsl:variable name="this-pos" select="$char-start + position() - 1"/>
                              <xsl:variable name="this-cs" select="$these-cs[@pos = $this-pos]"/>
                              <xsl:value-of select="($this-cs[not(@insert)], .)[1]"/>
                              <xsl:value-of select="$this-cs[@insert]"/>
                              <xsl:if
                                 test="(position() = $this-char-count) and exists($this-cs/@nbsp)">
                                 <xsl:value-of select="$zwj"/>
                              </xsl:if>
                           </xsl:for-each>
                        </xsl:variable>
                        <xsl:value-of select="string-join($pass1, '')"/>
                     </xsl:for-each>
                  </xsl:variable>
                  <xsl:for-each select="$replacements">
                     <xsl:variable name="this-diff" select="tan:diff($this-text, .)"/>
                     <xsl:variable name="this-diff-trimmed"
                        select="tan:trim-long-text($this-diff, 17)"/>
                     <xsl:copy-of
                        select="tan:error('cl104', concat('Differs with copy (= b): ', tan:xml-to-string($this-diff-trimmed)), ., 'replace-text')"
                     />
                  </xsl:for-each>
               </xsl:if>

               <!-- Feedback on divs that are defective or where help is requested in @n -->
               <xsl:if test="exists($self-and-model-merged)">
                  <xsl:variable name="matching-merged-div"
                     select="key('div-via-ref', tan:ref/text(), $self-and-model-merged)"/>
                  <xsl:variable name="this-is-defective"
                     select="not($matching-merged-div/tan:src = '2')"/>
                  <xsl:variable name="model-children-missing-here"
                     select="$matching-merged-div/tan:div[not(@type = '#version')][not(tan:src = '1')]"/>
                  <xsl:variable name="n-needs-help" select="exists(tan:n/@help)"/>
                  <xsl:if test="$this-is-defective">
                     <xsl:copy-of
                        select="tan:error('cl107', 'no div with this ref appears in the model')"/>
                  </xsl:if>
                  <xsl:if test="exists($model-children-missing-here)">
                     <xsl:copy-of
                        select="tan:error('cl107', concat('children in model missing here: ', string-join($model-children-missing-here//tan:ref/text(), ', ')))"
                     />
                  </xsl:if>
                  <xsl:if test="$n-needs-help or $this-is-defective">
                     <xsl:variable name="unused-siblings-in-model"
                        select="$matching-merged-div/(preceding-sibling::tan:div, following-sibling::tan:div)[not(tan:src = '1')]"/>
                     <xsl:variable name="this-message"
                        select="
                           if (not(exists($unused-siblings-in-model))) then
                              'no siblings in the model suggest themselves as alternatives'
                           else
                              concat('the model has siblings not yet used here: ', string-join($unused-siblings-in-model/tan:ref/tan:n[last()], ', '))"/>
                     <xsl:variable name="this-fix" as="element()*">
                        <xsl:for-each select="$unused-siblings-in-model/tan:ref">
                           <element n="{tan:n[last()]}"/>
                        </xsl:for-each>
                     </xsl:variable>
                     <xsl:copy-of select="tan:help($this-message, $this-fix, 'copy-attributes')"/>
                  </xsl:if>
               </xsl:if>

               <!-- Check to see if the values of @n or @ref are present -->
               <xsl:if test="not(exists(tan:div))">
                  <xsl:variable name="go-up-to" select="20"/>
                  <xsl:variable name="opening-text" select="substring($this-text, 1, $go-up-to)"/>
                  <xsl:variable name="opening-text-analyzed"
                     select="tan:analyze-numbers-in-string($opening-text, true(), ())"/>
                  <xsl:variable name="opening-text-as-numerals"
                     select="tan:string-to-numerals($opening-text, true(), true(), ())"/>
                  <xsl:variable name="opening-text-replacement"
                     select="string-join($opening-text-analyzed/text(), '')"/>
                  <xsl:if test="($opening-text-analyzed/self::tan:tok)[1] = tan:n">
                     <xsl:copy-of
                        select="tan:error('cl115', 'opening seems to duplicate @n ', concat($opening-text-replacement, substring($this-text, $go-up-to + 1)), 'replace-text')"
                     />
                  </xsl:if>
                  <xsl:if test="$diagnostics-on">
                     <xsl:message select="'opening text: ', $opening-text"/>
                     <xsl:message select="'opening text analyzed: ', $opening-text-analyzed"/>
                     <xsl:message select="'opening text as numerals: ', $opening-text-as-numerals"/>
                     <xsl:message select="'opening text replacement: ', $opening-text-replacement"/>
                  </xsl:if>
                  <xsl:for-each select="tan:ref[tan:n]">
                     <xsl:variable name="n-qty" select="count(tan:n)"/>
                     <xsl:variable name="this-ref" select="text()"/>
                     <xsl:if
                        test="
                           ($n-qty gt 1) and
                           (every $i in (1 to $n-qty)
                              satisfies tan:n[$i] = ($opening-text-analyzed[@number])[$i])">
                        <xsl:copy-of
                           select="tan:error('cl116', concat('opening seems to duplicate the reference for this &lt;div>: ', $this-ref), concat($opening-text-replacement, substring($this-text, $go-up-to + 1)), 'replace-text')"
                        />
                     </xsl:if>
                  </xsl:for-each>
               </xsl:if>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>

         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="/*" mode="dependency-expansion-verbose">
      <xsl:param name="class-2-claims" tunnel="yes"/>
      <xsl:variable name="this-src" select="(@src, tan:head/@src)"/>
      <xsl:variable name="this-work" select="(@work)"/>
      <xsl:variable name="this-format" select="name(.)"/>
      <xsl:variable name="relevant-claims"
         select="
            $class-2-claims[if ($this-format = 'TAN-T-merge') then
               (../tan:work = $this-work)
            else
               ((tan:src, tan:tok-ref/tan:src) = $this-src)]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <expansion>verbose</expansion>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="class-2-claims" select="$relevant-claims" tunnel="yes"/>
            <xsl:with-param name="doc-format" select="$this-format" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:div" mode="dependency-expansion-verbose">
      <xsl:param name="class-2-claims" tunnel="yes"/>
      <xsl:variable name="this-ref" select="tan:ref/text()"/>
      <xsl:variable name="is-leaf-div" select="not(exists(tan:div))"/>
      <xsl:variable name="these-div-claims"
         select="$class-2-claims/self::tan:div-ref[tan:ref/text() = $this-ref]"/>
      <!-- If it's a leaf div, pass on exact ref matches; if it isn't a leaf div, pass on only references that go deeper -->
      <!-- In all cases, pass it on if there's no div ref -->
      <xsl:variable name="claims-to-pass-to-children"
         select="
            $class-2-claims[if (exists(tan:ref)) then
               tan:ref[if ($is-leaf-div) then
                  (text() = $this-ref)
               else
                  matches(text(), concat($this-ref, '\W'))]
            else
               true()]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:choose>
            <xsl:when test="exists($claims-to-pass-to-children)">
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="class-2-claims" select="$claims-to-pass-to-children"
                     tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="node()"/>
            </xsl:otherwise>
         </xsl:choose>
         <xsl:for-each select="$these-div-claims">
            <see-q>
               <xsl:value-of select="(ancestor-or-self::*/@q)[last()]"/>
            </see-q>
         </xsl:for-each>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:tok | tan:non-tok" mode="dependency-expansion-verbose">
      <xsl:param name="class-2-claims" tunnel="yes"/>
      <xsl:variable name="this-n" select="@n"/>
      <xsl:variable name="this-val" select="."/>
      <xsl:variable name="relevant-claims"
         select="
            $class-2-claims/self::tan:tok[if (exists(tan:tok-ref)) then
               (tan:tok-ref/tan:tok/@n = $this-n)
            else
               if (exists(tan:val)) then
                  tan:val = $this-val
               else
                  if (exists(tan:rgx)) then
                     (tan:matches($this-val, tan:rgx))
                  else
                     false()]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each select="$relevant-claims">
            <see-q>
               <xsl:value-of select="@q"/>
            </see-q>
         </xsl:for-each>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="text()" mode="dependency-expansion-verbose">
      <xsl:param name="token-definition" as="element()?" tunnel="yes"/>
      <xsl:choose>
         <xsl:when test="exists(parent::tan:div[not(tan:div)])">
            <xsl:copy-of select="tan:tokenize-text(., $token-definition, true())/*"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>


   <!-- MERGING -->

   <xsl:template match="tan:TAN-T/tan:head" mode="merge-expanded-docs-prep">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="../@*"/>
         <xsl:for-each select="../@src">
            <src>
               <xsl:value-of select="."/>
            </src>
         </xsl:for-each>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:TAN-T/tan:body" mode="merge-expanded-docs-prep">
      <xsl:param name="merge-doc-ids" tunnel="yes"/>
      <xsl:variable name="this-src-id" select="../@src"/>
      <xsl:variable name="this-doc-position" select="index-of($merge-doc-ids, ../@id)"/>
      <xsl:apply-templates mode="#current">
         <xsl:with-param name="src-id" select="($this-src-id, $this-doc-position)[1]" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:template>
   <xsl:template match="tan:div" mode="merge-expanded-docs-prep">
      <xsl:param name="src-id" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <src>
            <xsl:value-of select="$src-id"/>
         </src>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:merge-divs" as="item()*">
      <!-- See fuller version below -->
      <xsl:param name="expanded-class-1-fragment" as="item()*"/>
      <xsl:copy-of select="tan:merge-divs($expanded-class-1-fragment, true(), (), ())"/>
   </xsl:function>
   <xsl:function name="tan:merge-divs" as="item()*">
      <!-- See fuller version below -->
      <xsl:param name="expanded-class-1-fragment" as="item()*"/>
      <xsl:param name="itemize-leaf-divs" as="xs:boolean"/>
      <xsl:copy-of select="tan:merge-divs($expanded-class-1-fragment, $itemize-leaf-divs, (), ())"/>
   </xsl:function>
   <xsl:function name="tan:merge-divs" as="item()*">
      <!-- Input: expanded class 1 document fragment whose individual <div>s are assumed to be in the proper hierarchy (result of tan:normalize-text-hierarchy()); a boolean indicating whether leaf divs should be itemized; an optional string representing the name of an attribute to be checked for duplicates -->
      <!-- Output: the fragment with the <div>s grouped according to their <ref> values -->
      <!-- If the 2nd parameter is true, for each leaf <div> in a group there will be a separate <div type="#version">; otherwise leaf divs will be merely copied -->
      <!-- For merging multiple files normally the value should be true; if they are misfits from a single source, false -->
      <xsl:param name="expanded-class-1-fragment" as="item()*"/>
      <xsl:param name="itemize-leaf-divs" as="xs:boolean"/>
      <xsl:param name="exclude-elements-with-duplicate-values-of-what-attribute" as="xs:string?"/>
      <xsl:param name="keep-last-duplicate" as="xs:boolean?"/>
      <xsl:apply-templates select="$expanded-class-1-fragment" mode="merge-divs">
         <xsl:with-param name="itemize-leaf-divs" select="$itemize-leaf-divs" as="xs:boolean"
            tunnel="yes"/>
         <xsl:with-param name="duplicate-check"
            select="$exclude-elements-with-duplicate-values-of-what-attribute" tunnel="yes"/>
         <xsl:with-param name="keep-last-duplicate" select="$keep-last-duplicate" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>

   <xsl:function name="tan:group-divs" as="element()*">
      <!-- Input: expanded <div>s -->
      <!-- Output: those <div>s grouped in <group>s according to their <ref> values -->
      <!-- Attempt is made to preserve original orders by means of <src> -->
      <xsl:param name="divs-to-group" as="element()*"/>
      <!-- Begin looking for overlaps between divs by creating <div>s with only <ref> and the plain text reference -->
      <xsl:variable name="ref-group-prep" as="element()*">
         <xsl:for-each select="$divs-to-group">
            <xsl:copy>
               <xsl:for-each select="tan:ref">
                  <xsl:copy>
                     <xsl:value-of select="text()"/>
                  </xsl:copy>
               </xsl:for-each>
            </xsl:copy>
         </xsl:for-each>
      </xsl:variable>
      <!-- Now create groups of those stripped <div>s -->
      <xsl:variable name="ref-groups"
         select="tan:group-elements-by-shared-node-values($ref-group-prep, 'ref')" as="element()*"/>
      <xsl:variable name="sort-key-prep" as="element()*">
         <xsl:for-each-group select="$divs-to-group" group-by="tan:src">
            <a src="{current-grouping-key()}">
               <xsl:for-each select="current-group()/tan:ref[1]">
                  <xsl:variable name="this-first-ref" select="text()"/>
                  <ref>
                     <xsl:value-of
                        select="$ref-groups[tan:div/tan:ref = $this-first-ref]/tan:div[1]/tan:ref[1]"
                     />
                  </ref>
               </xsl:for-each>
            </a>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:variable name="sort-key" select="tan:collate-sequences($sort-key-prep)" as="xs:string*"/>
      <xsl:variable name="diagnostics-on" select="false()" as="xs:boolean"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:group-divs()'"/>
         <xsl:message select="'ref groups: ', $ref-groups"/>
         <xsl:message select="'sort key prep: ', $sort-key-prep"/>
         <xsl:message select="'sort key: ', $sort-key"/>
      </xsl:if>
      <xsl:for-each-group select="$divs-to-group"
         group-by="
            for $i in tan:ref[1]/text()
            return
               $ref-groups[tan:div/tan:ref = $i]/tan:div[1]/tan:ref[1]">
         <xsl:sort select="(index-of($sort-key, current-grouping-key()))[1]"/>
         <group>
            <xsl:copy-of select="current-group()"/>
         </group>
      </xsl:for-each-group>
   </xsl:function>

   <xsl:template match="tan:body" mode="merge-divs">
      <!--<xsl:variable name="these-children-divs-regrouped" as="element()*"
         select="tan:group-elements-by-shared-node-values(tan:div, '^ref$')"/>-->
      <xsl:variable name="these-children-divs-regrouped" as="element()*"
         select="tan:group-divs(tan:div)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="node() except tan:div"/>
         <xsl:apply-templates select="$these-children-divs-regrouped" mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:group" mode="merge-divs">
      <xsl:param name="itemize-leaf-divs" tunnel="yes" select="true()"/>
      <xsl:param name="duplicate-check" as="xs:string?" tunnel="yes"/>
      <xsl:param name="keep-last-duplicate" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="this-group-revised" as="element()">
         <xsl:choose>
            <xsl:when test="string-length($duplicate-check) gt 0">
               <xsl:apply-templates select="." mode="strip-duplicate-children-by-attribute-value">
                  <xsl:with-param name="attribute-to-check" select="$duplicate-check"/>
                  <xsl:with-param name="keep-last-duplicate" select="$keep-last-duplicate"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="."/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="children-divs" select="$this-group-revised/tan:div"/>
      <xsl:variable name="distinct-refs" select="distinct-values($children-divs/tan:ref/text())"/>
      <div>
         <xsl:copy-of select="$children-divs/@*"/>
         <xsl:copy-of
            select="$children-divs/(* except (tan:div, tan:tok, tan:non-tok, tan:ref, tei:*))"/>
         <!--<xsl:choose>
            <xsl:when test="$itemize-leaf-divs">
               <xsl:copy-of select="$children-divs/tan:src"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of
                  select="$children-divs/(* except (tan:div, tan:tok, tan:non-tok, tan:ref, tei:*))"
               />
            </xsl:otherwise>
         </xsl:choose>-->
         <xsl:for-each-group select="$children-divs/tan:ref" group-by="text()">
            <ref>
               <xsl:copy-of select="current-group()[1]/tan:n"/>
               <xsl:copy-of select="current-group()/tan:orig-ref"/>
               <xsl:value-of select="current-grouping-key()"/>
            </ref>
         </xsl:for-each-group>
         <xsl:for-each-group select="$children-divs" group-by="exists(tan:div)">
            <xsl:choose>
               <xsl:when test="current-grouping-key()">
                  <!-- if children divs are not leaf divs, then continue the process -->
                  <!--<xsl:apply-templates
                     select="tan:group-elements-by-shared-node-values(current-group()/tan:div, '^ref$')"
                     mode="#current"/>-->
                  <xsl:apply-templates select="tan:group-divs(current-group()/tan:div)"
                     mode="#current"/>
               </xsl:when>
               <xsl:when test="$itemize-leaf-divs">
                  <!-- process leaf divs of a TAN-T-merge here -->
                  <xsl:apply-templates select="current-group()" mode="#current"/>
               </xsl:when>
               <xsl:otherwise>
                  <!-- It is assumed that if leaf divs are not being itemized, they are not in a TAN-T-merge (i.e., a single source), and so you want to flag cases where leaf divs and non-leaf divs get mixed -->
                  <xsl:copy-of select="current-group()/(tan:tok, tan:non-tok)"/>
                  <xsl:value-of select="tan:text-join(current-group()/text())"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </div>
   </xsl:template>
   <xsl:template match="tan:div[not(tan:div)]" mode="merge-divs">
      <!-- Special feature to itemize leaf divs, to differentiate them in a merge from <div>s of other versions -->
      <xsl:variable name="new-refs" as="element()+">
         <xsl:variable name="this-src" select="concat('#', tan:src)"/>
         <xsl:for-each select="tan:ref">
            <xsl:copy>
               <xsl:value-of select="string-join((text(), $this-src), $separator-hierarchy)"/>
               <xsl:copy-of select="*"/>
               <v>
                  <xsl:value-of select="$this-src"/>
               </v>
            </xsl:copy>
         </xsl:for-each>
      </xsl:variable>
      <div type="#version">
         <xsl:copy-of select="@* except @type"/>
         <!-- if 'version' is already reserved as an idref for another div-type, the hash in the attribute can be used to disambiguate -->
         <type>version</type>
         <xsl:copy-of select="$new-refs"/>
         <xsl:copy-of select="node() except tan:ref"/>
      </div>
   </xsl:template>


   <!-- INFUSION -->

   <xsl:function name="tan:div-to-div-transfer" as="item()*">
      <!-- Two-parameter version of the fuller one, below -->
      <xsl:param name="items-with-div-content-to-be-transferred" as="item()*"/>
      <xsl:param name="items-whose-divs-should-be-infused-with-new-content" as="item()*"/>
      <xsl:copy-of
         select="tan:div-to-div-transfer($items-with-div-content-to-be-transferred, $items-whose-divs-should-be-infused-with-new-content, '\s+')"
      />
   </xsl:function>
   <xsl:function name="tan:div-to-div-transfer" as="item()*">
      <!-- Input: (1) any set of divs with content to be transferred into the structure of (2) another set of divs; and (3) a snap marker. -->
      <!-- Output: The div structure of (2), infused with the content of (1). The content is allocated  proportionately, with preference given to punctuation, within a certain range, and then word breaks. -->
      <!-- This function is useful for converting class-1 documents from one reference system to another. Normally the conversion is flawed, because two versions of the same work rarely synchronize, but this function provides a good estimate, or a starting point for manual correction. -->
      <!-- The raw text will be tokenized based on the third parameter, so that words, clauses, or sentences are not broken up. -->
      <xsl:param name="items-with-div-content-to-be-transferred" as="item()*"/>
      <xsl:param name="items-whose-divs-should-be-infused-with-new-content" as="item()*"/>
      <xsl:param name="break-at-regex" as="xs:string"/>
      <xsl:variable name="content" select="tan:text-join($items-with-div-content-to-be-transferred)"/>
      <xsl:copy-of
         select="tan:infuse-divs($content, $items-whose-divs-should-be-infused-with-new-content, $break-at-regex)"
      />
   </xsl:function>

   <xsl:function name="tan:infuse-divs" as="item()*">
      <!-- Input: a string; an XML fragment that has <div>s -->
      <!-- Output: the latter, infused with the former, following infusing text proportionate to the relative quantities of text being replaced -->
      <xsl:param name="new-content-to-be-transferred" as="xs:string?"/>
      <xsl:param name="items-whose-divs-should-be-infused-with-new-content" as="item()*"/>
      <xsl:param name="break-at-regex" as="xs:string"/>
      <xsl:variable name="snap-marker"
         select="
            if (string-length($break-at-regex) lt 1) then
               '\s+'
            else
               $break-at-regex"/>

      <xsl:variable name="new-content-tokenized"
         select="tan:chop-string($new-content-to-be-transferred, $snap-marker)"/>
      <xsl:variable name="new-content-key" as="xs:integer*">
         <!-- This variable is a key between the characters and the tokens (sometimes complete sentences), to provide better predictive accuracy -->
         <xsl:for-each select="$new-content-tokenized">
            <xsl:variable name="this-pos" select="position()"/>
            <xsl:for-each select="tan:chop-string(.)">
               <xsl:value-of select="$this-pos"/>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="attribute-names"
         select="
            for $i in $items-whose-divs-should-be-infused-with-new-content//@*
            return
               name($i)"/>
      <xsl:variable name="mold-prep-1" as="element()">
         <mold>
            <xsl:apply-templates select="$items-whose-divs-should-be-infused-with-new-content"
               mode="analyze-string-length-pass-1">
               <xsl:with-param name="mark-only-leaf-divs" select="false()" tunnel="yes"/>
            </xsl:apply-templates>
         </mold>
      </xsl:variable>
      <xsl:variable name="mold" as="element()">
         <xsl:apply-templates select="$mold-prep-1" mode="analyze-string-length-pass-2">
            <xsl:with-param name="parent-pos" select="0" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:variable name="mold-infused" as="element()">
         <xsl:apply-templates select="$mold" mode="infuse-tokenized-text">
            <xsl:with-param name="raw-content-tokenized" select="$new-content-tokenized"
               tunnel="yes"/>
            <xsl:with-param name="raw-content-key" select="$new-content-key" tunnel="yes"/>
            <xsl:with-param name="char-count-plus-1" select="count($new-content-key) + 1"
               tunnel="yes"/>
            <xsl:with-param name="total-length"
               select="sum(($mold//*:div)[last()]/(@string-length, @string-pos))" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:variable name="ks-to-ditch" as="element()*">
         <!-- We have inevitably assigned a string to more than one leaf div. We now look for duplicates, and keep only the one with the greatest amount of hypothesized overlap. -->
         <xsl:for-each-group select="$mold-infused//tan:k" group-by="@pos">
            <xsl:for-each select="current-group()">
               <xsl:sort select="xs:integer(@qty)" order="descending"/>
               <xsl:if test="position() gt 1">
                  <xsl:copy-of select="."/>
               </xsl:if>
            </xsl:for-each>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:variable name="mold-with-unique-ks" as="element()">
         <xsl:apply-templates select="$mold-infused" mode="infuse-tokenized-text-cleanup">
            <xsl:with-param name="bad-ks" select="$ks-to-ditch" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      <!-- diagnostics, results -->
      <!--<xsl:message>Diagnostics on</xsl:message>-->
      <!--<xsl:copy-of select="$mold-infused"/>-->
      <!--<xsl:copy-of select="$ks-to-ditch"/>-->
      <!--<xsl:copy-of select="$mold-with-unique-ks/*"/>-->
      <xsl:apply-templates select="$mold-with-unique-ks" mode="infuse-tokenized-div-end-check">
         <xsl:with-param name="bad-ks" select="$ks-to-ditch" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>

   <xsl:template match="*:div[not(*:div)]" mode="infuse-tokenized-text">
      <xsl:param name="raw-content-tokenized" as="xs:string*" tunnel="yes"/>
      <xsl:param name="raw-content-key" as="xs:integer*" tunnel="yes"/>
      <xsl:param name="char-count-plus-1" tunnel="yes" as="xs:integer"/>
      <xsl:param name="total-length" as="xs:double" tunnel="yes"/>
      <xsl:variable name="this-div-id" select="generate-id()"/>
      <xsl:variable name="this-n" select="@n"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:variable name="this-first" as="xs:double?"
            select="ceiling(@string-pos div $total-length * $char-count-plus-1)"/>
         <xsl:variable name="next-first" as="xs:double?"
            select="ceiling((@string-pos + @string-length) div $total-length * $char-count-plus-1)"/>
         <xsl:variable name="text-key"
            select="subsequence($raw-content-key, $this-first, ($next-first - $this-first))"/>
         <xsl:for-each-group select="$text-key" group-by=".">
            <k pos="{current-grouping-key()}" qty="{count(current-group())}" id="{$this-div-id}">
               <xsl:value-of select="$raw-content-tokenized[current-grouping-key()]"/>
            </k>
         </xsl:for-each-group>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="*:div" mode="infuse-tokenized-text-cleanup">
      <xsl:copy>
         <xsl:copy-of select="@* except (@string-length, @string-pos)"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:k" mode="infuse-tokenized-text-cleanup">
      <xsl:param name="bad-ks" tunnel="yes" as="element()*"/>
      <xsl:if
         test="
            not(some $i in $bad-ks
               satisfies $i/@id = @id and $i/@pos = @pos)">
         <xsl:value-of select="."/>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tan:mold" mode="infuse-tokenized-div-end-check">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <xsl:template match="*:div[not(*:div)]" mode="infuse-tokenized-div-end-check">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:value-of select="."/>
         <xsl:if test="matches(text(), '\S$')">
            <xsl:variable name="next-leaf" select="following::*:div[not(*:div)][text()][1]"/>
            <xsl:if test="matches($next-leaf/text(), '^\S')">
               <xsl:value-of select="$zwj"/>
            </xsl:if>
         </xsl:if>
      </xsl:copy>
   </xsl:template>



   <!-- ANALYSIS -->

   <xsl:function name="tan:analyze-string-length" as="item()*">
      <!-- One-parameter function of the two-parameter version below -->
      <xsl:param name="resolved-class-1-doc-or-fragment" as="item()*"/>
      <xsl:copy-of select="tan:analyze-string-length($resolved-class-1-doc-or-fragment, false())"/>
   </xsl:function>
   <xsl:function name="tan:analyze-string-length" as="item()*">
      <!-- Input: any class-1 document or fragment (or a result of tan:diff()); an indication whether string lengths should be added only to leaf divs, or to every div. -->
      <!-- Output: the same document, with @string-length and @string-pos added to every element -->
      <!-- Function to calculate string lengths of each leaf elements and their relative position, so that a raw text can be segmented proportionally and given the structure of a model exemplar. NB: any $special-end-div-chars that terminate a <div> not only will not be counted, but the
         assumed space that follows will also not be counted. On the other hand, the lack of a special
         character at the end means that the nominal space that follows a div will be included in both
         the length and the position. Thus input...
         <div type="m" n="1">abc&#xad;</div>
         <div type="m" n="2">def&#x200d;</div>
         <div type="m" n="3">ghi</div>
         <div type="m" n="4">xyz</div>
         ...presumes a raw joined text of "abcdefghi xyz ", and so becomes output:
         <div type="m" n="1" string-length="3" string-pos="1">abc&#xad;</div>
         <div type="m" n="2" string-length="3" string-pos="4">def&#x200d;</div>
         <div type="m" n="3" string-length="4" string-pos="7">ghi</div>
         <div type="m" n="4" string-length="4" string-pos="11">xyz</div> -->
      <!-- This function does the same thing as tan:analyze-leaf-div-string-length(), but approaches the problem in a two-template cycle, instead of a loop -->
      <xsl:param name="resolved-class-1-doc-or-fragment" as="item()*"/>
      <xsl:param name="mark-only-leaf-divs" as="xs:boolean"/>
      <xsl:variable name="pass-1" as="item()*">
         <xsl:apply-templates select="$resolved-class-1-doc-or-fragment"
            mode="analyze-string-length-pass-1">
            <xsl:with-param name="mark-only-leaf-divs" select="$mark-only-leaf-divs" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>
      <!-- diagnostics, results -->
      <!--<xsl:copy-of select="$pass-1"/>-->
      <xsl:apply-templates select="$pass-1" mode="analyze-string-length-pass-2">
         <xsl:with-param name="parent-pos" select="0" tunnel="yes"/>
         <xsl:with-param name="mark-only-leaf-elements" select="$mark-only-leaf-divs" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*:body | tan:div | tan:tok | tan:non-tok | tei:*"
      mode="analyze-string-length-pass-1">
      <xsl:param name="mark-only-leaf-divs" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="is-leaf" select="not(exists(*:div))" as="xs:boolean"/>
      <xsl:variable name="is-tok" select="exists(self::tan:tok) or exists(self::tan:non-tok)"
         as="xs:boolean"/>
      <xsl:choose>
         <xsl:when test="$mark-only-leaf-divs and not($is-leaf)">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <!-- The string length will include the hypothetical space that follows the div (or if an special end-div marker is present, the space  and the marker will be ignored -->
               <xsl:attribute name="string-length"
                  select="
                     tan:string-length(if ($is-tok) then
                        .
                     else
                        tan:text-join(.))"/>
               <xsl:choose>
                  <xsl:when test="$is-leaf and $mark-only-leaf-divs">
                     <xsl:copy-of select="node()"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates mode="#current"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:copy>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="tan:a | tan:b | tan:common" mode="analyze-string-length-pass-1">
      <!-- To process tan:diff() results -->
      <xsl:variable name="this-length" select="string-length(.)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="self::tan:common or self::tan:a">
            <xsl:attribute name="s1-length" select="$this-length"/>
         </xsl:if>
         <xsl:if test="self::tan:common or self::tan:b">
            <xsl:attribute name="s2-length" select="$this-length"/>
         </xsl:if>
         <xsl:copy-of select="text()"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="*[@string-length or @s1-length or @s2-length]"
      mode="analyze-string-length-pass-2">
      <xsl:param name="parent-pos" as="xs:integer" tunnel="yes"/>
      <xsl:param name="mark-only-leaf-elements" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="is-tei" select="exists(self::tei:*)" as="xs:boolean"/>
      <xsl:variable name="preceding-nodes"
         select="
            if ($is-tei) then
               preceding-sibling::node()//descendant-or-self::text()
            else
               if ($mark-only-leaf-elements = true()) then
                  preceding-sibling::*//descendant-or-self::*[not(*)]
               else
                  preceding-sibling::*"/>
      <xsl:variable name="preceding-string-lengths" select="$preceding-nodes/@string-length"/>
      <xsl:variable name="preceding-sibling-pos" as="xs:integer">
         <xsl:choose>
            <xsl:when test="$is-tei">
               <xsl:copy-of select="string-length(string-join($preceding-nodes, ''))"/>
            </xsl:when>
            <xsl:when test="exists($preceding-string-lengths)">
               <xsl:copy-of select="xs:integer(sum($preceding-string-lengths))"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="0"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="this-string-pos" select="$parent-pos + $preceding-sibling-pos"
         as="xs:integer?"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists(@string-length)">
            <xsl:attribute name="string-pos" select="$this-string-pos + 1"/>
         </xsl:if>
         <!-- next items for tan:s1 | tan:s2 | tan:common, from the diff function -->
         <xsl:if test="exists(@s1-length)">
            <xsl:attribute name="s1-pos" select="sum(preceding-sibling::*/@s1-length) + 1"/>
         </xsl:if>
         <xsl:if test="exists(@s2-length)">
            <xsl:attribute name="s2-pos" select="sum(preceding-sibling::*/@s2-length) + 1"/>
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="parent-pos" select="$this-string-pos" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:analyze-leaf-div-string-length" as="item()*">
      <!-- Input: any class 1 document fragment, or result of tan:diff() -->
      <!-- Output: Every leaf div or common/a/b stamped with @string-length and @string-pos, indicating how long the text node is, and where it is relative to all other leaf text nodes, after TAN text normalization rules have been applied. -->
      <!-- This function is useful for statistical processing, and for comparing a TAN-T(EI) file against a redivision. -->
      <!-- It has also been designed to stamp the <a> and <common> results of tan:diff(), to facilitate SQFs that replace a text with that of the other version. -->
      <!-- This function does the same thing as tan:analyze-string-length(), but approaches the problem with a recursive loop -->
      <xsl:param name="document-fragment" as="item()*"/>
      <xsl:copy-of select="tan:analyze-leaf-div-text-length-loop($document-fragment, 0, false())"/>
   </xsl:function>
   <xsl:function name="tan:analyze-leaf-div-text-length-loop" as="item()*">
      <!-- Loop function for the master one, above. -->
      <xsl:param name="items-to-process" as="item()*"/>
      <xsl:param name="char-count-so-far" as="xs:integer"/>
      <xsl:param name="return-final-count" as="xs:boolean"/>
      <xsl:variable name="first-item-to-process" select="$items-to-process[1]"/>
      <xsl:choose>
         <xsl:when test="not(exists($first-item-to-process)) and not($return-final-count)"/>
         <xsl:when test="not(exists($first-item-to-process)) and $return-final-count">
            <xsl:copy-of select="$char-count-so-far"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:choose>
               <xsl:when test="$first-item-to-process instance of document-node()">
                  <xsl:document>
                     <xsl:copy-of
                        select="tan:analyze-leaf-div-text-length-loop(($first-item-to-process/node(), $items-to-process[position() gt 1]), $char-count-so-far, $return-final-count)"
                     />
                  </xsl:document>
               </xsl:when>
               <xsl:when
                  test="
                     $first-item-to-process instance of comment()
                     or $first-item-to-process instance of processing-instruction()
                     or $first-item-to-process instance of text()">
                  <xsl:copy-of select="$first-item-to-process"/>
                  <xsl:copy-of
                     select="tan:analyze-leaf-div-text-length-loop($items-to-process[position() gt 1], $char-count-so-far, $return-final-count)"
                  />
               </xsl:when>
               <xsl:when test="$first-item-to-process instance of element()">
                  <xsl:variable name="this-name" select="name($first-item-to-process)"/>
                  <xsl:variable name="add-this-element-text-to-count"
                     select="
                        ($this-name = 'div' and not($first-item-to-process/tan:div))
                        or $this-name = ('common', 'a')"
                     as="xs:boolean"/>
                  <xsl:variable name="stamp-this-element"
                     select="$add-this-element-text-to-count or $this-name = 'b'"/>
                  <xsl:choose>
                     <xsl:when test="$stamp-this-element">
                        <xsl:variable name="this-text"
                           select="
                              if ($first-item-to-process/tan:tok) then
                                 string-join($first-item-to-process/(tan:tok, tan:non-tok), '')
                              else
                                 $first-item-to-process/text()"/>
                        <xsl:variable name="this-text-norm"
                           select="
                              if ($this-name = 'div') then
                                 tan:normalize-div-text($this-text)
                              else
                                 $this-text"/>
                        <xsl:variable name="this-length" select="tan:string-length($this-text-norm)"/>
                        <xsl:variable name="new-char-count"
                           select="
                              if ($add-this-element-text-to-count) then
                                 $char-count-so-far + $this-length
                              else
                                 $char-count-so-far"/>
                        <xsl:element name="{$this-name}">
                           <xsl:copy-of select="$first-item-to-process/@*"/>
                           <xsl:attribute name="string-length" select="$this-length"/>
                           <xsl:attribute name="string-pos" select="$char-count-so-far + 1"/>
                           <!--<xsl:if test="$add-this-element-text-to-count">
                              <xsl:attribute name="string-pos" select="$char-count-so-far + 1"/>
                           </xsl:if>-->
                           <xsl:copy-of select="$first-item-to-process/node()"/>
                        </xsl:element>
                        <xsl:copy-of
                           select="tan:analyze-leaf-div-text-length-loop($items-to-process[position() gt 1], $new-char-count, $return-final-count)"
                        />
                     </xsl:when>

                     <xsl:otherwise>
                        <xsl:variable name="processed-children-and-count" as="item()*">
                           <xsl:copy-of
                              select="tan:analyze-leaf-div-text-length-loop($first-item-to-process/node(), $char-count-so-far, true())"
                           />
                        </xsl:variable>
                        <xsl:variable name="new-count"
                           select="$processed-children-and-count[last()]"/>
                        <xsl:for-each select="$first-item-to-process">
                           <xsl:copy>
                              <xsl:copy-of select="@*"/>
                              <xsl:copy-of
                                 select="$processed-children-and-count[position() lt last()]"/>
                           </xsl:copy>
                        </xsl:for-each>
                        <xsl:copy-of
                           select="tan:analyze-leaf-div-text-length-loop($items-to-process[position() gt 1], $new-count, $return-final-count)"
                        />
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:when>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

</xsl:stylesheet>
