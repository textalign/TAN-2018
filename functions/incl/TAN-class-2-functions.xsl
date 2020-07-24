<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:fn="http://www.w3.org/2005/xpath-functions"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:xi="http://www.w3.org/2001/XInclude" exclude-result-prefixes="#all" version="2.0">

   <!-- Core functions for class 2 files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:key name="tok-via-ref" match="tan:tok" use="tan:ref/text()"/>

   <!-- GLOBAL VARIABLES AND PARAMETERS -->
   <!-- Source picking and identification -->
   <xsl:variable name="src-ids" as="xs:string*">
      <xsl:for-each select="$head/tan:source">
         <xsl:value-of select="(@xml:id, string(position()))[1]"/>
      </xsl:for-each>
   </xsl:variable>

   <!-- FUNCTIONS -->

   <!-- PROCESSING CLASS 2 DOCUMENTS AND THEIR DEPENDENCIES -->

   <!-- EXPANDING -->

   <!-- TERSE EXPANSION -->
   <!-- core -->

   <xsl:template match="tan:source | tan:morphology[not(@attr)]" mode="core-expansion-terse">
      <xsl:variable name="is-first-link-element" select="not(exists(preceding-sibling::tan:source))"/>
      <xsl:if test="$is-first-link-element">
         <xsl:variable name="other-token-definitions" select="preceding-sibling::tan:token-definition"/>
         <xsl:variable name="src-ids-not-defined" select="../tan:source[not(@xml:id = $other-token-definitions/tan:src)]/@xml:id"/>
         <xsl:if test="exists($src-ids-not-defined)">
            <token-definition>
               <xsl:copy-of select="$token-definition-default/@*"/>
               <xsl:for-each select="$src-ids-not-defined">
                  <src>
                     <xsl:value-of select="."/>
                  </src>
               </xsl:for-each>
            </token-definition>
         </xsl:if>
      </xsl:if>
      <!-- dependencies must be evaluated at the terse stage -->
      <xsl:apply-templates select="." mode="check-referred-doc"/>
   </xsl:template>

   <xsl:template match="tan:rename" mode="core-expansion-terse">
      <xsl:variable name="these-refs" select="tan:ref"/>
      <xsl:variable name="these-news" select="tan:new"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="@new = (tan:n, $these-refs)">
            <xsl:copy-of select="tan:error('cl203')"/>
         </xsl:if>
         <xsl:if
            test="exists($these-refs) and exists($these-news) and not(count($these-refs) = count($these-news/tan:ref))">
            <xsl:copy-of select="tan:error('cl216')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:rename/tan:by" mode="core-expansion-terse">
      <xsl:variable name="these-ns" select="../tan:n, ../tan:ref/tan:n[last()]"/>
      <xsl:variable name="these-n-types" select="for $i in $these-ns return 
         tan:analyze-numbers-in-string($i, true(), ())"/>
      <xsl:if test="exists($these-n-types/@non-number)">
         <xsl:copy-of select="tan:error('cl213')"/>
      </xsl:if>
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:tok[not(tan:from)] | tan:tok/tan:from | tan:tok/tan:to |
      tan:from-tok | tan:through-tok"
      mode="core-expansion-terse">
      <xsl:param name="is-tan-a-lm" tunnel="yes"/>
      <xsl:param name="is-for-lang" tunnel="yes"/>
      <xsl:param name="use-validation-mode" tunnel="yes" as="xs:boolean?" select="$is-validation"/>
      <xsl:variable name="is-general-tok-claim" select="self::tan:tok[not(@ref)] and $is-tan-a-lm"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <!-- The <tok> in a TAN-A-lm file needs to have a <src> added if it is source-specific, and a <result> added if it is not -->
         <xsl:if test="$is-tan-a-lm">
            <xsl:choose>
               <xsl:when test="$is-for-lang">
                  <result>
                     <xsl:value-of select="@val, @rgx"/>
                  </result>
               </xsl:when>
               <xsl:otherwise>
                  <src>1</src>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
         <xsl:if test="not(exists(@pos))">
            <!-- <pos> becomes the prime way to identify any token @rgx/@val + @pos combo, so needs a @q -->
            <!-- For universal <tok>s found in TAN-A-lm files, i.e., those without @ref, the implication is 1-last -->
            <pos attr="" q="{generate-id()}" from="">1</pos>
            <xsl:if test="not($use-validation-mode)">
               <xsl:variable name="this-extra-pos" as="element()">
                  <pos/>
               </xsl:variable>
               <xsl:for-each select="$this-extra-pos">
                  <xsl:copy>
                     <xsl:attribute name="attr"/>
                     <xsl:attribute name="to"/>
                     <xsl:attribute name="q" select="generate-id()"/>
                     <xsl:text>last</xsl:text>
                  </xsl:copy>
               </xsl:for-each>
            </xsl:if>
         </xsl:if>
         <xsl:if test="not(exists(@val)) and not(exists(@rgx))">
            <rgx attr="">.+</rgx>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template
      match="
         tan:adjustments/tan:skip/tan:div-type |
         tan:adjustments/tan:*/tan:ref | tan:adjustments/tan:*/tan:n | tan:passage/tan:ref"
      mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="q" select="generate-id(.)"/>
         <xsl:if test="parent::tan:to">
            <!-- We prime the reset-hierarchy operation for reassign/to/ref -->
            <xsl:attribute name="reset"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <!-- class 2 -->
   
   <xsl:template match="tan:skip/tan:div-type | tan:skip/tan:n | tan:rename/tan:n | tan:passage
      | tan:from-tok | tan:through-tok | tan:rename | tan:reassign"
      mode="class-2-expansion-terse class-2-expansion-terse-for-validation">
      <xsl:param name="dependencies-adjusted-and-marked" as="document-node()*" tunnel="yes"/>
      <!-- This is the generic, default template to flag class 2 elements that must be marked in the source class 1 files -->
      <xsl:variable name="these-src-id-nodes" select="ancestor-or-self::*[tan:src][1]"/>
      <xsl:variable name="these-src-ids" select="$these-src-id-nodes/tan:src/text()"/>
      <xsl:variable name="this-name" select="name(.)"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="these-errors" as="element()*">
         <xsl:for-each select="$dependencies-adjusted-and-marked[*/@src = $these-src-ids]">
            <xsl:variable name="this-src-id" select="*/@src"/>
            <xsl:variable name="these-markers" select="key('q-ref', $this-q, .)"/>
            <xsl:choose>
               <xsl:when test="exists($these-markers)"/>
               <xsl:when test="$this-name = 'div-type'">
                  <xsl:copy-of select="tan:error('dty01')"/>
               </xsl:when>
               <xsl:when test="$this-name = 'n'">
                  <xsl:copy-of select="tan:error('cl215')"/>
               </xsl:when>
               <!-- we don't bother to signal a missing <passage>, which gets flagged at the from/through-tok level -->
            </xsl:choose>
            <xsl:copy-of select="$these-markers/(tan:error, tan:warning)"/>
         </xsl:for-each>
      </xsl:variable>
      
      <xsl:if test="exists(@attr)">
         <xsl:copy-of select="$these-errors"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(exists(@attr))">
            <xsl:copy-of select="$these-errors"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:equate" mode="class-2-expansion-terse class-2-expansion-terse-for-validation">
      <!-- equate locators should be more forgiving than other adjustment locators: you do not want every value of @n to match each source, only one combination -->
      <xsl:param name="dependencies-adjusted-and-marked" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="these-src-id-nodes" select="ancestor-or-self::*[tan:src][1]"/>
      <xsl:variable name="these-src-ids" select="$these-src-id-nodes/tan:src"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="these-ns" select="tan:n"/>
      <xsl:variable name="duplicate-ns" select="tan:duplicate-items($these-ns)"/>
      <xsl:variable name="these-equate-markers" as="element()*">
         <xsl:for-each select="$dependencies-adjusted-and-marked[*/@src = $these-src-ids]">
            <xsl:variable name="this-src-id" select="*/@src"/>
            <xsl:variable name="these-markers" select="key('q-ref', $this-q, .)"/>
            <xsl:sequence select="$these-markers"/>
            <xsl:if test="not(exists($these-markers))">
               <missing>
                  <xsl:value-of select="$this-src-id"/>
               </missing>
            </xsl:if>
         </xsl:for-each>
      </xsl:variable>
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for template mode: class-2-expansion-terse'"/>
         <xsl:message select="'this equate: ', ."/>
         <xsl:message select="'src ids: ', $these-src-ids"/>
         <xsl:message select="'equate markers: ', $these-equate-markers"/>
      </xsl:if>
      
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($these-equate-markers/self::tan:missing)">
               <xsl:copy-of select="tan:error('cl207', concat(string-join($these-equate-markers/self::tan:missing, ', '), ' lack(s) any div whose @n = ', string-join($these-ns, ', ')))"/>
         </xsl:if>
         <xsl:if test="exists($duplicate-ns)">
            <xsl:copy-of select="tan:error('cl205', concat('Duplicates: ', string-join(distinct-values($duplicate-ns), ', ')))"/>
         </xsl:if>
         <xsl:copy-of select="$these-equate-markers/(descendant-or-self::tan:error, descendant-or-self::tan:warning)"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:to/tan:ref | tan:new/tan:ref" mode="class-2-expansion-terse class-2-expansion-terse-for-validation">
      <!-- these refs do not assume the ref exists in the target sources -->
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <xsl:template match="tan:ref"
      mode="class-2-expansion-terse class-2-expansion-terse-for-validation">
      <xsl:param name="dependencies-adjusted-and-marked" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="this-work-node-parent" select="ancestor-or-self::*[tan:work][1]"/>
      <xsl:variable name="this-src-node-parent" select="ancestor-or-self::*[tan:src][1]"/>
      <xsl:variable name="these-work-ids" select="$this-work-node-parent/tan:work"/>
      <xsl:variable name="these-src-ids" select="$this-src-node-parent/tan:src"/>
      <xsl:variable name="is-from" select="exists(@from)"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="this-ref" select="text()"/>
      <xsl:variable name="this-is-in-adjustment-action" select="exists(ancestor::tan:head)"/>
      <xsl:variable name="ref-markers" as="element()*">
         <xsl:for-each
            select="$dependencies-adjusted-and-marked[*/(@work, @src) = ($these-work-ids, $these-src-ids)]">
            <xsl:variable name="this-src-id" select="*/@src"/>
            <xsl:variable name="these-ref-markers" select="key('q-ref', $this-q, .)"/>
            <xsl:variable name="this-message" as="xs:string+"
               select="$this-src-id, ' lacks @ref ', $this-ref"/>
            <xsl:choose>
               <xsl:when test="exists($these-ref-markers)">
                  <xsl:sequence select="$these-ref-markers"/>
               </xsl:when>
               <xsl:when test="exists($these-work-ids)">
                  <xsl:copy-of select="tan:error('ref02', string-join($this-message, ''))"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="tan:error('ref01', string-join($this-message, ''))"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>

      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for ', ."/>
         <xsl:message select="'work node parent: ', $this-work-node-parent"/>
         <xsl:message select="'src node parent: ', $this-src-node-parent"/>
         <xsl:message select="'work id: ', $these-work-ids"/>
         <xsl:message select="'source ids: ', $these-src-ids"/>
         <xsl:message select="'found ', count($ref-markers), 'ref markers: ', $ref-markers"/>
      </xsl:if>

      <xsl:if test="$is-from and not($this-is-in-adjustment-action)">
         <!-- We do not do adjustment actions, because any faults in the ranges will be picked up by expanding them early on,
         and a sequence error will result in a nonsense range. -->
         <xsl:variable name="matching-to" select="following-sibling::tan:ref[@to][1]"/>
         <xsl:if test="$diagnostics-on">
            <xsl:message select="'matching to: ', $matching-to"/>
         </xsl:if>

         <xsl:for-each
            select="$dependencies-adjusted-and-marked[*/(@work, @src) = ($these-work-ids, $these-src-ids)]">
            <xsl:variable name="these-ref-markers" select="key('q-ref', $this-q, .)"/>
            <xsl:variable name="these-to-markers" select="key('q-ref', $matching-to/@q, .)"/>
            <xsl:variable name="this-src-id" select="*/@src"/>
            
            <xsl:if test="$diagnostics-on">
               <xsl:message select="concat('Source ', $this-src-id, ' from markers:'), $these-ref-markers"/>
               <xsl:message select="concat('Source ', $this-src-id, ' to markers:'), $these-to-markers"/>
            </xsl:if>
            
            <xsl:if
               test="exists($these-ref-markers) and exists($these-to-markers) and tan:node-before($these-to-markers, $these-ref-markers)">
               <xsl:variable name="this-message"
                  select="'In src', $this-src-id, ' ', $this-ref, ' comes after ', $matching-to/text()"/>
               <xsl:copy-of select="tan:error('ref03', string-join($this-message, ' '))"/>
            </xsl:if>

         </xsl:for-each>
         
      </xsl:if>
      <xsl:copy-of
         select="$ref-markers/(descendant-or-self::tan:error, descendant-or-self::tan:warning)"/>
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <xsl:template match="tan:pos" mode="class-2-expansion-terse class-2-expansion-terse-for-validation">
      <!-- Tokens are identified by a combination of rgx/val plus pos. Because the latter is the only constant, we monitor identified 
         tokens through tan:pos, not tan:rgx or tan:val -->
      <xsl:param name="dependencies-adjusted-and-marked" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="these-src-id-nodes" select="ancestor-or-self::*[tan:src][1]"/>
      <xsl:variable name="these-src-ids" select="$these-src-id-nodes/tan:src"/>
      <xsl:variable name="this-ordinal"
         select="
            if (. castable as xs:integer) then
               tan:ordinal(.)
            else
               ."
         as="xs:string"/>
      <xsl:variable name="this-val-or-rgx" select="../tan:rgx, ../tan:val"/>
      <xsl:variable name="is-from" select="exists(@from)"/>
      <xsl:variable name="matching-to" select="following-sibling::tan:pos[@to][1]"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="this-pos" select="."/>
      <xsl:variable name="pos-markers" as="element()*">
         <!-- look for markers for this pos that have been left in the source document -->
         <xsl:for-each select="$dependencies-adjusted-and-marked[*/@src = $these-src-ids]">
            <xsl:variable name="this-src-id" select="*/@src"/>
            <xsl:variable name="these-pos-markers" select="key('q-ref', $this-q, .)"/>
            <xsl:choose>
               <xsl:when test="not(exists($these-pos-markers))">
                  <xsl:variable name="this-message" as="xs:string+"
                     select="'Target ref in source ', $this-src-id, ' lacks a ', $this-ordinal, ' token with ', name($this-val-or-rgx), ' ', $this-val-or-rgx/text()"
                  />
                  <xsl:copy-of select="tan:error('tok01', string-join($this-message, ''))"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:sequence select="$these-pos-markers"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="erroneous-pos-markers" select="$pos-markers[descendant-or-self::tan:error or descendant-or-self::tan:warning]"/>
      <xsl:variable name="successful-pos-markers" select="$pos-markers except $erroneous-pos-markers"/>
      
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on for ', ."/>
         <xsl:message select="'is from?: ', $is-from"/>
         <xsl:message select="'matching to: ', $matching-to"/>
         <xsl:message select="count($pos-markers), ' found token markers: ', $pos-markers"/>
      </xsl:if>
      
      <xsl:copy-of select="$erroneous-pos-markers/(descendant-or-self::tan:error, descendant-or-self::tan:warning)"/>
      <xsl:copy-of select="$successful-pos-markers/tan:points-to"/>
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <xsl:template match="tan:chars" mode="class-2-expansion-terse class-2-expansion-terse-for-validation">
      <xsl:param name="dependencies-adjusted-and-marked" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="these-src-id-nodes" select="ancestor-or-self::*[tan:src][1]"/>
      <xsl:variable name="these-src-ids" select="$these-src-id-nodes/tan:src"/>
      <xsl:variable name="this-ordinal"
         select="
            if (. castable as xs:integer) then
               tan:ordinal(.)
            else
               ."
         as="xs:string"/>
      <xsl:variable name="is-from" select="exists(@from)"/>
      <xsl:variable name="matching-to" select="following-sibling::tan:chars[@to][1]"/>
      <xsl:variable name="this-q" select="@q"/>
      <xsl:variable name="this-c" select="."/>
      <xsl:variable name="c-markers" as="element()*">
         <xsl:for-each select="$dependencies-adjusted-and-marked[*/@src = $these-src-ids]">
            <xsl:variable name="this-src-id" select="*/@src"/>
            <xsl:variable name="these-c-markers" select="key('q-ref', $this-q, .)"/>
            <xsl:choose>
               <xsl:when test="not(exists($these-c-markers))">
                  <xsl:variable name="this-message" as="xs:string+"
                     select="'Target token in source ', $this-src-id, ' lacks a ', $this-ordinal, ' character'"
                  />
                  <xsl:copy-of select="tan:error('chr01', string-join($this-message, ''))"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:sequence select="$these-c-markers"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      <xsl:copy-of select="$c-markers/(descendant-or-self::tan:error | descendant-or-self::tan:warning)"/>
      <xsl:copy-of select="."/>
   </xsl:template>



   <!-- NORMAL EXPANSION -->

   <xsl:template match="tan:div-ref" mode="core-expansion-normal">
      <xsl:copy-of select="."/>
   </xsl:template>
   

   <!-- VERBOSE EXPANSION -->
   
   <xsl:template match="tan:source" mode="class-2-expansion-verbose">
      <xsl:variable name="this-first-da" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="this-master-location" select="$this-first-da/*/tan:head/tan:master-location[1]"/>
      <xsl:variable name="this-first-da-master" select="tan:get-1st-doc($this-master-location)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="exists($this-master-location) and not(deep-equal($this-first-da/*, $this-first-da-master/*))">
            <xsl:copy-of
               select="tan:error('tan18', 'Source differs from the version found at the master location')"
            />
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
