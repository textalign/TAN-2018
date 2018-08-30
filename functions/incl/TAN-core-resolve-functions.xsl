<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:function name="tan:resolve-doc" as="document-node()*">
      <!-- one-parameter version of the fuller one, below -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:copy-of select="tan:resolve-doc($TAN-documents, true(), (), ())"/>
   </xsl:function>
   <xsl:function name="tan:resolve-doc" as="document-node()*">
      <!-- two-parameter version of the fuller one, below -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean"/>
      <xsl:copy-of select="tan:resolve-doc($TAN-documents, $leave-breadcrumbs, (), ())"/>
   </xsl:function>
   
   <xsl:function name="tan:resolve-doc" as="document-node()*">
      <!-- Input: any TAN documents; 
         boolean indicating whether documents should be breadcrumbed or not; 
         optional name of an attribute and a sequence of strings to stamp in each document's root element to mark each document; 
         -->
      <!-- Output: that document resolved -->
      <!-- Resolving involves the following steps:
         - stamp main root element, resolve @href, add @q, resolve <alias> (adding one <idref> per terminal idref), normalize <name> (if a candidate for being a target of @which)
         - resolve arabic numbers
         - resolve <inclusion>s
         - insert <inclusion>-derived substitutes
         - ensure every @which and attribute with idref values has a corresponding vocabulary item, marking those that don't
      -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean"/>
      <xsl:param name="add-attr-to-root-element-named-what" as="xs:string?"/>
      <xsl:param name="add-what-val-to-new-root-attribute" as="xs:string*"/>
      <xsl:for-each select="$TAN-documents">
         <xsl:variable name="this-doc" select="."/>
         <xsl:variable name="this-doc-no" select="position()"/>
         <xsl:variable name="this-doc-stamped-attr-val"
            select="$add-what-val-to-new-root-attribute[$this-doc-no]"/>
         
         
         <!-- Step: first stamp: stamp the document root element, resolve @hrefs, resolve <alias>, normalize <name> -->
         <xsl:variable name="doc-stamped" as="document-node()">
            <xsl:apply-templates select="." mode="first-stamp">
               <xsl:with-param name="leave-breadcrumbs" select="$leave-breadcrumbs" tunnel="yes"/>
               <xsl:with-param name="stamp-root-element-with-attr-name"
                  select="$add-attr-to-root-element-named-what" tunnel="yes"/>
               <xsl:with-param name="stamp-root-element-with-attr-val" tunnel="yes"
                  select="$this-doc-stamped-attr-val"/>
            </xsl:apply-templates>
         </xsl:variable>
         
         <!-- Step: convert numerals to Arabic -->
         <xsl:variable name="doc-with-n-and-ref-converted" as="document-node()">
            <xsl:apply-templates select="$doc-stamped" mode="resolve-numerals"/>
         </xsl:variable>
         
         <!-- Step: if inclusion takes place, replace select <inclusion>s and every <ELEMENT @include> -->
         <!-- substep: insert relevant content into <inclusion>s, e.g., <substitutes> -->
         <xsl:variable name="elements-with-attr-include"
            select="$doc-with-n-and-ref-converted//*[@include]"/>
         <xsl:variable name="these-inclusions-resolved" as="element()*">
            <xsl:for-each-group select="$elements-with-attr-include"
               group-by="tokenize(@include, ' ')">
               <xsl:variable name="this-include-idref" select="current-grouping-key()"/>
               <xsl:variable name="this-inclusion-element"
                  select="$doc-with-n-and-ref-converted/*/tan:head/tan:inclusion[@xml:id = $this-include-idref]"/>
               <xsl:variable name="these-elements-names-to-fetch"
                  select="
                     for $i in current-group()
                     return
                        name($i)"/>
               <xsl:copy-of
                  select="tan:resolve-inclusion-element-loop($this-inclusion-element, $these-elements-names-to-fetch, $this-doc/*/@id, $this-doc/*/@xml:base, 1)"
               />
            </xsl:for-each-group>
         </xsl:variable>
         <!-- substep: replace parts of the doc with the full/revised elements, keeping @q -->
         <xsl:variable name="doc-with-inclusions-resolved" as="document-node()">
            <xsl:apply-templates select="$doc-with-n-and-ref-converted"
               mode="apply-resolved-inclusions">
               <xsl:with-param name="resolved-inclusions" tunnel="yes"
                  select="$these-inclusions-resolved"/>
            </xsl:apply-templates>
         </xsl:variable>
         
         
         <!-- Step: ensure every @which and idref point to a full vocabulary item -->
         <xsl:variable name="elements-still-to-be-checked" select="$doc-with-inclusions-resolved//*[not(ancestor-or-self::*/@include) and not(ancestor-or-self::tan:inclusion)]"/>
         <xsl:variable name="this-vocabulary-raw"
            select="tan:element-vocabulary($elements-still-to-be-checked)"/>
         <xsl:variable name="this-vocabulary-consolidated" select="tan:consolidate-elements($this-vocabulary-raw[not(self::tan:error)]), $this-vocabulary-raw/self::tan:error"/>

         <!-- Step: add to each <vocabulary> the particular vocabulary items from the previous step; for TAN vocabulary, insert a new <vocabulary> populated with vocabulary items -->
         <!-- for the step above, also stamp <resolved> as the first child of the root element, and copy the error messages due to bad idrefs or @which values to the host element -->
         <xsl:variable name="doc-with-complete-vocabulary" as="document-node()">
            <xsl:apply-templates select="$doc-with-inclusions-resolved"
               mode="resolve-vocabulary-references">
               <xsl:with-param name="vocabulary-analysis"
                  select="$this-vocabulary-consolidated" tunnel="yes"/>
            </xsl:apply-templates>
         </xsl:variable>
         
         
         <!-- diagnostics, results -->
         <!--<xsl:document>
            <diagnostics>
               <!-\-<xsl:copy-of select="$elements-with-attr-include"/>-\->
               <xsl:copy-of select="$doc-with-inclusions-resolved"/>
               <!-\-<test21a><xsl:copy-of select="$doc-with-inclusions-resolved/*/tan:head/tan:work"/></test21a>-\->
               <!-\-<test21b><xsl:copy-of select="tan:element-vocabulary($doc-with-inclusions-resolved/*/tan:head/tan:work)"/></test21b>-\->
               <test27a><xsl:copy-of select="$elements-still-to-be-checked"/></test27a>
               <test24a><xsl:copy-of select="$this-vocabulary-raw"/></test24a>
               <!-\-<test24b><xsl:copy-of select="$this-vocabulary-consolidated"/></test24b>-\->
            </diagnostics>
         </xsl:document>-->
         <!--<xsl:copy-of select="$doc-stamped"/>-->
         <!--<xsl:copy-of select="$doc-with-n-and-ref-converted"/>-->
         <!--<xsl:copy-of select="$doc-with-includes-resolved"/>-->
         <xsl:copy-of select="$doc-with-complete-vocabulary"/>
      </xsl:for-each>
   </xsl:function>

   <!-- Step: stamp documents -->
   <xsl:template match="/*" mode="first-stamp expand-standard-tan-voc resolve-href">
      <!-- The first-stamp mode ensures that when a document is handed over to a variable, the original document URI is not lost. It also provides (1) the breadcrumbing service, so that errors occurring downstream, in an inclusion or TAN-voc file can be diagnosed; (2) the option for @src to be imprinted on the root element, so that a class 1 TAN file can be tethered to a class 2 file that uses it as a source; (3) the conversion of @href to an absolute URI, resolved against the document's base.-->
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="stamp-root-element-with-attr-name" as="xs:string?" tunnel="yes"/>
      <xsl:param name="stamp-root-element-with-attr-val" as="xs:string?" tunnel="yes"/>
      <xsl:variable name="this-base-uri" select="tan:base-uri(.)" as="xs:anyURI?"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(exists(@xml:base))">
            <xsl:attribute name="xml:base" select="$this-base-uri"/>
         </xsl:if>
         <xsl:if test="string-length($stamp-root-element-with-attr-name) gt 0">
            <xsl:attribute name="{$stamp-root-element-with-attr-name}"
               select="$stamp-root-element-with-attr-val"/>
         </xsl:if>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <stamped/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="base-uri" select="$this-base-uri" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="node()" mode="first-stamp">
      <xsl:param name="base-uri" as="xs:anyURI?" tunnel="yes"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="affects-only-elements-named" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="apply-rules"
         select="count($affects-only-elements-named) lt 1 or name(.) = $affects-only-elements-named"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$apply-rules and $leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:if test="$apply-rules and @href">
            <xsl:variable name="this-base-uri"
               select="
                  if (string-length($base-uri) gt 0) then
                     $base-uri
                  else
                     tan:base-uri(.)"/>
            <xsl:variable name="new-href" select="resolve-uri(@href, xs:string($this-base-uri))"/>
            <xsl:attribute name="href" select="$new-href"/>
            <xsl:if test="not($new-href = @href)">
               <xsl:attribute name="orig-href" select="@href"/>
            </xsl:if>
         </xsl:if>
         <xsl:choose>
            <xsl:when test="exists(@include)">
               <!-- We assume that anything that is included has been already processed -->
               <xsl:copy-of select="node()"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:item/tan:name | tan:vocabulary-key/*/tan:name" mode="first-stamp">
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <!-- If <name> is a candidate for being referred to by @which, make a clone version of the normalized name immediately after, if its normalized form differs -->
      <xsl:variable name="this-name" select="text()"/>
      <xsl:variable name="this-name-norm" select="tan:normalize-name($this-name)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
      <xsl:if test="not($this-name = $this-name-norm)">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- we add @norm, to accelerate name checking -->
            <xsl:attribute name="norm"/>
            <xsl:value-of select="$this-name-norm"/>
         </xsl:copy>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:vocabulary-key" mode="first-stamp">
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <!-- We insert an empty <tan-vocabulary> as a placeholder to attract the standard vocabulary items that are invoked -->
      <tan-vocabulary/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:alias" mode="first-stamp">
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:copy-of select="tan:resolve-alias(.)/tan:idref"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:function name="tan:resolve-alias" as="element()*">
      <!-- Input: one or more <alias>es -->
      <!-- Output: those elements with children <idref>, each containing a single value that the alias stands for -->
      <!-- It is assumed that <alias>es are still embedded in an XML structure that allows one to reference sibling <alias>es -->
      <!-- Note, this only resolves for each <alias> its final idrefs, but does not check to see if those idrefs are valid -->
      <xsl:param name="aliases" as="element()*"/>
      <xsl:for-each select="$aliases">
         <xsl:variable name="other-aliases" select="../tan:alias"/>
         <xsl:variable name="this-id" select="(@xml:id, @id)[1]"/>
         <xsl:variable name="these-idrefs" select="tokenize(normalize-space(@idrefs), ' ')"/>
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="tan:resolve-alias-loop($these-idrefs, $this-id, $other-aliases)"/>
         </xsl:copy>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:resolve-alias-loop" as="element()*">
      <!-- Function associated with the master one, above; returns only <id-ref> and <error> children -->
      <xsl:param name="idrefs-to-process" as="xs:string*"/>
      <xsl:param name="alias-ids-already-processed" as="xs:string*"/>
      <xsl:param name="other-aliases" as="element()*"/>
      <xsl:choose>
         <xsl:when test="count($idrefs-to-process) lt 1"/>
         <xsl:otherwise>
            <xsl:variable name="next-idref" select="$idrefs-to-process[1]"/>
            <xsl:variable name="next-idref-norm" select="tan:help-extracted($next-idref)"/>
            <xsl:variable name="other-alias-picked"
               select="$other-aliases[(@xml:id, @id) = $next-idref-norm]" as="element()?"/>
            <xsl:choose>
               <xsl:when test="$next-idref-norm = $alias-ids-already-processed">
                  <xsl:copy-of select="tan:error('tan14')"/>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop($idrefs-to-process[position() gt 1], $alias-ids-already-processed, $other-aliases)"
                  />
               </xsl:when>
               <xsl:when test="exists($other-alias-picked)">
                  <xsl:variable name="new-idrefs"
                     select="tokenize(normalize-space($other-alias-picked/@idrefs), ' ')"/>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop(($new-idrefs, $idrefs-to-process[position() gt 1]), ($alias-ids-already-processed, $next-idref-norm), $other-aliases)"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <idref>
                     <xsl:copy-of select="$next-idref-norm/@help"/>
                     <xsl:value-of select="$next-idref-norm"/>
                  </idref>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop($idrefs-to-process[position() gt 1], $alias-ids-already-processed, $other-aliases)"
                  />
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
   <xsl:function name="tan:resolve-href" as="node()?">
      <!-- One-parameter version of the full one, below -->
      <xsl:param name="xml-node" as="node()?"/>
      <xsl:copy-of select="tan:resolve-href($xml-node, true())"/>
   </xsl:function>
   <xsl:function name="tan:resolve-href" as="node()?">
      <!-- Input: any XML node; a boolean -->
      <!-- Output: the same node, but with @href resolved to absolute form, with @orig-href if the 2nd parameter is true -->
      <xsl:param name="xml-node" as="node()?"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean"/>
      <xsl:variable name="this-base-uri" select="tan:base-uri($xml-node)"/>
      <xsl:apply-templates select="$xml-node" mode="resolve-href">
         <xsl:with-param name="base-uri" select="$this-base-uri" tunnel="yes"/>
         <xsl:with-param name="leave-breadcrumbs" select="$leave-breadcrumbs" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="processing-instruction()" mode="resolve-href">
      <xsl:param name="base-uri" as="xs:anyURI?" tunnel="yes"/>
      <xsl:variable name="this-base-uri"
         select="
            if (exists($base-uri)) then
               $base-uri
            else
               tan:base-uri(.)"/>
      <xsl:variable name="href-regex" as="xs:string">(href=['"])([^'"]+)(['"])</xsl:variable>
      <xsl:processing-instruction name="{name(.)}">
            <xsl:analyze-string select="." regex="{$href-regex}">
                <xsl:matching-substring>
                    <xsl:value-of select="concat(regex-group(1), resolve-uri(regex-group(2), $this-base-uri), regex-group(3))"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:processing-instruction>
   </xsl:template>
   <xsl:template match="*[@href]" mode="resolve-href">
      <xsl:param name="base-uri" as="xs:anyURI?" tunnel="yes"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes" select="true()"/>
      <xsl:variable name="this-base-uri"
         select="
            if (exists($base-uri)) then
               $base-uri
            else
               tan:base-uri(.)"/>
      <xsl:variable name="new-href" select="resolve-uri(@href, xs:string($this-base-uri))"/>
      <xsl:copy>
         <xsl:copy-of select="@* except @href"/>
         <xsl:attribute name="href" select="$new-href"/>
         <xsl:if test="not($new-href = @href) and $leave-breadcrumbs">
            <xsl:attribute name="orig-href" select="@href"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>

   <!-- Step: convert numerals to Arabic numerals -->
   <xsl:template match="/*" priority="1" mode="resolve-numerals">
      <xsl:variable name="ambig-is-roman" select="tan:head/tan:ambiguous-letter-numerals-are-roman"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="*[@include]" mode="resolve-numerals">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="*[not(@include)]" mode="resolve-numerals">
      <xsl:param name="ambig-is-roman" as="xs:boolean?" tunnel="yes" select="true()"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:copy>
         <xsl:for-each select="@*">
            <xsl:variable name="this-name" select="name(.)"/>
            <xsl:choose>
               <xsl:when test="$this-name = $attributes-that-take-non-arabic-numerals">
                  <xsl:variable name="val-normalized"
                     select="tan:string-to-numerals(lower-case(.), $ambig-is-roman, false())"/>
                  <xsl:attribute name="{$this-name}" select="$val-normalized"/>
                  <xsl:if test="not(. = $val-normalized)">
                     <xsl:attribute name="{concat('orig-',$this-name)}" select="."/>
                  </xsl:if>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="."/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:function name="tan:resolve-inclusion-element-loop" as="element()?">
      <!-- Input: any inclusion element; names of elements that are of interest; ids and urls of documents already processed; loop counter -->
      <!-- Output: the <inclusion> with last children newly inserted: <error>, <inclusion>, <substitutes>, <tan-vocabulary>, <vocabulary>, <local> -->
      <!-- We assume the <location> in the input <inclusion> already has had its @href resolved -->
      <xsl:param name="inclusion-element" as="element()"/>
      <xsl:param name="names-of-elements-of-interest" as="xs:string*"/>
      <xsl:param name="doc-ids-already-processed" as="xs:string*"/>
      <xsl:param name="doc-urls-already-processed" as="xs:string*"/>
      <xsl:param name="loop-counter" as="xs:integer"/>
      <xsl:variable name="this-inclusion-doc" select="tan:get-1st-doc($inclusion-element)"/>
      <xsl:variable name="this-inclusion-doc-uri" select="tan:base-uri($this-inclusion-doc)"/>
      <!-- we focus upon head @include and not body @include because we are interested in vocabulary items that might need to be resolved -->
      <xsl:variable name="this-inclusion-head-elements-with-attr-include"
         select="$this-inclusion-doc/*/tan:head//*[@include]"/>
      <xsl:variable name="these-elements-of-primary-interest"
         select="$this-inclusion-doc//*[name() = $names-of-elements-of-interest]"/>
      <xsl:variable name="this-inclusion-extra-vocabulary"
         select="tan:get-1st-doc($this-inclusion-doc/*/tan:head/tan:vocabulary)"/>
      <xsl:variable name="this-inclusion-extra-vocabulary-resolved"
         select="tan:resolve-doc($this-inclusion-extra-vocabulary, false())"/>
      
      <inclusion>
         <xsl:copy-of select="$inclusion-element/@*"/>
         <xsl:copy-of select="$inclusion-element/node()"/>
         <xsl:choose>
            <xsl:when test="$loop-counter gt $loop-tolerance">
               <xsl:message
                  select="concat('Inclusion resolution cannot be looped more than', xs:string($loop-tolerance), 'times')"
               />
            </xsl:when>
            <xsl:when test="$this-inclusion-doc/tan:error">
               <xsl:copy-of select="$this-inclusion-doc/tan:error"/>
            </xsl:when>
            <xsl:when
               test="
               (($inclusion-element/tan:IRI, $this-inclusion-doc/*/@id) = $doc-ids-already-processed)
               or ($this-inclusion-doc-uri = $doc-urls-already-processed)">
               <xsl:copy-of select="tan:error('inc03')"/>
            </xsl:when>
            <xsl:when test="not(exists($these-elements-of-primary-interest))">
               <xsl:copy-of select="tan:error('inc02')"/>
            </xsl:when>
            
            <xsl:otherwise>
               <!-- We are ready to fetch elements from the document being included. -->
               <!-- First (the recursive bit), resolve all next-level <inclusion>s -->
               <!-- It may not seem intuitive to expand every @include in the head. But it is possible that one of the elements of 
                  primary interest will have references to vocabulary items that are hidden in <inclusion>s. So we must ferret them out. -->
               <xsl:variable name="nested-inclusions-resolved" as="element()*">
                  <xsl:for-each-group
                     select="($these-elements-of-primary-interest[@include] union $this-inclusion-head-elements-with-attr-include)"
                     group-by="tokenize(@include, '\s+')">
                     <xsl:variable name="this-include-idref" select="current-grouping-key()"/>
                     <xsl:variable name="this-inclusion-element"
                        select="$this-inclusion-doc/*/tan:head/tan:inclusion[@xml:id = $this-include-idref]"/>
                     <xsl:variable name="these-elements-names-to-fetch"
                        select="
                        distinct-values(for $i in current-group()
                        return
                        name($i))"/>
                     <xsl:copy-of
                        select="tan:resolve-inclusion-element-loop($this-inclusion-element, $these-elements-names-to-fetch, ($doc-ids-already-processed, $this-inclusion-doc/*/@id), ($doc-urls-already-processed, $this-inclusion-doc-uri), $loop-counter + 1)"
                     />
                  </xsl:for-each-group>
               </xsl:variable>
               
               <!-- copy the nested <inclusion>s within the <inclusion> -->
               <xsl:copy-of select="$nested-inclusions-resolved"/>
               
               <!-- Second, prepare the nonincluded elements that are of interest -->
               <!-- Resolve @href, <alias>, but don't worry about adding @q -->
               <!-- Note, unlike tan:resolve-doc() the stamping occurs not on the entire document but only on elements of interest -->
               <xsl:variable name="substitutes-stamped" as="element()*">
                  <xsl:apply-templates select="$these-elements-of-primary-interest[not(@include)]"
                     mode="first-stamp">
                     <xsl:with-param name="leave-breadcrumbs" select="false()" tunnel="yes"/>
                  </xsl:apply-templates>
               </xsl:variable>
               <!-- convert numerals to Arabic -->
               <xsl:variable name="ambig-is-roman"
                  select="$this-inclusion-doc/*/tan:head/tan:ambiguous-letter-numerals-are-roman"/>
               <xsl:variable name="substitutes-with-n-and-ref-converted" as="element()*">
                  <xsl:apply-templates select="$substitutes-stamped"
                     mode="resolve-numerals">
                     <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
                  </xsl:apply-templates>
               </xsl:variable>
               <substitutes>
                  <xsl:copy-of select="$substitutes-with-n-and-ref-converted"/>
               </substitutes>
               
               <!-- Third, get the vocabulary for the substitutes, provided they are not inclusions -->
               <xsl:variable name="this-inclusion-doc-with-inclusions-resolved" as="document-node()">
                  <xsl:apply-templates select="$this-inclusion-doc" mode="apply-resolved-inclusions">
                     <xsl:with-param name="resolved-inclusions" select="$nested-inclusions-resolved"
                        tunnel="yes"/>
                  </xsl:apply-templates>
               </xsl:variable>
               <xsl:variable name="vocabulary-items-of-interest" as="element()*"
                  select="tan:element-vocabulary($this-inclusion-doc-with-inclusions-resolved//*[name() = $names-of-elements-of-interest][not(@include)])"/>
               <xsl:copy-of select="tan:consolidate-elements($vocabulary-items-of-interest)"/>
               
            </xsl:otherwise>
         </xsl:choose>
      </inclusion>
   </xsl:function>

   <xsl:template match="*[@include]" mode="resolve-vocabulary-references">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="/*" mode="resolve-vocabulary-references">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <!-- The next element signifies that the file has been resolved, and to interpret it, one need no longer access any vocabulary, whether standard or special -->
         <resolved/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:inclusion" mode="resolve-vocabulary-references">
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="tan:vocabulary[not(@include)]" mode="resolve-vocabulary-references">
      <xsl:param name="vocabulary-analysis" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-iri" select="tan:IRI"/>
      <xsl:variable name="vocabulary-items-used" select="$vocabulary-analysis[tan:IRI = $this-iri]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <xsl:copy-of select="$vocabulary-items-used/tan:item"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:tan-vocabulary" mode="resolve-vocabulary-references">
      <xsl:param name="vocabulary-analysis" as="element()*" tunnel="yes"/>
      <xsl:copy-of select="$vocabulary-analysis/self::tan:tan-vocabulary"/>
   </xsl:template>

   <xsl:template match="tan:vocabulary-key" mode="resolve-vocabulary-references">
      <xsl:param name="vocabulary-analysis" as="element()*" tunnel="yes"/>
      <xsl:variable name="standard-vocabulary-items-used"
         select="$vocabulary-analysis[self::tan-vocabulary]"/>
      <xsl:if
         test="exists($standard-vocabulary-items-used) and not(exists(preceding-sibling::tan:tan-vocabulary))">
         <tan-vocabulary>
            <xsl:copy-of select="tan:distinct-items($standard-vocabulary-items-used/*)"/>
         </tan-vocabulary>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="*" mode="resolve-vocabulary-references">
      <xsl:param name="vocabulary-analysis" as="element()*" tunnel="yes"/>
      <!-- Because this template resolves vocabulary references, it deals with both the initiation points and the target destinations, two mutually exclusive categories -->
      <!-- If there is a @q match in the vocabulary analysis, it's a target destination; otherwise check to see if it has an initiation point (@which, an idref attribute) and if so, any matches in the vocabulary analysis -->
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="this-substitute" select="$vocabulary-analysis//*[@q = $this-q]"/>
      <xsl:variable name="this-which" select="@which"/>
      <xsl:variable name="this-which-norm" select="tan:normalize-name(@which)"/>
      <!--<xsl:variable name="these-idref-attributes" select="@*[name() = $id-idrefs/tan:id-idrefs/tan:id[not(@cross-file)]/tan:idrefs/@attribute]"/>-->
      <xsl:variable name="these-idref-attributes" select="@*[tan:takes-idrefs(.)]"/>
      <xsl:variable name="this-element-name" select="name(.)"/>
      <xsl:choose>
         <xsl:when test="exists($this-substitute)">
            <xsl:copy-of select="$this-substitute"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:if test="exists($this-which)">
                  <!-- We ignore errors with tan:id because those are aimed at attributes with idrefs -->
                  <xsl:copy-of select="$vocabulary-analysis/self::tan:error[tan:item[not(tan:id)][(tan:affects-element = $this-element-name) and (tan:name = $this-which-norm)]]"/>
               </xsl:if>
               <xsl:for-each select="$these-idref-attributes">
                  <xsl:variable name="this-attr-name" select="name(.)"/>
                  <xsl:variable name="target-element-names" select="tan:target-element-names(.)"/>
                  <xsl:variable name="this-attribute-value"
                     select="
                        if (string-length(.) lt 1) then
                           concat($help-trigger, '#')
                        else
                           ."/>
                  <xsl:for-each select="tokenize(normalize-space($this-attribute-value), ' ')">
                     <xsl:variable name="this-val" select="."/>
                     <xsl:copy-of select="$vocabulary-analysis/self::tan:error[tan:item[(tan:affects-element = $target-element-names) and (tan:id = $this-val)]]"/>
                  </xsl:for-each>
               </xsl:for-each>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="tan:inclusion" mode="apply-resolved-inclusions">
      <xsl:param name="resolved-inclusions" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-iri" select="tan:IRI"/>
      <xsl:variable name="this-id" select="@xml:id"/>
      <xsl:variable name="matching-inclusion"
         select="$resolved-inclusions[(tan:IRI = $this-iri) or (@xml:id = $this-id)]"/>
      <xsl:choose>
         <xsl:when test="exists($matching-inclusion)">
            <xsl:copy-of select="$matching-inclusion"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="*[@include]" mode="apply-resolved-inclusions">
      <xsl:param name="resolved-inclusions" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="these-include-idrefs" select="tokenize(@include, '\s+')"/>
      <xsl:variable name="matching-substitutes"
         select="$resolved-inclusions[@xml:id = $these-include-idrefs]//tan:substitutes/*[name() = $this-name]"/>
      <xsl:copy>
         <xsl:copy-of select="$matching-substitutes/@*"/>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(exists($matching-substitutes))">
            <xsl:copy-of select="tan:error('inc02')"/>
         </xsl:if>
         <xsl:copy-of select="$matching-substitutes/node()"/>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
