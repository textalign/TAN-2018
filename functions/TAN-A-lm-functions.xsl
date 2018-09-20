<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="2.0">

   <!-- Core functions for TAN-A-lm files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:include href="incl/TAN-class-1-functions.xsl"/>
   <xsl:include href="incl/TAN-class-2-functions.xsl"/>
   <xsl:include href="incl/TAN-class-3-functions.xsl"/>
   <xsl:include href="incl/TAN-core-functions.xsl"/>

   <!-- TAN-A-LM GLOBAL VARIABLES -->
   
   <xsl:variable name="morphologies-expanded"
      select="tan:expand-doc($morphologies-resolved)" as="document-node()*"/>

   <!-- FUNCTIONS -->
   
   <xsl:template match="@m-matches" mode="evaluate-conditions">
      <xsl:param name="context" tunnel="yes"/>
      <xsl:attribute name="{name()}">
         <xsl:value-of select="matches($context/text()[1], .)"/>
      </xsl:attribute>
   </xsl:template>
   <xsl:template match="@m-has-how-many-features" mode="evaluate-conditions">
      <xsl:param name="context" tunnel="yes"/>
      <xsl:variable name="this-val" select="tan:expand-numerical-sequence(., 999)"/>
      <xsl:attribute name="{name()}">
         <xsl:value-of select="count($context/tan:f) = $this-val"/>
      </xsl:attribute>
   </xsl:template>
   <xsl:template match="@m-has-features" mode="evaluate-conditions">
      <xsl:param name="context" tunnel="yes"/>
      <xsl:variable name="these-conditions" as="element()*">
         <xsl:analyze-string select="." regex="(\+ )?\S+">
            <xsl:matching-substring>
               <xsl:variable name="this-item" select="tokenize(., ' ')"/>
               <xsl:element name="{if (count($this-item) gt 1) then 'and' else 'feature'}">
                  <xsl:value-of select="$this-item[last()]"/>
               </xsl:element>
            </xsl:matching-substring>
         </xsl:analyze-string>
      </xsl:variable>
      <xsl:variable name="these-conditions-pass-2" as="element()*">
         <xsl:for-each-group select="$these-conditions" group-starting-with="tan:feature">
            <group>
               <xsl:for-each select="current-group()">
                  <feature>
                     <xsl:value-of select="."/>
                  </feature>
               </xsl:for-each>
            </group>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:attribute name="{name()}">
         <xsl:value-of
            select="
               some $i in $these-conditions-pass-2
                  satisfies
                  every $j in $i/tan:feature
                     satisfies
                     $context/tan:f = $j"
         />
      </xsl:attribute>
   </xsl:template>
   <xsl:template match="@tok-matches" mode="evaluate-conditions">
      <xsl:param name="context" tunnel="yes"/>
      <xsl:variable name="this-val" select="."/>
      <xsl:attribute name="{name()}">
         <xsl:value-of
            select="
               some $i in $context/ancestor::tan:ana//tan:tok/tan:result
                  satisfies tan:matches($i, tan:escape($this-val))"
         />
      </xsl:attribute>
   </xsl:template>
   

   <!-- FILE PROCESSING: EXPANSION -->

   <!--  TERSE EXPANSION -->

   <xsl:template match="tan:body" mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="is-for-lang" select="exists(root()/*/tan:head/tan:for-lang)"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:tok" mode="core-expansion-terse">
      <xsl:param name="is-for-lang" tunnel="yes" as="xs:boolean"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$is-for-lang = false()">
            <src>1</src>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:m" mode="core-expansion-terse">
      <!-- This step breaks down the <m> into constituent <f>s with @n indicating position, and the values normalized (lowercase) -->
      <xsl:variable name="this-text-norm" select="normalize-space(lower-case(text()))"/>
      <xsl:variable name="this-code" select="tan:help-extracted($this-text-norm)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$this-code/@help"/>
         <xsl:value-of select="$this-code"/>
         <xsl:for-each select="tokenize($this-text-norm, ' ')">
            <xsl:variable name="this-val-checked" select="tan:help-extracted(.)"/>
            <xsl:variable name="this-val" select="$this-val-checked/text()"/>
            <f n="{position()}">
               <xsl:copy-of select="$this-val-checked/@help"/>
               <xsl:choose>
                  <xsl:when test="$this-val = ('-', '') and exists($this-val-checked/@help)">
                     <xsl:text> </xsl:text>
                  </xsl:when>
                  <xsl:when test="$this-val = ('-', '')"/>
                  <xsl:otherwise>
                     <xsl:value-of select="$this-val"/>
                  </xsl:otherwise>
               </xsl:choose>
            </f>
         </xsl:for-each>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:tan-vocabulary/tan:item[tan:affects-element = 'feature']/tan:id" mode="dependency-expansion-terse">
      <!-- ids for features are not allowed to be case-sensitive -->
      <xsl:variable name="this-id-lowercase" select="lower-case(.)"/>
      <xsl:if test="not(. = $this-id-lowercase)">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$this-id-lowercase"/>
         </xsl:copy>
      </xsl:if>
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <xsl:template match="tan:vocabulary-key/tan:feature[@xml:id][tan:IRI]" mode="dependency-expansion-terse">
      <!-- We copy @xml:id for an internally defined vocab key feature, to make it easier to match vocab items to feature codes -->
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <id>
            <xsl:value-of select="@xml:id"/>
         </id>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:m" mode="tan-a-lm-expansion-terse">
      <xsl:param name="dependencies" tunnel="yes"/>
      <xsl:variable name="morphology-ids" select="ancestor-or-self::*[tan:morphology][1]/tan:morphology"/>
      <xsl:variable name="these-morphologies"
         select="$dependencies[tan:TAN-mor/@morphology = $morphology-ids]"/>
      <xsl:variable name="this-m" select="."/>
      <xsl:variable name="these-codes" select="tan:f"/>
      <xsl:variable name="these-morphology-cat-quantities"
         select="
            for $i in $these-morphologies
            return
               count($i/tan:TAN-mor/tan:body/tan:category)"/>
      <xsl:variable name="relevant-asserts-and-reports"
         select="
            $these-morphologies/tan:TAN-mor/tan:body/tan:rule[some $i in (self::*, tan:where)
               satisfies tan:conditions-hold($i, $this-m)]"
      />
      <xsl:variable name="disobeyed-asserts"
         select="$relevant-asserts-and-reports/tan:assert[not(tan:conditions-hold(., $this-m))]"/>
      <xsl:variable name="disobeyed-reports"
         select="$relevant-asserts-and-reports/tan:report[tan:conditions-hold(., $this-m)]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="$these-morphology-cat-quantities gt 0 and count($these-codes) gt $these-morphology-cat-quantities">
            <xsl:copy-of
               select="tan:error('tlm02', concat('max ', $these-morphology-cat-quantities))"/>
         </xsl:if>
         <xsl:apply-templates select="($disobeyed-asserts, $disobeyed-reports)"
            mode="element-to-error">
            <xsl:with-param name="error-id" select="'tlm04'"/>
         </xsl:apply-templates>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="dependencies" select="$these-morphologies" tunnel="yes"/>
            <xsl:with-param name="feature-vocabulary" select="$these-morphologies/tan:TAN-mor/tan:head/(tan:vocabulary, tan:tan-vocabulary, tan:vocabulary-key)/(tan:feature, tan:item[tan:affects-element = 'feature'])"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:f[text()]" mode="tan-a-lm-expansion-terse">
      <xsl:param name="dependencies" tunnel="yes" as="document-node()*"/>
      <xsl:param name="feature-vocabulary"/>
      <xsl:variable name="this-f" select="."/>
      <xsl:variable name="help-requested" select="exists(@help)"/>
      <xsl:variable name="this-pos" select="xs:integer(@n)"/>
      <xsl:variable name="this-category" select="$dependencies/tan:TAN-mor/tan:body/tan:category[$this-pos]"/>
      <xsl:variable name="this-id-resolved"
         select="
            if (exists($this-category)) then
               $this-category/tan:feature[@code = $this-f]/@type
            else
               $this-f"
      />
      <xsl:variable name="this-voc-item" select="$feature-vocabulary[tan:id = $this-id-resolved]"/>
      
      <xsl:copy-of select="."/>
      <!-- these errors are set as following siblings of the errant element because we need to tether it as a child to an element that was in the original. -->
      <xsl:if test="not(exists($this-voc-item)) or $help-requested = true()">
         <xsl:variable name="this-message" as="xs:string*">
            <xsl:value-of
               select="
                  if (not(exists($this-voc-item))) then
                     concat($this-f, ' not found; try: ')
                  else
                     concat($this-f, ' is valid (= ', $this-voc-item/tan:name[1],'); all options: ')"
            />
            <xsl:choose>
               <xsl:when test="exists($this-category)">
                  <xsl:for-each select="$this-category/tan:feature">
                     <xsl:variable name="this-id" select="@type"/>
                     <xsl:value-of
                        select="concat(@code, ' (', $feature-vocabulary[tan:id = $this-id]/tan:name[1], ') ')"
                     />
                  </xsl:for-each>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:for-each select="$feature-vocabulary">
                     <xsl:sort select="matches(tan:id[1], tan:escape($this-f))" order="descending"/>
                     <xsl:value-of select="concat(tan:id[1], ' (', tan:name[1], ') ')"/>
                  </xsl:for-each>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:variable>
         <xsl:copy-of select="tan:error('tlm03', string-join($this-message, ''))"/>
      </xsl:if>
   </xsl:template>

   <!--  NORMAL EXPANSION -->

   <!-- reserved -->

   <!--  VERBOSE EXPANSION -->
   
   <!-- reserved -->
   
</xsl:stylesheet>
