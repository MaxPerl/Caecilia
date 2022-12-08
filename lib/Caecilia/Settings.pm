package Caecilia::Settings;

use 5.006001;
use strict;
use warnings;
use utf8;

require Exporter;

use pEFL::Elm;
use pEFL::Evas;

use Caecilia::MyElm ":all";

use YAML('Load', 'Dump');
use File::HomeDir;
use File::Path ('make_path');

use Text::Tabs;

our @ISA = qw(Exporter);

our $AUTOLOAD;

sub new {
	my ($class, $app, %opts) = @_;
	
	# Get index
	
	my $obj = {
		app => $app,
		};
	bless($obj,$class);
	
	return $obj;
}

sub show_dialog {
	my ($self) = @_;
	
	my $app = $self->app();
	
	my $settings_win = pEFL::Elm::Win->add($app->elm_mainwindow(), "Settings", ELM_WIN_BASIC);
	$settings_win->title_set("Settings");
	$settings_win->focus_highlight_enabled_set(1);
	$settings_win->autodel_set(1);
	$self->elm_settings_win($settings_win);
	
	my $bg = pEFL::Elm::Bg->add($settings_win);
	_expand_widget($bg);
	$bg->show(); $settings_win->resize_object_add($bg);
	
	my $container = pEFL::Elm::Table->add($settings_win);
	_expand_widget($container);
	$container->show(); $settings_win->resize_object_add($container);
	
	my $tb = pEFL::Elm::Toolbar->add($container);
	$tb->shrink_mode_set(ELM_TOOLBAR_SHRINK_SCROLL);
	$tb->select_mode_set(ELM_OBJECT_SELECT_MODE_ALWAYS);
	$tb->homogeneous_set(0);
	$tb->horizontal_set(0);
	$tb->align_set(0.0);
	$tb->size_hint_weight_set(0.0,EVAS_HINT_EXPAND);
	$tb->size_hint_align_set(0.0,EVAS_HINT_FILL);
	$tb->show(); $container->pack($tb,0,0,1,5);

	$self->elm_toolbar($tb);

	my $naviframe = pEFL::Elm::Naviframe->add($settings_win);
	_expand_widget($naviframe);
	$naviframe->show();
	$container->pack($naviframe,1,0,4,5);
	
	my $settings_appearance_it = $naviframe->item_push("",undef,undef,$self->_settings_appearance_create($naviframe),undef);
	$settings_appearance_it->title_enabled_set(0,0);
	my $settings_abcm2ps_it =$naviframe->item_push("",undef,undef,$self->_settings_abcm2ps_create($naviframe),undef);
	$settings_abcm2ps_it->title_enabled_set(0,0);
	my $settings_tabulator_it = $naviframe->item_push("",undef,undef,$self->_settings_tabulator_create($naviframe),undef);
	$settings_tabulator_it->title_enabled_set(0,0);
	
	my $tab_item = $tb->item_append("preferences-desktop-font","Appearance",\&_settings_category_cb, $settings_appearance_it);
	my $tab_item2 = $tb->item_append("media-playback-start","abcm2ps Options",\&_settings_category_cb, $settings_abcm2ps_it);
	my $tab_item3 = $tb->item_append("applications-development","Tabulator",\&_settings_category_cb, $settings_tabulator_it);
	
	$tab_item->selected_set(1);
	
	$settings_win->resize(500,400);
	
	$settings_win->show();
	
	return $settings_win;
}

sub _settings_category_cb {
	my ($it,$obj) = @_;
	$it->promote();
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
	
	# Callbacks
	$cancel_btn->smart_callback_add("clicked", sub { $self->elm_settings_win()->del(); }, undef );
	$ok_btn->smart_callback_add("clicked", \&save_settings, $self);
	
	return $btn_bx;
}

