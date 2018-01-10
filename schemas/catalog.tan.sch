<?xml version="1.0" encoding="UTF-8"?>
<schema xmlns="http://purl.oclc.org/dsdl/schematron"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" queryBinding="xslt2">
    <title>Tests for catalog.tan.xml files.</title>
    <ns prefix="tan" uri="tag:textalign.net,2015:ns"/>
    <pattern id="terse-true">
        <xsl:param name="validation-is-terse" select="true()"/>
    </pattern>
    <include href="incl/TAN-core.sch"/>
    <xsl:include href="../functions/catalog.tan-functions.xsl"/>
</schema>
