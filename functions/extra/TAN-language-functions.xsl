<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" xmlns:xhtml="http://www.w3.org/1999/xhtml"
   xmlns:mods="http://www.loc.gov/mods/v3"  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
   exclude-result-prefixes="#all" version="3.0">
   <!-- This is a special set of extra functions for processing information about languages -->

   <xsl:variable name="iso-639-3" select="doc('lang/iso-639-3.xml')" as="document-node()?"/>
   
   <xsl:variable name="grc-tokens-without-accents" select="doc('lang/grc-tokens-without-accents.xml')/*/*"/>

   <xsl:function name="tan:lang-code" as="xs:string*">
      <!-- Input: the name of a language -->
      <!-- Output: the 3-letter code for the language -->
      <!-- If no exact match is found, the parameter will be treated as a regular expression, and all case-insensitive matches will be returned -->
      <xsl:param name="lang-name" as="xs:string?"/>
      <xsl:variable name="lang-match"
         select="$iso-639-3/tan:iso-639-3/tan:l[@name = $lang-name]/@id"/>
      <xsl:value-of select="$lang-match"/>
      <xsl:if test="not(exists($lang-match)) and (string-length($lang-name) gt 0)">
         <xsl:value-of
            select="
               for $i in $iso-639-3/tan:iso-639-3/tan:l[matches(@name, $lang-name, 'i')]
               return
                  string($i)"
         />
      </xsl:if>
   </xsl:function>

   <xsl:function name="tan:lang-name" as="xs:string*">
      <!-- Input: the code of a language -->
      <!-- Output: the name of the language -->
      <!-- If no exact match is found, the parameter will be treated as a regular expression, and all case-insensitive matches will be returned -->
      <xsl:param name="lang-code" as="xs:string?"/>
      <xsl:variable name="lang-match"
         select="$iso-639-3/tan:iso-639-3/tan:l[@id = $lang-code]/@name"/>
      <xsl:value-of select="$lang-match"/>
      <xsl:if test="not(exists($lang-match)) and (string-length($lang-code) gt 0)">
         <xsl:value-of
            select="
               for $i in $iso-639-3/tan:iso-639-3/tan:l[matches(@id, $lang-code, 'i')]
               return
                  string($i)"
         />
      </xsl:if>
   </xsl:function>
   
   <xsl:function name="tan:lang-catalog" as="document-node()*">
      <!-- Input: language codes -->
      <!-- Output: the catalogs for those languages -->
      <xsl:param name="lang-codes" as="xs:string*"/>
      <xsl:variable name="lang-codes-rev"
         select="
            if ((count($lang-codes) lt 1) or $lang-codes = '*') then
               '*'
            else
               $lang-codes"/>
      <xsl:for-each select="$lang-codes-rev">
         <xsl:variable name="this-lang-code" select="."/>
         <xsl:variable name="these-catalog-uris"
            select="
               if ($this-lang-code = '*') then
                  (for $i in $languages-supported
                  return
                     $lang-catalog-map($i))
               else
                  $lang-catalog-map($this-lang-code)"/>
         <xsl:if test="not(exists($these-catalog-uris))">
            <xsl:message select="'No catalogs defined for', $this-lang-code"/>
         </xsl:if>
         <xsl:for-each select="$these-catalog-uris">
            <xsl:variable name="this-uri" select="resolve-uri(., $extra-parameters-base-uri)"/>
            <xsl:choose>
               <xsl:when test="doc-available($this-uri)">
                  <xsl:sequence select="doc($this-uri)"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:message select="'Language catalog not available at ', $this-uri"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:for-each>
   </xsl:function>
   <xsl:variable name="languages-supported" select="map:keys($lang-catalog-map)"/>
   
</xsl:stylesheet>
