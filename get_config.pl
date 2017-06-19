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
##################################################################################
##################################################################################

require "routines.pl";
our ($user_begin, $user_end, $subreddit, $username, $string, $print_option, $get_option);
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

    print "Print comments? (yes/no): ";
    $print_option = <STDIN>;

    print "Enter downloading program (wget/aria2): ";
    $get_option = <STDIN>;
    
    open (my $FH, ">", $config_file)
	or die ("I cannot write the config file. $!\n");
    print $FH "startdate(mmddyy):".$user_begin."enddate(mmddyy):".$user_end."subreddit:".$subreddit."username:".$username."string:".$string."print_comments:".$print_option."download_program:".$get_option;
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
($user_begin, $user_end, $subreddit, $username, $string, $print_option, $get_option) = @data;

if ($subreddit =~ /^\s*$/) {
    $subreddit = "dwarffortress";
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
