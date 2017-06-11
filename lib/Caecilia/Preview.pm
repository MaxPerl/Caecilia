package Caecilia::Preview;

use 5.006000;
use strict;
use warnings;

use utf8;
use Gtk3;
use Glib('TRUE','FALSE');

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
	my ($class, %config) = @_;
	
	my $preview_object = \%config;
	bless $preview_object;
	
	# page_id
	$preview_object->page('1');
	$preview_object->build_preview_object;
	
	#$preview_object->render_preview('content' => $preview_object->{'content'});
	
	return $preview_object;
}

sub build_preview_object {
	my ($self) = shift;
	
	# a scrolled window for the textview
	my $scrolled_window = Gtk3::ScrolledWindow->new();
	$scrolled_window->set_policy("automatic", "automatic");
	$scrolled_window->set_border_width(5);
	# use the set_hexpand and set_vexpand from Gtk3::Widget on the
	# ScrolledWindow to expand it!
	$scrolled_window->set_hexpand(TRUE);
	$scrolled_window->set_vexpand(TRUE);
	
	my $image = Gtk3::Image->new();
	my $scale_factor = 1.0;
	
	# Save the scrolled window
	$self->{image} = $image;
	$self->{view} = $scrolled_window;
	$self->{scale_factor} = 1.0;
	$self->{filename} = "";
	
	# Build the Preview
	#my $pixbuf = $self->load_image($self->{filename}, $scale_factor);
	$scrolled_window->add_with_viewport($image);
	
	return ;
}

sub load_image {
	my ($self, $file, $scale_factor) = @_;
	my $pixbuf = Gtk3::Gdk::Pixbuf->new_from_file($file);
	my $width = $pixbuf->get_width();
	my $height = $pixbuf->get_height();
	my $scale_width = $width * $scale_factor;
	my $scale_height = $height * $scale_factor;
	my $scaled = $pixbuf->scale_simple($scale_width,$scale_height,'hyper');
	my $image = $self->{image};
	$image->set_from_pixbuf($pixbuf);
	return $scaled;
}

sub zoom_in {
	my $self = shift;
	$self->{scale_factor} = $self->{scale_factor} + 0.1;
	my $pixbuf = $self->load_image($self->{filename}, $self->{scale_factor});
	$self->{image}->set_from_pixbuf($pixbuf);
	return $self->{scale_factor};
}

sub zoom_out {
	my $self = shift;
	$self->{scale_factor} = $self->{scale_factor} - 0.1;
	my $pixbuf = $self->load_image($self->{filename}, $self->{scale_factor});
	$self->{image}->set_from_pixbuf($pixbuf);
	return $self->{scale_factor}
}

sub render_preview {
	my ($self, $filename) = @_;
	my $page = $self->page();
	$filename =~ s/\.abc$//;
	$filename =~ s/\d{3}$//;
	if ($page < 10) {
		$filename = $filename . "00" . $page . ".svg";
	}
	elsif ($page < 100) {
		$filename = $filename . "0" . $page . ".svg";
	}
	else {
		$filename = $filename . $page . ".svg";
	}
	$self->{filename} = $filename;
	$self->load_image($filename, $self->{scale_factor});
}

sub page {
	my ($self, $new_page) = @_;
	
	
	my $old_page = $self->{page};
	
	$self->{page} = $new_page if (defined $new_page);
	
	return $old_page;
}

sub next_page {
	my ($self) = @_;
	
	my $old_page = $self->page();
	return $self->page($old_page+1) unless ($old_page >= $self->number_of_pages());
	
}

sub previous_page {
	my ($self) = @_;
	
	my $old_page = $self->page();
	return $self->page($old_page-1) unless ($old_page <= 1);
	
}

sub number_of_pages {
	my ($self, $new_number_of_pages) = @_;	
	
	my $old_number_of_pages = $self->{number_of_pages};
	
	$self->{number_of_pages} = $new_number_of_pages if (defined $new_number_of_pages);
	
	return $old_number_of_pages;
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
