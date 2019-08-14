package Caecilia::Preview;

use 5.006000;
use strict;
use warnings;

require Exporter;

use utf8;
#use File::ShareDir 'dist_dir';
use Image::LibRSVG;
use Image::Info qw(image_info dim);

our @ISA = qw(Exporter Tcl::Tk::Widget);

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

sub new {
    my ($class, $parent, %config) = @_;
    
    my $obj = {};
    bless $obj;
    
    $obj->page('1');
    $obj->number_of_pages(0);
    $obj->build_preview_object($parent);
     
    return $obj;
}

sub build_preview_object {
    my ($self, $f) = @_;
    
    my $canvas = $f->tkpCanvas(-bg => 'white');
    
    my $xs = $f->ttkScrollbar(-orient => 'horizontal', -command => [$canvas, 'xview'])
        ->pack(-side => "bottom",-fill => 'x');
    $canvas->configure(-xscrollcommand => [$xs, 'set']);
    
    my $s = $f->ttkScrollbar(-orient => 'vertical', -command => [$canvas, 'yview'])
        ->pack(-side => 'right',-fill => 'y');
    $canvas->configure(-yscrollcommand => [$s, 'set']);
    
    
    $canvas->pack(-side => "right", -fill => "both", -expand => 1);
    
    my $w = $canvas->cget('-width');
    my $h = $canvas->cget('-height');
    my $ih = $w*0.75;
    my $y = $h/2;
    #my $r = $w / $h;
    #$self->{h}=$h; $self->{w}=$w,$self->{r}=$r;
    $canvas->Photo('logo', -file => "$main::share/caecilia-logo.png");
    my $logo = $canvas->createPimage(0,$y,-image => 'logo',-width => $w,-height => $ih);
    
    $self->{canvas} = $canvas;
    $self->{logo} = $logo;
    $self->{frame} = $f;
    
    $canvas->bind('<Configure>' => [\&resize, Tcl::Ev('%h','%w'), $self, $h]);
    $canvas->bind("<MouseWheel>" => [\&on_mousewheel, Tcl::Ev('%D'),$canvas]);
    $canvas->bind("<Button-4>" => sub {$canvas->interp->call('event',"generate", $canvas,"<MouseWheel>", -delta => 120);});
    $canvas->bind("<Button-5>" => sub {$canvas->interp->call('event','generate',$canvas,"<MouseWheel>", -delta => -120);});
    $canvas->bind("<Button>" => [\&on_hor_scroll, Tcl::Ev('%b'), $canvas]);
    #$canvas->bind('<Configure>' => [\&size, Tcl::Ev('%h','%w'), $self]);
    $canvas->configure(-scrollregion => "0 0 $w $h");
    
}

sub on_hor_scroll {
	my ($num, $canvas) = @_;
	if ($num == 6) {
		$canvas->xview('scroll', -5, 'units');
	}
	elsif ($num == 7) {
		$canvas->xview('scroll', 5, 'units');
	}
}

sub on_mousewheel {
	my ($delta,$canvas,$delta2) = @_;
	my $numbers = -1*$delta/120;
	$canvas->yview('scroll',$numbers,'units');
}

sub resize {
    my ($h, $w, $self, $old_h) = @_;
    my $canvas = $self->{canvas};
    my $logo = $self->{logo};
    
    $canvas->itemconfigure($logo, -width => $w, -height => $w*0.75);
    
    if ($canvas->itemcget($logo,-state) eq "hidden") {
        $canvas->configure(-scrollregion => [$canvas->bbox("all")]);
    }
    else {
        $canvas->configure(-scrollregion => "0 0 $w $h");
    }
}

