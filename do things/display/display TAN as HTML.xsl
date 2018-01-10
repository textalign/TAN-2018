<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:import href="../get%20inclusions/convert-TAN-to-HTML.xsl"/>
    <xsl:output method="html" indent="yes"/>
    
    <xsl:param name="validation-phase" select="'verbose'"/>
    <xsl:param name="input-items" select="$self-expanded"/>
    <xsl:param name="target-format" select="'html'"/>

</xsl:stylesheet>
