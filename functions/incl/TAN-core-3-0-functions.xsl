<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="tag:textalign.net,2015:ns" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
   xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:math="http://www.w3.org/2005/xpath-functions/math"
   xmlns:functx="http://www.functx.com" xmlns:sch="http://purl.oclc.org/dsdl/schematron"
   exclude-result-prefixes="#all" version="3.0">
   <!-- XSLT 3.0 functions for TAN -->
   <!-- These are functions that otherwise would be part of the core TAN function library, but are written in 3.0, before the
   rest of the function library has been upgraded to v. 3.0 -->

   <xsl:function name="tan:longest-ascending-subsequence" as="element()*">
      <!-- Input: a sequence of integers or sequences of integers (or items with child elements that can be cast into integers) -->
      <!-- Output: a sequence of elements, each with a text node of an integer greater than the preceding element text node, 
         and the entire sequence of integers in the text nodes being one of the longet ascending subsequences of the input 
         elements. Each output element has a @pos with an integer identifying the position of the input item that has been 
         chosen (to handle repetitions) -->
      <!-- Although this function claims by its name to find the longest subsequence, in the interests of efficiency, it modifies 
         the so-called Patience method of finding the string, which may return only a long string, not the longest possible string. 
         Such an approach allows the number of operations to be directly proportionate to the number of input values; to
         backtrack would be proportionate to that number squared. The routine does "remember" gaps. If adding a number
         to the sequence would require a jumps, the sequence is created, along with a copy of the pre-gapped sequence, in case
         it can resume later. 
      --> 
      <!-- The input is a sequence of elements, not integers, because this function has been written to support 
         tan:collate-pairs-of-sequences(), which requires choice options. That is, you may have a situation
         where you are comparing two sequences, either of which may have values that repeat, e.g., (a, b, c, b, d) and 
         (c, b, d). The first sequence might get converted to integers 1-5. In finding a corresponding sequence of integers
         for the second set, b must be allowed to be either 2 or 4, i.e., (3, (2, 4), 5). These would ideally be expressed as arrays of
         integers, but this function serves an XSLT 2.0 library (where arrays are not recognized), and arrays are difficult to 
         construct in XSLT 3.0. -->
      <xsl:param name="integer-sequence" as="item()*"/>
      <xsl:variable name="sequence-count" select="count($integer-sequence)"/>
      <xsl:variable name="first-item" select="$integer-sequence[1]"/>
      
      <xsl:variable name="subsequences" as="element()*">
         <xsl:iterate select="$integer-sequence">
            <xsl:param name="subsequences-so-far" as="element()*"/>
            <xsl:variable name="this-pos" select="position()"/>
            <xsl:variable name="these-ints" as="xs:integer*">
               <xsl:choose>
                  <!-- If the item is castable as a single integer, do so -->
                  <xsl:when test=". castable as xs:integer">
                     <xsl:sequence select="xs:integer(.)"/>
                  </xsl:when>
                  <!-- If the item's children are castable as a sequence of integers, do so-->
                  <xsl:when
                     test="
                        every $i in *
                           satisfies $i castable as xs:integer">
                     <xsl:sequence
                        select="
                           for $i in *
                           return
                              xs:integer($i)"
                     />
                  </xsl:when>
                  <!-- Otherwise we don't know what kind of input is being given, and the item is skipped. -->
                  <xsl:otherwise>
                     <xsl:message
                        select="'Cannot interpret the following as an integer or sequence of integers: ' || ."
                     />
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:variable>
            <!-- Look at the sequences so far and find those whose first (i.e., reversed last) value is less than
            the current value -->
            <xsl:variable name="eligible-subsequences"
               select="$subsequences-so-far[xs:integer(tan:val[1]) lt max($these-ints)][not(@before) or (xs:integer(@before) gt min($these-ints))]"/>
            <xsl:variable name="new-subsequences" as="element()*">
               <xsl:for-each select="$these-ints">
                  <!-- Iterate over each of the integers in the current item and build new sequences out of the
                  eligible ones. -->
                  <xsl:variable name="this-int" select="."/>
                  <!-- Find within the eligible subsequences (1) those that are gapped (marked by @before) and the integer 
                     precedes where the gap was, (2) the standard <seq> that -->
                  <xsl:variable name="these-eligible-subsequences" select="$eligible-subsequences[xs:integer(tan:val[1]) lt $this-int][not(@before) 
                     or (xs:integer(@before) gt $this-int)]"/>
                  <xsl:for-each select="$these-eligible-subsequences">
                     <xsl:sort select="count(*)" order="descending"/>
                     <xsl:variable name="this-subsequence-last-int" select="xs:integer(tan:val[1])"/>
                     <!-- Retain as a default only the longest new subsequence -->
                     <xsl:if test="position() eq 1">
                        <xsl:copy>
                           <val pos="{$this-pos}">
                              <xsl:value-of select="$this-int"/>
                           </val>
                           <xsl:copy-of select="*"/>
                        </xsl:copy>
                        <!-- If there's a gap in the sequence, "remember" the sequence before the gap -->
                        <xsl:if test="$this-int gt ($this-subsequence-last-int + 1)">
                           <gap before="{$this-int}">
                              <xsl:copy-of select="*"/>
                           </gap>
                        </xsl:if>
                     </xsl:if>
                  </xsl:for-each>
                  <xsl:if test="not(exists($these-eligible-subsequences))">
                     <!-- If there's no match, let the integer start a new subsequence -->
                     <seq>
                        <val pos="{$this-pos}">
                           <xsl:value-of select="."/>
                        </val>
                     </seq>
                  </xsl:if>
               </xsl:for-each>
               <xsl:copy-of select="$subsequences-so-far except $eligible-subsequences"/>
            </xsl:variable>
            
            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'Diagnostics on, tan:longest-ascending-subsequence(), building $subsequences'"/>
               <xsl:message select="'Iteration number: ', $this-pos"/>
               <xsl:message select="'These integers: ', $these-ints"/>
               <xsl:message
                  select="
                     'Eligible subsequences: ',
                     string-join(for $i in $eligible-subsequences
                     return
                        string-join((name($i), name($i/@before), $i/(@before, *)), ' '), '; ')"
               />
               <xsl:message
                  select="
                     'New subsequences: ',
                     string-join(for $i in $new-subsequences
                     return
                        string-join((name($i), name($i/@before), $i/(@before, *)), ' '), '; ')"
               />
            </xsl:if>
            
            <xsl:if test="position() eq ($sequence-count)">
               <xsl:copy-of select="$new-subsequences"/>
            </xsl:if>
            <xsl:next-iteration>
               <xsl:with-param name="subsequences-so-far" select="$new-subsequences"/>
            </xsl:next-iteration>
         </xsl:iterate>
      </xsl:variable>
      
      <!-- The longest subsequence might not be at the top, so we re-sort, then
      return a reversal of the children (because the subsequence was built in
      reverse). -->
      <xsl:for-each select="$subsequences">
         <xsl:sort select="count(*)" order="descending"/>
         <xsl:if test="position() eq 1">
            <xsl:for-each select="reverse(*)">
               <xsl:copy-of select="."/>
            </xsl:for-each>
         </xsl:if>
      </xsl:for-each>
   </xsl:function>
   
   
   <!-- STRING 3.0 FUNCTIONS -->
   
   <xsl:function name="tan:diff-to-collation" as="element()">
      <!-- Input: any single output of diff, two string for the labels of diff strings a and b -->
      <!-- Output: a <collation> with the data prepped for merging with other collations -->
      <!-- This function was written to support the XSLT 3.0 version of tan:collate() -->
      <xsl:param name="diff-output" as="element()?"/>
      <xsl:param name="diff-text-a-label" as="xs:string?"/>
      <xsl:param name="diff-text-b-label" as="xs:string?"/>
      <collation>
         <witness id="{$diff-text-a-label}"/>
         <witness id="{$diff-text-b-label}"/>
         <xsl:iterate select="$diff-output/*">
            <xsl:param name="next-a-pos" select="1"/>
            <xsl:param name="next-b-pos" select="1"/>
            
            <xsl:variable name="this-length" select="string-length(.)"/>
            <xsl:variable name="this-a-length"
               select="
                  if (self::tan:a or self::tan:common) then
                     $this-length
                  else
                     0"
            />
            <xsl:variable name="this-b-length"
               select="
                  if (self::tan:b or self::tan:common) then
                     $this-length
                  else
                     0"
            />
            
            <xsl:choose>
               <!-- We leave a marker for both witnesses in every <a> or <b>, but marking one
               as <wit> and another as <x>. This will facilitate the grouping of collations. -->
               <xsl:when test="self::tan:a">
                  <u>
                     <txt>
                        <xsl:value-of select="."/>
                     </txt>
                     <wit ref="{$diff-text-a-label}" pos="{$next-a-pos}"/>
                     <x ref="{$diff-text-b-label}" pos="{$next-b-pos}"/>
                  </u>
               </xsl:when>
               <xsl:when test="self::tan:b">
                  <u>
                     <txt>
                        <xsl:value-of select="."/>
                     </txt>
                     <x ref="{$diff-text-a-label}" pos="{$next-a-pos}"/>
                     <wit ref="{$diff-text-b-label}" pos="{$next-b-pos}"/>
                  </u>
               </xsl:when>
               <xsl:when test="self::tan:common">
                  <c>
                     <txt>
                        <xsl:value-of select="."/>
                     </txt>
                     <wit ref="{$diff-text-a-label}" pos="{$next-a-pos}"/>
                     <wit ref="{$diff-text-b-label}" pos="{$next-b-pos}"/>
                  </c>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:message select="'Unclear how to process ' || name(.)"/>
               </xsl:otherwise>
            </xsl:choose>
            <xsl:next-iteration>
               <xsl:with-param name="next-a-pos" select="$next-a-pos + $this-a-length"/>
               <xsl:with-param name="next-b-pos" select="$next-b-pos + $this-b-length"/>
            </xsl:next-iteration>
         </xsl:iterate>
      </collation>
   </xsl:function>
   
   <xsl:function name="tan:collation-to-strings" as="element()*">
      <!-- Input: any output from tan:collate (version for XSLT 3.0) -->
      <!-- Output: a sequence of <witness id="">[ORIGINAL STRING] -->
      <!-- This function was written to reverse, and therefore test the integrity of, the output of tan:collate() -->
      <xsl:param name="tan-collate-output" as="element()?"/>
      <xsl:apply-templates select="$tan-collate-output/tan:witness" mode="collation-to-strings"/>
   </xsl:function>
   
   <xsl:template match="tan:witness" mode="collation-to-strings">
      <xsl:variable name="this-id" select="@id"/>
      <xsl:variable name="text-nodes" select="../*[tan:wit/@ref = $this-id]"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:value-of select="string-join($text-nodes/tan:txt)"/>
      </xsl:copy>
      <xsl:iterate select="$text-nodes">
         <xsl:param name="next-pos" select="1"/>
         <xsl:variable name="this-pos" select="tan:wit[@ref = $this-id]/@pos"/>
         <xsl:variable name="this-length" select="string-length(tan:txt)"/>
         <xsl:if test="not($next-pos = $this-pos)">
            <xsl:message select="'In text ' || $this-id || ', next position expected was ', $next-pos, ' but stated @pos is ' || $this-pos || '. See text fragment: ' || tan:txt"/>
         </xsl:if>
         <xsl:next-iteration>
            <xsl:with-param name="next-pos" select="$next-pos + $this-length"/>
         </xsl:next-iteration>
      </xsl:iterate>
   </xsl:template>
   
   
   <xsl:function name="tan:collate" as="element()?">
      <!-- 3-parameter version of fuller one, below -->
      <xsl:param name="strings-to-collate" as="xs:string*"/>
      <xsl:param name="string-labels" as="xs:string*"/>
      <xsl:param name="preoptimize-string-order" as="xs:boolean"/>
      <xsl:sequence
         select="tan:collate($strings-to-collate, $string-labels, $preoptimize-string-order, true(), true())"
      />
   </xsl:function>
   
   
   <xsl:function name="tan:collate" as="element()?">
      <!-- Input: a sequence of strings to be collated; a sequence of strings that label each string; a boolean
      indicating whether the sequence of input strings should be optimized; a boolean indicating whether
      the results of tan:diff() should be processed and weighed; a boolean indicating whether the collation 
      should be cleaned up. -->
      <!-- Output: a <collation> with (1) one <witness> per string (and if the last parameter is true, then a 
         sequence of children <commonality>s, signifying how close that string is with every other, and (2)
         a sequence of <c>s and <u>s, each with a <txt> and one or more <wit ref="" pos=""/>, indicating which
         string witness attests to the [c]ommon or [u]nique reading, and what position in that string the 
         particular text fragment starts at. -->
      <!-- If there are not enough labels (2nd parameter) for the input strings, the numerical position of 
      the input string will be used as the string label / witness id. -->
      <!-- If the third parameter is true, then tan:diff() will be performed against each pair of strings. Each
      diff output will be weighed by closeness of the two texts, and sorted accordingly. The results of this 
      operation will be stored in collation/witness/commonality. This requires (n-1)! operations, so should 
      be efficient for a few input strings, but will grow progressively longer according to the number and 
      size of the input strings. Preoptimizing strings will likely produces greater congruence in the <u>
      fragments. -->
      <!-- If the last parameter is true, then cleanup will not be performed. This parameter was introduced
      because the cleanup process itself invokes tan:collate() and one does not want to get into an endless 
      loop because of a mishmash of differences that can never be reconciled or brought closer together. -->
      <!-- This version of tan:collate was written in XSLT 3.0 to take advantage of xsl:iterate, and has an
      arity of 3 and 5 parameters to distinguish it from its XSLT 2.0 predecessors, which used a different approach 
      to collation. Tests comparing the two versions of tan:collate() may be profitable. -->
      <!-- Changes in output from previous version of tan:collate():
          - @w is now <wit> with @ref and @pos
          - the text node of <u> or <c> is now wrapped in <txt>
          - @length is ignored (the value is easily calculated)
        With these changes, any witness can be easily reconstructed with the XPath expression 
        tan:collation/()
      -->
      <xsl:param name="strings-to-collate" as="xs:string*"/>
      <xsl:param name="string-labels" as="xs:string*"/>
      <xsl:param name="preoptimize-string-order" as="xs:boolean"/>
      <xsl:param name="adjust-diffs-during-preoptimization" as="xs:boolean"/>
      <xsl:param name="clean-up-collation" as="xs:boolean"/>

      <xsl:variable name="string-count" select="count($strings-to-collate)"/>
      <xsl:variable name="string-labels-norm" as="xs:string*"
         select="
            for $i in (1 to $string-count)
            return
               ($string-labels[$i], string($i))[1]"/>


      <xsl:variable name="all-diffs" as="element()*">
         <xsl:if test="$preoptimize-string-order">
            <xsl:for-each select="$string-labels-norm[position() gt 1]">
               <xsl:variable name="text1" select="."/>
               <xsl:variable name="this-pos" select="position() + 1"/>
               <xsl:for-each select="$string-labels-norm[position() lt $this-pos]">
                  <xsl:variable name="text2" select="."/>
                  <xsl:variable name="that-pos" select="position()"/>
                  <xsl:variable name="this-diff"
                     select="tan:diff($strings-to-collate[$that-pos], $strings-to-collate[$this-pos], false())"/>
                  <xsl:variable name="this-diff-adjusted"
                     select="
                        if ($adjust-diffs-during-preoptimization) then
                           tan:adjust-diff($this-diff)
                        else
                           $this-diff"/>
                  <diff a="{$text2}" b="{$text1}">
                     <xsl:copy-of select="$this-diff-adjusted/*"/>
                  </diff>
               </xsl:for-each>
            </xsl:for-each>
         </xsl:if>
      </xsl:variable>

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

      <xsl:variable name="string-labels-re-sorted"
         select="
            if ($preoptimize-string-order) then
               distinct-values(for $i in $diffs-sorted
               return
                  ($i/@a, $i/@b))
            else
               $string-labels-norm"/>

      <xsl:variable name="strings-re-sorted"
         select="
            if ($preoptimize-string-order) then
               (for $i in $string-labels-re-sorted,
                  $j in index-of($string-labels-norm, $i)
               return
                  $strings-to-collate[$j])
            else
               $strings-to-collate"/>

      <xsl:variable name="first-diff"
         select="tan:diff($strings-re-sorted[1], $strings-re-sorted[2], false())"/>
      <xsl:variable name="first-diff-adjusted"
         select="
            if ($adjust-diffs-during-preoptimization) then
               tan:adjust-diff($first-diff)
            else
               $first-diff"/>
      <xsl:variable name="first-diff-collated"
         select="tan:diff-to-collation($first-diff-adjusted, $string-labels-re-sorted[1], $string-labels-re-sorted[2])"/>

      <xsl:variable name="diagnostics-on" select="string-length($strings-re-sorted[2]) lt 1"/>
      <xsl:if test="$diagnostics-on">
         <xsl:message select="'Diagnostics on, 2020 version of tan:collate()'"/>
         <xsl:message select="'String count: ', $string-count"/>
         <xsl:message
            select="'String labels re-sorted: ' || string-join($string-labels-re-sorted, ' ')"/>
         <xsl:message select="'First diff (adjusted): ' || serialize($first-diff-adjusted)"/>
         <xsl:message select="'First diff collated: ' || serialize($first-diff-collated)"/>
      </xsl:if>

      <xsl:variable name="fragmented-collation" as="element()*">
         <xsl:if test="not(exists($strings-re-sorted[3]))">
            <xsl:sequence select="$first-diff-collated"/>
         </xsl:if>
         <xsl:iterate select="$strings-re-sorted[position() gt 2]" exclude-result-prefixes="#all">
            <xsl:param name="collation-so-far" as="element()?" select="$first-diff-collated"/>
            <!-- The previous string is a text that links the previous collation and the diff that is about to be run. -->
            <xsl:param name="previous-string" as="xs:string?" select="$strings-re-sorted[2]"/>
            <xsl:param name="previous-string-label" as="xs:string?"
               select="$string-labels-re-sorted[2]"/>

            <xsl:variable name="iteration" select="position() + 2"/>
            <xsl:variable name="this-label" select="$string-labels-re-sorted[$iteration]"/>

            <xsl:variable name="this-diff" select="tan:diff($previous-string, ., false())"/>
            <xsl:variable name="this-diff-adjusted"
               select="
                  if ($adjust-diffs-during-preoptimization) then
                     tan:adjust-diff($this-diff)
                  else
                     $this-diff"/>
            <xsl:variable name="this-diff-collation"
               select="tan:diff-to-collation($this-diff-adjusted, $previous-string-label, $this-label)"/>

            <!-- The linking text is split in different ways, both in the base collation and the collation to add. Each of those
            should be splintered up so that every starting position for the linking in one collation is also reflected in the other.-->

            <xsl:variable name="pos-values-compared" as="element()">
               <pos-compared>
                  <xsl:for-each-group
                     select="$collation-so-far/*/*[@ref = $previous-string-label]/@pos, $this-diff-collation/*/*[@ref = $previous-string-label]/@pos"
                     group-by=".">
                     <xsl:sort select="number(current-grouping-key())"/>
                     <xsl:variable name="group-root-elements"
                        select="current-group()/ancestor::tan:collation"/>
                     <group pos="{current-grouping-key()}">
                        <xsl:if test="exists($group-root-elements[tan:witness/@id = $this-label])">
                           <new/>
                        </xsl:if>
                        <xsl:if
                           test="exists($group-root-elements[not(tan:witness/@id = $this-label)])">
                           <base/>
                        </xsl:if>
                     </group>
                  </xsl:for-each-group>
               </pos-compared>
            </xsl:variable>
            <xsl:variable name="pos-values-to-add" as="element()">
               <pos-to-add>
                  <in-base-collation>
                     <xsl:for-each-group select="$pos-values-compared/tan:group"
                        group-starting-with="*[tan:base]">
                        <xsl:if test="count(current-group()) gt 1">
                           <break>
                              <xsl:copy-of select="current-group()[1]/@*"/>
                              <xsl:for-each select="current-group()[position() gt 1]">
                                 <at-pos>
                                    <xsl:value-of select="@pos"/>
                                 </at-pos>
                              </xsl:for-each>
                           </break>
                        </xsl:if>
                     </xsl:for-each-group>
                  </in-base-collation>
                  <in-new-collation>
                     <xsl:for-each-group select="$pos-values-compared/tan:group"
                        group-starting-with="*[tan:new]">
                        <xsl:if test="count(current-group()) gt 1">
                           <break>
                              <xsl:copy-of select="current-group()[1]/@*"/>
                              <xsl:for-each select="current-group()[position() gt 1]">
                                 <at-pos>
                                    <xsl:value-of select="@pos"/>
                                 </at-pos>
                              </xsl:for-each>
                           </break>
                        </xsl:if>
                     </xsl:for-each-group>
                  </in-new-collation>

               </pos-to-add>
            </xsl:variable>

            <xsl:variable name="both-collations-splintered" as="element()*">
               <!-- The strategy here is to go through each collation and fragment any <c> or <u> where the linking
               text has text that should be broken up to match the other collation. -->
               <xsl:for-each select="$collation-so-far, $this-diff-collation">
                  <xsl:variable name="this-collation" select="."/>
                  <xsl:variable name="this-collation-position" select="position()"/>
                  <xsl:variable name="this-is-base-collation" select="$this-collation-position eq 1"/>
                  <xsl:copy>
                     <xsl:copy-of select="@*"/>
                     <xsl:attribute name="is-base" select="$this-is-base-collation"/>
                     <!-- group each <u> and <c> based on whether a child <x> or <wit> for the linking text has a matching position -->
                     <xsl:for-each-group select="*"
                        group-by="(*[@ref = $previous-string-label]/@pos, '-1')[1]">
                        <xsl:variable name="this-pos-val" select="current-grouping-key()"/>
                        <xsl:variable name="break-points"
                           select="$pos-values-to-add/*[$this-collation-position]/tan:break[@pos = $this-pos-val]/tan:at-pos"/>
                        <xsl:choose>
                           <xsl:when test="not(exists($break-points)) or ($this-pos-val = '0')">
                              <xsl:copy-of select="current-group()" copy-namespaces="no"/>
                           </xsl:when>
                           <xsl:otherwise>
                              <xsl:variable name="this-pos-int" select="xs:integer($this-pos-val)"/>
                              <xsl:variable name="these-break-point-ints"
                                 select="
                                    for $i in $break-points
                                    return
                                       xs:integer($i)"/>
                              <xsl:for-each select="current-group()">
                                 <xsl:variable name="this-element" select="."/>
                                 <xsl:variable name="this-text" select="tan:txt/text()"/>
                                 <xsl:variable name="this-text-length"
                                    select="string-length($this-text)"/>
                                 <xsl:variable name="next-segment-start-pos"
                                    select="$this-pos-int + $this-text-length"/>
                                 <xsl:choose>
                                    <xsl:when
                                       test="self::tan:c or (tan:wit/@ref = $previous-string-label)">
                                       <xsl:for-each
                                          select="($this-pos-int, $these-break-point-ints)">
                                          <xsl:variable name="this-position" select="position()"/>
                                          <xsl:variable name="this-new-pos-int" select="."/>
                                          <xsl:variable name="this-substring-start"
                                             select="$this-new-pos-int - $this-pos-int + 1"/>
                                          <xsl:variable name="next-start-pos"
                                             select="($these-break-point-ints, $next-segment-start-pos)[$this-position]"/>
                                          <xsl:variable name="this-substring-length"
                                             select="$next-start-pos - $this-new-pos-int"/>
                                          <xsl:variable name="this-text-portion"
                                             select="substring($this-text, $this-substring-start, $this-substring-length)"/>

                                          <xsl:if test="$diagnostics-on">
                                             <xsl:message
                                                select="'Starting splinter ', $this-position, 'at ', $this-new-pos-int"/>
                                             <xsl:message
                                                select="'Substring start: ', $this-substring-start"/>
                                             <xsl:message
                                                select="'Substring length: ', $this-substring-length"/>
                                             <xsl:message
                                                select="'Text portion: ' || $this-text-portion"/>
                                          </xsl:if>

                                          <xsl:element name="{name($this-element)}"
                                             namespace="tag:textalign.net,2015:ns">
                                             <xsl:copy-of select="$this-element/@*"/>
                                             <txt>
                                                <xsl:value-of select="$this-text-portion"/>
                                             </txt>
                                             <xsl:for-each select="$this-element/tan:wit">
                                                <xsl:variable name="this-diff-with-linking-text-pos"
                                                  select="$this-pos-int - xs:integer(@pos)"/>
                                                <xsl:copy copy-namespaces="no">
                                                  <xsl:copy-of select="@ref"/>
                                                  <xsl:attribute name="pos"
                                                  select="$this-new-pos-int - $this-diff-with-linking-text-pos"
                                                  />
                                                </xsl:copy>
                                             </xsl:for-each>
                                             <xsl:copy-of select="$this-element/tan:x"/>
                                          </xsl:element>
                                       </xsl:for-each>
                                    </xsl:when>
                                    <xsl:otherwise>
                                       <xsl:copy-of select="." copy-namespaces="no"/>
                                    </xsl:otherwise>
                                 </xsl:choose>
                              </xsl:for-each>
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:for-each-group>

                  </xsl:copy>
               </xsl:for-each>

            </xsl:variable>


            <xsl:variable name="new-base-collation" as="element()">
               <collation>
                  <!-- We copy the <witness> elements both for breadcrumbs and to provide the critical ligament
                  from one collation to the next. -->
                  <xsl:copy-of select="$collation-so-far/tan:witness"/>
                  <witness id="{$this-label}"/>

                  <!-- The collations we are gathering consist of elements that have identical sequences of @pos for the linking
                  text, and they are in numerical order. So by grouping by the linking text @pos, we are guaranteed groups 
                  made up of the following items from the two collations:
                       - From the base collation: zero or more <u>s without the linking text then either a <u> with the 
                          linking text as a witness or a <c> (also obviously with the linking text and every other version so far)
                       - From the new collation: zero or one <u> without the linking text then either a <u> with only 
                          the linking text as a witness (i.e., the new text is marked <x>) or a <c> (with both texts)
                  In both collations, the last group might not have the final <u>/<c> with the linking text. (The linking text
                  might finish before other texts do.)
                      The strategy is to group together from both collations (1) the initial <u>s that lack the linking text, then 
                  (2) the final zero, one, or two <u>/<c>s that have a linking text.
                      For #1, group if the text of a new <u> matches a text of a base <u>, retain that <u> but imprint a <wit> for
                      the new string, otherwise append the new <u> as-is. Any base <u>s that don't match should have an <x>
                      imprinted for the new text.
                      For #2, the following happens for the following possibilities:
                      Base <u> + new <u>                                       retain base <u>, imprinting an <x> for the new string
                      Base <c> + new <u>                                        convert base to <u>, imprinting an <x> for the new string
                      Base <u> + new <c>                                        retain base <u>, imprinting a <wit> for the new string
                      Base <c> + new <c>                                        retain base <c>, imprinting a <wit> for the new string
                              Note that the first two scenarios hold true simply if there is a new <u> (not attested in the new
                              string). Further, the final group might have:
                      No base element + no new element         nothing
                -->
                  <xsl:for-each-group select="$both-collations-splintered/*"
                     group-by="*[@ref = $previous-string-label]/@pos">
                     <!--<xsl:sort select="number(current-grouping-key())"/>-->

                     <!-- If from the groups about to be created the first of the two groups fails to have a reference to
                     the incoming text, we need a reference with an accurate @pos, so now we get all those that are 
                     available. -->
                     <xsl:variable name="refs-to-new-text"
                        select="current-group()/*[@ref = $this-label]"/>

                     <xsl:for-each-group select="current-group()"
                        group-by="exists(tan:wit[@ref = $previous-string-label])">
                        <!-- If indeed the group has a reading from the linking text, it should come second, and the sort places 
                           false before true -->
                        <xsl:sort select="current-grouping-key()"/>
                        <xsl:variable name="group-has-linking-text" select="current-grouping-key()"/>
                        <xsl:variable name="these-base-collation-items"
                           select="current-group()[ancestor::tan:collation/@is-base = true()]"/>
                        <!-- We know there will be no more than one of the following -->
                        <xsl:variable name="this-new-collation-item"
                           select="current-group() except $these-base-collation-items"/>
                        <xsl:choose>
                           <xsl:when test="count($this-new-collation-item) gt 1">
                              <xsl:message
                                 select="'Unexpected: more than one new collation item: ', serialize($this-new-collation-item)"
                              />
                           </xsl:when>

                           <xsl:when test="not($group-has-linking-text)">
                              <!-- scenario #1, the front end described above -->

                              <xsl:variable name="base-text-match-positions"
                                 select="
                                    for $i in (1 to count($these-base-collation-items))
                                    return
                                       (if ($these-base-collation-items[$i]/tan:txt = $this-new-collation-item/tan:txt) then
                                          $i
                                       else
                                          ())"/>
                              <xsl:for-each select="$these-base-collation-items">
                                 <xsl:copy>
                                    <xsl:copy-of select="node()"/>
                                    <xsl:choose>
                                       <!-- If the incoming new item matches the text of more than one base item, use only the last to
                                       make a copy of the new witness. -->
                                       <xsl:when
                                          test="position() = $base-text-match-positions[last()]">
                                          <xsl:copy-of select="$this-new-collation-item/tan:wit"/>
                                       </xsl:when>

                                       <xsl:when test="(exists($base-text-match-positions)) and (position() gt $base-text-match-positions[last()])">
                                          <!-- For items after the last match, we need to increase the @pos by however long the string was -->
                                          <x>
                                             <xsl:copy-of
                                                select="$this-new-collation-item/tan:wit/@ref"/>
                                             <xsl:attribute name="pos"
                                                select="number($this-new-collation-item/tan:wit/@pos) + string-length($this-new-collation-item/tan:txt)"
                                             />
                                          </x>
                                       </xsl:when>
                                       <xsl:otherwise>
                                          <x>
                                             <xsl:copy-of select="$refs-to-new-text[1]/@*"/>
                                          </x>
                                       </xsl:otherwise>
                                    </xsl:choose>
                                 </xsl:copy>
                              </xsl:for-each>
                              <xsl:if test="not(exists($base-text-match-positions))">
                                 <!-- If there are no unique elements in the base that have a matching text, then insert the new 
                                    unique element -->
                                 <xsl:copy-of select="$this-new-collation-item"/>
                              </xsl:if>
                           </xsl:when>

                           <!-- error checks betwen scenarios #1 and #2, and special situations -->

                           <xsl:when test="count($these-base-collation-items) gt 1">
                              <xsl:message
                                 select="'Unexpected: more than one base collation item: ', serialize($these-base-collation-items)"/>
                              <xsl:message
                                 select="'Accompanying new collation item: ', serialize($this-new-collation-item)"
                              />
                           </xsl:when>
                           <!-- If the current group is just a placeholder, but has no actual text, skip it -->
                           <xsl:when test="not(current-group()/tan:txt/text())"/>

                           <!-- The following two special situations, where <txt> is empty, have been replaced by the preceding <xsl:when> -->
                           <!--<xsl:when test="(count(current-group()) eq 1) and (name($this-new-collation-item) = 'c') and not($this-new-collation-item/tan:txt/text())">
                              <!-\- This is a case where we're at the end of the iteration, the base collation ends with a <u> because the
                              linking text isn't in it, and the new collation ends with a <c> that lacks text, because both the new text also lacks text 
                              at that place. In this case we can just drop the item altogether. If the next string goes beyond the limits, the
                              algorithm should still work normally. -\->
                              <!-\-<xsl:copy-of select="$this-new-collation-item"/>-\->
                           </xsl:when>-->
                           <!--<xsl:when test="(count(current-group()) eq 1) and (name($these-base-collation-items[1]) = 'c') and not(current-group()/tan:txt/text())">
                              <!-\- This is a case where we're at the end of the iteration, the base collation ends with a <c> that has an empty
                              <txt> and the new collation has nothing. In this case we can just drop the item altogether. -\->
                           </xsl:when>-->
                           <xsl:when test="count(current-group()) eq 1">
                              <xsl:message
                                 select="
                                    'We expect collation items to come in groups of two or more; only one item (' || (if (exists($this-new-collation-item)) then
                                       'new'
                                    else
                                       'base') || ' item, linking text ' || $previous-string-label || '): ', serialize(current-group())"
                              />
                           </xsl:when>

                           <!-- If we've gotten to this point, we're at the second group, the tail-end, scenario #2 described above -->
                           <xsl:when test="(name($this-new-collation-item) = 'u')">
                              <!-- If the new collation item is <u> then the reading is not attested in the new string, so no 
                                 matter whether the base element is a <c> or <u> it must be converted to <u>.-->
                              <u>
                                 <xsl:copy-of select="$these-base-collation-items/node()"/>
                                 <!-- This is a case where the new string is unattested, and that's reflected in the imprinted <x>,
                                 which by design is already present -->
                                 <xsl:copy-of select="$this-new-collation-item/tan:x"/>
                              </u>
                           </xsl:when>
                           <xsl:when
                              test="(name($these-base-collation-items) = 'u') and (name($this-new-collation-item) = 'c')">
                              <u>
                                 <xsl:copy-of select="$these-base-collation-items/node()"/>
                                 <wit>
                                    <xsl:copy-of select="$this-new-collation-item/tan:wit/@*"/>
                                 </wit>
                              </u>
                           </xsl:when>
                           <xsl:when
                              test="(name($these-base-collation-items) = 'c') and (name($this-new-collation-item) = 'c')">
                              <c>
                                 <xsl:copy-of select="$these-base-collation-items/node()"/>
                                 <wit>
                                    <xsl:copy-of select="$this-new-collation-item/tan:wit/@*"/>
                                 </wit>
                              </c>
                           </xsl:when>
                           <xsl:otherwise>
                              <!-- Not quite sure what's going on, so we bellow and moan -->
                              <xsl:message
                                 select="'We are not quite sure what to do with: ', serialize(current-group())"
                              />
                           </xsl:otherwise>
                        </xsl:choose>
                     </xsl:for-each-group>

                  </xsl:for-each-group>
               </collation>
            </xsl:variable>

            <xsl:variable name="diagnostics-on" select="false()"/>
            <xsl:variable name="imprint-diagnostics-on" select="true()"/>
            <xsl:if test="$diagnostics-on">
               <xsl:message select="'Iteration: ', $iteration"/>
               <xsl:message select="'Collation so far: ' || serialize($collation-so-far)"/>
               <xsl:message select="'Previous string: ' || $previous-string"/>
               <xsl:message select="'This string label: ' || $this-label"/>
               <xsl:message select="'This string: ' || ."/>
               <xsl:message select="'This diff (not adjusted): ' || serialize($this-diff)"/>
               <xsl:message select="'This diff (adjusted): ' || serialize($this-diff-adjusted)"/>
               <xsl:message select="'This diff as collation: ' || serialize($this-diff-collation)"/>
               <xsl:message
                  select="'Linking text @pos values compared: ' || serialize($pos-values-compared)"/>
               <xsl:message
                  select="'Places where the two collations should be broken up: ' || serialize($pos-values-to-add)"/>
               <xsl:message
                  select="'Base collation splintered: ' || serialize($both-collations-splintered[1])"/>
               <xsl:message
                  select="'New collation splintered: ' || serialize($both-collations-splintered[2])"/>
               <xsl:message select="'New base collation: ' || serialize($new-base-collation)"/>
            </xsl:if>

            <!-- The following diagnostic passage interjects feedback straight into the output, a more drastic method of
               feedback which may or may not be the best way to diagnose a problem. -->

            <xsl:if test="$diagnostics-on and $imprint-diagnostics-on">
               <diagnostics>
                  <previous-collation n="{position()}">
                     <added-witness>
                        <xsl:value-of select="$previous-string-label"/>
                     </added-witness>
                     <xsl:copy-of select="$collation-so-far"/>
                  </previous-collation>
                  <diff>
                     <xsl:copy-of select="$this-diff"/>
                  </diff>
                  <diff-adjusted>
                     <xsl:copy-of select="$this-diff-adjusted"/>
                  </diff-adjusted>
                  <base-coll-splintered>
                     <xsl:copy-of select="$both-collations-splintered[1]"/>
                  </base-coll-splintered>
                  <new-coll-splintered>
                     <xsl:copy-of select="$both-collations-splintered[2]"/>
                  </new-coll-splintered>
               </diagnostics>
            </xsl:if>

            <!-- If we're at the end of the iteration, we're done and we can return the last collation. -->
            <xsl:if test="$iteration eq $string-count">
               <xsl:copy-of select="$new-base-collation"/>
            </xsl:if>

            <xsl:next-iteration>
               <xsl:with-param name="collation-so-far" select="$new-base-collation"/>
               <xsl:with-param name="previous-string" select="."/>
               <xsl:with-param name="previous-string-label" select="$this-label"/>
            </xsl:next-iteration>
         </xsl:iterate>
      </xsl:variable>

      <xsl:variable name="cleaned-up-collation-pass-1" as="element()*">
         <xsl:apply-templates select="$fragmented-collation" mode="clean-up-collation-pass-1">
            <xsl:with-param name="allow-recollation" tunnel="yes" select="$clean-up-collation"/>
         </xsl:apply-templates>
      </xsl:variable>
      
      <xsl:variable name="cleaned-up-collation-pass-2" as="element()*">
         <xsl:choose>
            <xsl:when test="$clean-up-collation">
               <xsl:apply-templates select="$cleaned-up-collation-pass-1" mode="clean-up-collation-pass-2"
               />
            </xsl:when>
            <xsl:otherwise>
               <xsl:sequence select="$cleaned-up-collation-pass-1"/>
            </xsl:otherwise>
         </xsl:choose>
      </xsl:variable>

      <!-- output for the entire function -->
      <collation>
         <xsl:for-each select="$string-labels-re-sorted">
            <xsl:variable name="this-string-label" select="."/>
            <xsl:variable name="these-diffs" select="$diffs-sorted[(@a, @b) = $this-string-label]"/>
            <witness id="{.}">
               <xsl:for-each select="$these-diffs">
                  <xsl:variable name="that-string-label"
                     select="(@a, @b)[not(. = $this-string-label)]"/>
                  <commonality with="{$that-string-label}">
                     <xsl:value-of select="@commonality"/>
                  </commonality>
               </xsl:for-each>
            </witness>
         </xsl:for-each>
         <xsl:copy-of select="$cleaned-up-collation-pass-2/*"/>
      </collation>

      <xsl:variable name="check-output-integrity" as="xs:boolean" select="true()"/>
      <xsl:if test="$check-output-integrity">
         <xsl:for-each select="1 to count($string-labels-re-sorted)">
            <xsl:variable name="this-pos" select="."/>
            <xsl:variable name="this-label" select="$string-labels-re-sorted[$this-pos]"/>
            <xsl:variable name="this-input-string" select="$strings-re-sorted[$this-pos]"/>
            <xsl:variable name="this-output-string"
               select="string-join($cleaned-up-collation-pass-2/*[tan:wit/@ref = $this-label]/tan:txt)"
            />
            <xsl:if test="not($this-input-string eq $this-output-string)">
               <xsl:message
                  select="'Error in tan:collate(). String ' || $this-label || ' does not match output.'"/>
               <xsl:message
                  select="serialize(tan:diff($this-input-string, $this-output-string, false()))"/>
            </xsl:if>
         </xsl:for-each>
      </xsl:if>

   </xsl:function>
   
   <!-- <x> was just a placeholder that can easily be determined by the lack of a <wit>; <witness>
   is no longer needed because it has been reconstructed, perhaps with collation statistics. -->
   <xsl:template match="tan:x | tan:witness" mode="clean-up-collation-pass-1"/>
   <xsl:template match="tan:previous-collation | tan:diagnostics" mode="clean-up-collation-pass-1">
      <xsl:copy-of select="."/>
   </xsl:template>
   
   <xsl:template match="*[tan:u]" mode="clean-up-collation-pass-1">
      <xsl:param name="allow-recollation" select="true()" as="xs:boolean" tunnel="yes"/>
      <!-- A collation might have the following issues:
      1. nearby <u>s that have identical <txt> contents; the challenge is that such creatures are separated
      from each other by sibling <u>s that don't have identical <txt> contents.
      2. a total mishmash of <u>s that are difficult to read, and would be much easier to read if the collation
      routine was run on the fragments. -->
      <!-- Prior to this step, consecutive <u>s should have <wit>s that follow the order of the sources. After this step,
      that principle is no longer true. -->
      <xsl:variable name="witness-count" select="count(tan:witness)"/>
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each-group select="*" group-adjacent="name(.)">
            <xsl:choose>
               <xsl:when test="current-grouping-key() = 'u'">
                  <xsl:variable name="these-u-wits" select="current-group()/tan:wit"/>
                  <xsl:variable name="these-u-wit-refs" select="distinct-values($these-u-wits/@ref)"/>
                  <xsl:variable name="these-u-wit-counts"
                     select="
                        for $i in $these-u-wit-refs
                        return
                           count($these-u-wits[@ref = $i])"
                  />
                  <!-- (max($these-u-wit-counts) gt 1) and  -->
                  <!--<xsl:variable name="these-us-should-be-recollated"
                     select="(count($these-u-wit-refs) gt 2)"/>-->
                  <!--<xsl:variable name="these-us-should-be-recollated"
                     select="$allow-recollation and (max($these-u-wit-counts) gt 1) and (count($these-u-wit-refs) gt 2)"/>-->
                  <xsl:variable name="these-us-should-be-recollated"
                     select="$allow-recollation and (count($these-u-wit-refs) gt 2)"/>
                  <xsl:variable name="these-u-strings" as="xs:string*"
                     select="
                        for $i in $these-u-wit-refs
                        return
                           string-join(current-group()[tan:wit/@ref = $i]/tan:txt)"
                  />
                  <xsl:variable name="these-offsets" as="element()*">
                     <xsl:for-each select="$these-u-wit-refs">
                        <xsl:variable name="this-ref" select="."/>
                        <xsl:variable name="this-smallest-pos" select="($these-u-wits[@ref = $this-ref])[1]/@pos"/>
                        <offset ref="{$this-ref}" by="{$this-smallest-pos}"/>
                     </xsl:for-each>
                  </xsl:variable>
                  
                  
                  <xsl:variable name="diagnostics-on" select="false()"/>
                  <xsl:if test="$diagnostics-on">
                     <xsl:message select="'Diagnostics on, template mode clean-up-collation'"/>
                     <xsl:message select="'Allow recollation?', $allow-recollation"/>
                     <xsl:message
                        select="
                           'These u witness refs: (', count($these-u-wit-refs), '): ',
                           (for $i in $these-u-wit-refs
                           return
                              ($i || ' (pos ' || $these-u-wits[@ref = $i][1]/@pos || '); '))"
                     />
                     <xsl:message select="'These u witness counts: ', $these-u-wit-counts"/>
                     <xsl:message select="'These us should be recollated: ', $these-us-should-be-recollated"/>
                     <xsl:message select="'These u strings: ', (for $i in $these-u-strings return '[START]' || $i || '[END]  ')"/>
                  </xsl:if>
                  
                  <xsl:choose>
                     <xsl:when test="$these-us-should-be-recollated">
                        <xsl:variable name="these-us-recollated"
                           select="tan:collate($these-u-strings, $these-u-wit-refs, true(), true(), false())"
                           as="element()"/>
                        
                        <xsl:if test="$diagnostics-on">
                           <xsl:message select="'These us recollated: ', serialize($these-us-recollated)"/>
                        </xsl:if>
                        
                        <xsl:for-each select="$these-us-recollated/(* except tan:witness)">
                           <xsl:variable name="this-element-name"
                              select="
                                 if (count(tan:wit) eq $witness-count) then
                                    'c'
                                 else
                                    'u'"
                           />
                           <xsl:element name="{$this-element-name}">
                              <xsl:apply-templates select="* except tan:x" mode="add-collation-pos-offset">
                                 <xsl:with-param name="offsets" select="$these-offsets"/>
                              </xsl:apply-templates>
                           </xsl:element>
                        </xsl:for-each>
                     </xsl:when>
                     
                     <xsl:otherwise>
                        <xsl:variable name="these-u-groups" as="element()+">
                           <xsl:variable name="cg-count" select="count(current-group())"/>
                           <xsl:iterate select="current-group()">
                              <xsl:param name="items-to-group" as="element()*"/>
                              <xsl:variable name="this-item" select="."/>
                              <xsl:variable name="this-starts-new-group" select="$this-item/tan:wit/@ref = $items-to-group/tan:wit/@ref"/>
                              <xsl:variable name="new-item-groups"
                                 select="
                                 if ($this-starts-new-group) then
                                 $this-item
                                 else
                                 ($items-to-group, $this-item)"
                              />
                              <xsl:choose>
                                 <xsl:when test="(position() eq $cg-count) and $this-starts-new-group">
                                    <group>
                                       <xsl:copy-of select="$items-to-group"/>
                                    </group>
                                    <group>
                                       <xsl:copy-of select="$this-item"/>
                                    </group>
                                 </xsl:when>
                                 <xsl:when test="$this-starts-new-group">
                                    <group>
                                       <xsl:copy-of select="$items-to-group"/>
                                    </group>
                                 </xsl:when>
                                 <xsl:when test="(position() eq $cg-count)">
                                    <group>
                                       <xsl:copy-of select="$items-to-group"/>
                                       <xsl:copy-of select="$this-item"/>
                                    </group>
                                 </xsl:when>
                              </xsl:choose>
                              <xsl:next-iteration>
                                 <xsl:with-param name="items-to-group" select="$new-item-groups"/>
                              </xsl:next-iteration>
                           </xsl:iterate>
                        </xsl:variable>
                        
                        <xsl:if test="$diagnostics-on">
                           <xsl:message select="'These u groups: ', serialize($these-u-groups)"/>
                        </xsl:if>
                        
                        <xsl:for-each select="$these-u-groups">
                           <xsl:for-each-group select="*" group-by="tan:txt">
                              <u>
                                 <xsl:copy-of select="current-group()/@*"/>
                                 <xsl:copy-of select="current-group()[1]/tan:txt"/>
                                 <xsl:apply-templates select="current-group()/(* except tan:txt)" mode="#current"/>
                              </u>
                           </xsl:for-each-group> 
                        </xsl:for-each>
                     </xsl:otherwise>
                  </xsl:choose>
                  
               </xsl:when>
               <xsl:otherwise>
                  <xsl:apply-templates select="current-group()" mode="#current"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group> 
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="tan:wit" mode="add-collation-pos-offset">
      <xsl:param name="offsets" as="element()*"/>
      <xsl:variable name="this-ref" select="@ref"/>
      <xsl:variable name="this-pos" select="number(@pos)"/>
      <xsl:variable name="this-offset-pos" select="(number($offsets[@ref = $this-ref][1]/@by), 1)[1]"/>
      <xsl:copy>
         <xsl:copy-of select="@* except @pos"/>
         <xsl:attribute name="pos" select="$this-pos + $this-offset-pos - 1"/>
      </xsl:copy>
   </xsl:template>
   
   <xsl:template match="*[tan:u]" mode="clean-up-collation-pass-2">
      <!-- At the end of cleanup, there may be adjacent <c>s, which should be consolidated -->
      <xsl:copy>
         <xsl:copy-of select="@*"/>
         <xsl:for-each-group select="*" group-adjacent="name(.)">
            <xsl:choose>
               <xsl:when test="(current-grouping-key() eq 'c') and (count(current-group()) gt  1)">
                  <c>
                     <txt>
                        <xsl:value-of select="string-join(current-group()/tan:txt)"/>
                     </txt>
                     <xsl:copy-of select="current-group()[1]/tan:wit"/>
                  </c>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:copy-of select="current-group()"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group> 
      </xsl:copy>
   </xsl:template>
   
   
   
   <xsl:function name="tan:common-start-string" as="xs:string?">
      <!-- See full function below -->
      <xsl:param name="strings" as="xs:string*"/>
      <xsl:sequence select="tan:common-start-or-end-string($strings, true())"/>
   </xsl:function>
   
   <xsl:function name="tan:common-end-string" as="xs:string?">
      <!-- See full function below -->
      <xsl:param name="strings" as="xs:string*"/>
      <xsl:sequence select="tan:common-start-or-end-string($strings, false())"/>
   </xsl:function>
   
   <xsl:function name="tan:common-start-or-end-string" as="xs:string?">
      <!-- See full function below -->
      <xsl:param name="strings" as="xs:string*"/>
      <xsl:param name="find-common-start" as="xs:boolean"/>
      <xsl:variable name="string-count" select="count($strings)"/>
      <xsl:choose>
         <xsl:when test="$string-count lt 2">
            <xsl:sequence select="$strings"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:iterate select="$strings[position() gt 1]">
               <xsl:param name="common-so-far" as="xs:string*" select="$strings[1]"/>
               <xsl:variable name="this-css" select="tan:common-start-or-end-string(., $common-so-far, $find-common-start)"/>
               <xsl:choose>
                  <xsl:when test="string-length($this-css) lt 1">
                     <xsl:sequence select="$this-css"/>
                     <xsl:break/>
                  </xsl:when>
                  <xsl:when test="(position() = ($string-count - 1))">
                     <xsl:sequence select="$this-css"/>
                  </xsl:when>
                  <xsl:otherwise>
                     <xsl:next-iteration>
                        <xsl:with-param name="common-so-far" select="$this-css"/>
                     </xsl:next-iteration>
                  </xsl:otherwise>
               </xsl:choose>
            </xsl:iterate>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:function>
   
   <xsl:function name="tan:common-start-or-end-string" as="xs:string?">
      <!-- Input: two strings; a boolean -->
      <!-- Output: the longest string that can be formed by comparing a common end of both strings,
      the starting end if the boolean is true, otherwise the -->
      <xsl:param name="string-a" as="xs:string?"/>
      <xsl:param name="string-b" as="xs:string?"/>
      <xsl:param name="find-common-start" as="xs:boolean"/>
      <xsl:variable name="a-codepoints" as="xs:integer*"
         select="
            if ($find-common-start) then
               string-to-codepoints($string-a)
            else
               reverse(string-to-codepoints($string-a))"
      />
      <xsl:variable name="b-codepoints" as="xs:integer*"
         select="
            if ($find-common-start) then
               string-to-codepoints($string-b)
            else
               reverse(string-to-codepoints($string-b))"
      />
      <xsl:variable name="commonality" as="xs:integer*">
         <xsl:iterate select="$a-codepoints">
            <xsl:param name="codepoints-to-compare" select="$b-codepoints" as="xs:integer*"/>
            <xsl:variable name="this-a-point" select="."/>
            <xsl:variable name="this-b-point" select="$codepoints-to-compare[1]"/>
            <xsl:variable name="next-b-codepoints" select="$codepoints-to-compare[position() gt 1]"/>
            <xsl:variable name="this-is-match" select="$this-a-point eq $this-b-point"/>
            <xsl:if test="$this-is-match">
               <xsl:sequence select="$this-a-point"/>
            </xsl:if>
            <xsl:choose>
               <xsl:when test="not($this-is-match) or not(exists($codepoints-to-compare))">
                  <xsl:break/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:next-iteration>
                     <xsl:with-param name="codepoints-to-compare" select="$next-b-codepoints"/>
                  </xsl:next-iteration>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:iterate>
      </xsl:variable>
      
      <xsl:choose>
         <xsl:when test="$find-common-start">
            <xsl:value-of select="codepoints-to-string($commonality)"/>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="codepoints-to-string(reverse($commonality))"/>
         </xsl:otherwise>
      </xsl:choose>
      
   </xsl:function>
   
   
   <xsl:function name="tan:adjust-diff" as="element()*">
      <!-- Input: any output <diff>s from tan:diff() -->
      <!-- Output: the output adjusted, with <a> and <b>s adjusted if there are more optimal placements -->
      <xsl:param name="diff-output" as="element()*"/>
      <xsl:variable name="end-of-sequence" as="element()">
         <end-of-sequence/>
      </xsl:variable>
      <xsl:variable name="adjustment-1" as="element()?">
         <xsl:for-each select="$diff-output">
            <xsl:variable name="element-count" select="count(*)"/>
            <xsl:copy>
               <xsl:copy-of select="@*"/>
               <xsl:iterate select="*, $end-of-sequence">
                  <xsl:param name="group-so-far" as="element()">
                     <group/>
                  </xsl:param>
                  
                  <xsl:variable name="this-is-the-end" select="self::tan:end-of-sequence"/>
                  <xsl:variable name="last-group-in-group-so-far" select="$group-so-far/tan:group[last()]"/>
                  <xsl:variable name="this-name" select="name(.)"/>
                  
                  <!-- We think of the adjustment process as being applied to a triad, i.e., a combination of 
                     <common> + <a/b> + <common> or <a/b> + <common> + <a/b>. The triad is complete 
                     in the case of the former, and in the latter it is  complete only if the current element is 
                     not a missing <a> or <b> (i.e., the current element is <common>)-->
                  <!-- We assume there is only perhaps one <a> and perhaps one <b> before
                  any <common>, so checking for completeness of the triad depends upon checking
                  for <common>, instead of trying to figure out combinations of <a> and <b>. -->
                  <xsl:variable name="group-so-far-is-a-complete-triad"
                     select="(count($group-so-far/tan:group) eq 3)
                     and 
                     (self::tan:common or $last-group-in-group-so-far/tan:common)"
                  />
                  
                  <xsl:variable name="group-so-far-for-adjustment" as="element()?">
                     <xsl:choose>
                        <xsl:when test="$this-is-the-end and exists($group-so-far/tan:group/tan:a) and exists($group-so-far/tan:group/tan:b)">
                           <!-- If we're at the end, well, it's time to wrap things up. Because we've ended with a dummy 
                           element, the group so far should be the first two parts of a triad. The middle part cannot be 
                           shifted right, and it can be shifted left only if some new element is created at the tail to receive
                           the common text. And so it must be a <common>. Which means that the middle part of the triad
                           can only be a group of both <a> and <b>.
                           -->
                           <group>
                              <xsl:copy-of select="$group-so-far/*"/>
                              <group>
                                 <common/>
                              </group>
                           </group>
                        </xsl:when>
                        <xsl:when test="$group-so-far-is-a-complete-triad">
                           <xsl:sequence select="$group-so-far"/>
                        </xsl:when>
                        <!-- If the group so far is incomplete and we're not at the end, then we leave the variable empty -->
                     </xsl:choose>
                  </xsl:variable>
                  
                  <!-- The terms "end" and "start" are relative to the middle part of the triad -->
                  <xsl:variable name="common-end-1"
                     select="tan:common-end-string($group-so-far-for-adjustment/tan:group[position() = (1, 2)]/*)"
                  />
                  <xsl:variable name="common-start-1"
                     select="tan:common-start-string($group-so-far-for-adjustment/tan:group[position() = (2, 3)]/*)"
                  />
                  
                  <xsl:variable name="shift-middle-by" as="xs:integer?">
                     <xsl:choose>
                        <!-- We shift only <a>s and <b>s, not <common>s -->
                        <xsl:when
                           test="exists($group-so-far-for-adjustment/tan:group[2]/tan:common)"/>
                        <!-- If an <a> or <b> can be shifted to accommodate word spaces, we prefer that spaces be put 
                        at the end of the <a> or <b>, hence the different placement of \s in each of the next two
                        regular expressions. The other patterns below look for grouping punctuation, e.g. () {}
                        [] &; <> to try to get the whole group within an <a> or <b> -->
                        <xsl:when
                           test="
                              $group-so-far-for-adjustment/tan:group[1]/tan:common
                              and matches($common-end-1, '^\s*[\[&lt;\(&amp;\{]')">
                           <xsl:value-of select="string-length($common-end-1) * -1"/>
                        </xsl:when>
                        <xsl:when
                           test="
                              $group-so-far-for-adjustment/tan:group[3]/tan:common
                              and matches($common-start-1, '[\]&gt;\)\s;\}]$')">
                           <xsl:value-of select="string-length($common-start-1)"/>
                        </xsl:when>
                        <!-- The previous two cases looked for cases where the entire common segment could be moved;
                        we now look for partial movements, The next two cases look for places where an opening or closing
                        punctuation can (and should) be pushed into an a/b. -->
                        <xsl:when test="matches($common-end-1, '[\[&lt;\(]')">
                           <xsl:value-of select="string-length(replace($common-start-1, '$.*?(\s*[\[&lt;\(])', '$1', 's'))"/>
                        </xsl:when>
                        <xsl:when test="matches($common-start-1, '[\]&gt;\)]')">
                           <xsl:value-of select="string-length(replace($common-start-1, '^(.*[\]&gt;\)]\s*).*$', '$1', 's'))"/>
                        </xsl:when>
                     </xsl:choose>
                  </xsl:variable>
                  
                  <xsl:variable name="text-to-insert" as="xs:string?">
                     <xsl:choose>
                        <xsl:when test="$shift-middle-by lt 0">
                           <xsl:sequence
                              select="substring($common-end-1, (string-length($common-end-1) + $shift-middle-by))"
                           />
                        </xsl:when>
                        <xsl:when test="$shift-middle-by gt 0">
                           <xsl:sequence
                              select="substring($common-start-1, 1, $shift-middle-by)"
                           />
                        </xsl:when>
                     </xsl:choose>
                  </xsl:variable>
                  
                  <xsl:variable name="new-group-adjusted" as="element()?">
                     <xsl:choose>
                        <xsl:when test="exists($shift-middle-by)">
                           <group>
                              <xsl:apply-templates select="$group-so-far-for-adjustment/*[1]" mode="trim-or-add-text">
                                 <xsl:with-param name="trim-end-by" tunnel="yes"
                                    select="
                                       if ($shift-middle-by lt 0) then
                                          abs($shift-middle-by)
                                       else
                                          ()"
                                 />
                                 <xsl:with-param name="append-text" tunnel="yes"
                                    select="
                                       if ($shift-middle-by gt 0) then
                                          $text-to-insert
                                       else
                                          ()"
                                 />
                              </xsl:apply-templates>
                              <xsl:apply-templates select="$group-so-far-for-adjustment/*[2]" mode="trim-or-add-text">
                                 <xsl:with-param name="trim-start-by" tunnel="yes"
                                    select="
                                       if ($shift-middle-by gt 0) then
                                          $shift-middle-by
                                       else
                                          ()"
                                 />
                                 <xsl:with-param name="trim-end-by" tunnel="yes"
                                    select="
                                       if ($shift-middle-by lt 0) then
                                          abs($shift-middle-by)
                                       else
                                          ()"
                                 />
                                 <xsl:with-param name="prepend-text" tunnel="yes"
                                    select="
                                       if ($shift-middle-by lt 0) then
                                          $text-to-insert
                                       else
                                          ()"
                                 />
                                 <xsl:with-param name="append-text" tunnel="yes"
                                    select="
                                       if ($shift-middle-by gt 0) then
                                          $text-to-insert
                                       else
                                          ()"
                                 />
                              </xsl:apply-templates>
                              <xsl:apply-templates select="$group-so-far-for-adjustment/*[3]"
                                 mode="trim-or-add-text">
                                 <xsl:with-param name="trim-start-by" tunnel="yes"
                                    select="
                                       if ($shift-middle-by gt 0) then
                                          $shift-middle-by
                                       else
                                          ()"/>
                                 <xsl:with-param name="prepend-text" tunnel="yes"
                                    select="
                                       if ($shift-middle-by lt 0) then
                                          $text-to-insert
                                       else
                                          ()"
                                 />
                              </xsl:apply-templates>
                           </group>
                        </xsl:when>
                        <xsl:otherwise>
                           <xsl:sequence select="$group-so-far-for-adjustment"/>
                        </xsl:otherwise>
                     </xsl:choose>
                  </xsl:variable>
                  
                  <!-- build new parameters -->
                  <xsl:variable name="group-to-pass-to-next-iteration" as="element()">
                     <group>
                        <xsl:choose>
                           <!-- Is the group so far incomplete? I.e., is this an <a> that needs to join
                           a lonely <b> or vice versa? -->
                           <xsl:when test="($last-group-in-group-so-far/tan:a and self::tan:b)
                              or ($last-group-in-group-so-far/tan:b and self::tan:a)">
                              <xsl:copy-of select="$last-group-in-group-so-far/preceding-sibling::*"/>
                              <group>
                                 <xsl:copy-of select="$last-group-in-group-so-far/*"/>
                                 <xsl:copy-of select="."/>
                              </group>
                           </xsl:when>
                           <!-- Perhaps its incomplete only because we've just started. -->
                           <xsl:when test="not($group-so-far-is-a-complete-triad)">
                              <xsl:copy-of select="$group-so-far/tan:group"/>
                              <group>
                                 <xsl:copy-of select="."/>
                              </group>
                           </xsl:when>
                           <xsl:otherwise>
                              <!-- The second part of the inherited triad now becomes the first part of the next triad -->
                              <xsl:copy-of select="$new-group-adjusted/*[2]"/>
                              <xsl:copy-of select="$new-group-adjusted/*[3]"/>
                              <group>
                                 <xsl:copy-of select="."/>
                              </group>
                           </xsl:otherwise>
                        </xsl:choose>
                     </group>
                  </xsl:variable>
                  
                  <xsl:variable name="diagnostics-on" select="false()"/>
                  <xsl:if test="$diagnostics-on">
                     <xsl:message select="'Diagnostics on, tan:adjust-diff(), iteration', position()"/>
                     <xsl:if test="$this-is-the-end"><xsl:message select="'Last iteration.'"/></xsl:if>
                     <xsl:message select="'Group so far: ', serialize($group-so-far)"/>
                     <xsl:message select="'This item: ', serialize(.)"/>
                     <xsl:message
                        select="'Process the group that has been built so far?: ', $group-so-far-is-a-complete-triad"
                     />
                     <xsl:message select="'Group primed for adjustment and output: ', serialize($group-so-far-for-adjustment)"/>
                     <xsl:message select="'Common end (1): ' || $common-end-1"/>
                     <xsl:message select="'Common start (1): ' || $common-start-1"/>
                     <xsl:message select="'Shift middle by:', $shift-middle-by"/>
                     <xsl:message select="'Text to insert: ' || $text-to-insert"/>
                     <xsl:message select="'Group to pass to next iteration: ', serialize($group-to-pass-to-next-iteration)"/>
                  </xsl:if>
                  
                  <!-- write results -->
                  <!-- We copy only those elements that have text. In the course of adjustment, some elements might
                  have been dispensed with, creating another area that needs to be fixed. -->
                  <xsl:choose>
                     <xsl:when test="$this-is-the-end and exists($new-group-adjusted/tan:group[3]/*[text()])">
                        <xsl:copy-of select="$new-group-adjusted/tan:group[1]/*[text()]"/>
                        <xsl:copy-of select="$new-group-adjusted/tan:group[2]/*[text()]"/>
                        <xsl:copy-of select="$new-group-adjusted/tan:group[3]/*[text()]"/>
                     </xsl:when>
                     <xsl:when test="$this-is-the-end">
                        <!-- If we're at the end but can't move the second part of the triad, then we just 
                        return the group so far, without changes -->
                        <xsl:copy-of select="$group-so-far/tan:group/*[text()]"/>
                     </xsl:when>
                     <xsl:when test="$group-so-far-is-a-complete-triad">
                        <!-- Only the first part of the triad is now fully adjusted, and can be copied to output. The 
                           second part of the triad will become the first part of the next triad. -->
                        <xsl:copy-of select="$new-group-adjusted/tan:group[1]/*[text()]"/>
                     </xsl:when>
                  </xsl:choose>
                  
                  <xsl:next-iteration>
                     <xsl:with-param name="group-so-far" select="$group-to-pass-to-next-iteration"/>
                  </xsl:next-iteration>
               </xsl:iterate>
            </xsl:copy>
         </xsl:for-each>
      </xsl:variable>
      
      <!-- If adjustments created an element to empty out, then adjacent elements need to be consolidated -->
      <diff>
         <xsl:for-each-group select="$adjustment-1/*" group-adjacent="name() = 'common'">
            <xsl:choose>
               <xsl:when test="current-grouping-key()">
                  <common><xsl:value-of select="current-group()"/></common>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:for-each-group select="current-group()" group-by="name()">
                     <xsl:sort select="current-grouping-key()"/>
                     <xsl:element name="{current-grouping-key()}">
                        <xsl:value-of select="string-join(current-group())"/>
                     </xsl:element>
                  </xsl:for-each-group>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:for-each-group>
      </diff>
      
      </xsl:function>

      <xsl:template match="tan:a | tan:b | tan:common" mode="trim-or-add-text">
         <xsl:param name="trim-start-by" tunnel="yes" as="xs:integer?"/>
         <xsl:param name="trim-end-by" tunnel="yes" as="xs:integer?"/>
         <xsl:param name="prepend-text" tunnel="yes" as="xs:string?"/>
         <xsl:param name="append-text" tunnel="yes" as="xs:string?"/>
         <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="$prepend-text"/>
            <xsl:choose>
               <xsl:when test="($trim-start-by gt 0) and ($trim-end-by gt 0)">
                  <xsl:value-of select="substring(., $trim-start-by + 1, (string-length(.) - $trim-start-by - $trim-end-by))"/>
               </xsl:when>
               <xsl:when test="$trim-start-by gt 0">
                  <xsl:value-of select="substring(., $trim-start-by + 1)"/>
               </xsl:when>
               <xsl:when test="$trim-end-by gt 0">
                  <xsl:value-of select="substring(., 1, (string-length(.) - $trim-end-by))"/>
               </xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="."/>
               </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="$append-text"/>
         </xsl:copy>
      </xsl:template>
   
   
   
</xsl:stylesheet>
