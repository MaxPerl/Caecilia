package Caecilia::Editor;

use 5.006000;
use strict;
use warnings;

require Exporter;

use utf8;

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

sub new {
    my ($class, $f) = @_;
    
    my $obj = {};
    bless $obj;
    
    my $editor = $f->ctext(-wrap => 'word', 
        -bg => 'white',
        -relief => 'flat',
        -linemap => 1,
        -borderwidth => 0,
        -linemapfg => "black",  
        #-linemap_select_fg => "black",
        -linemap_select_bg => $main::style->lookup('.','-selectbackground'),
        -linemap_select_fg => $main::style->lookup('.','-selectforeground'),
        -font => "Helvetica 11 normal",
        -selectforeground =>'white');
    
    my $linemap = $f->Canvas(
    	-width => 40,
    	-highlightthickness => 0,
    	-background => 'white'
    );
    
    my $s = $f->ttkScrollbar(-orient => 'vertical', -command => [$editor, 'yview'])
        ->pack(-side => 'right',-fill => 'y');
    $editor->configure(-yscrollcommand => [$s, 'set']);
    #$linemap->pack(-side => 'left', -fill => 'y');
    $editor->pack(-expand => 1, -fill => 'both');
    
    #$f->interp->Eval("trace add execution $editor leave [list ctextAdvanced::traceCallback $editor $linemap]");
    #$f->interp->Eval("bind $editor <Configure> [list ctextAdvanced::traceCallback $editor $linemap]");
    
    $obj->{frame}= $f;
    $obj->{editor} = $editor;
    
    # Add Syntax Highlighting
    $obj->setup_highlight();
    
    # Disable highlight with sel
    #$editor->bind("<<Selection>>" => sub {test_sel($obj)}); 
    
    # Prevent making the "notes" temporary blue
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor remark_prevent black {\\[r\:.+}");
    
    # Popup Menu
    my $popup = $obj->popup_menu();
    if ($editor->interp->Eval('tk windowingsystem') eq "aqua") {
        $editor->bind("<2>", [sub {my($x,$y) = @_; $popup->interp->call("tk_popup",$popup,$x,$y)}, Tcl::Ev("%X", "%Y")]);
        $editor->bind("<Control-1>", [sub {my($x,$y) = @_; $popup->interp->call("tk_popup",$popup,$x,$y)}, Tcl::Ev("%X", "%Y")]);
    }
    else
    {
        $editor->bind("<3>", [sub {my($x,$y) = @_; $popup->interp->call("tk_popup",$popup,$x,$y)}, Tcl::Ev("%X", "%Y")]);
    }

    return $obj;
}

sub setup_highlight {
    my ($self) =@_;
    my $editor = $self->{editor};
    # Add Syntax Highlighting
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor note #2badfb {[_=^]?[abcdefgxzABCDEFG][0-9,']*}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor lyrics grey {^[wW]:.+}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor inlineheader {-foreground black -font \"Helvetica 11 bold\"} {\\[[a-zA-Z]:.*?\\]}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor header {-foreground black -font \"Helvetica 11 bold\"} {^[a-zA-Z]:.*}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor remark {-foreground black -font \"Helvetica 11 bold\"} {\\[r:.*\\]}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor layout #fb99cb {%%.+}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor comment #fb99cb {%.*}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor string grey {\".*?\"}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor keyword_prevent #cb319b {![a-z]+}");
    $editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor keywords {-foreground #cb319b -font \"Helvetica 11 bold\"} {![a-z]+!}");
    $editor->highlight('1.0', 'end');
}

sub tk {
	my ($self) = shift;
	return $self->{editor};
}
sub highlight {
    my ($self) = @_;
    my $editor = $self->{editor};
    $editor->configure(-highlight => 1);
    my $text = $self->get_text();
    $self->set_text($text);
}

sub clear_highlight {
    my ($self) = @_;
    my $editor = $self->{editor};
    $editor->configure(-highlight => 0);
    my $text = $self->get_text();
    $self->set_text($text);
} 

sub test_sel {
    my ($self) = @_;
    my $editor = $self->{editor};
    if ($editor->tagRanges('sel')) {
        $self->clear_highlight();
        #$editor->tagConfigure("bold black",-foreground => 'white');
    }
    else {
        #$self->highlight();
        $editor->tagConfigure("bold black",-foreground => 'black');
        $editor->configure(-foreground => 'white');
    }
}


sub popup_menu {
    my ($self) = @_;
    my $editor = $self->{editor};
    my $popup = $editor->Menu(-relief => 'flat',-cursor => 'left_ptr');
    $popup->addCommand(-label => "Cut       ",-command => sub {$editor->cut}, -accelerator => "Ctrl+X");
    $popup->addCommand(-label => "Copy      ",-command => sub {$editor->copy}, -accelerator => "Ctrl+C");
    $popup->addCommand(-label => "Paste     ",-command => sub {$editor->paste},-accelerator => "Ctrl+V");
    $popup->addCommand(-label => "Select all        ",-command => sub {$editor->tagAdd('sel','1.0','end')},-accelerator => "Ctrl+/");
    
    return $popup;
}


sub get_text {
    my ($self) = @_;
    
    my $editor = $self->{editor};
    my $text = $editor->get('1.0','end');
    return $text;
}

sub set_text {
    my ($self, $text) = @_;
    $text =~ s/\r\n/\n/g;
    my $editor = $self->{editor};
    $editor->delete('1.0', 'end');
    $editor->insert('1.0', $text);
    $editor->highlight('1.0', 'end');
    # TK always (!) adds a new line at the end
    $editor->delete('end-1c', 'end') if ($editor->get('end-1c', 'end') eq "\n");
}

sub modified {
	my ($self, $new_status) = @_;	
	
	my $txt = $self->{editor};
	my $old_status = $txt->edit('modified');
	
	$txt->edit('modified',$new_status) if (defined $new_status);
	
	return $old_status;
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
