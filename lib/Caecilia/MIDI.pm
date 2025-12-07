package Caecilia::MIDI;
use 5.006001;
use strict;
use warnings;
use utf8;

require Exporter;

use pEFL::Evas;
use pEFL::Elm;
use pEFL::Emotion;
use pEFL::Evas::Rectangle;

use JavaScript::QuickJS;
use MIDI;

our @ISA = qw(Exporter);

our $AUTOLOAD;

my $region_old_y = 0;
our $play_length = 0;

sub new {
	my ($class, $app, $box) = @_;
	
	# Get index
	
	my $obj = {
		app => $app,
		abc_file => $app->tmpdir . "/midi.abc",
		midi_file => $app->tmpdir . "/out.mid",
		# TODO: abc2svg_path should be an option in app not in renderer or midi
		abc2svg_path => $app->share_dir . "/abc2svg/",
		elm_video => undef,
		elm_midibar => undef,
		elm_progress_spinner => undef,
		ecore_timer => undef,
		events => {},
		voice_pointers => [],
		preview_scale_factor => 1,
		};
	
	bless($obj,$class);
	$obj->init_ui($app,$box);
	return $obj;
}

sub init_ui {
    my ($self, $app, $main_box) = @_;
    
    my $box = pEFL::Elm::Box->add($main_box);
    $box->horizontal_set(1);
    # how a container object should resize a given child within its area
    $box->size_hint_weight_set(EVAS_HINT_EXPAND,0);
    # how to align an object
    $box->size_hint_align_set(EVAS_HINT_FILL, 0.5);
    $self->elm_midibar($box);

    my $mid_b = pEFL::Elm::Button->add($box);
    $mid_b->text_set("Generate Midi");
    $box->pack_end($mid_b); $mid_b->show();

    my $video = pEFL::Elm::Video->add($box);
    $video->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
    $self->elm_video($video);

    # basic tutorial code
    # basic text button
    my $rewind_b = pEFL::Elm::Button->new($box);
    my $icon_backward = pEFL::Elm::Icon->add($rewind_b);
	$icon_backward->standard_set("media-seek-backward");
	$rewind_b->part_content_set("icon",$icon_backward);
    $box->pack_end($rewind_b);$rewind_b->show();

    # basic tutorial code
    # basic text button
    my $play_b = pEFL::Elm::Button->new($box);
    my $icon_play = pEFL::Elm::Icon->add($play_b);
	$icon_play->standard_set("media-playback-start");
	$play_b->part_content_set("icon",$icon_play);
    $box->pack_end($play_b);$play_b->show();

    # basic tutorial code
    # basic text button
    my $forward_b = pEFL::Elm::Button->new($box);
    my $icon_forward = pEFL::Elm::Icon->add($forward_b);
	$icon_forward->standard_set("media-seek-forward");
	$forward_b->part_content_set("icon",$icon_forward);
    $box->pack_end($forward_b);$forward_b->show();

    my $progress_spinner = pEFL::Elm::Slider->add($box);
    $progress_spinner->size_hint_align_set(EVAS_HINT_FILL,0);
    $progress_spinner->size_hint_weight_set(EVAS_HINT_EXPAND,0.0);
    $progress_spinner->step_set(1);
    $progress_spinner->value_set(0);
    $box->pack_end($progress_spinner);$progress_spinner->show();
    $self->elm_progress_spinner($progress_spinner);

    my $emotion = $video->emotion_get();
    $emotion->smart_callback_add("position_update",\&_pos_update,$self);
    $emotion->smart_callback_add("length_change",\&_pos_update,$self);
    $emotion->smart_callback_add("playback_finished",\&_playback_finished_cb,$self);

    $mid_b->smart_callback_add("clicked" => \&generate_mid, $self);
    $play_b->smart_callback_add("clicked" => \&play, $video);
    $rewind_b->smart_callback_add("clicked" => \&rewind, $video);
    $forward_b->smart_callback_add("clicked" => \&forward, $video);

    $progress_spinner->smart_callback_add("changed" => \&change_pos, $video);

    $main_box->pack_end($box); $box->show();

}

sub _playback_finished_cb {
    my ($self, $em, $event) = @_;
    my $video = $self->elm_video();
    $video->stop();
    $video->file_set("");
    $video->file_set($self->midi_file);
    $self->elm_progress_spinner->value_set(0);
    $video->pause();
}

