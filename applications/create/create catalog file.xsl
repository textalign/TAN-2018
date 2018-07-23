<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="2.0">
    <!-- Input: any file -->
    <!-- Output: a catalog.xml file for all XML files or a catalog.tan.xml file for all TAN files in that directory and its subdirectories -->
    <!-- The resultant files provide support for fn:collection(). -->
    <xsl:output indent="yes"/>
    <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>

    <xsl:param name="tan-only" as="xs:boolean" select="true()"/>

    <xsl:param name="target-base-relative-uri" select="tan:cfn(/)" as="xs:string"/>
    <xsl:variable name="target-base-resolved-uri" select="resolve-uri($target-base-relative-uri, base-uri(/*))" as="xs:string"/>
    <xsl:variable name="target-base-directory" select="replace($target-base-resolved-uri, '[^/]+$', '')"/>
    <!-- regular expression to filter out results; currently looks for filenames that begin "private-" or have an ISO date in the filename (but not path) -->
    <xsl:param name="exclude-filenames-that-match-what-pattern" as="xs:string"
        select="'private-|\d\d\d\d-\d\d-\d\d[^/]+'"/>

    <xsl:param name="rnc-schema-uri-relative-to-this-stylesheet"
        select="'../../schemas/catalog.tan.rnc'"/>
    <xsl:param name="sch-schema-uri-relative-to-this-stylesheet"
        select="'../../schemas/catalog.tan.sch'"/>

    <xsl:variable name="catalog-file-name"
        select="
            if ($tan-only) then
                'catalog.tan.xml'
            else
                'catalog.xml'"
    />

    <xsl:variable name="results" as="document-node()">
        <xsl:document>
            <xsl:if test="$tan-only">
                <xsl:text>&#xa;</xsl:text>
                <xsl:processing-instruction name="xml-model">
                <xsl:text>href ="</xsl:text>
                <xsl:value-of select="tan:uri-relative-to($rnc-schema-uri-relative-to-this-stylesheet, $target-base-resolved-uri)"/>
                <xsl:text>" type="application/relax-ng-compact-syntax"</xsl:text>
            </xsl:processing-instruction>
                <xsl:text>&#xa;</xsl:text>
                <xsl:processing-instruction name="xml-model">
                <xsl:text>href ="</xsl:text>
                <xsl:value-of select="tan:uri-relative-to($sch-schema-uri-relative-to-this-stylesheet, $target-base-resolved-uri)"/>
                <xsl:text>" type="application/xml" schematypens="http://purl.oclc.org/dsdl/schematron"</xsl:text>
            </xsl:processing-instruction>
            </xsl:if>
            <xsl:text>&#xa;</xsl:text>
            <collection stable="true">
                <xsl:message select="'Searching ', $target-base-directory"/>
                <xsl:for-each
                    select="collection(concat($target-base-directory, '?select=*.xml;recurse=yes;on-error=ignore'))">
                    <xsl:variable name="this-base-uri" select="base-uri(.)"/>
                    <!--<xsl:message select="'File at ', $this-base-uri"/>-->
                    <!--<xsl:message
                        select="
                            if (string-length($exclude-filenames-that-match-what-pattern) gt 0) then
                                not(matches($this-base-uri, $exclude-filenames-that-match-what-pattern))
                            else
                                true()"
                    />-->
                    <!--<xsl:message select="$tan-only, exists(root()/*/tan:head)"/>-->
                    <xsl:if
                        test="
                            if (string-length($exclude-filenames-that-match-what-pattern) gt 0) then
                                not(matches($this-base-uri, $exclude-filenames-that-match-what-pattern))
                            else
                                true()">
                        <xsl:if test="not($tan-only) or exists(root()/*/tan:head)">
                            <doc
                                href="{tan:uri-relative-to($this-base-uri, $target-base-directory)}">
                                <xsl:copy-of select="root()/*/@id"/>
                                <xsl:copy-of select="root()/tei:TEI/tei:text/tei:body/@xml:lang"/>
                                <xsl:copy-of select="root()/tan:TAN-T/tan:body/@xml:lang"/>
                                <xsl:attribute name="root" select="name(root()/*)"/>
                                <xsl:copy-of select="tan:TAN-A-lm/tan:body/(tan:for-lang, tan:tok-starts-with, tan:tok-is)"/>
                            </doc>
                        </xsl:if>
                    </xsl:if>
                </xsl:for-each>
            </collection>
        </xsl:document>
    </xsl:variable>

    <xsl:template match="node()"/>
    <xsl:template match="/">
        <xsl:result-document href="{resolve-uri($catalog-file-name,$target-base-resolved-uri)}">
            <xsl:copy-of select="$results"/>
        </xsl:result-document>
    </xsl:template>
</xsl:stylesheet>
