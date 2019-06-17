<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:tan="tag:textalign.net,2015:ns"
    xmlns:saxon="http://saxon.sf.net/" exclude-result-prefixes="#all" version="2.0">

    <!-- This stylesheet, coupled with its major parameter, is intended to perform major structural alterations on any TAN file in preparation for its reuse. HTML is primarily in mind, so attributes are either converted to children elements or dropped altogether. Elements part of non-mixed content may be reordered, and elements can be marked as needing to be grouped if there are more than one of them as siblings. Further, any element or attribute may be prefaced by a <label>, whose text content will notify the significance of the data that follows. -->

    <xsl:variable name="order-of-alter-actions"
        select="('skip', 'wrap', 'add-attributes', 'rename', 'prepend-content', 'append-content')"/>

    <xsl:function name="tan:alter" as="item()*">
        <!-- Input: any XML fragments that should be altered; documents that conform to alter.rnc or elements whose contents conform to those of the root element defined in alter.rnc -->
        <!-- Output: the items, after altering -->
        <!-- Caution: if multiple alters are provided, the phase names will be ordered primarily by the first alter; this may result in phases being executed in an unpredictable way -->
        <xsl:param name="items-to-alter" as="item()*"/>
        <xsl:param name="alters" as="item()*"/>
        <xsl:variable name="master-phase-list" as="element()">
            <phase-list>
                <xsl:for-each-group
                    select="$alters//tan:phase[not(preceding-sibling::tan:breakpoint)]"
                    group-by="@xml:id">
                    <xsl:copy-of select="current-group()[1]"/>
                </xsl:for-each-group>
            </phase-list>
        </xsl:variable>
        <xsl:variable name="phases-to-process" as="xs:string+"
            select="('#default', $master-phase-list/tan:phase/@xml:id)"/>
        <xsl:variable name="alter-elements" as="element()*">
            <xsl:apply-templates select="$alters//tan:alter" mode="normalize-alter"/>
        </xsl:variable>
        <!--<xsl:copy-of select="$master-phase-list"/>-->
        <!--<xsl:copy-of select="$alter-elements"/>-->
        <xsl:copy-of
            select="tan:alter-loop($items-to-alter, $alter-elements, $phases-to-process)"/>
    </xsl:function>
    <xsl:template match="tan:alter[not(tan:where)] | tan:where" mode="normalize-alter">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:if test="not(exists(@phases))">
                <xsl:attribute name="phases" select="'#default'"/>
            </xsl:if>
            <xsl:copy-of select="node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:function name="tan:alter-loop" as="item()*">
        <!-- loop function supporting the one above -->
        <xsl:param name="items-to-alter" as="item()*"/>
        <xsl:param name="alter-elements-normalized" as="item()*"/>
        <xsl:param name="phases-to-process" as="xs:string*"/>

        <xsl:choose>
            <xsl:when test="not(exists($phases-to-process))">
                <xsl:copy-of select="$items-to-alter"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="this-phase" select="$phases-to-process[1]"/>
                <!--<xsl:variable name="relevant-alters"
                    select="$alter-elements-normalized[some $i in (@phases, tan:where/@phases) satisfies (tokenize($i,'\s+') = $this-phase)]"
                />-->
                <xsl:variable name="relevant-alters" as="element()*">
                    <xsl:apply-templates select="$alter-elements-normalized" mode="alter-alters">
                        <xsl:with-param name="phase-chosen" select="$this-phase" tunnel="yes"/>
                    </xsl:apply-templates>
                </xsl:variable>
                <xsl:choose>
                    <xsl:when test="not(exists($relevant-alters))">
                        <xsl:copy-of
                            select="tan:alter-loop($items-to-alter, $alter-elements-normalized, $phases-to-process[position() gt 1])"
                        />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="results" as="item()*">
                            <xsl:apply-templates select="$items-to-alter"
                                mode="alter-tan-for-reuse">
                                <xsl:with-param name="current-phase" select="$this-phase"
                                    tunnel="yes"/>
                                <xsl:with-param name="alters" select="$relevant-alters"
                                    tunnel="yes"/>
                            </xsl:apply-templates>
                        </xsl:variable>
                        <!--<test22a>
                            <xsl:copy-of select="$relevant-alters"/>
                        </test22a>-->
                        <xsl:copy-of
                            select="tan:alter-loop($results, $alter-elements-normalized, $phases-to-process[position() gt 1])"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    <xsl:template match="tan:alter | *[@phases]" mode="alter-alters">
        <xsl:param name="phase-chosen" as="xs:string?" tunnel="yes"/>
        <xsl:variable name="these-phases-targeted" select="tokenize(normalize-space(@phases), ' ')"/>
        <xsl:variable name="children-conditions" as="element()*">
            <xsl:apply-templates select="*[@phases]" mode="#current"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$phase-chosen = $these-phases-targeted">
                <xsl:copy-of select="."/>
            </xsl:when>
            <xsl:when test="exists($children-conditions)">
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:copy-of select="$children-conditions"/>
                    <xsl:copy-of select="*[not(@phases)]"/>
                </xsl:copy>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="apply-alter-action" priority="1">
        <xsl:param name="alter-action" as="element()?"/>
        <xsl:variable name="this-element" select="."/>
        <xsl:choose>
            <xsl:when test="$alter-action/self::tan:skip[not(@shallow) or @shallow = true()]">
                <xsl:copy-of select="node()"/>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:skip"/>
            <xsl:when test="$alter-action/self::tan:wrap">
                <xsl:variable name="this-namespace"
                    select="($alter-action/@namespace, namespace-uri(.))[1]"/>
                <xsl:element name="{$alter-action/@element-name}">
                    <xsl:copy-of select="."/>
                </xsl:element>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:rename">
                <xsl:variable name="this-namespace"
                    select="($alter-action/@namespace, namespace-uri(.))[1]"/>
                <xsl:element name="{$alter-action/@new}" namespace="{$this-namespace}">
                    <xsl:copy-of select="@*"/>
                    <xsl:copy-of select="node()"/>
                </xsl:element>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:prepend-content">
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:apply-templates select="$alter-action/node()" mode="evaluate-node">
                        <xsl:with-param name="context" select="." tunnel="yes"/>
                        <xsl:with-param name="processing-instruction" select="'deep-copy'"/>
                    </xsl:apply-templates>
                    <xsl:copy-of select="node()"/>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:append-content">
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:copy-of select="node()"/>
                    <xsl:apply-templates select="$alter-action/node()" mode="evaluate-node">
                        <xsl:with-param name="context" select="." tunnel="yes"/>
                        <xsl:with-param name="processing-instruction" select="'deep-copy'"/>
                    </xsl:apply-templates>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:add-attributes">
                <xsl:variable name="replace-existing" as="xs:boolean"
                    select="not(exists($alter-action/@replace-existing)) or ($alter-action/@replace-existing = true())"/>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:for-each select="$alter-action/(@* except @replace-existing)">
                        <xsl:choose>
                            <xsl:when test="$replace-existing">
                                <xsl:apply-templates select="." mode="evaluate-node">
                                    <xsl:with-param name="context" select="$this-element"
                                        tunnel="yes"/>
                                </xsl:apply-templates>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:variable name="this-attr-name" select="name(.)"/>
                                <xsl:variable name="existing-attr"
                                    select="$this-element/@*[name(.) = $this-attr-name]"/>
                                <xsl:attribute name="{$this-attr-name}"
                                    select="string-join(($existing-attr, tan:evaluate(string(.), $this-element)), ' ')"
                                />
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each>
                    <xsl:copy-of select="node()"/>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:prepend-siblings">
                <xsl:apply-templates select="$alter-action/node()" mode="evaluate-node">
                    <xsl:with-param name="context" select="." tunnel="yes"/>
                    <xsl:with-param name="processing-instruction" select="'deep-copy'"/>
                </xsl:apply-templates>
                <xsl:copy-of select="."/>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:append-siblings">
                <xsl:copy-of select="."/>
                <xsl:apply-templates select="$alter-action/node()" mode="evaluate-node">
                    <xsl:with-param name="context" select="." tunnel="yes"/>
                    <xsl:with-param name="processing-instruction" select="'deep-copy'"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:children-elements">
                <xsl:variable name="child-alter-action" select="$alter-action/*[1]"/>
                <xsl:variable name="expected-group-size"
                    select="max(($child-alter-action/@min-group-size, 1))"/>
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:choose>
                        <!-- What action is to be performed on the children? -->
                        <xsl:when test="$child-alter-action/self::tan:group">
                            <xsl:variable name="adjacent-grouping" as="xs:boolean"
                                select="($child-alter-action/@adjacent = true()) or (not(exists($child-alter-action/@adjacent)))"/>
                            <!-- first process the elements -->
                            <xsl:choose>
                                <xsl:when test="$adjacent-grouping">
                                    <xsl:for-each-group select="*"
                                        group-adjacent="tan:all-conditions-hold($alter-action, .)">
                                        <xsl:choose>
                                            <xsl:when test="current-grouping-key() = true()">
                                                <xsl:for-each-group select="current-group()"
                                                  group-adjacent="name(.)">
                                                  <xsl:copy-of
                                                  select="tan:group-elements(current-group(), $expected-group-size, $child-alter-action/@prepend-label)"
                                                  />
                                                </xsl:for-each-group>
                                            </xsl:when>
                                            <xsl:otherwise>
                                                <xsl:copy-of select="current-group()"/>
                                            </xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:for-each-group>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:choose>
                                        <xsl:when test="current-grouping-key() = true()">
                                            <xsl:for-each-group select="current-group()"
                                                group-by="name(.)">
                                                <xsl:copy-of
                                                  select="tan:group-elements(current-group(), $expected-group-size, $child-alter-action/@prepend-label)"
                                                />
                                            </xsl:for-each-group>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:copy-of select="current-group()"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:otherwise>
                            </xsl:choose>
                            <!-- now copy anything that's not an element -->
                            <xsl:copy-of select="text(), comment(), processing-instruction()"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <!-- no action has been defined, so just copy all children as-is -->
                            <xsl:copy-of select="node()"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="@*" mode="apply-alter-action" priority="1">
        <xsl:param name="alter-action" as="element()?"/>
        <xsl:choose>
            <xsl:when test="$alter-action/self::tan:skip"/>
            <xsl:when test="$alter-action/self::tan:rename">
                <xsl:attribute name="{$alter-action/@new}" select="."/>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:replace">
                <xsl:attribute name="{name(.)}" select="tan:batch-replace(., $alter-action)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="text() | processing-instruction() | comment()" mode="apply-alter-action"
        priority="1">
        <xsl:param name="alter-action" as="element()?"/>
        <xsl:choose>
            <xsl:when test="$alter-action/self::tan:skip"/>
            <xsl:when test="$alter-action/self::tan:wrap">
                <xsl:variable name="this-prefix" select="$alter-action/@namespace-prefix"/>
                <xsl:variable name="this-namespace"
                    select="($alter-action/@namespace, namespace-uri(parent::*))[1]"/>
                <xsl:variable name="this-name"
                    select="string-join(($this-prefix, $alter-action/@element-name), ':')"/>
                <xsl:element name="{$this-name}" namespace="{$this-namespace}">
                    <xsl:copy-of select="."/>
                </xsl:element>
            </xsl:when>
            <xsl:when test="$alter-action/(self::tan:prepend-content, self::tan:prepend-siblings)">
                <xsl:apply-templates select="$alter-action/node()" mode="evaluate-node">
                    <xsl:with-param name="context" select="." tunnel="yes"/>
                    <xsl:with-param name="processing-instruction" select="'deep-copy'"/>
                </xsl:apply-templates>
                <xsl:copy-of select="."/>
            </xsl:when>
            <xsl:when test="$alter-action/(self::tan:append-content, self::tan:append-siblings)">
                <xsl:copy-of select="."/>
                <xsl:apply-templates select="$alter-action/node()" mode="evaluate-node">
                    <xsl:with-param name="context" select="." tunnel="yes"/>
                    <xsl:with-param name="processing-instruction" select="'deep-copy'"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$alter-action/self::tan:replace">
                <xsl:copy-of select="tan:batch-replace(., $alter-action)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="*" mode="evaluate-node">
        <xsl:param name="processing-instruction" as="xs:string?"/>
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="#current"/>
            <xsl:if test="string-length($processing-instruction) gt 0">
                <xsl:processing-instruction name="tan-alter">
                    <xsl:value-of select="$processing-instruction"/>
                </xsl:processing-instruction>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="@*" mode="evaluate-node">
        <xsl:param name="context" tunnel="yes"/>
        <xsl:variable name="value-evaluated" select="tan:evaluate(., $context)"/>
        <xsl:attribute name="{name(.)}" select="$value-evaluated"/>
    </xsl:template>
    <xsl:template match="text()" mode="evaluate-node">
        <xsl:param name="context" tunnel="yes"/>
        <xsl:value-of select="tan:evaluate(., $context)"/>
    </xsl:template>

    <xsl:function name="tan:alter-action-loop">
        <!-- Input: a node that should be altered; a series of elements providing alter actions -->
        <!-- Output: that node, after going through all alters -->
        <xsl:param name="altered-fragment-so-far" as="item()*"/>
        <xsl:param name="alter-actions" as="element()*"/>
        <xsl:choose>
            <xsl:when test="not(exists($alter-actions))">
                <xsl:copy-of select="$altered-fragment-so-far"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="this-alter-action" select="$alter-actions[1]"/>
                <xsl:variable name="results" as="item()*">
                    <xsl:apply-templates select="$altered-fragment-so-far"
                        mode="apply-alter-action">
                        <xsl:with-param name="alter-action" select="$this-alter-action"/>
                    </xsl:apply-templates>
                </xsl:variable>
                <xsl:variable name="next-alter-actions" select="$alter-actions[position() gt 1]"/>
                <xsl:choose>
                    <xsl:when test="name($this-alter-action) = ('skip', 'wrap')">
                        <xsl:if test="exists($next-alter-actions)">
                            <xsl:message>
                                <xsl:text>Current action leaves unprocessed actions. Current action: </xsl:text>
                                <xsl:value-of select="tan:xml-to-string($this-alter-action)"/>
                            </xsl:message>
                            <xsl:message>
                                <xsl:text>Unprocessed alter actions: </xsl:text>
                                <xsl:value-of select="tan:xml-to-string($next-alter-actions)"/>
                            </xsl:message>
                        </xsl:if>
                        <xsl:copy-of select="$results"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy-of select="tan:alter-action-loop($results, $next-alter-actions)"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:template match="@evaluate" mode="evaluate-conditions">
        <xsl:param name="context" tunnel="yes" as="item()?"/>
        <xsl:variable name="context-evaluated" select="tan:evaluate(string(.), $context)"/>
        <xsl:attribute name="{name()}">
            <xsl:value-of select="$context-evaluated[. castable as xs:boolean] = true()"/>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="@node-matches" mode="evaluate-conditions">
        <xsl:param name="context" tunnel="yes" as="item()?"/>
        <xsl:attribute name="{name()}">
            <xsl:choose>
                <xsl:when test="$context castable as xs:string">
                    <xsl:value-of select="tan:matches(string($context), .)"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="false()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="@node-name" mode="evaluate-conditions">
        <xsl:param name="context" tunnel="yes" as="item()?"/>
        <xsl:variable name="these-vals" select="tokenize(normalize-space(.), ' ')"/>
        <xsl:attribute name="{name()}">
            <xsl:value-of select="(name($context), '*') = $these-vals"/>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="@node-type" mode="evaluate-conditions">
        <xsl:param name="context" tunnel="yes" as="item()?"/>
        <xsl:variable name="these-vals" select="tokenize(normalize-space(.), ' ')"/>
        <xsl:variable name="context-check" as="xs:boolean*">
            <xsl:if test="$these-vals = 'element'">
                <xsl:value-of select="$context instance of element()"/>
            </xsl:if>
            <xsl:if test="$these-vals = 'attribute'">
                <xsl:value-of select="$context instance of attribute()"/>
            </xsl:if>
            <xsl:if test="$these-vals = 'comment'">
                <xsl:value-of select="$context instance of comment()"/>
            </xsl:if>
            <xsl:if test="$these-vals = 'processing-instruction'">
                <xsl:value-of select="$context instance of processing-instruction()"/>
            </xsl:if>
            <xsl:if test="$these-vals = 'document-node'">
                <xsl:value-of select="$context instance of document-node()"/>
            </xsl:if>
            <xsl:if test="$these-vals = 'text'">
                <xsl:value-of select="$context instance of text()"/>
            </xsl:if>
        </xsl:variable>
        <xsl:attribute name="{name()}">
            <xsl:value-of select="exists($context-check) and ($context-check = true())"/>
        </xsl:attribute>
    </xsl:template>
    <xsl:template match="@node-namespace" mode="evaluate-conditions">
        <xsl:param name="context" tunnel="yes" as="item()?"/>
        <xsl:variable name="this-namespace" select="namespace-uri($context)"/>
        <xsl:attribute name="{name()}">
            <xsl:value-of select=". = $this-namespace"/>
        </xsl:attribute>
    </xsl:template>

    <xsl:variable name="test-sequence" select="('phase', 'node-name', 'node-type', 'node-namespace')"/>
    <xsl:template match="node() | @*" priority="1" mode="alter-tan-for-reuse">
        <xsl:param name="current-phase" tunnel="yes" as="xs:string?"/>
        <xsl:param name="alters" tunnel="yes"/>
        <xsl:param name="delay" select="0" as="xs:integer"/>
        <xsl:variable name="this-node" select="."/>
        <xsl:variable name="these-alters"
            select="$alters[(self::*, tan:where)[tan:all-conditions-hold(., $this-node, $test-sequence, false())]]"/>
        <xsl:variable name="special-pi" select="processing-instruction()[matches(., 'deep-copy')]"/>
        <xsl:choose>
            <xsl:when test="exists($special-pi)">
                <xsl:copy>
                    <xsl:copy-of select="@*"/>
                    <xsl:copy-of select="node() except processing-instruction()"/>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="$delay gt 0">
                <xsl:copy>
                    <xsl:apply-templates select="node() | @*" mode="#current">
                        <xsl:with-param name="delay" select="$delay - 1"/>
                    </xsl:apply-templates>
                </xsl:copy>
            </xsl:when>
            <xsl:when test="exists($these-alters)">
                <xsl:variable name="these-actions-sorted" as="element()*">
                    <xsl:for-each select="$these-alters/(* except tan:where)">
                        <xsl:sort select="(index-of($order-of-alter-actions, name(.)), 999)[1]"/>
                        <xsl:copy-of select="."/>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="this-node-changed" as="item()*"
                    select="tan:alter-action-loop(., $these-actions-sorted)"/>
                <xsl:choose>
                    <xsl:when test="exists($these-actions-sorted/self::tan:skip)">
                        <!-- If there's been a skip, work on the next nodes -->
                        <xsl:apply-templates select="$this-node-changed" mode="#current"/>
                    </xsl:when>
                    <xsl:when test="exists($these-actions-sorted/self::tan:wrap)">
                        <!-- If there's been a wrap, work on the grandchildren nodes -->
                        <xsl:apply-templates select="$this-node-changed" mode="#current">
                            <xsl:with-param name="delay" select="2"/>
                        </xsl:apply-templates>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:for-each select="$this-node-changed">
                            <xsl:copy>
                                <xsl:apply-templates select="node() | @*" mode="#current"/>
                            </xsl:copy>
                        </xsl:for-each>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="node() | @*" mode="#current"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>




    <!-- bookmark; leftovers from previous version -->
    <xsl:function name="tan:group-min" as="xs:integer*">
        <!-- Input: any sequence of attributes or elements; an attribute name whose truth value should be checked -->
        <!-- Output: the same number of booleans, indicating whether the attribute or element should be suppressed, grouped, or whatever (dependent upon the name of the attribute), given the parameters of the stylesheet -->
        <xsl:param name="attributes-or-elements" as="item()*"/>
        <xsl:for-each select="$attributes-or-elements">
            <xsl:variable name="node-name" select="name(.)"/>
            <xsl:variable name="node-type" as="xs:string?">
                <xsl:choose>
                    <xsl:when test=". instance of element()">element</xsl:when>
                    <xsl:when test=". instance of attribute()">attribute</xsl:when>
                </xsl:choose>
            </xsl:variable>
            <xsl:value-of
                select="($alter-doc/*/*[name() = $node-type and @name = $node-name]/@group-min, $alter-doc/*/@group-min, 999999)[1]"
            />
        </xsl:for-each>
    </xsl:function>

    <xsl:function name="tan:get-label" as="element()?">
        <xsl:param name="node" as="item()?"/>
        <xsl:param name="is-grouped" as="xs:boolean"/>
        <xsl:sequence select="tan:get-label($node, $is-grouped, false())"/>
    </xsl:function>
    <xsl:function name="tan:get-label" as="element()?">
        <!-- Input: any attribute or element; a yes/no value indicating whether the group label should be retrieved instead -->
        <!-- Output: a <label> with the value of the label specified by the parameter -->
        <xsl:param name="node" as="item()?"/>
        <xsl:param name="is-grouped" as="xs:boolean"/>
        <xsl:param name="is-group" as="xs:boolean"/>
        <xsl:variable name="node-name" select="name($node)"/>
        <xsl:variable name="node-is-attribute" select="$node instance of attribute()"/>
        <xsl:variable name="node-type" as="xs:string?">
            <xsl:choose>
                <xsl:when test="$node instance of element()">element</xsl:when>
                <xsl:when test="$node-is-attribute">attribute</xsl:when>
                <xsl:when test="$node instance of comment()">comment</xsl:when>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="node-namespace"
            select="
                if ($node-is-attribute = true()) then
                    namespace-uri($node/parent::*)
                else
                    namespace-uri($node)"/>
        <xsl:variable name="this-param"
            select="$alter-doc/*/*[name() = $node-type and @name = $node-name]"/>
        <xsl:variable name="this-label" as="xs:string?"
            select="
                if ($is-group = true()) then
                    ($this-param/@group-label, $alter-doc/*/@group-label, (concat(($this-param/@label, $alter-doc/*/@label)[1], 's')))[1]
                else
                    if ($is-grouped = true()) then
                        ($this-param/@group-item-label, $alter-doc/*/@group-item-label, $this-param/@label, $alter-doc/*/@label)[1]
                    else
                        ($this-param/@label, $alter-doc/*/@label)[1]"/>
        <xsl:variable name="label-format"
            select="($this-param/@format-label, $alter-doc/*/@format-label)[1]"/>
        <xsl:variable name="label-format-constructor"
            select="$alter-doc//tan:format-label[@xml:id = $label-format]"/>
        <xsl:variable name="label-value" select="tan:evaluate($this-label, $node)"/>
        <!--<xsl:message select="$is-group, $this-label, $label-value"/>-->
        <xsl:variable name="new-label" select="string-join($label-value, '')"/>
        <!-- format the label -->
        <xsl:if test="string-length($new-label) gt 0 and $node-type = ('element', 'attribute')">
            <xsl:element name="label" namespace="{$node-namespace}">
                <xsl:value-of
                    select="
                        if (exists($label-format-constructor)) then
                            tan:format-string($new-label, $label-format-constructor)
                        else
                            $new-label"
                />
            </xsl:element>
        </xsl:if>
    </xsl:function>

    <xsl:function name="tan:format-string" as="xs:string*">
        <!-- Input: any sequence of strings; and a specially constructed element with child <replace> and <change-case>s -->
        <!-- Output: the same strings, after transformation -->
        <xsl:param name="strings" as="xs:string*"/>
        <xsl:param name="format-element" as="element()"/>
        <xsl:for-each select="$strings">
            <xsl:variable name="this-string" select="."/>
            <xsl:apply-templates select="$format-element/*[1]" mode="format-string">
                <xsl:with-param name="string" select="$this-string"/>
            </xsl:apply-templates>
        </xsl:for-each>
    </xsl:function>
    <xsl:template match="*" mode="format-string">
        <xsl:param name="string" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="following-sibling::*">
                <xsl:apply-templates select="following-sibling::*[1]" mode="format-string">
                    <xsl:with-param name="string" select="$string"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$string"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="tan:replace" mode="format-string">
        <xsl:param name="string" as="xs:string"/>
        <xsl:variable name="new-string"
            select="replace($string, @pattern, @replacement, (@flags, '')[1])"/>
        <xsl:choose>
            <xsl:when test="following-sibling::*">
                <xsl:apply-templates select="following-sibling::*[1]" mode="format-string">
                    <xsl:with-param name="string" select="$new-string"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$new-string"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="tan:change-case" mode="format-string">
        <xsl:param name="string" as="xs:string"/>
        <xsl:variable name="string-analyzed" select="tokenize($string, '\s+')"/>
        <xsl:variable name="to-upper" select="matches(@to, 'upper', 'i')"/>
        <xsl:variable name="to-lower" select="matches(@to, 'lower', 'i')"/>
        <xsl:variable name="words-picked" select="tokenize(@words, '\s+')"/>
        <xsl:variable name="initial-only" select="tan:true(@initial-only)"/>
        <xsl:variable name="new-string" as="xs:string*">
            <xsl:for-each select="$string-analyzed">
                <xsl:variable name="pos" select="position()"/>
                <xsl:choose>
                    <xsl:when
                        test="
                            string($pos) = $words-picked
                            or ($pos = count($string-analyzed) and $words-picked = 'last')
                            or matches($words-picked, '^any|all|\*$', 'i')">
                        <xsl:choose>
                            <xsl:when test="$to-upper = true()">
                                <xsl:value-of
                                    select="
                                        if ($initial-only = true()) then
                                            concat(upper-case(substring(., 1, 1)), substring(., 2))
                                        else
                                            upper-case(.)"
                                />
                            </xsl:when>
                            <xsl:when test="$to-lower = true()">
                                <xsl:value-of
                                    select="
                                        if ($initial-only = true()) then
                                            concat(lower-case(substring(., 1, 1)), substring(., 2))
                                        else
                                            upper-case(.)"
                                />
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="."/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="."/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="following-sibling::*">
                <xsl:apply-templates select="following-sibling::*[1]" mode="format-string">
                    <xsl:with-param name="string" select="string-join($new-string, ' ')"/>
                </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="string-join($new-string, ' ')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
