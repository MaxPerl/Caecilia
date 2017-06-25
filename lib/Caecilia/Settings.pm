package Caecilia::Settings;

use strict;
no strict 'vars';
use warnings;

# the init function loads the default settings
sub init {
	our $ABCM2PS_PATH = 'abcm2ps';
	our $ABCM2PS_AUTOLINEBREAK = '1';
}

sub get_config {
	if (-e "$ENV{HOME}/.caecilia/config.pl") {
		do "$ENV{HOME}/.caecilia/config.pl";
		return 1;
	}
	else {
		warn "No configuration file found.\nTake default conifguration\n";
		return 0;
	}
}

sub write_config {
	unless (-d "$ENV{HOME}/.caecilia") {
		mkdir "$ENV{HOME}/.caecilia";
		
	}
	
	open my $fh, ">", "$ENV{HOME}/.caecilia/config.pl" or die "Could not open $ENV{HOME}/.caecilia/config.pl: $!\n";
	# NOTE: We have to put the values in single quotes because of "use strict"!
	# NOTE: $VAR = ; breaks config dowm
	print $fh "# This is an automatically created configuration file\n";
	print $fh "\$ABCM2PS_PATH = '$Caecilia::Settings::ABCM2PS_PATH'; \n";
	print $fh "\$ABCM2PS_AUTOLINEBREAK = '$Caecilia::Settings::ABCM2PS_AUTOLINEBREAK'; \n";
	close $fh;
	return 1;
}

return 1;