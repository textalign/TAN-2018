<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns" xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="2.0">
   <!-- Core variables, parameters, and functions for any stylesheet that generates a TAN file. The primary purpose is to credit/blame the master stylesheet by means of <agent>, add a <role> if one doesn't exist, and log the change in <change> -->
   <!-- This stylesheet is meant to be imported (not included) by other master stylesheets. Any stylesheets that include it must have certain variables defined. -->

   <xsl:function name="tan:preceding-text-node" as="text()?">
      <!-- Input: any element -->
      <!-- Output: the text node, if any, that comes before it. -->
      <!-- This function is useful for replicating indentation levels. -->
      <xsl:param name="element" as="element()"/>
      <xsl:value-of select="($element/preceding::node()[1])[self::text()]"/>
   </xsl:function>

   <xsl:param name="stylesheet-iri" as="xs:string" required="yes"/>
   <xsl:param name="stylesheet-url" as="xs:string" select="static-base-uri()"/>
   <xsl:param name="change-message" as="xs:string*" required="yes"/>

   <xsl:variable name="definition-for-this-stylesheet"
      select="$head/tan:definitions/tan:algorithm[tan:IRI = $stylesheet-iri]"/>

   <xsl:variable name="stylesheet-id" as="xs:string">
      <xsl:choose>
         <xsl:when test="exists($definition-for-this-stylesheet)">
            <xsl:value-of select="$definition-for-this-stylesheet/@xml:id"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="new-id-number-start"
               select="
                  max((0,
                  for $i in $head//@xml:id[matches(., '^xslt\d+$')]
                  return
                     number(replace($i, '\D+', ''))))"/>
            <xsl:value-of select="concat('xslt', string($new-id-number-start + 1))"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>

   <xsl:variable name="stylesheet-role"
      select="$TAN-keyword-files/tan:TAN-key/tan:body[@affects-element = 'role']/tan:item[tan:name = 'stylesheet']"/>
   <xsl:variable name="role-element-for-stylesheet"
      select="$head//tan:role[(tan:IRI = $stylesheet-role/tan:IRI) or (tan:name, @which) = $stylesheet-role/tan:name]"/>
   <xsl:variable name="stylesheet-role-id">
      <xsl:choose>
         <xsl:when test="exists($role-element-for-stylesheet)">
            <xsl:value-of select="$role-element-for-stylesheet/@xml:id"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="new-id-number-start"
               select="
                  max((0,
                  for $i in $head//tan:role/@xml:id[matches(., '^stylesheet\d+$')]
                  return
                     number(replace($i, '\D+', ''))))"/>
            <xsl:variable name="new-id-number"
               select="
                  if ($new-id-number-start = 0) then
                     ''
                  else
                     string($new-id-number-start + 1)"/>
            <xsl:value-of select="concat('stylesheet', $new-id-number)"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:variable>

   <xsl:template match="tan:person | tan:organization | tan:algorithm" mode="credit-stylesheet">
      <xsl:copy-of select="."/>
      <xsl:if
         test="not(exists((following-sibling::tan:person, following-sibling::tan:organization, following-sibling::tan:algorithm))) and not(exists($definition-for-this-stylesheet))">
         <xsl:value-of select="tan:preceding-text-node(.)"/>
         <algorithm xml:id="{$stylesheet-id}">
            <IRI>
               <xsl:value-of select="$stylesheet-iri"/>
            </IRI>
            <name>Stylesheet to populate a TAN-A-div file from collections.</name>
            <desc>Stylesheet at: <xsl:value-of
                  select="tan:uri-relative-to($stylesheet-url, $doc-uri)"/></desc>
         </algorithm>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:role" mode="credit-stylesheet">
      <xsl:copy-of select="."/>
      <xsl:if
         test="not(exists(following-sibling::tan:role)) and not(exists($role-element-for-stylesheet))">
         <xsl:value-of select="tan:preceding-text-node(.)"/>
         <role xml:id="{$stylesheet-role-id}" which="stylesheet"/>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:resp" mode="credit-stylesheet">
      <xsl:copy-of select="."/>
      <xsl:if test="not(exists(following-sibling::tan:resp))">
         <xsl:value-of select="tan:preceding-text-node(.)"/>
         <resp who="{$stylesheet-id}" roles="{$stylesheet-role-id}"/>
      </xsl:if>
   </xsl:template>
   <xsl:template match="tan:change" mode="credit-stylesheet">
      <xsl:copy-of select="."/>
      <xsl:if test="not(exists(following-sibling::tan:change))">
         <xsl:value-of select="tan:preceding-text-node(.)"/>
         <change who="{$stylesheet-id}" when="{current-dateTime()}">
            <xsl:value-of select="$change-message"/>
         </change>
      </xsl:if>
   </xsl:template>

</xsl:stylesheet>
