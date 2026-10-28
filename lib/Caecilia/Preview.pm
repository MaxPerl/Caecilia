package Caecilia::Preview;
use 5.006001;
use strict;
use warnings;
use utf8;

require Exporter;

use pEFL::Ecore;
use pEFL::Ecore::EventHandler;
use pEFL::Ecore::Event::Key;
use pEFL::Elm;
use pEFL::Evas;

use Syntax::SourceHighlight;
use HTML::Entities;
use Encode;
use Image::Info qw(image_info dim);

use Text::Tabs;

use Caecilia::MyElm ":all";

our @ISA = qw(Exporter);

our $AUTOLOAD;

sub new {
	my ($class, $app, $box) = @_;
	
	# Get index
	
	my $obj = {
		app => $app,
		elm_viewer => undef,
		number_of_pages => undef,
		page => undef,
		notes => {},
		notes_rect => [],
		visible => [],
		longpress_check => undef,
		"up_to_date" => 0,
		};
	
	bless($obj,$class);
	$obj->init_preview($app,$box);
	return $obj;
}

sub init_preview {
	my ($self,$app,$panes) = @_;
	
	############################
	# ADD PREVIEW TOOLBAR
	############################
	my $left_box = pEFL::Elm::Box->add($panes);
	_expand_widget($left_box);
	
	$self->add_preview_toolbar($app->elm_mainwindow,$left_box);
	
	my $scroller = pEFL::Elm::Scroller->add($left_box);
	_expand_widget($scroller); $scroller->show();
	$left_box->pack_end($scroller);
	
	my $viewer = pEFL::Elm::Image->add($scroller);
	my $path = $app->share_dir . "/caecilia-logo.png";
	$viewer->file_set($path,"");
	$self->elm_viewer($viewer);
	$scroller->content_set($viewer);
	$scroller->smart_callback_add("scroll",\&move_notes, $self);
	$scroller->smart_callback_add("size,changed",\&move_notes, $self);
	
	$self->elm_scroller($scroller);
	$panes->part_content_set("right",$left_box);
	
	$self->app->preview($self);
	
}

##################################
# Add Preview Toolbar
##################################
sub add_preview_toolbar {
	my ($self, $win, $box) = @_;
	
	my $bx = pEFL::Elm::Box->add($box);
	$bx->horizontal_set(1);
	$bx->size_hint_align_set(EVAS_HINT_FILL, 0);
	$bx->size_hint_weight_set(EVAS_HINT_EXPAND, 0);
	$bx->show();$box->pack_end($bx);
	
	my %tb;

	my $preview_btn = pEFL::Elm::Button->add($bx);
	my $icon = pEFL::Elm::Icon->add($bx);
	# set the image file and the button as an icon
	$icon->standard_set("view-restore");
	$preview_btn->part_content_set("icon",$icon);
	$preview_btn->text_set("Preview   ");
	$preview_btn->size_hint_weight_set(0, EVAS_HINT_EXPAND);
	$preview_btn->size_hint_align_set(0, EVAS_HINT_FILL);
	$preview_btn->smart_callback_add("clicked", \&preview_cb, $self);
	$bx->pack_end($preview_btn); $preview_btn->show();
	$tb{preview_btn} = $preview_btn;


	my $prev_btn = pEFL::Elm::Button->add($bx);
	my $icon2 = pEFL::Elm::Icon->add($bx);
	$icon2->standard_set("go-previous");
	$prev_btn->part_content_set("icon",$icon2);
	$prev_btn->size_hint_weight_set(0, EVAS_HINT_EXPAND);
	$prev_btn->size_hint_align_set(0, EVAS_HINT_FILL);
	$prev_btn->smart_callback_add("clicked", \&previous_page_cb, $self);
	$bx->pack_end($prev_btn); $prev_btn->show();
	$tb{prev_btn} = $prev_btn;
	
	my $next_btn = pEFL::Elm::Button->add($bx);
	my $icon3 = pEFL::Elm::Icon->add($bx);
	$icon3->standard_set("go-next");
	$next_btn->part_content_set("icon",$icon3);
	$next_btn->size_hint_weight_set(0, EVAS_HINT_EXPAND);
	$next_btn->size_hint_align_set(0, EVAS_HINT_FILL);
	$next_btn->smart_callback_add("clicked", \&next_page_cb, $self);
	$bx->pack_end($next_btn); $next_btn->show();
	$tb{next_btn} = $next_btn;
	
	my $select_page_combo = pEFL::Elm::Combobox->add($bx);
	_expand_widget_x($select_page_combo);
	$select_page_combo->text_set("");
	
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default");
	$itc->text_get(sub {return pEFL::Elm::Entry::utf8_to_markup($_[0]);});
	$select_page_combo->smart_callback_add("item,selected", \&_select_page_combo_item_selected_cb, $self);
	$select_page_combo->smart_callback_add("item,pressed", \&_select_page_combo_item_pressed_cb, $self);
	$select_page_combo->show(); $bx->pack_end($select_page_combo);
	$tb{combo} = $select_page_combo;
	$tb{itc} = $itc;

	$self->{toolbar} = \%tb;
}

sub next_page_cb {
	my ($preview) = @_;
	$preview->next_page();
	$preview->render_preview($preview->app->tmpdir . "/preview");
}

sub previous_page_cb {
	my ($preview) = @_;
	$preview->previous_page();
	$preview->render_preview($preview->app->tmpdir . "/preview");
}

sub preview_cb {
	my ($preview) = @_;

	$preview->generate_preview();
	
	# Generate MIDI only if preview is succesful
	# (generate_preview set $preview->up_to_date() to 1!!!)
	$preview->app->midi->generate_mid() if ($preview->up_to_date());	
}

sub generate_preview {
	my ($preview) = @_;
	
	my $app = $preview->app();
	my $en = $app->entry->elm_entry();
	my $text = $en->entry_get();
	
	# delete old created files	
	my $tmpdir = $app->tmpdir();
	my @filelist = <"$tmpdir/preview*">;
	foreach my $file (@filelist) {
		unlink $file;
	}
	
	my $r = $app->renderer();
	$r->render_preview(outfile => "$tmpdir/preview");

	if (-e "$tmpdir/preview-1.svg") {
		my @filelist = <"$tmpdir/preview*.svg">;
		my $number_of_pages = @filelist;
		$preview->page(1) unless $preview->page();
		$preview->number_of_pages($number_of_pages);
		$preview->render_preview("$tmpdir/preview");
		
		# For insert decoration functionality it is important, that preview is up-to-date
		$preview->up_to_date(1);
		
		# Update Combobox
		$preview->update_page_combo($number_of_pages);
	}
	else {
		warn "$tmpdir/preview-1.svg doesn*t exist\n";
	}	
}

sub update_page_combo {
	my ($self, $number_of_pages) = @_;

	my $tb = $self->{toolbar};
	return unless ($tb);
	
	my $combo = $tb->{combo};
	$combo->clear();
	foreach my $i (1..$number_of_pages) {
		$combo->item_append($tb->{itc}, "Page $i (#$i)", undef, ELM_GENLIST_ITEM_NONE, undef, undef);
	}
	$combo->text_set("Page ". $self->page() . "(#" . $self->page(). ")");
}


