<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" 
   exclude-result-prefixes="#all" version="3.0">
   
   <!-- This stylesheet allows users to quickly test a TAN file or components of the TAN library. Alter as you like. -->

   <xsl:include href="../../functions/TAN-A-tok-functions.xsl"/>
   <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
   <xsl:output method="xml" indent="yes"/>

   <xsl:param name="validation-phase" select="'terse'"/>

   <xsl:template match="/">
      <test>
         <xsl:message select="'Testing ' || $doc-id || 'at' || $doc-uri"/>
         <self-r><xsl:copy-of select="$self-resolved"/></self-r>
         <self-e><xsl:copy-of select="$self-expanded"/></self-e>
         <diff><xsl:copy-of select="tan:diff('Here is a string.', 'A string is here.')"/></diff>
      </test>
   </xsl:template>

</xsl:stylesheet>
