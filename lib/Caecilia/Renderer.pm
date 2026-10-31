package Caecilia::Renderer;

use 5.006000;
use strict;
use warnings;

use utf8;
use Caecilia::Settings;
use Caecilia::MyElm qw(_expand_widget _expand_widget_x _add_checkoption);
use IPC::Open3;

use JavaScript::QuickJS;
use File::Temp;

use pEFL::Elm;
use pEFL::Evas;

use PDF::API2;
use SVGPDF;
use File::Path qw(make_path remove_tree);

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

# SVG-Pixel (96 dpi) -> PDF-Punkte (72 pt pro Zoll)
my $PX2PT = 0.75;

# Preloaded methods go here.

sub new {
	my ($class, $app, %config) = @_;
	
	# TODO: abc2svg_path should be an option in app not in renderer or midi
	my $renderer_object = {app => $app, 
	    abc2svg_path => $app->share_dir . "/abc2svg/",
	    notes => {},
		error_message => "",
		elm_error_btn => undef,
		elm_only_current_check => undef};
	bless $renderer_object,$class;
	
	return $renderer_object;
}

# Put abc directives in front of the text of the preview, that a necessary for a working preview
# NEW: The directives are also put in front of the text for the MIDI (MIDI::generate_mid), so that
# the offsets of the notes (istart in MIDI) are the same in preview and MIDI
# IMPORTANT: If you change something here, the error line numbers (see render_preview) must be changed, too!
sub preview_header {
	my ($self) = @_;
	
	my $config = $self->app->settings->load_config();
	my $pageheight_cm = $config->{preview_pageheight} || 29.7;
	my $pagewidth_cm = $config->{preview_pagewidth} || 21.0;
	my $preview_scale = $config->{preview_scale} || 1;
	
	my $header = "\%\%fullsvg 1\n\%\%musicfont abc2svg\n\%\%pageheight $pageheight_cm"."cm\n\%\%pagewidth $pagewidth_cm"."cm\n\%\%pagescale $preview_scale\n";
	
	# FIX HYPHEN IN LYRICS BUG IN abc2svg 1.23.6:
	# see https://chiselapp.com/user/moinejf/repository/abc2svg/tktview/4129bd6558
	$header = $header . "%%hyphencont 0\n";
	
	return $header;
}

