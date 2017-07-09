package Caecilia::Settings;

use strict;
no strict 'vars';
use warnings;
use Glib('TRUE', 'FALSE');

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
	print $fh "\$Caecilia::Settings::ABCM2PS_LANDSCAPE = '$Caecilia::Settings::ABCM2PS_LANDSCAPE';\n" if ($Caecilia::Settings::ABCM2PS_LANDSCAPE);
	print $fh "\$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE ='$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE';\n" if ($Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE);
	print $fh "\$Caecilia::Settings::ABCM2PS_XREFNUMBERS = '$Caecilia::Settings::ABCM2PS_XREFNUMBERS';\n" if ($Caecilia::Settings::ABCM2PS_XREFNUMBERS);
	print $fh "\$Caecilia::Settings::ABCM2PS_NOLYRICS = '$Caecilia::Settings::ABCM2PS_NOLYRICS';\n" if ($Caecilia::Settings::ABCM2PS_NOLYRICS);
	print $fh "\$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE ='$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE';\n" if ($Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE);
	print $fh "\$Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE = '$Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE';\n" if ($Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE);
	print $fh "\$Caecilia::Settings::ABCM2PS_NOSLURINGRACE = '$Caecilia::Settings::ABCM2PS_NOSLURINGRACE';\n" if ($Caecilia::Settings::ABCM2PS_NOSLURINGRACE);
	print $fh "\$Caecilia::Settings::ABCM2PS_FLATBEAMS = '$Caecilia::Settings::ABCM2PS_FLATBEAMS';\n" if ($Caecilia::Settings::ABCM2PS_FLATBEAMS);
	
	close $fh;
	return 1;
}

