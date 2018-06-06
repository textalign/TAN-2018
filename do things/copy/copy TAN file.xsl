<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="2.0">

    <!-- Input: any TAN file; a copy location -->
    <!-- Output: the file copied to the target location, resolving all relative @hrefs -->

    <!--<xsl:import href="../../functions/TAN-A-div-functions.xsl"/>-->
    <xsl:import href="../get%20inclusions/convert.xsl"/>
    <xsl:output indent="no" use-character-maps="tan"/>
    
    <xsl:param name="copy-to" as="xs:string" required="yes"/>
    <xsl:variable name="copy-to-resolved" select="resolve-uri($copy-to, $doc-uri)"/>
    
    <!-- THIS STYLESHEET -->

    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:copy-tan-file'"/>
    <xsl:variable name="stylesheet-url" select="static-base-uri()"/>
    <xsl:variable name="change-message" select="'Copied file from', $doc-uri, 'to', $copy-to-resolved"/>

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
