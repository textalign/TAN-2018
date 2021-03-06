<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">
    <!-- Input: any file -->
    <!-- Output: a catalog file for schemas/, functions/, and TAN-key -->
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
                <xsl:variable name="this-directory" select="."/>
                <xsl:for-each
                    select="
                        collection(string-join(($this-directory, '.?select=*.sch'), '/')),
                        collection(string-join(($this-directory, '.?select=*.rng'), '/'))">
                    <doc href="{tan:uri-relative-to(base-uri(.), $base-schema-directory-resolved)}"/>
                </xsl:for-each>
            </xsl:for-each>
        </collection>
    </xsl:variable>
    
    <xsl:variable name="key-directories" select="('../TAN-key')"/>
    <xsl:variable name="base-key-directory-resolved" select="resolve-uri($key-directories[1])"/>
    <xsl:variable name="key-URIs">
        <collection stable="true">
            <xsl:for-each select="$key-directories">
                <xsl:variable name="this-directory" select="."/>
                <xsl:for-each
                    select="collection(string-join(($this-directory, '.?select=*.xml'), '/'))">
                    <doc href="{tan:uri-relative-to(base-uri(.), $base-key-directory-resolved)}"/>
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
        <xsl:result-document href="{resolve-uri('../TAN-key/collection.xml',static-base-uri())}">
            <xsl:copy-of select="$key-URIs"/>
        </xsl:result-document>
    </xsl:template>
</xsl:stylesheet>
