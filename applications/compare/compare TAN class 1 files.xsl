<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:tan="tag:textalign.net,2015:ns" exclude-result-prefixes="#all" version="3.0">
    
    <!--<xsl:import href="../get%20inclusions/convert.xsl"/>-->
    <xsl:include href="../get%20inclusions/core-for-TAN-output.xsl"/>
    <xsl:include href="../../functions/TAN-A-functions.xsl"/>
    <xsl:include href="../../functions/TAN-extra-functions.xsl"/>
    <xsl:include href="../get%20inclusions/save-files.xsl"/>
    
    <xsl:import href="../get%20inclusions/convert-TAN-to-HTML.xsl"/>

    <!-- This is a MIRU Stylesheet (MIRU = Main Input Resolved URIs) -->
    <!-- Primary (catalyzing) input: any XML file, including this one -->
    <!-- Secondary (main) input: resolved URIs to one or more class-1 files -->
    <!-- Primary output: perhaps diagnostics -->
    <!-- Secondary output: for each group of files to be compared: (1) an XML file with the results
        of tan:diff() or tan:collate(), along with select statistical analyses; (2) an HTML file presenting
        the differences visually -->

    <!-- This stylesheet is useful only if the processed files are different versions of the same work in the same language. -->
    <!-- The XML output is a straightforward result of tan:diff() or tan:collate(), perhaps with statistical analysis prepended
    inside the root element. The HTML output has been designed to work with specific JavaScript and CSS files, and the HTML output
    will not render correctly unless you have set up dependencies correctly. See comments in code below. -->
    <!-- This application has considerable potential for development. Desiderata:
        1. Support a single TAN-A as the catalyst or MIRU provider, allowing <alias> to define the groups.
        2. Support MIRUs that point to non-TAN files, e.g., plain text, docx, xml.
        3. Support choice on whether Venn diagrams adjust the common area or not.
        4. Support choices of statistics to provide.
    -->

    <xsl:output indent="yes"/>
    
    <xsl:variable name="relative-uri-to-examples" select="'../../examples'"/>
    <xsl:variable name="relative-uri-1" select="'../../../library-arithmeticus/aristotle'"/>
    <xsl:variable name="relative-uri-2" select="'../../../library-arithmeticus/evagrius'"/>
    <xsl:variable name="relative-uri-3" select="'../../../library-arithmeticus/bible'"/>
    
    <!-- In what directory are the class-1 files to be compared? Unless $main-input-resolved-uris has been given values directly, this parameter will be used to get a collection of all files in the directories chosen. -->
    <xsl:param name="main-input-resolved-uri-directories" as="xs:string*"
        select="string(resolve-uri($relative-uri-3, static-base-uri()))"/>
    
    <!-- The input files are at what resolved URIs? Example: 'file:/c:/users/cjohnson/Downloads' -->
    <xsl:param name="main-input-resolved-uris" as="xs:string*">
        <xsl:for-each select="$main-input-resolved-uri-directories">
            <xsl:try select="uri-collection(.)">
                <xsl:catch>
                    <xsl:message select="'Unable to get a uri collection from ' || ."/>
                </xsl:catch>
            </xsl:try>
        </xsl:for-each>
    </xsl:param>
    
    <!-- For a main input resolved URI to be used, what pattern (regular expression) must be matched? Any item in $main-input-resolved-uris not matching this pattern will be excluded. A null or empty string results in this parameter being ignored. -->
    <xsl:param name="mirus-must-match-regex" as="xs:string?" select="'psalms.lat.+xml$'"/>

    <!-- For a main input resolved URI to be used, what pattern (regular expression) must NOT be matched? Any item in $main-input-resolved-uris matching this pattern will be excluded. A null or empty string results in this parameter being ignored. -->
    <xsl:param name="mirus-must-not-match-regex" as="xs:string?" select="'14616'"/>
    
    <xsl:variable name="mirus-chosen"
        select="
            $main-input-resolved-uris[if (string-length($mirus-must-match-regex) gt 0) then
                matches(., $mirus-must-match-regex, 'i')
            else
                true()][if (string-length($mirus-must-not-match-regex) gt 0) then
                not(matches(., $mirus-must-not-match-regex, 'i'))
            else
                true()]"
    />
    
    <!-- Should tan:collate() be allowed to re-sort the strings to take advantage of optimal matches? True produces better results, but could take longer than false. -->
    <xsl:param name="preoptimize-string-order" as="xs:boolean" select="true()"/>
    
    <!-- What alterations, if any, should be made to strings BEFORE tan:diff() or tan:collate() are applied? These take the form of a sequence of elements with attributes named after the parameters in fn:replace() along with an optional @message. Example: <replace pattern="q" replacement="" flags="i" message="Deleting q's."/> -->
    <xsl:param name="batch-replacements" as="element()*"/>
    
    <!-- What text differences should be ignored when compiling difference statistics? These are built into a series of elements that group <c>s, e.g. <alias><c>'</c><c>"</c></alias> would, for statistical purposes, ignore differences merely of a single apostrophe and quotation mark. This affects only statistics. The difference would still be visible in the diff/collation. -->
    <xsl:param name="unimportant-change-character-aliases" as="element()*"/>
    
    <!-- What text differences should be ignored when compiling difference statistics? Example, [\r\n] ignores any deleted or inserted line endings. Such differences will still be visible, but they will be ignored for the purposes of statistics. -->
    <xsl:variable name="unimportant-change-regex" as="xs:string" select="'[\r\n]'"/>
    
    
    
    
    <!-- STYLESHEET PARAMETERS -->
    <xsl:param name="stylesheet-iri"
        select="'tag:textalign.net,2015:stylesheet:compare-class-1-files'"/>
    <xsl:param name="stylesheet-url" select="static-base-uri()"/>
    <xsl:param name="stylesheet-name" select="'Application to compare class 1 files'"/>
    <xsl:param name="change-message" select="'Compared class 1 files.'"/>
    
    
    <!-- Beginning of main input -->
    
    <xsl:variable name="main-input-files" select="tan:open-file($mirus-chosen)"/>
    
    <xsl:variable name="main-input-class-1-files" select="$main-input-files[tei:TEI or tan:TAN-T]"/>
    
    <xsl:variable name="main-input-files-resolved" as="document-node()*"
        select="
            for $i in $main-input-class-1-files
            return
                tan:resolve-doc($i, false(), ())"
    />
    
    <xsl:variable name="main-input-files-expanded" as="document-node()*"
        select="
            for $i in $main-input-files-resolved
            return
                tan:expand-doc($i, 'terse', false())"
    />
    
    <!-- The mode core-expansion-ad-hoc-pre-pass mode is used to build grouping and sort keys. If you wish to modify how groups are built,
    or sorted, you can simply add rules to the template mode build-comparison-[grouping/sort]-key -->
    <xsl:template match="/*" mode="core-expansion-ad-hoc-pre-pass">
        <xsl:variable name="keys-and-label" as="element()*">
            <xsl:apply-templates select="." mode="build-keys-and-label"/>
        </xsl:variable>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="grouping-key" select="string-join($keys-and-label/self::tan:grouping-key, ' ')"/>
            <xsl:attribute name="sort-key" select="string-join($keys-and-label/self::tan:sort-key, ' ')"/>
            <xsl:attribute name="label" select="replace(string-join($keys-and-label/self::tan:label, '_'), '[\s.]', '_')"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <!-- by default, nothing goes into keys or a label unless specified -->
    <xsl:template match="* | text() | comment() | processing-instruction()" mode="build-keys-and-label">
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <!-- A diff/collation of texts that do not share the same language makes no sense, so the @xml:lang value should be part of the key. -->
    <xsl:template match="*:body" mode="build-keys-and-label">
        <grouping-key><xsl:value-of select="@xml:lang"/></grouping-key>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    <!-- Default sort and label is by filename -->
    <xsl:template match="/*" mode="build-keys-and-label">
        <xsl:variable name="this-filename" select="tan:cfn(@xml:base)"/>
        <sort-key><xsl:value-of select="$this-filename"/></sort-key>
        <label><xsl:value-of select="$this-filename"/></label>
        <xsl:apply-templates mode="#current"/>
    </xsl:template>
    
    
    <!-- This builds a series of XML documents with the diffs and collations, plus simple metadata on each file -->
    <xsl:variable name="file-groups-diffed-and-collated" as="document-node()*">
        <xsl:for-each-group select="$main-input-files-expanded" group-by="*/@grouping-key">
            <xsl:variable name="this-group-pos" select="position()"/>
            <xsl:variable name="this-group" as="document-node()+">
                <xsl:for-each select="current-group()">
                    <xsl:sort select="*/@sort-key"/>
                    <xsl:sequence select="."/>
                </xsl:for-each>
            </xsl:variable>
            
            <xsl:variable name="these-texts"
                select="
                    for $i in $this-group
                    return
                        tan:text-join($i/*/tan:body)"
            />
            <xsl:variable name="these-texts-normalized"
                select="
                    if (count($batch-replacements) gt 0) then
                        (for $i in $these-texts
                        return
                            tan:batch-replace($i, $batch-replacements))
                    else
                        $these-texts"
            />

            <xsl:variable name="texts-to-compare" as="xs:string*" select="$these-texts-normalized"/>
            
            <xsl:variable name="these-labels"
                select="
                    for $i in $this-group
                    return
                        ($i/*/@label, '')[1]"
            />
            <xsl:variable name="these-duplicate-labels" select="tan:duplicate-values($these-labels)"/>
            <xsl:variable name="these-labels-revised" as="xs:string*">
                <xsl:for-each select="$these-labels">
                    <xsl:variable name="this-pos" select="position()"/>
                    <xsl:choose>
                        <xsl:when test=". = ('', $these-duplicate-labels)">
                            <xsl:value-of select="string-join((., string($this-pos)), ' ')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="."/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
            </xsl:variable>


            <!-- global variable's messaging, output -->
            <xsl:for-each select="$texts-to-compare">
                <xsl:variable name="this-pos" select="position()"/>
                <xsl:choose>
                    <xsl:when test="string-length(.) lt 1">
                        <xsl:message
                            select="$this-group[$this-pos]/*/@xml:base || ' is a zero-length string.'"
                        />
                    </xsl:when>
                    <xsl:when test="not(matches(., '\w'))">
                        <xsl:message
                            select="$this-group[$this-pos]/*/@xml:base || ' has no letters.'"
                        />
                    </xsl:when>
                </xsl:choose>
            </xsl:for-each>

            <xsl:choose>
                <!-- Ignore groups beyond the threshold -->
                <xsl:when test="count($this-group) lt 2">
                    <xsl:message
                        select="'Ignoring ' || $this-group/*/@xml:base || ' because it has no pair.'"
                    />
                </xsl:when>
                <xsl:when
                    test="
                        some $i in $texts-to-compare
                            satisfies ($i = ('', ()))">
                    <xsl:message
                        select="'Ignoring entire set of texts because at least one of them, after normalization, results in a zero-length string. Check: ' || string-join($this-group/*/@xml:base, ' ')"
                    />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:document>
                        <group cgk="{current-grouping-key()}" count="{count($this-group)}"
                            _target-format="xml-indent"
                            _target-uri="{$target-output-directory-resolved || 'diff-' || current-grouping-key() || '-' || $today-iso || '.xml'}">
                            <xsl:for-each select="$this-group">
                                <xsl:variable name="this-pos" select="position()"/>
                                <xsl:variable name="this-text"
                                    select="$these-texts-normalized[$this-pos]"/>
                                <xsl:variable name="this-id-ref"
                                    select="$these-labels-revised[$this-pos]"/>
                                <file length="{string-length($this-text)}" uri="{*/@xml:base}"
                                    ref="{$this-id-ref}"/>
                            </xsl:for-each>

                            <xsl:choose>
                                <xsl:when test="count($texts-to-compare) eq 2">
                                    <xsl:copy-of
                                        select="tan:adjust-diff(tan:diff($texts-to-compare[1], $texts-to-compare[2], false()))"
                                    />
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:copy-of
                                        select="tan:collate($texts-to-compare, $these-labels-revised, $preoptimize-string-order)"
                                    />
                                </xsl:otherwise>
                            </xsl:choose>
                        </group>
                    </xsl:document>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:variable>
    
    <!-- Next, build a statistical profile -->
    <xsl:variable name="file-groups-with-stats" as="document-node()*">
        <xsl:apply-templates select="$file-groups-diffed-and-collated" mode="add-diff-stats"/>
    </xsl:variable>
    
    <xsl:template match="tan:group[tan:diff]" mode="add-diff-stats">
        <xsl:variable name="these-as" select="tan:diff/tan:a"/>
        <xsl:variable name="these-bs" select="tan:diff/tan:b"/>
        <xsl:variable name="these-a-lengths"
            select="
                for $i in $these-as
                return
                    string-length($i)"/>
        <xsl:variable name="these-b-lengths"
            select="
                for $i in $these-bs
                return
                    string-length($i)"/>
        <xsl:variable name="these-character-alias-exceptions" as="element()*">
            <xsl:for-each-group select="tan:diff/*" group-ending-with="tan:common">
                <xsl:variable name="this-a" select="current-group()/self::tan:a"/>
                <xsl:variable name="this-b" select="current-group()/self::tan:b"/>
                <xsl:variable name="this-char-alias"
                    select="$unimportant-change-character-aliases[tan:c = $this-a][tan:c = $this-b]"/>
                <xsl:copy-of select="$this-char-alias[1]"/>
            </xsl:for-each-group>
        </xsl:variable>
        <xsl:variable name="this-exception-length" select="count($these-character-alias-exceptions)"/>
        <xsl:variable name="this-full-length" select="string-length(tan:diff)"/>
        <xsl:variable name="this-a-length" select="sum($these-a-lengths) - $this-exception-length"/>
        <xsl:variable name="this-b-length" select="sum($these-b-lengths) - $this-exception-length"/>
        <xsl:variable name="orig-a-length" select="xs:integer(tan:file[1]/@length)"/>
        <xsl:variable name="orig-b-length" select="xs:integer(tan:file[2]/@length)"/>
        <xsl:variable name="this-a-portion" select="$this-a-length div $orig-a-length"/>
        <xsl:variable name="this-b-portion" select="$this-b-length div $orig-b-length"/>
        <xsl:document>
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <!--<xsl:apply-templates select="node() except tan:diff" mode="#current"/>-->
                <stats>
                    <witness id="a" class="e-a">
                        <uri>
                            <xsl:value-of select="tan:file[1]/@uri"/>
                        </uri>
                        <length>
                            <xsl:value-of select="tan:file[2]/@length"/>
                        </length>
                        <diff-count>
                            <xsl:value-of select="count($these-as) - $this-exception-length"/>
                        </diff-count>
                        <diff-length>
                            <xsl:value-of select="$this-a-length"/>
                        </diff-length>
                        <diff-portion>
                            <xsl:value-of select="format-number($this-a-portion, '0.0%')"/>
                        </diff-portion>
                    </witness>
                    <witness id="b" class="e-b">
                        <uri>
                            <xsl:value-of select="tan:file[2]/@uri"/>
                        </uri>
                        <length>
                            <xsl:value-of select="tan:file[2]/@length"/>
                        </length>
                        <diff-count>
                            <xsl:value-of select="count($these-bs) - $this-exception-length"/>
                        </diff-count>
                        <diff-length>
                            <xsl:value-of select="$this-b-length"/>
                        </diff-length>
                        <diff-portion>
                            <xsl:value-of select="format-number($this-b-portion, '0.0%')"/>
                        </diff-portion>
                    </witness>
                    <diff id="diff" class="a-diff">
                        <uri>
                            <xsl:value-of select="@_target-uri"/>
                        </uri>
                        <length>
                            <xsl:value-of select="$this-full-length"/>
                        </length>
                        <diff-count>
                            <xsl:value-of
                                select="count($these-as) + count($these-bs) - $this-exception-length"
                            />
                        </diff-count>
                        <diff-length>
                            <xsl:value-of select="$this-a-length + $this-b-length"/>
                        </diff-length>
                        <diff-portion>
                            <xsl:value-of
                                select="format-number($this-a-portion + $this-b-portion, '0.0%')"/>
                        </diff-portion>
                    </diff>
                    <xsl:if test="$this-exception-length gt 0">
                        <note>
                            <xsl:text>The statistics above exclude differences of </xsl:text>
                            <xsl:value-of
                                select="
                                    string-join(for $i in tan:distinct-items($these-character-alias-exceptions)
                                    return
                                        string-join($i/tan:c, ' and '), '; ')"/>
                            <xsl:text>.</xsl:text>
                        </note>
                    </xsl:if>
                </stats>
                <xsl:apply-templates select="tan:diff" mode="#current"/>
            </xsl:copy>
        </xsl:document>
    </xsl:template>
    
    <xsl:template match="tan:diff" mode="add-diff-stats">
        <xsl:copy-of select="tan:analyze-leaf-div-string-length(.)"/>
    </xsl:template>
    
    <xsl:template match="tan:group[tan:collation]" mode="add-diff-stats">
        <xsl:variable name="this-group" select="."/>
        <xsl:variable name="all-us" select="tan:collation/tan:u"/>
        <xsl:variable name="all-u-groups" as="element()">
            <u-groups>
                <!--  group-by="tokenize(@w, ' ')" -->
                <xsl:for-each-group select="$all-us" group-by="tan:wit/@ref">
                    <xsl:sort
                        select="
                            if (current-grouping-key() castable as xs:integer) then
                                xs:integer(current-grouping-key())
                            else
                                0"/>
                    <xsl:sort select="current-grouping-key()"/>
                    <group n="{current-grouping-key()}">
                        <xsl:copy-of select="current-group()"/>
                    </group>
                </xsl:for-each-group>
            </u-groups>
        </xsl:variable>
        <xsl:variable name="this-target-uri" select="@_target-uri"/>
        <!--<xsl:variable name="this-full-length" select="string-length(string-join(tan:collation/(* except tan:witness)))"/>-->
        <xsl:variable name="this-full-length"
            select="string-length(string-join(tan:collation/*/tan:txt))"/>

        <xsl:variable name="us-excepted-by-character-alias-exceptions" as="element()*">
            <xsl:for-each-group select="tan:collation/tan:u"
                group-adjacent="
                    for $i in tan:txt
                    return
                        ($unimportant-change-character-aliases[tan:c = $i]/@n, '')[1]">
                <xsl:variable name="these-us" select="current-group()"/>

                <xsl:variable name="is-for-every-ref"
                    select="
                        every $i in $this-group/tan:file/@ref
                            satisfies exists($these-us/tan:wit[@ref = $i])"/>

                <xsl:if test="(string-length(current-grouping-key()) gt 0) and $is-for-every-ref">
                    <xsl:sequence select="current-group()"/>
                </xsl:if>
            </xsl:for-each-group>
        </xsl:variable>
        <xsl:variable name="this-exception-length"
            select="count($us-excepted-by-character-alias-exceptions)"/>

        <xsl:variable name="this-common-length"
            select="string-length(string-join(tan:collation/tan:c/tan:txt))"/>

        <xsl:variable name="this-collation-diff-length"
            select="string-length(string-join($all-us/tan:txt))"/>
        <xsl:variable name="these-files" select="tan:file"/>
        <xsl:variable name="this-file-count" select="count($these-files)"/>
        <xsl:variable name="these-witnesses" select="tan:collation/tan:witness"/>
        <xsl:variable name="basic-stats" as="element()">
            <stats>
                <xsl:for-each select="$these-files">
                    <xsl:variable name="this-pos" select="position()"/>
                    <xsl:variable name="this-label"
                        select="string(($these-witnesses[$this-pos]/@id, $this-pos)[1])"/>
                    <xsl:variable name="this-diff-group" select="$all-u-groups/tan:group[$this-pos]"/>
                    <xsl:variable name="these-diffs" select="$this-diff-group/tan:u"/>
                    <xsl:variable name="these-diff-exceptions"
                        select="$us-excepted-by-character-alias-exceptions[tan:wit/@ref = $this-label]"/>
                    <xsl:variable name="this-exception-length"
                        select="count($these-diff-exceptions)"/>
                    <xsl:variable name="this-diff-length"
                        select="string-length(string-join($these-diffs)) - $this-exception-length"/>
                    <xsl:variable name="this-diff-portion"
                        select="$this-diff-length div ($this-common-length + $this-diff-length + $this-exception-length)"/>
                    <witness class="{'a-w-' || @ref}">
                        <xsl:copy-of select="@ref"/>
                        <uri>
                            <xsl:value-of select="@uri"/>
                        </uri>
                        <length>
                            <xsl:value-of select="@length"/>
                        </length>
                        <diff-count>
                            <xsl:value-of
                                select="count($these-diffs[tan:txt]) - count($these-diff-exceptions)"
                            />
                        </diff-count>
                        <diff-length>
                            <xsl:value-of select="$this-diff-length"/>
                        </diff-length>
                        <diff-portion>
                            <xsl:value-of select="format-number($this-diff-portion, '0.0%')"/>
                        </diff-portion>
                    </witness>
                </xsl:for-each>
            </stats>
        </xsl:variable>

        <!-- 3-way venns, to calculate distance of any version between any two others -->
        <xsl:variable name="three-way-venns" as="element()">
            <venns>
                <xsl:if test="$this-file-count ge 3">
                    <xsl:for-each select="1 to ($this-file-count - 2)">
                        <xsl:variable name="this-a-pos" select="."/>
                        <xsl:variable name="this-a-label"
                            select="$this-group/tan:file[$this-a-pos]/@ref"/>
                        <xsl:for-each select="($this-a-pos + 1) to ($this-file-count - 1)">
                            <xsl:variable name="this-b-pos" select="."/>
                            <xsl:variable name="this-b-label"
                                select="$this-group/tan:file[$this-b-pos]/@ref"/>
                            <xsl:for-each select="($this-b-pos + 1) to $this-file-count">
                                <xsl:variable name="this-c-pos" select="."/>
                                <xsl:variable name="this-c-label"
                                    select="$this-group/tan:file[$this-c-pos]/@ref"/>
                                <xsl:variable name="all-relevant-nodes"
                                    select="$this-group/tan:collation/*[tan:wit[@ref = ($this-a-label, $this-b-label, $this-c-label)]]"/>

                                <xsl:variable name="these-excepted-us" as="element()*">
                                    <xsl:for-each-group select="$all-relevant-nodes/self::tan:u"
                                        group-adjacent="
                                            for $i in tan:txt
                                            return
                                                ($unimportant-change-character-aliases[c = $i]/@n, '')[1]">
                                        <xsl:variable name="is-for-every-ref"
                                            select="
                                                (current-group()/tan:wit/@ref = $this-a-label) and (current-group()/tan:wit/@ref = $this-b-label)
                                                and (current-group()/tan:wit/@ref = $this-c-label)"/>
                                        <xsl:if
                                            test="(string-length(current-grouping-key()) gt 0) and $is-for-every-ref">
                                            <xsl:sequence select="current-group()"/>
                                        </xsl:if>
                                    </xsl:for-each-group>
                                </xsl:variable>
                                <xsl:variable name="this-exception-length"
                                    select="count($these-excepted-us)"/>

                                <xsl:variable name="this-full-length"
                                    select="string-length(string-join($all-relevant-nodes))"/>
                                <xsl:variable name="these-a-nodes"
                                    select="$all-relevant-nodes[tan:wit/@ref = $this-a-label]"/>
                                <xsl:variable name="these-b-nodes"
                                    select="$all-relevant-nodes[tan:wit/@ref = $this-b-label]"/>
                                <xsl:variable name="these-c-nodes"
                                    select="$all-relevant-nodes[tan:wit/@ref = $this-c-label]"/>
                                <!-- The seven parts of a 3-way venn diagram -->
                                <xsl:variable name="these-a-only-nodes"
                                    select="$these-a-nodes except ($these-b-nodes, $these-c-nodes, $these-excepted-us)"/>
                                <xsl:variable name="these-b-only-nodes"
                                    select="$these-b-nodes except ($these-a-nodes, $these-c-nodes, $these-excepted-us)"/>
                                <xsl:variable name="these-c-only-nodes"
                                    select="$these-c-nodes except ($these-a-nodes, $these-b-nodes, $these-excepted-us)"/>
                                <xsl:variable name="these-a-b-only-nodes"
                                    select="($these-a-nodes intersect $these-b-nodes) except ($these-c-nodes, $these-excepted-us)"/>
                                <xsl:variable name="these-a-c-only-nodes"
                                    select="($these-a-nodes intersect $these-c-nodes) except ($these-b-nodes, $these-excepted-us)"/>
                                <xsl:variable name="these-b-c-only-nodes"
                                    select="($these-b-nodes intersect $these-c-nodes) except ($these-a-nodes, $these-excepted-us)"/>
                                <xsl:variable name="these-a-b-and-c-nodes"
                                    select="$all-relevant-nodes[tan:wit/@ref = $this-a-label][tan:wit/@ref = $this-b-label][tan:wit/@ref = $this-c-label], $these-excepted-us"/>
                                <xsl:variable name="length-a-only"
                                    select="string-length(string-join($these-a-only-nodes))"/>
                                <xsl:variable name="length-b-only"
                                    select="string-length(string-join($these-b-only-nodes))"/>
                                <xsl:variable name="length-c-only"
                                    select="string-length(string-join($these-c-only-nodes))"/>
                                <xsl:variable name="length-a-b-only"
                                    select="string-length(string-join($these-a-b-only-nodes))"/>
                                <xsl:variable name="length-a-c-only"
                                    select="string-length(string-join($these-a-c-only-nodes))"/>
                                <xsl:variable name="length-b-c-only"
                                    select="string-length(string-join($these-b-c-only-nodes))"/>
                                <xsl:variable name="length-a-b-and-c"
                                    select="string-length(string-join($these-a-b-and-c-nodes))"/>
                                <venn>
                                    <a>
                                        <xsl:value-of select="$this-a-label"/>
                                    </a>
                                    <b>
                                        <xsl:value-of select="$this-b-label"/>
                                    </b>
                                    <c>
                                        <xsl:value-of select="$this-c-label"/>
                                    </c>
                                    <node-count>
                                        <xsl:value-of select="count($all-relevant-nodes)"/>
                                    </node-count>
                                    <length>
                                        <xsl:value-of select="$this-full-length"/>
                                    </length>
                                    <part>
                                        <a/>
                                        <node-count>
                                            <xsl:value-of select="count($these-a-only-nodes)"/>
                                        </node-count>
                                        <length>
                                            <xsl:value-of select="$length-a-only"/>
                                        </length>
                                        <portion>
                                            <xsl:value-of
                                                select="$length-a-only div $this-full-length"/>
                                        </portion>
                                    </part>
                                    <part>
                                        <b/>
                                        <node-count>
                                            <xsl:value-of select="count($these-b-only-nodes)"/>
                                        </node-count>
                                        <length>
                                            <xsl:value-of select="$length-b-only"/>
                                        </length>
                                        <portion>
                                            <xsl:value-of
                                                select="$length-b-only div $this-full-length"/>
                                        </portion>
                                        <texts>
                                            <xsl:for-each select="$these-b-only-nodes">
                                                <xsl:copy>
                                                  <xsl:copy-of select="tan:txt"/>
                                                  <xsl:copy-of
                                                  select="tan:wit[@ref = $this-b-label]"/>
                                                </xsl:copy>
                                            </xsl:for-each>
                                        </texts>
                                    </part>
                                    <part>
                                        <c/>
                                        <node-count>
                                            <xsl:value-of select="count($these-c-only-nodes)"/>
                                        </node-count>
                                        <length>
                                            <xsl:value-of select="$length-c-only"/>
                                        </length>
                                        <portion>
                                            <xsl:value-of
                                                select="$length-c-only div $this-full-length"/>
                                        </portion>
                                    </part>
                                    <part>
                                        <a/>
                                        <b/>
                                        <node-count>
                                            <xsl:value-of select="count($these-a-b-only-nodes)"/>
                                        </node-count>
                                        <length>
                                            <xsl:value-of select="$length-a-b-only"/>
                                        </length>
                                        <portion>
                                            <xsl:value-of
                                                select="$length-a-b-only div $this-full-length"/>
                                        </portion>
                                    </part>
                                    <part>
                                        <a/>
                                        <c/>
                                        <node-count>
                                            <xsl:value-of select="count($these-a-c-only-nodes)"/>
                                        </node-count>
                                        <length>
                                            <xsl:value-of select="$length-a-c-only"/>
                                        </length>
                                        <portion>
                                            <xsl:value-of
                                                select="$length-a-c-only div $this-full-length"/>
                                        </portion>
                                        <texts>
                                            <xsl:for-each select="$these-a-c-only-nodes">
                                                <xsl:copy>
                                                  <xsl:copy-of select="tan:txt"/>
                                                  <xsl:copy-of
                                                  select="tan:wit[@ref = $this-a-label]"/>
                                                  <xsl:copy-of
                                                  select="tan:wit[@ref = $this-c-label]"/>
                                                </xsl:copy>
                                            </xsl:for-each>
                                        </texts>
                                    </part>
                                    <part>
                                        <b/>
                                        <c/>
                                        <node-count>
                                            <xsl:value-of select="count($these-b-c-only-nodes)"/>
                                        </node-count>
                                        <length>
                                            <xsl:value-of select="$length-b-c-only"/>
                                        </length>
                                        <portion>
                                            <xsl:value-of
                                                select="$length-b-c-only div $this-full-length"/>
                                        </portion>
                                    </part>
                                    <part>
                                        <a/>
                                        <b/>
                                        <c/>
                                        <node-count>
                                            <xsl:value-of select="count($these-a-b-and-c-nodes)"/>
                                        </node-count>
                                        <length>
                                            <xsl:value-of select="$length-a-b-and-c"/>
                                        </length>
                                        <portion>
                                            <xsl:value-of
                                                select="$length-a-b-and-c div $this-full-length"/>
                                        </portion>
                                    </part>
                                    <xsl:if test="$this-exception-length gt 0">
                                        <note>
                                            <xsl:text>The statistics above exclude differences consisting exclusively of </xsl:text>
                                            <xsl:value-of
                                                select="
                                                    string-join(for $i in tan:distinct-items($unimportant-change-character-aliases)
                                                    return
                                                        string-join($i/c, ' versus '), '; ')"/>
                                            <xsl:text>.</xsl:text>
                                        </note>
                                    </xsl:if>
                                </venn>
                            </xsl:for-each>
                        </xsl:for-each>
                    </xsl:for-each>
                </xsl:if>
            </venns>
        </xsl:variable>

        <xsl:document>
            <xsl:copy>
                <xsl:copy-of select="@*"/>
                <stats>
                    <xsl:copy-of select="$basic-stats/*"/>
                    <collation id="collation" class="a-collation">
                        <uri>
                            <xsl:value-of select="$this-target-uri"/>
                        </uri>
                        <length>
                            <xsl:value-of select="$this-full-length"/>
                        </length>
                        <diff-count>
                            <xsl:value-of select="count($all-us[tan:txt])"/>
                        </diff-count>
                        <diff-length>
                            <xsl:value-of select="$this-collation-diff-length"/>
                        </diff-length>
                        <diff-portion>
                            <xsl:value-of
                                select="format-number(($this-collation-diff-length div $this-full-length), '0.0%')"
                            />
                        </diff-portion>
                    </collation>
                    <xsl:if test="$this-exception-length gt 0">
                        <note>
                            <xsl:text>The statistics above exclude differences consisting exclusively of </xsl:text>
                            <xsl:value-of
                                select="
                                    string-join(for $i in tan:distinct-items($unimportant-change-character-aliases)
                                    return
                                        string-join($i/c, ' versus '), '; ')"/>
                            <xsl:text>.</xsl:text>
                        </note>
                    </xsl:if>
                    <xsl:copy-of select="$three-way-venns"/>
                </stats>
                <xsl:apply-templates select="tan:collation" mode="#current"/>
            </xsl:copy>
        </xsl:document>
    </xsl:template>
    
    <!-- Infusion of diff / collation in first expanded TAN-T file -->
    
    <xsl:variable name="output-containers-prepped" as="document-node()*">
        <xsl:apply-templates select="$file-groups-with-stats"
            mode="infuse-class-1-with-diff-or-collation"/>
    </xsl:variable>
    
    <xsl:template match="tan:group/tan:diff" mode="infuse-class-1-with-diff-or-collation">
        <xsl:variable name="first-class-1-base-uri" select="../tan:stats/tan:witness[1]/tan:uri"/>
        <xsl:variable name="first-class-1-doc" select="$main-input-files-expanded[*/@xml:base = $first-class-1-base-uri]"/>
        <xsl:variable name="first-class-1-doc-analyzed" select="tan:analyze-leaf-div-string-length($first-class-1-doc)"/>
        <xsl:variable name="split-collation-where" select="key('elements-with-attrs-named', 'string-pos', $first-class-1-doc-analyzed/*/tan:body)"/>
        <xsl:variable name="split-count" select="count($split-collation-where)"/>
        <xsl:variable name="this-diff" select="."/>
        <xsl:variable name="diff-split" as="element()">
            <diff>
                <xsl:iterate select="$split-collation-where">
                    <xsl:param name="diff-so-far" as="element()" select="$this-diff"/>
                    <xsl:variable name="this-string-last-pos" select="xs:integer(@string-pos) + xs:integer(@string-length) - 1"/>
                    <xsl:variable name="first-diff-element-not-of-interest" select="$diff-so-far/(tan:a | tan:common)[xs:integer(@string-pos) gt $this-string-last-pos][1]"/>
                    <xsl:variable name="diff-elements-not-of-interest" select="$first-diff-element-not-of-interest | $first-diff-element-not-of-interest/following-sibling::*"/>
                    <xsl:variable name="diff-elements-of-interest" select="$diff-so-far/(* except $diff-elements-not-of-interest)"/>
                    <xsl:variable name="last-diff-element-of-interest-with-this-witness" select="$diff-elements-of-interest[self::tan:a or self::tan:common][last()]"/>
                    <xsl:variable name="last-deoiwtw-pos" select="xs:integer($last-diff-element-of-interest-with-this-witness/@string-pos)"/>
                    <xsl:variable name="last-deoiwtw-length" select="xs:integer($last-diff-element-of-interest-with-this-witness/@string-length)"/>
                    <xsl:variable name="amount-needed" select="$this-string-last-pos - $last-deoiwtw-pos + 1"/>
                    <xsl:variable name="fragment-to-keep" as="element()?">
                        <xsl:if test="exists($last-diff-element-of-interest-with-this-witness)">
                            <xsl:element
                                name="{name($last-diff-element-of-interest-with-this-witness)}">
                                <!--<xsl:attribute name="string-length" select="$amount-needed"/>-->
                                <!--<xsl:copy-of
                                    select="$last-diff-element-of-interest-with-this-witness/@string-pos"/>-->
                                <xsl:value-of
                                    select="substring($last-diff-element-of-interest-with-this-witness, 1, $amount-needed)"
                                />
                            </xsl:element>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="fragment-to-push-to-next-iteration" as="element()?">
                        <xsl:if test="($last-deoiwtw-length gt $amount-needed) and exists($last-diff-element-of-interest-with-this-witness)">
                            <xsl:element
                                name="{name($last-diff-element-of-interest-with-this-witness)}">
                                <xsl:attribute name="string-length"
                                    select="$last-deoiwtw-length - $amount-needed"/>
                                <xsl:attribute name="string-pos"
                                    select="$last-deoiwtw-pos + $amount-needed"/>

                                <xsl:value-of
                                    select="substring($last-diff-element-of-interest-with-this-witness, $amount-needed + 1)"/>
                            </xsl:element>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="next-diff" as="element()">
                        <diff>
                            <xsl:copy-of select="$fragment-to-push-to-next-iteration"/>
                            <xsl:copy-of select="$diff-elements-not-of-interest"/>
                        </diff>
                    </xsl:variable>
                    
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:copy-of select="node() except (text() | tei:*)"/>
                        <xsl:if test="not(exists($last-diff-element-of-interest-with-this-witness))">
                            <xsl:for-each select="$diff-elements-of-interest">
                                <xsl:copy>
                                    <xsl:value-of select="."/>
                                </xsl:copy>
                            </xsl:for-each>
                        </xsl:if>
                        <xsl:for-each select="$last-diff-element-of-interest-with-this-witness/preceding-sibling::*, $fragment-to-keep, 
                            $last-diff-element-of-interest-with-this-witness/(following-sibling::* except $diff-elements-not-of-interest)">
                            <xsl:copy>
                                <xsl:value-of select="."/>
                            </xsl:copy>
                        </xsl:for-each>
                    </xsl:copy>
                    
                    <xsl:next-iteration>
                        <xsl:with-param name="diff-so-far" select="$next-diff"/>
                    </xsl:next-iteration>
                    
                </xsl:iterate>
            </diff>
        </xsl:variable>
        
        <xsl:copy-of select="$diff-split"/>
        
    </xsl:template>
    
    <xsl:template match="tan:group/tan:collation" mode="infuse-class-1-with-diff-or-collation">
        <xsl:variable name="first-class-1-base-uri" select="../tan:stats/tan:witness[1]/tan:uri"/>
        <xsl:variable name="first-class-1-idref" select="../tan:stats/tan:witness[1]/@ref"/>
        <xsl:variable name="first-class-1-doc" select="$main-input-files-expanded[*/@xml:base = $first-class-1-base-uri]"/>
        <xsl:variable name="first-class-1-doc-analyzed" select="tan:analyze-leaf-div-string-length($first-class-1-doc)"/>
        <xsl:variable name="split-collation-where" select="key('elements-with-attrs-named', 'string-pos', $first-class-1-doc-analyzed/*/tan:body)"/>
        <xsl:variable name="split-count" select="count($split-collation-where)"/>
        <xsl:variable name="this-collation" select="."/>
        <xsl:variable name="collation-split" as="element()">
            <collation>
                <xsl:copy-of select="$this-collation/tan:witness"/>
                <xsl:iterate select="$split-collation-where">
                    <xsl:param name="collation-so-far" as="element()" select="$this-collation"/>
                    <xsl:variable name="this-string-last-pos" select="xs:integer(@string-pos) + xs:integer(@string-length) - 1"/>
                    <xsl:variable name="first-collation-element-not-of-interest" select="$collation-so-far/*[tan:wit[@ref = $first-class-1-idref][xs:integer(@pos) gt $this-string-last-pos]][1]"/>
                    <xsl:variable name="collation-elements-not-of-interest" select="$first-collation-element-not-of-interest | $first-collation-element-not-of-interest/following-sibling::*"/>
                    <xsl:variable name="collation-elements-of-interest" select="$collation-so-far/(* except $collation-elements-not-of-interest)"/>
                    <xsl:variable name="last-collation-element-of-interest-with-this-witness" select="$collation-elements-of-interest[tan:wit[@ref = $first-class-1-idref]][last()]"/>
                    <xsl:variable name="last-ceoiwtw-pos" select="xs:integer($last-collation-element-of-interest-with-this-witness/tan:wit[@ref = $first-class-1-idref]/@pos)"/>
                    <xsl:variable name="last-ceoiwtw-length" select="string-length($last-collation-element-of-interest-with-this-witness/tan:txt)"/>
                    <xsl:variable name="amount-needed" select="$this-string-last-pos - $last-ceoiwtw-pos + 1"/>
                    <xsl:variable name="fragment-to-keep" as="element()?">
                        <xsl:element name="{name($last-collation-element-of-interest-with-this-witness)}">
                            <txt>
                                <xsl:value-of select="substring($last-collation-element-of-interest-with-this-witness, 1, $amount-needed)"/>
                            </txt>
                            <xsl:copy-of select="$last-collation-element-of-interest-with-this-witness/tan:wit"/>
                        </xsl:element>
                    </xsl:variable>
                    <xsl:variable name="fragment-to-push-to-next-iteration" as="element()?">
                        <xsl:if test="$last-ceoiwtw-length gt $amount-needed">
                            <xsl:element name="{name($last-collation-element-of-interest-with-this-witness)}">
                                <txt>
                                    <xsl:value-of select="substring($last-collation-element-of-interest-with-this-witness, $amount-needed + 1)"/>
                                </txt>
                                <xsl:for-each select="$last-collation-element-of-interest-with-this-witness/tan:wit">
                                    <xsl:copy>
                                        <xsl:copy-of select="@ref"/>
                                        <xsl:attribute name="pos"
                                            select="xs:integer(@pos) + $amount-needed"/>
                                    </xsl:copy>
                                </xsl:for-each>
                            </xsl:element>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="next-collation" as="element()">
                        <collation>
                            <xsl:copy-of select="$fragment-to-push-to-next-iteration"/>
                            <xsl:copy-of select="$collation-elements-not-of-interest"/>
                        </collation>
                    </xsl:variable>
                    
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:copy-of select="node() except (text() | tei:*)"/>
                        <xsl:copy-of select="$last-collation-element-of-interest-with-this-witness/preceding-sibling::*[not(self::tan:witness)]"/>
                        <xsl:copy-of select="$fragment-to-keep"/>
                        <xsl:copy-of select="$last-collation-element-of-interest-with-this-witness/(following-sibling::* except $collation-elements-not-of-interest)"/>
                    </xsl:copy>
                    
                    <xsl:next-iteration>
                        <xsl:with-param name="collation-so-far" select="$next-collation"/>
                    </xsl:next-iteration>
                    
                </xsl:iterate>
            </collation>
        </xsl:variable>
        
        <xsl:copy-of select="$collation-split"/>
        
    </xsl:template>
    
    
    
    <!-- HTML OUTPUT -->
    
    <xsl:variable name="output-as-html" as="document-node()*">
        <xsl:apply-templates select="$output-containers-prepped" mode="diff-to-html"/>
    </xsl:variable>
    
    <xsl:template match="/*" mode="diff-to-html">
        <xsl:variable name="this-title" as="xs:string*">
            <xsl:text>Comparison of </xsl:text>
            <xsl:value-of
                select="string(count(tan:stats/tan:witness)) || ' files, rendered from ' || (tan:stats/*/tan:uri)[last()]"
            />
        </xsl:variable>
        <xsl:variable name="this-target-uri" select="replace(@_target-uri, '\w+$', 'html')"/>
        <html xmlns="http://www.w3.org/1999/xhtml">
            <xsl:attribute name="_target-format">xhtml-noindent</xsl:attribute>
            <xsl:attribute name="_target-uri" select="$this-target-uri"/>
            <head>
                <title>
                    <xsl:value-of select="$this-title"/>
                </title>
                <!-- TAN css attend to some basic style issues common to TAN converted to HTML. -->
                <link rel="stylesheet"
                    href="{tan:uri-relative-to($resolved-uri-to-css, $this-target-uri)}"
                    type="text/css">
                    <xsl:comment/>
                </link>
                <!-- The TAN JavaScript code uses jQuery. -->
                <script src="{tan:uri-relative-to($resolved-uri-to-jquery, $this-target-uri)}"><!--  --></script>
                <!-- The d3js library is required for use of the Venn JavaScript library -->
                <script src="https://d3js.org/d3.v5.min.js"><!--  --></script>
                <!-- The Venn JavaScript library: https://github.com/benfred/venn.js/ -->
                <script src="{$resolved-uri-to-venn-js}"><!--  --></script>
            </head>
            <body>
                <h1>
                    <xsl:value-of select="$this-title"/>
                </h1>
                <div class="timedate">
                    <xsl:value-of
                        select="'Comparison generated ' || format-dateTime(current-dateTime(), '[MNn] [D], [Y], [h]:[m01] [PN]')"
                    />
                </div>
                <xsl:apply-templates select="*" mode="#current">
                    <xsl:with-param name="last-wit-idref" select="tan:stats/tan:witness[last()]/@ref"
                        tunnel="yes"/>
                </xsl:apply-templates>
                <!-- TAN JavaScript comes at the end, to ensure the DOM is loaded. The file supports manipulation of the sources and their appearance. -->
                <script src="{tan:uri-relative-to($resolved-uri-to-js, $this-target-uri)}"><!--  --></script>
            </body>
        </html>
    </xsl:template>
    
    <xsl:template match="*" mode="diff-to-html">
        <xsl:param name="last-wit-idref" tunnel="yes"/>
        <xsl:variable name="these-ws" select="tan:wit/@ref"/>
        <xsl:variable name="this-w-count" select="ancestor::tan:group/@count"/>
        <xsl:variable name="these-w-class-vals"
            select="
                string-join(for $i in $these-ws
                return
                    ' a-w-' || $i)"
        />
        <!-- For tan:collate() 2.0 results, which supplies @base for a likely base version -->
        <xsl:variable name="this-base-class-val"
            select="
                if (exists(@base)) then
                    ' a-base'
                else
                    ()"
        />
        <xsl:variable name="this-special-class-val"
            select="
                if (($these-ws = $last-wit-idref) or self::tan:b) then
                    ' a-last a-other'
                else
                    ()"
        />
        <xsl:element name="div" namespace="http://www.w3.org/1999/xhtml">
            <xsl:attribute name="class" select="'e-' || name(.) || $these-w-class-vals || $this-base-class-val || $this-special-class-val"/>
            
            <xsl:choose>
                <xsl:when test="exists(tan:wit)">
                    <!-- Based on results of tan:collate() 3.0 -->
                    <div class="wits" xmlns="http://www.w3.org/1999/xhtml">
                        <xsl:value-of select="string-join(tan:wit/@ref, ' ')"/>
                    </div>
                    <xsl:apply-templates select="@* | node()" mode="#current"/>
                </xsl:when>
                <xsl:when test="exists(@w)">
                    <!-- Based on results of tan:collate() 2.0 -->
                    <div class="wits" xmlns="http://www.w3.org/1999/xhtml">
                        <xsl:value-of select="@w"/>
                    </div>
                    <div class="text" xmlns="http://www.w3.org/1999/xhtml">
                        <xsl:apply-templates select="@* | node()" mode="#current"/>
                    </div>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:apply-templates select="@* | node()" mode="#current"/>
                </xsl:otherwise>
            </xsl:choose>
           
        </xsl:element>
    </xsl:template>
    
    <!-- We skip <wit> since they've been amalgamated as a new first child of the parent  -->
    <xsl:template match="tan:wit" mode="diff-to-html"/>
    
    <xsl:template match="@*" mode="diff-to-html">
        <xsl:element name="div" namespace="http://www.w3.org/1999/xhtml">
            <xsl:attribute name="class" select="'a-' || name(.)"/>
            <xsl:apply-templates select="string(.)" mode="#current"/>
        </xsl:element>
    </xsl:template>
    <!-- parse the witnesses as individual classes only in the host element -->
    <xsl:template match="@w | @base | @length" mode="diff-to-html"/>
    
    <xsl:template match="text()" mode="diff-to-html">
        <xsl:analyze-string select="." regex="\r?\n">
            <xsl:matching-substring>
                <xsl:text>¶</xsl:text>
                <xsl:element name="br" namespace="http://www.w3.org/1999/xhtml"/>
            </xsl:matching-substring>
            <xsl:non-matching-substring>
                <xsl:analyze-string select="." regex="(file|https?|ftp)://?\S+">
                    <xsl:matching-substring>
                        <!-- Pull back from any characters at the end that aren't part of the URL proper. -->
                        <xsl:analyze-string select="." regex="(&lt;[^&gt;]+&gt;|[&lt;\)\].;])+$">
                            <xsl:matching-substring>
                                <xsl:value-of select="."/>
                            </xsl:matching-substring>
                            <xsl:non-matching-substring>
                                <xsl:variable name="href-norm" select="replace(., '\.$', '')"/>
                                <a href="{$href-norm}" xmlns="http://www.w3.org/1999/xhtml">
                                    <xsl:value-of select="."/>
                                </a>
                            </xsl:non-matching-substring>
                        </xsl:analyze-string>
                    </xsl:matching-substring>
                    <xsl:non-matching-substring>
                        <xsl:value-of select="."/>
                    </xsl:non-matching-substring>
                </xsl:analyze-string>
            </xsl:non-matching-substring>
        </xsl:analyze-string>
    </xsl:template>
    
    <xsl:variable name="resolved-uri-to-css"
        select="($target-output-directory-resolved || 'css/diff.css')"/>
    <xsl:variable name="resolved-uri-to-js"
        select="($target-output-directory-resolved || 'js/diff.js')"/>
    <xsl:variable name="resolved-uri-to-jquery"
        select="($target-output-directory-resolved || 'js/jquery-3.4.1.min.js')"/>
    <xsl:variable name="resolved-uri-to-venn-js"
        select="($target-output-directory-resolved || 'js/venn.js/venn.js')"/>
    
    <!-- HTML TABLE: for basic stats about each version, and selection -->
    <xsl:template match="tan:stats" mode="diff-to-html">
        <table xmlns="http://www.w3.org/1999/xhtml">
            <xsl:attribute name="class" select="'e-' || name(.)"/>
            <thead>
                <tr>
                    <th></th>
                    <th></th>
                    <th></th>
                    <th colspan="3">Differences</th>
                </tr>
                <tr>
                    <th></th>
                    <th>URI</th>
                    <th>Length</th>
                    <th>Number</th>
                    <th>Length</th>
                    <th>Portion</th>
                </tr>
            </thead>
            <tbody>
                <!-- templates on venns/venn are applied after the table built by group/collation -->
                <xsl:apply-templates select="* except (tan:venns, tan:note)" mode="#current"/>
            </tbody>
        </table>
        <xsl:apply-templates select="tan:note" mode="#current"/>
    </xsl:template>
    
    <!-- one row per witness -->
    <xsl:template match="tan:stats/*" mode="diff-to-html">
        <xsl:variable name="is-last-witness" select="(following-sibling::*[1]/(self::tan:collation, self::tan:diff))"/>
        <tr xmlns="http://www.w3.org/1999/xhtml">
            <xsl:copy-of select="@class"/>
            <!-- The name of the witness, and the first column, for selection -->
            <td>
                <div><xsl:value-of select="@ref"/></div>
                <xsl:if test="not(self::tan:collation) and not(self::tan:diff)">
                    <div>
                        <xsl:attribute name="class"
                            select="
                                'last-picker' || (if ($is-last-witness) then
                                    ' a-last'
                                else
                                    ())"/>
                        <div>
                            <xsl:text>Tt</xsl:text>
                        </div>
                    </div>
                    <div>
                        <xsl:attribute name="class"
                            select="
                                'other-picker' || (if ($is-last-witness) then
                                    ' a-other'
                                else
                                    ())"/>
                        <div>
                            <xsl:text>Tt</xsl:text>
                        </div>
                    </div>
                    <div class="switch">
                        <div class="on">☑</div>
                        <div class="off" style="display:none">☐</div>
                    </div>
                </xsl:if>
            </td>
            <xsl:apply-templates mode="#current"/>
        </tr>
    </xsl:template>
    
    <xsl:template match="tan:stats/*/*" mode="diff-to-html">
        <td xmlns="http://www.w3.org/1999/xhtml">
            <xsl:attribute name="class" select="'e-' || name(.)"/>
            <xsl:apply-templates mode="#current"/>
        </td>
    </xsl:template>
    
    <xsl:template match="tan:note" mode="diff-to-html" priority="1">
        <div class="explanation" xmlns="http://www.w3.org/1999/xhtml">
            <xsl:apply-templates mode="#current"/>
        </div>
    </xsl:template>
    
    <xsl:template match="tan:venns" priority="1" mode="diff-to-html">
        <div class="venns" xmlns="http://www.w3.org/1999/xhtml">
            <div class="label">Three-way Venns and Analysis</div>
            <div class="explanation">Versions are presented below in sets of three, with a Venn
                diagram for visualization. Numbers refer to the quantity of characters that diverge
                from common, shared text (that is, shared by all three, regardless of any other
                version).</div>
            <div class="explanation">The diagrams are useful for thinking about how a document was
                revised. The narrative presumes that versions A, B, and C represent consecutive
                editing stages in a document, and an interest in the position of B relative to the
                path from A to C. The diagrams also depict wasted work. Whatever is in B that is in
                neither A nor C represents text that B added that C deleted. Whatever is in A and C
                but not in B represent text deleted by B that was restored by C.</div>
            <div class="explanation">Although ideal for describing an editorial path where A, B, and
                C stand in direct relation to each other, the scenarios can be profitably used to
                study three versions whose relationship is unknown.</div>
            <div class="explanation">Note, some data combinations are impossible to draw accurately
                with a 3-circle Venn diagram (e.g., a 3-circle Venn diagram for items in the set
                {[a, z], [b, z], [c, z]} will always incorrectly show overlap for each pair of
                items).</div>
            <div class="explanation">The colors are fixed according to the A, B, and C components of
                the Venn diagram, not to the version labels, which change color from one Venn
                diagram to the next.</div>
            <xsl:apply-templates mode="#current"/>
        </div>
    </xsl:template>
    
    <xsl:template match="tan:venns/tan:venn" priority="1" mode="diff-to-html">
        <xsl:variable name="letter-sequence" select="('a', 'b', 'c')"/>
        <xsl:variable name="these-keys" select="tan:a | tan:b | tan:c"/>
        <xsl:variable name="this-id" select="'venn-' || string-join((tan:a, tan:b, tan:c), '-')"/>
        <xsl:variable name="common-part" select="tan:part[tan:a][tan:b][tan:c]"/>
        <xsl:variable name="other-parts" select="tan:part except $common-part"/>
        <xsl:variable name="single-parts" select="$other-parts[count((tan:a, tan:b, tan:c)) eq 1]"/>
        <xsl:variable name="double-parts" select="$other-parts[count((tan:a, tan:b, tan:c)) eq 2]"/>
        <xsl:variable name="common-length" select="number($common-part/tan:length)"/>
        <xsl:variable name="all-other-lengths"
            select="
            for $i in $other-parts/tan:length
                return
                    number($i)"
        />
        <xsl:variable name="max-sliver-length" select="max($all-other-lengths)"/>
        <xsl:variable name="reduce-common-section-by"
            select="
                if ($common-length gt $max-sliver-length) then
                    ($common-length - $max-sliver-length)
                else
                    0"
        />
        <xsl:variable name="these-labels" as="element()+">
            <div class="venn-a" xmlns="http://www.w3.org/1999/xhtml">
                <xsl:value-of select="tan:a"/>
            </div>
            <div class="venn-b" xmlns="http://www.w3.org/1999/xhtml">
                <xsl:value-of select="tan:b"/>
            </div>
            <div class="venn-c" xmlns="http://www.w3.org/1999/xhtml">
                <xsl:value-of select="tan:c"/>
            </div>
        </xsl:variable>
        <div class="venn" xmlns="http://www.w3.org/1999/xhtml">
            <div class="label">
                <xsl:copy-of select="$these-labels"/>
            </div>
            <xsl:for-each select="'b'">
                <xsl:variable name="this-letter" select="."/>
                <xsl:variable name="other-letters" select="$letter-sequence[not(. = $this-letter)]"/>
                <xsl:variable name="start-letter" select="$other-letters[1]"/>
                <xsl:variable name="end-letter" select="$other-letters[2]"/>
                <xsl:variable name="this-letter-label" select="$these-keys[name(.) = $this-letter]"/>
                <xsl:variable name="start-letter-label" select="$these-keys[name(.) = $start-letter]"/>
                <xsl:variable name="end-letter-label" select="$these-keys[name(.) = $end-letter]"/>
                <xsl:variable name="this-div-label" select="$these-labels[. = $this-letter-label]"/>
                <xsl:variable name="start-div-label" select="$these-labels[. = $start-letter-label]"/>
                <xsl:variable name="end-div-label" select="$these-labels[. = $end-letter-label]"/>
                
                <xsl:variable name="this-nixed-insertions" select="$single-parts[*[name(.) = $this-letter]]"/>
                <xsl:variable name="this-nixed-deletions" select="$double-parts[not(*[name(.) = $this-letter])]"/>
                <xsl:variable name="start-unique" select="$single-parts[*[name(.) = $start-letter]]"/>
                <xsl:variable name="not-in-end" select="$double-parts[not(*[name(.) = $end-letter])]"/>
                <xsl:variable name="not-in-start" select="$double-parts[not(*[name(.) = $start-letter])]"/>
                <xsl:variable name="end-unique" select="$single-parts[*[name(.) = $end-letter]]"/>
                
                <xsl:variable name="journey-deletions" select="number($start-unique/tan:length) + number($not-in-end/tan:length)"/>
                <xsl:variable name="journey-insertions" select="number($not-in-start/tan:length) + number($end-unique/tan:length)"/>
                <xsl:variable name="journey-distance" select="$journey-deletions + $journey-insertions"/>
                <xsl:variable name="this-traversal" select="number($start-unique/tan:length) + number($not-in-start/tan:length)"/>
                <xsl:variable name="these-mistakes" select="number($this-nixed-insertions/tan:length) + number($this-nixed-deletions/tan:length)"/>
                <xsl:variable name="these-likely-false-mistakes" as="xs:string*">
                    <xsl:analyze-string
                        select="string-join(($this-nixed-insertions/tan:texts/*/tan:txt, $this-nixed-deletions/tan:texts/*/tan:txt))"
                        regex="{string-join(((for $i in $unimportant-change-character-aliases/tan:c return tan:escape($i)), $unimportant-change-regex), '|')}" flags="s">
                        <xsl:matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:matching-substring>
                    </xsl:analyze-string>
                </xsl:variable>
                <xsl:variable name="this-likely-false-mistake-count" select="string-length(string-join($these-likely-false-mistakes))"/>
                
                <xsl:variable name="diagnostics-on" select="false()"/>
                <xsl:if test="$diagnostics-on">
                    <xsl:message select="'Diagnostics on, calculating relative distance of intermediate version between start and end.'"/>
                    <xsl:message select="'Start unique length ' || $start-unique/tan:length"/>
                    <xsl:message select="'Not in end length ' || $not-in-end/tan:length"/>
                    <xsl:message select="'Not in start length ' || $not-in-start/tan:length"/>
                    <xsl:message select="'End unique length ' || $end-unique/tan:length"/>
                    <xsl:message select="'End unique length ' || $end-unique/tan:length"/>
                </xsl:if>
                
                <div>
                    <xsl:text>The distance from </xsl:text>
                    <xsl:copy-of select="$start-div-label"/>
                    <xsl:text> to </xsl:text>
                    <xsl:copy-of select="$end-div-label"/>
                    <xsl:text> is </xsl:text>
                    <xsl:value-of select="string($journey-distance) || ' (' || string($journey-deletions) || ' characters deleted and ' || string($journey-insertions) || ' inserted). Intermediate version '"/>
                    <xsl:copy-of select="$this-div-label"/>
                    <xsl:value-of select="' contributed ' || string($this-traversal) || ' characters to the end result (' || format-number(($this-traversal div $journey-distance), '0.0%') || '). '"/>
                    <xsl:if test="$these-mistakes gt 0">
                        <xsl:value-of select="'But it inserted ' || $this-nixed-insertions/tan:length || ' characters that were deleted by '"/>
                        <xsl:copy-of select="$end-div-label"/>
                        <xsl:value-of select="', and deleted ' || $this-nixed-deletions/tan:length || ' characters that were restored by '"/>
                        <xsl:copy-of select="$end-div-label"/>
                        <xsl:text>. </xsl:text>
                        <xsl:if test="number($this-nixed-insertions/tan:length) gt 0">
                            <xsl:text>Nixed insertions: </xsl:text>
                            <xsl:for-each-group select="$this-nixed-insertions/tan:texts/*/tan:txt" group-by=".">
                                <xsl:sort select="count(current-group())" order="descending"/>
                                <xsl:if test="position() gt 1">
                                    <xsl:text>, </xsl:text>
                                </xsl:if>
                                <div class="fragment"><xsl:value-of select="current-grouping-key()"/></div>
                                <xsl:value-of select="' (' || string(count(current-group())) || ')'"/>
                            </xsl:for-each-group>
                            <xsl:text>. </xsl:text>
                        </xsl:if>
                        <xsl:if test="number($this-nixed-deletions/tan:length) gt 0">
                            <xsl:text>Nixed deletions: </xsl:text>
                            <xsl:for-each-group select="$this-nixed-deletions/tan:texts/*/tan:txt" group-by=".">
                                <xsl:sort select="count(current-group())" order="descending"/>
                                <xsl:if test="position() gt 1">
                                    <xsl:text>, </xsl:text>
                                </xsl:if>
                                <div class="fragment"><xsl:value-of select="current-grouping-key()"/></div>
                                <xsl:value-of select="' (' || string(count(current-group())) || ')'"/>
                            </xsl:for-each-group>
                            <xsl:text>. </xsl:text>
                        </xsl:if>
                    </xsl:if>
                    <div class="bottomline">
                        <xsl:value-of
                            select="
                                'Aggregate progress was ' || string($this-traversal - $these-mistakes + $this-likely-false-mistake-count) ||
                                ' (' || format-number((($this-traversal - $these-mistakes + $this-likely-false-mistake-count) div $journey-distance), '0.0%')"/>
                        <xsl:if test="$this-likely-false-mistake-count gt 0">
                            <xsl:text>, after adjusting for </xsl:text>
                            <xsl:value-of select="$this-likely-false-mistake-count"/>
                            <xsl:text> nixed deletions and insertions that seem negligible</xsl:text>
                        </xsl:if>
                        <xsl:text>). </xsl:text>
                    </div>
                </div>
            </xsl:for-each>
            <div id="{$this-id}" class="diagram"><!--  --></div>
            <xsl:if test="$common-length gt $max-sliver-length">
                <div class="explanation">
                    <xsl:text>*To show more accurately the differences between the three versions, the proportionate size of the central common section has been reduced by </xsl:text>
                    <xsl:value-of select="string($reduce-common-section-by)"/>
                    <xsl:text>, to match the size of the largest sliver. All other non-common slivers are rendered proportionate to one another.</xsl:text>
                </div>
            </xsl:if>
            <xsl:apply-templates select="tan:note" mode="#current"/>
        </div>
        <script xmlns="http://www.w3.org/1999/xhtml">
            <xsl:text>
