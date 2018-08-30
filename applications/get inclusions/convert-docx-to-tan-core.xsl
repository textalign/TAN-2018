<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Basic rules for converting docx to tan -->
    <!-- Companion stylesheet to convert.xsl -->
    
    <xsl:include href="convert-docx-to-tan-tei.xsl"/>
    <xsl:include href="convert-docx-to-tan-a.xsl"/>

    <!-- PASS 1 -->

    <!-- gatekeeping template: make sure only the relevant parts of the docx get processed -->
    <xsl:template match="document-node()" mode="input-pass-1">
        <xsl:param name="target-root-element-name" as="xs:string?"/>
        <xsl:variable name="intended-target"
            select="
                if (string-length($target-root-element-name) lt 1) then
                    $template-root-element-name
                else
                    $target-root-element-name"
        />
        <xsl:if test="($intended-target = ('TEI', 'TAN-T') and exists(w:document))
            or ($intended-target = ('TAN-A') and exists(w:comments))">
            <xsl:document>
                <xsl:apply-templates mode="#current"/>
            </xsl:document>
        </xsl:if>
    </xsl:template>

    <!-- default behavior: shallow skip -->
    <xsl:template match="*" mode="input-pass-1">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    <!-- PASS 2 -->
    <!-- PASS 3 -->
    <!-- PASS 4 -->



    <!-- INFUSION -->
    
    <xsl:template match="tei:body | tan:body" priority="1" mode="infuse-template">
        <xsl:param name="new-content" tunnel="yes"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <xsl:when test="$template-root-element-name = ('TAN-T', 'TEI')">
                    <xsl:variable name="all-ns"
                        select="distinct-values((*:div/@n, $new-content/*:body/*:div/@n))"/>
                    <xsl:variable name="this-body" select="."/>
                    <xsl:for-each select="$all-ns">
                        <xsl:sort select="number(.)"/>
                        <xsl:variable name="this-n" select="."/>
                        <xsl:variable name="this-new-content" select="$new-content/*:body/*:div[@n = $this-n]"/>
                        <xsl:choose>
                            <xsl:when test="exists($this-new-content)">
                                <xsl:copy-of select="$this-new-content"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:copy-of select="$this-body/*:div[@n = $this-n]"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                </xsl:when>
                <xsl:when test="$template-root-element-name = 'TAN-A'">
                    <xsl:message>
                        <xsl:value-of
                            select="concat(xs:string(count(.//tan:claim)), ' claims in the template have been replaced with ', count($new-content/tan:TAN-A/tan:claim), ' new claims')"
                        /></xsl:message>
                    <xsl:copy-of select="$new-content/tan:TAN-A/tan:claim"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message>Rules for infusion have not been defined</xsl:message>
                    <xsl:copy-of select="node()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>

    </xsl:template>

</xsl:stylesheet>
