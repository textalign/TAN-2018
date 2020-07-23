<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="2.0">

   <!-- Core functions for TAN-voc files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:include href="incl/TAN-class-3-functions.xsl"/>
   <xsl:include href="incl/TAN-core-functions.xsl"/>
   <xsl:import href="extra/TAN-schema-functions.xsl"/>

   <!-- PROCESSING TAN-voc FILES: RESOLUTION -->
   
   <xsl:template match="tan:body | tan:group | tan:item" mode="imprint-vocabulary" priority="1">
      <xsl:param name="inherited-affects-elements" as="xs:string*" tunnel="yes"/>
      <xsl:variable name="these-affects-elements"
         select="tokenize(normalize-space(@affects-element), ' ')"/>
      <xsl:variable name="current-affects-elements"
         select="
            if (exists($these-affects-elements)) then
               $these-affects-elements
            else
               $inherited-affects-elements"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="name(.) = 'item'">
            <xsl:for-each select="$current-affects-elements">
               <affects-element>
                  <xsl:value-of select="."/>
               </affects-element>
            </xsl:for-each>
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="inherited-affects-elements" select="$current-affects-elements"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>


   <!-- PROCESSING TAN-voc FILES: EXPANSION -->
   
   <xsl:template match="tan:body" mode="core-expansion-terse">
      <xsl:variable name="all-body-iris" select=".//tan:IRI"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-IRIs" select="tan:duplicate-items($all-body-iris)"
               tunnel="yes"/>
            <!--<xsl:with-param name="inherited-affects-elements" select="tan:affects-element"
               tunnel="yes"/>-->
            <xsl:with-param name="is-reserved"
               select="(parent::tan:TAN-voc/@id = $TAN-vocabulary-files/*/@id) or $doc-is-error-test"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="*[@affects-element]/tan:affects-element" mode="core-expansion-terse">
      <xsl:variable name="this-val" select="."/>
      <xsl:if test="not(. = $TAN-elements-that-take-the-attribute-which/@name)">
         <xsl:variable name="this-fix" as="element()*">
            <xsl:for-each select="$TAN-elements-that-take-the-attribute-which/@name">
               <xsl:sort select="matches(., $this-val)" order="descending"/>
               <element affects-element="{.}"/>
            </xsl:for-each>
         </xsl:variable>
         <xsl:copy-of
            select="tan:error('voc03', concat('try: ', string-join($this-fix/@affects-element, ', ')), $this-fix, 'copy-attributes')"
         />
      </xsl:if>
      <xsl:if test="($this-val = 'vocabulary') and not(tan:doc-id-namespace(root(.)) = $TAN-id-namespace)">
         <xsl:copy-of select="tan:error('voc06')"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:item | tan:verb" mode="core-expansion-terse">
      <xsl:param name="is-reserved" as="xs:boolean?" tunnel="yes"/>
      <xsl:variable name="these-affects-elements" select="tan:affects-element/text()"/>
      <xsl:variable name="reserved-vocabulary-docs"
         select="$TAN-vocabularies[tan:TAN-voc/tan:body[tokenize(@affects-element, '\s+') = $these-affects-elements]]"/>
      <xsl:variable name="reserved-vocabulary-items"
         select="
            for $i in $reserved-vocabulary-docs
            return
               key('item-via-node-name', $these-affects-elements, $i)"
      />
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if
            test="($is-reserved = true()) 
            and (not(exists(tan:IRI[starts-with(., $TAN-id-namespace)]))) and (not(exists(tan:token-definition)))">
            <xsl:variable name="this-fix" as="element()">
               <IRI>
                  <xsl:value-of select="$TAN-namespace"/>
               </IRI>
            </xsl:variable>
            <xsl:copy-of select="tan:error('voc04', (), $this-fix, 'prepend-content')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="reserved-vocabulary-items" select="$reserved-vocabulary-items"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <!-- NORMAL EXPANSION -->

   <xsl:template match="tan:body" mode="core-expansion-normal">
      <xsl:variable name="duplicate-names" as="element()*">
         <xsl:for-each-group select=".//tan:name"
            group-by="ancestor::tan:*[tan:affects-element][1]/tan:affects-element">
            <xsl:for-each-group select="current-group()" group-by=".">
               <xsl:if test="count(current-group()) gt 1">
                  <xsl:copy-of select="current-group()"/>
               </xsl:if>
            </xsl:for-each-group>
         </xsl:for-each-group>
      </xsl:variable>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-names" select="$duplicate-names" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:name" mode="core-expansion-normal">
      <xsl:param name="duplicate-names" tunnel="yes"/>
      <xsl:variable name="this-name-normalized" select="tan:normalize-name(.)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$this-name-normalized = $duplicate-names">
            <xsl:copy-of select="tan:error('voc02')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
