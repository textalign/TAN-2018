<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="2.0">

   <!-- Core functions for catalog.tan.xml files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:include href="incl/TAN-class-3-functions.xsl"/>
   <xsl:include href="extra/TAN-schema-functions.xsl"/>
   <xsl:include href="incl/TAN-core-functions.xsl"/>
   
   <xsl:template match="collection" priority="2"
      mode="get-undefined-idrefs resolve-critical-dependencies apply-inclusions-and-adjust-vocabulary resolve-numerals
      core-expansion-terse core-expansion-normal core-expansion-verbose core-expansion-terse-attributes">
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <!--<xsl:template match="tan:*" mode="#all" priority="1">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>-->

</xsl:stylesheet>
