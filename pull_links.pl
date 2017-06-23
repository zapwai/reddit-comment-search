#!/usr/bin/perl
# Reddit Comment Search
# Copyright (C) 2017 David Ferrone
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
################################################################################
################################################################################
## Pulls LISTINGS of threads between specific dates using reddit's cloudsearch.
## The timestamp uses epoch dates.
## the subreddit/LINKS folder is created if it does not already exist.
## user is prompted for start and end dates, as well as the subreddit name.
## these are convered to epoch dates, the number of days counted,
## and links for each DAY are pulled.

#use warnings;
#use strict;

do "get_config.pl";		# Also sets ONE_DAY.

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

print "Downloading thread listings.\n";

my $cnt;			# counter for long downloads.
$| = 1;

my $START_TIME = $begin_edate;
my $END_TIME = $START_TIME + $TIME_PERIOD;
foreach my $k (1..$TOTAL_PERIODS) {
    my $linkaddy = "https://www.reddit.com/r/".$subreddit
	."/search.json?q=timestamp:$START_TIME..$END_TIME"
	.'&sort=new&restrict_sr=on&limit=100&syntax=cloudsearch';
    my $filename = "$listing_dir/$START_TIME-to-$END_TIME.json";
    `wget -nc -q --tries=100 -O $filename "$linkaddy"`; 
    $START_TIME += $TIME_PERIOD;
    $END_TIME += $TIME_PERIOD;

    # Tiny bit of feedback is nice.
    $cnt++;
    print "." if ($cnt % 100 == 0);
}


#Now pull down the actual comment threads using another script.
print "\nListings received."; 
do "pull_comment_threads.pl";
