<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    tan:test="hello"
    xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="3.0">
    
    <!-- Primary (catalyzing) input: any TAN file -->
    <!-- Secondary input: none -->
    <!-- Primary output: perhaps diagnostics -->
    <!-- Secondary output: an HTML file -->
    <!-- Resultant output will need attention, because of how unpredictable CSS and JavaScript dependencies might be. -->
    
    <xsl:param name="output-diagnostics-on" static="yes" as="xs:boolean" select="false()"/>
    
    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:import href="../get%20inclusions/convert-TAN-to-HTML.xsl"/>
    
    <xsl:output method="html" use-when="not($output-diagnostics-on)"/>
    <xsl:output method="xml" indent="yes" use-when="$output-diagnostics-on"/>
    
    
    <!-- THIS STYLESHEET -->
    <xsl:param name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:display-tan-as-html'"/>
    <xsl:param name="stylesheet-name" select="'TAN to HTML converter'"/>
    <xsl:param name="stylesheet-url" select="static-base-uri()"/>
    <xsl:param name="change-message" select="'Converted tan file to html. The quality of results will depend significantly upon any linked CSS or JavaScript files.'"/>
    <xsl:param name="stylesheet-is-core-tan-application" select="true()"/>
    <xsl:param name="stylesheet-to-do-list">
        <to-do xmlns="tag:textalign.net,2015:ns">
            <comment who="kalvesmaki" when="2020-07-28">Need to wholly overhaul the default CSS and JavaScript files in output/css and output/js</comment>
            <comment who="kalvesmaki" when="2020-07-28">Need to build parameters to allow users to drop elements from the HTML DOM.</comment>
        </to-do>
    </xsl:param>
    
    
    <xsl:param name="validation-phase" select="'terse'"/>
    <xsl:param name="input-items" select="$self-expanded"/>
    <xsl:param name="default-html-template" as="xs:string" select="resolve-uri('../../templates/template.html', static-base-uri())"/>
    <xsl:param name="template-url-relative-to-actual-input" select="$default-html-template"/>
    
    <xsl:param name="output-filename" select="tan:cfn($doc-uri) || '.html'"/>
    
    <xsl:param name="input-pass-4" select="tan:tan-to-html($input-pass-3)" as="item()*"/>
    
    <xsl:template match="/" use-when="$output-diagnostics-on">
        <diagnostics>
            <input-pass-1><xsl:copy-of select="$input-pass-1"/></input-pass-1>
            <input-as-html><xsl:copy-of select="$input-pass-4"/></input-as-html>
        </diagnostics>
    </xsl:template>

</xsl:stylesheet>
