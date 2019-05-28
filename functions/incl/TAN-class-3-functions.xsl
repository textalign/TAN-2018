<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" 
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:fn="http://www.w3.org/2005/xpath-functions"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="2.0">

   <!-- Core functions for class 3 files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <!-- FUNCTIONS -->
   
   <!-- FUNCTIONS: SEQUENCES -->
   
   <xsl:function name="tan:feature-test-to-groups" as="element()*">
      <!-- Input: any value of @feature-test -->
      <!-- Output: the value converted into a series of <group>ed <item>s, observing the accepted syntax for this attribute -->
      <!-- Example: "a b + c" - > 
               <group>
                  <item>a</item>
               </group>
               <group>
                  <item>b</item>
                  <item>c</item>
               </group>
 -->
      <xsl:param name="attr-feature-test" as="xs:string?"/>
      <xsl:variable name="attr-norm" select="tan:normalize-text($attr-feature-test)"/>
      <xsl:if test="string-length($attr-feature-test) gt 0">
         <xsl:analyze-string select="$attr-feature-test" regex="[^\s\+]+(\s\+\s[^\s\+]+)*">
            <xsl:matching-substring>
               <group>
                  <xsl:for-each select="tokenize(., ' \+ ')">
                     <item>
                        <xsl:value-of select="lower-case(.)"/>
                     </item>
                  </xsl:for-each>
               </group>
            </xsl:matching-substring>
         </xsl:analyze-string>
      </xsl:if>
   </xsl:function>

   <!-- FILE PROCESSING: EXPANSION -->

   <xsl:template match="tan:TAN-mor/tan:body" mode="dependency-adjustments-pass-1 core-expansion-terse">
      <xsl:variable name="duplicate-features" select="tan:duplicate-items(tan:category/tan:feature/tan:type)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-features" select="$duplicate-features" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:category " mode="dependency-adjustments-pass-1 core-expansion-terse">
      <xsl:variable name="duplicate-codes" select="tan:duplicate-items(tan:feature/tan:code)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-codes" select="$duplicate-codes" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:feature/tan:type" mode="dependency-adjustments-pass-1 core-expansion-terse">
      <xsl:param name="duplicate-features" tunnel="yes"/>
      <xsl:if test=". = $duplicate-features">
         <xsl:copy-of select="tan:error('tmo01', concat(., ' repeats'))"/>
      </xsl:if>
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="tan:feature/tan:code" mode="dependency-adjustments-pass-1 core-expansion-terse">
      <xsl:param name="duplicate-codes" tunnel="yes"/>
      <xsl:if test=". = $duplicate-codes">
         <xsl:copy-of select="tan:error('tmo02', concat(., ' repeats'))"/>
      </xsl:if>
      <xsl:copy-of select="."/>
   </xsl:template>

</xsl:stylesheet>
