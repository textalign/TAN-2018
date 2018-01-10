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

   <xsl:template match="tan:category " mode="dependency-expansion-terse core-expansion-terse">
      <xsl:variable name="duplicate-codes"
         select="
            tan:duplicate-items(for $i in tan:feature/@code
            return
               lower-case($i))"
      />
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-codes" select="$duplicate-codes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:feature" mode="dependency-expansion-terse core-expansion-terse">
      <xsl:param name="duplicate-codes"/>
      <xsl:copy>
         <xsl:copy-of select="@* except @xml:id"/>
         <xsl:if test="exists(@xml:id)">
            <xsl:attribute name="xml:id" select="lower-case(@xml:id)"/>
         </xsl:if>
         <xsl:if test="exists(@code)">
            <xsl:if test="lower-case(@code) = $duplicate-codes">
               <xsl:copy-of select="tan:error('tmo02')"/>
            </xsl:if>
            <xsl:variable name="this-code" select="tan:help-extracted(@code)"/>
            <code>
               <xsl:copy-of select="$this-code/@help"/>
               <xsl:value-of select="lower-case($this-code/text())"/>
            </code>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
