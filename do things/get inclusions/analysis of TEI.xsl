<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:tan="tag:textalign.net,2015:ns" xmlns="tag:textalign.net,2015:ns"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="2.0">
   <!-- global variables to analyze TEI -->
   
   <xsl:variable name="milestoneLike-element-info" as="element()">
      <milestones>
         <group type="anchor">
            <element name="anchor"/>
         </group>
         <group type="fw">
            <!-- technically, fw is rather unlike the other elements in this class, in that it is not empty -->
            <element name="fw"/>
         </group>
         <group type="scriptum">
            <element name="gb" idref="gathering" which="gathering"/>
            <element name="pb" idref="page" which="page"/>
            <element name="cb" idref="column" which="column (page)"/>
            <element name="lb" idref="line" which="line (physical)"/>
         </group>
         <group type="untyped">
            <element name="milestone"/>
         </group>
      </milestones>
   </xsl:variable>
   
</xsl:stylesheet>
