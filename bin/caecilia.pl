#! /usr/bin/env perl

use strict;
use warnings;
use utf8;

use lib ('../lib');
use Caecilia::MyTk;
use File::Temp;
use Caecilia::Editor;
use Caecilia::Preview;
use Caecilia::Renderer;
use File::ShareDir 'dist_dir';

# Variable for filename
our $filename = '';

# Sharedir
our $share = dist_dir('Caecilia');
#our $share = ('../share');

our $tmpdir = File::Temp->newdir();

my $int = Caecilia::MyTk->new();
$int->lappend('auto_path', "$share");
$int->packageRequire('ctextAdvanced');
$int->packageRequire('Img');
$int->Declare('ctext', 'ctextAdvanced', -prefix => 'ctextAdvanced' );
$int->Declare('tkpCanvas', 'tkp::canvas', -prefix => 'tkpcan', -require => 'tkpath' );

# Theme settings
our $style = Tcl::Tk::ttkStyle->new($int);

$int->Eval('package require ttk::theme::Breeze');
#$int->Eval('package require ttk::theme::Arc');
#$int->packageRequire('ttk::theme::scidthemes');

$style->theme_use('Breeze');
#$int->tk_setPalette(
#    background => $style->lookup('.','-background'),
#    foreground => $style->lookup('.','-foreground'),
#    highlightColor => $style->lookup('.','-focuscolor') || $style->lookup('.','-highlightcolor') || $style->lookup('.','-selectbackground'),
#    selectBackground => $style->lookup('.','-selectbackground'),
#    selectForeground => $style->lookup('.','-selectforeground'),
#    activeBackground => $style->lookup('.','-selectbackground'),
#    activeForeground => $style->lookup('.','-selectforeground'),
#);
#my $font = $style->lookup('.','-font');
#$int->optionAdd('*font',$font);
#$int->optionAdd('*font',"Helvetica 16");

our $mw = $int->ttk_mainwindow();
$mw->geometry('960x600');
$mw->title('Caecilia - An editor for the ABC notation language');

$int->Eval("set ::tk::Priv(folderImage) [image create photo -file $share/breeze-icons/folder-blue.png]");
$int->Eval("set ::tk::Priv(updirImage) [image create photo -file $share/breeze-icons/go-parent-folder.png]");
$int->Eval("set ::tk::Priv(fileImage) [image create photo -file $share/breeze-icons/text-x-generic.png]");

# Initialization
Caecilia::Settings->init();
Caecilia::Settings->get_config();

create_menu();
create_toolbar();

my $paned = $mw->ttkPanedwindow(-orient => 'horizontal');
my $f_editor = $paned->ttkFrame(-width=>300);
my $f_preview = $paned->ttkFrame(-width=>300);
# fixed size of the frame in the paned at beginning
$int->call('pack','propagate',$f_editor,0);
$int->call('pack','propagate',$f_preview,0);

$paned->add($f_editor,-weight => 1);
$paned->add($f_preview,-weight => 1);

$paned->pack(-expand => 1, -fill => 'both');
our $editor = Caecilia::Editor->new($f_editor);

# Just a placeholder
our $preview = Caecilia::Preview->new($f_preview);


$int->MainLoop();

