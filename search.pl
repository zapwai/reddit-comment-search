#!/usr/bin/perl
# Copyright 2017 David Ferrone
#
## Requires scraper_config.txt file.
## This will search each comment thread in the subreddit folder,
## and produce hashes of links, one for submissions, one for comments,
## containing all occurrences where $username is the author.

## If you desire a case sensitive search
## find each occurrence of =~ /$string/i
## and remove the letter i.

## Currently inefficient. Creates two hashes for no real reason.

#use warnings;
use DateTime;
use JSON;

my $config_file = "scraper_config.txt";
if (!-e $config_file) {
    print "No configuration file, sorry, must halt.\n";
    print "Please run pull_links.pl first.\n";
    exit;
}

my ($user_begin, $user_end, $subreddit, $username, $string);

if (-e $config_file) {
    open (FH, "<", $config_file);
    my @data;
    while (my $line = <FH>) {
	my @pieces = split(":", $line);
	push @data, pop @pieces;
    }
    ($user_begin, $user_end, $subreddit, $username, $string) = @data;
}

chomp ($user_begin, $user_end, $subreddit, $username, $string);

sub get_edates {
    my ($user_begin, $user_end) = (shift, shift);
    # Testing the format of input dates.
    if ($user_begin =~ m/[^\d]/ or $user_end =~ m/[^\d]/) {
	print "Non-numeric character encountered in date.\n"; exit;
    }
    if (length($user_begin) != 6 or length($user_end) != 6) {
	print "Wrong date length encountered.\n"; exit;
    }

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
    return ($begin_edate, $end_edate);
}

my ($begin_edate, $end_edate) = get_edates($user_begin, $user_end);

if ($end_edate < $begin_edate) {
    print "You want time to move backwards?\n";
    print "I don't think the date $user_begin comes before $user_end...\n";
    exit;
}

# Remove beginning or ending spaces.
$username =~ s/^\s+|\s+$//g;
$subreddit =~ s/^\s+|\s+$//g;
# $string may purposely have spaces.

print "Config file supplied the following: \n";
print "startdate:".$user_begin."\n";
print "enddate:".$user_end."\n";
print "subreddit:".$subreddit."\n";
print "username:".$username."\n";
print "string:".$string."\n";

if (!-e $subreddit) {
    print "The folder $subreddit does not appear to exist...\n";
    print "(Have you run the pull_links.pl script?)\n";
    exit;
}

if (!length($string) and !length($username)) {
    print "(No username and no string will simply print all links in your requested timeframe.)\n";
}

unless (!length($string) or !length $username) {
    print "\nI will return threads from the $subreddit folder in which /u/$username said the string:$string.\n";
}
if (!length $string and length $username) {
    print "\nA general search for /u/$username in the $subreddit folder.\n";
}
if (length $string and !length $username) {
    print "\nA general search for the string \"$string\" in the $subreddit folder.\n";
}

# Reddit thread JSONs are two merged together. e.g. [{},{}]
# We remove the [], then create header ($FirstJSON) and content ($SecondJSON).
# For some context check out a .json file, perhaps try the jq command. e.g.
# jq "." Buddhism/Extended_JSON_Comments/15sk1n-c7r0v33.json | grep replies -C 5

our $link;	 # permalink to the thread itself.
my %submit_link; # Submitted links by $username (key is edate of submission)
my %comment_link; # Commented links by $username (key is edate of comment)

my %comment_content; # The body of the comments. (key is edate of comment)

# In the event that a string was supplied in $string, we use these:
my %string_comment_link;
my %string_comment_content;
my %string_comment_author;

