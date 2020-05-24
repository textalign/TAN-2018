<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="tag:textalign.net,2015:ns" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Basic conversion utility for moving data from one TAN file to another -->
    <!-- Must be included by a master stylesheet that also includes the TAN function library, perhaps by also importing convert.xsl -->

    <xsl:function name="tan:copy-data" as="document-node()?">
        <!-- The two-param version of the fuller one, below. In this case, we assume that everything in the body should be copied. -->
        <xsl:param name="source-tan-file" as="document-node()?"/>
        <xsl:param name="target-tan-file" as="document-node()?"/>
        <xsl:variable name="source-tan-file-resolved" select="tan:resolve-doc($source-tan-file)"/>
        <xsl:variable name="source-tan-file-hist" select="tan:get-doc-history($source-tan-file-resolved)"/>
        <xsl:variable name="data-assigned-resp" as="element()*">
            <xsl:apply-templates select="$source-tan-file" mode="assign-resp">
                <xsl:with-param name="default-resp"
                    select="$source-tan-file-resolved/*/tan:head/tan:file-resp" tunnel="yes"/>
                <xsl:with-param name="first-edit-date" select="$source-tan-file-hist/*[last()]" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:copy-of select="tan:copy-data($source-tan-file, $target-tan-file, $data-assigned-resp)"/>
    </xsl:function>
    
    <xsl:template match="node() | document-node()" mode="assign-resp">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <xsl:template match="tan:ana | tan:align" mode="assign-resp">
        <xsl:param name="default-resp" tunnel="yes" as="element()?"/>
        <xsl:param name="first-edit-date" tunnel="yes" as="element()?"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:if test="not(exists(@claimant))">
                <xsl:variable name="last-claimant" select="ancestor::*[@claimant][1]"/>
                <xsl:attribute name="claimant" select="($last-claimant/@claimant, $default-resp/@who)[1]"/>
                <xsl:attribute name="claim-when"
                    select="($last-claimant/@claim-when, $first-edit-date/(@when, @ed-when, @claim-when, @accessed-when))[1]"
                />
            </xsl:if>
            <xsl:copy-of select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:function name="tan:copy-data" as="document-node()?">
        <!-- Input: two TAN files, of the same type, the first to be copied into the second; the data that should be copied -->
        <!-- Output: data from the third parameter, interpreted in the light of the first file, copied in the second -->
        <xsl:param name="source-tan-file" as="document-node()?"/>
        <xsl:param name="target-tan-file" as="document-node()?"/>
        <xsl:param name="data-to-copy" as="element()*"/>
        <xsl:variable name="source-type" select="tan:tan-type($source-tan-file)"/>
        <xsl:variable name="target-type" select="tan:tan-type($target-tan-file)"/>
        <xsl:variable name="source-resolved" select="tan:resolve-doc($source-tan-file)"/>
        <xsl:variable name="target-resolved" select="tan:resolve-doc($target-tan-file)"/>
        <!-- First, find all the idrefs in the data. -->
        <!--<xsl:variable name="data-idrefs" select="$data-to-copy//(*, @*)[name(.) = $id-idrefs/tan:id-idrefs/tan:id/tan:idrefs/@attribute]"/>-->
        <!-- Then find all the vocabulary items behind those idrefs -->
        <!--<xsl:variable name="data-idref-vocabulary" select="tan:vocabulary-key-item($data-idrefs, $source-resolved/*/tan:head)"/>-->
        <xsl:variable name="data-idref-vocabulary" select="tan:element-vocabulary($data-to-copy//*)"/>
        
        <xsl:choose>
            <xsl:when test="not($source-type = $target-type)">
                <xsl:message select="'Cannot copy data from', $source-type, 'to', $target-type"/>
            </xsl:when>
            <xsl:otherwise>
                <!-- diagnostics -->
                <xsl:document>
                    <!--<xsl:copy-of select="$target-resolved"/>-->
                    <diagnostics>
                        <!--<xsl:copy-of select="$data-to-copy"/>-->
                        <!--<xsl:value-of select="$data-idrefs"/>-->
                        <xsl:copy-of select="$data-idref-vocabulary"/>
                    </diagnostics>
                </xsl:document>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    

</xsl:stylesheet>
