<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" exclude-result-prefixes="#all" version="2.0">
   <xsl:output indent="yes"/>
   <!-- Catalyzing and main input: any xslt stylesheet -->
   <!-- Primary output: that same stylesheet, but with the children of the root element re-sorted in order of dependency, from least dependent to most -->
   <!-- Secondary output: none -->
   <!-- Results should be checked carefully. Comments will be sorted with independent elements, and inclusions or imports will not be taken into account -->

   <!-- THIS STYLESHEET -->
   <xsl:param name="stylesheet-iri"
      select="'tag:textalign.net,2015:stylesheet:re-sort-xslt-stylesheet'"/>
   <xsl:param name="stylesheet-name" select="'Re-sorter of XSLT file'"/>
   <xsl:param name="stylesheet-url" select="static-base-uri()"/>
   <xsl:param name="stylesheet-is-core-tan-application" select="true()"/>
   

   <xsl:include href="../get%20inclusions/XSLT%20analysis.xsl"/>
   <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>

   <xsl:variable name="original" select="/"/>
   <xsl:variable name="analysis-pass-1" as="element()">
      <stylesheet>
         <xsl:for-each select="/*/node()">
            <node n="{position()}">
               <xsl:choose>
                  <xsl:when test=". instance of text()">
                     <xsl:attribute name="type" select="'text'"/>
                  </xsl:when>
                  <xsl:when test=". instance of comment()">
                     <xsl:attribute name="type" select="'comment'"/>
                  </xsl:when>
                  <xsl:when test=". instance of processing-instruction()">
                     <xsl:attribute name="type" select="'processing instruction'"/>
                  </xsl:when>
                  <xsl:when test=". instance of element()">
                     <xsl:variable name="this-component-name" select="name(.)"/>
                     <xsl:attribute name="type" select="'element'"/>
                     <xsl:attribute name="name" select="$this-component-name"/>
                     <xsl:if test="exists(@name)">
                        <xsl:variable name="this-regex"
                           select="tan:regex-for-component(@name, $this-component-name, false())"/>
                        <name>
                           <xsl:value-of select="@name"/>
                        </name>
                        <xsl:if test="exists($this-regex)">
                           <xpath-regex>
                              <xsl:value-of select="$this-regex"/>
                           </xpath-regex>
                        </xsl:if>
                     </xsl:if>
                     <xsl:for-each select="tokenize(@mode, '\s+')">
                        <name type="mode">
                           <xsl:value-of select="."/>
                        </name>
                     </xsl:for-each>
                  </xsl:when>
               </xsl:choose>
            </node>
         </xsl:for-each>
      </stylesheet>
   </xsl:variable>
   
   <xsl:template match="*" mode="mark-dependencies">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:node[@type = 'element']" mode="mark-dependencies">
      <xsl:variable name="this-node" select="."/>
      <xsl:variable name="this-element-number"
         select="count(preceding-sibling::tan:node[@type = 'element']) + 1"/>
      <xsl:variable name="original-element" select="$original/*/*[$this-element-number]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="node()"/>
         <xsl:for-each select="$analysis-pass-1//tan:node[not(@n = $this-node/@n)]/tan:xpath-regex">
            <xsl:variable name="this-regex" select="text()"/>
            <xsl:if
               test="
                  some $i in $original-element//@*
                     satisfies matches($i, $this-regex)">
               <depends-upon>
                  <xsl:value-of select="../@n"/>
               </depends-upon>
            </xsl:if>
         </xsl:for-each>
         <xsl:for-each select="$analysis-pass-1//tan:node[@name = 'xsl:template']/tan:name[not(@type)]">
            <xsl:variable name="this-name" select="."/>
            <xsl:if test="exists($original-element//xsl:call-templates[@name = $this-name])">
               <depends-upon>
                  <xsl:value-of select="../@n"/>
               </depends-upon>
            </xsl:if>
         </xsl:for-each>
         <xsl:for-each select="$analysis-pass-1//tan:name[@type = 'mode']">
            <xsl:variable name="this-mode" select="."/>
            <xsl:if test="exists($original-element//xsl:apply-templates[(@mode = $this-mode) and not(@mode = $original-element/@mode)])">
               <depends-upon>
                  <xsl:value-of select="../@n"/>
               </depends-upon>
            </xsl:if>
         </xsl:for-each>
      </xsl:copy>
   </xsl:template>
   <xsl:variable name="analysis-pass-2" as="element()">
      <xsl:apply-templates select="$analysis-pass-1" mode="mark-dependencies"/>
   </xsl:variable>
   
   <xsl:function name="tan:reorder-by-dependence-loop" as="element()?">
      <!-- Input: an element with children elements to be reordered; an element with the results so far -->
      <!-- Output: resultant element with the child elements reordered from least dependent to most -->
      <xsl:param name="element-with-children-to-reorder" as="element()"/>
      <xsl:param name="results-so-far" as="element()?"/>
      <xsl:param name="loop-counter" as="xs:integer"/>
      <xsl:variable name="next-children-to-add"
         select="
            $element-with-children-to-reorder/*[not(exists(tan:depends-upon))
            or (every $i in tan:depends-upon
               satisfies $i = ($results-so-far/*/@n, @n))]"
      />
      <xsl:variable name="new-param-1" as="element()">
         <xsl:element name="{name($element-with-children-to-reorder)}">
            <xsl:copy-of select="$element-with-children-to-reorder/@*"/>
            <xsl:copy-of select="$element-with-children-to-reorder/* except $next-children-to-add"/>
         </xsl:element>
      </xsl:variable>
      <xsl:variable name="new-param-2" as="element()">
         <xsl:element name="{name($element-with-children-to-reorder)}">
            <xsl:copy-of select="$results-so-far/@*"/>
            <xsl:copy-of select="$results-so-far/*"/>
            <xsl:copy-of select="$next-children-to-add"/>
         </xsl:element>
      </xsl:variable>
      <xsl:choose>
         <xsl:when test="not(exists($element-with-children-to-reorder/*)) or $loop-counter gt $loop-tolerance">
            <xsl:copy-of select="$results-so-far"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="tan:reorder-by-dependence-loop($new-param-1, $new-param-2, $loop-counter + 1)"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   <xsl:variable name="analysis-pass-3"
      select="tan:reorder-by-dependence-loop($analysis-pass-2, (), 0)"/>
   <xsl:variable name="new-sequence" as="xs:integer*" select="$analysis-pass-3/*/@n"/>

   <xsl:template match="comment() | processing-instruction()">
      <xsl:copy-of select="."/>
   </xsl:template>
   <xsl:template match="/*">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         
         <!-- diagnostics, troubleshooting -->
         <!--<xsl:copy-of select="$analysis-pass-1"/>-->
         <!--<xsl:copy-of select="$analysis-pass-2"/>-->
         <!--<xsl:copy-of select="$analysis-pass-3"/>-->
         <!--<xsl:copy-of select="$new-sequence"/>-->
         
         <!-- results -->
         <xsl:for-each select="node()">
            <xsl:sort select="index-of($new-sequence, position())"/>
            <xsl:copy-of select="."/>
         </xsl:for-each>
      </xsl:copy>
   </xsl:template>
</xsl:stylesheet>
