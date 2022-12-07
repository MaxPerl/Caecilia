package Caecilia;

use local::lib;

use 5.006001;
use strict;
use warnings;
use utf8;

use pEFL;
use pEFL::Elm;
use pEFL::Evas;
use pEFL::Ecore;

use File::ShareDir 'dist_dir';
use File::Temp;

use File::HomeDir;
use File::Basename;
use Cwd qw(abs_path getcwd);

use Caecilia::Tab;
use Caecilia::Tabs;
use Caecilia::Entry;
use Caecilia::Search;
use Caecilia::Settings;
use Caecilia::Preview;
use Caecilia::Renderer;

use Text::Tabs;

our $AUTOLOAD; 

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

our $VERSION = '0.20';

our $SELF;

sub new {
	my ($class) = @_;
	our $share = dist_dir('Caecilia');
	
	my $obj = {
		tabs => undef,
		entry => undef,
		preview => undef,
		current_tab => 0,
		settings => undef,
		share_dir => $share,
		tmpdir => File::Temp->newdir(),
		elm_mainwindow => undef,
		elm_menu => undef,
		elm_toolbar => undef,
		# Statusbar
		elm_src_highlight_check => undef,
		elm_linewrap_check => undef,
		elm_linecolumn_label => undef};
	bless($obj,$class);
	
	return $obj;
}

