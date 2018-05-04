<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="2.0">

    <!-- Input: any TAN file; a copy location -->
    <!-- Output: the file copied to the target location, resolving all relative @hrefs -->

    <xsl:import href="../../functions/TAN-A-div-functions.xsl"/>
    <xsl:import href="../get%20inclusions/core-for-TAN-output.xsl"/>
    <xsl:output indent="no" use-character-maps="tan"/>
    
    <xsl:param name="copy-to" as="xs:string" required="yes"/>
    <xsl:variable name="copy-to-resolved" select="resolve-uri($copy-to, $doc-uri)"/>
    
    <!-- THIS STYLESHEET -->

    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:copy-tan-file'"/>
    <xsl:variable name="stylesheet-url" select="static-base-uri()"/>
    <xsl:variable name="change-message" select="'Copied file from', $doc-uri, 'to', $copy-to-resolved"/>

    <xsl:variable name="self-hrefs-resolved" as="document-node()">
        <xsl:apply-templates select="/" mode="revise-hrefs"/>
    </xsl:variable>
    
    <xsl:template match="node() | @*" mode="revise-hrefs">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="document-node()" mode="revise-hrefs" priority="1">
        <xsl:document>
            <xsl:for-each select="node()">
                <xsl:text>&#xa;</xsl:text>
                <xsl:apply-templates select="." mode="#current"/>
            </xsl:for-each>
        </xsl:document>
    </xsl:template>
    
    <xsl:template match="processing-instruction()" priority="1" mode="revise-hrefs">
        <xsl:variable name="href-regex" as="xs:string">(href=['"])([^'"]+)(['"])</xsl:variable>
        <xsl:processing-instruction name="{name(.)}">
            <xsl:analyze-string select="." regex="{$href-regex}">
                <xsl:matching-substring>
                    <xsl:value-of select="concat(regex-group(1), tan:uri-relative-to(resolve-uri(regex-group(2), $doc-uri), $copy-to-resolved), regex-group(3))"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:processing-instruction>
    </xsl:template>
    <xsl:template match="@href" mode="revise-hrefs">
        <xsl:variable name="this-href-resolved" select="resolve-uri(., $doc-uri)"/>
        <xsl:variable name="this-href-relative" select="tan:uri-relative-to($this-href-resolved, $copy-to-resolved)"/>
        <xsl:attribute name="href" select="$this-href-relative"/>
    </xsl:template>
    
    <xsl:template match="/">
        <xsl:message select="'Saving to', $copy-to-resolved"/>
        <xsl:result-document href="{$copy-to-resolved}">
            <xsl:copy-of select="$self-hrefs-resolved"/>
        </xsl:result-document>
    </xsl:template>
    
</xsl:stylesheet>
