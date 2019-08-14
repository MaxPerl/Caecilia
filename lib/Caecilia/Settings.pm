package Caecilia::Settings;

use strict;
no strict 'vars';
use warnings;

################
# The configuration part
#################
# the init function loads the default settings
sub init {
	our $ABCM2PS_PATH = 'abcm2ps';
	our $ABCM2PS_AUTOLINEBREAK = '1';
}

sub get_config {
	if (-e "$ENV{HOME}/.caecilia/config.pl") {
		do "$ENV{HOME}/.caecilia/config.pl";
		return 1;
	}
	else {
		warn "No configuration file found.\nTake default conifguration\n";
		return 0;
	}
}

sub write_config {
	unless (-d "$ENV{HOME}/.caecilia") {
		mkdir "$ENV{HOME}/.caecilia";
	}
	
	open my $fh, ">", "$ENV{HOME}/.caecilia/config.pl" or die "Could not open $ENV{HOME}/.caecilia/config.pl: $!\n";
	# NOTE: We have to put the values in single quotes because of "use strict"!
	# NOTE: $VAR = ; breaks config down
	print $fh "# This is an automatically created configuration file\n";
	print $fh "\$ABCM2PS_PATH = '$Caecilia::Settings::ABCM2PS_PATH'; \n";
	print $fh "\$ABCM2PS_AUTOLINEBREAK = '$Caecilia::Settings::ABCM2PS_AUTOLINEBREAK'; \n";
	print $fh "\$Caecilia::Settings::ABCM2PS_BREAKNBARS = '$Caecilia::Settings::ABCM2PS_BREAKNBARS';\n" if ($Caecilia::Settings::ABCM2PS_BREAKNBARS);
	print $fh "\$Caecilia::Settings::ABCM2PS_SCALEFACTOR = '$Caecilia::Settings::ABCM2PS_SCALEFACTOR';\n" if ($Caecilia::Settings::ABCM2PS_SCALEFACTOR);
	print $fh "\$Caecilia::Settings::ABCM2PS_STAFFWIDTH='$Caecilia::Settings::ABCM2PS_STAFFWIDTH';\n" if ($Caecilia::Settings::ABCM2PS_STAFFWIDTH);
	print $fh "\$Caecilia::Settings::ABCM2PS_LEFTMARGIN ='$Caecilia::Settings::ABCM2PS_LEFTMARGIN';\n" if ($Caecilia::Settings::ABCM2PS_LEFTMARGIN);
	print $fh "\$Caecilia::Settings::ABCM2PS_STAFFSEPARATION ='$Caecilia::Settings::ABCM2PS_STAFFSEPARATION';\n" if ($Caecilia::Settings::ABCM2PS_STAFFSEPARATION);
	print $fh "\$Caecilia::Settings::ABCM2PS_MAXSHRINK = '$Caecilia::Settings::ABCM2PS_MAXSHRINK';\n" if ($Caecilia::Settings::ABCM2PS_MAXSHRINK);
	print $fh "\$Caecilia::Settings::ABCM2PS_FORMATFILE = '$Caecilia::Settings::ABCM2PS_FORMATFILE';\n" if ($Caecilia::Settings::ABCM2PS_FORMATFILE);
	print $fh "\$Caecilia::Settings::ABCM2PS_FORMATDIRECTORY = '$Caecilia::Settings::ABCM2PS_FORMATDIRECTORY';\n" if ($Caecilia::Settings::ABCM2PS_FORMATDIRECTORY);
	print $fh "\$Caecilia::Settings::ABCM2PS_LANDSCAPE = '$Caecilia::Settings::ABCM2PS_LANDSCAPE';\n" if ($Caecilia::Settings::ABCM2PS_LANDSCAPE);
	print $fh "\$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE ='$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE';\n" if ($Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE);
	print $fh "\$Caecilia::Settings::ABCM2PS_XREFNUMBERS = '$Caecilia::Settings::ABCM2PS_XREFNUMBERS';\n" if ($Caecilia::Settings::ABCM2PS_XREFNUMBERS);
	print $fh "\$Caecilia::Settings::ABCM2PS_NOLYRICS = '$Caecilia::Settings::ABCM2PS_NOLYRICS';\n" if ($Caecilia::Settings::ABCM2PS_NOLYRICS);
	print $fh "\$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE ='$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE';\n" if ($Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE);
	print $fh "\$Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE = '$Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE';\n" if ($Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE);
	print $fh "\$Caecilia::Settings::ABCM2PS_NOSLURINGRACE = '$Caecilia::Settings::ABCM2PS_NOSLURINGRACE';\n" if ($Caecilia::Settings::ABCM2PS_NOSLURINGRACE);
	print $fh "\$Caecilia::Settings::ABCM2PS_NUMBERNBARS = '$Caecilia::Settings::ABCM2PS_NUMBERNBARS';\n" if ($Caecilia::Settings::ABCM2PS_NUMBERNBARS);
	print $fh "\$Caecilia::Settings::ABCM2PS_NUMBERNBARSBOXED = '$Caecilia::Settings::ABCM2PS_NUMBERNBARSBOXED';\n" if ($Caecilia::Settings::ABCM2PS_NUMBERNBARSBOXED);
	print $fh "\$Caecilia::Settings::ABCM2PS_FLATBEAMS = '$Caecilia::Settings::ABCM2PS_FLATBEAMS';\n" if ($Caecilia::Settings::ABCM2PS_FLATBEAMS);
	
	close $fh;
	return 1;
}

