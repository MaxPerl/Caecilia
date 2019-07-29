# Caecilia
A still simple Editor with Syntax Highlighting, a preview function and click-to-note feature for the ABC notation format (http://abcnotation.com/) written with perl/Tcl::Tk

Windows binaries with all necesssary libraries and modules can be found at www.maximilianlika.de/static/files/Caecilia-x86_64-0.10.exe . Please note that you have to install abcm2ps seperately and to adjust the abcm2ps path in the Edit->Settings dialog. Binaries for abcm2ps can be found at http://abcplus.sourceforge.net/ .

Under Linux you can install the application with:

```
perl ./Makefile.PL
make
su
make install
```

Therefore you need the following libraries and perl modules:

* Gtk3
* GooCanvas2
* GtkSourceView 3
* perl-Gtk3
* perl-Gtk3-SourceView
* perl-GooCanvas2
* perl-ShareDir
* perl-ShareDir-Install
