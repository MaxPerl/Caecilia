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

our @classes = (
	{name => "note", pattern => '\[*[_=^]*[abcdefgxzABCDEFGXZ][,\']*\]*[0-9\/]*'},
	{name => "slur", pattern => '[\(\)\-]'},
	{name => "lyrics", pattern => "^[wW]:.+"},
	{name => "keywords", pattern => '![\S]+?!'},
	{name => "inlineheader", pattern => "\[[a-vx-zA-VX-Z]:.*?\]"},
	{name => "header", pattern => "^[a-vx-zA-VX-Z]:.*"},
	{name => "remark", pattern => '\[r:.*\]'},
	{name => "string", pattern => "\".*?\""},
	{name => "layout", pattern => "%%.+"},
	{name => "comment", pattern => "%.*"},
);

sub new {
    my ($class, $f) = @_;
    
    my $obj = {};
    bless $obj;
    
    my $editor = $f->Text(-wrap => 'word', 
        -bg => 'white',
        -relief => 'flat',
        #-linemap => 1,
        -borderwidth => 0,
        #-linemapfg => "black",  
        #-linemap_select_fg => "black",
        #-linemap_select_bg => $main::style->lookup('.','-selectbackground'),
        #-linemap_select_fg => $main::style->lookup('.','-selectforeground'),
        -font => "Helvetica 11 normal",
        -exportselection => 1,
        #-selectforeground =>'white'
        );
   
    
    my $linemap = $f->Canvas(
    	-width => 40,
    	-highlightthickness => 0,
    );
    
    my $s = $f->ttkScrollbar(-orient => 'vertical', -command => [$editor, 'yview'])
        ->pack(-side => 'right',-fill => 'y');
    $editor->configure(-yscrollcommand => [$s, 'set']);
    $linemap->pack(-side => 'left', -fill => 'y');
    $editor->pack(-expand => 1, -fill => 'both');
    
    # Syntax Highlighting Bindings
    $obj->setup_highlight($editor);
    $editor->bind('<<ReHighlight>>' => sub {$editor->update('idletasks'); $obj->forAllMatches($editor,\@classes);});
    $editor->bind("<KeyRelease>" => sub {$editor->interp->Eval("event generate $editor <<ReHighlight>>");});
    $editor->bind("<MouseWheel>" => [\&on_mousewheel, Tcl::Ev('%D'),$editor]);
	$editor->bind("<ButtonRelease-4>" => sub {$editor->interp->Eval("event generate $editor <MouseWheel> -delta 120 -when now");});
	$editor->bind("<ButtonRelease-5>" => sub {$editor->interp->Eval("event generate $editor <MouseWheel> -delta -120 -when now");});
	$s->bind("<ButtonRelease>"=> sub {$editor->interp->Eval("event generate $editor <<ReHighlight>>");});
    
    # Linemap Bindings
    $linemap->interp->call("trace", "add", "execution", $editor, "leave", [sub {my @args = @_; traceCallback($editor, $linemap, "Helvetica 10 normal",\@args)}]);
	$editor->bind("<Configure>" => sub {my @args = @_; traceCallback($editor, $linemap, "Helvetica 10 normal",\@args)});
    
    $obj->{frame}= $f;
    $obj->{editor} = $editor;
    $obj->{linemaptk} = $linemap;
    
    # Prevent making the "notes" temporary blue
    #$editor->interp->Eval("::ctextAdvanced::addHighlightClassForRegexp $editor remark_prevent black {\\[r\:.+}");
   
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
    my ($self,$editor) =@_;
    $editor->tagConfigure("note", -foreground => "#2badfb");
    $editor->tagConfigure("slur", -foreground => "#2badfb",-font => "Helvetica 10 bold");
    $editor->tagConfigure("lyrics", -foreground => "grey", -font => "Helvetica 10 italic");
    $editor->tagConfigure("string", -foreground => "grey", -font => "Helvetica 10 normal");
    $editor->tagConfigure("keywords", -foreground => "#cb319b", -font => "Helvetica 10 bold");
    $editor->tagConfigure("keywords_prevent", -foreground => "#cb319b", -font => "Helvetica 10 bold");
    $editor->tagConfigure("inlineheader", -foreground => "black", -font => "Helvetica 10 bold");
    $editor->tagConfigure("header", -foreground => "black", -font => "Helvetica 10 bold");
    $editor->tagConfigure("remark", -foreground => "black", -font => "Helvetica 10 bold");
    $editor->tagConfigure("layout", -foreground => "#fb99cb");
    $editor->tagConfigure("comment", -foreground => "#fb99cb");
    $editor->tagConfigure("sel", -foreground => "white");
    $editor->tagRaise("sel");
    $self->{highlight} = 1;
}

sub tk {
	my ($self) = shift;
	return $self->{editor};
}
sub highlight {
    my ($self, $value) = @_;
    my $old_value = $self->{highlight};
    $self->{highlight} = $value if (defined($value));
    my $tk = $self->tk();
    if (defined($value) && $value == 0) {
    	foreach my $class (@classes) {
    		my $name = $class->{name};
    		$tk->tagRemove("$name","1.0","end");
    	}
    }
    $tk->interp->Eval("event generate $tk <<ReHighlight>>") if (defined($value));
    return $old_value;
}

