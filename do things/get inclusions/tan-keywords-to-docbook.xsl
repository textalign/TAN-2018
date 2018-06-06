<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns="http://docbook.org/ns/docbook" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:rng="http://relaxng.org/ns/structure/1.0" xmlns:docbook="http://docbook.org/ns/docbook" 
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="3.0">
    <!-- Input: a TAN-key file or fragment -->
    <!-- Output: a docbook representation of those keywords -->
    <!-- Written primarily to support creation of TAN guideline content -->
    <xsl:template match="*" mode="deep-skip"/>
    <xsl:template match="tan:head" mode="keyword-to-docbook">
        <xsl:apply-templates select="tan:name | tan:desc | tan:master-location" mode="#current"/>
    </xsl:template>
    <xsl:template match="tan:name" mode="keyword-to-docbook">
        <title>
            <xsl:value-of select=". || ' ('"/>
            <xsl:copy-of
                select="
                    for $i in tokenize(/tan:TAN-key/tan:body/@affects-element, '\s+')
                    return
                        tan:prep-string-for-docbook(tan:string-representation-of-component($i, 'element'))"
            />
            <xsl:text>)</xsl:text>
        </title>
    </xsl:template>
    <xsl:template match="docbook:code" mode="adjust-docbook-keyword-desc">
        <xsl:choose>
            <xsl:when
                test="
                    some $i in docbook:link/@linkend
                        satisfies matches($i, '^pattern-')">
                <!-- we drop anything that looks like a pattern, because patterns won't be discussed in keyword descriptions -->
                <xsl:value-of select="."/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="tan:desc" mode="keyword-to-docbook">
        <para>
            <xsl:copy-of select="tan:prep-string-for-docbook(.)"/>
        </para>
    </xsl:template>
    <xsl:template match="tan:master-location" mode="keyword-to-docbook">
        <para>
            <xsl:text>Master location: </xsl:text>
            <link
                xlink:href="{/tan:TAN-key/tan:head/tan:master-location[1]/@href}">
                <xsl:value-of select="/tan:TAN-key/tan:head/tan:master-location[1]/@href"
                /></link>
        </para>
    </xsl:template>
    <xsl:template match="/" mode="keyword-to-docbook">
        <section xml:id="{'keywords-' || tokenize(tan:TAN-key/tan:body/@affects-element,'\s+')[1]}">
            <xsl:apply-templates select="tan:TAN-key/tan:head" mode="keyword-to-docbook"/>
            <table frame="all">
                <title>
                    <xsl:value-of select="tan:TAN-key/tan:head/tan:name"/>
                </title>
                <tgroup cols="3">
                    <colspec colname="c1" colnum="1" colwidth="1.0*"/>
                    <colspec colname="c2" colnum="2" colwidth="1.0*"/>
                    <colspec colname="c3" colnum="3" colwidth="1.0*"/>
                    <thead>
                        <row>
                            <entry>keywords (optional values of <link linkend="attribute-which"
                                        ><code>@which</code></link>)</entry>
                            <entry>
                                <xsl:value-of
                                    select="
                                        if (tan:TAN-key/tan:body/@affects-element = 'token-definition')
                                        then
                                            'pattern'
                                        else
                                            'IRIs'"
                                />
                            </entry>
                            <entry>Comments</entry>
                        </row>
                    </thead>
                    <tbody>
                        <xsl:for-each select="//tan:item">
                            <row>
                                <entry>
                                    <itemizedlist>
                                        <xsl:for-each select="tan:name">
                                            <listitem>
                                                <para>
                                                  <xsl:value-of select="."/>
                                                </para>
                                            </listitem>
                                        </xsl:for-each>
                                    </itemizedlist>
                                </entry>
                                <entry>
                                    <itemizedlist>
                                        <xsl:for-each select="tan:IRI, tan:token-definition/@pattern">
                                            <listitem>
                                                <para>
                                                    <xsl:choose>
                                                        <xsl:when test="matches(.,'^(ftp|https?)://')">
                                                            <link xlink:href="{.}">
                                                                <xsl:value-of select="."/>
                                                            </link>
                                                        </xsl:when>
                                                        <xsl:otherwise>
                                                            <xsl:value-of select="."/>
                                                        </xsl:otherwise>
                                                    </xsl:choose>
                                                </para>
                                            </listitem>
                                        </xsl:for-each>
                                    </itemizedlist>
                                </entry>
                                <entry>
                                    <xsl:for-each select="tan:desc">
                                        <para>
                                            <xsl:apply-templates select="tan:prep-string-for-docbook(.)" mode="adjust-docbook-keyword-desc"/>
                                        </para>
                                    </xsl:for-each>
                                </entry>
                            </row>
                        </xsl:for-each>
                    </tbody>
                </tgroup>
            </table>
        </section>
    </xsl:template>
</xsl:stylesheet>