####################
# The Settings GUI
####################
sub settings_cb {
	my ($window) = @_;
	# a Gtk3::Dialog
	my $dialog = Gtk3::Dialog->new();
	$dialog->set_transient_for($window);
	
	my $content_area = $dialog->get_content_area();
	my $grid = Gtk3::Grid->new();
	$grid->set_column_spacing(20); $grid->set_row_spacing(5);
	
	####
	# Path 
	####
	my $pathlabel = _add_header("Path to abcm2ps");
	my $abcpath_entry = Gtk3::Entry->new(); $abcpath_entry->set_hexpand(TRUE);
	$abcpath_entry->set_text("$Caecilia::Settings::ABCM2PS_PATH");
	
	#####
	# Line Breaks options
	#####
	my $header_linebreak = _add_header("Line Breaks Options");
	
	my $autolinebreak = _add_checkoption(label => "Auto line break", value =>$Caecilia::Settings::ABCM2PS_AUTOLINEBREAK);
	
	my ($breaknbars_check, $breaknbars_spin) = _add_spin_with_check(label => "Break every n bars", value => $Caecilia::Settings::ABCM2PS_BREAKNBARS,  min => 0, max => 100, step => 1, digits => 0);
	
	#####
	# Output formatting
	#####
	my $header_outputf = _add_header("Output Formatting");
	
	my ($scale_check, $scale_spin) = _add_spin_with_check(label => "Set Scale Factor", value => $Caecilia::Settings::ABCM2PS_SCALEFACTOR,  min => 0, max => 100, step => 0.1, digits => 2);
	
	my ($staffwidth_check,$staffwidth_entry) = _add_entry_with_check(label => "Set Staff width (cm/in/pt)", value => $Caecilia::Settings::ABCM2PS_STAFFWIDTH);
	
	my ($leftmargin_check,$leftmargin_entry) = _add_entry_with_check(label => "Set left margin (cm/in/pt)", value => $Caecilia::Settings::ABCM2PS_LEFTMARGIN);
	
	my ($staffseparation_check,$staffseparation_entry) = _add_entry_with_check(label => "Set staff separation (cm/in/pt)", value => $Caecilia::Settings::ABCM2PS_STAFFSEPARATION);
	
	my ($shrink_check, $shrink_spin) = _add_spin_with_check(label => "Set maximal shrinkage to", value => $Caecilia::Settings::ABCM2PS_MAXSHRINK,  min => 0, max => 1, step => 0.1, digits => 2);
	
	#####
	# Output Options
	#####
	my $header_outputopts = _add_header("Output Options");
	my $landscape = _add_checkoption(label => "landscape mode", value =>$Caecilia::Settings::ABCM2PS_LANDSCAPE);
	my ($indent_check,$indent_entry) = _add_entry_with_check(label => "indent first line (cm/in/pt)", value => $Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE);
	my $xref = _add_checkoption(label => "Add xref numbers in titles", value => $Caecilia::Settings::ABCM2PS_XREFNUMBERS);
	my $nolyrics = _add_checkoption(label => "Don't output lyrics", value =>$Caecilia::Settings::ABCM2PS_NOLYRICS);
	
	my $pagenumbering_check = Gtk3::CheckButton->new("Set the page numbering mode");
	my @pagenumberingmodes = ('off', 'left','right','even left, odd right','even right, odd left');
	my $liststore = Gtk3::ListStore->new('Glib::String');
	foreach my $mode (@pagenumberingmodes) {
		my $iter = $liststore->append();
		$liststore->set($iter, 0 => "$mode");
	}
	my $pagenumbering_combobox = Gtk3::ComboBox->new_with_model($liststore);
	my $cell = Gtk3::CellRendererText->new();
	$pagenumbering_combobox->pack_start($cell, FALSE);
	$pagenumbering_combobox->add_attribute($cell, 'text', 0);
	if ($Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE) {
		$pagenumbering_check->set_active(TRUE);
		$pagenumbering_combobox->set_active($Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE);
	}
	else {
		$pagenumbering_combobox->set_active(0);
		$pagenumbering_combobox->set_state_flags('insensitive', TRUE);
	}
	$pagenumbering_check->signal_connect('toggled' => \&_toggle_check, $pagenumbering_combobox);
	
	my $onetuneperpage = _add_checkoption(label => "Write one tune per page", value =>$Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE);
	my $noslur = _add_checkoption(label => "no slur in grace notes", value =>$Caecilia::Settings::ABCM2PS_NOSLURINGRACE);
	my $flatbeams = _add_checkoption(label => "have flat beams", value =>$Caecilia::Settings::ABCM2PS_FLATBEAMS);
	
	# Attach the widgets to the grid
	# attach(Kind, links, oben, Weite, Höhe)
	$grid->attach($pathlabel, 0,0,1,1);
	$grid->attach($abcpath_entry, 0, 1, 2, 1);
	$grid->attach($header_linebreak, 0,2,1,1);
	$grid->attach($autolinebreak, 0,3,2,1);
	$grid->attach($breaknbars_check, 0,4,1,1);$grid->attach($breaknbars_spin, 1,4,1,1);
	$grid->attach($header_outputf, 0,5,1,1);
	$grid->attach($scale_check, 0,6,1,1);$grid->attach($scale_spin, 1,6,1,1);
	$grid->attach($staffwidth_check, 0,7,1,1);$grid->attach($staffwidth_entry, 1,7,1,1);
	$grid->attach($leftmargin_check, 0,8,1,1);$grid->attach($leftmargin_entry, 1,8,1,1);
	$grid->attach($staffseparation_check, 0,9,1,1);$grid->attach($staffseparation_entry, 1,9,1,1);
	$grid->attach($shrink_check, 0,10,1,1);$grid->attach($shrink_spin, 1,10,1,1);
	$grid->attach($header_outputopts, 0,11,1,1);
	$grid->attach($landscape, 0,12,2,1);
	$grid->attach($indent_check, 0,13,1,1);$grid->attach($indent_entry, 1,13,1,1);
	$grid->attach($xref, 0,14,2,1);
	$grid->attach($nolyrics, 0,15,2,1);
	$grid->attach($pagenumbering_check, 0,16,1,1);$grid->attach($pagenumbering_combobox, 1,16,1,1);
	$grid->attach($onetuneperpage, 0,17,2,1);
	$grid->attach($noslur, 0,18,2,1);
	# to do number meaasures every n bars
	$grid->attach($flatbeams, 0,20,2,1);
	
	####
	# The Apply/Cancel Buttons
	####
	$dialog->add_button('Apply', 'apply');
	$dialog->add_button('Cancel', 'cancel');
	# After clicking Apply we need all widgets to save the content of them
	my @widgets = ($abcpath_entry, $autolinebreak,$breaknbars_spin,$scale_spin, $staffwidth_entry, $leftmargin_entry, $staffseparation_entry, $shrink_spin, $landscape, $indent_entry, $xref, $nolyrics, $pagenumbering_combobox, $onetuneperpage, $noslur, $flatbeams);
	$dialog->signal_connect('response' => \&settings_response,\@widgets);
	
	$content_area->add($grid);
	
	$dialog->show_all();
}

