package Caecilia::Renderer;

use 5.006000;
use strict;
use warnings;

use utf8;
use File::ShareDir 'dist_dir';
use Caecilia::Settings;
use Cwd;
use IPC::Open3;

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
	#my $sharedir = dist_dir('Caecilia');
	my $share = ('../share');
	
	return $renderer_object;
}

sub render {
	my (%opts) = @_;
	my $dir = $main::tmpdir;
	
	my @cmd;
	push @cmd, '-c' if ($Caecilia::Settings::ABCM2PS_AUTOLINEBREAK);
	push @cmd, '-A' if ($opts{mode} eq 'preview');
	push @cmd, '-q' if ($opts{mode} eq 'preview');
	push @cmd, '-s' if ($opts{mode} eq 'preview');
	push @cmd, '0.75' if ($opts{mode} eq 'preview');
	
	push @cmd, "-B$Caecilia::Settings::ABCM2PS_BREAKNBARS" if ($Caecilia::Settings::ABCM2PS_BREAKNBARS);
	push @cmd, "-e$opts{pattern}" if ($opts{pattern});
	
	# no scale in preview
	if ($Caecilia::Settings::ABCM2PS_SCALEFACTOR) {
        if ($opts{mode} eq 'preview') {
            warn "The option scalefactor (-s) is not supported in Preview. So preview and  rendered output may differ\n";
        }
        else {
            push @cmd, "-s$Caecilia::Settings::ABCM2PS_SCALEFACTOR";
        }
	}
	push @cmd, "-w$Caecilia::Settings::ABCM2PS_STAFFWIDTH" if ($Caecilia::Settings::ABCM2PS_STAFFWIDTH);
	push @cmd, "-m$Caecilia::Settings::ABCM2PS_LEFTMARGIN" if ($Caecilia::Settings::ABCM2PS_LEFTMARGIN);
	push @cmd, "-d$Caecilia::Settings::ABCM2PS_STAFFSEPARATION" if ($Caecilia::Settings::ABCM2PS_STAFFSEPARATION);
	push @cmd, "-a$Caecilia::Settings::ABCM2PS_MAXSHRINK" if ($Caecilia::Settings::ABCM2PS_MAXSHRINK);
	push @cmd, "-F$Caecilia::Settings::ABCM2PS_FORMATFILE" if ($Caecilia::Settings::ABCM2PS_FORMATFILE);
	push @cmd, "-D$Caecilia::Settings::ABCM2PS_FORMATDIRECTORY" if ($Caecilia::Settings::ABCM2PS_FORMATDIRECTORY);
	push @cmd, "-l" if ($Caecilia::Settings::ABCM2PS_LANDSCAPE);
	push @cmd, "-I$Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE" if ($Caecilia::Settings::ABCM2PS_INDENTFIRSTLINE);
	push @cmd, "-x" if ($Caecilia::Settings::ABCM2PS_XREFNUMBERS);
	push @cmd, "-M" if ($Caecilia::Settings::ABCM2PS_NOLYRICS);
	
	my %pagenumberingmodes = ('off'=>0, 'left'=>1,'right'=>2,'even left, odd right'=>3,'even right, odd left'=>4);
	push @cmd, "-N".$pagenumberingmodes{$Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE}  if ($Caecilia::Settings::ABCM2PS_PAGENUMBERINGMODE);
	push @cmd, "-1" if ($Caecilia::Settings::ABCM2PS_ONETUNEPERPAGE);
	push @cmd, "-G" if ($Caecilia::Settings::ABCM2PS_NOSLURINGRACE);
	
	if ($Caecilia::Settings::ABCM2PS_NUMBERNBARS && $Caecilia::Settings::ABCM2PS_NUMBERNBARSBOXED) {
		push @cmd, ("-j".$Caecilia::Settings::ABCM2PS_NUMBERNBARS."b");
	}
	elsif ($Caecilia::Settings::ABCM2PS_NUMBERNBARS) {
		push @cmd, "-j$Caecilia::Settings::ABCM2PS_NUMBERNBARS";
	}
	push @cmd, "-b$opts{firstmeasure}" if ($opts{firstmeasure});
	push @cmd, "-f" if ($Caecilia::Settings::ABCM2PS_FLATBEAMS);
	
	my $text = $main::editor->get_text();
	# Scale stylesheet directive isn't supported in preview
	#$text =~ s/%%scale.*\n//g if ($opts{mode} eq 'preview');
	# create new files for preview	
	open my $fh, ">:encoding(utf8)", "$dir/render.abc";
	print $fh "$text";
	close $fh;
	
	push @cmd, "$dir/render.abc";
	
	push @cmd, "-E" if ($opts{outformat} eq '.eps');
	push @cmd, "-g" if ($opts{outformat} eq '.svg (one tune per file)');
	push @cmd, "-v" if ($opts{outformat} eq '.svg (one page per file)');
	push @cmd, "-X" if ($opts{outformat} eq '.xhtml');
	push @cmd, "-z" if ($opts{outformat} eq '.xhtml (embedded abc)');
	
	$opts{outfile} = $opts{outfile} . ".ps" if ($opts{outformat} eq '.ps');
	$opts{outfile} = $opts{outfile} . ".eps" if ($opts{outformat} eq '.eps');
	$opts{outfile} = $opts{outfile} . ".svg" if ($opts{outformat} eq '.svg (one tune per file)');
	$opts{outfile} = $opts{outfile} . ".svg" if ($opts{outformat} eq '.svg (one page per file)');
	$opts{outfile} = $opts{outfile} . ".xhtml" if ($opts{outformat} eq '.xhtml');
	$opts{outfile} = $opts{outfile} . ".xhtml" if ($opts{outformat} eq '.xhtml (embedded abc)');
	push @cmd, "-O$opts{outfile}";
	
	my ($stdin,$stdout, $stderr);
	#my $pid = open3(\*IN, \*OUT, \*ERR, $Caecilia::Settings::ABCM2PS_PATH, @cmd); 
	
	my $pid = open3(\*IN, \*OUT, \*ERR, $Caecilia::Settings::ABCM2PS_PATH, @cmd);
	my $error_message ='';
		while(my $line = <ERR>) {
			$error_message .= $line
		}
	close IN; close OUT; close ERR;
	waitpid($pid,0);
	if ($?) {
		# if generating preview doesn't work, show an error dialog
		my $dialog = $main::mw->messageBox(
            -type => "ok",
            -message => "Error occured while running abcm2ps",
            -icon => "error",
            -title => "Error",
            -detail => $error_message);
	}
}

