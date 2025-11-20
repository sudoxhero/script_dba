select
   der.session_id,
   convert(char(12), dateadd(MILLISECOND,(der.total_elapsed_time), 0), 114) tempo,
   db_name(der.database_id) database_name,
   des.program_name,
   der.blocking_session_id,
   der.start_time,
   der.status,
   der.command,
   dest.text,
   cast(cast(deqp.query_plan as nvarchar(max)) as xml) query_plan,
   dec.client_net_address,
   des.host_process_id,
   des.login_name
from
   sys.dm_exec_requests der
   inner join
      sys.dm_exec_connections dec
      on der.session_id = dec.session_id
   inner join
      sys.dm_exec_sessions des
      on der.session_id = des.session_id CROSS APPLY sys.dm_exec_sql_text(sql_handle) dest CROSS APPLY sys.dm_exec_query_plan(der.plan_handle) deqp
where
   db_name(der.database_id) <> 'master'
   and der.session_id <> @@SPID
group by
   der.session_id,
   der.blocking_session_id,
   der.percent_complete,
   der.total_elapsed_time,
   der.estimated_completion_time,
   der.start_time,
   der.status,
   der.command,
   dest.text,
   cast(deqp.query_plan as nvarchar(max)),
   der.sql_handle,
   der.plan_handle,
   dec.client_net_address,
   des.host_name,
   db_name(der.database_id),
   des.program_name,
   des.host_process_id,
   des.login_name
order by
   2 desc
