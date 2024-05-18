#! /usr/bin/env perl

use strict;
use warnings;
use utf8;

use pEFL;
use pEFL::Evas;

use Caecilia;

use File::HomeDir;
use File::ShareDir 'dist_dir';

use File::Path qw(make_path);
use File::Copy;

# Fist time setup
my $userdir = File::HomeDir->my_home . "/.caecilia";
my $share = dist_dir("Caecilia");

if (! -e "$userdir/source-highlight") {
	print "Caecilia runs first time. Therefore some first run setup is done\n";
	print "\nCreate user path..."; 
	make_path("$userdir/source-highlight") or die "Path creation failed: $!\n";
	print "\t\t[Done]\n";
	print "Copy source-highlight files...";
	copy("$share/source-highlight/abc.lang","$userdir/source-highlight/abc.lang") or die "Copy failed: $!";
	copy("$share/source-highlight/lang.map","$userdir/source-highlight/lang.map") or die "Copy failed: $!";
	copy("$share/source-highlight/myhtml.outlang","$userdir/source-highlight/myhtml.outlang") or die "Copy failed: $!";
	copy("$share/source-highlight/mystyle.style","$userdir/source-highlight/mystyle.style") or die "Copy failed: $!";
	print "\t[Done]\n\n";
}

my $c = Caecilia->new();
$c->init_ui();
