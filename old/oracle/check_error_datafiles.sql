set linesize 30000
col "Datafile Name" for a20
col "Datafile Number" for a20
col "Tablespace Name" for a20
col "Datafile Status" for a20
col "Error" for a50
col "Change #" for a10
col "Time" for a10

SELECT 
                d.NAME as "Datafile Name", 
                r.FILE# as "Datafile Number", 
                t.NAME as "Tablespace Name", 
                d.STATUS as "Datafile Status", 
                r.ERROR as "Error", 
                r.CHANGE# as "Change #", 
                r.TIME as "Time"
            FROM 
                GV$RECOVER_FILE r, 
                GV$DATAFILE d, 
                GV$TABLESPACE t
            WHERE 
                t.TS# = d.TS# AND 
                d.FILE# = r.FILE#;
               
