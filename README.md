# Caecilia
A still simple Editor with Syntax Highlighting and a preview function for the ABC notation format (http://abcnotation.com/) written with perl/Gtk3

Windows binaries can be found under www.maximilianlika.de/static/caecilia/Caecilia-x86_64-0.08.exe . Please note that you have to install abcm2ps seperately and to adjust the abcm2ps path in the Edit->Settings dialog. Binaries for abcm2ps can be found at http://abcplus.sourceforge.net/ .

Under Linux you can install the application with:

```
perl ./Makefile.PL
make
su
make install
```

You will need the following libraries and perl modules:

* Gtk3
* GooCanvas2
* GtkSource
* perl-Gtk3
* perl-Gtk3-SourceView
* perl-GooCanvas2
* perl-ShareDir
* perl-ShareDir-Install
