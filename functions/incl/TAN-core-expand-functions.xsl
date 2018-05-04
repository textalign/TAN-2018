<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:function name="tan:expand-doc" as="document-node()*">
      <!-- one-parameter version of the fuller one below -->
      <xsl:param name="tan-doc-and-dependencies" as="document-node()*"/>
      <xsl:copy-of select="tan:expand-doc($tan-doc-and-dependencies, $validation-phase)"/>
   </xsl:function>

   <xsl:function name="tan:expand-doc" as="document-node()*">
      <!-- Input: a tan document, a string indicating a phase of expansion, and for class-2 documents, any dependency class-1 files -->
      <!-- Output: the document and its dependencies expanded at the phase indicated -->
      <!-- Because class 2 files are expanded hand-in-glove with the class 1 files they depend upon, expansion is necessarily synchronized. The original class-2 document is the first document of the result, and the expanded class-1 files follow. -->
      <xsl:param name="tan-doc-and-dependencies" as="document-node()*"/>
      <xsl:param name="target-phase" as="xs:string"/>
      <xsl:variable name="diagnostics" as="xs:boolean" select="false()"/>
      <xsl:if test="$diagnostics">
         <xsl:message>Diagnostics turned on for tan:expand-doc()</xsl:message>
      </xsl:if>
      <xsl:variable name="tan-doc" select="$tan-doc-and-dependencies[1]"/>
      <xsl:variable name="dependencies" select="$tan-doc-and-dependencies[position() gt 1]"/>
      <xsl:variable name="this-id" select="$tan-doc/*/@id"/>
      <xsl:variable name="this-class" select="tan:class-number($tan-doc)"/>
      <xsl:variable name="expansion-so-far" select="$tan-doc/*/tan:expansion"/>
      <xsl:choose>
         <!-- Don't try to do anything if the input document itself is empty -->
         <xsl:when test="not(exists($tan-doc-and-dependencies/*))"/>
         <xsl:when test="$target-phase = $expansion-so-far">
            <!-- If the document is already expanded, no further action is needed -->
            <xsl:sequence select="$tan-doc-and-dependencies"/>
         </xsl:when>
         
         <xsl:when test="name($tan-doc/*) = 'collection'">
            <xsl:apply-templates select="$tan-doc" mode="catalog-expansion-terse"/>
         </xsl:when>

         <!-- terse expansion -->
         <xsl:when test="$target-phase = 'terse'">
            <!-- Terse expansion needs at least three passes: one to resolve aliases (necessary  for interpreting attributes), one to expand overloaded attributes, and then general element expansions. -->
            <xsl:variable name="core-expansion-pass-1" as="document-node()?">
               <xsl:apply-templates select="$tan-doc" mode="core-expansion-terse-alias"/>
            </xsl:variable>
            <xsl:variable name="core-expansion-pass-2" as="document-node()?">
               <xsl:apply-templates select="$core-expansion-pass-1"
                  mode="core-expansion-terse-attributes"/>
            </xsl:variable>
            <xsl:variable name="these-dependencies-resolved" as="document-node()*">
               <xsl:choose>
                  <xsl:when test="(count($dependencies) gt 0) or ($this-class = (1, 3))">
                     <xsl:sequence select="$dependencies"/>
                  </xsl:when>
                  <!-- Class 2 files absolutely must come with the source class 1 files upon which they depend. This variable ensures we have them. -->
                  <xsl:when test="$doc-id = $this-id">
                     <xsl:sequence select="$sources-resolved, $morphologies-resolved"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:variable name="sources-must-be-altered"
                        select="exists($core-expansion-pass-2/*/tan:head/tan:alter/(tan:equate, tan:rename, tan:reassign))"/>
                     <xsl:variable name="these-sources-1st-da"
                        select="tan:get-1st-doc($core-expansion-pass-2/*/tan:head/tan:source)"/>
                     <xsl:variable name="these-morphologies-1st-da"
                        select="
                           if (name($tan-doc/*) = 'TAN-A-lm') then
                              tan:get-1st-doc($core-expansion-pass-2/*/tan:head/tan:definitions/tan:morphology)
                           else
                              ()"/>
                     <xsl:sequence
                        select="tan:resolve-doc($these-sources-1st-da, $sources-must-be-altered, 'src', $core-expansion-pass-2/*/tan:head/tan:source/@xml:id, (), ())"/>
                     <xsl:if test="exists($these-morphologies-1st-da)">
                        <xsl:sequence
                           select="tan:resolve-doc($these-morphologies-1st-da, true(), 'morphology', $core-expansion-pass-2/*/tan:head/tan:definitions/tan:morphology/@xml:id, (), ())"
                        />
                     </xsl:if>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>
            <xsl:variable name="core-expansion-pass-3" as="document-node()?">
               <xsl:apply-templates select="$core-expansion-pass-2" mode="core-expansion-terse">
                  <xsl:with-param name="dependencies" select="$these-dependencies-resolved"
                     tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:choose>
               <!-- terse expansion class 2 -->
               <xsl:when test="$this-class = 2">
                  <xsl:variable name="alter-part-1"
                     select="$core-expansion-pass-3/*/tan:head/tan:alter/(tan:skip, tan:rename, tan:equate)"/>
                  <xsl:variable name="alter-part-2"
                     select="$core-expansion-pass-3/*/(tan:head/tan:alter/tan:reassign, tan:body/tan:claim)"/>
                  <xsl:variable name="dependencies-pass-1" as="document-node()*">
                     <xsl:apply-templates select="$these-dependencies-resolved"
                        mode="dependency-expansion-terse">
                        <!-- The first pass of source expansion processes the first three parts of the <alter>: <skip>, <rename>, <equate> -->
                        <!-- It also sets up <n> and <ref> elements in dependency <div>s that are essential for later references -->
                        <xsl:with-param name="class-2-doc" select="$core-expansion-pass-3"
                           tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:variable>
                  <xsl:variable name="dependencies-pass-2" as="document-node()*">
                     <xsl:choose>
                        <xsl:when test="exists($alter-part-1)">
                           <xsl:apply-templates select="$dependencies-pass-1" mode="reset-hierarchy"
                           />
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$dependencies-pass-1"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>
                  <xsl:variable name="dependencies-pass-3" as="document-node()*">
                     <xsl:apply-templates select="$dependencies-pass-2"
                        mode="dependencies-tokenized-selectively">
                        <xsl:with-param name="class-2-doc" select="$core-expansion-pass-3"
                           tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:variable>
                  <xsl:variable name="class-2-expansion" as="document-node()?">
                     <xsl:apply-templates select="$core-expansion-pass-3"
                        mode="class-2-expansion-terse">
                        <xsl:with-param name="dependencies" select="$dependencies-pass-3"
                           tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:variable>
                  <xsl:choose>
                     <xsl:when test="$diagnostics">
                        <xsl:document>
                           <xsl:copy-of select="$alter-part-1"/>
                        </xsl:document>
                        <!--<xsl:copy-of select="$core-expansion-pass-3, $these-dependencies-resolved"/>-->
                        <!--<xsl:copy-of select="$core-expansion-pass-3, $dependencies-pass-1"/>-->
                        <!--<xsl:copy-of select="$core-expansion-pass-3, $dependencies-pass-2"/>-->
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:copy-of select="$class-2-expansion, $dependencies-pass-3"/>
                     </xsl:otherwise>
                  </xsl:choose>
                  <xsl:if test="$diagnostics">
                  </xsl:if>
               </xsl:when>
               <xsl:otherwise>
                  <!-- diagnostics, results -->
                  <!--<xsl:copy-of select="$core-expansion-pass-1, $dependencies"/>-->
                  <!--<xsl:copy-of select="$core-expansion-pass-2, $dependencies"/>-->
                  <xsl:copy-of select="$core-expansion-pass-3, $dependencies"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:when>


         <!-- normal expansion -->
         <xsl:when test="$target-phase = 'normal'">
            <xsl:choose>
               <xsl:when test="$expansion-so-far = 'terse'">
                  <xsl:variable name="core-expansion" as="document-node()">
                     <xsl:apply-templates select="$tan-doc" mode="core-expansion-normal">
                        <xsl:with-param name="dependencies" select="$dependencies" tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:variable>
                  <xsl:choose>
                     <xsl:when test="$this-class = 2">
                        <xsl:variable name="dependencies-reset" as="document-node()*">
                           <xsl:apply-templates select="$dependencies" mode="reset-hierarchy"/>
                           <!-- testing -->
                           <!--<xsl:apply-templates select="$dependencies[2]" mode="reset-hierarchy">
                              <!-\-<xsl:with-param name="test" select="true()" tunnel="yes"/>-\->
                           </xsl:apply-templates>-->
                        </xsl:variable>
                        <xsl:variable name="dependencies-should-be-fully-tokenized"
                           select="exists($core-expansion/*/tan:body//tan:tok[not(tan:ref)])"/>
                        <xsl:variable name="dependencies-pass-2" as="document-node()*">
                           <xsl:apply-templates select="$dependencies-reset"
                              mode="dependency-expansion-normal">
                              <xsl:with-param name="token-definition"
                                 select="
                                    if ($dependencies-should-be-fully-tokenized) then
                                       $core-expansion/*/tan:head/tan:definitions/tan:token-definition
                                    else
                                       ()"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:variable>
                        <xsl:variable name="class-2-expansion" as="document-node()">
                           <xsl:apply-templates select="$core-expansion"
                              mode="class-2-expansion-normal">
                              <xsl:with-param name="dependencies" select="$dependencies-pass-2"
                                 tunnel="yes"/>
                              <xsl:with-param name="all-tokens"
                                 select="$dependencies-pass-2/tan:TAN-T/tan:body//tan:tok"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:variable>
                        <!-- diagnostics, results -->
                        <!--<xsl:copy-of select="$core-expansion, $dependencies"/>-->
                        <!--<xsl:copy-of select="$core-expansion, $dependencies-reset"/>-->
                        <!--<xsl:copy-of select="$core-expansion, $dependencies-pass-2"/>-->
                        <xsl:copy-of select="$class-2-expansion, $dependencies-pass-2"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:copy-of select="$core-expansion, $dependencies"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:when>

               <xsl:otherwise>
                  <!-- If the document hasn't been expanded even tersely, then that needs to happen first. -->
                  <xsl:variable name="pass-1"
                     select="tan:expand-doc($tan-doc-and-dependencies, 'terse')"/>
                  <xsl:copy-of select="tan:expand-doc($pass-1, 'normal')"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:when>

         <!-- verbose expansion -->
         <xsl:otherwise>
            <xsl:choose>
               <xsl:when test="$expansion-so-far = 'normal'">
                  <xsl:variable name="core-expansion" as="document-node()">
                     <xsl:apply-templates select="$tan-doc" mode="core-expansion-verbose"/>
                  </xsl:variable>
                  <xsl:choose>
                     <xsl:when test="$this-class = 1">
                        <xsl:variable name="class-1-expansion" as="document-node()">
                           <xsl:apply-templates select="$core-expansion"
                              mode="class-1-expansion-verbose"/>
                        </xsl:variable>
                        <xsl:copy-of select="$class-1-expansion"/>
                     </xsl:when>
                     <xsl:when test="$this-class = 2">
                        <!-- Commented out sections below anticipate areas of development; it also points to a very useful application of TAN functions, namely, to create a merger of an number of class 1 documents -->
                        <!-- Those mergers are quite time consuming for TAN-A-div files with numerous or large source files -->
                        <!-- We assume from the previous expansion that all source <div>s are in proper hierarchical order -->
                        <!--<xsl:variable name="sources-merged" as="document-node()*">
                           <xsl:if test="tan:tan-type($tan-doc) = 'TAN-A-div'">
                              <xsl:for-each-group select="$dependencies" group-by="*/@work">
                                 <xsl:copy-of select="tan:merge-expanded-docs(current-group())"/>
                              </xsl:for-each-group>
                           </xsl:if>
                        </xsl:variable>-->
                        <!--<xsl:variable name="dependencies-expanded" as="document-node()*">
                           <xsl:apply-templates select="$dependencies"
                              mode="dependency-expansion-verbose">
                              <!-\- we send along any claims that invoke <tok> or <div-ref>; we stipulate they must have an element, to avoid collecting <tok>s that have been copied from the source into the class 2 file -\->
                              <!-\- we send along div-ref but not tok-ref, because some class 2 <tok>s are not connected to any particular text reference -\->
                              <xsl:with-param name="class-2-claims" select="$core-expansion/*/tan:body//(tan:tok, tan:div-ref)[*]" tunnel="yes"/>
                              <xsl:with-param name="token-definition"
                                 select="$core-expansion/*/tan:head/tan:definitions/tan:token-definition[1]"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:variable>-->
                        <xsl:variable name="class-2-expansion" as="document-node()">
                           <xsl:apply-templates select="$core-expansion"
                              mode="class-2-expansion-verbose">
                              <!--<xsl:with-param name="dependencies" select="$dependencies"
                                 tunnel="yes"/>-->
                           </xsl:apply-templates>
                        </xsl:variable>
                        <!-- diagnostics, results -->
                        <!--<xsl:copy-of select="$dependencies"/>-->
                        <!--<xsl:copy-of select="$sources-merged"/>-->
                        <!--<xsl:copy-of
                           select="$core-expansion, $dependencies-expanded, $sources-merged"/>-->
                        <!--<xsl:copy-of
                           select="$class-2-expansion, $dependencies-expanded, $sources-merged"/>-->
                        <xsl:copy-of select="$class-2-expansion, $dependencies"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:copy-of select="$core-expansion, $dependencies"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:variable name="pass-1"
                     select="tan:expand-doc($tan-doc-and-dependencies, 'normal')"/>
                  <xsl:copy-of select="tan:expand-doc($pass-1, 'verbose')"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <!-- EXPANSION, GENERALLY -->

   <xsl:template match="tan:inclusion | tan:key | tan:source | tan:see-also | tan:morphology | tan:redivision | tan:model | tan:successor | tan:predecessor"
      mode="check-referred-doc">
      <!-- Look for errors in a document referred to -->
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="this-doc-id" select="root(.)/*/@id"/>
      <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
      <xsl:variable name="this-pos" select="count(preceding-sibling::*[name(.) = $this-name]) + 1"/>
      <xsl:variable name="this-class" select="tan:class-number(.)"/>
      <xsl:variable name="this-relationship-idrefs" select="tan:relationship"/>
      <xsl:variable name="this-relationship-IRIs" select="../tan:definitions/tan:relationship[@xml:id = $this-relationship-idrefs]/tan:IRI"/>
      <xsl:variable name="this-TAN-reserved-relationships"
         select="
            if (exists($this-relationship-IRIs)) then
               $TAN-keywords/tan:TAN-key/tan:body//tan:item[tan:IRI = $this-relationship-IRIs]
            else
               ()"/>
      <xsl:variable name="target-1st-da-resolved" as="document-node()?">
         <xsl:choose>
            <xsl:when test="self::tan:inclusion and $this-doc-id = $doc-id">
               <xsl:copy-of select="$inclusions-resolved[position() = $this-pos]"/>
            </xsl:when>
            <xsl:when test="self::tan:key and $this-doc-id = $doc-id">
               <xsl:copy-of select="$keys-resolved[position() = $this-pos]"/>
            </xsl:when>
            <xsl:when test="self::tan:source and $this-doc-id = $doc-id">
               <xsl:copy-of select="$sources-resolved[position() = $this-pos]"/>
            </xsl:when>
            <xsl:when test="self::tan:see-also and $this-doc-id = $doc-id">
               <xsl:copy-of select="$see-alsos-resolved[position() = $this-pos]"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="tan:resolve-doc(tan:get-1st-doc(.))"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="target-class" select="tan:class-number($target-1st-da-resolved)"/>
      <xsl:variable name="target-is-faulty"
         select="
            deep-equal($target-1st-da-resolved, $empty-doc)
            or $target-1st-da-resolved/(tan:error, tan:warning, tan:fatal, tan:help)"/>
      <xsl:variable name="target-is-in-progress" as="xs:boolean?"
         select="
            if ($target-1st-da-resolved/*/(tan:body, tei:text/tei:body)/@in-progress = false())
            then
               false()
            else
               if (exists($target-1st-da-resolved/*/(tan:body, tei:text/tei:body))) then
                  true()
               else
                  ()"/>
      <xsl:variable name="target-new-versions"
         select="$target-1st-da-resolved/*/tan:head/tan:see-also[tan:definition(tan:relationship) = 'new version']"/>
      <xsl:variable name="target-hist" select="tan:get-doc-hist($target-1st-da-resolved)"/>
      <xsl:variable name="target-id" select="$target-1st-da-resolved/*/@id"/>
      <xsl:variable name="target-last-change-agent" select="tan:last-change-agent($target-1st-da-resolved)"/>
      <!-- We change TEI to TAN-T, just so that TEI and TAN-T files can be treated as copies of each other -->
      <xsl:variable name="prov-root-name" select="replace(name(root(.)/*), '^TEI$', 'TAN-T')"/>
      <xsl:variable name="target-accessed"
         select="max(tan:dateTime-to-decimal(tan:location/@when-accessed))"/>
      <xsl:variable name="target-updates"
         select="$target-hist/*[number(@when-sort) gt $target-accessed]"/>
      <xsl:variable name="duplicate-key-item-names" as="element()*">
         <xsl:for-each-group select="$keys-1st-da/tan:TAN-key/tan:body//tan:item"
            group-by="tokenize(tan:normalize-text((ancestor-or-self::*/@affects-element)[last()]), ' ')">
            <xsl:variable name="this-element-name" select="current-grouping-key()"/>
            <xsl:for-each-group select="current-group()" group-by="tan:name">
               <xsl:if
                  test="
                     count(current-group()) gt 1 and (some $i in current-group()
                        satisfies root($i)/*/@id = $target-1st-da-resolved/*/@id)">
                  <duplicate affects-element="{$this-element-name}" name="{current-grouping-key()}"
                  />
               </xsl:if>
            </xsl:for-each-group>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:variable name="duplicate-key-item-IRIs" as="element()*">
         <xsl:for-each-group select="$keys-1st-da/tan:TAN-key/tan:body//tan:item" group-by="tan:IRI">
            <xsl:if
               test="
                  count(current-group()) gt 1 and (some $i in current-group()
                     satisfies root($i)/*/@id = $target-1st-da-resolved/*/@id)">
               <duplicate
                  affects-element="{distinct-values(for $i in current-group() return tokenize(tan:normalize-text(($i/ancestor-or-self::*/@affects-element)[1]),' '))}"
                  iri="{current-grouping-key()}"/>
            </xsl:if>
         </xsl:for-each-group>
      </xsl:variable>

      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="
               $this-TAN-reserved-relationships//ancestor::tan:group/tan:name = 'TAN files'
               and $target-class = 0">
            <xsl:copy-of
               select="tan:error('see01', concat('root element name: ', name($target-1st-da-resolved/*)))"
            />
         </xsl:if>
         <xsl:if
            test="
               $this-TAN-reserved-relationships//ancestor::tan:group/tan:name = 'copies'
               and not(replace(name($target-1st-da-resolved/*), '^TEI$', 'TAN-T') = $prov-root-name)">
            <xsl:copy-of
               select="tan:error('see03', concat('root element name: ', name($target-1st-da-resolved/*)))"
            />
         </xsl:if>
         <xsl:if
            test="
               $this-TAN-reserved-relationships/tan:name = 'different work version' and
               not($prov-root-name = 'TAN-T'
               and $head/tan:definitions/tan:work/tan:IRI = $target-1st-da-resolved/(tei:TEI, tan:TAN-T)/tan:head/tan:definitions/tan:work/tan:IRI)">
            <xsl:copy-of select="tan:error('see04')"/>
         </xsl:if>
         <xsl:copy-of select="$target-1st-da-resolved/tan:error"/>
         <xsl:if test="exists(tan:location) and not($target-id = tan:IRI) and $target-class gt 0">
            <xsl:copy-of
               select="tan:error('loc02', concat('ID of see-also file: ', $target-id), $target-id, 'replace-text')"
            />
         </xsl:if>
         <xsl:if
            test="($doc-id = $target-1st-da-resolved/*/@id) and not(self::tan:see-also and $this-TAN-reserved-relationships/tan:name = ('new version', 'old version'))">
            <xsl:copy-of select="tan:error('loc03')"/>
         </xsl:if>
         <xsl:if test="exists($target-updates)">
            <xsl:variable name="this-message">
               <xsl:text>Target updated </xsl:text>
               <xsl:value-of select="count($target-updates)"/>
               <xsl:text> times since last accessed (</xsl:text>
               <xsl:for-each select="$target-updates">
                  <xsl:value-of select="concat('&lt;', name(.), '> ')"/>
                  <xsl:for-each select="(@when-accessed, @ed-when, @when)">
                     <xsl:value-of select="concat('[', ., '] ')"/>
                  </xsl:for-each>
               </xsl:for-each>
               <xsl:text>)</xsl:text>
            </xsl:variable>
            <xsl:copy-of select="tan:error('wrn02', $this-message)"/>
            <xsl:for-each select="$target-updates[@flags]">
               <xsl:variable name="this-id" select="@when"/>
               <xsl:variable name="this-flag">
                  <xsl:analyze-string select="@flags" regex="^(warning|error|fatal|info)">
                     <xsl:matching-substring>
                        <xsl:value-of select="regex-group(1)"/>
                     </xsl:matching-substring>
                  </xsl:analyze-string>
               </xsl:variable>
               <xsl:if test="string-length($this-flag) gt 1">
                  <xsl:element name="{$this-flag}">
                     <xsl:attribute name="xml:id" select="$this-id"/>
                     <xsl:element name="{if ($this-flag = 'info') then 'message' else 'rule'}">
                        <xsl:value-of select="."/>
                     </xsl:element>
                  </xsl:element>
               </xsl:if>
            </xsl:for-each>
         </xsl:if>
         <xsl:if test="$target-is-in-progress = true()">
            <xsl:copy-of select="tan:error('wrn03')"/>
         </xsl:if>
         <xsl:if test="exists($target-new-versions)">
            <xsl:copy-of select="tan:error('wrn05')"/>
         </xsl:if>
         <xsl:if test="self::tan:inclusion and $target-is-faulty = true()">
            <xsl:copy-of select="tan:error('inc04')"/>
         </xsl:if>
         <xsl:if test="self::tan:key">
            <xsl:if test="$target-is-faulty = true()">
               <xsl:copy-of select="tan:error('whi04')"/>
            </xsl:if>
            <xsl:if test="exists($duplicate-key-item-names)">
               <xsl:copy-of
                  select="
                     tan:error('whi02', string-join(for $i in $duplicate-key-item-names
                     return
                        concat($i/@affects-element, ' ', $i/@name), '; '))"
               />
            </xsl:if>
            <xsl:if test="exists($duplicate-key-item-IRIs)">
               <xsl:copy-of
                  select="
                     tan:error('tan11', string-join(for $i in $duplicate-key-item-IRIs
                     return
                        concat($i/@affects-element, ' ', $i/@iri), '; '))"
               />
            </xsl:if>
         </xsl:if>
         <xsl:if test="self::tan:source and $target-is-faulty = true() and $this-class = 2">
            <xsl:copy-of select="tan:error('cl201')"/>
         </xsl:if>
         <xsl:if test="exists($target-last-change-agent/self::tan:algorithm)">
            <xsl:copy-of select="tan:error('wrn07','The last change in the dependency was made by an algorithm.')"/>
         </xsl:if>
         <xsl:if test="$target-is-faulty">
            <xsl:variable name="these-catalogs"
               select="
                  if ($this-doc-id = $doc-id) then
                     $doc-catalogs
                  else
                     tan:catalogs(., false())"
            />
            <xsl:variable name="these-iris" select="tan:IRI"/>
            <xsl:variable name="catalog-matches" select="$these-catalogs/collection/doc[@id = $these-iris]"/>
            <xsl:variable name="possible-uris"
               select="
                  for $i in $catalog-matches
                  return
                     resolve-uri($i/@href, xs:string(tan:base-uri($i)))[not(. = $this-base-uri)]"
            />
            <xsl:variable name="this-fix" as="element()*">
               <xsl:for-each select="$possible-uris">
                  <location href="{tan:uri-relative-to(xs:string(.), xs:string($this-base-uri))}"
                     when-accessed="{current-date()}"/>
               </xsl:for-each> 
            </xsl:variable>
            <xsl:if test="exists($possible-uris)">
               <xsl:copy-of select="tan:error('wrn08', (), $this-fix, 'append-content')"/>
            </xsl:if>
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="target-id" select="$target-id"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:IRI" mode="check-referred-doc">
      <xsl:param name="target-id" as="xs:string?"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test=". = $duplicate-head-iris">
            <xsl:copy-of select="tan:error('tan09', .)"/>
         </xsl:if>
         <xsl:if test="exists($target-id) and not(. = $target-id)">
            <xsl:copy-of
               select="tan:error('tan10', concat('Target document @id = ', $target-id), $target-id, 'replace-text')"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <!-- CORE EXPANSION TERSE -->

   <xsl:template match="tan:body" mode="core-expansion-terse-alias">
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:function name="tan:resolve-alias" as="element()*">
      <!-- Input: one or more <alias>es -->
      <!-- Output: those elements with children <idref>, each containing a single value that the alias stands for -->
      <xsl:param name="aliases" as="element()*"/>
      <xsl:for-each select="$aliases">
         <xsl:variable name="this-id" select="(@xml:id, @id)[1]"/>
         <xsl:variable name="these-idrefs" select="tokenize(normalize-space(@idrefs), ' ')"/>
         <xsl:variable name="other-aliases" select="../tan:alias[not((@xml:id, @id) = $this-id)]"/>
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="tan:resolve-alias-loop($other-aliases, $these-idrefs, $this-id)"/>
         </xsl:copy>
      </xsl:for-each>
   </xsl:function>
   <xsl:function name="tan:resolve-alias-loop" as="element()*">
      <!-- Function associated with the master one, above; returns only <id-ref> and <error> children -->
      <xsl:param name="other-aliases" as="element()*"/>
      <xsl:param name="idrefs-to-process" as="xs:string*"/>
      <xsl:param name="alias-ids-already-processed" as="xs:string*"/>
      <xsl:choose>
         <xsl:when test="count($idrefs-to-process) lt 1"/>
         <xsl:otherwise>
            <xsl:variable name="next-idref" select="$idrefs-to-process[1]"/>
            <xsl:variable name="this-idref-checked" select="tan:help-extracted($next-idref)"/>
            <xsl:variable name="other-alias-picked"
               select="$other-aliases[(@xml:id, @id) = $this-idref-checked]" as="element()?"/>
            <xsl:choose>
               <xsl:when test="$this-idref-checked = $alias-ids-already-processed">
                  <xsl:copy-of select="tan:error('tan14')"/>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop($other-aliases, $idrefs-to-process[position() gt 1], $alias-ids-already-processed)"
                  />
               </xsl:when>
               <xsl:when test="exists($other-alias-picked)">
                  <xsl:variable name="new-idrefs"
                     select="tokenize(normalize-space($other-alias-picked/@idrefs), ' ')"/>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop($other-aliases, ($new-idrefs, $idrefs-to-process[position() gt 1]), ($alias-ids-already-processed, $this-idref-checked))"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <idref>
                     <xsl:copy-of select="$this-idref-checked/@help"/>
                     <xsl:value-of select="$this-idref-checked"/>
                  </idref>
                  <xsl:copy-of
                     select="tan:resolve-alias-loop($other-aliases, $idrefs-to-process[position() gt 1], $alias-ids-already-processed)"
                  />
               </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:template match="tan:alias" mode="core-expansion-terse-alias dependency-expansion-terse">
      <xsl:variable name="this-id" select="(@xml:id, @id)"/>
      <!--<xsl:variable name="this-resolved" select="$all-aliases-resolved[$this-id = (@xml:id, @id)]"/>-->
      <xsl:variable name="this-resolved" select="tan:resolve-alias(.)"/>
      <xsl:variable name="these-entities"
         select="root(.)//*[(@xml:id, @id) = $this-resolved/tan:idref]"/>
      <!--<xsl:variable name="these-entities" select="tan:idrefs($this-resolved/tan:idref, root())"/>-->
      <xsl:variable name="these-entity-names"
         select="
            distinct-values(for $i in $these-entities[not(self::tan:error)]
            return
               name($i))"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists(@idrefs) and not(exists($these-entities))">
            <xsl:copy-of select="tan:error('tan05')"/>
         </xsl:if>
         <xsl:if test="count($these-entity-names) gt 1">
            <xsl:variable name="this-message"
               select="concat('mixes ', string-join($these-entity-names, ', '))"/>
            <xsl:copy-of select="tan:error('tan13', $this-message)"/>
         </xsl:if>
         <xsl:copy-of select="$these-entities[self::tan:error]"/>
         <!-- next item copies both errors and <idref> with fully resolved idrefs -->
         <xsl:copy-of select="$this-resolved/*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:function name="tan:resolve-idref" as="xs:string*">
      <!-- Input: any strings -->
      <!-- Output: if a string refers to the id value of an <alias>, the references to that alias, otherwise the string itself -->
      <xsl:param name="ref-vals" as="xs:string*"/>
      <xsl:param name="aliases-expanded" as="element()*"/>
      <xsl:for-each select="$ref-vals">
         <xsl:variable name="this-val" select="."/>
         <xsl:variable name="this-alias" select="$aliases-expanded[(@xml:id, @id) = $this-val]"/>
         <xsl:choose>
            <xsl:when test="exists($this-alias)">
               <xsl:for-each select="$this-alias/tan:idref">
                  <xsl:value-of select="."/>
               </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
               <xsl:value-of select="."/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>

   <xsl:template match="/*" mode="core-expansion-terse-attributes">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="aliases" select="tan:head/tan:definitions/tan:alias" tunnel="yes"
            />
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tei:teiHeader" mode="core-expansion-terse-attributes">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="*" mode="core-expansion-terse-attributes">
      <xsl:param name="aliases" tunnel="yes"/>
      <xsl:variable name="this-from" select="tan:dateTime-to-decimal(@from)"/>
      <xsl:variable name="this-to" select="tan:dateTime-to-decimal(@to)"/>
      <xsl:variable name="this-head" select="root()/*/tan:head"/>
      <!-- This next variable treats attributes that refer via idrefs to one or more entities defined by @xml:id -->
      <xsl:variable name="these-refs" as="element()*">
         <xsl:for-each
            select="@*[name(.) = $id-idrefs/tan:id-idrefs/tan:id[not(@cross-file)]/tan:idrefs/@attribute][parent::tan:* or parent::tei:div]">
            <xsl:variable name="this-attribute-name" select="name(.)"/>
            <xsl:variable name="should-refer-to-which-element"
               select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs/@attribute = $this-attribute-name]/tan:element"/>
            <xsl:variable name="all-possible-valid-entities"
               select="$this-head//*[name(.) = $should-refer-to-which-element]"/>
            <xsl:variable name="this-attribute-value"
               select="
                  if (string-length(.) lt 1) then
                     concat($help-trigger, '#')
                  else
                     ."
            />
            <attribute name="{$this-attribute-name}">
               <xsl:for-each select="tokenize(normalize-space($this-attribute-value), ' ')">
                  <xsl:variable name="this-val-checked" select="tan:help-extracted(.)"/>
                  <xsl:variable name="this-val" select="$this-val-checked/text()"/>
                  <xsl:variable name="this-val-resolved" as="xs:string*"
                     select="
                        if ($this-val = '*') then
                           $all-possible-valid-entities/@xml:id
                        else
                           tan:resolve-idref($this-val, $aliases)"/>
                  <xsl:for-each select="$this-val-resolved">
                     <xsl:variable name="this-val" select="."/>
                     <xsl:variable name="this-val-esc" select="tan:escape(.)"/>
                     <xsl:variable name="entities-pointed-to"
                        select="$all-possible-valid-entities[(@xml:id, @id) = $this-val]"/>
                     <xsl:element name="{$this-attribute-name}">
                        <xsl:attribute name="attr"/>
                        <xsl:copy-of select="$this-val-checked/@help"/>
                        <xsl:if test="not(exists($entities-pointed-to))">
                           <xsl:variable name="this-message">
                              <xsl:value-of
                                 select="concat('@', $this-attribute-name, ' must point to valid values of ')"/>
                              <xsl:value-of
                                 select="
                                    string-join(for $i in $should-refer-to-which-element
                                    return
                                       concat('&lt;', $i, '>'), ', ')"/>
                              <xsl:value-of
                                 select="concat(': delete ', ., ' or change to: ', string-join($all-possible-valid-entities/@xml:id, ' '))"
                              />
                           </xsl:variable>
                           <xsl:variable name="new-element-fixes" as="element()*">
                              <xsl:for-each select="$should-refer-to-which-element">
                                 <xsl:element name="{.}">
                                    <xsl:attribute name="xml:id" select="$this-val"/>
                                 </xsl:element>
                              </xsl:for-each>
                           </xsl:variable>
                           <xsl:copy-of
                              select="tan:error('tan05', $this-message, $new-element-fixes, 'copy-element-after-last-of-type')"
                           />
                        </xsl:if>
                        <xsl:if
                           test="exists($this-val-checked/@help) or not(exists($entities-pointed-to))">
                           <xsl:variable name="this-fix" as="element()*">
                              <xsl:for-each select="$all-possible-valid-entities">
                                 <xsl:sort select="matches(@xml:id, $this-val-esc)" order="descending"/>
                                 <element>
                                    <xsl:attribute name="{$this-attribute-name}" select="@xml:id"/>
                                 </element>
                              </xsl:for-each>
                           </xsl:variable>
                           <xsl:variable name="this-message"
                              select="concat($this-val, ' unknown; try: ', string-join($this-fix/@*, '; '))"/>
                           <xsl:copy-of
                              select="tan:help($this-message, $this-fix, 'copy-attributes')"/>
                        </xsl:if>
                        <xsl:value-of select="."/>
                     </xsl:element>
                  </xsl:for-each>
               </xsl:for-each>
            </attribute>
         </xsl:for-each>
      </xsl:variable>

      <xsl:variable name="duplicate-refs" select="tan:duplicate-items($these-refs/*/text())"/>
      <xsl:variable name="dates"
         select="$this-from, $this-to, tan:dateTime-to-decimal((self::tan:*/@when, @ed-when, @when-accessed))"/>
      <!-- replacement variable below December 2017: resolution should have happened in the previous major step, that of resolution -->
      <xsl:variable name="this-href-resolved" select="@href"/>
      <!--<xsl:variable name="this-href-resolved"
         select="resolve-uri(@href, (root()/*/@base-uri, $doc-uri)[1])"/>-->
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($duplicate-refs)">
            <xsl:copy-of select="tan:error('tan06', $duplicate-refs)"/>
         </xsl:if>
         <xsl:if test="(@xml:id, @id) = $duplicate-ids">
            <xsl:copy-of
               select="tan:error('tan03', concat('ids used so far: ', string-join($all-ids, ', ')))"
            />
         </xsl:if>
         <xsl:if test="$dates = 0">
            <xsl:copy-of select="tan:error('whe01')"/>
         </xsl:if>
         <xsl:if test="
               some $i in $dates
                  satisfies $i > $now">
            <xsl:copy-of
               select="tan:error('whe02', concat('Currently ', string(current-dateTime())))"/>
         </xsl:if>
         <xsl:if test="exists(@from) and exists(@to) and ($this-from gt $this-to)">
            <xsl:copy-of select="tan:error('whe03')"/>
         </xsl:if>
         <xsl:if
            test="(@pattern, @matches-m, @matches-tok, @rgx)[matches(., '\\[^nrtpPsSiIcCdDuwW\\|.?*+(){}#x2D#x5B#x5D#x5E\]\[\^\-]')]">
            <xsl:copy-of select="tan:error('tan07')"/>
         </xsl:if>
         <xsl:if test="exists(self::tan:master-location) and matches(@href, '!/')">
            <xsl:copy-of select="tan:error('tan15')"/>
         </xsl:if>
         <xsl:if test="$this-href-resolved = $doc-uri">
            <xsl:copy-of select="tan:error('tan17')"/>
         </xsl:if>
         <xsl:if test="exists(@href) and not((self::tan:location, self::tan:master-location))">
            <xsl:choose>
               <xsl:when test="doc-available($this-href-resolved)">
                  <xsl:variable name="target-doc" select="doc($this-href-resolved)"/>
                  <xsl:variable name="target-IRI" select="$target-doc/*/@id"/>
                  <xsl:variable name="target-name" select="$target-doc/*/tan:head/tan:name"/>
                  <xsl:variable name="target-desc" select="$target-doc/*/tan:head/tan:desc"/>
                  <xsl:variable name="this-message">
                     <xsl:text>Target file has the following IRI + name pattern: </xsl:text>
                     <xsl:value-of select="$target-IRI"/>
                     <xsl:value-of select="concat(' (', $target-name[1], ')')"/>
                  </xsl:variable>
                  <xsl:variable name="this-fix" as="element()">
                     <xsl:copy>
                        <xsl:copy-of select="@* except (@href, @orig-href, @q)"/>
                        <IRI>
                           <xsl:value-of select="$target-IRI"/>
                        </IRI>
                        <xsl:copy-of select="$target-name"/>
                        <xsl:copy-of select="$target-desc"/>
                        <location when-accessed="{current-dateTime()}"
                           href="{tan:uri-relative-to(@href, $doc-uri)}"/>
                     </xsl:copy>
                  </xsl:variable>
                  <xsl:copy-of select="tan:error('tan08', $this-message, $this-fix, 'replace-self')"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="tan:error('tan08')"/>
                  <xsl:copy-of select="tan:error('wrn01')"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
         <xsl:copy-of select="$these-refs/*"/>
         <xsl:variable name="try-to-expand-ranges" select="exists(parent::tan:alter)"/>
         <xsl:for-each select="(@ref, @pos, @chars, @n[not(parent::*:div)], @new)">
            <!-- analysis of hierarchically complex sequences; we exclude div/@n because that's handled separately, because a <alter> might make changes -->
            <xsl:variable name="this-name" select="name(.)"/>
            <!--<xsl:variable name="this-val-normalized" select="tan:normalize-sequence(., $this-name)"/>-->
            <xsl:variable name="this-val-analyzed"
               select="tan:analyze-sequence(., $this-name, $try-to-expand-ranges)"/>
            <xsl:copy-of select="$this-val-analyzed/*"/>
         </xsl:for-each>
         <xsl:for-each select="(@div-type, @affects-element, @object)">
            <!-- Here we distribute remaining attributes that take multiple, space-delimited values. -->
            <xsl:variable name="this-attr-name" select="name(.)"/>
            <xsl:variable name="this-name" select="name(.)"/>
            <xsl:variable name="this-val-normalized" select="normalize-space(.)"/>
            <xsl:variable name="this-val-analyzed"
               select="tan:analyze-sequence($this-val-normalized, $this-name, false())"/>
            <xsl:copy-of select="$this-val-analyzed/*"/>
         </xsl:for-each>
         <xsl:if test="exists(@in-progress)">
            <xsl:if
               test="@in-progress = false() and not(exists(root(.)/*/tan:head/tan:master-location))">
               <xsl:variable name="this-fix">
                  <master-location href="{$doc-uri}"/>
               </xsl:variable>
               <xsl:copy-of select="tan:error('tan02', '', $this-fix, 'add-master-location')"/>
            </xsl:if>
         </xsl:if>
         <xsl:for-each select="@val, @rgx">
            <xsl:variable name="this-name" select="name(.)"/>
            <xsl:element name="{$this-name}" namespace="tag:textalign.net,2015:ns">
               <xsl:value-of select="tan:help-extracted(.)"/>
            </xsl:element>
         </xsl:for-each>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="/*" mode="core-expansion-terse" priority="-2">
      <xsl:variable name="this-last-change-agent" select="tan:last-change-agent(root())"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($this-last-change-agent/self::tan:algorithm)">
            <xsl:copy-of select="tan:error('wrn07','The last change was made by an algorithm.')"/>
         </xsl:if>
         <expansion>terse</expansion>
         <xsl:if test="@TAN-version = $previous-TAN-versions">
            <xsl:variable name="prev-version-uri" select="'../../do%20things/convert/convert%20TAN%202017%20to%20TAN%202018.xsl'"/>
            <xsl:copy-of
               select="tan:error('tan20', concat('To convert this file to the current version, try ', resolve-uri($prev-version-uri, static-base-uri())))"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="this-tan-type" select="name(.)" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="collection" mode="catalog-expansion-terse">
      <xsl:variable name="duplicate-ids" select="tan:duplicate-items(doc/@id)"/>
      <xsl:variable name="duplicate-hrefs" select="tan:duplicate-items(doc/@href)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-ids" select="$duplicate-ids"/>
            <xsl:with-param name="duplicate-hrefs" select="$duplicate-hrefs"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="doc" mode="catalog-expansion-terse">
      <xsl:param name="duplicate-ids"/>
      <xsl:param name="duplicate-hrefs"/>
      <!-- this template is for catalog.tan.xml files; we assume that @href is absolute since the document has already been resolved -->
      <xsl:variable name="this-doc-available" select="doc-available(@href)"/>
      <xsl:variable name="this-doc"
         select="
            if ($this-doc-available) then
               doc(@href)
            else
               ()"/>
      <xsl:variable name="this-doc-root-element-name" select="name($this-doc/*)"/>
      <xsl:variable name="this-doc-id" select="$this-doc/*/@id"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="@id = $duplicate-ids">
            <xsl:copy-of select="tan:error('cat04','file may incorrectly duplicate the @id of another')"/>
         </xsl:if>
         <xsl:if test="@href = $duplicate-hrefs">
            <xsl:copy-of select="tan:error('cat05')"/>
         </xsl:if>
         <xsl:choose>
            <xsl:when test="$this-doc-available">
               <xsl:if test="not($this-doc-root-element-name = @root)">
                  <xsl:variable name="this-fix" as="element()">
                     <fix root="{$this-doc-root-element-name}"/>
                  </xsl:variable>
                  <xsl:copy-of
                     select="tan:error('cat02', concat('Target root element name ', $this-doc-root-element-name), $this-fix, 'copy-attributes')"
                  />
               </xsl:if>
               <xsl:if test="not($this-doc-id = @id)">
                  <xsl:variable name="this-fix" as="element()">
                     <fix id="{$this-doc-id}"/>
                  </xsl:variable>
                  <xsl:copy-of
                     select="tan:error('cat03', concat('Target @id ', $this-doc-id), $this-fix, 'copy-attributes')"
                  />
               </xsl:if>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="tan:error('cat01', (), (), 'delete-self')"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>


   <!-- CORE EXPANSION NORMAL -->

   <xsl:template match="/*" mode="core-expansion-normal dependency-expansion-normal">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <expansion>normal</expansion>
         <xsl:copy-of select="tan:error('wrn06')"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:master-location" mode="core-expansion-normal">
      <xsl:variable name="this-master-doc" select="tan:get-1st-doc(.)" as="document-node()?"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:choose>
            <xsl:when test="exists($this-master-doc/(tan:error, tan:warning))">
               <xsl:copy-of select="$this-master-doc/*"/>
            </xsl:when>
            <xsl:when test="not(deep-equal($orig-self/*, $this-master-doc/*))">
               <xsl:variable name="target-hist" select="tan:get-doc-hist($this-master-doc)"/>
               <xsl:variable name="target-changes"
                  select="tan:xml-to-string(tan:copy-of-except($target-hist/*[position() lt 4], (), 'when-sort', ()))"/>
               <xsl:copy-of
                  select="tan:error('tan18', concat('Master document differs from this one; last three edits: ', $target-changes))"
               />
            </xsl:when>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:see-also | tan:model | tan:redivision | tan:successor | tan:predecessor"
      mode="core-expansion-normal">
      <xsl:apply-templates select="." mode="check-referred-doc"/>
   </xsl:template>

   <xsl:template match="tan:inclusion | tan:key" mode="core-expansion-terse">
      <xsl:apply-templates select="." mode="check-referred-doc"/>
   </xsl:template>
   <xsl:template match="tan:see-also" mode="core-expansion-terse">
      <!-- In terse mode, we do only basic checks on <see also>. The deep checks we do for inclusions and keys are reserved for the normal mode. -->
      <xsl:variable name="these-iris" select="tan:IRI"/>
      <xsl:variable name="this-see-also-doc" select="$see-alsos-resolved[*/@id = $these-iris]"/>
      <xsl:variable name="target-1st-da" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="target-doc"
         select="
            if (exists($this-see-also-doc)) then
               $this-see-also-doc
            else
               tan:resolve-doc($target-1st-da)"/>
      <xsl:variable name="this-relationship" select="tan:definition(tan:relationship)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$this-relationship/tan:name = ('alternatively divided edition', 'model')">
            <xsl:if
               test="not(/*/tan:head/tan:definitions/tan:work/tan:IRI = $target-doc/*/tan:head/tan:definitions/tan:work/tan:IRI)">
               <xsl:copy-of select="tan:error('cl102')"/>
            </xsl:if>
         </xsl:if>
         <xsl:if test="$this-relationship/tan:name = 'alternatively divided edition'">
            <xsl:if
               test="not(/*/tan:head/tan:source/tan:IRI = $target-doc/*/tan:head/tan:source/tan:IRI)">
               <xsl:copy-of select="tan:error('cl101')"/>
            </xsl:if>

            <xsl:if
               test="
                  exists(/tan:TAN-T/tan:head/tan:definitions/tan:version) and
                  exists($target-doc/*/tan:head/tan:definitions/tan:version) and
                  not(/*/tan:head/tan:definitions/tan:version/tan:IRI = $target-doc/*/tan:head/tan:definitions/tan:version/tan:IRI)">
               <xsl:copy-of select="tan:error('cl103')"/>
            </xsl:if>
         </xsl:if>
         <xsl:if test="$this-relationship/tan:name = 'model'">
            <xsl:variable name="other-models"
               select="(preceding-sibling::tan:see-also, following-sibling::tan:see-also)[tan:definition(tan:relationship)/tan:name = 'model']"/>
            <xsl:if test="exists($other-models)">
               <xsl:copy-of select="tan:error('cl106')"/>
            </xsl:if>
         </xsl:if>
         
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:IRI[not(parent::tan:item)]" mode="core-expansion-terse">
      <xsl:variable name="names-a-TAN-file" select="tan:must-refer-to-external-tan-file(.)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test=". = $duplicate-head-iris and not(parent::tan:relationship)">
            <xsl:copy-of select="tan:error('tan09', .)"/>
         </xsl:if>
         <xsl:if test="matches(.,'^urn:')">
            <xsl:variable name="this-urn-namespace" select="replace(., '^urn:([^:]+):.+', '$1')"/>
            <xsl:if test="not($this-urn-namespace = $official-urn-namespaces)">
               <xsl:copy-of select="tan:error('tan19', concat($this-urn-namespace,' is not in the official registry of URN namespaces '))"/>
            </xsl:if>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:definitions" mode="core-expansion-terse">
      <xsl:param name="extra-definitions" tunnel="yes"/>
      <xsl:variable name="token-definition-source-duplicates"
         select="tan:duplicate-items(tan:token-definition/tan:src)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(exists($primary-agent))">
            <xsl:copy-of
               select="tan:error('tan01', concat('Need a person, organization, or algorithm with an IRI that begins tag:', $doc-namespace))"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="token-definition-errors"
               select="$token-definition-source-duplicates"/>
         </xsl:apply-templates>
         <xsl:copy-of select="$extra-definitions"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:token-definition" mode="core-expansion-terse">
      <xsl:param name="token-definition-errors"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$token-definition-errors = tan:src">
            <xsl:copy-of select="tan:error('cl202')"/>
         </xsl:if>
         <xsl:if test="not(exists(@src))">
            <xsl:for-each select="../../tan:source">
               <src>
                  <xsl:value-of select="(@xml:id, 1)[1]"/>
               </src>
            </xsl:for-each>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:item/tan:name" mode="expand-tan-key-dependencies core-expansion-terse">
      <xsl:param name="reserved-keyword-items" as="element()*"/>
      <xsl:param name="is-reserved" as="xs:boolean?" tunnel="yes"/>
      <xsl:param name="inherited-affects-elements" tunnel="yes"/>
      <xsl:variable name="this-name" select="text()"/>
      <xsl:variable name="this-name-common" select="tan:normalize-text($this-name, true())"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="($reserved-keyword-items/tan:name = ($this-name, $this-name-common)) and ($is-reserved = false())">
            <xsl:copy-of select="tan:error('tky01')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
      <!-- make a clone version of the name immediately after, to check lowercase values -->
      <xsl:if test="not($this-name = $this-name-common)">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!-- we add @common, to distinguish it from the master, for error checking -->
            <xsl:attribute name="common"/>
            <xsl:value-of select="$this-name-common"/>
         </xsl:copy>
      </xsl:if>
   </xsl:template>

   <xsl:template match="text()[matches(., '\S')]" mode="core-expansion-normal">
      <xsl:variable name="this-text" select="."/>
      <xsl:variable name="this-text-normalized" select="normalize-unicode(.)"/>
      <xsl:if test="$this-text != $this-text-normalized">
         <xsl:copy-of
            select="tan:error('tan04', concat('Should be: ', $this-text-normalized), $this-text-normalized, 'replace-text')"
         />
      </xsl:if>
      <xsl:if test="matches(., '^\p{M}')">
         <xsl:copy-of select="tan:error('cl111', (), replace(., '^\p{M}+', ''), 'replace-text')"/>
      </xsl:if>
      <xsl:if test="matches(., '\s\p{M}')">
         <xsl:copy-of
            select="tan:error('cl112', (), replace(., '\s+(\p{M})', '$1'), 'replace-text')"/>
      </xsl:if>
      <xsl:if test="matches(., $regex-characters-not-permitted)">
         <xsl:copy-of
            select="tan:error('cl113', (), replace(., $regex-characters-not-permitted, ''), 'replace-text')"
         />
      </xsl:if>
      <xsl:value-of select="tan:normalize-text(.)"/>
   </xsl:template>

   <!-- CORE EXPANSION VERBOSE -->

   <xsl:template match="/*" mode="core-expansion-verbose">
      <xsl:variable name="this-local-catalog" as="document-node()?" select="tan:catalogs(., true())[1]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <expansion>verbose</expansion>
         <xsl:choose>
            <xsl:when test="exists($this-local-catalog)">
               <xsl:variable name="this-local-catalog-resolved"
                  select="tan:resolve-doc($this-local-catalog)"/>
               <xsl:variable name="this-local-catalog-expanded"
                  select="tan:expand-doc($this-local-catalog-resolved)"/>
               <xsl:variable name="this-local-catalog-errors"
                  select="$this-local-catalog-expanded//(tan:error, tan:warning)"/>
               <xsl:variable name="this-local-collection"
                  select="
                     for $i in $this-local-catalog
                     return
                        collection($i)"
               />
               <xsl:if test="not(@id = $this-local-catalog/collection/doc/@id)">
                  <xsl:copy-of select="tan:error('cat06')"/>
               </xsl:if>
               <xsl:if test="exists($this-local-catalog-errors)">
                  <xsl:copy-of select="tan:error('cat07')"/>
                  <xsl:copy-of select="$this-local-catalog-errors"/>
               </xsl:if>
               <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
