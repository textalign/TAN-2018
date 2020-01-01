<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:function name="tan:resolve-doc" as="document-node()?">
      <xsl:param name="TAN-document" as="document-node()?"/>
      <xsl:copy-of select="tan:resolve-doc($TAN-document, true(), ())"/>
   </xsl:function>
   
   <xsl:function name="tan:resolve-doc" as="document-node()?">
      <!-- Input: any TAN document; a boolean indicating whether each element should be stamped with a unique id in @q; attributes that should be added to the root element -->
      <!-- Output: the TAN document, resolved, as explained in the associated loop function below -->
      <xsl:param name="TAN-document" as="document-node()?"/>
      <xsl:param name="add-q-ids" as="xs:boolean"/>
      <xsl:param name="attributes-to-add-to-root-element" as="attribute()*"/>
      <xsl:copy-of
         select="tan:resolve-doc-loop($TAN-document, $add-q-ids, $attributes-to-add-to-root-element, (), (), (), (), 0)"
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
         <xsl:variable name="these-attrs-to-stamp" as="attribute()*">
            <xsl:attribute name="{$this-name-norm}" select="($this-id, $this-element-expanded/(@xml:id, tan:id))[1]"/>
         </xsl:variable>
         <xsl:variable name="this-source-must-be-adjusted"
            select="
               ($this-element-name = 'source') and
               exists(following-sibling::tan:adjustments[(self::*, tan:where)/@src[tokenize(., ' ') = ($this-id, '*')]]/(tan:equate, tan:rename, tan:reassign, tan:skip))"/>
         <xsl:variable name="add-q-ids" select="$this-source-must-be-adjusted"/>
         
         <xsl:variable name="diagnostics-on" select="false()"/>
         <xsl:if test="$diagnostics-on">
            <xsl:message select="'diagnostics on for tan:get-and-resolve-dependency()'"/>
            <xsl:message select="'this element expanded:', $this-element-expanded"/>
         </xsl:if>
         <xsl:choose>
            <xsl:when test="not(exists($this-first-doc))">
               <xsl:sequence select="$empty-doc"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="tan:resolve-doc($this-first-doc, $add-q-ids, $these-attrs-to-stamp)"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>
   
   <xsl:function name="tan:resolve-doc-loop" as="document-node()?">
      <!-- Input: any TAN document and a variety of other parameters -->
      <!-- Output: the document resolved according to specifications -->
      <!-- $element-filters is sequence of elements specifying conditions for whether an element should be fetched, e.g.,:
            <filter>
               <element-name>item</element-name>
               <element-name>verb</element-name>
               <name norm="">vocab name</name>
            </filter>
            <filter>
                <element-name>license</element-name>
                <element-name>div</element-name>
            </filter>
      -->
      <xsl:param name="TAN-document" as="document-node()?"/>
      <xsl:param name="add-q-ids" as="xs:boolean"/>
      <xsl:param name="attributes-to-add-to-root-element" as="attribute()*"/>
      <xsl:param name="urls-already-visited" as="xs:string*"/>
      <xsl:param name="doc-ids-already-visited" as="xs:string*"/>
      <xsl:param name="relationship-to-prev-doc" as="xs:string?"/>
      <xsl:param name="element-filters" as="element()*"/>
      <xsl:param name="loop-counter" as="xs:integer"/>
      
      <xsl:variable name="this-doc-id" select="$TAN-document/*/@id"/>
      <xsl:variable name="this-doc-base-uri" select="tan:base-uri($TAN-document)"/>
      <xsl:variable name="this-is-collection-document" select="$TAN-document/collection"/>
      
      <xsl:choose>
         <xsl:when test="exists($TAN-document/*) and not(namespace-uri($TAN-document/*) = ($TAN-namespace, $TEI-namespace)) and not($this-is-collection-document)">
            <xsl:message
               select="'Document namespace is', $quot, namespace-uri($TAN-document/*), $quot, ', which is not in the TAN or TEI namespaces so tan:resolve() returning only stamped version'"/>
            <xsl:sequence select="$TAN-document"/>
         </xsl:when>
         <xsl:when test="$loop-counter gt $loop-tolerance">
            <xsl:message select="'tan:resolve-doc-loop-new() has repeated itself more than ', $loop-tolerance, ' times and must halt.'"/>
         </xsl:when>
         <xsl:when test="not(exists($TAN-document/(tan:*, tei:*[@TAN-version], collection)))">
            <xsl:document>
               <xsl:copy-of
                  select="tan:error('lnk07', concat('Document requested to be resolved is not a TAN file, but is in the namespace ', namespace-uri($TAN-document/*)))"
               />
            </xsl:document>
         </xsl:when>
         <xsl:when test="$this-doc-id = $doc-ids-already-visited">
            <xsl:document>
               <xsl:copy-of
                  select="tan:error('inc03', concat('The document ', $this-doc-id, ' may not include, directly or indirectly, another document with that same id.'))"
               />
            </xsl:document>
         </xsl:when>
         <xsl:when test="$this-doc-base-uri = $urls-already-visited">
            <xsl:document>
               <xsl:copy-of
                  select="tan:error('inc03', concat('The document at ', $this-doc-base-uri, ' may not include, directly or indirectly, another document at that same location.'))"
               />
            </xsl:document>
         </xsl:when>
         <xsl:otherwise>
            <!-- If all is well, proceed -->
            
            <!-- Step 1: Stamp root element, resolve @hrefs, convert @xml:id to <id> and include alias names, normalize <name>, 
               insert into <vocabulary> full IRI + name pattern (if missing), add constructed IRI + name patterns for elements that imply them,
               if a TAN-voc file, make sure <item> and <verb> retain <affects-element>, <affects-attribute>, <group>
               if there are element filters, get rid of any element that does not match the filter, but retain a root element and a <head type="vocab"/> to contain vocabulary explaining the elements of interest.
            -->
            <!-- Neither vocabularies nor inclusions are dealt with at this stage. We first need to find out what kinds of filters need to be 
               applied to the vocabularies and inclusions before trying to fetch them. -->

            <!-- Step 1a: resolve <alias> -->
            <xsl:variable name="doc-aliases-resolved" select="tan:resolve-alias($TAN-document/*/tan:head/tan:vocabulary-key/tan:alias)"/>
            
            <!-- Stepb 1b: stamp the document, inserting the resolved aliases as a tunnel parameter -->
            <xsl:variable name="doc-stamped" as="document-node()?">
               <xsl:choose>
                  <xsl:when test="exists($element-filters)">
                     <xsl:apply-templates select="$TAN-document" mode="first-stamp-shallow-skip">
                        <xsl:with-param name="add-q-ids" select="$add-q-ids" tunnel="yes"/>
                        <xsl:with-param name="root-element-attributes" tunnel="yes"
                           select="$attributes-to-add-to-root-element"/>
                        <xsl:with-param name="doc-base-uri" tunnel="yes" select="$this-doc-base-uri"/>
                        <xsl:with-param name="resolved-aliases" tunnel="yes" as="element()*"
                           select="$doc-aliases-resolved"/>
                        <xsl:with-param name="element-filters" as="element()+" tunnel="yes"
                           select="$element-filters"/>
                     </xsl:apply-templates>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:apply-templates select="$TAN-document" mode="first-stamp-shallow-copy">
                        <xsl:with-param name="add-q-ids" select="$add-q-ids" tunnel="yes"/>
                        <xsl:with-param name="root-element-attributes" tunnel="yes"
                           select="$attributes-to-add-to-root-element"/>
                        <xsl:with-param name="doc-base-uri" tunnel="yes" select="$this-doc-base-uri"/>
                        <xsl:with-param name="resolved-aliases" tunnel="yes" as="element()*"
                           select="$doc-aliases-resolved"/>
                     </xsl:apply-templates>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>


            <!-- Step 2: build element filters for vocabulary and inclusions -->
            <!-- Step 2a: inclusion element filters -->
            <xsl:variable name="elements-with-attr-include" select="$doc-stamped//*[@include]"/>
            <xsl:variable name="element-filters-for-inclusions" as="element()*">
               <xsl:for-each-group select="$elements-with-attr-include"
                  group-by="tokenize(@include, '\s+')">
                  <xsl:variable name="these-element-names"
                     select="
                        distinct-values(for $i in current-group()
                        return
                           name($i))"/>
                  <xsl:variable name="this-inclusion" select="current-grouping-key()"/>
                  <xsl:for-each-group select="current-group()" group-by="name(.)">
                     <xsl:if test="exists(current-group()[not(tan:filter)])">
                        <filter inclusion="{$this-inclusion}">
                           <element-name>
                              <xsl:value-of select="current-grouping-key()"/>
                           </element-name>
                        </filter>
                     </xsl:if>
                     <xsl:for-each select="current-group()/tan:filter">
                        <xsl:copy>
                           <xsl:attribute name="inclusion" select="$this-inclusion"/>
                           <xsl:copy-of select="*"/>
                        </xsl:copy>
                     </xsl:for-each>
                  </xsl:for-each-group>
               </xsl:for-each-group> 
            </xsl:variable>
            <!-- Step 2b: vocabulary element filters -->
            <xsl:variable name="vocabulary-heads" select="$doc-stamped/*/tan:head, $doc-stamped/(tan:TAN-voc, tan:TAN-A)/tan:body"/>
            <xsl:variable name="element-filters-for-vocabularies-pass-1" as="element()*">
               <xsl:apply-templates select="$doc-stamped" mode="get-undefined-idrefs"/>
            </xsl:variable>
            <xsl:variable name="element-filters-for-vocabularies-pass-2" as="element()*">
               <xsl:for-each select="tan:distinct-items($element-filters-for-vocabularies-pass-1)">
                  <xsl:variable name="these-element-names" select="tan:element-name"/>
                  <xsl:variable name="these-element-name-vals" select="tan:name"/>
                  <xsl:variable name="these-element-idref-vals" select="tan:idref"/>
                  <xsl:variable name="vocab-item-candidates"
                     select="$vocabulary-heads//*[(name(.), tan:affects-element) = $these-element-names]"/>
                  <xsl:variable name="vocab-item-matches"
                     select="$vocab-item-candidates[((tan:id, tan:alias) = $these-element-idref-vals) or (tan:name = $these-element-name-vals)]"/>
                  <xsl:if test="not(exists($vocab-item-matches))">
                     <xsl:copy-of select="."/>
                  </xsl:if>
               </xsl:for-each>
            </xsl:variable>


            <!-- Step 3. Selectively resolve each vocabulary and inclusion, the two most critical dependencies -->
            
            <!-- Although <vocabulary> and <inclusion> behave differently in their host file, they
               are extracted by the same process: the host file queries another TAN file and asks for 
               only a subset of its elements. Hence, neither one has priority over the other, because they are 
               part of the same process; it also means that errors of circular reference make no distinction 
               between inclusions and vocabularies.
            -->
            <xsl:variable name="doc-with-critical-dependencies-resolved" as="document-node()?">
               <xsl:apply-templates select="$doc-stamped" mode="resolve-critical-dependencies">
                  <xsl:with-param name="inclusion-element-filters" tunnel="yes"
                     select="$element-filters-for-inclusions"/>
                  <xsl:with-param name="vocabulary-element-filters" tunnel="yes"
                     select="$element-filters-for-vocabularies-pass-2"/>
                  <xsl:with-param name="doc-id" tunnel="yes" select="$this-doc-id"/>
                  <xsl:with-param name="doc-ids-already-visited" tunnel="yes" select="$doc-ids-already-visited"/>
                  <xsl:with-param name="doc-base-uri" tunnel="yes" select="$this-doc-base-uri"/>
                  <xsl:with-param name="urls-already-visited" as="xs:string*" tunnel="yes" select="$urls-already-visited"/>
                  <xsl:with-param name="loop-counter" tunnel="yes" as="xs:integer" select="$loop-counter"/>
               </xsl:apply-templates>
            </xsl:variable>
            
              
            <!-- Step 4: embed within every *[@include] the substitutes from the appropriate <include>; 
               strip away from every <inclusion>'s <TAN-*> element anything that is not a vocabulary item, or an <inclusion>;
               reduce vocabulary elements
            -->
            <xsl:variable name="imprinted-inclusions" select="$doc-with-critical-dependencies-resolved/*/tan:head/tan:inclusion"/>
            <xsl:variable name="doc-with-inclusions-applied-and-vocabulary-adjusted" as="document-node()?">
               <xsl:apply-templates select="$doc-with-critical-dependencies-resolved" mode="apply-inclusions-and-adjust-vocabulary">
                  <xsl:with-param name="imprinted-inclusions" select="$imprinted-inclusions" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            

            <!-- Step 5. convert numerals to Arabic -->
            <xsl:variable name="doc-with-n-and-ref-converted" as="document-node()">
               <xsl:choose>
                  <xsl:when test="tan:class-number($doc-with-inclusions-applied-and-vocabulary-adjusted) = 1">
                     <xsl:apply-templates select="$doc-with-inclusions-applied-and-vocabulary-adjusted"
                        mode="resolve-numerals"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:sequence select="$doc-with-inclusions-applied-and-vocabulary-adjusted"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>
            
            

            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'Diagnostics on, tan:resolve-doc-loop()'"/>
               <xsl:message select="'add @q ids?', $add-q-ids"/>
               <xsl:message select="'attributes to add to root element:', $attributes-to-add-to-root-element"/>
               <xsl:message select="'urls already visited:', $urls-already-visited"/>
               <xsl:message select="'doc ids already visited:', $doc-ids-already-visited"/>
               <xsl:message select="'relationship to previous doc:', $relationship-to-prev-doc"/>
               <xsl:message select="'incoming element filters:', $element-filters"/>
               <xsl:message select="'loop counter:', $loop-counter"/>
               <xsl:message select="'Doc stamped: ', $doc-stamped"/>
               <xsl:message select="'Element filters for inclusions:', $element-filters-for-inclusions"/>
               <xsl:message select="'Element filters for vocabularies pass 1:', $element-filters-for-vocabularies-pass-1"/>
               <xsl:message select="'Element filters for vocabularies pass 2:', $element-filters-for-vocabularies-pass-2"/>
               <xsl:message select="'Doc with inclusions applied and vocabulary adjusted: ', $doc-with-inclusions-applied-and-vocabulary-adjusted"/>
               <xsl:message select="'Doc with n and ref converted', $doc-with-n-and-ref-converted"/>
            </xsl:if>

            <!--<xsl:copy-of select="$doc-stamped"/>-->
            <!--<xsl:copy-of select="$doc-with-critical-dependencies-resolved"/>-->
            <!--<xsl:copy-of select="$doc-with-inclusions-applied-and-vocabulary-adjusted"/>-->
            <xsl:copy-of select="$doc-with-n-and-ref-converted"/>
            
         </xsl:otherwise>
      </xsl:choose>
      
   </xsl:function>
   
   <!-- Resolving, step 1 templates, functions -->
   
   <xsl:function name="tan:resolve-alias" as="element()*">
      <!-- Input: one or more <alias>es -->
      <!-- Output: those elements with children <idref>, each containing a single value that the alias stands for -->
      <!-- It is assumed that <alias>es are still embedded in an XML structure that allows one to reference sibling <alias>es -->
      <!-- Note, this function only resolves idrefs, but does not check to see if they target anything -->
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
            <alias>
               <xsl:value-of select="$this-id"/>
            </alias>
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
   
   <!-- shallow skipping if we are interested only in select elements -->
   <xsl:template match="@* | text() | comment() | processing-instruction()"
      mode="first-stamp-shallow-skip"/>
   
   <xsl:template match="*" mode="first-stamp-shallow-skip">
      <xsl:param name="element-filters" as="element()+" tunnel="yes"/>
      <xsl:variable name="this-attr-include" select="@include"/>
      <xsl:variable name="these-affects-elements" select="self::tan:item/ancestor-or-self::*[@affects-element][1]/@affects-element"/>
      <xsl:variable name="these-element-names" select="name(.), tokenize($these-affects-elements, '\s+')"/>
      <xsl:variable name="these-normalized-name-children"
         select="
            for $i in tan:name
            return
               tan:normalize-name($i)"
      />
      <xsl:variable name="matching-element-filters" as="element()*">
         <xsl:for-each select="$element-filters">
            <xsl:choose>
               <xsl:when test="not(tan:element-name = $these-element-names)"/>
               <xsl:when test="exists(tan:name) and not(tan:name = $these-normalized-name-children)
                  and not(exists($this-attr-include))"
               />
               <xsl:otherwise>
                  <xsl:sequence select="."/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics on, template mode first-stamp-shallow-skip'"/>
         <xsl:message select="'This element (shallow): ', tan:shallow-copy(.)"/>
         <xsl:message select="'These element names:', $these-element-names"/>
         <xsl:message select="'Element filters: ', $element-filters"/>
         <xsl:message select="'Exist matching element filters? ', exists($matching-element-filters)"/>
         <xsl:message select="'Matching element filters: ', $matching-element-filters"/>
      </xsl:if>
      
      <xsl:choose>
         <xsl:when test="exists($matching-element-filters)">
            <xsl:apply-templates select="." mode="first-stamp-shallow-copy">
               <!-- When building the vocabulary filter, we pushed ahead the <id> and <alias> values, so they could be
                  inserted into the relevant full vocabulary item
               -->
               <xsl:with-param name="children-to-append" select="$matching-element-filters/(tan:id, tan:alias)"/>
               <xsl:with-param name="inclusion-filters" select="$matching-element-filters"/>
            </xsl:apply-templates>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates mode="#current"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template match="tan:head" mode="first-stamp-shallow-skip">
      <xsl:param name="element-filters" as="element()+" tunnel="yes"/>
      <!-- When resolving only part of a document (i.e. fetching only select elements), we still need access to the entire file's vocabulary. -->
      <!-- This template prepares a special container for the vocabulary -->
      <xsl:variable name="this-is-inclusion-search" select="exists($element-filters/@inclusion)"/>
      <!-- If it is not an inclusion search (i.e., if it is a vocabulary search, which targets the body of a tan:TAN-voc file), we skip the head altogether -->
      <xsl:choose>
         <xsl:when test="$this-is-inclusion-search">
            <head vocabulary="">
               <!-- keep a copy of the current head -->
               <xsl:apply-templates mode="first-stamp-shallow-copy"/>
               <!-- we must be certain to retain vocabulary items that are allowed in the body. -->
               <xsl:apply-templates select="parent::tan:TAN-A/tan:body//tan:claim[@xml:id]"
                  mode="first-stamp-shallow-copy"/>
               <xsl:apply-templates select="parent::tan:TAN-voc/tan:body//(tan:item, tan:verb)"
                  mode="first-stamp-shallow-copy"/>
            </head>
            <!-- With the special head in place, we can now continue shallow skipping, looking for desired elements, provided
               that the filters are calling for elements to include. If this file is being searched purly for vocabulary, then the body,
               not the head, is of primary interest.
            -->
            <xsl:apply-templates mode="#current"/>
         </xsl:when>
         <xsl:when test="exists(tan:inclusion)">
            <!-- A file being fetched qua vocabulary might have inclusions that need to play a factor -->
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates select="tan:inclusion" mode="first-stamp-shallow-copy"/>
            </xsl:copy>
         </xsl:when>
      </xsl:choose>
   </xsl:template>
   
   <!-- The following template works for both modes on the root element, because even with shallow skipping, we at least want a root element, so the document is well formed -->
   <xsl:template match="/*" mode="first-stamp-shallow-skip first-stamp-shallow-copy expand-standard-tan-voc resolve-href">
      <xsl:param name="add-q-ids" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="root-element-attributes" as="attribute()*" tunnel="yes"/>
      <xsl:param name="doc-base-uri" tunnel="yes"/>
      
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$root-element-attributes"/>
         <xsl:if test="not(exists(@xml:base))">
            <xsl:attribute name="xml:base" select="$doc-base-uri"/>
         </xsl:if>
         <xsl:if test="$add-q-ids">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <stamped/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
      
   </xsl:template>
   
   <!-- templates for retaining, stamping elements of interest -->
   <xsl:template match="processing-instruction()" mode="resolve-href first-stamp-shallow-copy">
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
   
   <xsl:template match="*" mode="first-stamp-shallow-copy">
      <xsl:param name="add-q-ids" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="doc-base-uri" tunnel="yes"/>
      <xsl:param name="resolved-aliases" tunnel="yes" as="element()*"/>
      <xsl:param name="children-to-append" as="element()*"/>
      <xsl:param name="inclusion-filters" as="element()*"/>

      <xsl:variable name="this-element-name" select="name(.)"/>
      <xsl:variable name="this-href" select="@href"/>
      <xsl:variable name="this-id" select="(@xml:id, @id)[1]"/>
      
      <!-- Some elements are the kind that would be suited to IRI + name patterns, but don't need them because
      of native conventions used within the attributes. For those elements, we construct an IRI + name pattern,
      to facilitate vocabulary searches. -->
      <xsl:variable name="elements-to-insert" as="element()*">
         <xsl:choose>
            <xsl:when test="self::tan:period">
               <IRI>
                  <xsl:value-of select="concat('tag:textalign.net,2015:ns:period:from', @from, ':to', @to)"/>
               </IRI>
               <name>
                  <xsl:value-of select="concat('From ', @from, ' to ', @to)"/>
               </name>
            </xsl:when>
         </xsl:choose>
      </xsl:variable>
      
      <xsl:copy>
         <xsl:copy-of select="@* except @href"/>
         <xsl:if test="$add-q-ids">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:if test="exists($this-href)">
            <xsl:variable name="revised-href"
               select="
                  if (tan:is-valid-uri($this-href)) then
                     resolve-uri($this-href, $doc-base-uri)
                  else
                     ()"
            />
            <xsl:attribute name="href" select="$revised-href"/>
            <xsl:if test="not($this-href eq $revised-href)">
               <xsl:attribute name="orig-href" select="@href"/>
            </xsl:if>
            <!-- Division point between attributes (above) and elements (below) -->
            <xsl:if test="$revised-href eq $doc-base-uri">
               <xsl:copy-of select="tan:error('tan17')"/>
            </xsl:if>
         </xsl:if>
         <xsl:if test="exists($this-id)">
            <xsl:variable name="matching-aliases" select="$resolved-aliases[tan:idref = $this-id]"/>
            <id>
               <xsl:value-of select="$this-id"/>
            </id>
            <xsl:copy-of select="$matching-aliases/tan:alias"/>
         </xsl:if>
         <xsl:if test="$this-element-name = ('item', 'verb')">
            <xsl:variable name="attributes-of-interest"
               select="
                  self::tan:item/ancestor-or-self::*[@affects-element][1]/@affects-element,
                  self::tan:item/ancestor-or-self::*[@affects-attribute][1]/@affects-attribute,
                  ancestor::tan:group[1]/@type"/>
            <xsl:for-each select="$attributes-of-interest">
               <xsl:variable name="this-attr-name" select="name(.)"/>
               <xsl:for-each select="tokenize(., '\s+')">
                  <xsl:element name="{$this-attr-name}">
                     <xsl:value-of select="."/>
                  </xsl:element>
               </xsl:for-each>
            </xsl:for-each>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
         <xsl:copy-of select="$elements-to-insert"/>
         <xsl:copy-of select="$children-to-append"/>
         <!-- An inclusion filter here will make sure that only certain elements get copied during the inclusion process -->
         <xsl:if test="exists(@include)">
            <xsl:copy-of select="$inclusion-filters"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>
   
   <!-- We add tan:head to the match pattern below to avoid catching collection files -->
   <xsl:template match="tan:head/tan:vocabulary[@which]" mode="first-stamp-shallow-copy">
      <xsl:param name="add-q-ids" as="xs:boolean" tunnel="yes"/>
      <xsl:variable name="this-which-norm" select="tan:normalize-name(@which)"/>
      <xsl:variable name="this-item"
         select="$TAN-vocabularies/tan:TAN-voc/tan:body[@affects-element = 'vocabulary']/tan:item[tan:name = $this-which-norm]"/>
      <xsl:copy>
         <!-- We drop @which because this is a special, immediate substitution -->
         <xsl:copy-of select="@* except @which"/>
         <xsl:if test="$add-q-ids">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:copy-of select="$this-item/*"/>
         <xsl:if test="not(exists($this-item))">
            <xsl:copy-of select="tan:error('whi04')"/>
            <xsl:copy-of select="tan:error('whi05')"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:name" mode="first-stamp-shallow-copy">
      <xsl:param name="add-q-ids" as="xs:boolean" tunnel="yes"/>
      
      <xsl:variable name="this-name" select="text()"/>
      <xsl:variable name="this-name-normalized" select="tan:normalize-name($this-name)"/>
      
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$add-q-ids">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:value-of select="."/>
      </xsl:copy>
      <xsl:if test="not($this-name = $this-name-normalized)">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- we add a normalized form (marked by @norm) to accelerate name checking -->
            <xsl:attribute name="norm"/>
            <xsl:value-of select="$this-name-normalized"/>
         </xsl:copy>
      </xsl:if>
   </xsl:template>
   
   <xsl:template match="tan:alias" mode="first-stamp-shallow-copy">
      <xsl:param name="add-q-ids" as="xs:boolean" tunnel="yes"/>
      <xsl:param name="resolved-aliases" tunnel="yes" as="element()*"/>
      <xsl:variable name="this-id" select="(@xml:id, @id)[1]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$add-q-ids">
            <xsl:attribute name="q" select="generate-id(.)"/>
         </xsl:if>
         <xsl:copy-of select="$resolved-aliases[tan:alias = $this-id]/*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   
   <!-- Resolving, step 2 templates -->
   
   <xsl:template match="text() | comment() | processing-instruction()"
      mode="get-undefined-idrefs"/>
   <xsl:template match="* | document-node()" mode="get-undefined-idrefs">
      <xsl:apply-templates select="@* | node()" mode="#current"/>
   </xsl:template>
   
   <xsl:template match="@*" mode="get-undefined-idrefs">
      <xsl:variable name="target-element-names" select="tan:target-element-names(.)"/>
      <xsl:if test="exists($target-element-names)">
         <xsl:variable name="is-attr-which" select="name(.) = 'which'"/>
         <xsl:variable name="these-vals"
            select="
               if ($is-attr-which) then
                  tan:normalize-name(.)
               else
                  tokenize(., '\s+')"
         />
         <xsl:variable name="this-parent" select=".."/>
         <xsl:for-each select="$these-vals">
            <filter type="vocabulary">
               <xsl:for-each select="$target-element-names">
                  <element-name>
                     <xsl:value-of select="."/>
                  </element-name>
               </xsl:for-each>
               <xsl:choose>
                  <xsl:when test="$is-attr-which">
                     <name norm="">
                        <xsl:value-of select="."/>
                     </name>
                     <!-- Although <name> is used to look for vocabulary, when that vocabulary
                     is found, there is a unique opportunity to copy in the values that will make 
                     the vocab item complete. So we copy <id> and <alias> now, to be transferred
                     at a later stage. -->
                     <xsl:copy-of select="$this-parent/(tan:id, tan:alias)"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <idref>
                        <xsl:value-of select="."/>
                     </idref>
                     <name norm="">
                        <xsl:value-of select="tan:normalize-name(.)"/>
                     </name>
                  </xsl:otherwise>
               </xsl:choose>
            </filter>
         </xsl:for-each>
      </xsl:if>
   </xsl:template>


   
   <!-- Resolving, step 3 templates -->
   
   <xsl:template match="tan:inclusion | tan:vocabulary" mode="resolve-critical-dependencies">
      <xsl:param name="inclusion-element-filters" tunnel="yes"/>
      <xsl:param name="vocabulary-element-filters" tunnel="yes"/>
      <xsl:param name="doc-id" tunnel="yes"/>
      <xsl:param name="doc-ids-already-visited" as="xs:string*" tunnel="yes"/>
      <xsl:param name="doc-base-uri" tunnel="yes"/>
      <xsl:param name="urls-already-visited" as="xs:string*" tunnel="yes"/>
      <xsl:param name="loop-counter" tunnel="yes" as="xs:integer"/>
      
      <xsl:variable name="is-inclusion" select="name(.) = 'inclusion'"/>
      <xsl:variable name="this-id" select="@xml:id"/>
      <xsl:variable name="first-doc-available" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="first-doc-base-uri" select="tan:base-uri($first-doc-available)"/>
      
      <xsl:variable name="filters-chosen"
         select="
            if ($is-inclusion) then
               $inclusion-element-filters[@inclusion = $this-id]
            else
               $vocabulary-element-filters"
      />
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics on, template mode resolve-critical-dependencies'"/>
         <xsl:message select="'This inclusion/vocabulary:', ."/>
         <xsl:message select="'This doc id:', string($doc-id)"/>
         <xsl:message select="'Doc ids already visited:', $doc-ids-already-visited"/>
         <xsl:message select="'This doc base uri:', $doc-base-uri"/>
         <xsl:message select="'URLs previously visited:', $urls-already-visited"/>
         <xsl:message select="'Loop counter:', $loop-counter"/>
         <xsl:message
            select="'First inclusion/vocabulary doc available (shallow):', tan:shallow-copy($first-doc-available/*)"
         />
         <xsl:message select="'First doc available base uri:', $first-doc-base-uri"/>
      </xsl:if>
      
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <xsl:choose>
            <!-- If an inclusion isn't invoked with @include then there's no need to process it. -->
            <xsl:when test="not(exists($filters-chosen)) and $is-inclusion"/>
            <xsl:when test="not(exists($first-doc-available)) and $is-inclusion">
               <xsl:copy-of select="tan:error('inc04')"/>
            </xsl:when>
            <xsl:when test="not(exists($first-doc-available))">
               <xsl:copy-of select="tan:error('whi04')"/>
            </xsl:when>
            <xsl:when test="exists($first-doc-available/(tan:error, tan:fatal))">
               <xsl:copy-of select="$first-doc-available"/>
            </xsl:when>
            <!-- The error for a TAN file attempting to include itself, directly or indirectly, will be placed in <location>... -->
            <xsl:when test="$first-doc-base-uri = ($doc-base-uri, $urls-already-visited)"/>
            <!-- ...or in <IRI> -->
            <xsl:when test="tan:IRI = ($doc-id, $doc-ids-already-visited)"/>
            <xsl:when test="($first-doc-available/*/@id = $doc-id)">
               <xsl:copy-of
                  select="tan:error('inc03', concat('Target ', name(.), ' has an id that matches the id of the dependent document: ', $doc-id))"
               />
            </xsl:when>
            <xsl:when test="($first-doc-available/*/@id = $doc-ids-already-visited)">
               <xsl:copy-of
                  select="tan:error('inc03', concat('Target ', name(.), ' has an id (', $first-doc-available/*/@id, ') that matches the id of a document that includes (directly or indirectly) this one'))"
               />
            </xsl:when>
            <xsl:when test="exists($first-doc-available/(tan:error, tan:warning, tan:fatal))">
               <xsl:copy-of select="$first-doc-available/*"/>
            </xsl:when>
            <!--<xsl:when test="not($is-inclusion) and not(tan:tan-type($first-doc-available) = 'TAN-voc')">
               <xsl:copy-of select="tan:error('inc01', concat('Target document has root element named ', name($first-doc-available/*)))"/>
            </xsl:when>-->
            <xsl:when test="not(exists($first-doc-available/(tan:*, tei:*[@TAN-version])))">
               <xsl:copy-of
                  select="tan:error('lnk07', concat('Target ', name(.), ' is not a TAN file, but is in the namespace ', namespace-uri($first-doc-available/*)))"
               />
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="attributes-to-add" as="attribute()*">
                  <xsl:attribute name="{name(.)}" select="@xml:id"/>
               </xsl:variable>
               <xsl:if test="not($first-doc-available/*/@TAN-version = $TAN-version)">
                  <xsl:copy-of select="tan:error('inc06', concat('Target document is version: ', $first-doc-available/*/@TAN-version))"/>
               </xsl:if>
               <xsl:copy-of
                  select="tan:resolve-doc-loop($first-doc-available, false(), $attributes-to-add, ($urls-already-visited, $doc-base-uri), ($doc-ids-already-visited, $doc-id), name(.), $filters-chosen, ($loop-counter + 1))"
               />
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:inclusion/tan:IRI | tan:vocabulary/tan:IRI" mode="resolve-critical-dependencies">
      <xsl:param name="doc-id" tunnel="yes"/>
      <xsl:param name="doc-ids-already-visited" as="xs:string*" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test=". = $doc-id">
            <xsl:copy-of
               select="tan:error('inc03', concat('TAN document with id ', $doc-id, ' should not attempt to include another TAN file by the same id.'))"
            />
         </xsl:if>
         <xsl:if test=". = $doc-ids-already-visited">
            <xsl:copy-of
               select="tan:error('inc03', concat('TAN document with id ', $doc-id, ' is already included by another TAN file with the id ', .))"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:inclusion/tan:location[@href] | tan:vocabulary/tan:location[@href]" mode="resolve-critical-dependencies">
      <xsl:param name="doc-base-uri" tunnel="yes"/>
      <xsl:param name="urls-already-visited" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="href-resolved"
         select="
            if (tan:is-valid-uri(@href)) then
               resolve-uri(@href, $doc-base-uri)
            else
               ()"
      />
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$doc-base-uri = $href-resolved">
            <xsl:copy-of
               select="tan:error('inc03', concat('TAN document at ', $doc-base-uri, ' should not attempt to include itself.'))"
            />
         </xsl:if>
         <xsl:if test="$doc-base-uri = $urls-already-visited">
            <xsl:copy-of
               select="tan:error('inc03', concat('TAN document at ', $doc-base-uri, ' is already included by ', $href-resolved))"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:vocabulary-key" mode="resolve-critical-dependencies">
      <!-- We send all vocabulary filters through the official TAN vocabularies; these will come out as <TAN-voc> elements, which will get fixed in the next step -->
      <xsl:param name="vocabulary-element-filters" tunnel="yes"/>
      <xsl:copy-of select="."/>
      <xsl:apply-templates select="$TAN-vocabularies" mode="first-stamp-shallow-skip">
         <xsl:with-param name="element-filters" select="$vocabulary-element-filters" tunnel="yes"/>
         <xsl:with-param name="add-q-ids" tunnel="yes" select="false()"/>
      </xsl:apply-templates>
   </xsl:template>
   
   

   <!-- Resolving, step 4 templates -->
   
   <xsl:template match="tan:inclusion/*[tan:head]" mode="apply-inclusions-and-adjust-vocabulary">
      <!-- Every <inclusion>, after the requisite <IRI>, <name>, <desc>, has the root element of
      the target document, and that root element has <head vocabulary="">, followed by elements that
      are intended to be substitutes in the host/dependent file. The <inclusion> can dispense with the
      substitutes, but it needs to hang on to the <head>. -->
      <!-- Further, a prefix must be sent down the pipeline, to make sure that nested inclusions get unique 
         ids that reflect the nesting. -->
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates select="tan:head" mode="prefix-element-inclusion-attribute-xmlid">
            <xsl:with-param name="xmlid-prefix" tunnel="yes" select="concat(../@xml:id, '_')"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:inclusion" mode="prefix-element-inclusion-attribute-xmlid">
      <!-- Referencing inclusions that are deeply nested could be a challenge unless @xml:ids are 
         rebuilt to be unique, done here by string-joining inclusion @xml:id's with the underscore -->
      <xsl:param name="xmlid-prefix" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@* except @xml:id"/>
         <xsl:attribute name="xml:id" select="concat($xmlid-prefix, @xml:id)"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:inclusion/tan:id/text()" mode="prefix-element-inclusion-attribute-xmlid">
      <xsl:param name="xmlid-prefix" tunnel="yes"/>
      <xsl:value-of select="concat($xmlid-prefix, .)"/>
   </xsl:template>
   
   <xsl:template match="*[@include]" mode="apply-inclusions-and-adjust-vocabulary">
      <xsl:param name="imprinted-inclusions" tunnel="yes"/>

      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="this-element-name" select="name(.)"/>
      <xsl:variable name="this-attr-include-val-norm" select="tan:help-extracted(@include)"/>
      <xsl:variable name="these-include-idrefs" select="tokenize($this-attr-include-val-norm, ' ')"/>
      <xsl:for-each select="$these-include-idrefs">
         <!-- We need to distribute according to individual values of @include, so that vocabulary can be resolved accurately. -->
         <xsl:variable name="this-idref" select="."/>
         <xsl:variable name="relevant-inclusions" select="$imprinted-inclusions[@xml:id = $this-idref]/*/*[name(.) = $this-element-name]"/>
         <xsl:if test="not(exists($relevant-inclusions))">
            <xsl:variable name="invoking-file-id-for-this-file" select="root($this-element)/*/@inclusion"/>
            <xsl:element name="{$this-element-name}">
               <xsl:copy-of select="$this-element/(@* except @include)"/>
               <xsl:attribute name="include" select="$this-idref"/>
               <xsl:choose>
                  <xsl:when test="exists($invoking-file-id-for-this-file)">
                     <xsl:copy-of
                        select="tan:error('inc02', concat('Included file ', $invoking-file-id-for-this-file, ' cannot find elements named ', $this-element-name, ' in target doc ', $this-idref))"
                     />
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:copy-of
                        select="tan:error('inc02', concat('Cannot find elements named ', $this-element-name, ' in target doc ', $this-idref))"
                     />
                     <xsl:apply-templates select="$this-element/node()" mode="#current"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:element>
         </xsl:if>
         <xsl:for-each select="$relevant-inclusions">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="$this-element/(@* except @include)"/>
               <xsl:attribute name="include" select="$this-idref"/>
               <xsl:apply-templates select="node()" mode="prefix-attr-include">
                  <xsl:with-param name="inclusion-id-prefix" tunnel="yes"
                     select="concat($this-idref, '_')"/>
               </xsl:apply-templates>
            </xsl:copy>
         </xsl:for-each>
         
      </xsl:for-each>
   </xsl:template>
   <xsl:template match="*[@include]" mode="prefix-attr-include">
      <xsl:param name="inclusion-id-prefix" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@* except @include"/>
         <xsl:attribute name="include" select="concat($inclusion-id-prefix, @include)"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:vocabulary/tan:TAN-voc" mode="apply-inclusions-and-adjust-vocabulary">
      <!-- We already know that <vocabulary> targets a TAN-voc file, so we can skip the root element, 
      and even the <head type="vocabulary">, and merely report back the <item>s and <verb>s -->
      <xsl:copy-of select="tan:item, tan:verb"/>
   </xsl:template>
   
   <xsl:template match="tan:head/tan:TAN-voc" mode="apply-inclusions-and-adjust-vocabulary">
      <!-- We retain those standard TAN vocabulary items only if they fetched something that matched a vocabulary filter -->
      <xsl:variable name="vocab-items" select="tan:item, tan:verb"/>
      <xsl:if test="exists($vocab-items)">
         <tan-vocabulary>
            <IRI>
               <xsl:value-of select="@id"/>
            </IRI>
            <name>
               <xsl:value-of select="concat('Standard TAN vocabulary for ', replace(@id, '.+:([^:]+)$', '$1'))"/>
            </name>
            <location href="{@xml:base}" accessed-when="{current-dateTime()}"/>
            <xsl:copy-of select="$vocab-items"/>
         </tan-vocabulary>
      </xsl:if>
   </xsl:template>
   
   <xsl:function name="tan:resolve-href" as="node()?">
      <!-- One-parameter version of the full one, below -->
      <xsl:param name="xml-node" as="node()?"/>
      <xsl:copy-of select="tan:resolve-href($xml-node, true())"/>
   </xsl:function>
   <xsl:function name="tan:resolve-href" as="node()?">
      <!-- Two-parameter version of the full one, below -->
      <xsl:param name="xml-node" as="node()?"/>
      <xsl:param name="add-q-ids" as="xs:boolean"/>
      <xsl:variable name="this-base-uri" select="tan:base-uri($xml-node)"/>
      <xsl:copy-of select="tan:resolve-href($xml-node, $add-q-ids, $this-base-uri)"/>
   </xsl:function>
   <xsl:function name="tan:resolve-href" as="node()?">
      <!-- Input: any XML node; a boolean -->
      <!-- Output: the same node, but with @href resolved to absolute form, with @orig-href if the 2nd parameter is true -->
      <xsl:param name="xml-node" as="node()?"/>
      <xsl:param name="add-q-ids" as="xs:boolean"/>
      <xsl:param name="this-base-uri" as="xs:string"/>
      <xsl:apply-templates select="$xml-node" mode="resolve-href">
         <xsl:with-param name="base-uri" select="$this-base-uri" tunnel="yes"/>
         <xsl:with-param name="add-q-ids" select="$add-q-ids" tunnel="yes"/>
      </xsl:apply-templates>
   </xsl:function>
   
   <xsl:template match="*[@href]" mode="resolve-href expand-standard-tan-voc">
      <xsl:param name="base-uri" as="xs:anyURI?" tunnel="yes"/>
      <xsl:param name="add-q-ids" as="xs:boolean" tunnel="yes" select="true()"/>
      <xsl:variable name="this-base-uri"
         select="
            if (exists($base-uri)) then
               $base-uri
            else
               tan:base-uri(.)"
      />
      <xsl:variable name="new-href" select="resolve-uri(@href, xs:string($this-base-uri))"/>
      <xsl:copy>
         <xsl:copy-of select="@* except @href"/>
         <xsl:choose>
            <xsl:when test="string-length($this-base-uri) gt 0">
               <xsl:attribute name="href" select="$new-href"/>
               <xsl:if test="not($new-href = @href) and $add-q-ids">
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
   
   
   <!-- Resolving, step 5 templates -->
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
   
   <xsl:function name="tan:consolidate-resolved-vocab-items" as="element()*">
      <!-- Input: elements that should be consolidated -->
      <!-- Output: the elements, consolidated -->
      <!-- This function was written to produce an accurately resolved <head>, and adopts the following assumptions. -->
      <!-- We assume that the order of the elements may be altered; it is assumed that elements are never interleaved with text or other nodes -->
      <!-- Elements that are empty and distinct, e.g., <location>, should not be consolidated. -->
      <!-- It is also assumed that elements that share <IRI> values should be consolidated with each other -->
      <!-- Oct 2019: This function was written originally to support the previous method of resolving
      a document. That method has been deleted, but this function retained, in case it proves useful 
      at a later stage. -->
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