sub load_tune {
    my ($self,$file,$scale_factor,$no_parse) = @_;
    
    my $canvas = $self->{canvas};
    
    # Clear canvas
    $self->clear_canvas();
    
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
    my $rsvg = Image::LibRSVG->new();
    $rsvg->convertAtSize($file, "$file.png", $w,$h) or die "Could not convert svg: $!\n";
    
    my $tune = $canvas->Photo('tune', -file => "$file.png");
    my $t = $canvas->createPimage(0,0,-image => 'tune',-anchor => 'nw', -tags => ['tune']);
    
    
    my @notes = parse_abc("$file");
    foreach my $note (@notes) { 
        my $col = $note->{col};
        my $row = $note->{row};
        my $editor = $main::editor->{editor};
        my $n = $canvas->create('prect',$note->{'x'}, $note->{'y'}, $note->{'x'} + $note->{'width'}, $note->{'y'} +$note->{'height'}, 
        	-fill => $main::style->lookup('.','-selectbackground'), -fillopacity => 0,
        	-stroke => $main::style->lookup('.','-selectbackground'), -strokeopacity => 0,
        	-tags => ['notes']);
        
        # The method CanvasBind is defined in Caecilia::MyTk in the package
        # Tcl::Tk::Widget::tkpCanvas
        $canvas->CanvasBind($n, "<Enter>" => sub {
        	$canvas->itemconfigure($n, -fillopacity => 0.5, -strokeopacity => 0.5)
        	});
        $canvas->CanvasBind($n, "<Leave>" => sub {
        	$canvas->itemconfigure($n, -fillopacity => 0, -strokeopacity => 0)
        	});
        # Click and jump in the editor to the note
        $canvas->CanvasBind($n, "<Button-1>" => sub {jump_to_note($editor,$row,$col);});
    }
    $canvas->configure(-scrollregion => [$canvas->bbox("all")]);
}

sub jump_to_note {
	my ($editor,$row,$col) = @_;
	$editor->markSet("insert","$row.$col");
	$editor->focus;
	$editor->see('insert');
	my $line = $editor->get("$row.$col","$row.end");
	my $end;
	if ($line =~ m/^\[/) {
		$line =~ m/\[.+?\][0-9\/]*/gc;
		$end = pos($line) + $col;
	}
	else {
		$line =~ m/[_=^]*[abcdefgxzABCDEFGXZ][,'-]*[0-9\/]*/gc;
		$end = pos($line) + $col;
	}
	$editor->tagRemove("sel","1.0","end");
	$editor->tagAdd("sel", "$row.$col", "$row.$end"); 
	$editor->interp->Eval("event generate $editor <<ReHighlight>>");
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
    my $logo = $self->{logo};
    my $canvas = $self->{canvas};
    my $state = $canvas->itemcget($logo,-state);
    $canvas->itemconfigure($logo,-state => "normal") if ($state eq "hidden");    
}

sub hide_logo {
    my ($self) = @_;
    my $logo = $self->{logo};
    my $canvas = $self->{canvas};
    $canvas->itemconfigure($logo,-state => "hidden");
}

sub clear_canvas {
    my ($self) = @_;
    my $canvas = $self->{canvas};
    $canvas->delete('tune','notes');
}

sub size {
    my ($h, $w, $self) = @_;
    my $canvas = $self->{canvas};
    my $wscale = $w/$self->{w};
    my $hscale = $h/$self->{h};
    $self->{h} = $h; $self->{w} = $w;
    my $logo = $self->{logo};
    # resize canvas
    #$canvas->configure(-width => $w, -height => $h);
    # rescale all objects
    if ( $self->{w} / $self->{h} > $self->{r} ) {
        #$canvas->scale('all',0,0,$hscale,$hscale);
        my $iw = $canvas->itemcget($logo, -width);
        my $ih = $canvas->itemcget($logo, -height);
        $canvas->itemconfigure($logo, -width => $iw * $hscale, -height => $ih*$hscale);
    }
    elsif ( $self->{w} / $self->{h} < $self->{r} ) {
        #$canvas->scale('all',0,0,$wscale,$wscale);
        my $iw = $canvas->itemcget($logo, -width);
        my $ih = $canvas->itemcget($logo, -height);
        $canvas->itemconfigure($logo, -width => $iw * $wscale, -height => $ih*$wscale);
    }
    elsif ( $self->{w} / $self->{h} == $self->{r} ) {
        #$canvas->scale('all',0,0,$hscale,$wscale);
        my $iw = $canvas->itemcget($logo, -width);
        my $ih = $canvas->itemcget($logo, -height);
        $canvas->itemconfigure($logo, -width => $iw * $wscale, -height => $ih*$hscale);
    }
    #$canvas->configure(-scrollregion => [$canvas->bbox("all")]);
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



# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

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

Maximilian Lika, E<lt>maximilian@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.26.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
