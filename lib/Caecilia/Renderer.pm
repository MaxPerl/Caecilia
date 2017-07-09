package Caecilia::Renderer;

use 5.006000;
use strict;
use warnings;

use utf8;
use Gtk3;
use Glib('TRUE','FALSE');
use File::ShareDir 'dist_dir';
use Caecilia::Settings;
use Cwd;

require Exporter;

our @ISA = qw(Exporter);

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
	my ($class, %config) = shift;
	
	my $renderer_object = {};
	bless $renderer_object;
	
	# Sharedir
	my $sharedir = dist_dir('Caecilia');
	
	return $renderer_object;
}

sub render {
	my (%opts) = @_;
	my $dir = $opts{tmpdir};
	
	my @cmd;
	push @cmd, $Caecilia::Settings::ABCM2PS_PATH;
	push @cmd, '-c' if ($Caecilia::Settings::ABCM2PS_AUTOLINEBREAK);
	push @cmd, '-A' if ($opts{mode} eq 'preview');
	push @cmd, "-B$Caecilia::Settings::ABCM2PS_BREAKNBARS" if ($Caecilia::Settings::ABCM2PS_BREAKNBARS);
	push @cmd, "-e$opts{pattern}" if ($opts{pattern});
	push @cmd, "-s$Caecilia::Settings::ABCM2PS_SCALEFACTOR" if ($Caecilia::Settings::ABCM2PS_SCALEFACTOR);
	push @cmd, "-w$Caecilia::Settings::ABCM2PS_STAFFWIDTH" if ($Caecilia::Settings::ABCM2PS_STAFFWIDTH);
	push @cmd, "-m$Caecilia::Settings::ABCM2PS_LEFTMARGIN" if ($Caecilia::Settings::ABCM2PS_LEFTMARGIN);
	push @cmd, "-d$Caecilia::Settings::ABCM2PS_STAFFSEPARATION" if ($Caecilia::Settings::ABCM2PS_STAFFSEPARATION);
	push @cmd, "-a$Caecilia::Settings::ABCM2PS_MAXSHRINK" if ($Caecilia::Settings::ABCM2PS_MAXSHRINK);
	push @cmd, "-l" if ($Caecilia::Settings::ABCM2PS_LANDSCAPE);
	push @cmd, "-I$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE" if ($Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE);
	push @cmd, "-x" if ($Caecilia::Settings::ABCM2PS_XREFNUMBERS);
	push @cmd, "-M" if ($Caecilia::Settings::ABCM2PS_NOLYRICS);
	push @cmd, "-N$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE " if ($Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE);
	push @cmd, "-1" if ($Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE);
	push @cmd, "-G" if ($Caecilia::Settings::ABCM2PS_NOSLURINGRACE);
	push @cmd, "-b$opts{firstmeasure}" if ($opts{firstmeasure});
	push @cmd, "-f" if ($Caecilia::Settings::ABCM2PS_FLATBEAMS);
	
	my $text = $opts{editor}->get_text();
	
	# create new files for preview	
	open my $fh, ">:encoding(utf8)", "$dir/render.abc";
	print $fh "$text";
	close $fh;
	
	push @cmd, "$dir/render.abc";
	
	push @cmd, "-E" if ($opts{outformat} eq "1");
	push @cmd, "-g" if ($opts{outformat} eq "2");
	push @cmd, "-v" if ($opts{outformat} eq "3");
	push @cmd, "-X" if ($opts{outformat} eq "4");
	push @cmd, "-z" if ($opts{outformat} eq "5");
	
	$opts{outfile} = $opts{outfile} . ".ps" if ($opts{outformat} eq "0");
	$opts{outfile} = $opts{outfile} . ".eps" if ($opts{outformat} eq "1");
	$opts{outfile} = $opts{outfile} . ".svg" if ($opts{outformat} eq "2");
	$opts{outfile} = $opts{outfile} . ".svg" if ($opts{outformat} eq "3");
	$opts{outfile} = $opts{outfile} . ".xhtml" if ($opts{outformat} eq "4");
	$opts{outfile} = $opts{outfile} . ".xhtml" if ($opts{outformat} eq "5");
	push @cmd, "-O$opts{outfile}";
	
	print "CMD @cmd \n";
	system(@cmd);
	if ($?) {
		# if generating preview doesn't work, show an error dialog
		my $dialog = Gtk3::Dialog->new();
		$dialog->set_title('Error');
		$dialog->set_transient_for($opts{window});
		$dialog->set_modal('TRUE');
		$dialog->add_button('Ok','ok');
		$dialog->signal_connect('response' => sub {shift->destroy();});
		my $content_area = $dialog->get_content_area();
		my $label= Gtk3::Label->new("Could not run abcm2ps successfully\nExit-Code: $?");
		$content_area->add($label);
		$dialog->show_all();
	}
}

