<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math"
   exclude-result-prefixes="#all" version="2.0">
   
   <!-- Core functions for TAN-mor files. Written principally for Schematron validation, but suitable for general use in other contexts -->
   <xsl:template match="*[@which]/tan:id" priority="1" mode="core-expansion-terse">
      <!-- This template overrules the default, because TAN-mor files
      must cite all features that are allowed, and many times the name
      is conveniently also the perfect id. -->
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <xsl:include href="incl/TAN-class-3-functions.xsl"/>
   <xsl:include href="incl/TAN-core-functions.xsl"/>

</xsl:stylesheet>
