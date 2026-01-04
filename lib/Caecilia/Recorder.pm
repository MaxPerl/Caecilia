package Caecilia::Recorder;

use 5.006000;
use strict;
use warnings;

use utf8;
use File::ShareDir 'dist_dir';
use Caecilia::Settings;
use Caecilia::MyElm ":all";
use IPC::Open2;
use IPC::Open3;
use File::HomeDir;

use pEFL::Elm;
use pEFL::Evas;

require Exporter;

our @ISA = qw(Exporter);

our $AUTOLOAD;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Caecilia ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

# Preloaded methods go here.

sub new {
	my ($class, $app, %config) = @_;
	
	# TODO: abc2svg_path should be an option in app not in renderer or midi
	my $recorder_object = {
		app => $app, 
	    midi_file => $app->tmpdir . "/recorder.mid",
		splitted_midi_file => $app->tmpdir . "/recorder_splitted.mid",
	    abc_file => $app->tmpdir . "/recorder.abc",
		child_in => "",
		pid => ""
		};
	bless $recorder_object,$class;
	
	return $recorder_object;
}

sub show_record_dialog {
	my ($self) = @_;
	my $new_win = pEFL::Elm::Win->add($self->app->elm_mainwindow(), "New abc file", ELM_WIN_BASIC);
	$new_win->title_set("Record Midi");
	$new_win->focus_highlight_enabled_set(1);
	$new_win->autodel_set(1);
	
	my $bg = pEFL::Elm::Bg->add($new_win);
	_expand_widget($bg);
	$bg->show(); $new_win->resize_object_add($bg);
	
	my $box = pEFL::Elm::Box->add($new_win);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($new_win);
	$frame->text_set("Record MIDI");
	$frame->part_content_set("default",$box);
	_expand_widget($frame);
	$frame->show(); $new_win->resize_object_add($frame);
	
	my $table = pEFL::Elm::Table->add($frame);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	##########################
	# Select Device 
	##########################
	_add_header($table, 0, "Select Device", 1);
	my @devices = ();
	my $config = $self->app->settings->load_config();
	my $aseqdump = $config->{aseqdump_path} || "aseqdump";
	foreach my $d (`$aseqdump -l`) {
		chomp($d);
		$d =~ s/^\s*//;
		$d =~ s/\s{2,}/###/g;
		next if $d =~ /^Port/;
		my $device = "$d";
		push @devices, $device;
	}
	
	my $devices_combo = _add_combo($table,
		"row" => 2, "width" => 2,
		"text" => $self->midi_device() || "", "genlist" => \@devices, "frame" => $frame,
		);
	
	##########################
	# Select measure
	##########################
	_add_header($table,3,"Measure (M:)",1);
	my $measure_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($measure_combo);
	$measure_combo->text_set($self->midi_measure() || "4/4");
	
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default");
	$itc->text_get(sub {return $_[0];});
	my @measures = ("C","C|","2/4", "3/4","4/4", "5/4","6/4","7/4", "2/2", "3/2", "4/2", "3/8","5/8", "6/8", "7/8","8/8","9/8", "12/8", "3/16", "6/16", "12/16");
	foreach my $m (@measures) {
		$measure_combo->item_append($itc,$m,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$measure_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$measure_combo->show(); $table->pack($measure_combo,0,4,2,1);
	
	############################
	# Select tempo
	############################
	my $tempo_slider = _add_slider($table, "row" => 5, "width" => 2, 
		"max" => 200, "value" => $self->midi_tempo() || 100, 
		"label" => "Tempo");
		
	############################
	# Number of bars
	###########################
	my $bars_spinner = _add_spinner($table,
		"row" => 6, "width" => 2,
		"max" => 99, "value" => $self->midi_bars() || 10,
		"label" => "Number of bars to record"
	);
	
	my $ok_btn = pEFL::Elm::Button->new($table);
	$ok_btn->text_set("Record Midi");
	_expand_widget_x($ok_btn);
	$ok_btn->show(); $table->pack($ok_btn,0,7,2,2);
	$ok_btn->smart_callback_add("clicked", \&record_midi_cb, [$self,$devices_combo,$measure_combo,$tempo_slider,$bars_spinner]);
	
	$new_win->resize(420,200);
	$new_win->show();
}

sub record_midi_cb {
	my ($data, $obj, $e) = @_;
	
	my $self;
	# set only if record_midi is called show_record_dialog, not from 
	# show_recording_finished_dialog
	if (ref($data) eq "ARRAY") {
		$self = $data->[0];
		my $device = $data->[1]->text_get(); 
		$self->midi_device($device);
		my $measure = $data->[2]->text_get(); 
		$self->midi_measure($measure);
		$self->midi_tempo($data->[3]->value_get()); 
		$self->midi_bars($data->[4]->value_get()); 
	}
	else {
		$self = $data;
	}
	
	$self->run_midish();
    
    $obj->top_widget_get()->del();
    
    my $popup = pEFL::Elm::Popup->add($self->app->elm_mainwindow);
	
	$popup->part_text_set("title", "Recording MIDI");
	$popup->text_set("Click finish to stop recording");
	
	$popup->scrollable_set(1);
	
	# popup buttons
	my $btn = pEFL::Elm::Button->add($popup);
	$btn->text_set("Close");
	$popup->part_content_set("button1",$btn);
	$btn->smart_callback_add("clicked",\&stop_recording,[$self,$popup]);
	
	# popup show should be called after adding all the contents and the buttons
	# of popup to set the focus into popup's contents correctly.
	$popup->show();
}

sub run_midish {
	my ($self) = @_;
	
	my $config = $self->app->settings->load_config();
    
    my $child_out; my $child_in;
    my $midish = $config->{midish_path} || "midish";
    my $pid = open2($child_out, $child_in, $midish);
    
    my ($device) = split("###", $self->midi_device() ); 
    my $measure = $self->midi_measure();
    $measure =~ s!\/! !; 
	$measure = "4 4" if ($measure eq "C");
	$measure = "2 2" if ($measure eq "X|");
    
    print $child_in "dnew 0 \"".$device."\" rw\n";
    print $child_in "g 0\n";
    print $child_in "tnew mytrack\n";
    print $child_in "mins ".$self->midi_bars()." {$measure}\n";
    print $child_in "t ".$self->midi_tempo()."\n";
    print $child_in "m on\n";
    print $child_in "r\n";
    
    $self->child_in($child_in);
    $self->pid($pid);
    
    return;
}

sub stop_recording {
	my ($data, $obj, $e) = @_;
	my $self = $data->[0];
	my $popup = $data->[1];
	my $child_in = $self->child_in();
	
	print $child_in "s\n";
	print $child_in "export \"". $self->midi_file(). "\"\n";
	print $child_in "exit\n";
	
	waitpid( $self->pid(), 0 );
	my $child_exit_status = $? >> 8;
	
	close $self->child_in();
	$self->child_in("");
	
	$popup->del();
	
	$self->show_recording_finished_dialog();
}

sub show_recording_finished_dialog {
	my ($self) = @_;
	
	my $new_win = pEFL::Elm::Win->add($self->app->elm_mainwindow(), "Recording finished", ELM_WIN_BASIC);
	$new_win->title_set("Recording finished");
	$new_win->focus_highlight_enabled_set(1);
	$new_win->autodel_set(1);
	
	my $bg = pEFL::Elm::Bg->add($new_win);
	_expand_widget($bg);
	$bg->show(); $new_win->resize_object_add($bg);
	
	my $box = pEFL::Elm::Box->add($new_win);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($new_win);
	$frame->text_set("Recording finished");
	$frame->part_content_set("default",$box);
	_expand_widget($frame);
	$frame->show(); $new_win->resize_object_add($frame);
	
	my $table = pEFL::Elm::Table->add($frame);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	my $text = "Recorded midi events to " . $self->midi_file .
		"<br>To import please click on Import Midi";
	my $label = _add_label($table, 0, $text, 2);
	
	my ($ok_btn, $cancel_btn) = _add_buttons($table, "row" => 1,
		"ok" => "Import now", "cancel" => "Record again");
		
	my $close_btn = pEFL::Elm::Button->new($table);
	$close_btn->text_set("Close");
	_expand_widget_x($close_btn);
	$close_btn->show(); $table->pack($close_btn,0,2,2,1);
	
	$ok_btn->smart_callback_add("clicked", \&import_now, $self);
	$cancel_btn->smart_callback_add("clicked", \&record_again, $self);
	$close_btn->smart_callback_add("clicked", sub {$_[1]->top_widget_get->del();}, undef);
	
	$new_win->resize(300,200);
	$new_win->show();
}

sub import_now {
	my ($self,$obj,$e) = @_;
	$obj->top_widget_get->del; $self->show_import_midi_dialog();
}

sub record_again {
	my ($self,$obj,$e) = @_;
	$obj->top_widget_get->del; $self->record_midi_cb($obj);
}

sub show_import_midi_dialog {
	my ($self) = @_;
	my $new_win = pEFL::Elm::Win->add($self->app->elm_mainwindow(), "Import Midi", ELM_WIN_BASIC);
	$new_win->title_set("Import Midi");
	$new_win->focus_highlight_enabled_set(1);
	$new_win->autodel_set(1);
	
	my $bg = pEFL::Elm::Bg->add($new_win);
	_expand_widget($bg);
	$bg->show(); $new_win->resize_object_add($bg);
	
	my $box = pEFL::Elm::Box->add($new_win);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($new_win);
	$frame->text_set("Import Midi");
	$frame->part_content_set("default",$box);
	_expand_widget($frame);
	$frame->show(); $new_win->resize_object_add($frame);
	
	my $table = pEFL::Elm::Table->add($frame);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	
	#################################
	# File select button
	#################################
	_add_header($table, 0, "Input MIDI file", 2);
	my $btn_bx = pEFL::Elm::Box->add($table);
	_expand_widget_x($btn_bx);
	$btn_bx->horizontal_set(1);
	$btn_bx->show(); $table->pack($btn_bx,0,1,4,1);
	
	my $fselect_btn = pEFL::Elm::Button->new($btn_bx);
	$fselect_btn->text_set("Import MIDI Recording");
	_expand_widget_x($fselect_btn);
	$fselect_btn->show(); $btn_bx->pack_end($fselect_btn);
	
	my $select_rec_btn = pEFL::Elm::Button->new($btn_bx);
	my $icon = pEFL::Elm::Icon->add($btn_bx);
	$icon->standard_set("media-record");
	$select_rec_btn->part_content_set("icon",$icon);
	$select_rec_btn->show(); $btn_bx->pack_end($select_rec_btn);

	$select_rec_btn->smart_callback_add("clicked", sub {$_[0]->text_set("Import MIDI Recording")}, $fselect_btn);
	$fselect_btn->smart_callback_add("clicked", \&select_midi_file, undef);
	
	##########################
	# aul
	##########################
	_add_header($table, 2, "Denominator auf abc unit length", 2);
	my @auls = ("auto", "2","4","8","16","32", "64");
	my $aul_combo = _add_combo($table,
		"row" => 3, "width" => 4,
		"text" => "auto", "genlist" => \@auls, "frame" => $frame,
		);
	
	#########################
	# ppu
	#########################
	_add_header($table, 4, "Parts per unit length", 2);
	my $ppu_combo = _add_combo($table,
		"row" => 5, "width" => 4,
		"text" => "auto", "genlist" => \@auls, "frame" => $frame,
		);
	
	########################
	# key signatur
	########################	
	_add_header($table, 6, "Key signatur", 2);
	my @keys = ("auto","0 (C/Am)", "1 (G/Em)", "2 (D/Bm)", "3 (A/F#m)", "4 (E/C#m)", "5 (B/G#m)", "6 (F#/D#m)", "-1 (F/Dm)", "-2 (B/Gm)", "-3 (Eb/Cm)", "-4 (Ab/Fm)", "-5 (Db/Bm)", "-6 (Gb/Ebm)");
	my $k_combo = _add_combo($table,
		"row" => 7, "width" => 4,
		"text" => "auto", "genlist" => \@keys, "frame" => $frame,
		);
	
	
	#################NOTE!!!!!!!!!!!##########
	# Manually setting time signatur does only make sense if one also sets the tempo manually
	# this seems very very complicated (I got good results only with the option -b
	# To make it short: At the moment I think it is best to retrieve time signatur and tempo 
	# from MIDI file. Perhaps in the future I will add some advanced (but not recommended) options here
	##########
	########################
	# time signatur
	########################	
	#_add_header($table, 6, "Time signatur", 2);
	#my @measures = ("auto)", "C","C|","2/3", "3/4","4/4", "5/4","6/4","7/4", "2/2", "3/2", "4/2", "3/8","5/8", "6/8", "7/8","8/8","9/8", "12/8", "3/16", "6/16", "12/16");
	#my $m_combo = _add_combo($table,
	#	"row" => 7, "width" => 3,
	#	"text" => "auto", "genlist" => \@measures, "frame" => $frame,
	#	);
	
	##########################
	# bpl
	#########################
	my ($bpl_check,$bpl_spinner) = _add_spin_with_check($table,
			value => "", label => "Bars per line/staff", row => 8,
			min => 0, max => 12, step => 1, fmt => "%1.0f");
	
	##########################
	# split voice
	#########################
	my ($splitv_check,$splitv_spinner) = _add_spin_with_check($table,
			value => "", label => "Split MIDI file at pitch (C=60!)", row => 9,
			min => 0, max => 126, step => 1, fmt => "%1.0f");
	
	###########################
	# s / sr
	###########################
	my $s_check = _add_checkoption($table,
		value => 0, label => "Do not discard very short notes", row => 10);
	
	my $sr_check = _add_checkoption($table,
		value => 0, label => "Do not notate short rest", row => 11);
		
	#########################
	# -nb / -nt
	########################
	my $nb_check = _add_checkoption($table,
		value => 0, label => "Do not look for broken rhytms", row => 12);
	
	my $nt_check = _add_checkoption($table,
		value => 0, label => "Do not look for triplets", column => 2, row => 12);
	
	my $nogr_check = _add_checkoption($table,
		value => 0, label => "No note grouping", column => 2, row => 10);
		
	my $noly_check = _add_checkoption($table,
		value => 0, label => "Supress lyric output", column => 2, row => 11);
	
	
	
	
	my %options = (
		fselect_btn => $fselect_btn,
		aul_combo => $aul_combo,
		ppu_combo => $ppu_combo,
		key_combo => $k_combo,
		# measure_combo => $m_combo,
		bpl_spinner => $bpl_spinner,
		s_check => $s_check,
		sr_check => $sr_check,
		nb_check => $nb_check,
		nt_check => $nt_check,
		nogr_check => $nogr_check,
		noly_check => $noly_check,
		splitv_spinner => $splitv_spinner
	);
	
	my ($ok_btn, $cancel_btn) = _add_buttons($table, "row" => 16, "width" => 4,
		"ok" => "Open in new tune", "cancel" => "Replace current tune");
		
	my $close_btn = pEFL::Elm::Button->new($table);
	$close_btn->text_set("Close");
	_expand_widget_x($close_btn);
	$close_btn->show(); $table->pack($close_btn,0,17,4,1);
	
	$ok_btn->smart_callback_add("clicked", \&import_and_open, [$self, \%options]);
	$cancel_btn->smart_callback_add("clicked", \&import_and_replace, [$self, \%options]);
	$close_btn->smart_callback_add("clicked", sub {$_[1]->top_widget_get->del();}, undef);
	
	$new_win->resize(420,200);
	$new_win->show();
}

sub select_midi_file {
	my ($data, $obj, $e) = @_;
	
	my $toplevel = $obj->top_widget_get();
	bless($toplevel,"ElmWinPtr");
	
	my $new_win = pEFL::Elm::Win->add($toplevel, "Select Midi file", ELM_WIN_BASIC);
	$new_win->title_set("Select Midi file");
	$new_win->focus_highlight_enabled_set(1);
	$new_win->autodel_set(1);
	
	my $bg = pEFL::Elm::Bg->add($new_win);
	_expand_widget($bg);
	$bg->show(); $new_win->resize_object_add($bg);
	
	my $vbox = pEFL::Elm::Box->add($new_win);
	_expand_widget($vbox);
	$vbox->show();
	$new_win->resize_object_add($vbox);


	my $fs = pEFL::Elm::Fileselector->add($new_win);
	#$fs->is_save_set(1);
	$fs->expandable_set(0);
	$fs->path_set(File::HomeDir->my_home);
	$fs->mime_types_filter_append("audio/midi","Midi files");
	$fs->mime_types_filter_append("*","All files");
	_expand_widget($fs);
	$fs->show(); $vbox->pack_end($fs);


	$fs->smart_callback_add("done", \&_fs_done, $obj);


	# win 400x400
	$new_win->resize(350,350);
	$new_win->show();

}

sub _fs_done {
	my ($data, $obj, $ev_info) = @_;
	my $selected = pEFL::ev_info2s($ev_info);
	$data->text_set($selected) if ($selected);
	$obj->top_widget_get()->del();

}

sub import_and_open {
	my ($data,$obj,$e) = @_;
	
	my $self = $data->[0];
	my $opts = $data->[1];
	
	my $config = $self->app->settings->load_config();
	
	my ($child_exit_status, $error_message) = $self->run_midi2abc($opts);
	
	my $message;
	if ( $child_exit_status != 0 ) {
		$message = "<b>Errors occured while running midi2abc:</b><br/>$error_message";
		_show_info($obj->top_widget_get, "Error", $message);
	}
	else {
		# Open file
		my $content = $self->get_abc_text();
		
		my $tune = $self->app->current_tune();
		if ( (scalar(@{$self->app->tunes->tunes}) != 1) || ($tune->filename) || ($tune->id != 0) || ($tune->changed() != 0)) {
		
			# Add Tune
			my @tunes = @{$self->app->tunes->tunes};
			my $tune_id = $#tunes+1;
			$tune = Caecilia::Tune->new(id => $tune_id, content => $content);
			$self->app->tunes->push_tune($tune);
		}
		
		# Insert content
		$self->app->entry->elm_entry->entry_set($content);
		$self->app->entry->rehighlight_all();
		
		# Change the changed status of current tune here
		# otherwise it doesn't recognize that the tab was changed
		$self->app->current_tune->changed(1);
		
		$message = "<b>Import succesful</b>";
		_show_info($obj->top_widget_get, "DONE", $message);
	}
}

sub import_and_replace {
	my ($data,$obj,$e) = @_;
	
	my $self = $data->[0];
	my $opts = $data->[1];
	
	my ($child_exit_status, $error_message) = $self->run_midi2abc($opts);
	
	my $message;
	if ( $child_exit_status != 0 ) {
		$message = "<b>Errors occured while running midi2abc:</b><br/>$error_message";
		_show_info($obj->top_widget_get, "Error", $message);
	}
	else {
		# Open file
		my $content = $self->get_abc_text();
		
		# Insert content
		my $en = $self->app->entry()->elm_entry;
		$en->select_all; my ($pos,$end) = $en->select_region_get(); my $selected_text=$en->selection_get();
		$self->app->entry->elm_entry->entry_insert($content);
		$self->app->entry->rehighlight_all();
		
		# we have to add the insert undo record because only the del event is recorded automatically???
		my $undo_record_insert = {};
		$undo_record_insert->{pos} = $pos;
		$undo_record_insert->{content} = $content;
		$undo_record_insert->{plain_length} = length($content);
		push @{$self->app->current_tune->undo_stack},$undo_record_insert;
		
		$message = "<b>Import succesful</b>";
		_show_info($obj->top_widget_get, "DONE", $message);
	}
}

# Mostly stolen from Cacilia::open_file
sub get_abc_text {
	my ($self) = @_;
	
	my $config = $self->app->settings->load_config();
	
	open my $fh, "<:encoding(utf-8)", $self->abc_file();
	my $content=""; my $line;
	while (my $line=<$fh>) {
		$content = $content . $line;
	}
	
	close $fh;
	
	if ($config->{expand_tabs}) {
		$content = expand($content);	
	}
	elsif ($config->{unexpand_tabs}) {
		$content = unexpand($content);
	}
	
	$content = pEFL::Elm::Entry::utf8_to_markup($content);
		
	return $content;
}

sub run_midi2abc {
	my ($self,$opts) = @_;
	
	# TODO: Support for importing extern midi files
	
	my $config = $self->app->settings->load_config();
	
	if (! $opts->{splitv_spinner}->disabled_get() ) {
		$self->split_midi($opts->{splitv_spinner}->value_get());
	}
	
	my $aul = $opts->{aul_combo}->text_get();
	my $ppu = $opts->{ppu_combo}->text_get();
	my $key = $opts->{key_combo}->text_get();
	if ($key ne "auto") {
		$key =~ s/\(.*\)//;
	}
	#my $measure = $opts->{measure_combo}->text_get();
	my $bpl = $opts->{bpl_spinner}->disabled_get ? "" : $opts->{bpl_spinner}->value_get();
	my $s = $opts->{s_check}->state_get();
	my $sr = $opts->{sr_check}->state_get();
	my $nb = $opts->{nb_check}->state_get();
	my $nt = $opts->{nt_check}->state_get();
	my $nogr = $opts->{nogr_check}->state_get();
	my $noly = $opts->{noly_check}->state_get();
	
	my @cmd;
	my $midi_file;
	
	my $fselect = $opts->{fselect_btn}->text_get();
	if ($fselect eq "Import MIDI Recording") {
		
		$midi_file = $opts->{splitv_spinner}->disabled_get() ? $self->midi_file() : $self->splitted_midi_file();
	}
	else {
		$midi_file = $fselect;
	}
	
	push @cmd, "-f", $midi_file;
	push @cmd, "-aul",$aul if ($aul ne "auto");
	push @cmd, "-ppu",$ppu if ($ppu ne "auto");
	push @cmd, "-k", $key if ($key ne "auto");
	#push @cmd, "-m", $measure if ($measure ne "auto");
	push @cmd, "-bpl", $bpl if ($bpl);
	push @cmd, "-bps", $bpl if ($bpl);
	push @cmd, "-s" if ($s);
	push @cmd, "-sr" if ($sr);
	push @cmd, "-nb" if ($nb);
	push @cmd, "-nt" if ($nt);
	push @cmd, "-nogr" if ($nogr);
	push @cmd, "-noly" if ($noly);
	
	push @cmd, "-o", $self->abc_file();
	
	# TODO: Make option in settings for the path!!!
	my $midi2abc = $config->{midi2abc_path} || "midi2abc";
	my $pid = open3(\*IN, \*OUT, \*ERR, $midi2abc,@cmd);
	my $error_message = ""; my $out = "";
	
	while(my $line = <ERR>) {
			#$line =~ s/^\/.*render.abc\://;
			$error_message = $error_message. $line . "<br/>";
	}
	
	close IN; close OUT; close ERR;
	waitpid($pid,0);
	my $child_exit_status = $? >> 8;
	print "midi2abc exits with error status: $child_exit_status\n";
	
	return ($child_exit_status, $error_message);
}

sub split_midi {
	my ($self, $cut_off) = @_;
	
	my $opus = MIDI::Opus->new({ 'from_file' => $self->midi_file()});

	my $i = 1;
	my @new_score;
	my @new_score_LH;

	foreach my $track ($opus->tracks()) {
		my $events_r = $track->events_r();
		my ($score_r, $ticks) = MIDI::Score::events_r_to_score_r( $events_r );
	
		foreach my $event (@$score_r) {
			if ($event->[0] eq "note") { 
			
				if ($event->[4] < $cut_off) {
					push @new_score_LH, $event;
				}
				else {
					push @new_score, $event;
				}		
			}
	
		}
		$i++;
	}

	my @tracks = $opus->tracks();
	$tracks[1]->events_r( MIDI::Score::score_r_to_events_r( \@new_score ));
	my $track_LH = MIDI::Track->new();
	$track_LH->events_r(MIDI::Score::score_r_to_events_r( \@new_score_LH ));

	push @tracks, $track_LH;

	$opus->tracks(@tracks);

	$opus->write_to_file($self->splitted_midi_file());
}


################
# Getter / Setter
#################
sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|midi_file|splitted_midi_file|abc_file|/;
	
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

1;
__END__


=head1 NAME

Caecilia::Renderer

=head1 DESCRIPTION

This is the Renderer component of the Caecilia Appliation.

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
