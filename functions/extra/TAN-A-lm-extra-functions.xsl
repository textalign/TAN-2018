<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:sch="http://purl.oclc.org/dsdl/schematron" xmlns:xhtml="http://www.w3.org/1999/xhtml"
   xmlns:mods="http://www.loc.gov/mods/v3" exclude-result-prefixes="#all" version="2.0">
   <!-- This is a special set of extra functions for processing TAN-A-lm files -->
   
   <xsl:variable name="TAN-feature-vocabulary" select="$TAN-vocabularies[tan:TAN-voc/@id = 'tag:textalign.net,2015:tan-voc:features']"/>

   <xsl:function name="tan:merge-anas" as="element()?">
      <!-- Input: a set of <ana>s that should be merged; a list of strings to which <tok>s should be restricted -->
      <!-- Output: the merger of the <ana>s, with @cert recalibrated and all <tok>s merged -->
      <!-- This function presumes that every relevant <tok> has a @val, and that values of <l> and <m> have been normalized -->

      <xsl:param name="anas-to-merge" as="element(tan:ana)*"/>
      <xsl:param name="regard-only-those-toks-that-have-what-vals" as="xs:string*"/>
      <xsl:variable name="ana-tok-counts" as="xs:integer*">
         <xsl:for-each select="$anas-to-merge">
            <xsl:variable name="toks-of-interest"
               select="tan:tok[@val = $regard-only-those-toks-that-have-what-vals]"/>
            <xsl:choose>
               <xsl:when test="exists(@tok-pop)">
                  <xsl:value-of select="@tok-pop"/>
               </xsl:when>
               <xsl:when test="exists($toks-of-interest)">
                  <xsl:value-of select="count($toks-of-interest)"/>
               </xsl:when>
               <xsl:when test="exists(tan:lm)">
                  <xsl:value-of
                     select="
                        sum(for $i in tan:lm
                        return
                           (count($i/tan:l) * count($i/tan:m)))"
                  />
               </xsl:when>
               <xsl:otherwise>1</xsl:otherwise>
            </xsl:choose>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="ana-certs"
         select="
            for $i in $anas-to-merge
            return
               if ($i/@cert) then
                  number($i/@cert)
               else
                  1"
      />
      <xsl:variable name="lms-itemized" as="element()*">
         <xsl:apply-templates select="$anas-to-merge" mode="itemize-lms">
            <xsl:with-param name="ana-cert-sum" select="sum($ana-certs)" tunnel="yes"/>
            <xsl:with-param name="context-tok-count" select="sum($ana-tok-counts)"/>
            <xsl:with-param name="tok-val" select="$regard-only-those-toks-that-have-what-vals"/>
         </xsl:apply-templates>
      </xsl:variable>
      <xsl:variable name="lms-grouped" as="element()*">
         <xsl:for-each-group select="$lms-itemized" group-by="tan:l">
            <xsl:variable name="this-lm-cert"
               select="
                  sum(for $i in current-group()
                  return
                     number($i/@cert))"/>
            <xsl:variable name="this-l-group-count" select="count(current-group())"/>
            <lm>
               <xsl:if
                  test="($this-l-group-count lt count($lms-itemized)) and $this-lm-cert lt 0.9999">
                  <xsl:attribute name="cert" select="$this-lm-cert"/>
               </xsl:if>
               <xsl:copy-of select="current-group()[1]/tan:l"/>
               <xsl:for-each-group select="current-group()" group-by="tan:m">
                  <xsl:variable name="this-m-cert"
                     select="
                        sum(for $i in current-group()
                        return
                           number($i/@cert))"/>
                  <xsl:variable name="this-m-group-count" select="count(current-group())"/>
                  <m>
                     <xsl:if test="$this-m-group-count lt $this-l-group-count">
                        <xsl:attribute name="cert" select="$this-m-cert div $this-lm-cert"/>
                     </xsl:if>
                     <xsl:value-of select="current-grouping-key()"/>
                  </m>
               </xsl:for-each-group>
            </lm>
         </xsl:for-each-group>
      </xsl:variable>
      <ana tok-pop="{sum($ana-tok-counts)}">
         <xsl:copy-of
            select="tan:distinct-items($anas-to-merge/tan:tok[@val = $regard-only-those-toks-that-have-what-vals])"/>
         <xsl:for-each select="$lms-grouped">
            <xsl:sort
               select="
                  if (@cert) then
                     number(@cert)
                  else
                     1"
               order="descending"/>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="tan:l"/>
               <xsl:for-each select="tan:m">
                  <xsl:sort
                     select="
                        if (@cert) then
                           number(@cert)
                        else
                           1"
                     order="descending"/>
                  <xsl:copy-of select="."/>
               </xsl:for-each>
            </xsl:copy>
         </xsl:for-each>
      </ana>
   </xsl:function>

   <xsl:template match="node()" mode="itemize-lms">
      <xsl:apply-templates mode="#current"/>
   </xsl:template>
   <xsl:template match="tan:ana" mode="itemize-lms">
      <xsl:param name="ana-cert-sum" as="xs:double?"/>
      <xsl:param name="context-tok-count" as="xs:integer"/>
      <xsl:param name="tok-val" as="xs:string*"/>
      <xsl:variable name="toks-of-interest" select="tan:tok[@val = $tok-val]"/>
      <xsl:variable name="this-tok-count" as="xs:integer">
         <xsl:choose>
            <xsl:when test="exists(@tok-pop)">
               <xsl:value-of select="@tok-pop"/>
            </xsl:when>
            <xsl:when test="exists($toks-of-interest)">
               <xsl:value-of select="count($toks-of-interest)"/>
            </xsl:when>
            <xsl:otherwise>1</xsl:otherwise>
         </xsl:choose>
      </xsl:variable>
      <!--<xsl:variable name="this-lm-combo-count"
            select="
                sum(for $i in tan:lm
                return
                    (count($i/tan:l) * count($i/tan:m)))"/>-->
      <xsl:apply-templates select="tan:lm" mode="#current">
         <xsl:with-param name="ana-cert" tunnel="yes"
            select="$this-tok-count div $context-tok-count"/>
         <!--<xsl:with-param name="lm-count" tunnel="yes" select="$this-lm-combo-count"/>-->
      </xsl:apply-templates>
   </xsl:template>
   <xsl:template match="tan:l" mode="itemize-lms">
      <xsl:param name="ana-cert" as="xs:double" tunnel="yes"/>
      <!--<xsl:param name="lm-count" as="xs:integer" tunnel="yes"/>-->
      <xsl:variable name="this-l" select="."/>
      <xsl:variable name="this-lm-cert" select="number((../@cert, 1)[1])"/>
      <xsl:variable name="this-l-cert" select="number((@cert, 1)[1])"/>
      <!--<xsl:variable name="this-l-pop" select="count(../tan:l)"/>-->
      <xsl:variable name="sibling-ms" select="following-sibling::tan:m"/>
      <!--<xsl:variable name="this-m-pop" select="count($sibling-ms)"/>-->
      <xsl:variable name="diagnostics-on" select="false()"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode itemize-lms, for: ', ."/>
         <xsl:message select="'ana certainty: ', $ana-cert"/>
         <xsl:message select="'lm certainty: ', $this-lm-cert"/>
         <xsl:message select="'this certainty: ', $this-l-cert"/>
         <xsl:message select="'these m certainties: ', $sibling-ms/@cert"/>
      </xsl:if>
      <xsl:for-each select="$sibling-ms">
         <xsl:variable name="this-m-cert" select="number((@cert, 1)[1])"/>
         <xsl:variable name="this-itemized-lm-cert"
            select="($ana-cert * $this-lm-cert * $this-l-cert * $this-m-cert)"/>
         <lm>
            <xsl:if test="$this-itemized-lm-cert lt 0.9999">
               <xsl:attribute name="cert" select="$this-itemized-lm-cert"/>
            </xsl:if>
            <l>
               <xsl:value-of select="$this-l"/>
            </l>
            <m>
               <xsl:copy-of select="@* except @cert"/>
               <xsl:value-of select="."/>
            </m>
         </lm>
      </xsl:for-each>
   </xsl:template>


</xsl:stylesheet>
