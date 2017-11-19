# Troubleshooting Guide for SQL Server Database Mail

This page was built using [This Guide](http://www.midnightdba.com/DBARant/complete-troubleshooting-guide-for-sql-server-databasemail-dbmail/) by **Shawn McCown**.

**Symptoms:**

	Mail used to work, but just quit a couple weeks ago.
	Mail sits in the queue unsent.
	There are no errors being logged for the messages. Normally you would expect to have an error of some kind to tshoot.
	There are not messages of any kind about the mail operation at all.
	

## 1. Check the DBMail log for any errors.

The first thing you ALWAYS do is look for error messages. With DBMail you can either check the log through the GUI or you can check the table directly. We’re going to check the table directly because it’s easier to type a query and to create a screenshot.
So open a query window and run this query:
```
SELECT * FROM msdb.dbo.sysmail_event_log
ORDER BY log_date DESC
```
Notice that I’m ordering it descending by date. That’s so the newest ones are on top and it keeps the scrolling down so you can easily see new entries. If you’re lucky you’ll have a nice error message you can troubleshoot. In this case there’s absolutely nothing and in fact there hasn’t been a new message in several days. So we’re flying blind here. But checking for errors is always the first place to start. So since there are no errors, we have to decide where the issue lies. It could be an issue with SQL itself, or something could have happened on the Windows or the Exchange side.
As long as we’re already in SQL though, let’s check some of the low hanging fruit while we’re here.


