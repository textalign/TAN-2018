<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tan="tag:textalign.net,2015:ns" version="3.0">
    <xsl:import href="../update/update%20TAN-T%20text%20via%20redivided%20copy.xsl"/>
    <xsl:output use-character-maps="tan"/>
    <!--<xsl:template match="tan:body">
        <xsl:copy-of select="$input-pass-2/tan:TAN-T/tan:body"/>
    </xsl:template>-->
    <!-- The default template below is included to overwrite the default behavior of convert.xsl's default template -->
    <xsl:template match="/" priority="5">
        <!--<xsl:copy>
            <xsl:apply-templates/>
        </xsl:copy>-->
        <xsl:copy-of select="$input-pass-2"/>
    </xsl:template>
</xsl:stylesheet>
