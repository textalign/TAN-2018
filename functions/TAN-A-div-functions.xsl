<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="2.0">

   <!-- Core functions for TAN-A-div files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:include href="incl/TAN-class-1-functions.xsl"/>
   <xsl:include href="incl/TAN-class-2-functions.xsl"/>
   <xsl:include href="incl/TAN-class-3-functions.xsl"/>
   <xsl:include href="incl/TAN-core-functions.xsl"/>

   <!-- FUNCTIONS -->

   <xsl:function name="tan:data-type-check" as="xs:boolean">
      <!-- Input: an item and a string naming a data type -->
      <!-- Output: a boolean indicating whether the item can be cast into that data type -->
      <!-- If the first parameter doesn't match a data type, the function returns false -->
      <xsl:param name="item" as="item()?"/>
      <xsl:param name="data-type" as="xs:string"/>
      <xsl:choose>
         <xsl:when test="$data-type = 'string'">
            <xsl:value-of select="$item castable as xs:string"/>
         </xsl:when>
         <xsl:when test="$data-type = 'boolean'">
            <xsl:value-of select="$item castable as xs:boolean"/>
         </xsl:when>
         <xsl:when test="$data-type = 'decimal'">
            <xsl:value-of select="$item castable as xs:decimal"/>
         </xsl:when>
         <xsl:when test="$data-type = 'float'">
            <xsl:value-of select="$item castable as xs:float"/>
         </xsl:when>
         <xsl:when test="$data-type = 'double'">
            <xsl:value-of select="$item castable as xs:double"/>
         </xsl:when>
         <xsl:when test="$data-type = 'duration'">
            <xsl:value-of select="$item castable as xs:duration"/>
         </xsl:when>
         <xsl:when test="$data-type = 'dateTime'">
            <xsl:value-of select="$item castable as xs:dateTime"/>
         </xsl:when>
         <xsl:when test="$data-type = 'time'">
            <xsl:value-of select="$item castable as xs:time"/>
         </xsl:when>
         <xsl:when test="$data-type = 'date'">
            <xsl:value-of select="$item castable as xs:date"/>
         </xsl:when>
         <xsl:when test="$data-type = 'gYearMonth'">
            <xsl:value-of select="$item castable as xs:gYearMonth"/>
         </xsl:when>
         <xsl:when test="$data-type = 'gYear'">
            <xsl:value-of select="$item castable as xs:gYear"/>
         </xsl:when>
         <xsl:when test="$data-type = 'gMonthDay'">
            <xsl:value-of select="$item castable as xs:gMonthDay"/>
         </xsl:when>
         <xsl:when test="$data-type = 'gDay'">
            <xsl:value-of select="$item castable as xs:gDay"/>
         </xsl:when>
         <xsl:when test="$data-type = 'gMonth'">
            <xsl:value-of select="$item castable as xs:gMonth"/>
         </xsl:when>
         <xsl:when test="$data-type = 'hexBinary'">
            <xsl:value-of select="$item castable as xs:hexBinary"/>
         </xsl:when>
         <xsl:when test="$data-type = 'base64Binary'">
            <xsl:value-of select="$item castable as xs:base64Binary"/>
         </xsl:when>
         <xsl:when test="$data-type = 'anyURI'">
            <xsl:value-of select="$item castable as xs:anyURI"/>
         </xsl:when>
         <xsl:when test="$data-type = 'QName'">
            <xsl:value-of select="$item castable as xs:QName"/>
         </xsl:when>
         <!-- the following datatypes are not recognized in a basic XSLT 2.0 processor -->
         <!--<xsl:when test="$data-type = 'normalizedString'">
            <xsl:value-of select="$item castable as xs:normalizedString"/>
         </xsl:when>
         <xsl:when test="$data-type = 'token'">
            <xsl:value-of select="$item castable as xs:token"/>
         </xsl:when>
         <xsl:when test="$data-type = 'language'">
            <xsl:value-of select="$item castable as xs:language"/>
         </xsl:when>
         <xsl:when test="$data-type = 'NMTOKEN'">
            <xsl:value-of select="$item castable as xs:NMTOKEN"/>
         </xsl:when>
         <xsl:when test="$data-type = 'NMTOKENS'">
            <xsl:value-of select="$item castable as xs:NMTOKENS"/>
         </xsl:when>
         <xsl:when test="$data-type = 'Name'">
            <xsl:value-of select="$item castable as xs:Name"/>
         </xsl:when>
         <xsl:when test="$data-type = 'NCName'">
            <xsl:value-of select="$item castable as xs:NCName"/>
         </xsl:when>
         <xsl:when test="$data-type = 'ID'">
            <xsl:value-of select="$item castable as xs:ID"/>
         </xsl:when>
         <xsl:when test="$data-type = 'IDREF'">
            <xsl:value-of select="$item castable as xs:IDREF"/>
         </xsl:when>
         <xsl:when test="$data-type = 'IDREFS'">
            <xsl:value-of select="$item castable as xs:IDREFS"/>
         </xsl:when>
         <xsl:when test="$data-type = 'ENTITY'">
            <xsl:value-of select="$item castable as xs:ENTITY"/>
         </xsl:when>
         <xsl:when test="$data-type = 'ENTITIES'">
            <xsl:value-of select="$item castable as xs:ENTITIES"/>
         </xsl:when>
         <xsl:when test="$data-type = 'integer'">
            <xsl:value-of select="$item castable as xs:integer"/>
         </xsl:when>
         <xsl:when test="$data-type = 'nonPositiveInteger'">
            <xsl:value-of select="$item castable as xs:nonPositiveInteger"/>
         </xsl:when>
         <xsl:when test="$data-type = 'negativeInteger'">
            <xsl:value-of select="$item castable as xs:negativeInteger"/>
         </xsl:when>
         <xsl:when test="$data-type = 'long'">
            <xsl:value-of select="$item castable as xs:long"/>
         </xsl:when>
         <xsl:when test="$data-type = 'int'">
            <xsl:value-of select="$item castable as xs:int"/>
         </xsl:when>
         <xsl:when test="$data-type = 'short'">
            <xsl:value-of select="$item castable as xs:short"/>
         </xsl:when>
         <xsl:when test="$data-type = 'byte'">
            <xsl:value-of select="$item castable as xs:byte"/>
         </xsl:when>
         <xsl:when test="$data-type = 'nonNegativeInteger'">
            <xsl:value-of select="$item castable as xs:nonNegativeInteger"/>
         </xsl:when>
         <xsl:when test="$data-type = 'unsignedLong'">
            <xsl:value-of select="$item castable as xs:unsignedLong"/>
         </xsl:when>
         <xsl:when test="$data-type = 'unsignedInt'">
            <xsl:value-of select="$item castable as xs:unsignedInt"/>
         </xsl:when>
         <xsl:when test="$data-type = 'unsignedShort'">
            <xsl:value-of select="$item castable as xs:unsignedShort"/>
         </xsl:when>
         <xsl:when test="$data-type = 'unsignedByte'">
            <xsl:value-of select="$item castable as xs:unsignedByte"/>
         </xsl:when>
         <xsl:when test="$data-type = 'positiveInteger'">
            <xsl:value-of select="$item castable as xs:positiveInteger"/>
         </xsl:when>-->
         <!-- some workarounds for the above -->
         <xsl:when test="$data-type = 'IDREF'">
            <xsl:value-of select="count(root($item)//id($item)) = 1"/>
         </xsl:when>
         <xsl:when test="$data-type = 'IDREFS'">
            <xsl:value-of select="exists(root($item)//id($item))"/>
         </xsl:when>
         <xsl:when test="$data-type = 'language'">
            <xsl:value-of select="matches($item,'^[a-z]{2,3}(-[A-Z]{2,3}(-[a-zA-Z]{4})?)?$')"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="false()"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <!-- PROCESSING TAN FILES: EXPANSION -->

   <!-- TERSE EXPANSION -->

   <xsl:template match="tan:head" mode="core-expansion-terse">
      <xsl:param name="dependencies" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="this-head" select="."/>
      <xsl:variable name="work-elements" as="element()*">
         <xsl:for-each select="$dependencies/*/tan:head/tan:work">
            <xsl:variable name="this-src" select="/*/@src"/>
            <xsl:variable name="these-equate-works"
               select="$this-head/tan:vocabulary-key/tan:alias[tan:idref = $this-src]"/>
            <xsl:copy>
               <xsl:copy-of select="$this-src"/>
               <xsl:copy-of select="@*"/>
               <xsl:copy-of select="node()"/>
               <xsl:for-each select="$these-equate-works">
                  <equate>
                     <!-- By using the @q value of the <alias>, we set up the routine to look for any other source mentioned by that <alias> -->
                     <xsl:value-of select="@q"/>
                  </equate>
               </xsl:for-each>
            </xsl:copy>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="default-work-collation"
         select="tan:group-elements-by-shared-node-values($work-elements, 'IRI')"/>
      <xsl:variable name="calculated-work-collation"
         select="tan:group-elements-by-shared-node-values($work-elements, 'IRI|equate')"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="default-work-collation" select="$default-work-collation"
               tunnel="yes"/>
            <xsl:with-param name="extra-vocabulary" select="$calculated-work-collation"
               tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:body" mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="vocabulary" select="../tan:head/tan:vocabulary-key"
               tunnel="yes"/>
            <xsl:with-param name="inherited-subjects" select="tan:subject" tunnel="yes"/>
            <xsl:with-param name="inherited-verbs" select="tan:verb" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:claim" mode="core-expansion-terse">
      <xsl:param name="vocabulary" tunnel="yes"/>
      <xsl:param name="inherited-subjects" tunnel="yes"/>
      <xsl:param name="inherited-verbs" tunnel="yes"/>
      <xsl:variable name="immediate-subject-refs" select="tan:subject"/>
      <xsl:variable name="immediate-verb-refs" select="tan:verb"/>

      <xsl:variable name="these-subject-refs"
         select="
            if (exists($immediate-subject-refs)) then
               $immediate-subject-refs
            else
               $inherited-subjects"/>
      <xsl:variable name="these-verb-refs"
         select="
            if (exists($immediate-verb-refs)) then
               $immediate-verb-refs
            else
               $inherited-verbs"/>
      <xsl:variable name="these-object-refs" select="(tan:object, tan:claim)"/>

      <xsl:variable name="these-subjects" select="($these-subject-refs[not(@attr)], $vocabulary/tan:*[@xml:id = $these-subject-refs[@attr]])"/>
      <xsl:variable name="subjects-that-are-not-textual"
         select="$these-subjects[not(name() = $elements-that-refer-to-textual-items or exists((@work, @src)))]"/>

      <xsl:variable name="these-verbs" select="$vocabulary/tan:verb[@xml:id = $these-verb-refs]"/>
      <xsl:variable name="these-verbs-with-object-constraints"
         select="$these-verbs[exists(@object-datatype)]"/>
      <xsl:variable name="verbal-groups"
         select="
            for $i in $these-verbs
            return
               tokenize($i/@orig-group, '\s+')"/>

      <xsl:variable name="these-objects"
         select="($these-object-refs[not(@attr)], $vocabulary/tan:*[@xml:id = $these-object-refs[@attr]])"/>
      <xsl:variable name="objects-that-are-not-textual"
         select="$these-objects[not(name() = $elements-that-refer-to-textual-items or exists((@work, @src)))]"/>

      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($these-verbs-with-object-constraints)">
            <xsl:if test="not(exists(tan:object))">
               <xsl:copy-of select="tan:error('clm01')"/>
            </xsl:if>
            <xsl:if test="count($these-verbs) gt 1">
               <xsl:copy-of select="tan:error('clm02')"/>
            </xsl:if>
         </xsl:if>
         <xsl:if test="not(exists($these-subject-refs))">
            <xsl:copy-of select="tan:error('clm05')"/>
         </xsl:if>
         <xsl:if test="not(exists($these-verb-refs)) and not(exists(tan:claim))">
            <xsl:copy-of select="tan:error('clm07')"/>
         </xsl:if>
         <xsl:if test="not(exists($these-object-refs)) and $verbal-groups = 'object-required'">
            <xsl:copy-of select="tan:error('clm06', 'object is required')"/>
         </xsl:if>
         <xsl:if
            test="$verbal-groups = 'text-subject' and exists($subjects-that-are-not-textual)">
            <xsl:copy-of select="tan:error('clm06', 'subjects must be textual')"/>
         </xsl:if>
         <xsl:if
            test="$verbal-groups = 'text-object' and exists($objects-that-are-not-textual)">
            <xsl:copy-of select="tan:error('clm06', 'objects must be textual')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="verbs" select="$these-verbs"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:object" mode="core-expansion-terse">
      <xsl:param name="verbs" as="element()*"/>
      <xsl:variable name="this-text" select="text()[matches(., '\S')][1]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each select="$verbs[@object-datatype]">
            <xsl:variable name="this-datatype" select="@object-datatype"/>
            <xsl:variable name="this-lexical-constraint" select="@object-lexical-constraint"/>
            <xsl:if test="not(tan:data-type-check($this-text, $this-datatype))">
               <xsl:variable name="help-message"
                  select="concat('value must match data type ', $this-datatype)"/>
               <xsl:copy-of select="tan:error('clm03', $help-message)"/>
            </xsl:if>
            <xsl:if
               test="exists($this-lexical-constraint) and not(matches($this-text, $this-lexical-constraint))">
               <xsl:variable name="help-message"
                  select="concat('value must match pattern ', $this-lexical-constraint)"/>
               <xsl:copy-of select="tan:error('clm04', $help-message)"/>
            </xsl:if>
         </xsl:for-each>

         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>


   <!-- NORMAL EXPANSION -->

   <xsl:template match="tan:work[ancestor::tan:claim]" mode="core-expansion-normal">
      <xsl:variable name="this-work-id" select="."/>
      <xsl:variable name="this-work-group" select="/tan:TAN-A-div/tan:head/tan:vocabulary-key/tan:group[tan:work/@src = $this-work-id]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:value-of select="$this-work-group/@n"/>
      </xsl:copy>
   </xsl:template>

   <!-- VERBOSE EXPANSION -->

   <!-- pending -->

</xsl:stylesheet>
