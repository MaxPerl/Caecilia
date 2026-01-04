# Caecilia
A simple Editor with Syntax Highlighting, MIDI recording, importing and playing functionality and a preview function with click-to-note (Left Mouseclick), insert-decorations-through Entry and Preview (left-click in Entry or longpress in Preview) and play-from-note (right click in Preview) feature for the ABC notation format (http://abcnotation.com/) written with perl/pEFL.

![Screenshot to Caecilia](https://github.com/MaxPerl/Caecilia/raw/master/screenshot.jpg "Screenshot to Caecilia")

Please note that you have to install abcm2ps and abcmidi/midi2abc seperately and to adjust the abcm2ps path in the Edit->Settings dialog. Binaries for abcm2ps and abcmidi/midi2abc can be found at http://abcplus.sourceforge.net/. Abc2svg is used for preview function and already included.

Under Linux you can install the application with:

```
perl ./Makefile.PL
make
sudo make install
```

Therefore you need the following libraries and perl modules:

* pEFL
* Source::SyntaxHighlight
* Image::Info
* File::ShareDir
* File::HomeDir
* Convert::Color
* HTML::Entities
* MIDI
* MIDI::Util
* Music::Tempo
* JavaScript::QuickJS
* YAML

To record midi and convert it to abc you need the follwing programs:
* abcmidi/midi2abc
* midish
* aseqdump (part of alsa)
