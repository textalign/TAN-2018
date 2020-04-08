<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:tan="tag:textalign.net,2015:ns"
    exclude-result-prefixes="#all" version="3.0">
    
    <!-- Create App for XSL -->
    <!-- author: Joel Kalvesmaki -->
    <!-- updated: 2020-04-08 -->
    <!-- To do: 
        refine, test batch process
        develop parallel process for shell (.sh)
    -->
    
    <!-- This stylesheet creates a batch file for each of one or more input XSLT stylesheets, to make
        it easier for someone to use an XSLT stylesheet like a traditional application. A user needs 
        merely to use the File Explorer to drag files onto the batch file, and run the stylesheet. 
        
        This process will not serve every type of XSLT application. It targets a significant subset of XSLT
        that we will call here MIRU stylesheets: Main Input via Resolved URIs.
        In a MIRU stylesheet:
          - the initial, catalyzing input is irrelevant; any XML file, including stylesheet itself, can be the catalyzing input.
          - the main input is determined by a single parameter that takes a sequence of strings for resolved 
            uris; those files are either input files or plain-text lists of input files.
        In a MIRU stylesheet, the catalyzing XML input is of no consequence, and so the MIRU stylesheet can be its own
        catalyzing input. The main input is drawn from files fetched from the resolved uris. 
        
        The advantage of a MIRU stylesheet is that anything can be input, including non-XML, binary files. In many 
        MIRU stylesheets the primary output (the output determined by the default or initial template) is of no or 
        little consequence, perhaps providing a diagnostic report or a log. The more important output files are generated 
        by xsl:result-document, either iterating over the input and saving each output file somewhere relative to the input,
        the stylesheet, or some other location. 
        
        The file you are reading is an example of a MIRU stylesheet. To test it, copy this file, and drag the copy atop the 
        original. A new batch file will appear alongside the copy. 
        
        The process should work as will for NIR (no input required) XSLT stylesheets.
    -->
    
    <!-- Catalyzing input: any XML file (including this one) -->
    <!-- Main input: one or more resolved uris pointing to XSLT stylesheets -->
    <!-- Primary output: nothing, unless diagnostics are on -->
    <!-- Secondary output: a batch file with the same name as the main input -->
    <!-- Adjust parameters below, as needed -->
    
    
    <xsl:import href="../../functions/TAN-A-functions.xsl"/>
    
    <!-- + + + + + + + + + + + + + + -->
    <!-- START OF PARAMETERS -->

    <!-- What are the resolved uris for the XSLT files that should have an app created? -->
    <xsl:param name="main-input-resolved-uris" as="xs:string*"/>
    
    <!-- Alternatively, you might provide resolved URIs pointing to a plain-text list of resolved URIs, each on a separate line -->
    <xsl:param name="main-input-resolved-uri-lists" as="xs:string*"/>
    
    <!-- Where is the XSLT Processor relative to this stylesheet? -->
    <xsl:param name="processor-path-relative-to-this-stylesheet" as="xs:string"
        >../../processors/saxon9he.jar</xsl:param>

    <!-- What are the standard Saxon options you want to include? See https://saxonica.com/documentation/index.html#!using-xsl/commandline -->
    <xsl:param name="default-saxon-options" as="xs:string?"/>
    
    <!-- What should be the filename of the primary output (if any)? Note, this value populates the -o parameter, and does not dictate whether there will be any primary output, or the handling of secondary output via xsl:result-document -->
    <xsl:param name="primary-output-target-uri" as="xs:string">%_xslPath%.output.xml</xsl:param>
    
    <!-- What is the name of the key parameter in the stylesheet? It must be anticipating a sequence of strings representing resolved uris -->
    <xsl:param name="key-parameter-name" as="xs:string" select="'main-input-resolved-uris'"/>
    
    <!-- Do you want to turn diagnostics on? This parameter does not affect the content of the output file(s). -->
    <xsl:param name="diagnostics-on" as="xs:boolean?" select="false()"/>
    
    <!-- There are numerous other adjustments you can make to the batch file itself. -->

    <!-- END OF PARAMETERS -->
    <!-- + + + + + + + + + + + + + + -->
    
    <xsl:variable name="miru-lists-parsed" as="xs:string*">
        <xsl:for-each select="distinct-values($main-input-resolved-uri-lists)">
            <xsl:choose>
                <xsl:when test="unparsed-text-available(.)">
                    <!-- get text lines that have text -->
                    <xsl:message select="'unparsed text lines: ' || unparsed-text-lines(.)"/>
                    <xsl:sequence select="unparsed-text-lines(.)[matches(., '\S')]"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message select="'No text file found at ' || ."/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:variable>
    
    <xsl:variable name="processor-path-resolved" as="xs:string"
        select="resolve-uri($processor-path-relative-to-this-stylesheet, static-base-uri())"/>
    
    <xsl:variable name="batch-file-template" as="xs:string"
        select="unparsed-text(resolve-uri('create%20app%20for%20xsl.bat', static-base-uri()))"/>
    
    <xsl:function name="tan:adjust-batch-file" as="xs:string">
        <!-- Input: a template batch file, assorted parameters -->
        <!-- Output: a revised version of the batch file -->
        <xsl:param name="target-uri-resolved" as="xs:string"/>
        <xsl:variable name="new-saxon-path"
            select="tan:uri-relative-to($processor-path-resolved, $target-uri-resolved)"
        />
        <!-- We process the output in multiple passes, to avoid indentations of too great a depth -->
        <xsl:variable name="output-pass-1" as="xs:string+">
            <!-- set up the path to the Saxon engine and its options (other than -xsl:, -o:, and -s:) -->
            <xsl:analyze-string select="$batch-file-template" regex="(set _saxonPath=)\S*">
                <xsl:matching-substring>
                    <xsl:value-of select="regex-group(1) || $new-saxon-path"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:analyze-string select="." regex="(set _saxonOptions=)\S*">
                        <xsl:matching-substring>
                            <xsl:value-of select="regex-group(1) || $default-saxon-options"/>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:variable name="output-pass-2" as="xs:string+">
            <!-- set up option -o: and the key parameter -->
            <xsl:analyze-string select="string-join($output-pass-1)" regex="(set _keyParameter=)\S+">
                <xsl:matching-substring>
                    <xsl:value-of select="regex-group(1) || $key-parameter-name"/>
                </xsl:matching-substring>
                <xsl:non-matching-substring>
                    <xsl:analyze-string select="." regex="(set _xslOutput=)\S+">
                        <xsl:matching-substring>
                            <xsl:value-of select="regex-group(1) || $primary-output-target-uri"/>
                        </xsl:matching-substring>
                        <xsl:non-matching-substring>
                            <xsl:value-of select="."/>
                        </xsl:non-matching-substring>
                    </xsl:analyze-string>
                </xsl:non-matching-substring>
            </xsl:analyze-string>
        </xsl:variable>
        <xsl:value-of select="string-join($output-pass-2)"/>
    </xsl:function>
    
    <xsl:output indent="yes"/>
    <xsl:template match="/">
        <xsl:if test="$diagnostics-on">
            <diagnostics>
                <main-input-uris-resolved count="{count($main-input-resolved-uris)}">
                    <xsl:for-each select="$main-input-resolved-uris">
                        <uri doc-available="{doc-available(.)}"><xsl:value-of select="."/></uri>
                    </xsl:for-each>
                </main-input-uris-resolved>
            </diagnostics>
        </xsl:if>
        <xsl:if test="count($miru-lists-parsed) gt 0 and count($main-input-resolved-uris) gt 1">
            <xsl:message select="'Input is both a sequence of resolved uris and a list of them. Attempting to synthesize both.'"/>
        </xsl:if>
        <xsl:for-each select="$miru-lists-parsed, $main-input-resolved-uris">
            <xsl:variable name="this-uri" select="normalize-space(.)"/>
            <xsl:choose>
                <xsl:when test="doc-available($this-uri)">
                    <xsl:variable name="this-doc" select="doc($this-uri)"/>
                    <xsl:variable name="this-is-xslt" select="exists($this-doc/(xsl:stylesheet, xsl:transform))"/>
                    <xsl:variable name="these-params" select="$this-doc/*/xsl:param"/>
                    <xsl:variable name="these-possible-key-params" select="$these-params[not(@as) or (@as = ('xs:string+', 'xs:string*'))]"/>
                    <xsl:variable name="this-key-param" select="$these-params[@name = $key-parameter-name]"/>
                    <xsl:variable name="this-valid-key-param"
                        select="$these-possible-key-params[@name = $key-parameter-name]"/>
                    <xsl:choose>
                        <xsl:when test="$this-is-xslt and exists($this-valid-key-param)">
                            <xsl:variable name="target-href" select="replace($this-uri, '.[^\.]+$', '.bat')"/>
                            <xsl:message select="'Saving batch file at ' || $target-href"/>
                            <xsl:result-document method="text" href="{$target-href}">
                                <xsl:value-of select="tan:adjust-batch-file($target-href)"/>
                            </xsl:result-document>
                        </xsl:when>
                        <xsl:when test="$this-is-xslt and exists($this-key-param)">
                            <xsl:message select="$this-uri || ' is an XSLT document, and there is a key param named ' || $key-parameter-name || 
                                ' but it is not defined as taking a sequence of strings.'"/>
                        </xsl:when>
                        <xsl:when test="$this-is-xslt">
                            <xsl:message select="$this-uri || ' is an XSLT document, but there is no key param named ' || 
                                $key-parameter-name || '. This operation expects a single parameter defined as accepting a sequence of strings. ' || 
                                string(count($these-possible-key-params)) || ' valid parameters exist. ' || string-join($these-possible-key-params/@name, ', ')"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:message select="$this-uri || ' is not an XSLT document'"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:message select="$this-uri || ' is not available'"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
