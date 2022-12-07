package Caecilia::Renderer;

use 5.006000;
use strict;
use warnings;

use utf8;
use File::ShareDir 'dist_dir';
use Caecilia::Settings;
use Caecilia::MyElm qw(_expand_widget _expand_widget_x _add_entry_with_check _add_spin_with_check _combobox_item_pressed);
use Cwd;
use IPC::Open3;

use pEFL::Elm;
use pEFL::Evas;

require Exporter;

our @ISA = qw(Exporter);

our $AUTOLOAD;

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
	my ($class, $app, %config) = @_;
	
	my $renderer_object = {app => $app};
	bless $renderer_object,$class;
	
	# Sharedir
	#my $sharedir = dist_dir('Caecilia');
	my $share = ('../share');
	
	return $renderer_object;
}

sub render {
	my ($self, %opts) = @_;
	
	my $app = $self->app();
	my $dir = $app->tmpdir;
	
	my $config = $app->settings->load_config();
	
	my @cmd;
	push @cmd, '-c' if ($config->{abcm2ps_autolinebreak});
	push @cmd, '-A' if ($opts{mode} eq 'preview');
	push @cmd, '-q' if ($opts{mode} eq 'preview');
	push @cmd, '-s' if ($opts{mode} eq 'preview');
	push @cmd, '0.75' if ($opts{mode} eq 'preview');
	
	push @cmd, "-B$Caecilia::Settings::ABCM2PS_BREAKNBARS" if ($config->{abcm2ps_breaknbars});
	push @cmd, "-e$opts{pattern}" if ($opts{pattern});
	
	# no scale in preview
	if ($config->{abcm2ps_scalefactor}) {
        if ($opts{mode} eq 'preview') {
            warn "The option scalefactor (-s) is not supported in Preview. So preview and  rendered output may differ\n";
        }
        else {
            push @cmd, "-s".$config->{abcm2ps_scalefactor};
        }
	}
	push @cmd, "-w".$config->{abcm2ps_staffwidth} if ($config->{abcm2ps_staffwidth});
	push @cmd, "-m".$config->{abcm2ps_leftmargin} if ($config->{abcm2ps_leftmargin});
	push @cmd, "-d".$config->{abcm2ps_staffseparation} if ($config->{abcm2ps_staffseparation});
	push @cmd, "-a".$config->{abcm2ps_maxshrink} if ($config->{abcm2ps_maxshrink});
	push @cmd, "-F".$config->{abcm2ps_fmtfile} if ($config->{abcm2ps_fmtfile});
	push @cmd, "-D".$config->{abcm2ps_fmtdir} if ($config->{abcm2ps_fmtdir});
	push @cmd, "-l" if ($config->{abcm2ps_landscape});
	push @cmd, "-I".$config->{abcm2ps_indentfirstline} if ($config->{abcm2ps_indentfirstline});
	push @cmd, "-x" if ($config->{abcm2ps_xrefnumbers});
	push @cmd, "-M" if ($config->{abcm2ps_nolyrics});
	
	my %pagenumberingmodes = ('off'=>0, 'left'=>1,'right'=>2,'even left, odd right'=>3,'even right, odd left'=>4);
	push @cmd, "-N".$pagenumberingmodes{$config->{abcm2ps_pagenumbering}}  if ($config->{abcm2ps_pagenumbering});
	push @cmd, "-1" if ($config->{abcm2ps_onetuneperpage});
	push @cmd, "-G" if ($config->{abcm2ps_nosluringrace});
	
	
	if ($config->{abcm2ps_numbernbars} && $config->{abcm2ps_numbernbarsboxed}) {
		push @cmd, ("-j".$config->{abcm2ps_numbernbars}."b");
	}
	elsif ($config->{abcm2ps_numbernbars}) {
		push @cmd, "-j".$config->{abcm2ps_numbernbars};
	}
	push @cmd, "-b$opts{firstmeasure}" if ($opts{firstmeasure});
	push @cmd, "-f" if ($config->{abcm2ps_flatbeams});
	
	# Get the text of the entry and add a white background to the preview.abc
	my $text = "%%bgcolor \"white\"\n" . $self->app->entry->elm_entry->entry_get();
	# convert $text to utf8
	$text = pEFL::Elm::Entry::markup_to_utf8($text);	
	$text = Encode::decode("utf-8",$text);
	
	
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
	my $abcm2ps = $config->{abcm2ps_path} || "abcm2ps";
	my $pid = open3(\*IN, \*OUT, \*ERR, $abcm2ps, @cmd);
	my $error_message ='';
		while(my $line = <ERR>) {
			$error_message .= $line
		}
	close IN; close OUT; close ERR;
	waitpid($pid,0);
	if ($?) {
		# TODO:
		# if generating preview doesn't work, show an error dialog
		warn "Error occured while running abcm2ps: $error_message\n";
	}
}


