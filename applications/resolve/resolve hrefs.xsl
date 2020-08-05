<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
   default-mode="resolve-href"
   exclude-result-prefixes="#all" version="3.0">

   <!-- Input: any XML -->
   <!-- Output: all hrefs resolved, as well as each html @src and processing instructions -->

   <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>

   <!-- THIS STYLESHEET -->
   
   <xsl:param name="stylesheet-iri" select="'tag:textalign.net,2015:stylesheet:resolve-hrefs'"/>
   <xsl:variable name="stylesheet-url" select="static-base-uri()"/>
   <xsl:param name="change-message">
      <xsl:value-of select="'Links in ' || base-uri(/) || ' resolved'"/>
   </xsl:param>

   <xsl:template match="element() | text() | comment() | @*" mode="resolve-href">
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="/" mode="resolve-href">
      <xsl:copy>
         <xsl:apply-templates select="node()" mode="#current">
            <xsl:with-param name="leave-breadcrumbs" select="false()" tunnel="yes"/>
            <xsl:with-param name="add-q-ids" tunnel="yes" select="false()"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="html:script/@src" mode="resolve-href">
      <xsl:param name="base-uri" as="xs:anyURI?" tunnel="yes"/>
      <xsl:attribute name="src" select="resolve-uri(., $base-uri)"/>
   </xsl:template>

</xsl:stylesheet>
