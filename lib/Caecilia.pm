package Caecilia;

use 5.006000;
use strict;
use warnings;

use utf8;
use Gtk3;
use Glib('TRUE','FALSE');

use Caecilia::Editor;
use Caecilia::Preview;

use File::Temp;
use File::ShareDir 'dist_dir';

require Exporter;

our @ISA = qw(Exporter Gtk3::ApplicationWindow);

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

our $VERSION = '0.06';


# Preloaded methods go here.

sub new {
	my $window = shift @_;
	my ($app) = shift @_;
	
	# Create the tmp dir
	my $tmpdir = File::Temp->newdir();
	my $sharedir = dist_dir('Caecilia');	
	
	# variable for filename
	my $filename = "";
	
	# Create the windows
	$window = bless Gtk3::ApplicationWindow->new($app);
	$window->set_title('Caecilia - An editor for the ABC notation language');
	$window->set_default_size(900,600);
	$window->set_border_width(5);
	my $icon = Gtk3::Gdk::Pixbuf->new_from_file("$sharedir/caecilia-icon.png");
	$window->set_icon($icon);
	
	# Create the grid that contains all elements
	my $grid = Gtk3::Grid->new();
	$grid->set_column_spacing(10);
	
	# Create the Editor and Preview 
	my $paned = Gtk3::Paned->new('horizontal');
	#$paned->set_position(500);
	my $editor = Caecilia::Editor->new();
	my $preview = Caecilia::Preview->new('editor' => $editor);
	$paned->pack1($editor->{view}, TRUE, TRUE);
	$paned->pack2($preview->{view},TRUE,TRUE);
	
	# Create the toolbar with GtkBuilder and the toolbar.ui file
	my $toolbar_ui_file = "$sharedir/toolbar.ui";
	# For development
	#my $toolbar_ui_file = "../share/toolbar.ui";
	my $builder = Gtk3::Builder->new();
	$builder->add_from_file($toolbar_ui_file) or die "tollbar.ui file not found!";
	my $toolbar = $builder->get_object('toolbar');
	
	# Get the buttons
	my $new_button = $builder->get_object('new_button');
	my $save_button = $builder->get_object('save_button');
	my $save_as_button = $builder->get_object('save_as_button');
	my $open_button = $builder->get_object('open_button');
	my $preview_button = $builder->get_object('preview_button');
	my $zoom_in_button = $builder->get_object('zoom_in_button');
	my $zoom_out_button = $builder->get_object('zoom_out_button');
	my $next_page_button = $builder->get_object('next_page_button');
	my $previous_page_button = $builder->get_object('previous_page_button');
	
	# Create the Windows actions
	my $new_action = Glib::IO::SimpleAction->new('new', undef);
	$new_action->signal_connect('activate'=> sub {$window->new_cb(shift, $editor, \$filename);});
	$window->add_action($new_action);
	
	my $save_action = Glib::IO::SimpleAction->new('save', undef);
	$save_action->signal_connect('activate'=> sub {$window->save_cb(shift, $editor, \$filename);});
	$window->add_action($save_action);
	
	my $save_as_action = Glib::IO::SimpleAction->new('save_as', undef);
	$save_as_action->signal_connect('activate'=> sub {$window->save_as_cb(shift, $editor, \$filename);});
	$window->add_action($save_as_action);
	
	my $open_action = Glib::IO::SimpleAction->new('open', undef);
	$open_action->signal_connect('activate'=> sub {$window->open_cb(shift, $editor, \$filename);});
	$window->add_action($open_action);
	
	my $preview_action = Glib::IO::SimpleAction->new('preview', undef);
	$preview_action->signal_connect('activate'=>sub {$window->preview_cb(shift,$editor, $preview, $tmpdir);});
	$window->add_action($preview_action);
	
	my $zoom_in_action = Glib::IO::SimpleAction->new('zoom_in', undef);
	$zoom_in_action->signal_connect('activate'=> sub {$window->zoom_in_cb(shift, $preview);});
	$window->add_action($zoom_in_action);
	
	my $zoom_out_action = Glib::IO::SimpleAction->new('zoom_out', undef);
	$zoom_out_action->signal_connect('activate'=> sub {$window->zoom_out_cb(shift, $preview);});
	$window->add_action($zoom_out_action);
	
	my $next_page_action = Glib::IO::SimpleAction->new('next_page', undef);
	$next_page_action->signal_connect('activate'=> sub {$window->next_page_cb(shift, $preview, $tmpdir);});
	$window->add_action($next_page_action);
	
	my $previous_page_action = Glib::IO::SimpleAction->new('previous_page', undef);
	$previous_page_action->signal_connect('activate'=> sub {$window->previous_page_cb(shift, $preview, $tmpdir);});
	$window->add_action($previous_page_action);
	
	# Attach content to the grid
	$grid->attach($toolbar, 0,0,1,1);
	$grid->attach($paned, 0,1,1,1);
	$grid->show_all();
	
	$window->add($grid);
	return $window;
}

