#!/usr/bin/perl
# Copyright 2017 David Ferrone
## Pulls LISTINGS of threads between specific dates using reddit's cloudsearch. The timestamp uses epoch dates.

#the subreddit/LINKS folder is created if it does not already exist.
#user is prompted for start and end dates, as well as the subreddit name.
#these are convered to epoch dates, the number of days counted, and links for each DAY are pulled.

require "./date_routines.pl";	#Gets the edate given mmddyy format.

my ($user_begin, $user_end, $subreddit, $username, $string);
my $config_file = "scraper_config.txt";

#Normal usage would be to edit the scraper_config.txt file.
#This sets the values in case user deleted the config file.
unless (-e $config_file) {
    print "Enter start date (mmddyy): ";
    $user_begin = <STDIN>;

    print "Enter end date (mmddyy): ";
    $user_end = <STDIN>;

    print "Enter subreddit (default all): /r/";
    $subreddit = <STDIN>;

    print "Enter a username (default none): /u/";
    $username = <STDIN>;

    print "Enter a string (default none): ";
    $string = <STDIN>;

    if ($subreddit =~ /^\s*$/) {
	$subreddit = "all\n";
    }

    open (my $FH, ">", $config_file)
	or die ("I cannot write the config file. $!\n");
    print $FH "startdate(mmddyy):".$user_begin."enddate(mmddyy):".$user_end."subreddit:".$subreddit."username:".$username."string:".$string;
}

#Process the config file
if (-e $config_file) {
    open (my $FH, "<", $config_file)
	or die ("I cannot read the config file. $!\n");
    my @data;
    while (my $line = <$FH>) {
	my @pieces = split(":", $line);
	push @data, pop @pieces;
    }
    ($user_begin, $user_end, $subreddit, $username, $string) = @data;
}

chomp ($user_begin, $user_end, $subreddit, $username, $string);

my $begin_edate = get_edate($user_begin) if (is_valid_date($user_begin));
my $end_edate = get_edate($user_end) if (is_valid_date($user_end));
# Add one day to the end_edate. (The edate is midnight of the date provided, which would skip the last day.)
$end_edate += $ONE_DAY;

# Halt on messed up order of dates.
if ($end_edate < $begin_edate) {
    print "You want time to move backwards?\n";
    print "I don't think the date $user_begin comes before $user_end...\n";
    exit;
}

my $ONE_DAY = 86400;
my $TIME_PERIOD = $ONE_DAY; 

# Number of days to download.
my $TOTAL_PERIODS = ($end_edate - $begin_edate)/$TIME_PERIOD; 

# Remove leading or trailing spaces
$subreddit =~ s/^\s+|\s+$//g;
# No multiple subreddits - if it contains a space we exit.
if ($subreddit =~ /\s/) { 
    print "Do not input more than one subreddit please.\n";
    exit;
}

# Check if this subreddit already exists with a funny capitalized name
# Use the name that already exists.
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

# Make the listings directory if it does not already exist.
my $listing_dir = "./".$subreddit."/LINKS";
unless(-e $listing_dir or mkdir $listing_dir) {
    die "Unable to create directory $listing_dir\n $! \n";
}

# Repeat until all downloads successful. $cnt verifies.
my $cnt=0;		      
while ($cnt < $TOTAL_PERIODS) {	
    $cnt=0;
    my $START_TIME = $begin_edate;
    my $END_TIME = $START_TIME + $TIME_PERIOD;
    foreach my $k (1..$TOTAL_PERIODS) {
	my $linkaddy = "https://www.reddit.com/r/".$subreddit."/search.json?q=timestamp:$START_TIME..$END_TIME&sort=new&restrict_sr=on&limit=100&syntax=cloudsearch";

	my $filename = "$listing_dir/$START_TIME-to-$END_TIME.json";
	unless (-s $filename){ 
	    `wget -nc -q --tries=100 -O $filename "$linkaddy"`; 
	}
	if (-s $filename) {
	    $cnt++;
	}
	$START_TIME += $TIME_PERIOD;
	$END_TIME += $TIME_PERIOD;
    }
}

#Now pull down the actual comment threads using another script.
print "Listings received, now downloading each reddit thread.\n";
exec("perl pull_comment_threads.pl $subreddit");
