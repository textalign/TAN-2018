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
      <xsl:variable name="this-val"
         select="
            if (. castable as xs:integer) then
               xs:integer(.)
            else
               0"
      />
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
   <!--<xsl:function name="tan:evaluate-morphological-test" as="xs:boolean?">
      <!-\- Input: a TAN-mor's <where>, <assert>, or <report>; a TAN-A-lm's <m> (within context) -\->
      <!-\- Output: booleans indicating whether the tests stated in the attributes hold true -\->
      <!-\- If no relevant condition attributes are present, the function returns false. -\->
      <xsl:param name="TAN-mor-element-with-condition-attributes" as="element()?"/>
      <xsl:param name="m-element" as="element()"/>
      <xsl:variable name="m-matches" select="$TAN-mor-element-with-condition-attributes/@m-matches"/>
      <xsl:variable name="tok-matches" select="$TAN-mor-element-with-condition-attributes/@tok-matches"/>
      <xsl:variable name="m-has-features" select="$TAN-mor-element-with-condition-attributes/@m-has-features"/>
      <xsl:variable name="m-has-how-many-features"
         select="$TAN-mor-element-with-condition-attributes/@m-has-how-many-features"/>
      <xsl:variable name="condition-1" as="xs:boolean?">
         <xsl:if test="exists($m-matches)">
            <xsl:copy-of select="matches($m-element/text()[1], $m-matches)"/>
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="condition-2" as="xs:boolean?">
         <xsl:if test="exists($tok-matches)">
            <xsl:copy-of
               select="
                  some $i in $m-element/ancestor::tan:ana//tan:tok/tan:result
                     satisfies matches($i, tan:escape($tok-matches))"
            />
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="condition-3" as="xs:boolean?">
         <xsl:if test="exists($m-has-features)">
            <xsl:variable name="these-conditions" as="element()*">
               <xsl:analyze-string select="$m-has-features" regex="(\+ )?\S+">
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
            <xsl:copy-of
               select="
                  some $i in $these-conditions-pass-2
                     satisfies
                     every $j in $i/tan:feature
                        satisfies
                        $m-element/tan:f = $j"
            />
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="condition-4" as="xs:boolean?">
         <xsl:if test="exists($m-has-how-many-features)">
            <xsl:copy-of select="count($m-element/tan:f) = xs:integer($m-has-how-many-features)"/>
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="all-conditions"
         select="$condition-1, $condition-2, $condition-3, $condition-4" as="xs:boolean*"/>
      <xsl:value-of
         select="exists($all-conditions) and
            (every $i in $all-conditions
               satisfies $i)"
      />
   </xsl:function>-->


   <!-- FILE PROCESSING: EXPANSION -->

   <!--  TERSE EXPANSION -->

   <xsl:template match="tan:body" mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists(tan:for-lang) and exists(root(.)/tan:TAN-A-lm/tan:head/tan:source)">
            <xsl:copy-of select="tan:error('tlm01')"/>
         </xsl:if>
         <xsl:if test="not(exists(tan:for-lang) or exists(root(.)/tan:TAN-A-lm/tan:head/tan:source))">
            <xsl:copy-of select="tan:error('tlm05')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:tok" mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <src>1</src>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:m" mode="core-expansion-terse">
      <xsl:variable name="this-code" select="tan:help-extracted(text())"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$this-code/@help"/>
         <xsl:value-of select="$this-code"/>
         <xsl:for-each select="tokenize(normalize-space($this-code), ' ')">
            <xsl:variable name="this-val-checked" select="tan:help-extracted(.)"/>
            <xsl:variable name="this-val" select="$this-val-checked/text()"/>
            <f n="{position()}">
               <xsl:copy-of select="$this-val-checked/@help"/>
               <xsl:value-of
                  select="
                     if ($this-val = '-') then
                        ()
                     else
                        lower-case($this-val)"
               />
            </f>
         </xsl:for-each>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:ana" mode="class-2-expansion-terse">
      <xsl:param name="dependencies" tunnel="yes"/>
      <xsl:variable name="children-pass-1" as="element()">
         <ana>
            <xsl:apply-templates mode="#current"/>
         </ana>
      </xsl:variable>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates select="$children-pass-1/*" mode="class-2-expansion-terse-pass-2">
            <xsl:with-param name="dependencies" select="$dependencies" tunnel="yes"/>
            <xsl:with-param name="morphology-ids" select="ancestor::tan:body/tan:morphology"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:m" mode="class-2-expansion-terse-pass-2">
      <xsl:param name="dependencies" tunnel="yes"/>
      <xsl:param name="morphology-ids" tunnel="yes"/>
      <xsl:variable name="these-morphology-idrefs"
         select="
            if (exists(tan:morphology)) then
               tan:morphology
            else
               $morphology-ids"/>
      <xsl:variable name="these-morphologies"
         select="$dependencies[tan:TAN-mor/@morphology = $these-morphology-idrefs]"/>
      <xsl:variable name="this-m" select="."/>
      <xsl:variable name="these-codes" select="tan:f"/>
      <xsl:variable name="these-morphology-cat-quantities"
         select="
            for $i in $these-morphologies
            return
               count($i/tan:TAN-mor/tan:body/tan:category)"/>

      <!--<xsl:variable name="relevant-asserts-and-reports"
         select="
            $these-morphologies/tan:TAN-mor/tan:body/tan:rule[some $i in (self::*, tan:where)
               satisfies tan:evaluate-morphological-test($i, $this-m)]"
      />-->
      <xsl:variable name="relevant-asserts-and-reports"
         select="
            $these-morphologies/tan:TAN-mor/tan:body/tan:rule[some $i in (self::*, tan:where)
               satisfies tan:conditions-hold($i, $this-m)]"
      />
      <!--<xsl:variable name="disobeyed-asserts"
         select="$relevant-asserts-and-reports/tan:assert[not(tan:evaluate-morphological-test(., $this-m))]"/>-->
      <!--<xsl:variable name="disobeyed-reports"
         select="$relevant-asserts-and-reports/tan:report[tan:evaluate-morphological-test(., $this-m)]"/>-->
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
            <xsl:with-param name="morphologies" select="$these-morphologies"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:f[text()]" mode="class-2-expansion-terse-pass-2">
      <xsl:param name="morphologies" as="document-node()*"/>
      <xsl:variable name="this-pos" select="xs:integer(@n)"/>
      <xsl:variable name="those-categories" select="$morphologies/tan:TAN-mor/tan:body/tan:category"/>
      <xsl:variable name="those-aliases" select="$morphologies/tan:TAN-mor/tan:head/tan:definitions/tan:alias"/>
      <xsl:variable name="those-defined-features" select="$morphologies/tan:TAN-mor/tan:head/tan:definitions/tan:feature"/>
      <xsl:variable name="this-code-resolved"
         select="
            if (exists($those-categories)) then
               text()
            else
               lower-case(tan:resolve-idref(., $those-aliases))"
      />
      <xsl:variable name="help-requested" select="exists(@help)"/>
      <xsl:variable name="those-target-features" as="element()*"
         select="
            if (exists($those-categories)) then
               $those-categories[$this-pos]/tan:feature
            else
               $those-defined-features"/>
      <xsl:variable name="this-feature"
         select="$those-target-features[(@xml:id, tan:code) = $this-code-resolved]"/>
      <xsl:variable name="close-features"
         select="
            $those-target-features[some $i in $this-code-resolved
               satisfies matches((tan:code, @xml:id, @id)[1],
               tan:escape($i))]"/>
      <xsl:copy-of select="."/>
      <!-- these errors are set as following siblings of the errant element because we need to tether it as a child to an element that was in the original. -->
      <xsl:if test="not(exists($this-feature)) or $help-requested = true()">
         <xsl:variable name="this-message" as="xs:string*">
            <xsl:value-of select="concat($this-code-resolved, ' not found; ')"/>
            <xsl:if test="exists($close-features)">
               <xsl:value-of
                  select="
                     for $i in $close-features
                     return
                        concat($i/@code, ' (', $i/tan:name[1], ')')"/>
               <xsl:text>; </xsl:text>
            </xsl:if>
            <xsl:text>all codes: </xsl:text>
            <xsl:choose>
               <xsl:when test="exists($those-categories)">
                  <xsl:value-of
                     select="
                        for $i in $those-target-features,
                           $j in ($i/@type, $those-aliases[(@xml:id, @id) = $i/@type]),
                           $k in
                           $those-defined-features[@xml:id = $j]
                        return
                           concat($i/@code, ' (', $k/tan:name[1], ')')"
                  />
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of
                     select="
                        for $i in $those-target-features
                        return
                           concat(string-join(($those-aliases[tan:idref = $i/@xml:id]/(@xml:id, @id), $i/@xml:id), ' '), ' (', $i/tan:name[1], ')')"
                  />
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
