# Reddit Comment Search
Downloads all listings (into LINKS) then threads (into Extended_JSON_Comments). Then searches for specified username as the author of the comments (from *all* replies, no matter how deep) between the specified dates in the specified subreddit. 

----

Uses perl with the DateTime and JSON libraries.

Usage:
1) Edit the config file,
2) Type "perl pull_links.pl" in the terminal.
or if you've already pulled the threads down,
2) Type "perl search.pl" in the terminal.

----

This will wget all threads, one day at a time, from the subreddit.
A small example is provided over a 10 day period. It will take a while to download the threads if you use a larger time period or a popular subreddit.
A blank username will search all comments for a string.
(A blank string will output all comments by the username.)

----

Todo:
1) Fix format of blank username result (does not display the author of each comment).
2) Allow multiple subreddits.
3) Allow multiple usernames (both in the thread or saying the string).
4) Bug: The start and end dates are only used when downloading links, not during a search!

----

See http://zapwai.net/dorfman/ for a specific application.

