// chord.js - generation of accompaniment
//
// Copyright (C) 2020-2026 Jean-François Moine and Seymour Shlien
//
// This file is part of abc2svg.
//
// abc2svg is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// abc2svg is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with abc2svg.  If not, see <http://www.gnu.org/licenses/>.

// This file contains the configuration and the generation
// of the accompaniment chords.

// %%chordkit: set chord parameters
//
// - define a chord as one letter
// %%chordkit [ <single_letter> "=" <chord> ]*
// ex: %%chordkit f=*1, c=139
//
// - define the chord types (qualities)
// %%chordkit "type" "=" [ <chord_type> ":" <ABC_notes> ]*
// ex: %%chordkit type=m:C_EG dim7:C_E^FA
//
// - define general parameters (instruments, volume...)
// %%chordkit [ <keyword> "=" <value> [ "," <value> ] ]*
//   with the keywords:
//		instr = instrument_chord [ "," instrument_bass]
//		vol = volume_chord [ "," volume_bass ]	% 0..127
// ex: %%chordkit instr=guitnyl % guitar nylon
//
// %%chord: define the transformation of a chord symbol into a playable chord
//
// %%chord [ <number_of_measures> ] [ <list_of_notes/chords> ]
//
// On playback, the list of the notes/chords is played during the
// <number_of_measures>.
// If this number is null, chord playback is stopped. Then, playing
// may be restarted with the previous or a new list of notes/chords by
// setting again this number.
//
// The notes are the offsets (indexes) of the notes in the current chord symbol
// - '0' is a rest
// - '1' is the tonic
// - '3' is the note between the tonic and the dominant (2nd, maj/min 3nd or 4th)
// - '5' is the dominant (5th)
// - '7' is the 6th or the 7th or even 5th if no 5 in the chord
// - '8' and '9' are the last notes of the chord (9th, 11th)
//
// note:	1 __3_ _5_ ___7___ _8  _9
// MIDI:	0 2345 678 9,10,11 14  17
// C chord:	C D EF  G  A    B   D'  F'
//
// The notes/chords are separed by spaces. Each note (sole note or
// individual note of a chord) may be followed by one or many commas or
// single quotes that change the note pitch to a lower or upper octave.
//
// A star (*) before a note means the note is a bass note that may be played
// by an other instrument (%%chordkit chord bassinstr=<instrument_name>)
// (the bass stuff is not coded yet)
//
// A plus sign (+) is a special note that
// - indicates continuous chords when it is the first item in the list.
//	The exact chord may be defined by the 2nd item. It defaults to *1,136.
// - continues the previous note/chord.
//
// ex: %%chord 1 *1, 135 0 5, 137 +

// -- chord table --
// from https://en.wikipedia.org/wiki/Chord_(music)
// index = chord symbol type
// value: array of MIDI pitch / root
//	index = inversion
abc2svg.chnm = {
	'': [0, 4, 7],
	'6': [0, 4, 7, 9],
	'7': [0, 4, 7, 10],
	M7: [0, 4, 7, 11],
	aug: [0, 4, 8],
	aug7: [0, 4, 8, 10],
	m: [0, 3, 7],
	m6: [0, 3, 7, 9],
	m7: [0, 3, 7, 10],
	mM7: [0, 3, 7, 11],
	dim: [0, 3, 6],
	dim7: [0, 3, 6, 9],
	m7b5: [0, 3, 6, 10],
	'9': [0, 4, 7, 10, 14],
//	m9:
//	maj9:
//	M9:
	'11': [0, 4, 7, 10, 14, 17],
	sus4: [0, 5, 7]
//	sus9:
//	'7sus4':
//	'7sus9':
//	'5':
}

abc2svg.letmid = {			// letter -> MIDI pitch
	C: 0,
	D: 2,
	E: 4,
	F: 5,
	G: 7,
	A: 9,
	B: 11
} // letmid