sub _settings_appearance_create {
	my ($self,$parent) = @_;
	
	my $config = $self->load_config();
	
	my $box = pEFL::Elm::Box->add($parent);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($parent);
	$frame->text_set("Appearance settings");
	$frame->part_content_set("default",$box);
	_expand_widget($frame);
	$frame->show();
	
	my $table = pEFL::Elm::Table->add($parent);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	my $font_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($font_combo);
	my $font = $config->{font} || "Font";
	$font_combo->text_set($font);
	
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default");
	$itc->text_get(sub {return $_[0];});
	my @fonts = $box->evas_get->font_available_list_pv();
	my @mono = ();
	foreach my $font (@fonts) {
		if ($font =~ m/[mM]ono/) {
			$font =~ s/:style.*$//;
			$font =~ s/,.*$//;
			push @mono, $font if (!grep /^$font$/, @mono);
			
		}
	}
	@mono = sort(@mono);
	foreach my $f (@mono) {
		$font_combo->item_append($itc,$f,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$font_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, undef);
	$font_combo->show(); $table->pack($font_combo,0,1,2,1);
	
	my $tabs_label = pEFL::Elm::Label->new($table);
	$tabs_label->text_set("Font size");
	$tabs_label->show(); $table->pack($tabs_label,0,2,1,1);
	
	my $font_size_spinner = pEFL::Elm::Slider->add($table);
	$font_size_spinner->size_hint_align_set(EVAS_HINT_FILL,0.5);
	$font_size_spinner->size_hint_weight_set(EVAS_HINT_EXPAND,0.0);
	$font_size_spinner->unit_format_set("%1.0f");
	$font_size_spinner->indicator_format_set("%1.0f");
	$font_size_spinner->min_max_set(6,24);
	$font_size_spinner->step_set(1);
	$font_size_spinner->value_set($config->{font_size} || 10.0);
	$font_size_spinner->show(); $table->pack($font_size_spinner,1,2,1,1);
		
	# Save important widgets
	$self->elm_font_size_slider($font_size_spinner);
	$self->elm_font_combo($font_combo);
	
	$self->_add_buttons($table,3);
	
	return $frame;
}

sub _settings_tabulator_create {
	my ($self,$parent) = @_;
	
	my $config = $self->load_config();
	
	my $box = pEFL::Elm::Box->add($parent);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($parent);
	$frame->text_set("Tabulator settings");
	$frame->part_content_set("default",$box);
	_expand_widget($frame);
	$frame->show();
	
	my $table = pEFL::Elm::Table->add($parent);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	my $tabs_label = pEFL::Elm::Label->new($table);
	$tabs_label->text_set("Tabstops");
	$tabs_label->show(); $table->pack($tabs_label,0,2,1,1);
	
	my $tabs_spinner = pEFL::Elm::Spinner->add($table);
	$tabs_spinner->value_set($config->{tabstops} || 4);
	_expand_widget_x($tabs_spinner);
	$tabs_spinner->show(); $table->pack($tabs_spinner,1,2,1,1);
	
	my $tabmode_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($tabmode_combo);
	my $tabmode = $config->{tabmode} || "Tabulator mode";
	$tabmode_combo->text_set($tabmode);
	# elm_object_part_content_set(hoversel, "icon", rect);
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default");
	$itc->text_get(sub {return $_[0];});
	$tabmode_combo->item_append($itc,"Add tabulators",undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	$tabmode_combo->item_append($itc,"Add whitespace",undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	$tabmode_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, undef);
	$tabmode_combo->show(); $table->pack($tabmode_combo,0,3,2,1);
	
	my $header2 = pEFL::Elm::Label->add($table);
	$header2->text_set("<b>Customize when opening a file</b>");
	$header2->size_hint_weight_set(EVAS_HINT_EXPAND,0);
	$header2->size_hint_align_set(0,0);
	#$header2->align_set(0.0);
	$header2->show(); $table->pack($header2,0,4,2,1);
	
	my $unexpand_check = pEFL::Elm::Check->add($table);
	_expand_widget_x($unexpand_check);
	$unexpand_check->text_set("Unexpand white space to tabs");
	$unexpand_check->state_set(1) if ($config->{unexpand_tabs});
	$unexpand_check->show(); $table->pack($unexpand_check,0,5,2,1);
	
	my $expand_check = pEFL::Elm::Check->add($table);
	_expand_widget_x($expand_check);
	$expand_check->text_set("Expand tabs to white space");
	$expand_check->state_set(1) if ($config->{expand_tabs});
	$expand_check->show(); $table->pack($expand_check,0,6,2,1);
	
	# Save important widgets
	$self->elm_tabs_spinner($tabs_spinner);
	$self->elm_tabmode_combo($tabmode_combo);
	$self->elm_unexpand_check($unexpand_check);
	$self->elm_expand_check($expand_check);
	
	$self->_add_buttons($table,7);
	
	return $frame;
}

sub _settings_abcm2ps_create {
	my ($self,$parent) = @_;
	
	my $config = $self->load_config();
	
	my $scroller = pEFL::Elm::Scroller->add($parent);
	
	my $box = pEFL::Elm::Box->add($parent);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($parent);
	$frame->text_set("abcm2ps settings");
	#$frame->part_content_set("default",$box);
	$frame->part_content_set("default",$scroller);
	_expand_widget($frame);
	$frame->show();
	
	
	my $table = pEFL::Elm::Table->add($parent);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	_add_header($table,0,"Path to abcm2ps");
	
	my $abcm2ps_path_en = pEFL::Elm::Entry->add($table);
	$abcm2ps_path_en->entry_set($config->{abcm2ps_path} || "abcm2ps");
	$abcm2ps_path_en->scrollable_set(1);
	$abcm2ps_path_en->single_line_set(1);
	$abcm2ps_path_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($abcm2ps_path_en);
	$abcm2ps_path_en->show(); $table->pack($abcm2ps_path_en,0,1,4,2);
	
	_add_header($table,4,"Linebreak Options");
		
	my $autolinebreak_check = _add_checkoption($table,label => "Auto line break", 
		value => $config->{abcm2ps_autolinebreak}, row => 5);
	
	my ($breaknbars_check, $breaknbars_spinner) = _add_spin_with_check($table,
		value => $config->{abcm2ps_breaknbars}, label => "Break every n bars", row => 6, 
		min => 0, max => 100, step => 1, fmt => "%1.0f");
	
	##################
	# Output formatting
	###################
	_add_header($table,7,"Output formating");
	
	my ($scalefactor_check,$scalefactor_spinner) = _add_spin_with_check($table,
			value => $config->{abcm2ps_scalefactor}, label => "Set Scale Factor", row => 8,
			min => 0, max => 100, step => 0.1, fmt => "%1.2f");
	
	my ($staffwidth_check, $staffwidth_en) = _add_entry_with_check($table,
		value => $config->{abcm2ps_staffwidth}, label => "Set staff width (cm/in/pt)", row => 9,);
	
	my ($leftmargin_check, $leftmargin_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_leftmargin}, label => "Set left margin (cm/in/pt)", row => 10);
	
	my ($staffseparation_check, $staffseparation_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_staffseperation}, label => "Set staff separation (cm/in/pt)", row => 11);
	
	my ($maxshrink_check,$maxshrink_spinner) = _add_spin_with_check($table,
			value => $config->{abcm2ps_maxshrink}, label => "Set maximal shrinkage to", row => 12,
			min => 0, max => 1, step => 0.1, fmt => "%1.2f");
	
	my ($fmtfile_check, $fmtfile_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_formatfile}, label => "Read format file \"foo.fmt\"", row => 13);
	
	my ($fmtdir_check, $fmtdir_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_formatdirectory}, label => "Read format directory \"foo.fmt\"", row => 14);
		
	###############
	# Output Options
	###############
	
	_add_header($table, 15, "Output Options");
	
	my $landscape_check = _add_checkoption($table,
		value => $config->{abcm2ps_landscape}, label => "landscape mode", row => 16);
	
	my ($indentfirstline_check, $indentfirstline_en) = _add_entry_with_check( $table,
		value => $config->{abcm2ps_intentfirstline}, label => "indent first line (cm/in/pt)", row => 17);
	
	my $xrefnumbers_check = _add_checkoption($table,
		value => $config->{abcm2ps_xrefnumbers}, label => "Add xrefnumbers in titles", row => 18);
		
	my $nolyrics_check = _add_checkoption($table,
		value => $config->{abcm2ps_nolyrics}, label => "Don't output lyrics", row => 19);
		
	# PAGE NUMBERING OPTIONS
	my $pnlabel = pEFL::Elm::Label->new($table);
	$pnlabel->text_set("Page numbering mode");
	$pnlabel->size_hint_align_set(0,0);
	$pnlabel->show(); $table->pack($pnlabel,0,20,2,1);
	
	my @pagenumberingmodes = ('off', 'left','right','even left, odd right','even right, odd left');
	my $pagenumbering_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($pagenumbering_combo);
	my $pagenumbering = $config->{abcm2ps_pagenumberingmode} || "off";
	$pagenumbering_combo->text_set($pagenumbering);
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default"); $itc->text_get(sub {return $_[0];});
	foreach my $mode (@pagenumberingmodes) {
		$pagenumbering_combo->item_append($itc,$mode,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$pagenumbering_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, undef);
	$pagenumbering_combo->show(); $table->pack($pagenumbering_combo,0,21,4,1);
	
	
	my $onetuneperpage_check = _add_checkoption($table,
		value => $config->{abcm2ps_onetuneperpage}, label => "Write one tune per page", row => 22);
		
	my $nosluringrace_check = _add_checkoption($table,
		value => $config->{abcm2ps_nosluringrace}, label => "no slur in grace notes", row => 23);
	
	
	my ($numbernbars_check, $numbernbars_spin) =_add_spin_with_check($table,
		value => $config->{abcm2ps_numbernbars}, label => "Number measures every n bars", row => 24,
		min => 0, max => 100, step => 1, fmt => "%1.0f"); 
		
	# ggf. TODO: toggle numbernbarsboxed_check, too, if numbernbars_check is changed
	my $numbernbarsboxed_check = _add_checkoption($table,
		value => $config->{abcm2ps_numbernbarsboxed}, label => "Display measures in a box", row => 25);
	
	my $flatbeams_check = _add_checkoption($table,
		value => $config->{abcm2ps_flatbeams}, label => "have fleatbeams", row => 26);
	
	# Save important widgets
	$self->elm_abcm2ps_path_en($abcm2ps_path_en);
	$self->elm_autolinebreak_check($autolinebreak_check);
	$self->elm_breaknbars_spinner($breaknbars_spinner);
	$self->elm_scalefactor_spinner($scalefactor_spinner);
	$self->elm_staffwidth_en($staffwidth_en);
	$self->elm_leftmargin_en($leftmargin_en);
	$self->elm_staffseparation_en($staffseparation_en);
	$self->elm_maxshrink_spinner($maxshrink_spinner);
	$self->elm_fmtfile_en($fmtfile_en);
	$self->elm_fmtdir_en($fmtdir_en);
	$self->elm_landscape_check($landscape_check);
	$self->elm_indentfirstline_en($indentfirstline_en);
	$self->elm_xrefnumbers_check($xrefnumbers_check);
	$self->elm_nolyrics_check($nolyrics_check);
	$self->elm_pagenumberig_combo($pagenumbering_combo);
	$self->elm_onetuneperpage_check($onetuneperpage_check);
	$self->elm_nosluringrace_check($nosluringrace_check);
	$self->elm_numbernbars_spin($numbernbars_spin);
	$self->elm_numbernbarsboxed_check($numbernbarsboxed_check);
	$self->elm_flatbeams_check($flatbeams_check);
	
	$self->_add_buttons($table,27);
	
	$scroller->content_set($box);
	$scroller->show();
	
	return $frame;
}

