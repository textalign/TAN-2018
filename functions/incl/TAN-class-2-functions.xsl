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

   <xsl:template match="tan:source | tan:morphology[not(@attr)]" mode="core-expansion-terse">
      <!-- dependencies must be evaluated at the terse stage -->
      <xsl:apply-templates select="." mode="check-referred-doc"/>
   </xsl:template>
   <xsl:template match="tan:source[not(@xml:id)]" mode="core-expansion-terse">
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:attribute name="xml:id" select="count(preceding-sibling::tan:source) + 1"/>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
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
      <xsl:param name="this-tan-type" tunnel="yes"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="$this-tan-type = 'TAN-A-lm'">
            <src>1</src>
         </xsl:if>
         <xsl:if test="not(exists(@pos))">
            <pos attr="">1</pos>
         </xsl:if>
         <xsl:if test="not(exists(@val))">
            <val attr="">^.+$</val>
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   <!-- next several items below slated to be moved to TAN-class-1-functions.xsl, but kept here to be able to look at comparable functions in different windows -->
   <xsl:template match="tan:body" mode="reset-hierarchy">
      <!--<xsl:param name="test" tunnel="yes" select="false()"/>-->
      <xsl:variable name="these-misfits" as="element()*">
         <xsl:apply-templates select="tan:div" mode="only-misfit-divs"/>
      </xsl:variable>
      <xsl:choose>
         <xsl:when test="exists($these-misfits)">
            <xsl:variable name="these-misfit-divs-and-anchors" as="element()*">
               <xsl:apply-templates select="tan:div" mode="only-misfit-divs-and-anchors">
                  <xsl:with-param name="misfits" select="$these-misfits" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:variable name="these-misfits-and-anchors-qs" select="$these-misfit-divs-and-anchors/@q"/>
            <xsl:variable name="these-misfit-divs-and-anchors-placed-in-hierarchy" as="element()*">
               <xsl:apply-templates select="$these-misfit-divs-and-anchors"
                  mode="reconstruct-div-hierarchy"/>
            </xsl:variable>
            <xsl:variable name="these-divs-without-misfits">
               <xsl:apply-templates mode="divs-excluding-what-qs">
                  <xsl:with-param name="qs-to-exclude" select="$these-misfits/@q" tunnel="yes"/>
               </xsl:apply-templates>
            </xsl:variable>
            <xsl:variable name="this-body-before-synthesis" as="element()">
               <body>
                  <xsl:copy-of select="@*"/>
                  <xsl:copy-of select="node() except tan:div"/>
                  <xsl:copy-of select="$these-divs-without-misfits"/>
                  <xsl:copy-of select="$these-misfit-divs-and-anchors-placed-in-hierarchy"/>
               </body>
            </xsl:variable>
            <!-- diagnostics, results -->
            <!--<test0><xsl:copy-of select="$these-misfits"/></test0>-->
            <!--<test1><xsl:copy-of select="$these-misfit-divs-and-anchors"/></test1>-->
            <!--<test2><xsl:copy-of select="$these-divs-without-misfits"/></test2>-->
            <!--<test3><xsl:copy-of select="$these-misfit-divs-and-anchors-placed-in-hierarchy"/></test3>-->
            <!--<xsl:copy-of select="$this-body-before-synthesis"/>-->
            <xsl:copy-of
               select="tan:merge-divs($this-body-before-synthesis, false(), 'q', true())"
            />
         </xsl:when>
         <xsl:otherwise>
            <xsl:copy-of select="."/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template match="tan:div" mode="only-misfit-divs">
      <xsl:variable name="parental-refs" select="../tan:ref/text()"/>
      <xsl:variable name="stated-parental-refs"
         select="
            for $i in tan:ref
            return
               string-join($i/tan:n[position() lt last()], $separator-hierarchy)"/>
      <xsl:choose>
         <!-- ignore 1st-level <div>s that are children of <body> -->
         <xsl:when
            test="
               string-length($parental-refs[1]) lt 1 and (some $i in $stated-parental-refs
                  satisfies string-length($i) lt 1)">
            <xsl:apply-templates select="tan:div" mode="#current"/>
         </xsl:when>
         <xsl:when
            test="
               some $i in $stated-parental-refs
                  satisfies not($i = $parental-refs)">
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:when>
         <xsl:otherwise>
            <xsl:apply-templates select="tan:div" mode="#current"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="tan:div" mode="only-misfit-divs-and-anchors">
      <xsl:param name="misfits" tunnel="yes" as="element()*"/>
      <xsl:if
         test="tan:ref/text() = $misfits/tan:ref/text()">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="no-misfit-divs-or-anchors">
               <xsl:with-param name="misfits" select="$misfits" tunnel="yes"/>
            </xsl:apply-templates>
         </xsl:copy>
      </xsl:if>
      <!-- we keep applying templates on the content, even if its is a misfit or anchor, so as to fetch any descendant misfits -->
      <xsl:apply-templates select="tan:div" mode="#current"/>
   </xsl:template>
   <xsl:template match="tan:div" mode="no-misfit-divs-or-anchors">
      <xsl:param name="misfits" tunnel="yes" as="element()*"/>
      <xsl:if
         test="not(tan:ref/text() = $misfits/tan:ref/text())">
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
         </xsl:copy>
      </xsl:if>
   </xsl:template>

   <xsl:template match="tan:div" mode="reconstruct-div-hierarchy">
      <xsl:param name="depth-so-far" as="xs:integer" select="1"/>
      <xsl:choose>
         <xsl:when test="count(tan:ref[1]/tan:n) le $depth-so-far">
            <xsl:copy-of select="."/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:variable name="these-ns" select="tan:ref[1]/tan:n[position() le $depth-so-far]"/>
            <div>
               <ref><xsl:value-of select="string-join($these-ns, $separator-hierarchy)"/>
                  <xsl:copy-of select="$these-ns"/></ref>
               <xsl:apply-templates select="." mode="#current">
                  <xsl:with-param name="depth-so-far" select="$depth-so-far + 1"/>
               </xsl:apply-templates>
            </div>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   
   <xsl:template match="tan:div" mode="divs-excluding-what-qs">
      <xsl:param name="qs-to-exclude" tunnel="yes"/>
      <xsl:variable name="exclude-this" select="exists(@q) and (@q = $qs-to-exclude)"/>
      <xsl:choose>
         <xsl:when test="(count($qs-to-exclude) lt 1)">
            <xsl:copy-of select="."/>
         </xsl:when>
         <xsl:when test="$exclude-this"/>
         <xsl:otherwise>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:apply-templates mode="#current"/>
            </xsl:copy>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <xsl:template
      match="tan:object[(tan:src, tan:work)] | tan:subject[(tan:src, tan:work)] | tan:tok[@ref] | tan:from | tan:tok/tan:to | tan:div-ref | tan:alter/tan:*"
      mode="class-2-expansion-terse">
      <xsl:param name="dependencies" as="document-node()*" tunnel="yes"/>
      <xsl:variable name="is-alter-action" select="exists(ancestor::tan:alter)"/>
      <xsl:variable name="dependency-actions"
         select="
            if ($is-alter-action) then
               tan:get-via-q-ref(@q, $dependencies)
            else
               ()"/>
      <xsl:variable name="this-element" select="."/>
      <xsl:variable name="this-val" select="(tan:val, '^.+$')[1]"/>
      <xsl:variable name="unprocessed-skips-renames-and-reassigns" as="element()*">
         <xsl:for-each
            select="self::tan:skip/tan:src, self::tan:rename/tan:src, self::tan:reassign/tan:src">
            <xsl:variable name="this-src" select="text()"/>
            <xsl:for-each
               select="$this-element/(tan:div-type, tan:n, tan:ref, tan:range/(tan:n, tan:ref), tan:tok/tan:ref)">
               <xsl:variable name="this-item-text" select="text()"/>
               <xsl:variable name="this-item-name" select="name(.)"/>
               <xsl:variable name="matching-actions"
                  select="
                     $dependency-actions[ancestor::tan:TAN-T/@src = $this-src][parent::tan:n/tan:orig-n = $this-item-text
                     or tan:div-type = $this-element/tan:div-type
                     or parent::tan:ref/tan:orig-ref/text() = $this-item-text
                     or self::tan:reassign]"/>
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
      </xsl:variable>
      <xsl:variable name="these-work-refs" select="tan:work, (parent::tan:object, parent::tan:subject, parent::tan:locus)/tan:work,
         (parent::tan:group, parent::tan:tok)/parent::*/tan:work"/>
      <xsl:variable name="these-src-refs"
         select="
            (tan:src, ancestor::tan:alter/(self::*, tan:where)/tan:src,
            (parent::tan:object, parent::tan:subject, parent::tan:locus)/tan:src,
            (parent::tan:group, parent::tan:tok)/parent::*/tan:src),
            (root()/tan:TAN-A-div/tan:head/tan:definitions/tan:group[tan:work/@src = $these-work-refs]/tan:work/@src)"
      />
      <xsl:variable name="these-div-refs" as="element()*">
         <xsl:for-each select="$these-src-refs">
            <xsl:variable name="this-src" select="."/>
            <!-- In the case of alter actions, we fetch divs that go by the old names -->
            <xsl:for-each
               select="
                  if ($is-alter-action) then
                     $this-element/(self::tan:tok/tan:ref, tan:tok/tan:ref, parent::tan:tok/tan:ref)
                  else
                     $this-element/(self::tan:tok, parent::tan:tok, tan:range)/tan:ref">
               <xsl:variable name="this-ref-text" select="text()"/>
               <xsl:variable name="that-div"
                  select="
                     for $i in $dependencies[root()/*/@src = $this-src]
                     return
                        if ($is-alter-action) then
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
            <xsl:variable name="tokens-picked" select="tan:div/tan:tok[tan:matches(., $this-val)]"/>
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
         <xsl:if test="tan:val and not(exists($these-div-refs/tan:div/tan:tok))">
            <!-- Report attempts to tokenize a non-leaf div -->
            <xsl:copy-of
               select="tan:error('tok02', concat('try: ', string-join($these-div-refs//tan:div[not(tan:div)]/tan:ref/text(), ', ')))"
            />
         </xsl:if>
         <xsl:if test="exists($missing-div-refs) and not($is-alter-action)">
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
                  select="concat($this-val, ' not found at position(s) ', string-join(distinct-values($missing-tok-refs/tan:pos), ', '), ': ')"/>
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
            test="(exists($missing-tok-refs) and not(exists($dependency-actions))) or exists(tan:pos/@help) or exists(tan:val/@help)">
            <xsl:variable name="tok-opts" as="element()*">
               <try>try tokens (positions): </try>
               <xsl:for-each-group select="$these-div-refs" group-by="tan:src">
                  <group>
                     <src><xsl:value-of select="current-grouping-key()"/>: </src>
                     <xsl:for-each select="current-group()">
                        <group>
                           <ref><xsl:value-of select="tan:ref"/>: </ref>
                           <xsl:for-each-group select="tan:div/tan:tok" group-by=".">
                              <xsl:sort select="tan:matches(., replace($this-val, '^^(.+)\$$', '$1'))"
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
                  select="concat('characters for ', $this-val, ' not found at position(s) ', string-join(distinct-values($missing-char-refs/tan:pos[xs:integer(.) gt 0]), ', '), ': ')"/>
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
            test="exists(tan:error[@xml:id = 'tok01']) or exists(tan:pos/@help) or exists(tan:val/@help)">
            <!-- placeholder for providing help on the r ight tok -->
         </xsl:if>
         <xsl:apply-templates mode="#current"/>
      </xsl:copy>
   </xsl:template>

   
   
   <xsl:template match="tan:tok[not(tan:tok-ref)][tan:val]" mode="class-2-expansion-normal">
      <!-- If there's no specific reference, it's pointing to tokens anywhere in the source -->
      <!--<xsl:param name="dependencies" tunnel="yes"/>-->
      <xsl:param name="all-tokens" tunnel="yes"/>
      <xsl:variable name="this-val" select="tan:val"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:if test="exists($all-tokens)">
            <xsl:for-each select="tan:src">
               <xsl:variable name="this-src" select="."/>
               <xsl:variable name="source-tokens"
                  select="$all-tokens[root()/tan:TAN-T/@src = $this-src]"/>
               <xsl:variable name="first-source-match" select="$all-tokens[tan:matches(., $this-val)][1]"/>
               <xsl:if test="not(exists($first-source-match))">
                  <xsl:variable name="examples-maximum" select="50"/>
                  <xsl:variable name="val-adjusted" select="replace($this-val, '^\^(.+)\$$', '$1')"/>
                  <!--<xsl:variable name="near-matches" select="$dependencies/tan:TAN-T/tan:body//tan:tok[tan:matches(., $val-adjusted)]"/>-->
                  <xsl:variable name="this-message" as="xs:string*">
                     <xsl:text>try: </xsl:text>
                     <xsl:for-each-group select="$all-tokens" group-by=".">
                        <xsl:sort select="tan:matches(., $val-adjusted)" order="descending"/>
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