sub create_menu {
    my () = @_;
    
    $mw->optionAdd('*tearOff',0);
    
    my $menu = $mw->Menu(-relief => 'flat');
    $mw->configure(-menu => $menu );
    
    
    my $file = $menu->Menu(-relief => 'flat');
    $file->addCommand(-label => 'New        ', -command => \&new, -accelerator => 'Ctrl+N');
    $file->addCommand(-label => 'Open       ', -command => \&open_file, -accelerator => 'Ctrl+O');
    $file->addCommand(-label => 'Save       ', -command => \&save, -accelerator => 'Ctrl+S');
    $file->addCommand(-label => 'Save as        ', -command => \&save_as);
    $file->addCommand(-label => 'Quit       ', -command => sub {$mw->destroy()}, -accelerator => 'Ctrl+Q');
    
    $mw->bind('<Control-n>' => \&new);
    $mw->bind('<Control-o>' => \&open_file);
    $mw->bind('<Control-s>' => \&save);
    $mw->bind('<Control-q>' => sub {$mw->destroy()});
    
    my $edit = $menu->Menu(-relief => 'flat');
    $edit->addCommand(-label => 'Settings',  -accelerator => 'Ctrl+,',
        -command => sub { Caecilia::Settings::settings_cb( $mw); });
    $edit->addCommand(-label => 'Render', -accelerator => 'Ctrl+R',
        -command => sub { Caecilia::Renderer::render_dialog( $mw); });
    $edit->addCommand(-label => 'Preview        ', -command => \&preview_cb, -accelerator => 'Ctrl+P');
    $edit->addCommand(-label => 'Next Page      ', -command => \&next_page_cb, -accelerator => 'Ctrl+Right');
    $edit->addCommand(-label => 'Previous Page      ', -command => \&previous_page_cb, -accelerator => 'Ctrl+Left');
    
    $mw->bind('<Control-comma>' => sub { Caecilia::Settings::settings_cb( $mw); } );
    $mw->bind('<Control-r>' => sub { Caecilia::Renderer::render_dialog( $mw); } );
    $mw->bind('<Control-p>' => \&preview_cb);
    $mw->bind('<Control-Left>' => \&previous_page_cb);
    $mw->bind('<Control-Right>' => \&next_page_cb);
    
    my ($highlight, $currentline, $linenumbers) = (1,1,1);
    my $view = $menu->Menu(-relief => 'flat');
    $view->addCheckbutton(-label => 'Syntax Highlighting', 
    	-variable => \$highlight, 
    	-command => sub {
    			if ($highlight == 1) {$editor->highlight} 
    			else {$editor->clear_highlight}
    			}
	);
    $view->addCheckbutton(-label => 'Highlight Current Line', 
    	-variable => \$currentline,
    	-command => sub {
    			print "not implemented yet\n";
    			}
    	);
    $view->addCheckbutton(-label => 'Show Line Numbers', 
    	-variable => \$linenumbers,
    	-command => sub {
    			if ($linenumbers == 1) {$editor->tk->configure(-linemap =>1)} 
    			else {$editor->tk->configure(-linemap =>0)}
    			}
    	);
    
    
    my $help = $menu->Menu(-relief => 'flat');
    $help->addCommand(-label => 'About      ', -command => \&about);
    
    $menu->addCascade(-menu => $file, -label => 'File');
    $menu->addCascade(-menu => $edit, -label => 'Edit');
    $menu->addCascade(-menu => $view, -label => 'View');
    $menu->addCascade(-menu => $help, -label => 'Help');
}

sub create_toolbar {
    my $toolbar = $mw->ttkFrame()->pack(-fill => 'x');
    
    # Create icons
    my $icon_new = $toolbar->Photo(-file => "$share/breeze-icons/document-new.png");
    my $icon_open = $toolbar->Photo(-file => "$share/breeze-icons/document-open.png");
    my $icon_save = $toolbar->Photo(-file => "$share/breeze-icons/document-save.png");
    my $icon_save_as = $toolbar->Photo(-file => "$share/breeze-icons/document-save-as.png");
    my $icon_preview = $toolbar->Photo(-file => "$share/breeze-icons/preview.png");
    my $icon_previous = $toolbar->Photo(-file => "$share/breeze-icons/go-previous.png");
    my $icon_next = $toolbar->Photo(-file => "$share/breeze-icons/go-next.png");
    
    # Icon Buttons
    $toolbar->ttkButton(-text => 'New', -style => 'Toolbutton', -compound => 'left', -image => $icon_new,-command => \&new)
        ->pack(-side => 'left',-padx => '2px',-pady => '2px');
    $toolbar->ttkButton(-text => 'Open',-style => 'Toolbutton', -compound => 'left',-image => $icon_open, -command => \&open_file)
        ->pack(-side => 'left',-padx => '2px');
    $toolbar->ttkButton(-text => 'Save',-style => 'Toolbutton', -compound => 'left',-image => $icon_save, -command => \&save)
        ->pack(-side => 'left',-padx => '2px');
    $toolbar->ttkButton(-text => 'Save as',-style => 'Toolbutton', -compound => 'left',-image => $icon_save_as, -command => \&save_as)
        ->pack(-side => 'left',-padx => '2px');
    $toolbar->ttkButton(-text => 'Preview',-style => 'Toolbutton', -compound => 'left',-image => $icon_preview, -command => \&preview_cb)
        ->pack(-side => 'left',-padx => '2px');
    $toolbar->ttkButton(-text => 'Previous Page',-style => 'Toolbutton', -compound => 'left',-image => $icon_previous, -command => \&previous_page_cb)
        ->pack(-side => 'left',-padx => '2px');
    $toolbar->ttkButton(-text => 'Next Page',-style => 'Toolbutton', -compound => 'left',-image => $icon_next, -command => \&next_page_cb)
        ->pack(-side => 'left',-padx => '2px');
}