sub save_settings {
	my ($self, $obj, $ev) = @_;
	
	my $config = {};
	
	#################
	# Tabulator settings
	#################
	my $tabs_spinner = $self->elm_tabs_spinner();
	my $tabmode_combo = $self->elm_tabmode_combo();
	my $unexpand_check = $self->elm_unexpand_check();
	my $expand_check = $self->elm_expand_check();
	my $font_size_slider = $self->elm_font_size_slider();
	my $font_combo = $self->elm_font_combo();
	
	$config->{tabstops} = $tabs_spinner->value_get();
	$config->{tabmode} = $tabmode_combo->text_get();
	$config->{unexpand_tabs} = $unexpand_check->state_get();
	$config->{expand_tabs} = $expand_check->state_get();
	
	if ($tabmode_combo->text_get() eq "Add whitespace") {
		$self->app->entry->tabmode("whitespaces");
	}
	else {
		$self->app->entry->tabmode("tabs");
	}
	
	#################
	# Font settings
	#################
	my $font = $font_combo->text_get() || "Monospace";
	$font =~ s/ //g;
	$config->{font} = $font;
	
	$config->{font_size} = int($font_size_slider->value_get());
	
	my $entry = $self->app->entry();
	my $en = $entry->elm_entry();
	
	my $font_size = $config->{font_size} || 10;
	
	my $user_style = qq(DEFAULT='font=$font:style=Regular font_size=$font_size');
	my $w = $entry->_calc_em($user_style);
	
	$tabstop = $config->{tabstops} || 4;
	my $tabs = $w * $tabstop;
	
	$user_style = qq(DEFAULT='font=$font:style=Regular font_size=$font_size tabstops=$tabs');
	$en->text_style_user_push($user_style);
	
	#$self->app->entry->rehighlight_all();
	
	######################
	# abcm2ps Settings
	######################
	$config->{abcm2ps_path} = $self->elm_abcm2ps_path_en->entry_get();
	$config->{abcm2ps_autolinebreak} = $self->elm_autolinebreak_check->state_get();
	$config->{abcm2ps_breaknbars} = _spinner_get($self->elm_breaknbars_spinner);
	$config->{abcm2ps_scalefactor} = _spinner_get($self->elm_scalefactor_spinner);
	$config->{abcm2ps_staffwidth} = _en_get($self->elm_staffwidth_en);
	$config->{abcm2ps_leftmargin} = _en_get($self->elm_leftmargin_en);
	$config->{abcm2ps_staffseparation} = _en_get($self->elm_staffseparation_en);
	$config->{abcm2ps_maxshrink} = _spinner_get($self->elm_maxshrink_spinner);
	$config->{abcm2ps_fmtfile} = _en_get($self->elm_fmtfile_en);
	$config->{abcm2ps_fmtdir} = _en_get($self->elm_fmtdir_en);
	$config->{abcm2ps_landscape} = $self->elm_landscape_check->state_get();
	$config->{abcm2ps_indentfirstline} = _en_get($self->elm_indentfirstline_en);
	$config->{abcm2ps_xrefnumbers} = $self->elm_xrefnumbers_check->state_get();
	$config->{abcm2ps_nolyrics} = $self->elm_nolyrics_check->state_get();
	$config->{abcm2ps_pagenumbering} = $self->elm_pagenumberig_combo->text_get();
	$config->{abcm2ps_onetuneperpage} = $self->elm_onetuneperpage_check->state_get();
	$config->{abcm2ps_nosluringrace} = $self->elm_nosluringrace_check->state_get();
	$config->{abcm2ps_numbernbars} = _spinner_get($self->elm_numbernbars_spin);
	$config->{abcm2ps_numbernbarsboxed} = $self->elm_numbernbarsboxed_check->state_get();
	$config->{abcm2ps_flatbeams} = $self->elm_flatbeams_check->state_get();
	
	
	$self->save_config($config);
	
	$self->elm_settings_win()->del();
	
	return
}

