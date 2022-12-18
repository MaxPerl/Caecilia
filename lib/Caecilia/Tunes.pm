package Caecilia::Tunes;

use 5.006001;
use strict;
use warnings;
use utf8;

require Exporter;

use pEFL::Elm;
use pEFL::Evas;

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

sub _new_tune_cb {
	my ($self) = @_;
	my @tunes = @{$self->tunes};
	my $tune_id = $#tunes+1;
	my $tune = Caecilia::Tune->new(id => $tune_id);
	$self->push_tune($tune);
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