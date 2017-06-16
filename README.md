# Reddit Comment Search
Downloads all listings (into LINKS) then threads (into Extended_JSON_Comments). Then searches for specified username as the author of the comments (from *all* replies, no matter how deep) between the specified dates in the specified subreddit. 

----

Uses wget and Perl with the DateTime and JSON modules.

Usage:
1) Edit the config file,
2) Type "perl pull_links.pl" in the terminal.

or if you've already pulled the threads down,

2) Type "perl search.pl" in the terminal.

----

This will wget all threads, one day at a time, from the subreddit.
A small example is provided over a 12 day period. It will take a while to download the threads if you use a larger time period or a popular subreddit.

(e.g. Downloading /r/Buddhism from Jan 01 2007 to Jan 01 2014 took 10 minutes to pull listings, then 90 minutes to download the reddit threads, and 5 minutes to search for a string in that set of files. This was 400MB of content at nearly 100KB/s, pulling down about 5 threads a second. It used 14MB of RAM by the end of the downloading phase, and 25-30MB during the (single-core) search.)

A blank username will search all comments for a string.

A blank string will output all comments by the given username.

----

Todo:
1) Allow multiple keywords rather than just a string.
2) Allow multiple subreddits.
3) Allow multiple usernames (both in the thread, or saying the string).
4) UTF support, both in thread titles and body (currently says 'Wide character' for special characters.)
5) Provide some feedback when pulling listings and threads, so the user knows ETA. (pull_links.pl is currently silent.)
6) Auto-detect and fix 'malformed JSONs'. (Just delete that .json and retry.)

Bugs:
1) Searches all downloaded threads, regardless of date. (It has to check the header JSON for the date, *then* choose to ignore it. Very slow. Reddit uses fairly predictable alphabetical IDs though.)
2) Prints all link submissions, regardless of date.

----

See http://zapwai.net/dorfman/ for a specific application.
