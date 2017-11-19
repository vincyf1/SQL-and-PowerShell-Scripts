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

Telnet is one of those very unfriendly programs because underneath that 1st line you’ll just have a blinking cursor… not even a cmd prompt, just a cursor. So you have to know what to do.

However, let’s mark what telnet has told us so far. So far by being able to connect to the server, we know the following:
1. There’s nothing wrong with the network between the 2 servers.
2. Port 25 isn’t being blocked by anything.
3. The smtp server is running and active.

Now, this is a simple port test so we still don’t know if we can send mail to that server. We just know that physically there’s nothing standing in our way. Had this step failed, we would proceed with testing the network connection, firewall, anti-virus (AV), and Exchange. You won’t be able to test Exchange itself probably, but you can ask your Exchange guy if it’s up. And you can ask your network guy if he knows of anything wrong with the network between the 2 servers. At this point though, chances are it’s a firewall issue. That could mean a local Windows firewall, or maybe your AV has a firewall, or it could be an external firewall sitting between the 2 servers. But usually when you can’t connect you’ve either got a firewall issue, or you’ve typed something wrong in the cmd.

One more thing on this before I move on. If it appears to hang instead of returning an error it’s highly likely that it’s a firewall issue. This is the #1 sign that you’re being blocked. So if you hit enter on your cmd and it just doesn’t return, or takes a long time to return, then start looking at firewall issues before you do anything else. Otherwise the cmd should return fairly quickly… usually within 1-2secs.

Ok, we’ve verified basic connectivity, now we need to see if we can actually send mail through that host. We’re going to physically test that in a min, but for now let’s stay with telnet and do a couple tests.
Let’s start with a simple HELLO cmd. In smtp world, we’re going to use EHLO, which means Extended Hello.
First though you’ll need to reset with RSET. Then you’ll run EHLO, then you’ll get your results.
*Note that after each cmd you’ll be greeted by the same unfriendly cursor with no cmd prompt. It’s not thinking, it’s waiting for a cmd from you. Here’s the entire session:

You’ll see that all the responses start with 250. 250 means OK.
For further reading here’s a piece on Extended SMTP: http://en.wikipedia.org/wiki/Extended_SMTP

*NOTE: Of course, you could just have the wrong smtp server name… wouldn’t it be great if it were that simple?

## 4. Test SMTP Relay through telnet.

Now we’re going to start our relay tests. This will tell us if the server is setup to be able to send mail through the smtp server.
Before we get into the actual cmds though, I want to take a couple mins and explain why we have to do this. This is a beginner tutorial after all, so I like to explain things.

### What is SMTP Relay?

Ok, so here’s the scoop, and I’ll be as brief as I can. The spammers of this world like to send emails to as many people as they can. They hide viruses in their emails, porn, and sometimes their just nonsense. Regardless of their goal they have this funny thing about getting caught. It’s actually illegal to spread viruses intentionally through email spam. So what these dastardly doers of dirty deeds do is they look for an open email server they can use to send the spam for them. Once they find an unsuspecting email server out on the internet, they use that server to relay their spam for them. So the way companies fight this is they lock down their email servers so that only certain servers can use them as an SMTP relay. I’m pretty sure MS Exchange comes locked down out of the box these days, so good for MS. You have to specifically open up SMTP relay for any server you want to allow to send mail through your Exchange server. And what we’re going to do now is test whether our server can send email through our email server.

Before each set of cmds you have to reset. So you’ll notice I always type RSET before each set.

In the above pic, the greens are your reset cmds. Notice there’s one after each set of cmds?
Also, I didn’t EHLO first so I had to do that before I could do anything else. And once I got my response back I ran RSET and then my yellow cmds. My yellow cmds are the ones that actually test the relay. They pretty much explain themselves so I won’t go into any detail.

If your relay cmds fail then perhaps you should talk to your email admin to make sure your server is setup as an SMTP Relay. You’ll send him your IP and he’ll make it happen.
To get out of telnet type QUIT.
And just so there are no misunderstands, here’s the list of cmds from start to finish for this operation.
telnet smtp.domain.tdl
rset
ehlo
rset
mail from:FromEmail@domain.com
rcpt to:ToEmail@domain.com

If everything succeeds then we know that our server is setup with smtp relay through the email server.






