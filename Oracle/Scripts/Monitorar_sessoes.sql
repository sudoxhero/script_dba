/*
Script voltado para ver as sessões ativas ordernadas por tempo de execução
*/

set colsep ";"
set linesize 500
set pagesize 1000
col elapsed_time for a10
col username format a15
col service_name format a20
col inst_id for 9
col sid for 99999
col machine format a45
col serial# for 99999
col sql_text for a50
col event for a50
col program for a50

select distinct inst_id, sid, serial#, username, machine, program, dbms_lob.substr(sql_text,50,1) as sql_text, sql_id, elapsed_time, status, event,service_name from (
select s.inst_id, s.sid, s.serial#, s.username, s.machine, s.program, gv.sql_text, gv.sql_id,
TO_CHAR(TRUNC(s.last_call_et/3600),'FM9900') || ':' || TO_CHAR(TRUNC(MOD(s.last_call_et,3600)/60),'FM00') || ':' || TO_CHAR(MOD(s.last_call_et,60),'FM00') as elapsed_time,
s.status, s.event,s.SERVICE_NAME
from gv$sql gv, gv$session s
where gv.sql_id=s.sql_id
and gv.inst_id=s.inst_id
and username is not null
and s.status='ACTIVE'
order by elapsed_time desc
)
order by elapsed_time desc;

/*

*/