THRD: foreach my $Thread (<"$subreddit/Extended_JSON_Comments/*">) {
    open (my $FILE, $Thread)
	or die("Thread $Thread cannot be opened.\n$!\n");
    my $row = <$FILE>;
    close $FILE;
    # I want the location of the  second  occurance of the word "Listing".
    # I need to split the JSONs a bit earlier than this, at comma.
    my $MehPt = index( $row, 'Listing' ) + 3;
    my $BrokenRow = substr ( $row, $MehPt );
    my $EndPt = index( $BrokenRow, 'Listing' ) + 4;
    my $FirstJSON= substr ( $row, 1 , ($EndPt - 3) ); 
    my $SecondJSON = substr ( $row, $EndPt , -1);

    $FirstJSON = decode_json($FirstJSON);
    $SecondJSON = decode_json($SecondJSON);

    for my $listy ( @{$FirstJSON->{data}->{children}} ) {
	$link = "https://www.reddit.com".$listy->{data}->{permalink};
	my $edate = $listy->{data}->{created_utc};
	if ($edate < $begin_edate or $edate > $end_edate) {
	    next THRD;		# If wrong date I want the next $Thread.
	}
	if (!length($string) and !length($username)) {
	    $submit_link{$edate} = $link;
	}
	my $author = $listy->{data}->{author};
	unless (!length $username) {
	    if (is_username($author)) {
		## {id} in header JSON (in content JSON it's under {link_id})
		# my $id = $listy->{data}->{id}; 
		my $title = $listy->{data}->{title};
		$submit_link{$edate} = $link;
	    }
	}
    }

    for my $contenty ( @{$SecondJSON->{data}->{children}} ) {
	my $id = $contenty->{data}->{link_id}; 
	$id = substr($id,3);
	
	my $author = $contenty->{data}->{author};
	my $edate = $contenty->{data}->{created_utc}; 
	my $new_link = $link.$contenty->{data}->{id};
	my $comment = $contenty->{data}->{body};

	unless (!length $username) {
	    if (is_username($author)) {
		# Search for the string, if one was supplied.
		unless (!length $string) {
		    if ($comment =~ /$string/i) {
			$string_comment_link{$edate} = $new_link;
			$string_comment_content{$edate} = $comment;
		    }
		}
	    }
	    $comment_link{$edate} = $new_link;
	    $comment_content{$edate} = $comment;
	}
	# Just check for the string, if there is no username.
	if (!length $username) {
	    unless (!length $string) {
		if ($comment =~ /$string/i) {
		    $string_comment_link{$edate} = $new_link;
		    $string_comment_content{$edate} = $comment;
		}
	    }
	}
	# If no reply we are done. Otherwise traverse the replies.
	unless (!length $contenty->{data}->{replies}) { 
	    my $hash_ref_to_replies = $contenty->{data}->{replies};
	    traverse_replies($hash_ref_to_replies);
	}
    }
}

## We always print submissions.
print "\n";
print "Submissions";
unless (!length $username) {
    print " by /u/$username: ";
}
if (!(scalar keys %submit_link)) {
    print " (none)";
}
print "\n";

foreach (sort keys %submit_link) {
    print "---"x10,"\n";
    print "$_: ",$submit_link{$_};
    print "\n";
}

## If no string was supplied, print all comments by given username.
if (!length $string) {
    unless (!length $username){
	print "All comments";
    }
    unless (!length $username) {
	print "by /u/$username: ";
    }
    print "\n";
    foreach (sort keys %comment_link) {
	print "---"x10,"\n";
	print "$_: ",$comment_link{$_};
	print "\n\n";
	print $comment_content{$_};
	print "\n\n";
    }
}
## If a search string was supplied to $string, print the string hash.
elsif (length $string) {
    print "Comments ";
    unless (!length $username) {
	print "by /u/$username ";
    }
    print "containing the string \"$string\": \n";
    foreach (sort keys %string_comment_link) {
	print "---"x10,"\n";
	print "$_: ",$string_comment_link{$_};
	print "\n\n";
	print $string_comment_content{$_};
	print "\n\n";
    }
}

sub is_username {
    my $author = shift;
    if ($username eq $author) {
	return 1;
    }
    return 0;
}

sub traverse_replies {
    my $hash_ref_to_replies = shift;
    for ( @{$hash_ref_to_replies->{data}->{children}} ) {

	my $edate = $_->{data}->{created_utc};
	my $new_link = $link.$_->{data}->{id};
	my $comment = $_->{data}->{body};

	unless ($_->{kind} eq "more") {
	    unless (!length $username) {
		if ( is_username($_->{data}->{author}) ) {
		    $comment_link{$edate} = $new_link;
		    $comment_content{$edate} = $comment;
		    # Search for the string, if it was supplied.
		    unless (!length $string) {
			if ($comment =~ /$string/i) {
			    $string_comment_link{$edate} = $new_link;
			    $string_comment_content{$edate} = $comment;
			}
		    }
		}
	    }
	    # Just check for the string, if there is no username.
	    if (!length $username) {
		unless (!length $string) {
		    if ($comment =~ /$string/i) {
			$string_comment_link{$edate} = $new_link;
			$string_comment_content{$edate} = $comment;
		    }
		}
	    }
	}
	# The value of {replies} is "" when there are no replies.
	if (!$_->{data}->{replies}) {
	    next;
	} else {
	    my $next_hash_ref = $_->{data}->{replies};
	    traverse_replies($next_hash_ref);
	}
    }
}