sub generate_mid {
    my ($self) = @_;
    
    # Clear old-files
	if (-e $self->midi_file) {
		unlink $self->midi_file or die "Coud not unlink MIDI File\n";
    }
    
    if (-e $self->abc_file) {
    	unlink $self->abc_file or die "Coud not unlink ABC File\n";
    }
    
    if (-e $self->app->tmpdir . "/preview.notes") {
    	unlink ($self->app->tmpdir . "/preview.notes") or die "Coud not unlink Notes File\n";
    }
    undef %{ $self->events };
    foreach my $pointer (@{ $self->voice_pointers }) {
    	$pointer->del() if (defined($pointer));
    }
    undef @{ $self->voice_pointers };
    
    # Get the text of the entry and add a white background to the preview.abc
	my $text = $self->app->entry->elm_entry->entry_get();
	# convert $text to utf8
	$text = pEFL::Elm::Entry::markup_to_utf8($text);	
	$text = Encode::decode("utf-8",$text);
	
	# Scale stylesheet directive isn't supported in preview
	#$text =~ s/%%scale.*\n//g if ($opts{mode} eq 'preview');
	# create new files for preview	
	open my $fh, ">:encoding(utf8)", $self->abc_file() or die "Could not open abc file: $!\n";
	print $fh "$text";
	close $fh;
    
    my $preview = $self->app->preview;
    $preview->page(1);
    $preview->render_preview($self->app->tmpdir . "/preview");
    
    my $config = $self->app->settings->load_config();
    $self->preview_scale_factor($config->{preview_scale});
    
    my $notes = $self->to_notes();
    $self->generate_events($notes);
    $self->to_midi($notes);

    my $opus = MIDI::Opus->new({'from_file' => $self->midi_file});
    my $track = ($opus->tracks)[0];
    my ($score, $end_time) = MIDI::Score::events_r_to_score_r($track->events_r);
    $play_length = $end_time / 100;
    
    my $video = $self->elm_video;
    $video->stop();
    $video->file_set("");
    $video->file_set($self->midi_file);
    $video->play_position_set(0);
    $self->elm_progress_spinner->value_set(0);
}

sub change_pos {
    my ($video, $spinner, $event_info) = @_;
    
    $video->pause();
    my $pos = $spinner->value_get();
    $region_old_y = 0;
    $video->play_position_set($pos);
    $video->play();
}

sub _pos_update {
	my ($self, $emotion, $event_info) = @_;
	
	my $progress_spinner = $self->elm_progress_spinner; 
	
	my $position = $emotion->position_get();
	
	# WORKAROUND: play_length() does not work on midi files
	#my $duration = $emotion->play_length_get();
	my $duration = $play_length;
	
	$progress_spinner->min_max_set(0,$duration);
	$progress_spinner->value_set($position);
	
	my $key = sprintf("%.1f",$position);
	
	if ( defined( $self->{events}->{$key} ) ) {
	    
	    my $preview = $self->app->preview();
	    my $scale_factor = $self->preview_scale_factor();;
	    
	    my $events = $self->{events}->{$key};
	    my $viewer = $preview->elm_viewer();
	    my ($vx,$vy,$vw,$vh) = $viewer->geometry_get();
	    my $region_x=0; my $region_y=0; my $region_w=0; my $first_pointer_per_pos_y=undef; 
	    foreach my $event (@$events) {
	        # We added the ABC file some commands (e.g. %%fullsvg 1, %%musicfont etc)
	        # TODO: Save the added value as istart? DONE with preview_beginabc_length, istn't it?
	        my $renderer = $self->app->renderer();
	        my $istart = $event->{istart} + $renderer->preview_beginabc_length();
	        my $voice = $event->{voice};
	        my @pointers = @{$self->{voice_pointers}};
	        my %notes = %{$preview->{notes}}; 
	        my $note = $notes{$istart};
	        if ($note->{page_nr} != $self->app->preview->page() ) {
	        	#$self->elm_video->pause();
	        	$self->app->preview->page($note->{page_nr});
	        	$self->app->preview->render_preview($self->app->tmpdir . "/preview");
	        	$region_old_y = 0;
	        	#$self->elm_video->play();
	        }
	        
            my $canvas = $preview->elm_scroller->evas_get();
            
            
	        my ($sx,$sy,$sh) = $preview->elm_scroller->geometry_get();
	        my $x = ($scale_factor*$note->{x}) + $vx-2;
			my $y = ($scale_factor*$note->{y}) + $note->{svg_offset} +$vy;
			
			$region_x = $x-$vx-($vw/4) if ($x>$region_x);
			# This is tricky: We don't want that the pointer jumps up and down on multiple voices
			# so never jump up 
			$region_y = $y-$vy-($vh/4) if ($y>$region_y);
			if ($region_y < $region_old_y) {
				$region_y = $region_old_y;
			}
			
			# and use only the first pointer per position as anchor to center scrolling
			unless (defined($first_pointer_per_pos_y)) {				
				$first_pointer_per_pos_y = $region_y;
			}
			
	        if ($pointers[$voice]) {
	            my $p = $self->{voice_pointers}->[$voice];
	            if ($x<$sx || $y < $sy) {
					$p->hide();
				}
				else {
	            	$p->move(($scale_factor*$note->{x})+$vx-2, ($scale_factor*$note->{y})+$note->{svg_offset}+$vy);
	            	$p->show();
	            }
	        }
	        else {
	            my $n = pEFL::Evas::Rectangle->new($canvas);
	            $n->move($x, $y);
	            $n->resize($scale_factor *3,$scale_factor * 40);
	            $n->color_set(24,68,91,150);
	            $self->{voice_pointers}->[$voice]=$n;
	        }
	    }
	    
	    $region_old_y = $first_pointer_per_pos_y;
	    $preview->elm_scroller->region_show($region_x, $first_pointer_per_pos_y, $vw/2,$vh/2);
	}
}

