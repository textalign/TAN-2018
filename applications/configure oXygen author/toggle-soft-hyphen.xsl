<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tan="tag:textalign.net,2015:ns" version="3.0">
    <xsl:import href="../../functions/TAN-A-div-functions.xsl"/>
    <xsl:output use-character-maps="tan"/>
    <xsl:template match="tan:div[not(tan:div)]">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:choose>
                <xsl:when test="matches(., concat($shy, '\s*$'))">
                    <xsl:value-of select="replace(., concat($shy, '\s*$'), '')"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:analyze-string select="." regex="\s*$">
                        <xsl:non-matching-substring>
                            <xsl:value-of select="concat(., $shy)"/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:copy>
    </xsl:template>
</xsl:stylesheet>
