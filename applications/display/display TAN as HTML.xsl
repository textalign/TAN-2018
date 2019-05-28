<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:import href="../get%20inclusions/convert-TAN-to-HTML.xsl"/>
    <xsl:output method="html" indent="yes"/>
    
    <!-- THIS STYLESHEET -->
    
    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:display-tan-as-html'"/>
    <xsl:variable name="stylesheet-url" select="static-base-uri()"/>
    <xsl:variable name="change-message" select="'Converted tan file to html'"/>
    
    <xsl:param name="validation-phase" select="'terse'"/>
    <xsl:param name="input-items" select="$self-expanded"/>
    <xsl:param name="default-html-template" as="xs:string" select="resolve-uri('../../templates/template.html', static-base-uri())"/>
    <xsl:param name="template-url-relative-to-actual-input" select="$default-html-template"/>
    
    <xsl:param name="output-directory-relative-to-template" as="xs:string?"
        select="'../../output/html/'"/>
    
    <xsl:param name="input-pass-4" select="tan:tan-to-html($input-pass-3)" as="item()*"/>
    
    <!--<xsl:template match="/" priority="5">
        <!-\-<xsl:copy-of select="$self-expanded[*/@src = 'ara-2']"/>-\->
        <!-\-<xsl:copy-of select="tan:shallow-copy($input-items//tan:body/*)"/>-\->
        <xsl:copy-of select="$input-pass-1"/>
        <!-\-<xsl:copy-of select="$input-pass-2"/>-\->
        <!-\-<test20a><xsl:copy-of select="tan:collate-sequences($test20)"/></test20a>-\->
        <!-\-<test10a><xsl:value-of select="$template-url-resolved"/></test10a>-\->
        <!-\-<xsl:copy-of select="$template-doc"/>-\->
        <!-\-<test10b><xsl:value-of select="$output-url-resolved"/></test10b>-\->
        <!-\-<xsl:copy-of select="$template-infused-with-revised-input"/>-\->
    </xsl:template>-->

</xsl:stylesheet>
