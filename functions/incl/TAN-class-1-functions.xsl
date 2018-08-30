<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:fn="http://www.w3.org/2005/xpath-functions"
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

   <!-- redivisions -->
   <xsl:variable name="redivisions-1st-da" select="tan:get-1st-doc($head/tan:redivision)"/>
   <xsl:variable name="redivisions-resolved" select="tan:resolve-doc($redivisions-1st-da)"/>
   
   <!-- models -->
   <xsl:variable name="models-1st-da" select="tan:get-1st-doc($head/tan:model)"/>
   <xsl:variable name="models-resolved" select="tan:resolve-doc($models-1st-da)"/>
   
   <!-- annotations -->
   <xsl:variable name="annotations-1st-da" select="tan:get-1st-doc($head/tan:annotation)"/>
   <xsl:variable name="annotations-resolved" select="tan:resolve-doc($annotations-1st-da)"/>
   
   

   <!-- CLASS 1 FUNCTIONS: TEXT -->

   <xsl:variable name="special-end-div-chars" select="($zwj, $dhy)" as="xs:string+"/>
   <xsl:variable name="special-end-div-chars-regex"
      select="concat('[', string-join($special-end-div-chars, ''), ']\s*$')" as="xs:string"/>
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
   <xsl:template match="*" mode="text-join">
      <xsl:apply-templates select="*" mode="text-join"/>
   </xsl:template>
   <xsl:template match="*:div[not(*:div)]" mode="text-join">
      <xsl:variable name="text-nodes" select="text()[matches(., '\S')]"/>
      <xsl:variable name="is-not-last-leaf-div"
         select="exists(following::*:div[not(*:div)][text()[matches(., '\S')] or tan:tok or tei:*])"/>
      <xsl:variable name="text-nodes-to-process" as="xs:string*">
         <xsl:choose>
            <xsl:when test="exists(tan:tok)">
               <xsl:sequence select="(tan:tok, tan:non-tok)/text()"/>
            </xsl:when>
            <xsl:when test="exists($text-nodes)">
               <xsl:sequence select="text()"/>
            </xsl:when>
            <xsl:when test="exists(tei:*)">
               <xsl:value-of select="normalize-space(string-join(descendant::tei:*/text(), ''))"/>
            </xsl:when>
         </xsl:choose>
      </xsl:variable>
      <!--<xsl:if test="exists($text-nodes-to-process) and (@type = ('s','par','ic'))">
         <xsl:message select="., $is-not-last-leaf-div"/></xsl:if>-->
      <xsl:value-of select="tan:normalize-div-text($text-nodes-to-process, $is-not-last-leaf-div)"/>
   </xsl:template>

   <xsl:function name="tan:normalize-div-text" as="xs:string*">
      <!-- One-parameter version of the fuller one, below. -->
      <xsl:param name="div-text-nodes" as="xs:string*"/>
      <xsl:copy-of select="tan:normalize-div-text($div-text-nodes, false())"/>
   </xsl:function>
   <xsl:function name="tan:normalize-div-text" as="xs:string*">
      <!-- Input: any sequence of strings, presumed to be text nodes of a single leaf div; a boolean indicating whether special div-end characters should be retained or not -->
      <!-- Output: the same sequence, normalized according to TAN rules. Each item in the sequence is space normalized and then if its end matches one of the special div-end characters, ZWJ U+200D or SOFT HYPHEN U+AD, the character is removed; otherwise a space is added at the end. Zero-length strings are skipped. -->
      <!-- This function is designed specifically for TAN's commitment to nonmixed content. That is, every TAN element contains either elements or non-whitespace text but not both, which also means that whitespace text nodes are effectively ignored. It is assumed that every TAN element is followed by a notional whitespace. -->
      <!-- The second parameter is important, because output will be used to normalize and repopulate leaf <div>s (where special div-end characters should be retained) or to concatenate leaf <div> text (where those characters should be deleted) -->
      <xsl:param name="div-text-nodes" as="xs:string*"/>
      <xsl:param name="remove-special-div-end-chars" as="xs:boolean"/>
      <xsl:variable name="string-count" select="count($div-text-nodes)"/>
      <xsl:for-each select="$div-text-nodes">
         <xsl:variable name="this-norm" select="normalize-space(.)"/>
         <xsl:variable name="ends-in-special-char"
            select="matches($this-norm, $special-end-div-chars-regex)"/>
         <xsl:choose>
            <xsl:when test="string-length(.) lt 1"/>
            <xsl:when test="position() lt $string-count">
               <!-- We copy preliminary segments as-is, because no special treatment of the last character is needed -->
               <xsl:value-of select="$this-norm"/>
            </xsl:when>
            <!-- The following cases deal with how a <div>'s text should end -->
            <xsl:when test="$ends-in-special-char and ($remove-special-div-end-chars = false())">
               <xsl:value-of select="$this-norm"/>
            </xsl:when>
            <xsl:when test="$ends-in-special-char">
               <xsl:value-of select="replace($this-norm, $special-end-div-chars-regex, '')"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- Any div ending in something other than a special character is assumed to have a space character, which we add here explicitly -->
               <xsl:value-of select="concat($this-norm, ' ')"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
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
      <xsl:variable name="this-text" select="tan:normalize-div-text(., true())"/>
      <xsl:variable name="prev-leaf" select="preceding::tan:div[not(tan:div)][1]"/>
      <xsl:variable name="first-tok-is-fragment"
         select="matches($prev-leaf, $special-end-div-chars-regex)"/>
      <xsl:variable name="this-tokenized" as="element()*">
         <xsl:copy-of select="tan:tokenize-text($this-text, $token-definition, true())"/>
      </xsl:variable>
      <xsl:variable name="last-tok" select="$this-tokenized/tan:tok[last()]"/>
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
            <!--<tok>
               <xsl:value-of
                  select="replace($last-tok, concat($special-end-div-chars-regex, '\s*'), '')"/>
               <xsl:value-of select="$next-leaf-tokenized/tan:tok[xs:integer(@n) = 1]"/>
            </tok>-->
            <!--<xsl:copy-of select="$next-leaf-tokenized/tan:non-tok[xs:integer(@n) = 1]"/>-->
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

   <xsl:template match="tan:work" mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="matches(@include, '\s')">
            <xsl:copy-of select="tan:error('cl108')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:redivision" mode="core-expansion-terse">
      <xsl:variable name="these-iris" select="tan:IRI"/>
      <xsl:variable name="this-redivision-doc-resolved" select="$redivisions-resolved[*/@id = $these-iris]"/>
      <xsl:variable name="target-1st-da" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="target-doc-resolved"
         select="
            if (exists($this-redivision-doc-resolved)) then
               $this-redivision-doc-resolved
            else
               tan:resolve-doc($target-1st-da)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="not(/*/tan:head/tan:source/tan:IRI = $target-doc-resolved/*/tan:head/tan:source/tan:IRI)">
            <xsl:copy-of select="tan:error('cl101')"/>
         </xsl:if>
         <xsl:if test="not(/*/tan:head/tan:work/tan:IRI = $target-doc-resolved/*/tan:head/tan:work/tan:IRI)">
            <xsl:copy-of select="tan:error('cl102')"/>
         </xsl:if>
         <xsl:if
            test="
               exists(/tan:TAN-T/tan:head/tan:version) and
               exists($target-doc-resolved/*/tan:head/tan:version) and
               not(/*/tan:head/tan:version/tan:IRI = $target-doc-resolved/*/tan:head/tan:version/tan:IRI)">
            <xsl:copy-of select="tan:error('cl103')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:model" mode="core-expansion-terse">
      <xsl:variable name="these-iris" select="tan:IRI"/>
      <xsl:variable name="this-model-doc-resolved" select="$models-resolved[*/@id = $these-iris]"/>
      <xsl:variable name="target-1st-da" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="target-doc-resolved"
         select="
            if (exists($this-model-doc-resolved)) then
               $this-model-doc-resolved
            else
               tan:resolve-doc($target-1st-da)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(/*/tan:head/tan:work/tan:IRI = $target-doc-resolved/*/tan:head/tan:work/tan:IRI)">
            <xsl:copy-of select="tan:error('cl102')"/>
         </xsl:if>
         <xsl:variable name="other-models"
            select="(preceding-sibling::tan:model, following-sibling::tan:model)"/>
         <xsl:if test="exists($other-models)">
            <xsl:copy-of select="tan:error('cl106')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tei:teiHeader" mode="#all" priority="-4">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tei:div[not(tei:div)]/tei:*"
      mode="resolve-numerals core-expansion-terse-attributes">
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="tan:TAN-T | tei:TEI" mode="core-expansion-terse dependency-expansion-terse">
      <!-- Homogenize tei:TEI to tan:TAN-T -->
      <xsl:param name="class-2-doc" tunnel="yes" as="document-node()?"/>
      <!--<xsl:param name="definitions" tunnel="yes" as="element()*"/>-->
      <xsl:variable name="vocabulary" select="$class-2-doc/*/tan:head/tan:vocabulary-key"/>
      <xsl:variable name="this-src-id" select="@src"/>
      <xsl:variable name="is-self" select="@id = $doc-id" as="xs:boolean"/>
      <xsl:variable name="this-expansion" select="'terse'"/>
      <xsl:variable name="this-work-group"
         select="$vocabulary/tan:group[tan:work/@src = $this-src-id]"/>
      <xsl:variable name="these-div-types" select="tan:head/tan:vocabulary-key/tan:div-type"/>
      <xsl:variable name="these-adjustments"
         select="
            $class-2-doc/*/tan:head/tan:adjustments[(tan:src, tan:where/tan:src) = $this-src-id][if (exists(tan:div-type)) then
               tan:div-type = $these-div-types/@xml:id
            else
               true()]"/>
      <xsl:variable name="this-last-change-agent" select="tan:last-change-agent(root())"/>
      <TAN-T>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($this-work-group)">
            <xsl:attribute name="work" select="$this-work-group/@n"/>
         </xsl:if>
         <xsl:if test="exists($this-last-change-agent/self::tan:algorithm)">
            <xsl:copy-of select="tan:error('wrn07', 'The last change was made by an algorithm.')"/>
         </xsl:if>
         <expanded>terse</expanded>
         <xsl:variable name="these-skips"
            select="
               $these-adjustments/tan:skip[if (exists(tan:div-type)) then
                  tan:div-type = $these-div-types/@xml:id
               else
                  true()]"/>
         <xsl:variable name="these-renames"
            select="
               $these-adjustments/tan:rename[if (exists(tan:div-type)) then
                  tan:div-type = $these-div-types/@xml:id
               else
                  true()]"/>
         <xsl:variable name="these-equates" select="$these-adjustments/tan:equate[exists(tan:n)]"/>
         <xsl:choose>
            <xsl:when
               test="exists($these-skips) or exists($these-renames) or exists($these-equates)">
               <xsl:apply-templates mode="dependency-expansion-terse">
                  <xsl:with-param name="adjustment-skips" tunnel="yes" select="$these-skips"/>
                  <xsl:with-param name="adjustment-renames" tunnel="yes" select="$these-renames"/>
                  <xsl:with-param name="adjustment-equates" tunnel="yes" select="$these-equates"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates mode="core-expansion-terse"/>
            </xsl:otherwise>
         </xsl:choose>
      </TAN-T>
   </xsl:template>
   <xsl:template match="tei:body" mode="core-expansion-terse dependency-expansion-terse">
      <body>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </body>
   </xsl:template>
   <xsl:template match="tei:text" mode="core-expansion-terse dependency-expansion-terse">
      <!-- Makes sure the tei:body rises rootward one level, as is customary in TAN and HTML -->
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <xsl:template match="tan:div | tei:div"
      mode="core-expansion-terse dependency-expansion-terse-no-adjustments">
      <!-- streamlined expansion of <div>s; applied to dependencies of class-2 files only when there are no more adjustment items to process -->
      <xsl:param name="parent-new-refs" as="element()*" select="$empty-element"/>
      <xsl:variable name="is-tei" select="namespace-uri() = 'http://www.tei-c.org/ns/1.0'"
         as="xs:boolean"/>
      <xsl:variable name="this-n-analyzed" select="tan:analyze-sequence(@n, 'n', true())"/>
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
      <xsl:variable name="text-space-normalized" as="xs:string?">
         <xsl:if test="$is-leaf-div">
            <xsl:choose>
               <xsl:when test="exists(tei:*)">
                  <xsl:value-of select="normalize-space(string-join(tei:*//text(), ''))"/>
               </xsl:when>
               <xsl:otherwise>
                  <!-- joining must happen first, in case there are comments breaking up the text -->
                  <xsl:value-of select="normalize-space(string-join(text(), ''))"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
      </xsl:variable>
      <div>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$this-n-analyzed/*"/>
         <xsl:copy-of select="$new-refs"/>
         <xsl:if test="$is-tei">
            <xsl:if test="exists(@include) and exists(@*[not(name() = ('ed-who', 'ed-when'))])">
               <xsl:copy-of select="tan:error('tei02')"/>
            </xsl:if>
            <xsl:if test="not(exists(@n) and exists(@type)) and not(exists(@include))">
               <xsl:copy-of select="tan:error('tei03')"/>
            </xsl:if>
         </xsl:if>
         <xsl:apply-templates select="*" mode="#current">
            <xsl:with-param name="parent-new-refs" select="$new-refs"/>
         </xsl:apply-templates>
         <xsl:value-of select="$text-space-normalized"/>
      </div>
   </xsl:template>

   <xsl:template match="tan:div | tei:div" mode="dependency-expansion-terse">
      <!-- This template serves to make adjustments declared in the <adjustments> of a class 2 file upon a dependency class 1 file. -->
      <!-- In the course of <adjustments>, errors may be detected that should be reported to the dependent class 2 file. In those cases, the specific instruction is copied along with its @q value, and the error is embedded inside. That way when the normalized source file is returned to the class 2 file, the specific error can be matched with the specific instruction in the <adjustments>. -->
      <xsl:param name="adjustment-skips" tunnel="yes" as="element()*"/>
      <xsl:param name="adjustment-renames" tunnel="yes" as="element()*"/>
      <xsl:param name="adjustment-equates" tunnel="yes" as="element()*"/>
      <xsl:param name="parent-orig-refs" as="element()*" select="$empty-element"/>
      <xsl:param name="parent-new-refs" as="element()*" select="$empty-element"/>
      <xsl:variable name="diagnostics" as="xs:boolean" select="false()"/>
      <xsl:if test="$diagnostics">
         <xsl:message>Diagnostics turned on for template mode
            dependency-expansion-terse</xsl:message>
      </xsl:if>
      <xsl:variable name="is-tei" select="namespace-uri() = 'http://www.tei-c.org/ns/1.0'"
         as="xs:boolean"/>
      <xsl:variable name="this-type-analyzed" select="tan:analyze-sequence(@type, 'type', false())"/>
      <xsl:variable name="this-n-analyzed" select="tan:analyze-sequence(@n, 'n', true())"/>

      <xsl:variable name="orig-refs" as="element()*">
         <xsl:for-each select="$parent-orig-refs">
            <xsl:variable name="this-ref" select="."/>
            <xsl:for-each select="$this-n-analyzed/*">
               <ref>
                  <xsl:value-of select="string-join(($this-ref/text(), .), $separator-hierarchy)"/>
                  <xsl:copy-of select="$this-ref/*"/>
                  <xsl:copy-of select="."/>
               </ref>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>

      <!-- Before renaming, we deal with skips, the more drastic action. -->
      <!-- The expression below looks to see the div has a flagged reference (using the pre-modified reference system), @n, @type, or @n + @type combination. -->
      <xsl:variable name="skip-instructions"
         select="
            $adjustment-skips[tan:ref/text() = $orig-refs/text()
            or (tan:div-type = $this-type-analyzed and not(exists(tan:n)))
            or (tan:n = $this-n-analyzed/* and not(exists(tan:div-type)))
            or (tan:div-type = $this-type-analyzed and tan:n = $this-n-analyzed)]"/>
      <xsl:variable name="first-skip-instruction" select="$skip-instructions[1]"/>

      <xsl:choose>
         <xsl:when test="exists($skip-instructions)">
            <skip>
               <xsl:copy-of select="$first-skip-instruction/@*"/>
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
               </xsl:copy>
               <xsl:copy-of select="$first-skip-instruction/node()"/>
            </skip>
            <xsl:if test="count($skip-instructions) gt 1">
               <xsl:for-each select="$skip-instructions">
                  <xsl:copy>
                     <xsl:copy-of select="@*"/>
                     <xsl:copy-of select="tan:error('cl214')"/>
                  </xsl:copy>
               </xsl:for-each>
            </xsl:if>
            <!-- if it's a shallow skip, keep going -->
            <xsl:if
               test="not(exists($first-skip-instruction/@shallow)) or $first-skip-instruction/@shallow = true()">
               <xsl:apply-templates select="*" mode="#current">
                  <!-- original refs retain this node's properties, even if it is being skipped, to trace refs based on the legacy system -->
                  <xsl:with-param name="parent-orig-refs" select="$orig-refs"/>
                  <xsl:with-param name="parent-new-refs" select="$parent-new-refs"/>
               </xsl:apply-templates>
            </xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <!-- We are not skipping, so now we can analyze renaming, aliases -->
            <xsl:variable name="possible-rename-rules"
               select="
                  $adjustment-renames[not(exists(tan:div-type))
                  or tan:div-type = $this-type-analyzed/*]"/>

            <xsl:variable name="new-ns" as="element()*">
               <xsl:for-each select="$this-n-analyzed/*">
                  <xsl:variable name="this-n" select="."/>
                  <xsl:variable name="specific-renames"
                     select="$possible-rename-rules[(tan:n, tan:range/tan:n) = $this-n]"/>
                  <xsl:variable name="first-rename" select="$specific-renames[1]"/>
                  <xsl:variable name="pass-1-rename" as="element()">
                     <xsl:choose>
                        <xsl:when test="not(exists($first-rename))">
                           <xsl:sequence select="$this-n"/>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:copy>
                              <xsl:copy-of select="@*"/>
                              <xsl:if test="count($specific-renames) gt 1">
                                 <xsl:for-each select="$specific-renames">
                                    <xsl:copy>
                                       <xsl:copy-of select="@*"/>
                                       <xsl:copy-of
                                          select="tan:error('cl212', concat('duplicate renaming rules for @n ', $this-n, '; only the first has been applied'))"
                                       />
                                    </xsl:copy>
                                 </xsl:for-each>
                              </xsl:if>
                              <xsl:choose>
                                 <xsl:when test="exists($first-rename/@new)">
                                    <xsl:value-of select="$first-rename/@new"/>
                                 </xsl:when>
                                 <xsl:when
                                    test="exists($first-rename/@by) and not($this-n castable as xs:integer)">
                                    <rename>
                                       <xsl:copy-of select="$first-rename/@*"/>
                                       <xsl:copy-of select="tan:error('cl213')"/>
                                    </rename>
                                    <xsl:value-of select="$this-n"/>
                                 </xsl:when>
                                 <xsl:when test="exists($first-rename/@by)">
                                    <xsl:variable name="incr" select="xs:integer($first-rename/@by)"/>
                                    <xsl:value-of
                                       select="xs:integer($this-n) + xs:integer($first-rename/@by)"
                                    />
                                 </xsl:when>
                                 <xsl:otherwise>
                                    <xsl:value-of select="$this-n"/>
                                 </xsl:otherwise>
                              </xsl:choose>
                              <orig-n>
                                 <xsl:value-of select="$this-n"/>
                              </orig-n>
                              <xsl:copy-of select="tan:shallow-copy($specific-renames)"/>
                           </xsl:copy>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>
                  <!-- now supply alias via equated n's -->
                  <xsl:for-each select="$pass-1-rename">
                     <xsl:variable name="this-n" select="text()"/>
                     <xsl:if test="$diagnostics">
                        <xsl:message select="$this-n"/>
                     </xsl:if>
                     <xsl:copy-of select="."/>
                     <xsl:copy-of
                        select="$adjustment-equates[tan:n = $this-n]/tan:n[not(. = $this-n)]"/>
                  </xsl:for-each>
               </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="new-refs" as="element()*">
               <xsl:for-each select="$new-ns">
                  <xsl:variable name="this-n" select="."/>
                  <xsl:variable name="this-n-val" select="$this-n/text()"/>
                  <xsl:for-each select="$parent-new-refs">
                     <xsl:variable name="this-ref"
                        select="normalize-space(string-join((text(), $this-n-val), $separator-hierarchy))"/>
                     <xsl:variable name="specific-renames"
                        select="$possible-rename-rules[(tan:ref/text(), tan:range/tan:ref/text()) = $this-ref]"/>
                     <xsl:variable name="first-rename" select="$specific-renames[1]"/>
                     <ref>
                        <xsl:if test="count($specific-renames) gt 1">
                           <xsl:for-each select="$specific-renames">
                              <xsl:copy>
                                 <xsl:copy-of select="@*"/>
                                 <xsl:copy-of
                                    select="tan:error('cl212', concat('duplicate renaming rules for ref with @n ', $this-n-val, '; only the first has been applied'))"
                                 />
                              </xsl:copy>
                           </xsl:for-each>
                        </xsl:if>
                        <xsl:choose>
                           <xsl:when test="exists($first-rename/@new)">
                              <xsl:variable name="these-old-refs"
                                 select="$first-rename/(tan:ref, tan:range/tan:ref)/text()"/>
                              <xsl:variable name="this-place"
                                 select="index-of($these-old-refs, $this-ref)[1]"/>
                              <xsl:variable name="this-new"
                                 select="$first-rename/(tan:new, tan:range/tan:new)[$this-place]/text()"/>
                              <xsl:value-of select="$this-new"/>
                              <xsl:for-each select="tokenize($this-new, ' ')">
                                 <n>
                                    <xsl:value-of select="."/>
                                 </n>
                              </xsl:for-each>
                           </xsl:when>
                           <xsl:when
                              test="exists($first-rename/@by) and not($this-n-val castable as xs:integer)">
                              <rename>
                                 <xsl:copy-of select="$first-rename/*"/>
                                 <xsl:copy-of select="tan:error('cl213')"/>
                              </rename>
                              <xsl:value-of select="$this-n-val"/>
                           </xsl:when>
                           <xsl:when test="exists($first-rename/@by)">
                              <xsl:variable name="incr" select="xs:integer($first-rename/@by)"/>
                              <xsl:variable name="new-last-n"
                                 select="xs:integer($this-n-val) + xs:integer($first-rename/@by)"/>
                              <xsl:value-of
                                 select="normalize-space(string-join((text(), xs:string($new-last-n)), $separator-hierarchy))"/>
                              <xsl:copy-of select="tan:n"/>
                              <n>
                                 <xsl:value-of select="$new-last-n"/>
                              </n>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:value-of select="$this-ref"/>
                              <xsl:copy-of select="tan:n"/>
                              <n>
                                 <xsl:value-of select="$this-n-val"/>
                              </n>
                           </xsl:otherwise>
                        </xsl:choose>
                        <xsl:if test="exists($first-rename)">
                           <!-- We signal that an adjustment action has been acted on by copying the original reference, followed by a copy of the adjustment action -->
                           <orig-ref>
                              <xsl:value-of select="$this-ref"/>
                           </orig-ref>
                           <!--<xsl:copy-of select="$specific-renames"/>-->
                           <xsl:copy-of select="tan:shallow-copy($specific-renames)"/>
                        </xsl:if>
                     </ref>
                  </xsl:for-each>

               </xsl:for-each>
            </xsl:variable>

            <xsl:variable name="is-leaf-div" select="not(exists(*:div))"/>
            <xsl:variable name="text-space-normalized" as="xs:string?">
               <xsl:if test="$is-leaf-div">
                  <xsl:choose>
                     <xsl:when test="exists(tei:*)">
                        <xsl:value-of select="normalize-space(string-join(tei:*//text(), ''))"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:value-of select="normalize-space(.)"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:if>
            </xsl:variable>

            <xsl:variable name="skips-to-pass-to-children"
               select="
                  $adjustment-skips[if (exists((tan:ref, tan:range/tan:ref))) then
                     (some $i in (tan:ref, tan:range/tan:ref),
                        $j in $new-refs
                        satisfies matches($i/text(), concat('^', $j/text(), '\W')))
                  else
                     true()]"/>
            <xsl:variable name="renames-to-pass-to-children"
               select="
                  $adjustment-renames[if (exists((tan:ref, tan:range/tan:ref))) then
                     (some $i in (tan:ref, tan:range/tan:ref),
                        $j in $new-refs
                        satisfies matches($i/text(), concat('^', $j/text(), '\W')))
                  else
                     true()]"/>


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
               <xsl:if test="$is-tei">
                  <xsl:if
                     test="exists(@include) and exists(@*[not(name() = ('ed-who', 'ed-when'))])">
                     <xsl:copy-of select="tan:error('tei02')"/>
                  </xsl:if>
                  <xsl:if test="not(exists(@n) and exists(@type)) and not(exists(@include))">
                     <xsl:copy-of select="tan:error('tei03')"/>
                  </xsl:if>
                  <xsl:value-of select="$text-space-normalized"/>
               </xsl:if>
               <xsl:choose>
                  <xsl:when
                     test="not(exists($skips-to-pass-to-children)) and not(exists($renames-to-pass-to-children)) and not(exists($adjustment-equates))">
                     <xsl:apply-templates mode="dependency-expansion-terse-no-adjustments">
                        <xsl:with-param name="parent-new-refs" select="$new-refs"/>
                     </xsl:apply-templates>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates mode="#current">
                        <xsl:with-param name="parent-orig-refs" select="$orig-refs"/>
                        <xsl:with-param name="parent-new-refs" select="$new-refs"/>
                        <xsl:with-param name="adjustment-skips" tunnel="yes"
                           select="$skips-to-pass-to-children"/>
                        <xsl:with-param name="adjustment-renames" tunnel="yes"
                           select="$renames-to-pass-to-children"/>
                     </xsl:apply-templates>
                  </xsl:otherwise>
               </xsl:choose>
            </div>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="tei:lb | tei:pb | tei:cb"
      mode="core-expansion-terse dependency-expansion-terse normalize-tei-space">
      <xsl:variable name="prev-text" select="preceding-sibling::node()[1]/self::text()"/>
      <xsl:variable name="next-text" select="following-sibling::node()[1]/self::text()"/>
      <xsl:variable name="next-text-check" as="xs:string*">
         <xsl:if test="exists($next-text)">
            <xsl:analyze-string select="$next-text" regex="^\s*{$break-marker-regex}" flags="x">
               <xsl:matching-substring>
                  <xsl:value-of select="concat('match: ', .)"/>
               </xsl:matching-substring>
               <xsl:non-matching-substring>
                  <xsl:value-of select="concat('nonmatch: ', .)"/>
               </xsl:non-matching-substring>
            </xsl:analyze-string>
         </xsl:if>
      </xsl:variable>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="count($next-text-check) gt 1 and not(exists(@rend))">
            <xsl:variable name="this-message"
               select="concat($next-text-check[1], ' looks like a break mark')"/>
            <xsl:variable name="this-fix" as="item()*">
               <xsl:copy copy-namespaces="no">
                  <xsl:copy-of select="@* except @q"/>
                  <xsl:attribute name="rend" select="normalize-space($next-text-check[1])"/>
               </xsl:copy>
               <xsl:value-of select="$next-text-check[2]"/>
            </xsl:variable>
            <xsl:copy-of
               select="tan:error('tei04', $this-message, $this-fix, 'replace-self-and-next-sibling')"
            />
         </xsl:if>
         <xsl:if
            test="
               (@break = ('no', 'n') and (matches($prev-text, '\s$') or matches($next-text, '^\s'))
               or (not(@break = ('no', 'n')) and (matches($prev-text, '\S$') and matches($next-text, '^\S'))))">
            <xsl:copy-of select="tan:error('tei05')"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:head" mode="dependencies-tokenized-selectively">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:body" mode="dependencies-tokenized-selectively">
      <xsl:param name="class-2-doc" tunnel="yes" as="document-node()?"/>
      <xsl:variable name="this-src-id" select="parent::tan:TAN-T/@src"/>
      <xsl:variable name="these-reassigns"
         select="$class-2-doc/*/tan:head/tan:adjustments[(tan:src, tan:where/tan:src) = $this-src-id]/tan:reassign"/>
      <xsl:variable name="data-toks"
         select="$class-2-doc/*/tan:body//tan:tok[(self::*, parent::*)/(tan:src, tan:work) = $this-src-id]"/>
      <xsl:variable name="token-definition"
         select="($class-2-doc/*/tan:head/tan:token-definition[tan:src = $this-src-id])[1]"/>
      <xsl:variable name="tokenize-everywhere" select="exists($class-2-doc/tan:TAN-A-lm/tan:body//tan:tok[not(@ref)])"/>
      <xsl:choose>
         <xsl:when test="exists($these-reassigns) or exists($data-toks)">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="adjustment-reassigns" select="$these-reassigns"/>
                  <xsl:with-param name="data-toks" select="$data-toks"/>
                  <xsl:with-param name="token-definition" select="$token-definition" tunnel="yes"/>
                  <xsl:with-param name="tokenize-everywhere" select="$tokenize-everywhere" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="tan:div" mode="dependencies-tokenized-selectively">
      <!--<xsl:param name="class-2-doc" tunnel="yes" as="document-node()?"/>-->
      <!--<xsl:param name="src-id" tunnel="yes"/>-->
      <xsl:param name="adjustment-reassigns" as="element()*"/>
      <xsl:param name="data-toks" as="element()*"/>
      <xsl:param name="token-definition" as="element()*" tunnel="yes"/>
      <xsl:param name="tokenize-everywhere" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="this-div" select="."/>
      <xsl:variable name="is-leaf-div" select="not(exists(tan:div))"/>
      <!-- In the course of adjusting a source, it is possible that <div>s get moved into leaf <div>s before those leaf <div>s can be reassigned -->
      <xsl:variable name="is-mixed-div"
         select="not($is-leaf-div) and exists(text()[matches(., '\S')])"/>
      <xsl:variable name="these-refs" select="tan:ref/text()"/>
      <xsl:variable name="reassign-instructions"
         select="$adjustment-reassigns[tan:tok/tan:ref/text() = $these-refs]"/>
      <xsl:variable name="reassigns-to-pass-to-children"
         select="
            $adjustment-reassigns[some $i in $these-refs
               satisfies matches((tan:tok/tan:ref/text())[1], concat('^', $i, '\W'))]"/>
      <xsl:variable name="these-data-toks" select="$data-toks[tan:ref/text() = $these-refs]"/>
      <xsl:variable name="data-toks-to-pass-to-children"
         select="
            $data-toks[some $i in $these-refs
               satisfies matches((tan:ref/text())[1], concat('^', $i, '\W'))]"/>
      <!--<xsl:variable name="claims-that-require-tokenization"
         select="key('tok-via-ref', $these-refs, $class-2-doc)[(self::*, parent::*)/(tan:src, tan:work) = $src-id]"/>-->
      <xsl:variable name="div-should-be-tokenized"
         select="($is-leaf-div or $is-mixed-div) and (exists($reassign-instructions) or exists($these-data-toks))"/>
      <xsl:choose>
         <xsl:when test="$tokenize-everywhere or $div-should-be-tokenized">
            <xsl:variable name="text-tokenized"
               select="tan:tokenize-text(text(), $token-definition, true())"/>
            <xsl:variable name="previous-renames" select="$this-div/tan:ref/tan:rename"/>
            <xsl:variable name="reassigns-identified" as="element()*">
               <!-- This variable rebuilds each reassign by looking for errors and translating each <pos> and <val>/<rgx> of a <tok>, <from>, or <to> into a series of <n>s with the positions inferred from this context; those <n>s will be used later to pick out the tokenized <n>s -->
               <xsl:for-each select="$reassign-instructions">
                  <xsl:variable name="this-reassign" select="."/>
                  <xsl:copy>
                     <xsl:copy-of select="@*"/>
                     <xsl:if test="exists($previous-renames)">
                        <!-- Warning: the <div> being reassigned has been newly created via <rename> instructions -->
                        <xsl:copy-of
                           select="tan:error('rea03', concat('Moved here: ', string-join($this-div/tan:ref/tan:orig-ref, ', ')))"
                        />
                     </xsl:if>
                     <xsl:for-each select="tan:tok[tan:ref/text() = $these-refs]">
                        <xsl:copy>
                           <xsl:copy-of select="@*"/>
                           <xsl:copy-of select="node()"/>
                           <xsl:choose>
                              <xsl:when test="exists(tan:from)">
                                 <!-- it's a range of toks -->
                                 <xsl:variable name="this-from-val" select="tan:from/tan:val"/>
                                 <xsl:variable name="this-from-rgx" select="tan:from/tan:rgx"/>
                                 <xsl:variable name="possible-from-tokens"
                                    select="
                                       $text-tokenized/tan:tok[if (exists($this-from-val)) then
                                          . = $this-from-val
                                       else
                                          tan:matches(., $this-from-rgx)]"/>
                                 <xsl:variable name="this-from-pos"
                                    select="tan:expand-pos-or-chars(tan:from/tan:pos, count($possible-from-tokens))"/>
                                 <xsl:variable name="this-to-val" select="tan:to/tan:val"/>
                                 <xsl:variable name="this-to-rgx" select="tan:to/tan:rgx"/>
                                 <xsl:variable name="possible-to-tokens"
                                    select="
                                       $text-tokenized/tan:tok[if (exists($this-to-val)) then
                                          . = $this-to-val
                                       else
                                          tan:matches(., $this-to-rgx)]"/>
                                 <xsl:variable name="this-to-pos"
                                    select="tan:expand-pos-or-chars(tan:to/tan:pos, count($possible-to-tokens))"/>
                                 <xsl:variable name="from-token-picked"
                                    select="$possible-from-tokens[$this-from-pos]"/>
                                 <xsl:variable name="to-token-picked"
                                    select="$possible-to-tokens[$this-to-pos]"/>
                                 <from>
                                    <xsl:copy-of select="tan:from/@*"/>
                                    <xsl:if test="not(exists($from-token-picked))">
                                       <xsl:copy-of
                                          select="tan:error('tok01', concat('only ', string(count($possible-from-tokens)), ' instance(s) of ', $this-from-val))"
                                       />
                                    </xsl:if>
                                    <xsl:copy-of select="tan:from/node()"/>
                                 </from>
                                 <to>
                                    <xsl:copy-of select="tan:to/@*"/>
                                    <xsl:if test="not(exists($to-token-picked))">
                                       <xsl:copy-of
                                          select="tan:error('tok01', concat('only ', string(count($possible-to-tokens)), ' instance(s) of ', $this-to-val))"
                                       />
                                    </xsl:if>
                                    <xsl:copy-of select="tan:to/node()"/>
                                 </to>
                                 <xsl:if
                                    test="exists($from-token-picked) and exists($to-token-picked)">
                                    <xsl:variable name="from-pos"
                                       select="xs:integer($from-token-picked/@n)"/>
                                    <xsl:variable name="to-pos"
                                       select="xs:integer($to-token-picked/@n)"/>
                                    <xsl:choose>
                                       <xsl:when test="$to-pos le $from-pos">
                                          <xsl:copy-of select="tan:error('rea01')"/>
                                       </xsl:when>
                                       <xsl:otherwise>
                                          <xsl:for-each select="$from-pos to $to-pos">
                                             <n>
                                                <xsl:value-of select="."/>
                                             </n>
                                          </xsl:for-each>
                                       </xsl:otherwise>
                                    </xsl:choose>
                                 </xsl:if>
                              </xsl:when>
                              <xsl:otherwise>
                                 <!-- it's not a range of toks defined by <from> and <to>, but individual ones -->
                                 <xsl:variable name="this-val" select="tan:val"/>
                                 <xsl:variable name="this-rgx" select="tan:rgx"/>
                                 <xsl:variable name="tokens-picked"
                                    select="
                                       $text-tokenized/tan:tok[if (exists($this-val)) then
                                          . = $this-val
                                       else
                                          tan:matches(., $this-rgx)]"/>
                                 <xsl:for-each select=".//tan:pos">
                                    <xsl:variable name="this-pos"
                                       select="tan:expand-pos-or-chars(., count($tokens-picked))"/>
                                    <xsl:variable name="this-token"
                                       select="$tokens-picked[$this-pos]"/>
                                    <xsl:choose>
                                       <xsl:when test="not(exists($this-token))">
                                          <xsl:copy-of
                                             select="tan:error('tok01', concat('only ', string(count($tokens-picked)), ' instance(s) of ', $this-val, $this-rgx))"
                                          />
                                       </xsl:when>
                                       <xsl:otherwise>
                                          <n>
                                             <xsl:value-of select="$this-token/@n"/>
                                          </n>
                                       </xsl:otherwise>
                                    </xsl:choose>
                                 </xsl:for-each>

                              </xsl:otherwise>
                           </xsl:choose>
                        </xsl:copy>
                     </xsl:for-each>
                     <xsl:copy-of select="tan:to"/>
                  </xsl:copy>
               </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="text-redivided" as="element()*">
               <xsl:for-each-group select="$text-tokenized/*"
                  group-by="
                     for $i in @n
                     return
                        ($reassigns-identified[tan:tok/tan:n = $i]/tan:to/tan:ref/text(), $these-refs)[1]">
                  <!-- generate @q for elements that are to be removed from their context -->
                  <div q="{generate-id(current-group()[1])}">
                     <ref>
                        <xsl:value-of select="current-grouping-key()"/>
                        <!-- We include the original reference children, except <n>, to check the work later (adjustments, original references). -->
                        <xsl:copy-of select="$this-div/tan:ref/(* except tan:n)"/>
                        <xsl:for-each
                           select="tokenize(current-grouping-key(), $separator-hierarchy)">
                           <n><xsl:value-of select="."/></n>
                        </xsl:for-each>
                        <xsl:if test="not(current-grouping-key() = $these-refs)">
                           <xsl:variable name="specific-reassigns"
                              select="$reassigns-identified[tan:tok/tan:n = current-group()/@n][tan:to/tan:ref/text() = current-grouping-key()]"/>
                           <xsl:for-each select="$these-refs">
                              <orig-ref>
                                 <xsl:value-of select="."/>
                              </orig-ref>
                           </xsl:for-each>
                           <!-- Just as in pass 1, we signal that the adjustment has been processed by placing a copy of it as a sibling of the <orig-ref> -->
                           <xsl:copy-of select="tan:shallow-copy($specific-reassigns)"/>
                        </xsl:if>
                     </ref>
                     <xsl:copy-of select="current-group()"/>
                  </div>
               </xsl:for-each-group>
            </xsl:variable>
            <xsl:variable name="duplicate-reassigns"
               select="tan:duplicate-items($reassigns-identified/tan:tok/tan:n)"/>
            <!-- Any tokens that have been reassigned are given new <div>s that are siblings of the context <div> -->
            <xsl:copy-of select="$text-redivided[not(tan:ref/text() = $these-refs)]"/>
            <!-- We deeply copy the newly constructed reassigns so as to report any embedded errors -->
            <xsl:copy-of select="$reassigns-identified"/>
            <div>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="* except tan:div"/>
               <!-- We add the following, to report errors back to the class 2 file -->
               <xsl:if test="exists($duplicate-reassigns)">
                  <xsl:for-each select="$reassigns-identified[tan:tok/tan:n = $duplicate-reassigns]">
                     <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:copy-of
                           select="tan:error('rea02', concat('duplicate instructions for token numbers ', string-join($duplicate-reassigns, ', ')))"
                        />
                     </xsl:copy>
                  </xsl:for-each>
               </xsl:if>
               <xsl:choose>
                  <xsl:when test="exists($reassigns-identified)">
                     <xsl:copy-of select="$text-redivided[tan:ref = $these-refs]/(* except tan:ref)"
                     />
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:copy-of select="$text-tokenized/*"/>
                  </xsl:otherwise>
               </xsl:choose>
            </div>
            <!-- This ensures that children <div>s that happen to be in a mixed <div> get processed -->
            <xsl:choose>
               <xsl:when
                  test="exists($reassigns-to-pass-to-children) or exists($data-toks-to-pass-to-children)">
                  <xsl:apply-templates select="tan:div" mode="#current">
                     <xsl:with-param name="adjustment-reassigns"
                        select="$reassigns-to-pass-to-children"/>
                     <xsl:with-param name="data-toks" select="$data-toks-to-pass-to-children"/>
                  </xsl:apply-templates>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="tan:div"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:when>
         <xsl:when
            test="exists($reassigns-to-pass-to-children) or exists($data-toks-to-pass-to-children)">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates mode="#current">
                  <xsl:with-param name="adjustment-reassigns"
                     select="$reassigns-to-pass-to-children"/>
                  <xsl:with-param name="data-toks" select="$data-toks-to-pass-to-children"/>
               </xsl:apply-templates>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>



   <!-- NORMAL EXPANSION -->

   <xsl:template match="tan:TAN-T/tan:body" mode="core-expansion-normal">
      <xsl:variable name="all-refs" select=".//tan:div/tan:ref/text()"/>
      <xsl:variable name="duplicate-refs" select="tan:duplicate-items($all-refs)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-refs" select="$duplicate-refs" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:div" mode="core-expansion-normal">
      <xsl:param name="duplicate-refs" tunnel="yes"/>
      <xsl:variable name="this-ref" select="tan:ref/text()"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$this-ref = $duplicate-refs">
            <xsl:copy-of select="tan:error('cl109', $this-ref)"/>
         </xsl:if>
         <xsl:if
            test="
               not(tan:div) and
               not(some $i in text()
                  satisfies matches($i, '\S'))">
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
         <xsl:if test="exists(tan:div) and exists(text()[matches(., '\S')])">
            <xsl:copy-of select="tan:error('cl217', (), (), (), .//(tan:rename, tan:reassign))"/>
         </xsl:if>
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

   <xsl:template match="/*" mode="class-1-expansion-verbose">
      <xsl:variable name="diagnostics" select="false()"/>
      <xsl:if test="$diagnostics">
         <xsl:message>Diagnostics turned on for template class-1-expansion-verbose</xsl:message>
      </xsl:if>
      <!-- Evaluate each redivision -->
      <xsl:variable name="redivisions" select="tan:head/tan:redivision"/>
      <xsl:variable name="these-redivisions" as="document-node()*">
         <xsl:for-each select="$redivisions">
            <xsl:variable name="these-iris" select="tan:IRI"/>
            <xsl:variable name="this-see-also-doc" select="$see-alsos-resolved[*/@id = $these-iris]"/>
            <xsl:sequence
               select="
                  if (exists($this-see-also-doc)) then
                     $this-see-also-doc
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
      <xsl:variable name="relevant-ade-nos" as="xs:integer*"
         select="
            for $i in (1 to count($redivisions))
            return
               if (exists($these-redivision-diffs[$i]/(tan:a, tan:b))) then
                  $i
               else
                  ()"/>
      <xsl:variable name="relevant-see-also-ades"
         select="$redivisions[position() = $relevant-ade-nos]"/>
      <xsl:variable name="relevant-ade-diffs"
         select="tan:analyze-leaf-div-string-length($these-redivision-diffs[position() = $relevant-ade-nos])"
         as="element()*"/>
      <xsl:variable name="redivision-diffs-prepped" as="element()*">
         <xsl:for-each select="$relevant-ade-diffs">
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
      <xsl:variable name="see-also-model"
         select="(tan:head/tan:see-also[tan:element-vocabulary(.)//tan:name = 'model'])[1]"/>
      <xsl:variable name="model-already-resolved"
         select="$see-alsos-resolved[*/@id = $see-also-model/tan:IRI]"/>
      <xsl:variable name="this-model-resolved"
         select="
            if (exists($model-already-resolved)) then
               $model-already-resolved
            else
               tan:resolve-doc(tan:get-1st-doc($see-also-model))"
         as="document-node()?"/>
      <xsl:variable name="this-model-expanded"
         select="tan:expand-doc($this-model-resolved, 'terse')"/>
      <xsl:variable name="self-and-model-merged"
         select="
            if (exists($see-also-model)) then
               tan:merge-expanded-docs((root(), $this-model-expanded))
            else
               ()"/>

      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$diagnostics">
            <!--<test14a><xsl:value-of select="string-length($this-doc-text)"/></test14a>-->
            <!--<test14b><xsl:value-of select="string-length(tan:text-join($these-ades[1]/*/(tan:body, tei:text/tei:body)))"/></test14b>-->
            <!--<xsl:variable name="test14c" select="tan:analyze-leaf-div-string-length($these-ade-diffs[1])"/>-->
            <!--<test14c><xsl:copy-of select="tan:trim-long-text($test14c, 21)"/></test14c>-->
            <!--<xsl:copy-of select="$these-ade-diffs"/>-->
            <!--<test1><xsl:copy-of select="$relevant-ade-diffs"/></test1>-->
            <!--<test2><xsl:copy-of select="$ade-diffs-prepped"/></test2>-->
            <!--<test3a><xsl:copy-of select="$this-model-expanded"/></test3a>-->
            <!--<test3>
               <xsl:copy-of select="$self-and-model-merged"/>
            </test3>-->
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="bad-see-alsos" select="$relevant-see-also-ades" tunnel="yes"/>
            <xsl:with-param name="text-redivisions" select="$redivision-diffs-prepped" tunnel="yes"/>
            <xsl:with-param name="self-and-model-merged" select="$self-and-model-merged"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:model" mode="class-1-expansion-verbose">
      <xsl:param name="self-and-model-merged" tunnel="yes"/>
      <xsl:variable name="all-divs" select="$self-and-model-merged//tan:div[tan:div]"/>
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
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <xsl:if test="exists($defective-divs)">
            <xsl:copy-of select="tan:error('cl107', $this-message)"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:redivision" mode="class-1-expansion-verbose">
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

   <xsl:template match="tan:body" mode="class-1-expansion-verbose">
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

   <xsl:template match="tan:div" mode="class-1-expansion-verbose">
      <xsl:param name="text-redivisions" tunnel="yes"/>
      <xsl:param name="leaf-div-replacements" as="element()*" tunnel="yes"/>
      <xsl:param name="self-and-model-merged" tunnel="yes"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="this-replacement" select="$leaf-div-replacements[@q = $this-q]"/>
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
                     select="tan:analyze-numbers-in-string($opening-text, true())"/>
                  <xsl:variable name="opening-text-as-numerals"
                     select="tan:string-to-numerals($opening-text, true(), true())"/>
                  <xsl:variable name="opening-text-replacement"
                     select="string-join($opening-text-analyzed/text(), '')"/>
                  <xsl:if test="($opening-text-analyzed/self::tan:tok)[1] = tan:n">
                     <xsl:copy-of
                        select="tan:error('cl115', 'opening seems to duplicate @n ', concat($opening-text-replacement, substring($this-text, $go-up-to + 1)), 'replace-text')"
                     />
                  </xsl:if>
                  <xsl:for-each select="tan:ref[tan:n]">
                     <xsl:variable name="n-qty" select="count(tan:n)"/>
                     <xsl:if
                        test="
                           every $i in (1 to $n-qty)
                              satisfies tan:n[$i] = ($opening-text-analyzed[@number])[$i]">
                        <xsl:copy-of
                           select="tan:error('cl116', 'opening seems to duplicate the reference', concat($opening-text-replacement, substring($this-text, $go-up-to + 1)), 'replace-text')"
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
      <xsl:variable name="diagnostics" select="false()" as="xs:boolean"/>
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
      <xsl:if test="$diagnostics">
         <xsl:message select="$ref-groups"/>
         <xsl:message select="$sort-key-prep"/>
         <xsl:message select="$sort-key"/>
      </xsl:if>
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
         <xsl:variable name="this-src" select="tan:src"/>
         <xsl:for-each select="tan:ref">
            <xsl:copy>
               <xsl:value-of select="string-join((text(), $this-src), $separator-hierarchy)"/>
               <xsl:copy-of select="*"/>
               <n>
                  <xsl:value-of select="$this-src"/>
               </n>
            </xsl:copy>
         </xsl:for-each>
         <!--<xsl:if test="not(exists(tan:ref))">
            <test36a><xsl:copy-of select="."/></test36a>
         </xsl:if>-->
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
      <!-- Input: any class 1 document fragment -->
      <!-- Output: Every leaf div stamped with @string-length and @string-pos, indicating how long the text node is, and where it is relative to all other leaf text nodes, after TAN text normalization rules have been applied. -->
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
                           <xsl:if test="$add-this-element-text-to-count">
                              <xsl:attribute name="string-pos" select="$char-count-so-far + 1"/>
                           </xsl:if>
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
