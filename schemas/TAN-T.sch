<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform" queryBinding="xslt2">
   <title>Tests for TAN-T files.</title>
   <ns prefix="tan" uri="tag:textalign.net,2015:ns"/>
   <phase id="terse">
      <active pattern="core-tests"/>
      <active pattern="terse-true"/>
   </phase>
   <phase id="normal">
      <active pattern="core-tests"/>
      <active pattern="normal-true"/>
   </phase>
   <phase id="verbose">
      <active pattern="core-tests"/>
      <active pattern="verbose-true"/>
   </phase>
   <pattern id="terse-true">
      <xsl:param name="validation-is-terse" select="true()"/>
   </pattern>
   <pattern id="normal-true">
      <xsl:param name="validation-is-normal" select="true()"/>
   </pattern>
   <pattern id="verbose-true">
      <xsl:param name="validation-is-verbose" select="true()"/>
   </pattern>
   <include href="incl/TAN-core.sch"/>
   <xsl:include href="../functions/TAN-T-functions.xsl"/>
</schema>