sub init_ui {
	my ($self) = @_;
	
	pEFL::Elm::init($#ARGV, \@ARGV);
	pEFL::Elm::Config::scroll_accel_factor_set(1);
	pEFL::Elm::policy_set(ELM_POLICY_QUIT, ELM_POLICY_QUIT_LAST_WINDOW_CLOSED);
	
	my $win = pEFL::Elm::Win->util_standard_add("Caecilia", "Caecilia");
	$win->smart_callback_add("delete,request" => \&on_exit, $self);
	$self->elm_mainwindow($win);
	
	pEFL::Ecore::EventHandler->add(ECORE_EVENT_KEY_DOWN, \&key_down, $self);
	
	# Create new icon
	my $ic = pEFL::Elm::Icon->add($win);
	$ic->file_set($self->share_dir . "/caecilia-icon.png", undef );
	$ic->size_hint_aspect_set(EVAS_ASPECT_CONTROL_VERTICAL, 1, 1);
	$win->icon_object_set($ic);
	
	# Create settings instance
	my $settings = Caecilia::Settings->new($self);
	$self->settings($settings);
	
	my $renderer = Caecilia::Renderer->new($self);
	$self->renderer($renderer);
	
	my $config = $settings->load_config();
	$tabstop = $config->{tabstops} || 4; 
	
	my $box = pEFL::Elm::Box->add($win);
	$box->size_hint_weight_set(EVAS_HINT_EXPAND, EVAS_HINT_EXPAND);
	$box->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$win->resize_object_add($box);
	$box->show();
	
	$self->add_toolbar($win,$box);
	
	my $tabs = Caecilia::Tabs->new($self,$box);
	$self->tabs($tabs);
	
	my $panes = pEFL::Elm::Panes->add($box);
	$panes->size_hint_weight_set(EVAS_HINT_EXPAND, EVAS_HINT_EXPAND);
	$panes->size_hint_align_set(EVAS_HINT_FILL, EVAS_HINT_FILL);
	
	my $entry = Caecilia::Entry->new($self,$panes);
	$self->entry($entry);
	
	my $preview = Caecilia::Preview->new($self,$panes);
	$self->preview($preview);
	
	$box->pack_end($panes);
	$panes->show();
	
	$self->add_menu($win,$box);
	
	$self->add_statusbar($box);
	
	if (@ARGV) {
	
		my $i = 0;
		foreach my $fname (@ARGV) {
			my $filename = abs_path($fname);
			$self->open_file($filename);
		}
	}
	else {
		my $tab = Caecilia::Tab->new(filename => "", id => 0);
		$self->current_tab($tab);
		$self->tabs()->push_tab($tab);
	}
	
	$win->resize(900,600);
	$win->show();

	pEFL::Elm::run();
	pEFL::Elm::shutdown();
}


sub _button_click_cb {
	my ($data, $button, $event_info) = @_;
	my $item = $data->elm_toolbar_item;
	$item->del();
}


##################################
# Menu
##################################
sub add_menu {
	my ($self, $win, $box) = @_;
	
	my $menu = $win->main_menu_get();
	
	my $file_it = $menu->item_add(undef,undef,"File",undef, undef);
	
	$menu->item_add($file_it,"document-new","New",sub {$self->tabs->_new_tab_cb},undef);
	$menu->item_add($file_it,"document-open","Open",\&_open_cb,$self);
	$menu->item_add($file_it,"document-save","Save",\&save,$self);
	$menu->item_add($file_it,"document-save-as","Save as",\&save_as,$self);
	$menu->item_add($file_it,"document-export","Export",sub {my $r = $self->renderer(); $r->show_dialog()},undef);
	$menu->item_add($file_it,"document-close","Close",\&_close_tab_cb,$self->tabs());
	$menu->item_add($file_it,"window-close","Exit",\&on_exit,$self);
	
	
	my $edit_it = $menu->item_add(undef,undef,"Edit",undef, undef);
	
	my $entry = $self->entry();
	$menu->item_add($edit_it,"edit-undo","Undo",\&Caecilia::Entry::undo,$self->entry);
	$menu->item_add($edit_it,"edit-redo","Redo",\&Caecilia::Entry::redo,$self->entry);
	$menu->item_add($edit_it,"edit-cut","Cut",sub {$self->entry->elm_entry->selection_cut()},undef);
	$menu->item_add($edit_it,"edit-copy","Copy",sub {$self->entry->elm_entry->selection_copy()},undef);
	$menu->item_add($edit_it,"edit-paste","Paste",sub {$self->entry->elm_entry->selection_paste()},undef);
	$menu->item_add($edit_it,"preferences-other","Settings",sub {my $s = $self->settings(); $s->show_dialog($self)},undef);
	
	
	my $doc_it = $menu->item_add(undef,undef,"View",undef, undef);
	my $linewrap_check = pEFL::Elm::Check->add($menu); $linewrap_check->state_set(1); 
	my $linewrap_it = $menu->item_add($doc_it,"document-new","Line wrap",\&toggle_linewrap,$self);
	$linewrap_it->content_set($linewrap_check);
	$self->elm_linewrap_check($linewrap_check);

	my $src_highlight_check = pEFL::Elm::Check->add($menu); $src_highlight_check->state_set(1); 
	my $src_highlight_it = $menu->item_add($doc_it,"document-new","Source highlight",\&toggle_src_highlight,$self);
	$src_highlight_it->content_set($src_highlight_check);
	$self->elm_src_highlight_check($src_highlight_check);
	
	$menu->item_add($doc_it,"view-restore","Preview",\&preview_cb,$self);
	$menu->item_add($doc_it,"go-next","Next Page",\&next_page_cb,$self);
	$menu->item_add($doc_it,"go-previous","Previous Page",\&previous_page_cb,$self);
	
	
	my $help_it = $menu->item_add(undef,undef,"Help",undef, undef);
	my $about_it = $menu->item_add($help_it,"help-about","About",\&about,$self);
	# Create new icon
	my $ic = pEFL::Elm::Icon->add($win);
	$ic->file_set($self->share_dir . "/caecilia-icon.png", undef );
	$ic->size_hint_aspect_set(EVAS_ASPECT_CONTROL_VERTICAL, 1, 1);
	$about_it->content_set($ic);
	
	# Keyboard shortcuts
	#pEFL::Ecore::EventHandler->add(ECORE_EVENT_KEY_DOWN, \&key_down, $self);
}

##################################
# Toolbar
##################################
sub add_toolbar {
	my ($self, $win, $box) = @_;
	
	my $f = pEFL::Elm::Frame->add($box);
	$f->style_set("pad_small");
	$f->size_hint_align_set(EVAS_HINT_FILL, 0);
	$f->size_hint_weight_set(EVAS_HINT_EXPAND, 0);
	$f->show();$box->pack_end($f);
	
	my $tabsbar = pEFL::Elm::Toolbar->add($f);
	$tabsbar->homogeneous_set(1);
	$tabsbar->select_mode_set(ELM_OBJECT_SELECT_MODE_DISPLAY_ONLY);
	$tabsbar->shrink_mode_set(ELM_TOOLBAR_SHRINK_MENU);
	$tabsbar->size_hint_align_set(EVAS_HINT_FILL, 0);
	$tabsbar->size_hint_weight_set(EVAS_HINT_EXPAND, 0);
	$tabsbar->align_set(0);
	$tabsbar->icon_size_set(14);
	$f->content_set($tabsbar);
	
	$tabsbar->item_append("document-new","New",sub {$self->tabs->_new_tab_cb},undef);
	$tabsbar->item_append("document-open","Open",\&_open_cb,$self);
	$tabsbar->item_append("document-save","Save",\&save,$self);
	$tabsbar->item_append("document-save-as","Save as",\&save_as,$self);
	my $it_sep = $tabsbar->item_append(undef,undef,undef,undef);
	$it_sep->separator_set(1);
	$tabsbar->item_append("document-export","Export",sub {my $r = $self->renderer(); $r->show_dialog()},undef);
	my $it_sep2 = $tabsbar->item_append(undef,undef,undef,undef);
	$it_sep2->separator_set(1);
	$tabsbar->item_append("view-restore","Preview",\&preview_cb,$self);
	$self->{prev_btn} = $tabsbar->item_append("go-previous","Previous Page",\&previous_page_cb,$self);
	$self->{next_btn} = $tabsbar->item_append("go-next","Next Page",\&next_page_cb,$self);
	my $it_sep3 = $tabsbar->item_append(undef,undef,undef,undef);
	$it_sep3->separator_set(1);
	$tabsbar->item_append("preferences-other","Settings",sub {my $s = $self->settings(); $s->show_dialog($self)},undef);
	
	$self->elm_toolbar($tabsbar);
	$tabsbar->show();
}

sub next_page_cb {
	my ($self) = @_;
	my $preview = $self->preview();
	$preview->next_page();
	$preview->render_preview($self->tmpdir . "/preview");
}

sub previous_page_cb {
	my ($self) = @_;
	my $preview = $self->preview();
	$preview->previous_page();
	$preview->render_preview($self->tmpdir . "/preview");
}

sub preview_cb {
	my ($self) = @_;
	
	my $en = $self->entry->elm_entry();
	my $text = $en->entry_get();
	
	
	# delete old created files	
	my $tmpdir = $self->tmpdir();
	my @filelist = <"$tmpdir/preview*">;
	foreach my $file (@filelist) {
		unlink $file;
	}
	
	my $r = $self->renderer();
	$r->render(outfile => "$tmpdir/preview", outformat => '.svg (one page per file)', mode => 'preview');

	if (-e "$tmpdir/preview001.svg") {
		my @filelist = <"$tmpdir/preview*.svg">;
		my $number_of_pages = @filelist;
		$self->preview->page(1);
		$self->preview->number_of_pages($number_of_pages);
		$self->preview->render_preview("$tmpdir/preview");
	}
	else {
		warn "$tmpdir/preview001.svg doesn*t exist\n";
	}
	
}

sub key_down {
	my ($self, $type, $event) = @_;
	my $e = pEFL::ev_info2obj($event, "pEFL::Ecore::Event::Key");
	my $keyname = $e->keyname();
	my $modifiers = $e->modifiers();
	
	if ($modifiers == 2 && $keyname eq "n") {
		$self->tabs->_new_tab_cb();
	}
	elsif ($modifiers == 2 && $keyname eq "o") {
		_open_cb($self);
	}
	elsif ($modifiers == 2 && $keyname eq "p") {
		preview_cb($self);
	}
	#elsif ($modifiers == 2 && $keyname eq "Up") {
	#	$self->elm_toolbar->focus_set(1);
	#	next_page_cb($self);
	#}
	#elsif ($modifiers == 2 && $keyname eq "Down") {
	#	$self->elm_toolbar->focus_set(1);
	#	previous_page_cb($self);	
	#}
	elsif ($modifiers == 2 && $keyname eq "s") {
		save($self);
	}
	elsif ($modifiers == 3 && $keyname eq "s") {
		save_as($self);
	}
	elsif ($modifiers == 2 && $keyname eq "w") {
		_close_tab_cb($self->tabs);
	}
	elsif ($modifiers == 2 && $keyname eq "q") {
		on_exit($self);
	}
	elsif ($modifiers == 2 && $keyname eq "z") {
		Caecilia::Entry::undo($self->entry);
	}
	elsif ($modifiers == 2 && $keyname eq "y") {
		Caecilia::Entry::redo($self->entry);
	}
	
	return ECORE_CALLBACK_DONE;
} 

sub on_exit {
	my ($self) = @_;
	
	my @unsaved = grep $_->changed() > 0, @{$self->tabs->tabs()};
	
	if (@unsaved) {
		my $popup = pEFL::Elm::Popup->add($self->elm_mainwindow());
		
		$popup->part_text_set("default","Warning: There are some unsaved files. Close anyway?");
		
		my $btn1 = pEFL::Elm::Button->add($popup);
		$btn1->text_set("Okay");
		$btn1->smart_callback_add("clicked" => sub {pEFL::Elm::exit});
		
		my $btn2 = pEFL::Elm::Button->add($popup);
		$btn2->text_set("Cancel");
		$btn2->smart_callback_add("clicked" => sub {$popup->del});
		
		$popup->part_content_set("button1", $btn1);
		$popup->part_content_set("button2", $btn2);
		
		$popup->show();
	}
	else {
		pEFL::Elm::exit();
	}
}

sub file_cb {
	my ($self) = @_;
	
	my $fs_win = pEFL::Elm::Win->add($self->elm_mainwindow(), "Open a file", ELM_WIN_BASIC);
	$fs_win->focus_highlight_enabled_set(1);
	$fs_win->autodel_set(1);
	
	my $vbox = pEFL::Elm::Box->add($fs_win);
	$vbox->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
	$vbox->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$vbox->show();
	$fs_win->resize_object_add($vbox);
	
	my $fs = pEFL::Elm::Fileselector->add($fs_win);
	
	my $path; my $filename;
	if ($self->current_tab->filename) { 
		(undef, $path, undef) = fileparse( $self->current_tab->filename );
		$filename = $self->current_tab->filename;
	}
	else { 
		$path = getcwd || File::HomeDir->my_home;
	}
	$fs->path_set($path);
	$fs->selected_set($filename) if ($filename);
	$fs->mime_types_filter_append("text/vnd.abc","*.abc");
	$fs->mime_types_filter_append("*","All files");
	$fs->expandable_set(0);
	$fs->expandable_set(0);
	$fs->size_hint_weight_set(EVAS_HINT_EXPAND,EVAS_HINT_EXPAND);
	$fs->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$fs->show();
	
	$vbox->pack_end($fs);
	#$fs_win->resize_object_add($fs);
	$fs_win->resize(600,400);
	$fs_win->show();
	
	return $fs;
}

sub about {
	my ($self) = @_;
	
	my $popup = pEFL::Elm::Popup->add($self->elm_mainwindow());
	$popup->text_set("<b>Caecilia</b><br/><br/>A simple Editor for the ABC notation format written in Perl/pEFL");
	
	# popup buttons
	my $btn = pEFL::Elm::Button->add($popup);
	$btn->text_set("Close");
	$popup->part_content_set("button1",$btn);
	$btn->smart_callback_add("clicked",sub {$_[0]->del},$popup);
	
	# popup show should be called after adding all the contents and the buttons
	# of popup to set the focus into popup's contents correctly.
	$popup->show();
	
}

sub _open_cb {
	my ($self) = @_;
	
	my $fs = $self->file_cb;
	
	$fs->smart_callback_add("done", \&_fs_open_done, $self);
	$fs->smart_callback_add("activated", \&_fs_open_done, $self);
	$fs->smart_callback_add("selected,invalid", \&_fs_invalid, $self);
}

sub save_as {
	my ($self) = @_;
	
	my $fs = $self->file_cb;
	
	$fs->is_save_set(1);
	$fs->smart_callback_add("done", \&_fs_save_done, $self);
	$fs->smart_callback_add("activated", \&_fs_save_done, $self);
	$fs->smart_callback_add("selected,invalid", \&_fs_invalid, $self);
}

sub save {
	my ($self) = @_;
	
	my $current_tab = $self->current_tab();
	my $elm_it = $current_tab->elm_toolbar_item();
	my $en = $self->entry->elm_entry();
	my $filename = $current_tab->filename || "";
	
	if ($filename) {
		# get the content of the buffer, without hidden characters
		my $content = $en->entry_get();
		$content = pEFL::Elm::Entry::markup_to_utf8($content);
		
		# umlauts etc. must be converted
		$content = Encode::decode("utf-8",$content);
		
		# Here we mustn't decode entities
		# otherwise for example &lt; is saved as <
		#decode_entities($content);
		
		
		open my $fh, ">:encoding(UTF-8)", $filename or die "Could not save file: $filename\n";
		print $fh "$content";
		close $fh;
		
		$current_tab->changed(0);
		my ($name,$dirs,$suffix) = fileparse($filename); 
		$elm_it->part_text_set("default",$name);
	}
	else {
		# use save_as_callback
		$self->save_as();
	}
	
}

sub _fs_invalid {
	my ($self, $obj, $ev_info) = @_;
	print "Warn: File doesn't exist\n";
}

sub _fs_save_done {
	my ($self, $obj, $ev_info) = @_;
	
	my $selected = pEFL::ev_info2s($ev_info);
	
	my $fs_win = $obj->top_widget_get;
	$fs_win->del();
	
	return unless($selected);
	
	my $current_tab = $self->current_tab();
	$current_tab->filename($selected);
	
	$self->save();
}


sub open_file {
	my ($self, $selected) = @_;
	
	my $config = $self->settings->load_config();
	
	if (-e $selected && -f $selected && -r $selected) {
		
		my $en = $self->entry->elm_entry();
		
		# Open file
		open my $fh, "<:encoding(utf-8)", $selected;
		my $content=""; my $line;
		while (my $line=<$fh>) {
			$content = $content . $line;
		}
	
		close $fh;
		
		if ($config->{expand_tabs}) {
			$content = expand($content);	
		}
		elsif ($config->{unexpand_tabs}) {
			$content = unexpand($content);
		}
		
		$content = pEFL::Elm::Entry::utf8_to_markup($content);
		
		# Change the filename variable and/or open a new tab
		my ($name,$dirs,$suffix) = fileparse($selected); 
		
		my $tab = $self->current_tab();
		
		if ( (scalar(@{$self->tabs->tabs}) == 1) && (!$tab->filename) && ($tab->id == 0) && ($tab->changed() == 0)) { 
			$tab->filename($selected);
		}
		else {
			if ($tab) {
				$tab->content($en->entry_get);
				$tab->cursor_pos($en->cursor_pos_get());
			}
			
			my $new_tab = Caecilia::Tab->new(filename => $selected, id => scalar( @{$self->tabs->tabs} ) );
			$self->current_tab($new_tab);
			$self->tabs()->push_tab($new_tab);
		}
	
		# change content of the entry
		
		# This seems to be already done by pEFL::Elm::Entry::utf8_to_markup
		#$content =~ s/\t/<tab\/>/g;
		#$content =~ s/\n/<br\/>/g;
		$en->entry_set($content);

		# Determ the input language 
		#$self->entry->determ_source_lang($selected);
		
		#rehighlight all
		$self->entry->rehighlight_all();
		
		# Workaround: Through inserting changed event is triggered
		$self->current_tab->changed(0);
		$self->current_tab->elm_toolbar_item->text_set($name);
		
		$en->cursor_pos_set(0);
	}
	else {
		warn "Could not open file $selected\n";
	}
}

sub _fs_open_done {
	my ($self, $obj, $ev_info) = @_;
	
	my $fs_win = $obj->top_widget_get;
	$fs_win->del();
	
	return unless($ev_info);
	
	my $selected = pEFL::ev_info2s($ev_info);
	
	$self->open_file($selected);
	
}

sub toggle_linewrap {
	my ($self, $obj, $ev) = @_;
	my $check = $self->elm_linewrap_check();
	
	my $entry = $self->entry();
	
	if ($entry->linewrap() eq "yes") {
		$entry->linewrap("no");
		$entry->elm_entry()->line_wrap_set(ELM_WRAP_NONE);
		
		$check->state_set(0);
	}
	else {
		$entry->linewrap("yes");
		$entry->elm_entry()->line_wrap_set(ELM_WRAP_WORD);
		
		$check->state_set(1);
	}
}

sub toggle_src_highlight {
	my ($self, $obj, $ev) = @_;
	my $check = $self->elm_src_highlight_check();
	
	my $current_tab = $self->current_tab();
	
	if ($current_tab->source_highlight() eq "yes") {
		$current_tab->source_highlight("no");
		$self->entry->clear_highlight();
		
		$check->state_set(0);
	}
	else {
		$current_tab->source_highlight("yes");
		$self->entry->rehighlight_all();
		
		$check->state_set(1);
	}
}

#################################
# Status Bar
##############################

sub add_statusbar {
	my ($self,$vbox) = @_;
	
	my $hbox = pEFL::Elm::Box->add($vbox);
	$hbox->padding_set(25,25);
	$hbox->horizontal_set(1);
	$hbox->size_hint_weight_set(EVAS_HINT_EXPAND,0);
	$hbox->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$vbox->pack_end($hbox);
	$hbox->show();
	
	my $separator = pEFL::Elm::Separator->add($hbox);
	$separator->horizontal_set(1);
	$separator->size_hint_weight_set(EVAS_HINT_EXPAND,0);
	$separator->size_hint_align_set(EVAS_HINT_FILL,EVAS_HINT_FILL);
	$hbox->pack_end($separator);
	$separator->show();
	
	my $line_column_label = pEFL::Elm::Label->add($hbox);
	$line_column_label->text_set("Line: 1 Column: 0");
	$line_column_label->show(); 
	$hbox->pack_end($line_column_label);
	$self->elm_linecolumn_label($line_column_label);
	
	my $separator2 = pEFL::Elm::Separator->add($hbox);
	$separator2->horizontal_set(1);
	$hbox->pack_end($separator2);
	$separator2->show();
}

######################
# Accessors 
#######################

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~ m/tabs|entry|settings|renderer|share_dir|tmpdir|current_tab|preview|elm_mainwindow|elm_menu|elm_toolbar|elm_src_highlight_check|elm_linewrap_check|elm_linecolumn_label/;
	
	my $attrib = $AUTOLOAD;
	$attrib =~ s/.*://;
	
	my $oldval = $self->{$attrib};
	$self->{$attrib} = $newval if $newval;
	
	return $oldval;
}

sub DESTROY {

}


# Preloaded methods go here.

1;
__END__

=head1 NAME

Caecilia

=head1 DESCRIPTION

A simple Editor with Syntax Highlighting, a preview function and click-to-note feature for the ABC notation format (http://abcnotation.com/) written with perl/pEFL

=head1 SEE ALSO

L<pEFL Perl module|pEFL>

L<ABC Notation website|http://abcnotation.com/>

L<ABC plus website|http://abcplus.sourceforge.net/>

=head1 AUTHOR

Maximilian Lika, E<lt>perlmax@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
