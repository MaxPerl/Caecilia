package Caecilia::Editor;

use 5.006000;
use strict;
use warnings;

use utf8;
use Gtk3;
use Glib('TRUE','FALSE');
use Gtk3::SourceView;
use File::ShareDir 'dist_dir';

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
	
	my $editor_object = {};
	bless $editor_object;
	
	# Sharedir
	my $sharedir = dist_dir('Caecilia');
	
	# a scrolled window for the textview
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy("automatic", "automatic");
	$scrolled_window->set_border_width(5);
	# use the set_hexpand and set_vexpand from Gtk3::Widget on the
	# ScrolledWindow to expand it!
	$scrolled_window->set_hexpand(TRUE);
	$scrolled_window->set_vexpand(TRUE);
	
	# Init LanguageManager
	my $lm = Gtk3::SourceView::LanguageManager->new();
	my @search_path = $lm->get_search_path();
	unshift @search_path, $sharedir;
	$lm->set_search_path(\@search_path);
	
	# Get Caecilia Layout Scheme
	my $sm = Gtk3::SourceView::StyleSchemeManager->new();
	$sm->set_search_path([$sharedir]);
	my $scheme = $sm->get_scheme('caecilia');
	
	# Syntax Hervorhebung im Buffer aktivierten
	my $lang = $lm->get_language("abc");
	my $buffer = Gtk3::SourceView::Buffer->new_with_language($lang);
	$buffer->set_style_scheme($scheme);
	$buffer->set_highlight_syntax(TRUE);
	
	# Save the change status property
	$editor_object->changed_status(0);
	$buffer->signal_connect('changed'=>\&changed_text, $editor_object);
	
	# a textview
	my $textview = Gtk3::SourceView::View->new();
	# displays the buffer
	$textview->set_buffer($buffer);
	$textview->set_highlight_current_line(TRUE);
	$textview->set_show_line_numbers(TRUE);
	$textview->set_wrap_mode("word");
	
	# Adjust the font size
	my $fontdesc = Pango::FontDescription->new();
	$fontdesc->set_size(12*Pango::SCALE);
	$textview->modify_font($fontdesc);
	
	$scrolled_window->add($textview);
	
	# Set some variables
	$editor_object->{view} = $scrolled_window;
	$editor_object->{buffer} = $buffer;
	$editor_object->{textview} =  $textview;

	return $editor_object;
}

sub get_text {
	my ($self) = @_;
	my $buffer = $self->{buffer};
	my ($start, $end) = $buffer->get_bounds();
	my $content = $buffer->get_text($start, $end, FALSE);
	return $content;
}

sub set_text {
	my ($self, $content) = @_;
	my $buffer = $self->{buffer};
	# important: we need the length in byte!! Usually the perl function
	# length deals in logical characters, not in physical bytes! For how
	# many bytes a string encoded as UTF-8 would take up, we have to use
	# length(Encode::encode_utf8($content) (for that we have to "use Encode"
	# first [see more http://perldoc.perl.org/functions/length.html]
	# Alternative solutions: 1) open with tag "<:encoding(utf8)"
	# 2) For insert all the text set length in the $buffer->set_text method 
	# 	to -1 (!text must be nul-terminated)
	# 3) In Perl Gtk3 the length argument is optional! Without length 
	#	all text is inserted
	my $length = length(Encode::encode_utf8($content));
	$buffer->set_text($content,$length);
	
	return 1;
}

# call bach function if TEXT IN A BUFFER CHANGED
sub changed_text {
	my $buffer = shift;
	my $self = shift;
	$self->changed_status(1);
	
}

sub changed_status {
	my ($self, $new_status) = @_;
	
	
	my $old_status = $self->{changed_status};
	
	$self->{changed_status} = $new_status if (defined $new_status);
	
	return $old_status;
}

sub jump_to {
	my ($self, $row, $col) = @_;
	my $buffer = $self->{buffer};
	# Place cursor to found note
	my $iter = $buffer->get_iter_at_line_offset($row-1,$col);
	$buffer->place_cursor($iter);
	
	# reset blinking of cursor
	my $textview = $self->{textview};
	$textview->reset_cursor_blink();
	
	# Scroll to cursor
	my $x = $textview->scroll_to_iter($iter, 0.0,TRUE, 0.0, 0.4);
	

	return 1
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
