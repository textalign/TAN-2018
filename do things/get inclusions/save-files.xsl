<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns" xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="2.0">
   
   <!-- templates for stamping documents to be saved, and for saving them as well -->
   
   <!-- MARKING FILES TO BE SAVED -->
   <xsl:function name="tan:mark-save-as" as="item()*">
      <!-- Input: any document; a string representing a local uri -->
      <!-- Output: the same document, with @save-as stamped in the root element -->
      <xsl:param name="items-to-mark-for-saving" as="item()*"/>
      <xsl:param name="save-as-uri" as="xs:string*"/>
      <xsl:variable name="item-count" select="count($items-to-mark-for-saving)"/>
      <xsl:variable name="uri-count" select="count($save-as-uri)"/>
      <xsl:choose>
         <xsl:when test="$item-count gt 0 and $uri-count = 0">
            <xsl:message></xsl:message>
         </xsl:when>
      </xsl:choose>
      <xsl:for-each select="$items-to-mark-for-saving">
         <xsl:variable name="pos" select="position()"/>
         <xsl:variable name="this-node-type" select="tan:node-type(.)"/>
         <xsl:variable name="this-uri" select="$save-as-uri[$pos]"/>
         <xsl:choose>
            <xsl:when test="not($this-node-type = 'document-node')">
               <xsl:message select="$this-node-type, 'cannot be marked for saving'"/>
            </xsl:when>
            <xsl:when test="not(exists($this-uri))">
               <xsl:message select="'No uri provided to mark where the document should be saved.'"/>
            </xsl:when>
            <xsl:otherwise>
               <xsl:apply-templates select="." mode="stamp-save-as">
                  <xsl:with-param name="save-as-uri" select="$this-uri" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:for-each>
   </xsl:function>
   
   <xsl:template match="/*" mode="stamp-save-as">
      <xsl:param name="save-as-uri" as="xs:string?" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="string-length($save-as-uri) gt 0">
            <xsl:attribute name="save-as" select="$save-as-uri"/>
         </xsl:if>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>
   
   <!-- SAVING INTERMEDIATE STEPS -->
   <!-- Note, due to security concerns, functions cannot be used to save documents -->
   <!-- Saving occurs either by the named template or the moded template -->
   <xsl:template match="/" mode="save-file">
      <xsl:variable name="this-save-as" select="*/@save-as"/>
      <xsl:if test="exists($this-save-as)">
         <xsl:message select="'Saving file as', $this-save-as/string()"/>
         <xsl:result-document href="{$this-save-as}">
            <xsl:apply-templates mode="#current"/>
         </xsl:result-document>
      </xsl:if>
   </xsl:template>
   <xsl:template match="/*[@save-as]" mode="save-file">
      <xsl:copy>
         <xsl:copy-of select="@* except @save-as"/>
         <xsl:copy-of select="node()"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template name="save-file">
      <xsl:param name="document-to-save" as="document-node()" required="yes"/>
      <xsl:apply-templates select="$document-to-save" mode="save-file"/>
   </xsl:template>
   
</xsl:stylesheet>
