<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns" xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="2.0">
   <!-- template for outputting a TAN file. The primary purpose is to credit/blame the master stylesheet by means of <agent>, add a <role> if one doesn't exist, and log the change in <change> -->

   <xsl:import href="../../parameters/output-parameters.xsl"/>

   <!-- we apply templates to attributes, to allow @xml:base or other attributes to be deleted -->
   <xsl:template match="node() | @*" mode="credit-stylesheet">
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="/tan:* | /tei:TEI" mode="credit-stylesheet">
      <xsl:variable name="this-base-uri" select="tan:base-uri(.)"/>
      <xsl:variable name="vocabulary-for-this-stylesheet"
         select="tan:head/tan:vocabulary-key/tan:algorithm[tan:IRI = $stylesheet-iri]"/>
      <xsl:variable name="stylesheet-id" as="xs:string">
         <xsl:choose>
            <xsl:when test="exists($vocabulary-for-this-stylesheet)">
               <xsl:value-of select="$vocabulary-for-this-stylesheet/@xml:id"/>
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
         <xsl:if test="not(exists($vocabulary-for-this-stylesheet))">
            <algorithm xml:id="{$stylesheet-id}">
               <xsl:value-of select="$most-common-indentations[4]"/>
               <IRI>
                  <xsl:value-of select="$stylesheet-iri"/>
               </IRI>
               <xsl:value-of select="$most-common-indentations[4]"/>
               <name>
                  <xsl:value-of select="($stylesheet-name, 'Stylesheet to create a TAN file.')[1]"/>
               </name>
               <xsl:value-of select="$most-common-indentations[4]"/>
               <location href="{tan:uri-relative-to($stylesheet-url, $default-output-directory-resolved)}"
                  accessed-when="{current-dateTime()}"/>
               <xsl:value-of select="$most-common-indentations[3]"/>
            </algorithm>
         </xsl:if>
      </xsl:variable>
      
      <xsl:variable name="last-xslt-id-number"
         select="
            max((0,
            for $i in tan:head/(tan:definitions, tan:vocabulary-key)/*/@xml:id[matches(., '^xslt\d+$')]
            return
               number(replace($i, '\D+', ''))))"
      />
      <xsl:variable name="new-id-number" select="string($last-xslt-id-number + 1)"/>
      <xsl:variable name="stylesheet-role-id" select="concat('xslt', $new-id-number)"/>
      
      <xsl:variable name="preexisting-stylesheet-resps" select="tan:head/tan:resp[@roles = 'stylesheet']"/>
      <xsl:variable name="new-resp-element" as="element()?">
         <xsl:if test="not(exists($preexisting-stylesheet-resps))">
            <resp who="{$stylesheet-id}" roles="stylesheet"/>
         </xsl:if>
      </xsl:variable>
      
      <xsl:text>&#xa;</xsl:text>
      <xsl:copy>
         <xsl:apply-templates select="@*" mode="#current"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="new-vocabulary-key-children" tunnel="yes" as="element()*"
               select="$new-algorithm-element"/>
            <xsl:with-param name="new-resp-elements" select="$new-resp-element" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:definitions | tan:vocabulary-key" mode="credit-stylesheet">
      <xsl:param name="new-vocabulary-key-children" tunnel="yes"/>
      <xsl:param name="new-resp-elements" tunnel="yes"/>
      <xsl:variable name="first-indent" select="node()[1][self::text()]"/>
      <xsl:copy>
         <xsl:apply-templates select="@*" mode="#current"/>
         <xsl:copy-of select="tan:copy-indentation($new-vocabulary-key-children, *[1])"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
      <xsl:if test="exists($new-resp-elements)">
         <xsl:copy-of select="tan:copy-indentation($new-resp-elements, .)"/>
      </xsl:if>
      <!--<xsl:copy-of select="following-sibling::node()[1][self::text()]"/>-->
   </xsl:template>
   
   <xsl:template match="tan:resp[@roles = 'stylesheet'][1]/@who" mode="credit-stylesheet">
      <xsl:param name="new-vocabulary-key-children" tunnel="yes"/>
      <xsl:attribute name="who"
         select="string-join((., $new-vocabulary-key-children/@xml:id), ' ')"/>
   </xsl:template>
   
   <xsl:template match="tan:change[last()]" mode="credit-stylesheet">
      <xsl:param name="new-vocabulary-key-children" tunnel="yes" as="element()*"/>
      <xsl:copy>
         <xsl:apply-templates select="node() | @*" mode="#current"/>
      </xsl:copy>
      <xsl:value-of select="$most-common-indentations[2]"/>
      <change who="{$new-vocabulary-key-children/@xml:id}" when="{current-dateTime()}">
         <xsl:value-of select="$change-message"/>
      </change>
   </xsl:template>

   <xsl:template match="tan:body" mode="credit-stylesheet">
      <xsl:param name="new-vocabulary-key-children" tunnel="yes" as="element()*"/>
      <xsl:copy>
         <xsl:apply-templates select="@*" mode="#current"/>
         <xsl:if test="tan:class-number(.) = 2">
            <!-- We presume that this process of creating class 2 data requires blaming/crediting the stylesheet with the data -->
            <xsl:attribute name="claimant" select="$new-vocabulary-key-children/self::tan:algorithm/@xml:id"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
