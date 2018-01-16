<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:tan="tag:textalign.net,2015:ns"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:fn="http://www.w3.org/2005/xpath-functions" xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="#all" version="2.0">

    <!-- General functions that process strings -->

    <xsl:function name="tan:batch-replace" as="xs:string?">
        <!-- Input: a string, a sequence of <[ANY NAME] pattern="" replacement="" [flags=""]> -->
        <!-- Output: the string, after those replaces are processed in order -->
        <xsl:param name="string" as="xs:string?"/>
        <xsl:param name="replace-elements" as="element()*"/>
        <xsl:choose>
            <xsl:when test="not(exists($replace-elements))">
                <xsl:value-of select="$string"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="new-string"
                    select="
                        if (exists($replace-elements[1]/@flags)) then
                            tan:replace($string, $replace-elements[1]/@pattern, $replace-elements[1]/@replacement, $replace-elements[1]/@flags)
                        else
                            tan:replace($string, $replace-elements[1]/@pattern, $replace-elements[1]/@replacement)"/>
                <xsl:value-of
                    select="tan:batch-replace($new-string, $replace-elements[position() gt 1])"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="tan:string-length" as="xs:integer">
        <!-- Input: any string -->
        <!-- Output: the number of characters in the string, as defined by TAN (i.e., modifiers are counted with the preceding base character) -->
        <xsl:param name="input" as="xs:string?"/>
        <xsl:copy-of select="count(tan:chop-string($input))"/>
    </xsl:function>
    
    <xsl:function name="tan:normalize-text" as="xs:string*">
        <!-- one-parameter version of full function below -->
        <xsl:param name="text" as="xs:string*"/>
        <xsl:copy-of select="tan:normalize-text($text, false())"/>
    </xsl:function>
    <xsl:function name="tan:normalize-text" as="xs:string*">
        <!-- Input: any sequence of strings; a boolean indicating whether the results should be normalized further to a common form -->
        <!-- Output: that sequence, with each item's space normalized, and removal of any help requested -->
        <!-- A common form is one where the string is converted to lower-case, and hyphens are replaced by spaces -->
        <xsl:param name="text" as="xs:string*"/>
        <xsl:param name="render-common" as="xs:boolean"/>
        <xsl:variable name="pass1"
            select="
                for $i in $text
                return
                    normalize-unicode(normalize-space(replace($i, $help-trigger-regex, '')))"/>
        <xsl:copy-of
            select="
                if ($render-common = true()) then
                    lower-case(replace($pass1, '-', ' '))
                else
                    $pass1"
        />
    </xsl:function>
    
    <xsl:function name="tan:atomize-string" as="xs:string*">
        <!-- alias for tan:-chop-string() -->
        <xsl:param name="input" as="xs:string?"/>
        <xsl:copy-of select="tan:chop-string($input)"/>
    </xsl:function>
    
    <xsl:variable name="char-reg-exp" select="'\P{M}\p{M}*'"/>
    <xsl:function name="tan:chop-string" as="xs:string*">
        <!-- Input: any string -->
        <!-- Output: that string chopped into a sequence of individual characters, following TAN rules (modifying characters always join their preceding base character) -->
        <xsl:param name="input" as="xs:string?"/>
        <xsl:if test="string-length($input) gt 0">
            <xsl:analyze-string select="$input" regex="{$char-reg-exp}">
                <xsl:matching-substring>
                    <xsl:value-of select="."/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:value-of select="."/>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:if>
    </xsl:function>
    
    <xsl:function name="tan:tokenize-text" as="element()*">
        <!-- one-parameter version of the function below -->
        <xsl:param name="text" as="xs:string*"/>
        <xsl:copy-of
            select="tan:tokenize-text($text, $token-definition-default, true())"/>
    </xsl:function>
    <xsl:function name="tan:tokenize-text" as="element()*">
        <!-- Input: any number of strings; a <token-definition>; a boolean indicating whether tokens should be counted and labeled. -->
        <!-- Output: a <result> for each string, tokenized into <tok> and <non-tok>, respectively. If the counting option is turned on, the <result> contains @tok-count and @non-tok-count, and each <tok> and <non-tok> have an @n indicating which <tok> group it belongs to. -->
        <xsl:param name="text" as="xs:string*"/>
        <xsl:param name="token-definition" as="element(tan:token-definition)?"/>
        <xsl:param name="count-toks" as="xs:boolean?"/>
        <xsl:variable name="this-tok-def"
            select="
                if (exists($token-definition)) then
                    $token-definition
                else
                    $token-definition-default"/>
        <xsl:variable name="pattern" select="$this-tok-def/@pattern"/>
        <xsl:variable name="flags" select="$this-tok-def/@flags"/>
        <xsl:variable name="pass1" as="element()*">
            <xsl:for-each select="$text">
                <results regex="{$pattern}" flags="{$flags}">
                    <xsl:analyze-string select="." regex="{$pattern}">
                        <xsl:matching-substring>
                            <tok>
                                <xsl:value-of select="."/>
                            </tok>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <non-tok>
                                <xsl:value-of select="."/>
                            </non-tok>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </results>
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$count-toks = true()">
                <xsl:for-each select="$pass1">
                    <results tok-count="{count(tan:tok)}" non-tok-count="{count(tan:non-tok)}">
                        <xsl:for-each-group select="*" group-starting-with="tan:tok">
                            <xsl:variable name="pos" select="position()"/>
                            <xsl:for-each select="current-group()">
                                <xsl:copy>
                                    <xsl:attribute name="n" select="$pos"/>
                                    <xsl:value-of select="."/>
                                </xsl:copy>
                            </xsl:for-each>
                        </xsl:for-each-group>
                    </results>
                </xsl:for-each>

            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="$pass1"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>


    <xsl:param name="loop-tolerance" as="xs:integer" select="550"/>

    <xsl:function name="tan:diff" as="element()">
        <!-- 2-param version of fuller one below -->
        <xsl:param name="string-a" as="xs:string?"/>
        <xsl:param name="string-b" as="xs:string?"/>
        <xsl:copy-of select="tan:diff($string-a, $string-b, true())"/>
    </xsl:function>
    <xsl:function name="tan:diff" as="element()">
        <!-- Input: any two strings; boolean indicating whether results should snap to nearest word -->
        <!-- Output: an element with <a>, <b>, and <common> children showing where strings a and b match and depart -->
        <!-- This function was written after tan:diff, intended to be a cruder and faster way to check two strings against each other, suitable for validation without hanging due to nested recursion objections. -->
        <xsl:param name="string-a" as="xs:string?"/>
        <xsl:param name="string-b" as="xs:string?"/>
        <xsl:param name="snap-to-word" as="xs:boolean"/>
        <xsl:variable name="a-prepped" as="element()">
            <a>
                <xsl:value-of select="$string-a"/>
            </a>
        </xsl:variable>
        <xsl:variable name="b-prepped" as="element()">
            <b>
                <xsl:value-of select="$string-b"/>
            </b>
        </xsl:variable>
        <xsl:variable name="strings-prepped" as="element()+">
            <xsl:for-each select="$a-prepped, $b-prepped">
                <xsl:sort select="string-length(text())"/>
                <xsl:copy-of select="."/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="strings-diffed" as="element()*"
            select="tan:diff-loop($strings-prepped[1], $strings-prepped[2], true(), true(), 0)"/>
        <xsl:variable name="results-sorted-1" as="element()">
            <diff>
                <xsl:for-each-group select="$strings-diffed" group-starting-with="tan:common">
                    <xsl:copy-of select="current-group()/self::tan:common"/>
                    <xsl:if test="exists(current-group()/self::tan:a)">
                        <a>
                            <xsl:value-of select="string-join(current-group()/self::tan:a, '')"/>
                        </a>
                    </xsl:if>
                    <xsl:if test="exists(current-group()/self::tan:b)">
                        <b>
                            <xsl:value-of select="string-join(current-group()/self::tan:b, '')"/>
                        </b>
                    </xsl:if>
                </xsl:for-each-group>
            </diff>
        </xsl:variable>
        <xsl:variable name="results-sorted-2" as="element()">
            <diff>
                <xsl:copy-of select="tan:group-adjacent-elements($results-sorted-1/*)"/>
            </diff>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$snap-to-word">
                <xsl:variable name="snap1" as="element()">
                    <xsl:apply-templates select="$results-sorted-2" mode="snap-to-word-pass-1"/>
                </xsl:variable>
                <xsl:variable name="snap2" as="element()">
                    <!-- It happens that sometimes matching words get restored in this process, either at the beginning or the end of an <a> or <b>; this step moves those common words back into the common pool -->
                    <snap2>
                        <xsl:for-each-group select="$snap1/*" group-starting-with="tan:common">
                            <xsl:copy-of select="current-group()/self::tan:common"/>
                            <xsl:variable name="text-a"
                                select="string-join(current-group()/(self::tan:a, self::tan:a-or-b), '')"/>
                            <xsl:variable name="text-b"
                                select="string-join(current-group()/(self::tan:b, self::tan:a-or-b), '')"/>
                            <xsl:variable name="a-toks" as="xs:string*">
                                <xsl:analyze-string select="$text-a" regex="\s+">
                                    <xsl:matching-substring>
                                        <xsl:value-of select="."/>
                                    </xsl:matching-substring>
                                    <xsl:non-matching-substring>
                                        <xsl:value-of select="."/>
                                    </xsl:non-matching-substring>
                                </xsl:analyze-string>
                            </xsl:variable>
                            <xsl:variable name="b-toks" as="xs:string*">
                                <xsl:analyze-string select="$text-b" regex="\s+">
                                    <xsl:matching-substring>
                                        <xsl:value-of select="."/>
                                    </xsl:matching-substring>
                                    <xsl:non-matching-substring>
                                        <xsl:value-of select="."/>
                                    </xsl:non-matching-substring>
                                </xsl:analyze-string>
                            </xsl:variable>
                            <xsl:variable name="a-tok-qty" select="count($a-toks)"/>
                            <xsl:variable name="b-tok-qty" select="count($b-toks)"/>
                            <xsl:variable name="non-matches-from-start" as="xs:integer*">
                                <!-- We are looking for first word where there isn't a match -->
                                <xsl:for-each select="$a-toks">
                                    <xsl:variable name="pos" select="position()"/>
                                    <xsl:if test="not(. = $b-toks[$pos])">
                                        <xsl:value-of select="$pos"/>
                                    </xsl:if>
                                </xsl:for-each>
                                <xsl:if test="$a-tok-qty lt $b-tok-qty">
                                    <xsl:value-of select="$a-tok-qty + 1"/>
                                </xsl:if>
                            </xsl:variable>
                            <!-- grab those tokens in b starting with the first non match and reverse the order -->
                            <xsl:variable name="b-nonmatches-rev"
                                select="reverse($b-toks[position() ge $non-matches-from-start[1]])"/>
                            <xsl:variable name="a-nonmatches-rev"
                                select="reverse($a-toks[position() ge $non-matches-from-start[1]])"/>
                            <xsl:variable name="non-matches-from-end" as="xs:integer*">
                                <!-- We're looking for the first word from the end where there isn't match -->
                                <xsl:for-each select="$a-nonmatches-rev">
                                    <xsl:variable name="pos" select="position()"/>
                                    <xsl:if test="not(. = $b-nonmatches-rev[$pos])">
                                        <xsl:value-of select="$pos"/>
                                    </xsl:if>
                                </xsl:for-each>
                                <!--<xsl:if test="$a-tok-qty lt $b-tok-qty">
                                    <xsl:value-of select="$a-tok-qty + 1"/>
                                </xsl:if>-->
                                <xsl:if test="count($a-nonmatches-rev) lt count($b-nonmatches-rev)">
                                    <xsl:value-of select="count($a-nonmatches-rev) + 1"/>
                                </xsl:if>
                            </xsl:variable>
                            <xsl:variable name="a-analyzed" as="element()*">
                                <xsl:for-each select="$a-toks">
                                    <xsl:variable name="pos" select="position()"/>
                                    <xsl:variable name="rev-pos" select="$a-tok-qty - $pos"/>
                                    <xsl:choose>
                                        <xsl:when test="$pos lt $non-matches-from-start[1]">
                                            <common-head>
                                                <xsl:value-of select="."/>
                                            </common-head>
                                        </xsl:when>
                                        <xsl:when test="$rev-pos + 1 lt $non-matches-from-end[1]">
                                            <common-tail>
                                                <xsl:value-of select="."/>
                                            </common-tail>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <a>
                                                <xsl:value-of select="."/>
                                            </a>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:for-each>
                            </xsl:variable>
                            <xsl:variable name="b-analyzed" as="element()*">
                                <xsl:for-each
                                    select="
                                        $b-toks[position() ge $non-matches-from-start[1]
                                        and position() le ($b-tok-qty - $non-matches-from-end[1] + 1)]">
                                    <b>
                                        <xsl:value-of select="."/>
                                    </b>
                                </xsl:for-each>
                            </xsl:variable>
                            <xsl:for-each-group select="($a-analyzed, $b-analyzed)"
                                group-by="name()">
                                <xsl:sort
                                    select="index-of(('common-head', 'a', 'b', 'common-tail'), current-grouping-key())"/>
                                <xsl:variable name="element-name"
                                    select="replace(current-grouping-key(), '-.+', '')"/>
                                <xsl:element name="{$element-name}">
                                    <xsl:value-of select="string-join(current-group(), '')"/>
                                </xsl:element>
                            </xsl:for-each-group>
                        </xsl:for-each-group>
                    </snap2>
                </xsl:variable>
                <diff>
                    <!-- diagnostics, results -->
                    <!--<xsl:copy-of select="$strings-prepped"/>-->
                    <!--<xsl:copy-of select="$strings-diffed"/>-->
                    <!--<xsl:copy-of select="$results-sorted-1"/>-->
                    <!--<xsl:copy-of select="$results-sorted-2"/>-->
                    <!--<xsl:copy-of select="$snap1"/>-->
                    <!--<xsl:copy-of select="$snap2"/>-->
                    <xsl:copy-of select="tan:group-adjacent-elements($snap2/*)"/>
                </diff>
            </xsl:when>
            <xsl:otherwise>
                <!-- results, diagnostics -->
                <!--<xsl:sequence select="$results-sorted-1"/>-->
                <xsl:sequence select="$results-sorted-2"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="tan:group-adjacent-elements" as="element()*">
        <!-- Input: any sequence of elements -->
        <!-- Output: the same elements, but adjacent elements of the same name grouped together -->
        <xsl:param name="elements" as="element()*"/>
        <xsl:for-each-group select="$elements" group-adjacent="name()">
            <xsl:element name="{current-grouping-key()}">
                <xsl:copy-of select="current-group()/@*"/>
                <xsl:copy-of select="current-group()/node()"/>
            </xsl:element>
        </xsl:for-each-group>
    </xsl:function>
    <xsl:template match="*" mode="snap-to-word-pass-1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="tan:common" mode="snap-to-word-pass-1">
        <xsl:variable name="regex-1"
            select="
                if (exists(preceding-sibling::*)) then
                    '^\w+'
                else
                    ()"/>
        <xsl:variable name="regex-2"
            select="
                if (exists(following-sibling::*)) then
                    '\w+$'
                else
                    ()"/>
        <xsl:variable name="content-analyzed" as="element()">
            <content>
                <xsl:choose>
                    <xsl:when test="exists($regex-1) or exists($regex-2)">
                        <xsl:analyze-string select="text()"
                            regex="{string-join(($regex-1, $regex-2),'|')}">
                            <xsl:matching-substring>
                                <a-or-b>
                                    <xsl:value-of select="."/>
                                </a-or-b>
                            </xsl:matching-substring>
                            <xsl:non-matching-substring>
                                <common>
                                    <xsl:value-of select="."/>
                                </common>
                            </xsl:non-matching-substring>
                        </xsl:analyze-string>
                    </xsl:when>
                    <xsl:otherwise>
                        <common>
                            <xsl:value-of select="text()"/>
                        </common>
                    </xsl:otherwise>
                </xsl:choose>
            </content>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="matches($content-analyzed/tan:common, '\S')">
                <xsl:copy-of select="$content-analyzed/*"/>
            </xsl:when>
            <xsl:otherwise>
                <a-or-b>
                    <xsl:value-of select="."/>
                </a-or-b>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!--<xsl:param name="vertical-stops"
        select="
            ((for $i in reverse(1 to 20)
            return
                $i * 0.05), 0.025)"
        as="xs:double*"/>-->
    <!--<xsl:param name="vertical-stops"
        select="(1.0, 0.95, 0.9, 0.8, 0.65, 0.5, 0.35, 0.2, 0.1, 0.05, 0.025, 0.01)" as="xs:double*"/>-->
    <xsl:param name="vertical-stops"
        select="
            for $i in (0 to 14)
            return
                math:pow(2, (-0.5 * $i))"/>
    <xsl:function name="tan:diff-loop">
        <xsl:param name="short-string" as="element()?"/>
        <xsl:param name="long-string" as="element()?"/>
        <xsl:param name="start-at-beginning" as="xs:boolean"/>
        <xsl:param name="check-vertically-before-horizontally" as="xs:boolean"/>
        <xsl:param name="loop-counter" as="xs:integer"/>
        <!-- If diagnostics are needed, set the following variable to something that will give messages at the right times -->
        <xsl:variable name="diagnostic-flag" as="xs:boolean" select="$loop-counter = -1"/>
        <xsl:variable name="short-size" select="string-length($short-string)"/>
        <xsl:if test="$diagnostic-flag">
            <xsl:message>start at beginning <xsl:value-of select="$start-at-beginning"/>; check v
                before h <xsl:value-of select="$check-vertically-before-horizontally"
                /></xsl:message>
            <xsl:message>short string <xsl:value-of select="substring($short-string, 1, 10)"
                />...</xsl:message>
            <xsl:message>long string <xsl:value-of select="substring($long-string, 1, 10)"
                />...</xsl:message>
        </xsl:if>
        <xsl:choose>
            <xsl:when test="$loop-counter ge $loop-tolerance">
                <xsl:if test="$diagnostic-flag">
                    <xsl:message>Can't go beyond loop <xsl:value-of select="$loop-tolerance"
                        /></xsl:message>
                </xsl:if>
                <xsl:copy-of select="$short-string, $long-string"/>
            </xsl:when>
            <xsl:when test="string-length($long-string) lt 1"/>
            <xsl:when test="$short-size lt 1">
                <xsl:copy-of select="$long-string"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="horizontal-search-on-long" as="element()*">
                    <xsl:for-each select="$vertical-stops">
                        <xsl:variable name="vertical-pos" select="position()"/>
                        <xsl:variable name="percent-of-short-to-check"
                            select="min((max((., 0.0000001)), 1.0))"/>
                        <xsl:variable name="number-of-horizontal-passes"
                            select="
                                if ($check-vertically-before-horizontally) then
                                    1
                                else
                                    xs:integer((1 - $percent-of-short-to-check) * 50) + 1"/>
                        <xsl:variable name="length-of-short-substring"
                            select="ceiling($short-size * $percent-of-short-to-check)"/>
                        <xsl:variable name="length-of-play-in-short"
                            select="$short-size - $length-of-short-substring"/>
                        <xsl:variable name="horizontal-stagger"
                            select="$length-of-play-in-short div max(($number-of-horizontal-passes - 1, 1))"/>
                        <xsl:if test="$diagnostic-flag">
                            <xsl:message select="$horizontal-stagger"/>
                        </xsl:if>
                        <xsl:variable name="horizontal-pass-sequence"
                            select="
                                if ($start-at-beginning) then
                                    (1 to $number-of-horizontal-passes)
                                else
                                    reverse(1 to $number-of-horizontal-passes)"/>
                        <xsl:for-each select="$horizontal-pass-sequence">
                            <xsl:variable name="horizontal-pos" select="."/>
                            <xsl:variable name="starting-pos-of-short-substring"
                                select="ceiling(($horizontal-pos - 1) * $horizontal-stagger) + 1"/>
                            <xsl:variable name="picked-search-text"
                                select="
                                    concat(if ($check-vertically-before-horizontally and $start-at-beginning) then
                                        '^'
                                    else
                                        (), substring($short-string, $starting-pos-of-short-substring, $length-of-short-substring), if ($check-vertically-before-horizontally and not($start-at-beginning)) then
                                        '$'
                                    else
                                        ())"/>
                            <xsl:if test="$diagnostic-flag">
                                <xsl:message select="$picked-search-text"/>
                            </xsl:if>
                            <xsl:variable name="this-search" as="element()*">
                                <xsl:if test="string-length($picked-search-text) gt 0">
                                    <xsl:analyze-string select="$long-string"
                                        regex="{tan:escape($picked-search-text)}">
                                        <xsl:matching-substring>
                                            <common loop="{$loop-counter}">
                                                <xsl:value-of select="."/>
                                            </common>
                                        </xsl:matching-substring>
                                        <xsl:non-matching-substring>
                                            <xsl:element name="{name($long-string)}">
                                                <xsl:attribute name="loop" select="$loop-counter"/>
                                                <xsl:value-of select="."/>
                                            </xsl:element>
                                        </xsl:non-matching-substring>
                                    </xsl:analyze-string>
                                </xsl:if>
                            </xsl:variable>
                            <xsl:if test="exists($this-search/self::tan:common)">
                                <result short-search-start="{$starting-pos-of-short-substring}"
                                    short-search-length="{$length-of-short-substring}">
                                    <xsl:copy-of select="$this-search"/>
                                </result>
                            </xsl:if>
                        </xsl:for-each>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:variable name="first-result"
                    select="($horizontal-search-on-long/self::tan:result)[1]"/>
                <xsl:choose>
                    <xsl:when test="not(exists($first-result))">
                        <xsl:choose>
                            <xsl:when test="not($check-vertically-before-horizontally = true())">
                                <xsl:copy-of select="$long-string, $short-string"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:copy-of
                                    select="tan:diff-loop($short-string, $long-string, $start-at-beginning, false(), $loop-counter + 1)"
                                />
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="short-search-start"
                            select="xs:integer($first-result/@short-search-start)"/>
                        <xsl:variable name="short-search-length"
                            select="xs:integer($first-result/@short-search-length)"/>
                        <xsl:variable name="long-head" as="element()">
                            <xsl:element name="{name($long-string)}">
                                <xsl:attribute name="loop" select="$loop-counter"/>
                                <xsl:copy-of
                                    select="$first-result/tan:common[1]/preceding-sibling::*/text()"
                                />
                            </xsl:element>
                        </xsl:variable>
                        <xsl:variable name="long-tail" as="element()?">
                            <xsl:element name="{name($long-string)}">
                                <xsl:attribute name="loop" select="$loop-counter"/>
                                <xsl:copy-of
                                    select="$first-result/tan:common[1]/following-sibling::*/text()"
                                />
                            </xsl:element>
                        </xsl:variable>
                        <xsl:variable name="short-head" as="element()">
                            <xsl:element name="{name($short-string)}">
                                <xsl:attribute name="loop" select="$loop-counter"/>
                                <xsl:value-of
                                    select="substring($short-string, 1, $short-search-start - 1)"/>
                            </xsl:element>
                        </xsl:variable>
                        <xsl:variable name="short-tail" as="element()">
                            <xsl:element name="{name($short-string)}">
                                <xsl:attribute name="loop" select="$loop-counter"/>
                                <xsl:value-of
                                    select="substring($short-string, $short-search-start + $short-search-length)"
                                />
                            </xsl:element>
                        </xsl:variable>
                        <xsl:variable name="head-input" as="element()*">
                            <xsl:for-each select="$long-head, $short-head">
                                <xsl:sort select="string-length(.)"/>
                                <xsl:copy-of select="."/>
                            </xsl:for-each>
                        </xsl:variable>
                        <xsl:variable name="tail-input" as="element()*">
                            <xsl:for-each select="$long-tail, $short-tail">
                                <xsl:sort select="string-length(.)"/>
                                <xsl:copy-of select="."/>
                            </xsl:for-each>
                        </xsl:variable>
                        <!-- need to loop again on head fragments -->
                        <xsl:copy-of
                            select="
                                tan:diff-loop($head-input[1], $head-input[2], false(), true(), $loop-counter + 1)"/>
                        <xsl:copy-of select="$first-result/tan:common[1]"/>
                        <!-- need to loop again on tail fragments -->
                        <xsl:if test="$diagnostic-flag">
                            <xsl:message
                                select="'tail1: ', $tail-input[1], ' tail2: ', $tail-input[2]"/>
                        </xsl:if>
                        <xsl:copy-of
                            select="
                                tan:diff-loop($tail-input[1], $tail-input[2], true(), true(), $loop-counter + 1)"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="tan:collate" as="element()">
        <!-- one parameter version of full one below -->
        <xsl:param name="strings" as="xs:string*"/>
        <xsl:variable name="these-labels"
            select="
                for $i in (1 to count($strings))
                return
                    xs:string($i)"/>
        <xsl:copy-of select="tan:collate($strings, $these-labels)"/>
    </xsl:function>
    <xsl:function name="tan:collate" as="element()">
        <!-- Input: any number of strings -->
        <!-- Output: an element with <c> and <u w="[WITNESS NUMBERS]">, showing where there are common strings and where there are departures. At the beginning are <witness>es identifying the numbers, and providing basic statistics about how much each pair of witnesses agree. -->
        <!-- This function was written to deal with multiple OCR results of the same page of text, to find agreement wherever possible. -->
        <xsl:param name="strings" as="xs:string*"/>
        <xsl:param name="labels" as="xs:string*"/>
        <xsl:choose>
            <xsl:when test="count($strings) lt 2">
                <!-- If fewer than two strings are given, a collation can't be done -->
                <collation>
                    <witness>
                        <xsl:value-of select="$labels[1]"/>
                    </witness>
                    <c w="{$labels[1]}">
                        <xsl:value-of select="$strings[1]"/>
                    </c>
                </collation>
            </xsl:when>
            <xsl:otherwise>
                <!-- Step 1: run diff against each pair of strings -->
                <xsl:variable name="all-diffs" as="element()*">
                    <xsl:for-each select="$labels[position() gt 1]">
                        <xsl:variable name="text1" select="."/>
                        <xsl:variable name="this-pos" select="position() + 1"/>
                        <xsl:for-each select="$labels[position() lt $this-pos]">
                            <xsl:variable name="text2" select="."/>
                            <xsl:variable name="that-pos" select="position()"/>
                            <xsl:variable name="this-diff"
                                select="tan:diff($strings[$this-pos], $strings[$that-pos], false())"/>
                            <diff a="{$text1}" b="{$text2}">
                                <xsl:copy-of select="$this-diff/*"/>
                            </diff>
                        </xsl:for-each>
                    </xsl:for-each>
                </xsl:variable>
                <!-- Step 2: sort by greatest amount of commonality -->
                <xsl:variable name="diffs-sorted" as="element()*">
                    <xsl:for-each-group select="$all-diffs"
                        group-by="
                            sum((for $i in tan:common
                            return
                                string-length($i))) div (sum((for $j in tan:*
                            return
                                string-length($j))) - (sum((for $k in (tan:a, tan:b)
                            return
                                string-length($k))) div 2))">
                        <xsl:sort order="descending" select="current-grouping-key()"/>
                        <xsl:for-each select="current-group()">
                            <xsl:copy>
                                <xsl:attribute name="commonality" select="current-grouping-key()"/>
                                <xsl:copy-of select="@* | node()"/>
                            </xsl:copy>
                        </xsl:for-each>
                    </xsl:for-each-group>
                </xsl:variable>
                <!-- Step 3: get the sequence in which versions should be processed -->
                <xsl:variable name="collate-order"
                    select="
                        distinct-values(for $i in $diffs-sorted
                        return
                            ($i/@a, $i/@b))"/>
                <!-- Step 4: set up the first collation diff -->
                <xsl:variable name="first-collation" as="element()">
                    <xsl:apply-templates select="$diffs-sorted[1]" mode="diff-to-collation">
                        <xsl:with-param name="w1" select="$collate-order[1]" tunnel="yes"/>
                        <xsl:with-param name="w2" select="$collate-order[2]" tunnel="yes"/>
                    </xsl:apply-templates>
                </xsl:variable>
                <!-- Step 5: run the collation loop -->
                <xsl:variable name="this-collation"
                    select="
                        tan:collate-loop-outer($first-collation, for $i in $collate-order[position() gt 2],
                            $j in index-of($labels, $i)
                        return
                            $strings[$j], $collate-order[position() gt 2])"/>
                <!-- Step 6: consolidate, stamp the collation -->
                <xsl:variable name="consolidated-collation" as="element()">
                    <collation>
                        <xsl:for-each-group select="$this-collation/*" group-adjacent="name(.)">
                            <xsl:choose>
                                <xsl:when test="current-grouping-key() = 'witness'">
                                    <xsl:for-each select="current-group()">
                                        <xsl:variable name="this-witness" select="text()"/>
                                        <xsl:copy>
                                            <xsl:attribute name="id" select="$this-witness"/>
                                            <xsl:for-each select="$collate-order">
                                                <xsl:variable name="this-partner" select="."/>
                                                <xsl:variable name="this-diff"
                                                  select="$diffs-sorted[(@a = $this-partner and @b = $this-witness) or (@a = $this-witness and @b = $this-partner)]"/>
                                                <commonality with="{$this-partner}">
                                                  <xsl:value-of
                                                  select="
                                                            if (exists($this-diff)) then
                                                                $this-diff/@commonality
                                                            else
                                                                1.0"
                                                  />
                                                </commonality>
                                            </xsl:for-each>
                                        </xsl:copy>
                                    </xsl:for-each>
                                </xsl:when>
                                <!-- Commented out because it produced false results. A collation of 'ah', 'an', and 'oho' doubled up the 'o' -->
                                <!--<xsl:when test="current-grouping-key() = 'u'">
                                    <xsl:for-each-group select="current-group()" group-by="text()">
                                        <u w="{string-join(current-group()/@w,' ')}">
                                            <xsl:value-of select="current-grouping-key()"/>
                                        </u>
                                    </xsl:for-each-group>
                                </xsl:when>-->
                                <xsl:otherwise>
                                    <xsl:copy-of select="current-group()"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each-group>
                    </collation>
                </xsl:variable>
                <!-- Step 7: determine, for groups of <u>s, what the base text should be -->
                <xsl:variable name="collation-with-base-marked" as="element()">
                    <collation>
                        <xsl:for-each-group select="$consolidated-collation/*"
                            group-adjacent="name(.)">
                            <xsl:choose>
                                <xsl:when test="current-grouping-key() = 'u'">
                                    <xsl:variable name="witness-count-max"
                                        select="
                                            max((for $i in current-group()
                                            return
                                                count(tokenize($i/@w, ' '))))"/>
                                    <xsl:variable name="this-group" as="element()">
                                        <group>
                                            <xsl:copy-of select="current-group()"/>
                                        </group>
                                    </xsl:variable>
                                    <xsl:variable name="most-probable-base"
                                        select="($this-group/*[count(tokenize(@w, ' ')) = $witness-count-max])[1]"/>
                                    <xsl:copy-of select="$most-probable-base/preceding-sibling::*"/>
                                    <u base="">
                                        <xsl:copy-of select="$most-probable-base/@w"/>
                                        <xsl:value-of select="$most-probable-base/text()"/>
                                    </u>
                                    <xsl:copy-of select="$most-probable-base/following-sibling::*"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:copy-of select="current-group()"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:for-each-group>
                    </collation>
                </xsl:variable>
                <!-- diagnostics, results -->
                <!--<xsl:copy-of select="$this-collation"/>-->
                <!--<xsl:copy-of select="$consolidated-collation"/>-->
                <xsl:copy-of select="$collation-with-base-marked"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:template match="tan:diff" mode="diff-to-collation">
        <xsl:param name="w1" tunnel="yes"/>
        <xsl:param name="w2" tunnel="yes"/>
        <collation>
            <witness>
                <xsl:value-of select="$w1"/>
            </witness>
            <witness>
                <xsl:value-of select="$w2"/>
            </witness>
            <xsl:apply-templates mode="#current"/>
        </collation>
    </xsl:template>
    <xsl:template match="tan:common" mode="diff-to-collation">
        <c length="{string-length(.)}">
            <xsl:value-of select="."/>
        </c>
    </xsl:template>
    <xsl:template match="tan:a" mode="diff-to-collation">
        <xsl:param name="w1" tunnel="yes"/>
        <u w="{$w1}">
            <xsl:value-of select="."/>
        </u>
    </xsl:template>
    <xsl:template match="tan:b" mode="diff-to-collation">
        <xsl:param name="w2" tunnel="yes"/>
        <u w="{$w2}">
            <xsl:value-of select="."/>
        </u>
    </xsl:template>

    <xsl:function name="tan:collate-loop-outer" as="element()">
        <!-- Input: a collation element (see template mode diff-to-collation), some strings to process, and corresponding string labels -->
        <!-- Output: a series of collation elements, marking where there is commonality and differences -->
        <xsl:param name="collation-so-far" as="element()"/>
        <xsl:param name="strings-to-process" as="xs:string*"/>
        <xsl:param name="string-labels" as="xs:string*"/>
        <!-- Step 1: can the loop even be run? It can't if there aren't strings to process, or there is no commonality in the collation -->
        <xsl:choose>
            <!-- If there are no more strings to process, then end the loop -->
            <xsl:when test="count($strings-to-process) lt 1">
                <xsl:copy-of select="$collation-so-far"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="new-collation" as="element()">
                    <collation>
                        <xsl:copy-of select="$collation-so-far/tan:witness"/>
                        <witness>
                            <xsl:value-of select="$string-labels[1]"/>
                        </witness>
                        <xsl:copy-of
                            select="tan:collate-loop-inner($collation-so-far, $strings-to-process[1], $string-labels[1])"
                        />
                    </collation>
                </xsl:variable>
                <xsl:copy-of
                    select="tan:collate-loop-outer($new-collation, $strings-to-process[position() gt 1], $string-labels[position() gt 1])"
                />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="tan:collate-loop-inner" as="element()*">
        <!-- Input: a collation element (see template mode diff-to-collation), one string to process, and the corresponding string label -->
        <!-- Output: a series of collation elements, marking where there is commonality and differences -->
        <!-- This inner loop returns only the children of the collation element; the outer loop handles the parent element -->
        <xsl:param name="collation-so-far" as="element()"/>
        <xsl:param name="string-to-process" as="xs:string?"/>
        <xsl:param name="string-label" as="xs:string?"/>
        <xsl:choose>
            <!-- If there's no string to process, end -->
            <xsl:when test="string-length($string-to-process) lt 1">
                <xsl:copy-of select="$collation-so-far/(tan:c, tan:u)[string-length(.) gt 0]"/>
            </xsl:when>
            <!-- If the collation so far has no common elements, then end the loop -->
            <xsl:when test="not(exists($collation-so-far/tan:c))">
                <xsl:copy-of select="$collation-so-far/tan:u"/>
                <u w="{$string-label}">
                    <xsl:value-of select="$string-to-process"/>
                </u>
            </xsl:when>
            <xsl:otherwise>
                <!-- Step 2a: split $collation-so-far into three: the longest <c> and what precedes and what follows -->
                <xsl:variable name="collation-longest-common-length"
                    select="
                        xs:string(max((for $i in $collation-so-far/tan:c/@length
                        return
                            xs:integer($i))))"/>
                <xsl:variable name="collation-longest-common"
                    select="($collation-so-far/tan:c[@length = $collation-longest-common-length])[1]"/>
                <!-- Step 2b: get the diff between the longest collation segment and the next string to be processed -->
                <xsl:variable name="this-diff"
                    select="tan:diff($collation-longest-common, $string-to-process, false())"/>
                <!-- Step 3: are the results complete, or does the loop need to be run again? -->
                <xsl:choose>
                    <!-- If there's no match, then every stretch of text is unique, including the longest collation segment. Mark them as such and end. -->
                    <xsl:when test="not(exists($this-diff/tan:common))">
                        <xsl:for-each
                            select="$collation-so-far/(tan:c, tan:u)[string-length(.) gt 0]">
                            <u
                                w="{if (exists(@w)) then @w else string-join($collation-so-far/tan:witness,' ')}">
                                <xsl:value-of select="."/>
                            </u>
                        </xsl:for-each>
                        <u w="{$string-label}">
                            <xsl:value-of select="$string-to-process"/>
                        </u>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- There's a match. Find the longest common match. Isolate the heads and tails of both strings. Add the collations parts to the collation's head and tail. Run the collation's head against the string head and the collation's tail against the string tail. -->
                        <!-- Step 4: focus on the longest common match -->
                        <xsl:variable name="this-diff-common-length-max"
                            select="
                                max((for $i in $this-diff/tan:common
                                return
                                    string-length($i)))"/>
                        <xsl:variable name="this-diff-longest-match"
                            select="($this-diff/tan:common[string-length(.) = $this-diff-common-length-max])[1]"/>
                        <xsl:variable name="string-head"
                            select="string-join($this-diff-longest-match/preceding-sibling::*/(self::* except self::*:a), '')"/>
                        <xsl:variable name="string-tail"
                            select="string-join($this-diff-longest-match/following-sibling::*/(self::* except self::*:a), '')"/>
                        <xsl:variable name="clc-head"
                            select="string-join($this-diff-longest-match/preceding-sibling::*/(self::* except self::*:b), '')"/>
                        <xsl:variable name="clc-tail"
                            select="string-join($this-diff-longest-match/following-sibling::*/(self::* except self::*:b), '')"/>
                        <xsl:variable name="collation-head" as="element()">
                            <collation>
                                <xsl:copy-of select="$collation-longest-common/preceding-sibling::*"/>
                                <xsl:if test="string-length($clc-head) gt 0">
                                    <c length="{string-length($clc-head)}">
                                        <xsl:value-of select="$clc-head"/>
                                    </c>
                                </xsl:if>
                            </collation>
                        </xsl:variable>
                        <xsl:variable name="collation-tail" as="element()">
                            <collation>
                                <xsl:copy-of select="$collation-so-far/tan:witness"/>
                                <xsl:if test="string-length($clc-tail) gt 0">
                                    <c length="{string-length($clc-tail)}">
                                        <xsl:value-of select="$clc-tail"/>
                                    </c>
                                </xsl:if>
                                <xsl:copy-of select="$collation-longest-common/following-sibling::*"
                                />
                            </collation>
                        </xsl:variable>
                        <xsl:copy-of
                            select="tan:collate-loop-inner($collation-head, $string-head, $string-label)"/>
                        <c length="{$this-diff-common-length-max}">
                            <xsl:value-of select="$this-diff-longest-match"/>
                        </c>
                        <xsl:copy-of
                            select="tan:collate-loop-inner($collation-tail, $string-tail, $string-label)"
                        />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

</xsl:stylesheet>
