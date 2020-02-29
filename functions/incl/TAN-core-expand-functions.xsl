<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:function name="tan:expand-doc" as="document-node()*">
      <!-- one-parameter version of the fuller one below -->
      <xsl:param name="tan-doc-and-dependencies" as="document-node()*"/>
      <xsl:copy-of select="tan:expand-doc($tan-doc-and-dependencies, $validation-phase)"/>
   </xsl:function>

   <xsl:function name="tan:expand-doc" as="document-node()*">
      <!-- Input: a tan document + dependencies, a string indicating a phase of expansion -->
      <!-- Output: the document and its dependencies expanded at the phase indicated -->
      <!-- Because class 2 files are expanded hand-in-glove with the class 1 files they depend upon, expansion is necessarily synchronized. The original class-2 document is the first document of the result, and the expanded class-1 files follow. -->
      <xsl:param name="tan-doc-and-dependencies" as="document-node()*"/>
      <xsl:param name="target-phase" as="xs:string"/>
      <xsl:variable name="tan-doc" select="$tan-doc-and-dependencies[1]"/>
      <xsl:variable name="dependencies" select="$tan-doc-and-dependencies[position() gt 1]"/>
      <xsl:variable name="this-id" select="$tan-doc/*/@id"/>
      <xsl:variable name="this-class-number" select="tan:class-number($tan-doc)"/>
      <xsl:variable name="this-tan-type" select="tan:tan-type($tan-doc)"/>
      <xsl:variable name="this-is-tan-a" select="$this-tan-type = 'TAN-A'"/>
      <xsl:variable name="this-is-tan-a-lm" select="$this-tan-type = 'TAN-A-lm'"/>
      <xsl:variable name="expansion-so-far" select="$tan-doc/*/tan:expanded"/>
      <xsl:variable name="diagnostics-on" as="xs:boolean" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for tan:expand-doc()'"/>
         <xsl:message select="'expanding to', $target-phase, 'phase on doc id ', string($this-id)"/>
      </xsl:if>
      <xsl:choose>
         <!-- Don't try to do anything if the input document itself is empty -->
         <xsl:when test="not(exists($tan-doc-and-dependencies/*))"/>
         <!-- If the document is already expanded, no further action is needed -->
         <xsl:when test="$target-phase = $expansion-so-far">
            <xsl:sequence select="$tan-doc-and-dependencies"/>
         </xsl:when>
         <!-- If the document is a collection, it gets treated specially (phases don't matter). -->
         <xsl:when test="name($tan-doc/*) = 'collection'">
            <xsl:apply-templates select="$tan-doc" mode="catalog-expansion-terse"/>
         </xsl:when>

         <!-- terse expansion -->
         <xsl:when test="$target-phase = 'terse'">
            <!-- Terse expansion needs at least two passes: one to expand overloaded attributes, and then general element expansions. -->

            <!-- We insert pre-pass template that has no effect within validation, so that users downstream can cut out parts of the file of no interest -->
            <xsl:variable name="core-expansion-ad-hoc-pre-pass" as="document-node()?">
               <xsl:apply-templates select="$tan-doc" mode="core-expansion-ad-hoc-pre-pass"/>
            </xsl:variable>

            <!-- Some overloaded attributes in class 2 files, i.e., @ref, @n, and @new, should be expanded only in the context of a host source file  -->
            <xsl:variable name="core-expansion-pass-1" as="document-node()?">
               <xsl:apply-templates select="$core-expansion-ad-hoc-pre-pass"
                  mode="core-expansion-terse-attributes"/>
            </xsl:variable>

            <xsl:variable name="these-dependencies-resolved" as="document-node()*">
               <!-- Get all files upon which the host file depends, namely <source>s and <morphology>s -->
               <xsl:choose>
                  <!-- Only class 2 files have dependencies; if they have already been fed in, keep 'em -->
                  <xsl:when test="(count($dependencies) gt 0) or ($this-class-number = (1, 3))">
                     <xsl:sequence select="$dependencies"/>
                  </xsl:when>
                  <!-- Class 2 files absolutely must come with the source class 1 files upon which they depend. This variable ensures we have them. -->
                  <xsl:when test="$doc-id = $this-id">
                     <xsl:sequence select="$sources-resolved, $morphologies-resolved"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:copy-of
                        select="tan:get-and-resolve-dependency($core-expansion-pass-1/(tan:TAN-A, tan:TAN-A-lm, tan:TAN-A-tok)/tan:head/tan:source)"/>
                     <xsl:copy-of
                        select="tan:get-and-resolve-dependency($core-expansion-pass-1/tan:TAN-A-lm/tan:head/tan:vocabulary-key/tan:morphology)"
                     />
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>

            <xsl:variable name="core-expansion-pass-2" as="document-node()?">
               <xsl:apply-templates select="$core-expansion-pass-1" mode="core-expansion-terse">
                  <xsl:with-param name="dependencies" select="$these-dependencies-resolved"
                     tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'Core expansion pass 1:', $core-expansion-pass-1"/>
               <xsl:message select="'Dependencies resolved: ', $these-dependencies-resolved"/>
               <xsl:message select="'Core expansion pass 2:', $core-expansion-pass-2"/>
            </xsl:if>

            <xsl:choose>
               <!-- terse expansion class 2 -->
               <xsl:when test="$this-class-number = 2">
                  <!-- If a class 2 file, first make all adjustments to the class-1 sources requested by the class 2 file, resetting the 
                     hierarchy if required. Then for every textual reference in the class-2 file, place a marker in the relevant
                     class-1 sources. At that point the class-2 file can be evaluated, by looking for markers in the class-1 sources,
                     with errors returned for missing markers, or too many of them.
                  -->

                  <!--<xsl:variable name="class-2-expansion-pass-1" as="document-node()?">
                     <xsl:choose>
                        <xsl:when test="$this-is-tan-a">
                           <xsl:apply-templates select="$core-expansion-pass-2" mode="expand-work"/>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$core-expansion-pass-2"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>-->

                  <!-- All textual references must begin with @ref (expanded to <ref> in an earlier pass) -->
                  <xsl:variable name="these-ref-parents"
                     select="$core-expansion-pass-2/*/tan:body//*[tan:ref]"/>
                  <xsl:variable name="adjustments-part-1"
                     select="$core-expansion-pass-2/*/tan:head/tan:adjustments/(tan:skip, tan:rename, tan:equate)"/>

                  <!-- The first pass of source expansion processes the first three steps of the <adjustments>: <skip>, <rename>, <equate> -->
                  <!-- We almost always go through this first pass even if there are no adjustments, because it also sets up <n> and <ref> elements in dependency <div>s that are essential for later references -->
                  <!-- This process involves leaving a marker for each adjustment element's locator, to facilitate validation -->
                  <xsl:variable name="dependencies-adjusted-pass-1a" as="document-node()*">
                     <xsl:choose>
                        <xsl:when
                           test="not($is-validation) or exists($adjustments-part-1) or exists($these-ref-parents) or $this-is-tan-a-lm">
                           <xsl:apply-templates select="$these-dependencies-resolved"
                              mode="dependency-adjustments-pass-1">
                              <xsl:with-param name="class-2-doc" select="$core-expansion-pass-2"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$these-dependencies-resolved"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>

                  <xsl:variable name="adjustment-pass-1a-dependency-divs-to-reset"
                     select="
                        for $i in $dependencies-adjusted-pass-1a
                        return
                           key('divs-to-reset', '', $i)"/>

                  <!-- If the first adjustments created actions that threw the hierarchy of sources out of whack, then reset the hierarchy before proceeding -->
                  <xsl:variable name="dependencies-adjusted-pass-1b" as="document-node()*">
                     <xsl:apply-templates select="$dependencies-adjusted-pass-1a"
                        mode="reset-hierarchy">
                        <xsl:with-param name="divs-to-reset"
                           select="$adjustment-pass-1a-dependency-divs-to-reset" tunnel="yes"/>
                        <xsl:with-param name="process-entire-document" select="true()" tunnel="yes"
                        />
                     </xsl:apply-templates>
                     <!--<xsl:choose>
                        <xsl:when test="exists($adjustment-pass-1a-dependency-divs-to-reset)">
                           <xsl:apply-templates select="$dependencies-adjusted-pass-1a"
                              mode="reset-hierarchy">
                              <xsl:with-param name="divs-to-reset"
                                 select="$adjustment-pass-1a-dependency-divs-to-reset" tunnel="yes"
                              />
                           </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$dependencies-adjusted-pass-1a"/>
                        </xsl:otherwise>
                     </xsl:choose>-->
                  </xsl:variable>

                  <!-- Now perform second round of adjustments, <reassign> -->

                  <xsl:variable name="adjustments-part-2"
                     select="$core-expansion-pass-2/*/tan:head/tan:adjustments/tan:reassign"/>

                  <xsl:variable name="dependencies-adjusted-pass-2a" as="document-node()*">
                     <xsl:choose>
                        <xsl:when test="exists($adjustments-part-2)">
                           <xsl:apply-templates select="$dependencies-adjusted-pass-1b"
                              mode="dependency-adjustments-pass-2">
                              <xsl:with-param name="class-2-doc" select="$core-expansion-pass-2"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$dependencies-adjusted-pass-1b"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>

                  <!-- If the first adjustments created actions that threw the hierarchy of sources out of whack, then reset the hierarchy before proceeding -->
                  <xsl:variable name="dependencies-adjusted-pass-2b" as="document-node()*">
                     <xsl:choose>
                        <xsl:when test="exists($adjustments-part-2)">
                           <xsl:apply-templates select="$dependencies-adjusted-pass-2a"
                              mode="reset-hierarchy">
                              <xsl:with-param name="divs-to-reset"
                                 select="
                                    for $i in $dependencies-adjusted-pass-2a
                                    return
                                       key('divs-to-reset', '', $i)"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$dependencies-adjusted-pass-2a"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>

                  <!-- Now, in dependencies, place markers corresponding to the text references made in the class-2 body. 
                     Markers are of three sorts: <div> references (derived from @ref); token references (derived from
                     @val/@rgx + @pos); character references (derived from @chars)
                  -->
                  <!-- On the first pass, set all <div>-based markers (@ref), and tokenize any leaf <div>s that are subject to token references -->
                  <xsl:variable name="special-elements-that-require-universal-tokenization" select="$core-expansion-pass-2/tan:TAN-A-lm/tan:body//tan:tok[not(@ref)]"/>
                  <xsl:variable name="dependencies-marked-pass-1" as="document-node()*">
                     <xsl:choose>
                        <xsl:when test="exists($these-ref-parents) or exists($special-elements-that-require-universal-tokenization)">
                           <xsl:apply-templates select="$dependencies-adjusted-pass-2b"
                              mode="mark-dependencies-pass-1">
                              <xsl:with-param name="class-2-doc" select="$core-expansion-pass-2"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$dependencies-adjusted-pass-2b"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>

                  <!-- On the second pass, set all token- and character-based markers; all tokenization should have happened in the previous step -->
                  <xsl:variable name="these-tok-parents"
                     select="$these-ref-parents[descendant::tan:pos]"/>
                  <xsl:variable name="dependencies-marked-pass-2" as="document-node()*">
                     <xsl:choose>
                        <xsl:when test="exists($these-tok-parents) or exists($special-elements-that-require-universal-tokenization)">
                           <xsl:apply-templates select="$dependencies-marked-pass-1"
                              mode="mark-dependencies-pass-2">
                              <xsl:with-param name="class-2-doc" select="$core-expansion-pass-2"
                                 tunnel="yes"/>
                           </xsl:apply-templates>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$dependencies-marked-pass-1"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>

                  <xsl:variable name="dependencies-stripped-to-markers" as="document-node()*">
                     <xsl:choose>
                        <xsl:when
                           test="exists($adjustments-part-1) or exists($adjustments-part-2) or exists($these-ref-parents) or exists($special-elements-that-require-universal-tokenization)">
                           <xsl:apply-templates select="$dependencies-marked-pass-2"
                              mode="strip-dependencies-to-markers"/>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$dependencies-marked-pass-2"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>

                  <!-- Now check the dependent class 2 document to see if there were any errors -->
                  <xsl:variable name="class-2-expansion-pass-1" as="document-node()?">
                     <xsl:apply-templates select="$core-expansion-pass-2"
                        mode="class-2-expansion-terse">
                        <xsl:with-param name="dependencies-adjusted-and-marked"
                           select="$dependencies-stripped-to-markers" tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:variable>

                  <xsl:if test="$diagnostics-on">
                     <xsl:variable name="diagnostics-on-for-main-class-2-file" as="xs:boolean"
                        select="false()"/>
                     <xsl:variable name="diagnostics-on-for-what-dependency-numbers"
                        as="xs:integer*" select="(1)"/>
                     <xsl:if test="$diagnostics-on-for-main-class-2-file">
                        <xsl:message select="'orig doc: ', $tan-doc"/>
                        <xsl:message
                           select="'main class 2 file, core expansion pass 1: ', $core-expansion-pass-1"/>
                        <xsl:message
                           select="'main class 2 file, core expansion pass 2: ', $core-expansion-pass-2"/>
                        <xsl:message select="'these ref parents: ', $these-ref-parents"/>
                        <xsl:message select="'these adjustments part 1: ', $adjustments-part-1"/>
                        <xsl:message select="'these adjustments part 2: ', $adjustments-part-2"/>
                        <xsl:message
                           select="'main class 2 file, expansion pass 2: ', $class-2-expansion-pass-1"
                        />
                     </xsl:if>
                     <xsl:if test="exists($diagnostics-on-for-what-dependency-numbers)">
                        <xsl:message
                           select="'dependencies resolved: ', $these-dependencies-resolved[position() = $diagnostics-on-for-what-dependency-numbers]"/>
                        <xsl:message
                           select="'dependencies adjusted pass 1a: ', $dependencies-adjusted-pass-1a[position() = $diagnostics-on-for-what-dependency-numbers]"/>
                        <xsl:message
                           select="'dependencies adjusted pass 1b: ', $dependencies-adjusted-pass-1b[position() = $diagnostics-on-for-what-dependency-numbers]"/>
                        <xsl:message
                           select="'dependencies adjusted pass 2a: ', $dependencies-adjusted-pass-2a[position() = $diagnostics-on-for-what-dependency-numbers]"/>
                        <xsl:message
                           select="'dependencies adjusted pass 2b: ', $dependencies-adjusted-pass-2a[position() = $diagnostics-on-for-what-dependency-numbers]"/>
                        <xsl:message
                           select="'dependencies marked pass 1: ', $dependencies-marked-pass-1[position() = $diagnostics-on-for-what-dependency-numbers]"/>
                        <xsl:message
                           select="'dependencies marked pass 2: ', $dependencies-marked-pass-2[position() = $diagnostics-on-for-what-dependency-numbers]"
                        />
                     </xsl:if>
                  </xsl:if>
                  <xsl:choose>
                     <xsl:when test="$this-is-tan-a-lm">
                        <xsl:apply-templates select="$class-2-expansion-pass-1"
                           mode="tan-a-lm-expansion-terse">
                           <xsl:with-param name="dependencies" as="document-node()*"
                              select="$dependencies-marked-pass-2" tunnel="yes"/>
                        </xsl:apply-templates>
                        <xsl:copy-of select="$dependencies-marked-pass-2"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <!--<xsl:copy-of select="$core-expansion-pass-2, $dependencies-adjusted-pass-2b"/>-->
                        <xsl:copy-of select="$class-2-expansion-pass-1, $dependencies-marked-pass-2"
                        />
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:when>
               <xsl:otherwise>
                  <!-- classes 1, 3 diagnostics, results -->
                  <xsl:copy-of select="$core-expansion-pass-2, $dependencies"/>
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
                     <xsl:when test="$this-class-number = 2">
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
                                       $core-expansion/*/tan:head/tan:token-definition
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
                     <xsl:when test="$this-class-number = 1">
                        <!-- In the first pass, get the normalized text of each redivision, and the div structure of each model -->
                        <xsl:variable name="class-1-expansion-pass-1" as="document-node()">
                           <xsl:apply-templates select="$core-expansion"
                              mode="class-1-expansion-verbose-pass-1"/>
                        </xsl:variable>
                        <xsl:variable name="class-1-expansion-pass-2" as="document-node()">
                           <xsl:apply-templates select="$class-1-expansion-pass-1"
                              mode="class-1-expansion-verbose-pass-2"/>
                        </xsl:variable>
                        <xsl:variable name="class-1-expansion-pass-3" as="document-node()">
                           <xsl:apply-templates select="$class-1-expansion-pass-2"
                              mode="class-1-expansion-verbose-pass-3"/>
                        </xsl:variable>
                        <!--<xsl:copy-of select="$class-1-expansion-pass-1"/>-->
                        <!--<xsl:copy-of select="$class-1-expansion-pass-2"/>-->
                        <xsl:copy-of select="$class-1-expansion-pass-3"/>
                     </xsl:when>
                     <xsl:when test="$this-class-number = 2">
                        <!-- Commented out sections below anticipate areas of development; it also points to a very useful application of TAN functions, namely, to create a merger of an number of class 1 documents -->
                        <!-- Those mergers are quite time consuming for TAN-A files with numerous or large source files -->
                        <!-- We assume from the previous expansion that all source <div>s are in proper hierarchical order -->
                        <!--<xsl:variable name="sources-merged" as="document-node()*">
                           <xsl:if test="tan:tan-type($tan-doc) = 'TAN-A'">
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
                                 select="$core-expansion/*/tan:head/tan:token-definition[1]"
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

   <xsl:template match="tan:inclusion/* | tan:vocabulary/tan:item" priority="1" mode="check-referred-doc">
      <!-- ignore anything deeper than inclusion -->
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:algorithm | tan:TAN-T/tan:head/tan:source | tei:TEI/tan:head/tan:source"
      mode="check-referred-doc">
      <!-- This component of the template mode is to check elements that point to non-TAN files -->
      <xsl:variable name="target-1st-da" select="tan:get-1st-doc(.)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$target-1st-da/(tan:error, tan:warning, tan:fatal, tan:help)"/>
         <xsl:if test="(namespace-uri($target-1st-da/*) = $TAN-namespace) and not(exists($target-1st-da/(tan:error, tan:warning, tan:fatal)))">
            <xsl:copy-of select="tan:error('cl114')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template
      match="
         tan:inclusion | tan:vocabulary | tan:TAN-A/tan:head/tan:source | tan:TAN-A-lm/tan:head/tan:source | tan:TAN-A-tok/tan:head/tan:source
         | tan:see-also | tan:morphology | tan:redivision | tan:model | tan:successor | tan:predecessor | tan:annotation"
      mode="check-referred-doc">
      <!-- Look for errors in a TAN document referred to; should not be applied to non-TAN files -->
      <xsl:variable name="this-name" select="name(.)"/>
      <!--<xsl:variable name="must-point-to-tan-file" select="not($this-name = ('source', 'see-also'))"/>
      <xsl:variable name="most-point-to-same-file-type" select="$this-name = ('successor', 'predecessor', 'model', 'redivision')"/>-->
      <xsl:variable name="this-doc-id" select="root(.)/*/@id"/>
      <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
      <xsl:variable name="this-pos" select="count(preceding-sibling::*[name(.) = $this-name]) + 1"/>
      <xsl:variable name="this-class" select="tan:class-number(.)"/>
      <xsl:variable name="this-tan-type" select="tan:tan-type(.)"/>
      <xsl:variable name="this-relationship-idrefs" select="tan:relationship"/>
      <xsl:variable name="this-relationship-IRIs"
         select="../tan:vocabulary-key/tan:relationship[@xml:id = $this-relationship-idrefs]/tan:IRI"/>
      <xsl:variable name="this-TAN-reserved-relationships"
         select="
            if (exists($this-relationship-IRIs)) then
               $TAN-vocabularies/tan:TAN-voc/tan:body//tan:item[tan:IRI = $this-relationship-IRIs]
            else
               ()"/>
      <xsl:variable name="this-voc-expansion" select="tan:element-vocabulary(.)/tan:item"/>
      <xsl:variable name="this-element-expanded"
         select="(.[exists(tan:location)], $this-voc-expansion, $empty-element)[1]"/>
      <xsl:variable name="target-1st-da" select="tan:get-1st-doc($this-element-expanded)"/>
      <xsl:variable name="target-version" select="$target-1st-da/*/@TAN-version"/>
      <xsl:variable name="target-resolved" as="document-node()?">
         <xsl:choose>
            <!-- Oct 2019: I think we can delete this, thanks to revision in resolve-doc() -->
            <!--<xsl:when
               test="($this-name = ('inclusion', 'vocabulary')) and exists($target-version) and not($target-version = $TAN-version)">
               <xsl:document>
                  <xsl:copy-of select="tan:error('inc06')"/>
               </xsl:document>
            </xsl:when>-->
            <xsl:when test="self::tan:inclusion and $this-doc-id = $doc-id">
               <xsl:copy-of select="$inclusions-resolved[position() = $this-pos]"/>
            </xsl:when>
            <xsl:when test="self::tan:vocabulary and $this-doc-id = $doc-id">
               <xsl:copy-of select="$vocabularies-resolved[position() = $this-pos]"/>
            </xsl:when>
            <xsl:when test="self::tan:source and $this-doc-id = $doc-id">
               <xsl:copy-of select="$sources-resolved[position() = $this-pos]"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of select="tan:resolve-doc($target-1st-da, false(), ())"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="target-class" select="tan:class-number($target-resolved)"/>
      <xsl:variable name="target-tan-type" select="name($target-resolved/*)"/>
      <xsl:variable name="target-is-faulty"
         select="
            deep-equal($target-resolved, $empty-doc)
            or $target-resolved/(tan:error, tan:warning, tan:fatal, tan:help)"/>
      <xsl:variable name="target-is-self-referential"
         select="$target-resolved/tan:error/@xml:id = 'tan16'"/>
      <xsl:variable name="target-is-wrong-version"
         select="$target-resolved/tan:error/@xml:id = 'inc06'"/>
      <xsl:variable name="target-to-do-list" select="$target-resolved/*/tan:head/tan:to-do"/>
      <!--<xsl:variable name="target-new-versions"
         select="$target-1st-da-resolved/*/tan:head/tan:see-also[tan:vocabulary-key-item(tan:relationship) = 'new version']"/>-->
      <xsl:variable name="target-new-versions" select="$target-resolved/*/tan:head/tan:successor"/>
      <xsl:variable name="target-hist" select="tan:get-doc-history($target-resolved)"/>
      <xsl:variable name="target-id" select="$target-resolved/*/@id"/>
      <xsl:variable name="target-last-change-agent" select="tan:last-change-agent($target-resolved)"/>
      <!-- We change TEI to TAN-T, just so that TEI and TAN-T files can be treated as copies of each other -->
      <!--<xsl:variable name="prov-root-name" select="replace(name(root(.)/*), '^TEI$', 'TAN-T')"/>-->
      <!--<xsl:variable name="target-work" select="tan:element-vocabulary($target-resolved/*/tan:head/tan:work)"/>-->
      <xsl:variable name="target-accessed"
         select="max(tan:dateTime-to-decimal((tan:location/@accessed-when, @accessed-when)))"/>
      <xsl:variable name="target-updates"
         select="$target-hist/*[number(@when-sort) gt $target-accessed]"/>
      <xsl:variable name="default-link-error-message"
         select="concat('targets file with root element: ', name($target-resolved/*))"/>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message
            select="'diagnostics on, template mode check-referred-doc, for: ', tan:shallow-copy(.)"/>
         <xsl:message select="'target: ', $target-resolved"/>
         <xsl:message select="'target class: ', $target-class"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="($this-name = 'source') and ($this-class = 2) and not(exists(@xml:id))">
            <xsl:attribute name="xml:id" select="count(preceding-sibling::tan:source) + 1"/>
         </xsl:if>
         <xsl:if test="$this-name = ('model', 'redivision') and not($target-class = 1)">
            <xsl:copy-of select="tan:error('lnk03', $default-link-error-message)"/>
         </xsl:if>
         <xsl:if test="$this-name = ('annotation') and not($target-class = 2)">
            <xsl:copy-of select="tan:error('lnk04', $default-link-error-message)"/>
         </xsl:if>
         <xsl:if test="$this-name = ('morphology') and not($target-tan-type = 'TAN-mor')">
            <xsl:copy-of select="tan:error('lnk06', $default-link-error-message)"/>
         </xsl:if>
         <xsl:if
            test="exists(tan:location) and not($target-id = tan:IRI/text()) and $target-class gt 0">
            <xsl:copy-of
               select="tan:error('loc02', concat('ID of see-also file: ', $target-id), $target-id, 'replace-text')"
            />
         </xsl:if>
         <xsl:if
            test="($doc-id = $target-resolved/*/@id) and not(self::tan:successor or self::tan:predecessor)">
            <xsl:copy-of select="tan:error('loc03')"/>
         </xsl:if>
         <xsl:if test="exists($target-to-do-list/*)">
            <xsl:copy-of select="tan:error('wrn03', $target-to-do-list/*)"/>
         </xsl:if>
         <xsl:if test="exists($target-updates)">
            <xsl:variable name="this-message">
               <xsl:text>Target updated </xsl:text>
               <xsl:value-of select="count($target-updates)"/>
               <xsl:text> times since last accessed (</xsl:text>
               <xsl:for-each select="$target-updates">
                  <xsl:value-of select="concat('&lt;', name(.), '> ')"/>
                  <xsl:for-each select="(@accessed-when, @ed-when, @when)">
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
         <xsl:if test="exists($target-new-versions)">
            <xsl:copy-of select="tan:error('wrn05')"/>
         </xsl:if>

         <!-- tests that are specific to the name of the element being checked -->
         <xsl:choose>
            <xsl:when test="self::tan:inclusion">
               <xsl:if test="exists(.//tan:inclusion//tan:error[@xml:id = 'inc03'])">
                  <xsl:copy-of select="tan:error('inc03')"/>
               </xsl:if>
               <xsl:if test="not($target-is-faulty) and $target-class = 0">
                  <xsl:copy-of select="tan:error('lnk01', $default-link-error-message)"/>
               </xsl:if>
               <xsl:if test="$target-is-faulty = true()">
                  <xsl:copy-of select="tan:error('inc04', 'target is faulty')"/>
               </xsl:if>
               <xsl:if test="$target-class = 0">
                  <xsl:copy-of select="tan:error('inc04', 'target is not a TAN file')"/>
               </xsl:if>
               <xsl:if test="$this-doc-id = $target-resolved/*/tan:head/tan:vocabulary/tan:IRI">
                  <xsl:copy-of select="tan:error('inc04')"/>
               </xsl:if>
            </xsl:when>
            <xsl:when test="self::tan:vocabulary">
               <xsl:variable name="duplicate-vocab-item-names" as="element()*">
                  <xsl:for-each-group
                     select="$target-resolved/tan:TAN-voc/tan:body//(tan:item, tan:verb)"
                     group-by="
                        if (self::tan:verb) then
                           'verb'
                        else
                           tokenize(tan:normalize-text(ancestor-or-self::*[@affects-element][1]/@affects-element), ' ')">
                     <xsl:variable name="this-element-name" select="current-grouping-key()"/>
                     <xsl:for-each-group select="current-group()" group-by="tan:name">
                        <xsl:if
                           test="
                              count(current-group()) gt 1 and (some $i in current-group()
                                 satisfies root($i)/*/@id = $target-resolved/*/@id)">
                           <duplicate affects-element="{$this-element-name}"
                              name="{current-grouping-key()}"/>
                        </xsl:if>
                     </xsl:for-each-group>
                  </xsl:for-each-group>
               </xsl:variable>
               <xsl:variable name="duplicate-vocab-item-IRIs" as="element()*">
                  <xsl:for-each-group select="$target-resolved/tan:TAN-voc/tan:body//(tan:item, tan:verb)"
                     group-by="tan:IRI">
                     <xsl:if
                        test="
                           count(current-group()) gt 1 and (some $i in current-group()
                              satisfies root($i)/*/@id = $target-resolved/*/@id)">
                        <duplicate
                           affects-element="{distinct-values(for $i in current-group() return 
                           tokenize(tan:normalize-text($i/ancestor-or-self::*[@affects-element][1]/@affects-element),' ')), (if (exists(current-group()/self::tan:verb)) then 'verb' else ())}"
                           iri="{current-grouping-key()}"/>
                     </xsl:if>
                  </xsl:for-each-group>
               </xsl:variable>
               <xsl:variable name="target-vocab-inclusions"
                  select="$target-resolved/tan:TAN-voc/tan:head/tan:inclusion"/>
               <xsl:if test="not($target-tan-type = 'TAN-voc')">
                  <xsl:copy-of select="tan:error('lnk05', $default-link-error-message)"/>
               </xsl:if>
               <xsl:if test="$target-is-faulty = true()">
                  <xsl:copy-of select="tan:error('whi04')"/>
               </xsl:if>
               <xsl:if test="exists($duplicate-vocab-item-names)">
                  <xsl:copy-of
                     select="
                        tan:error('whi02', string-join(for $i in $duplicate-vocab-item-names
                        return
                           concat($i/@affects-element, ' ', $i/@name), '; '))"
                  />
               </xsl:if>
               <xsl:if test="exists($duplicate-vocab-item-IRIs)">
                  <xsl:copy-of
                     select="
                        tan:error('tan11', string-join(for $i in $duplicate-vocab-item-IRIs
                        return
                           concat($i/@affects-element, ' ', $i/@iri), '; '))"
                  />
               </xsl:if>
               <xsl:if test="$this-doc-id = $target-vocab-inclusions/tan:IRI">
                  <xsl:copy-of select="tan:error('inc05')"/>
               </xsl:if>
            </xsl:when>
            <xsl:when test="self::tan:source">
               <xsl:if test="$target-is-faulty = true() and $this-class = 2">
                  <xsl:copy-of select="tan:error('cl201')"/>
               </xsl:if>
            </xsl:when>
            <xsl:when test="self::tan:successor or self::tan:precedessor or self::tan:companion-version">
               <xsl:choose>
                  <xsl:when test="$this-class = 1 and $target-class = 1"/>
                  <xsl:when test="$this-tan-type = $target-tan-type"/>
                  <xsl:when test="$target-is-faulty"/>
                  <xsl:otherwise>
                     <xsl:copy-of select="tan:error('lnk02', $default-link-error-message)"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:when>
         </xsl:choose>

         <!-- general tests -->
         <xsl:if test="exists($target-last-change-agent/self::tan:algorithm)">
            <xsl:copy-of
               select="tan:error('wrn07', 'The last change in the dependency was made by an algorithm.')"
            />
         </xsl:if>
         <xsl:if
            test="$target-is-faulty and not($target-is-self-referential or $target-is-wrong-version)">
            <xsl:variable name="these-catalogs"
               select="
                  if ($this-doc-id = $doc-id) then
                     $doc-catalogs
                  else
                     tan:catalogs(., false())"/>
            <xsl:variable name="these-iris" select="tan:IRI"/>
            <xsl:variable name="catalog-matches"
               select="$these-catalogs/collection/doc[@id = $these-iris]"/>
            <xsl:variable name="possible-uris"
               select="
                  for $i in $catalog-matches,
                  $j in tan:base-uri($i)[not(. = $this-base-uri)]
                  return
                     resolve-uri($i/@href[tan:is-valid-uri(.)], xs:string($j))"/>
            <xsl:variable name="this-fix" as="element()*">
               <xsl:for-each select="$possible-uris">
                  <location href="{tan:uri-relative-to(xs:string(.), xs:string($this-base-uri))}"
                     accessed-when="{current-date()}"/>
               </xsl:for-each>
            </xsl:variable>
            <xsl:if test="exists($possible-uris)">
               <xsl:copy-of select="tan:error('wrn08', (), $this-fix, 'append-content')"/>
            </xsl:if>
         </xsl:if>
         <xsl:copy-of select="$target-resolved/(tan:error, tan:warning, tan:fatal, tan:help)"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="target-id" select="$target-id"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:IRI" priority="2" mode="check-referred-doc">
      <xsl:param name="target-id" as="xs:string?"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test=". = $duplicate-head-iris">
            <xsl:copy-of select="tan:error('tan09', .)"/>
         </xsl:if>
         <xsl:if test="(string-length($target-id) gt 0) and not(text() = $target-id)">
            <xsl:copy-of
               select="tan:error('tan10', concat('Target document @id = ', $target-id), $target-id, 'replace-text')"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="*[@href]" mode="check-referred-doc">
      <xsl:variable name="href-is-local" select="tan:url-is-local(@href)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:choose>
            <xsl:when test="not($internet-available) and not($href-is-local)">
               <!-- if it's a url on the internet, but there's no internet connection, provide the appropriate warning -->
               <xsl:copy-of select="tan:error('wrn10')"/>
            </xsl:when>
            <xsl:when
               test="$internet-available and not($href-is-local) and not(doc-available(@href))">
               <xsl:copy-of select="tan:error('wrn11')"/>
            </xsl:when>
            <xsl:when test="$href-is-local and not(doc-available(@href))">
               <xsl:copy-of select="tan:error('wrn01')"/>
            </xsl:when>
         </xsl:choose>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <!-- EXPANSION FOR ALL TAN FILES -->

   <!-- CORE EXPANSION TERSE -->

   <xsl:template match="/*[tan:head]" mode="core-expansion-terse-attributes">
      <xsl:variable name="ambig-is-roman" select="not(tan:numerals/@priority = 'letters')"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
            <xsl:with-param name="vocabulary-nodes" select="tan:head, self::tan:TAN-A/tan:body, self::tan:TAN-voc/tan:body"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tei:teiHeader | tan:head/tan:vocabulary | tan:head/tan:tan-vocabulary"
      mode="core-expansion-terse-attributes">
      <!-- we just deep copy the teiHeader, whose attribute constructions cannot be predicted, and any 
         vocabulary brought in from resolving the document, since the attributes should have already been
         expanded or resolved in the context of their original document.
      -->
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="tan:* | tei:*" mode="core-expansion-terse-attributes">
      <xsl:param name="ambig-is-roman" as="xs:boolean?" tunnel="yes"/>
      <xsl:param name="vocabulary-nodes" tunnel="yes"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="these-errors" select="tan:error"/>
      <xsl:variable name="this-attr-include" select="@include"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="this-from" select="tan:dateTime-to-decimal(@from)"/>
      <xsl:variable name="this-to" select="tan:dateTime-to-decimal(@to)"/>
      <xsl:variable name="dates"
         select="$this-from, $this-to, tan:dateTime-to-decimal((self::tan:*/@when, @ed-when, @accessed-when))"/>
      <!-- We presume each @href was resolved when the document was resolved -->
      <xsl:variable name="this-href" select="@href"/>
      <xsl:variable name="attributes-that-take-idrefs"
         select="
            if (exists(@include)) then
               (@include, @ed-who)
            else
               (@*[tan:takes-idrefs(.)] except @div-type)"
      />
      <xsl:variable name="this-id" select="@xml:id, @id"/>
      <xsl:variable name="appropriate-vocabulary-nodes"
         select="
            if (exists($this-attr-include)) then
               $vocabulary-nodes//tan:inclusion[@xml:id = $this-attr-include]
            else
               $vocabulary-nodes"
      />
      
      <xsl:copy>
         <xsl:copy-of select="@*"/>

         <!-- Process every attribute. For those that permit multiple values, convert the attribute to a series
         of elements, one value each. -->
         
         <xsl:for-each select="$attributes-that-take-idrefs">
            <!-- Check @which and attributes that point to vocabulary items -->
            <!-- We exclude @div-type, because it cannot be resolved against anything but the source headers -->
            <xsl:variable name="this-attr-name" select="name(.)"/>
            <xsl:variable name="this-is-which" select="$this-attr-name = 'which'"/>
            <xsl:variable name="these-target-element-names" select="tan:target-element-names(.)"/>
            <xsl:variable name="these-vals-pass-1"
               select="
                  if ($this-is-which) then
                     tan:normalize-name(.)
                  else
                     tokenize(normalize-space(.))"
            />
            <xsl:variable name="these-vals-normalized" select="tan:help-extracted($these-vals-pass-1)"/>
            <xsl:variable name="these-distinct-vals" select="distinct-values($these-vals-normalized)"/>
            <xsl:variable name="dupl-values" select="tan:duplicate-items($these-vals-normalized)"/>
            <xsl:variable name="any-value-allowed" select="$these-vals-normalized = '*'"/>
            <!--<xsl:variable name="this-vocabulary" select="tan:attribute-vocabulary(.)"/>-->
            <xsl:variable name="this-vocabulary"
               select="
                  for $i in $these-vals-normalized
                  return
                     tan:vocabulary($these-target-element-names, $i, $appropriate-vocabulary-nodes)"
            />
            <xsl:variable name="these-vocabulary-items" select="$this-vocabulary/(* except (tan:IRI, tan:name, tan:desc))"/>
            <xsl:variable name="vocabulary-pointed-to-more-than-once"
               select="
                  if (count($these-vocabulary-items) gt 1) then
                     (for $i in (2 to count($these-vocabulary-items)),
                        $j in (1 to ($i - 1))
                     return
                        (if (deep-equal($these-vocabulary-items[$i], $these-vocabulary-items[$j])) then
                           $these-vocabulary-items[$i]
                        else
                           ()))
                  else
                     ()"
            />
            <xsl:variable name="all-permissible-vocabulary-items"
               select="tan:vocabulary($these-target-element-names, (), $vocabulary-nodes)"/>
            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'diagnostics on for ', ."/>
               <xsl:message
                  select="count($these-vals-pass-1), 'normalized values: ', string-join($these-vals-pass-1, ', ')"/>
               <xsl:message select="'these vals parsed: ', $these-vals-normalized"/>
               <xsl:message select="'appropriate vocabulary nodes:', $appropriate-vocabulary-nodes"/>
               <xsl:message select="'this vocabulary: ', $this-vocabulary"/>
            </xsl:if>
            <!-- If tan:vocabulary() finds errors, copy them. -->
            <xsl:copy-of select="$this-vocabulary/self::tan:error"/>
            <xsl:if test="not(exists($these-vals-pass-1))">
               <xsl:copy-of
                  select="
                     if ($this-is-which) then
                        tan:error('whi01')
                     else
                        tan:error('tan05')"
               />
            </xsl:if>
            <xsl:if test="exists($dupl-values)">
               <xsl:variable name="this-message"
                  select="concat('duplicate values: ', string-join($dupl-values, ', '))"/>
               <xsl:copy-of select="tan:error('tan06', $this-message)"/>
            </xsl:if>
            <xsl:for-each select="$vocabulary-pointed-to-more-than-once">
               <xsl:variable name="these-duplicate-refs"
                  select="(@xml:id, @id, tan:id, tan:name)[. = $these-vals-normalized]"/>
               <xsl:variable name="this-message"
                  select="concat(string-join($these-duplicate-refs, ', '), ' all point to the same ', name(.), ' (', tan:name[1], ')')"/>
               <xsl:copy-of select="tan:error('tan21', $this-message)"/>
            </xsl:for-each>
            <xsl:for-each select="$these-vals-normalized">
               <xsl:variable name="this-val" select="text()"/>
               <xsl:variable name="this-is-joker" select="$this-val = '*'"/>
               <xsl:variable name="this-val-esc" select="tan:escape($this-val)"/>
               <xsl:variable name="preexisting-error"
                  select="$these-errors[tan:item/(tan:id, tan:name) = $this-val]"/>
               <xsl:variable name="vocab-items-available" select="$this-vocabulary/(* except tan:IRI, tan:name, tan:desc)"/>
               <xsl:variable name="vocab-items-pointed-to-by-id" select="$vocab-items-available[(tan:id, tan:alias) = $this-val]"/>
               <xsl:variable name="vocab-items-pointed-to-by-name"
                  select="
                     if (not(exists($vocab-items-pointed-to-by-id))) then
                        $vocab-items-available[tan:name = tan:normalize-name($this-val)]
                     else
                        ()"
               />
               <xsl:variable name="item-is-erroneous"
                  select="not($this-is-joker) and not(exists($vocab-items-pointed-to-by-id)) and not(exists($vocab-items-pointed-to-by-name))"
               />
               
               <xsl:variable name="diagnostics-on" select="false()"/>
               <xsl:if test="$diagnostics-on">
                  <xsl:message select="'Diagnostics on template mode core-expansion-terse-attributes, on individual value for attr', $this-attr-name"/>
                  <xsl:message select="'This attribute name: ', $this-attr-name"/>
                  <xsl:message select="'Target element names: ', $these-target-element-names"/>
                  <xsl:message select="'This value:', $this-val"/>
                  <xsl:message select="'Appropriate vocabulary nodes:', $appropriate-vocabulary-nodes"/>
                  <xsl:message select="'Vocab items available: ', $vocab-items-available"/>
                  <xsl:message select="'Vocab items pointed to by id:', $vocab-items-pointed-to-by-id"/>
                  <xsl:message select="'Vocab items pointed to by name:', $vocab-items-pointed-to-by-name"/>
               </xsl:if>
               
               <xsl:if test="$item-is-erroneous">
                  <xsl:variable name="this-message"
                     select="concat($this-val, ' matches no id')"/>
                  <xsl:variable name="this-fix" as="element()">
                     <xsl:element name="{$these-target-element-names[1]}">
                        <xsl:attribute name="xml:id" select="$this-val"/>
                        <xsl:attribute name="which"/>
                     </xsl:element>
                  </xsl:variable>
                  <xsl:copy-of
                     select="
                        if ($this-is-which) then
                           tan:error('whi01', $this-message, $this-fix, 'add-vocabulary-key-item')
                        else
                           tan:error('tan05', $this-message, $this-fix, 'add-vocabulary-key-item')"
                  />
               </xsl:if>
               <xsl:if test="exists(@help) or $item-is-erroneous">
                  <xsl:variable name="this-fix" as="element()*">
                     <xsl:for-each
                        select="$all-permissible-vocabulary-items/*[not(@q = $this-q)][name() = ('item', $these-target-element-names)]">
                        <xsl:sort
                           select="
                              some $i in (@*, *)
                                 satisfies matches($i, $this-val-esc, 'i')"
                           order="descending"/>
                        <xsl:variable name="this-val" select="(@xml:id, tan:name)[1]"/>
                        <element>
                           <xsl:attribute name="{$this-attr-name}" select="$this-val"/>
                        </element>
                     </xsl:for-each>
                  </xsl:variable>
                  <xsl:variable name="this-message-preamble"
                     select="
                        if (exists(@help)) then
                           'help requested; try: '
                        else
                           concat($this-val, ' not found; try: ')"/>
                  <xsl:variable name="this-message"
                     select="concat($this-message-preamble, string-join($this-fix/@*, '; '))"/>
                  <xsl:copy-of select="tan:help($this-message, $this-fix, 'copy-attributes')"/>
               </xsl:if>
               
               <xsl:if test="$this-is-joker">
                  <xsl:for-each select="$vocab-items-available">
                     <xsl:element name="{$this-attr-name}">
                        <xsl:attribute name="attr"/>
                        <xsl:value-of select="tan:id[1]"/>
                        <xsl:if test="$distribute-vocabulary = true()">
                           <xsl:copy-of select="."/>
                        </xsl:if>
                     </xsl:element>
                  </xsl:for-each>
               </xsl:if>
               <xsl:element name="{$this-attr-name}">
                  <xsl:attribute name="attr"/>
                  <xsl:value-of select="$this-val"/>
                  <xsl:if test="$distribute-vocabulary = true()">
                     <xsl:variable name="this-item-vocabulary"
                        select="
                           if (exists($vocab-items-pointed-to-by-id)) then
                              $vocab-items-pointed-to-by-id
                           else
                              $vocab-items-pointed-to-by-name"
                     />
                     <!-- we regularize item vocabulary to tan:item, so that an embedded vocabulary definition can be easily and consistently found -->
                     <xsl:copy-of select="$this-item-vocabulary/self::tan:item"/>
                     <xsl:for-each select="$this-item-vocabulary[not(self::tan:item)]">
                        <item>
                           <xsl:copy-of select="@*"/>
                           <affects-element>
                              <xsl:value-of select="name(.)"/>
                           </affects-element>
                           <xsl:copy-of select="node()"/>
                        </item>
                     </xsl:for-each>
                  </xsl:if>
               </xsl:element>
               
            </xsl:for-each>
            <!-- The values might yield vocabulary ids that aren't in the original values (e.g., '*'), so expansion should include them -->
            <xsl:for-each select="$this-vocabulary/*/@xml:id[not(. = $these-vals-normalized)]">
               <xsl:element name="{$this-attr-name}">
                  <xsl:attribute name="attr"/>
                  <xsl:value-of select="."/>
                  <xsl:if test="$distribute-vocabulary = true()">
                     <xsl:copy-of select=".."/>
                  </xsl:if>
               </xsl:element>
            </xsl:for-each>
            <xsl:if test="$this-vocabulary/*/tan:name = $this-id">
               <xsl:copy-of select="tan:error('tan12')"/>
            </xsl:if>
         </xsl:for-each>

         <xsl:if test="$this-id = $duplicate-ids">
            <xsl:copy-of
               select="tan:error('tan03', concat('ids used so far: ', string-join($all-ids, ', ')))"
            />
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
         <xsl:if test="(@pattern, @matches-m, @matches-tok, @rgx)[not(tan:regex-is-valid(.))]">
            <xsl:copy-of select="tan:error('tan07')"/>
         </xsl:if>
         <xsl:if
            test="exists(self::tan:master-location) and (matches(@href, '!/') or ends-with(@href, 'docx') or ends-with(@href, 'zip'))">
            <xsl:copy-of select="tan:error('tan15')"/>
         </xsl:if>
         <xsl:if test="$this-href = $doc-uri">
            <xsl:copy-of select="tan:error('tan17')"/>
         </xsl:if>
         <xsl:if test="exists(@href) and not((self::tan:location, self::tan:master-location))">
            <xsl:choose>
               <xsl:when test="not(tan:url-is-local(@href)) and not($internet-available)"/>
               <xsl:when test="doc-available($this-href)">
                  <xsl:variable name="target-doc" select="doc($this-href)"/>
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
                        <location accessed-when="{current-dateTime()}"
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

         <xsl:variable name="try-to-expand-ranges" select="exists(parent::tan:adjustments)"/>
         <xsl:for-each select="(@ref, @pos, @chars, @n[not(parent::*:div)])">
            <!-- analysis of attributes that point to another file -->
            <!-- We exclude div/@n, which does not point to another file, and is handled separately, in class 1 resolution -->
            <!-- These attributes are characteristic of class 2 files -->
            <xsl:variable name="this-name" select="name(.)"/>
            <xsl:variable name="this-val-analyzed"
               select="tan:analyze-sequence(., $this-name, $try-to-expand-ranges, $ambig-is-roman)"/>
            <xsl:variable name="this-attr-converted-to-elements"
               select="tan:stamp-q-id($this-val-analyzed/*, true())"/>
            <xsl:copy-of select="$this-attr-converted-to-elements"/>
         </xsl:for-each>
         <xsl:if test="exists(@new)">
            <!-- @new is special, in that the resultant <new> will encase its value as a representation of @ref or @n, depending upon which one <rename> has -->
            <xsl:variable name="type-of-new"
               select="
                  if (exists(@ref)) then
                     'ref'
                  else
                     'n'"/>
            <xsl:variable name="this-val-analyzed"
               select="tan:analyze-sequence(@new, $type-of-new, true(), $ambig-is-roman)"/>
            <xsl:variable name="this-attr-converted-to-elements"
               select="tan:stamp-q-id($this-val-analyzed/*, true())"/>
            <new q="{generate-id(@new)}">
               <xsl:copy-of select="$this-attr-converted-to-elements"/>
            </new>
         </xsl:if>
         <!-- default behavior for any other attributes left over; we don't do every attribute, because not every one needs to be expanded into an element -->
         <xsl:apply-templates select="@code, @val, @rgx, @div-type, @affects-element, @affects-attribute, @by, @item-type, @in-lang"
            mode="#current"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="vocabulary-nodes" select="$appropriate-vocabulary-nodes"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="@*" mode="core-expansion-terse-attributes">
      <xsl:param name="add-q-id" as="xs:boolean?"/>
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="this-val-parsed" select="tan:help-extracted(.)"/>
      <xsl:variable name="this-q-id" select="generate-id(.)"/>
      <xsl:variable name="multiple-vals-space-delimited"
         select="$this-name = $names-of-attributes-that-may-take-multiple-space-delimited-values"/>
      <xsl:variable name="render-lowercase"
         select="$this-name = $names-of-attributes-that-are-case-indifferent"/>
      <xsl:variable name="these-vals-1"
         select="
            if ($multiple-vals-space-delimited) then
               tokenize($this-val-parsed/text(), ' ')
            else
               $this-val-parsed/text()"/>
      <xsl:variable name="these-vals-2"
         select="
            if ($render-lowercase) then
               for $i in $these-vals-1
               return
                  lower-case($i)
            else
               $these-vals-1"/>
      <xsl:for-each select="$these-vals-2">
         <xsl:element name="{$this-name}" namespace="tag:textalign.net,2015:ns">
            <xsl:attribute name="attr"/>
            <xsl:if test="$add-q-id">
               <xsl:attribute name="q" select="$this-q-id"/>
            </xsl:if>
            <xsl:choose>
               <!-- a faulty regular expression will be flagged in the parent; its value should be suppressed, to avoid fatal errors -->
               <xsl:when test="$this-name = 'rgx' and not(tan:regex-is-valid(.))"/>
               <xsl:otherwise>
                  <xsl:value-of select="."/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:element>
      </xsl:for-each>
   </xsl:template>

   <xsl:template match="/*" mode="core-expansion-terse" priority="-2">
      <xsl:variable name="this-last-change-agent" select="tan:last-change-agent(root())"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
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
            <xsl:with-param name="is-tan-a-lm" select="(name(.) = 'TAN-A-lm')" tunnel="yes"/>
            <xsl:with-param name="is-for-lang" select="exists(tan:head/tan:for-lang)" tunnel="yes"/>
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
            <xsl:copy-of
               select="tan:error('cat04', 'file may incorrectly duplicate the @id of another')"/>
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
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>


   <xsl:template match="tan:head" mode="core-expansion-terse">
      <xsl:variable name="token-definition-source-duplicates"
         select="tan:duplicate-items(tan:token-definition/tan:src)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="token-definition-errors"
               select="$token-definition-source-duplicates"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:inclusion | tan:vocabulary" mode="core-expansion-terse">
      <xsl:apply-templates select="." mode="check-referred-doc"/>
   </xsl:template>

   <xsl:template match="tan:name" mode="core-expansion-terse">
      <!-- parameters below specifically for TAN-voc files -->
      <xsl:param name="reserved-vocabulary-items" as="element()*"/>
      <xsl:param name="is-reserved" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="this-name" select="text()"/>
      <xsl:variable name="this-name-norm" select="tan:normalize-name($this-name)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="($reserved-vocabulary-items/tan:name = ($this-name, $this-name-norm)) and ($is-reserved = false() or $doc-is-error-test)">
            <xsl:copy-of select="tan:error('voc01')"/>
         </xsl:if>
         <xsl:if test="$is-reserved and not($this-name = $this-name-norm)">
            <xsl:copy-of
               select="tan:error('voc07', concat('replace with ', $this-name-norm), $this-name-norm, 'replace-text')"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:IRI" mode="core-expansion-terse">
      <!-- The next param is specific to TAN-voc files -->
      <xsl:param name="duplicate-IRIs" tunnel="yes"/>
      <xsl:variable name="names-a-TAN-file" select="tan:must-refer-to-external-tan-file(.)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test=". = ($duplicate-head-iris, $duplicate-IRIs)">
            <xsl:copy-of select="tan:error('tan09', .)"/>
         </xsl:if>
         <xsl:if test="matches(., '^urn:')">
            <xsl:variable name="this-urn-namespace" select="replace(., '^urn:([^:]+):.+', '$1')"/>
            <xsl:if test="not($this-urn-namespace = $official-urn-namespaces)">
               <xsl:copy-of
                  select="tan:error('tan19', concat($this-urn-namespace, ' is not in the official registry of URN namespaces '))"
               />
            </xsl:if>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:token-definition" mode="core-expansion-terse">
      <xsl:param name="token-definition-errors"/>
      <xsl:variable name="this-vocabulary" select="tan:element-vocabulary(.)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$this-vocabulary//tan:token-definition/@*"/>
         <xsl:if test="$token-definition-errors = tan:src">
            <xsl:copy-of select="tan:error('cl202')"/>
         </xsl:if>
         <xsl:if test="not(exists(@src))">
            <xsl:for-each select="../tan:source">
               <src>
                  <xsl:value-of select="(@xml:id, 1)[1]"/>
               </src>
            </xsl:for-each>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:vocabulary-key" mode="core-expansion-terse">
      <xsl:param name="extra-vocabulary" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <xsl:copy-of select="$extra-vocabulary"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:file-resp" mode="core-expansion-terse">
      <xsl:variable name="these-whos" select="tan:who"/>
      <!--<xsl:variable name="who-vocab" select="tan:glossary(('person', 'organization'), $these-whos), preceding-sibling::tan:vocabulary-key/*[(@xml:id, @id) = $these-whos]"/>-->
      <xsl:variable name="who-vocab" select="tan:vocabulary(('person', 'organization'), $these-whos, (parent::tan:head, root(.)/(tan:TAN-A, tan:TAN-voc)/tan:body))"/>
      <xsl:variable name="key-agent"
         select="$who-vocab/*[tan:IRI[starts-with(., $doc-id-namespace)]]"/>
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, tan:file-resp, template mode core-expansion-terse'"/>
         <xsl:message select="'Who vocab:', $who-vocab"/>
         <xsl:message select="'Key agent:', $key-agent"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(exists($key-agent))">
            <xsl:copy-of
               select="tan:error('tan01', concat('Need a person, organization, or algorithm with an IRI that begins ', $doc-id-namespace))"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:to-do" mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(exists(tan:comment)) and not(exists(../tan:master-location))">
            <xsl:variable name="this-fix">
               <master-location href="{$doc-uri}"/>
            </xsl:variable>
            <xsl:copy-of select="tan:error('tan02', '', $this-fix, 'add-master-location')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <!-- CORE EXPANSION NORMAL -->

   <xsl:template match="/*" mode="core-expansion-normal dependency-expansion-normal">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <expanded>normal</expanded>
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
               <xsl:variable name="target-hist" select="tan:get-doc-history($this-master-doc)"/>
               <xsl:variable name="target-changes"
                  select="tan:xml-to-string(tan:copy-of-except($target-hist/*[position() lt 4], (), 'when-sort', ()))"/>
               <xsl:copy-of
                  select="tan:error('tan18', concat('Master document differs from this one; last three edits: ', $target-changes))"
               />
            </xsl:when>
         </xsl:choose>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template
      match="tan:see-also | tan:model | tan:redivision | tan:successor | tan:predecessor | tan:algorithm | tan:source[tan:location] | tan:annotation"
      mode="core-expansion-normal">
      <xsl:apply-templates select="." mode="check-referred-doc"/>
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
      <xsl:variable name="this-local-catalog" as="document-node()?"
         select="tan:catalogs(., true())[1]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <expanded>verbose</expanded>
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
                        tan:collection($i)"/>
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
