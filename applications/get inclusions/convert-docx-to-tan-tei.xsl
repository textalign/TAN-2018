<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.tei-c.org/ns/1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Basic rules for converting docx to tan -->
    <!-- Companion stylesheet to dependent core stylesheet -->

    <xsl:param name="default-div-type-sequence" select="('hom', 'sec', 'sub')"/>
    <xsl:param name="default-div-type-for-centered-p" select="'title'"/>
    <xsl:param name="default-ref-regex" select="'\s*(\d+)\W+(\d+)\W*(\d*)\W*'"/>
    <xsl:param name="docx-is-first-level-hierarchy" as="xs:boolean" select="false()"/>

    <!-- PASS 1 -->
    <!-- The goal here is a simple, unadorned, plain TAN-TEI body, perhaps retaining anchors in case it is being treated as a source -->

    <xsl:template match="/w:document" priority="1" mode="input-pass-1">
        <xsl:variable name="this-base-uri" select="@xml:base"/>
        <xsl:variable name="this-base-uri-without-percentage"
            select="replace($this-base-uri, '%\d\d', '')"/>
        <xsl:variable name="numbers-in-filename" as="xs:integer*">
            <xsl:analyze-string
                select="replace($this-base-uri-without-percentage, '.+/([^/]+)$', '$1')" regex="\d+">
                <xsl:matching-substring>
                    <xsl:copy-of select="xs:integer(.)"/>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:variable name="this-docx-number" select="$numbers-in-filename[1]"/>
        <xsl:variable name="these-comments"
            select="$input-items[w:comments/@xml:base = $this-base-uri]"/>
        <xsl:element name="body" namespace="{$template-namespace}">
            <xsl:if test="$docx-is-first-level-hierarchy">
                <div level="1" type="{$default-div-type-sequence[1]}" n="{$this-docx-number}"/>
            </xsl:if>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="comments" select="$these-comments" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:element>

    </xsl:template>
    <xsl:template match="w:p" mode="input-pass-1">
        <xsl:variable name="this-p-type" as="xs:string?">
            <xsl:choose>
                <xsl:when
                    test="exists(.//w:jc[@w:val = 'center']) or (exists(w:r[1]/w:tab) and exists(w:pPr/w:rPr/w:b))">
                    <!-- If the paragraph is centered, or if it is a bold paragraph with an initial indent, treat it like a title or rubric -->
                    <xsl:value-of select="$default-div-type-for-centered-p"/>
                </xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="exists($this-p-type)">
                <xsl:element name="div" namespace="{$template-namespace}">
                    <xsl:attribute name="level"
                        select="
                            if ($docx-is-first-level-hierarchy) then
                                2
                            else
                                1"/>
                    <xsl:attribute name="type" select="$this-p-type"/>
                    <xsl:attribute name="n"/>
                </xsl:element>
                <xsl:apply-templates mode="#current"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates mode="#current"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="text()" mode="input-pass-1">
        <xsl:value-of select="normalize-unicode(.)"/>
    </xsl:template>

    <xsl:template match="w:commentRangeStart | w:commentRangeEnd" mode="input-pass-1">
        <xsl:param name="keep-anchors" tunnel="yes" select="false()"/>
        <xsl:if test="$keep-anchors">
            <xsl:copy-of select="."/>
        </xsl:if>
    </xsl:template>

    <!-- PASS 2 -->
    <!-- Goal: begin the hierarchy by replacing references in plain with empty elements; give preceding step @n values -->

    <xsl:template match="*:div[not(*)]" mode="input-pass-2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:if test="string-length(@n) lt 1">
                <xsl:variable name="this-type" select="@type"/>
                <xsl:variable name="this-is-what-nth-of-type"
                    select="count(preceding-sibling::*:div[(@type = $this-type) and (string-length(@n) lt 1)]) + 1"/>
                <xsl:variable name="this-n-suffix"
                    select="
                        if (($this-is-what-nth-of-type gt 1)) then
                            concat('-', string($this-is-what-nth-of-type))
                        else
                            ()"/>
                <xsl:attribute name="n" select="concat($this-type, $this-n-suffix)"/>
            </xsl:if>
            <xsl:copy-of select="text()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="text()" mode="input-pass-2">
        <xsl:variable name="ancestor-level" select="xs:integer((ancestor::*/@level)[last()])"/>
        <xsl:variable name="this-level"
            select="
                if (exists($ancestor-level)) then
                    $ancestor-level + 1
                else
                    1"/>
        <xsl:analyze-string select="." regex="{$default-ref-regex}">
            <xsl:matching-substring>
                <xsl:for-each select="$this-level to count($default-div-type-sequence)">
                    <xsl:variable name="this-pos" select="."/>
                    <xsl:variable name="this-n" select="regex-group($this-pos)"/>
                    <xsl:if test="string-length($this-n) gt 0">
                        <xsl:element name="div" namespace="{$template-namespace}">
                            <xsl:attribute name="level" select="$this-pos"/>
                            <xsl:choose>
                                <xsl:when test="$this-n = ('T', 'Τ')">
                                    <xsl:attribute name="type" select="'title'"/>
                                    <xsl:attribute name="n" select="'title'"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:attribute name="type"
                                        select="$default-div-type-sequence[position() = $this-pos]"/>
                                    <xsl:attribute name="n" select="regex-group($this-pos)"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:element>
                    </xsl:if>
                </xsl:for-each>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:value-of select="."/>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:template>

    <!-- PASS 3 -->
    <!-- Goal: convert the flat hierarchy to a regular one -->
    <xsl:template match="*[*:div[@level]]" mode="input-pass-3">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:copy-of select="tan:sequence-to-tree(node())"/>
        </xsl:copy>
    </xsl:template>


    <!-- PASS 4 -->
    <!-- If adjacent <div>s have the same @n value, they should be consolidated; normalize space -->

    <xsl:template match="*[*:div]" mode="input-pass-4">
        <xsl:variable name="this-div" select="."/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select="*" group-adjacent="@n">
                <xsl:variable name="new-group" as="element()">
                    <xsl:element name="div" namespace="{$template-namespace}">
                        <xsl:copy-of select="current-group()[1]/@*"/>
                        <xsl:copy-of select="current-group()/node()"/>
                    </xsl:element>
                </xsl:variable>
                <xsl:apply-templates select="$new-group" mode="#current"/>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="text()" mode="input-pass-4">
        <xsl:variable name="preceding-text" select="preceding-sibling::text()[1]"/>
        <xsl:variable name="following-text" select="following-sibling::text()[1]"/>
        <!-- we add a notional space at the end of a <p> or <ab>, to anticipate space normalization -->
        <xsl:variable name="this-text-norm"
            select="
                if (exists($following-text)) then
                    .
                else
                    concat(., ' ')"/>
        <xsl:analyze-string select="$this-text-norm" regex="^\s+">
            <!-- If there is a preceding text, and it ends in a non-space character, then normalize initial space of this text node to a single space -->
            <xsl:matching-substring>
                <xsl:if test="exists($preceding-text)">
                    <xsl:if test="matches($preceding-text, '\S$')">
                        <xsl:text> </xsl:text>
                    </xsl:if>
                </xsl:if>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:analyze-string select="." regex="\s+$">
                    <!-- normalize trailing space to a single space -->
                    <xsl:matching-substring>
                        <xsl:text> </xsl:text>
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <xsl:value-of select="normalize-space(.)"/>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:template>

</xsl:stylesheet>
