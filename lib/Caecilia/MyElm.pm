package Caecilia::MyElm;

use strict;
use warnings;

require Exporter;

use pEFL::Elm;
use pEFL::Evas;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Tcl::Tk::ttk ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	_add_header
	_add_label
	_add_checkoption
	_add_entry_with_check
	_add_spin_with_check
	_expand_widget_x
	_expand_widget
	_combobox_item_pressed
	_add_color_setting
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

sub _add_header {
	my ($table, $row, $header, $width) = @_;
	$width = $width || 2;
	my $label = pEFL::Elm::Label->new($table);
	$label->text_set("<b>$header</b>");
	$label->size_hint_align_set(0,0);
	$label->show(); $table->pack($label,0,$row,$width,1);
}

sub _add_label {
	my ($table, $row, $header, $width) = @_;
	$width = $width || 1;
	my $label = pEFL::Elm::Label->new($table);
	$label->text_set("$header");
	$label->size_hint_align_set(0,0.5);
	$label->show(); $table->pack($label,0,$row,$width,1);
}

sub _add_checkoption {
	my ($table, %opts) = @_;
	
	my $check = pEFL::Elm::Check->add($table);
	_expand_widget_x($check);
	$check->text_set($opts{label});
	$check->state_set(1) if ($opts{value});
	$check->show(); $table->pack($check,0,$opts{row},2,1);
	
	return $check;
}

sub _add_entry_with_check {
	my ($table, %opts) = @_;
	
	my $check = pEFL::Elm::Check->add($table);
	_expand_widget_x($check);
	$check->text_set($opts{label});
	$check->state_set(1) if ($opts{value});
	$check->show(); $table->pack($check,0,$opts{row},2,1);
	
	my $en = pEFL::Elm::Entry->add($table);
	if ($opts{value}) {
		$en->entry_set($opts{value});
	}
	else {
		$en->disabled_set(1);
	}
	$en->scrollable_set(1);
	$en->single_line_set(1);
	$en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget_x($en);
	$en->show(); $table->pack($en,2,$opts{row},2,1);
	
	$check->smart_callback_add("changed", \&toggle, $en);
	
	return ($check,$en);
}

sub _add_spin_with_check {
	my ($table, %opts) = @_;
	
	my $check = pEFL::Elm::Check->add($table);
	_expand_widget_x($check);
	$check->text_set($opts{label});
	$check->state_set(1) if ($opts{value});
	$check->show(); $table->pack($check,0,$opts{row},2,1);
	
	my $spinner = pEFL::Elm::Spinner->add($table);
	$spinner->min_max_set($opts{min},$opts{max});
	$spinner->step_set($opts{step});
	$spinner->label_format_set($opts{fmt});
	
	if ($opts{value}) {
		$spinner->value_set($opts{value});
	}
	else {
		$spinner->disabled_set(1);
	}
	_expand_widget_x($spinner);
	$spinner->show(); $table->pack($spinner,2,$opts{row},1,1);
	
	$check->smart_callback_add("changed", \&toggle, $spinner);
	
	return ($check,$spinner);
}

sub toggle {
	my ($data,$check) = @_;
	
	if ($check->state_get()) {
		$data->disabled_set(0);
	}
	else {
		$data->disabled_set(1);
	}
}

sub _expand_widget {
	my ($widget) = @_;
	$widget->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
	$widget->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
}

sub _expand_widget_x {
	my ($widget) = @_;
	$widget->size_hint_align_set(EVAS_HINT_FILL,0);
	$widget->size_hint_weight_set(EVAS_HINT_EXPAND,0);
}

sub _combobox_item_pressed_cb {
	my ($data,$obj,$event_info) = @_;
	# Focus workaround 1: Without this after ending hover
	# the roller jumps up and down
	$obj->focus_set(1);
	my $item = pEFL::ev_info2obj($event_info, "ElmGenlistItemPtr");
	my $text = $item->text_get();
	$obj->text_set($text);
	$obj->hover_end();
	# Focus Workaround 2: Without this sometimes (multiple selection)
	# frame doesn't get the scroller again [and can't be scrolled by wheel]
	$data->focus_set(1);
}

############
# Color setting widgets
###########

sub _add_color_setting {
	my ($table,$row,$opts) = @_;
	
	_add_label($table,$row,$opts->{text});

	my $btn = pEFL::Elm::Button->add($table);
	$btn->size_hint_weight_set(EVAS_HINT_EXPAND,0);
	$btn->size_hint_align_set(EVAS_HINT_FILL,0);
	my $bg = pEFL::Elm::Bg->add($btn);
	$bg->color_set( @{ $opts->{color} } );
	$btn->part_content_set("icon", $bg);
	$btn->show(); $table->pack($btn,1,$row,1,1);
	$opts->{btn_bg} = $bg;
	
	$btn->smart_callback_add("clicked",\&set_color,$opts);
	
	return $bg;
}