####################
# The Settings GUI
####################
sub settings_cb {
	my ($mw) = @_;
	# a Gtk3::Dialog
	my $dialog = $mw->Toplevel();
    $dialog->title('Render Abc Music');
	$dialog->transient("$mw");
	$dialog->geometry('450x450');
	
	
	my $canvas = $dialog->Canvas();
	my $s = $dialog->ttkScrollbar(-orient => 'vertical', -command => [$canvas, 'yview'])
        ->pack(-side => 'right',-fill => 'y');
    $canvas->configure(-yscrollcommand => [$s, 'set']);
	$canvas->pack(-side => "right", -fill => "both", -expand => 1);
	
	####
	# Path 
	####
	
	my $content = $canvas->ttkFrame(-width => 400, -height => 970);
	$canvas->createWindow(0, 0,-anchor, 'nw',-window, $content);
	
	###
	_add_header($content,"Path to abcm2ps");
	my $abcpath_entry = $content->ttkEntry(-textvariable => \$Caecilia::Settings::ABCM2PS_PATH)
        ->pack(-expand=>1,-fill=>"x",-padx => 5,-pady => 5);
	
	#####
	# Line Breaks options
	#####
	_add_header($content, "Line Breaks Options");
	
	_add_checkoption($content, label => "Auto line break", value =>\$Caecilia::Settings::ABCM2PS_AUTOLINEBREAK);
	
	_add_spin_with_check($content, label => "Break every n bars", value => \$Caecilia::Settings::ABCM2PS_BREAKNBARS,  min => 0, max => 100, step => 1, digits => 0);
	
	#####
	# Output formatting
	#####
	_add_header($content, "Output Formatting");
	
	_add_spin_with_check($content, label => "Set Scale Factor", value => \$Caecilia::Settings::ABCM2PS_SCALEFACTOR,  min => 0, max => 100, step => 0.1, digits => 2);
	
	_add_entry_with_check($content, label => "Set Staff width (cm/in/pt)", value => \$Caecilia::Settings::ABCM2PS_STAFFWIDTH);
	
	_add_entry_with_check($content, label => "Set left margin (cm/in/pt)", value => \$Caecilia::Settings::ABCM2PS_LEFTMARGIN);
	
	_add_entry_with_check($content, label => "Set staff separation (cm/in/pt)", value => \$Caecilia::Settings::ABCM2PS_STAFFSEPARATION);
	
	_add_spin_with_check($content, label => "Set maximal shrinkage to", value => \$Caecilia::Settings::ABCM2PS_MAXSHRINK,  min => 0, max => 1, step => 0.1, digits => 2);
	
	_add_entry_with_check($content, label => "Read format file \"foo.fmt\"", value => \$Caecilia::Settings::ABCM2PS_FORMATFILE);
	
	_add_entry_with_check($content, label => "Read format file \"foo.fmt\"", value => \$Caecilia::Settings::ABCM2PS_FORMATDIRECTORY);
	
	#####
	# Output Options
	#####
	_add_header($content, "Output Options");
	_add_checkoption($content, label => "landscape mode", value =>\$Caecilia::Settings::ABCM2PS_LANDSCAPE);
	_add_entry_with_check($content, label => "indent first line (cm/in/pt)", value => \$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE);
	_add_checkoption($content, label => "Add xref numbers in titles", value => \$Caecilia::Settings::ABCM2PS_XREFNUMBERS);
	_add_checkoption($content, label => "Don't output lyrics", value =>\$Caecilia::Settings::ABCM2PS_NOLYRICS);
	
	# PAGE NUMBERING OPTIONS
	my @pagenumberingmodes = ('off', 'left','right','even left, odd right','even right, odd left');
	my $f1 = $content->ttkFrame()->pack(-expand => 1, -fill => 'both', -padx => 5,-pady => 5);
	my $pagenr_combo = $f1->ttkCombobox(-textvariable => \$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE,
        -values => \@pagenumberingmodes, -state => 'disabled');
    my $check = 0;
    my $pagenr_checkbutton = $f1->ttkCheckbutton(
        -text => "Set the pagenumbering mode", -variable => \$check, -onvalue => 1, -offvalue => 0,
        -width => 30, 
        -command => sub {toggle_combo($pagenr_combo,\$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE)})
        ->pack(-side => 'left');
    $pagenr_combo->pack(-side => 'left', -expand => 1, -fill => 'x');
    
    if ($Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE) {
		$check = 1;
		$pagenr_combo->configure(-state => 'readonly');
		
		# No toplevel mousescroll events on Combobox
		my $class = $pagenr_combo->class();
		$pagenr_combo->interp->Eval("bindtags $pagenr_combo [list $pagenr_combo $class all]");
	}
	else {
		my $toplevel = $pagenr_combo->toplevel();
		$pagenr_combo->interp->Eval("bindtags $pagenr_combo [list $pagenr_combo $toplevel all]");
	}
	
	_add_checkoption($content, label => "Write one tune per page", value =>\$Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE);
	_add_checkoption($content, label => "no slur in grace notes", value =>\$Caecilia::Settings::ABCM2PS_NOSLURINGRACE);
	
	# This is a little bit complicated because numbernbars_check toggles
	# both $numbersnbars_spin and $barnumbers
	my ($numbernbars_check, $numbernbars_spin) =_add_spin_with_check($content, 
		label => "Number the measures every n bars", 
		value => \$Caecilia::Settings::ABCM2PS_NUMBERNBARS,  
		min => 0, max => 100, step => 1, digits => 0);
	my $barnumbers = _add_checkoption($content, 
		label => "Display measure numbers in a box", 
		value => \$Caecilia::Settings::ABCM2PS_NUMBERNBARSBOXED);
	$barnumbers->configure(-state=>'disabled');
	$numbernbars_check->configure(-command => sub {
        		toggle($numbernbars_spin,\$Caecilia::Settings::ABCM2PS_NUMBERNBARS);
        		toggle($barnumbers,\$Caecilia::Settings::ABCM2PS_NUMBERNBARSBOXED);
       		}
    );
    if ($Caecilia::Settings::ABCM2PS_NUMBERNBARS) {
		$barnumbers->configure(-state => 'normal')
	}
	
	_add_checkoption($content, label => "have flat beams", value =>\$Caecilia::Settings::ABCM2PS_FLATBEAMS);
	
	
	####
	# The Apply/Cancel Buttons
	####
	my $f4 = $content->ttkFrame()->pack(-expand => 1, -fill => 'x',-padx => 5,-pady => 5);
	my $ok_button = $f4->ttkButton(
        -text => "Apply",
        -command => sub {settings_response($dialog,'apply')})
        ->pack(-side => 'left');
    my $cancel_button = $f4->ttkButton(
        -text => "Cancel",
        -command => sub {settings_response($dialog,'cancel')})
        ->pack(-side => 'left', -padx => 5);
    
	
    # Mousewheel event is always routed to the window that currently has focus. This isn't $canvas, but $content
    $content->bind("<MouseWheel>" => [\&on_mousewheel, Tcl::Ev('%D'),$canvas]);
    # Button events are sent to the window containing the pointer. This can be $content, but also an internal widget
    # of content. So we bind the toplevel window. Then the binding applies to the toplevel window and all its internal windows.
    # see https://www.tcl.tk/man/tcl/TkCmd/bind.htm#M4  
    $dialog->bind("<Button-4>" => sub {$canvas->interp->call('event',"generate", $content,"<MouseWheel>", -delta => 120);});
    $dialog->bind("<Button-5>" => sub {$canvas->interp->call('event','generate',$content,"<MouseWheel>", -delta => -120);});
    
    $canvas->configure(-scrollregion => [$canvas->bbox('all')]);
}