sub render_dialog {
    my ($mw) = @_;
    
    my $dialog = $mw->Toplevel();
    $dialog->title('Render Abc Music');
	$dialog->transient("$mw");
	
	my $f1 = $dialog->ttkFrame()->pack(-expand => 1, -fill => 'x', -padx => 5,-pady => 5);
	# Output label
	my $outfile_label = $f1->ttkLabel(-text => "Outfile")->pack(-side => 'left');
	
	# output format combobox
	my @outformats = ('.ps', '.eps','.svg (one tune per file)','.svg (one page per file)','.xhtml','.xhtml (embedded abc)');
	my $formatsvar='.ps';
	my $formats_cbox = $f1->ttkCombobox(
        -values => \@outformats, -textvariable => \$formatsvar)
        ->pack(-side =>'right');
	#TODO filename_ref if en empty doc
	my $filename = $main::filename;
	$filename =~ s/\..*$//;
	my $outfile_entry = $f1->ttkEntry(-textvariable => \$filename)->pack(-side => 'right', -expand => 1, -fill => 'x');
	
	# TODO tune selection TODO
	my $f3 = $dialog->ttkFrame()->pack(-expand => 1, -fill => 'both', -padx => 5,-pady => 5);
	my $pattern_bool = 0; my $pattern_val='';
	my $pattern_entry = $f3->ttkEntry(-textvariable => \$pattern_val,-state => 'disabled',);
	my $pattern_check = $f3->ttkCheckbutton(
        -text => "Tune selection", -variable => \$pattern_bool, -onvalue => 1, -offvalue => 0,
        -width => 20,
        -command => sub {toggle($pattern_entry)})
        ->pack(-side => 'left');
    $pattern_entry->pack(-side => 'left', -expand => 1, -fill => 'x');
	
    # first measure number
    my $f2 = $dialog->ttkFrame()->pack(-expand => 1, -fill => 'both', -padx => 5,-pady => 5);
    my $firstmeasurebool = 0;
    my $firstmeasure_spinvar = 0;
    my $firstmeasure_spin = $f2->ttkSpinbox(
        -from => 1, -to=>1000, -textvariable => \$firstmeasure_spinvar,-increment => 1,-state => 'disabled');
    my $firstmeasure_check = $f2->ttkCheckbutton(
        -text => "first measure number", -variable => \$firstmeasurebool, -onvalue => 1, -offvalue => 0,
        -width => 20,
        -command => sub {toggle($firstmeasure_spin)})
        ->pack(-side => 'left');
    $firstmeasure_spin->pack(-side => 'left', -expand => 1, -fill => 'x');
	
	####
	# The Apply/Cancel Buttons
	####
	my $f4 = $dialog->ttkFrame()->pack(-expand => 1, -fill => 'x',-padx => 5,-pady => 5);
	my @params = (\$filename,\$formatsvar,\$firstmeasurebool,\$firstmeasure_spinvar);
	my $ok_button = $f4->ttkButton(
        -text => "Ok",
        -command => sub {render_dialog_response($dialog,'ok',\@params)})
        ->pack(-side => 'left', -padx => 3);
    my $cancel_button = $f4->ttkButton(
        -text => "Cancel",
        -command => sub {render_dialog_response($dialog,'cancel',\@params)})
        ->pack(-side => 'left', -padx => 3);
    my $settings_button = $f4->ttkButton(
        -text => "Abcm2ps Settings",
        -command => sub {Caecilia::Settings::settings_cb( $mw);})
        ->pack(-side => 'left', -padx => 3);
}

sub render_dialog_response {
	my ($dialog, $response, $params_ref) = @_;
	my ($filename,$formatsvar,$firstmeasurebool,$firstmeasure_spinvar) = @$params_ref;
	if ($response eq 'ok') {
		render(outfile => $$filename, outformat => $$formatsvar, firstmeasure => $$firstmeasure_spinvar, mode => '');
		$dialog->destroy; 
	}
	else {
		$dialog->destroy();
	}
}

sub toggle {
    my ($widget) = @_;
    if ($widget->state eq 'disabled') {
        $widget->configure(-state => 'normal')
    }
    else {
        $widget->state('disabled')
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