sub linemap {
    my ($self, $value) = @_;
    my $old_value = $self->{linemap};
    $self->{linemap} = $value if (defined($value));
    my $editor = $self->tk();
    my $linemap = $self->{linemaptk};
    if (defined($value) && $value == 0) {
    	$linemap->packForget();
    }
    elsif (defined($value) && $value == 1) {
    	$editor->packForget();
    	$linemap->pack(-side => 'left', -fill => 'y');
    	$editor->pack(-expand => 1, -fill => 'both');
    }
    return $old_value;
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
    $popup->addCommand(-label => "Cut       ",-command => sub {$editor->interp->Eval("event generate $editor <<Cut>>");}, -accelerator => "Ctrl+X");
    $popup->addCommand(-label => "Copy      ",-command => sub {$editor->interp->Eval("event generate $editor <<Copy>>");}, -accelerator => "Ctrl+C");
    $popup->addCommand(-label => "Paste     ",-command => sub {$editor->interp->Eval("event generate $editor <<Paste>>");},-accelerator => "Ctrl+V");
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
    #$editor->highlight('1.0', 'end');
    # TK always (!) adds a new line at the end
    $editor->delete('end-1c', 'end') if ($editor->get('end-1c', 'end') eq "\n");
    $editor->interp->Eval("event generate $editor <<ReHighlight>>");
}

sub modified {
	my ($self, $new_status) = @_;	
	
	my $txt = $self->{editor};
	my $old_status = $txt->edit('modified');
	
	$txt->edit('modified',$new_status) if (defined $new_status);
	
	return $old_status;
}

sub forAllMatches {
	my ($self, $editor, $classes, $all) = @_;
	
	# First check modify status and print a * in title if the abc file was modified
	my $title=$main::mw->title();
	$main::mw->title($title . ' *') if ($editor->edit('modified') && $title !~/\*$/);
	
	# Syntax Highlighting Support
	return unless ($self->highlight());
	my $start; my $end;
	my $index = $editor->index('end');
	my ($i) = $index =~/(\d+).\d+/;
	if ($all) {
		
		$start = 1;
		$end = $i;
	}
	else {
		my $frac = $editor->yview();
		$start = $i*$frac->[0]; $start = sprintf "%.0f",$start; $start = $start-10;
		$end = $i*$frac->[1]; $end = sprintf "%.0f", $end; $end = $end+10;
		if ($start < 1.0) {$start = 1.0}
		if ($end > $i) {$end = $i}
	}
	my $text = $editor->get("$start.0","$end.end");
	
	foreach my $class (@$classes) {
		my $name = $class->{name};
		my $pattern = $class->{pattern};
		$editor->tagRemove("$name","$start.0","$end.end");
		my $i = $start;
		foreach my $line ( split("\n", $text) ) {
			while ($line =~ m/$pattern/gc) {
				my $cend = pos($line);
				my $match = $&;
				my $cbegin = $cend-length($match);
				$editor->tagAdd("$name", "$i.$cbegin", "$i.$cend");
			} 
			$i++;
		} 
	}
}

sub traceCallback {
	my ($text,$canvas,$font,$args) = @_;
	my @args = @$args; 
	my $command = $args[0];
	return unless ($command);
	# only redraw if args are null (meaning we were called by a binding)
    # or called by the trace and the command could potentially change
    # the size of a line.
	unless ($command =~ /tag|mark|bbox|cget|compare|count|debug|dlineinfo|dump|get|index|mark|peer|search/) {
		
		$canvas->interp->Eval(<<"EOS");
		    # Stolen from Tcl/Tk wiki: https://wiki.tcl-lang.org/page/line+numbers+in+text+widget
			# Thanks Bryan Oakley
		    $canvas delete all
		    set i [$text index @0,0]
		    while true {
		        set dline [$text dlineinfo \$i]
		        if {[llength \$dline] == 0} break
		        set height [lindex \$dline 3]
		        set y [lindex \$dline 1]
		        set cy [expr {\$y + int(\$height/2.0)}]
		        set linenum [lindex [split \$i .] 0]
		        set rect [$canvas create rectangle 0 \$y [$canvas cget -width] [expr \$y+\$height] \\
		        	-fill [$canvas cget -background] -outline [$canvas cget -background] ]
		        set item [$canvas create text 0 \$y -anchor nw -width 40 -text \$linenum \\
		        	-fill black -font \"$font\" \\
		        	-tags {numbers} -justify right ]
		        
		        # TODO toggle Linenumber
		        #$canvas bind \$item <ButtonPress-1> \\
		        #	[list ctextAdvanced::toggleLinenumber $text $canvas \$item \$rect \$linenum]
		        #$canvas bind \$rect <ButtonPress-1> \\
		        #	[list ctextAdvanced::toggleLinenumber $text $canvas \$item \$rect \$linenum]
		        set i [$text index "\$i + 1 line"]
		    }

EOS
	}
}

sub on_mousewheel {
	my ($delta,$canvas,$delta2) = @_;
	
	my $numbers = -1*$delta/120;
	my $int = $canvas->interp;
	$canvas->yview('scroll',$numbers,'units');
	#$canvas->interp->Eval("tk busy hold $canvas");
	##$canvas->update();
	$int->Eval("event generate $canvas <<ReHighlight>>");
	#$int->call('after',20, sub {$int->Eval("event generate $editor <KeyRelease>")});
	return"-code break";
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