sub play {
    my ($video, $btn, $event_info) = @_;
    
    my $emotion = $video->emotion_get();
    if ($emotion->play_get()) {
		$video->pause()
	}
	else {
		$video->play()
	}
}

sub forward {
    my ($video, $btn, $event_info) = @_;
    my $length = $video->length_get();
    my $pos = $video->play_position_get();
    $pos = $pos+10;
    if ($pos > $length) {
        $pos = 0;
    }
    $video->play_position_set($pos);
}

sub rewind {
    my ($video, $btn, $event_info) = @_;
    my $pos = $video->play_position_get();
    $pos = $pos-10;
    if ($pos < 0) {
        $pos = 0;
    }
    $video->play_position_set($pos);
}

sub to_notes {
    my ($self) = @_;
    my $val = JavaScript::QuickJS->new()
        ->set_globals(path => $self->abc2svg_path(), abc_file => $self->abc_file)
        ->os()->std()->helpers()->eval(js());
    return $val;
}

sub generate_events {
    my ($self, $notes) = @_;
    
    my %events;
    foreach my $line ( split(/\n/,$notes) ) {
        $line =~ m/\s*(\d+)\t\d*\t\d*\t\d*\t(\d*)\t(\d*)/;
        my $time = $1; 
        $time = $time/100; $time = sprintf("%.1f",$time);
        my $voice = $2;
        my $istart = $3;
        
        my %event = (voice => $voice, istart => $istart);
        
        next unless(defined($istart));
        if (defined( $events{$time} ) ) {
            push @{ $events{$time} }, \%event;
        }
        else {
            $events{$time} = [];
            push @{ $events{$time} }, \%event;
        }
        
        # Add a link to midi position in the notes hash of PREVIEW
        my $key_of_note = $istart + $self->app->renderer->preview_beginabc_length();
        $self->app->preview->{notes}->{$key_of_note}->{"midi_position"} = $time;
    }
    $self->{events} = \%events;
}

