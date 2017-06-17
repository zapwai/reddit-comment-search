require "routines.pl";
our ($user_begin, $user_end, $subreddit, $username, $string);
my $config_file = "config.txt";

#Normal usage would be to edit the config.txt file.
#This will set the values in case the user deleted the config file.
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

    open (my $FH, ">", $config_file)
	or die ("I cannot write the config file. $!\n");
    print $FH "startdate(mmddyy):".$user_begin."enddate(mmddyy):".$user_end."subreddit:".$subreddit."username:".$username."string:".$string;
}

#Process the config file
open (my $FH, "<", $config_file)
    or die ("I cannot read the config file. $!\n");
my @data;
while (my $line = <$FH>) {
    my @pieces = split(":", $line);
    push @data, pop @pieces;
}

chomp @data;
($user_begin, $user_end, $subreddit, $username, $string) = @data;

if ($subreddit =~ /^\s*$/) {
    $subreddit = "all";
}

our $ONE_DAY = 86400;

(is_valid_date($user_begin)) ? our $begin_edate = get_edate($user_begin) : die "Invalid begin date.";
(is_valid_date($user_end)) ? our $end_edate = get_edate($user_end) : die "Invalid end date.";

# Add one day to the end_edate.
# (The edate is midnight of the date provided, which would skip the last day.)
$end_edate += $ONE_DAY;

# Halt on messed up order of dates.
if ($end_edate < $begin_edate) {
    print "You want time to move backwards?\n";
    print "I don't think the date $user_begin comes before $user_end...\n";
    exit;
}
