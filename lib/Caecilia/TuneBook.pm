package Caecilia::TuneBook;

use 5.006001;
use strict;
use warnings;
use utf8;

use pEFL::Elm;
use Caecilia::MyElm qw(_add_header _expand_widget _expand_widget_x);
use Encode;

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

sub new {
	my ($class, %opts) = @_;

	# content now must ALWAYS be an arrayref of PLAIN TEXT strings:
	#   index 0   = file header (everything before the first "X:" line, may be empty)
	#   index 1..n = the tunes (each one starts with its "X:" line)
	my $content = defined($opts{content}) ? [ _split_content($opts{content}) ] : [""];
	
	my $obj = {
		filename => $opts{filename}, 
		changed => 0,
		undo_stack => [],
		redo_stack => [],
		content => $content,
		cursor_pos => 1,
		id => $opts{id},
		source_highlight => "yes",
		elm_toolbar_item => undef,
		# current_tune: -1 = raw mode (the whole file is in the editor)
		#                0 = header, 1 = first tune, 2 = second tune ... (split mode)
		# The edit mode is not stored, it is derived from current_tune (see edit_mode)
		current_tune => -1
		};
	bless($obj,$class);
	return $obj;
}

############################
# Helper functions
############################

# A new tune begins at an "X:" line. But a tune ends at an empty line
# (ABC standard), so the lines between the last empty line and the next "X:" (for
# example "%%MIDI program 40" or a comment) belong to the next tune and not to the
# previous one. (Text behind earlier empty lines, e.g. a free text paragraph,
# stays with the previous tune.)
# This cuts these lines off the end of the text $$ref (scalar ref) and returns them.
# If there is no empty line in the text (or nothing behind the last one) nothing
# is cut off and "" is returned.
sub _cut_lines_after_last_blank {
	my ($ref) = @_;

	my @lines = split /(?<=\n)/, $$ref;

	# index of the last empty line (only whitespaces)
	my $idx = -1;
	for (my $i = $#lines; $i >= 0; $i--) {
		# Suche nach der letzten leeren Zeile 
		# ([ \t]* = Zeile leer oder nur aus Leerzeichen oder Tabulatoren bestehend  
		if ($lines[$i] =~ /^[ \t]*\n\z/) { $idx = $i; last; }
	}

	# no empty line ($idx < 0) or nothing behind ($idx == $#lines) it
	return "" if ($idx < 0 || $idx == $#lines);

	my $cut = join("", @lines[$idx+1 .. $#lines]);
	$$ref = join("", @lines[0 .. $idx]);
	return $cut;
}

# Splits the plain text of a whole file into (header, tune1, tune2, ...)
# join("", _split_content($text)) always gives back $text
sub _split_content {
	my ($text) = @_;
	
	my $header = "";
	my @tunes = ();

	# Cut behind every "\n", the "\n" stays at its line
	# ?<= = Lookbehind. Er prüft nur, was vor einer Position steht, 
	# und verbraucht dabei keine Zeichen. (Ohne Lookbehind würde das "\n" abgeschnitten,
	# weil split den Trenner wegwirft)
	foreach my $line (split /(?<=\n)/, $text) {

		# A new tune begins
		if ($line =~ /^X:/) {
			# Lines behind the last empty line of the previous tune belong to the new tune
			# (befor the first (X: 1) tune nothing is cut: they stay in the header)
			my $pre = "";
			if (scalar(@tunes) > 0) {
				$pre = _cut_lines_after_last_blank(\$tunes[-1]);
			}
			push @tunes, $pre . $line;
		}
		# There is already a tune => the line belongs to the last tune
		elsif (scalar(@tunes) > 0) {
			$tunes[-1] .= $line;
		}
		# No tune seen yet => the line belongs to the header
		else {
			$header .= $line;
		}
	}
	
	return ($header, @tunes);
}

# Makes sure, that a (non empty) part ends with an empty line.
# Without an empty line between header and tune or between two tunes
# some programs don't recognize the border.
sub _add_trailing_newline {
	my ($text) = @_;

	return $text if ($text eq "");

	my ($trail) = $text =~ /(\n*)\z/;
	my $have = length($trail);

	$text .= "\n" x (2 - $have) if ($have < 2);
	return $text;
}

# Cursor position and undo/redo stacks refer to the text in the editor.
# If the text changes (other tune, other mode), they are no longer valid
sub _reset_tunebook {
	my ($self) = @_;
	$self->{undo_stack} = [];
	$self->{redo_stack} = [];
	$self->{cursor_pos} = 0;
}

############################
# Creation of TuneBooks and Tunes
############################

sub new_tune {
	my ($app, %opts) = @_;
	my $into_tunebook = $opts{into_tunebook} ? 1 : 0;
	my $title = $into_tunebook ? "Add a new tune" : "Create a new abc file";
	my $mw = $app->elm_mainwindow();
	
	my $new_win = pEFL::Elm::Win->add($mw, "New abc file", ELM_WIN_BASIC);
	$new_win->title_set("$title");
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
	$frame->text_set($title);
	$frame->part_content_set("default",$box);
	_expand_widget($frame);
	$frame->show(); $new_win->resize_object_add($frame);
	
	my $table = pEFL::Elm::Table->add($frame);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	_add_header($table,0,"Title", 1);
	
	my $title_en = pEFL::Elm::Entry->add($table);
	$title_en->entry_set("");
	$title_en->scrollable_set(1);
	$title_en->single_line_set(1);
	$title_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($title_en);
	$title_en->show(); $table->pack($title_en,0,1,2,1);
	
	_add_header($table,2,"Subitle", 1);
	
	my $subtitle_en = pEFL::Elm::Entry->add($table);
	$subtitle_en->entry_set("");
	$subtitle_en->scrollable_set(1);
	$subtitle_en->single_line_set(1);
	$subtitle_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($subtitle_en);
	$subtitle_en->show(); $table->pack($subtitle_en,0,3,2,1);
	
	_add_header($table,4,"Composer", 1);
	
	my $composer_en = pEFL::Elm::Entry->add($table);
	$composer_en->entry_set("");
	$composer_en->scrollable_set(1);
	$composer_en->single_line_set(1);
	$composer_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($composer_en);
	$composer_en->show(); $table->pack($composer_en,0,5,2,1);
	
	_add_header($table,6,"Measure",1);
	
	my $measure_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($measure_combo);
	$measure_combo->text_set("4/4");
	
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default");
	$itc->text_get(sub {return $_[0];});
	my @measures = ("C","C|","2/4", "3/4","4/4", "5/4","6/4","7/4", "2/2", "3/2", "4/2", "3/8","5/8", "6/8", "7/8","8/8","9/8", "12/8", "3/16", "6/16", "12/16");
	foreach my $m (@measures) {
		$measure_combo->item_append($itc,$m,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$measure_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$measure_combo->show(); $table->pack($measure_combo,0,7,2,1);
	
	_add_header($table,8,"Standard note length",1);
	
	my $length_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($length_combo);
	$length_combo->text_set("1/4");
	
	my $itc2 = pEFL::Elm::GenlistItemClass->new();
	$itc2->item_style("default");
	$itc2->text_get(sub {return $_[0];});
	my @lengths = ("1/2","1/4","1/8","1/16","1/32");
	foreach my $l (@lengths) {
		$length_combo->item_append($itc2,$l,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$length_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$length_combo->show(); $table->pack($length_combo,0,9,2,1);
	
	_add_header($table,10,"Tempo (Q:)", 1);
	
	my $tempo_en = pEFL::Elm::Entry->add($table);
	$tempo_en->entry_set("");
	$tempo_en->scrollable_set(1);
	$tempo_en->single_line_set(1);
	$tempo_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($tempo_en);
	$tempo_en->show(); $table->pack($tempo_en,0,11,2,1);
	
	_add_header($table,12,"Key (K:)",1);
	
	my $key_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($key_combo);
	$key_combo->text_set("C (C Major)");
	
	my $itc3 = pEFL::Elm::GenlistItemClass->new();
	$itc3->item_style("default");
	$itc3->text_get(sub {return $_[0];});
	my @keys = ("None", "C (C Major)","G (G Major)","D (D Major)","A (A Major)","E (E Major), B (B Major)", "F# (F# Major", "C# (C# Major)",
	"F (F Major)", "Bb (Bb Major)", "Eb (Eb Major)", "Ab (Ab Major)", "Db (Db Major)", "Gb (Gb Major)", "Cb (Cb Major)",
	"Am (A Minor)", "Em (E Minor)", "Bm (B Minor)", "F#m (F# Minor)", "C#m (C# Minor)", "G#m (G# Minor)", "D#m (D# Minor)", "A#m (A# Minor)",
	"Dm (D Minor)", "Gm (G Minor)", "Cm (C Minor)", "Fm (F Minor)", "Bbm (Bb Minor)", "Ebm (Eb Minor)", "Abm (Ab Minor)"	);
	foreach my $k (@keys) {
		$key_combo->item_append($itc3,$k,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$key_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$key_combo->show(); $table->pack($key_combo,0,13,2,1);
	
	my @args = ($new_win, $title_en, $subtitle_en, $composer_en, $measure_combo, $length_combo, $tempo_en, $key_combo);
	
	_add_buttons($app, $table, 14,\@args, $into_tunebook);
	
	$new_win->resize(420,600);
	$new_win->show();
	
}

sub _add_buttons {
	my ($app, $table,$row, $args, $into_tunebook) = @_;
	
	my $width = 2;
	my $btn_bx = pEFL::Elm::Box->add($table);
	_expand_widget_x($btn_bx);
	$btn_bx->horizontal_set(1);
	$btn_bx->show(); $table->pack($btn_bx,0,$row,$width,1);
	if ($into_tunebook) {
		my $after_btn = pEFL::Elm::Button->new($btn_bx);
		$after_btn->text_set("Insert after current tune");
		_expand_widget($after_btn);
		$after_btn->show(); $btn_bx->pack_end($after_btn);

		my $last_btn = pEFL::Elm::Button->new($btn_bx);
		$last_btn->text_set("Insert as last tune");
		_expand_widget($last_btn);
		$last_btn->show(); $btn_bx->pack_end($last_btn);
	
		my $cancel_btn = pEFL::Elm::Button->new($btn_bx);
		$cancel_btn->text_set("Cancel");
		_expand_widget($cancel_btn);
		$cancel_btn->show(); $btn_bx->pack_end($cancel_btn);
	
		# Callbacks
		$cancel_btn->smart_callback_add("clicked", sub { $args->[0]->del(); }, undef );
		$after_btn->smart_callback_add("clicked", \&_new_tune_cb, [$app,$args, "after_current"]);
		$last_btn->smart_callback_add("clicked", \&_new_tune_cb, [$app,$args, "last"]);
	}
	else {
		my $ok_btn = pEFL::Elm::Button->new($btn_bx);
		$ok_btn->text_set("OK");
		_expand_widget($ok_btn);
		$ok_btn->show(); $btn_bx->pack_end($ok_btn);
	
		my $cancel_btn = pEFL::Elm::Button->new($btn_bx);
		$cancel_btn->text_set("Cancel");
		_expand_widget($cancel_btn);
		$cancel_btn->show(); $btn_bx->pack_end($cancel_btn);
	
		# Callbacks
		$cancel_btn->smart_callback_add("clicked", sub { $args->[0]->del(); }, undef );
		$ok_btn->smart_callback_add("clicked", \&_new_tunebook_cb, [$app,$args]);
	}
	
	return $btn_bx;
}

# Builds the lines of the tune
sub create_header_lines {
	my ($args) = @_;
	
	my $key = $args->[7]->text_get() || undef;
	if ($key) {
		$key =~ s/\(.*\)//;
	}
	
	my $content = "";
	$content .= "T: ". $args->[1]->text_get() . "\n" if ($args->[1]->text_get);
	$content .= "T: ". $args->[2]->text_get() . "\n" if ($args->[2]->text_get);
	$content .= "C: ". $args->[3]->text_get() . "\n" if ($args->[3]->text_get);
	$content .= "M: ". $args->[4]->text_get() . "\n" if ($args->[4]->text_get);
	$content .= "L: ". $args->[5]->text_get() . "\n" if ($args->[5]->text_get);
	$content .= "Q: ". $args->[6]->text_get() . "\n" if ($args->[6]->text_get);
	$content .= "K: ". $key . "\n" if ($key);	
	
	return Encode::decode("UTF-8", pEFL::Elm::Entry::markup_to_utf8($content));
}

sub _new_tunebook_cb {
	my ($data, $btn) = @_;
	my $app = $data->[0]; my $args = $data->[1];
	my @tabs = @{$app->tabs->tabs};
	
	my $content = "X: 1\n" . create_header_lines($args);
	$args->[0]->del();
	my $entry = $app->entry;
	
	my $current_tunebook = $app->current_tunebook();
	my $tunebook_id; my $tunebook;
	
	# Create TuneBook in empty tab, if the untitled tab at the beginning is unchanged
	# see also / the same as in Caecilia::open_file ;-)
	if ( (scalar(@{$app->tabs->tabs}) == 1) && (!$current_tunebook->filename) && ($current_tunebook->id == 0) && ($current_tunebook->changed() == 0)) { 
		$tunebook = $current_tunebook;
	}
	# otherwise create in new tab
	else {
		$tunebook_id = $#tabs+1;	
		$tunebook = Caecilia::TuneBook->new(id => $tunebook_id);

		# push_tab selects the new tab and thereby calls change_tab, which saves the
		# old tab, makes the new tunebook the current one and clears the editor
		$app->tabs->push_tab($tunebook);
	}

	# The file has exactly one tune, so split mode starts with it
	$tunebook->content_all_str($content);
	$tunebook->edit_mode("split");
	$entry->set_text($tunebook->content_current_str);
	
	# Update toolbar (fill Combobox, change text of mode button, disable buttons etc.);
	$entry->update_toolbar();

	# A new file with content is unsaved (Entry::set_text restores the changed state)
	# # set_text restores the old changed state, so mark the new file as changed afterwards	
	$tunebook->changed(1);
	my $elm_it = $tunebook->elm_toolbar_item();
	my $title = $elm_it->text_get();
	$elm_it->text_set("$title*") if ($title !~ /\*$/);
}

sub _new_tune_cb {
	my ($data, $btn) = @_;
	my ($app, $args, $position) = @$data;

	my $lines = create_header_lines($args);
	$args->[0]->del();

	my $new = add_tune($app, $lines, $position);
	$app->entry->insert_tune($new);
}

# Insert a new tune into the TuneBook:
# $text: the header lines of the tune from the dialog (without X: )
# $position: "after_current" => behind the current tune; "last" => as last tune of TuneBook
# $text are the lines of the tune without the "X: " line. The X: line is created automatically
# Without $text a template is used
# Returns the index of the new tune.
sub add_tune {
	my ($app, $text, $position) = @_;
	
	my $tunebook = $app->current_tunebook();
	# save the editor text into Tunebook 
	# ! in raw mode splits the whole text again and so update the indices (see content_all str() that is called in content_current_str in raw mode)
	$tunebook->content_current_str($app->entry->get_text());
	
	my $split = ($tunebook->current_tune() >= 0) ? 1 : 0;
	
	# Index of the part behind (undef = at the end)
	my $after;
	if ($position eq "after_current") {
		# split mode: the current tune
		# raw mode: jump to the next X: and insert it there
		# if current tune is file header (0) => add tune at the first tune
		$after = $split ? $tunebook->current_tune()
						: $tunebook->index_at_offset($app->entry->elm_entry->cursor_pos_get());
	}

	my $content = $tunebook->content();
	$text = "T: Untitled\nK: C\n" unless (defined($text));
	$after = $#{$content} if (!defined($after) || $after < 0 || $after > $#{$content});

	# TODO always resort_reference_numbers???
	# X: number = highest X: number + 1
	my $max = 0;
	foreach my $i (1..$#{$content}) {
		foreach my $line (split /\n/, $content->[$i]) {
			if ($line =~ /^X:\s*(\d+)/) {
				$max = $1 if ($1 > $max);
				last;
			}
		}
	}
	
	my $tune = "X: " . ($max+1) . "\n" . $text;
	$tune .= "\n" unless ($tune =~ /\n$/);

	# Empty line behind the new tune, if another part follows
	$tune = _add_trailing_newline($tune) if ($after < $#{$content});

	# Empty line between the previous part and the new tune
	# $after: index of the existing tune after the new tune is inserted!!!	
	$content->[$after] = _add_trailing_newline($content->[$after]);

	splice(@$content, $after+1, 0, $tune);

	return $after+1;
}

############################
# Content handling
############################

# Getter and setter for the text of the current tune:
# raw mode: the whole file, split mode: the current tune (or the header)
#
# Setter ($text defined): stores the text of the editor in the content.
# Unlike the other accessors it returns nothing (the old value would
# be a join of the whole file in raw mode)
# Getter: returns the text for the editor
sub content_current_str {
	my ($self, $text) = @_;
	
	if (defined($text)) {
		my $content = $self->content();

		if ($self->edit_mode() eq "split") {
			my $i = $self->current_tune();
			if ($i < 0 || $i > $#{$content}) {
				warn "content_current_str: current_tune $i is out of range\n";
				return;
			}

			# Just store the text, Don't split here: The indices of the other
			# tunes must not change while the user works in split mode. If the user
			# typed or deleted "X:" lines, this is only recognized by reload() or
			# when switching to raw mode. Saving is not affected, because
			# content_all_str joins all parts without loss.
			$content->[$i] = $text;
		}
		else {
			# raw mode: the user may have added or deleted tunes
			$self->content_all_str($text);
		}

		return;
	}
	else {
		my $content = $self->content();
	
		if ($self->edit_mode() eq "split") {
			my $part = $content->[ $self->current_tune() ];
			return defined($part) ? $part : "";
		}
	
		# raw mode: the whole file
		return $self->content_all_str();
	}
}

# Getter and setter for the whole text of the tunebook:
# Whole file (header + all tunes), independent of the mode (e.g. for save).
#
# Getter: returns the whole file. Please be aware: Call content_current_str($editor_text)
# before, because the editor may be newer than the saved content in the Arrayref.
# Setter ($text defined): splits the whole file in header + tunes and stores them in
# the Arrayref. Unlike the other accessors it returns nothing (the old value would
# be a join of the whole file). The edit mode is NOT changed, the caller must call
# edit_mode afterwards, because current_tune may not exist in the new content.
sub content_all_str {
	my ($self, $text) = @_;

	# Setter: split the whole file in header + tunes. Nothing is returned and the
	# edit mode is NOT changed (the caller must call edit_mode afterwards)
	if (defined($text)) {
		$self->content([ _split_content($text) ]);
		return;
	}

	# Getter
	return join("", @{$self->content()});
}

# Text for the renderer / MIDI: 
# $editor_text is the current text in the editor (you get it with Entry::get_text)
# In split mode it returns header + current tune
# # There is no preview function of the file header (current_tune == 0) => returns undef!
# In raw mode: the editor text (which is the whole file!)
sub create_preview_abc {
	my ($self, $editor_text) = @_;

	my $i = $self->current_tune();
	return $editor_text if ($i < 0);
	return undef if ($i == 0);
	return _add_trailing_newline($self->content()->[0]) . $editor_text;
}

# Number of characters that create_preview_abc puts in front of the editor text
# in raw mode / header edit: 0
# split mode: length of the file header (+ empty line)
sub preview_abc_offset {
	my ($self) = @_;

	return 0 if ($self->current_tune() < 1);

	return length(_add_trailing_newline($self->content()->[0]) );
}

############################
# Modes and tunes
############################

# Getter and setter for the index of the tune that is shown in the editor:
# -1 = raw mode (whole file), 0 = header, 1 = first tune, 2 = second tune ...
#
# This is the only place that changes the current tune. Setting a new value
# (also the same value) resets cursor position and undo/redo stacks, because
# they refer to the text in the editor. Setting a value >= 0 switches to split mode,
# setting -1 to raw mode.
# Call content_current_str($editor_text) before (to save the editor)
# and content_current_str() afterwards (to refill the editor)!
# Like the other accessors it returns the old value
sub current_tune {
	my ($self, $index) = @_;

	my $oldval = $self->{current_tune};

	if (defined($index)) {
		if ($index < -1 || $index > $#{$self->content()}) {
			warn "current_tune: index $index is out of range\n";
			return $oldval;
		}
		$self->{current_tune} = $index;
		$self->_reset_tunebook();
	}

	return $oldval;
}

# Getter and setter for the edit mode "raw" or "split". The mode is not stored,
# it is derived from current_tune (-1 = raw).
# Setter "split": starts with the first tune (if there is one), only if there is no tune at all
# (only the header exists) with the header. For a certain tune use current_tune($index)
# Call content_current_str($editor_text) before (to save the editor)
# and content_current_str() afterwards (to refill the editor)!
sub edit_mode {
	my ($self, $mode) = @_;

	my $oldval = $self->current_tune() < 0 ? "raw" : "split";

	if (defined($mode)) {
		if ($mode eq "split") {
			my $last = $#{$self->content()};
			$self->current_tune($last >= 1 ? 1 : 0);
		}
		else {
			$self->current_tune(-1);
		}
	}

	return $oldval;
}

# Splits all parts anew (e.g. after the user typed or deleted "X:" lines in split mode).
# Call content_current_str($editor_text) before (to save the editor), and 
# content_current_str() afterwards (to refill the editor) and rebuild the combobox (tune_labels)!
# Simple first version: current_tune is kept (if it still exists), but the
# tune in the editor can shift if the number of tunes in front of it has changed
sub reload {
	my ($self) = @_;

	# first get the current content of Arrayref as string (which perhaps is changed
	# with new X: .. lines, than split this new string and save it rightly splitted
	# in the Arrayref
	$self->content_all_str( $self->content_all_str() );

	# the new content can be shorter: then use the last part. Setting current_tune
	# also resets cursor position and undo/redo stacks
	my $last = $#{$self->content()};
	$self->current_tune( $self->current_tune() > $last ? $last : $self->current_tune() );
}

# Index of the part in which the current cursor is
# $pos of the whole text (=cursor position in raw mode!)
# A position exactly at the beginning of the tune belongs to this part!
# Call content_current_str($editor_text) before!
sub index_at_offset {
	my ($self, $pos) = @_;

	my $content = $self->content();
	my $end = 0;
	foreach my $i (0..$#{$content}) {
		$end += length($content->[$i]);
		return $i if ($pos < $end);
	}

	return $#{$content};
}

# Offset of the beginn of the tune with reference nr. $index
# in the whole text (necessary in raw mode to set the cursor 
# after inserting a new tune!)
sub offset_of_index {
	my ($self, $index) = @_;
	
	my $content = $self->content();
	my $offset = 0;
	
	foreach my $i (0..$index-1) {
		$offset += length($content->[$i]);
	}
	
	return $offset;
}

# Labels for the combobox: "(File header) (#0)", "X 1: Title of tune (#1=", ...
# The number in (#n) at the end is the index in the content array
sub tune_labels {
	my ($self) = @_;

	my $content = $self->content();
	my @labels = ("(File header) (#0)");

	foreach my $i (1..$#{$content}) {
		my $x = "";
		my $title = "";
		# A tune can start with lines in front of the "X:" line (see _split_content),
		# so look for the title only behind it
		my $seen_x = 0;
		foreach my $line (split /\n/, $content->[$i]) {
			if ($line =~ /^X:\s*(.*?)\s*$/) {
				next if ($seen_x);
				$seen_x = 1; $x = $1;
				next;
			}
			next unless ($seen_x);
			if ($line =~ /^T:\s*(.*?)\s*$/) {
				$title = $1;
				last;
			}
		}
		$x = "?" if ($x eq "");
		$title = "(untitled)" if ($title eq "");
		push @labels, "X: $x - $title (#$i)";
	}

	return @labels;
}

# Index in the content array out of a lbel of tune_labels
sub tune_index_from_label {
	my ($self, $label) = @_;

	return $1 if (defined($label) && $label =~ /\(#(\d+)\)\s*$/);
	return undef;
}

############################
# Accessors
############################

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/filename|changed|id|content|undo_stack|redo_stack|cursor_pos|auto_indent|source_highlight|sh_lang|elm_toolbar_item/;
	
	my $attrib = $AUTOLOAD;
	$attrib =~ s/.*://;
	
	my $oldval = $self->{$attrib};
	$self->{$attrib} = $newval if defined($newval);
	
	return $oldval;
}

sub DESTROY {}


# Preloaded methods go here.

1;
__END__


=head1 NAME

Caecilia::TuneBook

=head1 DESCRIPTION

This saves information of a single tunebook (e.g. a single abc file, which can contain several tunes).

The content is always an arrayref: index 0 is the file header, index 1..n are the tunes.
In raw edit mode (current_tune = -1) the editor shows the whole file, in split edit mode
only the part selected by current_tune.

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