sub to_midi {
    my ($self, $notes) = @_;
    
    my %tracks;
    my @score;
    my %instruments;
    my $n;my $i;


    my @lines = split(/\n/, $notes);
    
    my %channels = ("0" => 0);
    my $last_channel = 0;
    my %voices = ();
    
    foreach my $line (@lines) {
    	if ($line =~ m/ v:\d+\s+MIDI program (\d+) (\d+)/ ) {
            my $voice = $1-1; my $program = $2;
            
            $voice =~ s/\..\d//;
            # Hack: Channel 10 ist for percussion only
        	$voice = $voice+1 if ($voice == 9);
            
            foreach my $channel (keys %channels) {
            	if ($program == $channels{$channel}) {
            		$voices{$voice} = $channel;
            		last;
            	}
            }
            
            if (!defined($voices{$voice})) {
            
            	# Hack: Channel 10 (=9) ist for percussion only
            	$last_channel = $last_channel+1;
            	$last_channel = 10 if ($last_channel == 9);
            
            	$voices{$voice} = $last_channel; 
            	$channels{$last_channel} = $program;
            }
        }
    }
    
    foreach my $channel (keys %channels) {
        push @{ $tracks{"$n"} }, ['patch_change', 0, $channel, $channels{$channel}];
    }
    
    foreach my $line (@lines) {
        
        next if $line =~ m/^#/;
        next if $line =~ m/^ v:/;
        my ($time, $instr, $pitch, $duration, $voice, $istart) = split(/\t/,$line);
        next if (!defined($voice));
        $voice =~ s/\..\d$//;
        chomp($istart);
        
        # Hack: Channel 10 ist for percussion only
        $voice = $voice+1 if ($voice == 9);
        
        if ( !defined($tracks{"$voice"} ) ) {
            $tracks{"$voice"} = [];
        }
        
        my $channel = $voices{$voice};
        push @{ $tracks{"$voice"} }, ['text_event', $time, "T:$time V:$voice ISTART:$istart"];
        push @{ $tracks{"$voice"} }, ['note', $time, $duration, $channel, $pitch, 64];
        
    }

    my @tracks; $n = 1;
    foreach my $voice (sort { $a <=> $b } keys %tracks) {
        my $events_r = MIDI::Score::score_r_to_events_r($tracks{"$voice"});
        my $track = MIDI::Track->new({events => $events_r});
        push @tracks, $track;
    }
    my $opus = MIDI::Opus->new(
        { 'format' => 1, 'ticks' => 50, 'tracks' => \@tracks});

    $opus->write_to_file($self->midi_file);
}

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|abc_file|events|midi_file|abc2svg_path|preview_scale_factor|voice_pointers|elm_midibar|elm_video|elm_progress_spinner/;
	
	my $attrib = $AUTOLOAD;
	$attrib =~ s/.*://;
	
	my $oldval = $self->{$attrib};
	$self->{$attrib} = $newval if defined($newval);
	if ($attrib eq "rehighlight") {
		#print "Highlight set to $newval\n" if $newval;
	}
	return $oldval;
}

sub DESTROY {}

