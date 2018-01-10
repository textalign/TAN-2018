<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:ti="http://chs.harvard.edu/xmlns/cts"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="2.0">

    <!-- Input: A TAN file written to conform to the TAN schema that was before December 2017 -->
    <!-- Output: The same TAN file, updated to suit the 2018 schemas. -->

    <!-- The following is a stylesheet that ensures that this transformation gets credited/blamed in the resultant TAN-TEI file -->
    <xsl:import href="../../functions/incl/TAN-core-functions.xsl"/>
    <xsl:import href="../get%20inclusions/core-for-TAN-output.xsl"/>
    
    <xsl:output indent="no"/>

    <xsl:param name="apply-special-collection-rules-1" as="xs:boolean" select="false()"/>
    <xsl:param name="general-key-locator" as="element()">
        <key>
            <location href="../../../library/evagrius/TAN-key/evagrius.TAN-key.xml"/>
        </key>
    </xsl:param>
    <xsl:variable name="general-key-resolved" select="tan:resolve-doc(tan:get-1st-doc($general-key-locator))" as="document-node()?"/>
    <xsl:param name="second-key-locator" as="element()">
        <key>
            <location href="../../../library/evagrius/TAN-key/evagrius-works-TAN-key.xml"/>
        </key>
    </xsl:param>
    <xsl:variable name="second-key-resolved" select="tan:resolve-doc(tan:get-1st-doc($second-key-locator))" as="document-node()?"/>

    <xsl:param name="apply-special-collection-rules-2" as="xs:boolean" select="true()"/>
    
    <xsl:variable name="indent-analysis" as="element()*">
        <xsl:for-each select="/*//text()[not(matches(., '\S'))][not(parent::tei:div[not(tei:div)])]">
            <xsl:variable name="last-segment" select="tokenize(., '\n')[last()]"/>
            <xsl:variable name="this-length" select="string-length($last-segment)"/>
            <xsl:variable name="this-ancestor-count" select="count(ancestor::*)"/>
            <xsl:variable name="average" select="$this-length div $this-ancestor-count"/>
            <indent length="{$this-length}" ancestor-count="{$this-ancestor-count}" avg="{$average}"/>
        </xsl:for-each>
    </xsl:variable>
    <xsl:variable name="average-indent" as="xs:string?">
        <xsl:choose>
            <xsl:when test="count($indent-analysis) lt 1"/>
            <xsl:otherwise>
                <xsl:variable name="avg"
                    select="
                        xs:integer(round(avg(for $i in $indent-analysis
                        return
                            number($i/@avg))))"/>
                <xsl:value-of
                    select="
                        string-join(for $i in (1 to $avg)
                        return
                            ' ', '')"
                />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <!-- These variables modify the core TAN output stylesheet -->
    <xsl:variable name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:convert-tan2017-to-tan2018'"/>
    <xsl:variable name="this-stylesheet-uri" select="static-base-uri()"/>
    <xsl:variable name="change-message" select="'TAN file updated to 2018 schemas.'"/>

    <xsl:function name="tan:indent" as="xs:string?">
        <!-- Input: a number representing the number of ancestors a node has -->
        <!-- Output: an indentation corresponding to the number of ancestors to the node and the average length of indentation -->
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:variable name="these-indentations"
            select="
                for $i in (1 to $ancestor-count)
                return
                    $average-indent"/>
        <xsl:value-of select="string-join(('&#xa;', $these-indentations), '')"/>
    </xsl:function>

    <xsl:template match="*" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:param name="except-attribute" as="xs:string*"/>
        <xsl:variable name="this-name" select="name(.)"/>
        <xsl:if test="$this-name = ('split-leaf-div-at', 'realign')">
            <xsl:value-of select="tan:indent($ancestor-count)"/>
            <xsl:comment>The following element has been eliminated, and its value must be manually altered. See documentation on &lt;equate>, &lt;rename>, &lt;move>.</xsl:comment>
            <xsl:value-of select="tan:indent($ancestor-count)"/>
        </xsl:if>
        <xsl:copy>
            <!--<xsl:attribute name="a" select="$ancestor-count"/>-->
            <xsl:copy-of select="@*[not(name(.) = $except-attribute)]"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/" mode="special-collection-rules-1 special-collection-rules-2">
        <xsl:document>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="0"/>
            </xsl:apply-templates>
        </xsl:document>
    </xsl:template>
    <xsl:template match="*" mode="special-collection-rules-1 special-collection-rules-2">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    
    <xsl:template match="text()" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer" select="0"/>
        <xsl:param name="reindent" as="xs:boolean" tunnel="yes" select="false()"/>
        <xsl:choose>
            <xsl:when test="following-sibling::*[1]/self::tan:suppress-div-types"/>
            <xsl:when test="matches(.,'\S') or $reindent = false()">
                <xsl:value-of select="."/>
            </xsl:when>
            <xsl:when test="not(exists(following-sibling::node()))">
                <!-- a final whitespace node should reflect the indentation of its parent, not its siblings -->
                <xsl:value-of select="tan:indent($ancestor-count - 1)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="tan:indent($ancestor-count)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <xsl:template match="processing-instruction()" mode="convert-2017-to-2018">
        <xsl:processing-instruction name="{name()}">
            <xsl:value-of select="replace(., 'TAN-LM(-lang)?', 'TAN-A-lm')"/>
        </xsl:processing-instruction>
    </xsl:template>
    
    <xsl:template match="tan:TAN-LM" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <TAN-A-lm>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </TAN-A-lm>
    </xsl:template>
    
    <xsl:template match="tan:head" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates
                select="node() except (tan:agent, tan:role, (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:role or self::tan:agent]])"
                mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:rights-excluding-sources" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <license>
            <xsl:copy-of select="@which"/>
            <xsl:copy-of select="(@include, @ed-when, @ed-who)"/>
            <xsl:copy-of select="node()"/>
        </license>
        <xsl:copy-of select="tan:indent($ancestor-count)"/>
        <licensor who="{@rights-holder}">
            <xsl:copy-of select="(@include, @ed-when, @ed-who)"/>
        </licensor>
    </xsl:template>
    
    <xsl:template match="tan:source" mode="convert-2017-to-2018">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates
                select="node() except tan:rights-source-only/(self::*, preceding-sibling::node()[1]/self::text())"
            />
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:see-also" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="relationship" select="replace(tan:relationship/@which, '\s+', '-')"
            />
            <xsl:apply-templates
                select="node() except (tan:relationship, (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:relationship]])"
                mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="tan:declarations" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:variable name="this-base-indent" select="tan:indent($ancestor-count)"/>
        <!--<xsl:variable name="relationship-idrefs" select="distinct-values(../tan:see-also/tan:relationship/@which)"/>-->
        <definitions>
            <!--<xsl:attribute name="a" select="$ancestor-count"/>-->
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates
                select="node() except (tan:rename-div-ns, tan:filter, (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:rename-div-ns or self::tan:filter]], node()[last()]/self::text())"
                mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
            <xsl:apply-templates
                select="ancestor::tan:head//(tan:agent, tan:role, tan:relationship[for $i in @which return not(exists(preceding::tan:relationship[@which = $i]))], (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:role or self::tan:agent or self::tan:relationship]]), 
                root()/*/tan:body/(tan:feature, (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:feature]]), 
                root()/*/tan:body/tan:category/(tan:feature, (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:feature]])"
                mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
                <xsl:with-param name="reindent" select="true()" tunnel="yes"/>
            </xsl:apply-templates>
            <xsl:value-of select="node()[last()]/self::text()"/>
        </definitions>
        <xsl:value-of select="$this-base-indent"/>
        <alter>
            <xsl:if test="exists(../tan:source/@xml:id)">
                <xsl:attribute name="src" select="*"/>
            </xsl:if>
            <xsl:copy-of select="tan:rename-div-ns/(self::*, preceding-sibling::node()[last()]/self::text())"/>
            <xsl:apply-templates
                select="tan:filter/(*, (text(), comment(), tan:comment)[following-sibling::*[1][self::*]]), /*/tan:body/(tan:split-leaf-div-at, tan:realign, tan:equate-works, (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:split-leaf-div-at or self::tan:realign or self::tan:equate-works]])"
                mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
                <xsl:with-param name="reindent" select="true()" tunnel="yes"/>
            </xsl:apply-templates>
            <xsl:value-of select="$this-base-indent"/>
        </alter>
        <xsl:for-each select="../tan:agent">
            <xsl:value-of select="$this-base-indent"/>
            <resp>
                <xsl:copy-of select="@* except (@xml:id, @which)"/>
                <xsl:if test="not(exists(@include))">
                    <xsl:attribute name="who" select="@xml:id"/>
                </xsl:if>
            </resp>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="tan:agent" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <person>
            <xsl:copy-of select="@* except @roles"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </person>
    </xsl:template>

    <xsl:template match="tan:role" mode="convert-2017-to-2018"> 
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:relationship" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="xml:id" select="replace(@which,'\s','-')"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:equate-works" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <equate>
            <xsl:copy-of select="@*"/>
        </equate>
    </xsl:template>
        
    <xsl:template match="tan:split-leaf-div-at" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:variable name="this-element" select="."/>
        <xsl:for-each-group select="node()"
            group-by="
                if (exists(@src)) then
                    @src
                else
                    (following-sibling::*/@src)[1]">
            <xsl:comment>Note, split-leaf-div-at has been removed. Study documentation on the element move instead.</xsl:comment>
            <split-leaf-div-at>
                <xsl:copy-of select="$this-element/@*"/>
                <xsl:attribute name="src" select="current-grouping-key()"/>
                <xsl:apply-templates select="current-group()" mode="#current">
                    <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
                    <xsl:with-param name="reindent" select="true()" tunnel="yes"/>
                    <xsl:with-param name="except-attribute" select="'src'"/>
                </xsl:apply-templates>
            </split-leaf-div-at>
        </xsl:for-each-group> 
    </xsl:template>
    
    <xsl:template match="tan:body" mode="convert-2017-to-2018"> 
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates
                select="node() except (tan:split-leaf-div-at, tan:realign, tan:feature, (text(), comment(), tan:comment)[following-sibling::*[1][self::tan:split-leaf-div-at or self::tan:realign or self::tan:feature]])"
                mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:assert | tan:report" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <rule>
            <xsl:apply-templates select="@context" mode="#current"/>
            <xsl:value-of select="tan:indent($ancestor-count + 1)"/>
            <xsl:copy>
                <xsl:apply-templates select="@* except @context" mode="#current"/>
                <xsl:value-of select="text()"/>
            </xsl:copy>
            <xsl:value-of select="tan:indent($ancestor-count)"/>
        </rule>
    </xsl:template>
    
    <xsl:template match="tan:TAN-A-lm/tan:body" mode="convert-2017-to-2018">
        <xsl:copy-of select="."/>
    </xsl:template>
    
    <xsl:template match="tan:body/tan:feature" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:variable name="this-code" select="@code"/>
        <xsl:variable name="this-code-converted">
            <xsl:choose>
                <xsl:when test="string-length($this-code) = 1">
                    <xsl:value-of
                        select="concat('x', tan:dec-to-hex(string-to-codepoints($this-code)))"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="replace(replace(replace($this-code,'\W','-'),'^(\d)','n$1'),'\$','dollar')"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="code-suited-to-xml-id" select="$this-code castable as xs:NCName"/>
        <xsl:if test="not($code-suited-to-xml-id)">
            <alias id="{$this-code}" idrefs="{$this-code-converted}"/>
            <xsl:value-of select="tan:indent($ancestor-count)"/>
        </xsl:if>
        <xsl:copy>
            <xsl:copy-of select="@* except @code"/>
            <xsl:attribute name="xml:id" select="$this-code-converted"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:category/tan:feature" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:variable name="this-cat-no" select="count(parent::tan:category/preceding-sibling::tan:category) + 1"/>
        <xsl:variable name="this-code" select="@code"/>
        <xsl:copy>
            <xsl:copy-of select="@* except @code"/>
            <xsl:attribute name="xml:id" select="concat('c', string($this-cat-no), $this-code)"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:category" mode="convert-2017-to-2018">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:variable name="this-cat-no" select="count(preceding-sibling::tan:category) + 1"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="type" select="concat('c', string($this-cat-no))"/>
            <xsl:for-each select="tan:feature">
                    <xsl:value-of select="tan:indent($ancestor-count + 1)"/>
                <xsl:copy>
                    <xsl:attribute name="type" select="concat('c', string($this-cat-no), @code)"/>
                    <xsl:attribute name="code"
                        select="(@code, concat('c', string($this-cat-no)))[1]"/>
                </xsl:copy>
            </xsl:for-each>
            <xsl:value-of select="tan:indent($ancestor-count)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="@TAN-version" mode="convert-2017-to-2018">
        <xsl:attribute name="TAN-version" select="'2018'"/>
    </xsl:template>
    <xsl:template match="@regex" mode="convert-2017-to-2018">
        <xsl:attribute name="pattern" select="."/>
    </xsl:template>
    <xsl:template match="@context" mode="convert-2017-to-2018">
        <xsl:attribute name="m-has-features" select="."/>
    </xsl:template>
    <xsl:template match="@feature-test" mode="convert-2017-to-2018">
        <xsl:attribute name="m-has-features" select="."/>
    </xsl:template>
    <xsl:template match="@regex" mode="convert-2017-to-2018">
        <xsl:attribute name="pattern" select="."/>
    </xsl:template>
    
    <xsl:template match="tan:suppress-div-types | tan:lexicon/tan:for-lang | tan:head/tan:for-lang" mode="convert-2017-to-2018"/>




    <!-- customized template for a particular collection -->
    <xsl:template match="tei:teiHeader" mode="special-collection-rules-1 special-collection-rules-2">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:copy>
            <xsl:copy-of select="@* except @*:type"/>
            <xsl:apply-templates mode="#current">
                <xsl:with-param name="ancestor-count" select="$ancestor-count + 1"/>
            </xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="tan:license[@include]" mode="special-collection-rules-1">
        <xsl:copy>
            <xsl:copy-of select="@* except @include"/>
            <xsl:attribute name="which" select="'by_4.0'"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:licensor[@include]" mode="special-collection-rules-1">
        <xsl:copy>
            <xsl:copy-of select="@* except @include"/>
            <xsl:attribute name="who" select="'kalvesmaki'"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:inclusion" mode="special-collection-rules-1">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:if test="not(exists(preceding-sibling::tan:inclusion))">
            <xsl:for-each select="($general-key-resolved, $second-key-resolved)">
                <xsl:if test="position() gt 1">
                    <xsl:copy-of select="tan:indent($ancestor-count)"/>
                </xsl:if>
                <xsl:apply-templates select="tan:TAN-key" mode="#current">
                    <xsl:with-param name="ancestor-count" select="$ancestor-count"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:TAN-key" mode="special-collection-rules-1">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <key>
            <xsl:copy-of select="tan:indent($ancestor-count + 1)"/>
            <IRI>
                <xsl:value-of select="@id"/>
            </IRI>
            <xsl:copy-of select="tan:indent($ancestor-count + 1)"/>
            <name>
                <xsl:value-of select="tan:head/tan:name[1]"/>
            </name>
            <xsl:copy-of select="tan:indent($ancestor-count + 1)"/>
            <location href="{tan:uri-relative-to(tan:base-uri(.), $doc-uri)}"
                when-accessed="{current-date()}"/>
            <xsl:copy-of select="tan:indent($ancestor-count)"/>
        </key>
    </xsl:template>
    <xsl:template match="tan:work[@include]" mode="special-collection-rules-1">
        <xsl:variable name="this-cpg" as="xs:string*">
            <xsl:analyze-string select="$doc-uri" regex="(no-)?cpg\d*\w?">
                <xsl:matching-substring>
                    <xsl:value-of select="."/>
                </xsl:matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:variable name="first-key-item"
            select="($second-key-resolved//tan:item[tan:IRI[matches(., concat($this-cpg, '$'))]])[1]"/>
        <xsl:copy>
            <xsl:copy-of select="@* except @include"/>
            <xsl:attribute name="which" select="$first-key-item/tan:name[1]"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:div-type" mode="special-collection-rules-1">
        <xsl:param name="ancestor-count" as="xs:integer"/>
        <xsl:if test="not(exists(preceding-sibling::tan:div-type))">
            <xsl:variable name="div-types-used" select="distinct-values(root()//*:div/@type)"/>
            <xsl:for-each select="$div-types-used">
                <xsl:variable name="type-adjusted">
                    <xsl:choose>
                        <xsl:when test=". = 'head'">
                            <xsl:value-of select="'heading'"/>
                        </xsl:when>
                        <xsl:when test=". = 'sect'">
                            <xsl:value-of select="'section'"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="."/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:if test="not(position() = 1)">
                    <xsl:copy-of select="tan:indent($ancestor-count)"/>
                </xsl:if>
                <div-type which="{$type-adjusted}" xml:id="{.}"/>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>
    <xsl:template match="tan:token-definition | tan:see-also[not(tan:location)]" mode="special-collection-rules-1"/>
    <xsl:template match="tan:person[@include]" mode="special-collection-rules-1">
        <person xml:id="kalvesmaki" which="Joel Kalvesmaki"/>
    </xsl:template>
    <xsl:template match="tan:role[@include]" mode="special-collection-rules-1">
        <role xml:id="editor" which="editor"/>
    </xsl:template>
    <xsl:template match="tan:resp[@include]" mode="special-collection-rules-1">
        <resp who="kalvesmaki" roles="editor"/>
    </xsl:template>
    
    
    <!-- 2nd set of special rules -->
    <xsl:template match="tan:person[@xml:id = 'perseus']" mode="special-collection-rules-2">
        <organization>
            <xsl:copy-of select="@*"/>
        </organization>
    </xsl:template>
    

    <xsl:variable name="pass1" as="document-node()">
        <xsl:document>
            <xsl:for-each select="/node()">
                <xsl:text>&#xa;</xsl:text>
                <xsl:apply-templates select="." mode="convert-2017-to-2018">
                    <xsl:with-param name="ancestor-count" select="0"/>
                </xsl:apply-templates>
            </xsl:for-each>
        </xsl:document>
    </xsl:variable>
    <xsl:variable name="pass2" as="document-node()">
        <xsl:choose>
            <xsl:when test="$apply-special-collection-rules-2">
                <xsl:apply-templates select="$pass1" mode="special-collection-rules-2">
                    <xsl:with-param name="ancestor-count" select="0"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$apply-special-collection-rules-1">
                <!--<xsl:copy-of select="$key-resolved"/>-->
                <xsl:apply-templates select="$pass1" mode="special-collection-rules-1">
                    <xsl:with-param name="ancestor-count" select="0"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$pass1"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <xsl:template match="/">
        <xsl:apply-templates select="$pass2" mode="credit-stylesheet"/>
    </xsl:template>

</xsl:stylesheet>
