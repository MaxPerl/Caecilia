#!/usr/bin/env perl

use lib ('../lib');

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
use Encode;

my $app = Gtk3::Application->new('app.plabcedit', 'non-unique');

$app->signal_connect('startup' => \&_init);
$app->signal_connect('open' => \&_open_cb);
$app->signal_connect('activate'=> \&_build_ui);
$app->signal_connect('shutdown'=>\&_cleanup);

$app->run();

exit;


# The CALLBACK FUNCTIONS to the APP-SIGNALS
sub _init {
	my ($app) = @_;
	
	# Menu creation
	my $menu = Glib::IO::Menu->new();
	$menu->append('Quit','app.quit');
	$app->set_app_menu($menu);
	
	# Actions of the menu
	my $quit_action = Glib::IO::SimpleAction->new('quit', undef);
	$quit_action->signal_connect('activate'=> sub {$app->quit()});
	$app->add_action($quit_action);
	
}

sub _build_ui {
	my ($app) = @_;
	my $window = Caecilia->new($app);
	$window->signal_connect('delete_event' => sub {$app->quit()});
	$window->show_all();
}

sub open_cb {
	print "@_\n";
}
sub _cleanup {
	my ($app) = @_;
}