sub _en_get {
	my ($en) = @_;
	return $en->disabled_get ? "" : $en->entry_get();
}

sub _spinner_get {
	my ($spinner) = @_;
	return $spinner->disabled_get ? "" : $spinner->value_get();
}

sub load_config {
	my $self = shift;
	
	my $path = File::HomeDir->my_home . "/.caecilia/config.yaml";
	
	if (-e $path) {
		open my $fh, "<:encoding(utf-8)", $path or die "Could not open $path: $!\n";
		#flock $fh, LOCK_SH;
		my $yaml ='';
		while (my $line = <$fh>) {$yaml .= $line}
		close $fh;
	
		return Load($yaml);
	}
	else {
		return {};
	}
}

sub save_config {
	my ($self, $config) = @_;
	
	my $path = File::HomeDir->my_home . "/.caecilia";
	
	unless (-e $path) {
		make_path $path or die "Could not create $path: $!";
	}
	
	open my $fh, ">:encoding(utf-8)", "$path/config.yaml" or die "Could not open $path: $!\n";
	# flock $fh, LOCK_EX;
	my $yaml = Dump($config);
	print $fh "$yaml";
	close $fh;
}

############################
# Accessors
############################

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/::(app|elm_toolbar|elm_tabs_spinner|elm_tabmode_combo|elm_unexpand_check|elm_expand_check|elm_font_size_slider|elm_font_combo|elm_settings_win)|elm_abcm2ps_path_en|elm_autolinebreak_check|elm_breaknbars_spinner|elm_scalefactor_spinner|elm_staffwidth_en|elm_leftmargin_en|elm_staffseparation_en|elm_maxshrink_spinner|elm_fmtfile_en|elm_fmtdir_en|elm_landscape_check|elm_indentfirstline_en|elm_xrefnumbers_check|elm_nolyrics_check|elm_pagenumberig_combo|elm_onetuneperpage_check|elm_nosluringrace_check|elm_numbernbars_spin|elm_numbernbarsboxed_check|elm_flatbeams_check|$/;
	
	my $attrib = $AUTOLOAD;
	$attrib =~ s/.*://;
	
	my $oldval = $self->{$attrib};
	$self->{$attrib} = $newval if defined($newval);
	
	return $oldval;
}

sub DESTROY {}


# Preloaded methods go here.

1;
__END__


=head1 NAME

Caecilia::Settings

=head1 DESCRIPTION

This is the Settings component of the Caecilia Appliation.

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut