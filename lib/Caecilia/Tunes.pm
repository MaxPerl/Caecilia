package Caecilia::Tunes;

use 5.006001;
use strict;
use warnings;
use utf8;

require Exporter;

use pEFL::Elm;
use pEFL::Evas;

use Caecilia::MyElm qw(_add_header _expand_widget _expand_widget_x _add_entry_with_check _add_spin_with_check _combobox_item_pressed);

use File::Basename;

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

our $VERSION = '0.01';

sub new {
	my ($class, $app, $box) = @_;
	
	# Get index
	
	my $obj = {
		app => $app,
		tunes => [],
		elm_tabsbar => undef,
		
		};
	bless($obj,$class);
	$obj->init_tunesbar($app,$box);
	return $obj;
}

sub init_tunesbar {
	my ($self, $app, $box) = @_;
	
	my $tunesbar = pEFL::Elm::Toolbar->add($box);
	$tunesbar->homogeneous_set(0);
	$tunesbar->align_set(0);
	$tunesbar->size_hint_align_set(EVAS_HINT_FILL, 0);
	$tunesbar->size_hint_weight_set(EVAS_HINT_EXPAND, 0);
	$tunesbar->shrink_mode_set(ELM_TOOLBAR_SHRINK_SCROLL);
	$tunesbar->transverse_expanded_set(1);
	$box->pack_end($tunesbar);
	
	$self->elm_tabsbar($tunesbar);
	
	# This is very tricky
	# _close_tune_cb only works if the right tune is selected
	# the easiest solution would be to make an own menu for each toolbar item
	# unfortunately this does not work (because items can not have own evas (smart) events
	# therefore the solution here is only to show the menu when a left click occurs at the
	# selected tune item (see show_tab_menu)
	my $menu = pEFL::Elm::Menu->add($tunesbar);
	$menu->item_add(undef,undef,"Close tune",\&_close_tune_cb,$self);
	$tunesbar->event_callback_add(EVAS_CALLBACK_MOUSE_DOWN,\&show_tab_menu,$menu);
	$tunesbar->smart_callback_add("selected",\&_no_change_tab,$self);

	$tunesbar->show();
}

sub _no_change_tab {
	my ($data, $obj, $ev_info) = @_;
	my $tabitem = pEFL::ev_info2obj($ev_info, "ElmToolbarItemPtr"); 	
	unless ($obj->selected_item_get()) {
		$tabitem->selected_set(1);
	}
} 

sub _close_tune_cb {
	my ($self) = @_;
	
	my @tunes = @{$self->tunes}; 
	my $current_tune = $self->app->current_tune();
	
	if ($current_tune->changed() > 0) {
		my $popup = pEFL::Elm::Popup->add($self->app->elm_mainwindow());
		
		$popup->part_text_set("default","Warning: Tune contains unsaved content. Close anyway?");
		
		my $btn1 = pEFL::Elm::Button->add($popup);
		$btn1->text_set("Okay");
		$btn1->smart_callback_add("clicked" => sub {$current_tune->changed(0); $popup->del(); $self->_close_tune_cb});
		
		my $btn2 = pEFL::Elm::Button->add($popup);
		$btn2->text_set("Cancel");
		$btn2->smart_callback_add("clicked" => sub {$popup->del});
		
		$popup->part_content_set("button1", $btn1);
		$popup->part_content_set("button2", $btn2);
		
		$popup->show();
	}
	else {
		my $tune_id = $current_tune->id();
		$self->clear_tunes();
		splice @tunes,$tune_id,1;
		$self->refresh_tunes(@tunes);
	}
	
	if ($#tunes < 0 ) {
		pEFL::Elm::exit();
	}
}

sub _new_tune {
	my ($self) = @_;
	
	my $mw = $self->app->elm_mainwindow();
	
	my $new_win = pEFL::Elm::Win->add($mw, "New abc file", ELM_WIN_BASIC);
	$new_win->title_set("Create a new abc file");
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
	$frame->text_set("Create .abc file");
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
	
	$self->_add_buttons($table, 14,\@args);
	
	$new_win->resize(420,600);
	$new_win->show();
	
}

sub _add_buttons {
	my ($self,$table,$row, $args) = @_;
	
	my $width = 2;
	my $btn_bx = pEFL::Elm::Box->add($table);
	_expand_widget_x($btn_bx);
	$btn_bx->horizontal_set(1);
	$btn_bx->show(); $table->pack($btn_bx,0,$row,$width,1);
	
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
	$ok_btn->smart_callback_add("clicked", \&_new_tune_cb, [$self,$args]);
	
	return $btn_bx;
}