sub on_mousewheel {
	my ($delta,$canvas,$delta2) = @_;
	# TODO Some widgets have an own binding to MouseWheel (SpinBox, Combobox) etc. Here don't do the binding
	my $numbers = -1*$delta/120;
	$canvas->yview('scroll',$numbers,'units');
	#return "-code break";
}

sub settings_response {
	my ($dialog, $response) = @_;
	
	if ($response eq "apply") {
		Caecilia::Settings->write_config();
		$dialog->destroy();
	}
	else {
		$dialog->destroy();
	}
}

##############
# Internal functions
##############

sub _add_header {
	my ($content,$label) = @_;
	my $header = $content->ttkLabel(-text => "$label",-font=>"Helvetiva 10 bold")
        ->pack(-expand => 1, -fill => "both",-padx => 5,-pady => 5);
}

sub _add_checkoption {
	my ($content, %opts) = @_;
	my $f = $content->ttkFrame()->pack(-expand => 1, -fill => 'both', -padx => 5,-pady => 5);
	my $checkbutton = $f->ttkCheckbutton(-text => $opts{'label'},-variable => $opts{value} )
        ->pack(-side => "left");
	return $checkbutton;
}

sub _add_entry_with_check {
	my ($content, %opts) = @_;
	my $f = $content->ttkFrame()->pack(-expand => 1, -fill => 'both', -padx => 5,-pady => 5);
	my $check = 0;
	my $entry = $f->ttkEntry(-textvariable => $opts{value},-state => 'disabled',);
	my $checkbutton = $f->ttkCheckbutton(
        -text => $opts{label}, -variable => \$check, -onvalue => 1, -offvalue => 0,
        -width => 30,
        -command => sub {toggle($entry,$opts{value})})
        ->pack(-side => 'left');
    $entry->pack(-side => 'left', -expand => 1, -fill => 'x');
	
	if (${$opts{value}}) {
		$check = 1;
		$entry->configure(-state => 'normal')
	}
	
	
	return ($checkbutton, $entry);
}

