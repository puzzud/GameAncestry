##Install dependences.
#cpan Text::CSV
#wget http://search.cpan.org/CPAN/authors/id/M/MS/MSERGEANT/DBD-SQLite-1.13.tar.gz
##untargz file and navigate to its provided source.
#perl Makefile.PL
#make -j9
#make test
#make install

perl build_db.pl ../database;
