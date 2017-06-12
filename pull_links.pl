#!/usr/bin/perl
## Pulls LISTINGS of threads between specific dates using reddit's cloudsearch. The timestamp uses epoch dates.

#the subreddit/LINKS folder is created if it does not already exist.
#user is prompted for start and end dates, as well as the subreddit name.
#these are convered to epoch dates, the number of days counted, and links for each DAY are pulled.

use strict;
use warnings;

use DateTime;

my ($user_begin, $user_end, $subreddit);

my $config_file = "scraper_config.txt";

#Normal usage would be to edit the scraper_config.txt file.
unless (-e $config_file) {
    print "Enter start date (mmddyy): ";
    $user_begin = <STDIN>;

    print "Enter end date (mmddyy): ";
    $user_end = <STDIN>;

    # Testing the format of input dates.
    if ($user_begin =~ m/[^\d]/ or $user_end =~ m/[^\d]/) {
	print "Non-numeric character encountered.\n"; exit;
    }
    if (length($user_begin) != 6 or length($user_end) != 6) {
	print "Wrong date length encountered.\n"; exit;
    }

    print "Enter subreddit (default all): ";
    $subreddit = <STDIN>;

}

#Process the config file
if (-e $config_file) {
    open (FH, "<", $config_file);
    my @data;
    while (my $line = <FH>){
	my @pieces = split(":", $line);
	push @data, pop @pieces;
    }
    ($user_begin, $user_end, $subreddit) = @data;
}

chomp ($user_begin, $user_end, $subreddit);

my @begin_nums = split "", $user_begin;
my @end_nums = split "", $user_end;

my $begin_day = $begin_nums[2].$begin_nums[3];
my $begin_month = $begin_nums[0].$begin_nums[1];
my $begin_year = "20".$begin_nums[4].$begin_nums[5];

my $dt_begin = DateTime->new(
    year => $begin_year,
    month => $begin_month,
    day => $begin_day,
    hour => 0,
    minute => 0,
    second => 0, 
);
my $begin_edate = $dt_begin->epoch;

my $end_day = $end_nums[2].$end_nums[3];
my $end_month = $end_nums[0].$end_nums[1];
my $end_year = "20".$end_nums[4].$end_nums[5];

my $dt_end = DateTime->new(
    year => $end_year,
    month => $end_month,
    day => $end_day+1, # May as well include this last day, not stop at midnight.
    hour => 0,
    minute => 0,
    second => 0,
);
my $end_edate = $dt_end->epoch;

my $ONE_DAY = 86400;
#my $ONE_WEEK = $ONE_DAY*7;	# Was initially used for fewer files.
my $TIME_PERIOD = $ONE_DAY; 

my $TOTAL_PERIODS = ($end_edate - $begin_edate)/$ONE_DAY; # Number of days to download.

my $BEGIN = $begin_edate;
my $TRUE_END = $end_edate;

$subreddit =~ s/^\s+|\s+$//g;	# remove starting or trailing spaces
if ($subreddit =~ /\s/) { # At this point if it contains spaces we exit.
    print "Do not input more than one subreddit please.\n";
    exit;
}

if ($subreddit eq "") {
    $subreddit = "all";		# set default subreddit here
}

# Check if this subreddit already exists, (in lowercase instead of proper format).
opendir my $current_folder, "./";
my @files_in_current_folder = readdir $current_folder;
close $current_folder;
foreach (@files_in_current_folder) {
    unless ($_ eq "." or $_ eq ".."){
	if (-d "./$_") {
	    if ( lc($subreddit) eq lc($_) ) {
		$subreddit = $_;
	    }
	}
    }
}

# Make the subreddit directory if it does not already exist.
unless(-e $subreddit or mkdir $subreddit) {
    die "Unable to create directory $subreddit\n $! \n";
}

my $dir = "./".$subreddit."/LINKS";
unless(-e $dir or mkdir $dir) {
    die "Unable to create directory $dir\n $! \n";
}

my $cnt=0;		      # Repeat until all downloads successful.
while ($cnt < $TOTAL_PERIODS) {	
    $cnt=0;
    my $START_TIME = $BEGIN; 
    my $END_TIME = $START_TIME + $TIME_PERIOD;
    foreach my $k (1..$TOTAL_PERIODS) {
	my $linkaddy = "https://www.reddit.com/r/".$subreddit."/search.json?q=timestamp:$START_TIME..$END_TIME&sort=new&restrict_sr=on&limit=100&syntax=cloudsearch";

	my $filename = "$dir/$START_TIME-to-$END_TIME.json";
	unless (-s $filename){ 
	    `wget --tries=100 -O $filename "$linkaddy"`; # Could also use the no-clobber -nc feature, but not necessary.
	}
	if (-s $filename) {
	    $cnt++;
	}
	$START_TIME += $TIME_PERIOD;
	$END_TIME += $TIME_PERIOD;
    }
}

# Now that we've finished, pull down the actual comment threads using another script.
exec("perl pull_comment_threads.pl $subreddit");
