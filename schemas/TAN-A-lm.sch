<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
   xmlns:xsl="http://www.w3.org/1999/XSL/Transform" queryBinding="xslt2">
   <title>Tests for TAN-A-lm files.</title>
   <ns prefix="tan" uri="tag:textalign.net,2015:ns"/>
   <include href="incl/sch-pattern-terse.sch"/>
   <include href="incl/sch-pattern-normal.sch"/>
   <include href="incl/sch-pattern-verbose.sch"/>
   <include href="incl/sch-phase-terse.sch"/>
   <include href="incl/sch-phase-normal.sch"/>
   <include href="incl/sch-phase-verbose.sch"/>
   <include href="incl/TAN-core.sch"/>
   <xsl:include href="../functions/TAN-A-lm-functions.xsl"/>
</schema>