sub _select_page_combo_item_pressed_cb {
	my ($self,$obj,$event_info) = @_;
	
	my $item = pEFL::ev_info2obj($event_info, "ElmGenlistItemPtr");
	
	my $text = $item->text_get();
	$obj->text_set($text);
	$item->selected_set(1);
	$obj->hover_end();

	my $index = $1 if (defined($text) && $text =~ /\(#(\d+)\)\s*$/);;
	return unless (defined($index));

	my $tmpdir = $self->app->tmpdir;
	$self->page($index);
	$self->render_preview("$tmpdir/preview");
	$self->up_to_date(1)
	#$self->update_toolbar();
}

# FIX SELECTION ISSUE!
# Don't select item if it is clicked
sub _select_page_combo_item_selected_cb {
	my ($self,$obj,$event_info) = @_;
	
	my $item = pEFL::ev_info2obj($event_info, "ElmGenlistItemPtr");
	$item->selected_set(0);
}

sub move_notes {
	my ($self,$scroller,$ev) = @_;
	
	my $config = $self->app->settings->load_config();
	my $scale_factor = $config->{preview_scale} || 1;
	
	return unless (ref($self->{notes_rect}) eq "ARRAY");
	my @notes = @{$self->{notes_rect}};
	
	my ($vx,$vy,$vw,$vh) = $self->elm_viewer->geometry_get();
	my ($sx,$sy,$sw,$sh) = $self->elm_scroller->geometry_get();

	foreach my $note (@notes) {
		my $n = $note->{evas_object};
		my $x = ($scale_factor * $note->{x}) + $vx;
		my $y = ($scale_factor * $note->{y}) + $note->{svg_offset} + $vy;
		my ($nx,$ny,$nw,$nh) = $n->geometry_get();

		# komplett im sichtbaren Bereich des Scrollers?
		if ($x < $sx || $y < $sy
	    	|| ($x + $nw) > ($sx + $sw)
	    	|| ($y + $nh) > ($sy + $sh)) {
			$n->hide();
		}
		else {
			$n->move($x, $y);
			$n->show();
		}
	}
	
	return unless (ref($self->app->midi->{voice_pointers}) eq "ARRAY");
	my @voice_pointers = @{$self->app->midi->{voice_pointers}};
	
	foreach my $vp (@voice_pointers) { 
			$vp->hide() if (defined($vp));	
	}
	
}

sub load_tune {
	my ($self,$file,$scale_factor,$no_parse) = @_;
	
	# Clear viewer
	$self->clear_viewer();
	
	my $viewer = $self->elm_viewer();
	
	# Creating tune and notes
	# estimate dimensions of the svg
	my $info = image_info("$file");
	my ($w,$h) = dim($info); 
	$w =~ s/px$//;$h =~ s/px$//;
	
	# create image
	$viewer->file_set(undef,"");
    $viewer->size_hint_min_set($w,$h);
	$viewer->file_set($file,"");
	
	#my @notes = parse_abc("$file");
	my %notes = %{ $self->{notes} };
	#foreach my $note (@notes) {
	while ( my ($key, $value) = each(%notes) ) {
	    my $note = $value; 
	    next if ($note->{page_nr} != $self->page());
		
		my $n = $self->create_note_rect($note,[24,68,91,0],$scale_factor);
		
		$n->event_callback_add(EVAS_CALLBACK_MOUSE_IN, sub {$_[0]->color_set(24,68,91,150)}, $n);
	    $n->event_callback_add(EVAS_CALLBACK_MOUSE_OUT, sub {$_[0]->color_set(0,0,0,0)}, $n);
	    
	    # Dirty Workaround: On wheel event we hide, so that the scroller can retrieve the wheel event
	    $n->event_callback_add(EVAS_CALLBACK_MOUSE_WHEEL, sub {$_[0]->hide()}, $n);
	    
	    my $renderer = $self->app->renderer;
	    my $istart = $note->{istart} - $renderer->preview_beginabc_length();
		my $iend = $note->{iend} - $renderer->preview_beginabc_length();
	    
		$n->event_callback_add(EVAS_CALLBACK_MOUSE_UP, \&jump_to_note, [$self,$note]);
		$n->event_callback_add(EVAS_CALLBACK_MOUSE_DOWN, \&set_longpress_check, [$self,$note]);
	
		$note->{evas_object} = $n;
		
		push @{$self->{notes_rect}},$note;
		$self->{notes}->{$key}->{evas_object} = $n;
	}
	
	# keine Sichtbarkeit über den Rand hinaus 
	# Das muss bereits bei Erstellung geprüft werden, nicht erst beim ersten Scroll-/Resize-Event
	move_notes($self, $self->elm_scroller, undef);
}

sub create_note_rect {
    my ($self, $note, $color, $scale_factor) = @_;
    
    my $viewer = $self->elm_viewer();
    my $canvas = $self->elm_scroller->evas_get();
    
    my ($vx,$vy,$vw,$vh) = $viewer->geometry_get();
    
    my $n = pEFL::Evas::Rectangle->new($canvas);
	$n->move(($scale_factor*$note->{x})+$vx, ($scale_factor*$note->{y})+$note->{svg_offset}+$vy);
	$n->resize($scale_factor*$note->{width},$scale_factor*$note->{height});
	$n->color_set(@$color);
	$n->show();
	
	return $n;
}

sub set_longpress_check {
	my ($data, $evas, $obj, $event_info) = @_;
	my $event = pEFL::ev_info2obj($event_info, "pEFL::Evas::Event::MouseDown");
	my ($self, $note) = @$data;
	$self->longpress_check(1);
	pEFL::Ecore::Timer->add(0.3,\&longpress_cb,[$self,$note]);
}

sub longpress_cb {
	my ($data) = @_;
	my ($self, $note) = @$data;
	if ($self->longpress_check && $self->up_to_date() == 0) {
		$self->app->_show_info("Error", "The Entry was changed and so the Preview is not up to date.<br>" .
			"Please refresh preview before inserting decorations");
	}
	elsif ($self->longpress_check) {
		$self->longpress_check(0);
		show_context_menu($self,$note);
	}		
	return ECORE_CALLBACK_CANCEL;
}

sub show_context_menu {
	my ($self, $note) = @_;
	
	#return if ($list_mouse_down > 0);
	my $obj = $self->elm_viewer();
	
	my $ctxpopup = pEFL::Elm::Ctxpopup->add($obj);
	$ctxpopup->smart_callback_add("dismissed", \&_dismissed_cb, undef);
	
	item_new($ctxpopup, "dynamics", "mp", $self, $note);
	item_new($ctxpopup, "articulations", ">",$self, $note);
   	item_new($ctxpopup, "ornaments", "trill", $self,$note);
   	item_new($ctxpopup, "fermata etc", "fermata", $self,$note);
   	item_new($ctxpopup,"repetitions", "slashslashslash", $self,$note);
   	item_new($ctxpopup,"range decos", "8vastart", $self,$note);
   	item_new($ctxpopup,"bindings", "end", $self,$note);
   	
   	my $canvas = $obj->evas_get();
   	my ($x, $y) = $canvas->pointer_canvas_xy_get();
   	$ctxpopup->move($x,$y);
   	$ctxpopup->show();
}

sub _ctxpopup_item_cb {
	my ($data, $obj, $evinfo) = @_;
	my $selected = pEFL::ev_info2obj($evinfo, "pEFL::Elm::CtxpopupItem");
	
	my $self = $data->[0];
	my $note = $data->[2];
	
	#my $istart = $note->{istart};
	#my $start_offset = $note->{istart} - $self->app->renderer->preview_beginabc_length();
	
	#my $entry = $self->elm_entry();
	#$entry->select_none();
	#$entry->cursor_pos_set($start_offset);
	
	$obj->del();
	Caecilia::Entry::select_deco($data,$data->[0]->app->entry->elm_entry(),undef);
	
}

sub item_new {
	my ($ctxpopup, $label, $fname, $self, $note) = @_;
	
	my $icon_file = $self->app()->share_dir() . "/icons/decos/$fname.png";
    my $icon = pEFL::Elm::Icon->add($ctxpopup);
    $icon->file_set("$icon_file", undef );
    $icon->size_hint_aspect_set(0.5, 1, 1);
    
	my $entry = $self->app->entry();
		
	return $ctxpopup->item_append("Insert $label", $icon, \&_ctxpopup_item_cb, [$entry, $label, $note]);
}

sub _dismissed_cb {
	my ($data, $obj, $ev) = @_;
	$obj->del();
}

sub jump_to_note {
	my ($data, $evas, $obj, $event_info) = @_;
	my $event = pEFL::ev_info2obj($event_info, "pEFL::Evas::Event::MouseUp");
	my ($self, $note) = @$data;
	
	unless ($self->longpress_check()) {
		# Do nothing, because we had a hold event
	}
	else {
		$self->longpress_check(0);
		my $istart = $note->{istart};
		my $start_offset = $note->{istart} - $self->app->renderer->preview_beginabc_length(); 
		my $stop_offset = $note->{iend} - $self->app->renderer->preview_beginabc_length();
		if ($event->button == 1) {
	
		my $en = $self->app->entry->elm_entry;
		my $textblock = $en->textblock_get();
		my $cp1 = pEFL::Evas::TextblockCursor->new($textblock);
		#$cp1->pos_set(0);
		#my $i;
		#for ($i=0;$i<$row;$i++) {
		#	$cp1->paragraph_next();
		#}
		#my $lpos = $cp1->pos_get();
		$cp1->pos_set($start_offset);
		my $cp2 = pEFL::Evas::TextblockCursor->new($textblock);
		$cp2->pos_set($stop_offset);
	
		my $start = $cp1->pos_get();
		my $e = $cp2->pos_get();
		$en->cursor_pos_set($start);
		$en->select_region_set($start,$e);
	
		$cp1->free();
		$cp2->free();
		}
		elsif ($event->button == 3) {
			my $midi_position = $self->{notes}->{$istart}->{midi_position};
			my $midi = $self->app->midi;
			my $spinner = $midi->elm_progress_spinner;
			my $video = $midi->elm_video();
			my $emotion = $video->emotion_get();
		
			$video->pause() if ($emotion->play_get());
			$video->play_position_set($midi_position);
			$video->play();
		}
	
	}
	
}

# TODO: This function isn't used anymore
sub parse_abc {
	my ($file) = @_;
	$file =~ s/-.*.svg//;
	$file = "$file.notes";
	my @notes;
	open my $fh, "<", $file;
	while (my $line = <$fh>) {
		if ($line =~ m!<abc type=".*" start_offset="(.*)" stop_offset="(.*)" x="(.*)" y="(.*)" width="(.*)" height="(.*)" svg_offset="(.*)" page_nr="(.*)"/>!) {
			my %note = (
					'start_offset' => $1,
					'stop_offset' => $2,
					'x' => $3,
					'y' => $4,
					'width' => $5,
					'height' => $6,
					'svg_offset' => $7,
					'page_nr' => $8,
					);
			push @notes, \%note;
		}
	}
	close $fh;
	return @notes;
}

sub show_logo {
	my ($self) = @_;
	
	$self->clear_viewer();
	
	my $app = $self->app();
	my $viewer = $self->elm_viewer();
	my $path = $app->share_dir . "/caecilia-logo.png";
	
	$viewer->size_hint_min_set(0,0);
	$viewer->file_set($path,"");
	$self->elm_scroller->region_show(0,0,1,1);
}

sub clear_notes {
	my ($self) = @_;
	
	my @notes = ();
	@notes = @{$self->{notes_rect}} if (defined($self->{notes_rect}));
	
	foreach my $note (@notes) { 
		my $n = $note->{evas_object};
		$n->del();
	}
	
	undef($self->{notes_rect});
}

sub clear_viewer {
	my ($self) = @_;
	
	$self->clear_notes();
		
	my $viewer = $self->elm_viewer();
	$viewer->file_set(undef,"");
}

sub reset_preview {
	my ($self) = @_;

	$self->page(0);
	$self->number_of_pages(0);
	$self->up_to_date(0);
	
	$self->clear_viewer();
	$self->clear_notes();
	
	$self->show_logo();
	# alternative: empty preview:
	#$self->elm_viewer->size_hint_min_set(0,0);
	#$self->elm_viewer->file_set(undef,"");
	#$self->elm_scroller->region_show(0,0,1,1);	
}

sub render_preview {
	my ($self, $filename) = @_;
	my $page = $self->page();
	my $number_of_pages = $self->number_of_pages;
	$page = $number_of_pages if ($page > $number_of_pages);
	$filename =~ s/\.abc$//;
	$filename =~ s/\d{3}$//;
	#if ($page < 10) {
	#	$filename = $filename . "00" . $page . ".svg";
	#}
	#elsif ($page < 100) {
	#	$filename = $filename . "0" . $page . ".svg";
	#}
	#else {
	#	$filename = $filename . $page . ".svg";
	#}
	my $config = $self->app->settings->load_config();
	$filename = "$filename-$page.svg";
	if (-e $filename) {
		$self->{filename} = $filename;
		$self->load_tune($filename, $config->{preview_scale} || 1);#scale_factor not used at moment
	}
}

sub next_page {
	my ($self) = @_;
	
	my $old_page = $self->page();
	my $new_page = $old_page + 1;
	
	unless ($old_page >= $self->number_of_pages()) {
		my $tb = $self->{toolbar};
		my $combo = $tb->{combo};
		$combo->text_set("Page $new_page (#$new_page)");
	
		return $self->page($new_page);
	}
	
}

sub previous_page {
	my ($self) = @_;
	
	my $old_page = $self->page();
	my $new_page = $old_page - 1;
	
	unless ($old_page <= 1) {
		my $tb = $self->{toolbar};
		my $combo = $tb->{combo};
		$combo->text_set("Page $new_page (#$new_page)");
	
		return $self->page($new_page);
	}
}

######################
# Accessors 
#######################

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|elm_viewer|elm_scroller|page|number_of_pages|longpress_check|up_to_date|/;
	
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



# Preloaded methods go here.

1;
__END__


=head1 NAME

Caecilia::Preview

=head1 DESCRIPTION

This is the Preview component of the Caecilia Appliation.

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
