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

## 5. Send test email through vbs or Powershell.

Now we’re going to complete out smtp test at the Windows level by sending a couple emails without SQL in the picture. Remember, this whole thing started because DBMail doesn’t work, but we still haven’t ascertained whether the issue is with SQL or with Windows. So far though it’s none of these things:
1. Network
2. email server
3. firewall
4. SMTP Relay

Now we’re just going to test email through a mechanism that isn’t SQL so we can make sure there’s nothing wrong with Windows communications or something else we didn’t test for specifically.
I thought about providing both the vbs and the powershell code, but I’m just going to give you the powershell. Seriously, if you’re still using vbs then you deserve what you get. Learn something.
So here’s the powershell.
```
$smtpServer = "emailserver"
$smtpPort = 25
$emailFrom = "from@domain.com"
$emailTo = "to@domain.com"
$smtp = new-object Net.Mail.SmtpClient($smtpServer)
$smtp.Port = $smtpPort
$subject = "subject" 
$body = "body " 
$smtp.Send($emailFrom, $emailTo, $subject, $body)
```

I’ll be honest, I pulled that off the internet somewhere a while back but it’s pretty straightforward so I don’t think there should be any licensing issues.

The reason we do this step is because you can test one thing or another all you like, but for me, mail isn’t working until I get an actual email. The previous step didn’t actually send an email. This one does.
OK, so if that worked, then you’ve actually got email flow from your server to Exchange, and from Exchange to your mailbox.
You can stop tshooting Windows now. We’ve verified everything we need and we can now concentrate on this being a SQL problem.

### Intermission

Real quick, before we move on to SQL tshooting, I need to go back and cover a couple places errors could have occurred in some of the previous steps. Specifically, firewalls. If you weren’t able to telnet to the smtp server at all, then I said the chances are it’s probably a firewall issue. So I just wanted to discuss firewalls briefly with these next 2 steps. I had to put them somewhere. However, if you were able to connect with telnet then you can skip these steps.

## 6. Check Firewall blocking application or port.

Briefly, a firewall is an app that controls which ports you can communicate with servers on. In this case, port 25. It’s very likely that your NT guys have locked down the server and are blocking port 25 because they didn’t anticipate you needing to send mail through there. You’ll probably need their help to unblock it because if you do it yourself, it could be part of a policy somewhere and it would just be reset in the future and you’d be right back where you are now. So work with your Windows guys to unblock the port. It’s also possible that the email guys have smtp on another port, so talk to them to and make sure they haven’t switched ports on you.
I’m not really interested in talking you through an intimate tutorial on how to configure Windows Firewall because there’s plenty of that out there. So if you don’t know how to check it out for yourself, then go to your Windows guys. They should know.

Also, the firewall might not be in Windows at all. It could be anywhere between the 2 servers. So you may have to talk to your router guys too to make sure there isn’t an appliance in between somewhere. Remember, telnet doesn’t know where it’s being blocked, just that it’s happening. And to tell the truth, it doesn’t really even know that, it just knows it can’t reach its destination and it ends up timing out.

## 7. Check anti-virus blocking application or port.

This really belongs with the above step but I thought I should call it out specifically. Many AV vendors have started including their own firewalls that can block apps and ports. So you may see that there’s nothing wrong with Windows Firewall and that there are no appliances in the mix, but you’re still being blocked. So it may be an AV firewall. Chances are you won’t have rights to change the setting and you may not even be able to view it either. So you’ll most likely have to go to your Windows guys for help with this one. And even if you could see it, a lot of times they’re configured at an enterprise level through the AV mgmt. software so again, you won’t be able to do this on your own. I just wanted you to know that this is out there.

## 8. Run DatabaseMail.exe manually.

We’re at another crossroads here. We’ve decided that there’s nothing wrong with Windows, firewalls, the network, or the email server. The problem is definitely somewhere in SQL. So how do we know where to begin looking? We’ve got to decide if this is a config issue, or something deeper. This step will take us a good way to deciding that.
Let’s take a quick look at what happens. When you send an email through DBMail, it gets put into a table. We’re going to investigate the tables later. That’s why you get a notice that says ‘Mail queued.’. Then SQL calls DatabaseMail.exe to actually send the mail. So we’re going to send the mail manually using the same method so we can get around any config issues that may be getting in the way.
You’re going to go to your Binn (pronounced Bin-N) folder and run the DatabaseMail.exe app. Your Binn folder is in your SQL install folder. I can’t tell you exactly where it’ll be because different versions are slightly different and install locations aren’t all the same. But here’s where mine is: C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Binn

You can double-click the exe and it’ll open a cmd window. There won’t be anything in the window, it’ll be completely blank. And it’ll stay open until you close it. What should happen though is you should see your email queue starting to be processed. If you do start seeing emails being sent then you know for a fact that the issue is something in the config. Email itself is working just fine. What’s broken is how SQL is calling it. Maybe it’s a security issue, or maybe a routing issue.

