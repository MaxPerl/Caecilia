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
		elm_voice_spinner => undef,
		ecore_timer => undef,
		events => {},
		voice_pointers => [],
		preview_scale_factor => 1,
		is_finished => 0,
		saved_pos => 0,
		video_del => undef,
		};
	
	bless($obj,$class);
	$obj->init_ui($app,$box);
	return $obj;
}

sub reset_midi {
	my ($self) = @_;
	
	my $video = $self->elm_video;
    $video->stop();
    $self->video_del($video);

    # Here we create a new Elm_Video with no midi file
    my $box = $self->elm_midibar();
    my $video_new = pEFL::Elm::Video->add($box);
    $self->elm_video($video_new);

    my $emotion = $video_new->emotion_get();
    $emotion->smart_callback_add("position_update", \&_pos_update, $self);
    $emotion->smart_callback_add("playback_finished", \&_playback_finished_cb, $self);
    $emotion->smart_callback_add("open_done", \&_open_done_cb, $self);

    $emotion->file_set("");
	
	$self->is_finished(0);
	$self->saved_pos(0);
	$self->hide_voice_pointers();
	
	my $progress_spinner = $self->elm_progress_spinner();
	
	$progress_spinner->min_max_set(0,0);
	$progress_spinner->value_set(0);
	
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

    my $video = pEFL::Elm::Video->add($box);
    $self->elm_video($video);
	
	# Play Button
	my $play_b = pEFL::Elm::Button->new($box);
    $play_b->text_set("Play Preview");
    my $icon_play = pEFL::Elm::Icon->add($play_b);
    $icon_play->standard_set("media-playback-start");
    $play_b->part_content_set("icon",$icon_play);
    $box->pack_end($play_b);$play_b->show();
    
    # Backward Button
    my $rewind_b = pEFL::Elm::Button->new($box);
    my $icon_backward = pEFL::Elm::Icon->add($rewind_b);
	$icon_backward->standard_set("media-seek-backward");
	$rewind_b->part_content_set("icon",$icon_backward);
    $box->pack_end($rewind_b);$rewind_b->show();

    # Forward Button
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

    my $voice_label = pEFL::Elm::Label->new($box);
    $voice_label->text_set("Y-Scroll to Voice");
    $voice_label->show(); $box->pack_end($voice_label);
	
    my $voice_spinner = pEFL::Elm::Spinner->add($box);
    $voice_spinner->min_max_set(0,64);
    $voice_spinner->value_set(1);
    $voice_spinner->show();$box->pack_end($voice_spinner);
    $self->elm_voice_spinner($voice_spinner);
	
    my $renderer_error_b = pEFL::Elm::Button->add($box);
    $renderer_error_b->text_set("No errors");
    $box->pack_end($renderer_error_b); $renderer_error_b->show();
    $self->app->renderer->elm_error_btn($renderer_error_b);
    
    my $emotion = $video->emotion_get();
    $emotion->smart_callback_add("position_update",\&_pos_update,$self);
    #$emotion->smart_callback_add("length_change",\&_pos_update,$self);
    $emotion->smart_callback_add("playback_finished",\&_playback_finished_cb,$self);
    $emotion->smart_callback_add("open_done",\&_open_done_cb,$self);

    $play_b->smart_callback_add("clicked" => \&play, $self);
    $rewind_b->smart_callback_add("clicked" => \&rewind, $video);
    $forward_b->smart_callback_add("clicked" => \&forward, $video);
    $renderer_error_b->smart_callback_add("clicked" => \&Caecilia::Renderer::show_errors, $self->app->renderer);

    $progress_spinner->smart_callback_add("changed" => \&change_pos, $self);

    $main_box->pack_end($box); $box->show();
}

sub _open_done_cb {
    my ($data, $obj, $ev) = @_;
    $data->hide_voice_pointers;
    $obj->position_set($data->saved_pos());
    $data->video_del()->del; 
    $data->video_del(undef);
}

