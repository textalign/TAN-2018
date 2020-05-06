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
</xsl:stylesheet>
