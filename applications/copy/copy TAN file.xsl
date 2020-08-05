<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="2.0">

    <!-- Primary (catalyzing) input: any TAN file -->
    <!-- Secondary input: a copy location -->
    <!-- Primary output: none -->
    <!-- Secondary output: the file copied to the target location, revising any relative @hrefs in light of the target location -->
    
    <!-- July 2020: When you use this application in the context of an oXygen dialogue, you should type the 
        path directly into the bar. If you use the navigation feature you will be required to select a file that you wish 
        to overwrite. -->

    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:output indent="no" use-character-maps="tan"/>
    
    <xsl:param name="copy-to" as="xs:string" required="yes"/>
    <xsl:variable name="copy-to-resolved" select="resolve-uri($copy-to, $doc-uri)"/>
    
    <!-- THIS STYLESHEET -->
    <xsl:param name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:copy-tan-file'"/>
    <xsl:param name="stylesheet-url" select="static-base-uri()"/>
    <xsl:param name="change-message" select="'Copied file from', $doc-uri, 'to', $copy-to-resolved"/>
    <xsl:param name="stylesheet-is-core-tan-application" select="true()"/>

    <xsl:variable name="self-hrefs-resolved" as="document-node()"
        select="tan:revise-hrefs(/, $doc-uri, $copy-to-resolved)"/>
    
    <xsl:template match="document-node()" mode="revise-hrefs" priority="1">
        <xsl:document>
            <xsl:for-each select="node()">
                <xsl:text>&#xa;</xsl:text>
                <xsl:apply-templates select="." mode="#current"/>
            </xsl:for-each>
        </xsl:document>
    </xsl:template>
    
    <xsl:template match="/">
        <xsl:message select="'Saving to', $copy-to-resolved"/>
        <xsl:result-document href="{$copy-to-resolved}">
            <xsl:copy-of select="$self-hrefs-resolved"/>
        </xsl:result-document>
    </xsl:template>
    
</xsl:stylesheet>