sub _playback_finished_cb {
    my ($self, $em, $event) = @_;
    
    my $video = $self->elm_video();
    $video->emotion_get->play_set(0);
    $self->hide_voice_pointers;
    $self->is_finished(1);
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
    
    # Get the text of the entry and create the preview abc
    # (get text already converts text to utf8!! so markup_to_utf8 and decode are
    # not necessary here again
    my $text = $self->app->current_tunebook->create_preview_abc($self->app->entry->get_text());
    # if (!defined($text)) [e.g. Header is selected in splitmode !!!] 
    # =>=> Don't create MIDI!!!
    return unless (defined($text));
    
    # TODO: midi positions are links into the notes of the preview, so it must be up-to-date?
    #$self->app->preview->preview_cb() unless ($self->app->preview->up_to_date());
    # NICHT MEHR ERFORDERLICH, weil sowohl für preview als auch für midi nur noch eine
    # Einstiegsfunktion existiert Preview::preview_cb()
    
    # same text as the preview = same offsets in Preview and MIDI (istart)
    $text = $self->app->renderer->preview_header() . $text;
    	
    # Scale stylesheet directive isn't supported in preview
    #$text =~ s/%%scale.*\n//g if ($opts{mode} eq 'preview');
    # create new files for preview	
    open my $fh, ">:encoding(utf8)", $self->abc_file() or die "Could not open abc file: $!\n";
    print $fh "$text";
    close $fh;
    
    my $preview = $self->app->preview;
    $preview->render_preview($self->app->tmpdir . "/preview");
    
    my $config = $self->app->settings->load_config();
    $self->preview_scale_factor($config->{preview_scale});
    
    my $notes = $self->to_notes();
    $self->generate_events($notes);
    my ($success, $midi_errors) = $self->to_midi($notes);

	if (!$success) {
    	$self->app->_show_info("MIDI creation error:", join("<br>", @$midi_errors));
		return;
	}
	
    my $opus = MIDI::Opus->new({'from_file' => $self->midi_file});
    
    # The problem is: Opus has two tracks. Only one with notes :-(
    # So we have to check all tracks for the length
    foreach my $track ($opus->tracks()) {
    
    	my ($score, $end_time) = MIDI::Score::events_r_to_score_r($track->events_r);
    	$play_length = $end_time / 100 if ( ($end_time / 100) > $play_length);
    }

    # To create a new GSTREAMER PIPELINE (and no auto playback when generating new midi file!!!)
    # Create a new Elm Video

    # First save position    
    my $video = $self->elm_video;
    
    if ($video) {
    	my $pos = $video->play_position_get();
    	$video->stop();
    	$self->saved_pos($pos);

    	# IMPORTANT: We cannot delete video here (otherwise we get a segfault)
    	# So do it, when the new file was opened in the new (!) Elm_Video
    	# (see open_done_cb)
    	$self->video_del($video);
    }

    # Here we create our new Elm_Video
    my $box = $self->elm_midibar();
    my $video_new = pEFL::Elm::Video->add($box);
    $self->elm_video($video_new);

    my $emotion = $video_new->emotion_get();
    $emotion->smart_callback_add("position_update", \&_pos_update, $self);
    $emotion->smart_callback_add("playback_finished", \&_playback_finished_cb, $self);
    $emotion->smart_callback_add("open_done", \&_open_done_cb, $self) if ($video);

    $emotion->file_set($self->midi_file);
    
    if (@$midi_errors) {
    	$self->app->_show_info("MIDI creation error:", join("<br>", @$midi_errors));
	}
}

sub change_pos {
    my ($self, $spinner, $event_info) = @_;
    my $video = $self->elm_video();
    my $pos = $spinner->value_get();
    $region_old_y = 0;
    $video->play_position_set($pos);
}