sub settings_response {
	my ($dialog, $response, $widgets_ref) = @_;
	my ($abcpath_entry, $autolinebreak,$breaknbars_spin,$scale_spin, $staffwidth_entry, $leftmargin_entry, $staffseparation_entry, $shrink_spin, $landscape, $indent_entry, $xref, $nolyrics, $pagenumbering_combobox, $onetuneperpage, $noslur, $flatbeams) = @$widgets_ref;
	
	if ($response eq "apply") {
		$Caecilia::Settings::ABCM2PS_PATH = $abcpath_entry->get_text();
		$Caecilia::Settings::ABCM2PS_AUTOLINEBREAK = $autolinebreak->get_active();
		
		if (grep/insensitive/, @{$breaknbars_spin->get_state_flags()}) {
			undef $Caecilia::Settings::ABCM2PS_BREAKNBARS
		} else { 
			$Caecilia::Settings::ABCM2PS_BREAKNBARS = $breaknbars_spin->get_value_as_int
		}
		
		if (grep /insensitive/, @{$scale_spin->get_state_flags()}) {
			undef $Caecilia::Settings::ABCM2PS_SCALEFACTOR
		} else {
			$Caecilia::Settings::ABCM2PS_SCALEFACTOR = $scale_spin->get_value
		}
		
		if (grep /insensitive/, @{$staffwidth_entry->get_state_flags()} ) { 
			undef $Caecilia::Settings::ABCM2PS_STAFFWIDTH
		} elsif ($staffwidth_entry->get_text()) { 
			$Caecilia::Settings::ABCM2PS_STAFFWIDTH = $staffwidth_entry->get_text()
		}
		
		if (grep /insensitive/, @{$leftmargin_entry->get_state_flags()} ) { 
			undef $Caecilia::Settings::ABCM2PS_LEFTMARGIN 
		} elsif ($leftmargin_entry->get_text()) { 
			$Caecilia::Settings::ABCM2PS_LEFTMARGIN = $leftmargin_entry->get_text() 
		}
		
		if (grep /insensitive/, @{$staffseparation_entry->get_state_flags()}) { undef $Caecilia::Settings::ABCM2PS_STAFFSEPARATION }
		elsif ($staffseparation_entry->get_text()) {$Caecilia::Settings::ABCM2PS_STAFFSEPARATION = $staffseparation_entry->get_text() }
		
		if (grep /insensitive/, @{$shrink_spin->get_state_flags()}) {undef $Caecilia::Settings::ABCM2PS_MAXSHRINK} else { $Caecilia::Settings::ABCM2PS_MAXSHRINK = $shrink_spin->get_value}
		 
		$Caecilia::Settings::ABCM2PS_LANDSCAPE = $landscape->get_active();
		
		if (grep /insensitive/, @{$indent_entry->get_state_flags()}) { 
			undef $Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE
		} elsif ($indent_entry->get_text()) { 
			$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE = $indent_entry->get_text() 
		}
		
		$Caecilia::Settings::ABCM2PS_XREFNUMBERS = $xref->get_active();
		$Caecilia::Settings::ABCM2PS_NOLYRICS = $nolyrics->get_active();
		
		if (grep /insensitive/, @{$pagenumbering_combobox->get_state_flags()}) { 
			undef $Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE 
		} else {
			$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE = $pagenumbering_combobox->get_active()
		}
		
		$Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE = $onetuneperpage->get_active();
		$Caecilia::Settings::ABCM2PS_NOSLURINGRACE = $noslur->get_active();
		$Caecilia::Settings::ABCM2PS_FLATBEAMS = $flatbeams->get_active();
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
	my ($label) = shift;
	my $header = Gtk3::Label->new();
	$header->set_xalign(0);
	$header->set_markup("<b>$label</b>");
	return $header;
}

sub _add_checkoption {
	my (%opts) = @_;
	
	my $checkbutton = Gtk3::CheckButton->new($opts{'label'});
	if ($opts{'value'}) {
		$checkbutton->set_active(TRUE);
	}
	return $checkbutton;
}

sub _add_entry_with_check {
	my (%opts) = @_;
	my $check = Gtk3::CheckButton->new("$opts{label}");
	my $entry = Gtk3::Entry->new();$entry->set_hexpand(TRUE);
	$entry->set_state_flags('insensitive', TRUE);
	if ($opts{value}) {
		$entry->set_state_flags('normal', TRUE);
		$check->set_active(TRUE);
		$entry->set_text("$opts{value}");
	}
	$check->signal_connect('toggled' => \&_toggle_check, $entry);
	return ($check, $entry);
}

sub _add_spin_with_check {
	my (%opts) = @_;
	my $check = Gtk3::CheckButton->new("$opts{label}");
	my $ad = Gtk3::Adjustment->new(0,$opts{min},$opts{max},$opts{step},0,0);
	my $spin = Gtk3::SpinButton->new($ad, $opts{step}, $opts{digits});
	$spin->set_state_flags('insensitive', TRUE);
	if ($opts{value}) {
		$spin->set_state_flags('normal', TRUE);
		$check->set_active(TRUE);
		$spin->set_value($opts{value});
	}
	$check->signal_connect('toggled' => \&_toggle_check, $spin);
	return ($check, $spin);
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
return 1;