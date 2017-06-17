#!/usr/bin/perl
# Copyright 2017 David Ferrone
#
## Requires _config.txt file.
## This will search each comment thread in the subreddit folder,
## and produce hashes of links, one for submissions, one for comments,
## containing all occurrences where $username is the author.

## If you desire a case sensitive search
## find each occurrence of =~ /$string/i
## and remove the letter i.

## Currently inefficient.
## For instance, Creates two sets of hashes for no real reason.
## Also many double-checks on existence of $username and $string. Lack of logic everywhere.
## The index and checking is unnecessary - reddit ids are ordered alphabetically.
require "routines.pl";
use JSON;
use autodie;

do "get_config.pl" if (!length $begin_edate);

# Remove beginning or ending spaces.
$username =~ s/^\s+|\s+$//g;
$subreddit =~ s/^\s+|\s+$//g;
$print_option =~ s/^\s+|\s+$//g;
# $string may purposely have spaces.

$print_option = substr (uc ($print_option), 0, 1);
my $config_report = <<"endl";
 Config file supplied the following:
 startdate:$user_begin
 enddate:$user_end
 subreddit:$subreddit
 username:$username
 string:$string
 print_comments:$print_option
endl
print $config_report;

if (!-e $subreddit) {
    print "The folder $subreddit does not appear to exist...\n";
    print "(Have you run the pull_links.pl script?)\n";
    exit;
}

unless (!length($string) or !length($username)) {
    print "\nI will return threads from the $subreddit folder in which /u/$username said the string:$string.\n";
}

if (!length($string) and !length($username)) {
    print "(No username and no string will simply print all links in your requested timeframe.)\n";
} elsif (!length $string and length $username) {
    print "\nA general search for /u/$username in the $subreddit folder.\n";
} elsif (length $string and !length $username) {
    print "\nA general search for the string \"$string\" in the $subreddit folder.\n";
}

# Reddit thread JSONs are two merged together. e.g. [{},{}]
# We remove the [], then create header ($FirstJSON) and content ($SecondJSON).
# For some context check out a .json file, with the jq command.

my $link;	 # permalink to the thread itself.
my %submit_link; # Submitted links by $username (key is edate of submission)
my %comment_link; # Commented links by $username (key is edate of comment)

my %comment_content; # The body of the comments. (key is edate of comment)

# In the event that a string was supplied in $string, we ALSO use these:
my %string_comment_link;
my %string_comment_content;
my %string_comment_author;

my $target_dir = "$subreddit/Extended_JSON_Comments";
my $index_filename = $target_dir."/_INDEX";
unless (-e $index_filename) {
    print "Creating index of dates --> files.\n";
    `perl index_creator.pl $subreddit`;
}
my @files_to_open;
print "Reading index";
open (my $FILE, "<", $index_filename);
my $time_counter = 0;
$| = 1;
while (my $line = <$FILE>) {
    chomp($line);
    my @pieces = split("\t", $line);
    if ($pieces[0] < $begin_edate) {
	if ($time_counter == 0) {
	    $time_counter++;
	    print ".";
	}
	next;
    } elsif ($pieces[0] > $end_edate) {
	if ($time_counter == 2) {
	    $time_counter++;
	    print ".";
	}
	next;
    } else {
	if ($time_counter == 1) {
	    $time_counter++;
	    print ".";
	}
	push @files_to_open, $pieces[1];
    }
}

print " done.";
close $FILE;
$time_counter=0;
print " Searching through the Reddit threads";

THRD: foreach my $Thread (@files_to_open) {
    open (my $FILE, "<", $Thread)
	or die("Thread $Thread cannot be opened.\n$!\n");
    my $row = <$FILE>;		# unnecessary assignment.
    close $FILE;
    $time_counter++;
    print "." if ($time_counter % 100 == 0);
    my ($FirstJSON, $SecondJSON) = split_merged_jsons($row);
    
    $FirstJSON = decode_json($FirstJSON);
    $SecondJSON = decode_json($SecondJSON);

    for my $listy ( @{$FirstJSON->{data}->{children}} ) {
	$link = "https://www.reddit.com".$listy->{data}->{permalink};
	my $edate = $listy->{data}->{created_utc};
	# if ($edate < $begin_edate or $edate > $end_edate) {
	#     next THRD;		# This check is not necessary, the index took care of it.
	# }
	if (!length($string) and !length($username)) {
	    $submit_link{$edate} = $link;
	    next THRD;
	}
	unless (!length $username) {
	    my $author = $listy->{data}->{author};
	    if (is_username($author)) {
		$submit_link{$edate} = $link;
	    }
	}
    }

    for my $contenty ( @{$SecondJSON->{data}->{children}} ) {
	# my $id = $contenty->{data}->{link_id}; 
	# $id = substr($id,3);  # If you need the id of the thread itself.
	
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
		$comment_link{$edate} = $new_link;
		$comment_content{$edate} = $comment;
	    }
	    
	}
	# Just check for the string, if there is no username.
	if (!length $username) {
	    unless (!length $string) {
		if ($comment =~ /$string/i) {
		    $string_comment_link{$edate} = $new_link;
		    $string_comment_content{$edate} = $comment;
		    $string_comment_author{$edate} = $author;
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

print " done.\n";

## Print submissions.
unless (!(scalar keys %submit_link)) {
    print "\n";
    print "Submissions";
    print " by /u/$username: " unless (!length $username);
    print "\n";
    foreach (sort keys %submit_link) {
	print "$_: ",$submit_link{$_};
	print "\n";
    }
}
## If no string was supplied, print all comments by given username.
if (!length $string) {
    print "All comments";
    print " by /u/$username: " unless (!length $username);
    print "\n";
    foreach (sort keys %comment_link) {
	print "$_: ",$comment_link{$_};
	print "\n";
	unless ($print_option eq "N"){
	    print $comment_content{$_};
	    print "\n";
	}
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
	print "$_: ",$string_comment_link{$_};
	print "\n";
	unless ($print_option eq "N"){
	    print $string_comment_content{$_};
	    print "\n";
	}
	if (!length $username) {
	    print "\t--".$string_comment_author{$_}."\n";
	}
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
	my $author = $_->{data}->{author};
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
			$string_comment_author{$edate} = $author;
		    }
		}
	    }
	}
	# The value of {replies} is "" when there are no replies.
	if (!length $_->{data}->{replies}) {
	    next;
	} else {
	    my $next_hash_ref = $_->{data}->{replies};
	    traverse_replies($next_hash_ref);
	}
    }
}
