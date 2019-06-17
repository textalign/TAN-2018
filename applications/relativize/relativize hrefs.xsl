<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
   default-mode="relativize-href"
   exclude-result-prefixes="#all" version="3.0">

   <!-- Input: any XML, a target URL -->
   <!-- Output: all hrefs relativized to that target URL, as well as each html @src and processing instructions -->

   <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>
   
   <xsl:param name="target-base-uri" as="xs:string" required="yes"/>
   <xsl:variable name="target-base-uri-norm" as="xs:string">
      <xsl:choose>
         <xsl:when test="string-length($target-base-uri) gt 0">
            <xsl:value-of select="$target-base-uri"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="base-uri()"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>

   <xsl:template match="element() | text() | comment() | @*" mode="relativize-href">
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="@xml:base" mode="relativize-href">
      <xsl:attribute name="xml:base" select="$target-base-uri-norm"/>
   </xsl:template>
   
   <xsl:template match="processing-instruction()" mode="relativize-href">
      <xsl:variable name="href-regex" as="xs:string">(href=['"])([^'"]+)(['"])</xsl:variable>
      <xsl:processing-instruction name="{name(.)}">
            <xsl:analyze-string select="." regex="{$href-regex}">
                <xsl:matching-substring>
                    <xsl:value-of select="regex-group(1) || tan:uri-relative-to(regex-group(2), $target-base-uri-norm) || regex-group(3)"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:processing-instruction>
   </xsl:template>
   
   <xsl:template match="@href" mode="relativize-href">
      <xsl:attribute name="href" select="tan:uri-relative-to(., $target-base-uri-norm)"/>
   </xsl:template>
   
   <xsl:template match="html:script/@src" mode="relativize-href">
      <xsl:attribute name="src" select="tan:uri-relative-to(., $target-base-uri-norm)"/>
   </xsl:template>

</xsl:stylesheet>
