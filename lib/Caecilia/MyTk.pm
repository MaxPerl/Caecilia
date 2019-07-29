package Caecilia::MyTk;

use strict;
use warnings;

require Exporter;
use Tcl::Tk;

our @ISA = qw(Exporter Tcl::Tk);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Tcl::Tk::ttk ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	load_ttk_widgets
	ttk_mainwindow
	ttkMainWindow
);

our $VERSION = '0.08';

sub ttk_mainwindow {
    # this is a window with path '.'
    my $interp = shift;
    load_ttk_widgets($interp);
    return $interp->widget('.', 'Tcl::Tk::Widget::MainWindow');
}

sub ttkMainWindow {
    my $interp = Tcl::Tk->new(@_);
    load_ttk_widgets($interp);
    $interp->mainwindow;
}

sub load_ttk_widgets {
	
	my $int = shift;
	my %widgets = (
		'ttkButton' => 'ttk::button',
		'ttkCheckbutton' => 'ttk::checkbutton',
		'ttkCombobox' => 'ttk::combobox',
		'ttkEntry' => 'ttk::entry',
		'ttkFrame' => 'ttk::frame',
		'ttkLabel' => 'ttk::label',
		'ttkLabelframe' => 'ttk::labelframe',
		'ttkMenubutton' => 'ttk::menubutton',
		'ttkNotebook' => 'ttk::notebook',
		'ttkPanedwindow' => 'ttk::panedwindow',
		'ttkProgressbar' => 'ttk::progressbar',
		'ttkRadiobutton'=> 'ttk::radiobutton',
		'ttkScale' => 'ttk::scale',
		'ttkScrollbar' => 'ttk::scrollbar',
		'ttkSeparator' => 'ttk::separator',
		'ttkSizegrip' => 'ttk::sizegrip',
		'ttkSpinbox' => 'ttk::spinbox',
		'ttkTreeview' => 'ttk::treeview',
		'ttkWidget' => 'ttk::widget'
	);
	
	foreach my $key (keys %widgets) {
		$int->Declare($key, $widgets{$key}, -prefix => lc($key) );
		
		# Override/Create some functions in the Tcl::Tk::Widgte::ttk* widget classes
		no strict 'refs';
		*{ "Tcl::Tk::Widget::".$key."::state" } = \&Tcl::Tk::ttkWidget::state;
	}
	
	{
		# Add ttkStyle* Compatibility with Tcl::pTk::Tile
		no strict 'refs';
		*{ "Tcl::Tk::Widget::ttkThemeNames" } = \&Tcl::Tk::ttkStyle::theme_names;
		*{ "Tcl::Tk::Widget::ttkThemeUse" } = \&Tcl::Tk::ttkStyle::theme_use;
		*{ "Tcl::Tk::Widget::ttkStyleLayout" } = \&Tcl::Tk::ttkStyle::layout;
		*{ "Tcl::Tk::Widget::ttkStyleElementOptions" } = \&Tcl::Tk::ttkStyle::element_options;
		*{ "Tcl::Tk::Widget::ttkStyleConfigure" } = \&Tcl::Tk::ttkStyle::configure;
		*{ "Tcl::Tk::Widget::ttkStyleLookup" } = \&Tcl::Tk::ttkStyle::lookup;
		*{ "Tcl::Tk::Widget::ttkStyleMap" } = \&Tcl::Tk::ttkStyle::map;
	}

}

sub AUTOLOAD {
	my $self = shift;
	#my ($method) = (our $AUTOLOAD) =~ /^Tcl::Tk::ttk::(\w+)$/ or
	my ($method) = (our $AUTOLOAD) =~ /^Caecilia::MyTk::(\w+)$/ or 
		die "Curious value at AUTOLOAD: $AUTOLOAD";
	
	# The Tcl::Tk::AUTOLOAD function clips the method name from the
	# $Tcl::Tk::AUTOLOAD variable. When called from Tcl::Tk::ttk interpreter
	# this is Tcl::Tk::ttk::$method, so that method becomes ttk::$method
	# which leads to an error... Therefore we have to call the method 
	# explizitly as Tcl::Tk::function...
	$method = "Tcl::Tk::$method";
	$self->$method(@_);
	
	
}

# Preloaded methods go here.

##########################
# ttkWidgets 
##########################
package Tcl::Tk::ttkWidget;
our @ISA = qw(Tcl::Tk::Widget);

sub state {
    my $wid = shift;
    my $int = $wid->interp;
    $int->call("$wid",'state',@_);
};

package Tcl::Tk::Widget::ttkMenubutton;
our @ISA = qw(Tcl::Tk::ttkWidget);

sub command {
    my $wid = shift;
    my $int = $wid->interp;
    my %args = @_;
    Tcl::Tk::Widget::_process_underline(\%args);
    my $mnu = $wid->_get_menu();
    $int->call("$mnu",'add','command',%args);
}
	