sub _new_tune_cb {
	my ($data, $btn) = @_;
	my $self = $data->[0]; my $args = $data->[1];
	my @tunes = @{$self->tunes};
	my $tune_id = $#tunes+1;
	
	my $key = $args->[7]->text_get() || undef;
	if ($key) {
		$key =~ s/\(.*\)//;
	}
	
	my $content .= "X: 1<br/>";
	$content .= "T: ". $args->[1]->text_get() . "<br/>" if ($args->[1]->text_get);
	$content .= "T: ". $args->[2]->text_get() . "<br/>" if ($args->[2]->text_get);
	$content .= "C: ". $args->[3]->text_get() . "<br/>" if ($args->[3]->text_get);
	$content .= "M: ". $args->[4]->text_get() . "<br/>" if ($args->[4]->text_get);
	$content .= "L: ". $args->[5]->text_get() . "<br/>" if ($args->[5]->text_get);
	$content .= "Q: ". $args->[6]->text_get() . "<br/>" if ($args->[6]->text_get);
	$content .= "K: ". $key . "<br/>" if ($key);
	
	
	
	$args->[0]->del();
	my $tune = Caecilia::Tune->new(id => $tune_id, content => $content);
	$self->push_tune($tune);
	$self->app->entry->elm_entry->entry_set($content);
}

sub clear_tunes {
	my ($self) = @_;
	
	foreach my $tune (@{$self->tunes}) {
		$tune->elm_toolbar_item->del();
		$tune->elm_toolbar_item(undef);
	}
	
	$self->tunes([]);
}

sub refresh_tunes {
	my ($self,@tunes) = @_;
	
	my $id = 0;
	foreach my $tune (@tunes) {
		$self->push_tune($tune);
		$tune->id($id);
		$id++;
	}
}

sub push_tune {
	my ($self, $tune) = @_;
	
	push @{$self->tunes}, $tune;
	my @tunes = @{$self->tunes};
	
	my $tunesbar = $self->elm_tabsbar();
	my $filename = $tune->filename() || "Untitled";
	
	my ($name,$dirs,$suffix) = fileparse($filename);
	$name = "$name*" if ($tune->changed()>0);
	 
	my $id = $#tunes;
	
	my $tab_item = $tunesbar->item_append(undef,$name, \&change_tab, [$self, $id]);
	
	$tune->elm_toolbar_item($tab_item);
	
	# Select the new item and deselect the actual selected item
	$tab_item->selected_set(1);
}


sub show_tab_menu {
	my ($menu, $evas, $obj, $evinfo) = @_;
	my $ev = pEFL::ev_info2obj($evinfo, "pEFL::Evas::Event::MouseDown");
	
	my $selected = $obj->selected_item_get();
	my $track = $selected->track();
	my ($x,$y,$w,$h) = $track->geometry_get();
	$selected->untrack();
	my $canvas = $ev->canvas();
	return unless ($canvas->{x} > $x && $canvas->{x} < $x+$w);
	
	if ($ev->button == 3) {
		$menu->move($canvas->{x},$canvas->{y});
		$menu->show();
	}
}

sub change_tab {
	my ($data, $obj, $ev_info) = @_;
	my $tabitem = pEFL::ev_info2obj($ev_info, "ElmToolbarItemPtr");
	
	my $self = $data->[0];
	my $id = $data->[1]; 
	
	my $tunes = $self->tunes();
	my $entry = $self->app->entry;
	
	
	my $en=$entry->elm_entry;
	if ( ref($self->app->current_tune) eq "Caecilia::Tune") {
		 my $current = $self->app->current_tune;
		 $current->content($en->entry_get);
		 $current->cursor_pos($en->cursor_pos_get());
	}
	else {
		warn "Warn: This is very curious :-S There is no current tune???\n";
	}
	my $tune = $tunes->[$id];
	$self->app->current_tune($tune);
		
	$entry->is_change_tab("yes");
	$en->entry_set($tune->content);
	$en->focus_set(1);
		
}


############################
# Accessors
############################

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|tunes|elm_tabsbar/;
	
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

Caecilia::Tunes

=head1 DESCRIPTION

This is the Tunes component (e.g. the tunesbar where you can select the opened tunes) of the Caecilia Appliation.

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
