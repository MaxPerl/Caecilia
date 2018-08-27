use 5.006000;
use ExtUtils::MakeMaker;
use File::ShareDir::Install;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
install_share 'share';
WriteMakefile(
    NAME              => 'Caecilia',
    VERSION_FROM      => 'lib/Caecilia.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {'Test'        =>  0,
			  'Gtk3'	=> 0,
			  'Gtk3::SourceView' => 0,
			  'GooCanvas2' => 0,
			  'File::ShareDir' => 0 }, # e.g., Module::Name => 1.1
    BUILD_REQUIRES    => {'ExtUtils::MakeMaker' => 0,
			  'File::ShareDir::Install' => 0},
    ABSTRACT_FROM     => 'lib/Caecilia.pm', # retrieve abstract from module
    EXE_FILES	      => ['bin/caecilia.pl'],
    AUTHOR            => 'Maximilian Lika <maximilian@(none)>',
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);

package MY;
use File::ShareDir::Install qw(postamble);
