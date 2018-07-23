<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns" xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="2.0">
   <!-- template for outputting a TAN file. The primary purpose is to credit/blame the master stylesheet by means of <agent>, add a <role> if one doesn't exist, and log the change in <change> -->

   <!--<xsl:param name="stylesheet-iri" as="xs:string" required="yes"/>
   <xsl:param name="stylesheet-url" as="xs:string" select="static-base-uri()"/>
   <xsl:param name="change-message" as="xs:string*" required="yes"/>-->
   <xsl:import href="../../parameters/output-parameters.xsl"/>

   <xsl:template match="/tan:*" mode="credit-stylesheet">
      <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
      <xsl:variable name="definition-for-this-stylesheet"
         select="tan:head/tan:definitions/tan:algorithm[tan:IRI = $stylesheet-iri]"/>
      <xsl:variable name="stylesheet-id" as="xs:string">
         <xsl:choose>
            <xsl:when test="exists($definition-for-this-stylesheet)">
               <xsl:value-of select="$definition-for-this-stylesheet/@xml:id"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="new-id-number-start"
                  select="
                     max((0,
                     for $i in .//@xml:id[matches(., '^xslt\d+$')]
                     return
                        number(replace($i, '\D+', ''))))"
               />
               <xsl:value-of select="concat('xslt', string($new-id-number-start + 1))"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="new-algorithm-element" as="element()?">
         <xsl:if test="not(exists($definition-for-this-stylesheet))">
            <algorithm xml:id="{$stylesheet-id}">
               <IRI>
                  <xsl:value-of select="$stylesheet-iri"/>
               </IRI>
               <name>Stylesheet to create a TAN file.</name>
               <desc>Stylesheet at: <xsl:value-of
                  select="tan:uri-relative-to($stylesheet-url, string($this-base-uri))"/></desc>
            </algorithm>
         </xsl:if>
      </xsl:variable>
      
      <xsl:variable name="stylesheet-role"
         select="$TAN-keyword-files/tan:TAN-key/tan:body[@affects-element = 'role']/tan:item[tan:name = 'stylesheet']"/>
      <xsl:variable name="role-element-for-stylesheet"
         select="tan:head/tan:definitions/tan:role[(tan:IRI = $stylesheet-role/tan:IRI) or (tan:name, @which) = $stylesheet-role/tan:name]"/>
      <xsl:variable name="stylesheet-role-id">
         <xsl:choose>
            <xsl:when test="exists($role-element-for-stylesheet)">
               <xsl:value-of select="$role-element-for-stylesheet/@xml:id"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:variable name="new-id-number-start"
                  select="
                     max((0,
                     for $i in tan:head/tan:definitons/tan:role/@xml:id[matches(., '^stylesheet\d+$')]
                     return
                        number(replace($i, '\D+', ''))))"
               />
               <xsl:variable name="new-id-number"
                  select="
                     if ($new-id-number-start = 0) then
                        ''
                     else
                        string($new-id-number-start + 1)"
               />
               <xsl:value-of select="concat('stylesheet', $new-id-number)"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <xsl:variable name="new-role-element" as="element()?">
         <xsl:if test="not(exists($role-element-for-stylesheet))">
            <role xml:id="{$stylesheet-role-id}" which="stylesheet"/>
         </xsl:if>
      </xsl:variable>
      
      <xsl:variable name="new-resp-element" as="element()?">
         <resp who="{$stylesheet-id}" roles="{$stylesheet-role-id}"/>
      </xsl:variable>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="new-definition-children" tunnel="yes"
               select="($new-algorithm-element, $new-role-element)"/>
            <xsl:with-param name="new-resp-elements" select="$new-resp-element" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:head" mode="credit-stylesheet">
      <xsl:param name="new-definition-children" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
         <change who="{$new-definition-children/self::tan:algorithm/@xml:id}"
            when="{current-dateTime()}">
            <xsl:value-of select="$change-message"/>
         </change>
         <xsl:copy-of select="node()[1][self::text()]"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:definitions" mode="credit-stylesheet">
      <xsl:param name="new-definition-children" tunnel="yes"/>
      <xsl:variable name="first-indent" select="node()[1][self::text()]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each select="$new-definition-children">
            <xsl:copy-of select="$first-indent"/>
            <xsl:copy-of select="."/>
         </xsl:for-each>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
      <xsl:copy-of select="following-sibling::node()[1][self::text()]"/>
   </xsl:template>
   
   <xsl:template match="tan:resp[1]" mode="credit-stylesheet">
      <xsl:param name="new-resp-elements" tunnel="yes"/>
      <xsl:copy-of select="$new-resp-elements"/>
      <xsl:copy-of select="preceding-sibling::node()[1]/self::text()"/>
      <xsl:copy-of select="."/>
   </xsl:template>

   <xsl:template match="tan:body" mode="credit-stylesheet">
      <xsl:param name="new-definition-children" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="tan:class-number(.) = 2">
            <!-- We presume that this process of creating class 2 data requires blaming/crediting the stylesheet with the data -->
            <xsl:attribute name="claimant" select="$new-definition-children/self::tan:algorithm/@xml:id"/>
         </xsl:if>
      <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
