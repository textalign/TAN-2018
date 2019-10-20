<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="3.0">
    <!-- Input: any file -->
    <!-- Output: a catalog.xml file for all XML files or a catalog.tan.xml file for all TAN files in that directory and its subdirectories -->
    <!-- The resultant files provide support for fn:collection(). -->
    
    <xsl:output indent="yes"/>
    <xsl:include href="../../functions/incl/TAN-core-functions.xsl"/>

    <xsl:param name="tan-only" as="xs:boolean" select="true()"/>
    
    <!-- Do you want to embed in <doc> the entirety of the contents of the resolved <head>, or do you want only minimal metadata
        (the children of <head> before <vocabulary-key>)?
    -->
    <xsl:param name="include-fully-resolved-metadata" as="xs:boolean" select="false()"/>

    <xsl:param name="target-base-relative-uri" select="tan:cfn(/)" as="xs:string"/>
    <xsl:variable name="target-base-resolved-uri" select="resolve-uri($target-base-relative-uri, base-uri(/*))" as="xs:string"/>
    <xsl:variable name="target-base-directory" select="replace($target-base-resolved-uri, '[^/]+$', '')"/>
    <xsl:variable name="target-url-resolved" select="resolve-uri($catalog-file-name,$target-base-resolved-uri)"/>
    

    <!-- regular expression to filter out results; currently looks for filenames that have the text "private-" or "temp-" -->
    <xsl:param name="exclude-filenames-that-match-what-pattern" as="xs:string?"
        select="'private-|temp-'"/>

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

    <xsl:variable name="collection-search-param"
        select="
            concat('?select=*.',
            if ($tan-only) then
                'xml'
            else
                '*',
            ';recurse=yes;on-error=ignore')"
    />
    <xsl:variable name="this-uri-collection" select="uri-collection(concat($target-base-directory, $collection-search-param))"/>
    
    <xsl:variable name="results-pass-1" as="document-node()">
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
                <xsl:attribute name="metadata-resolved" select="$include-fully-resolved-metadata"/>
                <xsl:message select="'Creating catalog file by searching for files in this directory: ', $target-base-directory"/>
                <xsl:message select="'Metadata should be fully resolved? ', $include-fully-resolved-metadata"/>
                <xsl:message select="'TAN files only: ', $tan-only"/>
                <xsl:if test="string-length($exclude-filenames-that-match-what-pattern) gt 0">
                    <xsl:message select="'Excluding filenames that match this pattern: ', $exclude-filenames-that-match-what-pattern"/>
                </xsl:if>
                <xsl:for-each select="$this-uri-collection">
                    <xsl:variable name="this-base-uri" select="."/>
                    <xsl:if test="doc-available(.)">
                        <xsl:variable name="this-doc" select="doc(.)"/>
                        <xsl:variable name="this-is-tan" select="tan:class-number($this-doc) ge 1"/>
                        <xsl:if
                            test="
                                if (string-length($exclude-filenames-that-match-what-pattern) gt 0) then
                                    not(matches($this-base-uri, $exclude-filenames-that-match-what-pattern))
                                else
                                    true()">
                            <xsl:if test="not($tan-only) or exists($this-doc/*/tan:head)">
                                <doc
                                    href="{tan:uri-relative-to($this-base-uri, $target-base-directory)}">
                                    <xsl:copy-of select="$this-doc/*/@*"/>
                                    <xsl:copy-of select="$this-doc/*/tan:body/@*"/>
                                    <xsl:attribute name="root" select="name($this-doc/*)"/>
                                    <xsl:variable name="head-pass-1" as="node()*">
                                        <xsl:choose>
                                            <xsl:when test="$include-fully-resolved-metadata">
                                                <xsl:variable name="this-doc-resolved"
                                                  select="
                                                        if ($this-is-tan) then
                                                            tan:resolve-doc($this-doc, false(), ())
                                                        else
                                                            $this-doc"/>
                                                <xsl:copy-of
                                                  select="$this-doc-resolved/(tei:TEI/tei:text, tan:*)/tei:body/@*"/>
                                                <xsl:copy-of
                                                  select="$this-doc-resolved/*/tan:head/*"/>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:apply-templates
                                                  select="$this-doc/*/tan:head/tan:vocabulary-key/preceding-sibling::*"
                                                  mode="resolve-href"/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:variable>
                                    <xsl:apply-templates select="$head-pass-1" mode="uri-relative-to">
                                        <xsl:with-param name="base-uri" select="$target-base-directory" tunnel="yes"/>
                                    </xsl:apply-templates>
                                </doc>
                            </xsl:if>
                        </xsl:if>
                    </xsl:if>
                </xsl:for-each>
            </collection>
        </xsl:document>
    </xsl:variable>

    
    <xsl:variable name="results-pass-2" as="document-node()">
        <xsl:message select="'Resolving @href values relative to ', $target-url-resolved"/>
        <xsl:apply-templates select="$results-pass-1" mode="uri-relative-to">
            <xsl:with-param name="base-uri" tunnel="yes" select="$target-url-resolved"/>
        </xsl:apply-templates>
    </xsl:variable>

    <xsl:template match="node()"/>
    <xsl:template match="/">
        <xsl:result-document href="{$target-url-resolved}">
            <!--<xsl:copy-of select="$results-pass-1"/>-->
            <xsl:copy-of select="$results-pass-2"/>
        </xsl:result-document>
    </xsl:template>
</xsl:stylesheet>