sub js { 
return <<'EOF';
function load(fn) {
	return std.loadScript(fn)
}

var abc2svg = {
	print: print,
	printErr: function(str) {
		std.err.printf('%s\n', str)
	},
	quit: function() {
		std.exit(1)
	},
	readFile: std.loadFile,
	get_mtime: function(fn) {
		return new Date(os.stat(fn)[0].mtime)
	},
	loadjs: function(fn, relay, onerror) {
		try {
			load(fn[0] == '/' ? fn : (path + fn))
			if (relay)
				relay()
		} catch(e) {
			if (onerror)
				onerror()
			else
				abc2svg.printErr('Cannot read file ' + fn +
					'\n  ' + e.name + ': ' + e.message)
			return
		}
	} // loadjs()
} // abc2svg

abc2svg.loadjs('abc2svg-1.js');
abc2svg.loadjs('util/sndgen.js');
abc2svg.loadjs('util/chord.js');

let content = std.loadFile(abc_file);
let output = '';

var user = {
	anno_start: function(music_type, start_offset, stop_offset, x, y, w, h, s) {
	    std.printf('start_offset %s\n', start_offset);
	},
	read_file: function(fn) {	// read a file (main or included)
	    var	i,
		p = fn,
		file = abc2svg.readFile(p)

		if (!file && fn[0] != '/') {
			for (i = 0; i < abc2svg.path.length; i++) {
				p = abc2svg.path[i] + '/' + fn
				file = abc2svg.readFile(p)
				if (file)
					break
			}
		}

		if (!file)
			return file

		// memorize the file path
		// i = p.lastIndexOf('/')
		// if (i > 0) {
		//	p = p.slice(0, i)
		//	if (abc2svg.path.indexOf(p) < 0)
		//		abc2svg.path.unshift(p)
		// }

		// convert the file content into a Unix string
		i = file.indexOf('\r')
		if (i >= 0) {
			if (file[i + 1] == '\n')
				file =  file.replace(/\r\n/g, '\n')	// MS
			else
				file =  file.replace(/\r/g, '\n')	// Mac
		}

		// load the required modules (synchronous)
		abc2svg.modules.load(file)

		return file
	},
	errtxt: '',
	errmsg:			// print or store the error messages
		typeof abc2svg.printErr == 'function'
			? function(msg, l, c) { abc2svg.printErr(msg) }
			: function(msg, l, c) { user.errtxt += msg + '\n' }
} // user

// treat a file
function do_file(fn) {
    var	file = user.read_file(fn)

	if (!file) {
		if (fn != 'default.abc')
			user.errmsg('Cannot read file ' + fn)
		return
	}

	// generate
	try {
		abc.tosvg(fn, file)
	} catch (e) {
		abc2svg.abort(e)
	}
} // do_file()

let abc = new abc2svg.Abc(user);
		
do_file(abc_file);

abc2svg.abc_end = function() {
	function pit(v) {
		if (v - (v | 0))
			return v.toFixed(2)
		return v.toString()
	} // pit()

    var	e, t, vn,
	audio = ToAudio(),		// (in sndgen.js)
	po = {				// play object
		conf: {		// configuration
			speed: 1
		},
		tgen: 3600, 	// generate by (for) 1 hour
		get_time: function() { return -.3},	// (move the time origin)
		midi_ctrl: function(po, s, t) {
		output = output + '\n' + ' v:' + s.v + '  MIDI control ' + s.ctrl + ' ' + s.val;
		}, // midi_ctrl()
		midi_prog: function(po, s) {
			if (s.instr != undefined)
				output = output + '\n' + ' v:' + s.v + '  MIDI program '+ (s.chn + 1) + ' '
					+ s.instr;
			else
				output = output + '\n' + ' v:' + s.v + '  MIDI channel ' + (s.chn + 1);
		}, // midi_prog()
		note_run: function(po, s, k, t, d) {
			output = output + '\n' + ' ' + (t * 100).toFixed(0) +
				'\t' + po.c_i[po.v_c[s.v]] +
				'\t' + pit(k) +
				'\t' + (d * 100).toFixed(0) +
				'\t' + vn[s.p_v.id] +
				'\t' + s.istart;
		}, // note_run()
		v_c: [],		// voice to channel
		c_i: []			// channel to instrument
	},
	tunes = abc.tunes.slice(0)	// get a copy of the generated tunes

	// define the voice numbers
	function dvn(v_tb) {
	    var	i, n, p_v,
		v = 0

		vn = {}
		while (1) {
			p_v = v_tb[v]
			if (!p_v)
				break
			if (vn[p_v.id]) {
				v++
				continue
			}
			vn[p_v.id] = v.toString()
			n = 1
			while (1) {
				p_v = p_v.voice_down
				if (!p_v)
					break
				vn[p_v.id] = v.toString() + '.' + n.toString()
				n++
			}
			v++
		}
	} //dvn()

	// ---- abc_end() body ----

	if (user.errtxt)
		abc2svg.printErr('\n--- Errors ---\n' + user.errtxt)

	output = output + '# MIDI flow (time and duration in 1/100s)\n\
# time instr  pitch  duration voice istart';

	// loop on the tunes and
	while (1) {
		e = tunes.shift()
		if (!e)
			break

		audio.add(e[0], e[1], e[3])	// generate the music
		dvn(e[1])

		t = (e[2].T || '(no title)').replace(/\n/g, ' / ')
		output = output + '\n' + '# ------- tune ' +
			e[2].X + '. ' +
			t +
			' -------';
			
		po.stop = false
		po.s_end = null
		po.s_cur = e[0]		// first music symbol
		po.repn = false
		po.repv = 0

		abc2svg.play_next(po)
	}
} // abc_end()


abc2svg.abort = function(e) {
	abc2svg.print(e.message + '\n*** Abort ***\n' + e.stack)
	abc2svg.abc_end()
	abc2svg.quit()
}

abc2svg.abc_end();
output = output;
EOF
}

1;