var sets = [</xsl:text>
            <xsl:apply-templates select="tan:part" mode="#current">
                <xsl:with-param name="reduce-results-by" select="$reduce-common-section-by"/>
            </xsl:apply-templates>
            <xsl:text>
    ];

var chart = venn.VennDiagram()
    chart.wrap(false) 
    .width(320)
    .height(320);

var div = d3.select("#</xsl:text>
            <xsl:value-of select="$this-id"/>
            <xsl:text>").datum(sets).call(chart);
div.selectAll("text").style("fill", "white");
div.selectAll(".venn-circle path").style("fill-opacity", .6);

</xsl:text>
        </script>
    </xsl:template>
    
    <xsl:template match="tan:venn/tan:part" mode="diff-to-html">
        <xsl:param name="reduce-results-by" as="xs:numeric?"/>
        <xsl:variable name="this-parent" select=".."/>
        <xsl:variable name="these-letters"
            select="
                for $i in (tan:a, tan:b, tan:c)
                return
                    name($i)"
        />
        <xsl:variable name="these-labels" select="../*[name(.) = $these-letters]"/>
        <!-- unfortunately, the javascript library we use doesn't look at intersections but unions,
        so lengths need to be recalculated -->
        <xsl:variable name="these-relevant-parts"
            select="
                ../tan:part[every $i in $these-letters
                    satisfies *[name(.) = $i]]"
        />
        <xsl:variable name="these-relevant-lengths" select="$these-relevant-parts/tan:length"/>

        <xsl:variable name="total-length"
            select="
                sum(for $i in ($these-relevant-lengths)
                return
                    number($i)) - $reduce-results-by"
        />
        <xsl:variable name="this-part-length" select="tan:length"/>
        
        <xsl:text>{sets:[</xsl:text>
        <xsl:value-of
            select="
                string-join((for $i in $these-labels
                return
                    ('&quot;' || $i || '&quot;')), ', ')"
        />
        <xsl:text>], size: </xsl:text>
        <xsl:value-of select="$total-length"/>
        
        <xsl:value-of
            select="
                ', label: &quot;' || (if (count($these-letters) eq 3) then
                    '*'
                else
                    ()) || string($this-part-length) || '&quot;'"
        />
        
        <xsl:text>}</xsl:text>
        <xsl:if test="exists(following-sibling::tan:part)">
            <xsl:text>,</xsl:text>
        </xsl:if>
        <xsl:text>&#xa;            </xsl:text>
    </xsl:template>
    
    
    
    <!-- HTML TABLE: for comparing commonality between pairs of versions -->
    <xsl:template match="tan:group/tan:collation" mode="diff-to-html">
        <xsl:variable name="witness-ids" select="tan:witness/@id"/>
        <xsl:if test="exists(tan:witness/tan:commonality)">
            <div xmlns="http://www.w3.org/1999/xhtml">
                <div class="label">Pairwise Similarity</div>
                <div class="explanation">The table below shows the percentage of similarity of each
                    pair of versions, starting with the version that shows the least divergence from
                    the entire group and proceeding to versions that are most divergent. This table
                    is useful for identifying clusters and pairs of versions that are closest to
                    each other.</div>
                <table>
                    <xsl:attribute name="class" select="'e-' || name(.)"/>
                    <thead>
                        <tr>
                            <th/>
                            <xsl:for-each select="$witness-ids">
                                <th>
                                    <xsl:value-of select="."/>
                                </th>
                            </xsl:for-each>
                        </tr>
                    </thead>
                    <tbody>
                        <xsl:apply-templates select="tan:witness" mode="#current">
                            <xsl:with-param name="witness-ids" select="$witness-ids"/>
                        </xsl:apply-templates>
                    </tbody>
                </table>
            </div>
        </xsl:if>
        <!-- venns appeared in the previous sibling, but for visualization, it makes sense to study them
        only after looking at the two-way tables -->
        <xsl:apply-templates select="../tan:stats/tan:venns" mode="#current"/>
        <!-- The following processes the a, b, u, common elements -->
        <h2 xmlns="http://www.w3.org/1999/xhtml">Comparison</h2>
        <xsl:apply-templates select="* except tan:witness" mode="#current"/>
    </xsl:template>
    
    <xsl:template match="tan:witness" mode="diff-to-html">
        <xsl:param name="witness-ids"/>
        <xsl:variable name="commonality-children" select="tan:commonality"/>
        <tr xmlns="http://www.w3.org/1999/xhtml">
            <td><xsl:value-of select="@id"/></td>
            <xsl:for-each select="$witness-ids">
                <xsl:variable name="this-id" select="."/>
                <xsl:variable name="this-commonality" select="$commonality-children[@with = $this-id]"/>
                <td>
                    <xsl:if test="exists($this-commonality)">
                        <xsl:variable name="this-commonality-number" select="number($this-commonality)"/>
                        <xsl:attribute name="style"
                            select="'background-color: rgba(0, 128, 0, ' || string($this-commonality-number * $this-commonality-number * 0.6) || ')'"
                        />
                        <xsl:value-of select="format-number($this-commonality-number * 100, '0.0')"/>
                    </xsl:if>
                </td>
            </xsl:for-each>
        </tr>
    </xsl:template>
    
    


    <xsl:template match="/" priority="5">
        <xsl:for-each select="$file-groups-with-stats, $output-as-html">
            <xsl:call-template name="save-file">
                <xsl:with-param name="document-to-save" select="."/>
            </xsl:call-template>
        </xsl:for-each>
        <diagnostics>
            <main-input-resolved-uris count="{count($main-input-resolved-uris)}"><xsl:value-of select="$main-input-resolved-uris"/></main-input-resolved-uris>
            <MIRUs-chosen count="{count($mirus-chosen)}"><xsl:value-of select="$mirus-chosen"/></MIRUs-chosen>
            <!--<input-class-1-files count="{count($main-input-class-1-files)}"/>-->
            <!--<input-expanded-with-grouping-keys><xsl:copy-of select="tan:shallow-copy($main-input-files-expanded, 2)"/></input-expanded-with-grouping-keys>-->
            <output-dir><xsl:value-of select="$target-output-directory-resolved"/></output-dir>
            <!--<file-groups-diffed-and-collated><xsl:copy-of select="$file-groups-diffed-and-collated"/></file-groups-diffed-and-collated>-->
            <!--<file-groups-with-stats><xsl:copy-of select="$file-groups-with-stats"/></file-groups-with-stats>-->
            <!--<output-containers-prepped><xsl:copy-of select="$output-containers-prepped"/></output-containers-prepped>-->
            <!--<html-output><xsl:copy-of select="$output-as-html"/></html-output>-->
        </diagnostics>
    </xsl:template>


</xsl:stylesheet>
