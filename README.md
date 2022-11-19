# Caecilia
A still simple Editor with Syntax Highlighting, a preview function and click-to-note feature for the ABC notation format (http://abcnotation.com/) written with perl/Tcl::Tk

Please note that you have to install abcm2ps seperately and to adjust the abcm2ps path in the Edit->Settings dialog. Binaries for abcm2ps can be found at http://abcplus.sourceforge.net/ .

Under Linux you can install the application with:

```
perl ./Makefile.PL
make
su
make install
```

Therefore you need the following libraries and perl modules:

* Tk with tkpath and Img extension
* Tcl::Tk
* libRSVG
* Image::Info
* File::ShareDir
