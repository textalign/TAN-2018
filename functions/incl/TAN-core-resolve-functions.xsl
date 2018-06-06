<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:function name="tan:resolve-doc" as="document-node()*">
      <!-- one-parameter version of the fuller one, below -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:copy-of select="tan:resolve-doc($TAN-documents, true(), (), (), (), ())"/>
   </xsl:function>
   <xsl:function name="tan:resolve-doc" as="document-node()*">
      <!-- two-parameter version of the fuller one, below -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean"/>
      <xsl:copy-of select="tan:resolve-doc($TAN-documents, $leave-breadcrumbs, (), (), (), ())"/>
   </xsl:function>
   <xsl:function name="tan:resolve-doc" as="document-node()*">
      <!-- Input: any number of TAN documents; boolean indicating whether documents should be breadcrumbed or not; optional name of an attribute and a sequence of strings to stamp in each document's root element as a way of providing another identifier for the document; a list of element names to which any inclusion should be restricted; a list of ids for documents that should not be used to generate inclusions.
      Output: those same documents, resolved, along the following steps:
           a. Stamp each document with @xml:base and the optional root attribute; resolve @href, putting the original (if different) in @orig-href
           b. Normalize @ref and @n, converting them whenever possible to Arabic numerals, and keeping the old versions as @orig-ref and @orig-n; if @n is a range or series, it will be expanded
           c. Resolve every element that has @include.
           d. Resolve every element that has @which.
           e. If anything happened at #3, remove any duplicate elements. -->
      <!-- This function and the functions connected with it are among the most important in the TAN library, since they provide critical stamping (for validation and diagnosing problems) and expand abbreviated parts (to explicitly state what is implied by @include and @which) of a TAN file. Perhaps more importantly, it is a recursive function that is used to resolve not only the beginning of the inclusion process but its middle and endpoints as well. -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean"/>
      <xsl:param name="add-attr-to-root-element-named-what" as="xs:string?"/>
      <xsl:param name="add-what-val-to-new-root-attribute" as="xs:string*"/>
      <xsl:param name="restrict-inclusion-to-what-element-names" as="xs:string*"/>
      <xsl:param name="doc-ids-already-checked" as="xs:string*"/>
      <xsl:for-each select="$TAN-documents">
         <xsl:variable name="this-doc" select="."/>
         <xsl:variable name="this-doc-no" select="position()"/>
         <xsl:variable name="this-doc-stamped-attr-val"
            select="$add-what-val-to-new-root-attribute[$this-doc-no]"/>
         <xsl:variable name="this-doc-id" select="$this-doc/*/@id"/>
         <xsl:variable name="new-doc-ids-checked-so-far"
            select="($doc-ids-already-checked, $this-doc-id)"/>
         <xsl:variable name="elements-that-must-be-expanded"
            select="
               $this-doc//*[@include][if (exists($restrict-inclusion-to-what-element-names)) then
                  name() = $restrict-inclusion-to-what-element-names
               else
                  true()]"/>
         <xsl:variable name="included-docs-resolved" as="document-node()*">
            <xsl:for-each-group select="$elements-that-must-be-expanded"
               group-by="tokenize(tan:normalize-text(@include), ' ')">
               <xsl:variable name="this-inclusion-idref" select="current-grouping-key()"/>
               <xsl:variable name="this-inclusion-element"
                  select="$this-doc/*/tan:head/tan:inclusion[@xml:id = $this-inclusion-idref]"/>
               <xsl:variable name="this-inclusion-doc"
                  select="tan:get-1st-doc($this-inclusion-element)"/>
               <xsl:variable name="names-of-elements-to-fetch"
                  select="
                     for $i in current-group()
                     return
                        name($i)"
                  as="xs:string*"/>
               <xsl:choose>
                  <xsl:when test="not(exists($this-inclusion-element))"/>
                  <xsl:when test="$this-inclusion-doc/*/@id = $new-doc-ids-checked-so-far">
                     <xsl:document>
                        <xsl:copy-of select="tan:error('inc05')"/>
                     </xsl:document>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:copy-of
                        select="tan:resolve-doc($this-inclusion-doc, false(), 'inclusion', $this-inclusion-idref, $names-of-elements-to-fetch, $new-doc-ids-checked-so-far)"
                     />
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:for-each-group>
         </xsl:variable>
         <xsl:variable name="doc-stamped" as="document-node()?">
            <xsl:document>
               <xsl:apply-templates select="node()" mode="first-stamp">
                  <xsl:with-param name="leave-breadcrumbs" select="$leave-breadcrumbs" tunnel="yes"/>
                  <xsl:with-param name="stamp-root-element-with-attr-name"
                     select="$add-attr-to-root-element-named-what"/>
                  <xsl:with-param name="stamp-root-element-with-attr-val"
                     select="$this-doc-stamped-attr-val"/>
               </xsl:apply-templates>
            </xsl:document>
         </xsl:variable>
         <xsl:variable name="doc-with-n-and-ref-converted" as="document-node()?">
            <xsl:apply-templates select="$doc-stamped" mode="core-resolution-arabic-numerals"/>
         </xsl:variable>
         <xsl:variable name="doc-attr-include-resolved" as="document-node()?">
            <xsl:choose>
               <xsl:when test="not(exists($elements-that-must-be-expanded))">
                  <xsl:sequence select="$doc-with-n-and-ref-converted"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:apply-templates select="$doc-with-n-and-ref-converted"
                     mode="resolve-attr-include">
                     <xsl:with-param name="tan-doc-ids-checked-so-far"
                        select="$new-doc-ids-checked-so-far" tunnel="yes"/>
                     <xsl:with-param name="docs-whence-inclusion-resolved"
                        select="$included-docs-resolved" tunnel="yes"/>
                  </xsl:apply-templates>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>
         <xsl:variable name="names-of-elements-with-attr-include" as="xs:string*"
            select="
               distinct-values(for $i in $elements-that-must-be-expanded
               return
                  name($i))"/>
         <xsl:variable name="extra-keys-1st-da"
            select="tan:get-1st-doc($doc-attr-include-resolved/*/tan:head/tan:key[not(@include)])"/>
         <xsl:variable name="extra-keys-resolved"
            select="tan:resolve-doc($extra-keys-1st-da, false(), (), (), ('group', 'item'), $new-doc-ids-checked-so-far)"
            as="document-node()*"/>
         <xsl:variable name="extra-keys-expanded" as="document-node()*">
            <xsl:for-each select="$extra-keys-resolved">
               <xsl:variable name="pos" select="position()"/>
               <xsl:variable name="this-key" select="." as="document-node()"/>
               <xsl:if
                  test="
                     not(some $i in $extra-keys-resolved[position() lt $pos]
                        satisfies deep-equal($i/*, $this-key/*))">
                  <xsl:apply-templates select="." mode="expand-tan-key-dependencies">
                     <xsl:with-param name="leave-breadcrumbs" select="false()" tunnel="yes"/>
                  </xsl:apply-templates>
               </xsl:if>
            </xsl:for-each>
         </xsl:variable>
         <xsl:variable name="doc-attr-which-resolved" as="document-node()?">
            <xsl:apply-templates select="$doc-attr-include-resolved" mode="resolve-keyword">
               <xsl:with-param name="extra-keys" select="$extra-keys-expanded" tunnel="yes"/>
            </xsl:apply-templates>
         </xsl:variable>
         <xsl:choose>
            <xsl:when test="$this-doc-id = $doc-ids-already-checked">
               <!--<xsl:sequence select="."/>-->
               <xsl:document>
                  <xsl:copy-of select="tan:error('inc05')"/>
               </xsl:document>
            </xsl:when>
            <xsl:otherwise>
               <!-- diagnostics, results -->
               <!--<xsl:copy-of select="."/>-->
               <!--<xsl:copy-of select="$included-docs-resolved"/>-->
               <!--<xsl:copy-of select="$doc-stamped"/>-->
               <!--<xsl:copy-of select="$doc-with-n-and-ref-converted"/>-->
               <!--<xsl:copy-of select="$doc-attr-include-resolved"/>-->
               <!--<xsl:copy-of select="$extra-keys-1st-da"/>-->
               <!--<xsl:copy-of select="$extra-keys-resolved"/>-->
               <!--<xsl:copy-of select="$duplicate-keys-removed"/>-->
               <xsl:copy-of
                  select="tan:strip-duplicates($doc-attr-which-resolved, $names-of-elements-with-attr-include)"
               />
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <!-- Step 3a: stamp it -->
   <xsl:template match="/*" mode="first-stamp expand-tan-key-dependencies resolve-href">
      <!-- The first-stamp mode ensures that when a document is handed over to a variable, the original document URI is not lost. It also provides (1) the breadcrumbing service, so that errors occurring downstream, in an inclusion or TAN-key file can be diagnosed; (2) the option for @src to be imprinted on the root element, so that a class 1 TAN file can be tethered to a class 2 file that uses it as a source; (3) the conversion of @href to an absolute URI, resolved against the document's base.-->
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="stamp-root-element-with-attr-name" as="xs:string?"/>
      <xsl:param name="stamp-root-element-with-attr-val" as="xs:string?"/>
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
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="base-uri" select="$this-base-uri" tunnel="yes"/>
            <xsl:with-param name="leave-breadcrumbs" select="$leave-breadcrumbs" tunnel="yes"/>
         </xsl:apply-templates>
         <!--<xsl:for-each select="node()">
            <xsl:variable name="pos" select="position()"/>
            <xsl:apply-templates select="." mode="#current">
               <xsl:with-param name="base-uri" select="$this-base-uri" tunnel="yes"/>
               <xsl:with-param name="leave-breadcrumbs" select="$leave-breadcrumbs" tunnel="yes"/>
               <xsl:with-param name="pos" select="$pos"/>
            </xsl:apply-templates>
         </xsl:for-each>-->
      </xsl:copy>
   </xsl:template>
   <xsl:template match="node()" mode="first-stamp">
      <xsl:param name="base-uri" as="xs:anyURI?" tunnel="yes"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:if test="@href">
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
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
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
               tan:base-uri(.)"
      />
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
   <xsl:template match="*[@href]" mode="resolve-href expand-tan-key-dependencies">
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

   <!-- Step 3b: convert its numerals to Arabic numerals -->
   <xsl:template match="/*" mode="core-resolution-arabic-numerals">
      <xsl:variable name="ambig-is-roman" select="tan:head/tan:definitions/tan:ambiguous-letter-numerals-are-roman"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="*" mode="core-resolution-arabic-numerals">
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

   <!-- Step 3c: resolve each @include -->
   <xsl:template match="*[@include]" mode="resolve-attr-include">
      <xsl:param name="tan-doc-ids-checked-so-far" as="xs:string*" tunnel="yes"/>
      <xsl:param name="docs-whence-inclusion-resolved" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="this-element-name" select="name($this-element)"/>
      <xsl:variable name="these-inclusion-idrefs"
         select="tokenize(tan:normalize-text(@include), ' ')"/>
      <xsl:variable name="relevant-docs"
         select="$docs-whence-inclusion-resolved[*/@inclusion = $these-inclusion-idrefs]"
         as="document-node()*"/>
      <xsl:variable name="relevant-doc-ids" select="$relevant-docs/*/@id"/>
      <xsl:variable name="relevant-elements-to-include"
         select="$relevant-docs//*[name() = $this-element-name][not(ancestor::*[name() = $this-element-name])]"/>
      <xsl:variable name="relevant-elements-to-include-prepended"
         select="
            for $i in $relevant-elements-to-include
            return
               tan:prepend-id-or-idrefs($i, root($i)/*/@inclusion)"/>
      <xsl:variable name="attr-in-this-element-to-suppress" select="'include'"/>
      <xsl:variable name="attr-in-included-element-to-suppress"
         select="('ed-when', 'ed-who', 'which')"/>
      <xsl:choose>
         <xsl:when test="not(exists($relevant-docs))">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="tan:error('tan05')"/>
            </xsl:copy>
         </xsl:when>
         <xsl:when test="exists($relevant-docs/(tan:error, tan:fatal))">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="$relevant-docs/*"/>
            </xsl:copy>
         </xsl:when>
         <xsl:when test="$tan-doc-ids-checked-so-far = $relevant-doc-ids">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="tan:error('inc03')"/>
            </xsl:copy>
         </xsl:when>
         <xsl:when test="not(exists($relevant-elements-to-include))">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="tan:error('inc02')"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:for-each select="$relevant-elements-to-include">
               <xsl:copy>
                  <xsl:copy-of
                     select="$this-element/@*[not(name() = $attr-in-this-element-to-suppress)]"/>
                  <xsl:for-each
                     select="$this-element/@*[name() = $attr-in-this-element-to-suppress]">
                     <xsl:attribute name="orig-{name()}" select="."/>
                  </xsl:for-each>
                  <!-- We bring from the inclusion document only those attributes that have any meaning in the new document (e.g., @ed-when and @ed-who are skipped), and those attributes that are ambiguous outside their host context are normalized (@n and @ref are converted to Arabic numerals) -->
                  <xsl:copy-of select="@*[not(name() = $attr-in-included-element-to-suppress)]"/>
                  <xsl:for-each select="@*[name() = $attr-in-included-element-to-suppress]">
                     <xsl:attribute name="orig-{name()}" select="."/>
                  </xsl:for-each>
                  <xsl:copy-of select="node()"/>
                  <!-- We do not apply templates again, because every */@include is (or should be) empty -->
               </xsl:copy>
            </xsl:for-each>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:function name="tan:prepend-id-or-idrefs" as="element()*">
      <!-- Input: any elements with @xml:id or an attribute that points to an element with an @xml:id value; some string that should be prepended to every value of every attribute found-->
      <!-- Output: the same elements, but with each value prepended with the string and a double hyphen -->
      <!-- This function is critical for disambiguating during the inclusion process. -->
      <xsl:param name="elements-with-id-or-id-refs" as="element()"/>
      <xsl:param name="string-to-prepend" as="xs:string?"/>
      <xsl:apply-templates select="$elements-with-id-or-id-refs" mode="prepend-id-or-idrefs">
         <xsl:with-param name="string-to-prepend" select="$string-to-prepend" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   <xsl:template match="*" mode="prepend-id-or-idrefs">
      <xsl:param name="string-to-prepend" as="xs:string" tunnel="yes"/>
      <xsl:copy>
         <xsl:for-each select="@*">
            <xsl:variable name="this-name" select="name(.)"/>
            <xsl:choose>
               <xsl:when test="$this-name = ($id-idrefs//@attribute, 'xml:id')">
                  <xsl:variable name="vals" as="xs:string*">
                     <xsl:analyze-string select="." regex="\s+">
                        <xsl:non-matching-substring>
                           <xsl:value-of select="concat($string-to-prepend, '--', .)"/>
                        </xsl:non-matching-substring>
                     </xsl:analyze-string>
                  </xsl:variable>
                  <xsl:attribute name="{$this-name}" select="string-join($vals, ' ')"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="."/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <!-- Step 3d: resolve each @which -->
   <xsl:template match="*[@which]" mode="resolve-keyword">
      <xsl:param name="extra-keys" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="element-name" select="name(.)"/>
      <xsl:variable name="this-which-checked" select="tan:help-extracted(@which)"/>
      <xsl:variable name="this-which-normalized" select="replace(lower-case($this-which-checked/text()),'-',' ')"/>
      <!--<xsl:variable name="this-which" select="tan:normalize-text(@which, true())"/>-->
      <!--<xsl:variable name="help-requested" select="matches(@which, $help-trigger-regex)"/>-->
      <xsl:variable name="help-requested" select="exists($this-which-checked/@help)"/>
      <xsl:variable name="attr-in-key-element-to-suppress" select="('group')" as="xs:string*"/>
      <xsl:variable name="valid-definitions" select="tan:glossary($element-name, $this-which-checked, $extra-keys, ())"/>
      <xsl:variable name="definition-matches" as="element()*"
         select="$valid-definitions[tan:name[normalize-space(.) = $this-which-normalized]]"/>
      <xsl:variable name="close-matches"
         select="$valid-definitions[tan:name[matches(., $this-which-normalized, 'i')]]"/>
      <xsl:variable name="best-matches"
         select="
            if (exists($close-matches))
            then
               $close-matches
            else
               $valid-definitions"/>
      <xsl:variable name="definition-groups"
         select="normalize-space(string-join(($definition-matches/@group, $definition-matches/ancestor::tan:group/@type), ' '))"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$definition-matches/tan:token-definition/@pattern"/>
         <!-- We copy attributes from the target definition -->
         <xsl:copy-of
            select="$definition-matches/@*[not(name() = $attr-in-key-element-to-suppress)]"/>
         <xsl:for-each select="$definition-matches/@*[name() = $attr-in-key-element-to-suppress]">
            <xsl:attribute name="orig-{name()}" select="."/>
         </xsl:for-each>
         <xsl:if test="exists($definition-groups)">
            <!-- although strictly not necessary for validation, the <group> of a keyword is quite helpful in later processing, so the name of each group is included here -->
            <xsl:attribute name="orig-group" select="$definition-groups"/>
         </xsl:if>
         <xsl:if test="not(exists($definition-matches))">
            <xsl:variable name="this-message" as="xs:string*">
               <xsl:for-each select="$best-matches">
                  <xsl:value-of select="tan:name[1]"/>
                  <xsl:if test="tan:name[2]">
                     <xsl:value-of
                        select="concat(' (', string-join(tan:name[position() gt 1], '; '), ')')"/>
                  </xsl:if>
               </xsl:for-each>
            </xsl:variable>
            <xsl:variable name="this-fix" as="element()*">
               <xsl:for-each select="$best-matches/tan:name">
                  <xsl:sort select="matches(., $this-which-normalized)" order="descending"/>
                  <element>
                     <xsl:attribute name="which" select="."/>
                  </element>
               </xsl:for-each>
            </xsl:variable>
            <xsl:copy-of
               select="tan:error('whi01', concat('Try: ', string-join($this-message, '; ')), $this-fix, 'copy-attributes')"
            />
         </xsl:if>
         <xsl:if test="count($definition-matches) gt 1">
            <xsl:copy-of select="tan:error('whi02')"/>
         </xsl:if>
         <xsl:if test="not(exists($valid-definitions))">
            <xsl:copy-of
               select="tan:error('whi03', 'perhaps add key element pointing to TAN-key file')"/>
         </xsl:if>
         <xsl:if test="($help-requested = true()) and exists($definition-matches)">
            <xsl:variable name="this-message" as="xs:string*">
               <xsl:text>Help: </xsl:text>
               <xsl:for-each select="$definition-matches">
                  <xsl:text>ITEM </xsl:text>
                  <xsl:value-of select="tan:name[1]"/>
                  <xsl:text> </xsl:text>
                  <xsl:if test="tan:name[2]">
                     <xsl:value-of
                        select="concat('(', string-join(tan:name[position() gt 1], '; '), ') ')"/>
                  </xsl:if>
                  <xsl:text>description: </xsl:text>
                  <xsl:value-of select="tan:desc"/>
               </xsl:for-each>
            </xsl:variable>
            <xsl:copy-of select="tan:help($this-message, $valid-definitions, 'copy-after')"/>
         </xsl:if>
         <xsl:copy-of select="$definition-matches/*[not(self::tan:token-definition)]"/>
      </xsl:copy>
   </xsl:template>

   <!-- Step 3e: strip its duplicates -->
   <xsl:function name="tan:strip-duplicates" as="document-node()*">
      <!-- Input: any documents, sequence of strings of element names -->
      <!-- Output: the same documents after removing duplicate elements whose names match the second parameter. -->
      <!-- This function is applied during document resolution, to prune duplicate elements that might have been included -->
      <xsl:param name="tan-docs" as="document-node()*"/>
      <xsl:param name="element-names-to-check" as="xs:string*"/>
      <xsl:for-each select="$tan-docs">
         <xsl:copy>
            <xsl:apply-templates mode="strip-duplicates">
               <xsl:with-param name="element-names-to-check" select="$element-names-to-check"
                  tunnel="yes"/>
            </xsl:apply-templates>
         </xsl:copy>
      </xsl:for-each>
   </xsl:function>
   <xsl:template match="tan:* | tei:*" mode="strip-duplicates">
      <xsl:param name="element-names-to-check" as="xs:string*" tunnel="yes"/>
      <xsl:choose>
         <xsl:when test="name(.) = $element-names-to-check">
            <xsl:if
               test="
                  every $i in preceding-sibling::*
                     satisfies not(deep-equal(., $i))">
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:apply-templates mode="#current"/>
               </xsl:copy>
            </xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

</xsl:stylesheet>
