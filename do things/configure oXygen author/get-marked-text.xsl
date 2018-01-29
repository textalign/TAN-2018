<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0">
    <xsl:import href="incl/chop-string.xsl"/>
    <xsl:template match="*">
        <xsl:value-of select="up/preceding-sibling::text()"/>
        <xsl:value-of select="down/following-sibling::text()"/>
    </xsl:template>
</xsl:stylesheet>
