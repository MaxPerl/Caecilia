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
use Convert::Color;

use Text::Tabs;

our @ISA = qw(Exporter);

our $AUTOLOAD;

sub new {
	my ($class, $app, %opts) = @_;
	
	# Get index
	
	my $obj = {
		app => $app,
		config => load_config(undef),
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
	$settings_win->resize_object_add($container); $container->show();
	
	my $tb = pEFL::Elm::Toolbar->add($container);
	$tb->homogeneous_set(0);
	$tb->shrink_mode_set(ELM_TOOLBAR_SHRINK_SCROLL);
	$tb->select_mode_set(ELM_OBJECT_SELECT_MODE_ALWAYS);
	$tb->align_set(0.0);
	$tb->horizontal_set(0);
	$tb->size_hint_weight_set(0.0,EVAS_HINT_EXPAND);
	$tb->size_hint_align_set(0.0,EVAS_HINT_FILL);
	$container->pack($tb,0,0,1,5); $tb->show();

	$self->elm_toolbar($tb);

	my $naviframe = pEFL::Elm::Naviframe->add($settings_win);
	_expand_widget($naviframe);
	$container->pack($naviframe,1,0,4,5); $naviframe->show();
	
	my $settings_general_it = $naviframe->item_push("",undef,undef,$self->_settings_general_create($naviframe),undef);
	$settings_general_it->title_enabled_set(0,0);
	my $settings_preview_it = $naviframe->item_push("",undef,undef,$self->_settings_preview_create($naviframe),undef);
	$settings_preview_it->title_enabled_set(0,0);
	my $settings_midi_it = $naviframe->item_push("",undef,undef,$self->_settings_midi_create($naviframe),undef);
	$settings_midi_it->title_enabled_set(0,0);
	my $settings_appearance_it = $naviframe->item_push("",undef,undef,$self->_settings_appearance_create($naviframe),undef);
	$settings_appearance_it->title_enabled_set(0,0);
	my $settings_abcm2ps_it =$naviframe->item_push("",undef,undef,$self->_settings_abcm2ps_create($naviframe),undef);
	$settings_abcm2ps_it->title_enabled_set(0,0);
	my $settings_tabulator_it = $naviframe->item_push("",undef,undef,$self->_settings_tabulator_create($naviframe),undef);
	$settings_tabulator_it->title_enabled_set(0,0);
	
	my $tab_item0 = $tb->item_append("preferences-other","General",\&_settings_category_cb, $settings_general_it);
	my $tab_item1 = $tb->item_append("view-restore","Preview",\&_settings_category_cb, $settings_preview_it);
	my $tab_item2 = $tb->item_append("media-playback-start","Midi",\&_settings_category_cb, $settings_midi_it);
	my $tab_item3 = $tb->item_append("preferences-desktop-font","Appearance",\&_settings_category_cb, $settings_appearance_it);
	my $tab_item4 = $tb->item_append("applications-multimedia","abcm2ps Options",\&_settings_category_cb, $settings_abcm2ps_it);
	my $tab_item5 = $tb->item_append("applications-development","Tabulator",\&_settings_category_cb, $settings_tabulator_it);

	$tab_item0->selected_set(1);
	
	$naviframe->show();
	$settings_win->resize(600,400);
	
	$settings_win->show();
	
	return $settings_win;
}

sub _settings_category_cb {
	my ($it,$obj,$ev) = @_;
	$it->promote();
	
	#my $tit = pEFL::ev_info2obj($ev,"ElmToolbarItemPtr");
	#$tit->selected_set(1);
}

sub _add_buttons {
	my ($self,$table,$row, $width) = @_;
	
	$width = $width || 2;
	my $btn_bx = pEFL::Elm::Box->add($table);
	_expand_widget_x($btn_bx);
	$btn_bx->horizontal_set(1);
	$btn_bx->show(); $table->pack($btn_bx,0,$row,$width,1);
	
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

sub _settings_general_create {
	my ($self,$parent) = @_;
	
	my $config = $self->config();
	
	my $scroller = pEFL::Elm::Scroller->add($parent);
	
	my $box = pEFL::Elm::Box->add($parent);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($parent);
	$frame->text_set("General settings");
	$frame->part_content_set("default",$scroller);
	_expand_widget($frame);
	$frame->show();
	
	my $table = pEFL::Elm::Table->add($parent);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	_add_header($table,0,"Path to abcm2ps", 1);
	
	my $abcm2ps_path_en = pEFL::Elm::Entry->add($table);
	$abcm2ps_path_en->entry_set($config->{abcm2ps_path} || "abcm2ps");
	$abcm2ps_path_en->scrollable_set(1);
	$abcm2ps_path_en->single_line_set(1);
	$abcm2ps_path_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($abcm2ps_path_en);
	$abcm2ps_path_en->show(); $table->pack($abcm2ps_path_en,0,1,2,1);
	
	_add_header($table,2,"Path to scores",1);
	
	my $scores_path_en = pEFL::Elm::Entry->add($table);
	$scores_path_en->entry_set($config->{scores_path} || File::HomeDir->my_documents);
	$scores_path_en->scrollable_set(1);
	$scores_path_en->single_line_set(1);
	$scores_path_en->cnp_mode_set(ELM_CNP_MODE_PLAINTEXT());
	_expand_widget($scores_path_en);
	$scores_path_en->show(); $table->pack($scores_path_en,0,3,2,1);
	
	my $sep = pEFL::Elm::Separator->add($table);
	_expand_widget($sep);
	$sep->show(); $table->pack($sep,0,4,2,4);


	# Save important widgets
	$self->elm_abcm2ps_path_en($abcm2ps_path_en);
	$self->elm_scores_path_en($scores_path_en);
	
	$self->_add_buttons($table,8);
	
	$scroller->content_set($box);
	$scroller->show();
	return $frame;
}

sub _settings_preview_create {
	my ($self,$parent) = @_;
	
	my $config = $self->config();
	
	my $scroller = pEFL::Elm::Scroller->add($parent);
	
	my $box = pEFL::Elm::Box->add($parent);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($parent);
	$frame->text_set("Preview settings");
	$frame->part_content_set("default",$scroller);
	_expand_widget($frame);
	$frame->show();
	
	my $table = pEFL::Elm::Table->add($parent);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	_add_header($table,0,"Page format", 1);
	
	my $pageheight_label = pEFL::Elm::Label->new($table);
	$pageheight_label->text_set("Page height (cm)");
	$pageheight_label->show(); $table->pack($pageheight_label,0,1,1,1);
	
	my $pageheight_spinner = pEFL::Elm::Spinner->add($table);
	$pageheight_spinner->label_format_set("%1.1f");
	$pageheight_spinner->min_max_set(0,1000); $pageheight_spinner->interval_set(10);
	$pageheight_spinner->editable_set(1);
	$pageheight_spinner->value_set($config->{preview_pageheight} || 29.7);
	_expand_widget_x($pageheight_spinner);
	$pageheight_spinner->show(); $table->pack($pageheight_spinner,1,1,1,1);
	
	my $pagewidth_label = pEFL::Elm::Label->new($table);
	$pagewidth_label->text_set("Page width (cm)");
	$pagewidth_label->show(); $table->pack($pagewidth_label,0,2,1,1);
	
	my $pagewidth_spinner = pEFL::Elm::Spinner->add($table);
	$pagewidth_spinner->label_format_set("%1.1f");
	$pagewidth_spinner->min_max_set(0,1000); $pagewidth_spinner->interval_set(10);
	$pagewidth_spinner->editable_set(1);
	$pagewidth_spinner->value_set($config->{preview_pagewidth} || 21.0);
	_expand_widget_x($pagewidth_spinner);
	$pagewidth_spinner->show(); $table->pack($pagewidth_spinner,1,2,1,1);
	
	_add_header($table,3,"Scaling", 1);
	
	my $pscale_label = pEFL::Elm::Label->new($table);
	$pscale_label->text_set("Page scale");
	$pscale_label->show(); $table->pack($pscale_label,0,4,1,1);
	
	my $preview_scale_spinner = pEFL::Elm::Spinner->add($table);
	$preview_scale_spinner->label_format_set("%1.2f");
	$preview_scale_spinner->step_set(0.05); $preview_scale_spinner->interval_set(0.2);
	$preview_scale_spinner->min_max_set(0.00,10.00);
	$preview_scale_spinner->value_set($config->{preview_scale} || 1.0);
	_expand_widget_x($preview_scale_spinner);
	$preview_scale_spinner->show(); $table->pack($preview_scale_spinner,1,4,1,1);
	
	# Save important widgets
	$self->elm_pageheight_spinner($pageheight_spinner);
	$self->elm_pagewidth_spinner($pagewidth_spinner);
	$self->elm_preview_scale_spinner($preview_scale_spinner);
	
	
	$self->_add_buttons($table,15);
	
	$scroller->content_set($box);
	$scroller->show();
	return $frame;

}

sub _settings_midi_create {
	my ($self,$parent) = @_;
	
	my $config = $self->config();
	
	my $scroller = pEFL::Elm::Scroller->add($parent);
	
	my $box = pEFL::Elm::Box->add($parent);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($parent);
	$frame->text_set("Preview settings");
	$frame->part_content_set("default",$scroller);
	_expand_widget($frame);
	$frame->show();
	
	my $table = pEFL::Elm::Table->add($parent);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	_add_header($table, 0, "MIDI tuning",1);
	
	my $text = "The MIDI part of Caecilia is in an early, rudimentary state. One problem is time sync". 
		"with the follow-midi-bars. The follow mid function works on base of a time-position event handling" .
		"If there are problems you can try to change the tick value for the Abc to MIDI process".
		"higher values lead to a faster playback, whereas lower values slow down the playback" .
		"The default value is 50 which seems a fitting setting for Midi files created with abc2svg";
	my $label = pEFL::Elm::Label->new($table);
	$label->text_set("$text");
	$label->line_wrap_set(2);
	_expand_widget_x($label);
	$label->show(); $table->pack($label,0,1,3,1);
	
	_add_label($table,2,"MIDI ticks", 1);
		
	my $midi_ticks_spinner = pEFL::Elm::Slider->add($table);
	$midi_ticks_spinner->size_hint_align_set(EVAS_HINT_FILL,0.5);
	$midi_ticks_spinner->size_hint_weight_set(EVAS_HINT_EXPAND,0.0);
	$midi_ticks_spinner->unit_format_set("%1.0f");
	$midi_ticks_spinner->indicator_format_set("%1.0f");
	$midi_ticks_spinner->min_max_set(0,100);
	$midi_ticks_spinner->step_set(1);
	$midi_ticks_spinner->value_set($config->{midi_ticks} || 50);
	$midi_ticks_spinner->show(); $table->pack($midi_ticks_spinner,1,2,2,1);
	
	# Save important widgets
	$self->elm_midi_ticks_slider($midi_ticks_spinner);
	
	$self->_add_buttons($table,4,3);
	
	$scroller->content_set($box);
	$scroller->show();
	return $frame;
	
}

sub _settings_appearance_create {
	my ($self,$parent) = @_;
	
	my $config = $self->config();
	
	my $scroller = pEFL::Elm::Scroller->add($parent);
	
	my $box = pEFL::Elm::Box->add($parent);
	$box->horizontal_set(0);
	_expand_widget($box);
	$box->show();
	
	my $frame = pEFL::Elm::Frame->add($parent);
	$frame->text_set("Appearance settings");
	$frame->part_content_set("default",$scroller);
	_expand_widget($frame);
	$frame->show();
	
	my $table = pEFL::Elm::Table->add($parent);
	_expand_widget($table);
	$table->padding_set(10,10);
	$table->show(); $box->pack_end($table);
	
	_add_header($table,0,"Color Palette",1);
	
	my $palette_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($palette_combo);
	my $palette = $config->{color_palette} || "system";
	$palette_combo->text_set($palette);
	
	my $itc = pEFL::Elm::GenlistItemClass->new();
	$itc->item_style("default");
	$itc->text_get(sub {return $_[0];});
	
	$palette_combo->item_append($itc,"system",undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	
	my @palettes = pEFL::Elm::Config::palette_list_pv();
	foreach my $p (@palettes) {
		$palette_combo->item_append($itc,$p,undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$palette_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$palette_combo->show(); $table->pack($palette_combo,0,1,2,1);
	
	_add_header($table,3,"Font Settings",1);
	
	my $font_combo = pEFL::Elm::Combobox->add($table);
	_expand_widget_x($font_combo);
	my $font = $config->{font} || "Font";
	$font_combo->text_set($font);
	
	my $itc2 = pEFL::Elm::GenlistItemClass->new();
	$itc2->item_style("default_style");
	$itc2->text_get(sub {return $_[0];});
	my @fonts = $box->evas_get->font_available_list_pv();
	my @mono = ();
	foreach my $font (@fonts) {
		# is not important in the ABC notation format, isn't it?
		if ($font =~ m/[mM]ono/) {
			$font =~ s/:style.*$//;
			$font =~ s/,.*$//;
			push @mono, $font if (!grep /^$font$/, @mono);
			
		}
	}
	@mono = sort(@mono);
	foreach my $f (@mono) {
		my $font = $f;
		$font =~ s/ //g;
		$font_combo->item_append($itc2,"<font=$font>$f</font>",undef,ELM_GENLIST_ITEM_NONE,undef,undef);
	}
	$font_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$font_combo->show(); $table->pack($font_combo,0,4,2,1);
	
	_add_label($table,5,"Font Size");
		
	my $font_size_spinner = pEFL::Elm::Slider->add($table);
	$font_size_spinner->size_hint_align_set(EVAS_HINT_FILL,0.5);
	$font_size_spinner->size_hint_weight_set(EVAS_HINT_EXPAND,0.0);
	$font_size_spinner->unit_format_set("%1.0f");
	$font_size_spinner->indicator_format_set("%1.0f");
	$font_size_spinner->min_max_set(6,24);
	$font_size_spinner->step_set(1);
	$font_size_spinner->value_set($config->{font_size} || 10.0);
	$font_size_spinner->show(); $table->pack($font_size_spinner,1,5,1,1);
	
	my $font_color = $config->{font_color} || [157,157,157];
	_add_color_setting($table,6,{text => "Font Color", color => $font_color, 
		settings => $self,key => "font_color", win => $self->app->elm_mainwindow()});
	
	_add_header($table,7,"Source Highlight",1);
	
	my $header_color = $config->{header_color} || [157,157,157];
	_add_color_setting($table,8,{text => "Headers", color => $header_color, 
		settings => $self,key => "header_color", win => $self->app->elm_mainwindow()});
	
	my $string_color = $config->{string_color} || [157,157,157];
	_add_color_setting($table,9,{text => "Lyrics/Strings", color => $string_color, 
		settings => $self,key => "string_color", win => $self->app->elm_mainwindow()});
	
	my $notes_color = $config->{notes_color} || [43,173,251];
	_add_color_setting($table,10,{text => "Notes", color => $notes_color, 
		settings => $self,key => "notes_color", win => $self->app->elm_mainwindow()});
	
	my $slurs_color = $config->{slurs_color} || [43,173,251];
	_add_color_setting($table,11,{text => "Slurs", color => $slurs_color, 
		settings => $self,key => "slurs_color", win => $self->app->elm_mainwindow()});
	
	my $deco_color = $config->{deco_color} || [203,49,155];
	_add_color_setting($table,12,{text => "Keywords", color => $deco_color, 
		settings => $self,key => "deco_color", win => $self->app->elm_mainwindow()});
	
	my $dir_color = $config->{directives_color} || [251,153,203];
	_add_color_setting($table,13,{text => "Directives", color => $dir_color, 
		settings => $self,key => "directives_color", win => $self->app->elm_mainwindow()});
	
	my $comments_color = $config->{comments_color} || [251,153,203];
	_add_color_setting($table,14,{text => "Comments", color => $comments_color, 
		settings => $self, key => "comments_color", win => $self->app->elm_mainwindow()});
		
	# Save important widgets
	$self->elm_palette_combo($palette_combo);
	$self->elm_font_size_slider($font_size_spinner);
	$self->elm_font_combo($font_combo);
	
	$self->_add_buttons($table,15);
	
	$scroller->content_set($box);
	$scroller->show();
	return $frame;
}

sub _settings_tabulator_create {
	my ($self,$parent) = @_;
	
	my $config = $self->config();
	
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
	$tabmode_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
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
	
	my $config = $self->config();
	
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
	
	_add_header($table,0,"Linebreak Options");
		
	my $autolinebreak_check = _add_checkoption($table,label => "Auto line break", 
		value => $config->{abcm2ps_autolinebreak}, row => 1);
	
	my ($breaknbars_check, $breaknbars_spinner) = _add_spin_with_check($table,
		value => $config->{abcm2ps_breaknbars}, label => "Break every n bars", row => 2, 
		min => 0, max => 100, step => 1, fmt => "%1.0f");
	
	##################
	# Output formatting
	###################
	_add_header($table,3,"Output formating");
	
	my ($scalefactor_check,$scalefactor_spinner) = _add_spin_with_check($table,
			value => $config->{abcm2ps_scalefactor}, label => "Set Scale Factor", row => 4,
			min => 0, max => 100, step => 0.1, fmt => "%1.2f");
	
	my ($staffwidth_check, $staffwidth_en) = _add_entry_with_check($table,
		value => $config->{abcm2ps_staffwidth}, label => "Set staff width (cm/in/pt)", row => 5,);
	
	my ($leftmargin_check, $leftmargin_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_leftmargin}, label => "Set left margin (cm/in/pt)", row => 6);
	
	my ($staffseparation_check, $staffseparation_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_staffseperation}, label => "Set staff separation (cm/in/pt)", row => 7);
	
	my ($maxshrink_check,$maxshrink_spinner) = _add_spin_with_check($table,
			value => $config->{abcm2ps_maxshrink}, label => "Set maximal shrinkage to", row => 8,
			min => 0, max => 1, step => 0.1, fmt => "%1.2f");
	
	my ($fmtfile_check, $fmtfile_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_formatfile}, label => "Read format file \"foo.fmt\"", row => 9);
	
	my ($fmtdir_check, $fmtdir_en) = _add_entry_with_check($table,
		value => $config->{abcms2ps_formatdirectory}, label => "Read format directory \"foo.fmt\"", row => 10);
		
	###############
	# Output Options
	###############
	
	_add_header($table, 11, "Output Options");
	
	my $landscape_check = _add_checkoption($table,
		value => $config->{abcm2ps_landscape}, label => "landscape mode", row => 12);
	
	my ($indentfirstline_check, $indentfirstline_en) = _add_entry_with_check( $table,
		value => $config->{abcm2ps_intentfirstline}, label => "indent first line (cm/in/pt)", row => 13);
	
	my $xrefnumbers_check = _add_checkoption($table,
		value => $config->{abcm2ps_xrefnumbers}, label => "Add xrefnumbers in titles", row => 14);
		
	my $nolyrics_check = _add_checkoption($table,
		value => $config->{abcm2ps_nolyrics}, label => "Don't output lyrics", row => 15);
		
	# PAGE NUMBERING OPTIONS
	my $pnlabel = pEFL::Elm::Label->new($table);
	$pnlabel->text_set("Page numbering mode");
	$pnlabel->size_hint_align_set(0,0);
	$pnlabel->show(); $table->pack($pnlabel,0,16,2,1);
	
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
	$pagenumbering_combo->smart_callback_add("item,pressed",\&Caecilia::MyElm::_combobox_item_pressed_cb, $frame);
	$pagenumbering_combo->show(); $table->pack($pagenumbering_combo,0,17,4,1);
	
	#$pagenumbering_combo->realized_items_update();
	#$itc->free();
	
	my $onetuneperpage_check = _add_checkoption($table,
		value => $config->{abcm2ps_onetuneperpage}, label => "Write one tune per page", row => 18);
		
	my $nosluringrace_check = _add_checkoption($table,
		value => $config->{abcm2ps_nosluringrace}, label => "no slur in grace notes", row => 19);
	
	
	my ($numbernbars_check, $numbernbars_spin) =_add_spin_with_check($table,
		value => $config->{abcm2ps_numbernbars}, label => "Number measures every n bars", row => 20,
		min => 0, max => 100, step => 1, fmt => "%1.0f"); 
		
	# ggf. TODO: toggle numbernbarsboxed_check, too, if numbernbars_check is changed
	my $numbernbarsboxed_check = _add_checkoption($table,
		value => $config->{abcm2ps_numbernbarsboxed}, label => "Display measures in a box", row => 21);
	
	my $flatbeams_check = _add_checkoption($table,
		value => $config->{abcm2ps_flatbeams}, label => "have fleatbeams", row => 22);
	
	# Save important widgets
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
	
	my $config = $self->config();
	
	################
	# General
	#################
	$config->{abcm2ps_path} = $self->elm_abcm2ps_path_en->entry_get();
	$config->{scores_path} = $self->elm_scores_path_en->entry_get();
	
	################
	# Preview
	#################
	my $pageheight_spinner = $self->elm_pageheight_spinner();
	my $pagewidth_spinner = $self->elm_pagewidth_spinner();
	my $preview_scale_spinner = $self->elm_preview_scale_spinner();
	
	$config->{preview_pageheight} = sprintf("%.1f",$pageheight_spinner->value_get());
	$config->{preview_pagewidth} = sprintf("%.1f",$pagewidth_spinner->value_get());
	$config->{preview_scale} = sprintf("%.2f",$preview_scale_spinner->value_get());
	
	################
	# MIDI
	#################
	my $midi_ticks_slider = $self->elm_midi_ticks_slider();
	$config->{midi_ticks} = sprintf("%.0f",$midi_ticks_slider->value_get());
	
	#################
	# Tabulator settings
	#################
	my $tabs_spinner = $self->elm_tabs_spinner();
	my $tabmode_combo = $self->elm_tabmode_combo();
	my $unexpand_check = $self->elm_unexpand_check();
	my $expand_check = $self->elm_expand_check();
	my $palette_combo = $self->elm_palette_combo();
	my $font_size_slider = $self->elm_font_size_slider();
	my $font_combo = $self->elm_font_combo();
	
	$config->{tabstops} = sprintf("%.0f",$tabs_spinner->value_get());
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
	# Appareance settings
	#################
	my $palette = $palette_combo->text_get() || "system";
	$config->{color_palette} = $palette;
	if ($palette ne "system") {
		pEFL::Elm::Config::palette_set($palette);
	} 
	
	my $font = pEFL::Elm::Entry::markup_to_utf8($font_combo->text_get()) || "Monospace";
	$font =~ s/ //g;
	$config->{font} = $font;
	
	$config->{font_size} = sprintf("%.0f",$font_size_slider->value_get());
	
	my $entry = $self->app->entry();
	my $en = $entry->elm_entry();
	
	my $font_size = $config->{font_size} || 10;
	
	$config->{font_color} = $config->{font_color} || [157,157,157];
	my $c = Convert::Color->new("rgb8:" . join(",",@{$config->{font_color}})); my $fcolor = "#".$c->hex;
	
	my $user_style = qq(DEFAULT='font=$font:style=Regular font_size=$font_size');
	my $w = $entry->_calc_em($user_style);
	
	$tabstop = $config->{tabstops} || 4;
	my $tabs = $w * $tabstop;
	
	$user_style = qq(DEFAULT='font=$font:style=Regular font_size=$font_size tabstops=$tabs color=$fcolor');
	$en->text_style_user_push($user_style);
	
	$config->{header_color} = $config->{header_color} || [157,157,157];
	$config->{string_color} = $config->{string_color} || [157,157,157];
	$config->{notes_color} = $config->{notes_color} || [43,173,251];
	$config->{slurs_color} = $config->{slurs_color} || [43,173,251];
	$config->{deco_color} = $config->{deco_color} || [203,49,155];
	$config->{directives_color} = $config->{directives_color} || [251,153,203];
	$config->{comments_color} = $config->{comments_color} || [251,153,203];
	
	_write_style_file($self, $config);
	
	$self->app->entry->rehighlight_all();
	
	######################
	# abcm2ps Settings
	######################
	$config->{abcm2ps_autolinebreak} = $self->elm_autolinebreak_check->state_get();
	$config->{abcm2ps_breaknbars} = sprintf("%.0f",_spinner_get($self->elm_breaknbars_spinner));
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
	$config->{abcm2ps_numbernbars} = sprintf("%.0f",_spinner_get($self->elm_numbernbars_spin));
	$config->{abcm2ps_numbernbarsboxed} = $self->elm_numbernbarsboxed_check->state_get();
	$config->{abcm2ps_flatbeams} = $self->elm_flatbeams_check->state_get();	
	
	$self->save_config($config);
	
	$self->elm_settings_win()->del();
	
	return
}

sub _write_style_file {
	my ($self, $conf) = @_;
	my $userdir = File::HomeDir->my_home . "/.caecilia"; 
	my $path = File::HomeDir->my_home . "/.caecilia/source-highlight/mystyle.style";
	
	# Convert Colors to HTML colors
	my $c = Convert::Color->new("rgb8:" . join(",",@{$conf->{notes_color}})); my $notes = "#".$c->hex;
	my $c2 = Convert::Color->new("rgb8:" . join(",",@{$conf->{string_color}}) ); my $string = "#".$c2->hex;
	my $c3 = Convert::Color->new("rgb8:" . join(",",@{$conf->{deco_color}}) ); my $deco = "#".$c3->hex;
	my $c4 = Convert::Color->new("rgb8:" . join(",",@{$conf->{comments_color}}) ); my $comments = "#".$c4->hex;
	my $c5 = Convert::Color->new("rgb8:" . join(",",@{$conf->{slurs_color}}) ); my $slurs = "#".$c5->hex;
	my $c6 = Convert::Color->new("rgb8:" . join(",",@{$conf->{header_color}}) ); my $header = "#".$c6->hex;
	my $c7 = Convert::Color->new("rgb8:" . join(",",@{$conf->{directives_color}}) ); my $directives = "#".$c7->hex;
	
	# Write style file
	open my $fh, ">:encoding(utf-8)", "$path" or die "Could not open $path: $!\n";
	# flock $fh, LOCK_EX;
	print $fh <<EOF;
keyword "$notes" ; 
string "$string" i ;
specialchar "$deco" b ; 
comment "$comments" i, noref; 
preproc "$header" b; 
symbol "$slurs" b ; 
function "$directives"; 
EOF

	close $fh;
	
	# Apply new Syntax Highlight
	my $h1 = Syntax::SourceHighlight->new("$userdir/source-highlight/myhtml.outlang"); 
	$self->app->entry->sh_obj($h1);
	$h1->setStyleFile("$userdir/source-highlight/mystyle.style");
	$h1->setOutputDir("$userdir/source-highlight");
	$h1->setDataDir("$userdir/source-highlight");
	$h1->setOptimize(1);
	
	my $lm = Syntax::SourceHighlight::LangMap->new("$userdir/source-highlight/lang.map"); 
	$self->app->entry->sh_langmap($lm);
	
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
		unless $AUTOLOAD =~m/::(app|config|elm_toolbar|elm_scores_path_en|elm_pageheight_spinner|elm_pagewidth_spinner|elm_preview_scale_spinner|elm_midi_ticks_slider|elm_palette_combo|elm_tabs_spinner|elm_tabmode_combo|elm_unexpand_check|elm_expand_check|elm_font_size_slider|elm_font_combo|elm_settings_win)|elm_abcm2ps_path_en|elm_autolinebreak_check|elm_breaknbars_spinner|elm_scalefactor_spinner|elm_staffwidth_en|elm_leftmargin_en|elm_staffseparation_en|elm_maxshrink_spinner|elm_fmtfile_en|elm_fmtdir_en|elm_landscape_check|elm_indentfirstline_en|elm_xrefnumbers_check|elm_nolyrics_check|elm_pagenumberig_combo|elm_onetuneperpage_check|elm_nosluringrace_check|elm_numbernbars_spin|elm_numbernbarsboxed_check|elm_flatbeams_check|$/;
	
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