sub new_cb {
	my ($self, $action, $editor, $filename_ref) = @_;
	
	if ($editor->changed_status()) {
		$self->warn_unsaved('new', $editor, $filename_ref);
	}
	else {
		$editor->set_text("");
		$$filename_ref = "";
		$editor->changed_status(0);
	}
}

# callback function for SAVE
sub save_cb {
	my ($self, $action, $editor, $filename_ref) = @_;
	my $filename = $$filename_ref;
	
	# if $filenames[$n] is not already there
	if ($filename) {
		# get the content of the buffer, without hidden characters
		my $content = $editor->get_text();

		open my $fh, ">:encoding(utf8)", $filename;
		print $fh "$content";
		close $fh;
		
		$editor->changed_status(0);
	}
	else {
		# use save_as_callback
		$self->save_as_cb($action, $editor, $filename_ref);
	}
}

sub save_as_cb {
	my ($window, $action, $editor, $filename_ref) = @_;
	
	# create a filechooserdialog to save:
	# the arguments are: title of the window, parent_window, action,
	# (buttons, response)
	my $save_dialog = Gtk3::FileChooserDialog->new("Pick a file", 
							$window, 
							"save", 
							("gtk-cancel", "cancel",
							"gtk-save", "accept"));
	# the dialog will present a confirmation dialog if the user types a file name
	# that already exists
	$save_dialog->set_do_overwrite_confirmation(TRUE);
	# dialog always on top of the textview window
	$save_dialog->set_modal(TRUE);

	if ($$filename_ref) {
	# With the following code line we make the opened file preselected!
	$save_dialog->select_filename($$filename_ref);
	}

	# connect the dialog to the callback function save_response_cb
	$save_dialog->signal_connect("response" => sub {
		return save_response_cb(shift, shift, $editor, $filename_ref);
        });

	# show the dialog
	$save_dialog->show();
}

# Callback Function for the response of the save-as and save dialog 
# (= saving the file!)
sub save_response_cb {
	my ($dialog, $response_id, $editor, $filename_ref) = @_;
	
	# if response id is "ACCEPTED" (the button "Open" has been clicked)
	if ($response_id eq "accept") {
		# Erhalte den Filename
		my $filename = $dialog->get_filename();
		# get the bcontent of the buffer, without hidden characters
		my $content = $editor->get_text();
		open my $fh, ">:encoding(utf8)", $filename;
		print $fh "$content";
		close $fh;
		$editor->changed_status(0);
		$$filename_ref=$filename;
		$dialog->destroy();
		}
	# if response id is "CANCEL" (the button "Cancel" has been clicked)
	elsif ($response_id eq "cancel") {
		$dialog->destroy();
		}
}

sub open_cb {
	my ($window, $action, $editor, $filename_ref) = @_;
	
	if ($editor->changed_status()) {
		$window->warn_unsaved('new', $editor, $filename_ref);
	}
	else {
		# create a filechooserdialog to open:
		# the arguments are: title of the window, parent_window, action
		# (buttons, response)
		my $open_dialog = Gtk3::FileChooserDialog->new("Pick a file", 
						$window,
						"open",
						("gtk-cancel", "cancel", 
						"gtk-open", "accept"));

		# not only local files can be selected in the file selector
		$open_dialog->set_local_only(FALSE);

		# dialog always on top of the textview window
		$open_dialog->set_modal(TRUE);

		# connect the dialog with the callback function open_response_cb()
		$open_dialog->signal_connect("response" => \&open_response_cb, [$editor, $filename_ref]);
	
		# show the dialog
		$open_dialog->show();
		
	}
}
	
