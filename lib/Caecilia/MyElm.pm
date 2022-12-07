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
	_add_checkoption
	_add_entry_with_check
	_add_spin_with_check
	_expand_widget_x
	_expand_widget
	_combobox_item_pressed
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

sub _add_header {
	my ($table, $row, $header) = @_;
	
	my $label = pEFL::Elm::Label->new($table);
	$label->text_set("<b>$header</b>");
	$label->size_hint_align_set(0,0);
	$label->show(); $table->pack($label,0,$row,2,1);
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
	my $item = pEFL::ev_info2obj($event_info, "ElmGenlistItemPtr");
	my $text = $item->text_get();
	$obj->text_set($text);
	$obj->hover_end();
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