sub checkbutton {
    my $wid = shift;
    my $int = $wid->interp;
    my $mnu = $wid->_get_menu();
    $int->call("$mnu",'add','checkbutton',@_);
}
	
sub radiobutton {
    my $wid = shift;
    my $int = $wid->interp;
    my $mnu = $wid->_get_menu();
    $int->call("$mnu",'add','radiobutton',@_);
}

sub cascade {
    my $wid = shift;
    my $int = $wid->interp;
    my $mnu = $wid->_get_menu();
    Tcl::Tk::Widget::_addcascade($mnu, @_);
}
	
sub separator {
    my $wid = shift;
    my $int = $wid->interp;
    my $mnu = $wid->_get_menu();
    $int->call("$mnu",'add','separator',@_);
}

sub get_menu {
    my $wid = shift;
    my $int = $wid->interp;
    return $int->widget("$wid", "Tcl::Tk::Widget::Menu");
}	

sub cget {
    my $wid = shift;
    my $int = $wid->interp;
    if ($_[0] eq "-menu") {
        my $path = $int->invoke("$wid",'cget','-menu');
	return $int->widget($path,'Tcl::Tk::Widget::Menu') if $path;
	return undef;
    } else {
	die "Finish cget implementation for Menubutton";
    }
}

sub entryconfigure {
    my $wid = shift;
    my $int = $wid->interp;
    my $label = shift;
    $label =~ s/~//;
    my $mnu = $wid->_get_menu();
    $int->call("$mnu", 'entryconfigure', $label, @_);
}

sub _get_menu {
	my $wid = shift;
	
	# PROBLEM: if I write -menu without '', then the method above is called
	# which causes an error. Very confusing. 
	my $has_menu = $wid->cget('-menu');
	
	if (ref($has_menu) eq 'Tcl::Tk::Widget::Menu') {
		return $has_menu;
	}
	else {
		my $mnu = $wid->Menu();
		$wid->configure(-menu => $mnu);
		return $mnu;
	}
	
}

package Tcl::Tk::ttkStyle;

use strict;
use warnings;

sub new {
	my $class = shift;
	my $int = shift or die "Error: You have to pass the Tcl interpreter\n";
	my $self = {'int' => $int};
	return bless($self, $class);
}

sub interp {
    my $self=shift;
    return $self->{'int'};
}
sub theme_names {
	my $self = shift;
	return $self->interp->Eval("ttk::style theme names");
}

sub theme_use {
	my $self = shift;
	my $theme = shift || '';
	return $self->interp->Eval("ttk::style theme use $theme");
}

sub layout {
	my $self = shift;
	my $style = shift or die "Error: You must pass a style to layout method\n";
	
	return $self->interp->call("ttk::style", "layout", $style, @_);

}

sub element_options {
	my $self = shift;
	my $element = shift or die "Error: You must pass an element to element options method\n";
	return $self->interp->Eval("ttk::style element options $element");
}

sub configure {
	my $self = shift;
	my $style = shift or die "Error: You must pass a style to configure method\n";
	return $self->interp->call("ttk::style", "configure", $style, @_);
}

sub lookup {
	my $self = shift;
	my $style = shift or die "Error: You must pass a style to configure method\n";
	my $opt = shift or die "Error: You must pass a option to lookup method\n";
	
	return $self->interp->call("ttk::style", "lookup", $style, $opt, @_);
}

sub map {
	my $self = shift;
	my $style = shift or die "Error: You must pass a style to configure method\n";
	
	return $self->interp->call("ttk::style", "map", $style, @_);
}

#TODO: element_create, element_names, theme_create, theme_settings

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Tcl::Tk::ttk - A very tiny extension for Tcl::Tk to allow using the ttk styled widgets.

=head1 SYNOPSIS

  use Tcl::Tk;
  use Tcl::Tk::ttk;
  my $int = Tcl::Tk->new();
  load_ttk_widgets($int);
  my $mw = $int->mainwindow();
  my $lab = $mw->ttkLabel(-text => "Hello World")->pack();
  my $btn = $mw->ttkButton(-text => "test", -command => sub {
      $lab->configure(-text => "[". $lab->cget('-text')."]");
      })->pack;
  $int->MainLoop();

=head1 DESCRIPTION

Tcl::Tk::ttk declares the ttkWidgets for Tcl::Tk and provides access to the most ttk::style methods.

=head2 EXPORT

The only function which is exported is load_ttk_widget(), which declares the ttk::* widgets.
You have to pass the Tcl::Tk interpreter to the function and to call the function before the
first use of a ttkWidget.

The following widgets are declared:

=over

=item* 

=back

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

Copyright (C) 2018 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.22.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