sub _add_spin_with_check {
	my ($content,%opts) = @_;
	
	my $f = $content->ttkFrame()->pack(-expand => 1, -fill => 'both', -padx => 5,-pady => 5);
    my $spin = $f->ttkSpinbox(
        -from => $opts{min}, -to=>$opts{max}, -textvariable => $opts{value},-increment => $opts{step},-state => 'disabled');
    my $check = 0;
    my $checkbutton = $f->ttkCheckbutton(
        -text => $opts{label}, -variable => \$check, -onvalue => 1, -offvalue => 0,
        -width => 30,
        -command => sub {
        		toggle($spin,$opts{value})
        	}
        )->pack(-side => 'left');
    $spin->pack(-side => 'left', -expand => 1, -fill => 'x');
	
	if (${$opts{value}}) {
		$check = 1;
		$spin->configure(-state => 'normal');
		
		# No toplevel mousescroll events in Spinboxes
		my $class = $spin->class();
		$spin->interp->Eval("bindtags $spin [list $spin $class all]");
	}
	else {
		my $toplevel = $spin->toplevel();
		$spin->interp->Eval("bindtags $spin [list $spin $toplevel all]");
	}
	
	return ($checkbutton, $spin);
}

sub toggle {
    my ($widget,$value_ref) = @_;
    if ($widget->state =~ m/disabled/ ) {
        $widget->configure(-state => 'normal');
        
        # No toplevel mousescroll events in Spinboxes
		my $class = $widget->class();
		$widget->interp->Eval("bindtags $widget [list $widget $class all]");
    }
    else {
        $widget->state('disabled');
        ${$value_ref}= '';
        my $toplevel = $widget->toplevel();
        my $class = $widget->class();
        $widget->interp->Eval("bindtags $widget [list $widget $toplevel all]");
    }
}

sub toggle_combo {
    my ($widget,$value_ref) = @_;
    if ($widget->state =~ m/disabled/ ) {
        $widget->configure(-state => 'readonly');
        
        # No toplevel mousescroll events in Spinboxes
		my $class = $widget->class();
		$widget->interp->Eval("bindtags $widget [list $widget $class all]");
    }
    else {
        $widget->state('disabled');
        ${$value_ref}= '';
        
        my $toplevel = $widget->toplevel();
        my $class = $widget->class();
        $widget->interp->Eval("bindtags $widget [list $widget $toplevel all]");
    }
}

return 1;
