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

## 2. Check Mail XPs are enabled.

We need to check whether the Mail XPs are enabled. There will be no email until these XPs are enabled. So open a query window and run this query:
```
sp_configure 'Database Mail XPs'
 
sp_configure 'Database Mail XPs', 1
GO
RECONFIGURE
GO
```
Run line 1 above to query the status of the mail XPs. 0 means they’re disabled. 1 means they’re enabled. Run the rest of the code above to enable the XPs.

After you enable the XPs, try a test email. You can right-click on Management\Database Mail and choose ‘Send Test E-Mail’ and send it that way, but you’re likely to be sending lots of test emails so let’s use code instead. It’s faster.
```
EXEC msdb.dbo.sp_send_dbmail
@profile_name = 'profile',
@recipients = 'email@domain.com',
@subject = 'Test Email 1',
@body = 'Hey, I''m finally working!!'
```
I like to number my email subjects so I can see which one has finally come in when it starts working.

Now, we’ll assume that didn’t work, and that you checked the log again and there still aren’t any error messages. We need to check the Windows side now to make sure we’re not just spinning our wheels in SQL. That’s what we’ll do now.

## 3. Telnet to your mail server.

If you don’t have telnet installed you’ll need to go into the Control Panel and install it as a Windows Feature. I can’t tell you exactly how to do it because it’s slightly different in different versions of Windows. But what you want to install is called Telnet Client. It doesn’t require a reboot.

Once you’ve got telnet installed, open a cmd prompt and type the following syntax.
telnet SMTPservername 25

To break that down, telnet is the name of the program you’re running, SMTPservername should be replaced with the name of the SMTP server you’re trying to reach, and 25 is the port. So a real cmd could look something like this: telnet smtp.minion.com 25

You should get a response back right away.

So why did this call fail? Because you have to use the FQDN (Fully Qualified Domain Name) of the smtp server.
Here’s what it looks like when the call succeeds. I doesn’t show the call itself because that goes away as soon as you connect. But the call is this: telnet mailcon.midnight.dba 25

Notice the 3 part name of the server… host.domain.top-level-domain.
Now, strictly speaking it doesn’t HAVE to have the FQDN. In my experience you can use either the servername or the FQDN but you usually can’t use just the host.domain. But there are so many variations in networks I can easily see it be possible that yours is setup to be able to resolve host.domain. Anyway, whatever smtp address they gave you is what you should use.


