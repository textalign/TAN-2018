<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:tei="http://www.tei-c.org/ns/1.0"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="#all"
   version="2.0">

   <!-- Core functions for TAN-A files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:include href="incl/TAN-class-1-functions.xsl"/>
   <xsl:include href="incl/TAN-class-2-functions.xsl"/>
   <xsl:include href="incl/TAN-class-3-functions.xsl"/>
   <xsl:include href="incl/TAN-core-functions.xsl"/>

   <!-- GLOBAL VARIABLES -->

   <xsl:variable name="subjects-target-what-elements-names"
      select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs[@attribute = 'subject']]/tan:element"/>
   <xsl:variable name="objects-target-what-elements-names"
      select="$id-idrefs/tan:id-idrefs/tan:id[tan:idrefs[@attribute = 'object']]/tan:element"/>

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
            <xsl:value-of select="matches($item, '^[a-z]{2,3}(-[A-Z]{2,3}(-[a-zA-Z]{4})?)?$')"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="false()"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>

   <!-- PROCESSING TAN FILES: EXPANSION -->

   <!-- TERSE EXPANSION -->

   <xsl:template match="tan:work[ancestor::tan:claim]" mode="expand-work">
      <xsl:variable name="this-work-id" select="."/>
      <xsl:variable name="this-work-group"
         select="/tan:TAN-A/tan:head/tan:vocabulary-key/tan:group[tan:work/@src = $this-work-id]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:value-of select="$this-work-group/@n"/>
      </xsl:copy>
      <xsl:copy-of select="."/>
      <!--<xsl:for-each select="$this-work-group/*">
         <src>
            <xsl:value-of select="@src"/>
         </src>
      </xsl:for-each>-->
   </xsl:template>

   <xsl:template match="tan:head" priority="1" mode="core-expansion-terse">
      <xsl:param name="dependencies" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="this-head" select="."/>
      <xsl:variable name="token-definition-source-duplicates"
         select="tan:duplicate-items(tan:token-definition/tan:src)"/>
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
            <xsl:with-param name="extra-vocabulary" select="$calculated-work-collation" tunnel="yes"/>
            <xsl:with-param name="token-definition-errors"
               select="$token-definition-source-duplicates"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:body" mode="core-expansion-terse">
      <xsl:variable name="this-vocabulary"
         select="preceding-sibling::tan:head/(tan:vocabulary-key, tan:tan-vocabulary, tan:vocabulary)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="vocabulary" select="$this-vocabulary" tunnel="yes"/>
            <xsl:with-param name="local-head" select="preceding-sibling::tan:head" tunnel="yes"/>
            <xsl:with-param name="inherited-subjects" select="tan:subject" tunnel="yes"/>
            <xsl:with-param name="inherited-verbs" select="tan:verb" tunnel="yes"/>
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:claim" mode="core-expansion-terse">
      <xsl:param name="local-head" tunnel="yes"/>
      <xsl:param name="inherited-subjects" tunnel="yes"/>
      <xsl:param name="inherited-verbs" tunnel="yes"/>
      <xsl:variable name="immediate-subject-refs" select="tan:subject"/>
      <xsl:variable name="immediate-verb-refs" select="tan:verb"/>

      <!-- subjects -->
      <xsl:variable name="these-subject-refs"
         select="
            if (exists($immediate-subject-refs)) then
               $immediate-subject-refs
            else
               $inherited-subjects"/>
      <xsl:variable name="these-entity-subject-refs" select="$these-subject-refs[@attr]"/>
      <xsl:variable name="these-textual-passage-subject-refs"
         select="$these-subject-refs except $these-entity-subject-refs"/>
      <xsl:variable name="this-entity-subject-vocab"
         select="
            for $i in $these-entity-subject-refs
            return
               tan:vocabulary($subjects-target-what-elements-names, false(), $i, $local-head, false())"/>
      <xsl:variable name="these-entity-subject-vocab-items"
         select="$this-entity-subject-vocab/(* except (tan:IRI, tan:name, tan:desc, tan:location, tan:comment))"/>
      <xsl:variable name="these-subject-textual-entities"
         select="$these-entity-subject-vocab-items[(name(.), tan:affects-element) = $names-of-elements-that-describe-textual-entities]"/>
      <xsl:variable name="these-subject-nontextual-entities"
         select="$these-entity-subject-vocab-items except $these-subject-textual-entities"/>
      <xsl:variable name="these-subject-textual-artefact-entities"
         select="$these-subject-textual-entities[(name(.), tan:affects-element) = $names-of-elements-that-describe-text-bearers]"/>
      <xsl:variable name="these-subject-nontextual-artefact-entities"
         select="$these-entity-subject-vocab-items except $these-subject-textual-artefact-entities"/>

      <!-- verbs -->
      <xsl:variable name="these-verb-refs"
         select="
            if (exists($immediate-verb-refs)) then
               $immediate-verb-refs
            else
               $inherited-verbs"/>
      <xsl:variable name="this-verb-vocab"
         select="
            for $i in $these-verb-refs
            return
               tan:vocabulary('verb', false(), $i, $local-head, false())"/>
      <xsl:variable name="these-verb-vocab-items"
         select="$this-verb-vocab/(* except (tan:IRI, tan:name, tan:desc, tan:location, tan:comment))"/>
      <xsl:variable name="these-verbs-with-general-constraints"
         select="$these-verb-vocab-items[tan:group]"/>
      <xsl:variable name="these-verbs-with-object-data-constraints"
         select="$these-verb-vocab-items[exists(@object-datatype)]"/>
      <xsl:variable name="verbal-groups" select="$these-verbs-with-general-constraints/tan:group"/>


      <!-- objects -->
      <xsl:variable name="these-object-refs" select="(tan:object, tan:claim)"/>
      <xsl:variable name="these-entity-object-refs" select="$these-object-refs[@attr]"/>
      <xsl:variable name="these-textual-passage-object-refs"
         select="$these-object-refs[tan:src or tan:work]"/>
      <xsl:variable name="this-entity-object-vocab"
         select="
            for $i in $these-entity-object-refs
            return
               tan:vocabulary($objects-target-what-elements-names, false(), $i, $local-head, false())"/>
      <xsl:variable name="these-entity-object-vocab-items"
         select="$this-entity-object-vocab/(* except (tan:IRI, tan:name, tan:desc, tan:location, tan:comment))"/>
      <xsl:variable name="these-object-textual-entities"
         select="$these-entity-object-vocab-items[(name(.), tan:affects-element) = $names-of-elements-that-describe-textual-entities]"/>
      <xsl:variable name="these-object-nontextual-entities"
         select="$these-entity-object-vocab-items except $these-object-textual-entities"/>
      <xsl:variable name="these-object-textual-artefact-entities" 
         select="$these-object-textual-entities[(name(.), tan:affects-element) = $names-of-elements-that-describe-text-bearers]"/>
      <xsl:variable name="these-object-nontextual-artefact-entities"
         select="$these-entity-object-vocab-items except $these-object-textual-artefact-entities"/>
      <xsl:variable name="these-data-object-refs"
         select="$these-object-refs except ($these-entity-object-refs, $these-textual-passage-object-refs)"/>


      <!-- loci -->
      <xsl:variable name="these-loci" select="tan:at"/>

      <xsl:variable name="diagnostics-on" select="exists(tan:verb[matches(., 'claims')])"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'diagnostics on, template mode core-expansion-terse, for: ', ."/>
         <xsl:message select="'subjects inherited: ', $inherited-subjects"/>
         <xsl:message select="'subjects: entities: ', $these-entity-subject-vocab-items"/>
         <xsl:message select="'subjects: textual passages: ', $these-textual-passage-subject-refs"/>
         <xsl:message select="'verbs inherited: ', $inherited-verbs"/>
         <xsl:message select="'verb refs actual: ', $these-verb-refs"/>
         <xsl:message select="'verb vocab items: ', $these-verb-vocab-items"/>
         <xsl:message
            select="'verbs with object constraints: ', $these-verbs-with-object-data-constraints"/>
         <xsl:message select="'verbal groups: ', $verbal-groups"/>
         <xsl:message select="'objects: entities: ', $these-entity-object-vocab-items"/>
         <xsl:message select="'objects: textual passages: ', $these-textual-passage-object-refs"/>
         <xsl:message select="'objects: data: ', $these-data-object-refs"/>
      </xsl:if>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <!-- subject problems -->
         <xsl:if test="not(exists($these-subject-refs))">
            <xsl:copy-of select="tan:error('clm05')"/>
         </xsl:if>
         <!-- verb problems -->
         <!-- verb data constraint problems -->
         <xsl:if test="exists($these-verbs-with-object-data-constraints)">
            <!-- if data is expected, no object should be an entity or a textual passage -->
            <xsl:if test="exists(tan:object[@attr]) or exists(tan:object[@src or @work])">
               <xsl:copy-of select="tan:error('clm01')"/>
            </xsl:if>
            <xsl:if test="count($these-verb-vocab-items) gt 1">
               <xsl:copy-of select="tan:error('clm02')"/>
            </xsl:if>
         </xsl:if>
         <xsl:if test="not(exists($these-verb-refs)) and not(exists(tan:claim))">
            <xsl:copy-of select="tan:error('clm07')"/>
         </xsl:if>
         <!-- verb general constraint problems -->
         <xsl:if test="$verbal-groups = 'claim object' and (exists(tan:object) or not(exists(tan:claim)))">
            <xsl:copy-of select="tan:error('vrb01')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'one object' and not(count($these-object-refs) = 1)">
            <xsl:copy-of select="tan:error('vrb02')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'one or more loci' and not(exists($these-loci))">
            <xsl:copy-of select="tan:error('vrb03')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'one or more objects' and not(exists($these-object-refs))">
            <xsl:copy-of select="tan:error('vrb04')"/>
         </xsl:if>
         <xsl:if
            test="
               $verbal-groups = 'textual artefact or passage object'
               and exists($these-object-nontextual-artefact-entities)">
            <xsl:copy-of select="tan:error('vrb05')"/>
         </xsl:if>
         <xsl:if
            test="
               $verbal-groups = 'textual artefact or passage subject'
               and exists($these-subject-nontextual-artefact-entities)">
            <xsl:copy-of select="tan:error('vrb06')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'textual entity subject' and exists($these-subject-nontextual-entities)">
            <xsl:copy-of select="tan:error('vrb07')"/>
         </xsl:if>
         <xsl:if
            test="$verbal-groups = 'textual object' and exists($these-object-nontextual-entities)">
            <xsl:copy-of select="tan:error('vrb08')"/>
         </xsl:if>
         <xsl:if
            test="$verbal-groups = 'textual subject' and exists($these-subject-nontextual-entities)">
            <xsl:copy-of select="tan:error('vrb09')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'zero loci' and exists($these-loci)">
            <xsl:copy-of select="tan:error('vrb10')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'zero objects' and exists($these-object-refs)">
            <xsl:copy-of select="tan:error('vrb11')"/>
         </xsl:if>



         <!--<xsl:if
            test="
               $verbal-groups = 'textual entity subject'
               and (exists($these-textual-passage-subject-refs) or exists($these-subject-nontextual-entities))">
            <xsl:copy-of select="tan:error('vrb01')"/>
         </xsl:if>
         <xsl:if
            test="$verbal-groups = 'textual entity object'
            and (exists($these-textual-passage-object-refs) or exists($these-object-nontextual-entities) or exists($these-data-object-refs))">
            <xsl:copy-of select="tan:error('vrb02')"/>
         </xsl:if>
         <xsl:if
            test="$verbal-groups = 'textual passage subject' 
            and (exists($these-entity-subject-vocab-items))">
            <xsl:copy-of select="tan:error('vrb03')"/>
         </xsl:if>
         <xsl:if
            test="
               $verbal-groups = 'textual passage object'
               and (exists($these-entity-object-vocab-items))">
            <xsl:copy-of select="tan:error('vrb04')"/>
         </xsl:if>
         <xsl:if
            test="
               $verbal-groups = 'textual subject'
               and exists($these-subject-nontextual-entities)">
            <xsl:copy-of select="tan:error('vrb05')"/>
         </xsl:if>
         <xsl:if
            test="
               $verbal-groups = 'textual object'
               and exists($these-object-nontextual-entities)">
            <xsl:copy-of select="tan:error('vrb06')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'object required' 
            and not(exists($these-object-refs))">
            <xsl:copy-of select="tan:error('vrb07')"/>
         </xsl:if>
         <xsl:if test="$verbal-groups = 'object disallowed' 
            and exists($these-object-refs)">
            <xsl:copy-of select="tan:error('vrb08')"/>
         </xsl:if>
         <xsl:if
            test="$verbal-groups = 'textual entity subject' and (exists($these-subject-nontextual-entities) or exists($these-textual-passage-subject-refs))">
            <xsl:copy-of select="tan:error('vrb05')"/>
         </xsl:if>
         <!-\- locus problems -\->
         <xsl:if test="$verbal-groups = 'locus based' and not(exists($these-loci))">
            <xsl:copy-of select="tan:error('clm06', concat('at least one locus (&lt;at>) is required for the verb ', string-join($these-verbs-with-general-constraints[tan:group = 'locus-based']/tan:name[1], ', ')))"/>
         </xsl:if>-->
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="verbs" select="$these-verb-vocab-items"/>
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



   <!-- VERBOSE EXPANSION -->

   <!-- pending -->

</xsl:stylesheet>