sub render_preview {
	my ($self, %opts) = @_;
	
	my $app = $self->app();
	my $dir = $app->tmpdir;
	
	my $config = $app->settings->load_config();
	
	my $outfile = $opts{outfile};
	my $pageheight_cm = $config->{preview_pageheight} || 29.7;
	my $pagewidth_cm = $config->{preview_pagewidth} || 21.0;
	my $pageheight = $pageheight_cm * 37.795;
	my $pagewidth = $pagewidth_cm * 37.795;
	my $topmargin = $config->{preview_topmargin} * 10 * 3.7795 || 10 * 3.7795;
	my $bottommargin = $config->{preview_bottommargin} * 10 * 3.7795 || 10*3.7795;
	my $bgcolor = "white";
	
	# Get the text of the entry and add a white background to the preview.abc
	# - Preview: in split mode the file header is put in front of the tune
	# - Export (export => 1): the whole file. As in Caecilia::save the text 
	# of the editor is stored in the tunebook first
	# !!! There is no preview for file header!!!)
	my $tunebook = $app->current_tunebook();
	my $text = $app->entry->get_text();
	if ( $opts{export} && $opts{only_current}) {
		$tunebook->content_current_str($text);
		$text = $tunebook->content_current_str();
	}
	elsif ($opts{export}) {
		$tunebook->content_current_str($text);
		$text = $tunebook->content_all_str();
	}
	else {
		$text = $tunebook->create_preview_abc($text);
	}
	
	# Scale stylesheet directives aren't supported in preview
	warn "Directive \%\%scale is not supported in preview\n" if ($text =~ s/\%\%scale/%% ..../g);
	warn "Directive \%\%pagescale is not supported in preview\n" if ($text =~ s/\%\%pagescale/%% ......../g);
	warn "Directive \%\%staffscale is not supported in preview\n" if ($text =~ s/\%\%staffscale/%% ........./g);
	warn "Directive \%\%voicescale is not supported in preview\n" if ($text =~ s/\%\%voicescale/%% ........./g);
	
	# create new files for preview	
	open my $fh, ">:encoding(utf8)", "$dir/render.abc";
	print $fh "$text";
	close $fh;
	
	my $header = $self->preview_header();
	

	# The click to note functionality (Preview, Entry::insert_deco) must contain everything
	# that is put in front of the editor text: the header above and the file header of the tunebook
	# Not for an export, because there the whole file is rendered
	my $prefix_lines = 0;
	unless ($opts{export}) {
		my $tunebook_header_length = $tunebook->preview_abc_offset();
		$self->preview_beginabc_length(length($header) + $tunebook_header_length);
		
		# number of lines of the file header (needed for the error messages)
		$prefix_lines = substr($text,0, $tunebook_header_length) =~ tr/\n//;
	}
	
	my $val = JavaScript::QuickJS->new()
    ->set_globals(path => $self->abc2svg_path(), abc_file => "$dir/render.abc", pageheight => $pageheight, pagewidth => $pagewidth, bgcolor => $bgcolor, topmargin => $topmargin, bottommargin => $bottommargin, header => $header )
    ->os()->std()->helpers()->eval(js());
    
    my @pages = @{ $val->{pages} };
    
    # Print SVG
    my $i = 1;
    foreach my $svg (@pages) {
        open my $fh, ">:utf8", "$outfile-$i.svg";
        print $fh $svg;
        close $fh;
        $i++;
    }
    
    # Print Notes
    my @notes = @{ $val->{notes} };
    my @offsets2correctpages = @{ $val->{lastoffsets2correct_pages} };
    #open my $fh2, ">:utf8", "$outfile.notes";
    
    my %notes;
    foreach my $line (@notes) {
        $line= correct_pages($line, $topmargin, @offsets2correctpages);
        #print $fh2 $line;
        
	    ### Fill note hash for MIDI play
	    if ($line =~ m!<abc type=".*" start_offset="(.*)" stop_offset="(.*)" x="(.*)" y="(.*)" width="(.*)" height="(.*)" svg_offset="(.*)" page_nr="(.*)"/>!) {
			my %note = (
					'istart' => $1,
					'iend' => $2,
					'x' => $3,
					'y' => $4,
					'width' => $5,
					'height' => $6,
					'svg_offset' => $7,
					'page_nr' => $8,
					);
			$notes{$1} = \%note;
		}
	}
	#close $fh;

	# An export don't need to overwrite the notes of the preview
	return if ($opts{export}); 
	
	$self->app->preview->{notes} = \%notes;
	
	my @error_messages = @{ $val->{errors} };
	my $error_message = "";
	foreach my $error (@error_messages) {
		$error =~ s/.*\://;
		$error =~ m/(\d+),\d+$/;
		# We have to correct the added abc lines (see above)
		# The first Line is in Caecilia 1 (not 0)!! TODO: Perhaps change the behaviour / same behaviour as abc2svg; I think changed (see above 6 newlines, here only 5)
		my $line_nr = $1-5;
		# In split mode, we need to add the lines of the fileheader of the tunebook, too (see above)
		if ($line_nr > $prefix_lines) {
			$line_nr = $line_nr - $prefix_lines;
		}
		else {
			$error = "(file header) $error";
		}
		$error =~ s/\d+,(\d+)$/$line_nr,$1/;
		$error_message = $error_message . "<br/>" . $error;
	}
	
	print "ERROR MSG $error_message\n";
	$self->error_message($error_message);
	if ($error_message) {
		$self->elm_error_btn->text_set("Show Errors");
	}
	else {
		$self->elm_error_btn->text_set("No Errors");
	}
}

sub show_errors {
	my ($self) = @_;
	my $app = $self->app();
	$app->_show_info("Errors from the last abc2svg call:",$self->error_message());
}

