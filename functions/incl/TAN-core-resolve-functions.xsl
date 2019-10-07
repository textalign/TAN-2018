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
      <!-- four-parameter version of the fuller one, below -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean"/>
      <xsl:param name="add-attr-to-root-element-named-what" as="xs:string?"/>
      <xsl:param name="add-what-val-to-new-root-attribute" as="xs:string*"/>
      <xsl:copy-of
         select="tan:resolve-doc($TAN-documents, $leave-breadcrumbs, $add-attr-to-root-element-named-what, $add-what-val-to-new-root-attribute, true())"
      />
   </xsl:function>

   <xsl:function name="tan:get-and-resolve-dependency" as="document-node()*">
      <!-- Input: elements for a dependency, e.g., <source>, <morphology>, <vocabulary> -->
      <!-- Output: documents, if available, minimally resolved -->
      <!-- This function was written principally to expedite the processing of class-2 sources -->
      <xsl:param name="TAN-elements" as="element()*"/>
      <xsl:for-each select="$TAN-elements">
         <xsl:variable name="this-element-expanded"
            select="
               if (exists(tan:location)) then
                  .
               else
                  tan:element-vocabulary(.)/(tan:item, tan:verb)"/>
         <xsl:variable name="this-element-name" select="name(.)"/>
         <!-- We intend to imprint in the new document an attribute with the name of the element that invoked it, so that we can easily 
            identify what kind of relationship the dependency enjoys with the dependent. It is so customary to abbreviate "source" 
            as "src" that we make the transition now. -->
         <xsl:variable name="this-name-norm" select="replace($this-element-name, 'source', 'src')"/>
         <xsl:variable name="this-id" select="@xml:id"/>
         <xsl:variable name="this-first-doc" select="tan:get-1st-doc($this-element-expanded)"/>
         <xsl:variable name="this-source-must-be-adjusted"
            select="
               ($this-element-name = 'source') and
               exists(following-sibling::tan:adjustments[(self::*, tan:where)/@src[tokenize(., ' ') = ($this-id, '*')]]/(tan:equate, tan:rename, tan:reassign, tan:skip))"/>
         <xsl:variable name="leave-breadcrumbs" select="$this-source-must-be-adjusted"/>
         <xsl:variable name="resolve-vocabulary"
            select="$this-element-name = ('morphology', 'source')"/>
         <xsl:variable name="diagnostics-on" select="false()"/>
         <xsl:if test="$diagnostics-on">
            <xsl:message select="'diagnostics on for tan:get-and-resolve-dependency()'"/>
            <xsl:message select="'this element expanded:', $this-element-expanded"/>
         </xsl:if>
         <xsl:copy-of
            select="tan:resolve-doc($this-first-doc, $leave-breadcrumbs, $this-name-norm, ($this-id, $this-element-expanded/(@xml:id, tan:id))[1], $resolve-vocabulary)"
         />
         <xsl:if test="not(exists($this-first-doc))">
            <xsl:sequence select="$empty-doc"/>
         </xsl:if>
      </xsl:for-each>
   </xsl:function>

   <xsl:function name="tan:resolve-doc" as="document-node()*">
      <!-- Input: any TAN documents; 
         a boolean indicating whether documents should be breadcrumbed or not; 
         optional name of an attribute and a sequence of strings to stamp in each document's root element to mark each document;
         a boolean indicating whether vocabulary should be resolved
         -->
      <!-- Output: that document resolved -->
      <!-- Resolving involves the following steps:
         - stamp main root element, resolve @href, add @q, resolve <alias> (adding one <idref> per terminal idref), normalize <name> (if a candidate for being a target of @which)
         - resolve arabic numbers
         - resolve <inclusion>s
         - insert <inclusion>-derived substitutes
         - imprint vocabulary (standard and extended) within the <head>
         - ensure every @which and attribute with idref values has a corresponding vocabulary item, marking <error>s within parents of those that don't
      -->
      <!-- Because vocabulary resolution can be time-consuming, and because this function will be used upon sources of class-2 documents (where validation of the vocabulary is not paramount), it may be skipped -->
      <xsl:param name="TAN-documents" as="document-node()*"/>
      <xsl:param name="leave-breadcrumbs" as="xs:boolean"/>
      <xsl:param name="add-attr-to-root-element-named-what" as="xs:string?"/>
      <xsl:param name="add-what-val-to-new-root-attribute" as="xs:string*"/>
      <xsl:param name="resolve-vocabulary" as="xs:boolean"/>
      <xsl:for-each select="$TAN-documents">
         <xsl:variable name="this-doc" select="."/>
         <xsl:variable name="this-doc-no" select="position()"/>
         <xsl:variable name="this-doc-stamped-attr-val"
            select="$add-what-val-to-new-root-attribute[$this-doc-no]"/>


         <!-- Step: first stamp: stamp the document root element, resolve @hrefs, resolve <alias>, normalize <name>, replace <vocabulary @which> -->
         <xsl:variable name="doc-stamped" as="document-node()">
            <xsl:apply-templates select="$this-doc" mode="first-stamp">
               <xsl:with-param name="leave-breadcrumbs" select="$leave-breadcrumbs" tunnel="yes"/>
               <xsl:with-param name="stamp-root-element-with-attr-name"
                  select="$add-attr-to-root-element-named-what" tunnel="yes"/>
               <xsl:with-param name="stamp-root-element-with-attr-val" tunnel="yes"
                  select="$this-doc-stamped-attr-val"/>
            </xsl:apply-templates>
         </xsl:variable>

         <!-- Step: if inclusion takes place, replace select <inclusion>s and every <ELEMENT @include> -->
         <!-- substep: insert relevant content into <inclusion>s, e.g., <substitutes> -->
         <xsl:variable name="elements-with-attr-include" select="$doc-stamped//*[@include]"/>
         <xsl:variable name="these-inclusions-resolved" as="element()*">
            <xsl:for-each-group select="$elements-with-attr-include"
               group-by="tokenize(@include, ' ')">
               <xsl:variable name="this-include-idref" select="current-grouping-key()"/>
               <xsl:variable name="this-inclusion-element"
                  select="$doc-stamped/*/tan:head/tan:inclusion[@xml:id = $this-include-idref]"/>
               <xsl:variable name="these-elements-names-to-fetch"
                  select="
                     for $i in current-group()
                     return
                        name($i)"/>
               <xsl:if test="exists($this-inclusion-element)">
                  <xsl:copy-of
                     select="tan:resolve-inclusion-element-loop($this-inclusion-element, $these-elements-names-to-fetch, $this-doc/*/@id, $this-doc/*/@xml:base, $resolve-vocabulary, 1)"
                  />
               </xsl:if>
            </xsl:for-each-group>
         </xsl:variable>
         <!-- substep: replace parts of the doc with the full/revised elements, keeping @q -->
         <xsl:variable name="doc-with-inclusions-resolved" as="document-node()">
            <xsl:apply-templates select="$doc-stamped" mode="apply-resolved-inclusions">
               <xsl:with-param name="resolved-inclusions" tunnel="yes"
                  select="$these-inclusions-resolved"/>
            </xsl:apply-templates>
         </xsl:variable>

         <!-- step: resolve vocabulary -->
         <!-- this step does not mark as erroneous any vocabulary that's missing. It merely isolates every cited vocabulary items that can be found, and imprints them in the host file -->
         <xsl:variable name="doc-with-vocabulary-resolved" as="document-node()">
            <xsl:choose>
               <xsl:when test="$resolve-vocabulary = false()">
                  <xsl:sequence select="$doc-with-inclusions-resolved"/>
               </xsl:when>
               <xsl:otherwise>

                  <!-- Step 1: go through the document and for each attribute with an idref (including @which), create a list of 
                     key-value pairs: the name of the elements being pointed to, and the idref values intended. Retain @q for 
                     tracking errors. If a @which has a companion @xml:id or @id copy it as <id> for later reference. -->
                  <xsl:variable name="these-idref-attributes-and-IRIs" as="element()">
                     <idref-attributes-and-IRIs>
                        <xsl:apply-templates select="$doc-with-inclusions-resolved"
                           mode="reduce-to-idref-attributes-and-IRIs"/>
                     </idref-attributes-and-IRIs>
                  </xsl:variable>
                  <!-- Step 2: go through vocab files, reducing them to the vocabulary elements that 
                     should be inserted into the resolved doc's <head>. Use step 1 as a tunnel parameter. -->
                  <xsl:variable name="these-tan-voc-files-resolved" as="document-node()*"
                     select="tan:get-and-resolve-dependency($doc-with-inclusions-resolved/*/tan:head/tan:vocabulary)"/>
                  <xsl:variable name="all-tan-voc-files-reduced" as="document-node()*">
                     <xsl:apply-templates select="$these-tan-voc-files-resolved"
                        mode="reduce-tan-voc-files">
                        <xsl:with-param name="idref-attributes-and-IRIs"
                           select="$these-idref-attributes-and-IRIs" tunnel="yes"/>
                        <xsl:with-param name="aliases"
                           select="$doc-with-inclusions-resolved/*/tan:head/tan:vocabulary-key/tan:alias"
                           tunnel="yes"/>
                        <xsl:with-param name="is-standard-tan-voc" select="false()" tunnel="yes"/>
                     </xsl:apply-templates>
                     <xsl:apply-templates select="$TAN-vocabularies" mode="reduce-tan-voc-files">
                        <xsl:with-param name="idref-attributes-and-IRIs"
                           select="$these-idref-attributes-and-IRIs" tunnel="yes"/>
                        <xsl:with-param name="aliases"
                           select="$doc-with-inclusions-resolved/*/tan:head/tan:vocabulary-key/tan:alias"
                           tunnel="yes"/>
                        <xsl:with-param name="is-standard-tan-voc" select="true()" tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:variable>
                  <!-- Step 3: embed results of step 2 in the main document -->
                  <xsl:variable name="this-n-vocabulary"
                     select="tan:vocabulary('n', (), $doc-with-inclusions-resolved/(*/tan:head, tan:TAN-A/tan:body))"/>
                  <xsl:variable name="doc-with-vocabulary-imprinted" as="document-node()">
                     <xsl:apply-templates select="$doc-with-inclusions-resolved"
                        mode="imprint-vocabulary">
                        <xsl:with-param name="tan-voc-files-reduced"
                           select="$all-tan-voc-files-reduced" tunnel="yes"/>
                        <xsl:with-param name="n-vocabulary" select="$this-n-vocabulary" tunnel="yes"
                        />
                     </xsl:apply-templates>
                  </xsl:variable>

                  <xsl:variable name="diagnostics-on" select="false()"/>
                  <xsl:if test="$diagnostics-on">
                     <xsl:message select="'diagnostics on for tan:resolve-doc(), local variable $doc-with-vocabulary-resolved'"/>
                     <xsl:message select="'this doc’s vocabulary key: ', $this-doc/*/tan:head/tan:vocabulary-key"/>
                     <xsl:message
                        select="'idref attributes parsed: ', $these-idref-attributes-and-IRIs"/>
                     <xsl:message
                        select="'local tan-voc files resolved: ', $these-tan-voc-files-resolved"/>
                     <xsl:message select="'all tan-voc files reduced: ', $all-tan-voc-files-reduced"/>
                     <xsl:message
                        select="'doc with vocabulary imprinted: ', $doc-with-vocabulary-imprinted"/>
                  </xsl:if>
                  <xsl:if test="$these-tan-voc-files-resolved/tan:fatal">
                     <xsl:message
                        select="'In resolving ', $this-doc/*/@id, ' fatal error in fetching a local tan-voc file: ', $doc-with-inclusions-resolved/*/tan:head/tan:vocabulary"
                     />
                  </xsl:if>
                  <xsl:copy-of select="$doc-with-vocabulary-imprinted"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <!-- Step: convert numerals to Arabic -->
         <xsl:variable name="doc-with-n-and-ref-converted" as="document-node()">
            <xsl:choose>
               <xsl:when test="tan:class-number($this-doc) = 1">
                  <xsl:apply-templates select="$doc-with-vocabulary-resolved"
                     mode="resolve-numerals"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:sequence select="$doc-with-vocabulary-resolved"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>

         <xsl:variable name="diagnostics-on" select="false()"/>
         <xsl:if test="$diagnostics-on">
            <xsl:message select="'diagnostics on for tan:resolve-doc() for: ', tan:shallow-copy(*)"/>
            <xsl:message select="'resolve vocabulary?', $resolve-vocabulary"/>
            <xsl:message select="'adding root attribute', $add-attr-to-root-element-named-what"/>
            <xsl:message
               select="'values to add to root attribute:', $add-what-val-to-new-root-attribute"/>
            <xsl:message select="'doc stamped: ', $doc-stamped"/>
            <xsl:message select="'elements with @include: ', $elements-with-attr-include"/>
            <xsl:message select="'these inclusions resolved: ', $these-inclusions-resolved"/>
            <xsl:message
               select="'this doc with inclusions resolved: ', $doc-with-inclusions-resolved"/>
            <xsl:message
               select="'this doc with vocabulary resolved: ', $doc-with-vocabulary-resolved"/>
            <xsl:message
               select="'this doc with @n and @ref converted: ', $doc-with-n-and-ref-converted"/>
         </xsl:if>
         <xsl:choose>
            <xsl:when test="exists(*) and not(namespace-uri(*) = ($TAN-namespace, $TEI-namespace))">
               <xsl:message
                  select="'Document namespace is', $quot, namespace-uri(*), $quot, ', which is not in the TAN or TEI namespaces so tan:resolve() returning only stamped version'"/>
               <xsl:sequence select="$doc-stamped"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- diagnostics -->
               <!--<xsl:copy-of select="$doc-with-inclusions-resolved"/>-->
               <!--<xsl:copy-of select="$doc-with-vocabulary-resolved"/>-->
               <!-- results -->
               <xsl:copy-of select="$doc-with-n-and-ref-converted"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <!-- Step: stamp documents -->
   <xsl:template match="/*"
      mode="first-stamp expand-standard-tan-voc resolve-href resolve-inclusion">
      <!-- The first-stamp mode ensures that when a document is handed over to a variable, the original document URI is not lost. It also provides (1) the breadcrumbing service, so that errors occurring downstream, in an inclusion or TAN-voc file can be diagnosed; (2) the option for @src to be imprinted on the root element, so that a class 1 TAN file can be tethered to a class 2 file that uses it as a source; (3) the conversion of @href to an absolute URI, resolved against the document's base.-->
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="stamp-root-element-with-attr-name" as="xs:string?" tunnel="yes"/>
      <xsl:param name="stamp-root-element-with-attr-val" as="xs:string?" tunnel="yes"/>
      <xsl:variable name="this-base-uri" select="tan:base-uri(.)" as="xs:anyURI"/>
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
      <xsl:variable name="valid-href-exists"
         select="exists(@href) and not(matches(@href, '[\{\}\|\\\^\[\]`]'))"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode first-stamp, for: ', ."/>
         <xsl:message select="'base uri: ', $base-uri"/>
         <xsl:message select="'leave breadcrumbs?', $leave-breadcrumbs"/>
         <xsl:message select="'affects only elements named: ', $affects-only-elements-named"/>
         <xsl:message select="'apply rules? ', $apply-rules"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$apply-rules and $leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:if test="$apply-rules and $valid-href-exists">
            <xsl:variable name="this-base-uri"
               select="
                  if (string-length($base-uri) gt 0) then
                     $base-uri
                  else
                     tan:base-uri(.)"/>
            <xsl:variable name="new-href" select="resolve-uri(@href, xs:string($this-base-uri))"/>
            <!--<xsl:variable name="new-href" select="@href"/>-->
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'@href: ', @href"/>
               <xsl:message select="'this base uri: ', $this-base-uri"/>
               <xsl:message select="'new @href:', $new-href"/>
            </xsl:if>
            <xsl:attribute name="href" select="$new-href"/>
            <xsl:if test="not($new-href = @href)">
               <xsl:attribute name="orig-href" select="@href"/>
            </xsl:if>
         </xsl:if>
         <xsl:choose>
            <xsl:when test="not(exists(@include))">
               <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:when test="not(namespace-uri(root(.)) = $TAN-namespace)">
               <!-- If it has @include but the root is not in the TAN namespace (e.g., a collection file), then continue -->
               <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
               <!-- Otherwise we assume that anything that is included has been already processed -->
               <xsl:copy-of select="node()"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:item/tan:name | tan:vocabulary-key/*/tan:name"
      mode="first-stamp resolve-inclusion">
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <!-- If <name> is a candidate for being referred to by @which, make a clone version of the normalized name immediately after, if its normalized form differs -->
      <xsl:variable name="this-name" select="text()"/>
      <xsl:variable name="this-name-normalized" select="tan:normalize-name($this-name)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
      <xsl:if test="not($this-name = $this-name-normalized)">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- we add @norm, to accelerate name checking -->
            <xsl:attribute name="norm"/>
            <xsl:value-of select="$this-name-normalized"/>
         </xsl:copy>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:vocabulary[@which]" mode="first-stamp resolve-inclusion">
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:variable name="this-which-norm" select="tan:normalize-name(@which)"/>
      <xsl:variable name="this-item"
         select="$TAN-vocabularies/tan:TAN-voc/tan:body[@affects-element = 'vocabulary']/tan:item[tan:name = $this-which-norm]"/>
      <xsl:copy>
         <!-- We drop @which because this is a special, immediate substitution -->
         <xsl:copy-of select="@* except @which"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:copy-of select="$this-item/*"/>
         <xsl:if test="not(exists($this-item))">
            <xsl:copy-of select="tan:error('whi04')"/>
            <xsl:copy-of select="tan:error('whi05')"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:vocabulary-key" mode="first-stamp">
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:alias" mode="first-stamp resolve-inclusion">
      <xsl:param name="leave-breadcrumbs" as="xs:boolean" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$leave-breadcrumbs = true()">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:copy-of select="tan:resolve-alias(.)/*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:resolve-alias" as="element()*">
      <!-- Input: one or more <alias>es -->
      <!-- Output: those elements with children <idref>, each containing a single value that the alias stands for -->
      <!-- It is assumed that <alias>es are still embedded in an XML structure that allows one to reference sibling <alias>es -->
      <!-- Note, this only resolves for each <alias> its final idrefs, but does not check to see if those idrefs are valid -->
      <xsl:param name="aliases" as="element()*"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:resolve-alias()'"/>
      </xsl:if>
      <xsl:for-each select="$aliases">
         <xsl:variable name="other-aliases" select="../tan:alias"/>
         <xsl:variable name="this-id" select="(@xml:id, @id)[1]"/>
         <xsl:variable name="these-idrefs" select="tokenize(normalize-space(@idrefs), ' ')"/>
         <xsl:variable name="this-alias-check"
            select="tan:resolve-alias-loop($these-idrefs, $this-id, $other-aliases, 0)"/>
         <xsl:if test="$diagnostics-on">
            <xsl:message select="'this alias: ', ."/>
            <xsl:message select="'this alias checked: ', $this-alias-check"/>
         </xsl:if>
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="$this-alias-check"/>
         </xsl:copy>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:resolve-alias-loop" as="element()*">
      <!-- Function associated with the master one, above; returns only <id-ref> and <error> children -->
      <xsl:param name="idrefs-to-process" as="xs:string*"/>
      <xsl:param name="alias-ids-already-processed" as="xs:string*"/>
      <xsl:param name="other-aliases" as="element()*"/>
      <xsl:param name="loop-counter" as="xs:integer"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:resolve-alias-loop()'"/>
         <xsl:message select="'loop number: ', $loop-counter"/>
         <xsl:message select="'idrefs to process: ', $idrefs-to-process"/>
         <xsl:message select="'alias ids already processed: ', $alias-ids-already-processed"/>
         <xsl:message select="'other aliases: ', $other-aliases"/>
      </xsl:if>
      <xsl:choose>
         <xsl:when test="count($idrefs-to-process) lt 1"/>
         <xsl:when test="$loop-counter gt $loop-tolerance">
            <xsl:message select="'loop exceeds tolerance'"/>
            <xsl:copy-of select="$other-aliases"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="next-idref" select="$idrefs-to-process[1]"/>
            <xsl:variable name="next-idref-norm" select="tan:help-extracted($next-idref)"/>
            <xsl:variable name="other-alias-picked"
               select="$other-aliases[(@xml:id, @id) = $next-idref-norm]" as="element()?"/>
            <xsl:choose>
               <xsl:when test="$next-idref-norm = $alias-ids-already-processed">
                  <xsl:copy-of select="tan:error('tan14')"/>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop($idrefs-to-process[position() gt 1], $alias-ids-already-processed, $other-aliases, $loop-counter + 1)"
                  />
               </xsl:when>
               <xsl:when test="exists($other-alias-picked)">
                  <xsl:variable name="new-idrefs"
                     select="tokenize(normalize-space($other-alias-picked/@idrefs), ' ')"/>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop(($new-idrefs, $idrefs-to-process[position() gt 1]), ($alias-ids-already-processed, $next-idref-norm), $other-aliases, $loop-counter + 1)"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <idref>
                     <xsl:copy-of select="$next-idref-norm/@help"/>
                     <xsl:value-of select="$next-idref-norm"/>
                  </idref>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop($idrefs-to-process[position() gt 1], $alias-ids-already-processed, $other-aliases, $loop-counter + 1)"
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
   <xsl:template match="*[@href]" mode="resolve-href expand-standard-tan-voc resolve-inclusion">
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
         <xsl:choose>
            <xsl:when test="string-length($this-base-uri) gt 0">
               <xsl:attribute name="href" select="$new-href"/>
               <xsl:if test="not($new-href = @href) and $leave-breadcrumbs">
                  <xsl:attribute name="orig-href" select="@href"/>
               </xsl:if>
            </xsl:when>
            <xsl:otherwise>
               <xsl:message select="'No base uri detected for ', tan:shallow-copy(.)"/>
            </xsl:otherwise>
         </xsl:choose>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <!-- Step: three template modes that resolve vocabulary -->
   <xsl:template match="document-node() | text() | * | @div-type"
      mode="reduce-to-idref-attributes-and-IRIs">
      <xsl:apply-templates select="node() | @*" mode="#current"/>
   </xsl:template>
   <xsl:template match="comment() | processing-instruction()"
      mode="reduce-to-idref-attributes-and-IRIs"/>
   <xsl:template match="tan:IRI" mode="reduce-to-idref-attributes-and-IRIs">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="@*" mode="reduce-to-idref-attributes-and-IRIs">
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="this-refers-to-what-elements" select="tan:target-element-names(.)"/>
      <xsl:if test="exists($this-refers-to-what-elements)">
         <xsl:variable name="this-val-norm" select="tan:help-extracted(.)"/>
         <idref>
            <xsl:for-each select="$this-refers-to-what-elements">
               <element>
                  <xsl:value-of select="."/>
               </element>
            </xsl:for-each>
            <xsl:choose>
               <xsl:when test="$this-name = 'which'">
                  <val>
                     <xsl:value-of select="tan:normalize-name(.)"/>
                  </val>
                  <xsl:if test="exists(../(@id, @xml:id))">
                     <id>
                        <xsl:value-of select="../(@xml:id, @id)"/>
                     </id>
                  </xsl:if>
               </xsl:when>
               <xsl:when test="exists($this-val-norm/@help)">
                  <val>*</val>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:for-each select="tokenize($this-val-norm, ' ')">
                     <xsl:variable name="this-normalized-for-name" select="tan:normalize-name(.)"/>
                     <val>
                        <xsl:value-of select="."/>
                     </val>
                     <xsl:if test="not($this-normalized-for-name = .)">
                        <val>
                           <xsl:value-of select="$this-normalized-for-name"/>
                        </val>
                     </xsl:if>
                  </xsl:for-each>
               </xsl:otherwise>
            </xsl:choose>
         </idref>
         <xsl:text>&#xa;</xsl:text>
      </xsl:if>
   </xsl:template>


   <xsl:template match="/tan:*" mode="reduce-tan-voc-files">
      <xsl:param name="is-standard-tan-voc" as="xs:boolean" tunnel="yes"/>
      <xsl:variable name="root-element-name"
         select="
            if ($is-standard-tan-voc) then
               'tan-vocabulary'
            else
               'vocabulary'"/>
      <xsl:element name="{$root-element-name}">
         <IRI>
            <xsl:value-of select="@id"/>
         </IRI>
         <xsl:copy-of select="tan:head/tan:name"/>
         <xsl:apply-templates select="tan:body" mode="#current"/>
      </xsl:element>
      <xsl:text>&#xa;</xsl:text>
   </xsl:template>
   <xsl:template match="node()" mode="reduce-tan-voc-files">
      <xsl:param name="elements-affected" tunnel="yes"/>
      <xsl:param name="group-types" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="new-affects-elements"
         select="tokenize(normalize-space(@affects-element), ' ')"/>
      <xsl:variable name="this-group-type" select="self::tan:group/@type"/>
      <xsl:variable name="new-group-types" select="tokenize(normalize-space($this-group-type), ' ')"/>
      <xsl:apply-templates mode="#current">
         <!-- an @affects-element cancels out inherited ones -->
         <xsl:with-param name="elements-affected" tunnel="yes"
            select="
               if (exists($new-affects-elements)) then
                  $new-affects-elements
               else
                  $elements-affected"/>
         <!-- a @type is added to inherited ones -->
         <xsl:with-param name="group-types" tunnel="yes" select="$group-types, $new-group-types"/>
      </xsl:apply-templates>
   </xsl:template>

   <xsl:template match="tan:item | tan:verb" priority="1" mode="reduce-tan-voc-files">
      <xsl:param name="is-standard-tan-voc" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="aliases" as="element()*" tunnel="yes"/>
      <xsl:param name="idref-attributes-and-IRIs" tunnel="yes"/>
      <xsl:param name="elements-affected" tunnel="yes"/>
      <xsl:param name="group-types" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="these-elements-affected"
         select="
            if (self::tan:verb) then
               'verb'
            else
               if (exists(@affects-element)) then
                  tokenize(normalize-space(@affects-element), ' ')
               else
                  $elements-affected"
      />
      <xsl:variable name="these-groups"
         select="tokenize(normalize-space(@group), ' '), $group-types"/>
      <xsl:variable name="requests-matching-elements-affected"
         select="$idref-attributes-and-IRIs/tan:idref[tan:element = $these-elements-affected]"/>
      <xsl:variable name="these-names"
         select="
            if ($is-standard-tan-voc) then
               tan:name
            else
               tan:normalize-name(tan:name)"/>
      <xsl:variable name="relevant-requests"
         select="$requests-matching-elements-affected[tan:val = $these-names]"/>
      <xsl:variable name="these-aliases" select="$aliases[tan:idref = $relevant-requests/tan:id]"/>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for termplate: reduce-tan-voc-files'"/>
         <xsl:message select="'elements affected: ', $these-elements-affected"/>
         <xsl:message select="'these groups: ', $these-groups"/>
         <xsl:message
            select="'requests that match the elements affected by this vocabulary: ', $requests-matching-elements-affected"/>

      </xsl:if>
      <xsl:if test="exists($relevant-requests)">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each select="$these-elements-affected">
               <affects-element>
                  <xsl:value-of select="."/>
               </affects-element>
            </xsl:for-each>
            <xsl:for-each select="$these-groups">
               <group>
                  <xsl:value-of select="tan:normalize-name(.)"/>
               </group>
            </xsl:for-each>
            <xsl:apply-templates mode="#current"/>
            <xsl:copy-of select="$relevant-requests/tan:id"/>
            <xsl:for-each select="$these-aliases/(@xml:id, @id)">
               <alias>
                  <xsl:value-of select="."/>
               </alias>
            </xsl:for-each>
         </xsl:copy>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:item/tan:name | tan:verb/tan:name" mode="reduce-tan-voc-files">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:IRI" mode="reduce-tan-voc-files">
      <xsl:param name="idref-attributes-and-IRIs" tunnel="yes"/>
      <xsl:if test="not(. = $idref-attributes-and-IRIs/tan:IRI)">
         <xsl:copy-of select="."/>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:location | tan:token-definition | tan:constraints" mode="reduce-tan-voc-files">
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="tan:vocabulary[not(@include)]" mode="imprint-vocabulary">
      <xsl:param name="tan-voc-files-reduced" as="document-node()*" tunnel="yes"/>
      <xsl:param name="n-vocabulary" as="element()*" tunnel="yes"/>
      <!-- Since this is a TAN file's IRI, there should be only one IRI -->
      <xsl:variable name="this-tan-voc-iri" select="tan:IRI"/>
      <xsl:variable name="this-n-vocabulary" select="$n-vocabulary[tan:IRI = $this-tan-voc-iri]"/>
      <xsl:variable name="n-vocabulary-items" select="$this-n-vocabulary/tan:item"/>
      <xsl:variable name="this-tan-voc-file-reduced"
         select="$tan-voc-files-reduced[*/tan:IRI = $this-tan-voc-iri]"/>
      <!-- Make sure not to copy items that are duplicates of what the n vocabulary is bringing in -->
      <xsl:variable name="tan-voc-items-of-interest" select="$this-tan-voc-file-reduced/*/tan:item[not(tan:IRI = $n-vocabulary-items/tan:IRI)]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'tan-voc file reduced: ', $this-tan-voc-file-reduced"/>
         <xsl:message select="'n vocabulary: ', $this-n-vocabulary"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="node()"/>
         <xsl:copy-of select="$tan-voc-items-of-interest"/>
         <xsl:copy-of select="$n-vocabulary-items"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:vocabulary-key" mode="imprint-vocabulary">
      <xsl:param name="tan-voc-files-reduced" tunnel="yes" as="document-node()*"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
      <!-- Copy the relevant parts of the standard TAN vocabulary, after the <vocabulary-key> -->
      <xsl:copy-of select="$tan-voc-files-reduced/tan:tan-vocabulary[(tan:item, tan:verb)]"/>
   </xsl:template>
   <xsl:template match="tan:alias" priority="1" mode="imprint-vocabulary">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="*/*[@xml:id]" mode="imprint-vocabulary">
      <xsl:param name="aliases" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-id" select="@xml:id"/>
      <xsl:variable name="these-aliases" select="$aliases[tan:idref = $this-id]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <id>
            <xsl:value-of select="@xml:id"/>
         </id>
         <xsl:for-each select="$these-aliases/(@xml:id, @id)">
            <alias>
               <xsl:value-of select="."/>
            </alias>
         </xsl:for-each>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:body" mode="imprint-vocabulary">
      <!-- in the master TAN-A function file, this template is overridden; TAN-A files might have claims with @xml:ids to be processed -->
      <xsl:copy-of select="."/>
   </xsl:template>


   <!-- Step: convert numerals to Arabic numerals -->
   <xsl:template match="/*" priority="1" mode="resolve-numerals">
      <xsl:variable name="ambig-is-roman" select="not(tan:head/tan:numerals/@priority = 'letters')"/>
      <xsl:variable name="n-alias-items"
         select="tan:head/tan:vocabulary/tan:item[tan:affects-attribute = 'n']"/>
      <xsl:variable name="n-alias-constraints" select="tan:head/tan:n-alias"/>
      <xsl:variable name="n-alias-div-type-constraints"
         select="
            for $i in $n-alias-constraints
            return
               tokenize($i/@div-type, '\s+')"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <resolved>numerals</resolved>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
            <xsl:with-param name="n-alias-items" select="$n-alias-items" tunnel="yes"/>
            <xsl:with-param name="n-alias-div-type-constraints"
               select="$n-alias-div-type-constraints" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="*[@include] | tan:inclusion" priority="1" mode="resolve-numerals">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="*:div[@n]" mode="resolve-numerals">
      <xsl:param name="ambig-is-roman" as="xs:boolean?" tunnel="yes" select="true()"/>
      <xsl:param name="n-alias-items" as="element()*" tunnel="yes"/>
      <xsl:param name="n-alias-div-type-constraints" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="these-n-vals" select="tokenize(normalize-space(@n), ' ')"/>
      <xsl:variable name="these-div-types" select="tokenize(@type, '\s+')"/>
      <xsl:variable name="n-aliases-should-be-checked" as="xs:boolean"
         select="not(exists($n-alias-div-type-constraints)) or ($these-div-types = $n-alias-div-type-constraints)"/>
      <xsl:variable name="n-aliases-to-process" as="element()*"
         select="
            if ($n-aliases-should-be-checked) then
               $n-alias-items
            else
               ()"/>
      <xsl:variable name="vals-normalized"
         select="
            for $i in $these-n-vals
            return
               tan:string-to-numerals(lower-case($i), $ambig-is-roman, false(), $n-aliases-to-process)"/>
      <xsl:variable name="n-val-rebuilt" select="string-join($vals-normalized, ' ')"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode resolve-numerals, for: ', ."/>
         <xsl:message select="'ambig #s are roman: ', $ambig-is-roman"/>
         <xsl:message select="'Qty n aliases: ', count($n-alias-items)"/>
         <xsl:message select="'n alias constraints: ', $n-alias-div-type-constraints"/>
         <xsl:message select="'n aliases should be checked: ', $n-aliases-should-be-checked"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="n" select="$n-val-rebuilt"/>
         <xsl:if test="not(@n = $n-val-rebuilt)">
            <xsl:attribute name="orig-n" select="@n"/>
         </xsl:if>
         <xsl:if
            test="
               some $i in $these-n-vals
                  satisfies matches($i, '^0\d')">
            <xsl:copy-of select="tan:error('cl117')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:ref | tan:n" mode="resolve-numerals" priority="1">
      <!-- This part of resolve numerals handles class 2 references that have already been expanded from attributes to elements. -->
      <!-- Because class-2 @ref and @n are never tethered to a div type, we cannot enforce the constraints in the source class-1 file's <n-alias> -->
      <xsl:param name="ambig-is-roman" as="xs:boolean?" tunnel="yes" select="true()"/>
      <xsl:param name="n-alias-items" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-element-name" select="name(.)"/>
      <xsl:variable name="val-normalized"
         select="tan:string-to-numerals(lower-case(text()), $ambig-is-roman, false(), $n-alias-items)"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode resolve-numerals, for: ', ."/>
         <xsl:message select="'ambig #s are roman: ', $ambig-is-roman"/>
         <xsl:message select="'Qty n aliases: ', count($n-alias-items)"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:value-of select="$val-normalized"/>
         <xsl:choose>
            <xsl:when test="not($val-normalized = text()) and ($this-element-name = 'ref')">
               <xsl:for-each select="tokenize($val-normalized, ' ')">
                  <n>
                     <xsl:value-of select="."/>
                  </n>
               </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="*"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>


   <xsl:function name="tan:resolve-inclusion-element-loop" as="element()?">
      <!-- Input: any inclusion element; names of elements that are of interest; ids and urls of documents already processed; boolean indicating whether vocabulary should be resolved; loop counter -->
      <!-- Output: the <inclusion> with last children newly inserted: <error>, <inclusion>, <substitutes>, <tan-vocabulary>, <vocabulary>, <local> -->
      <!-- We assume the <location> in the input <inclusion> already has had its @href resolved -->
      <xsl:param name="inclusion-element" as="element()"/>
      <xsl:param name="names-of-elements-of-interest" as="xs:string*"/>
      <xsl:param name="doc-ids-already-processed" as="xs:string*"/>
      <xsl:param name="doc-urls-already-processed" as="xs:string*"/>
      <xsl:param name="resolve-vocabulary" as="xs:boolean"/>
      <xsl:param name="loop-counter" as="xs:integer"/>
      <xsl:variable name="this-inclusion-doc" select="tan:get-1st-doc($inclusion-element)"/>
      <xsl:variable name="this-inclusion-doc-uri" select="tan:base-uri($this-inclusion-doc)"/>
      <xsl:variable name="this-inclusion-doc-class-no"
         select="tan:class-number($this-inclusion-doc)"/>
      <xsl:variable name="this-inclusion-doc-lightly-resolved">
         <xsl:apply-templates select="$this-inclusion-doc" mode="resolve-inclusion">
            <xsl:with-param name="leave-breadcrumbs" select="false()" tunnel="yes"/>
            <xsl:with-param name="base-uri" tunnel="yes" select="$this-inclusion-doc-uri"/>
         </xsl:apply-templates>
      </xsl:variable>
      <!-- we focus upon head @include and not body @include because we are interested in vocabulary items that might need to be resolved -->
      <xsl:variable name="this-inclusion-head-elements-with-attr-include"
         select="$this-inclusion-doc/*/tan:head//*[@include]"/>
      <!-- In the following variable, make sure to exclude items of interest that are nested in other items of interest -->
      <xsl:variable name="these-elements-of-primary-interest"
         select="$this-inclusion-doc//*[name() = $names-of-elements-of-interest][not(name(..) = $names-of-elements-of-interest)]"/>
      <xsl:variable name="this-inclusion-extra-vocabulary"
         select="tan:get-1st-doc($this-inclusion-doc-lightly-resolved/*/tan:head/tan:vocabulary)"/>
      <xsl:variable name="this-inclusion-extra-vocabulary-resolved"
         select="tan:resolve-doc($this-inclusion-extra-vocabulary, false())"/>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:resolve-inclusion-element-loop()'"/>
         <xsl:message select="'loop number: ', $loop-counter"/>
         <xsl:message select="'inclusion element: ', $inclusion-element"/>
         <xsl:message select="'names of elements of interest: ', $names-of-elements-of-interest"/>
         <xsl:message select="'doc ids already processed: ', $doc-ids-already-processed"/>
         <xsl:message select="'doc urls already processed: ', $doc-urls-already-processed"/>
         <xsl:message select="'resolve vocabulary? ', $resolve-vocabulary"/>
         <xsl:message select="'inclusion doc (shallow): ', tan:shallow-copy($this-inclusion-doc/*)"/>
         <xsl:message select="'inclusion doc base uri:', $this-inclusion-doc-uri"/>
      </xsl:if>
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
               test="not(($this-inclusion-doc, $this-inclusion-extra-vocabulary)/*/@TAN-version = $TAN-version)">
               <xsl:copy-of select="tan:error('inc06')"/>
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
               <!-- It may seem excessive to expand every @include in the head. But it is possible that one of the elements of 
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
                     <xsl:if test="exists($this-inclusion-element)">
                        <xsl:copy-of
                           select="tan:resolve-inclusion-element-loop($this-inclusion-element, $these-elements-names-to-fetch, ($doc-ids-already-processed, $this-inclusion-doc/*/@id), ($doc-urls-already-processed, $this-inclusion-doc-uri), $resolve-vocabulary, $loop-counter + 1)"
                        />
                     </xsl:if>
                  </xsl:for-each-group>
               </xsl:variable>

               <!-- copy the nested <inclusion>s within the <inclusion> -->
               <xsl:copy-of select="$nested-inclusions-resolved"/>


               <!-- Second, get the vocabulary for the substitutes, provided they are not inclusions -->
               <xsl:variable name="this-inclusion-doc-with-inclusions-resolved" as="document-node()">
                  <xsl:apply-templates select="$this-inclusion-doc-lightly-resolved"
                     mode="apply-resolved-inclusions">
                     <xsl:with-param name="resolved-inclusions" select="$nested-inclusions-resolved"
                        tunnel="yes"/>
                  </xsl:apply-templates>
               </xsl:variable>
               <xsl:variable name="this-inclusion-docs-nonincluded-elements-of-interest"
                  select="$this-inclusion-doc-with-inclusions-resolved//*[name() = $names-of-elements-of-interest][not(@include)]"/>
               <xsl:variable name="vocabulary-items-of-interest" as="element()*"
                  select="tan:element-vocabulary($this-inclusion-docs-nonincluded-elements-of-interest)"/>
               <xsl:if test="$resolve-vocabulary = true()">
                  <xsl:copy-of
                     select="tan:consolidate-resolved-vocab-items($vocabulary-items-of-interest)"/>
               </xsl:if>


               <!-- Third, prepare the nonincluded elements that are of interest -->
               <!-- Resolve @href, <alias>, but don't worry about adding @q -->
               <!-- Note, unlike tan:resolve-doc() the stamping occurs not on the entire document but only on elements of interest -->
               <xsl:variable name="substitutes-stamped" as="element()*">
                  <xsl:apply-templates select="$these-elements-of-primary-interest[not(@include)]"
                     mode="first-stamp">
                     <xsl:with-param name="leave-breadcrumbs" select="false()" tunnel="yes"/>
                  </xsl:apply-templates>
               </xsl:variable>
               <!-- convert numerals to Arabic -->
               <xsl:variable name="substitutes-with-n-converted" as="element()*">
                  <xsl:choose>
                     <xsl:when test="$this-inclusion-doc-class-no = 1">
                        <xsl:variable name="ambig-is-roman"
                           select="
                              if ($this-inclusion-doc-lightly-resolved/*/tan:head/tan:numerals/@priority = 'letters') then
                                 false()
                              else
                                 true()"/>
                        <xsl:variable name="n-vocabulary"
                           select="
                              if ($names-of-elements-of-interest = 'div') then
                                 tan:vocabulary('n', (), $this-inclusion-doc-lightly-resolved/(*/tan:head, tan:TAN-A/tan:body))
                              else
                                 ()"/>
                        <xsl:variable name="n-alias-constraints"
                           select="$this-inclusion-doc-lightly-resolved/*/tan:head/tan:n-alias"/>
                        <xsl:if test="$diagnostics-on">
                           <xsl:message select="'ambig #s are roman: ', $ambig-is-roman"/>
                           <xsl:message select="'n vocabulary: ', $n-vocabulary"/>
                           <xsl:message select="'n alias constraints: ', $n-alias-constraints"/>
                        </xsl:if>
                        <xsl:apply-templates select="$substitutes-stamped" mode="resolve-numerals">
                           <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman"
                              tunnel="yes"/>
                           <xsl:with-param name="n-alias-items" select="$n-vocabulary/tan:item"
                              tunnel="yes"/>
                           <xsl:with-param name="n-alias-constraints" select="$n-alias-constraints"
                              tunnel="yes"/>
                        </xsl:apply-templates>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:sequence select="$substitutes-stamped"/>
                     </xsl:otherwise>
                  </xsl:choose>

               </xsl:variable>
               <xsl:if test="$diagnostics-on">
                  <xsl:message
                     select="'this inclusion doc: ', tan:shallow-copy($this-inclusion-doc/*)"/>
               </xsl:if>
               <substitutes>
                  <xsl:copy-of select="$substitutes-with-n-converted"/>
               </substitutes>
            </xsl:otherwise>
         </xsl:choose>
      </inclusion>
   </xsl:function>

   <xsl:template match="*[@include] | collection" mode="resolve-vocabulary-references">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="/tan:*" mode="resolve-vocabulary-references imprint-vocabulary">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <!-- The next element signifies that the file has been resolved, and to interpret it, one need no longer access any vocabulary, whether standard or special -->
         <resolved>vocabulary</resolved>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="aliases" select="tan:head/tan:vocabulary-key/tan:alias" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:inclusion/tan:substitutes/*" mode="resolve-vocabulary-references">
      <xsl:if test="not(exists(preceding-sibling::*))">
         <xsl:comment>shallow copy of substitutes; elements should have been substituted already into resolved document</xsl:comment>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:head/tan:vocabulary[not(@include)]" mode="resolve-vocabulary-references">
      <xsl:param name="vocabulary-analysis" as="element()*" tunnel="yes"/>
      <xsl:param name="n-vocabulary" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-iri" select="tan:IRI"/>
      <xsl:variable name="vocabulary-items-used" select="$vocabulary-analysis[tan:IRI = $this-iri]"/>
      <xsl:variable name="this-n-vocabulary" select="$n-vocabulary[tan:IRI = $this-iri]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <xsl:copy-of
            select="tan:consolidate-resolved-vocab-items(($vocabulary-items-used/tan:item, $this-n-vocabulary/tan:item))"/>
         <!--<xsl:copy-of select="tan:distinct-items(($vocabulary-items-used/tan:item, $this-n-vocabulary/tan:item))"/>-->
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:head/tan:tan-vocabulary" mode="resolve-vocabulary-references">
      <xsl:param name="vocabulary-analysis" as="element()*" tunnel="yes"/>
      <xsl:copy-of select="$vocabulary-analysis/self::tan:tan-vocabulary"/>
   </xsl:template>

   <xsl:template match="tan:vocabulary-key" mode="resolve-vocabulary-references">
      <!-- append any standard TAN vocabulary after the <vocabulary-key> -->
      <xsl:param name="vocabulary-analysis" as="element()*" tunnel="yes"/>
      <xsl:variable name="standard-vocabulary-items-used"
         select="$vocabulary-analysis[self::tan-vocabulary]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
      <xsl:if
         test="exists($standard-vocabulary-items-used) and not(exists(preceding-sibling::tan:tan-vocabulary))">
         <tan-vocabulary>
            <xsl:copy-of select="tan:distinct-items($standard-vocabulary-items-used/*)"/>
         </tan-vocabulary>
      </xsl:if>
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
      <xsl:variable name="these-idref-attributes" select="@*[tan:takes-idrefs(.)] except @div-type"/>
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
                  <xsl:copy-of
                     select="$vocabulary-analysis/self::tan:error[tan:item[not(tan:id)][(tan:affects-element = $this-element-name) and (tan:name = $this-which-norm)]]"
                  />
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
                     <xsl:copy-of
                        select="$vocabulary-analysis/self::tan:error[tan:item[(tan:affects-element = $target-element-names) and (tan:id = $this-val)]]"
                     />
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
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="$matching-inclusion/@*"/>
               <xsl:apply-templates select="$matching-inclusion/node()" mode="#current"/>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <!-- we can omit the substitutes, since they will be placed where needed in the host document -->
   <xsl:template match="tan:inclusion/tan:substitutes" mode="apply-resolved-inclusions"/>
   <xsl:template match="*[@include]" mode="apply-resolved-inclusions">
      <xsl:param name="resolved-inclusions" as="element()*" tunnel="yes"/>
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="these-include-idrefs" select="tokenize(@include, '\s+')"/>
      <xsl:variable name="matching-substitutes"
         select="$resolved-inclusions[@xml:id = $these-include-idrefs]//tan:substitutes/*[name() = $this-name]"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:choose>
         <xsl:when test="not(exists($resolved-inclusions))">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="tan:error('tan05')"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:when>
         <xsl:when test="not(exists($matching-substitutes))">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="tan:error('inc02')"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:for-each select="$matching-substitutes">
               <xsl:copy>
                  <xsl:copy-of select="@*"/>
                  <xsl:copy-of select="$this-element/@*"/>
                  <xsl:choose>
                     <xsl:when test="self::tan:adjustments">
                        <xsl:apply-templates mode="add-q-ref"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:copy-of select="node()"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:copy>
            </xsl:for-each>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template match="*[not(@q)]" mode="add-q-ref">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="q" select="generate-id(.)"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:consolidate-resolved-vocab-items" as="element()*">
      <!-- Input: elements that should be consolidated -->
      <!-- Output: the elements, consolidated -->
      <!-- This function is written to produce an accurately resolved <head>, and adopts the following assumptions. -->
      <!-- We assume that the order of the elements may be altered; It is assumed that elements are never interleaved with text or other nodes -->
      <!-- Elements that are empty and distinct, e.g., <location> should not be consolidated. -->
      <!-- It is also assumed that elements that share <IRI> values should be consolidated with each other -->
      <xsl:param name="elements-to-consolidate" as="element()*"/>
      <xsl:copy-of select="tan:consolidate-resolved-vocab-items-loop($elements-to-consolidate, 1)"/>
   </xsl:function>

   <xsl:function name="tan:consolidate-resolved-vocab-items-loop" as="element()*">
      <xsl:param name="elements-to-consolidate" as="element()*"/>
      <xsl:param name="loop-counter" as="xs:integer"/>
      <xsl:choose>
         <xsl:when test="$loop-counter gt $loop-tolerance">
            <xsl:message
               select="concat('Cannot loop more than ', string($loop-tolerance), ' times')"/>
            <xsl:copy-of select="$elements-to-consolidate"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:for-each-group select="$elements-to-consolidate" group-by="exists(*)">
               <xsl:choose>
                  <xsl:when test="current-grouping-key() = false()">
                     <!-- If we have elements that have no other elements, then they are either empty, or have text nodes -->

                     <xsl:for-each-group select="current-group()"
                        group-by="exists(text()[matches(., '\S')])">
                        <xsl:choose>
                           <xsl:when test="current-grouping-key() = true()">
                              <!-- elements with text nodes should be consolidated only if their name and text content are identical, and attributes should be ignored -->
                              <xsl:for-each-group select="current-group()"
                                 group-by="concat(name(.), '#', string-join(text(), ''))">
                                 <xsl:element name="{name(current-group()[1])}">
                                    <xsl:copy-of select="current-group()/@*"/>
                                    <xsl:value-of select="current-group()[1]"/>
                                 </xsl:element>
                              </xsl:for-each-group>
                           </xsl:when>
                           <xsl:otherwise>
                              <!-- empty elements should not be consolidated, but duplicates should be removed -->
                              <xsl:for-each-group select="current-group()" group-by="name(.)">
                                 <xsl:variable name="this-element-name"
                                    select="current-grouping-key()"/>
                                 <xsl:for-each-group select="current-group()"
                                    group-by="tan:element-fingerprint(.)">
                                    <xsl:element name="{$this-element-name}">
                                       <xsl:copy-of select="current-group()/@*"/>
                                       <xsl:value-of select="current-group()[1]"/>
                                    </xsl:element>
                                 </xsl:for-each-group>
                              </xsl:for-each-group>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:for-each-group>

                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:variable name="this-group-grouped-by-iri" as="element()*"
                        select="tan:group-elements-by-IRI(current-group())"/>
                     <xsl:for-each select="$this-group-grouped-by-iri">
                        <xsl:for-each-group select="*" group-by="name(.)">
                           <xsl:variable name="this-element-name" select="current-grouping-key()"/>
                           <xsl:element name="{$this-element-name}">
                              <xsl:copy-of select="current-group()/@*"/>
                              <xsl:copy-of
                                 select="tan:consolidate-resolved-vocab-items-loop(current-group()/*, $loop-counter + 1)"
                              />
                           </xsl:element>
                        </xsl:for-each-group>
                     </xsl:for-each>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:for-each-group>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>



</xsl:stylesheet>
