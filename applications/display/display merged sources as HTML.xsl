<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.w3.org/1999/xhtml" xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    <xsl:import href="display%20TAN%20as%20HTML.xsl"/>
    <xsl:output method="html" indent="yes"/>
    <xsl:param name="validation-phase" select="'verbose'"/>
    <xsl:param name="input-items" select="tan:merge-expanded-docs($self-expanded[position() gt 1])"/>
    
    <xsl:param name="levels-to-convert-to-aaa" as="xs:integer*" select="(2)"/>
    
    <xsl:template match="tan:TAN-T-merge" mode="input-pass-1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <group xmlns="tag:textalign.net,2015:ns">
                <xsl:for-each select="tan:head">
                    <xsl:sort select="index-of($src-ids, tan:src)"/>
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </group>
            <xsl:apply-templates select="tan:body" mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*[tan:div[tan:type = 'version']]" mode="input-pass-1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="* except tan:div" mode="#current"/>
            <xsl:for-each-group select=".//tan:div[tan:type = 'version']" group-by="tan:src">
                <xsl:sort select="index-of($src-ids, current-grouping-key())"/>
                <xsl:choose>
                    <xsl:when test="count(current-group()) = 1">
                        <xsl:for-each select="current-group()">
                            <xsl:copy>
                                <xsl:copy-of select="@*"/>
                                <xsl:apply-templates select="node() except tan:ref" mode="#current"/>
                            </xsl:copy>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <div xmlns="tag:textalign.net,2015:ns">
                            <xsl:copy-of select="current-group()[1]/@*"/>
                            <src><xsl:value-of select="current-grouping-key()"/></src>
                            <xsl:for-each select="current-group()">
                                <xsl:copy>
                                    <xsl:copy-of select="@* except @class"/>
                                    <xsl:attribute name="class" select="replace(@class, 'td |version ', '')"
                                    />
                                    <xsl:apply-templates select="node()" mode="#current"/>
                                </xsl:copy>
                            </xsl:for-each>
                        </div>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group> 
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:ref/text()" mode="input-pass-1">
        <xsl:variable name="new-ns" as="xs:string*">
            <xsl:for-each select="../tan:n">
                <xsl:variable name="this-pos" select="position()"/>
                <xsl:variable name="this-n" select="."/>
                <xsl:choose>
                    <xsl:when
                        test="$this-pos = $levels-to-convert-to-aaa and $this-n castable as xs:integer">
                        <xsl:value-of select="tan:int-to-aaa(xs:integer($this-n))"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="."/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="string-join($new-ns,' ')"/>
    </xsl:template>
    
    
    <xsl:template match="tan:TAN-T-merge" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="$self-resolved/*/tan:head/tan:name" mode="#current"/>
            <xsl:apply-templates select="$self-resolved/*/tan:head/tan:desc" mode="#current"/>
            <hr></hr>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <!--<xsl:template match="tan:name[1]" mode="tan-to-html-pass-2">
        <h1><xsl:value-of select="."/></h1>
    </xsl:template>-->
    <!--<xsl:template match="tan:name[position() gt 1]" mode="tan-to-html-pass-2">
        <h2><xsl:value-of select="."/></h2>
    </xsl:template>-->
    <xsl:template match="tan:desc" mode="tan-to-html-pass-2">
        <div><xsl:value-of select="."/></div>
    </xsl:template>
    <xsl:template match="tan:TAN-T-merge/tan:group" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="class" select="string-join((@class, 'sortable'), ' ')"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:head" mode="tan-to-html-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="draggable"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!--<xsl:template match="/" priority="1">
        <diagnostics>
            <xsl:copy-of select="$input-items"/>
            <!-\-<xsl:copy-of select="$input-pass-1"/>-\->
        </diagnostics>
    </xsl:template>-->
    
</xsl:stylesheet>
