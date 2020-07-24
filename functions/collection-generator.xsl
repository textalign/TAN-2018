<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="3.0">
    <!-- Input: any file (including this one) -->
    <!-- Output: a catalog file for schemas/, functions/, and TAN-voc -->
    <!-- The resultant files are important for the function library and validation, which can use fn:collection() only in connection with an XML file listing the XML files available. -->
    <xsl:output indent="yes"/>
    <xsl:include href="incl/TAN-core-functions.xsl"/>
    <xsl:variable name="function-directories" select="('.', 'extra', 'incl', 'errors', 'regex')"/>
    <xsl:variable name="function-URIs">
        <collection stable="true">
            <xsl:for-each select="$function-directories">
                <xsl:variable name="this-directory" select="."/>
                <xsl:for-each
                    select="collection(string-join(($this-directory, '.?select=*.x[ms]l'), '/'))">
                    <xsl:if test="not(base-uri(.) = static-base-uri())">
                        <doc href="{tan:uri-relative-to(base-uri(.), static-base-uri())}"/>
                    </xsl:if>
                </xsl:for-each>
            </xsl:for-each>
        </collection>
    </xsl:variable>
    
    <xsl:variable name="schema-directories" select="('../schemas', '../schemas/incl')"/>
    <xsl:variable name="base-schema-directory-resolved" select="resolve-uri($schema-directories[1])"/>
    <xsl:variable name="schema-URIs">
        <collection stable="true">
            <xsl:for-each select="$schema-directories">
                <xsl:variable name="this-directory-resolved" select="resolve-uri(., static-base-uri())"/>
                <xsl:for-each select="uri-collection($this-directory-resolved)">
                    <doc href="{tan:uri-relative-to(., $base-schema-directory-resolved)}"/>
                </xsl:for-each>
            </xsl:for-each>
        </collection>
    </xsl:variable>
    
    <xsl:variable name="vocabulary-directories" select="('../vocabularies')"/>
    <xsl:variable name="base-vocabulary-directory-resolved" select="resolve-uri($vocabulary-directories[1])"/>
    <xsl:variable name="vocabulary-URIs">
        <collection stable="true">
            <xsl:for-each select="$vocabulary-directories">
                <xsl:variable name="this-directory" select="."/>
                <xsl:for-each
                    select="collection(string-join(($this-directory, '.?select=*.xml'), '/'))">
                    <doc href="{tan:uri-relative-to(base-uri(.), $base-vocabulary-directory-resolved)}"/>
                </xsl:for-each>
            </xsl:for-each>
        </collection>
    </xsl:variable>

    <xsl:template match="/">
        <xsl:result-document href="{resolve-uri('collection.xml',static-base-uri())}">
            <xsl:copy-of select="$function-URIs"/>
        </xsl:result-document>
        <xsl:result-document href="{resolve-uri('../schemas/collection.xml',static-base-uri())}">
            <xsl:copy-of select="$schema-URIs"/>
        </xsl:result-document>
        <xsl:result-document href="{resolve-uri('../vocabularies/collection.xml',static-base-uri())}">
            <xsl:copy-of select="$vocabulary-URIs"/>
        </xsl:result-document>
    </xsl:template>
</xsl:stylesheet>