abc2svg.chord = {
    alias: {				// default aliases (from abcMIDI)
	c: "135789",
	b: "*1,135789",
	f: "*1,",
	g: "1'",
	h: "3'",
	i: "5'",
	j: "7'",
	z: "0",
	G: "1",
	H: "3",
	I: "5",
	J: "7",
    }, // alias

// name of the MIDI instruments
    prg_nam: `
0 acoustic grand piano
1 bright acoustic piano 
2 electric grand piano
3 honky-tonk piano 
4 electric piano 1 
5 electric piano 2 
6 harpsichord 
7 clavi 
8 celesta 
9 glockenspiel 
10 music box 
11 vibraphone 
12 marimba 
13 xylophone 
14 tubular bells 
15 dulcimer 
16 drawbar organ 
17 percussive organ 
18 rock organ 
19 church organ 
20 reed organ 
21 accordion 
22 harmonica 
23 tango accordion 
24 acoustic guitar (nylon) 
25 acoustic guitar (steel) 
26 electric guitar (jazz) 
27 electric guitar (clean) 
28 electric guitar (muted) 
29 overdriven guitar 
30 distortion guitar 
31 guitar harmonics 
32 acoustic bass 
33 electric bass (finger) 
34 electric bass (pick) 
35 fretless bass 
36 slap bass 1 
37 slap bass 2 
38 synth bass 1 
39 synth bass 2 
40 violin 
41 viola
42 cello 
43 contrabass 
44 tremolo strings 
45 pizzicato strings 
46 orchestral harp 
47 timpani 
48 string ensemble 1 
49 string ensemble 2 
50 synthstrings 1 
51 synthstrings 2 
52 choir aahs 
53 voice oohs 
54 synth voice 
55 orchestra hit 
56 trumpet 
57 trombone 
58 tuba 
59 muted trumpet 
60 french horn 
61 brass section 
62 synthbrass 1 
63 synthbrass 2 
64 soprano sax
65 alto sax 
66 tenor sax 
67 baritone sax 
68 oboe 
69 english horn
70 bassoon 
71 clarinet 
72 piccolo
73 flute 
74 recorder 
75 pan flute
76 blown bottle
77 shakuhachi 
78 whistle 
79 ocarina 
80 lead 1 (square) 
81 lead 2 (sawtooth)
82 lead 3 (calliope) 
83 lead 4 (chiff) 
84 lead 5 (charang) 
85 lead 6 (voice) 
86 lead 7 (fifths) 
87 lead 8 (bass + lead)
88 pad 1 (new age)
89 pad 2 (warm) 
90 pad 3 (polysynth)
91 pad 4 (choir) 
92 pad 5 (bowed) 
93 pad 6 (metallic) 
94 pad 7 (halo) 
95 pad 8 (sweep) 
96 fx 1 (rain) 
97 fx 2 (soundtrack) 
98 fx 3 (crystal) 
99 fx 4 (atmosphere) 
100 fx 5 (brightness) 
101 fx 6 (goblins) 
102 fx 7 (echoes) 
103 fx 8 (sci-fi) 
104 sitar 
105 banjo 
106 shamisen 
107 koto 
108 kalimba 
109 bag pipe 
110 fiddle 
111 shanai 
112 tinkle bell 
113 agogo 
114 steel drums 
115 woodblock 
116 taiko drum 
117 melodic tom 
118 synth drum 
119 reverse cymbal 
120 guitar fret noise 
121 breath noise 
122 seashore 
123 bird tweet 
124 telephone ring 
125 helicopter 
126 applause 
127 gunshot
`,

    // %%chordkit command
    set_kit: function(abc, cmd, parm) {
	if (!parm)
		return
    var	k, s, v,
	cfmt = abc.cfmt(),
	curv = abc.get_curvoice(),
	parse = abc.get_parse(),
	a = parm.match(/=|"[^"]*"|[^\s"=]+/g),
	val = {}

	function bad() {
		abc.syntax(1, abc.errs.bad_val, "%%chordkit")
	}

	// convert ABC into a list of pitch
	function abc2pit(p) {
	    var i, c, a,
		o = []

		for (i = 0; i < p.length; i++) {
			c = p[i]
			if (c == '^')
				a = 1, c = p[++i]
			else if (c == '_')
				a = -1, c = p[++i]
			else
				a = 0
			c = "C D EF G A Bc d ef g a b".indexOf(c)
			if (c < 0)
				return
			o.push(c)
		}
		return o
	} // abc2pit()

	// convert an instrument name into a MIDI program number
	function get_prog(p) {
	    var	i, j, k, l,
		nm = abc2svg.chord.prg_nam

		p = p.replace(/[-_]/g, ' ').trim().toLowerCase().split(' ')
		i = 0
		while (1) {			// search the 1st word
			j = nm.indexOf(p[i])
			if (j > 0
			 && (nm[j - 1] == ' ' || nm[j - 1] == '('))
				break
			if (++i >= p.length)
				return		// no instrument!
		}
		l = nm.lastIndexOf('\n', j)
		if (l < 0)
			l = 0			// candidate
		j = l
		if (i < p.length - 1)
		    while (1) {			// search if many words in a line
			k = nm.indexOf(p[i + 1], j + 1)
			if (k < 0)
				break
			if (nm[k - 1] != ' ' && nm[k - 1] != '(') {
				j = k
				continue
			}
			k = nm.lastIndexOf('\n', k)
			j = nm.indexOf(p[i], k)
			if (j < 0)
				break
			j = nm.lastIndexOf('\n', j)
			if (j == k) {
//fixme: continue with the next word
				l = j
				break
			}
		}
		return parseInt(nm.slice(l, l + 3))
	} //get_prog()

	if (!a)
		return bad()
	while (1) {
		k = a.shift()
		if (!k)
			break
		if (a[0] != '=' || !a[1])
			return bad()
		a.shift()
		v = a.shift()

		// if one letter, this is an alias
		if (/^[A-Za-z]$/.test(k)) {
			if (!/^(\*?[0135-9],*'*)+$/.test(v))	// '
				return bad
			if (!val.alias)
				val.alias = {}
			val.alias[k] = v
			continue
		}
		switch (k) {
		case "type":
			k = v.split(':')
			if (k.length != 2)
				return bad()
			v = abc2pit(k[1])
			if (!v)
				return bad()
			chnm[k[0]] = v
			continue
		case "alias":
			return bad()			// don't change this object
		case "instr":
			if (v[0] < '1' || v[0] > '9') {
				if (v[0] == '"')
					v = v.slice(1, -1)
				v = get_prog(v)
			}
			k = "prog"
			// fall thru
		case "prog":
			v = +v
			break
		case "oct":
			k = "trans"
			v = v == '-' ? -1 : 1
			break
		case "vol":
			v = +v
			if (v < 0 || v > 127)
				v = null
			break
		}
		if (v == null || isNaN(v))
			return bad()
		val[k] = v
// missing:
// cfmt.chord.bprog	in "prog" or "instr"
// cfmt.chord.bvol	in "vol"
	}
	if (parse.state >= 2
	 && curv) {
		s = abc.new_block("midigch")
		s.play = s.invis = 1 //true
		Object.assign(s, val)
	} else {
		if (!cfmt.chord)
			cfmt.chord = {}
		if (cfmt.chord.alias && val.alias) {
			Object.assign(cfmt.chord.alias, val.alias)
			delete val.alias
		}
		if (cfmt.chord.type && val.type) {
			Object.assign(cfmt.chord.type, val.type)
			delete val.type
		}
		Object.assign(cfmt.chord, val)	// keep the starting parameters
	}
    }, // set_kit()

    // %%chord command
    set_fmt: function(of, cmd, parm) {
	if (cmd == "chordkit")
		return abc2svg.chord.set_kit(this, cmd, parm)
	if (cmd != "chord")
		return of(cmd, parm)
	if (!parm)
		parm = "1"		// by default, restart with one measure
    var	c, i, j, n, rhy, s,
	abc = this,
	cfmt = abc.cfmt(),
	curv = abc.get_curvoice(),
	parse = abc.get_parse(),
	a = parm

	function bad() {
		abc.syntax(1, abc.errs.bad_val, "%%chord")
	}

	n = +a[0]			// number of measures
	if (isNaN(n))
		n = 1
	else
		a = a.slice(1).trim()
	if (!cfmt.chord) {
		if (!n)
			return
		cfmt.chord = {}
	}
	if (!cfmt.chord.alias)
		cfmt.chord.alias = {}

	// convert [ letter[digit] ]* into [ chord [ + ]* ]*
	if (/[A-Za-z]/.test(a)) {
		rhy = []
		i = 0
		if (a[0] == '+')
			rhy.push('+'),		// no rhythm
			i++
		for ( ; i < a.length; i++) {
			c = a[i]
			if (c == '+')
				c = '2'
			if (c >= '2' && c < '9') {
				while (--c > 0)
					rhy.push('+')
				continue
			}
			if (cfmt.chord.alias[c])
				rhy.push(cfmt.chord.alias[c])
			else if (abc2svg.chord.alias[c])
				rhy.push(abc2svg.chord.alias[c])
			else
				return bad()
		}
	} else {				// digital values
		rhy = a.match(/((\*?[0135-9],*'*)+|\+)/g)	// '
	}
	if (!rhy)
		return bad()

	if (parse.state >= 2
	 && curv) {
		s = abc.new_block("midigch")
		s.play = s.invis = 1 //true
		s.on = n
		if (n)
			s.gchnb = n
		if (rhy.length)
			s.rhy = rhy
	} else {
		cfmt.chord.on = n
		if (n)
			cfmt.chord.gchnb = n
		if (rhy.length)
			cfmt.chord.rhy = rhy
	}
    }, // set_fmt()

    set_hooks: function(abc) {
	abc.set_format = abc2svg.chord.set_fmt.bind(abc, abc.set_format)
    }
} // chord

// function called from sndgen on playback start
abc2svg.genchrd = function(first,	// first symbol in time
			 voice_tb,	// table of the voices
			 cfmt) {	// tune parameters
    var	chnm, i, k, vch, s, gchon, rhy, ti, dt, gchnb, inv,
	chmid = [],			// bass and chord pitches
	md = first.p_v.meter.wmeasure,	// measure duration
	nextim = 0,
	C = abc2svg.C,
	trans = 48 + (cfmt.chord.trans ? cfmt.chord.trans * 12 : 0)

	// create a chord according to the bass note
	// ('inv' is set when the chord is the first inversion EGc)
	function chcr(b, ch) {
	    var	j, r,
		i = ch.length

		if (b) {
			while (--i > 0) {
				if (ch[i] == b)		// search the bass in the chord
					break
			}
			if (i > 0) {			// do a chord inversion
				r = []
				for (j = i; j < ch.length; j++)
					r.push(ch[j])
				for (j = 0; j < i; j++)
					r.push(ch[j] + 12)
			}
		}
		if (!r)
			r = ch.slice()
		if (!i)
			r[0] = b - 12		// bass one octave lower

		// don't double the third
		inv = rhy[0] == '+'		// if no rhythm
			&& i == 1
		return r
	} // chcr()

	// return a new chord rhythm from a meter (M:)
	function meterhy(s) {
		if (!s.a_meter[0])
			return '+'		// M:none
	    var	r,
		t = s.a_meter[0].top,
		b = s.a_meter[0].bot

		switch (b) {
		case '2':
			b = 4
			t *= 2
			// fall thru
		case undefined:
			if (t[0] == 'C')
				t = 4, b = 4
			// fall thru
		case '4':
			if (t == '3')
				return "fzczcz"
			return "fzczfzczfzcz".slice(0, t * 2)
		case '8':
			return "fzcfzcfzcfzc".slice(0, t)
		}
		return 'z'			// no chord
	} // meterhy()

	// build a chord rhythm
	function bld_rhy(p) {
	    var	i, c, n

	    if (typeof p != "string") {
		rhy = p
	    } else {
		rhy = p == '+'
			? p			// no rhythm
			: p.match(/\[([G-Lg-l]\,*)+\]\d?|[bcf-lzG-L],*\d?/g)
		if (!rhy)
//fixme: error
			rhy = '+'
		for (i = 0; i < rhy.length; i++) {
			c = rhy[i]
			n = c.slice(-1)
			if (n >= '2' && n <= '9') {
				rhy[i] = c.slice(0, -1)
				while (--n > 0)
					rhy.splice(++i, 0, '+')
			}
		}
	    }
		dt = md / rhy.length * gchnb		// delta time
	} // bld_rhy()

	// generate a chord
	function gench(sb, i) {
	    var	r, ch, b, m, n, nt,
		a = sb.a_gch[i].otext

		if (a[0] == 'n' || a[0] == 'N') {	// if no chord (N.C.)
			chmid = []
			return
		}
		if (a.slice(-1) == ')')			// if alternate chord
			a = a.replace(/\(.*/, '')	// remove it
		a = a.replace(/\(|\)|\[|\]/g,'')	// remove ()[]
			.replace(/♯/g, '#')
			.replace(/♭/g, 'b')
			.match(/([A-G])([#b]?)([^/]*)\/?(.*)/)
			// a[1] = note, a[2] = acc, a[3] = type, a[4] = bass
		if (!a)
			return

		r = abc2svg.letmid[a[1]]		// root

			switch (a[2]) {
			case "#": r++; break
			case "b": r--; break
			}
			if (!a[3]) {
				ch = chnm[""]
			} else {
				ch = abc2svg.ch_alias[a[3]]
				if (ch == undefined)
					ch = a[3]
				ch = chnm[ch]
				if (!ch)
					ch = a[3][0] == 'm' ? chnm.m : chnm[""]
			}
			if (a[4]) {			// bass
				b = a[4][0].toUpperCase()
				b = abc2svg.letmid[b]
				if (b != undefined) {
					switch (a[4][1]) {
					case "#": b = (b + 1) % 12; break
					case "b": b = (b + 11) % 12; break
					}
					b = b - r
					if (b < 0)
						b += 12
				}
			}

		// generate the notes of the chord
		chmid = chcr(b, ch)
		n = chmid.length
		r += trans
		for (m = 0; m < n; m++)
			chmid[m] += r
	} // gench()

	// stop the previous chord by setting its duration
	function set_dur(s2, tim) {			// previous chord
		if (s2.dur
		 || tim == s2.time
		 || s2.nhd == undefined)	// no chord yet
			return
		s2.dur = tim - s2.time
		for (var m = 0; m <= s2.nhd; m++)
			s2.notes[m].dur = s2.dur
	} // set_dur()

	// add a letter note to a chord
	function addnt(s, p) {
		p = "GHIJKghijk".indexOf(p)
		if ((p % 5) >= chmid.length)		// no such note in this chord
			return
		s.nhd++
		s.notes.push({
			midi: chmid[p % 5]		// skip the bass
		})
		if (p >= 5)
			s.notes[s.nhd].midi += 12	// upper octave
	} // addnt()

	// generate a chord from its digits
	function gennum(s, p) {
	    var	c, nt,
		m = 0

		if (p[0] == '*') {
			m++				// basse
//fixme: to do
		}
		for ( ; m < p.length; m++) {
			c = +p[m]
			switch (c) {
			case 1:
				c = chmid[0]
				break
			case 3:
				c = chmid[1]
				break
			case 5:
				c = chmid[2]
				break
			default:			// 7, 8, 9
				while (!chmid[c])
					c--
				c = chmid[c]
				if (s.notes[s.nhd] && s.notes[s.nhd].midi >= c)
					c = 0
				break
			}
			if (c) {
				s.nhd++
				nt = {
					midi: c
				}
				s.notes.push(nt)
			}
			while (p[m + 1] == "'") {
				if (c)
					nt.midi += 12
				m++
			}
			while (p[m + 1] == ',') {
				if (c)
					nt.midi -= 12
				m++
			}
		}
	} // gennum()

	// insert a chord in the chord voice
	function insch(s_next, tim) {
		if (!chmid.length)
			return			// no defined chord yet
	    var	s, m,
		s2 = vch.last_sym,
		i = rhy[ti++]

		switch (i[0]) {
		case '+':			// same chord
			if (ti != 1)		// if not first +
				return
			ti = 0
			if (rhy[1])
				i = rhy[1]	// explicit continuous chord
			break
		case undefined:
		case '0':
		case 'z':
			set_dur(s2, tim)	// stop the previous chord
			return
		}

		s = {
			v: vch.v,
			p_v: vch,
			type: C.NOTE,
			nhd: -1,
			notes: []
		}
		s.time = tim
		switch (i[0]) {
		case 'c':
			s.nhd = chmid.length - 1
			for (m = 0; m <= s.nhd; m++)
				s.notes.push({
					midi: chmid[m]
				})
			break
		case '[':
			for (m = 1; m < i.length - 1; m++) {
				addnt(s, i[m])
				while (i[m + 1] == ',')
					s.notes[s.nhd].midi -= 12,
					m++
			}
			break
		default:
			if ((i[0] >= '1' && i[0] <= '9')
			 || i[0] == '*') {
				gennum(s, i)		// chords as digits
				break
			}
			addnt(s, i[0])			// chords as letters
			m = 1
			while (i[m] == ',')
				s.notes[0].midi -= 12,
				m++
			break
		case 'f':
			s.notes[0] = {
				midi: chmid[0] - 12
			}
			s.nhd = 0		// keep the chord root
			break
		case '+':			// no rhythm
		case 'b':
			s.nhd = chmid.length
			s.notes.push({
				midi: chmid[0] - 12
			})
			for (m = 0; m < s.nhd; m++)
				s.notes.push({
					midi: chmid[m]
				})
			break
		}
		if (s.nhd < 0)
			return

		// don't double the mediant (when a bass)
		if (inv
		 && s.notes[0].midi % 12 == s.notes[1].midi % 12)
			s.notes[1].midi = s.notes[3].midi - 12	// tonic
			
		s.prev = s2			// previous chord
		s2.next = s
		set_dur(s2, tim)		// stop the last chord
		
		vch.last_sym = s

		if (s_next) {				// if not last symbol of the tune
			s.ts_next = s_next		// insert before a bar
			s.ts_prev = s_next.ts_prev
			s_next.ts_prev = s
//			if (s.ts_prev)
				s.ts_prev.ts_next = s
		} else {				// no bar at end of tune
			while (s2.ts_next)
				s2 = s2.ts_next
			s2.ts_next = s
			s.ts_prev = s2
		}
	} // insch()

	// -- genchrd --

	// set the chordnames defined by %%MIDI chordname
	chnm = abc2svg.chnm
	if (cfmt.chord.names) {
		for (k in cfmt.chord.names) {
			chnm[k] = []
			for (i = 0; i < cfmt.chord.names[k].length; i++)
				chnm[k].push(+cfmt.chord.names[k][i])
		}
	}

	// create the chord voice
	vch = {
		v: voice_tb.length,
		id: "_chord",
		time: 0,
		sym: {
			type: C.BLOCK,
			subtype: "midiprog",
			chn: 15,				// MIDI channel
			instr: cfmt.chord.prog || 0,
			time: 0,
			dur: 0,
			next: {
				type: C.BLOCK,
				subtype: "midictl",
				time:0,
				dur: 0,
				ctrl: 7,		// volume
				val: cfmt.chord.vol || 75
			}
		}
	}
	vch.sym.p_v = vch
	vch.sym.v = vch.v
	vch.sym.next.p_v = vch
	vch.sym.next.v = vch.v
	vch.sym.next.prev = vch.sym
	vch.last_sym = vch.sym.next
	voice_tb.push(vch)

	s = first

	// insert the MIDI program and the volume of the chord voice after the tempo
	while (s.type != C.TEMPO
	 && s.ts_next && !s.ts_next.dur)	// but before the first note
		s = s.ts_next
	vch.sym.ts_prev = s
	vch.sym.ts_next = vch.sym.next
	vch.sym.next.ts_prev = vch.sym
	vch.sym.next.ts_next = s.ts_next
	if (s.ts_next)
		s.ts_next.ts_prev = vch.sym.next
	s.ts_next = vch.sym

	// loop on the symbols and add the accompaniment chords
	if (cfmt.chord.gchon != false)
		gchon = 1			// chordon by default
	gchnb = cfmt.chord.gchnb || 1
	s = first
	bld_rhy(cfmt.chord.rhy			// chord rhythm
		|| meterhy(s.p_v.meter))
	ti = 0					// time index in rhy
	while (1) {
		if (gchon) {
			while (s.time > nextim
			       && ti < rhy.length) {
				insch(s, nextim)	// generate the rhythm
				nextim += rhy[0] == '+' ? 100000 : dt
			}
			if (s.bar_type == "|"		// if a normal measure bar
			 && rhy[0] != '+'
			 && nextim != s.time) {		// and wrong times
//fixme: measure error
				nextim = s.time		// resynchronize
				ti = 0
			}
		}
		if (gchon && s.a_gch) {
			for (i = 0; i < s.a_gch.length; i++) {
				if (s.a_gch[i].type != 'g')
					continue
				gench(s, i)
				if (rhy[0] == '+'
				 && chmid.length)
					nextim = s.time
				break
			}
		}
		if (!s.dur) {
			if (s.bar_num) {		// if measure bar
				if (gchnb == 1
				 || !((s.bar_num - 1) % gchnb))
					ti = 0		// reset the time index
			} else if (s.wmeasure) {	// if meter
				md = s.wmeasure
				if (rhy[0] != '+')
					bld_rhy(meterhy(s))
			} else if (s.subtype == "midigch") {
				if (gchon && s.rhy)
					bld_rhy(s.rhy)	// new rhythm
				if (s.gchnb)
					gchnb = s.gchnb
				if (s.on != undefined) {
					gchon = s.on
					if (!gchon)
						set_dur(vch.last_sym, s.time)
				}
			}
		}
		if (!s.ts_next)
			break
		s = s.ts_next
	}
	if (gchon)  {
			while (s.time + (s.dur || 0) > nextim) {
				insch(s.dur ? null : s, nextim)
				if (rhy[0] == '+')
					break
				nextim += dt
			}
		set_dur(vch.last_sym, s.time + (s.dur || 0))
	}
} // genchrd()

// define the commands %%chordkit and %%chord
if (!abc2svg.mhooks)
	abc2svg.mhooks = {}
abc2svg.mhooks.chord = abc2svg.chord.set_hooks