# Korrigiert die Seitenzuordnung von Noten, deren Zeile beim Rendern auf die
# nächste Seite umgebrochen wurde.
#
# Hintergrund: Das JS (anno_stop) legt die Noten einer Zeile an, bevor
# img_out weiß, ob die Zeile noch auf die aktuelle Seite passt. Diese Noten
# haben dann page_nr und svg_offset der ALTEN Seite. Passt die Zeile nicht
# mehr, beginnt img_out eine neue Seite und die Zeile steht dort ganz oben
# (bei $topmargin). Das JS merkt sich dafür in @offsets (lastoffsets2correct_pages)
# den Offset (yo), bei dem auf Seite N der Umbruch stattfand
# (Index = Seitennummer - 1).
#
# Erkennung: Eine Note gehört zur umgebrochenen Zeile, wenn ihr svg_offset
# genau diesem Umbruch-Offset ihrer Seite entspricht. Nur die umgebrochene
# Zeile hat diesen Offset, alle anderen Zeilen der Seite liegen weiter oben.
#
# Korrektur: page_nr + 1 und svg_offset = $topmargin (Zeilenanfang auf der
# neuen Seite).
#
# Parameter: Notenzeile (<abc .../>), oberer Seitenrand, Liste der Umbruch-Offsets
sub correct_pages {
    my ($line, $topmargin, @offsets) = @_;
    return $line unless $line =~ m!<abc type="note" start_offset=".*" stop_offset=".*" x=".*" y=".*" width=".*" height=".*" svg_offset="(.*)" page_nr="(.*)"/>!;
    
    my $svg_offset=$1;
    my $page = $2;
    
    if (defined($offsets[$page-1]) && $svg_offset == $offsets[$page-1]) {
        my $np = $page+1;
        $line =~ s/page_nr="$page"/page_nr="$np"/;
        $line =~ s/svg_offset="$svg_offset"/svg_offset="$topmargin"/;
    }
    return $line;
}

sub render_abcm2ps {
	my ($self, %opts) = @_;
	
	my $app = $self->app();
	my $dir = $app->tmpdir;
	my $only_current = $self->elm_only_current_check->state_get();
	
	my $config = $app->settings->load_config();
	
	my @cmd;
	push @cmd, '-c' if ($config->{abcm2ps_autolinebreak});
	
	push @cmd, "-B".$config->{abcm2ps_breaknbars} if ($config->{abcm2ps_breaknbars});
	push @cmd, "-e$opts{pattern}" if ($opts{pattern});
	
	push @cmd, "-s".$config->{abcm2ps_scalefactor} if ($config->{abcm2ps_scalefactor});
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
	
	push @cmd, "-b". $config->{abcm2ps_firstmeasure} if ($config->{abcm2ps_firstmeasure});
	push @cmd, "-f" if ($config->{abcm2ps_flatbeams});
	
	# As in Caecilia::save store the text of the editor first in the tunebook
	my $tunebook = $app->current_tunebook();
	$tunebook->content_current_str($app->entry->get_text());
	# then get the text of the entry and add white background
	my $text;
	if ($only_current) {
		$text = "%%bgcolor \"white\"\n" . $tunebook->content_current_str();
	}
	else {
		$text = "%%bgcolor \"white\"\n" . $tunebook->content_all_str();
	}
	
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
	my $error_message =''; my $out = '';
	while(my $line = <ERR>) {
			$line =~ s/^\/.*render.abc\://;
			$error_message = $error_message. $line . "<br/>";
	}
	
	while(my $l = <OUT>) {
			$out = $l if ($l =~m/^Output written on/);
			$out =~ s/Output written on/\<b\>Output written on... \<\/b\>\<br\/\>/;
	}
	
	close IN; close OUT; close ERR;
	waitpid($pid,0);
	my $child_exit_status = $? >> 8;
	print "abcm2ps exits with error status: $child_exit_status\n";
	
	# TODO:
	# if generating preview doesn't work, show an error dialog
	my $popup = pEFL::Elm::Win->util_dialog_add($app->elm_mainwindow(), "Render abc", "Render completed");
	$popup->autodel_set(1);
	
	my $bg = pEFL::Elm::Bg->add($popup);
	_expand_widget($bg);
	$bg->show(); $popup->resize_object_add($bg);
	
	my $box = pEFL::Elm::Box->add($popup);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	$popup->resize_object_add($box);

	my $label = pEFL::Elm::Label->new($box);
	my $message = ''; 
	if ($out) {
		$message = $out . "<br/>";
	}
	if ( $child_exit_status != 0 ) {
		$message = $message . "<br/><b>Errors occured while running abcm2ps:</b><br/>$error_message";
	} 
	$label->text_set("$message");
	$label->line_wrap_set(ELM_WRAP_MIXED);
	$label->wrap_width_set(400);
	$label->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
	$label->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$label->show(); $box->pack_end($label);
	
	my $btn = pEFL::Elm::Button->new($box);
	$btn->text_set("Close");
	$box->pack_end($btn);
	$btn->smart_callback_add("clicked",sub {$_[0]->del},$popup);
	_expand_widget($btn);
	$btn->show();
	
	$popup->show();
	
}

