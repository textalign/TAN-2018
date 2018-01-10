<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="2.0">
    <!-- Input: any file -->
    <!-- Output: a catalog.tan.xml file for all XML files in that directory and its subdirectories -->
    <!-- The resultant files provide support for fn:collection(). -->
    <xsl:output indent="yes"/>
    <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>

    <xsl:variable name="target-base-uri" select="base-uri(/*)" as="xs:string"/>
    <xsl:variable name="target-base-directory" select="replace($target-base-uri, '[^/]+$', '')"/>
    <xsl:param name="exclude-filenames-that-match-what-pattern" as="xs:string" select="'/?private-'"/>

    <xsl:param name="rnc-schema-uri-relative-to-this-stylesheet"
        select="'../../schemas/catalog.tan.rnc'"/>
    <xsl:param name="sch-schema-uri-relative-to-this-stylesheet"
        select="'../../schemas/catalog.tan.sch'"/>

    <xsl:variable name="results" as="document-node()">
        <xsl:document>
            <xsl:text>&#xa;</xsl:text>
            <xsl:processing-instruction name="xml-model">
                <xsl:text>href ="</xsl:text>
                <xsl:value-of select="tan:uri-relative-to($rnc-schema-uri-relative-to-this-stylesheet, $target-base-uri)"/>
                <xsl:text>" type="application/relax-ng-compact-syntax"</xsl:text>
            </xsl:processing-instruction>
            <xsl:text>&#xa;</xsl:text>
            <xsl:processing-instruction name="xml-model">
                <xsl:text>href ="</xsl:text>
                <xsl:value-of select="tan:uri-relative-to($sch-schema-uri-relative-to-this-stylesheet, $target-base-uri)"/>
                <xsl:text>" type="application/xml" schematypens="http://purl.oclc.org/dsdl/schematron"</xsl:text>
            </xsl:processing-instruction>
            <xsl:text>&#xa;</xsl:text>
            <collection stable="true">
                <!--<xsl:copy-of select="$target-base-directory"/>-->
                <xsl:for-each
                    select="collection(concat($target-base-directory, '?select=*.xml;recurse=yes'))">
                    <xsl:variable name="this-base-uri" select="base-uri(.)"/>
                    <xsl:if
                        test="
                            if (string-length($exclude-filenames-that-match-what-pattern) gt 0) then
                                not(matches($this-base-uri, $exclude-filenames-that-match-what-pattern))
                            else
                                true()">
                        <xsl:if test="exists(root()/*/tan:head)">
                            <doc
                                href="{tan:uri-relative-to($this-base-uri, $target-base-directory)}">
                                <xsl:copy-of select="root()/*/@id"/>
                                <xsl:attribute name="root" select="name(root()/*)"/>
                            </doc>
                        </xsl:if>
                    </xsl:if>
                </xsl:for-each>
            </collection>
        </xsl:document>
    </xsl:variable>

    <xsl:template match="node()"/>
    <xsl:template match="/">
        <xsl:result-document href="{resolve-uri('catalog.tan.xml',$target-base-uri)}">
            <xsl:copy-of select="$results"/>
        </xsl:result-document>
    </xsl:template>
</xsl:stylesheet>
