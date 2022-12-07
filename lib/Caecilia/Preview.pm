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
		notes => [],
		};
	
	bless($obj,$class);
	$obj->init_preview($app,$box);
	return $obj;
}

sub init_preview {
	my ($self,$app,$box) = @_;
	
	my $scroller = pEFL::Elm::Scroller->add($box);
	
	my $viewer = pEFL::Elm::Image->add($scroller);
	my $path = $app->share_dir . "/caecilia-logo.png";
	$viewer->file_set($path,"");
	$self->elm_viewer($viewer);
	$scroller->content_set($viewer);
	$scroller->smart_callback_add("scroll",\&move_notes, $self);
	$scroller->smart_callback_add("size,changed",\&move_notes, $self);
	
	$self->elm_scroller($scroller);
	$box->part_content_set("right",$scroller);
	$scroller->show();
}

sub move_notes {
	my ($self,$scroller,$ev) = @_;
	
	my @notes = @{$self->{notes}};
	
	my ($vx,$vy,$vw,$vh) = $self->elm_viewer->geometry_get();
	my ($sx,$sy,$sh) = $self->elm_scroller->geometry_get();
	foreach my $note (@notes) { 
		my $x = $note->{x} + $vx;
		my $y = $note->{y} + $vy;
		my $n = $note->{evas_object};
		if ($x<$sx || $y < $sy) {
			$n->hide();
		}
		else {
			$n->show();	
			$n->move($note->{x}+$vx, $note->{y}+$vy);
		}	
	}
}

sub load_tune {
	my ($self,$file,$scale_factor,$no_parse) = @_;
	
	# Clear viewer
	$self->clear_viewer();
	
	my $viewer = $self->elm_viewer();
	my $canvas = $self->elm_scroller->evas_get();
	
	# Creating tune and notes
	# estimate dimensions of the svg
	my $info = image_info("$file");
	my ($w,$h) = dim($info);
	$w =~ s/px$//;$h =~ s/px$//;
	# In older versions of abcm2ps the dimensions are 
	# in inch
	if ($w =~ s/in$//) {
		$w = $w *96;
	}
	if ($h =~ s/in$//) {
		$h = $h * 96;
	 }
	
	# create image
	$viewer->file_set(undef,"");
	$viewer->size_hint_min_set($w,$h);
	$viewer->file_set($file,"");
	
	my ($vx,$vy,$vw,$vh) = $viewer->geometry_get();
	
	my @notes = parse_abc("$file");
	foreach my $note (@notes) { 
		my $col = $note->{col};
		# We added %%beginsvg bg white to preview.abc
		# and line starts at 0
		my $row = $note->{row}-2;
		my $n = pEFL::Evas::Rectangle->new($canvas);
		$n->move($note->{x}+$vx, $note->{y}+$vy);
		$n->resize($note->{width},$note->{height});
		$n->color_set(24,68,91,0);
		$n->show();
		
		$n->event_callback_add(EVAS_CALLBACK_MOUSE_IN, sub {$_[0]->color_set(24,68,91,150)}, $n);
		$n->event_callback_add(EVAS_CALLBACK_MOUSE_OUT, sub {$_[0]->color_set(24,68,91,0)}, $n);
		
		# Dirty Workaround: On wheel event we hide, so that the scroller can retrieve the wheel event
		$n->event_callback_add(EVAS_CALLBACK_MOUSE_WHEEL, sub {$_[0]->hide()}, $n);
		
		$n->event_callback_add(EVAS_CALLBACK_MOUSE_DOWN, sub {jump_to_note($self->app->entry->elm_entry, $row,$col);}, undef);
		$note->{evas_object} = $n;
		
		
		push @{$self->{notes}},$note;
	}
}

sub jump_to_note {
	my ($en,$row,$col) = @_;
	
	my $textblock = $en->textblock_get();
	my $cp1 = pEFL::Evas::TextblockCursor->new($textblock);
	$cp1->pos_set(0);
	my $i;
	for ($i=0;$i<$row;$i++) {
		$cp1->paragraph_next();
	}
	my $lpos = $cp1->pos_get();
	$cp1->pos_set($lpos + $col);
	my $cp2 = pEFL::Evas::TextblockCursor->new($textblock);
	$cp2->pos_set($lpos);
	$cp2->paragraph_char_last();
	
	my $line = $textblock->range_text_get($cp1,$cp2,EVAS_TEXTBLOCK_TEXT_PLAIN);
	$line = Encode::decode("UTF-8",$line);
	
	my $end;
	if ($line =~ m/^\[/) {
		$line =~ m/\[.+?\][0-9\/]*/gc;
		$end = pos($line) + $col;
	}
	else {
		$line =~ m/[_=^]*[abcdefgxzABCDEFGXZ][,'-]*[0-9\/]*/gc;
		$end = pos($line) + $col;
	}
	$cp2->paragraph_char_first();
	$cp2->pos_set($cp2->pos_get() + $end);
	my $start = $cp1->pos_get();
	my $e = $cp2->pos_get();
	print "START $start END $e\n";
	$en->cursor_pos_set($start);
	$en->select_region_set($start,$e);
	#$en->cursor_pos_set($start);
	
	$cp1->free();
	$cp2->free();
}

sub parse_abc {
	my ($file) = @_;
	my @notes;
	open my $fh, "<", $file;
	while (my $line = <$fh>) {
		if ($line =~ m!<abc type="[NR]".* row="(.*)" col="(.*)" x="(.*)" y="(.*)" width="(.*)" height="(.*)"/>!) {
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

sub show_logo {
	my ($self) = @_;
	
	$self->clear_viewer();
	
	my $app = $self->app();
	my $viewer = $self->elm_viewer();
	my $path = $app->share_dir . "/caecilia-logo.png";
	$viewer->file_set($path,"");
}

sub clear_notes {
	my ($self) = @_;
	
	my @notes = @{$self->{notes}};
	
	foreach my $note (@notes) { 
		my $n = $note->{evas_object};
		$n->del();
	}
	
	undef($self->{notes});
}

sub clear_viewer {
	my ($self) = @_;
	
	$self->clear_notes();
		
	my $viewer = $self->elm_viewer();
	$viewer->file_set(undef,"");
}

sub render_preview {
	my ($self, $filename) = @_;
	my $page = $self->page();
	my $number_of_pages = $self->number_of_pages;
	$page = $number_of_pages if ($page > $number_of_pages);
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
	if (-e $filename) {
		$self->{filename} = $filename;
		$self->load_tune($filename, 1);#scale_factor not used at moment
	}
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

######################
# Accessors 
#######################

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|elm_viewer|elm_scroller|page|number_of_pages|/;
	
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