package Caecilia::Tune;

use 5.006001;
use strict;
use warnings;
use utf8;

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

our $VERSION = '0.01';

sub new {
	my ($class, %opts) = @_;
	
	# Get index
	
	my $obj = {
		filename => $opts{filename}, 
		changed => 0,
		undo_stack => [],
		redo_stack => [],
		content => "",
		cursor_pos => 1,
		id => $opts{id},
		source_highlight => "yes",
		elm_toolbar_item => undef
		};
	bless($obj,$class);
	return $obj;
}


############################
# Accessors
############################

sub AUTOLOAD {
	my ($self, $newval) = @_;
	
	die("No method $AUTOLOAD implemented\n")
		unless $AUTOLOAD =~m/filename|changed|id|content|undo_stack|redo_stack|cursor_pos|auto_indent|source_highlight|sh_lang|elm_toolbar_item/;
	
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

Caecilia::Tune

=head1 DESCRIPTION

This saves information of a single tune (e.g. a single tune).

=head1 AUTHOR

Maximilian Lika, E<lt>maxperl@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Maximilian Lika

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.32.1 or,
at your option, any later version of Perl 5 you may have available.


=cut