It happens from time to time that something happens with DatabaseMail.exe. It’s possible it’s not even there. These things don’t happen to themselves so somebody had to delete it. I had a client quite some time ago who deleted it because they wanted to lockdown the instance and they didn’t want even the smallest chance that an email could be sent through DBMail on that box. Then that DBA left and the next guy was left to figure out what happened. SQL is expecting DatabaseMail.exe to be in the Binn folder of the SQL install directory so if it’s not there, then you need to take it from an instance of the same version and put it in Binn.

There could also be permissions issues, which we’ll cover more in detail in the next couple steps.
Of course, if the window just opens and closes really quickly then call it from the cmd line and you’ll get the error.

I’ve known guys who couldn’t get DBMail working in SQL so they opened DatabaseMail.exe and just left it open to process email. Let me tell you that this is 100% the wrong approach. It can be a stop-gap in a pinch, especially if it gets mail flowing again, but you should never use this as a permanent solution. But you can use it to get you out of the fire while you troubleshoot. You can run this manually to process the email, then troubleshoot for a while, then run it manually again to clear the queue again, and so on. So it’s a good way to keep the lights on.

## 9. Check DatabaseMail.exe permissions.

If you’re unable to manually send through DatabaseMail.exe then it may be a permissions issue. Your account may not have rights to run the program. And depending on how Windows is setup and your perms on that box, it may or may not be an easy fix. So try to give yourself rights to execute DatabaseMail.exe and if you’re not able to, then you may need to get your Windows guys involved. Of course, if you give yourself perms and you still can’t run it then you may need to logout and login again.

All the same, you shouldn’t really go any further until you can run it manually and get email to flow.

## 10. Stop/Start DBMail.

Sometimes simply stopping and starting DBMail can make things work again, especially after a config or permissions change. So you’ll probably run this stop and start code after everything you try. Most of the time it won’t make a difference, but I would hate to be tshooting something for 2hrs when I fixed it and didn’t restart DBMail to have the change take effect.
```
USE msdb ;
GO
EXECUTE dbo.sysmail_stop_sp ;
GO
USE msdb ;
GO
EXECUTE dbo.sysmail_start_sp ;
GO
--Check the status of DBMail
USE msdb ;
GO
EXECUTE sysmail_help_status_sp ;
GO
```

These are all self-explanatory because they’re named well enough. However, you should note what stopping DBMail does.
Per MSDN:
“This stored procedure only stops the queues for Database Mail. This stored procedure does not deactivate Service Broker message delivery in the database. This stored procedure does not disable the Database Mail extended stored procedures to reduce the surface area.”
Here’s the link to the article:
https://msdn.microsoft.com/en-us/library/ms173412.aspx

## 11. Change service account to Network Service and back to the domain account it was using.

This is a really big one, and it’s one of those permissions issues I’ve talked about.
What happens is someone (typically a DBA) will go in and change the account that the services are running under and instead of doing it through SSCM (SQL Server Configuration Manager), they’ll do it through Service.msc in Windows. This is the wrong way to change a service account for SQL.
The reason you should go through SSCM is because it’s smart. It knows things about SQL and what the services need, and the state of things. For instance, it knows when SQL is clustered. But for our purposes, there are permissions that an account needs to be able to run SQL effectively, and SSCM puts those permissions in place. You can go directly through Windows if you like, but then you’ll have to go give all the permissions manually, and that’s a ridiculous amount of work when you can just use the tool they gave you.

So if this is the case, if you’ve possibly had a service account change, then that could have stopped DBMail because the new service account doesn’t have the permissions it needs to access DatabaseMail.exe. The easiest way to handle this is to give the Agent service account the proper permissions. And the easiest way to do that is to set the Agent service to run under a different account first. Use something like Network Service, or local system. Then restart the Agent. The Agent service should now be running under the new account. Now, once that’s done, set it to start under the account you had already had in place before and restart the Agent service again. What this does is give you a way to let SSCM set the proper permissions when you setup the start account.

In my years of supporting DBMail I’ve only had to do this step like 3 times. 2 times, this worked exactly as planned. But 1 time, I had to perform this step on the SQL service itself as well as the Agent service. I’ll be honest, I don’t know why, but I wanted you to know that it’s a possibility.

If you try to use Network Service to startup the Agent service, and you’re unable to, it may be a permissions issue within SQL. So give the Network Service sa in SQL and it should startup just fine. Once you’ve got the services working under the proper accounts again you can remove the permissions from Network Service.

You may need to stop/start DBMail after you bounce the Agent. Mail should start flowing right away if the issue has been cleared.

## 12. Make sure msdb is owned by sa.

I’m not going to pretend to know what this is about. In my research for my issue I came across a few forum posts that suggested that this may be the issue. In fact, the forum posts say to make sure all system DBs are owned by sa. I’ve never had a system DB not be owned by sa, but I wanted to throw this in there to be complete.

## 13. Check there isn’t a space after the profile name or the SMTP server name in the mail config.

Something like this should produce an error that the profile doesn’t exist. However, if you’re not paying attention to errors at this stage, which you should be, then you may miss this. But I’ve seen misspellings of the profile name many times and this falls under that category.

## 14. Test different authentication methods in the mail config.

Depending on how the email server is configured you may need to try different authentication methods to the smtp server.

