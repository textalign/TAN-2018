<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet exclude-result-prefixes="#all" xmlns:tan="tag:textalign.net,2015:ns"
    xmlns:oasis="urn:oasis:names:tc:opendocument:xmlns:container"
    xmlns:html="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:opf="http://www.idpf.org/2007/opf"
version="2.0">

    <!-- Written March 2018 by Joel Kalvesmaki, released under a Creative Commons by_4.0 license. -->

    <!-- These XSLT functions allow one to retrieve the XML documents that are part of an epub document and save component parts as a new epub document. -->
    
    <!-- All nontextual content is necessarily ignored, since XSLT deals only with texts. One work-around is to link to nontextual content, and not embed it. -->
    
    <!-- A key factor in making these functions successful is the introduction of @jar-path to the root element of every component XML document. The @jar-path indicates where in the hierarchy of the Word file each document sits. Only XML documents that retain @jar-path can be used by tan:save-docx(), and in those cases, the provisional @jar-path is removed before zipping. -->
    
    <!-- OPENING EPUB FILES -->

    <xsl:function name="tan:epub-file-available" as="xs:boolean">
        <!-- Input: any element with an @href or a string -->
        <!-- Output: a boolean indicating whether the Word document is available at the url specified -->
        <xsl:param name="element-with-attr-href-or-string-with-absolute-uri" as="item()?"/>
        <xsl:variable name="input-base-uri"
            select="
                if ($element-with-attr-href-or-string-with-absolute-uri instance of node()) then
                    base-uri($element-with-attr-href-or-string-with-absolute-uri)
                else
                    ()"/>
        <xsl:variable name="static-base-uri" select="static-base-uri()"/>
        <xsl:variable name="best-base-uri" select="($input-base-uri, $static-base-uri)[1]"/>
        <xsl:variable name="intended-uri" as="xs:string"
            select="
            if ($element-with-attr-href-or-string-with-absolute-uri instance of node()) then
            ($element-with-attr-href-or-string-with-absolute-uri/@href, string($element-with-attr-href-or-string-with-absolute-uri))[1]
            else
            string($element-with-attr-href-or-string-with-absolute-uri)"
        />
        <xsl:variable name="source-uri" select="resolve-uri($intended-uri, $best-base-uri)"/>
        <xsl:variable name="source-jar-uri" select="concat('zip:', $source-uri, '!/')"/>
        <xsl:variable name="source-root" select="concat($source-jar-uri, '_rels/.rels')"/>
        <xsl:copy-of select="doc-available($source-root)"/>
    </xsl:function>
    
    <xsl:function name="tan:open-epub" as="document-node()*">
        <!-- Input: a contextual element with the attribute @href pointing to a Microsoft Office file, or a string representing an absolute uri -->
        <!-- Output: a sequence of the XML documents found inside the input -->
        <!-- To facilitate the reconstruction of the epub file, every extracted document will be stamped with @jar-path, with the local path and name of the component. -->
        <xsl:param name="element-with-attr-href-or-string-with-absolute-uri" as="item()?"/>
        <xsl:variable name="input-base-uri"
            select="
                if ($element-with-attr-href-or-string-with-absolute-uri instance of node()) then
                    base-uri($element-with-attr-href-or-string-with-absolute-uri)
                else
                    ()"
        />
        <xsl:variable name="static-base-uri" select="static-base-uri()"/>
        <xsl:variable name="best-base-uri" select="($input-base-uri, $static-base-uri)[1]"/>
        <xsl:variable name="intended-uri" as="xs:string"
            select="
                if ($element-with-attr-href-or-string-with-absolute-uri instance of node()) then
                    ($element-with-attr-href-or-string-with-absolute-uri/@href, string($element-with-attr-href-or-string-with-absolute-uri))[1]
                else
                    string($element-with-attr-href-or-string-with-absolute-uri)"
        />
        <xsl:variable name="this-extension" select="replace($intended-uri, '^.+\.(\w+)$', '$1')"/>
        <xsl:variable name="source-uri" select="resolve-uri($intended-uri, $best-base-uri)"/>
        <xsl:variable name="source-jar-uri" select="concat('zip:', $source-uri, '!/')"/>
        <xsl:variable name="source-root-rels-path" select="concat($source-jar-uri, 'META-INF/container.xml')"/>
        <xsl:variable name="source-root-container" as="document-node()?"
            select="tan:extract-epub-component($source-jar-uri, 'META-INF/container.xml')"/>
        <xsl:variable name="source-rootfiles" select="for $i in $source-root-container//oasis:rootfile return 
            tan:extract-epub-component($source-jar-uri, $i/@full-path)"/>
        <xsl:variable name="source-docs" as="document-node()*">
            <xsl:for-each select="$source-rootfiles">
                <xsl:variable name="this-jar-path" select="*/@jar-path"/>
                <xsl:variable name="this-jar-directory" select="replace($this-jar-path, '/[^/]+$','/')"/>
                <xsl:for-each select=".//*[@href]">
                    <xsl:variable name="this-href" select="@href"/>
                    <xsl:copy-of select="tan:extract-epub-component($source-jar-uri, concat($this-jar-directory, $this-href))"/>
                </xsl:for-each>
            </xsl:for-each>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="not(doc-available($source-root-rels-path))">
                <xsl:message>No document found at <xsl:value-of select="$source-jar-uri"/></xsl:message>
            </xsl:when>
            <xsl:otherwise>
                <xsl:sequence select="$source-root-container, $source-rootfiles, $source-docs"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>
    <xsl:function name="tan:extract-epub-component" as="document-node()?">
        <!-- Input: the base jar uri for an epub archive; a path to a component part of the archive -->
        <!-- Output: the XML document itself, but with @jar-path stamped into the root element -->
        <xsl:param name="source-jar-uri" as="xs:string"/>
        <xsl:param name="component-path" as="xs:string"/>
        <xsl:variable name="extracted-doc" as="document-node()?"
            select="
                if (doc-available(concat($source-jar-uri, $component-path))) then
                    doc(concat($source-jar-uri, $component-path))
                else
                    ()"/>
        <xsl:if test="exists($extracted-doc)">
            <xsl:apply-templates select="$extracted-doc" mode="stamp-epub-component-with-path">
                <xsl:with-param name="path" select="$component-path" tunnel="yes"/>
                <xsl:with-param name="base-uri" select="$source-jar-uri" tunnel="yes"/>
            </xsl:apply-templates>
        </xsl:if>
    </xsl:function>
    <xsl:template match="document-node()" mode="stamp-epub-component-with-path">
        <xsl:document>
            <xsl:apply-templates mode="#current"/>
        </xsl:document>
    </xsl:template>
    <xsl:template match="comment() | processing-instruction()" mode="stamp-epub-component-with-path clean-up-epub-before-repackaging">
        <xsl:copy-of select="."/>
    </xsl:template>
    <xsl:template match="*" mode="stamp-epub-component-with-path">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/*" mode="stamp-epub-component-with-path">
        <xsl:param name="path" as="xs:string" tunnel="yes"/>
        <xsl:param name="base-uri" as="xs:string" tunnel="yes"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="jar-path" select="$path"/>
            <xsl:attribute name="xml:base" select="$base-uri"/>
            <xsl:apply-templates mode="#current"/>
            <!-- We do not use <xsl:copy-of select="node()"/> because docx files are sensitive to namespace attributes -->
        </xsl:copy>
    </xsl:template>


    <!-- SAVING EPUB FILES -->

    <xsl:template name="tan:save-epub">
        <!-- Input: a sequence of documents that each have @jar-path stamped in the root element (the result of tan:open-docx()); a resolved uri for the new Word document -->
        <!-- Output: a file saved at the place located -->
        <!-- Ordinarily, this template would be a function, but <result-document> always fails in the context of a function. -->
        <xsl:param name="epub-parts" as="document-node()*"/>
        <xsl:param name="resolved-uri" as="xs:string"/>
        <xsl:for-each select="$epub-parts/*[@jar-path]">
            <xsl:result-document href="{concat('zip:', $resolved-uri, '!/', @jar-path)}">
                <xsl:document><xsl:apply-templates select="." mode="clean-up-epub-before-repackaging"/></xsl:document>
            </xsl:result-document>
        </xsl:for-each>
    </xsl:template>

    <xsl:template match="*" mode="clean-up-epub-before-repackaging">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates mode="#current"></xsl:apply-templates>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="/*" mode="clean-up-epub-before-repackaging">
        <!-- get rid of the special @jar-path and @xml:base we added, to automate repackaging in the right locations -->
        <xsl:copy>
            <xsl:copy-of select="@* except (@jar-path, @xml:base)"/>
            <!-- copying the attributes should also ensure that namespace nodes are copied; Word will mark a file as corrupt if otiose namespace nodes aren't included -->
            <xsl:apply-templates mode="clean-up-epub-before-repackaging"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template mode="clean-up-epub-before-repackaging"
        match="*:Relationship[root()/*/@jar-path = '_rels/.rels' and matches(@Target, '\.jpe?g$') and not(@TargetMode = 'External')]">
        <!-- get rid of elements in .rels that point to images (e.g., thumbnails) -->
    </xsl:template>
    
</xsl:stylesheet>
