<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="2.0">

   <xsl:function name="tan:expand-doc" as="document-node()*">
      <!-- one-parameter version of the fuller one below -->
      <xsl:param name="tan-doc" as="document-node()?"/>
      <xsl:copy-of select="tan:expand-doc($tan-doc, $validation-phase, $is-validation)"/>
   </xsl:function>
   <xsl:function name="tan:expand-doc" as="document-node()*">
      <!-- one-parameter version of the fuller one below -->
      <xsl:param name="tan-doc" as="document-node()?"/>
      <xsl:param name="target-phase" as="xs:string"/>
      <xsl:copy-of select="tan:expand-doc($tan-doc, $target-phase, $is-validation)"/>
   </xsl:function>
   
   <xsl:function name="tan:expand-doc-test" as="document-node()*">
      <!-- Input: a TAN document, a string specifying a target phase, and a boolean specifying whether validation should be used -->
      <!-- Output: select diagnostic output, testing the sequences of the expansion process -->
      <!-- In most cases, the output will be simple or non-existent. The function can be used to tailor specific conditions,
      to test the accuracy and speed of the expansion process. -->
      <xsl:param name="tan-doc" as="document-node()?"/>
      <xsl:param name="target-phase" as="xs:string"/>
      <xsl:param name="use-validation-mode" as="xs:boolean"/>
      <xsl:document>
         <test-expansion>
         </test-expansion>
      </xsl:document>
      
   </xsl:function>

   <xsl:function name="tan:expand-doc">
      <!-- Input: a tan document, a string indicating a phase of expansion, a boolean indicating whether the function is intended
      to serve validation -->
      <!-- Output: the document and its dependencies expanded at the phase indicated. -->
      <!-- If validation mode is true, then the results will be stripped down to root element and the bare markers for errors, 
         warnings, and fixes. If validation mode is false, then the complete, expanded document and its dependencies will be
         returned.
      -->
      <!-- Because class 2 files are expanded hand-in-glove with the class 1 files they depend upon, expansion is necessarily 
         synchronized with its dependent sources. The expanded form of the original class-2 document is the first document of the 
         result, and the expanded class-1 or -3 files follow. -->
      <xsl:param name="tan-doc" as="document-node()?"/>
      <xsl:param name="target-phase" as="xs:string"/>
      <xsl:param name="use-validation-mode" as="xs:boolean"/>

      <xsl:variable name="this-doc-id" select="$tan-doc/*/@id"/>
      <xsl:variable name="this-class-number" select="tan:class-number($tan-doc)"/>
      <xsl:variable name="this-tan-type" select="tan:tan-type($tan-doc)"/>
      <xsl:variable name="this-is-class-2" select="$this-class-number eq 2"/>
      <xsl:variable name="this-is-tan-a" select="$this-tan-type eq 'TAN-A'"/>
      <xsl:variable name="this-is-tan-a-lm" select="$this-tan-type eq 'TAN-A-lm'"/>
      <xsl:variable name="phase-picked" as="xs:string"
         select="
            if (not($target-phase = $validation-phase-names)) then
               ($validation-phase)
            else
               $target-phase"/>

      <!-- TERSE EXPANSION ALL CLASSES -->

      <!-- Terse expansion needs at least two passes: one to expand overloaded attributes, and then general element expansions. -->

      <!-- What follows is a wildcard template that has no effect within validation. Users downstream can cut out parts of the file of no interest -->
      <xsl:variable name="core-expansion-ad-hoc-pre-pass" as="document-node()?">
         <xsl:choose>
            <xsl:when test="$use-validation-mode = true()">
               <xsl:sequence select="$tan-doc"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates select="$tan-doc" mode="core-expansion-ad-hoc-pre-pass"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- Parse, itemize, and interpret attribute values. Some class 2 file attributes, i.e., @ref, @n, and @new, can be interpreted 
         only in the context of a host source file. Validation and non-validation should be identical.  -->
      <xsl:variable name="core-terse-expansion-pass-1" as="document-node()?">
         <xsl:apply-templates select="$core-expansion-ad-hoc-pre-pass"
            mode="core-expansion-terse-attributes">
            <xsl:with-param name="use-validation-mode" tunnel="yes" select="$use-validation-mode"/>
         </xsl:apply-templates>
      </xsl:variable>

      <xsl:variable name="dependencies-resolved" as="document-node()*">
         <!-- Get all files upon which the host file depends, namely <source>s and <morphology>s -->
         <xsl:choose>
            <!-- Only class 2 files have dependencies -->
            <xsl:when test="not($this-is-class-2)"/>
            <!-- Class 2 files absolutely must come with the source class 1 files upon which they depend. 
               This variable ensures we have them, without repeating the process. -->
            <xsl:when test="$this-doc-id eq $doc-id">
               <xsl:sequence select="$sources-resolved, $morphologies-resolved"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:copy-of
                  select="tan:get-and-resolve-dependency($core-terse-expansion-pass-1/(tan:TAN-A, tan:TAN-A-lm, tan:TAN-A-tok)/tan:head/tan:source)"/>
               <xsl:copy-of
                  select="tan:get-and-resolve-dependency($core-terse-expansion-pass-1/tan:TAN-A-lm/tan:head/tan:vocabulary-key/tan:morphology)"
               />
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      <!-- Allow element-based expansion to take place -->
      <xsl:variable name="core-terse-expansion-pass-2" as="document-node()?">
         <xsl:apply-templates select="$core-terse-expansion-pass-1" mode="core-expansion-terse">
            <xsl:with-param name="dependencies" select="$dependencies-resolved" tunnel="yes"/>
            <xsl:with-param name="use-validation-mode" select="$use-validation-mode" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:variable>



      <!-- TERSE EXPANSION CLASS 2 -->
      <!-- At this point class-1 and class-3 files should be completely expanded for the terse phase. Class-2 files 
         are complex, and need special rounds of terse expansion between the document and its dependencies. 
         The variables from here through pass 3 should be negligibly rapid for class-1 and class-3 files, but a
         class-2 file with complex/numerous adjustments and referents, or with lengthy or numerous sources,
         could take a long time to process. Caveat encoder.
      -->

      <!-- If a class 2 file, first make all adjustments to the class-1 sources requested by the class 2 file, resetting the 
         hierarchy if required. Then for every textual reference in the class-2 file, place a marker in the relevant
         class-1 sources. At that point the class-2 file can be evaluated, by looking for markers in the class-1 sources,
         with errors returned for missing markers, or too many of them.
      -->

      <!-- Important parts of the class-2 file -->
      <xsl:variable name="class-2-expansion-pass-2-head" as="element()?"
         select="
            if ($this-is-class-2) then
               $core-terse-expansion-pass-2/*/tan:head
            else
               ()"/>
      <xsl:variable name="class-2-expansion-pass-2-body" as="element()?"
         select="
            if ($this-is-class-2) then
               $core-terse-expansion-pass-2/*/tan:body
            else
               ()"/>
      
      <xsl:variable name="reference-trees" as="element()*">
         <xsl:for-each-group select="$class-2-expansion-pass-2-body//*[(tan:src | tan:work)]"
            group-by="tan:src, tan:work">
            <xsl:variable name="ref-parents" select="current-group()/descendant-or-self::*[tan:ref]"/>
            <xsl:variable name="ref-parents-that-do-not-need-iteration"
               select="$ref-parents[count(tan:ref) eq 1]"/>
            <xsl:variable name="other-ref-parents-iterated" as="element()*">
               <xsl:for-each select="$ref-parents except $ref-parents-that-do-not-need-iteration">
                  <xsl:variable name="this-ref-parent" select="."/>
                  <xsl:variable name="these-refs" select="tan:ref"/>
                  <xsl:for-each select="$these-refs">
                     <xsl:variable name="this-ref" select="."/>
                     <xsl:element name="{name($this-ref-parent)}">
                        <xsl:copy-of select="$this-ref-parent/@*"/>
                        <xsl:copy-of select="$this-ref"/>
                        <xsl:copy-of select="$this-ref-parent/(node() except tan:ref)"/>
                     </xsl:element>
                  </xsl:for-each>
               </xsl:for-each>
            </xsl:variable>
            
            <doc>
               <src>
                  <xsl:value-of select="current-grouping-key()"/>
               </src>
               <!-- Copy at the root level of the tree any claims that are not tethered to a particular reference -->
               <xsl:copy-of select="current-group()/self::tan:tok[not(tan:ref)]"/>
               <!-- Now build the reference tree -->
               <xsl:copy-of
                  select="tan:build-parent-ref-tree(($ref-parents-that-do-not-need-iteration, $other-ref-parents-iterated), 1, ())"
               />
            </doc>
         </xsl:for-each-group>

      </xsl:variable>

      <!-- All textual references must begin with @ref (expanded to <ref> in an earlier pass) -->
      <xsl:variable name="this-class-2-has-div-references" as="xs:boolean"
         select="exists($reference-trees/tan:div)"/>
      <!--<xsl:variable name="these-tok-parents" select="$these-ref-parents[descendant::tan:pos]"/>-->
      
      <!-- Are there claims that require tokenization of everything? If so, no div can be ignored during validation -->
      <!--<xsl:variable name="special-elements-that-require-universal-tokenization" as="element()*"
         select="$class-2-expansion-pass-2-body[parent::tan:TAN-A-lm]//tan:tok[not(@ref)]"/>-->
      <xsl:variable name="special-elements-that-require-universal-tokenization" as="element()*"
         select="$reference-trees/tan:tok"/>
      <xsl:variable name="adjustments-part-1" as="element()*"
         select="$class-2-expansion-pass-2-head/tan:adjustments/(tan:skip, tan:rename, tan:equate)"/>
      <xsl:variable name="adjustments-part-2" as="element()*"
         select="$class-2-expansion-pass-2-head/tan:adjustments/tan:reassign"/>

      <!-- Shall divs in the dependent files be dropped right away? If so, populate this filter -->
      <xsl:variable name="div-filters" as="element()*"
         select="
            if ($use-validation-mode
            and not(exists($special-elements-that-require-universal-tokenization))
            and not(exists($adjustments-part-1))
            and not(exists($adjustments-part-2))) then
               $reference-trees
            else
               ()"/>
      
      


      <!-- TERSE EXPANSION CLASS 2: ADJUSTMENTS -->
      <!-- The first pass of source expansion applies three types of adjustments: skip, rename, equate -->
      <!-- We almost always go through this first pass even if there are no adjustments, because it also properly itemizes
         <div> @n values via individual <n> and <ref> elements, which are essential later for finding <div>s -->
      <!-- This process involves behind a marker for each adjustment action taken, to determine later whether the 
         action has taken place or not. -->

      <xsl:variable name="make-adjustments-pass-1" as="xs:boolean"
         select="$this-is-class-2 and 
         (not($use-validation-mode) 
         or exists($adjustments-part-1) 
         or exists($reference-trees))"
      />

      <xsl:variable name="dependencies-adjusted-pass-1a" as="document-node()*">
         <xsl:choose>
            <xsl:when test="$make-adjustments-pass-1">
               <xsl:apply-templates select="$dependencies-resolved"
                  mode="dependency-adjustments-pass-1">
                  <xsl:with-param name="class-2-doc" select="$core-terse-expansion-pass-2" tunnel="yes"/>
                  <xsl:with-param name="div-filters" tunnel="yes" select="$div-filters"/>
                  <xsl:with-param name="use-validation-mode" select="$use-validation-mode" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$dependencies-resolved"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:variable name="adjustment-pass-1a-dependency-divs-to-reset"
         select="
            if ($make-adjustments-pass-1) then
               (for $i in $dependencies-adjusted-pass-1a
               return
                  key('divs-to-reset', '', $i))
            else
               ()"/>
      <xsl:variable name="adjustment-pass-1a-divs-with-attr-frag-from"
         select="
            if ($make-adjustments-pass-1) then
               (for $i in $dependencies-adjusted-pass-1a
               return
                  key('attrs-by-name', 'frag-from', $i))
            else
               ()"
      />


      <!-- If the first adjustments created actions that threw the hierarchy of sources out of whack, then reset the hierarchy before proceeding -->
      <xsl:variable name="dependencies-adjusted-pass-1b" as="document-node()*">
         <xsl:choose>
            <xsl:when test="exists($adjustment-pass-1a-dependency-divs-to-reset)">
               <xsl:apply-templates select="$dependencies-adjusted-pass-1a" mode="reset-hierarchy">
                  <xsl:with-param name="divs-to-reset"
                     select="$adjustment-pass-1a-dependency-divs-to-reset" tunnel="yes"/>
                  <xsl:with-param name="process-entire-document" select="true()" tunnel="yes"/>
                  <xsl:with-param name="remove-first-token-from" tunnel="yes" select="$adjustment-pass-1a-divs-with-attr-frag-from"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="exists($adjustment-pass-1a-divs-with-attr-frag-from)">
               <xsl:apply-templates select="$dependencies-adjusted-pass-1a" mode="remove-first-token">
                  <xsl:with-param name="remove-first-token-from" tunnel="yes" select="$adjustment-pass-1a-divs-with-attr-frag-from"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$dependencies-adjusted-pass-1a"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>


      <!-- Now perform the second round of adjustments, <reassign> -->
      <xsl:variable name="dependencies-adjusted-pass-2a" as="document-node()*">
         <xsl:choose>
            <xsl:when test="exists($adjustments-part-2)">
               <xsl:apply-templates select="$dependencies-adjusted-pass-1b"
                  mode="dependency-adjustments-pass-2">
                  <xsl:with-param name="class-2-doc" select="$core-terse-expansion-pass-2" tunnel="yes"/>
                  <xsl:with-param name="use-validation-mode" select="$use-validation-mode" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$dependencies-adjusted-pass-1b"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>


      <!-- If reassignments threw the hierarchy of sources out of whack, then reset the hierarchy before proceeding -->
      <xsl:variable name="dependencies-adjusted-pass-2b" as="document-node()*">
         <xsl:choose>
            <xsl:when test="exists($adjustments-part-2)">
               <xsl:apply-templates select="$dependencies-adjusted-pass-2a" mode="reset-hierarchy">
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


      <!-- TERSE EXPANSION CLASS 2: MARKERS -->
      <!-- In dependencies, place markers corresponding to the text references made in the class-2 body.
         Markers are of three sorts: <div> references (derived from @ref); token references (derived from
         @val/@rgx + @pos); character references (derived from @chars).
      -->
      <!-- If for validation: only one pass is needed, because the only goal is to see if every reference in the class-2
         document is valid. In the class-1 dependent file, everything is ignored in the body, and all that are left are
         class-2 markers and perhaps analyzed results, to provide help. -->
      <!-- If not for validation: two passes are needed. In the first, tokenization and character splitting occurs where 
         needed and a <ref> parent is left behind as a marker in the appropriate <div>. In the second pass, those markers 
         are adjusted. the <ref> stays in the appropriate <div> but any associated <pos> or <char> marker drifts leafward
         to land in the precise spot intended.
      -->
      
      <xsl:variable name="dependencies-marked-pass-1" as="document-node()*">
         <xsl:choose>
            <xsl:when
               test="$this-class-2-has-div-references or exists($special-elements-that-require-universal-tokenization)">
               <xsl:apply-templates select="$dependencies-adjusted-pass-2b[tan:TAN-T or tan:error]"
                  mode="mark-dependencies-pass-1">
                  <xsl:with-param name="class-2-doc" select="$core-terse-expansion-pass-2" tunnel="yes"/>
                  <xsl:with-param name="reference-trees" tunnel="yes" select="$reference-trees"/>
                  <xsl:with-param name="use-validation-mode" select="$use-validation-mode" tunnel="yes"/>
               </xsl:apply-templates>
               <xsl:sequence select="$dependencies-adjusted-pass-2b[tan:TAN-mor]"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$dependencies-adjusted-pass-2b"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- On the second pass, set all token- and character-based markers; all tokenization should have happened in the previous step -->
      <xsl:variable name="dependencies-marked-pass-2" as="document-node()*">
         <xsl:choose>
            <xsl:when test="$use-validation-mode and exists($reference-trees/descendant::tan:pos)">
               <!-- token references must be checked -->
               <xsl:apply-templates select="$dependencies-marked-pass-1" mode="mark-dependencies-pass-2-for-validation">
                  <xsl:with-param name="reference-trees" tunnel="yes" select="$reference-trees"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$use-validation-mode">
               <xsl:sequence select="$dependencies-marked-pass-1"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates select="$dependencies-marked-pass-1"
                  mode="mark-dependencies-pass-2"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:variable name="dependencies-stripped-to-markers" as="document-node()*">
         <xsl:choose>
            <xsl:when
               test="
                  exists($adjustments-part-1) or exists($adjustments-part-2)
                  or $this-class-2-has-div-references
                  or exists($special-elements-that-require-universal-tokenization)">
               <xsl:apply-templates select="$dependencies-marked-pass-2"
                  mode="strip-dependencies-to-markers"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$dependencies-marked-pass-2"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:variable name="core-terse-expansion-pass-3" as="document-node()?">
         <xsl:choose>
            <xsl:when test="$this-is-class-2 and $use-validation-mode">
               <!-- Now check the dependent class 2 document to see if there were any errors. -->
               <xsl:apply-templates select="$core-terse-expansion-pass-2" mode="class-2-expansion-terse-for-validation">
                  <xsl:with-param name="dependencies-adjusted-and-marked"
                     select="$dependencies-stripped-to-markers" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$this-is-class-2">
               <!-- Now check the dependent class 2 document to see if there were any errors. -->
               <xsl:apply-templates select="$core-terse-expansion-pass-2" mode="class-2-expansion-terse">
                  <xsl:with-param name="dependencies-adjusted-and-marked"
                     select="$dependencies-stripped-to-markers" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <!-- Yes, all the variables from pass 2 up to this point have been in service only to class 2 files -->
               <xsl:sequence select="$core-terse-expansion-pass-2"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      
      <!-- Some files, such as TAN-A-lm, need to have <tok> values ensconced before analyzing problems in other parts (assessing LM rules) -->
      <xsl:variable name="core-terse-expansion-pass-4" as="document-node()?">
         <xsl:choose>
            <xsl:when test="$this-is-tan-a-lm">
               <xsl:apply-templates select="$core-terse-expansion-pass-3"
                  mode="tan-a-lm-expansion-terse">
                  <xsl:with-param name="dependencies" as="document-node()*"
                     select="$dependencies-marked-pass-2" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$core-terse-expansion-pass-3"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics on for tan:expand-doc()'"/>
         <xsl:message select="'Expanding to', $phase-picked, 'phase on', $this-tan-type, 'with doc id', string($this-doc-id)"/>
         <xsl:message select="'Validation mode?', $use-validation-mode"/>
         <xsl:message select="'Terse expansion pass 1:', tan:xml-to-string($core-terse-expansion-pass-1)"/>
         <xsl:message select="'Dependencies resolved:', tan:xml-to-string($dependencies-resolved)"/>
         <xsl:message select="'Terse expansion pass 2:', tan:xml-to-string($core-terse-expansion-pass-2)"/>
         <xsl:if test="$this-is-class-2">
            <xsl:message select="concat('Reference trees (', string(count($reference-trees)),'): '), tan:xml-to-string($reference-trees)"/>
            <xsl:message select="concat('Adjustments part 1 (', string(count($adjustments-part-1)),'): '), tan:xml-to-string($adjustments-part-1)"/>
            <xsl:message select="concat('Adjustments part 2 (', string(count($adjustments-part-2)),'): '), tan:xml-to-string($adjustments-part-2)"/>
            <xsl:message select="'Make pass 1 adjustments?', $make-adjustments-pass-1"/>
            <xsl:if test="$make-adjustments-pass-1">
               <xsl:message select="'Dependencies adjusted pass 1a:', tan:xml-to-string($dependencies-adjusted-pass-1a)"/>
               <xsl:message select="concat('Pass 1a divs to reset (', string(count($adjustment-pass-1a-dependency-divs-to-reset)),'): '), tan:xml-to-string($adjustment-pass-1a-dependency-divs-to-reset)"/>
               <xsl:message select="'Divs that had fragment removed:', $adjustment-pass-1a-divs-with-attr-frag-from"/>
               <xsl:if test="exists($adjustment-pass-1a-dependency-divs-to-reset)">
                  <xsl:message select="'Dependencies adjusted pass 1b:', tan:xml-to-string($dependencies-adjusted-pass-1b)"/>
               </xsl:if>
            </xsl:if>
            <xsl:if test="exists($adjustments-part-2)">
               <xsl:message select="'Dependencies adjusted pass 2a:', tan:xml-to-string($dependencies-adjusted-pass-2a)"/>
               <xsl:message select="'Dependencies adjusted pass 2b:', tan:xml-to-string($dependencies-adjusted-pass-2b)"/>
            </xsl:if>
            <xsl:message select="'Dependencies marked pass 1:', tan:xml-to-string($dependencies-marked-pass-1)"/>
            <xsl:if test="not($use-validation-mode)">
               <xsl:message select="'Dependencies marked pass 2:', tan:xml-to-string($dependencies-marked-pass-2)"/>
            </xsl:if>
            <xsl:message select="'Dependencies stripped to markers:', tan:xml-to-string($dependencies-stripped-to-markers)"/>
            <xsl:message select="'Terse expansion pass 3:', tan:xml-to-string($core-terse-expansion-pass-3)"/>
            <xsl:message select="'Terse expansion pass 4:', tan:xml-to-string($core-terse-expansion-pass-4)"/>
         </xsl:if>
      </xsl:if>
      
      <!-- BEGINNING OF OUTPUT RESULTS -->
      
      <xsl:choose>
         <!-- Hard diagnostic feedback -->
         <xsl:when test="false()">
            <xsl:message select="'Replacing the output of tan:expand-doc() with diagnostic feedback'"/>
            <xsl:document>
               <expand-diagnostics>
                  <core-terse-pass-1><xsl:copy-of select="$core-terse-expansion-pass-1"/></core-terse-pass-1>
                  <!--<core-terse-pass-2><xsl:copy-of select="$core-terse-expansion-pass-2"/></core-terse-pass-2>-->
                  <xsl:if test="$this-is-class-2">
                     <!--<dependencies-resolved><xsl:copy-of select="$dependencies-resolved"/></dependencies-resolved>-->
                     <reference-trees count="{count($reference-trees)}"><xsl:copy-of select="$reference-trees"/></reference-trees>
                     <!--<adjustments-1><xsl:copy-of select="$adjustments-part-1"/></adjustments-1>-->
                     <!--<adjustments-2><xsl:copy-of select="$adjustments-part-2"/></adjustments-2>-->
                     <!--<make-adjustments-pass-1><xsl:value-of select="$make-adjustments-pass-1"/></make-adjustments-pass-1>-->
                     <!--<div-filters><xsl:copy-of select="$div-filters"/></div-filters>-->
                     <dep-adjusted-1a><xsl:copy-of select="$dependencies-adjusted-pass-1a"/></dep-adjusted-1a>
                     <dep-adj-1-divs-to-reset><xsl:copy-of select="$adjustment-pass-1a-dependency-divs-to-reset"/></dep-adj-1-divs-to-reset>
                     <!--<dep-adj-1-divs-with-attr-frag-from count="{count($adjustment-pass-1a-divs-with-attr-frag-from)}"><xsl:value-of select="$adjustment-pass-1a-divs-with-attr-frag-from"/></dep-adj-1-divs-with-attr-frag-from>-->
                     <dep-adjusted-1b><xsl:copy-of select="$dependencies-adjusted-pass-1b"/></dep-adjusted-1b>
                     <!--<dep-adjusted-2a><xsl:copy-of select="$dependencies-adjusted-pass-2a"/></dep-adjusted-2a>-->
                     <!--<dep-adjusted-2b><xsl:copy-of select="$dependencies-adjusted-pass-2b"/></dep-adjusted-2b>-->
                     <dep-marked-1><xsl:copy-of select="$dependencies-marked-pass-1"/></dep-marked-1>
                     <dep-marked-2><xsl:copy-of select="$dependencies-marked-pass-2"/></dep-marked-2>
                     <dep-stripped><xsl:copy-of select="$dependencies-stripped-to-markers"/></dep-stripped>
                  </xsl:if>
                  <core-terse-pass-3><xsl:copy-of select="$core-terse-expansion-pass-3"/></core-terse-pass-3>
                  <core-terse-pass-4><xsl:copy-of select="$core-terse-expansion-pass-4"/></core-terse-pass-4>
               </expand-diagnostics>
            </xsl:document>
         </xsl:when>
         
         <!-- Don't try to do anything if the input document itself is empty -->
         <xsl:when test="not(exists($tan-doc/*))"/>
         <!-- If the document is a collection, it gets treated specially (phases don't matter). -->
         <xsl:when test="name($tan-doc/*) = 'collection'">
            <xsl:apply-templates select="$tan-doc" mode="catalog-expansion-terse"/>
         </xsl:when>
         
         <!-- Terse, validation, all files -->
         <xsl:when test="($phase-picked eq 'terse') and $use-validation-mode">
            <xsl:apply-templates select="$core-terse-expansion-pass-4" mode="strip-for-validation"/>
         </xsl:when>

         <!-- All other files -->
         <xsl:when test="$phase-picked eq 'terse'">
            <xsl:sequence select="$core-terse-expansion-pass-4, $dependencies-marked-pass-2"/>
         </xsl:when>
         
         
         
         
         <xsl:otherwise>
            
            <!-- NORMAL EXPANSION ALL CLASSES -->
            
            <xsl:variable name="core-normal-expansion-pass-1" as="document-node()">
               <xsl:apply-templates select="$core-terse-expansion-pass-4" mode="core-expansion-normal">
                  <xsl:with-param name="dependencies" select="$dependencies-marked-pass-2" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            
            <!-- Class-2 files users might want help finding valid values for @ref, @pos, @rgx, @val, @chars -->
            <xsl:variable name="core-normal-expansion-pass-2" as="document-node()">
               <xsl:choose>
                  <xsl:when test="$this-is-class-2 and $use-validation-mode">
                     <xsl:apply-templates select="$core-normal-expansion-pass-1"
                        mode="class-2-expansion-normal">
                        <xsl:with-param name="dependencies" select="$dependencies-marked-pass-2"
                           tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:sequence select="$core-normal-expansion-pass-1"/>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>
            
            <xsl:choose>
               <xsl:when test="$use-validation-mode and ($phase-picked = 'normal')">
                  <xsl:apply-templates select="$core-normal-expansion-pass-2"
                     mode="strip-for-validation"/>
               </xsl:when>
               <xsl:when test="$phase-picked = 'normal'">
                  <xsl:copy-of select="$core-normal-expansion-pass-2, $dependencies-marked-pass-2"/>
               </xsl:when>
               
               
               
               
               <xsl:otherwise>
                  <!-- VERBOSE EXPANSION ALL CLASSES -->
                  
                  <xsl:variable name="core-verbose-expansion-pass-1" as="document-node()?">
                     <xsl:apply-templates select="$core-normal-expansion-pass-2" mode="core-expansion-verbose">
                        <xsl:with-param name="dependencies" select="$dependencies-marked-pass-2" tunnel="yes"/>
                     </xsl:apply-templates>
                  </xsl:variable>
                  
                  <xsl:variable name="core-verbose-expansion-pass-2" as="document-node()?">
                     <xsl:choose>
                        <xsl:when test="$this-class-number eq 1">
                           <!-- In the first pass, get the normalized text of each redivision, and the div structure of each model -->
                           <xsl:variable name="class-1-verbose-expansion-pass-1"
                              as="document-node()">
                              <xsl:apply-templates select="$core-verbose-expansion-pass-1"
                                 mode="class-1-expansion-verbose-pass-1"/>
                           </xsl:variable>
                           <xsl:variable name="class-1-verbose-expansion-pass-2"
                              as="document-node()">
                              <xsl:apply-templates select="$class-1-verbose-expansion-pass-1"
                                 mode="class-1-expansion-verbose-pass-2"/>
                           </xsl:variable>
                           <xsl:variable name="class-1-verbose-expansion-pass-3"
                              as="document-node()">
                              <xsl:apply-templates select="$class-1-verbose-expansion-pass-2"
                                 mode="class-1-expansion-verbose-pass-3"/>
                           </xsl:variable>
                           <xsl:sequence select="$class-1-verbose-expansion-pass-3"/>
                        </xsl:when>
                        
                        <xsl:when test="$this-is-class-2">
                           <xsl:apply-templates select="$core-verbose-expansion-pass-1"
                              mode="class-2-expansion-verbose"/>
                        </xsl:when>
                        
                        <xsl:otherwise>
                           <xsl:sequence select="$core-verbose-expansion-pass-1"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>
                  
                  <xsl:choose>
                     <xsl:when test="$use-validation-mode">
                        <xsl:apply-templates select="$core-verbose-expansion-pass-2"
                           mode="strip-for-validation"/>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:sequence
                           select="$core-verbose-expansion-pass-2, $dependencies-marked-pass-2"/>
                     </xsl:otherwise>
                  </xsl:choose>
                  
               </xsl:otherwise>
            </xsl:choose>
            
         </xsl:otherwise>
      </xsl:choose>

   </xsl:function>
   
   <xsl:function name="tan:build-parent-ref-tree" as="element()*">
      <!-- Input: any elements that are parents of <ref>s; an integer -->
      <!-- Output: the parent refs built into a tree; the integer is used to loop through the tree -->
      <!-- This assumes that there is only one <ref>, with constituent <n>s and a single text() that joins them into a reference -->
      <!-- If any <ref> lacks the requisite number of <n>s (2nd parameter) it will be ignored -->
      <xsl:param name="parent-refs" as="element()*"/>
      <xsl:param name="level-to-build" as="xs:integer"/>
      <xsl:param name="ref-so-far" as="xs:string?"/>
      
      <xsl:variable name="next-level" select="$level-to-build + 1"/>
      
      <xsl:choose>
         <xsl:when test="not(exists($parent-refs))"/>
         <xsl:otherwise>
            <xsl:for-each-group select="$parent-refs" group-by="tan:ref/tan:n[$level-to-build]">
               <xsl:variable name="this-n" select="current-grouping-key()"/>
               <xsl:variable name="this-ref" select="string-join(($ref-so-far, $this-n), $separator-hierarchy)"/>
               <xsl:variable name="items-to-deposit-here" select="current-group()[not(exists(tan:ref/tan:n[$next-level]))]"/>
               <div>
                  <n><xsl:value-of select="$this-n"/></n>
                  <ref><xsl:value-of select="$this-ref"/></ref>
                  <xsl:copy-of select="$items-to-deposit-here"/>
                  <xsl:copy-of
                     select="tan:build-parent-ref-tree((current-group() except $items-to-deposit-here), $next-level, $this-ref)"
                  />
               </div>
            </xsl:for-each-group> 
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
                  <xsl:value-of select="text()"/>
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

   <xsl:template match="comment()" mode="core-expansion-terse-attributes">
      <xsl:param name="use-validation-mode" tunnel="yes" select="$is-validation"/>
      <xsl:if test="not($use-validation-mode)">
         <xsl:copy-of select="."/>
      </xsl:if>
   </xsl:template>

   <xsl:template match="/*" priority="1" mode="core-expansion-terse-attributes">
      <xsl:param name="use-validation-mode" tunnel="yes" select="$is-validation"/>
      
      <xsl:variable name="ambig-is-roman" select="not(tan:head/tan:numerals/@priority = 'letters')"/>
      <xsl:variable name="vocabulary-nodes" select="tan:head, self::tan:TAN-A/tan:body, self::tan:TAN-voc/tan:body"/>
      <xsl:variable name="this-is-class-2" select="starts-with(name(.), 'TAN-A')"/>
      
      <xsl:variable name="these-pointing-attrs"
         select="key('attrs-by-name', ($names-of-attributes-that-take-idrefs, 'which'), .)"/>

      <!-- Master check of @which and attributes that point to vocabulary items -->
      <xsl:variable name="all-descendant-insertions" as="element()*">
         
         <!-- Attributes that take idref: values that must be resolved in light of file context -->
         <!-- Group 1: by attribute name; if @which, qualified by parent name -->
         <xsl:for-each-group select="$these-pointing-attrs"
            group-by="
               concat(name(.), (if (name(.) = 'which') then
                  concat(' ', name(..))
               else
                  ()))">
            <xsl:variable name="grouping-keys" select="tokenize(current-grouping-key(), ' ')"/>
            <xsl:variable name="this-attr-name" select="$grouping-keys[1]"/>
            <xsl:variable name="this-parent-name" select="$grouping-keys[2]"/>
            <xsl:variable name="this-is-which" select="$this-attr-name = 'which'"/>
            <xsl:variable name="these-target-element-names"
               select="
                  if ($this-is-which) then
                     tan:target-element-names($this-parent-name)
                  else
                     tan:target-element-names($this-attr-name)"
            />
            
            <!-- Group 2: by inclusion -->
            <xsl:for-each-group select="current-group()"
               group-by="(ancestor::*[@include][1]/@include, '')[1]">
               <xsl:variable name="this-include-idref" select="current-grouping-key()"/>
               <xsl:variable name="these-appropriate-vocabulary-nodes"
                  select="
                     if (string-length($this-include-idref) gt 0) then
                        $vocabulary-nodes//tan:inclusion[@xml:id = $this-include-idref]
                     else
                        $vocabulary-nodes"/>
               <xsl:variable name="these-appropriate-vocabulary-nodes-without-inclusions"
                  as="element()*">
                  <xsl:choose>
                     <xsl:when test="string-length($this-include-idref) gt 0">
                        <xsl:apply-templates select="$vocabulary-nodes" mode="remove-inclusions">
                           <xsl:with-param name="idref-exceptions" tunnel="yes"
                              select="$this-include-idref"/>
                        </xsl:apply-templates>
                     </xsl:when>
                     <xsl:otherwise>
                        <xsl:sequence select="$vocabulary-nodes"/>
                     </xsl:otherwise>
                  </xsl:choose>
               </xsl:variable>

               <xsl:variable name="empty-attrs" select="current-group()[. = '']"/>

               <context include="{$this-include-idref}">
                  <xsl:if test="exists($empty-attrs)">
                     <xsl:variable name="this-message"
                        select="concat($this-attr-name, ' has zero-length value')"/>
                     <insertion>
                        <xsl:copy-of select="$empty-attrs[1]"/>
                        <xsl:copy-of
                           select="
                              if ($this-is-which) then
                                 tan:error('whi01')
                              else
                                 tan:error('tan05')"
                        />
                     </insertion>
                  </xsl:if>
                  <!-- Group 3: by atomic value -->
                  <xsl:for-each-group select="current-group()"
                     group-by="
                        if ($this-is-which) then
                           tan:normalize-name(.)
                        else
                           tokenize(normalize-space(.), ' ')">
                     <xsl:variable name="this-val" select="current-grouping-key()"/>
                     <xsl:variable name="this-is-joker" select="$this-val = '*'"/>
                     <xsl:variable name="these-vals"
                        select="
                           if (not($this-is-which)) then
                              tokenize(normalize-space(.), ' ')
                           else
                              ()"/>
                     <xsl:variable name="variable-repeats-itself"
                        select="count($these-vals[. = $this-val]) gt 1"/>
                     <xsl:variable name="this-val-esc" select="tan:escape($this-val)"/>
                     <!--<xsl:variable name="these-qs" select="current-group()/../@q"/>-->

                     <xsl:variable name="this-val-without-help-request"
                        select="tan:help-extracted($this-val)"/>
                     <xsl:variable name="this-val-name-normalized"
                        select="tan:normalize-name($this-val-without-help-request)"/>

                     <xsl:variable name="this-vocabulary"
                        select="tan:vocabulary($these-target-element-names, $this-val-without-help-request, $these-appropriate-vocabulary-nodes-without-inclusions)"/>
                     <xsl:variable name="these-vocabulary-items"
                        select="$this-vocabulary/(* except (tan:IRI, tan:name, tan:desc))"/>
                     <xsl:variable name="all-permissible-vocabulary-items"
                        select="tan:vocabulary($these-target-element-names, (), $vocabulary-nodes)"/>
                     <xsl:variable name="vocab-items-available"
                        select="$this-vocabulary/(* except tan:IRI, tan:name, tan:desc)"/>
                     <xsl:variable name="vocab-items-pointed-to-by-id"
                        select="$vocab-items-available[(tan:id, tan:alias) = $this-val-without-help-request]"/>
                     <xsl:variable name="vocab-items-pointed-to-by-name"
                        select="
                           if (not(exists($vocab-items-pointed-to-by-id))) then
                              $vocab-items-available[tan:name = $this-val-name-normalized]
                           else
                              ()"/>
                     <xsl:variable name="this-item-vocabulary"
                        select="
                           if (exists($vocab-items-pointed-to-by-id)) then
                              $vocab-items-pointed-to-by-id
                           else
                              $vocab-items-pointed-to-by-name"/>
                     <xsl:variable name="item-is-erroneous"
                        select="not($this-is-joker) and not(exists($this-item-vocabulary))"/>

                     <xsl:if test="$variable-repeats-itself">
                        <insertion>
                           <xsl:copy-of select="current-group()[1]"/>
                           <xsl:copy-of
                              select="tan:error('tan21', concat($this-val, ' need not be repeated'))"
                           />
                        </insertion>
                     </xsl:if>

                     <!-- Group 4: by non-atomized value, so matches are easier -->
                     <xsl:for-each-group select="current-group()" group-by=".">
                        <insertion>
                           <!-- We copy the attribute + value directly into insertion so that it can be found using
                           deep-equal later. If this is @which, however, then the parent context also needs to be 
                           clarified. -->
                           <xsl:copy-of select="current-group()[1]"/>
                           <xsl:if test="$this-is-which">
                              <xsl:attribute name="parent" select="$this-parent-name"/>
                           </xsl:if>
                           <!-- If tan:vocabulary() finds errors, copy them. -->
                           <xsl:copy-of select="$this-vocabulary/self::tan:error"/>
                           <xsl:if test="$item-is-erroneous">
                              <xsl:variable name="this-message"
                                 select="concat($this-val, ' matches no id')"/>
                              <xsl:variable name="this-fix" as="element()?">
                                 <xsl:if test="string-length($these-target-element-names[1]) gt 0">
                                    <xsl:element name="{$these-target-element-names[1]}">
                                       <xsl:attribute name="xml:id" select="$this-val"/>
                                       <xsl:attribute name="which"/>
                                    </xsl:element>
                                 </xsl:if>
                              </xsl:variable>
                              <xsl:copy-of
                                 select="
                                    if ($this-is-which) then
                                       tan:error('whi01', $this-message, $this-fix, 'add-vocabulary-key-item')
                                    else
                                       tan:error('tan05', $this-message, $this-fix, 'add-vocabulary-key-item')"/>
                           </xsl:if>
                           <xsl:if
                              test="exists($this-val-without-help-request/@help) or $item-is-erroneous">
                              <xsl:variable name="this-fix" as="element()*">
                                 <xsl:for-each
                                    select="$all-permissible-vocabulary-items/*[name() = ('item', $these-target-element-names)]">
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
                              <xsl:copy-of
                                 select="tan:help($this-message, $this-fix, 'copy-attributes')"/>
                           </xsl:if>

                           <xsl:element name="{$this-attr-name}">
                              <xsl:attribute name="attr"/>
                              <xsl:value-of select="$this-val"/>
                              <xsl:choose>
                                 <xsl:when test="$use-validation-mode">
                                    <!-- In validation mode we are concerned ultimately with IRIs, which we copy as a way to check to see if
                                    two different idrefs somehow nevertheless point to the same IRI. But that means that any query on the 
                                    new <[name] attr=""> must point to the one text node inside for the proper value -->
                                    <xsl:for-each-group
                                       select="$this-item-vocabulary/descendant::tan:IRI"
                                       group-by=".">
                                       <xsl:copy-of select="current-group()[1]"/>
                                    </xsl:for-each-group>
                                 </xsl:when>
                                 <xsl:when test="$distribute-vocabulary">
                                    <!-- Vocabulary is distributed in situations where a TAN file is being prepared for HTML, etc. But if the
                              purpose is validation, there is no point. -->

                                    <!-- we regularize item vocabulary to tan:item, so that an embedded vocabulary definition can be easily and consistently found -->
                                    <xsl:copy-of select="$this-item-vocabulary/self::tan:item"/>
                                    <xsl:for-each
                                       select="$this-item-vocabulary[not(self::tan:item)]">
                                       <item>
                                          <xsl:copy-of select="@*"/>
                                          <affects-element>
                                             <xsl:value-of select="name(.)"/>
                                          </affects-element>
                                          <xsl:copy-of select="node()"/>
                                       </item>
                                    </xsl:for-each>
                                 </xsl:when>
                              </xsl:choose>

                           </xsl:element>

                           <!-- The values might yield vocabulary ids that aren't in the original values (e.g., '*'), so expansion should include them -->
                           <xsl:if test="$this-is-joker">
                              <xsl:for-each select="$this-vocabulary/*[@xml:id]">
                                 <xsl:element name="{$this-attr-name}">
                                    <xsl:attribute name="attr"/>
                                    <xsl:value-of select="@xml:id"/>
                                    <xsl:choose>
                                       <xsl:when test="$use-validation-mode">
                                          <xsl:copy-of select="descendant::tan:IRI"/>
                                       </xsl:when>
                                       <xsl:when test="$distribute-vocabulary">
                                          <xsl:copy-of select="."/>
                                       </xsl:when>
                                    </xsl:choose>
                                 </xsl:element>
                              </xsl:for-each>
                           </xsl:if>

                           <xsl:if
                              test="not($this-is-which) and not(current-group()[1] = $this-val)">
                              <xsl:variable name="these-itemized-vals" select="tokenize(., ' ')"/>
                              <xsl:variable name="these-dup-vals"
                                 select="tan:duplicate-items($these-itemized-vals)"/>
                              <xsl:if test="$this-val = $these-dup-vals">
                                 <xsl:copy-of
                                    select="tan:error('tan06', concat('repeated value: ', $this-val))"
                                 />
                              </xsl:if>
                           </xsl:if>
                        </insertion>
                     </xsl:for-each-group>
                  </xsl:for-each-group>
               </context>
            </xsl:for-each-group>

         </xsl:for-each-group>
         
      </xsl:variable>
      
      <xsl:variable name="regex-u-values" as="element()?">
         <xsl:if test="$this-is-class-2">
            <regex-u-values>
               <xsl:for-each-group
                  select="key('attrs-by-name', ('pattern', 'matches-m', 'matches-tok', 'rgx'), .)[matches(., '\\u')]"
                  group-by=".">
                  <regex>
                     <in>
                        <xsl:value-of select="current-grouping-key()"/>
                     </in>
                     <out>
                        <xsl:value-of select="tan:regex(current-grouping-key())"/>
                     </out>
                  </regex>
               </xsl:for-each-group>
            </regex-u-values>
         </xsl:if>
      </xsl:variable>
      
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="ambig-is-roman" select="$ambig-is-roman" tunnel="yes"/>
            <xsl:with-param name="vocabulary-nodes" select="$vocabulary-nodes"
               tunnel="yes"/>
            <xsl:with-param name="insertions" tunnel="yes" as="element()*"
               select="$all-descendant-insertions"/>
            <xsl:with-param name="regex-u-values" tunnel="yes" select="$regex-u-values"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tei:teiHeader"
      mode="core-expansion-terse-attributes">
      <xsl:param name="use-validation-mode" tunnel="yes" select="$is-validation"/>
      <!-- the contents of teiHeadercannot be predicted, so is useless for validation, but important for
         applications-->
      <xsl:if test="not($use-validation-mode)">
         <xsl:copy-of select="."/>
      </xsl:if>
   </xsl:template>
   
   <xsl:template match="tan:head[tan:adjustments]" priority="1"
      mode="core-expansion-terse-attributes">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="try-to-expand-ranges" tunnel="yes" as="xs:boolean" select="true()"
            />
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:head/tan:vocabulary[tan:location] | tan:head/tan:tan-vocabulary"
      priority="1"
      mode="core-expansion-terse-attributes">
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="*[@*]" mode="core-expansion-terse-attributes">
      <xsl:param name="insertions" tunnel="yes" as="element()*"/>
      <xsl:param name="include-idref" as="xs:string" select="''"/>
      
      <xsl:variable name="this-include-idref" as="xs:string" select="(@include, $include-idref)[1]"/>
      <xsl:variable name="this-element-name" select="name(.)"/>
      
      <xsl:variable name="these-insertions" select="$insertions[@include = $include-idref]"/>
      
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates select="@*" mode="core-expansion-terse-attributes-to-elements">
            <xsl:with-param name="insertions" select="$these-insertions" tunnel="yes"/>
            <xsl:with-param name="parent-name" select="$this-element-name"/>
         </xsl:apply-templates>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="include-idref" select="$this-include-idref"/>
         </xsl:apply-templates>
      </xsl:copy>
      
   </xsl:template>
   
   <xsl:template match="@*" mode="core-expansion-terse-attributes-to-elements">
      <xsl:param name="insertions" tunnel="yes" as="element()*"/>
      <xsl:param name="use-validation-mode" tunnel="yes" select="$is-validation"/>
      <xsl:param name="parent-name" as="xs:string?"/>
      
      <xsl:variable name="this-attr" select="."/>
      <xsl:variable name="these-insertions"
         select="$insertions/tan:insertion[@*[deep-equal(., $this-attr)]][not(@parent) or (@parent = $parent-name)]/*"
      />
      <xsl:variable name="these-duplicate-IRIs" select="tan:duplicate-values($these-insertions/tan:IRI)"/>
      <xsl:if test="exists($these-duplicate-IRIs)">
         <xsl:variable name="this-message-parts" as="xs:string*">
            <xsl:for-each select="$these-duplicate-IRIs">
               <xsl:variable name="this-dup-iri" select="."/>
               <xsl:variable name="these-vals" select="$these-insertions[tan:IRI = $this-dup-iri]/text()"/>
               <xsl:value-of select="concat(string-join($these-vals, ', '), ' redundantly point(s) to a vocabulary item with IRI ', $this-dup-iri)"/>
            </xsl:for-each> 
         </xsl:variable>
         <xsl:copy-of select="tan:error('tan21', string-join($this-message-parts, '; '))"/>
      </xsl:if>
      <xsl:for-each select="$these-insertions">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
               <xsl:when test="$use-validation-mode">
                  <!-- We do not copy the IRI, which were included solely to identify duplicates -->
                  <xsl:copy-of select="node() except tan:IRI"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="node()"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:copy>
      </xsl:for-each>

   </xsl:template>
   
   <xsl:template match="@xml:id | @id" mode="core-expansion-terse-attributes-to-elements">
      <xsl:if test=". = $duplicate-ids">
         <xsl:variable name="this-id" select="."/>
         <xsl:variable name="competing-id-attrs" select="($all-ids except .)[. = $this-id]"/>
         <xsl:variable name="this-message" as="xs:string*">
            <xsl:value-of select="concat(string(.), ' is already in use by ')"/>
            <xsl:for-each select="$competing-id-attrs">
               <xsl:value-of select="concat(tan:path(..), ' ')"/>
            </xsl:for-each>
         </xsl:variable>
         <xsl:copy-of select="tan:error('tan03', string-join($this-message, ''))"/>
      </xsl:if>
   </xsl:template>
   <xsl:template match="@from | @to | tan:*/@when | @ed-when | @accessed-when" mode="core-expansion-terse-attributes-to-elements">
      <!-- We do not expand into elements any attribute that is a single value -->
      <xsl:variable name="this-val-parsed" select="tan:help-extracted(.)" as="element()?"/>
      <xsl:variable name="this-datetime" select="tan:dateTime-to-decimal($this-val-parsed)"/>
      <xsl:if test="$this-datetime > $now">
         <xsl:copy-of
            select="tan:error('whe02', concat(., ' is a time/date in the future. It is currently ', string(current-dateTime())))"/>
      </xsl:if>
      <xsl:if test="name(.) = 'from'">
         <xsl:variable name="this-to" select="../@to"/>
         <xsl:variable name="that-datetime" select="tan:dateTime-to-decimal($this-to)"/>
         <xsl:if test="$this-datetime gt $that-datetime">
            <xsl:copy-of select="tan:error('whe03')"/>
         </xsl:if>
         <xsl:if test="exists($this-val-parsed)"></xsl:if>
      </xsl:if>
   </xsl:template>
   <xsl:template match="@pattern | @matches-m | @matches-tok | @rgx" mode="core-expansion-terse-attributes-to-elements">
      <xsl:param name="regex-u-values" tunnel="yes" as="element()?"/>
      <xsl:variable name="this-val-norm" select="tan:help-extracted(.)"/>
      <xsl:variable name="regex-is-valid" select="tan:regex-is-valid($this-val-norm)"/>
      <xsl:variable name="this-matching-u-value" select="$regex-u-values/tan:regex[tan:in = $this-val-norm]"/>
      <xsl:if test="not($regex-is-valid)">
         <xsl:copy-of select="tan:error('tan07')"/>
      </xsl:if>
      <xsl:element name="{name()}" namespace="tag:textalign.net,2015:ns">
         <xsl:copy-of select="$this-val-norm/@*"/>
         <!-- a faulty regular expression will be flagged as erroneous in the parent; its value should be suppressed, to avoid fatal errors -->
         <xsl:choose>
            <xsl:when test="$regex-is-valid and exists($this-matching-u-value)">
               <xsl:value-of select="$this-matching-u-value/tan:out"/>
            </xsl:when>
            <xsl:when test="$regex-is-valid">
               <xsl:value-of select="."/>
            </xsl:when>
         </xsl:choose>
      </xsl:element>
   </xsl:template>
   <xsl:template match="@href" mode="core-expansion-terse-attributes-to-elements">
      <!-- no need to convert to element -->
      <xsl:variable name="parent-name" select="name(..)"/>
      <xsl:variable name="this-href" select="."/>
      <xsl:if
         test="exists(parent::tan:master-location) and (matches(., '!/') or ends-with(., 'docx') or ends-with(., 'zip'))">
         <xsl:copy-of select="tan:error('tan15')"/>
      </xsl:if>
      <xsl:if test=". eq $doc-uri">
         <xsl:copy-of select="tan:error('tan17')"/>
      </xsl:if>
      <xsl:if test="not(ends-with($parent-name, 'location'))">
         <xsl:choose>
            <xsl:when test="not(tan:url-is-local($this-href)) and not($internet-available)"/>
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
               <xsl:variable name="this-parent" select=".."/>
               <xsl:variable name="this-fix" as="element()">
                  <xsl:element name="{name($this-parent)}">
                     <xsl:copy-of select="$this-parent/(@* except (@href, @orig-href, @q))"/>
                     <IRI>
                        <xsl:value-of select="$target-IRI"/>
                     </IRI>
                     <xsl:copy-of select="$target-name"/>
                     <xsl:copy-of select="$target-desc"/>
                     <location accessed-when="{current-dateTime()}"
                        href="{tan:uri-relative-to(@href, $doc-uri)}"/>
                  </xsl:element>
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
   </xsl:template>
   
   <xsl:template match="@ref | @pos | @chars | tan:equate/@n | tan:skip/@n | tan:rename/@n" mode="core-expansion-terse-attributes-to-elements">
      <!-- gets converted to one element per atomic value -->
      <xsl:param name="ambig-is-roman" as="xs:boolean?" tunnel="yes"/>
      <xsl:param name="try-to-expand-ranges" as="xs:boolean" tunnel="yes" select="false()"/>
      <!-- analysis of class-2 file attributes that point to source class-1 files -->
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="this-val-analyzed"
         select="tan:analyze-sequence(., $this-name, $try-to-expand-ranges, $ambig-is-roman)"/>
      <xsl:variable name="this-attr-converted-to-elements"
         select="tan:stamp-q-id($this-val-analyzed/*, true())"/>
      <xsl:copy-of select="$this-attr-converted-to-elements"/>
   </xsl:template>
   
   <xsl:template match="*[@val]/@chars" priority="1" mode="core-expansion-terse-attributes-to-elements">
      <xsl:variable name="this-val" select="../@val"/>
      <xsl:variable name="this-val-length" select="count(tan:chop-string($this-val))"/>
      <xsl:variable name="these-integers" select="tan:expand-numerical-sequence(., $this-val-length)"/>
      <xsl:copy-of select="tan:sequence-error($these-integers, concat($this-val, ' has only ', string($this-val-length), ' characters.'))"/>
   </xsl:template>
   
   <xsl:template match="*[@ref]/@new" mode="core-expansion-terse-attributes-to-elements">
      <!-- gets converted to one element per atomic value -->
      <xsl:param name="ambig-is-roman" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="this-val-analyzed"
         select="tan:analyze-sequence(., 'ref', true(), $ambig-is-roman)"/>
      <xsl:variable name="this-attr-converted-to-elements"
         select="tan:stamp-q-id($this-val-analyzed/*, true())"/>
      <new q="{generate-id(.)}">
         <xsl:copy-of select="$this-attr-converted-to-elements"/>
      </new>
   </xsl:template>
   <xsl:template match="*[@n]/@new" mode="core-expansion-terse-attributes-to-elements">
      <!-- gets converted to one element per atomic value -->
      <xsl:param name="ambig-is-roman" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="this-val-analyzed"
         select="tan:analyze-sequence(., 'n', true(), $ambig-is-roman)"/>
      <xsl:variable name="this-attr-converted-to-elements"
         select="tan:stamp-q-id($this-val-analyzed/*, true())"/>
      <new q="{generate-id(.)}">
         <xsl:copy-of select="$this-attr-converted-to-elements"/>
      </new>
   </xsl:template>
   
   <xsl:template match="@val | @by" mode="core-expansion-terse-attributes-to-elements">
      <xsl:variable name="this-val-parsed" select="tan:help-extracted(.)"/>
      <xsl:variable name="this-q-id" select="generate-id(.)"/>
      <xsl:element name="{name(.)}">
         <xsl:attribute name="q" select="$this-q-id"/>
         <xsl:value-of select="."/>
      </xsl:element>
   </xsl:template>
   
   <xsl:template match="@code | @div-type | @affects-element | @affects-attribute | @item-type | @in-lang" mode="core-expansion-terse-attributes-to-elements">
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
               $this-val-parsed/text()"
      />
      <xsl:variable name="these-vals-2"
         select="
            if ($render-lowercase) then
               for $i in $these-vals-1
               return
                  lower-case($i)
            else
               $these-vals-1"
      />
      <xsl:for-each select="$these-vals-2">
         <xsl:element name="{$this-name}" namespace="tag:textalign.net,2015:ns">
            <xsl:attribute name="attr"/>
            <xsl:value-of select="."/>
         </xsl:element>
      </xsl:for-each>
   </xsl:template>
   
   <xsl:template match="tan:inclusion" mode="remove-inclusions">
      <xsl:param name="idref-exceptions" tunnel="yes" as="xs:string*"/>
      <xsl:if test="@xml:id = $idref-exceptions">
         <xsl:copy-of select="."/>
      </xsl:if>
   </xsl:template>

   
   <!--<xsl:template match="@*" mode="core-expansion-terse-attributes">
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
            <xsl:choose>
               <!-\- a faulty regular expression will be flagged as erroneous in the parent; its value should be suppressed, to avoid fatal errors -\->
               <xsl:when test="$this-name = 'rgx' and not(tan:regex-is-valid(.))"/>
               <xsl:otherwise>
                  <xsl:value-of select="."/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:element>
      </xsl:for-each>
   </xsl:template>-->
   

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
         select="tan:duplicate-items(tan:token-definition/tan:src[text()])"/>
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

   <xsl:template match="*[@which]/tan:id" mode="core-expansion-terse">
      <xsl:copy-of select="."/>
      <xsl:if test=". eq ../@which">
         <xsl:copy-of select="tan:error('tan12')"/>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tan:name" mode="core-expansion-terse">
      <!-- parameters below are populated only in TAN-voc files -->
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
            <xsl:copy-of select="tan:error('cl202', concat('Duplicates: ', string-join($token-definition-errors, ', ')))"/>
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
      <xsl:variable name="who-vocab" select="tan:vocabulary(('person', 'organization'), $these-whos, (parent::tan:head, root(.)/(tan:TAN-A, tan:TAN-voc)/tan:body))"/>
      <xsl:variable name="this-doc-id-namespace" select="tan:doc-id-namespace(.)"/>
      <xsl:variable name="key-agent"
         select="$who-vocab/*[tan:IRI[starts-with(., $this-doc-id-namespace)]]"/>
      
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
      <!-- Text should have already been subject to tan:normalize-text() in the terse phase. This routine checks for other anomalies. -->
      <xsl:variable name="this-text" select="."/>
      <xsl:variable name="this-text-unicode-normalized" select="normalize-unicode(.)"/>
      <xsl:if test="$this-text != $this-text-unicode-normalized">
         <xsl:copy-of
            select="tan:error('tan04', concat('Should be: ', $this-text-unicode-normalized), $this-text-unicode-normalized, 'replace-text')"
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
      <xsl:value-of select="."/>
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
