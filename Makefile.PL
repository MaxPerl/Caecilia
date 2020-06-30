use 5.006001;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
install_share 'share';
WriteMakefile(
    NAME              => 'Caecilia',
    VERSION_FROM      => 'lib/Caecilia.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {	File::Temp => 0,
    						File::ShareDir => 0,
    						File::Basename => 0,
    						Image::Magick => 0,
    						Image::Info => 0,
    						Cwd => 0,
    						IPC::Open3 => 0,
    						}, # e.g., Module::Name => 1.1
    BUILD_REQUIRES    => {'File::ShareDir::Install' => 0},
    ABSTRACT_FROM     => 'lib/Caecilia.pm', # retrieve abstract from module
    EXE_FILES	      => ['bin/caecilia.pl'],
    AUTHOR            => 'Maximilian Lika <maximilian@>',
    LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);

package MY;
use File::ShareDir::Install qw(postamble);
