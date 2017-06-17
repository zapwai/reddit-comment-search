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
##################################################################################
##################################################################################
use DateTime;
# I want the location of the  second  occurance of the word "Listing".
# I need to split the JSONs a bit earlier than this, at comma.
sub split_merged_jsons {
    my $row = shift;
    my $MehPt = index( $row, 'Listing' ) + 3;
    my $BrokenRow = substr ( $row, $MehPt ); 
    my $EndPt = index( $BrokenRow, 'Listing' ) + 4;
    my $FirstJSON= substr ( $row, 1 , ($EndPt - 3) );
    my $SecondJSON = substr ( $row, $EndPt , -1);
    return ($FirstJSON, $SecondJSON);
}

sub is_valid_date {
    my $date = shift;
    if ($date =~ m/[^\d]/) {
	print "Non-numeric character encountered in date.\n"; exit;
    }
    if (length($date) != 6) {
	print "Wrong date length encountered.\n"; exit;
    }
    return 1;
}

sub get_edate {
    my $date = shift;
    my @digits = split "", $date;
    my $day = $digits[2].$digits[3];
    my $month = $digits[0].$digits[1];
    my $year = "20".$digits[4].$digits[5];
    my $dt = DateTime->new(
	year => $year,
	month => $month,
	day => $day,
	hour => 0,
	minute => 0,
	second => 0, 
    );
    my $edate = $dt->epoch;
    return $edate;
}
1;