sub show_dialog {
	my ($self) = @_;
	
	my $app = $self->app();
	
	my $render_win = pEFL::Elm::Win->util_dialog_add($app->elm_mainwindow(), "Render abc", "Render");
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
	my $filename = $app->current_tunebook->filename || "";
	$filename =~ s/\..*$//;
	$out_en->entry_set($filename);
	$out_en->scrollable_set(1);
	$out_en->single_line_set(1);
	$out_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($out_en);
	$out_en->show(); $table->pack($out_en,1,0,1,1);
	
	# output format combobox
	my $format_label = pEFL::Elm::Label->new($table);
	$format_label->text_set("Format");
	$format_label->size_hint_align_set(0,0.5);
	$format_label->show(); $table->pack($format_label, 0,1,1,1);
	
	# output format combobox
	my @outformats = ('pdf (abc2svg/internal)', 'svg (abc2svg/internal)', '.ps', '.eps','.svg (one tune per file)','.svg (one page per file)','.xhtml','.xhtml (embedded abc)');
	my $format_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($format_combo);
	#$format_combo->size_hint_min_set(400,0);
	$format_combo->text_set('pdf (abc2svg/internal)');
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default"); $itc->text_get(sub {return $_[0];});
	foreach my $format (@outformats) {
		$format_combo->item_append($itc,$format,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$format_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$format_combo->show(); $table->pack($format_combo,1,1,1,1);
	
	my $only_current_check = _add_checkoption($table,label => "Render only current tune", value => 0, row => 2);
	
	# Save widgets
	$self->elm_out_en($out_en);
	$self->elm_fmt_combo($format_combo);
	$self->elm_only_current_check($only_current_check);
	
	$self->_add_buttons($table, 3);
	
	$render_win->resize(600,150);
	$render_win->show();
	return $render_win;
}

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
	
	my $settings_btn1 = pEFL::Elm::Button->new($btn_bx);
	$settings_btn1->text_set("abc2svg Settings");
	_expand_widget($settings_btn1);
	$settings_btn1->show(); $btn_bx->pack_end($settings_btn1);
	
	my $settings_btn = pEFL::Elm::Button->new($btn_bx);
	$settings_btn->text_set("abcm2ps Settings");
	_expand_widget($settings_btn);
	$settings_btn->show(); $btn_bx->pack_end($settings_btn);
	
	# Callbacks
	$cancel_btn->smart_callback_add("clicked", sub { $self->elm_render_win()->del(); }, undef );
	$ok_btn->smart_callback_add("clicked", \&render_cb, $self);
	$settings_btn1->smart_callback_add("clicked", \&settings_cb, [$self, 'Preview']);
	$settings_btn->smart_callback_add("clicked", \&settings_cb, [$self, 'abcm2ps Options']);
	
	return $btn_bx;
}

sub render_cb {
	my ($self) = @_;
	
	my $filename = $self->elm_out_en->entry_get();
	my $formatsvar = $self->elm_fmt_combo->text_get();
	
	if ($formatsvar eq 'pdf (abc2svg/internal)') {
		$self->render_caecilia2pdf($filename);
	} 
	elsif ( $formatsvar eq 'svg (abc2svg/internal)') {
		$self->render_caecilia2svg($filename);
	}
	else {
		$self->render_abcm2ps(outfile => $filename, outformat => $formatsvar);
	}
	
	$self->elm_render_win->del();
}

sub settings_cb {
	my ($data) = @_;
	my $self = $data->[0]; my $itemlabel = $data->[1];
	my $settings = $self->app->settings();
	$settings->show_dialog();
	my $tb = $settings->elm_toolbar();
	my $tab_item = $tb->item_find_by_label($itemlabel);
	$tab_item->selected_set(1);
}

#########################################
# PDF/SVG Export by internal preview
#########################################

sub render_caecilia2svg {
	my ($self, $outfile) = @_;
	my $only_current = $self->elm_only_current_check->state_get() ? 1 : 0;
	$self->render_preview(outfile => $outfile, export => 1, only_current => $only_current);
}

sub render_caecilia2pdf {
	my ($self, $outfile) = @_;
	
	# Create temporary print directory
	make_path($self->app->tmpdir . "/print");
	
	# Make SVGs in temporary directory
	my $only_current = $self->elm_only_current_check->state_get() ? 1 : 0;
	$self->render_preview(outfile => $self->app->tmpdir . "/print/preview", export => 1, only_current => $only_current);
	
	# convert SVGs to pdf
	$self->svg2pdf($outfile);
	
	# Remove temporary print directory
	remove_tree($self->app->tmpdir . "/print");
}

sub svg2pdf {
	my ($self, $outfile) = @_;
	
	my $dir = $self->app->tmpdir . "/print";
	# --- Dateien einsammeln und natürlich sortieren ------------------------------
	opendir( my $dh, $dir ) or die "Cannot open dir '$dir': $!\n";
	my @files = grep { /^preview-\d+\.svg$/i } readdir($dh);
	closedir($dh);

	die "Cannot not find any .svg files in '$dir'.\n" unless @files;

	@files = sort {
    	( $a =~ /(\d+)/ )[0] <=> ( $b =~ /(\d+)/ )[0]
	} @files;

	
	my $pdf = PDF::API2->new;

	my $fontfile = $self->app->share_dir . "/abc2svg/abc2svg.ttf";
	die "Cannot find font: $fontfile\n" unless -f $fontfile;

	my %fontcache;

	# Font-Callback für SVGPDF
	# Gibt für die Notenschrift (abc2svg) die TTF zurück, sonst Times mit
	# Fett/Kursiv. 
	my $fc = sub {
    	my ( $self, %args ) = @_;
    	my $style  = $args{style} || {};
    	my $family = $style->{'font-family'} // '';

    	if ( $family =~ /abc2svg/i ) {
        	return $fontcache{abc2svg} //= $args{pdf}->font($fontfile);
    	}

    	my $bold   = ( $style->{'font-weight'} // '' ) =~ /^(bold|bolder|[6-9]00)$/i;
    	my $italic = ( $style->{'font-style'}  // '' ) =~ /^(italic|oblique)$/i;

    	my $name = $bold   && $italic ? 'Times-BoldItalic'
             : $bold              ? 'Times-Bold'
             : $italic            ? 'Times-Italic'
             :                      'Times-Roman';

    	return $fontcache{$name} //= $args{pdf}->font($name);
	};
	
	# --- Seiten erzeugen ---------------------------------------------------------
	for my $file (@files) {
    	my $path = "$dir/$file";
    	print "Process $file ...\n";

    	open( my $in, '<:encoding(UTF-8)', $path ) or die "Cannot read $path: $!\n";
    	my $xml = do { local $/; <$in> };
    	close $in;

    	my ( $pw, $ph ) = page_size_pt($xml);
    	my @blocks = split_blocks($xml);
    	unless (@blocks) {
        	warn "  -> block skipped ($file): Could not find a musical staff \n";
        	next;
    	}

    	my $page = $pdf->page;
    	$page->mediabox( 0, 0, $pw, $ph );

    	my $gfx = $page->gfx;
    	# weißer Hintergrund
    	$gfx->fill_color('white');
    	$gfx->rect( 0, 0, $pw, $ph );
    	$gfx->fill;

		my $config = $self->app->settings->load_config();
		my $topmargin = $config->{preview_topmargin} * 10 * 3.7795 || 10 * 3.7795;
    	my $y =  - $topmargin * $PX2PT;    

	    for my $block (@blocks) {
	
    		# Pro Block ein neues SVGPDF-Objekt (sonst sammelt es Ergebnisse an)
        	my $svg  = SVGPDF->new( pdf => $pdf, fc => $fc );
        
        	# $xofs ist immer ein Skalar, der eine Referenz auf ein Array enthält.
        	my $xofs = eval { $svg->process( $self->write_tmp($block) ) };
        
        	# Rein defensive Sicherheitsabfragen:
        	# $@: Gab es einen Fehler im eval?
			# !$xofs: Ist $xofs leer oder undefiniert? SVGPDF gibt in manchen Fällen einfach nichts zurück.
			# !@$xofs: Ist das Array leer? @$xofs macht aus der Referenz das Array, mit ! heißt es „keine Elemente“.
        	if ( $@ or !$xofs or !@$xofs ) {
            	warn "  -> Could not crete XOF ($file): " . ( $@ || 'No content' ) . "\n";
            	next;
        	}

			# split_blocks liefert Stücke, die jeweils von einem <svg bis zum nächsten </svg> laufen. 
			# In jeder temporären Datei steht damit genau ein <svg>, und SVGPDF gibt dafür ein Array mit genau einem Hash zurück. 
			# Deshalb reicht $xofs->[0], ein weiteres Element gibt es nicht.
        	my $e  = $xofs->[0];
        	# ->{xo} holt aus dem Hash den Eintrag xo, das eigentliche XObject, also das gezeichnete Bild des Blocks.
        	my $xo = $e->{xo} or next;
        	# height ist die Höhe in SVG-Pixeln. Fehlt sie, nimmt || die vheight, und fehlt auch die, dann 0. 
        	# Das Ergebnis wird mit 0,75 in Punkte umgerechnet. Mit diesem $h rückt später $y -= $h nach unten.
        	my $h  = ( $e->{height} || $e->{vheight} || 0 ) * $PX2PT;

	        # Argumente von $gfx->object: Objekt, x-pos, y-pos, x-skalierung, y-skalierung
    	    #
        	# 1. WARUM ypos = y?
        	# SVGPDF-XObjects haben ein gespiegeltes Y: sie hängen an ihrer Oberkante, also bei y = aktuelle Oberkante platzieren.
        	# Ihr Inhalt wächst da aus nach unten (negativ)
        	#
        	# 2. WARUM SKALIERUNGEN PX2PT
        	# SVGPDF liefert die Maße in SVG-Pixeln, also 794 × 96 für einen Block. PDF zählt in Punkten, und 1 px sind 0,75 pt. 
        	# Beide Richtungen müssen den denselben Faktor $PX2PT bekommen
        	$gfx->object( $xo, 0, $y, $PX2PT, $PX2PT );
        
        	# In einer PDF liegt der Nullpunkt unten links, und y wächst nach oben 
        	# =>  kleiner y-Wert = weiter unten auf der Seite 
        	# $y -= $h rückt die Position daher nach unten
        	$y -= $h;
	    }
	}

	$pdf->save("$outfile.pdf");
	$pdf->close;

	print "Fertig: $outfile.pdf (" . scalar(@files) . " Dateien)\n";
}

# Seitengröße in pt aus width/height des äußeren Seiten-<svg> (px) herausfiltern
sub page_size_pt {
    my ($xml) = @_;
    my ( $pw, $ph ) = ( 595.276, 841.89 );    # Fallback: A4
    if ( $xml =~ /\A\s*<svg\b[^>]*?\bwidth="([\d.]+)px"[^>]*?\bheight="([\d.]+)px"/s ) {
        ( $pw, $ph ) = ( $1 * $PX2PT, $2 * $PX2PT );
    }
    return ( $pw, $ph );
}

# Seiten-SVG in einzelne Notenblöcke zerlegen
sub split_blocks {
    my ($xml) = @_;
    # Lösche global alle von anno_stop hinzugefügten <abc> Elemente 
    $xml =~ s!<abc\b[^>]*/>!!g;
    # Lösche das ersten von img_out hinzugefügten <svg> Element bis zum <rect> Element
    # SVGPDF kann keine verschachtelten SVGs. Deswegen ist es hier wichtig, wieder zum Urzustand 
    # von abc2svg zurückzukehren. Die Größe der Seite, der Hintergrund und Topmargin werden durch PDF::API2 gemanaged 
    $xml =~ s!\A\s*<svg\b[^>]*>(?:\s*<rect\b[^>]*/>)?!!;
    # Das letzte und abschließende <svg> Element muss natürlich auch gelöscht werden
    $xml =~ s!</svg>\s*\z!!;
    
    # Alle passenden SVG-Blöcke in einem Array speichern und zurückgeben
    my @blocks = ($xml =~ m!(<svg\b.*?</svg>)!gs);
    return @blocks;
}

sub write_tmp {
    my ($self, $text) = @_;
    
    my $fh = File::Temp->new(
        TEMPLATE => 'svg2pdf-XXXXXX',
        SUFFIX   => '.svg',
        DIR      => $self->app->tmpdir . "/print",
        UNLINK   => 0,  
    );
    
    binmode( $fh, ':encoding(UTF-8)' );
    print $fh $text;
    close $fh;  
    return $fh->filename; 
}


################
# Getter / Setter
#################
sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/app|elm_render_win|elm_out_en|elm_fmt_combo|preview_beginabc_length|preview_scale|error_message|elm_error_btn|elm_only_current_check|abc2svg_path/;
	
	my $attrib = $AUTOLOAD;
	$attrib =~ s/.*://;
	
	my $oldval = $self->{$attrib};
	$self->{$attrib} = $newval if defined($newval);
	if ($attrib eq "rehighlight") {
		#print "Highlight set to $newval\n" if $newval;
	}
	return $oldval;
}

sub js {
return <<'EOF';

var abc, core = "abc2svg-1.js",
	out = [],			// output without SVG container
	yo = topmargin,				// offset of the next SVG
	w = pagewidth,				// max width
	page_nr = 1;

std.loadScript(path + core);

// let header = "%%fullsvg 1\n%%musicfont abc2svg\n";
// let beginsvg = std.loadFile(path + "abc2svg.abc");
let content = std.loadFile(abc_file);
let context = "";

// fix the problem about the text coordinates in librsvg
// stolen from abctopdf :-)
function bug(p) {
    var	i, t, r, x, y, c, o, j = 0;

	while (1) {
		i = p.indexOf("<text x=", j);
		if (i < 0)
			return p;
		j = p.indexOf("</text", i);
		t = p.slice(i, j);

		r = t.match(/x="([^"]+)"\s+y="([^"]+)"[^>]*>(.+)/);
			// r[1] = x list, r[2] = y list, r[3] = characters

		if (r[1].indexOf(",") < 0)
			continue;
		x = r[1].split(",");
		y = r[2].split(",");
		let k = 0;
		o = "<text x=\"" + x[0] + "\" y=\"" + y[0] + "\">" + r[3][0];
		while (++k < x.length)
			o += "\n<tspan x=\"" + x[k] + "\" y=\"" + y[k] + "\">" + r[3][k] + "</tspan>";
		p = p.replace(t, o);
	}
	// not reached
} //bug()

let value = {
    pages: [],
    notes: [],
    errors: [],
    lastoffsets2correct_pages: [],
};

let user = {
	// Wird von abc2svg für jedes Notenelement aufgerufen und merkt sich dessen
    	// Position (x, y, Breite, Höhe) für die Klickflächen im Editor.
    	//
    	// WICHTIG: abc2svg ruft anno_stop auf, BEVOR es die zugehörige Notenzeile
    	// per img_out ausgibt. Zu diesem Zeitpunkt wissen wir noch nicht, ob die
    	// Zeile noch auf die aktuelle Seite passt. Deshalb tragen die Noten hier
    	// immer die aktuelle Seite (page_nr) und den aktuellen Offset (yo).
    	// Passt die Zeile dann in img_out nicht mehr auf die Seite, landet sie auf
    	// der nächsten Seite und diese Angaben stimmen nicht mehr. Die Korrektur
    	// erfolgt nachträglich in Perl (sie oben Perl function correct_pages).
    anno_stop: function(music_type, start, stop_offset, x, y, w, h, s) {
        if (music_type == "note" || music_type == "rest") {
            let line = "<abc type=\"" + music_type + "\" start_offset=\"" + start + "\" stop_offset=\"" + stop_offset + "\" x=\"" + abc.sx(x) + "\" y=\"" + abc.sy(y) + "\" width=\"" + w + "\" height=\"" + h + "\" svg_offset=\"" + yo + "\" page_nr=\"" + page_nr + "\"/>\n";
            value.notes.push(line);
            out.push(line);
        }
	},
    img_out: function(p) {
		    switch (p.slice(0, 4)) {
		    case "<svg":
			    // Seit abc2svg 1.22.29 wird die Höhe der SVG-Zeilen mit Nachkommastellen
    			// ausgegeben (posy.toFixed(2), wegen %%fit2box), z.B. height="120.35px".
    			// Der frühere Regex mit (\d+) matchte nur ganze Zahlen, lieferte dann null
    			// und führte zu "TypeError: cannot read property '2' of null".
    			// Daher hier auch Dezimalpunkte erlauben. Der Inhalt der von abc2svg
    			// erzeugten SVGs ist nicht spezifiziert und kann sich zwischen Versionen
    			// ändern, deshalb wird ein unerwarteter Header abgefangen.
    			// Siehe https://chiselapp.com/user/moinejf/repository/abc2svg/tktview/5a01923787
				let h = p.match(/width=\"([\d.]+)px\" height=\"([\d.]+)px\"/);
			    // if (pagewidth > 0) {
			    //    w = pagewidth;
			    // } else if (w < h[1]) {
				//    w = h[1];	// max width
			    //}
				
			    w = Number(pagewidth);
			    let yoh = Number(yo) + Number(h[2]);
			    p = bug(p);
		        if (Number(yoh) > Number(pageheight) - Number(bottommargin)) {
			        
			        //std.printf("Offset %.4f !!! Page limit exceeded\n", yo);
			        value.lastoffsets2correct_pages.push(yo);
		            let page = "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\"\n\
                            xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n\
                            width=\"" + w + "px\" height=\"" + pageheight + "px\">\n"
                            + "<rect width=\"100\%\" height=\"100\%\" fill=\"" +bgcolor + "\"/>\n"
		                    + out.join("\n") 
		                    + "\n</svg>";
		            
		            value.pages.push(page);
		
	                if (user.errtxt)
		                tm.printErr(user.errtxt);
                    
                    yo = topmargin; 
                    
                    page_nr = page_nr + 1;
                    //std.printf("Start new page %d with offset %.4f and height %4.f\n",page_nr+1,yo, h[2]);
                    out = [];
                    var	i = p.indexOf(">");
                    out.push(p.slice(0, i) + "\n y=\"" + yo + "\"" + p.slice(i));
                    yo = Number(yo) + Number(h[2]);
		            
		        } else {
		            //std.printf("New line in page %d with offset %.4f and height %4.f\n",page_nr, yo, h[2]);
		            var	i = p.indexOf(">");
			        out.push(p.slice(0, i) + "\n y=\"" + yo + "\"" + p.slice(i));
			        yo = Number(yo) + Number(h[2]); // offset
		        }
		        
			    break;
		    }
	    },
    errmsg: function(message, line_number, column_number) {
        console.log("Error: " + message + " at "+ line_number + "," + column_number);
        value.errors.push(message + " at "+ line_number + "," + column_number);
        
    },
    read_file: std.loadFile,
    //page_format: true,
    //imagesize: "width=\"794px\" height=\"1190px\"",
};

abc = new abc2svg.Abc(user);

try {
    abc.tosvg(abc_file,header+content);
} catch (e) {
    console.log("tosvg failed: " + e + "\n" + e.stack);
    value.errors.push("abc2svg internal error: " + e.message + " at 4,0");
}

let page = "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\"\n\
            xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n\
            width=\"" + w + "px\" height=\"" + pageheight + "px\">\n" 
            + "<rect width=\"100\%\" height=\"100\%\" fill=\"" + bgcolor +"\"/>" 
            + out.join("\n")
            + "\n</svg>";

value.pages.push(page);

value;

EOF
}

sub DESTROY {}

1;
__END__


=head1 NAME

Caecilia::Renderer

=head1 DESCRIPTION

This is the Renderer component of the Caecilia Appliation.

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
