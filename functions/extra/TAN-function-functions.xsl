<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" exclude-result-prefixes="#all" version="3.0">
   <!-- This is a special set of functions for evaluating the TAN functions themselves -->
   <xsl:variable name="all-functions" select="collection('../collection.xml')"/>
   <xsl:function name="tan:errors-checked-where" as="element()*">
      <!-- Input: error ids -->
      <!-- Output: the top-level templates, stylesheets, and variables that use that error code -->
      <!-- Used primarily by schematron validation for TAN-errors.xml -->
      <xsl:param name="error-ids" as="xs:string*"/>
      <xsl:variable name="error-id-regex"
         select="concat('[', $quot, $apos, '](', string-join($error-ids, '|'), ')')"/>
      <xsl:sequence select="$all-functions//*[matches(@select, $error-id-regex)]"/>
   </xsl:function>
   <xsl:function name="tan:variables-checked-where" as="element()*">
      <!-- Input: name of a variable -->
      <!-- Output: the top-level templates, stylesheets, and variables that use that error code -->
      <!-- Used primarily by schematron validation for TAN-errors.xml -->
      <xsl:param name="error-ids" as="xs:string*"/>
      <xsl:variable name="error-id-regex"
         select="concat('\([', $quot, $apos, '](', string-join($error-ids, '|'), ')')"/>
      <xsl:sequence
         select="$all-functions//*[matches(@select, $error-id-regex)]/ancestor::*[last() - 1]"/>
   </xsl:function>
   
</xsl:stylesheet>
