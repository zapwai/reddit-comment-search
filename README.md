# Reddit Comment Search
Downloads all listings (into LINKS) then threads (into Extended_JSON_Comments). Then searches for specified username as the author of the comments (from *all* replies, no matter how deep) between the specified dates in the specified subreddit. 

----

Uses wget and Perl with the DateTime and Cpanel::JSON::XS modules.

Usage:
1) Edit the config file,
2) Type "perl pull_links.pl" in the terminal.

or if you've already pulled the threads down,

2) Type "perl search.pl" in the terminal.

----

This will wget all threads, one day at a time, from the subreddit.
A small example is provided in the config file. It will take a while to download the threads if you use a larger time period or a popular subreddit.

A blank username will search all comments for a string.

A blank string will output all comments by the given username.

----

Todo:
1) Allow multiple keywords rather than just a string.
2) Allow multiple usernames (both in the thread, or saying the string).
3) Allow multiple subreddits. (Trivial for the user to just run the program repeatedly though.)
4) UTF support, both in thread titles and body (currently says 'Wide character' for special characters.)
5) Provide some better feedback when pulling listings or threads, so the user knows ETA.

Bugs:
1) Prints all link submissions, regardless of date.
2) Going to be buggy with huge subreddits like /r/all, bc of reddit's 1000 thread limit. (I would have to detect this and then increase the number of listings pulled to more than one a day.)

----

See http://zapwai.net/dorfman/ for a specific application.
