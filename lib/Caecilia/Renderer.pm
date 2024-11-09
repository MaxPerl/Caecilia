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
	
	# TODO: abc2svg_path should be an option in app not in renderer or midi
	my $renderer_object = {app => $app, 
	    abc2svg_path => $app->share_dir . "/abc2svg/",
	    notes => {}};
	bless $renderer_object,$class;
	
	return $renderer_object;
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
    my $topmargin = 10*3.77;
    my $bgcolor = "white";
    my $preview_scale = $config->{preview_scale} || 1;
	
	# Get the text of the entry and add a white background to the preview.abc
	my $text = $self->app->entry->elm_entry->entry_get();
	# convert $text to utf8
	$text = pEFL::Elm::Entry::markup_to_utf8($text);	
	$text = Encode::decode("utf-8",$text);
	
	# Scale stylesheet directives aren't supported in preview
	warn "Directive \%\%scale is not supported in preview\n" if ($text =~ s/\%\%scale/%% ..../g);
	warn "Directive \%\%pagescale is not supported in preview\n" if ($text =~ s/\%\%pagescale/%% ......../g);
	warn "Directive \%\%staffscale is not supported in preview\n" if ($text =~ s/\%\%staffscale/%% ........./g);
	warn "Directive \%\%voicescale is not supported in preview\n" if ($text =~ s/\%\%voicescale/%% ........./g);
	
	# create new files for preview	
	open my $fh, ">:encoding(utf8)", "$dir/render.abc";
	print $fh "$text";
	close $fh;
	
	my $header = "\%\%fullsvg 1\n\%\%musicfont abc2svg\n\%\%pageheight $pageheight_cm"."cm\n\%\%pagewidth $pagewidth_cm"."cm\n\%\%pagescale $preview_scale\n";
	$self->preview_beginabc_length(length($header));
	
	my $val = JavaScript::QuickJS->new()
    ->set_globals(path => $self->abc2svg_path(), abc_file => "$dir/render.abc", pageheight => $pageheight, pagewidth => $pagewidth, bgcolor => $bgcolor, topmargin => $topmargin, header => $header )
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
        $line= correct_pages($line, @offsets2correctpages);
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
	
	$self->app->preview->{notes} = \%notes;
	
	my @error_messages = @{ $val->{errors} };
	my $error_message = "";
	foreach my $error (@error_messages) {
		$error =~ s/.*\://;
		$error =~ m/(\d+),\d+$/;
		# We have to correct the added abc lines (see above)
		# The first Line is in Caecilia 1 (not 0)!! TODO: Perhaps change the behaviour / same behaviour as abc2svg
		my $line_nr = $1-4;
		$error =~ s/\d+,(\d+)$/$line_nr,$1/;
		$error_message = $error_message . "<br/>" . $error;
	}
	
	print "ERROR MSG $error_message\n";
	if ($error_message) {
		# TODO:
		# if generating preview doesn't work, show an error dialog
		my $popup = pEFL::Elm::Popup->add($app->elm_mainwindow());
		$popup->part_text_set("default", "<b>Error occured while running abcm2ps:</b><br/><br/>". $error_message );
		$popup->scrollable_set(1);
		my $btn = pEFL::Elm::Button->add($popup);
		$btn->text_set("Close");
		$popup->part_content_set("button1",$btn);
		$btn->smart_callback_add("clicked",sub {$_[0]->del},$popup);
	
		# popup show should be called after adding all the contents and the buttons
		# of popup to set the focus into popup's contents correctly.
		$popup->show();
		
	}
}

sub correct_pages {
    my ($line, @offsets) = @_;
    $line =~ m!<abc type="note" start_offset=".*" stop_offset=".*" x=".*" y=".*" width=".*" height=".*" svg_offset="(.*)" page_nr="(.*)"/>!;
    
    my $svg_offset=$1;
    my $page = $2;
    
    if ($svg_offset == $offsets[$page-1]) {
        my $np = $page+1;
        $line =~ s/page_nr="$page"/page_nr="$np"/;
        $line =~ s/svg_offset="$svg_offset"/svg_offset="0"/;
    }
    return $line;
}

sub render_abcm2ps {
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
	my $popup = pEFL::Elm::Win->add($app->elm_mainwindow(), "Render abc", ELM_WIN_BASIC);
	$popup->title_set("Render completed");
	$popup->focus_highlight_enabled_set(1);
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
	my $filename = $app->current_tune->filename || "";
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
	$format_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
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
	
	$self->render_abcm2ps(outfile => $filename, outformat => $formatsvar, firstmeasure => $firstmeasure_spinvar, mode => '');
	
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
		unless $AUTOLOAD =~m/app|elm_render_win|elm_out_en|elm_fmt_combo|elm_firstmeasure_spin|elm_pattern_en|preview_beginabc_length|preview_scale|/;
	
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
	yo = 0,				// offset of the next SVG
	w = pagewidth,				// max width
	page_nr = 1;

std.loadScript(path + core);

// let header = "%%fullsvg 1\n%%musicfont abc2svg\n";
// let beginsvg = std.loadFile(path + "abc2svg.abc");
let content = std.loadFile(abc_file);
let context = "";

// fix the problem about the text coordinates in librsvg
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
			    let h = p.match(/width=\"(\d+)px\" height=\"(\d+)px\"/);
			    // if (pagewidth > 0) {
			    //    w = pagewidth;
			    // } else if (w < h[1]) {
				//    w = h[1];	// max width
			    //}
			    w = pagewidth;
			    let yoh = Number(yo) + Number(h[2]);
			    p = bug(p);
		        if (Number(yoh) > Number(pageheight)) {
			        
			        std.printf("Offset %.4f !!! Page limit exceeded\n", yo);
			        value.lastoffsets2correct_pages.push(yo);
		            let page = "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\"\n\
                            xmlns:xlink=\"http://www.w3.org/1999/xlink\"\n\
                            width=\"" + w + "px\" height=\"" + pageheight + "px\">\n"
                            + "<rect width=\"100\%\" height=\"100\%\" fill=\"" +bgcolor + "\"/>"
		                    + out.join("\n") 
		                    + "\n</svg>";
		            
		            value.pages.push(page);
		            
	                if (user.errtxt)
		                tm.printErr(user.errtxt);
                    
                    yo = 0; 
                    
                    page_nr = page_nr + 1;
                    // std.printf("Start new page %d with offset %.4f and height %4.f\n",page_nr+1,yo, h[2]);
                    out = [];
                    var	i = p.indexOf(">");
                    out.push(p.slice(0, i) + "\n y=\"" + yo + "\"" + p.slice(i));
                    yo = Number(yo) + Number(h[2]);
		            
		        } else {
		            // std.printf("New line in page %d with offset %.4f and height %4.f\n",page_nr, yo, h[2]);
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
abc.tosvg(abc_file,header+content);

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
