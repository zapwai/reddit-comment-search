#!/usr/bin/env perl
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
use warnings;
use strict;

use Local::GetConfig qw(sloppily_set);
use Local::Foo qw( pull_links pull_comment_threads search );

my ( $begin_edate, $end_edate, $subreddit, $username, $string, $print_option,
     $get_option ) = sloppily_set;

print "Will downloading of threads be required? (Y/N): ";
my $response = <STDIN>;
chomp $response;
my @letters = split( //, $response );
$response = $letters[0];

if ( $response eq 'n' || $response eq 'N' ) {
    search( $begin_edate, $end_edate, $subreddit, $username, $string,
	    $print_option, $get_option );
} else {
    pull_links( $subreddit, $begin_edate, $end_edate );
    pull_comment_threads( $subreddit, $begin_edate, $end_edate );
    search( $begin_edate, $end_edate, $subreddit, $username, $string,
	    $print_option, $get_option );
}
