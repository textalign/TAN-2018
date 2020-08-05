<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
   default-mode="relativize-href"
   exclude-result-prefixes="#all" version="3.0">

   <!-- Catalyzing input: any XML file -->
   <!-- Secondary input: a target URL -->
   <!-- Primary output: the XML file with all URLs relativized to the target URL, in any @href, html @src, or processing instructions -->
   <!-- Secondary output: none -->
   <!-- This application makes no presumption as to where the input file is (its base uri). If you wish to relativize
   hrefs in a file saved to disk, then $target-base-uri must be the resolved uri. If $target-base-uri is a relative
   uri, it will be resolved according to the base uri of the catalyzing document and the static base 
   uri otherwise. -->
   <!-- Note, this routine only affects resolved uris. Relative uris are presumed to be already fine. If that is 
   not the case, then you must resolve them before passing the document into this application. -->

   <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>
   
   <xsl:param name="target-base-uri" as="xs:string" required="yes"/>


   <!-- THIS STYLESHEET -->
   <xsl:param name="stylesheet-iri"
      select="'tag:textalign.net,2015:stylesheet:relativize-hrefs'"/>
   <xsl:param name="stylesheet-name" select="'URL relativizer'"/>
   <xsl:param name="stylesheet-url" select="static-base-uri()"/>
   <xsl:param name="stylesheet-is-core-tan-application" select="true()"/>
   
   <xsl:variable name="target-base-uri-resolved" as="xs:string">
      <xsl:choose>
         <xsl:when test="string-length($target-base-uri) gt 0 and tan:uri-is-relative($target-base-uri)">
            <xsl:value-of select="resolve-uri($target-base-uri)"/>
         </xsl:when>
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
      <xsl:attribute name="xml:base" select="$target-base-uri-resolved"/>
   </xsl:template>
   
   <xsl:template match="processing-instruction()" mode="relativize-href">
      <xsl:variable name="href-regex" as="xs:string">(href=['"])([^'"]+)(['"])</xsl:variable>
      <xsl:processing-instruction name="{name(.)}">
            <xsl:analyze-string select="." regex="{$href-regex}">
                <xsl:matching-substring>
                   <xsl:choose>
                      <xsl:when test="tan:uri-is-resolved(regex-group(2))">
                        <xsl:value-of select="regex-group(1) || tan:uri-relative-to(regex-group(2), $target-base-uri-resolved) || regex-group(3)"/>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:value-of select="."/>
                      </xsl:otherwise>
                   </xsl:choose>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:processing-instruction>
   </xsl:template>
   
   <xsl:template match="@href | html:script/@src" mode="relativize-href">
      <xsl:attribute name="{name(.)}"
         select="
            if (tan:uri-is-resolved(.)) then
               tan:uri-relative-to(., $target-base-uri-resolved)
            else
               ."
      />
   </xsl:template>
   
</xsl:stylesheet>
