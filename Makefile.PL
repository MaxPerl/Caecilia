use 5.006001;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;

my $edj_path = "./share/custom.edj";
unless (-e $edj_path) {
	print "\nEdje file custom.edj was not found in the distribution.\n";
	print "Therefore it must be compiled before Caecilia can be installed:\n";
	system("edje_cc","./share/custom.edc",$edj_path) == 0 or	
	die "Could not compile custom.edc: $?\n";
	print "\nCompiling of custom.edc...\t\t[Done]\n\n";
}

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
install_share 'share';
WriteMakefile(
    NAME              => 'Caecilia',
    VERSION_FROM      => 'lib/Caecilia.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {	File::Temp => 0,
							File::ShareDir => 0,
							File::Basename => 0,
							Image::Info => 0,
							pEFL => 0,
							Syntax::SourceHighlight => 0,
							Cwd => 0,
							IPC::Open3 => 0,
							}, # e.g., Module::Name => 1.1
    BUILD_REQUIRES	  => {'File::ShareDir::Install' => 0},
    ABSTRACT_FROM     => 'lib/Caecilia.pm', # retrieve abstract from module
    EXE_FILES		  => ['bin/caecilia.pl'],
    AUTHOR            => 'Maximilian Lika <Perlmax@cpan.org>',
    LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);

package MY;
use File::ShareDir::Install qw(postamble);
