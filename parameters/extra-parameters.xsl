<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns" xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:map="http://www.w3.org/2005/xpath-functions/map"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="3.0">
   <xsl:variable name="extra-parameters-base-uri" select="static-base-uri()"/>
   <!-- Language catalogs -->
   <xsl:param name="lang-catalog-map" as="map(*)">
      <xsl:map>
         <xsl:map-entry key="'grc'">
            <xsl:text>../../library-lm/grc/lm-perseus/catalog.tan.xml</xsl:text>
            <xsl:text>../../library-lm/grc/lm-bible/catalog.tan.xml</xsl:text>
         </xsl:map-entry>
         <xsl:map-entry key="'lat'">
            <xsl:text>../../library-lm/lat/lm-perseus/catalog.tan.xml</xsl:text>
         </xsl:map-entry>
      </xsl:map>
   </xsl:param>
</xsl:stylesheet>
