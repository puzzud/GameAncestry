#!/usr/bin/perl

use warnings FATAL => qw( all );
use strict;
no warnings 'redefine';

use DBI;

#--------------------------------------------------------------
sub GetCreationYearFromCreationDate( $ );
sub GetCreationYearMonthFromCreationDate( $ );
sub GetGamesWithCreationYear( $$ );
sub GetGamesWithCreationYearMonth( $$ );
sub GetGameFieldValue( $$$$ );

use constant
{
  GAME_NAME_CREATION_DATE_SEPARATOR => "<<SEP>>",
};

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

my $workingDbFileName = $databaseDirectory . "/" . "GameAncestory.db";
if( !( -e $workingDbFileName ) )
{
  print( "Database '$workingDbFileName' does not exist." . "\n" );
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

my $statement;
my $sth;
my $rv;

my $gameName;
my $gameCreationDate;
my $influencerGameName;
my $influencerCreationDate;

my $orderByCreationDate = 0;

my @row;

# Populate tables based on all corresponding / present CSV files.
$result = "";

my $graphLabel = "GameAncestory";
my $dateString = localtime;
print "digraph $graphLabel\n";
print "{\n";

if( $orderByCreationDate )
{
  print "rankdir=TB;\n";
  print "ranksep=.01\n";
  print "sep = 0.1;\n";
  print "mode = maxent;\n";
  print "fontsize = 8;\n";
}
else
{
  print "rankdir=BT;\n";
  print "size=\"32,16\";\n";
  print "fontsize = 12;\n";
}

#print "rank=source;\n";

#print "stylesheet = \"file.css\"";

print "overlap = false;\n";
print "splines = true;\n";
print "label = \"$graphLabel ($dateString)\";\n";

print "node [shape = rectangle, fillcolor = lightgrey];\n";

# Cache all linked or linking objects.
$statement = "select Name, CreationDate, InfluencerName, InfluencerCreationDate from GameInfluence;";
$sth = $dbh->prepare( $statement );
$rv = $sth->execute();

my @gameInfluenceList = ();
my %gameLinkHash = ();
while( @row = $sth->fetchrow_array() )
{
  $gameName = $row[0];
  $gameCreationDate = $row[1];

  $influencerGameName = $row[2];
  $influencerCreationDate = $row[3];

  my $influencerGameType = GetGameFieldValue( $dbh, $influencerGameName, $influencerCreationDate, "Type" );
  if( $influencerGameType ne "video" )
  {
    # Filter out non video games.
    next;
  }

  my @rowCopy = ();
  push( @rowCopy, $gameName );
  push( @rowCopy, $gameCreationDate );
  push( @rowCopy, $influencerGameName );
  push( @rowCopy, $influencerCreationDate );
  push( @gameInfluenceList, \@rowCopy );

  $gameLinkHash{$gameName . GAME_NAME_CREATION_DATE_SEPARATOR . $gameCreationDate} = 1;
  $gameLinkHash{$influencerGameName . GAME_NAME_CREATION_DATE_SEPARATOR . $influencerCreationDate} = 1;
}

if( $orderByCreationDate )
{
  # Build ranks by CreationDate.
  $statement = "select distinct CreationDate from Game where Type = 'video' order by CreationDate;";
  $sth = $dbh->prepare( $statement );
  $rv = $sth->execute();

  my %processedCreationYearHash = ();

  my @yearList = ();
  my $gameCreationYear;
  my $gameCreationYearMonth;

  my $previousYear = "";
  my $nextYear;

  my @gameList;
  while( @row = $sth->fetchrow_array() )
  {
    $gameCreationDate = $row[0];
    if( $gameCreationDate eq "" )
    {
      next;
    }

    $gameCreationYear = GetCreationYearFromCreationDate( $gameCreationDate );
    if( defined( $processedCreationYearHash{$gameCreationYear} ) )
    {
      next;
    }
    $processedCreationYearHash{$gameCreationYear} = 1;

    $gameCreationYearMonth = GetCreationYearMonthFromCreationDate( $gameCreationDate );

    $gameCreationYear = int( $gameCreationYear );

    if( $previousYear ne "" )
    {
      while( $previousYear ne $gameCreationYear )
      {
        $nextYear = $previousYear + 1;
        push( @yearList, $nextYear );
        $previousYear = $nextYear;
      }
    }
    else
    {
      push( @yearList, $gameCreationYear );
    }

    $previousYear = $gameCreationYear;
  }

  my $timeLine = "";
  print "{\n";
  my $numberOfYears = scalar( @yearList );
  for( my $yearIndex = 1; $yearIndex < $numberOfYears + 1; $yearIndex++ )
  {
    $previousYear = $yearList[$yearIndex - 1];
    $nextYear = $previousYear + 1;

    my $m1;
    my $m2;
    for( my $monthNumber = 1; $monthNumber < 12; $monthNumber++ )
    {
      $m1 = sprintf( "%02s", $monthNumber );
      $m2 = sprintf( "%02s", $monthNumber + 1 );
      $timeLine .= "node [shape=plaintext,label=\"$previousYear-$m1\"]\n";
      $timeLine .= "\"DATE:$previousYear-$m1\" -> \"DATE:$previousYear-$m2\"\n [style=\"invis\",dir=none,len=0]";
    }

    if( $yearIndex != $numberOfYears )
    {
      $timeLine .= "node [shape=plaintext,label=\"$previousYear-12\"]\n";
      $timeLine .= "\"DATE:$previousYear-12\" -> \"DATE:$nextYear-01\" [style=\"invis\",dir=none,len=0]\n";
    }
  }
  print $timeLine . ";\n";
  print "}\n";

  foreach $gameCreationYear ( @yearList )
  {
    for( my $monthNumber = 1; $monthNumber <= 12; $monthNumber++ )
    {
      my $m1 = sprintf( "%02s", $monthNumber );
      $gameCreationYearMonth = "$gameCreationYear-$m1";
      @gameList = GetGamesWithCreationYearMonth( $dbh, $gameCreationYearMonth );
      if( scalar( @gameList ) > 0 )
      {
        my $nodes = "";
        foreach my $gameNameCreationDatePairRef ( @gameList )
        {
          my @gamePair = @{$gameNameCreationDatePairRef};
          $gameName = $gamePair[0];
          $gameCreationDate = $gamePair[1];

          my $isIncluded = $gameLinkHash{$gameName . GAME_NAME_CREATION_DATE_SEPARATOR . $gameCreationDate};
          if( defined( $isIncluded ) )
          {
            $nodes .= "\"$gameName\"; ";
          }
        }
        
        if( $nodes ne "" )
        {
          print "{ rank = same; \"DATE:$gameCreationYearMonth\"; $nodes}\n"
        }
      }
    }
  }
}

# List all links.
my $rowRef;
foreach $rowRef ( @gameInfluenceList )
{
  @row = @{$rowRef};
  
  $gameName = $row[0];
  $gameCreationDate = $row[1];

  $influencerGameName = $row[2];
  $influencerCreationDate = $row[3];

  my $attributes = "";

#   my $influenceDescription = GetGameFieldValue( $dbh, $influencerGameName, $influencerCreationDate, "Description" );
#   if( ( $influenceDescription ne "" ) &&
#       ( $influenceDescription =~ /^http.*/ ) )
#   {
#     $influenceDescription =~ s/&/&amp;/g;
#   
#     $attributes = "URL=\"" . $influenceDescription . "\",target=\"_blank\"";
#   }

  my $nodeLinkStatement = "\"$gameName\" -> \"$influencerGameName\"";
  if( $attributes ne "" )
  {
    $attributes = "[" . $attributes . "]";

    $nodeLinkStatement .= " $attributes";
  }

  $nodeLinkStatement .= ";" . "\n";

  print $nodeLinkStatement;
}

# List all nodes again, complete with their own attributes.
foreach my $gameNameCreationDatePairString ( keys( %gameLinkHash ) )
{
  my @gameNameCreationDatePair = split( GAME_NAME_CREATION_DATE_SEPARATOR, $gameNameCreationDatePairString );
  $gameName         = $gameNameCreationDatePair[0];
  $gameCreationDate = $gameNameCreationDatePair[1];

  my $attributes = "";
  
  my $resourceDocument = GetGameFieldValue( $dbh, $gameName, $gameCreationDate, "ResourceDocument" );
  if( ( $resourceDocument ne "" ) &&
      ( $resourceDocument =~ /^http.*/ ) )
  {
    $resourceDocument =~ s/&/&amp;/g;
  
    if( $attributes ne "" )
    {
      $attributes .= ",";
    }
    $attributes = "URL=\"" . $resourceDocument . "\",target=\"_blank\"";
  }
  
  if( $attributes ne "" )
  {
    $attributes .= ",";
  }
  $attributes .= "style=\"filled\"";
  
  my $color;
  my $gameGenre = GetGameFieldValue( $dbh, $gameName, $gameCreationDate, "Genre" );
  if( $gameGenre eq "maze" )
  {
    $color = "#ccaaaa";
  }
  elsif( $gameGenre eq "trap 'em up" )
  {
    $color = "#ccaaaa";
  }
  elsif( ( $gameGenre eq "rpg" ) ||
         ( $gameGenre eq "roguelike" ) )
  {
    $color = "#ccbbaa";
  }
  elsif( ( $gameGenre eq "shooter" ) ||
         ( $gameGenre eq "gun" ) )
  {
    $color = "#aaaacc";
  }
  elsif( $gameGenre eq "stratedgy" )
  {
    $color = "#aaccaa";
  }
  elsif( ( $gameGenre eq "sports" ) ||
         ( $gameGenre eq "simulation" ) )
  {
    $color = "#aacccc";
  }
  elsif( $gameGenre eq "fighter" )
  {
    $color = "#aaccbb";
  }
  elsif( $gameGenre eq "racing" )
  {
    $color = "#bbccaa";
  }
  elsif( $gameGenre eq "adventure" )
  {
    $color = "#ccccaa";
  }
  elsif( $gameGenre eq "platformer" )
  {
    $color = "#ccaacc";
  }
  else
  {
    $color = "#bbbbbb";
  }
  
  if( $attributes ne "" )
  {
    $attributes .= ",";
  }
  $attributes .= "fillcolor=\"$color\"";
  
#   if( $attributes ne "" )
#   {
#     $attributes .= ",";
#   }
#   $attributes .= "color=\"$color\"";

#   my $fontcolor = "#eeeeee";
#   if( $attributes ne "" )
#   {
#     $attributes .= ",";
#   }
#   $attributes .= "fontcolor=\"$fontcolor\"";
  
  my $nodeStatement = "\"$gameName\"";
  if( $attributes ne "" )
  {
    $attributes = "[" . $attributes . "]";

    $nodeStatement .= " $attributes";
  }
  
  $nodeStatement .= ";" . "\n";
  
  print $nodeStatement;
}

print "}\n";

$dbh->disconnect();

exit( 0 );

#--------------------------------------------------------------
sub GetCreationYearFromCreationDate( $ )
{
  my $creationDate = $_[0];
  if( $creationDate eq "" )
  {
    return "";
  }

  if( index( $creationDate, "-" ) < 0 )
  {
    return $creationDate;
  }

  $creationDate = GetCreationYearMonthFromCreationDate( $creationDate );
  if( $creationDate =~ /(\d+)-\d+/ )
  {
    return $1;
  }

  return "";
}

sub GetCreationYearMonthFromCreationDate( $ )
{
  my $creationDate = $_[0];
  if( $creationDate eq "" )
  {
    return "";
  }

  if( index( $creationDate, "-" ) < 0 )
  {
    # CreationDate does not specify a month, assume last month in year.
    return $creationDate . "-12";
  }

  if( $creationDate =~ /(\d+-\d+)/ )
  {
    return $1;
  }

  if( $creationDate =~ /(\d+-\d+)-\d+/ )
  {
    return $1;
  }

  return "";
}

sub GetGamesWithCreationYear( $$ )
{
  my $dbh = $_[0];
  my $creationYear = $_[1];

  my @gameList = ();
  if( $creationYear eq "" )
  {
    return @gameList;
  }
  #print $creationYear . "\n";
  #$creationYear = $dbh->quote( $creationYear );

  my $statement = "select Name, CreationDate from Game where CreationDate like '$creationYear%' and Type = 'video';";
  my $sth = $dbh->prepare( $statement );
  my $rv = $sth->execute();

  my $gameName;
  my $gameCreationDate;

  my @row;
  while( @row = $sth->fetchrow_array() )
  {
    my @gameNameCreationDatePair = ();
    push( @gameNameCreationDatePair, $row[0] );
    push( @gameNameCreationDatePair, $row[1] );

    push( @gameList, \@gameNameCreationDatePair );
  }

  return @gameList;
}

sub GetGamesWithCreationYearMonth( $$ )
{
  my $dbh = $_[0];
  my $creationYearMonth = $_[1];

  my @gameList = ();
  if( $creationYearMonth eq "" )
  {
    return @gameList;
  }

  my $creationYear = GetCreationYearFromCreationDate( $creationYearMonth );
  my @yearGameList = GetGamesWithCreationYear( $dbh, $creationYear );
  foreach my $gameNameCreationDatePairRef ( @yearGameList )
  {
    my @gameNameCreationDatePair = @{$gameNameCreationDatePairRef};
    my $gameName = $gameNameCreationDatePair[0];
    my $gameCreationDate = $gameNameCreationDatePair[1];

    my $gameCreationYearMonth = GetCreationYearMonthFromCreationDate( $gameCreationDate );
    if( $gameCreationYearMonth eq $creationYearMonth )
    {
      push( @gameList, \@gameNameCreationDatePair );
    }
  }

  return @gameList;
}

sub GetGameFieldValue( $$$$ )
{
  my $dbh = $_[0];
  my $gameName = $_[1];
  my $gameCreationDate = $_[2];
  my $fieldId = $_[3];

  $gameName = $dbh->quote( $gameName );
  $gameCreationDate = $dbh->quote( $gameCreationDate );

  my $statement = "select $fieldId from Game where Name=$gameName and CreationDate=$gameCreationDate;";
  my $sth = $dbh->prepare( $statement );
  my $rv = $sth->execute();

  my @row = $sth->fetchrow_array();
  my $fieldValue = $row[0];
  if( !defined( $fieldValue ) )
  {
    $fieldValue = "";
  }
  
  return $fieldValue;
}
