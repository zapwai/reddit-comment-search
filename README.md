# Reddit Comment Search
Downloads all listings (into LINKS) then threads (into Extended_JSON_Comments). Then searches for specified username as the author of the comments (from *all* replies, no matter how deep) between the specified dates in the specified subreddit. 

----

Uses perl with the DateTime and JSON libraries.

Usage:
1) Edit the config file,
2) Type "perl pull_links.pl" in the terminal.

Currently allows one keyword.

This will wget all threads, one day at a time, from the subreddit.
A small example is provided over a 10 day period. It will take a while to download the threads if you use a larger time period or a popular subreddit.

----

Todo:
1) Fix format of blank username result(does not display the author of the comment).

----

See http://zapwai.net/dorfman/ for a specific application.

