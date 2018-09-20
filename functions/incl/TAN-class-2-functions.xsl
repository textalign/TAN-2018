<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns="tag:textalign.net,2015:ns"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:fn="http://www.w3.org/2005/xpath-functions"
   xmlns:math="http://www.w3.org/2005/xpath-functions/math" xmlns:functx="http://www.functx.com"
   xmlns:xi="http://www.w3.org/2001/XInclude" exclude-result-prefixes="#all" version="2.0">

   <!-- Core functions for class 2 files. Written principally for Schematron validation, but suitable for general use in other contexts -->

   <xsl:key name="tok-via-ref" match="tan:tok" use="tan:ref/text()"/>

   <!-- GLOBAL VARIABLES AND PARAMETERS -->
   <!-- Source picking and identification -->
   <xsl:variable name="src-ids" as="xs:string*">
      <xsl:for-each select="$head/tan:source">
         <xsl:value-of select="(@xml:id, string(position()))[1]"/>
      </xsl:for-each>
   </xsl:variable>

   <!-- FUNCTIONS -->

   <!-- PROCESSING CLASS 2 DOCUMENTS AND THEIR DEPENDENCIES -->

   <!-- EXPANDING -->

   <!-- TERSE EXPANSION -->
   <!-- core -->

   <xsl:template match="tan:source | tan:morphology[not(@attr)]" mode="core-expansion-terse">
      <!-- dependencies must be evaluated at the terse stage -->
      <xsl:apply-templates select="." mode="check-referred-doc"/>
   </xsl:template>

   <xsl:template match="tan:rename" mode="core-expansion-terse">
      <xsl:variable name="these-refs" select="tan:ref, tan:range/tan:ref"/>
      <xsl:variable name="these-news" select="tan:new, tan:range/tan:new"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="@new = (tan:n, $these-refs)">
            <xsl:copy-of select="tan:error('cl203')"/>
         </xsl:if>
         <xsl:if
            test="exists($these-refs) and exists($these-news) and not(count($these-refs) = count($these-news))">
            <xsl:copy-of select="tan:error('cl216')"/>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   <xsl:template match="tan:tok[not(tan:from)] | tan:tok/tan:from | tan:tok/tan:to"
      mode="core-expansion-terse">
      <xsl:param name="is-tan-a-lm" tunnel="yes"/>
      <xsl:param name="is-for-lang" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <!-- The <tok> in a TAN-A-lm file needs to have a <src> added if it is source-specific, and a <result> added if it is not -->
         <xsl:if test="$is-tan-a-lm">
            <xsl:choose>
               <xsl:when test="$is-for-lang">
                  <result>
                     <xsl:value-of select="@val, @rgx"/>
                  </result>
               </xsl:when>
               <xsl:otherwise>
                  <src>1</src>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
         <xsl:if test="not(exists(@pos))">
            <pos attr="">1</pos>
         </xsl:if>
         <xsl:if test="not(exists(@val)) and not(exists(@rgx))">
            <rgx attr="">.+</rgx>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <!-- class 2 -->

   <xsl:template
      match="tan:object[(tan:src, tan:work)] | tan:subject[(tan:src, tan:work)] | tan:tok[@ref] | tan:from |
      tan:tok/tan:to | tan:div-ref | tan:skip | tan:rename | tan:equate | tan:reassign"
      mode="class-2-expansion-terse">
      <xsl:param name="dependencies" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="diagnostics" select="false()"/>
      <xsl:variable name="is-adjustments-action" select="exists(ancestor::tan:adjustments)"/>
      <xsl:variable name="dependency-actions"
         select="
            if ($is-adjustments-action) then
               tan:get-via-q-ref(@q, $dependencies)
            else
               ()"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="this-element-name" select="name(.)"/>
      <xsl:variable name="this-parent-name" select="name(..)"/>
      <xsl:variable name="this-val" select="tan:val"/>
      <xsl:variable name="this-rgx" select="(tan:rgx, '.+')[1]"/>
      <xsl:variable name="unprocessed-skips-renames-and-reassigns" as="element()*">
         <xsl:if test="$is-adjustments-action">
            <xsl:for-each select="ancestor::tan:adjustments/tan:src">
               <xsl:variable name="this-src" select="text()"/>
               <xsl:for-each
                  select="$this-element/(tan:div-type, tan:n, tan:ref, tan:range/(tan:n, tan:ref), tan:tok/tan:ref)">
                  <xsl:variable name="this-item-text" select="text()"/>
                  <xsl:variable name="this-item-name" select="name(.)"/>
                  <xsl:variable name="matching-actions"
                     select="
                        $dependency-actions[root()/*/@src = $this-src]
                        [(name(.), name(..)) = ($this-element-name, $this-parent-name)
                        or parent::tan:n/tan:orig-n = $this-item-text
                        or tan:div-type = $this-element/tan:div-type
                        or parent::tan:ref/tan:orig-ref/text() = $this-item-text]"/>
                  <xsl:if test="not(exists($matching-actions))">
                     <missing>
                        <src>
                           <xsl:copy-of select="$this-src"/>
                        </src>
                        <xsl:element name="{$this-item-name}">
                           <xsl:value-of select="$this-item-text"/>
                        </xsl:element>
                     </missing>
                  </xsl:if>
               </xsl:for-each>
            </xsl:for-each>
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="these-work-refs" select="tan:work, (parent::tan:object, parent::tan:subject, parent::tan:locus)/tan:work,
         (parent::tan:group, parent::tan:tok)/parent::*/tan:work"/>
      <xsl:variable name="these-src-refs"
         select="
            (tan:src, ancestor::tan:adjustments/(self::*, tan:where)/tan:src,
            (parent::tan:object, parent::tan:subject, parent::tan:locus)/tan:src,
            (parent::tan:group, parent::tan:tok)/parent::*/tan:src),
            (root()/tan:TAN-A/tan:head/tan:vocabulary-key/tan:group[tan:work/@src = $these-work-refs]/tan:work/@src)"
      />
      <xsl:variable name="these-div-refs" as="element()*">
         <xsl:for-each select="$these-src-refs">
            <xsl:variable name="this-src" select="."/>
            <!-- In the case of adjustments, we fetch divs that go by the old names -->
            <xsl:for-each
               select="
                  if ($is-adjustments-action) then
                     $this-element/(self::tan:tok/tan:ref, tan:tok/tan:ref, parent::tan:tok/tan:ref)
                  else
                     $this-element/(self::tan:tok, parent::tan:tok, tan:range)/tan:ref">
               <xsl:variable name="this-ref-text" select="text()"/>
               <xsl:variable name="that-div"
                  select="
                     for $i in $dependencies[root()/*/@src = $this-src]
                     return
                        if ($is-adjustments-action) then
                           key('div-via-orig-ref', $this-ref-text, $dependencies[root()/*/@src = $this-src])
                        else
                           key('div-via-ref', $this-ref-text, $dependencies[root()/*/@src = $this-src])"
               />
               <div-ref>
                  <src>
                     <xsl:value-of select="$this-src"/>
                  </src>
                  <ref>
                     <xsl:value-of select="$this-ref-text"/>
                  </ref>
                  <xsl:copy-of select="$that-div"/>
               </div-ref>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="these-tok-refs" as="element()*">
         <xsl:for-each select="$these-div-refs[tan:div[tan:tok]]">
            <xsl:variable name="this-src" select="tan:src"/>
            <xsl:variable name="this-ref" select="tan:ref"/>
            <xsl:variable name="tokens-picked"
               select="
                  tan:div/tan:tok[if (exists($this-val)) then
                     (. = $this-val)
                  else
                     tan:matches(., $this-rgx)]"
            />
            <xsl:variable name="count-of-tokens-picked" select="count($tokens-picked)"/>
            <xsl:variable name="these-pos-ints"
               select="tan:expand-pos-or-chars($this-element/(tan:pos, tan:range[tan:pos]), $count-of-tokens-picked)"/>
            <xsl:for-each select="$these-pos-ints">
               <xsl:variable name="this-pos" select="."/>
               <xsl:variable name="that-token" select="$tokens-picked[$this-pos]"/>
               <tok-ref>
                  <xsl:copy-of select="$this-src"/>
                  <xsl:copy-of select="$this-ref"/>
                  <pos>
                     <xsl:value-of select="$this-pos"/>
                  </pos>
                  <max>
                     <xsl:value-of select="$count-of-tokens-picked"/>
                  </max>
                  <xsl:copy-of select="$that-token"/>
               </tok-ref>
            </xsl:for-each>
         </xsl:for-each>
      </xsl:variable>
      <xsl:variable name="these-char-refs" as="element()*">
         <xsl:if test="exists($this-element/(tan:chars, tan:range[tan:chars]))">
            <xsl:for-each select="$these-tok-refs[tan:tok]">
               <xsl:variable name="this-src" select="tan:src"/>
               <xsl:variable name="this-ref" select="tan:ref"/>
               <xsl:variable name="this-tok" select="tan:tok"/>
               <xsl:variable name="these-chars" select="tan:atomize-string($this-tok)"/>
               <xsl:variable name="count-of-chars" select="count($these-chars)"/>
               <xsl:variable name="these-pos-ints"
                  select="tan:expand-pos-or-chars($this-element/(tan:chars, tan:range[tan:chars]), $count-of-chars)"/>
               <xsl:for-each select="$these-pos-ints">
                  <xsl:variable name="this-pos" select="."/>
                  <xsl:variable name="that-char" select="$these-chars[$this-pos]"/>
                  <char-ref>
                     <xsl:copy-of select="$this-src"/>
                     <xsl:copy-of select="$this-ref"/>
                     <xsl:copy-of select="$this-tok"/>
                     <pos>
                        <xsl:value-of select="$this-pos"/>
                     </pos>
                     <max>
                        <xsl:value-of select="$count-of-chars"/>
                     </max>
                     <xsl:if test="exists($that-char)">
                        <char>
                           <xsl:value-of select="$that-char"/>
                        </char>
                     </xsl:if>
                  </char-ref>
               </xsl:for-each>
            </xsl:for-each>
         </xsl:if>
      </xsl:variable>
      <xsl:variable name="missing-div-refs" select="$these-div-refs[not(tan:div)]"/>
      <xsl:variable name="missing-tok-refs" select="$these-tok-refs[not(tan:tok)]"/>
      <xsl:variable name="missing-char-refs" select="$these-char-refs[not(tan:char)]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of
            select="$dependency-actions/(tan:error, tan:help, tan:warning, tan:fatal, tan:info)"/>
         <xsl:copy-of select="$dependency-actions/(parent::tan:error, parent::tan:help, parent::tan:warning, parent::tan:fatal, parent::tan:info)"/>
         <xsl:if test="exists($dependency-actions/tan:error[@xml:id = 'rea01'])">
            <xsl:variable name="divs-not-reassigned"
               select="$these-div-refs/tan:div[tan:ref[not(tan:orig-ref)]]"/>
            <xsl:variable name="last-unreassigned-tok" select="$divs-not-reassigned/tan:tok[last()]"/>
            <xsl:variable name="identical-toks"
               select="$these-div-refs/tan:div/tan:tok[. = $last-unreassigned-tok]"/>
            <xsl:if test="exists($identical-toks)">
               <xsl:variable name="identical-tok-nos-sorted" as="xs:string*">
                  <xsl:for-each select="$identical-toks">
                     <xsl:sort select="xs:integer(@n)"/>
                     <xsl:value-of select="@n"/>
                  </xsl:for-each>
               </xsl:variable>
               <xsl:variable name="this-tok-pos"
                  select="index-of($identical-tok-nos-sorted, $last-unreassigned-tok/@n)"/>
               <xsl:variable name="fix-for-to-via-val">
                  <to val="{$last-unreassigned-tok}">
                     <xsl:if test="$this-tok-pos gt 1">
                        <xsl:attribute name="pos" select="$this-tok-pos"/>
                     </xsl:if>
                  </to>
               </xsl:variable>
               <xsl:variable name="fix-for-to-via-pos">
                  <to pos="{$last-unreassigned-tok/@n}"/>
               </xsl:variable>
               <xsl:copy-of
                  select="tan:fix(($fix-for-to-via-val, $fix-for-to-via-pos), 'replace-children')"/>
            </xsl:if>
         </xsl:if>
         <xsl:if test="(tan:val or tan:rgx) and not(exists($these-div-refs/tan:div/tan:tok))">
            <!-- Report attempts to tokenize a non-leaf div -->
            <xsl:copy-of
               select="tan:error('tok02', concat('try: ', string-join($these-div-refs//tan:div[not(tan:div)]/tan:ref/text(), ', ')))"
            />
         </xsl:if>
         <xsl:if test="exists($missing-div-refs) and not($is-adjustments-action)">
            <xsl:variable name="this-message" as="xs:string*">
               <xsl:for-each-group select="$missing-div-refs" group-by="tan:src/text()">
                  <xsl:value-of
                     select="concat('Missing in some versions: ', current-grouping-key(), ': ', string-join(current-group()/tan:ref/text(), ', '))"
                  />
               </xsl:for-each-group>
            </xsl:variable>
            <xsl:choose>
               <xsl:when test="exists($these-work-refs) and exists($these-div-refs[tan:div])">
                  <xsl:copy-of select="tan:error('ref02', string-join($this-message, '; '))"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="tan:error('ref01', string-join($this-message, '; '))"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
         <xsl:if test="exists($missing-tok-refs) and not(exists($dependency-actions))">
            <xsl:if
               test="
                  some $i in $missing-tok-refs/tan:pos
                     satisfies $i = '0'">
               <xsl:copy-of select="tan:error('seq01')"/>
            </xsl:if>
            <xsl:if
               test="
                  some $i in $missing-tok-refs/tan:pos
                     satisfies $i = '-2'">
               <xsl:copy-of select="tan:error('seq03')"/>
            </xsl:if>
            <xsl:variable name="this-message" as="xs:string*">
               <xsl:variable name="message-preamble"
                  select="concat($this-val, $this-rgx, ' not found at position(s) ', string-join(distinct-values($missing-tok-refs/tan:pos), ', '), ': ')"/>
               <xsl:variable name="message-body" as="xs:string*">
                  <xsl:for-each-group select="$missing-tok-refs" group-by="tan:src">

                     <xsl:variable name="ref-report" as="xs:string*">
                        <xsl:for-each-group select="current-group()" group-by="tan:ref">
                           <xsl:value-of
                              select="concat(current-grouping-key(), ' has only ', current-group()[1]/tan:max, ' instance(s)')"
                           />
                        </xsl:for-each-group>
                     </xsl:variable>
                     <xsl:value-of
                        select="concat(current-grouping-key(), ': ', string-join($ref-report, ', '))"
                     />
                  </xsl:for-each-group>
               </xsl:variable>
               <xsl:value-of select="concat($message-preamble, string-join($message-body, '; '))"/>
            </xsl:variable>
            <xsl:copy-of select="tan:error('tok01', $this-message)"/>
         </xsl:if>
         <xsl:if
            test="(exists($missing-tok-refs) and not(exists($dependency-actions))) or exists((tan:pos, tan:val, tan:rgx)/@help)">
            <xsl:variable name="tok-opts" as="element()*">
               <try>try tokens (positions): </try>
               <xsl:for-each-group select="$these-div-refs" group-by="tan:src">
                  <group>
                     <src><xsl:value-of select="current-grouping-key()"/>: </src>
                     <xsl:for-each select="current-group()">
                        <group>
                           <ref><xsl:value-of select="tan:ref"/>: </ref>
                           <xsl:for-each-group select="tan:div/tan:tok" group-by=".">
                              <xsl:sort
                                 select="tan:matches(., concat(tan:escape($this-val), '|', replace($this-rgx, '^^(.+)\$$', '$1')))"
                                 order="descending"/>
                              <group>
                                 <xsl:copy-of select="current-grouping-key()"/>
                              </group>
                              <xsl:value-of
                                 select="concat(' (', string-join(current-group()/@n, ', '), ') ')"
                              />
                           </xsl:for-each-group>
                        </group>
                     </xsl:for-each>
                  </group>
               </xsl:for-each-group>
            </xsl:variable>
            <xsl:variable name="this-message" as="xs:string?">
               <xsl:value-of select="$tok-opts"/>
            </xsl:variable>
            <xsl:copy-of select="tan:help($this-message, (), ())"/>
         </xsl:if>
         <xsl:if test="exists($missing-char-refs)">
            <xsl:if
               test="
                  some $i in $missing-char-refs/tan:pos
                     satisfies $i = '0'">
               <xsl:copy-of select="tan:error('seq01')"/>
            </xsl:if>
            <xsl:if
               test="
                  some $i in $missing-char-refs/tan:pos
                     satisfies $i = '-2'">
               <xsl:copy-of select="tan:error('seq03')"/>
            </xsl:if>
            <xsl:variable name="this-message" as="xs:string*">
               <xsl:variable name="message-preamble"
                  select="concat('characters for ', $this-val, $this-rgx, ' not found at position(s) ', string-join(distinct-values($missing-char-refs/tan:pos[xs:integer(.) gt 0]), ', '), ': ')"/>
               <xsl:variable name="message-body" as="xs:string*">
                  <xsl:for-each-group select="$missing-char-refs" group-by="tan:src">
                     <xsl:variable name="ref-report" as="xs:string*">
                        <xsl:for-each-group select="current-group()" group-by="tan:ref">
                           <xsl:variable name="tok-report" as="xs:string*">
                              <xsl:for-each-group select="current-group()" group-by="tan:tok">
                                 <xsl:value-of
                                    select="concat(current-grouping-key(), ' (length ', (current-group()/tan:max)[1], ')')"
                                 />
                              </xsl:for-each-group>
                           </xsl:variable>
                           <xsl:value-of
                              select="concat(current-grouping-key(), ': ', string-join($tok-report, '; '))"
                           />
                        </xsl:for-each-group>
                     </xsl:variable>
                     <xsl:value-of
                        select="concat(current-grouping-key(), ': ', string-join($ref-report, ', '))"
                     />
                  </xsl:for-each-group>
               </xsl:variable>
               <xsl:value-of select="concat($message-preamble, string-join($message-body, '; '))"/>
            </xsl:variable>
            <xsl:copy-of select="tan:error('chr01', $this-message)"/>
         </xsl:if>
         <xsl:if test="exists($unprocessed-skips-renames-and-reassigns)">
            <xsl:variable name="this-message" as="xs:string*">
               <xsl:for-each-group select="$unprocessed-skips-renames-and-reassigns"
                  group-by="tan:src/text()">
                  <xsl:value-of
                     select="concat(current-grouping-key(), ': ', string-join(current-group()/(tan:n, tan:ref, tan:div-type)/text(), ', '))"
                  />
               </xsl:for-each-group>
            </xsl:variable>
            <xsl:choose>
               <xsl:when test="exists($unprocessed-skips-renames-and-reassigns/tan:n)">
                  <xsl:if test="$diagnostics">
                     <xsl:message select="'dependency actions:', $dependency-actions"/>
                     <xsl:message select="'unprocessed skips renames and reassigns:', $unprocessed-skips-renames-and-reassigns"/>
                  </xsl:if>
                  <xsl:copy-of select="tan:error('cl215', string-join($this-message, '; '))"/>
               </xsl:when>
               <xsl:when test="exists($unprocessed-skips-renames-and-reassigns/tan:div-type)">
                  <xsl:copy-of select="tan:error('dty01', string-join($this-message, '; '))"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="tan:error('ref01', string-join($this-message, '; '))"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:if>
         <!-- Make copies of the items found -->
         <xsl:choose>
            <xsl:when test="exists($these-char-refs)">
               <xsl:copy-of select="$these-char-refs"/>
            </xsl:when>
            <xsl:when test="exists($these-tok-refs)">
               <xsl:copy-of select="$these-tok-refs"/>
            </xsl:when>
            <!-- But if it's a tan:tok we ignore any div refs -->
            <xsl:when test="self::tan:tok"/>
            <xsl:otherwise>
               <xsl:copy-of select="$these-div-refs"/>
            </xsl:otherwise>
         </xsl:choose>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>


   <!-- NORMAL EXPANSION -->

   <xsl:template match="*[tan:tok]" mode="core-expansion-normal">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:apply-templates mode="#current">
            <xsl:with-param name="duplicate-toks" select="tan:duplicate-items(tan:tok/tan:tok-ref)"
            />
         </xsl:apply-templates>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:div-ref" mode="core-expansion-normal">
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <xsl:template match="tan:tok[tan:tok-ref]" mode="core-expansion-normal">
      <xsl:param name="dependencies" tunnel="yes"/>
      <xsl:param name="duplicate-toks"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="tan:tok-ref = $duplicate-toks">
            <xsl:copy-of select="tan:error('cl211', 'Duplicates sibling tok')"/>
         </xsl:if>
         <xsl:if
            test="exists(tan:error[@xml:id = 'tok01']) or exists((tan:pos, tan:val, tan:rgx)/@help)">
            <!-- placeholder for providing help on the right tok -->
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   
   
   <xsl:template match="tan:tok[not(tan:tok-ref)][tan:val or tan:rgx]" mode="class-2-expansion-normal">
      <!-- If there's no specific reference, it's pointing to tokens anywhere in the source -->
      <!--<xsl:param name="dependencies" tunnel="yes"/>-->
      <xsl:param name="all-tokens" tunnel="yes"/>
      <xsl:variable name="this-val" select="tan:val"/>
      <xsl:variable name="this-rgx" select="tan:rgx"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($all-tokens)">
            <xsl:for-each select="tan:src">
               <xsl:variable name="this-src" select="."/>
               <xsl:variable name="source-tokens"
                  select="$all-tokens[root()/tan:TAN-T/@src = $this-src]"/>
               <xsl:variable name="first-source-match"
                  select="
                     $all-tokens[if (exists($this-val))
                     then
                        (. = $this-val)
                     else
                        tan:matches(., $this-rgx)][1]"
               />
               <xsl:if test="not(exists($first-source-match))">
                  <xsl:variable name="examples-maximum" select="50"/>
                  <xsl:variable name="rgx-adjusted" select="replace($this-rgx, '^\^(.+)\$$', '$1')"/>
                  <xsl:variable name="this-message" as="xs:string*">
                     <xsl:text>try: </xsl:text>
                     <xsl:for-each-group select="$all-tokens" group-by=".">
                        <xsl:sort
                           select="tan:matches(., string-join(($this-val, $rgx-adjusted), '|'))"
                           order="descending"/>
                        <xsl:sort select="count(current-group())" order="descending"/>
                        <xsl:if test="not(position() = 1) and not(position() gt $examples-maximum)">
                           <xsl:text>, </xsl:text>
                        </xsl:if>
                        <xsl:if test="position() le $examples-maximum">
                           <xsl:value-of select="current-grouping-key()"/>
                           <xsl:value-of select="concat(' (', string(count(current-group())), ')')"/>
                        </xsl:if>
                     </xsl:for-each-group>
                  </xsl:variable>
                  <xsl:copy-of select="tan:error('tok01', string-join($this-message, ''))"/>
               </xsl:if>
            </xsl:for-each>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <xsl:template match="tan:rename | tan:reassign" mode="class-2-expansion-normal">
      <xsl:param name="dependencies" tunnel="yes" as="document-node()*"/>
      <xsl:variable name="error-ids-to-flag" select="('cl217')"/>
      <xsl:variable name="dependency-actions" select="tan:get-via-q-ref(@q, $dependencies)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:copy-of select="$dependency-actions/parent::tan:error[@xml:id = $error-ids-to-flag]"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>
   
   

   <!-- VERBOSE EXPANSION -->
   
   <xsl:template match="tan:source" mode="class-2-expansion-verbose">
      <xsl:variable name="this-first-da" select="tan:get-1st-doc(.)"/>
      <xsl:variable name="this-first-da-master" select="tan:get-1st-doc($this-first-da/*/tan:head/tan:master-location[1])"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="not(deep-equal($this-first-da/*, $this-first-da-master/*))">
            <xsl:copy-of select="tan:error('tan18', 'Source differs from the version found at the master location')"/>
            <xsl:apply-templates mode="#current"/>
         </xsl:if>
      </xsl:copy>
   </xsl:template>

</xsl:stylesheet>