sub show_dialog {
	my ($self) = @_;
	
	my $app = $self->app();
	
	my $render_win = pEFL::Elm::Win->add($app->elm_mainwindow(), "Render abc", ELM_WIN_BASIC);
	$render_win->title_set("Render");
	$render_win->focus_highlight_enabled_set(1);
	$render_win->autodel_set(1);
	$self->elm_render_win($render_win);
	
	my $bg = pEFL::Elm::Bg->add($render_win);
	_expand_widget($bg);
	$bg->show(); $render_win->resize_object_add($bg);
	
	my $box = pEFL::Elm::Box->add($render_win);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($render_win);
	$frame->text_set("Render .abc tune");
	$frame->part_content_set("default",$box);
	_expand_widget($frame);
	$frame->show(); $render_win->resize_object_add($frame);
	
	my $table = pEFL::Elm::Table->add($frame);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	my $out_label = pEFL::Elm::Label->new($table);
	$out_label->text_set("Outfile");
	$out_label->size_hint_align_set(0,0.5);
	$out_label->show(); $table->pack($out_label, 0,0,1,1);
	
	my $out_en = pEFL::Elm::Entry->new($table);
	my $filename = $app->current_tab->filename || "";
	$filename =~ s/\..*$//;
	$out_en->entry_set($filename);
	$out_en->scrollable_set(1);
	$out_en->single_line_set(1);
	$out_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($out_en);
	$out_en->show(); $table->pack($out_en,1,0,1,1);
	
	# output format combobox
	my @outformats = ('.ps', '.eps','.svg (one tune per file)','.svg (one page per file)','.xhtml','.xhtml (embedded abc)');
	my $format_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($format_combo);
	$format_combo->size_hint_min_set(400,0);
	$format_combo->text_set('.ps');
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default"); $itc->text_get(sub {return $_[0];});
	foreach my $format (@outformats) {
		$format_combo->item_append($itc,$format,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$format_combo->smart_callback_add("item,pressed",\&_combobox_item_pressed_cb, undef);
	$format_combo->show(); $table->pack($format_combo,2,0,2,1);
	
	my ($pattern_check, $pattern_en) = _add_entry_with_check($table,
		value => "", label => "Tune selection", row => 1);
		
	my ($firstmeasure_check, $firstmeasure_spin) = _add_spin_with_check( $table,
		value => "", label => "first measure number", 
		min => 1, max => 1000, step => 1, fmt => "%1.0f", row => 2);
	
	
	# Save widgets
	$self->elm_out_en($out_en);
	$self->elm_fmt_combo($format_combo);
	$self->elm_firstmeasure_spin($firstmeasure_spin);
	$self->elm_pattern_en($pattern_en);
	
	$self->_add_buttons($table, 4);
	
	$render_win->resize(530,225);
	$render_win->show();
	return $render_win;
}

sub render_cb {
	my ($self) = @_;
	
	my $filename = $self->elm_out_en->entry_get();
	my $formatsvar = $self->elm_fmt_combo->text_get();
	my $firstmeasure_spin = $self->elm_firstmeasure_spin();
	my $firstmeasure_spinvar = $firstmeasure_spin->disabled_get ? "" : $firstmeasure_spin->value_get();
	
	$self->render(outfile => $filename, outformat => $formatsvar, firstmeasure => $firstmeasure_spinvar, mode => '');
	
	$self->elm_render_win->del();
}

sub settings_cb {
	my ($self) = @_;
	my $settings = $self->app->settings();
	$settings->show_dialog();
	my $tb = $settings->elm_toolbar();
	my $tab_item = $tb->item_find_by_label('abcm2ps Options');
	$tab_item->selected_set(1);
}

####################
# UI helpers 
########################

sub _add_buttons {
	my ($self,$table,$row) = @_;
	
	my $btn_bx = pEFL::Elm::Box->add($table);
	_expand_widget_x($btn_bx);
	$btn_bx->horizontal_set(1);
	$btn_bx->show(); $table->pack($btn_bx,0,$row,2,1);
	
	my $ok_btn = pEFL::Elm::Button->new($btn_bx);
	$ok_btn->text_set("OK");
	_expand_widget($ok_btn);
	$ok_btn->show(); $btn_bx->pack_end($ok_btn);
	
	my $cancel_btn = pEFL::Elm::Button->new($btn_bx);
	$cancel_btn->text_set("Cancel");
	_expand_widget($cancel_btn);
	$cancel_btn->show(); $btn_bx->pack_end($cancel_btn);
	
	my $settings_btn = pEFL::Elm::Button->new($btn_bx);
	$settings_btn->text_set("Abcm2ps Settings");
	_expand_widget($settings_btn);
	$settings_btn->show(); $btn_bx->pack_end($settings_btn);
	
	# Callbacks
	$cancel_btn->smart_callback_add("clicked", sub { $self->elm_render_win()->del(); }, undef );
	$ok_btn->smart_callback_add("clicked", \&render_cb, $self);
	$settings_btn->smart_callback_add("clicked", \&settings_cb, $self);
	
	return $btn_bx;
}

################
# Getter / Setter
#################
sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|elm_render_win|elm_out_en|elm_fmt_combo|elm_firstmeasure_spin|elm_pattern_en|/;
	
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