sub set_color {
	my ($data,$obj,$evinfo) = @_;
	
	my $color_win = pEFL::Elm::Win->add($data->{win}, "Settings", ELM_WIN_BASIC);
	$color_win->title_set("Select color");
	$color_win->autodel_set(1);
	$color_win->resize(240,480);
	
	my $bg = pEFL::Elm::Bg->add($color_win);
	$bg->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
	$bg->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$bg->show(); $color_win->resize_object_add($bg);
	
	my $bx = pEFL::Elm::Box->add($color_win);
	$bx->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
	$color_win->resize_object_add($bx);
	$bx->show();

	my $fr = pEFL::Elm::Frame->add($color_win);
	$fr->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
	$fr->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$fr->text_set("Select color");
	$bx->pack_end($fr);
	$fr->show();

	my $rect = pEFL::Evas::Rectangle->add($color_win->evas_get());
	$fr->part_content_set("default",$rect);
	$rect->color_set(@{ $data->{color} },255);
	$rect->show();

	my $fr2 = pEFL::Elm::Frame->add($color_win);
	$fr2->size_hint_weight_set(1.0,0.5);
	$fr2->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$fr2->text_set("Color Selector");
	$bx->pack_end($fr2);
	$fr2->show();

	my $cs = pEFL::Elm::Colorselector->add($color_win);
	
	_create_palette($cs);
	
	$cs->size_hint_weight_set(EVAS_HINT_EXPAND,0.0);
	$cs->size_hint_align_set(EVAS_HINT_FILL,0.0);
	$cs->color_set(@{ $data->{color} },255);
	$cs->show();
	# TODO: Callbacks
	$fr2->part_content_set("default",$cs);
	
	my $ok_btn = pEFL::Elm::Button->new($bx);
	$ok_btn->text_set("OK");
	$ok_btn->size_hint_weight_set(EVAS_HINT_EXPAND,0);
	$ok_btn->size_hint_align_set(EVAS_HINT_FILL, 0);
	$ok_btn->show(); $bx->pack_end($ok_btn);
	
	my $cancel_btn = pEFL::Elm::Button->new($bx);
	$cancel_btn->text_set("Cancel");
	$cancel_btn->size_hint_weight_set(EVAS_HINT_EXPAND,0);
	$cancel_btn->size_hint_align_set(EVAS_HINT_FILL, 0);
	$cancel_btn->show(); $bx->pack_end($cancel_btn);
	
	# Callbacks
	$cancel_btn->smart_callback_add("clicked", sub { $color_win->del(); }, undef );
	$ok_btn->smart_callback_add("clicked", \&_set_color_cb, [$data, $cs, $color_win]);
	$cs->smart_callback_add("changed", \&_change_color,$rect);
	
	$color_win->show();
}

sub _create_palette {
	my $cs = shift;
	# default colors
	$cs->palette_name_set("myPalette");
	$cs->palette_color_add(157,157,157,255);
	$cs->palette_color_add(43,173,251,255);
	$cs->palette_color_add(203,49,155,255);
	$cs->palette_color_add(251,153,203,255);
	
	# source-highlight-colors
	$cs->palette_color_add(0,0,0,255);
	$cs->palette_color_add(255,255,255,255);
	$cs->palette_color_add(51,204,0,255);
	$cs->palette_color_add(255,0,0,255);
	$cs->palette_color_add(153,0,0,255);
	$cs->palette_color_add(0,0,255,255);
	$cs->palette_color_add(154,25,0,255);
	$cs->palette_color_add(204,51,204,255);
	$cs->palette_color_add(255,204,0,255);
	$cs->palette_color_add(102,255,255,255);
	$cs->palette_color_add(153,51,153,255);
	$cs->palette_color_add(255,102,0,255);
	$cs->palette_color_add(255,153,0,255);
	$cs->palette_color_add(51,255,51,255);
	$cs->palette_color_add(0,153,0,255);
	$cs->palette_color_add(0,128,128,255);
	$cs->palette_color_add(128,128,128,255);
	$cs->palette_color_add(0,0,128,255);
}

sub _set_color_cb {
	my ($data, $obj, $evinfo) = @_;
	my $opts = $data->[0];
	my $cs = $data->[1];
	my ($r,$g,$b,$a) = $cs->color_get();
	
	my $key = $opts->{key};
	my $config = $opts->{settings}->config();
	$config->{$key} = [$r,$g,$b];
	$opts->{settings}->config($config);
	
	$opts->{btn_bg}->color_set($r,$g,$b);
	
	$data->[2]->del();
}

sub _change_color {
	my ($rect, $obj, $evinfo) = @_;
	
	my ($r,$g,$b,$a) = $obj->color_get();
	$rect->color_set($r,$g,$b,$a);
}

1;

__END__

=head1 NAME

Caecilia::MyElm

=head1 DESCRIPTION

Some helpers / shortcuts for the pEFL UI parts of Caecilia.

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
