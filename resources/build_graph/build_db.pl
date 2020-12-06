#!/usr/bin/perl

use strict;
use DBI;

use File::Copy qw( copy );
use Text::CSV;

use warnings;

#--------------------------------------------------------------
my $numberOfProgramArguments = $#ARGV + 1;
if( $numberOfProgramArguments < 1 )
{
  print( "Specify directory which contains database information as first parameter." . "\n" );
  exit 1;
}

my $databaseDirectory = $ARGV[0];
if( !( -d $databaseDirectory ) )
{
  print( "Database directory '$databaseDirectory' does not exist." . "\n" );
  exit 2;
}

foreach my $argumentIndex ( 0 .. $#ARGV )
{
   #print "$ARGV[$argnum]\n";
}

my $baseDbFileName = $databaseDirectory . "/" . "empty.db";
if( !( -e $baseDbFileName ) )
{
  print( "Base database file '$baseDbFileName' does not exist." . "\n" );
  exit 3;
}

my $workingDbFileName = $databaseDirectory . "/" . "GameAncestory.db";
if( -e $workingDbFileName )
{
  unlink( $workingDbFileName );
}

copy( $baseDbFileName, $workingDbFileName );
if( !( -e $workingDbFileName ) )
{
  print( "Working database file '$workingDbFileName' could not be created." . "\n" );
  exit 4;
}

# Connect to database.
my $result;
my $dbh = DBI->connect( "dbi:SQLite:dbname=$workingDbFileName",
                        "",
                        "",
                        { RaiseError => 1 } ); #or die $DBI::errstr;

my @tableNameList = ();
my $numberOfTables;
my $tableName;

# Create tables with schema indicated by 'create.sql' file.
my $createSqlFileName = $databaseDirectory . "/" . "create.sql";
if( !( -e $createSqlFileName ) )
{
  print( "Could not open '$createSqlFileName' for create table SQL statements." . "\n" );
  exit( 5 );
}
else
{
  my $createSqlFile;
  open( $createSqlFile, "<", $createSqlFileName );

  my $line;
  while( $line = <$createSqlFile> )
  {
    if( $line =~ /^create\s+table\s+(\w*)\s*\(.*\)\s*;\s*$/i )
    {
      $tableName = $1;
      push( @tableNameList, $tableName );
      
      $dbh->do( $line );
      #print $dbh->rows();
    }
  }
}

$numberOfTables = scalar( @tableNameList );

# Populate tables based on all corresponding / present CSV files.
if( $numberOfTables > 0 )
{
  $result = "";
  my $csv = Text::CSV->new( {binary => 1} ) or $result = Text::CSV->error_diag();
  if( $result ne "" )
  {
    print( "Problem using Text::CSV library" . "\n" );
    exit( 6 );
  }

  my @insertSqlStatementList = ();
  my @headerRow;
  my @rowList;

  foreach $tableName ( @tableNameList )
  {
    my $rowIndex = -1;
    $result = "";
    my $csvFile;
    open( $csvFile, "<:encoding(utf8)", "$databaseDirectory/$tableName.csv" ) or $result = $!;
    if( $result ne "" )
    {
      print( "Problem loading $tableName.csv:  $result" );
      next;
    }

    @rowList = ();
    my $row;
    while( $row = $csv->getline( $csvFile ) )
    {
      if( ++$rowIndex == 0 )
      {
        @headerRow = @{$row};
        next;
      }

      push( @rowList, $row );
    }

    close( $csvFile );

    # Build column order based on read header row.
    my $columnOrderString = "";
    foreach my $columnName ( @headerRow )
    {
      if( $columnOrderString ne "" )
      {
        $columnOrderString .= ", ";
      }

      $columnOrderString .= $columnName;
    }
    #print( "($columnOrderString)" . "\n" );

    # Build insert statement for each row.
    my $valuesString;
    my @rowDataList;
    my $rowDatum;
    my $quotedValue;
    foreach $row ( @rowList )
    {
      $valuesString = "";

      @rowDataList = @{$row};
      foreach $rowDatum ( @rowDataList )
      {
        if( $valuesString ne "" )
        {
          $valuesString .= ", ";
        }

        if( !defined( $rowDatum ) )
        {
          print "Row missing entry." . "\n";

          # Correct it with a 'null' or rather empty value.
          $rowDatum = "";
        }

        $quotedValue = $dbh->quote( $rowDatum );
        $valuesString .= $quotedValue;
      }

      push( @insertSqlStatementList, "insert into $tableName ( $columnOrderString ) values ( $valuesString );" );
    }
  }

  # Rows.
  my $insertSqlStatement;
  foreach $insertSqlStatement ( @insertSqlStatementList )
  {
    #print( $insertSqlStatement . "\n" );
    $dbh->do( $insertSqlStatement ) or print "$insertSqlStatement" . "\n";
  }
}

$dbh->disconnect();

exit 0;
