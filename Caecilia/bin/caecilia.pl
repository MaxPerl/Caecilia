#!/usr/bin/env perl

# Binding for the Gio API
BEGIN {
	use Glib::Object::Introspection;
	Glib::Object::Introspection->setup(
		basename => 'Gio',
		version => '2.0',
		package => 'Glib::IO');
}

use strict;
use warnings;

use Gtk3;
use Glib('TRUE', 'FALSE');
use Caecilia;
use Caecilia::Settings;
use Encode;
use File::ShareDir 'dist_dir';

my $app = Gtk3::Application->new('app.c', 'non-unique');

$app->signal_connect('startup' => \&_init);
$app->signal_connect('open' => \&_open_cb);
$app->signal_connect('activate'=> \&_build_ui);
$app->signal_connect('shutdown'=>\&_cleanup);

$app->run();

exit;


# The CALLBACK FUNCTIONS to the APP-SIGNALS
sub _init {
	my ($app) = @_;
	
	# Create the AppMenu
	my $menu = Glib::IO::Menu->new();
	$menu->append('Settings', 'app.settings');
	$menu->append('About', 'app.about');
	$menu->append('Quit', 'win.quit');
	$app->set_app_menu($menu);
	
	# Create the MenuBar
	my $sharedir = dist_dir('Caecilia');
	my $builder = Gtk3::Builder->new();
	$builder->add_from_file("$sharedir/menubar.ui") or die 'Could not find menubar.ui';
	
	my $menubar = $builder->get_object('menubar');
	$app->set_menubar($menubar);
	
	my $about_action = Glib::IO::SimpleAction->new('about', undef);
	$about_action->signal_connect('activate'=> \&about_cb, $app);
	$app->add_action($about_action);
	
	my $settings_action = Glib::IO::SimpleAction->new('settings', undef);
	$settings_action->signal_connect('activate'=> sub {my $window= $app->get_active_window(); Caecilia::Settings::settings_cb($window);});
	$app->add_action($settings_action);
	
	###############
	# init configuration
	###############
	Caecilia::Settings->init();
	Caecilia::Settings->get_config();

}

sub _build_ui {
	my ($app) = @_;
	my $window = Caecilia->new($app);
	$window->show_all();
}

sub open_cb {
	print "@_\n";
}
sub _cleanup {
	my ($app) = @_;
	print "Terminating ...\n";
}

##############################
# call back function for the APP Actions
###############################
sub about_cb {
	my ($action, $parameter,$app) = @_;
	# a Gtk3::AboutDialog
	my $aboutdialog = Gtk3::AboutDialog->new();
	$aboutdialog->set_transient_for($app->get_active_window());
	my $share = dist_dir('Caecilia');
	my $logo = Gtk3::Gdk::Pixbuf->new_from_file_at_scale("$share/caecilia-logo.png", 280,-1, TRUE);
	$aboutdialog->set_logo($logo);

	# lists of authors and documenters (will be used later)
	my @authors = ('Maximilian Lika');
	my @documenters = ('Maximilian Lika');

	# we fill in the aboutdialog
	$aboutdialog->set_program_name('Caecilia');
	$aboutdialog->set_version($Caecilia::VERSION);
	$aboutdialog->set_comments("A yet simple Editor for the ABC notation format\n written with perl/Gtk3");
	$aboutdialog->set_copyright(
		"Copyright \xa9 2016 Maximilian Lika");
	# important: set_authors and set_documenters need an array ref!
	# with a normal array it doesn't work!	
	$aboutdialog->set_authors(\@authors);
	$aboutdialog->set_documenters(\@documenters);
	my $license = 	"This library is free software; you can redistribute it and/or modify\n". 
					"it under the same terms as Perl itself, either Perl version 5.20.2 \n". 
					"or, at your option, any later version of Perl 5 you may have available.\n".
					"This module is distributed in the hope that it will be useful, but \n".
					"WITHOUT ANY WARRANTY; without even the implied warranty of\n".
					"MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.";
	$aboutdialog->set_license("$license");
	$aboutdialog->set_website('http://github/MaxPerl/Caecilia');
	$aboutdialog->set_website_label('GitHub Repository of Caecilia');

	# to close the aboutdialog when 'close' is clicked we connect
	# the 'response' signal to on_close
	$aboutdialog->signal_connect('response'=>\&close_about);
	# show the aboutdialog
	$aboutdialog->show();
	}

# destroy the aboutdialog
sub close_about {
	my ($aboutdialog) = @_;
	$aboutdialog->destroy();
	}
