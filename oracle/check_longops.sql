SELECT s.sid,
       s.serial#,
       s.machine,
       ROUND(sl.elapsed_seconds/60) || ':' || MOD(sl.elapsed_seconds,60) elapsed,
       ROUND(sl.time_remaining/60) || ':' || MOD(sl.time_remaining,60) remaining,
       ROUND(sl.sofar/sl.totalwork*100, 2) progress_pct
FROM   v$session s,
       v$session_longops sl
WHERE  s.sid     = sl.sid
AND    s.serial# = sl.serial#;

SELECT SID, SERIAL#, OPNAME, TARGET, SOFAR, TOTALWORK, UNITS,
TO_CHAR(START_TIME,'DD/MON/YYYY HH24:MI:SS') START_TIME,
TO_CHAR(LAST_UPDATE_TIME,'DD/MON/YYYY HH24:MI:SS') LAST_UPDATE_TIME,
TIME_REMAINING, ELAPSED_SECONDS, MESSAGE, USERNAME
FROM V$SESSION_LONGOPS
WHERE TIME_REMAINING != 0;

SELECT SQL_ID, SQL_TEXT, ELAPSED_TIME from V$SQL WHERE SQL_ID = (SELECT SQL_ID FROM V$SESSION WHERE SID=27);

