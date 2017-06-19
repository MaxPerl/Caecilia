package Caecilia::Preview;

use 5.006000;
use strict;
use warnings;

use utf8;
use Gtk3;
use Glib('TRUE','FALSE');
use GooCanvas2;
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
	
	my $canvas = GooCanvas2::Canvas->new();
	$canvas->set('automatic-bounds' => TRUE);
	
	# Save the scrolled window
	$self->{canvas} = $canvas;
	$self->{view} = $scrolled_window;
	$self->{scale_factor} = 1.2;
	
	# Show the Logo at the beginning; oh how nice ;-)
	my $sharedir = dist_dir('Caecilia');	
	$self->{filename} = "$sharedir/caecilia-logo.png";
	
	# Build the Preview
	$self->load_image($self->{filename}, 0.5, 'no_parse');
	$scrolled_window->add_with_viewport($canvas);
	
	return ;
}

sub load_image {
	my ($self, $file, $scale_factor, $no_parse) = @_;
	
	my $canvas = $self->{canvas};
	my $root = $canvas->get_root_item();
	
	# First cleanup Canvas
	my $n_children = $root->get_n_children();
	for (my $i = 0; $i < $n_children; $i++) {
		$root->remove_child(0);
	} 
	
	# First render the svg
	my ($width, $height) = Gtk3::Gdk::Pixbuf::get_file_info($file);
	my $image = Gtk3::Gdk::Pixbuf->new_from_file($file);
	my $image_item = GooCanvas2::CanvasImage->new('parent' => $root,
					'pixbuf' => $image,
					'x' => 0,
					'y' => 0);
	$image_item->scale($scale_factor, $scale_factor);
					
	# Now render the ABC links and link it to the Editor (TODO)
	my $editor = $self->{editor};
	 
	unless ($no_parse) {
		my @notes = parse_abc($file);
		foreach my $note (@notes) {
		# Add a few simple items
		my $rect_item = GooCanvas2::CanvasRect->new('parent' => $root,
						'x' => $note->{'x'},
						'y' => $note->{'y'},
						'width' => $note->{'width'},
						'height' => $note->{'height'},
						'fill-color' => 'rgba(43,173,251,0)',
						'stroke-color' => 'transparent');
		$rect_item->scale($scale_factor, $scale_factor);
		$rect_item->signal_connect('button_press_event' => sub {$editor->jump_to($note->{row}, $note->{col});});
		$rect_item->signal_connect('enter_notify_event' => \&on_rect_enter);
		$rect_item->signal_connect('leave_notify_event' => \&on_rect_leave);
		}
	}	
	$canvas->update();
	return $image;
}

sub zoom_in {
	my $self = shift;
	$self->{scale_factor} = $self->{scale_factor} + 0.1;
	$self->load_image($self->{filename}, $self->{scale_factor});
	return $self->{scale_factor};
}

sub zoom_out {
	my $self = shift;
	$self->{scale_factor} = $self->{scale_factor} - 0.1;
	$self->load_image($self->{filename}, $self->{scale_factor});
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

# Parse ABC
sub parse_abc {
	my ($file) = @_;
	my @notes;
	open my $fh, "<", $file;
	while (my $line = <$fh>) {
		if ($line =~ m!<abc .* row="(.*)" col="(.*)" x="(.*)" y="(.*)" width="(.*)" height="(.*)"/>!) {
			my %note = (
					'row' => $1,
					'col' => $2,
					'x' => $3,
					'y' => $4,
					'width' => $5,
					'height' => $6
					);
			push @notes, \%note;
		}
	}
	close $fh;
	return @notes;
}

# Click to a note feature

sub on_rect_enter {
	my $item = shift;
	$item->set('fill-color' => 'rgba(43,173,251,0.5)');
	return 1;
}

sub on_rect_leave {
	my $item = shift;
	$item->set('fill-color' => 'rgba(43,173,251,0)');
	return 1;
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