To get to that screen follow this path in SSMS:
Database Mail\Configure Database Mail\Manage Database Mail accounts and profiles\View, change, or delete an existing account

You may need to work with your email admins to make sure you’re authenticating to the smtp server correctly. They may have something special setup.

## 15. Make sure the profile is set to Public.

You’ll need to make sure the profile is accessible to the public. That’s assuming you want this to be a public profile that is. Even if you’re not using this as a default profile (you’re calling it specifically in your email call), it’ll still need to be a public profile unless you go out of your way to set it up as a private profile for that account.
Here’s where you can manage these aspects of your profile:
Database Mail\Configure Database Mail\Manage profile security

## 16. Make sure the user sending the mail is either an admin or is in the DatabaseMailUserRole.

The user has to have permissions to call the sendMail SP. So make sure the user account sending the email is either a sysadmin (reserved only for DBAs), or is in the DatabaseMailUserRole role in msdb. There isn’t too much more to say about this really.

## 17. Check Service Broker is enabled in msdb.

When all is said and done, controlled by Service Broker (SB). So you have to make sure that SB is enabled for msdb.

```
USE master ;
GO
ALTER DATABASE msdb
SET ENABLE_BROKER ;
GO
```

Now, you have to have exclusive access to msdb. So you may need to turn off the Agent service. Just don’t do it on a prod box while there are jobs running that you really need.
NOTE: If by chance msdb were restored from another box, you won’t be able to enable SB like this. You’ll need to create a new SB GUID using the directions in #21 below.

## 18. Check that DatabaseMail.exe is in the Binn folder.

We mostly covered this in an above step, but it’s worth repeating in case you missed it. DatabaseMail.exe should be in your instance’s Binn folder. If it’s not there then someone has removed it and it needs to be put back. So go to another instance of the same version and copy this app to the Binn folder. Sometimes it’ll be called something different. SQL 2005 comes to mind where it’s called DatabaseMail90.exe. You may need to set permissions for the Agent account once you replace the app, but it depends on your Windows security config.

## 19. Check for Aliases that don’t belong or are misconfigured.

This one is obscure, but definitely worth checking. This one was the final piece to fixing my issue. Here’s what happened. I’m still trying to figure out why this was done, but still.

The box I had this issue on was a QA box. We’ll call it QA1. There was an Alias setup with the same name, QA1, but it was pointing to the prod box. I don’t understand why someone did this, but it’s there. Removing this Alias allowed mail to flow again. Actually, this is that routing issue I mentioned in one of the steps above. The request is being routed to a different box. There were some other hints that this was the issue. I saw some login failures in the Agent log. I didn’t think anything of it at the time, but now that I see the Alias the picture is clear. The Agent was being routed to a different box where of course you’re going to have login failures. I don’t know if you’ll get the login failures in the log every time you have this issue, but it’ll definitely keep mail from flowing.
Aliases are well-documented so I’m not going to bother explaining it here, but don’t leave this out of your investigation, especially if you’re still not getting an error message.

## 20. Check the hosts file for entries that may be misconfigured and messing things up.

This one is even more obscure but I’ve seen it once. If the subject of your email is coming from a SQL query, then you may get an error message about it not being able to resolve the loopback or something to that effect. This could easily be because of the Alias issue above, but it could also be that you need to add 127.0.0.1 to your HOST file. The chances that this is your problem are pretty slim, but I’m trying to be complete and list everything I can think of.

## 21. Re-issue the Service Broker GUID for msdb.

Since we’re dealing with Service Broker (SB) here, then things can go wrong. This one too is obscure but keep it under your hat just in case. Sometimes a DB doesn’t get a unique SB GUID. In this case you can replace the GUID.
You’ll need to stop the Agent service so you can have exclusive rights to the DB so don’t do this at any time when you need jobs to run. But the operation itself only takes a few secs so it’s not too bad.

```
ALTER DATABASE msdb
SET NEW_BROKER
```

## DBMail System Objects

sysmail_delete_mailitems_sp — Deletes messages from the queue. This is very handy if you’re pushing a lot of test messages into the queue and they’re getting stuck in there. By clearing the queue you can make sure you’re not flooded with 200 messages all at once when you get email flowing again. If I were you, I’d run then when my queue gets too big unless you just can’t afford to lose some of them. Here’s the MSDN documentation for this SP: https://msdn.microsoft.com/en-us/library/ms190293.aspx
** NOTE: You can delete individual messages out of the queue manually.

These are the DBMail tables we’re interested in. Rather than define each one, I’ve included the MSDN doc for them.

sysmail_allitems — https://msdn.microsoft.com/en-us/library/ms175056.aspx

sysmail_event_log — This is where you’ll see your error messages for individual emails that have failed to send. https://msdn.microsoft.com/en-us/library/ms178014.aspx

sysmail_faileditems — https://msdn.microsoft.com/en-us/library/ms187747.aspx

sysmail_sentitems — https://msdn.microsoft.com/en-us/library/ms174372.aspx

sysmail_unsentitems — https://msdn.microsoft.com/en-us/library/ms187817.aspx