sub new {
    # Note: warn_unsaved changes the modified property of $editor,
    # if user clicks "yes"
    warn_unsaved();
    $editor->set_text('') unless ( $editor->modified() );
}

sub open_file {
    # Note: warn_unsaved changes the modified property of $editor,
    # if user clicks "yes"
    warn_unsaved();
    my $file = $mw->getOpenFile() unless ( $editor->modified() );
    
    if ($file) {
        open my $fh, "<:encoding(utf-8)", $file;
		my $content="";
		while (my $line=<$fh>) {
			$content = $content . $line;
		}
		$editor->set_text($content);
		
		# Change the filename variable
		$filename = $file;
	}
}

sub save {
	
	# if $filenames[$n] is not already there
	if ($filename) {
		# get the content of the buffer, without hidden characters
		my $content = $editor->get_text();

		open my $fh, ">:encoding(utf8)", $filename;
		print $fh "$content";
		close $fh;
		
		$editor->modified(0);
	}
	else {
		# use save_as_callback
		save_as();
	}
}

sub save_as {
    my $file = $mw->getSaveFile(); 
    
    if ($file) {
        # get the content of the buffer, without hidden characters
		my $content = $editor->get_text();

		open my $fh, ">:encoding(utf8)", $file;
		print $fh "$content";
		close $fh;
		
		$editor->modified(0);
		
		# Change the filename variable
		$filename = $file;
	}
}

sub warn_unsaved {
    if ( $editor->modified() ) {
        my $yes = $mw->messageBox(
            -type => "yesno",
            -message => "Warning:\nUnsaved changes get lost",
            -icon => "question",
            -title => "Really close current document?");
            
        $editor->modified(0) if ($yes eq "yes");
    }
}

sub preview_cb {
    $preview->hide_logo();
    my $text = $editor->get_text();
    
    # delete old created files	
	my @filelist = <"$tmpdir/preview*">;
	foreach my $file (@filelist) {
		unlink $file;
    }
    
    Caecilia::Renderer::render(outfile => "$tmpdir/preview", outformat => '.svg (one page per file)', mode => 'preview');
    
    if (-e "$tmpdir/preview001.svg") {
		$preview->render_preview("$tmpdir/preview");
		my @filelist = <"$tmpdir/preview*.svg">;
		my $number_of_pages = @filelist;
		$preview->number_of_pages($number_of_pages);
    }
}

sub next_page_cb {
	$preview->next_page();
	$preview->render_preview("$tmpdir/preview");
}

sub previous_page_cb {
	$preview->previous_page();
	$preview->render_preview("$tmpdir/preview");
}

sub about {
    my $about_dialog = $mw->Toplevel();
    $about_dialog->title('About Caecilia');
    $about_dialog->transient('.');
    my $frame = $about_dialog->ttkFrame()->pack(-padx => 5,-pady => 5,-fill=> 'both',-expand => 1);
    my $logo = $frame->Photo('about-logo', -file => "$share/about.png");
    my $img = $frame->ttkLabel(-image => $logo)->pack();
    my $label = $frame->ttkLabel(-justify => "center",-font => 'Helvetica 10 bold', -text => "Caecilia")->pack;
    my $label2 = $frame->ttkLabel(-justify => "center", -text => "0.12\n A yet simple Editor for the ABC notation format\nwritten in perl/Tcl::Tk")->pack;
    my $frame2 = $about_dialog->ttkFrame(-height => 20, -borderwidth=>1)->pack(-fill=> 'x',-expand => 1);
    my $button = $frame2->ttkButton(-text => "Close",-command => sub {$about_dialog->destroy()})->pack(-side => "right",-padx => 5,-pady => 5);
    
    
}

package Tcl::Tk::Widget::tkpCanvas;
our @ISA = qw(Tcl::Tk::ttkWidget);

sub CanvasBind {
	my $self = shift;
    my $item = shift;
    $self->interp->call($self,'bind',$item,@_);
}

1;
