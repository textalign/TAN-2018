<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:ti="http://chs.harvard.edu/xmlns/cts"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Input: A TAN-TEI file -->
    <!-- Output: The same as a TAN-T file. -->

    <!-- The following stylesheet ensures that this transformation gets credited/blamed in the resultant TAN-TEI file -->
    <xsl:import href="../../functions/incl/TAN-core-functions.xsl"/>
    <xsl:import href="../get%20inclusions/core-for-TAN-output.xsl"/>

    <xsl:output indent="no"/>


    <!-- These variables modify the core TAN output stylesheet -->
    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:convert-tan-tei-to-tan-t'"/>
    <xsl:variable name="this-stylesheet-uri" select="static-base-uri()"/>
    <xsl:variable name="change-message" select="'Converted from TAN-TEI to TAN-T.'"/>

    <xsl:template match="tei:*" mode="tei-to-tan" priority="-1">
        <xsl:variable name="this-name" select="name(.)"/>
        <xsl:element name="{$this-name}" namespace="tag:textalign.net,2015:ns">
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:element>
    </xsl:template>

    <xsl:template match="processing-instruction()" mode="tei-to-tan">
        <xsl:text>&#xa;</xsl:text>
        <xsl:processing-instruction name="{name(.)}">
            <xsl:value-of select="replace(., 'TAN-TEI', 'TAN-T')"/>
        </xsl:processing-instruction>
    </xsl:template>

    <xsl:template match="tei:TEI" mode="tei-to-tan">
        <xsl:text>&#xa;</xsl:text>
        <TAN-T>
            <xsl:copy-of select="@id, @TAN-version"/>
            <xsl:apply-templates mode="#current"/>
        </TAN-T>
    </xsl:template>

    <xsl:template match="tei:teiHeader" mode="tei-to-tan"/>

    <xsl:template match="tei:text" mode="tei-to-tan">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tei:div[not(tei:div)]" mode="tei-to-tan">
        <div>
            <xsl:copy-of select="@n, @type, @ed-who, @ed-when"/>
            <xsl:value-of select="normalize-space(string-join(.//text(),''))"/>
        </div>
    </xsl:template>

    <xsl:template match="/">
        <xsl:document>
            <xsl:apply-templates mode="tei-to-tan"/>
        </xsl:document>
    </xsl:template>

</xsl:stylesheet>