sub render_dialog {
	my ($self, $window,$editor, $tmpdir, $filename_ref) = @_;
	
	my $dialog = Gtk3::Dialog->new();
	$dialog->set_transient_for($window);
	
	my $content_area = $dialog->get_content_area();
	my $grid = Gtk3::Grid->new();
	$grid->set_column_spacing(20); $grid->set_row_spacing(5);
	
	# Output label
	my $outfile_label = Gtk3::Label->new("Outfile");
	my $outfile_entry = Gtk3::Entry->new(); $outfile_entry->set_hexpand(TRUE);
	if ($$filename_ref) {
		my $filename = $$filename_ref;
		$filename =~ s/.abc$//;
		$outfile_entry->set_text($filename);
	}
	else {
		my $filename = getcwd . "/Out";
		$outfile_entry->set_text($filename);
	}
	
	# output format combobox
	my @outformats = ('.ps', '.eps','.svg (one tune per file)','.svg (one page per file)','.xhtml','.xhtml (embedded abc)');
	my $liststore = Gtk3::ListStore->new('Glib::String');
	foreach my $mode (@outformats) {
		my $iter = $liststore->append();
		$liststore->set($iter, 0 => "$mode");
	}
	my $outformats_combobox = Gtk3::ComboBox->new_with_model($liststore);
	my $cell = Gtk3::CellRendererText->new();
	$outformats_combobox->pack_start($cell, FALSE);
	$outformats_combobox->add_attribute($cell, 'text', 0);
	$outformats_combobox->set_active(0);
	
	# first measure number
	my $firstmeasure_check = Gtk3::CheckButton->new("first measure number");
	my $ad = Gtk3::Adjustment->new(0,0,1000,1,0,0);
	my $firstmeasure_spin = Gtk3::SpinButton->new($ad, 1, 0);
	$firstmeasure_spin->set_state_flags('insensitive', TRUE);
	$firstmeasure_check->signal_connect('toggled' => \&_toggle_check, $firstmeasure_spin);
	
	# tune selection
	my $pattern_check = Gtk3::CheckButton->new("Tune Selection");
	my $pattern_entry = Gtk3::Entry->new();$pattern_entry->set_hexpand(TRUE);
	$pattern_entry->set_state_flags('insensitive', TRUE);
	$pattern_check->signal_connect('toggled' => \&_toggle_check, $pattern_entry);
	
	# Attach the widgets to the grid
	# attach(Kind, links, oben, Weite, Höhe)
	$grid->attach($outfile_label, 0,0,1,1);
	$grid->attach($outfile_entry, 1, 0, 1, 1);
	$grid->attach($outformats_combobox, 2,0,1,1);
	$grid->attach($pattern_check, 0,1,1,1);$grid->attach($pattern_entry, 1,1,2,1);
	$grid->attach($firstmeasure_check, 0,2,1,1);$grid->attach($firstmeasure_spin, 1,2,2,1);
	
	####
	# The Apply/Cancel Buttons
	####
	$dialog->add_button('Abcm2ps Settings', '1');
	$dialog->add_button('Ok', 'ok');
	$dialog->add_button('Cancel', 'cancel');
	my @widgets = ($window, $editor, $tmpdir, $outfile_entry, $outformats_combobox, $pattern_entry, $firstmeasure_spin);
	$dialog->signal_connect('response' => \&render_dialog_response, \@widgets);
	
	$content_area->add($grid);
	$dialog->show_all();
}

sub render_dialog_response {
	my ($dialog, $response, $widgets_ref) = @_;
	my ($window, $editor, $tmpdir,  $outfile_entry, $outformats_combobox, $pattern_entry, $firstmeasure_spin) = @$widgets_ref;
	if ($response eq 'ok') {
		my $outfile = $outfile_entry->get_text();
		my $outformat = $outformats_combobox->get_active();
		my $pattern = $pattern_entry->get_text() unless (grep /insensitive/, @{$pattern_entry->get_state_flags()});
		my $firstmeasure = $firstmeasure_spin->get_value() unless (grep /insensitive/, @{$firstmeasure_spin->get_state_flags()});
		render(outfile => $outfile, outformat => $outformat, pattern => $pattern, firstmeasure => $firstmeasure, editor => $editor, tmpdir => $tmpdir, window => $window);
		$dialog->destroy; 
	}
	elsif ($response eq "1") {
		Caecilia::Settings::settings_cb($window);
	}
	else {
		$dialog->destroy();
	}
}

sub _toggle_check {
	my ($check, $widget) = @_;
	if ($check->get_active()) {
		$widget->set_state_flags('normal', TRUE);
	}
	else {
		$widget->set_state_flags('insensitive', TRUE);
	}
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Caecilia - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Caecilia;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Caecilia, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Maximilian Lika, E<lt>maximilian@(none)E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2017 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
