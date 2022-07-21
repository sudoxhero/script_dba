Find the amount of space allocated to data in the tablespaces
1.    Determine the spread of the space that's allocated to different components of the Oracle database:

set pages 200
select
'===========================================================' || chr(10) ||
'Total Database Physical Size = ' || round(redolog_size_gb+dbfiles_size_gb+tempfiles_size_gb+ctlfiles_size_gb,2) || ' GB' || chr(10) ||
'===========================================================' || chr(10) ||
' Redo Logs Size : ' || round(redolog_size_gb,3) || ' GB' || chr(10) ||
' Data Files Size : ' || round(dbfiles_size_gb,3) || ' GB' || chr(10) ||
' Temp Files Size : ' || round(tempfiles_size_gb,3) || ' GB' || chr(10) ||
' Archive Log Size - Approx only : ' || round(archlog_size_gb,3) || ' GB' || chr(10) ||
' Control Files Size : ' || round(ctlfiles_size_gb,3) || ' GB' || chr(10) ||
'===========================================================' || chr(10) ||
' Used Database Size : ' || used_db_size_gb || ' GB' || chr(10) ||
' Free Database Size : ' || free_db_size_gb || ' GB' ||chr(10) ||
' Data Pump Directory Size : ' || dpump_db_size_gb || ' GB' || chr(10) ||
' BDUMP Directory Size : ' || bdump_db_size_gb || ' GB' || chr(10) ||
' ADUMP Directory Size : ' || adump_db_size_gb || ' GB' || chr(10) ||
'===========================================================' || chr(10) ||
'Total Size (including Dump and Log Files) = ' || round(round(redolog_size_gb,2) +round(dbfiles_size_gb,2)+round(tempfiles_size_gb,2)+round(ctlfiles_size_gb,2) +round(adump_db_size_gb,2) +round(dpump_db_size_gb,2)+round(bdump_db_size_gb,2),2) || ' GB' || chr(10) ||
'===========================================================' as summary
FROM (SELECT sys_context('USERENV', 'DB_NAME')
db_name,
(SELECT SUM(bytes) / 1024 / 1024 / 1024 redo_size
FROM v$log)
redolog_size_gb,
(SELECT SUM(bytes) / 1024 / 1024 / 1024 data_size
FROM dba_data_files)
dbfiles_size_gb,
(SELECT nvl(SUM(bytes), 0) / 1024 / 1024 / 1024 temp_size
FROM dba_temp_files)
tempfiles_size_gb,
(SELECT SUM(blocks * block_size / 1024 / 1024 / 1024) size_gb
FROM v$archived_log
WHERE first_time >= SYSDATE - (
(SELECT value
FROM rdsadmin.rds_configuration
WHERE name =
'archivelog retention hours') /
24 ))
archlog_size_gb,
(SELECT SUM(block_size * file_size_blks) / 1024 / 1024 / 1024
controlfile_size
FROM v$controlfile)
ctlfiles_size_gb,
round(SUM(used.bytes) / 1024 / 1024 / 1024, 3)
db_size_gb,
round(SUM(used.bytes) / 1024 / 1024 / 1024, 3) - round(
free.f / 1024 / 1024 / 1024)
used_db_size_gb,
round(free.f / 1024 / 1024 / 1024, 3)
free_db_size_gb,
(SELECT round(SUM(filesize) / 1024 / 1024 / 1024, 3)
FROM TABLE(rdsadmin.rds_file_util.listdir('BDUMP')))
bdump_db_size_gb,
(SELECT round(SUM(filesize) / 1024 / 1024 / 1024, 3)
FROM TABLE(rdsadmin.rds_file_util.listdir('ADUMP')))
adump_db_size_gb,
(SELECT round(SUM(filesize) / 1024 / 1024 / 1024, 3)
FROM TABLE(rdsadmin.rds_file_util.listdir('DATA_PUMP_DIR')))
dpump_db_size_gb
FROM (SELECT bytes
FROM v$datafile
UNION ALL
SELECT bytes
FROM v$tempfile) used,
(SELECT SUM(bytes) AS f
FROM dba_free_space) free
GROUP BY free.f);
If the space allocated to temporary tablespace is more than expected, then use the following queries to further analyze the space used on your database.

2.    To view information about temporary tablespace usage, run the following query on the view DBA_TEMP_FREE_SPACE:

SQL> SELECT * FROM dba_temp_free_space;
3.    To resize the temporary tablespace (for example, to 10 GB), run the following query based on the output of the tablespace usage query:

SQL> ALTER TABLESPACE temp RESIZE 10g;
This command can fail if the tablespace has allocated extends beyond the 10-GB threshold.

4.    If the command fails, then shrink space on the temporary tablespace by running the following command:

SQL> ALTER TABLESPACE temp SHRINK SPACE KEEP 10g;
5.    To check for long-running sessions that are performing active sorting to disk and have temporary segments allocated, run the following query:

SQL> SELECT * FROM v$sort_usage;
6.    Based on the output, you can terminate the session (if the application logic and business allow), and retry resizing the temporary tablespace by following step 3.

7.    If terminating sessions is not an option, create a new temporary tablespace. Then, set the new tablespace as the default, and drop the old temporary tablespace:

SQL> SELECT property_name,property_value FROM DATABASE_PROPERTIES where PROPERTY_NAME='DEFAULT_TEMP_TABLESPACE';
SQL> create temporary tablespace temp2;
SQL> exec rdsadmin.rdsadmin_util.alter_default_temp_tablespace(tablespace_name => 'temp2');
<wait for a few minutes and verify if the default temporary tablespace for all users have been updated>
SQL> set pages 2000
SQL> column username for a30
SQL> select username, TEMPORARY_TABLESPACE from dba_users;
SQL> drop tablespace temp including contents and datafiles;
Check the space allocation for archive logs or trace files
1.    Check the current archive log retention:

SELECT value FROM rdsadmin.rds_configuration WHERE name ='archivelog retention hours';
2.    Calculate the space used by the archive logs by running the following query.

Note: X is the archive log retention set in the RDS instance. Replace X with the value reported in the previous query.

SELECT sum(blocks*block_size)/1024/1024/1024 FROM v$archived_log WHERE first_time >=sysdate-X/24 AND dest_id=1;
3.    If the space allocated for archive logs is more than expected, then update the retention policy value. You can then allow Amazon RDS automation to clear older archive log files. The following example configures the RDS instance to retain 24 hours of archive logs:

begin
 rdsadmin.rdsadmin_util.set_configuration(name => 'archivelog retention hours', value => '24');
end;
 /
commit;
For more information about listing and purging trace files, see Purging trace files.

Check the space allocation for the data pump directory
1.    If the space allocated on the data pump directory is more than expected, then check the available .dmp files that can be removed to free up space:

SQL> SELECT * FROM TABLE(RDSADMIN.RDS_FILE_UTIL.LISTDIR('DATA_PUMP_DIR')) ORDER by mtime;
2.    If this query finds .dmp files, delete them by running the following query, replacing the file name with the name of the .dmp files:

SQL> EXEC utl_file.fremove('DATA_PUMP_DIR','[file name]');
