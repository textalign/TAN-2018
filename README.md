# Text Alignment Network 

[http://textalign.net](http://textalign.net)

Alpha version 2020

This project has submodules, which must be invoked using the `--recursive` option:
`git clone --recursive [SOURCE PATH]`

New to TAN? Start with directories marked with an asterisk.

* `applications/`: mostly XSLT stylesheets for creating, editing, converting, and using with TAN files. 
* \*`examples/`: A small library of example TAN files. Snippets of these examples appear in the guidelines.
* `functions/`: The TAN function library, the core engine for validation and applications.
* \* `guidelines/`: the main documentation for TAN. See also http://textalign.net/release/TAN-2018/guidelines/xhtml/index.xhtml.
* `output/`: empty directory for placing sample output
* `parameters/`: Parameters that can be altered, to adjust both validation and activities.
* `schemas/`: The principle schemas for validating TAN files.
* `templates/`: Templates in various formats, both TAN and non-TAN. Useful for activities.
* `vocabularies/`:: standard TAN vocabulary files (TAN-voc).

If you wish to add the TAN function library to your XSLT applications, use `<xsl:include href="functions/TAN-A-functions.xsl"/>` and `<xsl:include href="functions/TAN-extra-functions.xsl"/>`. 

Participation in developing TAN is welcome. If you create or maintain a library of TAN files, share it.