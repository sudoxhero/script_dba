set linesize 30000
col "Group" for 99
col "Thread" for 99
col "Status" for a10
col "# of Members" for 99
col "Archived" for a10
col "Size (KB)" for 999999999
col "Sequence" for 999999999
col "First Changed #" for 999999999

SELECT 
                        group# as "Group",
                        THREAD# as "Thread",
                        NLS_INITCAP(status) as "Status", 
                        members as "# of Members", 
                        NLS_INITCAP(archived) as "Archived", 
                        TO_CHAR((bytes / 1024),'99999990') as "Size (KB)", 
                        sequence# as "Sequence", 
                        first_change# as "First Changed #" 
                    FROM 
                        v$log 
                    ORDER BY 1;
                    
