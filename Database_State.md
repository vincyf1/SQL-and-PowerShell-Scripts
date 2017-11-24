Source: https://www.dbrnd.com/2017/11/sql-server-interview-theory-what-are-the-different-states-of-database/
Author: Anvesh Patel

**ONLINE:**

If the database is in ONLINE state, that means it is available for all end users and functioning normally. 
The ONLINE database state means primary filegroup is online and might be other recovery process is running in the background.

**RESTORING:**

If the database is in RESTORING state, that means user started restoring process of your database using something like 
RESTORE DATABASE. In this state, the end user cannot access the database because it is under restoration. There are two 
options for restoring like RECOVERY and NORECOVERY.

The option RECOVERY will bring the database back into online state once it completes the restoration. The option NORECOVERY 
will keep the database in RESTORING state because the user might be restoring the database from multiple files and after all 
restore, we can change the state.

**RECOVERING:**

This is a recovery state of the database where the database is performing a recovery process. When few transactions are 
uncommitted, and database got shut down, at next startup of the database you can find RECOVERING state of the database.
At the startup time, it is trying to recover database from uncommitted transactions.

**RECOVERY PENDING:**

If your database in RECOVERY PENDING state, that means database recovery process failed due to some X reason. The end user 
cannot access the database in RECOVERY PENDING state.

**SUSPECT:** 

If the database is in SUSPECT mode, that means database recovery process has started but not completed successfully. If 
database in the SUSPECT state, the end user cannot access the database.

**EMERGENCY:**

Generally, this state is set by SQL Server System Admin for performing database maintenance task. In this state, the 
database will be in single-user mode, and login is restricted only to sysadmin account.

**OFFLINE:**

Only explicitly we can bring database in OFFLINE mode where the end user cannot access the database and database also stop 
the performing all functions. When DBAs are moving disk location or adding disk space, they are changing the database in 
OFFLINE mode.