sub _pos_update {
	my ($self, $emotion, $event_info) = @_;
	
	# If Emotion is not playing, don't do anything (especially don't show
	# voice pointers (again))
	return unless $emotion->play_get(); 

	my $progress_spinner = $self->elm_progress_spinner; 
	
	my $position = $emotion->position_get();
	
	# WORKAROUND: play_length() does not work on midi files
	#my $duration = $emotion->play_length_get();
	my $duration = $play_length;
	
	$progress_spinner->min_max_set(0,$duration);
	$progress_spinner->value_set($position);
	
	my $scroll_y = 0;
	
	my $key = sprintf("%.1f",$position);
	
	if ( defined( $self->{events}->{$key} ) ) {
	    
	    	my $preview = $self->app->preview();
	    	my $scale_factor = $self->preview_scale_factor();;
	    
	    	my $events = $self->{events}->{$key};
	    	my $viewer = $preview->elm_viewer();
	    	my ($vx,$vy,$vw,$vh) = $viewer->geometry_get();
	    	my $region_x=0; my $region_y=0; my $region_w=0; my $first_pointer_per_pos_y=undef; 
	    	foreach my $event (@$events) {
			my $voice_spinner = $self->elm_voice_spinner();
			my $follow_voice = $voice_spinner->value_get() || 1;
	
	        	# We added the ABC file some commands (e.g. %%fullsvg 1, %%musicfont etc)
	        	# Offset ist nun bereits in istart enthalten, weil MIDI und 
				# PREVIEW nun denselben Text verwenden 
				# (s.o. generate_mid: $text = $self->app->renderer->preview_header() . $text)
				# => hier nicht mehr $istart = $event->{istart} + $renderer->preview_beginabc erforderlich!!!!
	        	my $istart = $event->{istart};
	        	my $voice = $event->{voice};
	
			if ($voice == $follow_voice-1) {
				$scroll_y = 1;
		}

	        my @pointers = @{$self->{voice_pointers}};
	        my %notes = %{$preview->{notes}}; 
	        my $note = $notes{$istart};
	        if ($note->{page_nr} != $self->app->preview->page() ) {
	        	$self->app->preview->page($note->{page_nr});
	        	$self->app->preview->render_preview($self->app->tmpdir . "/preview");
	        	$region_old_y = 0;
	        }
	        
            	my $canvas = $preview->elm_scroller->evas_get();
            
            
	        my ($sx,$sy,$sh) = $preview->elm_scroller->geometry_get();
	        my $x = ($scale_factor*$note->{x}) + $vx-2;
		my $y = ($scale_factor*$note->{y}) + $note->{svg_offset} +$vy;
			
		$region_x = $x-$vx-($vw/4) if ($x>$region_x);
		# This is tricky: We don't want that the pointer jumps up and down on multiple voices
		# so never jump up 	
		$region_y = $y-$vy-($vh/4) if ($y>$region_y);	
			
		# and use only the follow voice pointer per position as anchor to center scrolling
		if ($voice == $follow_voice-1) {				
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
	    
		if ($scroll_y) {
	    	$region_old_y = $first_pointer_per_pos_y;
			$preview->elm_scroller->region_show($region_x, $first_pointer_per_pos_y, $vw/2,$vh/2);
		}
		else {
			$preview->elm_scroller->region_show($region_x, $region_old_y, $vw/2,$vh/2);
		}
	}
}

sub play {
    my ($self, $btn, $event_info) = @_;
    
    my $video = $self->elm_video();
    
    if ($self->is_finished()) {
    	$video->play_position_set(0);
    	$self->elm_progress_spinner->value_set(0);
    	$self->is_finished(0);
    }
    
    my $emotion = $video->emotion_get();
    if ($emotion->play_get()) {
		$video->emotion_get->play_set(0);
		$self->hide_voice_pointers();
	}
	else {
		$video->play()
	}
}

sub hide_voice_pointers {
	my ($self) = @_;
	my $voice_pointers = $self->voice_pointers();
	foreach my $p (@$voice_pointers) {
		$p->hide() if ($p);
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
    
    ###########################################################
    # ERROR HANDLING IS HERE NOT NECESSARY ANY MORE, because everything is now only
    # done in generate_preview (there is only one callback preview_cb() )
    #
    # Save abc2svg Errors for the Show Errors button of Renderer
    #my @abc2svg_errors = @{ $val->{errors} };
	#my $abc2svg_errors = "";
	#foreach my $error (@abc2svg_errors) {
	#	$error =~ s/.*\://;
	#	$error =~ m/(\d+),\d+$/;
		# The first Line is in Caecilia 1 (not 0 as in Elm_Entry)!! 
		# So add 1 to the line_nr of abc2svg
		# MIDI verwendet jetzt den selben Text wie Preview, daher statt 
		# $1 + 1 => $1-5 
		# TODO: Split Modus => Fehlerzeilen sind hier noch zu hoch wegen File Header
	#	my $line_nr = $1 -5;
	#	$error =~ s/\d+,(\d+)$/$line_nr,$1/;
	#	$abc2svg_errors = $abc2svg_errors . "<br/>" . $error;
	#}
	
	#print "ERROR MSG $abc2svg_errors\n";
	#$self->app->renderer->error_message($abc2svg_errors);
	#if ($abc2svg_errors) {
	#	$self->app->renderer->elm_error_btn->text_set("Show Errors");
	#}
	#else {
	#	$self->app->renderer->elm_error_btn->text_set("No Errors");
	#}
	#
	###########################################################
	    
    return $val->{output};
}

# Parst eine Notenzeile der JS-Ausgabe (to_notes).
# Spalten: time instr channel pitch duration voice istart
# Liefert eine leere Liste, wenn die Zeile keine Note ist (Kommentare, "v:"-Zeilen
# haben keine Tab-getrennten Felder und fallen ueber den voice-Check raus).
# $istart kann undef sein (Note ohne Position im ABC-Quelltext).
sub _parse_note_line {
    my ($line) = @_;

    return if $line =~ m/^\s*#/;

    my ($time, $instr, $channel, $pitch, $duration, $voice, $istart) = split(/\t/, $line);
    return unless defined($voice) && length($voice);

    $time =~ s/^\s+//;    # Notenzeilen beginnen mit einem Leerzeichen
    return unless length($time) && length($channel) && length($pitch) && length($duration);

    # Unterstimmen (0.1, 1.1, ...) kommen in den Track ihrer Hauptstimme.
    # Den Channel der Hauptstimme gibt abc2svg ihnen schon selbst.
    $voice =~ s/\..*$//;

    $istart =~ s/\s+$// if defined($istart);

    return ($time, $instr, $channel, $pitch, $duration, $voice, $istart);
}

sub generate_events {
    my ($self, $notes) = @_;

    my %events;
    # Offset ist nun bereits in istart enthalten, weil MIDI und PREVIEW nun denselben
    # Text verwenden (s.o. generate_mid: $text = $self->app->renderer->preview_header() . $text)
    #my $offset = $self->app->renderer->preview_beginabc_length();

    foreach my $line (split(/\n/, $notes)) {
        my ($time, undef, undef, undef, undef, $voice, $istart) = _parse_note_line($line);
        next unless defined($time);

        # Ohne istart gibt es keine Position im Preview, also nichts zu verlinken
        next unless defined($istart) && length($istart);

        $time = $time / 100;
        $time = sprintf("%.1f", $time);

        my %event = (voice => $voice, istart => $istart);

        if (defined($events{$time})) {
            push @{ $events{$time} }, \%event;
        }
        else {
            $events{$time} = [];
            push @{ $events{$time} }, \%event;
        }

        # Add a link to midi position in the notes hash of PREVIEW
        $self->app->preview->{notes}->{ $istart }->{midi_position} = $time;
    }
    $self->{events} = \%events;
}

sub to_midi {
    my ($self, $notes) = @_;
    
    my @midi_errors;     # Meldungen fuer "Show Errors"
    my %voices_of_channel; # wichtig, um die stummen Stimmen anzuzeigen, falls mehr als 15
    my @muted_voices; # hier werden für die Ausgabe dann alle stummen Stimmen gespeichert

    my @lines = split(/\n/, $notes);

    my %program_of_channel;

    # 1. Programm pro Channel aus den "MIDI program"-Zeilen holen.
    #    Der Channel kommt von abc2svg (0-basiert, Channel 9 = Drums wird dort
    #    ausgelassen). Welche Stimme welchen Channel benutzt, steht in den
    #    Notenzeilen. Channels ohne "MIDI program"-Zeile sind Klavier (0).
    foreach my $line (@lines) {
        next unless $line =~ m/^\s*v:\d+\s+MIDI program\s+(\d+)\s+(\d+)/;
        my ($ch, $program) = ($1, $2);
        $program_of_channel{$ch} = $program;
    }

	# 2. Notenzeilen einlesen
    my @notes;
    foreach my $line (@lines) {
        my ($time, $instr, $channel, $pitch, $duration, $voice, $istart) = _parse_note_line($line);
        next unless defined($time);
 
        # Noten ohne istart gehoeren trotzdem in die MIDI-Datei
        $istart = '' unless defined($istart);
 
        # Absicherung, falls der Channel keine Zahl ist (z.B. "undefined")
        $channel = 0 unless $channel =~ m/^\d+$/;
 
        push @notes, [$time, $channel, $pitch, $duration, $voice, $istart];
    }


    # 3. MIDI kennt nur die Channels 0-15, abc2svg zaehlt aber einfach weiter
    # (ab der 16. Stimme 16, 17, ...). Dann teilen sich Stimmen mit demselben
    # Programm einen Channel. Bis Channel 15 bleibt alles unveraendert.

    # Alle benutzten abc2svg-Channels sammeln (jeder nur einmal)
    my %is_used;
    foreach my $note (@notes) {
        my $channel = $note->[1]; my $voice = $note->[4];
        $is_used{$channel} = 1;
        # Save voice for error messages, if it must be muted
        $voices_of_channel{$channel}{$voice} = 1; 
    }
    my @used_channels = sort { $a <=> $b } keys %is_used;

    # Normalfall: jeder Channel bleibt, wie abc2svg ihn vergeben hat
    my %midi_channel;    # abc2svg-Channel => MIDI-Channel
    foreach my $abc2svh_ch (@used_channels) {
        $midi_channel{$abc2svh_ch} = $abc2svh_ch;
    }

    if (@used_channels && $used_channels[-1] > 15) {
        %midi_channel = ();
        my %channel_of_program;    # Programm => MIDI-Channel
        my $next_free = 0;

        foreach my $abc2svh_ch (@used_channels) {
            # Channel 9 ist von abc2svg für Schlagzeug reserviert und wird daher nicht umgelegt
            if ($abc2svh_ch == 9) {
                $midi_channel{$abc2svh_ch} = 9;
                next;
            }

            my $program = $program_of_channel{$abc2svh_ch};
            $program = 0 unless defined($program);

            if (!defined($channel_of_program{$program})) {
                # Auf Channel 9 darf auch bei der Neuordnung kein anderes Instrument als Schlagzeug gelegt werden
				$next_free++ if $next_free == 9;

                if ($next_free > 15) {
                    warn "MIDI: mehr als 15 verschiedene Instrumente, Manche Stimmen erklinen nicht\n";
                    # Kein Channel mehr frei: die Stimmen dieses Channels bleiben stumm
    				foreach my $voice (keys %{ $voices_of_channel{$abc2svh_ch} }) {
        				push @muted_voices, $voice + 1;    # Anzeige ab 1, wie bei V: 1, V: 2, ...
    				}
                }
                else {
                    $channel_of_program{$program} = $next_free;
                    $next_free++;
                }
            }
            $midi_channel{$abc2svh_ch} = $channel_of_program{$program};
        }
    }

	if (@muted_voices) {
    push @midi_errors, "More different instruments than the possible 15 MIDI channels. "
        . "These voices are muted: " . join(", ", sort { $a <=> $b } @muted_voices);
	}
	
    my %program_of_midi_channel;
    foreach my $ch (@used_channels) {
        next unless defined($midi_channel{$ch});     # stumme Channel werden übersprungen
        my $program = $program_of_channel{$ch};
        next unless defined($program);    # keine "MIDI program"-Zeile: kein patch_change (Klavier)
        $program_of_midi_channel{ $midi_channel{$ch} } = $program;
    }

    my %tracks;

    # 4. Setup-Track (Schluessel "-1" => kommt beim Sortieren zuerst) mit den
    #    Programmwechseln. Ein Track ist nur ein Container in der Datei und
    #    verbraucht keinen Channel; Channels gelten global ueber alle Tracks.
    foreach my $ch (keys %program_of_midi_channel) {
        push @{ $tracks{"-1"} }, ['patch_change', 0, $ch, $program_of_midi_channel{$ch}];
    }

    # 5. Noten: ein Track pro Hauptstimme
    foreach my $note (@notes) {
        my ($time, $abc2svh_ch, $pitch, $duration, $voice, $istart) = @$note;

        my $channel = $midi_channel{$abc2svh_ch};
        next unless defined($channel); # stumme Channel werden übersprungen

        if (!defined($tracks{$voice})) {
            $tracks{$voice} = [];
        }

        push @{ $tracks{$voice} }, ['text_event', $time, "T:$time V:$voice ISTART:$istart"];
        push @{ $tracks{$voice} }, ['note', $time, $duration, $channel, $pitch, 64];
    }

    my @tracks;
    foreach my $voice (sort { $a <=> $b } keys %tracks) {
        my $events_r = MIDI::Score::score_r_to_events_r($tracks{$voice});
        push @tracks, MIDI::Track->new({ events => $events_r });
    }

    my $opus = MIDI::Opus->new({ 'format' => 1, 'ticks' => 50, 'tracks' => \@tracks });
    $opus->write_to_file($self->midi_file);
    
    # Erfolg heisst: die Datei existiert
	my $success = (-e $self->midi_file) ? 1 : 0;
	if (!$success) {
    	push @midi_errors, "Die MIDI-Datei konnte nicht geschrieben werden.";
	}

	return ($success, \@midi_errors);
}

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|abc_file|events|midi_file|abc2svg_path|preview_scale_factor|voice_pointers|elm_midibar|elm_video|elm_progress_spinner|is_finished|saved_pos|video_del|elm_voice_spinner|ecore_timer/;
	
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

let value = {
    output: '',
    errors: [],
};

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
abc2svg.loadjs('midigen.js');
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
	errmsg: function(message, line_number, column_number) {
        console.log("Error: " + message + " at "+ line_number + "," + column_number);
        value.errors.push(message + " at "+ line_number + "," + column_number);
        
    },
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
		value.output = value.output + '\n' + ' v:' + s.v + '  MIDI control ' + s.ctrl + ' ' + s.val;
		}, // midi_ctrl()
		midi_prog: function(po, s) {
			//console.log("MIDI PROG EVENT VOICE" +s.v + "CHANEL " + (s.chn) + " INST" + s.instr + "\n");
			if (s.instr != undefined)
				value.output = value.output + '\n' + ' v:' + s.v + '  MIDI program '+ s.chn + ' '
					+ s.instr;
			else
				value.output = value.output + '\n' + ' v:' + s.v + '  MIDI channel ' + s.chn;
		}, // midi_prog()
		note_run: function(po, s, k, t, d) {
	value.output = value.output + '\n' + ' ' + (t * 100).toFixed(0) +
		'\t' + po.c_i[po.v_c[s.v]] +
		'\t' + po.v_c[s.v] +             // neu: Channel
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

	value.output = value.output + '# MIDI flow (time and duration in 1/100s)\n\
# time instr  pitch  duration voice istart';

	// loop on the tunes and
	while (1) {
		e = tunes.shift()
		if (!e)
			break

		audio.add(e[0], e[1], e[3])	// generate the music
		dvn(e[1])

		t = (e[2].T || '(no title)').replace(/\n/g, ' / ')
		value.output = value.output + '\n' + '# ------- tune ' +
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
value;
EOF
}

1;
