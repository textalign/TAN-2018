<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math"
   exclude-result-prefixes="#all" version="2.0">

   <!-- Core functions for TAN-T files. Written principally for Schematron validation, but suitable for general use in other contexts -->
   
   <xsl:include href="incl/TAN-class-1-functions.xsl"/>
   <xsl:include href="incl/TAN-core-functions.xsl"/>
   <xsl:output use-character-maps="tan"/>
</xsl:stylesheet>
