# Notes

Downloading /r/Buddhism from Jan 01 2007 to Jan 01 2014 took 10 minutes to pull listings, then 90 minutes to download the reddit threads, and ~5 minutes to search for a string in that set of files. This was 400MB of content at nearly 100KB/s, pulling down about 5 threads a second. It used 14MB of RAM by the end of the downloading phase, and 25-30MB during the (single-core) search. I'm still optimizing the search; Using an index file of dates to open fewer files halved the search time.

Update: Ooh... don't use JSON. Use JSON::XS. (Thanks Devel::NYTProf and Perl Maven! The 5 minute search I was crying about is down to 7 seconds.)

----

Unfortunately that doesn't speed up my download time for a large request. Now considering opening multiple jobs for wget or using another tool.