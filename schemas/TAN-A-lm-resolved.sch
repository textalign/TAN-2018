<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform" queryBinding="xslt2">
   <title>Tests for TAN-A-lm files.</title>
   <ns prefix="tan" uri="tag:textalign.net,2015:ns"/>
   <pattern xmlns="http://purl.oclc.org/dsdl/schematron"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform" id="terse-true">
      <xsl:param name="validation-is-terse" select="true()"/>
   </pattern>
   <pattern xmlns="http://purl.oclc.org/dsdl/schematron"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform" id="normal-true">
      <xsl:param name="validation-is-normal" select="true()"/>
   </pattern>
   <pattern xmlns="http://purl.oclc.org/dsdl/schematron"
      xmlns:xsl="http://www.w3.org/1999/XSL/Transform" id="verbose-true">
      <xsl:param name="validation-is-verbose" select="true()"/>
   </pattern>
   <phase id="terse"  xmlns="http://purl.oclc.org/dsdl/schematron">
      <active pattern="core-tests"/>
      <active pattern="terse-true"/>
   </phase>
   <phase id="normal"  xmlns="http://purl.oclc.org/dsdl/schematron">
      <active pattern="core-tests"/>
      <active pattern="normal-true"/>
   </phase>
   <phase id="verbose"  xmlns="http://purl.oclc.org/dsdl/schematron">
      <active pattern="core-tests"/>
      <active pattern="verbose-true"/>
   </phase>
   <include href="incl/TAN-core.sch"/>
   <xsl:include href="../functions/TAN-A-lm-functions.xsl"/>
</schema>