# callback function for the resonse of the open_dialog
sub open_response_cb {
	my ($dialog, $response_id, $args) = @_;
	my $open_dialog = $dialog;
	
	# if response id is "ACCEPTED" (the button "Open" has been clicked)
	if ($response_id eq "accept") {
		my $editor = $args->[0];
		my $filename_ref = $args->[1];
		
		# $filenames[$n] is the file that we get from the FileChooserDialog
		my $filename = $open_dialog->get_filename();
		
		open my $fh, "<:encoding(utf-8)", $filename;
		my $content="";
		while (my $line=<$fh>) {
			$content = $content . $line;
		}
		
		$editor->set_text($content);
		$editor->changed_status(0);
		$$filename_ref=$filename;
		
		$dialog->destroy();
		}
	# if response id is "CANCEL" (the button "Cancel" has been clicked)
	elsif ($response_id eq "cancel") {
		$dialog->destroy();
		}
	}

sub preview_cb {
	my ($self, $action,$editor, $preview, $dir) = @_;
	my $text = $editor->get_text();
	
	# delete old created files	
	my @filelist = <"$dir/preview*">;
	foreach my $file (@filelist) {
		unlink $file;
	}
	
	# create new files for preview	
	open my $fh, ">:encoding(utf8)", "$dir/preview.abc";
	print $fh "$text";
	close $fh;
	
	system("abcm2ps -q -A -O $dir/preview.abc -c -v $dir/preview.abc");
	
	$preview->render_preview("$dir/preview");
	@filelist = <"$dir/preview*.svg">;
	my $number_of_pages = @filelist;
	$preview->number_of_pages($number_of_pages);
}

sub zoom_in_cb {
	my ($self, $action,$preview) = @_;
	return $preview->zoom_in();
}

sub zoom_out_cb {
	my ($self, $action,$preview) = @_;
	return $preview->zoom_out();
}

sub next_page_cb {
	my ($self, $action, $preview, $tmpdir) = @_;
	$preview->next_page();
	$preview->render_preview("$tmpdir/preview");
}

sub previous_page_cb {
	my ($self, $action, $preview, $tmpdir) = @_;
	$preview->previous_page();
	$preview->render_preview("$tmpdir/preview");
}

sub warn_unsaved {
	my ($window, $from, $editor, $filename_ref) = @_;
	if ($from eq 'open') {
		my $messagedialog = Gtk3::MessageDialog->new($window,
												'modal',
												'warning',
												'ok_cancel',
												'You have unsaved content that will be lost by opening another file. Open anyway?');
		$messagedialog->signal_connect('response' => \&warn_unsaved_response, [$window,$from, $editor, $filename_ref]);
		$messagedialog->show();
	}
	elsif ($from eq 'new') {
		my $messagedialog = Gtk3::MessageDialog->new($window,
												'modal',
												'warning',
												'ok_cancel',
												'You have unsaved content that will be lost by creating a new file. Create a new file anyway?');
		$messagedialog->signal_connect('response' => \&warn_unsaved_response, [$from,$window, $editor, $filename_ref]);
		$messagedialog->show();
	}
}

sub warn_unsaved_response	{
	my ($self, $response_id, $args) = @_;
	my $from = $args->[0];
	my $window = $args->[1];
	my $editor = $args->[2];
	my $filename_ref = $args->[3];
	# We need to change the changed_status 
	$editor->changed_status(0);
	
	if ($response_id eq 'ok') {		
		$self->destroy;
		
		# Note that open_cb is a callback function that was originally called by a Glib::IO::Simple::Action
		# object. there is the second argument the SimpleAction parameter (here undef)
		# okay this code is not really understandable without explantation. Sorry ;-) 
		open_cb($window, undef, $editor, $filename_ref) if ($from eq 'open');
		new_cb($window, undef, $editor, $filename_ref) if ($from eq 'new');
	}
	else {
		$self->destroy;
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
