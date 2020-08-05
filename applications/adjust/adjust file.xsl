<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns="tag:textalign.net,2015:ns"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="3.0">
    <!-- Catalyzing input: any XML file -->
    <!-- Secondary input: none, unless you specify it -->
    <!-- Primary output: ad hoc adjustments, as defined below -->
    <!-- This stylesheet is intended to make minor adjustments to a document on a case-by-case basis -->
    <xsl:output method="xml" indent="yes"/>
    
    <xsl:include href="../../functions/TAN-A-functions.xsl"/>
    <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
    
    <!-- THIS STYLESHEET -->
    
    <xsl:param name="stylesheet-iri" select="'tag:textalign.net,2015:stylesheet:remodel-via-tan-t'"/>
    <xsl:variable name="stylesheet-url" select="static-base-uri()"/>
    <xsl:param name="change-message">
        <xsl:value-of select="'Ad hoc adjustments made to ' || base-uri(/) || '.'"/>
    </xsl:param>
    
    
    <xsl:template match="node() | @*">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="/node()">
        <!-- This template presumes that nodes attached to the document node should be on separate lines -->
        <xsl:text>&#xa;</xsl:text>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
